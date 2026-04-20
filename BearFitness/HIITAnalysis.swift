//
//  HIITAnalysis.swift
//  BearFitness
//

import Foundation

// Whether HR should rise, fall, or has no expectation between two adjacent phases
private enum TransitionDirection { case rising, falling, neutral }

private func expectedTransition(from prev: WorkoutPhase, to curr: WorkoutPhase) -> TransitionDirection {
    switch (prev, curr) {
    case (.warmUp,        .highIntensity),
         (.lowIntensity,  .highIntensity):  return .rising
    case (.highIntensity, .lowIntensity),
         (.highIntensity, .coolDown),
         (.lowIntensity,  .coolDown),
         (.warmUp,        .coolDown):       return .falling
    default:                                return .neutral
    }
}

// MARK: - Section Analysis

struct SectionAnalysis: Identifiable {
    let id: UUID
    let section: SessionSection
    let heartRateSamples: [(date: Date, bpm: Double)]

    // Pre-computed by HIITAnalysisService using the previous section's HR tail.
    // 1.0 if no previous section or neutral transition.
    let transitionScore: Double

    var hasData: Bool { !heartRateSamples.isEmpty }

    var avgBPM: Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        return heartRateSamples.map(\.bpm).reduce(0, +) / Double(heartRateSamples.count)
    }

    var actualZone: HeartRateZone { HeartRateZone.from(bpm: avgBPM) }

    var passed: Bool {
        guard hasData else { return false }
        return section.phase.targetBPMClosedRange.contains(avgBPM)
    }

    var isClose: Bool {
        guard hasData, !passed else { return false }
        let target = section.phase.targetBPMClosedRange
        let dist = max(target.lowerBound - avgBPM, avgBPM - target.upperBound, 0)
        return dist <= 15
    }

    // ── Score components ──────────────────────────────────────────────────────

    // Fraction of individual HR samples that landed in the target zone (0–1)
    var zoneMatchScore: Double {
        guard hasData else { return 0 }
        let target = section.phase.targetBPMClosedRange
        let inZone = heartRateSamples.filter { target.contains($0.bpm) }.count
        return Double(inZone) / Double(heartRateSamples.count)
    }

    // Alias kept for display code
    var compliancePercent: Double { zoneMatchScore }

    // Combined interval score: 70% zone match + 30% transition quality
    // Falls back to transition-only when no HR data is available.
    var intervalScore: Double {
        if hasData {
            return 0.7 * zoneMatchScore + 0.3 * transitionScore
        } else {
            return transitionScore
        }
    }
}

// MARK: - Full Workout Analysis Result

struct HIITAnalysisResult: Identifiable {
    let id: UUID
    let session: WorkoutSession
    let sectionResults: [SectionAnalysis]

    var hasAnyData: Bool { sectionResults.contains(where: \.hasData) }

    // Average interval score across sections that have HR data
    var overallScore: Double {
        let scored = sectionResults.filter(\.hasData)
        guard !scored.isEmpty else { return 0 }
        return scored.map(\.intervalScore).reduce(0, +) / Double(scored.count)
    }

    var overallScoreString: String { String(format: "%.0f%%", overallScore * 100) }

    // MARK: Component Averages

    var avgZoneMatchScore: Double {
        let s = sectionResults.filter(\.hasData)
        guard !s.isEmpty else { return 0 }
        return s.map(\.zoneMatchScore).reduce(0, +) / Double(s.count)
    }

    var avgTransitionScore: Double {
        let s = sectionResults.filter(\.hasData)
        guard !s.isEmpty else { return 0 }
        return s.map(\.transitionScore).reduce(0, +) / Double(s.count)
    }

    // MARK: Points System
    //
    // Per section with HR data: intervalScore × 10 (max 10 pts; 70% zone + 30% transition)

    var totalPoints: Int {
        sectionResults
            .filter(\.hasData)
            .reduce(0) { $0 + Int($1.intervalScore * 10) }
    }

    var maxPossiblePoints: Int {
        let n = sectionResults.filter(\.hasData).count
        guard n > 0 else { return 1 }
        return n * 10
    }

    var grade: String {
        guard maxPossiblePoints > 0 else { return "—" }
        let ratio = Double(totalPoints) / Double(maxPossiblePoints)
        switch ratio {
        case 0.85...: return "S"
        case 0.70..<0.85: return "A"
        case 0.55..<0.70: return "B"
        case 0.40..<0.55: return "C"
        default: return "D"
        }
    }

    // MARK: Phase Summaries

    func phaseAvgScore(for phase: WorkoutPhase) -> Double {
        let relevant = sectionResults.filter { $0.hasData && $0.section.phase == phase }
        guard !relevant.isEmpty else { return 0 }
        return relevant.map(\.intervalScore).reduce(0, +) / Double(relevant.count)
    }

    private var presentPhases: [WorkoutPhase] {
        Array(Set(sectionResults.filter(\.hasData).map(\.section.phase)))
    }

    var bestPhase: (phase: WorkoutPhase, compliance: Double)? {
        presentPhases.map { ($0, phaseAvgScore(for: $0)) }.max(by: { $0.1 < $1.1 })
    }

    var worstPhase: (phase: WorkoutPhase, compliance: Double)? {
        guard presentPhases.count > 1 else { return nil }
        let worst = presentPhases.map { ($0, phaseAvgScore(for: $0)) }.min(by: { $0.1 < $1.1 })
        guard let w = worst, let b = bestPhase, w.0 != b.phase else { return nil }
        return w
    }
}

// MARK: - Analysis Service

struct HIITAnalysisService {

    func analyze(session: WorkoutSession, using manager: HealthKitManager) async throws -> HIITAnalysisResult {
        // Fetch HR data for every section upfront so we can compute transitions
        var allSamples: [[(date: Date, bpm: Double)]] = []
        for section in session.sections {
            let samples = try await manager.fetchHeartRateInWindow(
                from: section.startTimestamp,
                to: section.endTimestamp
            )
            allSamples.append(samples)
        }

        var sectionResults: [SectionAnalysis] = []
        for (i, section) in session.sections.enumerated() {
            let currSamples = allSamples[i]
            let transition: Double

            if i == 0 {
                transition = 1.0  // First section — no prior phase to transition from
            } else {
                let prevSamples = allSamples[i - 1]
                let direction = expectedTransition(
                    from: session.sections[i - 1].phase,
                    to: section.phase
                )
                transition = computeTransitionScore(
                    prevSamples: prevSamples,
                    currSamples: currSamples,
                    direction: direction
                )
            }

            sectionResults.append(SectionAnalysis(
                id: UUID(),
                section: section,
                heartRateSamples: currSamples,
                transitionScore: transition
            ))
        }

        return HIITAnalysisResult(id: UUID(), session: session, sectionResults: sectionResults)
    }

    // Scores whether HR moved in the expected direction at a section boundary.
    // Compares the last 5 samples of the previous section against the first 5 of the next.
    // A 15 bpm change in the correct direction earns full credit.
    private func computeTransitionScore(
        prevSamples: [(date: Date, bpm: Double)],
        currSamples: [(date: Date, bpm: Double)],
        direction: TransitionDirection
    ) -> Double {
        guard direction != .neutral else { return 1.0 }
        guard !prevSamples.isEmpty, !currSamples.isEmpty else { return 1.0 }

        let window = 5
        let prevCount = min(window, prevSamples.count)
        let currCount = min(window, currSamples.count)
        let prevEnd   = prevSamples.suffix(prevCount).map(\.bpm).reduce(0, +) / Double(prevCount)
        let currStart = currSamples.prefix(currCount).map(\.bpm).reduce(0, +) / Double(currCount)
        let delta = currStart - prevEnd
        let threshold = 15.0

        switch direction {
        case .rising:  return min(max( delta / threshold, 0), 1.0)
        case .falling: return min(max(-delta / threshold, 0), 1.0)
        case .neutral: return 1.0
        }
    }
}

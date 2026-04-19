//
//  HIITAnalysis.swift
//  BearFitness
//

import Foundation

// BPM ranges that map to "passing" for each phase
private extension WorkoutPhase {
    var targetBPMClosedRange: ClosedRange<Double> {
        switch self {
        case .warmUp:        return 100...119
        case .highIntensity: return 140...170
        case .lowIntensity:  return 100...139
        case .coolDown:      return 100...119
        }
    }
}

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

    // Alias kept for backwards-compatible display code
    var compliancePercent: Double { zoneMatchScore }

    // How close actual duration was to planned (0–1, capped at 1)
    var durationMatchScore: Double { section.timeFraction }

    // Combined interval score: 50% zone + 30% duration + 20% transition
    // If HR data is unavailable, zone weight redistributes to the other two.
    var intervalScore: Double {
        if hasData {
            return 0.5 * zoneMatchScore + 0.3 * durationMatchScore + 0.2 * transitionScore
        } else {
            return 0.6 * durationMatchScore + 0.4 * transitionScore
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

    // MARK: Component Averages (used by breakdown bars)

    var avgZoneMatchScore: Double {
        let s = sectionResults.filter(\.hasData)
        guard !s.isEmpty else { return 0 }
        return s.map(\.zoneMatchScore).reduce(0, +) / Double(s.count)
    }

    var avgDurationMatchScore: Double {
        guard !sectionResults.isEmpty else { return 0 }
        return sectionResults.map(\.durationMatchScore).reduce(0, +) / Double(sectionResults.count)
    }

    var avgTransitionScore: Double {
        let s = sectionResults.filter(\.hasData)
        guard !s.isEmpty else { return 0 }
        return s.map(\.transitionScore).reduce(0, +) / Double(s.count)
    }

    // MARK: Points System
    //
    // Per section with HR data:
    //   intervalScore × 10  (max 10 pts, formula: 50% zone + 30% duration + 20% transition)
    //   +3 streak bonus per section when 3+ consecutive sections score ≥ 0.8
    // Global:
    //   +20 completion bonus if timeComplianceScore ≥ 0.95

    var totalPoints: Int {
        let withData = sectionResults.filter(\.hasData)
        guard !withData.isEmpty else { return 0 }

        var points = 0
        var streak = 0

        for sr in withData {
            let sectionPts = Int(sr.intervalScore * 10)
            points += sectionPts
            if sr.intervalScore >= 0.8 {
                streak += 1
                if streak >= 3 { points += 3 }
            } else {
                streak = 0
            }
        }

        if session.timeComplianceScore >= 0.95 { points += 20 }
        return points
    }

    var maxPossiblePoints: Int {
        let n = sectionResults.filter(\.hasData).count
        guard n > 0 else { return 1 }
        return n * 10 + max(0, n - 2) * 3 + 20
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

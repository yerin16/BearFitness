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

// MARK: - Section Analysis

struct SectionAnalysis: Identifiable {
    let id: UUID
    let section: SessionSection
    let heartRateSamples: [(date: Date, bpm: Double)]

    var hasData: Bool { !heartRateSamples.isEmpty }

    var avgBPM: Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        return heartRateSamples.map(\.bpm).reduce(0, +) / Double(heartRateSamples.count)
    }

    var actualZone: HeartRateZone {
        HeartRateZone.from(bpm: avgBPM)
    }

    var passed: Bool {
        guard !heartRateSamples.isEmpty else { return false }
        return section.phase.targetBPMClosedRange.contains(avgBPM)
    }

    // Avg BPM was within 15 bpm of the target range but didn't quite make it
    var isClose: Bool {
        guard hasData, !passed else { return false }
        let target = section.phase.targetBPMClosedRange
        let dist = max(target.lowerBound - avgBPM, avgBPM - target.upperBound, 0)
        return dist <= 15
    }

    // Fraction of individual samples that landed in the target zone
    var compliancePercent: Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        let target = section.phase.targetBPMClosedRange
        let inZone = heartRateSamples.filter { target.contains($0.bpm) }.count
        return Double(inZone) / Double(heartRateSamples.count)
    }
}

// MARK: - Full Workout Analysis Result

struct HIITAnalysisResult: Identifiable {
    let id: UUID
    let session: WorkoutSession
    let sectionResults: [SectionAnalysis]

    var hasAnyData: Bool {
        sectionResults.contains(where: \.hasData)
    }

    // Only counts sections where HR data was actually available
    var overallScore: Double {
        let withData = sectionResults.filter(\.hasData)
        guard !withData.isEmpty else { return 0 }
        let passed = withData.filter(\.passed).count
        return Double(passed) / Double(withData.count)
    }

    var overallScoreString: String {
        String(format: "%.0f%%", overallScore * 100)
    }

    // MARK: Points System
    //
    // Per section:
    //   +10  avg HR in target zone (pass)
    //   +5   avg HR within 15 bpm of zone (close)
    //   +3   streak bonus — applied per section when 3+ consecutive passes
    // Global:
    //   +20  all sections completed (timeComplianceScore >= 0.95)

    var totalPoints: Int {
        let withData = sectionResults.filter(\.hasData)
        guard !withData.isEmpty else { return 0 }

        var points = 0
        var streak = 0

        for sr in withData {
            if sr.passed {
                points += 10
                streak += 1
                if streak >= 3 { points += 3 }
            } else if sr.isClose {
                points += 5
                streak = 0
            } else {
                streak = 0
            }
        }

        if session.timeComplianceScore >= 0.95 {
            points += 20
        }

        return points
    }

    var maxPossiblePoints: Int {
        let n = sectionResults.filter(\.hasData).count
        guard n > 0 else { return 1 }
        let streakBonus = max(0, n - 2) * 3
        return n * 10 + streakBonus + 20
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

    func phaseAvgCompliance(for phase: WorkoutPhase) -> Double {
        let relevant = sectionResults.filter { $0.hasData && $0.section.phase == phase }
        guard !relevant.isEmpty else { return 0 }
        return relevant.map(\.compliancePercent).reduce(0, +) / Double(relevant.count)
    }

    // All phase types that actually have HR data
    private var presentPhases: [WorkoutPhase] {
        Array(Set(sectionResults.filter(\.hasData).map(\.section.phase)))
    }

    // Phase the user performed best in (highest avg sample compliance)
    var bestPhase: (phase: WorkoutPhase, compliance: Double)? {
        presentPhases
            .map { ($0, phaseAvgCompliance(for: $0)) }
            .max(by: { $0.1 < $1.1 })
    }

    // Phase the user struggled most with (only shown if different from best)
    var worstPhase: (phase: WorkoutPhase, compliance: Double)? {
        guard presentPhases.count > 1 else { return nil }
        let worst = presentPhases
            .map { ($0, phaseAvgCompliance(for: $0)) }
            .min(by: { $0.1 < $1.1 })
        guard let w = worst, let b = bestPhase, w.0 != b.phase else { return nil }
        return w
    }
}

// MARK: - Analysis Service

struct HIITAnalysisService {
    func analyze(session: WorkoutSession, using manager: HealthKitManager) async throws -> HIITAnalysisResult {
        var sectionResults: [SectionAnalysis] = []

        for section in session.sections {
            let samples = try await manager.fetchHeartRateInWindow(
                from: section.startTimestamp,
                to: section.endTimestamp
            )
            sectionResults.append(SectionAnalysis(
                id: UUID(),
                section: section,
                heartRateSamples: samples
            ))
        }

        return HIITAnalysisResult(
            id: UUID(),
            session: session,
            sectionResults: sectionResults
        )
    }
}

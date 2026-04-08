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

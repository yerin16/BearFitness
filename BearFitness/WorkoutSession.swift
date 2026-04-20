//
//  WorkoutSession.swift
//  BearFitness
//
//  Created by Yerin Kang on 4/2/26.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class WorkoutSession: Identifiable {
    var id: UUID
    var programName: String
    var workoutType: String
    var startedAt: Date
    var endedAt: Date
    var totalDurationSeconds: Int
    var sections: [SessionSection]

    init(
        programName: String,
        workoutType: String,
        startedAt: Date,
        endedAt: Date,
        totalDurationSeconds: Int,
        sections: [SessionSection]
    ) {
        self.id = UUID()
        self.programName = programName
        self.workoutType = workoutType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalDurationSeconds = totalDurationSeconds
        self.sections = sections
    }

    var formattedDuration: String {
        let h = totalDurationSeconds / 3600
        let m = (totalDurationSeconds % 3600) / 60
        let s = totalDurationSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var formattedDate: String {
        startedAt.formatted(.dateTime.month(.wide).day().year().hour().minute())
    }

}

// MARK: - Session Section

struct SessionSection: Codable, Identifiable {
    var id: UUID = UUID()
    var phase: WorkoutPhase
    var plannedDurationSeconds: Int
    var actualDurationSeconds: Int
    var startTimestamp: Date
    var endTimestamp: Date
    var roundNumber: Int
    var intervalNumber: Int

    var formattedActualDuration: String {
        let m = actualDurationSeconds / 60
        let s = actualDurationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // Fraction of planned time completed, capped at 1
    var timeFraction: Double {
        guard plannedDurationSeconds > 0 else { return 1.0 }
        return min(Double(actualDurationSeconds) / Double(plannedDurationSeconds), 1.0)
    }
}

// MARK: - Workout Phase

enum WorkoutPhase: String, Codable, CaseIterable {
    case warmUp = "WARM UP"
    case highIntensity = "HIGH INTENSITY"
    case lowIntensity = "LOW INTENSITY"
    case coolDown = "COOL DOWN"

    /// Zones used to define target BPM for this phase (see `HeartRateZone.bpmBounds`).
    var targetHeartRateZones: [HeartRateZone] {
        switch self {
        case .warmUp, .coolDown:
            return [.zone1, .zone2]
        case .lowIntensity:
            return [.zone2, .zone3]
        case .highIntensity:
            return [.zone4, .zone5]
        }
    }

    /// BPM range for scoring, overlays, and "in target" checks — derived from zone bounds.
    var targetBPMClosedRange: ClosedRange<Double> {
        HeartRateZone.mergedBPMRange(targetHeartRateZones)
    }

    private var targetZoneLabel: String {
        let zones = targetHeartRateZones
        guard let lo = zones.map(\.zoneNumber).min(),
              let hi = zones.map(\.zoneNumber).max() else { return "" }
        if lo == hi { return "Zone \(lo)" }
        return "Zone \(lo)–\(hi)"
    }

    var targetHRZone: String {
        "\(targetZoneLabel) · \(targetBPMRange)"
    }

    var targetBPMRange: String {
        let r = targetBPMClosedRange
        return "\(Int(r.lowerBound))-\(Int(r.upperBound)) bpm"
    }

    var color: Color {
        switch self {
        case .warmUp:        return Color(red: 1.0, green: 0.67, blue: 0.08)
        case .highIntensity: return Color(red: 1.0, green: 0.38, blue: 0.47)
        case .lowIntensity:  return Color(red: 0.0, green: 0.78, blue: 0.50)
        case .coolDown:      return Color(red: 0.20, green: 0.56, blue: 0.98)
        }
    }

    // Abbreviated label for chart annotations
    var shortLabel: String {
        switch self {
        case .warmUp:        return "WU"
        case .highIntensity: return "HI"
        case .lowIntensity:  return "LI"
        case .coolDown:      return "CD"
        }
    }

    var targetBPMLow: Double { targetBPMClosedRange.lowerBound }
    var targetBPMHigh: Double { targetBPMClosedRange.upperBound }
}

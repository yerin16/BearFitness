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
    var timeComplianceScore: Double  // 0–1, avg(actual/planned) across all sections

    init(
        programName: String,
        workoutType: String,
        startedAt: Date,
        endedAt: Date,
        totalDurationSeconds: Int,
        sections: [SessionSection],
        timeComplianceScore: Double = 1.0
    ) {
        self.id = UUID()
        self.programName = programName
        self.workoutType = workoutType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalDurationSeconds = totalDurationSeconds
        self.sections = sections
        self.timeComplianceScore = timeComplianceScore
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

    // Letter grade based purely on time compliance (no HealthKit needed)
    var timeGrade: String {
        switch timeComplianceScore {
        case 0.95...: return "S"
        case 0.85..<0.95: return "A"
        case 0.70..<0.85: return "B"
        case 0.50..<0.70: return "C"
        default: return "D"
        }
    }

    var timeGradeColor: Color {
        switch timeGrade {
        case "S": return Color(red: 0.55, green: 0.20, blue: 0.98)
        case "A": return .green
        case "B": return Color(red: 0.00, green: 0.72, blue: 0.90)
        case "C": return .orange
        default:  return .red
        }
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

    var targetHRZone: String {
        switch self {
        case .warmUp:        return "Zone 1-2 · 100-119 bpm"
        case .highIntensity: return "Zone 4-5 · 140-170 bpm"
        case .lowIntensity:  return "Zone 2-3 · 100-139 bpm"
        case .coolDown:      return "Zone 1-2 · 100-119 bpm"
        }
    }

    var targetBPMRange: String {
        switch self {
        case .warmUp:        return "100-119 bpm"
        case .highIntensity: return "140-170 bpm"
        case .lowIntensity:  return "100-139 bpm"
        case .coolDown:      return "100-119 bpm"
        }
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

    // Numeric BPM bounds for chart overlay
    var targetBPMLow:  Double { switch self { case .highIntensity: return 140; default: return 100 } }
    var targetBPMHigh: Double { switch self { case .highIntensity: return 170; case .lowIntensity: return 139; default: return 119 } }
}

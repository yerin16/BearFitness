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

// MARK: - Session Section (each phase of the workout)
struct SessionSection: Codable, Identifiable {
    var id: UUID = UUID()
    var phase: WorkoutPhase
    var plannedDurationSeconds: Int
    var actualDurationSeconds: Int
    var startTimestamp: Date
    var endTimestamp: Date
    var roundNumber: Int       // which cycle this belongs to
    var intervalNumber: Int    // which interval within the cycle

    var formattedActualDuration: String {
        let m = actualDurationSeconds / 60
        let s = actualDurationSeconds % 60
        return String(format: "%d:%02d", m, s)
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
}

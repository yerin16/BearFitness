//
//  HIITProgram.swift
//  BearFitness
//
//  Created by Yerin Kang on 4/2/26.
//

import Foundation
import SwiftData
import HealthKit

@Model
final class HIITProgram: Identifiable {
    var id: UUID
    var name: String
    var workoutType: String          // stored as string, mapped to HKWorkoutActivityType
    var warmUpSeconds: Int
    var highIntensitySeconds: Int
    var lowIntensitySeconds: Int
    var intervalSets: Int            // number of sets per cycle
    var repeatEnabled: Bool
    var numberOfCycles: Int
    var coolDownSeconds: Int
    var createdAt: Date

    init(
        name: String = "",
        workoutType: String = "Running",
        warmUpSeconds: Int = 0,
        highIntensitySeconds: Int = 0,
        lowIntensitySeconds: Int = 0,
        intervalSets: Int = 1,
        repeatEnabled: Bool = false,
        numberOfCycles: Int = 1,
        coolDownSeconds: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.workoutType = workoutType
        self.warmUpSeconds = warmUpSeconds
        self.highIntensitySeconds = highIntensitySeconds
        self.lowIntensitySeconds = lowIntensitySeconds
        self.intervalSets = intervalSets
        self.repeatEnabled = repeatEnabled
        self.numberOfCycles = numberOfCycles
        self.coolDownSeconds = coolDownSeconds
        self.createdAt = Date()
    }

    var totalDurationSeconds: Int {
        let intervalBlock = (highIntensitySeconds + lowIntensitySeconds) * intervalSets
        let cycles = repeatEnabled ? numberOfCycles : 1
        return warmUpSeconds + (intervalBlock * cycles) + coolDownSeconds
    }

    var formattedDuration: String {
        let total = totalDurationSeconds
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    static let workoutTypes = [
        "Running", "Walking", "Cycling", "Swimming",
        "Rowing", "Elliptical", "Jump Rope", "Stair Climbing", "Mixed Cardio"
    ]

    var sfSymbol: String {
        switch workoutType {
        case "Running":         return "figure.run"
        case "Walking":         return "figure.walk"
        case "Cycling":         return "figure.outdoor.cycle"
        case "Swimming":        return "figure.pool.swim"
        case "Rowing":          return "figure.rower"
        case "Elliptical":      return "figure.elliptical"
        case "Jump Rope":       return "figure.jumprope"
        case "Stair Climbing":  return "figure.stair.stepper"
        case "Mixed Cardio":    return "figure.mixed.cardio"
        default:                return "figure.mixed.cardio"
        }
    }
}

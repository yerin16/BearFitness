//
//  WorkoutStats.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import Foundation

struct WorkoutStats {
    var activeCalories: Double?
    var totalCalories: Double?
    var distanceKm: Double?
    var avgPacePerKm: String?
    var avgSpeedKph: Double?
    var elevationGain: Double?
    var steps: Double?
    var swimmingStrokes: Double?

    static let empty = WorkoutStats()
}

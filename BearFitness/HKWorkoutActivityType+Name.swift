//
//  HKWorkoutActivityType+Name.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import HealthKit

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        // Cardio
        case .running:                       return "Running"
        case .cycling:                       return "Cycling"
        case .swimming:                      return "Swimming"
        case .walking:                       return "Walking"
        case .hiking:                        return "Hiking"
        case .rowing:                        return "Rowing"
        case .elliptical:                    return "Elliptical"
        case .stairClimbing:                 return "Stair Climbing"
        case .jumpRope:                      return "Jump Rope"
        case .mixedCardio:                   return "Mixed Cardio"
        case .dance:                         return "Dance"
        case .skatingSports:                 return "Skating"
        case .crossCountrySkiing:            return "Cross Country Skiing"
        case .downhillSkiing:                return "Downhill Skiing"
        case .snowboarding:                  return "Snowboarding"
        case .surfingSports:                 return "Surfing"
        case .paddleSports:                  return "Paddling"

        // Training
        case .highIntensityIntervalTraining: return "HIIT"
        case .functionalStrengthTraining:    return "Strength Training"
        case .traditionalStrengthTraining:   return "Weight Training"
        case .coreTraining:                  return "Core Training"
        case .crossTraining:                 return "Cross Training"
        case .flexibility:                   return "Flexibility"
        case .yoga:                          return "Yoga"
        case .pilates:                       return "Pilates"
        case .cooldown:                      return "Cooldown"

        // Sports
        case .basketball:                    return "Basketball"
        case .soccer:                        return "Soccer"
        case .tennis:                        return "Tennis"
        case .volleyball:                    return "Volleyball"
        case .badminton:                     return "Badminton"
        case .baseball:                      return "Baseball"
        case .golf:                          return "Golf"
        case .tableTennis:                   return "Table Tennis"
        case .rugby:                         return "Rugby"
        case .hockey:                        return "Hockey"
        case .boxing:                        return "Boxing"
        case .kickboxing:                    return "Kickboxing"
        case .wrestling:                     return "Wrestling"
        case .martialArts:                   return "Martial Arts"
        case .climbing:                      return "Climbing"

        // Mind & Body
        case .mindAndBody:                   return "Mind & Body"
        case .taiChi:                        return "Tai Chi"

        // Water
        case .waterFitness:                  return "Water Fitness"
        case .waterPolo:                     return "Water Polo"

        // Other
        case .fitnessGaming:                 return "Fitness Gaming"
        case .wheelchairRunPace:             return "Wheelchair Run"
        case .wheelchairWalkPace:            return "Wheelchair Walk"
        case .other:                         return "Other"
        default:                             return "Workout"
        }
    }
}

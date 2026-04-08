//
//  HealthKitManager.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import HealthKit
import Combine
import CoreLocation

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()

    // MARK: - Authorization
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .swimmingStrokeCount)!,
            HKObjectType.quantityType(forIdentifier: .flightsClimbed)!,
            HKSeriesType.workoutRoute()
        ]

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }

    // MARK: - Fetch Workouts
    func fetchWorkouts() async throws -> [HKWorkout] {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: nil,
                limit: 20,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Fetch Heart Rate for a Workout
    func fetchHeartRate(for workout: HKWorkout) async throws -> [(date: Date, bpm: Double)] {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }

        let timePredicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: timePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let hrSamples = (samples as? [HKQuantitySample]) ?? []
                let parsed = hrSamples.map { sample in
                    (
                        date: sample.startDate,
                        bpm: sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    )
                }
                continuation.resume(returning: parsed)
            }
            self.healthStore.execute(query)
        }
    }
    
    // MARK: - Fetch Route for a Workout
    func fetchRoute(for workout: HKWorkout) async throws -> [CLLocationCoordinate2D] {
        let routeType = HKSeriesType.workoutRoute()
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)

        let routeSamples: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: workoutPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            healthStore.execute(query)
        }

        guard let route = routeSamples.first else { return [] }

        var allCoordinates: [CLLocationCoordinate2D] = []

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didFinish = false
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error {
                    if !didFinish {
                        didFinish = true
                        continuation.resume(throwing: error)
                    }
                    return
                }
                if let locations {
                    allCoordinates.append(contentsOf: locations.map(\.coordinate))
                }
                if done && !didFinish {
                    didFinish = true
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }

        return allCoordinates
    }
    
    // MARK: - Fetch Heart Rate in a Time Window
    func fetchHeartRateInWindow(from start: Date, to end: Date) async throws -> [(date: Date, bpm: Double)] {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }

        let timePredicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: timePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let hrSamples = (samples as? [HKQuantitySample]) ?? []
                let parsed = hrSamples.map { sample in
                    (
                        date: sample.startDate,
                        bpm: sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    )
                }
                continuation.resume(returning: parsed)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Fetch Workout Stats
    func fetchWorkoutStats(for workout: HKWorkout) async throws -> WorkoutStats {
        var stats = WorkoutStats()

        stats.activeCalories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie())

        let basal = workout.statistics(for: HKQuantityType(.basalEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        if let active = stats.activeCalories {
            stats.totalCalories = active + basal
        }

        // Pick the right distance type based on activity
        let distanceType: HKQuantityTypeIdentifier
        switch workout.workoutActivityType {
        case .cycling: distanceType = .distanceCycling
        case .swimming: distanceType = .distanceSwimming
        default: distanceType = .distanceWalkingRunning
        }

        if let distanceMeters = workout.statistics(for: HKQuantityType(distanceType))?
            .sumQuantity()?.doubleValue(for: .meter()) {
            stats.distanceKm = distanceMeters / 1000

            if workout.workoutActivityType == .running || workout.workoutActivityType == .walking {
                let paceSecsPerKm = workout.duration / stats.distanceKm!
                let mins = Int(paceSecsPerKm) / 60
                let secs = Int(paceSecsPerKm) % 60
                stats.avgPacePerKm = String(format: "%d:%02d /km", mins, secs)
            }

            if workout.workoutActivityType == .cycling {
                stats.avgSpeedKph = stats.distanceKm! / (workout.duration / 3600)
            }
        }

        stats.steps = workout.statistics(for: HKQuantityType(.stepCount))?
            .sumQuantity()?.doubleValue(for: .count())

        stats.swimmingStrokes = workout.statistics(for: HKQuantityType(.swimmingStrokeCount))?
            .sumQuantity()?.doubleValue(for: .count())

        if let elevationMeters = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity {
            stats.elevationGain = elevationMeters.doubleValue(for: .meter())
        }

        return stats
    }
    
    // MARK: - Error
    enum HealthKitError: Error {
        case notAvailable
    }
}

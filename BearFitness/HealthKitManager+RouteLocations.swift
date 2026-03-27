//
//  HealthKitManager+RouteLocations.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import HealthKit
import CoreLocation

extension HealthKitManager {

    /// Fetch route as full CLLocation objects (includes timestamp for HR matching)
    func fetchRouteLocations(for workout: HKWorkout) async throws -> [CLLocation] {
        let routeType = HKSeriesType.workoutRoute()
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)

        // Step 1: find the route sample attached to this workout
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

        // Step 2: stream full CLLocation objects from the route
        var allLocations: [CLLocation] = []

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
                    allLocations.append(contentsOf: locations)
                }
                if done && !didFinish {
                    didFinish = true
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }

        return allLocations
    }
}

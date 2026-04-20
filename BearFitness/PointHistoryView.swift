//
//  PointHistoryView.swift
//  BearFitness
//
//  Created by christine j on 4/10/26.
//

import SwiftUI
import SwiftData
import HealthKit

struct PointHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = HealthKitManager()

    @Query(sort: \WorkoutAnalysisRecord.analyzedAt, order: .reverse)
    private var records: [WorkoutAnalysisRecord]

    @State private var workoutsByUUID: [String: HKWorkout] = [:]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {

                    if records.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.gray2)
                            Text("No points yet")
                                .font(.headline)
                                .foregroundStyle(Color.appDarkText)
                            Text("Apply a HIIT program to one of your Apple Fitness workouts to earn points.")
                                .font(.dateCaptionSmall)
                                .foregroundStyle(Color.gray1)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(records) { record in
                                PointHistoryRow(
                                    record: record,
                                    workout: workoutsByUUID[record.workoutUUID]
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Point History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadWorkouts()
        }
    }

    @MainActor
    private func loadWorkouts() async {
        do {
            try await manager.requestAuthorization()
            let workouts = try await manager.fetchWorkouts()
            var map: [String: HKWorkout] = [:]
            for w in workouts {
                map[w.uuid.uuidString] = w
            }
            workoutsByUUID = map
        } catch {
            print("PointHistoryView: failed to load workouts — \(error)")
        }
    }
}

// MARK: - Point History Row

struct PointHistoryRow: View {
    let record: WorkoutAnalysisRecord
    let workout: HKWorkout?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: workout?.workoutActivityType.sfSymbol ?? "figure.run")
                .font(.system(size: 28))
                .foregroundStyle(LinearGradient.purpleBlue)
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout?.workoutActivityType.name ?? record.matchedSessionName)
                    .font(.workoutTypeSmall)
                    .gradientForeground()

                Text(formatDuration(workout?.duration ?? 0))
                    .font(.durationSmall)
                    .foregroundStyle(Color.appDarkText)

                HStack(spacing: 12) {
                    if let cal = workout?.statistics(for: HKQuantityType(.activeEnergyBurned))?
                        .sumQuantity()?.doubleValue(for: .kilocalorie()) {
                        Label(String(format: "%.0f kcal", cal), systemImage: "flame.fill")
                    }
                    if let dist = workout?.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                        .sumQuantity()?.doubleValue(for: .meter()) {
                        let mi = dist / 1609.34
                        Label(String(format: "%.1f mi", mi), systemImage: "map.fill")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Color.gray1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 20) {
                HStack(spacing: 3) {
                    Text("+\(record.totalPoints)")
                        .font(.pointsBadge)
                        .gradientForeground()
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.gradientPurple)
                }

                Text((workout?.startDate ?? record.analyzedAt)
                    .formatted(date: .numeric, time: .omitted))
                    .font(.dateCaption)
                    .foregroundStyle(Color.appDarkText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 15)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .cardShadow()
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

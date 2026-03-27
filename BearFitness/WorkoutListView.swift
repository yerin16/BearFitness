//
//  WorkoutListView.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import SwiftUI
import HealthKit

struct WorkoutListView: View {
    @StateObject private var manager = HealthKitManager()
    @State private var workouts: [HKWorkout] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading workouts...")
                        .foregroundStyle(Color.gray1)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(Color.gray2)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Button("Retry") {
                            Task { await loadData() }
                        }
                        .font(.bannerText)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(LinearGradient.blueLinear)
                        .clipShape(Capsule())
                    }
                } else if workouts.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.gray2)
                        Text("No workouts found")
                            .font(.headline)
                            .foregroundStyle(Color.darkText)
                        Text("Complete a workout with Apple Fitness\nand it will appear here.")
                            .font(.dateCaptionSmall)
                            .foregroundStyle(Color.gray1)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(workouts, id: \.uuid) { workout in
                                NavigationLink {
                                    WorkoutDetailScreen(
                                        workout: workout,
                                        manager: manager
                                    )
                                } label: {
                                    WorkoutCard(
                                        workout: workout,
                                        showPoints: hasPoints(workout)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("My Apple Fitness Workout")
                        .font(.workoutTitle)
                        .foregroundStyle(Color.darkText)
                }
            }
        }
        .task {
            await loadData()
        }
    }

    func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            try await manager.requestAuthorization()
            workouts = try await manager.fetchWorkouts()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func hasPoints(_ workout: HKWorkout) -> Bool {
        // TODO: Replace with real logic — check if the workout
        // was paired with a HIIT program
        guard let index = workouts.firstIndex(where: {
            $0.uuid == workout.uuid
        }) else { return false }
        return index < 2  // demo: first 2 workouts show points
    }
}

// MARK: - Workout Card
// Matches Figma "Pill / Exercise Details" component

struct WorkoutCard: View {
    let workout: HKWorkout
    var showPoints: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            // Workout type icon
            workoutIcon
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.workoutActivityType.name)
                    .font(.workoutTypeSmall)
                    .gradientForeground()

                Text(formatDuration(workout.duration))
                    .font(.durationSmall)
                    .foregroundStyle(Color.darkText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if showPoints {
                    HStack(spacing: 3) {
                        Text("+20")
                            .font(.pointsBadge)
                            .gradientForeground()
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.gradientPurple)
                    }
                }
                Text(workout.startDate.formatted(
                    date: .numeric, time: .omitted
                ))
                .font(.dateCaption)
                .foregroundStyle(Color.darkText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 15)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .cardShadow()
    }

    @ViewBuilder
    var workoutIcon: some View {
        let iconName: String = {
            switch workout.workoutActivityType {
            case .running:   return "figure.run"
            case .cycling:   return "figure.outdoor.cycle"
            case .swimming:  return "figure.pool.swim"
            case .walking:   return "figure.walk"
            case .yoga:      return "figure.yoga"
            case .functionalStrengthTraining:
                return "figure.strengthtraining.traditional"
            case .highIntensityIntervalTraining:
                return "figure.highintensity.intervaltraining"
            default:         return "figure.mixed.cardio"
            }
        }()

        Image(systemName: iconName)
            .font(.system(size: 28))
            .foregroundStyle(LinearGradient.purpleBlue)
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

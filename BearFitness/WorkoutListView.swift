//
//  WorkoutListView.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import SwiftUI
import HealthKit

// MARK: - Workout Filter
enum WorkoutFilter: Hashable {
    case all
    case type(HKWorkoutActivityType)

    var label: String {
        switch self {
        case .all: return "All"
        case .type(let t): return t.name
        }
    }

    var icon: String {
        switch self {
        case .all: return "flame.fill"
        case .type(let t): return t.sfSymbol
        }
    }
}

// MARK: - Date Group
struct WorkoutDateGroup: Identifiable {
    let id: String
    let title: String
    let workouts: [HKWorkout]
}

// MARK: - WorkoutListView
struct WorkoutListView: View {
    @StateObject private var manager = HealthKitManager()
    @State private var workouts: [HKWorkout] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var selectedFilter: WorkoutFilter = .all

    /// Unique workout types present in the data
    var availableFilters: [WorkoutFilter] {
        let types = Set(workouts.map(\.workoutActivityType))
        let sorted = types.sorted { $0.name < $1.name }
        return [.all] + sorted.map { .type($0) }
    }

    /// Workouts after applying the selected filter
    var filteredWorkouts: [HKWorkout] {
        switch selectedFilter {
        case .all:
            return workouts
        case .type(let t):
            return workouts.filter { $0.workoutActivityType == t }
        }
    }

    /// Group filtered workouts by relative date
    var groupedWorkouts: [WorkoutDateGroup] {
        let calendar = Calendar.current
        let now = Date()
        var groups: [String: [HKWorkout]] = [:]
        var order: [String] = []

        for workout in filteredWorkouts {
            let label: String
            if calendar.isDateInToday(workout.startDate) {
                label = "Today"
            } else if calendar.isDateInYesterday(workout.startDate) {
                label = "Yesterday"
            } else if let daysAgo = calendar.dateComponents([.day], from: workout.startDate, to: now).day,
                      daysAgo < 7 {
                label = "This Week"
            } else if let daysAgo = calendar.dateComponents([.day], from: workout.startDate, to: now).day,
                      daysAgo < 30 {
                label = "This Month"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                label = formatter.string(from: workout.startDate)
            }

            if groups[label] == nil {
                order.append(label)
            }
            groups[label, default: []].append(workout)
        }

        return order.map { title in
            WorkoutDateGroup(id: title, title: title, workouts: groups[title] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                if isLoading && workouts.isEmpty {
                    ProgressView("Loading workouts...")
                        .foregroundStyle(Color.gray1)
                } else if let error = errorMessage, workouts.isEmpty {
                    errorView(error)
                } else if workouts.isEmpty {
                    emptyView
                } else {
                    workoutList
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Workout List
    var workoutList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Title
                Text("My Apple Fitness Workout")
                    .font(.workoutTitle)
                    .foregroundStyle(Color.darkText)
                    .padding(.bottom, 0)

                // Filter pills
                filterBar

                // Grouped sections
                ForEach(groupedWorkouts) { group in
                    Text(group.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.gray1)
                        .padding(.top, 8)

                    ForEach(group.workouts, id: \.uuid) { workout in
                        NavigationLink {
                            WorkoutDetailScreen(workout: workout, manager: manager)
                        } label: {
                            WorkoutCard(workout: workout, showPoints: hasPoints(workout))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Filter count
                if filteredWorkouts.count != workouts.count {
                    Text("Showing \(filteredWorkouts.count) of \(workouts.count) workouts")
                        .font(.caption)
                        .foregroundStyle(Color.gray2)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Filter Bar
    var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableFilters, id: \.self) { filter in
                    FilterPill(
                        label: filter.label,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Empty & Error States
    var emptyView: some View {
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
    }

    func errorView(_ error: String) -> some View {
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
    }

    // MARK: - Data
    func loadData() async {
        if workouts.isEmpty { isLoading = true }
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
        guard let index = workouts.firstIndex(where: { $0.uuid == workout.uuid }) else { return false }
        return index < 2
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                ? AnyShapeStyle(LinearGradient.purpleBlue)
                : AnyShapeStyle(Color.lightGray)
            )
            .foregroundStyle(isSelected ? .white : Color.gray1)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workout Card (with subtitle stats)
struct WorkoutCard: View {
    let workout: HKWorkout
    var showPoints: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            workoutIcon
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.workoutActivityType.name)
                    .font(.workoutTypeSmall)
                    .gradientForeground()

                Text(formatDuration(workout.duration))
                    .font(.durationSmall)
                    .foregroundStyle(Color.darkText)

                // Quick stats subtitle
                HStack(spacing: 12) {
                    if let cal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                        Label(String(format: "%.0f kcal", cal), systemImage: "flame.fill")
                    }
                    if let dist = workout.totalDistance?.doubleValue(for: .meter()) {
                        let mi = dist / 1609.34
                        Label(String(format: "%.1f mi", mi), systemImage: "map.fill")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(Color.gray1)
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

                Text(workout.startDate.formatted(date: .numeric, time: .omitted))
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
        Image(systemName: workout.workoutActivityType.sfSymbol)
            .font(.system(size: 28))
            .foregroundStyle(LinearGradient.purpleBlue)
            .frame(width: 50, height: 50)
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - SF Symbol for workout types
extension HKWorkoutActivityType {
    var sfSymbol: String {
        switch self {
        case .running:                       return "figure.run"
        case .cycling:                       return "figure.outdoor.cycle"
        case .swimming:                      return "figure.pool.swim"
        case .walking:                       return "figure.walk"
        case .yoga:                          return "figure.yoga"
        case .functionalStrengthTraining:    return "figure.strengthtraining.traditional"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        case .rowing:                        return "figure.rower"
        case .elliptical:                    return "figure.elliptical"
        case .basketball:                    return "figure.basketball"
        case .soccer:                        return "figure.soccer"
        case .tennis:                        return "figure.tennis"
        default:                             return "figure.mixed.cardio"
        }
    }
}

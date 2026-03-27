//
//  WorkoutDetailScreen.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import SwiftUI
import HealthKit
import MapKit
import Charts

struct WorkoutDetailScreen: View {
    let workout: HKWorkout
    let manager: HealthKitManager

    @State private var heartRates: [(date: Date, bpm: Double)] = []
    @State private var isLoadingHR = true
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var isLoadingRoute = true
    @State private var workoutStats: WorkoutStats = .empty
    @State private var isLoadingStats = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                statsGrid
                heartRateSection
                applyProgramBanner
                heartRateChart
                mapSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.darkText)
                        .frame(width: 32, height: 32)
                        .background(Color.lightGray)
                        .clipShape(Circle())
                }
            }
        }
        .task {
            async let hr = manager.fetchHeartRate(for: workout)
            async let route = manager.fetchRoute(for: workout)
            async let stats = manager.fetchWorkoutStats(for: workout)

            heartRates = (try? await hr) ?? []
            isLoadingHR = false
            routeCoordinates = (try? await route) ?? []
            isLoadingRoute = false
            workoutStats = (try? await stats) ?? .empty
            isLoadingStats = false
        }
    }

    // MARK: - Header
    var headerSection: some View {
        HStack(spacing: 14) {
            Image(systemName: workoutIconName)
                .font(.system(size: 32))
                .foregroundStyle(LinearGradient.purpleBlue)
                .frame(width: 55, height: 55)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.workoutActivityType.name)
                    .font(.workoutTypeLarge)
                    .gradientForeground()
                Text(workout.startDate.formatted(
                    .dateTime.month(.wide).day().year().hour().minute()
                ))
                .font(.dateCaptionSmall)
                .foregroundStyle(Color.darkText)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 2×2 Stats Grid
    var statsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatCard(label: "Workout Time",
                     value: formatDuration(workout.duration))
            StatCard(label: "Distance",
                     value: distanceString)
            StatCard(label: "Active Kilocalories",
                     value: caloriesString)
            StatCard(label: "Avg. Heart Rate",
                     value: avgHRString)
        }
    }

    // MARK: - Heart Rate Title
    var heartRateSection: some View {
        Text("Heart Rate")
            .font(.sectionHeader)
            .foregroundStyle(Color.darkText)
    }

    // MARK: - Apply Program Banner
    var applyProgramBanner: some View {
        HStack {
            Text("Apply your HIIT program and earn points!")
                .font(.bannerText)
                .foregroundStyle(Color.appBlack)
            Spacer()
            Button {
                // TODO: Navigate to program selection
            } label: {
                Text("Apply")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(LinearGradient.blueLinear)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(LinearGradient.blueLinear.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Heart Rate Chart
    @ViewBuilder
    var heartRateChart: some View {
        if isLoadingHR {
            ProgressView("Loading heart rate data...")
                .frame(maxWidth: .infinity, minHeight: 200)
        } else if heartRates.isEmpty {
            Text("No heart rate data available.")
                .font(.dateCaptionSmall)
                .foregroundStyle(Color.gray2)
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            let minBPM = heartRates.map(\.bpm).min() ?? 0
            let maxBPM = heartRates.map(\.bpm).max() ?? 0

            Chart {
                ForEach(heartRates, id: \.date) { entry in
                    AreaMark(
                        x: .value("Time", entry.date),
                        yStart: .value("Min", minBPM - 10),
                        yEnd: .value("BPM", entry.bpm)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.gradientBlue.opacity(0.3),
                                Color.gradientBlue.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", entry.date),
                        y: .value("BPM", entry.bpm)
                    )
                    .foregroundStyle(LinearGradient.purpleBlue)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(
                    by: .minute, count: strideInterval
                )) { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.gray2.opacity(0.3))
                    AxisValueLabel(
                        format: .dateTime.hour().minute()
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(Color.gray1)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray2.opacity(0.3))
                    AxisValueLabel {
                        Text("\(value.as(Int.self) ?? 0)")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray1)
                    }
                }
            }
            .chartYScale(domain: (minBPM - 10)...(maxBPM + 10))
        }
    }

    // MARK: - Map
    @ViewBuilder
    var mapSection: some View {
        Text("Map")
            .font(.sectionHeader)
            .foregroundStyle(Color.darkText)

        if isLoadingRoute {
            ProgressView("Loading route...")
                .frame(maxWidth: .infinity, minHeight: 143)
        } else if routeCoordinates.isEmpty {
            Text("No route data available.")
                .font(.dateCaptionSmall)
                .foregroundStyle(Color.gray2)
                .frame(maxWidth: .infinity, minHeight: 143)
        } else {
            Map {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(.blue, lineWidth: 3)
                if let first = routeCoordinates.first {
                    Annotation("Start", coordinate: first) {
                        Circle().fill(.green)
                            .frame(width: 12, height: 12)
                    }
                }
                if let last = routeCoordinates.last {
                    Annotation("End", coordinate: last) {
                        Circle().fill(.red)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .frame(height: 143)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers
    var workoutIconName: String {
        switch workout.workoutActivityType {
        case .running:   return "figure.run"
        case .cycling:   return "figure.outdoor.cycle"
        case .swimming:  return "figure.pool.swim"
        case .walking:   return "figure.walk"
        case .yoga:      return "figure.yoga"
        default:         return "figure.mixed.cardio"
        }
    }

    var distanceString: String {
        if let km = workoutStats.distanceKm {
            return String(format: "%.2fmi", km * 0.621371)
        }
        return isLoadingStats ? "..." : "0.00mi"
    }

    var caloriesString: String {
        if let cal = workoutStats.activeCalories {
            return String(format: "%.0fcal", cal)
        }
        return isLoadingStats ? "..." : "0cal"
    }

    var avgHRString: String {
        if !heartRates.isEmpty {
            let avg = heartRates.map(\.bpm).reduce(0, +)
                / Double(heartRates.count)
            return String(format: "%.0fbpm", avg)
        }
        return isLoadingHR ? "..." : "0bpm"
    }

    var strideInterval: Int {
        let minutes = workout.duration / 60
        if minutes < 30 { return 5 }
        if minutes < 60 { return 10 }
        return 20
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.statLabel)
                .foregroundStyle(Color.darkText)
            Text(value)
                .font(.statValue)
                .foregroundStyle(Color.darkText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .cardShadow()
    }
}

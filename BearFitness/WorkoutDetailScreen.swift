//
//  WorkoutDetailScreen.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

//
//  WorkoutDetailScreen.swift
//  WorkoutTracker
//
//  Screen 2: Workout Detail
//  Performance: downsampled HR chart, binary search for route HR matching
//  UX: swipe-back from left edge, minimal x-axis labels
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
    @State private var routeLocations: [CLLocation] = []
    @State private var isLoadingRoute = true
    @Environment(\.dismiss) private var dismiss

    // Precomputed values (set once after data loads)
    @State private var avgBPM: Double = 0
    @State private var maxBPM: Double = 0
    @State private var minBPM: Double = 0
    @State private var chartData: [(date: Date, bpm: Double)] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                statsGrid
                heartRateTitle
                applyProgramBanner
                heartRateSummaryRow
                heartRateChart
                heartRateZoneSection
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.appDarkText)
                }
            }
        }
        // Re-enable native iOS swipe-back (the screen follows your finger)
        .enableSwipeBack()
        .task {
            async let hr = manager.fetchHeartRate(for: workout)
            async let route = manager.fetchRouteLocations(for: workout)

            let rawHR = (try? await hr) ?? []
            heartRates = rawHR
            isLoadingHR = false

            // Precompute stats once
            if !rawHR.isEmpty {
                let bpms = rawHR.map(\.bpm)
                avgBPM = bpms.reduce(0, +) / Double(bpms.count)
                maxBPM = bpms.max() ?? 0
                minBPM = bpms.min() ?? 0
                // Downsample for chart: max ~300 points keeps it smooth without lag
                chartData = downsample(rawHR, to: 300)
            }

            routeLocations = (try? await route) ?? []
            isLoadingRoute = false
        }
    }

    // MARK: - Header
    var headerSection: some View {
        HStack(spacing: 14) {
            Image(systemName: workout.workoutActivityType.sfSymbol)
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
                .foregroundStyle(Color.appDarkText)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Stats Grid
    var statsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatCard(label: "Workout Time", value: formatDuration(workout.duration))
            StatCard(label: "Distance", value: distanceString)
            StatCard(label: "Active Kilocalories", value: caloriesString)
            StatCard(label: "Avg. Heart Rate", value: avgHRString)
        }
    }

    // MARK: - Heart Rate Title
    var heartRateTitle: some View {
        Text("Heart Rate")
            .font(.sectionHeader)
            .foregroundStyle(Color.appDarkText)
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

    // MARK: - Avg / Max / Min Row
    @ViewBuilder
    var heartRateSummaryRow: some View {
        if !heartRates.isEmpty {
            HStack(spacing: 0) {
                HRSummaryColumn(label: "Avg", value: "\(Int(avgBPM))", unit: "bpm", color: .orange)
                Divider().frame(height: 40)
                HRSummaryColumn(label: "Max", value: "\(Int(maxBPM))", unit: "bpm", color: .red)
                Divider().frame(height: 40)
                HRSummaryColumn(label: "Min", value: "\(Int(minBPM))", unit: "bpm", color: .blue)
            }
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .cardShadow()
        }
    }

    // MARK: - Heart Rate Chart (uses downsampled data)
    @ViewBuilder
    var heartRateChart: some View {
        if isLoadingHR {
            ProgressView("Loading heart rate data...")
                .frame(maxWidth: .infinity, minHeight: 200)
        } else if chartData.isEmpty {
            Text("No heart rate data available.")
                .font(.dateCaptionSmall)
                .foregroundStyle(Color.gray2)
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            Chart {
                ForEach(chartData, id: \.date) { entry in
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

                RuleMark(y: .value("Avg", avgBPM))
                    .foregroundStyle(.orange.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                        .foregroundStyle(Color.gray2.opacity(0.3))
                    AxisValueLabel(format: .dateTime.hour().minute())
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

    // MARK: - Heart Rate Zone Bar
    @ViewBuilder
    var heartRateZoneSection: some View {
        if !heartRates.isEmpty {
            HeartRateZoneBar(heartRates: heartRates)
        }
    }

    // MARK: - Map with HR Heatmap
    @ViewBuilder
    var mapSection: some View {
        Text("Map")
            .font(.sectionHeader)
            .foregroundStyle(Color.appDarkText)

        if isLoadingRoute {
            ProgressView("Loading route...")
                .frame(maxWidth: .infinity, minHeight: 200)
        } else if routeLocations.isEmpty {
            Text("No route data available.")
                .font(.dateCaptionSmall)
                .foregroundStyle(Color.gray2)
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Map {
                    ForEach(routeSegments.indices, id: \.self) { i in
                        let seg = routeSegments[i]
                        MapPolyline(coordinates: seg.coordinates)
                            .stroke(seg.color, lineWidth: 4)
                    }

                    if let first = routeLocations.first?.coordinate {
                        Annotation("Start", coordinate: first) {
                            ZStack {
                                Circle().fill(.white).frame(width: 18, height: 18)
                                Circle().fill(.green).frame(width: 12, height: 12)
                            }
                        }
                    }
                    if let last = routeLocations.last?.coordinate {
                        Annotation("End", coordinate: last) {
                            ZStack {
                                Circle().fill(.white).frame(width: 18, height: 18)
                                Circle().fill(.red).frame(width: 12, height: 12)
                            }
                        }
                    }
                }
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 12) {
                    ZoneLegendDot(color: HeartRateZone.zone1.color, label: "Z1")
                    ZoneLegendDot(color: HeartRateZone.zone2.color, label: "Z2")
                    ZoneLegendDot(color: HeartRateZone.zone3.color, label: "Z3")
                    ZoneLegendDot(color: HeartRateZone.zone4.color, label: "Z4")
                    ZoneLegendDot(color: HeartRateZone.zone5.color, label: "Z5")
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Route Segments
    struct RouteSegment {
        let coordinates: [CLLocationCoordinate2D]
        let color: Color
    }

    var routeSegments: [RouteSegment] {
        guard routeLocations.count >= 2, !heartRates.isEmpty else {
            return [RouteSegment(
                coordinates: routeLocations.map(\.coordinate),
                color: Color.gradientBlue
            )]
        }

        // Downsample route to max ~500 points for segment building
        let locations = routeLocations.count > 500
            ? stride(from: 0, to: routeLocations.count, by: max(1, routeLocations.count / 500))
                .map { routeLocations[$0] }
            : routeLocations

        var segments: [RouteSegment] = []
        var currentColor = hrZoneColorFast(for: locations[0])
        var currentCoords = [locations[0].coordinate]

        for i in 1..<locations.count {
            let loc = locations[i]
            let color = hrZoneColorFast(for: loc)

            if color == currentColor {
                currentCoords.append(loc.coordinate)
            } else {
                currentCoords.append(loc.coordinate)
                segments.append(RouteSegment(coordinates: currentCoords, color: currentColor))
                currentCoords = [loc.coordinate]
                currentColor = color
            }
        }

        if currentCoords.count >= 2 {
            segments.append(RouteSegment(coordinates: currentCoords, color: currentColor))
        } else if !segments.isEmpty {
            var merged = segments[segments.count - 1].coordinates
            merged.append(contentsOf: currentCoords)
            segments[segments.count - 1] = RouteSegment(coordinates: merged, color: segments[segments.count - 1].color)
        }

        return segments
    }

    /// Binary search for closest HR sample — O(log n) instead of O(n)
    func hrZoneColorFast(for location: CLLocation) -> Color {
        let target = location.timestamp.timeIntervalSinceReferenceDate
        guard !heartRates.isEmpty else { return HeartRateZone.zone1.color }

        var lo = 0
        var hi = heartRates.count - 1

        while lo < hi {
            let mid = (lo + hi) / 2
            if heartRates[mid].date.timeIntervalSinceReferenceDate < target {
                lo = mid + 1
            } else {
                hi = mid
            }
        }

        // Check lo and lo-1 to find the actual closest
        var bestIdx = lo
        if lo > 0 {
            let deltaLo = abs(heartRates[lo].date.timeIntervalSinceReferenceDate - target)
            let deltaPrev = abs(heartRates[lo - 1].date.timeIntervalSinceReferenceDate - target)
            if deltaPrev < deltaLo { bestIdx = lo - 1 }
        }

        return HeartRateZone.from(bpm: heartRates[bestIdx].bpm).color
    }

    // MARK: - Downsample HR data for chart rendering
    /// Picks evenly spaced points, always keeping first and last
    func downsample(_ data: [(date: Date, bpm: Double)], to maxPoints: Int) -> [(date: Date, bpm: Double)] {
        guard data.count > maxPoints else { return data }

        var result: [(date: Date, bpm: Double)] = []
        let step = Double(data.count - 1) / Double(maxPoints - 1)

        for i in 0..<maxPoints {
            let index = min(Int(Double(i) * step), data.count - 1)
            result.append(data[index])
        }

        return result
    }

    // MARK: - Computed Values
    var distanceString: String {
        if let dist = workout.totalDistance?.doubleValue(for: .mile()) {
            return String(format: "%.2fmi", dist)
        }
        return "0.00mi"
    }

    var caloriesString: String {
        if let cal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?.doubleValue(for: .kilocalorie()) {
            return String(format: "%.0fcal", cal)
        }
        return "0cal"
    }

    var avgHRString: String {
        if !heartRates.isEmpty {
            return String(format: "%.0fbpm", avgBPM)
        }
        return isLoadingHR ? "..." : "0bpm"
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
                .foregroundStyle(Color.appDarkText)
            Text(value)
                .font(.statValue)
                .foregroundStyle(Color.appDarkText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .cardShadow()
    }
}

// MARK: - HR Summary Column
struct HRSummaryColumn: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.gray1)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 11))
                .foregroundStyle(Color.gray2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Zone Legend Dot
struct ZoneLegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.gray1)
        }
    }
}

// MARK: - Enable native iOS swipe-back gesture
// When navigationBarBackButtonHidden(true) is used, iOS disables the
// interactive pop gesture (the screen-follows-your-finger swipe).
// This modifier re-enables it via UIKit.

struct SwipeBackModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(SwipeBackHelper())
    }
}

struct SwipeBackHelper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            if let nav = uiViewController.navigationController {
                nav.interactivePopGestureRecognizer?.isEnabled = true
                nav.interactivePopGestureRecognizer?.delegate = nil
            }
        }
    }
}

extension View {
    func enableSwipeBack() -> some View {
        self.modifier(SwipeBackModifier())
    }
}

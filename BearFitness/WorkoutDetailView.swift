//
//  WorkoutDetailView.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import SwiftUI
import HealthKit
import MapKit
import Charts
import SwiftData

struct WorkoutDetailView: View {
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

    // HIIT Analysis state
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]
    @State private var showSessionPicker = false
    @State private var analysisResult: HIITAnalysisResult?
    @State private var showAnalysisResult = false
    @State private var isAnalyzing = false
    @State private var analysisError: String?

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
                showSessionPicker = true
            } label: {
                if isAnalyzing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(width: 60, height: 36)
                        .background(LinearGradient.blueLinear)
                        .clipShape(Capsule())
                } else {
                    Text("Apply")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(LinearGradient.blueLinear)
                        .clipShape(Capsule())
                }
            }
            .disabled(isAnalyzing)
        }
        .padding(14)
        .background(LinearGradient.blueLinear.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showSessionPicker) {
            SessionPickerSheet(
                workout: workout,
                sessions: allSessions,
                isAnalyzing: $isAnalyzing
            ) { selected in
                showSessionPicker = false
                Task {
                    isAnalyzing = true
                    do {
                        let result = try await HIITAnalysisService().analyze(session: selected, using: manager)
                        analysisResult = result
                        showAnalysisResult = true
                    } catch {
                        analysisError = error.localizedDescription
                    }
                    isAnalyzing = false
                }
            }
        }
        .sheet(isPresented: $showAnalysisResult) {
            if let result = analysisResult {
                HIITAnalysisResultSheet(result: result)
            }
        }
        .alert("Analysis Error", isPresented: .constant(analysisError != nil)) {
            Button("OK") { analysisError = nil }
        } message: {
            Text(analysisError ?? "")
        }
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

// MARK: - Swipe-back support
// navigationBarBackButtonHidden disables the interactive pop gesture, so we
// re-enable it by reaching into the UINavigationController via UIKit.

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

// MARK: - Session Picker Sheet

struct SessionPickerSheet: View {
    let workout: HKWorkout
    let sessions: [WorkoutSession]
    @Binding var isAnalyzing: Bool
    let onSelect: (WorkoutSession) -> Void

    @Environment(\.dismiss) private var dismiss

    private static let matchWindow: TimeInterval = 2 * 60 * 60  // ±2 hours

    var nearbySessions: [WorkoutSession] {
        sessions.filter { session in
            abs(session.startedAt.timeIntervalSince(workout.startDate)) <= Self.matchWindow
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState(message: "No HIIT sessions saved yet.\nComplete a program in the Timer tab first.")
                } else if nearbySessions.isEmpty {
                    emptyState(message: "No HIIT sessions found within 2 hours of this workout.\nAll saved sessions are shown below.")
                } else {
                    sessionList(nearbySessions, title: "Matching Sessions")
                }
            }
            .navigationTitle("Select HIIT Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func sessionList(_ list: [WorkoutSession], title: String) -> some View {
        List {
            Section(title) {
                ForEach(list) { session in
                    Button {
                        onSelect(session)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.programName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.appDarkText)
                            Text(session.formattedDate)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.gray1)
                            Text("\(session.sections.count) sections · \(session.formattedDuration)")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.gray1)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func emptyState(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(Color.gray2)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color.gray1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

// MARK: - Analysis Result Sheet

struct HIITAnalysisResultSheet: View {
    let result: HIITAnalysisResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    scoreHeader
                    sectionBreakdown
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(Color.white)
            .navigationTitle("HIIT Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var scoreHeader: some View {
        VStack(spacing: 8) {
            if result.hasAnyData {
                ZStack {
                    Circle()
                        .stroke(Color.gray2.opacity(0.3), lineWidth: 8)
                        .frame(width: 110, height: 110)
                    Circle()
                        .trim(from: 0, to: result.overallScore)
                        .stroke(
                            scoreColor(result.overallScore),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 110, height: 110)
                        .animation(.easeOut(duration: 0.6), value: result.overallScore)
                    VStack(spacing: 2) {
                        Text(result.overallScoreString)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(scoreColor(result.overallScore))
                        Text("Score")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.gray1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                Text("Sections hitting their target HR zone")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.gray1)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.gray2)
                        .padding(.top, 20)
                    Text("No heart rate data found")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appDarkText)
                    Text("Make sure you wore your Apple Watch\nduring the HIIT session.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.gray1)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var sectionBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Section Breakdown")
                .font(.sectionHeader)
                .foregroundStyle(Color.appDarkText)

            ForEach(result.sectionResults) { sectionResult in
                sectionRow(sectionResult)
            }
        }
    }

    private func sectionRow(_ sr: SectionAnalysis) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(sr.section.phase.color)
                .frame(width: 4, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(sr.section.phase.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appDarkText)
                Text("Target: \(sr.section.phase.targetBPMRange)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gray1)
                if sr.section.roundNumber > 0 {
                    Text("Round \(sr.section.roundNumber) · Interval \(sr.section.intervalNumber)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gray2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if sr.hasData {
                    Text("\(Int(sr.avgBPM)) bpm")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.appDarkText)
                    Text(sr.actualZone.label)
                        .font(.system(size: 11))
                        .foregroundStyle(sr.actualZone.color)
                    Image(systemName: sr.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(sr.passed ? Color.green : Color.red)
                } else {
                    Text("No data")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.gray2)
                }
            }
        }
        .padding(12)
        .background(Color.appLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.8...: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
}

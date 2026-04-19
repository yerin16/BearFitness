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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]
    @Query private var allRecords: [WorkoutAnalysisRecord]
    @State private var showSessionPicker = false
    @State private var analysisResult: HIITAnalysisResult?
    @State private var showAnalysisResult = false
    @State private var isAnalyzing = false
    @State private var analysisError: String?

    private var existingRecord: WorkoutAnalysisRecord? {
        allRecords.first { $0.workoutUUID == workout.uuid.uuidString }
    }

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

    @ViewBuilder
    var applyProgramBanner: some View {
        if let record = existingRecord {
            matchedResultCard(record)
        } else {
            applyButton
        }
    }

    private var applyButton: some View {
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
                HIITAnalysisResultSheet(
                    result: result,
                    onSave: { saveAnalysisRecord(result) },
                    onDiscard: { analysisResult = nil }
                )
            }
        }
        .alert("Analysis Error", isPresented: .constant(analysisError != nil)) {
            Button("OK") { analysisError = nil }
        } message: {
            Text(analysisError ?? "")
        }
    }

    private func saveAnalysisRecord(_ result: HIITAnalysisResult) {
        if let old = existingRecord { modelContext.delete(old) }

        let overlays = result.sectionResults.map { sr in
            SectionOverlayData(
                phaseRawValue: sr.section.phase.rawValue,
                startDate: sr.section.startTimestamp,
                endDate: sr.section.endTimestamp,
                targetLow: sr.section.phase.targetBPMLow,
                targetHigh: sr.section.phase.targetBPMHigh
            )
        }

        let record = WorkoutAnalysisRecord(
            workoutUUID: workout.uuid.uuidString,
            matchedSessionName: result.session.programName,
            matchedSessionDate: result.session.startedAt,
            matchRate: result.overallScore,
            totalPoints: result.totalPoints,
            maxPoints: result.maxPossiblePoints,
            hrGrade: result.grade,
            timeGrade: result.session.timeGrade,
            timeCompliance: result.session.timeComplianceScore,
            sectionsData: try? JSONEncoder().encode(overlays)
        )
        modelContext.insert(record)
        analysisResult = nil
    }

    private func matchedResultCard(_ record: WorkoutAnalysisRecord) -> some View {
        VStack(spacing: 12) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.gradientBlue)
                Text("Matched HIIT Program")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.appDarkText)
                Spacer()
                Button {
                    if let old = existingRecord { modelContext.delete(old) }
                    showSessionPicker = true
                } label: {
                    Text("Re-analyze")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.gradientBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.gradientBlue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            // Session info
            HStack(spacing: 6) {
                Image(systemName: "figure.highintensity.intervaltraining")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gray1)
                Text(record.matchedSessionName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.appDarkText)
                Text("·")
                    .foregroundStyle(Color.gray2)
                Text(record.matchedSessionDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gray1)
                Spacer()
            }

            Divider()

            // Score stats row
            HStack(spacing: 0) {
                scoreStatColumn(label: "HR Match", value: record.matchRateString, color: record.hrGradeColor)
                Divider().frame(height: 36)
                scoreStatColumn(label: "HR Grade", value: record.hrGrade, color: record.hrGradeColor)
                Divider().frame(height: 36)
                scoreStatColumn(label: "Points", value: "+\(record.totalPoints)", color: .gradientBlue)
                Divider().frame(height: 36)
                scoreStatColumn(label: "Time", value: record.timeGrade, color: record.timeGradeColor)
            }
        }
        .padding(14)
        .background(Color.gradientBlue.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gradientBlue.opacity(0.25), lineWidth: 1)
        )
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
                HIITAnalysisResultSheet(
                    result: result,
                    onSave: { saveAnalysisRecord(result) },
                    onDiscard: { analysisResult = nil }
                )
            }
        }
        .alert("Analysis Error", isPresented: .constant(analysisError != nil)) {
            Button("OK") { analysisError = nil }
        } message: {
            Text(analysisError ?? "")
        }
    }

    private func scoreStatColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.gray1)
        }
        .frame(maxWidth: .infinity)
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
            let overlays = existingRecord?.sectionOverlays ?? []
            let yMin = minBPM - 10
            let yMax = maxBPM + 10

            VStack(alignment: .leading, spacing: 8) {
                Chart {
                    // ── Section target-zone bands (rendered first = lowest layer) ──
                    ForEach(overlays) { overlay in
                        // Colored band for the target BPM zone
                        RectangleMark(
                            xStart: .value("Start", overlay.startDate),
                            xEnd:   .value("End",   overlay.endDate),
                            yStart: .value("Low",   overlay.targetLow),
                            yEnd:   .value("High",  overlay.targetHigh)
                        )
                        .foregroundStyle(
                            (overlay.phase?.color ?? Color.gray).opacity(0.13)
                        )

                        // Vertical divider at the section boundary
                        RuleMark(x: .value("Section", overlay.startDate))
                            .foregroundStyle(
                                (overlay.phase?.color ?? Color.gray).opacity(0.45)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3]))
                            .annotation(position: .top, alignment: .leading, spacing: 2) {
                                Text(overlay.phase?.shortLabel ?? "")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(overlay.phase?.color ?? Color.gray)
                            }
                    }

                    // ── Actual HR area + line ──
                    ForEach(chartData, id: \.date) { entry in
                        AreaMark(
                            x: .value("Time", entry.date),
                            yStart: .value("Min", yMin),
                            yEnd:   .value("BPM", entry.bpm)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.gradientBlue.opacity(0.28), Color.gradientBlue.opacity(0.04)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Time", entry.date),
                            y: .value("BPM",  entry.bpm)
                        )
                        .foregroundStyle(LinearGradient.purpleBlue)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }

                    // Average HR reference line
                    RuleMark(y: .value("Avg", avgBPM))
                        .foregroundStyle(.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                }
                .frame(height: 210)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Color.gray2.opacity(0.3))
                        AxisValueLabel(format: .dateTime.hour().minute())
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray1)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine().foregroundStyle(Color.gray2.opacity(0.3))
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.gray1)
                        }
                    }
                }
                .chartYScale(domain: yMin...yMax)

                // Phase legend shown only when overlay data is available
                if !overlays.isEmpty {
                    let uniquePhases = overlays.compactMap(\.phase)
                        .reduce(into: [WorkoutPhase]()) { acc, p in
                            if !acc.contains(p) { acc.append(p) }
                        }
                    HStack(spacing: 12) {
                        ForEach(uniquePhases, id: \.rawValue) { phase in
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(phase.color.opacity(0.4))
                                    .frame(width: 12, height: 8)
                                Text("\(phase.shortLabel) \(phase.targetBPMRange)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(phase.color)
                            }
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.orange.opacity(0.5))
                                .frame(width: 12, height: 1)
                            Text("Avg")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.gray1)
                        }
                    }
                }
            }
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
    @Query(sort: \HIITProgram.createdAt, order: .reverse) private var programs: [HIITProgram]
    @State private var selectedTab = 0   // 0 = My Programs, 1 = Session History

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented toggle
                Picker("Source", selection: $selectedTab) {
                    Text("My Programs").tag(0)
                    Text("Session History").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)

                Divider()

                Group {
                    if selectedTab == 0 {
                        if programs.isEmpty {
                            noProgramsEmptyState
                        } else {
                            programList
                        }
                    } else {
                        if sessions.isEmpty {
                            noSessionsEmptyState
                        } else {
                            sessionList
                        }
                    }
                }
            }
            .navigationTitle("Apply HIIT Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: Program list

    private var programList: some View {
        List {
            Section {
                ForEach(programs) { program in
                    programRow(program)
                }
            } header: {
                Text("Sections will be mapped onto your workout's start time.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gray1)
                    .textCase(nil)
            }
        }
    }

    private func programRow(_ program: HIITProgram) -> some View {
        Button {
            let synthetic = buildSyntheticSession(from: program, startingAt: workout.startDate)
            onSelect(synthetic)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: program.sfSymbol)
                    .font(.system(size: 18))
                    .foregroundStyle(LinearGradient.purpleBlue)
                    .frame(width: 36, height: 36)
                    .background(Color.appLightGray)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(program.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appDarkText)
                    Text("\(program.workoutType) · \(program.formattedDuration)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.gray1)
                    Text(programSectionSummary(program))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gray2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gray2)
            }
            .padding(.vertical, 4)
        }
    }

    private func programSectionSummary(_ p: HIITProgram) -> String {
        var parts: [String] = []
        if p.warmUpSeconds > 0 { parts.append("Warm-up") }
        if p.highIntensitySeconds > 0 { parts.append("\(p.intervalSets)× High") }
        if p.lowIntensitySeconds > 0 { parts.append("\(p.intervalSets)× Low") }
        if p.coolDownSeconds > 0 { parts.append("Cool-down") }
        return parts.joined(separator: " · ")
    }

    // Builds a temporary WorkoutSession by projecting the program's planned
    // structure onto the workout's actual start time. Not inserted into SwiftData.
    private func buildSyntheticSession(from program: HIITProgram, startingAt start: Date) -> WorkoutSession {
        var sections: [SessionSection] = []
        var cursor = start

        func addSection(phase: WorkoutPhase, seconds: Int, round: Int, interval: Int) {
            guard seconds > 0 else { return }
            let end = cursor.addingTimeInterval(TimeInterval(seconds))
            sections.append(SessionSection(
                id: UUID(),
                phase: phase,
                plannedDurationSeconds: seconds,
                actualDurationSeconds: seconds,
                startTimestamp: cursor,
                endTimestamp: end,
                roundNumber: round,
                intervalNumber: interval
            ))
            cursor = end
        }

        addSection(phase: .warmUp, seconds: program.warmUpSeconds, round: 0, interval: 0)

        let cycles = program.repeatEnabled ? program.numberOfCycles : 1
        for cycle in 1...cycles {
            for set in 1...program.intervalSets {
                addSection(phase: .highIntensity, seconds: program.highIntensitySeconds, round: cycle, interval: set)
                addSection(phase: .lowIntensity,  seconds: program.lowIntensitySeconds,  round: cycle, interval: set)
            }
        }

        addSection(phase: .coolDown, seconds: program.coolDownSeconds, round: 0, interval: 0)

        return WorkoutSession(
            programName: program.name,
            workoutType: program.workoutType,
            startedAt: start,
            endedAt: cursor,
            totalDurationSeconds: Int(cursor.timeIntervalSince(start)),
            sections: sections,
            timeComplianceScore: 1.0   // planned = actual for program-based analysis
        )
    }

    // MARK: Session history list

    private var closeSessions: [WorkoutSession] {
        sessions.filter { abs($0.startedAt.timeIntervalSince(workout.startDate)) <= 2 * 60 * 60 }
    }

    private var otherSessions: [WorkoutSession] {
        sessions.filter { abs($0.startedAt.timeIntervalSince(workout.startDate)) > 2 * 60 * 60 }
    }

    private var sessionList: some View {
        List {
            if !closeSessions.isEmpty {
                Section("Close in Time") {
                    ForEach(closeSessions) { session in sessionRow(session) }
                }
            }
            if !otherSessions.isEmpty {
                Section(closeSessions.isEmpty ? "All Sessions" : "Other Sessions") {
                    ForEach(otherSessions) { session in sessionRow(session) }
                }
            }
        }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        Button {
            onSelect(session)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.programName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appDarkText)
                    Spacer()
                    Text(session.timeGrade)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(session.timeGradeColor)
                }
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

    // Empty state when the user has no programs yet
    private var noProgramsEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Color.gray2)
            Text("No Programs Yet")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.appDarkText)
            Text("Create a HIIT program in the Programs tab first, then come back to apply it.")
                .font(.system(size: 13))
                .foregroundStyle(Color.gray1)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // Empty state when no sessions have been saved yet
    private var noSessionsEmptyState: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 8)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.gray2)

                VStack(spacing: 6) {
                    Text("No Saved Sessions")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.appDarkText)
                    Text("Run and save a HIIT timer session first, or switch to \"My Programs\" to apply a program directly.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.gray1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 12) {
                    stepRow(number: "1", title: "Run a program with the timer",
                            detail: "Tap the play button on any program card")
                    stepRow(number: "2", title: "Save when finished",
                            detail: "Tap \"Save Workout\" on the completion screen")
                    stepRow(number: "3", title: "Come back and select it here",
                            detail: "Or switch to \"My Programs\" to skip this step")
                }
                .padding(16)
                .background(Color.appLightGray)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 8)
        }
    }

    private func stepRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(LinearGradient.purpleBlue)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appDarkText)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gray1)
            }
        }
    }
}

// MARK: - Analysis Result Sheet

struct HIITAnalysisResultSheet: View {
    let result: HIITAnalysisResult
    let onSave: () -> Void
    let onDiscard: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        scoreHeader
                        matchedSessionRow
                        sectionBreakdown
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                // Pinned action buttons
                VStack(spacing: 10) {
                    Button {
                        onSave()
                        dismiss()
                    } label: {
                        Text("Save Match")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient.purpleBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                    }
                    Button {
                        onDiscard()
                        dismiss()
                    } label: {
                        Text("Discard")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.gray1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
                .background(Color.white)
            }
            .background(Color.white)
            .navigationTitle("HIIT Analysis")
            .navigationBarTitleDisplayMode(.inline)
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

    private var matchedSessionRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.highintensity.intervaltraining")
                .font(.system(size: 14))
                .foregroundStyle(LinearGradient.purpleBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.session.programName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appDarkText)
                Text(result.session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gray1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Time Grade")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.gray1)
                Text(result.session.timeGrade)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(result.session.timeGradeColor)
            }
        }
        .padding(12)
        .background(Color.appLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

            VStack(alignment: .trailing, spacing: 4) {
                if sr.hasData {
                    Text("\(Int(sr.avgBPM)) bpm")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.appDarkText)
                    HStack(spacing: 4) {
                        resultChip(value: sr.zoneMatchScore, label: "Z")
                        resultChip(value: sr.durationMatchScore, label: "D")
                        resultChip(value: sr.transitionScore, label: "T")
                    }
                    Text(String(format: "%.0f%%", sr.intervalScore * 100))
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(scoreColor(sr.intervalScore))
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

    private func resultChip(value: Double, label: String) -> some View {
        let color: Color = value >= 0.8 ? .green : value >= 0.5 ? .orange : Color.gray2
        return Text(label)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 16, height: 16)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.8...: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }
}

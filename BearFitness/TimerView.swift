//
//  TimerView.swift
//  BearFitness
//
//  Created by Yerin Kang on 4/2/26.
//

import SwiftUI
import SwiftData

struct TimerView: View {
    let program: HIITProgram
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var engine = TimerEngine()
    @State private var showCompletionSheet = false

    var body: some View {
        ZStack {
            currentBackgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        engine.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                timerRing

                Spacer()

                statsBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                controlButtons
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            engine.setup(from: program)
            engine.start()
        }
        .onChange(of: engine.state) { _, newState in
            if newState == .completed {
                showCompletionSheet = true
            }
        }
        .sheet(isPresented: $showCompletionSheet, onDismiss: {
            dismiss()
        }) {
            CompletionView(engine: engine) { shouldSave in
                if shouldSave {
                    let session = engine.buildSession()
                    modelContext.insert(session)
                }
                showCompletionSheet = false
            }
        }
        .interactiveDismissDisabled()
    }

    var currentBackgroundColor: Color {
        engine.currentPhase.color
    }

    // MARK: - Timer Ring

    var timerRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 12)
                .frame(width: 260, height: 260)

            Circle()
                .trim(from: 0, to: engine.progress)
                .stroke(.white, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: engine.progress)

            VStack(spacing: 8) {
                Text(engine.currentPhase.rawValue)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                Text(engine.formattedTimeRemaining)
                    .font(.system(size: 50, weight: .heavy))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                    Text(engine.currentPhase.targetBPMRange)
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Stats Bar

    var statsBar: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Rounds")
                    .font(.system(size: 14))
                Text(engine.totalRounds > 0
                     ? "\(engine.currentRound)/\(engine.totalRounds)"
                     : "-")
                    .font(.system(size: 30, weight: .heavy))
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text("Remaining Time")
                    .font(.system(size: 14))
                Text(engine.formattedTotalRemaining)
                    .font(.system(size: 30, weight: .heavy))
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                Text("Interval")
                    .font(.system(size: 14))
                Text(engine.totalIntervals > 0
                     ? "\(engine.currentInterval)/\(engine.totalIntervals)"
                     : "-")
                    .font(.system(size: 30, weight: .heavy))
            }
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .stroke(.white, lineWidth: 3)
        )
    }

    // MARK: - Control Buttons

    var controlButtons: some View {
        HStack(spacing: 40) {
            Button {
                engine.skipToPrevious()
            } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(.white.opacity(0.25))
                    .clipShape(Circle())
            }

            Button {
                engine.togglePlayPause()
            } label: {
                Image(systemName: engine.state == .running ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(currentBackgroundColor)
                    .frame(width: 80, height: 80)
                    .background(.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }

            Button {
                engine.skipToNext()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(.white.opacity(0.25))
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Completion View

struct CompletionView: View {
    let engine: TimerEngine
    let onAction: (Bool) -> Void

    // Pre-compute the time score once so the dial animates in smoothly
    private var timeScore: Double {
        let scoreable = engine.completedSections.filter { $0.plannedDurationSeconds > 0 }
        guard !scoreable.isEmpty else { return 1.0 }
        return scoreable.map(\.timeFraction).reduce(0, +) / Double(scoreable.count)
    }

    private var timeGrade: String {
        switch timeScore {
        case 0.95...: return "S"
        case 0.85..<0.95: return "A"
        case 0.70..<0.85: return "B"
        case 0.50..<0.70: return "C"
        default: return "D"
        }
    }

    private var gradeColor: Color {
        switch timeGrade {
        case "S": return Color(red: 0.55, green: 0.20, blue: 0.98)
        case "A": return .green
        case "B": return Color(red: 0.00, green: 0.72, blue: 0.90)
        case "C": return .orange
        default:  return .red
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(Color.gradientBlue)
                                .padding(.top, 24)

                            Text("Workout Complete!")
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundStyle(Color.appDarkText)

                            VStack(spacing: 12) {
                                Text(engine.programName)
                                    .font(.system(size: 18, weight: .bold))
                                    .gradientForeground()

                                HStack(spacing: 20) {
                                    summaryItem(label: "Duration", value: {
                                        let m = engine.totalElapsedSeconds / 60
                                        let s = engine.totalElapsedSeconds % 60
                                        return String(format: "%d:%02d", m, s)
                                    }())
                                    summaryItem(label: "Sections", value: "\(engine.completedSections.count)")
                                    summaryItem(label: "Type", value: engine.workoutType)
                                }
                            }
                            .padding(16)
                            .background(Color.appLightGray)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)
                        }

                        // Time compliance score card
                        timeScoreCard
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        // Section breakdown
                        if !engine.completedSections.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Section Breakdown")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.appDarkText)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)

                                VStack(spacing: 8) {
                                    ForEach(engine.completedSections) { section in
                                        sectionCard(section)
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                        }
                    }
                }

                // Save / Discard buttons pinned at bottom
                VStack(spacing: 10) {
                    Button {
                        onAction(true)
                    } label: {
                        Text("Save Workout")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient.purpleBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 25))
                    }

                    Button {
                        onAction(false)
                    } label: {
                        Text("Discard")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.gray1)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
                .padding(.top, 12)
                .background(Color(.systemBackground))
            }
            .background(Color(.systemBackground))
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Time Score Card

    private var timeScoreCard: some View {
        VStack(spacing: 16) {
            // Top row: large ring + text summary
            HStack(spacing: 20) {
                // Large dial
                ZStack {
                    Circle()
                        .stroke(gradeColor.opacity(0.15), lineWidth: 10)
                        .frame(width: 96, height: 96)
                    Circle()
                        .trim(from: 0, to: timeScore)
                        .stroke(gradeColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 96, height: 96)
                        .animation(.easeOut(duration: 0.8), value: timeScore)
                    VStack(spacing: 2) {
                        Text(timeGrade)
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(gradeColor)
                        Text(String(format: "%.0f%%", timeScore * 100))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.gray1)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Time Compliance")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.appDarkText)
                    Text("How closely you matched each section's planned duration.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.gray1)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Save & open History for full HR analysis →")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gray2)
                        .padding(.top, 2)
                }

                Spacer()
            }

            // Section heatmap strip
            if !engine.completedSections.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Per-section compliance")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gray1)

                    GeometryReader { geo in
                        HStack(spacing: 3) {
                            ForEach(engine.completedSections) { section in
                                let total = max(
                                    engine.completedSections.map(\.plannedDurationSeconds).reduce(0, +), 1
                                )
                                let w = geo.size.width * CGFloat(section.plannedDurationSeconds) / CGFloat(total)
                                completionSegment(section: section, width: max(w - 3, 4))
                            }
                        }
                    }
                    .frame(height: 20)
                }
            }
        }
        .padding(16)
        .background(Color.appLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func completionSegment(section: SessionSection, width: CGFloat) -> some View {
        let compliance = section.timeFraction

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(section.phase.color.opacity(0.15))
                .frame(width: width, height: 20)
            RoundedRectangle(cornerRadius: 4)
                .fill(section.phase.color.opacity(0.85))
                .frame(width: width * compliance, height: 20)
            Text("\(Int(compliance * 100))%")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Color.gray1.opacity(0.8))
                .frame(width: width, height: 20)
                .multilineTextAlignment(.center)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }

    // MARK: - Section Card

    func sectionCard(_ section: SessionSection) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(section.phase.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(section.phase.rawValue)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(section.phase.color)

                if section.roundNumber > 0 {
                    Text("Round \(section.roundNumber) · Set \(section.intervalNumber)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gray1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(section.formattedActualDuration)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.appDarkText)

                let planned = section.plannedDurationSeconds
                let actual = section.actualDurationSeconds
                if planned > 0 {
                    let pct = min(Int(Double(actual) / Double(planned) * 100), 100)
                    HStack(spacing: 4) {
                        Image(systemName: pct >= 90 ? "checkmark.circle.fill" : "clock")
                            .font(.system(size: 10))
                        Text("\(pct)%")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(pct >= 90 ? Color.gradientBlue : Color.gray2)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
        .background(Color.appLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    func summaryItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.gray1)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.appDarkText)
        }
    }
}

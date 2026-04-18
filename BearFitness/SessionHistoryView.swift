//
//  SessionHistoryView.swift
//  BearFitness
//
//  Created by Yerin Kang on 4/2/26.
//

import SwiftUI
import SwiftData

// MARK: - History List

struct SessionHistoryView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if sessions.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.gray2)
                Text("No history yet")
                    .font(.headline)
                    .foregroundStyle(Color.appDarkText)
                Text("Complete a HIIT program to see\nyour session history here.")
                    .font(.dateCaptionSmall)
                    .foregroundStyle(Color.gray1)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionCard(session: session) {
                                withAnimation { modelContext.delete(session) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: WorkoutSession
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row
            HStack(spacing: 5) {
                Image(systemName: iconForType(session.workoutType))
                    .font(.system(size: 12))
                    .foregroundStyle(LinearGradient.purpleBlue)

                Text(session.programName)
                    .font(.system(size: 14, weight: .bold))
                    .gradientForeground()
                    .lineLimit(1)

                Circle().fill(Color.gray2).frame(width: 5, height: 5)

                Text(session.workoutType)
                    .font(.system(size: 12, weight: .medium))
                    .gradientForeground()

                Spacer()

                Button { onDelete() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(LinearGradient.purpleBlue)
                }
            }

            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 12))
                .foregroundStyle(Color.gray1)
                .padding(.top, 4)

            HStack(alignment: .center, spacing: 12) {
                // Duration
                VStack(alignment: .leading, spacing: 0) {
                    Text("Total Time")
                        .font(.statLabel)
                        .foregroundStyle(Color.appDarkText)
                        .padding(.top, 6)
                    Text(session.formattedDuration)
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Color.appDarkText)
                }

                Spacer()

                // Section heatmap — one colored dot per section
                sectionHeatmap

                // Circular grade ring
                gradeRing
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .cardShadow()
    }

    // Small colored dots, one per section, colored by phase and opacity by time compliance
    private var sectionHeatmap: some View {
        HStack(spacing: 3) {
            ForEach(session.sections) { section in
                RoundedRectangle(cornerRadius: 2)
                    .fill(section.phase.color.opacity(0.3 + section.timeFraction * 0.7))
                    .frame(width: 6, height: 22)
            }
        }
    }

    // Circular progress ring with grade letter inside
    private var gradeRing: some View {
        ZStack {
            Circle()
                .stroke(session.timeGradeColor.opacity(0.18), lineWidth: 4)
                .frame(width: 48, height: 48)
            Circle()
                .trim(from: 0, to: session.timeComplianceScore)
                .stroke(session.timeGradeColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 48, height: 48)
                .animation(.easeOut(duration: 0.6), value: session.timeComplianceScore)
            VStack(spacing: 0) {
                Text(session.timeGrade)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(session.timeGradeColor)
                Text("\(Int(session.timeComplianceScore * 100))%")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.gray1)
            }
        }
    }

    func iconForType(_ type: String) -> String {
        switch type {
        case "Running":        return "figure.run"
        case "Walking":        return "figure.walk"
        case "Cycling":        return "figure.outdoor.cycle"
        case "Swimming":       return "figure.pool.swim"
        case "Rowing":         return "figure.rower"
        case "Elliptical":     return "figure.elliptical"
        case "Jump Rope":      return "figure.jumprope"
        case "Stair Climbing": return "figure.stair.stepper"
        case "Mixed Cardio":   return "figure.mixed.cardio"
        default:               return "figure.mixed.cardio"
        }
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    let session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = HealthKitManager()

    @State private var analysisResult: HIITAnalysisResult?
    @State private var isLoadingAnalysis = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                scoreOverview          // dual-ring banner
                sectionTimeline        // horizontal heatmap strip
                sectionBreakdownBlock
                hrAnalysisBlock
                sessionInfoBlock
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Color.white)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.appDarkText)
                }
            }
        }
        .enableSwipeBack()
        .task {
            do {
                try await manager.requestAuthorization()
                analysisResult = try await HIITAnalysisService().analyze(session: session, using: manager)
            } catch {}
            isLoadingAnalysis = false
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconForType(session.workoutType))
                .font(.system(size: 40))
                .foregroundStyle(LinearGradient.purpleBlue)
                .frame(width: 55, height: 55)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.workoutType)
                    .font(.system(size: 12, weight: .medium))
                    .gradientForeground()
                Text(session.programName)
                    .font(.system(size: 25, weight: .bold))
                    .gradientForeground()
                Text(session.formattedDate)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appDarkText)
                    .padding(.top, 2)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Score Overview (dual rings)

    private var scoreOverview: some View {
        HStack(spacing: 0) {
            // Time compliance ring
            scoreRingColumn(
                title: "Time",
                subtitle: "Compliance",
                value: session.timeComplianceScore,
                label: String(format: "%.0f%%", session.timeComplianceScore * 100),
                grade: session.timeGrade,
                gradeColor: session.timeGradeColor,
                ringColor: session.timeGradeColor,
                isLoading: false
            )

            Divider().frame(height: 80).padding(.horizontal, 8)

            // HR match ring
            if isLoadingAnalysis {
                VStack(spacing: 6) {
                    ProgressView()
                        .frame(width: 80, height: 80)
                    Text("HR Loading…")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.gray1)
                }
                .frame(maxWidth: .infinity)
            } else if let result = analysisResult, result.hasAnyData {
                let hrColor = scoreColor(result.overallScore)
                scoreRingColumn(
                    title: "HR",
                    subtitle: "Match Rate",
                    value: result.overallScore,
                    label: result.overallScoreString,
                    grade: result.grade,
                    gradeColor: gradeColor(result.grade),
                    ringColor: hrColor,
                    isLoading: false
                )
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.gray2)
                        .frame(width: 80, height: 80)
                    Text("No HR data")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.gray1)
                }
                .frame(maxWidth: .infinity)
            }

            Divider().frame(height: 80).padding(.horizontal, 8)

            // Stats column
            VStack(alignment: .leading, spacing: 6) {
                metaStat(label: "Duration", value: session.formattedDuration)
                metaStat(label: "Sections", value: "\(session.sections.count)")
                if let result = analysisResult, result.hasAnyData {
                    metaStat(label: "Points", value: "\(result.totalPoints) / \(result.maxPossiblePoints)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .cardShadow()
    }

    private func scoreRingColumn(
        title: String, subtitle: String,
        value: Double, label: String,
        grade: String, gradeColor: Color,
        ringColor: Color, isLoading: Bool
    ) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.15), lineWidth: 8)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)
                    .animation(.easeOut(duration: 0.7), value: value)
                VStack(spacing: 1) {
                    Text(label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ringColor)
                    Text(grade)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(gradeColor)
                }
            }
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.appDarkText)
            Text(subtitle)
                .font(.system(size: 9))
                .foregroundStyle(Color.gray1)
        }
        .frame(maxWidth: .infinity)
    }

    private func metaStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.gray1)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.appDarkText)
        }
    }

    // MARK: - Section Timeline Strip

    private var sectionTimeline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Section Timeline")
                .font(.sectionHeader)
                .foregroundStyle(Color.appDarkText)

            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(session.sections) { section in
                        let totalPlanned = max(session.sections.map(\.plannedDurationSeconds).reduce(0, +), 1)
                        let width = geo.size.width * CGFloat(section.plannedDurationSeconds) / CGFloat(totalPlanned)
                        timelineSegment(section: section, width: max(width - 3, 4))
                    }
                }
            }
            .frame(height: 20)
        }
    }

    private func timelineSegment(section: SessionSection, width: CGFloat) -> some View {
        let compliance = section.timeFraction

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(section.phase.color.opacity(0.15))
                .frame(width: width, height: 20)
            RoundedRectangle(cornerRadius: 4)
                .fill(section.phase.color)
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

    // MARK: - Section Breakdown

    private var sectionBreakdownBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Section Breakdown")
                .font(.sectionHeader)
                .foregroundStyle(Color.appDarkText)

            ForEach(session.sections) { section in
                sectionRow(section)
            }
        }
    }

    private func sectionRow(_ section: SessionSection) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(section.phase.color)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.phase.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appDarkText)
                if section.roundNumber > 0 {
                    Text("Round \(section.roundNumber) · Interval \(section.intervalNumber)")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gray1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(section.formattedActualDuration)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.appDarkText)

                let pct = section.plannedDurationSeconds > 0
                    ? Int(section.timeFraction * 100)
                    : 100
                Text("\(pct)% of planned")
                    .font(.system(size: 10))
                    .foregroundStyle(pct >= 90 ? Color.gradientBlue : Color.gray2)
            }
        }
        .padding(12)
        .background(Color.appLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - HR Analysis Block

    @ViewBuilder
    var hrAnalysisBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Heart Rate Analysis")
                .font(.sectionHeader)
                .foregroundStyle(Color.appDarkText)

            if isLoadingAnalysis {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Fetching heart rate data…")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.gray1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.appLightGray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let result = analysisResult, result.hasAnyData {
                hrScoreHeader(result)
                hrPhaseSummary(result)
                hrSectionList(result)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.gray2)
                    Text("No heart rate data found")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appDarkText)
                    Text("Make sure you wore your Apple Watch during this session.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.gray1)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color.appLightGray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func hrScoreHeader(_ result: HIITAnalysisResult) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Score dial
                ZStack {
                    Circle()
                        .stroke(scoreColor(result.overallScore).opacity(0.15), lineWidth: 7)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: result.overallScore)
                        .stroke(scoreColor(result.overallScore), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 80, height: 80)
                        .animation(.easeOut(duration: 0.7), value: result.overallScore)
                    VStack(spacing: 1) {
                        Text(result.overallScoreString)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(scoreColor(result.overallScore))
                        Text("Match")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.gray1)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(result.grade)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(gradeColor(result.grade))
                        Text("Grade")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.gray1)
                    }
                    Text("HR zone match rate across all sections")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.gray1)
                }

                Spacer()
            }

            // Points breakdown bar
            pointsBreakdownBar(result)
        }
        .padding(14)
        .background(Color.appLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func pointsBreakdownBar(_ result: HIITAnalysisResult) -> some View {
        let base = result.sectionResults.filter(\.hasData).reduce(0) { acc, sr in
            acc + (sr.passed ? 10 : sr.isClose ? 5 : 0)
        }
        let streak = max(0, result.totalPoints - base - (result.session.timeComplianceScore >= 0.95 ? 20 : 0))
        let completion = result.session.timeComplianceScore >= 0.95 ? 20 : 0
        let total = max(result.maxPossiblePoints, 1)

        return VStack(alignment: .leading, spacing: 6) {
            Text("\(result.totalPoints) / \(result.maxPossiblePoints) pts")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appDarkText)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    if base > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(scoreColor(result.overallScore))
                            .frame(width: geo.size.width * CGFloat(base) / CGFloat(total))
                    }
                    if streak > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.55, green: 0.20, blue: 0.98))
                            .frame(width: geo.size.width * CGFloat(streak) / CGFloat(total))
                    }
                    if completion > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gradientBlue)
                            .frame(width: geo.size.width * CGFloat(completion) / CGFloat(total))
                    }
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray2.opacity(0.25))
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 12) {
                legendDot(color: scoreColor(result.overallScore), label: "Zone hits")
                legendDot(color: Color(red: 0.55, green: 0.20, blue: 0.98), label: "Streak")
                legendDot(color: Color.gradientBlue, label: "Completion")
            }
            .font(.system(size: 10))
            .foregroundStyle(Color.gray1)
        }
    }

    @ViewBuilder
    private func hrPhaseSummary(_ result: HIITAnalysisResult) -> some View {
        let best = result.bestPhase
        let worst = result.worstPhase
        if best != nil || worst != nil {
            HStack(spacing: 10) {
                if let b = best {
                    phasePill(label: "Best", phase: b.phase,
                              value: String(format: "%.0f%%", b.compliance * 100),
                              icon: "arrow.up.circle.fill", tint: .green)
                }
                if let w = worst {
                    phasePill(label: "Needs work", phase: w.phase,
                              value: String(format: "%.0f%%", w.compliance * 100),
                              icon: "arrow.down.circle.fill", tint: .orange)
                }
            }
        }
    }

    private func phasePill(label: String, phase: WorkoutPhase, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 10)).foregroundStyle(Color.gray1)
                Text(phase.rawValue.capitalized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appDarkText)
                    .lineLimit(1)
            }
            Spacer()
            Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: .infinity)
    }

    private func hrSectionList(_ result: HIITAnalysisResult) -> some View {
        VStack(spacing: 8) {
            ForEach(result.sectionResults) { sr in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(sr.section.phase.color)
                        .frame(width: 4, height: 52)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(sr.section.phase.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.appDarkText)
                        Text("Target: \(sr.section.phase.targetBPMRange)")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.gray1)
                        if sr.section.roundNumber > 0 {
                            Text("R\(sr.section.roundNumber) · I\(sr.section.intervalNumber)")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.gray2)
                        }
                    }

                    Spacer()

                    if sr.hasData {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(Int(sr.avgBPM)) bpm")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.appDarkText)
                            Text(sr.actualZone.label)
                                .font(.system(size: 10))
                                .foregroundStyle(sr.actualZone.color)
                            Image(systemName: sr.passed ? "checkmark.circle.fill"
                                  : sr.isClose ? "minus.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(sr.passed ? Color.green : sr.isClose ? Color.orange : Color.red)
                        }
                    } else {
                        Text("No data")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.gray2)
                    }
                }
                .padding(10)
                .background(Color.appLightGray)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Session Info

    var sessionInfoBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Info")
                .font(.sectionHeader)
                .foregroundStyle(Color.appDarkText)

            VStack(spacing: 8) {
                HStack {
                    Text("Start").font(.system(size: 12)).foregroundStyle(Color.gray1)
                    Spacer()
                    Text(session.startedAt.formatted(.dateTime.hour().minute().second()))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.appDarkText)
                }
                HStack {
                    Text("End").font(.system(size: 12)).foregroundStyle(Color.gray1)
                    Spacer()
                    Text(session.endedAt.formatted(.dateTime.hour().minute().second()))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.appDarkText)
                }
            }
            .padding(14)
            .background(Color.appLightGray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.8...: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "S": return Color(red: 0.55, green: 0.20, blue: 0.98)
        case "A": return .green
        case "B": return Color(red: 0.00, green: 0.72, blue: 0.90)
        case "C": return .orange
        default:  return .red
        }
    }

    func iconForType(_ type: String) -> String {
        switch type {
        case "Running":        return "figure.run"
        case "Walking":        return "figure.walk"
        case "Cycling":        return "figure.outdoor.cycle"
        case "Swimming":       return "figure.pool.swim"
        case "Rowing":         return "figure.rower"
        case "Elliptical":     return "figure.elliptical"
        case "Jump Rope":      return "figure.jumprope"
        case "Stair Climbing": return "figure.stair.stepper"
        case "Mixed Cardio":   return "figure.mixed.cardio"
        default:               return "figure.mixed.cardio"
        }
    }
}

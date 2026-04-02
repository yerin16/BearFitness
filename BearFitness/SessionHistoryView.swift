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
                            SessionCard(session: session)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                modelContext.delete(session)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: name · type
            HStack(spacing: 5) {
                Image(systemName: iconForType(session.workoutType))
                    .font(.system(size: 12))
                    .foregroundStyle(LinearGradient.purpleBlue)

                Text(session.programName)
                    .font(.system(size: 14, weight: .bold))
                    .gradientForeground()
                    .lineLimit(1)

                Circle()
                    .fill(Color.gray2)
                    .frame(width: 5, height: 5)

                Text(session.workoutType)
                    .font(.system(size: 12, weight: .medium))
                    .gradientForeground()

                Spacer()
            }

            // Date
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 12))
                .foregroundStyle(Color.gray1)
                .padding(.top, 4)

            // Duration
            HStack(alignment: .bottom) {
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

                // Section count
                Text("\(session.sections.count) sections")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gray1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .cardShadow()
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
        default:               return "figure.mixed.cardio"
        }
    }
}

// MARK: - Session Detail View
struct SessionDetailView: View {
    let session: WorkoutSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header (matches Figma node 60:1829)
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
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color.appDarkText)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 8)

                // Summary stats (2 cards only)
                summaryGrid

                // Section breakdown
                Text("Section Breakdown")
                    .font(.sectionHeader)
                    .foregroundStyle(Color.appDarkText)

                ForEach(session.sections) { section in
                    sectionRow(section)
                }

                // Timestamps (for future HR comparison)
                Text("Timestamps")
                    .font(.sectionHeader)
                    .foregroundStyle(Color.appDarkText)

                timestampInfo
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
        .enableSwipeBack()
    }

    // MARK: - Summary Grid
    var summaryGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatCard(label: "Total Duration", value: session.formattedDuration)
            StatCard(label: "Sections", value: "\(session.sections.count)")
        }
    }

    // MARK: - Section Row
    func sectionRow(_ section: SessionSection) -> some View {
        HStack(spacing: 12) {
            // Phase color indicator
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

                let planned = section.plannedDurationSeconds
                let actual = section.actualDurationSeconds
                if planned > 0 {
                    let pct = Int(Double(actual) / Double(planned) * 100)
                    Text("\(pct)% of planned")
                        .font(.system(size: 10))
                        .foregroundStyle(pct >= 90 ? Color.gradientBlue : Color.gray2)
                }
            }
        }
        .padding(12)
        .background(Color.appLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Timestamp Info
    var timestampInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Start")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gray1)
                Spacer()
                Text(session.startedAt.formatted(.dateTime.hour().minute().second()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.appDarkText)
            }
            HStack {
                Text("End")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gray1)
                Spacer()
                Text(session.endedAt.formatted(.dateTime.hour().minute().second()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.appDarkText)
            }
            Text("Timestamps are stored per-section for future Apple Fitness heart rate comparison.")
                .font(.system(size: 10))
                .foregroundStyle(Color.gray2)
                .padding(.top, 4)
        }
        .padding(14)
        .background(Color.appLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        default:               return "figure.mixed.cardio"
        }
    }
}

//
//  HomeView.swift
//  BearFitness
//
//  Created by Mijung Jung on 4/10/26.
//

//
//  HomeView.swift
//  BearFitness
//
//

import SwiftUI
import SwiftData
import HealthKit
import Charts

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \HIITProgram.createdAt, order: .reverse) private var programs: [HIITProgram]
    @Query private var allRecords: [WorkoutAnalysisRecord]

    @StateObject private var healthManager = HealthKitManager()
    
    @State private var workouts: [HKWorkout] = []
    @State private var isLoading = false
    @State private var programToStart: HIITProgram?
    
    // Validation flow
    @State private var showSessionPicker = false
    @State private var selectedWorkout: HKWorkout?
    @State private var isAnalyzing = false
    @State private var analysisResult: HIITAnalysisResult?
    @State private var showAnalysisResult = false
    @State private var analysisError: String?
    
    // Program selection
    @State private var selectedProgramIndex: Int = 0
    @State private var showLevelSheet = false
    @State private var showTutorial = false

    // MARK: - Score & Streak computed values

    var totalAllTimePoints: Int { allRecords.reduce(0) { $0 + $1.totalPoints } }

    var weeklyPoints: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allRecords.filter { $0.analyzedAt >= cutoff }.reduce(0) { $0 + $1.totalPoints }
    }

    var currentStreak: Int { calculateStreak() }

    var pointsLevel: (name: String, color: Color, nextThreshold: Int) {
        switch totalAllTimePoints {
        case 0..<100:   return ("Rookie",    Color.gray1,                          100)
        case 100..<300: return ("Athlete",   Color.gradientBlue,                   300)
        case 300..<600: return ("Champion",  Color(red: 0.0,  green: 0.78, blue: 0.50), 600)
        case 600..<1000:return ("Master",    Color(red: 1.0,  green: 0.67, blue: 0.08), 1000)
        default:        return ("Elite",     Color(red: 0.55, green: 0.20, blue: 0.98), totalAllTimePoints)
        }
    }

    var levelProgress: Double {
        let level = pointsLevel
        let prev = previousThreshold
        let range = level.nextThreshold - prev
        guard range > 0 else { return 1.0 }
        return min(Double(totalAllTimePoints - prev) / Double(range), 1.0)
    }

    private var previousThreshold: Int {
        switch totalAllTimePoints {
        case 0..<100:    return 0
        case 100..<300:  return 100
        case 300..<600:  return 300
        case 600..<1000: return 600
        default:         return 1000
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("BearFitness")
                            .font(.workoutTitle)
                            .foregroundStyle(Color.appDarkText)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        
                        // Score & Streak hero card
                        scoreStreakCard
                            .padding(.horizontal, 20)

                        ActivityChartCard(records: allRecords)
                            .padding(.horizontal, 20)

                        ThisWeekSummarySection(workouts: workouts, records: allRecords, healthManager: healthManager)
                            .padding(.horizontal, 20)

                        suggestedProgramSection
                            .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                }
                .refreshable {
                    await loadWorkouts()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .fullScreenCover(item: $programToStart) { program in
                TimerView(program: program)
            }
            .sheet(isPresented: $showSessionPicker) {
                if let workout = selectedWorkout {
                    SessionPickerSheet(
                        workout: workout,
                        sessions: Array(sessions),
                        isAnalyzing: $isAnalyzing
                    ) { selected in
                        showSessionPicker = false
                        Task {
                            isAnalyzing = true
                            do {
                                let result = try await HIITAnalysisService().analyze(session: selected, using: healthManager)
                                

                                
                                analysisResult = result
                                showAnalysisResult = true
                            } catch {
                                analysisError = error.localizedDescription
                            }
                            isAnalyzing = false
                        }
                    }
                }
            }
            .sheet(isPresented: $showAnalysisResult) {
                if let result = analysisResult {
                    HIITAnalysisResultSheet(
                        result: result,
                        onSave: { analysisResult = nil },
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
        .task {
            await loadWorkouts()
        }
        .onAppear {
            // Silently re-fetch whenever the tab becomes visible so stale / empty state never lingers.
            Task { await loadWorkouts() }
        }
    }
    
    
    // Today's Content (replaces selectedDateContent)
    
    @ViewBuilder
    var todayContent: some View {
        let todayWorkouts = workoutsForToday
        
        if !todayWorkouts.isEmpty {
            // User has workouts today
            VStack(alignment: .leading, spacing: 12) {
                ForEach(todayWorkouts, id: \.uuid) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout, manager: healthManager)
                    } label: {
                        WorkoutCard(workout: workout)
                            .padding(.horizontal, 20)
                    }
                    .buttonStyle(.plain)
                }
                
  
                
                // Suggested program section
                suggestedProgramSection
                    .padding(.horizontal, 20)
            }
        } else {
            // No workouts for today
            emptyStateView
                .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Score & Streak Card

    var scoreStreakCard: some View {
        HStack(spacing: 0) {
            // Total Points column
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.55, green: 0.20, blue: 0.98))
                    Text("Total Points")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.gray1)
                }

                Text("\(totalAllTimePoints)")
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(LinearGradient.purpleBlue)

                // Level badge — tap to see all levels
                Button { showLevelSheet = true } label: {
                    HStack(spacing: 4) {
                        Text(pointsLevel.name)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(pointsLevel.color)
                    .clipShape(Capsule())
                }
                .sheet(isPresented: $showLevelSheet) {
                    LevelProgressSheet(totalPoints: totalAllTimePoints)
                        .presentationDetents([.medium, .large])
                }

                // Progress to next level
                if totalAllTimePoints < 1000 {
                    VStack(alignment: .leading, spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray2.opacity(0.2))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(pointsLevel.color)
                                    .frame(width: geo.size.width * levelProgress)
                                    .animation(.easeOut(duration: 0.6), value: levelProgress)
                            }
                        }
                        .frame(height: 6)

                        Text("\(pointsLevel.nextThreshold - totalAllTimePoints) pts to next level")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.gray1)
                    }
                } else {
                    Text("Max level reached!")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.20, blue: 0.98))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().frame(height: 100).padding(.horizontal, 16)

            // Streak column
            VStack(alignment: .center, spacing: 8) {
                Text("Streak")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.gray1)

                ZStack {
                    Circle()
                        .fill(currentStreak > 0
                              ? Color.orange.opacity(0.12)
                              : Color.gray2.opacity(0.1))
                        .frame(width: 72, height: 72)
                    VStack(spacing: 0) {
                        Text(currentStreak > 0 ? "🔥" : "—")
                            .font(.system(size: currentStreak > 0 ? 22 : 18))
                        Text("\(currentStreak)")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(currentStreak > 0 ? .orange : Color.gray2)
                    }
                }

                Text(currentStreak == 1 ? "day" : "days")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gray1)

                // Weekly points chip
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9))
                    Text("+\(weeklyPoints) this week")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color.gradientBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gradientBlue.opacity(0.1))
                .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearGradient.purpleBlue.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color(red: 0.55, green: 0.20, blue: 0.98).opacity(0.08), radius: 12, y: 4)
    }
    private func weekStat(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.appDarkText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.gray1)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    //Empty State
    
    var emptyStateView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Show last activity message only when there's no workout today
            if let lastWorkout = workouts.first {
                let lastDate: String = {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .long
                    return formatter.string(from: lastWorkout.startDate)
                }()
                
                Text("Your last activity was on \(lastDate).")
                    .font(Font.system(size: 15))
                    .foregroundStyle(Color.appDarkText)
            } else {
                Text("No workouts found yet.")
                    .font(Font.system(size: 15))
                    .foregroundStyle(Color.appDarkText)
            }
            
            Text("Would you like to get started?")
                .font(Font.system(size: 15, weight: .medium))
                .foregroundStyle(Color.appDarkText)
                .padding(.top, 4)
            
            // Suggested HIIT Program
            suggestedProgramSection
        }
    }
    
    // Suggested Program Section (extracted to be reusable)
    
    @ViewBuilder
    var suggestedProgramSection: some View {
        if !programs.isEmpty {
            let selectedProgram = programs.indices.contains(selectedProgramIndex) ? programs[selectedProgramIndex] : programs[0]
            
            VStack(alignment: .leading, spacing: 14) {
                // Program selector with dropdown
                HStack {
                    Menu {
                        ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                            Button {
                                selectedProgramIndex = index
                            } label: {
                                HStack {
                                    Image(systemName: program.sfSymbol)
                                    Text(program.name)
                                    if index == selectedProgramIndex {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("My Program:")
                                .font(Font.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.gray1)

                            Text(selectedProgram.name)
                                .font(Font.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.appDarkText)

                            Image(systemName: "chevron.down")
                                .font(Font.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.gray1)
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button { showTutorial = true } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.gray1)
                    }
                    .sheet(isPresented: $showTutorial) {
                        TutorialSheet(workoutType: selectedProgram.workoutType)
                            .presentationDetents([.medium])
                    }
                }
                
                // Program summary with icons
                VStack(spacing: 10) {
                    // Duration and activity type
                    HStack(spacing: 16) {
                        ProgramDetailBadge(
                            icon: "clock.fill",
                            label: formatProgramDuration(selectedProgram.totalDurationSeconds),
                            color: .blue
                        )
                        
                        ProgramDetailBadge(
                            icon: selectedProgram.sfSymbol,
                            label: selectedProgram.workoutType,
                            color: .purple
                        )
                    }
                    
                    // Phase breakdown
                    VStack(alignment: .leading, spacing: 6) {
                        if selectedProgram.warmUpSeconds > 0 {
                            PhaseRow(
                                icon: "figure.walk",
                                phase: "Warm Up",
                                duration: formatPhaseTime(selectedProgram.warmUpSeconds),
                                color: Color(red: 1.0, green: 0.67, blue: 0.08)
                            )
                        }
                        
                        if selectedProgram.highIntensitySeconds > 0 {
                            PhaseRow(
                                icon: "bolt.fill",
                                phase: "High Intensity",
                                duration: formatPhaseTime(selectedProgram.highIntensitySeconds) + " × \(selectedProgram.intervalSets)",
                                color: Color(red: 1.0, green: 0.38, blue: 0.47)
                            )
                        }
                        
                        if selectedProgram.lowIntensitySeconds > 0 {
                            PhaseRow(
                                icon: "figure.walk.motion",
                                phase: "Low Intensity",
                                duration: formatPhaseTime(selectedProgram.lowIntensitySeconds) + " × \(selectedProgram.intervalSets)",
                                color: Color(red: 0.0, green: 0.78, blue: 0.50)
                            )
                        }
                        
                        if selectedProgram.coolDownSeconds > 0 {
                            PhaseRow(
                                icon: "wind",
                                phase: "Cool Down",
                                duration: formatPhaseTime(selectedProgram.coolDownSeconds),
                                color: Color(red: 0.20, green: 0.56, blue: 0.98)
                            )
                        }
                        
                        if selectedProgram.repeatEnabled && selectedProgram.numberOfCycles > 1 {
                            HStack(spacing: 6) {
                                Image(systemName: "repeat")
                                    .font(Font.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.gray1)
                                Text("Repeats \(selectedProgram.numberOfCycles) cycles")
                                    .font(Font.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.gray1)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Start button
                Button {
                    programToStart = selectedProgram
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start HIIT Training")
                            .font(Font.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient.purpleBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .cardShadow()
        } else {
            // No programs created yet
            VStack(alignment: .leading, spacing: 12) {
                Text("💡 Get Started:")
                    .font(Font.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appDarkText)
                
                Text("Create your first HIIT program in the Program tab to begin your fitness journey!")
                    .font(Font.system(size: 13))
                    .foregroundStyle(Color.gray1)
                
                NavigationLink {
                    ProgramListView()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create HIIT Program")
                            .font(Font.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient.purpleBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .cardShadow()
        }
    }
    
    // Helper Views
    
    func instructionRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(Font.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(LinearGradient.purpleBlue)
                .clipShape(Circle())
            
            Text(text)
                .font(Font.system(size: 12))
                .foregroundStyle(Color.gray1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    //Computed Properties
    
    var workoutsForToday: [HKWorkout] {
        let calendar = Calendar.current
        return workouts.filter { workout in
            calendar.isDateInToday(workout.startDate)
        }
    }
    
    var sessionsThisWeek: [WorkoutSession] {
        let calendar = Calendar.current
        let now = Date()
        return sessions.filter { session in
            guard let daysAgo = calendar.dateComponents([.day], from: session.startedAt, to: now).day else {
                return false
            }
            return daysAgo >= 0 && daysAgo < 7
        }
    }
    
    var unvalidatedWorkoutsToday: [HKWorkout] {
        // For now, return today's workouts that don't have a matching session
        // In a real implementation, you'd check if workout has been validated
        let todayWorkouts = workoutsForToday
        // This is simplified - you'll need to add actual validation tracking
        return todayWorkouts
    }
    
    //Helper Functions
    

    func complianceColor(_ compliance: Double) -> Color {
        if compliance >= 80 {
            return Color.green
        } else if compliance >= 50 {
            return Color.orange
        } else {
            return Color.red
        }
    }
    
    func formatTotalDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    
    func formatShortDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m)m"
        }
    }
    
    func calculateStreak() -> Int {
        // Calculate consecutive days with workouts
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        while true {
            let hasWorkout = sessions.contains { session in
                calendar.isDate(session.startedAt, inSameDayAs: currentDate)
            }
            
            if hasWorkout {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    func formatProgramDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m) min"
        }
    }
    
    func formatPhaseTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        
        if m > 0 && s > 0 {
            return "\(m)m \(s)s"
        } else if m > 0 {
            return "\(m)m"
        } else {
            return "\(s)s"
        }
    }
    
    @MainActor
    func loadWorkouts() async {
        // Only block the UI with a spinner on the very first load.
        if workouts.isEmpty { isLoading = true }
        defer { isLoading = false }

        do {
            try await healthManager.requestAuthorization()
            workouts = try await healthManager.fetchWorkouts()
        } catch {
            print("Error loading workouts: \(error)")
        }
    }
}

// MARK: - Stat Badge Component

struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gray1)
                
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.appDarkText)
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Program Detail Badge

struct ProgramDetailBadge: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.appDarkText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Phase Row

struct PhaseRow: View {
    let icon: String
    let phase: String
    let duration: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 20)
            
            Text(phase)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.appDarkText)
            
            Spacer()
            
            Text(duration)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.gray1)
        }
    }
}

// MARK: - Level Progress Sheet

struct LevelProgressSheet: View {
    let totalPoints: Int
    @Environment(\.dismiss) private var dismiss

    struct Level: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let threshold: Int
        let color: Color
        let description: String
    }

    let levels: [Level] = [
        Level(name: "Rookie",   icon: "🌱", threshold: 0,    color: Color.gray1,
              description: "Just getting started — every rep counts."),
        Level(name: "Athlete",  icon: "⚡️", threshold: 100,  color: Color.gradientBlue,
              description: "You've built a real habit. Keep pushing."),
        Level(name: "Champion", icon: "🏅", threshold: 300,  color: Color(red: 0.0, green: 0.78, blue: 0.50),
              description: "Consistent effort and solid heart-rate control."),
        Level(name: "Master",   icon: "🔥", threshold: 600,  color: Color(red: 1.0, green: 0.67, blue: 0.08),
              description: "Your zone matching is elite. Dominating intervals."),
        Level(name: "Elite",    icon: "👑", threshold: 1000, color: Color(red: 0.55, green: 0.20, blue: 0.98),
              description: "The highest rank. Total HR and time precision."),
    ]

    private func isUnlocked(_ level: Level) -> Bool { totalPoints >= level.threshold }

    private func isCurrent(_ level: Level, index: Int) -> Bool {
        let next = index + 1 < levels.count ? levels[index + 1].threshold : Int.max
        return totalPoints >= level.threshold && totalPoints < next
    }

    private func progress(for level: Level, index: Int) -> Double {
        guard isCurrent(level, index: index) else { return isUnlocked(level) ? 1.0 : 0.0 }
        let next = index + 1 < levels.count ? levels[index + 1].threshold : level.threshold + 1
        let range = next - level.threshold
        guard range > 0 else { return 1.0 }
        return min(Double(totalPoints - level.threshold) / Double(range), 1.0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("\(totalPoints)")
                            .font(.system(size: 48, weight: .heavy))
                            .foregroundStyle(LinearGradient.purpleBlue)
                        Text("total points")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.gray1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    Divider()

                    ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                        levelRow(level: level, index: index)
                    }

                    Text("Earn points by matching your heart-rate zone, completing sections on time, and maintaining streaks.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.gray1)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, 20)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Levels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func levelRow(level: Level, index: Int) -> some View {
        let unlocked = isUnlocked(level)
        let current  = isCurrent(level, index: index)
        let prog     = progress(for: level, index: index)
        let nextThreshold = index + 1 < levels.count ? levels[index + 1].threshold : nil

        return HStack(alignment: .top, spacing: 14) {
            Text(level.icon)
                .font(.system(size: 22))
                .frame(width: 44, height: 44)
                .background(unlocked ? level.color.opacity(0.15) : Color.appLightGray)
                .clipShape(Circle())
                .overlay(Circle().stroke(current ? level.color : Color.clear, lineWidth: 2))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(level.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(unlocked ? level.color : Color.gray2)

                    if current {
                        Text("YOU ARE HERE")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(level.color)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if unlocked {
                        Image(systemName: current ? "star.fill" : "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(current ? level.color : Color.green)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.gray2)
                    }
                }

                Text(level.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gray1)

                if let next = nextThreshold {
                    Text("\(level.threshold) – \(next - 1) pts")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(unlocked ? level.color : Color.gray2)
                } else {
                    Text("\(level.threshold)+ pts")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(unlocked ? level.color : Color.gray2)
                }

                if current {
                    VStack(alignment: .leading, spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(level.color.opacity(0.15))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(level.color)
                                    .frame(width: geo.size.width * prog)
                                    .animation(.easeOut(duration: 0.6), value: prog)
                            }
                        }
                        .frame(height: 6)

                        if let next = nextThreshold {
                            Text("\(next - totalPoints) more pts to \(levels[index + 1].name)")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.gray1)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(current ? level.color.opacity(0.05) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(current ? level.color.opacity(0.3) : Color.appLightGray, lineWidth: 1)
        )
    }
}

//Activity Chart Card

struct ActivityChartCard: View {
    let records: [WorkoutAnalysisRecord]

    enum Period: String, CaseIterable { case week = "W", month = "M", year = "Y" }

    @State private var period: Period = .week

    struct Bucket: Identifiable {
        let id: String
        let label: String
        let isCurrent: Bool
        let points: Int
    }

    private var buckets: [Bucket] {
        let cal = Calendar.current
        let now = Date()
        switch period {
        case .week:
            return (0..<7).reversed().compactMap { offset -> Bucket? in
                guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
                let start = cal.startOfDay(for: day)
                let end   = cal.date(byAdding: .day, value: 1, to: start)!
                let pts   = records.filter { $0.matchedSessionDate >= start && $0.matchedSessionDate < end }
                                   .reduce(0) { $0 + $1.totalPoints }
                return Bucket(id: "\(offset)", label: dayLabel(day, offset: offset), isCurrent: offset == 0, points: pts)
            }
        case .month:
            return (0..<4).reversed().compactMap { offset -> Bucket? in
                guard let wk = cal.date(byAdding: .weekOfYear, value: -offset, to: cal.startOfDay(for: now)) else { return nil }
                let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: wk))!
                let sunday = cal.date(byAdding: .day, value: 7, to: monday)!
                let pts    = records.filter { $0.matchedSessionDate >= monday && $0.matchedSessionDate < sunday }
                                    .reduce(0) { $0 + $1.totalPoints }
                let label  = offset == 0 ? "This Wk" : "Wk \(4 - offset)"
                return Bucket(id: "\(offset)", label: label, isCurrent: offset == 0, points: pts)
            }
        case .year:
            return (0..<12).reversed().compactMap { offset -> Bucket? in
                guard let md = cal.date(byAdding: .month, value: -offset, to: now),
                      let start = cal.date(from: cal.dateComponents([.year, .month], from: md)),
                      let end   = cal.date(byAdding: .month, value: 1, to: start) else { return nil }
                let pts   = records.filter { $0.matchedSessionDate >= start && $0.matchedSessionDate < end }
                                   .reduce(0) { $0 + $1.totalPoints }
                return Bucket(id: "\(offset)", label: monthLabel(start), isCurrent: offset == 0, points: pts)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Points Activity")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.appDarkText)

            // Full-width W / M / Y slider
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.tertiarySystemFill))

                    let slotW = geo.size.width / CGFloat(Period.allCases.count)
                    let idx   = Period.allCases.firstIndex(of: period) ?? 0
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                        .frame(width: slotW - 6, height: geo.size.height - 6)
                        .offset(x: CGFloat(idx) * slotW + 3)
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: period)

                    HStack(spacing: 0) {
                        ForEach(Period.allCases, id: \.self) { p in
                            Button { withAnimation { period = p } } label: {
                                Text(p.rawValue)
                                    .font(.system(size: 13, weight: period == p ? .bold : .regular))
                                    .foregroundStyle(period == p ? Color.appDarkText : Color.gray1)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
            .frame(height: 36)

            if buckets.allSatisfy({ $0.points == 0 }) {
                Text(emptyStateMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.gray1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 100)
            } else {
                Chart(buckets) { bucket in
                    BarMark(
                        x: .value("Period", bucket.label),
                        y: .value("Points", bucket.points)
                    )
                    .foregroundStyle(bucket.isCurrent
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color(red: 0.55, green: 0.20, blue: 0.98), Color.gradientBlue],
                            startPoint: .bottom, endPoint: .top))
                        : AnyShapeStyle(Color(.systemGray4))
                    )
                    .cornerRadius(5)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color.gray2.opacity(0.25))
                        AxisValueLabel()
                            .font(.system(size: 9))
                            .foregroundStyle(Color.gray1)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: period == .year ? 8 : 10))
                            .foregroundStyle(Color.gray1)
                    }
                }
                .frame(height: 130)
                .animation(.easeInOut(duration: 0.25), value: period)
            }
        }
        .padding(.vertical, 8)
    }

    private var emptyStateMessage: String {
        switch period {
        case .week:  return "No matched workouts in the last 7 days.\nSwitch to M or Y to see older activity."
        case .month: return "No matched workouts in the last 4 weeks."
        case .year:  return "No matched workouts in the last 12 months."
        }
    }

    private func dayLabel(_ date: Date, offset: Int) -> String {
        if offset == 0 { return "Today" }
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM"
        return f.string(from: date)
    }
}

//This Week Summary

struct ThisWeekSummarySection: View {
    let workouts: [HKWorkout]
    let records: [WorkoutAnalysisRecord]
    let healthManager: HealthKitManager

    // UUIDs of workouts that have been matched/validated
    private var matchedUUIDs: Set<String> {
        Set(records.map { $0.workoutUUID })
    }

    private var thisWeekMatchedWorkouts: [HKWorkout] {
        let cal = Calendar.current
        let now = Date()
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return [] }
        let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? now
        let uuids = matchedUUIDs
        return workouts
            .filter { $0.startDate >= weekStart && $0.startDate < weekEnd && uuids.contains($0.uuid.uuidString) }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week Summary")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.appDarkText)

            if thisWeekMatchedWorkouts.isEmpty {
                Text("No matched workouts this week yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.gray1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(thisWeekMatchedWorkouts, id: \.uuid) { workout in
                    let record = records.first { $0.workoutUUID == workout.uuid.uuidString }
                    NavigationLink {
                        WorkoutDetailView(workout: workout, manager: healthManager)
                    } label: {
                        WorkoutCard(workout: workout, analysisRecord: record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Tutorial Sheet (this is in ?)

struct TutorialSheet: View {
    let workoutType: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("💡 To sync with Apple Watch:")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.appDarkText)

                VStack(alignment: .leading, spacing: 14) {
                    tutorialRow(number: "1", text: "Start a workout on your Apple Watch")
                    tutorialRow(number: "2", text: "Choose the matching activity type (\(workoutType))")
                    tutorialRow(number: "3", text: "Start the HIIT timer in BearFitness")
                    tutorialRow(number: "4", text: "After completing, validate and earn points!")
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func tutorialRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(LinearGradient.purpleBlue)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Color.appDarkText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [HIITProgram.self, WorkoutSession.self, WorkoutAnalysisRecord.self])
}

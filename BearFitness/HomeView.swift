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

                        // This Week Performance
                        weekPerformanceCard
                            .padding(.horizontal, 20)
                        
                        //Today's Content
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Today's Workouts")
                                .font(.sectionHeader)
                                .foregroundStyle(Color.appDarkText)
                                .padding(.horizontal, 20)
                            
                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                            } else {
                                todayContent
                            }
                        }
                        
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
                
                // Validation status - always show for today
                validationStatusView
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                
                // HIIT training benefits message
                Text("HIIT training makes it easier to achieve fitness goals by offering maximum health benefits in a fraction of the time.")
                    .font(Font.system(size: 14))
                    .foregroundStyle(Color.gray1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                
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

    // MARK: - Week Performance Card
    
    var weekPerformanceCard: some View {
        let weekSessions = sessionsThisWeek
        let totalDuration = weekSessions.reduce(0) { $0 + $1.totalDurationSeconds }
        let weekGoal = 3 // default should later implement so user can change goal
        

        
        return VStack(alignment: .leading, spacing: 16) {
            // Header with progress ring
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Week's Performance")
                        .font(Font.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.appDarkText)
                    
                    if weekSessions.count >= weekGoal {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.orange)
                            Text("Goal achieved!")
                                .font(Font.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.orange)
                        }
                    } else {
                        Text("\(weekGoal - weekSessions.count) more to reach your goal")
                            .font(Font.system(size: 12))
                            .foregroundStyle(Color.gray1)
                    }
                }
                
                Spacer()
                
                // Circular progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: min(Double(weekSessions.count) / Double(weekGoal), 1.0))
                        .stroke(
                            LinearGradient.purpleBlue,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: weekSessions.count)
                    
                    VStack(spacing: 0) {
                        Text("\(weekSessions.count)")
                            .font(Font.system(size: 20, weight: .bold))
                            .foregroundStyle(LinearGradient.purpleBlue)
                        Text("of \(weekGoal)")
                            .font(Font.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.gray1)
                    }
                }
            }
            
            Divider()
            
            
            // Stats strip
            HStack(spacing: 0) {
                weekStat(icon: "flame.fill",
                         label: "Sessions",
                         value: "\(weekSessions.count)",
                         color: .orange)
                Divider().frame(height: 40)
                weekStat(icon: "clock.fill",
                         label: "Duration",
                         value: formatShortDuration(totalDuration),
                         color: .blue)
                Divider().frame(height: 40)
                weekStat(icon: "star.fill",
                         label: "Points",
                         value: "+\(weeklyPoints)",
                         color: Color(red: 0.55, green: 0.20, blue: 0.98))
            }
            .background(Color.appLightGray)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.purple.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearGradient.purpleBlue.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.gradientBlue.opacity(0.1), radius: 10, y: 5)
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

    //Validation Status - Simplified
    
    @ViewBuilder
    var validationStatusView: some View {
        let unvalidatedCount = unvalidatedWorkoutsToday.count
        
        VStack(alignment: .leading, spacing: 12) {
            if unvalidatedCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(Font.system(size: 18))
                            .foregroundStyle(LinearGradient.purpleBlue)
                        
                        Text("Is this HIIT training done in BearFitness?")
                            .font(Font.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appDarkText)
                    }
                    
                    Text("If you completed a HIIT program with BearFitness, validate it to track your performance and earn points!")
                        .font(Font.system(size: 13))
                        .foregroundStyle(Color.gray1)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 26)
                }
                
                // Show validate buttons for each unvalidated workout
                ForEach(unvalidatedWorkoutsToday, id: \.uuid) { workout in
                    Button {
                        selectedWorkout = workout
                        showSessionPicker = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.workoutActivityType.name)
                                    .font(Font.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.appDarkText)
                                Text(workout.startDate.formatted(date: .omitted, time: .shortened))
                                    .font(Font.system(size: 12))
                                    .foregroundStyle(Color.gray1)
                            }
                            Spacer()
                            Text("Validate")
                                .font(Font.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(LinearGradient.purpleBlue)
                                .clipShape(Capsule())
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(LinearGradient.purpleBlue, lineWidth: 1)
                        )
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Font.system(size: 16))
                        .foregroundStyle(Color.green)
                    
                    Text("All workouts validated!")
                        .font(Font.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.appDarkText)
                }
            }
        }
        .padding(16)
        .background(LinearGradient.purpleBlue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 15))
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
            
            Text("HIIT training makes it easier to achieve fitness goals by offering maximum health benefits in a fraction of the time.")
                .font(Font.system(size: 14))
                .foregroundStyle(Color.gray1)
                .fixedSize(horizontal: false, vertical: true)
            
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
                        
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                
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
                
                Divider()
                
                // Instructions
                Text("💡 To sync with Apple Watch:")
                    .font(Font.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.appDarkText)
                
                VStack(alignment: .leading, spacing: 6) {
                    instructionRow(number: "1", text: "Start a workout on your Apple Watch")
                    instructionRow(number: "2", text: "Choose the matching activity type (\(selectedProgram.workoutType))")
                    instructionRow(number: "3", text: "Start the HIIT timer in BearFitness")
                    instructionRow(number: "4", text: "After completing, validate and earn points!")
                }
                .padding(.leading, 4)
                
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

#Preview {
    HomeView()
        .modelContainer(for: [HIITProgram.self, WorkoutSession.self, WorkoutAnalysisRecord.self])
}

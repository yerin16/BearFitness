//
//  SuggestionsView.swift
//  BearFitness
//

import SwiftUI
import SwiftData

// MARK: - Suggested Program Template

struct SuggestedProgram: Identifiable {
    let id = UUID()
    let name: String
    let workoutType: String
    let difficulty: Difficulty
    let description: String
    let warmUpSeconds: Int
    let highIntensitySeconds: Int
    let lowIntensitySeconds: Int
    let intervalSets: Int
    let repeatEnabled: Bool
    let numberOfCycles: Int
    let coolDownSeconds: Int

    enum Difficulty: String, CaseIterable {
        case beginner     = "Beginner"
        case intermediate = "Intermediate"
        case advanced     = "Advanced"

        var color: Color {
            switch self {
            case .beginner:     return .green
            case .intermediate: return .orange
            case .advanced:     return .red
            }
        }
    }

    var totalDurationSeconds: Int {
        let block = (highIntensitySeconds + lowIntensitySeconds) * intervalSets
        let cycles = repeatEnabled ? numberOfCycles : 1
        return warmUpSeconds + (block * cycles) + coolDownSeconds
    }

    var formattedDuration: String {
        let t = totalDurationSeconds
        if t >= 3600 {
            return String(format: "%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
        }
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    func toHIITProgram() -> HIITProgram {
        HIITProgram(
            name: name,
            workoutType: workoutType,
            warmUpSeconds: warmUpSeconds,
            highIntensitySeconds: highIntensitySeconds,
            lowIntensitySeconds: lowIntensitySeconds,
            intervalSets: intervalSets,
            repeatEnabled: repeatEnabled,
            numberOfCycles: numberOfCycles,
            coolDownSeconds: coolDownSeconds
        )
    }
}

// MARK: - Program Catalog

extension SuggestedProgram {
    static let catalog: [SuggestedProgram] = [

        // MARK: Beginner
        SuggestedProgram(
            name: "Walk-Run Starter",
            workoutType: "Running",
            difficulty: .beginner,
            description: "Alternate between easy jogging and walking. Great for building your cardio base without overdoing it.",
            warmUpSeconds: 3 * 60,
            highIntensitySeconds: 30,
            lowIntensitySeconds: 90,
            intervalSets: 6,
            repeatEnabled: false,
            numberOfCycles: 1,
            coolDownSeconds: 3 * 60
        ),
        SuggestedProgram(
            name: "Easy Bike Boost",
            workoutType: "Cycling",
            difficulty: .beginner,
            description: "Short bursts of faster pedaling with plenty of recovery. Perfect if you're new to HIIT on a bike.",
            warmUpSeconds: 5 * 60,
            highIntensitySeconds: 20,
            lowIntensitySeconds: 60,
            intervalSets: 8,
            repeatEnabled: false,
            numberOfCycles: 1,
            coolDownSeconds: 5 * 60
        ),
        SuggestedProgram(
            name: "Jump Rope Intro",
            workoutType: "Jump Rope",
            difficulty: .beginner,
            description: "Work intervals followed by generous rest. Focus on rhythm and coordination over speed.",
            warmUpSeconds: 2 * 60,
            highIntensitySeconds: 20,
            lowIntensitySeconds: 40,
            intervalSets: 8,
            repeatEnabled: false,
            numberOfCycles: 1,
            coolDownSeconds: 2 * 60
        ),

        // MARK: Intermediate
        SuggestedProgram(
            name: "Tabata Classic",
            workoutType: "Running",
            difficulty: .intermediate,
            description: "The original Tabata protocol: 20s all-out effort, 10s rest, 8 rounds. Repeated for multiple cycles.",
            warmUpSeconds: 2 * 60,
            highIntensitySeconds: 20,
            lowIntensitySeconds: 10,
            intervalSets: 8,
            repeatEnabled: true,
            numberOfCycles: 4,
            coolDownSeconds: 2 * 60
        ),
        SuggestedProgram(
            name: "Cycling Power Intervals",
            workoutType: "Cycling",
            difficulty: .intermediate,
            description: "30/30 intervals push your lactate threshold while keeping recovery equal to effort.",
            warmUpSeconds: 5 * 60,
            highIntensitySeconds: 30,
            lowIntensitySeconds: 30,
            intervalSets: 10,
            repeatEnabled: true,
            numberOfCycles: 2,
            coolDownSeconds: 5 * 60
        ),
        SuggestedProgram(
            name: "Row & Recover",
            workoutType: "Rowing",
            difficulty: .intermediate,
            description: "Hard rowing efforts with active recovery rows. Builds both aerobic capacity and upper-body endurance.",
            warmUpSeconds: 3 * 60,
            highIntensitySeconds: 40,
            lowIntensitySeconds: 20,
            intervalSets: 8,
            repeatEnabled: true,
            numberOfCycles: 2,
            coolDownSeconds: 3 * 60
        ),
        SuggestedProgram(
            name: "Stair Climber Pyramid",
            workoutType: "Stair Climbing",
            difficulty: .intermediate,
            description: "Escalating intensity on the stair climber. Consistent work-to-rest ratio keeps heart rate in the zone.",
            warmUpSeconds: 4 * 60,
            highIntensitySeconds: 45,
            lowIntensitySeconds: 30,
            intervalSets: 6,
            repeatEnabled: true,
            numberOfCycles: 2,
            coolDownSeconds: 4 * 60
        ),

        // MARK: Advanced
        SuggestedProgram(
            name: "Sprint Intervals",
            workoutType: "Running",
            difficulty: .advanced,
            description: "Near-maximal sprints with short recovery. Demands excellent fitness — aim for Zone 5 on every high interval.",
            warmUpSeconds: 5 * 60,
            highIntensitySeconds: 45,
            lowIntensitySeconds: 15,
            intervalSets: 8,
            repeatEnabled: true,
            numberOfCycles: 3,
            coolDownSeconds: 5 * 60
        ),
        SuggestedProgram(
            name: "Tabata Pro",
            workoutType: "Running",
            difficulty: .advanced,
            description: "Six full Tabata cycles with minimal rest between cycles. Only attempt this if you have a solid fitness base.",
            warmUpSeconds: 3 * 60,
            highIntensitySeconds: 20,
            lowIntensitySeconds: 10,
            intervalSets: 8,
            repeatEnabled: true,
            numberOfCycles: 6,
            coolDownSeconds: 3 * 60
        ),
        SuggestedProgram(
            name: "Elite Rowing HIIT",
            workoutType: "Rowing",
            difficulty: .advanced,
            description: "Long hard intervals on the rower with just enough rest to keep going. Targets sustained Zone 4–5 effort.",
            warmUpSeconds: 5 * 60,
            highIntensitySeconds: 60,
            lowIntensitySeconds: 20,
            intervalSets: 6,
            repeatEnabled: true,
            numberOfCycles: 3,
            coolDownSeconds: 5 * 60
        ),
        SuggestedProgram(
            name: "Mixed Cardio Blitz",
            workoutType: "Mixed Cardio",
            difficulty: .advanced,
            description: "High-density work for seasoned athletes. Very short recovery forces your body to clear lactate under load.",
            warmUpSeconds: 4 * 60,
            highIntensitySeconds: 30,
            lowIntensitySeconds: 10,
            intervalSets: 10,
            repeatEnabled: true,
            numberOfCycles: 4,
            coolDownSeconds: 4 * 60
        ),
    ]
}

// MARK: - Suggestions View

struct SuggestionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var myPrograms: [HIITProgram]

    @State private var selectedDifficulty: SuggestedProgram.Difficulty? = nil
    @State private var addedIDs: Set<UUID> = []

    var filtered: [SuggestedProgram] {
        guard let d = selectedDifficulty else { return SuggestedProgram.catalog }
        return SuggestedProgram.catalog.filter { $0.difficulty == d }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            difficultyFilter
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(filtered) { program in
                        SuggestionCard(
                            program: program,
                            isAdded: isAlreadyAdded(program)
                        ) {
                            addProgram(program)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private var difficultyFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(label: "All", tint: Color.gradientBlue, selected: selectedDifficulty == nil) {
                    selectedDifficulty = nil
                }
                ForEach(SuggestedProgram.Difficulty.allCases, id: \.self) { d in
                    filterPill(label: d.rawValue, tint: d.color, selected: selectedDifficulty == d) {
                        selectedDifficulty = selectedDifficulty == d ? nil : d
                    }
                }
            }
        }
    }

    private func filterPill(label: String, tint: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? tint : Color.appLightGray)
                .foregroundStyle(selected ? .white : Color.gray1)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func isAlreadyAdded(_ suggested: SuggestedProgram) -> Bool {
        addedIDs.contains(suggested.id) ||
        myPrograms.contains(where: { $0.name == suggested.name })
    }

    private func addProgram(_ suggested: SuggestedProgram) {
        let program = suggested.toHIITProgram()
        modelContext.insert(program)
        addedIDs.insert(suggested.id)
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let program: SuggestedProgram
    let isAdded: Bool
    let onAdd: () -> Void

    var sfSymbol: String {
        switch program.workoutType {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 13))
                    .foregroundStyle(LinearGradient.purpleBlue)

                Text(program.name)
                    .font(.system(size: 14, weight: .bold))
                    .gradientForeground()
                    .lineLimit(1)

                Spacer()

                // Difficulty badge
                Text(program.difficulty.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(program.difficulty.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(program.difficulty.color.opacity(0.12))
                    .clipShape(Capsule())
            }

            // Description
            Text(program.description)
                .font(.system(size: 12))
                .foregroundStyle(Color.gray1)
                .lineLimit(2)

            // Stats row
            HStack(spacing: 16) {
                statChip(icon: "clock", value: program.formattedDuration)
                statChip(icon: "arrow.up.arrow.down", value: "\(program.intervalSets) sets")
                if program.repeatEnabled {
                    statChip(icon: "repeat", value: "\(program.numberOfCycles)x")
                }
                statChip(icon: "bolt.fill", value: "\(program.highIntensitySeconds)s / \(program.lowIntensitySeconds)s")
            }

            // Add button
            Button {
                onAdd()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isAdded ? "checkmark" : "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text(isAdded ? "Added to My Programs" : "Add to My Programs")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(isAdded ? Color.gray1 : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isAdded ? AnyShapeStyle(Color.appLightGray) : AnyShapeStyle(LinearGradient.purpleBlue))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isAdded)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .cardShadow()
    }

    private func statChip(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(Color.gray2)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.gray1)
        }
    }
}

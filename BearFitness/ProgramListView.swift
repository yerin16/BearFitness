//
//  ProgramListView.swift
//  BearFitness
//
//  Created by Yerin Kang on 4/2/26.
//

import SwiftUI
import SwiftData

enum ProgramTab: String, CaseIterable {
    case myPrograms = "My Programs"
    case suggestions = "Suggestions"
    case history = "History"
}

struct ProgramListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HIITProgram.createdAt, order: .reverse) private var programs: [HIITProgram]
    @State private var selectedTab: ProgramTab = .myPrograms
    @State private var showCreateSheet = false
    @State private var programToEdit: HIITProgram?
    @State private var programToStart: HIITProgram?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("HIIT Programs")
                        .font(.workoutTitle)
                        .foregroundStyle(Color.appDarkText)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    segmentedToggle
                        .padding(.horizontal, 20)

                    switch selectedTab {
                    case .myPrograms:
                        myProgramsContent
                    case .suggestions:
                        placeholderContent("Suggestions coming soon")
                    case .history:
                        SessionHistoryView()
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                if selectedTab == .myPrograms {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(LinearGradient.purpleBlue)
                            .clipShape(Circle())
                            .shadow(color: Color.gradientBlue.opacity(0.4), radius: 10, y: 5)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 20)
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateProgramView()
            }
            .sheet(item: $programToEdit) { program in
                EditProgramView(program: program)
            }
            .fullScreenCover(item: $programToStart) { program in
                TimerView(program: program)
            }
        }
    }

    // MARK: - Segmented Toggle

    var segmentedToggle: some View {
        HStack(spacing: 0) {
            ForEach(ProgramTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab
                            ? Color.white
                            : Color.clear
                        )
                        .clipShape(Capsule())
                        .shadow(
                            color: selectedTab == tab ? Color.black.opacity(0.08) : .clear,
                            radius: 4, y: 2
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color(red: 0.94, green: 0.94, blue: 0.94))
        .clipShape(Capsule())
    }

    // MARK: - My Programs Content

    var myProgramsContent: some View {
        Group {
            if programs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "figure.highintensity.intervaltraining")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.gray2)
                    Text("No programs yet")
                        .font(.headline)
                        .foregroundStyle(Color.appDarkText)
                    Text("Tap + to create your first HIIT program")
                        .font(.dateCaptionSmall)
                        .foregroundStyle(Color.gray1)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(programs) { program in
                            ProgramCard(program: program, onDelete: {
                                deleteProgram(program)
                            }, onEdit: {
                                programToEdit = program
                            }, onStart: {
                                programToStart = program
                            })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 80) // space for FAB
                }
            }
        }
    }

    func placeholderContent(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.gray2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    func deleteProgram(_ program: HIITProgram) {
        modelContext.delete(program)
    }
}

// MARK: - Program Card

struct ProgramCard: View {
    let program: HIITProgram
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: program.sfSymbol)
                    .font(.system(size: 12))
                    .foregroundStyle(LinearGradient.purpleBlue)
                    .frame(width: 15, height: 15)

                Text(program.name.isEmpty ? "Untitled" : program.name)
                    .font(.system(size: 14, weight: .bold))
                    .gradientForeground()
                    .lineLimit(1)

                Circle()
                    .fill(Color.gray2)
                    .frame(width: 5, height: 5)

                Text(program.workoutType)
                    .font(.system(size: 12, weight: .medium))
                    .gradientForeground()

                Spacer()

                Menu {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.gradientBlue)
                        .frame(width: 24, height: 24)
                }
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Total Time")
                        .font(.statLabel)
                        .foregroundStyle(Color.appDarkText)
                        .padding(.top, 8)

                    Text(program.formattedDuration)
                        .font(.durationLarge)
                        .foregroundStyle(Color.appDarkText)
                }

                Spacer()

                Button {
                    onStart()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.gradientBlue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .cardShadow()
    }
}

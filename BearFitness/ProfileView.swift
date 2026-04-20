//
//  ProfileView.swift
//  BearFitness
//
//  Created by christine j on 4/10/26.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @AppStorage("profile_name")   private var name   = "Name"
    @AppStorage("profile_height") private var height = "5'6"
    @AppStorage("profile_weight") private var weight = "000"
    @AppStorage("profile_age")    private var age    = "21"

    @State private var editingName = false
    @State private var draftName   = ""
    @FocusState private var nameFieldFocused: Bool

    @State private var editingStat: StatField? = nil

    enum StatField: Identifiable {
        case height, weight, age
        var id: String {
            switch self {
            case .height: return "height"
            case .weight: return "weight"
            case .age:    return "age"
            }
        }
    }

    private var trimmedDraftName: String {
        draftName.trimmingCharacters(in: .whitespaces)
    }

    private var canSaveName: Bool {
        !trimmedDraftName.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // MARK: - Name Header
                        HStack {
                            if editingName {
                                TextField("Name", text: $draftName)
                                    .font(.system(size: 30, weight: .heavy))
                                    .foregroundStyle(Color.appDarkText)
                                    .tint(Color.gradientBlue)
                                    .submitLabel(.done)
                                    .focused($nameFieldFocused)
                                    .onSubmit { commitName() }

                                Button {
                                    commitName()
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(canSaveName ? Color.gradientBlue : Color.gray2)
                                        .font(.system(size: 22))
                                }
                                .disabled(!canSaveName)
                            } else {
                                Text(name)
                                    .font(.system(size: 30, weight: .heavy))
                                    .foregroundStyle(Color.appDarkText)

                                Spacer()

                                Button {
                                    draftName = name
                                    editingName = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        nameFieldFocused = true
                                    }
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.gray1)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // MARK: - Stats Row (Height / Weight / Age)
                        HStack(spacing: 12) {
                            statCard(value: height, label: "Height") {
                                editingStat = .height
                            }
                            statCard(value: weight, label: "Weight") {
                                editingStat = .weight
                            }
                            statCard(value: age, label: "Age") {
                                editingStat = .age
                            }
                        }
                        .padding(.horizontal, 20)

                        // MARK: - Account Section
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Account")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.appDarkText)
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                                .padding(.bottom, 12)

                            NavigationLink(destination: HeartRateZonesView()) {
                                HStack(spacing: 14) {
                                    Image(systemName: "heart")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.gradientBlue)
                                        .frame(width: 24, height: 24)
                                    Text("Heart Rate Zones")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.gray1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.gray2)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .tint(.clear)

                            NavigationLink(destination: PointHistoryView()) {
                                HStack(spacing: 14) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.gradientBlue)
                                        .frame(width: 24, height: 24)
                                    Text("Point History")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.gray1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.gray2)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                            }
                            .tint(.clear)
                        }
                        .padding(.bottom, 12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .cardShadow()
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editingStat) { field in
                statEditorSheet(for: field)
                    .presentationDetents([.height(320)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Name Commit Logic

    private func commitName() {
        guard canSaveName else { return }   // never save empty
        name = trimmedDraftName
        editingName = false
        nameFieldFocused = false
    }

    // MARK: - Stat Card

    @ViewBuilder
    func statCard(value: String, label: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 25, weight: .medium))
                    .gradientForeground(.blueLinear)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.gray1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 74)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stat Editor Sheet

    @ViewBuilder
    private func statEditorSheet(for field: StatField) -> some View {
        switch field {
        case .height:
            StatEditor(
                title: "Height",
                unit: "in.",
                minValue: 36,   // 3 ft
                maxValue: 96,   // 8 ft
                initialValue: extractNumber(from: height),
                onSave: { newVal in
                    height = "\(newVal) in."
                    editingStat = nil
                },
                onCancel: { editingStat = nil }
            )
        case .weight:
            StatEditor(
                title: "Weight",
                unit: "lb",
                minValue: 50,
                maxValue: 600,
                initialValue: extractNumber(from: weight),
                onSave: { newVal in
                    weight = "\(newVal) lb"
                    editingStat = nil
                },
                onCancel: { editingStat = nil }
            )
        case .age:
            StatEditor(
                title: "Age",
                unit: "years",
                minValue: 13,
                maxValue: 99,
                initialValue: extractNumber(from: age),
                onSave: { newVal in
                    age = "\(newVal)"
                    editingStat = nil
                },
                onCancel: { editingStat = nil }
            )
        }
    }

    private func extractNumber(from s: String) -> Int {
        let digits = s.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }
}

// MARK: - Stat Editor Sheet View

struct StatEditor: View {
    let title: String
    let unit: String
    let minValue: Int
    let maxValue: Int
    let initialValue: Int
    let onSave: (Int) -> Void
    let onCancel: () -> Void

    @State private var text: String = ""
    @FocusState private var fieldFocused: Bool

    private var parsedValue: Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return Int(trimmed)
    }

    private var isValid: Bool {
        guard let v = parsedValue else { return false }
        return v >= minValue && v <= maxValue
    }

    private var errorMessage: String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "Please enter a value" }
        guard let v = parsedValue else { return "Enter a valid number" }
        if v < minValue { return "Minimum is \(minValue) \(unit)" }
        if v > maxValue { return "Maximum is \(maxValue) \(unit)" }
        return nil
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit \(title)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.appDarkText)
                .padding(.top, 20)

            HStack(spacing: 8) {
                TextField("", text: $text)
                    .keyboardType(.numberPad)
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundStyle(Color.appDarkText)
                    .multilineTextAlignment(.center)
                    .frame(width: 140)
                    .focused($fieldFocused)

                Text(unit)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.gray1)
            }

            // Range hint / error message
            if let msg = errorMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
            } else {
                Text("Range: \(minValue)–\(maxValue) \(unit)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.gray1)
            }

            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.gray1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.appLightGray)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    if let v = parsedValue, isValid {
                        onSave(v)
                    }
                } label: {
                    Text("Save")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            isValid
                            ? AnyShapeStyle(LinearGradient.purpleBlue)
                            : AnyShapeStyle(Color.gray2)
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .onAppear {
            text = "\(initialValue)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                fieldFocused = true
            }
        }
    }
}

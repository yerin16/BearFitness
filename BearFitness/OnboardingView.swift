//
//  OnboardingView.swift
//  BearFitness
//
//  Created by christine j on 4/12/26.
//

import SwiftUI

// MARK: - Onboarding Container

struct OnboardingView: View {
    @AppStorage("has_onboarded")  private var hasOnboarded = false
    @AppStorage("profile_name")   private var profileName   = "Your Name"
    @AppStorage("profile_height") private var profileHeight = "5'6"
    @AppStorage("profile_weight") private var profileWeight = "000"
    @AppStorage("profile_age")    private var profileAge    = "21"

    @State private var step: Int = 0

    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var age       = 19
    @State private var weight    = 115
    @State private var heightIn  = 65

    var background: LinearGradient {
        LinearGradient(
            colors: [Color.gradientBlue, Color.gradientLightBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            switch step {
            case 0: SplashStep(onContinue: { step = 1 })
            case 1: NameStep(firstName: $firstName, lastName: $lastName, onContinue: { step = 2 })
            case 2: AgeStep(age: $age, onContinue: { step = 3 })
            case 3: WeightStep(weight: $weight, onContinue: { step = 4 })
            case 4: HeightStep(heightIn: $heightIn, onContinue: finish)
            default: EmptyView()
            }
        }
    }

    private func finish() {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast  = lastName.trimmingCharacters(in: .whitespaces)
        profileName   = [trimmedFirst, trimmedLast].filter { !$0.isEmpty }.joined(separator: " ")
        if profileName.isEmpty { profileName = "Your Name" }
        profileAge    = "\(age)"
        profileWeight = "\(weight) lb"
        profileHeight = "\(heightIn) in."
        hasOnboarded  = true
    }
}

// MARK: - Shared Pill Button

struct OnboardingContinueButton: View {
    let label: String
    let showArrow: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 16, weight: .bold))
                    .gradientForeground(.blueLinear)
                if showArrow {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.gradientBlue)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}

// MARK: - Step 0: Splash

struct SplashStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack {
            Spacer()
            Text("Bear Fitness")
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("HIIT start. No excuses.")
                .font(.system(size: 18))
                .foregroundStyle(Color.white.opacity(0.85))
                .padding(.top, 4)
            Spacer()
            OnboardingContinueButton(label: "Get Started", showArrow: false, action: onContinue)
                .padding(.bottom, 40)
        }
    }
}

// MARK: - Step 1: Name

struct NameStep: View {
    @Binding var firstName: String
    @Binding var lastName:  String
    let onContinue: () -> Void

    // Darker text color so typed input reads clearly on the white card
    private let inputTextColor = Color(red: 0.05, green: 0.05, blue: 0.08)

    var canContinue: Bool { !firstName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            Text("What's your name?")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black)
                .padding(.top, 120)

            VStack(alignment: .leading, spacing: 20) {
                labelledField(
                    title: "FIRST NAME",
                    required: true,
                    placeholder: "First name",
                    text: $firstName
                )
                labelledField(
                    title: "LAST NAME",
                    required: false,
                    placeholder: "Last name",
                    text: $lastName
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            Spacer()

            OnboardingContinueButton(label: "Continue", showArrow: true) {
                if canContinue { onContinue() }
            }
            .opacity(canContinue ? 1 : 0.5)
            .disabled(!canContinue)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    func labelledField(title: String, required: Bool, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                if required {
                    Text("*")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.red)
                }
            }
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.gray2)
                ZStack(alignment: .leading) {
                    // Custom darker placeholder
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(red: 0.35, green: 0.35, blue: 0.4))
                    }
                    TextField("", text: text)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(inputTextColor)
                        .tint(Color.gradientBlue)
                        .autocorrectionDisabled()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Step 2: Age

struct AgeStep: View {
    @Binding var age: Int
    let onContinue: () -> Void

    private let minAge = 13
    private let maxAge = 99
    private let rowHeight: CGFloat = 70

    var body: some View {
        VStack(spacing: 0) {
            Text("What's your age?")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black)
                .padding(.top, 120)

            Spacer()

            VerticalAgePicker(
                age: $age,
                minAge: minAge,
                maxAge: maxAge,
                rowHeight: rowHeight
            )
            .frame(height: rowHeight * 5)

            Spacer()

            OnboardingContinueButton(label: "Continue", showArrow: true, action: onContinue)
                .padding(.bottom, 40)
        }
    }
}

// MARK: - Vertical Age Picker (smooth drag-based, with highlight box)

// MARK: - Vertical Age Picker (smooth drag-based, with highlight box)

struct VerticalAgePicker: View {
    @Binding var age: Int
    let minAge: Int
    let maxAge: Int
    let rowHeight: CGFloat

    @State private var dragStartAge: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let centerY = geo.size.height / 2
            let values = Array(minAge...maxAge)

            ZStack {
                // SELECTION BACKGROUND — big vibrant indigo pill in the center
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.32, green: 0.32, blue: 0.95))
                    .frame(width: 180, height: 110)
                    .shadow(color: Color(red: 0.32, green: 0.32, blue: 0.95).opacity(0.6),
                            radius: 15, x: 0, y: 6)

                // Scrolling column of numbers
                VStack(spacing: 0) {
                    ForEach(values, id: \.self) { v in
                        Text("\(v)")
                            .font(.system(
                                size: fontSize(for: v),
                                weight: v == age ? .bold : .regular,
                                design: .serif
                            ))
                            .foregroundStyle(.white)
                            .opacity(opacity(for: v))
                            .frame(maxWidth: .infinity)
                            .frame(height: rowHeight)
                    }
                }
                .offset(y: totalOffsetY(centerY: centerY))
                .animation(dragStartAge == nil ? .spring(response: 0.35, dampingFraction: 0.85) : nil,
                           value: age)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if dragStartAge == nil { dragStartAge = age }

                        let startAge = dragStartAge ?? age
                        let rowsMoved = Int((-g.translation.height / rowHeight).rounded())
                        let newAge = max(minAge, min(maxAge, startAge + rowsMoved))
                        if newAge != age {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                age = newAge
                            }
                        }
                    }
                    .onEnded { _ in
                        dragStartAge = nil
                    }
            )
        }
    }

    private func totalOffsetY(centerY: CGFloat) -> CGFloat {
        let indexOfAge = CGFloat(age - minAge)
        let base = centerY - (indexOfAge * rowHeight + rowHeight / 2)
        return base
    }

    private func fontSize(for v: Int) -> CGFloat {
        let diff = abs(v - age)
        switch diff {
        case 0: return 72
        case 1: return 42
        case 2: return 34
        case 3: return 28
        default: return 24
        }
    }

    private func opacity(for v: Int) -> Double {
        let diff = abs(v - age)
        switch diff {
        case 0: return 1.0
        case 1: return 0.7
        case 2: return 0.45
        case 3: return 0.25
        default: return 0.0
        }
    }
}

// MARK: - Step 3: Weight

struct WeightStep: View {
    @Binding var weight: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("What's your weight?")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black)
                .padding(.top, 120)

            Spacer()

            VStack(spacing: 16) {
                Text("\(weight) lb")
                    .font(.system(size: 47, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                RulerPicker(
                    value: $weight,
                    range: 50...400,
                    majorStep: 5
                )
                .frame(height: 110)
            }

            Spacer()

            OnboardingContinueButton(label: "Continue", showArrow: true, action: onContinue)
                .padding(.bottom, 40)
        }
    }
}

// MARK: - Step 4: Height

struct HeightStep: View {
    @Binding var heightIn: Int
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("What's your height?")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black)
                .padding(.top, 120)

            Spacer()

            VStack(spacing: 16) {
                Text("\(heightIn) in.")
                    .font(.system(size: 47, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                RulerPicker(
                    value: $heightIn,
                    range: 36...96,
                    majorStep: 6
                )
                .frame(height: 110)
            }

            Spacer()

            OnboardingContinueButton(label: "Continue", showArrow: true, action: onContinue)
                .padding(.bottom, 40)
        }
    }
}

// MARK: - Horizontal Ruler Picker (drag to adjust, properly centered)

struct RulerPicker: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let majorStep: Int

    private let tickSpacing: CGFloat = 14   // gap between ticks
    private let tickWidth:   CGFloat = 2    // width of each tick

    @State private var dragStartValue: Int? = nil

    // Total horizontal distance per one unit of value
    private var unitWidth: CGFloat { tickSpacing + tickWidth }

    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let values = Array(range)

            ZStack {
                // Tick row
                HStack(spacing: tickSpacing) {
                    ForEach(values, id: \.self) { v in
                        let isSelected = v == value
                        VStack(spacing: 6) {
                            Rectangle()
                                .fill(isSelected ? Color.white : Color.white.opacity(0.75))
                                .frame(
                                    width: isSelected ? 3 : tickWidth,
                                    height: isSelected ? 65 : ((v % majorStep == 0) ? 55 : 35)
                                )

                            if v % majorStep == 0 {
                                Text("\(v)")
                                    .font(.system(
                                        size: isSelected ? 16 : 14,
                                        weight: isSelected ? .bold : .regular
                                    ))
                                    .foregroundStyle(.white)
                                    .frame(height: 20)
                                    .fixedSize()
                            } else {
                                Color.clear.frame(height: 20)
                            }
                        }
                        .frame(width: tickWidth)
                    }
                }
                // Shift the whole row so the current value's tick sits exactly at centerX
                .offset(x: centerX - offsetForValue())
                .animation(.spring(response: 0.25, dampingFraction: 0.85), value: value)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if dragStartValue == nil { dragStartValue = value }
                        let startValue = dragStartValue ?? value
                        let delta = Int((-g.translation.width / unitWidth).rounded())
                        let newValue = max(range.lowerBound,
                                           min(range.upperBound, startValue + delta))
                        if newValue != value {
                            value = newValue
                        }
                    }
                    .onEnded { _ in
                        dragStartValue = nil
                    }
            )
        }
    }

    // Distance from first tick's leading edge to the center of the tick for `value`
    private func offsetForValue() -> CGFloat {
        let idx = value - range.lowerBound
        return CGFloat(idx) * unitWidth + tickWidth / 2
    }
}

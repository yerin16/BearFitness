//
//  CreateProgramView.swift
//  BearFitness
//
//  Created by Yerin Kang on 4/2/26.
//

import SwiftUI
import SwiftData

struct CreateProgramView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var form = ProgramFormData()

    var body: some View {
        NavigationStack {
            ProgramFormContent(form: $form)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.gray1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.appLightGray)
                            .clipShape(Capsule())
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") { saveProgram() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(form.name.isEmpty ? AnyShapeStyle(Color.gray2) : AnyShapeStyle(LinearGradient.purpleBlue))
                            .clipShape(Capsule())
                            .disabled(form.name.isEmpty)
                    }
                }
        }
    }

    private func saveProgram() {
        let program = form.toProgram()
        modelContext.insert(program)
        do {
            try modelContext.save()
        } catch {
            print("Error saving program: \(error)")
        }
        dismiss()
    }
}

struct EditProgramView: View {
    @Bindable var program: HIITProgram
    @Environment(\.dismiss) private var dismiss

    @State private var form = ProgramFormData()

    var body: some View {
        NavigationStack {
            ProgramFormContent(form: $form)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.gray1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.appLightGray)
                            .clipShape(Capsule())
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            form.applyTo(program)
                            dismiss()
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(form.name.isEmpty ? AnyShapeStyle(Color.gray2) : AnyShapeStyle(LinearGradient.purpleBlue))
                        .clipShape(Capsule())
                        .disabled(form.name.isEmpty)
                    }
                }
                .onAppear {
                    form = ProgramFormData(from: program)
                }
        }
    }
}

// MARK: - Form Data

struct ProgramFormData {
    var name: String = ""
    var workoutType: String = "Running"
    var warmUpMinutes: Int = 0
    var warmUpSeconds: Int = 0
    var highIntensityMinutes: Int = 0
    var highIntensitySeconds: Int = 0
    var lowIntensityMinutes: Int = 0
    var lowIntensitySeconds: Int = 0
    var intervalSets: Int = 1
    var repeatEnabled: Bool = false
    var numberOfCycles: Int = 2
    var coolDownMinutes: Int = 0
    var coolDownSeconds: Int = 0

    var totalSeconds: Int {
        let warmUp = warmUpMinutes * 60 + warmUpSeconds
        let high = highIntensityMinutes * 60 + highIntensitySeconds
        let low = lowIntensityMinutes * 60 + lowIntensitySeconds
        let intervalBlock = (high + low) * intervalSets
        let cycles = repeatEnabled ? numberOfCycles : 1
        let coolDown = coolDownMinutes * 60 + coolDownSeconds
        return warmUp + (intervalBlock * cycles) + coolDown
    }

    var formattedTotal: String {
        let t = totalSeconds
        return String(format: "%02d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60)
    }

    init() {}

    init(from program: HIITProgram) {
        name = program.name
        workoutType = program.workoutType
        warmUpMinutes = program.warmUpSeconds / 60
        warmUpSeconds = program.warmUpSeconds % 60
        highIntensityMinutes = program.highIntensitySeconds / 60
        highIntensitySeconds = program.highIntensitySeconds % 60
        lowIntensityMinutes = program.lowIntensitySeconds / 60
        lowIntensitySeconds = program.lowIntensitySeconds % 60
        intervalSets = program.intervalSets
        repeatEnabled = program.repeatEnabled
        numberOfCycles = program.numberOfCycles
        coolDownMinutes = program.coolDownSeconds / 60
        coolDownSeconds = program.coolDownSeconds % 60
    }

    func toProgram() -> HIITProgram {
        HIITProgram(
            name: name,
            workoutType: workoutType,
            warmUpSeconds: warmUpMinutes * 60 + warmUpSeconds,
            highIntensitySeconds: highIntensityMinutes * 60 + highIntensitySeconds,
            lowIntensitySeconds: lowIntensityMinutes * 60 + lowIntensitySeconds,
            intervalSets: intervalSets,
            repeatEnabled: repeatEnabled,
            numberOfCycles: numberOfCycles,
            coolDownSeconds: coolDownMinutes * 60 + coolDownSeconds
        )
    }

    func applyTo(_ program: HIITProgram) {
        program.name = name
        program.workoutType = workoutType
        program.warmUpSeconds = warmUpMinutes * 60 + warmUpSeconds
        program.highIntensitySeconds = highIntensityMinutes * 60 + highIntensitySeconds
        program.lowIntensitySeconds = lowIntensityMinutes * 60 + lowIntensitySeconds
        program.intervalSets = intervalSets
        program.repeatEnabled = repeatEnabled
        program.numberOfCycles = numberOfCycles
        program.coolDownSeconds = coolDownMinutes * 60 + coolDownSeconds
    }
}

// MARK: - Shared Form Content

struct ProgramFormContent: View {
    @Binding var form: ProgramFormData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .leading) {
                    if form.name.isEmpty {
                        Text("Type Your Program Name")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.gray1)
                    }
                    TextField("", text: $form.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.appDarkText)
                        .tint(Color.gradientBlue)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                workoutTypePicker

                timeRow(
                    label: "Warm Up",
                    color: Color(red: 1.0, green: 0.67, blue: 0.08),
                    minutes: $form.warmUpMinutes,
                    seconds: $form.warmUpSeconds
                )

                stepperRow(label: "Interval Cycle", value: $form.intervalSets, unit: "set", range: 1...20)

                timeRow(
                    label: "High Intensity",
                    color: Color(red: 1.0, green: 0.38, blue: 0.47),
                    minutes: $form.highIntensityMinutes,
                    seconds: $form.highIntensitySeconds
                )

                timeRow(
                    label: "Low Intensity",
                    color: Color(red: 0.0, green: 0.78, blue: 0.50),
                    minutes: $form.lowIntensityMinutes,
                    seconds: $form.lowIntensitySeconds
                )

                repeatRow

                if form.repeatEnabled {
                    stepperRow(label: "Number of Cycles", value: $form.numberOfCycles, unit: "x", range: 2...20)
                }

                timeRow(
                    label: "Cool Down",
                    color: Color(red: 0.20, green: 0.56, blue: 0.98),
                    minutes: $form.coolDownMinutes,
                    seconds: $form.coolDownSeconds
                )

                totalDurationPreview
            }
            .padding(.bottom, 30)
        }
        .background(Color.white)
    }

    // MARK: - Workout Type Picker

    var workoutTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HIITProgram.workoutTypes, id: \.self) { type in
                    Button {
                        form.workoutType = type
                    } label: {
                        Text(type)
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                form.workoutType == type
                                ? AnyShapeStyle(LinearGradient.purpleBlue)
                                : AnyShapeStyle(Color.appLightGray)
                            )
                            .foregroundStyle(form.workoutType == type ? .white : Color.gray1)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Time Row

    func timeRow(
        label: String,
        color: Color,
        minutes: Binding<Int>,
        seconds: Binding<Int>
    ) -> some View {
        HStack {
            Text(String(format: "%02d:%02d", minutes.wrappedValue, seconds.wrappedValue))
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .frame(width: 44, height: 28)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.gray1)

            Spacer()

            HStack(spacing: 4) {
                Picker("", selection: minutes) {
                    ForEach(0..<60) { m in
                        Text("\(m) m").tag(m)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Picker("", selection: seconds) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { s in
                        Text("\(s) s").tag(s)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    // MARK: - Stepper Row

    func stepperRow(
        label: String,
        value: Binding<Int>,
        unit: String,
        range: ClosedRange<Int>
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.gray1)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    if value.wrappedValue > range.lowerBound {
                        value.wrappedValue -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.gray2)
                }

                Text("\(value.wrappedValue) \(unit)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appDarkText)
                    .frame(minWidth: 40)

                Button {
                    if value.wrappedValue < range.upperBound {
                        value.wrappedValue += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.gradientBlue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    // MARK: - Repeat Toggle

    var repeatRow: some View {
        HStack {
            Text("Repeat")
                .font(.system(size: 12))
                .foregroundStyle(Color.gray1)

            Spacer()

            Toggle("", isOn: $form.repeatEnabled)
                .labelsHidden()
                .tint(Color.gradientBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.appLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    // MARK: - Total Duration Preview

    var totalDurationPreview: some View {
        HStack {
            Text("Total Duration")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.appDarkText)

            Spacer()

            Text(form.formattedTotal)
                .font(.system(size: 20, weight: .heavy))
                .gradientForeground()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(LinearGradient.blueLinear.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

//
//  HeartRateZoneView.swift
//  BearFitness
//
//  Created by christine j on 4/10/26.
//

import SwiftUI

enum HRZoneMode: String {
    case automatic = "Automatic"
    case manual    = "Manual"
}

// MARK: - Custom Zone

struct CustomHRZone: Identifiable, Hashable, Codable {
    let id: Int
    var lower: Int
    var upper: Int
    var label: String { "Zone \(id)" }

    var rangeText: String {
        if id == 1 { return "< \(upper + 1)" }
        if upper == 999 { return "\(lower)+" }
        return "\(lower) - \(upper)"
    }
}

// MARK: - Automatic Zone

struct HRZoneCalculator {
    static func maxHR(forAge age: Int) -> Int {
        max(220 - age, 100)
    }

    static func automaticZones(forAge age: Int) -> [CustomHRZone] {
        let maxHR = Double(maxHR(forAge: age))
        let z1Upper = Int((maxHR * 0.60).rounded()) - 1
        let z2Lower = z1Upper + 1
        let z2Upper = Int((maxHR * 0.70).rounded()) - 1
        let z3Lower = z2Upper + 1
        let z3Upper = Int((maxHR * 0.80).rounded()) - 1
        let z4Lower = z3Upper + 1
        let z4Upper = Int((maxHR * 0.90).rounded()) - 1
        let z5Lower = z4Upper + 1

        return [
            CustomHRZone(id: 1, lower: 0,        upper: z1Upper),
            CustomHRZone(id: 2, lower: z2Lower,  upper: z2Upper),
            CustomHRZone(id: 3, lower: z3Lower,  upper: z3Upper),
            CustomHRZone(id: 4, lower: z4Lower,  upper: z4Upper),
            CustomHRZone(id: 5, lower: z5Lower,  upper: 999),
        ]
    }
}

// MARK: - Manual zone edited boundary

enum EditedSide {
    case lower, upper, both
}

fileprivate let manualZonesDefaultJSON: String = {
    let defaults: [CustomHRZone] = [
        CustomHRZone(id: 1, lower: 0,   upper: 118),
        CustomHRZone(id: 2, lower: 120, upper: 140),
        CustomHRZone(id: 3, lower: 141, upper: 160),
        CustomHRZone(id: 4, lower: 161, upper: 180),
        CustomHRZone(id: 5, lower: 181, upper: 999),
    ]
    if let data = try? JSONEncoder().encode(defaults),
       let s = String(data: data, encoding: .utf8) {
        return s
    }
    return "[]"
}()

fileprivate func decodeManualZones(from json: String) -> [CustomHRZone] {
    guard let data = json.data(using: .utf8),
          let zones = try? JSONDecoder().decode([CustomHRZone].self, from: data),
          zones.count == 5 else {
        return [
            CustomHRZone(id: 1, lower: 0,   upper: 118),
            CustomHRZone(id: 2, lower: 120, upper: 140),
            CustomHRZone(id: 3, lower: 141, upper: 160),
            CustomHRZone(id: 4, lower: 161, upper: 180),
            CustomHRZone(id: 5, lower: 181, upper: 999),
        ]
    }
    return zones
}

fileprivate func encodeManualZones(_ zones: [CustomHRZone]) -> String {
    if let data = try? JSONEncoder().encode(zones),
       let s = String(data: data, encoding: .utf8) {
        return s
    }
    return manualZonesDefaultJSON
}

// MARK: - Heart Rate Zones View

struct HeartRateZonesView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("hr_zone_mode") private var rawMode = HRZoneMode.automatic.rawValue
    @AppStorage("profile_age")  private var ageString = "21"
    @AppStorage("hr_manual_zones_json") private var manualZonesJSON = manualZonesDefaultJSON

    @State private var manualZones: [CustomHRZone] = []
    @State private var selectedZone: CustomHRZone? = nil

    private var isManual: Bool { rawMode == HRZoneMode.manual.rawValue }

    private var age: Int {
        Int(ageString) ?? 21
    }

    private var maxHR: Int {
        HRZoneCalculator.maxHR(forAge: age)
    }

    private var zones: [CustomHRZone] {
        isManual ? manualZones : HRZoneCalculator.automaticZones(forAge: age)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 0) {
                        modeRow(title: "Automatic", selected: !isManual) {
                            rawMode = HRZoneMode.automatic.rawValue
                        }
                        Divider().padding(.horizontal, 16)
                        modeRow(title: "Manual", selected: isManual) {
                            rawMode = HRZoneMode.manual.rawValue
                        }
                    }
                    .background(Color.appLightGray)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    if !isManual {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Estimated Max HR")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.gray1)
                                Text("\(maxHR) bpm")
                                    .font(.system(size: 18, weight: .heavy))
                                    .gradientForeground()
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Based on age")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.gray1)
                                Text("\(age) years")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.appDarkText)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(LinearGradient.blueLinear.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Heart Rate Zones")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.appDarkText)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ForEach(Array(zones.enumerated()), id: \.element.id) { idx, zone in
                                zoneRow(zone: zone)
                                if idx < zones.count - 1 {
                                    Divider().padding(.horizontal, 16)
                                }
                            }
                        }
                        .background(Color.appLightGray)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                    }

                    Text(isManual
                         ? "Tap a zone to edit its lower and upper BPM limits. Hold + or – to change quickly."
                         : "Zones are calculated from your age using Max HR = 220 – age. Edit your age on the Profile page.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.gray1)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            manualZones = decodeManualZones(from: manualZonesJSON)
        }
        .onChange(of: manualZones) { _, newValue in
            manualZonesJSON = encodeManualZones(newValue)
        }
        .navigationDestination(item: $selectedZone) { zone in
            HeartRateZoneEditView(zone: zone) { updated, side in
                if let idx = manualZones.firstIndex(where: { $0.id == updated.id }) {
                    manualZones[idx] = updated
                    propagateBoundaries(editedIndex: idx, side: side)
                }
            }
        }
    }

    // MARK: - Mode Row

    func modeRow(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.gray1)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.gradientBlue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Zone Row

    @ViewBuilder
    func zoneRow(zone: CustomHRZone) -> some View {
        Button {
            if isManual {
                selectedZone = zone
            }
        } label: {
            HStack {
                HStack(spacing: 10) {
                    Circle()
                        .fill(HeartRateZone.allCases[zone.id - 1].color)
                        .frame(width: 10, height: 10)

                    Text(zone.label)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.gray1)
                }

                Spacer()

                Text(zone.rangeText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.appDarkText)

                if isManual {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.gray2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isManual)
    }

    // MARK: - Boundary propagation

    func propagateBoundaries(editedIndex: Int, side: EditedSide) {
        manualZones[0].lower = 0
        manualZones[manualZones.count - 1].upper = 999

        if side == .upper || side == .both {
            if editedIndex < manualZones.count - 1 {
                manualZones[editedIndex + 1].lower = manualZones[editedIndex].upper + 1
                if manualZones[editedIndex + 1].upper != 999,
                   manualZones[editedIndex + 1].lower > manualZones[editedIndex + 1].upper {
                    manualZones[editedIndex + 1].upper = manualZones[editedIndex + 1].lower
                }
            }
        }

        if side == .lower || side == .both {
            if editedIndex > 0 {
                manualZones[editedIndex - 1].upper = manualZones[editedIndex].lower - 1
                if manualZones[editedIndex - 1].upper < manualZones[editedIndex - 1].lower {
                    manualZones[editedIndex - 1].lower = manualZones[editedIndex - 1].upper
                }
            }
        }
    }
}

struct HeartRateZoneEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State var zone: CustomHRZone
    let onSave: (CustomHRZone, EditedSide) -> Void

    @State private var initialLower: Int = 0
    @State private var initialUpper: Int = 0

    private var showsLower: Bool { zone.id != 1 }
    private var showsUpper: Bool { zone.id != 5 }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    if showsLower {
                        limitSection(
                            title: "LOWER LIMIT",
                            value: Binding(
                                get: { zone.lower },
                                set: { zone.lower = $0 }
                            )
                        )
                    }

                    if showsUpper {
                        limitSection(
                            title: "UPPER LIMIT",
                            value: Binding(
                                get: { zone.upper },
                                set: { zone.upper = $0 }
                            )
                        )
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(zone.label)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            initialLower = zone.lower
            initialUpper = zone.upper
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let lowerChanged = zone.lower != initialLower
                    let upperChanged = zone.upper != initialUpper
                    let side: EditedSide
                    if lowerChanged && upperChanged { side = .both }
                    else if lowerChanged { side = .lower }
                    else { side = .upper }

                    onSave(zone, side)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(LinearGradient.purpleBlue)
                        .clipShape(Capsule())
                }
            }
        }
    }

    func limitSection(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.appDarkText)
                .padding(.horizontal, 20)

            HStack {
                Text("Beats per minute")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.gray1)

                Spacer()

                HStack(spacing: 16) {
                    HoldRepeatButton(
                        systemName: "minus.circle.fill",
                        tint: Color.gray2
                    ) {
                        if value.wrappedValue > 30 { value.wrappedValue -= 1 }
                    }

                    Text("\(value.wrappedValue)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.appDarkText)
                        .frame(minWidth: 36)

                    HoldRepeatButton(
                        systemName: "plus.circle.fill",
                        tint: Color.gradientBlue
                    ) {
                        if value.wrappedValue < 250 { value.wrappedValue += 1 }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.appLightGray)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
        }
    }
}

struct HoldRepeatButton: View {
    let systemName: String
    let tint: Color
    let action: () -> Void

    @State private var timer: Timer? = nil
    @State private var holdStart: Date? = nil
    @State private var isPressed = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 22))
            .foregroundStyle(tint)
            .scaleEffect(isPressed ? 1.15 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if timer == nil {
                            isPressed = true
                            action()
                            holdStart = Date()
                            scheduleNext(interval: 0.4)
                        }
                    }
                    .onEnded { _ in
                        stop()
                    }
            )
    }

    private func scheduleNext(interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            action()
            let held = Date().timeIntervalSince(holdStart ?? Date())
            let nextInterval: TimeInterval
            switch held {
            case ..<1.0:  nextInterval = 0.25
            case ..<2.0:  nextInterval = 0.12
            case ..<4.0:  nextInterval = 0.05
            default:      nextInterval = 0.02
            }
            scheduleNext(interval: nextInterval)
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        holdStart = nil
        isPressed = false
    }
}

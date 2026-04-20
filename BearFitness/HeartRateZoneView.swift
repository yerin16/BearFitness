//
//  HeartRateZoneView.swift
//  BearFitness
//
//  Created by christine j on 4/10/26.
//

import SwiftUI

// MARK: - Zone Mode

enum HRZoneMode: String {
    case automatic = "Automatic"
    case manual    = "Manual"
}

// MARK: - Custom Zone Model

struct CustomHRZone: Identifiable, Hashable {
    let id: Int          // 1–5
    var lower: Int
    var upper: Int       // 999 = unlimited / shown as "+"

    var label: String { "Zone \(id)" }

    var rangeText: String {
        if id == 1 { return "< \(upper + 1)" }
        if upper == 999 { return "\(lower)+" }
        return "\(lower) - \(upper)"
    }
}

// MARK: - Automatic Zone Calculator

struct HRZoneCalculator {
    // Standard formula: Max HR = 220 - age
    // Zones are percentages of Max HR:
    //   Zone 1: 50-60% | Zone 2: 60-70% | Zone 3: 70-80% | Zone 4: 80-90% | Zone 5: 90%+

    static func maxHR(forAge age: Int) -> Int {
        max(220 - age, 100) // floor at 100 to prevent nonsense values
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

// MARK: - Heart Rate Zones View

struct HeartRateZonesView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("hr_zone_mode") private var rawMode = HRZoneMode.automatic.rawValue
    @AppStorage("profile_age")  private var ageString = "21"   // shared with ProfileView

    @State private var manualZones: [CustomHRZone] = [
        CustomHRZone(id: 1, lower: 0,   upper: 118),
        CustomHRZone(id: 2, lower: 120, upper: 140),
        CustomHRZone(id: 3, lower: 141, upper: 160),
        CustomHRZone(id: 4, lower: 161, upper: 180),
        CustomHRZone(id: 5, lower: 181, upper: 999),
    ]

    @State private var selectedZone: CustomHRZone? = nil

    private var isManual: Bool { rawMode == HRZoneMode.manual.rawValue }

    private var age: Int {
        Int(ageString) ?? 21
    }

    private var maxHR: Int {
        HRZoneCalculator.maxHR(forAge: age)
    }

    // Zones shown to the user — either calculated or manually edited
    private var zones: [CustomHRZone] {
        isManual ? manualZones : HRZoneCalculator.automaticZones(forAge: age)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: - Automatic / Manual Card
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

                    // MARK: - Max HR Info (Automatic mode only)
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

                    // MARK: - Zones List
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

                    // Mode helper text
                    Text(isManual
                         ? "Tap a zone to edit its lower and upper BPM limits."
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.appLightGray)
                            .frame(width: 32, height: 32)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appDarkText)
                    }
                }
            }
        }
        .navigationDestination(item: $selectedZone) { zone in
            HeartRateZoneEditView(zone: zone) { updated in
                if let idx = manualZones.firstIndex(where: { $0.id == updated.id }) {
                    manualZones[idx] = updated
                    linkZoneBoundaries()
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isManual ? Color.gray2 : Color.gray2.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isManual)
    }

    // Keep neighbouring zones consistent after an edit
    func linkZoneBoundaries() {
        for i in 1..<manualZones.count {
            manualZones[i].lower = manualZones[i - 1].upper + 1
        }
        manualZones[manualZones.count - 1].upper = 999
    }
}

// MARK: - Per-Zone Edit View

struct HeartRateZoneEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State var zone: CustomHRZone
    let onSave: (CustomHRZone) -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // LOWER LIMIT
                    limitSection(
                        title: "LOWER LIMIT",
                        value: Binding(
                            get: { zone.lower },
                            set: { zone.lower = $0 }
                        )
                    )

                    // UPPER LIMIT (hidden for Zone 5 — it's unlimited)
                    if zone.id < 5 {
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.appLightGray)
                            .frame(width: 32, height: 32)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appDarkText)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onSave(zone)
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

    // MARK: - Limit Section

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
                    Button {
                        if value.wrappedValue > 30 { value.wrappedValue -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.gray2)
                    }

                    Text("\(value.wrappedValue)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.appDarkText)
                        .frame(minWidth: 36)

                    Button {
                        if value.wrappedValue < 250 { value.wrappedValue += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.gradientBlue)
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

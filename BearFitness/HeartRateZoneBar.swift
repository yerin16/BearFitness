//
//  HeartRateZoneBar.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import SwiftUI

// MARK: - Heart Rate Zone

enum HeartRateZone: CaseIterable {
    case zone1, zone2, zone3, zone4, zone5

    var label: String {
        switch self {
        case .zone1: return "Zone 1"
        case .zone2: return "Zone 2"
        case .zone3: return "Zone 3"
        case .zone4: return "Zone 4"
        case .zone5: return "Zone 5"
        }
    }

    var shortLabel: String {
        switch self {
        case .zone1: return "Z1"
        case .zone2: return "Z2"
        case .zone3: return "Z3"
        case .zone4: return "Z4"
        case .zone5: return "Z5"
        }
    }

    var subtitle: String {
        switch self {
        case .zone1: return "Very Light"
        case .zone2: return "Light"
        case .zone3: return "Moderate"
        case .zone4: return "Hard"
        case .zone5: return "Maximum"
        }
    }

    var color: Color {
        switch self {
        case .zone1: return Color(red: 0.00, green: 0.72, blue: 0.90)
        case .zone2: return Color(red: 0.00, green: 0.80, blue: 0.35)
        case .zone3: return Color(red: 0.85, green: 0.80, blue: 0.00)
        case .zone4: return Color(red: 1.00, green: 0.60, blue: 0.00)
        case .zone5: return Color(red: 1.00, green: 0.18, blue: 0.33)
        }
    }

    /// 1–5 for display ("Zone 1", "Zone 1–2", …).
    var zoneNumber: Int {
        switch self {
        case .zone1: return 1
        case .zone2: return 2
        case .zone3: return 3
        case .zone4: return 4
        case .zone5: return 5
        }
    }

    /// BPM bounds aligned with `from(bpm:)` — single source of truth for targets.
    /// Z1 &lt; 100, Z2 100–119, Z3 120–139, Z4 140–159, Z5 160+.
    var bpmBounds: ClosedRange<Double> {
        switch self {
        case .zone1: return 50...99
        case .zone2: return 100...119
        case .zone3: return 120...139
        case .zone4: return 140...159
        case .zone5: return 160...220
        }
    }

    /// Merges one or more contiguous zones into one BPM range (e.g. Z1+Z2 → 50…119).
    static func mergedBPMRange(_ zones: [HeartRateZone]) -> ClosedRange<Double> {
        guard !zones.isEmpty else { return 0...0 }
        let lows = zones.map { $0.bpmBounds.lowerBound }
        let highs = zones.map { $0.bpmBounds.upperBound }
        return (lows.min() ?? 0)...(highs.max() ?? 0)
    }

    // Standard 5-zone model with ~200 bpm max HR baseline:
    // Z1 < 100, Z2 100–119, Z3 120–139, Z4 140–159, Z5 160+
    static func from(bpm: Double) -> HeartRateZone {
        switch bpm {
        case ..<100:    return .zone1
        case 100..<120: return .zone2
        case 120..<140: return .zone3
        case 140..<160: return .zone4
        default:        return .zone5
        }
    }
}

// MARK: - Heart Rate Zone Bar

struct HeartRateZoneBar: View {
    let heartRates: [(date: Date, bpm: Double)]

    var zones: [(zone: HeartRateZone, count: Int)] {
        HeartRateZone.allCases.map { zone in
            let count = heartRates.filter { HeartRateZone.from(bpm: $0.bpm) == zone }.count
            return (zone: zone, count: count)
        }
    }

    var total: Int { heartRates.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate Zones")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appDarkText)

            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(zones, id: \.zone) { item in
                        if item.count > 0 {
                            Rectangle()
                                .fill(item.zone.color)
                                .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(max(total, 1)))
                                .cornerRadius(3)
                        }
                    }
                }
            }
            .frame(height: 14)

            // Explicit colors needed here — .secondary breaks in dark mode
            VStack(spacing: 6) {
                ForEach(zones, id: \.zone) { item in
                    if item.count > 0 {
                        HStack {
                            Circle()
                                .fill(item.zone.color)
                                .frame(width: 10, height: 10)

                            Text(item.zone.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.appDarkText)

                            Text(item.zone.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.gray1)

                            Spacer()

                            Text(percentString(item.count))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.appDarkText)
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    func percentString(_ count: Int) -> String {
        guard total > 0 else { return "0%" }
        let pct = Double(count) / Double(total) * 100
        return String(format: "%.0f%%", pct)
    }
}

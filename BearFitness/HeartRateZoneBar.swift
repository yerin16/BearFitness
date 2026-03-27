//
//  HeartRateZoneBar.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import SwiftUI

// MARK: - Heart Rate Zone Model
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
        case .zone1: return Color(red: 0.55, green: 0.55, blue: 0.55) // Gray
        case .zone2: return Color(red: 0.30, green: 0.70, blue: 0.90) // Light blue
        case .zone3: return Color(red: 0.30, green: 0.80, blue: 0.40) // Green
        case .zone4: return Color(red: 1.00, green: 0.65, blue: 0.00) // Orange
        case .zone5: return Color(red: 0.90, green: 0.20, blue: 0.20) // Red
        }
    }

    /// Determine zone from BPM
    /// Standard 5-zone model (% of max HR ~200 as baseline):
    /// Z1: < 100, Z2: 100–119, Z3: 120–139, Z4: 140–159, Z5: 160+
    static func from(bpm: Double) -> HeartRateZone {
        switch bpm {
        case ..<100:  return .zone1
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
                .foregroundStyle(Color.darkText)

            // Colored bar
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

            // Zone labels with explicit colors (no .secondary — fixes dark mode)
            VStack(spacing: 6) {
                ForEach(zones, id: \.zone) { item in
                    if item.count > 0 {
                        HStack {
                            Circle()
                                .fill(item.zone.color)
                                .frame(width: 10, height: 10)

                            Text(item.zone.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.darkText)

                            Text(item.zone.subtitle)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.gray1)

                            Spacer()

                            Text(percentString(item.count))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.darkText)
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

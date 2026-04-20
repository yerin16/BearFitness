//
//  WorkoutAnalysisRecord.swift
//  BearFitness
//

import SwiftUI
import SwiftData

// Lightweight snapshot of one program section, stored as JSON inside the record.
// Used to draw the target-zone overlay on the HR chart.
struct SectionOverlayData: Codable, Identifiable {
    var id: UUID = UUID()
    var phaseRawValue: String
    var startDate: Date
    var endDate: Date
    var targetLow: Double
    var targetHigh: Double

    var phase: WorkoutPhase? { WorkoutPhase(rawValue: phaseRawValue) }

    var midDate: Date {
        Date(timeIntervalSince1970: (startDate.timeIntervalSince1970 + endDate.timeIntervalSince1970) / 2)
    }
}

@Model
final class WorkoutAnalysisRecord {
    var workoutUUID: String
    var matchedSessionName: String
    var matchedSessionDate: Date
    var matchRate: Double
    var totalPoints: Int
    var maxPoints: Int
    var hrGrade: String
    var analyzedAt: Date
    // JSON-encoded [SectionOverlayData] — nil for records saved before this feature
    var sectionsData: Data?

    init(
        workoutUUID: String,
        matchedSessionName: String,
        matchedSessionDate: Date,
        matchRate: Double,
        totalPoints: Int,
        maxPoints: Int,
        hrGrade: String,
        sectionsData: Data? = nil
    ) {
        self.workoutUUID = workoutUUID
        self.matchedSessionName = matchedSessionName
        self.matchedSessionDate = matchedSessionDate
        self.matchRate = matchRate
        self.totalPoints = totalPoints
        self.maxPoints = maxPoints
        self.hrGrade = hrGrade
        self.analyzedAt = Date()
        self.sectionsData = sectionsData
    }

    var sectionOverlays: [SectionOverlayData] {
        guard let data = sectionsData else { return [] }
        return (try? JSONDecoder().decode([SectionOverlayData].self, from: data)) ?? []
    }

    var matchRateString: String { String(format: "%.0f%%", matchRate * 100) }

    var hrGradeColor: Color {
        switch hrGrade {
        case "S": return Color(red: 0.55, green: 0.20, blue: 0.98)
        case "A": return .green
        case "B": return Color(red: 0.00, green: 0.72, blue: 0.90)
        case "C": return .orange
        default:  return .red
        }
    }

}

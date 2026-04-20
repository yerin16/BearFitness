//
//  BearFitnessApp.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import SwiftUI
import SwiftData
 
@main
struct BearFitnessApp: App {
    let container: ModelContainer
 
    @AppStorage("has_onboarded") private var hasOnboarded = false
 
    init() {
        do {
            let schema = Schema([HIITProgram.self, WorkoutSession.self, WorkoutAnalysisRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
 
    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
        }
        .modelContainer(container)
    }
}

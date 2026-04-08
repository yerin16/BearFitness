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
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [HIITProgram.self, WorkoutSession.self])
    }
}

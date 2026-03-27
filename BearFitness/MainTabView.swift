//
//  MainTabView.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import SwiftUI

enum AppTab: Int, CaseIterable {
    case home, workout, program, profile

    var title: String {
        switch self {
        case .home:    return "Home"
        case .workout: return "Workout"
        case .program: return "Program"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home:    return "house"
        case .workout: return "figure.run"
        case .program: return "doc.text"
        case .profile: return "person"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .workout

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home (blank for now)
            NavigationStack {
                Text("Home")
                    .foregroundStyle(.secondary)
                    .navigationTitle("Home")
            }
            .tag(AppTab.home)
            .tabItem {
                Image(systemName: AppTab.home.icon)
                Text(AppTab.home.title)
            }

            // Workout (our main screen)
            WorkoutListView()
                .tag(AppTab.workout)
                .tabItem {
                    Image(systemName: AppTab.workout.icon)
                    Text(AppTab.workout.title)
                }

            // Program (blank for now)
            NavigationStack {
                Text("Program")
                    .foregroundStyle(.secondary)
                    .navigationTitle("Program")
            }
            .tag(AppTab.program)
            .tabItem {
                Image(systemName: AppTab.program.icon)
                Text(AppTab.program.title)
            }

            // Profile (blank for now)
            NavigationStack {
                Text("Profile")
                    .foregroundStyle(.secondary)
                    .navigationTitle("Profile")
            }
            .tag(AppTab.profile)
            .tabItem {
                Image(systemName: AppTab.profile.icon)
                Text(AppTab.profile.title)
            }
        }
        .tint(Color.gradientBlue)
    }
}

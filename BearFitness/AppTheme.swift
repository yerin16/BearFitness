//
//  AppTheme.swift
//  BearFitness
//
//  Created by Yerin Kang on 3/27/26.
//

import SwiftUI

// MARK: - Gradient Presets

extension LinearGradient {
    static let purpleBlue = LinearGradient(
        colors: [Color.gradientBlue, Color.gradientPurple],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let blueLinear = LinearGradient(
        colors: [Color.gradientBlue, Color.gradientLightBlue],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Card Shadow

extension View {
    func cardShadow() -> some View {
        self.shadow(
            color: Color(red: 0x1D/255, green: 0x16/255, blue: 0x17/255).opacity(0.07),
            radius: 20,
            x: 0,
            y: 10
        )
    }
}

// MARK: - Gradient Text

struct GradientText: ViewModifier {
    var gradient: LinearGradient

    func body(content: Content) -> some View {
        content
            .overlay(gradient)
            .mask(content)
    }
}

extension View {
    func gradientForeground(_ gradient: LinearGradient = .purpleBlue) -> some View {
        self.modifier(GradientText(gradient: gradient))
    }
}

// MARK: - Font Tokens

extension Font {
    static let workoutTitle     = Font.system(size: 24, weight: .heavy)
    static let workoutTypeLarge = Font.system(size: 25, weight: .bold)
    static let workoutTypeSmall = Font.system(size: 15, weight: .bold)
    static let durationLarge    = Font.system(size: 30, weight: .heavy)
    static let durationSmall    = Font.system(size: 25, weight: .heavy)
    static let statLabel        = Font.system(size: 14, weight: .regular)
    static let statValue        = Font.system(size: 30, weight: .heavy)
    static let dateCaption      = Font.system(size: 14, weight: .regular)
    static let dateCaptionSmall = Font.system(size: 12, weight: .regular)
    static let sectionHeader    = Font.system(size: 18, weight: .bold)
    static let tabLabel         = Font.system(size: 12, weight: .medium)
    static let pointsBadge      = Font.system(size: 16, weight: .heavy)
    static let bannerText       = Font.system(size: 12, weight: .medium)
}

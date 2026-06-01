//
//  Theme.swift
//  RecipeBox
//

import SwiftUI

/// Centralized design tokens for the warm cookbook aesthetic.
enum Theme {
    // Warm paper background
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let paperRaised = Color(red: 1.0, green: 0.99, blue: 0.96)

    // Spice accent palette
    static let spice = Color(red: 0.78, green: 0.33, blue: 0.20)        // terracotta/paprika
    static let spiceDeep = Color(red: 0.55, green: 0.21, blue: 0.13)
    static let amber = Color(red: 0.93, green: 0.62, blue: 0.24)
    static let sage = Color(red: 0.42, green: 0.55, blue: 0.40)
    static let cream = Color(red: 1.0, green: 0.97, blue: 0.90)

    // Text
    static let ink = Color(red: 0.20, green: 0.16, blue: 0.13)
    static let inkSoft = Color(red: 0.42, green: 0.37, blue: 0.32)

    static let cardShadow = Color.black.opacity(0.08)

    static var warmGradient: LinearGradient {
        LinearGradient(
            colors: [spice, amber],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Font {
    /// Serif display font for headings, giving an editorial cookbook feel.
    static func cookbookTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .serif)
    }

    static func cookbookSerif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

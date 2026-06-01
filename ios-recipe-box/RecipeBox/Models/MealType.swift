//
//  MealType.swift
//  RecipeBox
//

import SwiftUI

/// Which part of the day a logged food belongs to.
enum MealType: String, CaseIterable, Identifiable, Codable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }

    var tint: Color {
        switch self {
        case .breakfast: return Theme.amber
        case .lunch: return Theme.sage
        case .dinner: return Theme.spice
        case .snack: return Color(red: 0.62, green: 0.49, blue: 0.78)
        }
    }

    /// Picks the most likely meal type for a given time of day.
    static func suggested(for date: Date = .now) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 4..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snack
        default: return .dinner
        }
    }
}

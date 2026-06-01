//
//  RecipeCategory.swift
//  RecipeBox
//

import SwiftUI

/// High-level recipe categories used for filtering and browsing.
enum RecipeCategory: String, CaseIterable, Identifiable, Codable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case dessert = "Dessert"
    case snack = "Snacks"
    case drink = "Drinks"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "takeoutbag.and.cup.and.straw.fill"
        case .dinner: return "fork.knife"
        case .dessert: return "birthday.cake.fill"
        case .snack: return "popcorn.fill"
        case .drink: return "cup.and.saucer.fill"
        }
    }

    var tint: Color {
        switch self {
        case .breakfast: return Color(red: 0.95, green: 0.66, blue: 0.27)
        case .lunch: return Color(red: 0.40, green: 0.62, blue: 0.40)
        case .dinner: return Color(red: 0.78, green: 0.36, blue: 0.24)
        case .dessert: return Color(red: 0.84, green: 0.46, blue: 0.58)
        case .snack: return Color(red: 0.62, green: 0.49, blue: 0.78)
        case .drink: return Color(red: 0.36, green: 0.58, blue: 0.68)
        }
    }
}

/// Grocery aisles used to organize shopping lists and ingredients.
enum GroceryAisle: String, CaseIterable, Identifiable, Codable {
    case produce = "Produce"
    case meat = "Meat & Seafood"
    case dairy = "Dairy & Eggs"
    case bakery = "Bakery"
    case pantry = "Pantry"
    case frozen = "Frozen"
    case spices = "Spices"
    case beverages = "Beverages"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .produce: return "carrot.fill"
        case .meat: return "fish.fill"
        case .dairy: return "drop.fill"
        case .bakery: return "birthday.cake.fill"
        case .pantry: return "cabinet.fill"
        case .frozen: return "snowflake"
        case .spices: return "leaf.fill"
        case .beverages: return "cup.and.saucer.fill"
        case .other: return "bag.fill"
        }
    }

    /// Display sort order so aisles group naturally on the list.
    var order: Int {
        GroceryAisle.allCases.firstIndex(of: self) ?? 99
    }
}

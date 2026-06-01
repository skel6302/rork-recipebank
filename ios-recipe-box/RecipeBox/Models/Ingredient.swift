//
//  Ingredient.swift
//  RecipeBox
//

import Foundation
import SwiftData

/// A single ingredient line belonging to a recipe.
@Model
final class Ingredient {
    var name: String
    var quantity: String
    var aisleRaw: String
    var sortIndex: Int

    init(name: String, quantity: String = "", aisle: GroceryAisle = .other, sortIndex: Int = 0) {
        self.name = name
        self.quantity = quantity
        self.aisleRaw = aisle.rawValue
        self.sortIndex = sortIndex
    }

    var aisle: GroceryAisle {
        get { GroceryAisle(rawValue: aisleRaw) ?? .other }
        set { aisleRaw = newValue.rawValue }
    }

    /// A clean single-line label like "2 cups flour".
    var displayLine: String {
        quantity.isEmpty ? name : "\(quantity) \(name)"
    }
}

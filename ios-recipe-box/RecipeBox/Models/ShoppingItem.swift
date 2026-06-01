//
//  ShoppingItem.swift
//  RecipeBox
//

import Foundation
import SwiftData

/// An item on the user's shopping list, optionally sourced from a recipe.
@Model
final class ShoppingItem {
    var name: String
    var quantity: String
    var aisleRaw: String
    var isChecked: Bool
    var sourceRecipeTitle: String?
    var addedAt: Date

    init(
        name: String,
        quantity: String = "",
        aisle: GroceryAisle = .other,
        isChecked: Bool = false,
        sourceRecipeTitle: String? = nil,
        addedAt: Date = .now
    ) {
        self.name = name
        self.quantity = quantity
        self.aisleRaw = aisle.rawValue
        self.isChecked = isChecked
        self.sourceRecipeTitle = sourceRecipeTitle
        self.addedAt = addedAt
    }

    var aisle: GroceryAisle {
        get { GroceryAisle(rawValue: aisleRaw) ?? .other }
        set { aisleRaw = newValue.rawValue }
    }

    var displayLine: String {
        quantity.isEmpty ? name : "\(quantity) \(name)"
    }
}

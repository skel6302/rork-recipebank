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

    /// Stable cloud identifier, assigned on first sync so the row follows the user across devices.
    var remoteID: String?
    /// Last local edit time, used for last-write-wins conflict resolution during sync.
    var updatedAt: Date = Date()

    init(
        name: String,
        quantity: String = "",
        aisle: GroceryAisle = .other,
        isChecked: Bool = false,
        sourceRecipeTitle: String? = nil,
        addedAt: Date = .now,
        remoteID: String? = nil,
        updatedAt: Date = .now
    ) {
        self.name = name
        self.quantity = quantity
        self.aisleRaw = aisle.rawValue
        self.isChecked = isChecked
        self.sourceRecipeTitle = sourceRecipeTitle
        self.addedAt = addedAt
        self.remoteID = remoteID
        self.updatedAt = updatedAt
    }

    var aisle: GroceryAisle {
        get { GroceryAisle(rawValue: aisleRaw) ?? .other }
        set { aisleRaw = newValue.rawValue }
    }

    var displayLine: String {
        quantity.isEmpty ? name : "\(quantity) \(name)"
    }
}

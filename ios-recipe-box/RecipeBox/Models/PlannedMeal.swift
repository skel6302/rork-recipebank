//
//  PlannedMeal.swift
//  RecipeBox
//

import Foundation
import SwiftData

/// A recipe (or free-text entry) assigned to a specific day and meal slot in the
/// weekly meal planner. Mirrors the AnyList-style "plan your week" experience.
@Model
final class PlannedMeal {
    /// The day this meal is planned for, normalized to the start of the day.
    var dayStart: Date

    /// Which meal slot of the day this belongs to.
    var mealTypeRaw: String

    /// Ordering within a single day/meal slot (multiple recipes can share a slot).
    var sortIndex: Int

    /// The recipe assigned to this slot, if any. Optional so a planned meal can be a
    /// quick free-text note, and so deleting a recipe nullifies the link gracefully.
    @Relationship var recipe: Recipe?

    /// A free-text title used when no recipe is attached (e.g. "Leftovers", "Eat out").
    var customTitle: String?

    // MARK: - Standalone food item
    // When a slot holds a single food (e.g. "a bagel") rather than a recipe, these
    // capture its name and nutrition so the planner isn't limited to recipes.

    /// The food's display name. Non-nil marks this slot as a food entry.
    var foodName: String?
    /// Human-readable serving, e.g. "1 medium" or "100 g".
    var foodServing: String?
    var foodCalories: Int = 0
    var foodProtein: Double = 0
    var foodCarbs: Double = 0
    var foodFat: Double = 0

    var createdAt: Date

    /// Stable cloud identifier, assigned on first sync so the slot follows the user across devices.
    var remoteID: String?
    /// Last local edit time, used for last-write-wins conflict resolution during sync.
    var updatedAt: Date = Date()

    init(
        dayStart: Date,
        mealType: MealType,
        sortIndex: Int = 0,
        recipe: Recipe? = nil,
        customTitle: String? = nil,
        foodName: String? = nil,
        foodServing: String? = nil,
        foodCalories: Int = 0,
        foodProtein: Double = 0,
        foodCarbs: Double = 0,
        foodFat: Double = 0,
        createdAt: Date = .now,
        remoteID: String? = nil,
        updatedAt: Date = .now
    ) {
        self.dayStart = Calendar.current.startOfDay(for: dayStart)
        self.mealTypeRaw = mealType.rawValue
        self.sortIndex = sortIndex
        self.recipe = recipe
        self.customTitle = customTitle
        self.foodName = foodName
        self.foodServing = foodServing
        self.foodCalories = foodCalories
        self.foodProtein = foodProtein
        self.foodCarbs = foodCarbs
        self.foodFat = foodFat
        self.createdAt = createdAt
        self.remoteID = remoteID
        self.updatedAt = updatedAt
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .dinner }
        set { mealTypeRaw = newValue.rawValue }
    }

    /// What to show on the planner card.
    var displayTitle: String {
        recipe?.title ?? foodName ?? customTitle ?? "Meal"
    }

    /// True when this slot holds a standalone food item rather than a recipe.
    var isFood: Bool { recipe == nil && foodName != nil }
}

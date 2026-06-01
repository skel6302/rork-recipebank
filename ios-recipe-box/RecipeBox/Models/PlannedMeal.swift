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

    var createdAt: Date

    init(
        dayStart: Date,
        mealType: MealType,
        sortIndex: Int = 0,
        recipe: Recipe? = nil,
        customTitle: String? = nil,
        createdAt: Date = .now
    ) {
        self.dayStart = Calendar.current.startOfDay(for: dayStart)
        self.mealTypeRaw = mealType.rawValue
        self.sortIndex = sortIndex
        self.recipe = recipe
        self.customTitle = customTitle
        self.createdAt = createdAt
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .dinner }
        set { mealTypeRaw = newValue.rawValue }
    }

    /// What to show on the planner card.
    var displayTitle: String {
        recipe?.title ?? customTitle ?? "Meal"
    }
}

//
//  FoodEntry.swift
//  RecipeBox
//

import Foundation
import SwiftData

/// A single logged food/meal with its nutrition, optionally captured from a photo
/// and analyzed by AI. Powers the calorie tracker.
@Model
final class FoodEntry {
    var name: String
    var mealTypeRaw: String
    var servingDescription: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var loggedAt: Date

    /// Whether the values were produced by the AI photo/recipe analyzer.
    var wasAIEstimated: Bool

    /// The photo of the food, if logged by camera or library. Stored externally so
    /// large blobs don't bloat the SwiftData store.
    @Attribute(.externalStorage) var photoData: Data?

    init(
        name: String,
        mealType: MealType = .snack,
        servingDescription: String = "",
        calories: Int = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        loggedAt: Date = .now,
        wasAIEstimated: Bool = false,
        photoData: Data? = nil
    ) {
        self.name = name
        self.mealTypeRaw = mealType.rawValue
        self.servingDescription = servingDescription
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.loggedAt = loggedAt
        self.wasAIEstimated = wasAIEstimated
        self.photoData = photoData
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }
}

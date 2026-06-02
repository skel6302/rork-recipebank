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

    /// How much of a full serving was eaten (1.0 = full, 0.5 = half, etc.).
    /// `calories`/`protein`/`carbs`/`fat` already reflect this portion; dividing
    /// by `portion` recovers the per-serving base used when re-scaling.
    var portion: Double = 1.0

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
        photoData: Data? = nil,
        portion: Double = 1.0
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
        self.portion = portion
    }

    /// Per-serving (full portion) calories, derived from the consumed amount.
    var baseCalories: Double { portion > 0 ? Double(calories) / portion : Double(calories) }
    var baseProtein: Double { portion > 0 ? protein / portion : protein }
    var baseCarbs: Double { portion > 0 ? carbs / portion : carbs }
    var baseFat: Double { portion > 0 ? fat / portion : fat }

    /// Rescales the consumed nutrition to a new portion, keeping the per-serving base.
    func applyPortion(_ newPortion: Double) {
        let base = (
            cal: baseCalories,
            protein: baseProtein,
            carbs: baseCarbs,
            fat: baseFat
        )
        portion = newPortion
        calories = Int((base.cal * newPortion).rounded())
        protein = (base.protein * newPortion * 10).rounded() / 10
        carbs = (base.carbs * newPortion * 10).rounded() / 10
        fat = (base.fat * newPortion * 10).rounded() / 10
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }
}

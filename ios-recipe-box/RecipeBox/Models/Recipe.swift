//
//  Recipe.swift
//  RecipeBox
//

import Foundation
import SwiftData

/// A single recipe with its metadata, ingredients, and step-by-step instructions.
@Model
final class Recipe {
    var title: String
    var summary: String
    var categoryRaw: String
    var servings: Int
    var prepMinutes: Int
    var cookMinutes: Int
    var rating: Int
    var isFavorite: Bool
    var imageName: String?
    var notes: String
    var createdAt: Date

    /// A photo of the original source recipe (e.g. grandma's handwritten card or a
    /// HelloFresh card) preserved alongside the digitized version. Stored externally
    /// so large image blobs don't bloat the SwiftData store.
    @Attribute(.externalStorage) var originalPhotoData: Data?

    /// A photo of the finished dish, chosen by the user from the photo library or
    /// camera. Shown on the recipe card and detail hero. Stored externally so the
    /// SwiftData store stays small.
    @Attribute(.externalStorage) var photoData: Data?

    /// Whether this recipe was created by scanning a physical source.
    var wasScanned: Bool

    /// Ingredients stored in display order.
    @Relationship(deleteRule: .cascade)
    var ingredients: [Ingredient]

    /// Ordered cooking steps.
    var steps: [String]

    init(
        title: String,
        summary: String = "",
        category: RecipeCategory = .dinner,
        servings: Int = 2,
        prepMinutes: Int = 10,
        cookMinutes: Int = 20,
        rating: Int = 0,
        isFavorite: Bool = false,
        imageName: String? = nil,
        notes: String = "",
        ingredients: [Ingredient] = [],
        steps: [String] = [],
        createdAt: Date = .now,
        originalPhotoData: Data? = nil,
        photoData: Data? = nil,
        wasScanned: Bool = false
    ) {
        self.title = title
        self.summary = summary
        self.categoryRaw = category.rawValue
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.rating = rating
        self.isFavorite = isFavorite
        self.imageName = imageName
        self.notes = notes
        self.ingredients = ingredients
        self.steps = steps
        self.createdAt = createdAt
        self.originalPhotoData = originalPhotoData
        self.photoData = photoData
        self.wasScanned = wasScanned
    }

    var category: RecipeCategory {
        get { RecipeCategory(rawValue: categoryRaw) ?? .dinner }
        set { categoryRaw = newValue.rawValue }
    }

    var totalMinutes: Int { prepMinutes + cookMinutes }

    /// The best photo to represent this recipe visually: a chosen dish photo if
    /// available, otherwise the scanned source photo.
    var displayPhotoData: Data? { photoData ?? originalPhotoData }
}

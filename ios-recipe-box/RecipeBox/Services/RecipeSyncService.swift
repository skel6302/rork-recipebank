//
//  RecipeSyncService.swift
//  RecipeBox
//

import Foundation
import SwiftData

// MARK: - Cloud DTOs

/// An ingredient as stored inside the recipe's `ingredients` JSON column.
nonisolated struct RemoteIngredient: Codable, Sendable {
    let name: String
    let quantity: String
    let aisle: String
    let sortIndex: Int

    enum CodingKeys: String, CodingKey {
        case name
        case quantity
        case aisle
        case sortIndex = "sort_index"
    }
}

/// A recipe row read back from Supabase.
nonisolated struct RemoteRecipe: Codable, Sendable {
    let id: UUID
    let title: String
    let summary: String
    let category: String
    let servings: Int
    let prepMinutes: Int
    let cookMinutes: Int
    let rating: Int
    let isFavorite: Bool
    let notes: String
    let steps: [String]
    let ingredients: [RemoteIngredient]
    let photoBase64: String?
    let originalPhotoBase64: String?
    let originalPhotoPages: [String]?
    let wasScanned: Bool
    let deleted: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case category
        case servings
        case prepMinutes = "prep_minutes"
        case cookMinutes = "cook_minutes"
        case rating
        case isFavorite = "is_favorite"
        case notes
        case steps
        case ingredients
        case photoBase64 = "photo_base64"
        case originalPhotoBase64 = "original_photo_base64"
        case originalPhotoPages = "original_photo_pages"
        case wasScanned = "was_scanned"
        case deleted
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// A recipe payload written to Supabase via upsert.
nonisolated struct RemoteRecipeUpsert: Encodable, Sendable {
    let id: UUID
    let userId: String
    let title: String
    let summary: String
    let category: String
    let servings: Int
    let prepMinutes: Int
    let cookMinutes: Int
    let rating: Int
    let isFavorite: Bool
    let notes: String
    let steps: [String]
    let ingredients: [RemoteIngredient]
    let photoBase64: String?
    let originalPhotoBase64: String?
    let originalPhotoPages: [String]?
    let wasScanned: Bool
    let deleted: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case summary
        case category
        case servings
        case prepMinutes = "prep_minutes"
        case cookMinutes = "cook_minutes"
        case rating
        case isFavorite = "is_favorite"
        case notes
        case steps
        case ingredients
        case photoBase64 = "photo_base64"
        case originalPhotoBase64 = "original_photo_base64"
        case originalPhotoPages = "original_photo_pages"
        case wasScanned = "was_scanned"
        case deleted
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated struct ProfileUpsert: Encodable, Sendable {
    let id: String
    let email: String
    let name: String
}

nonisolated struct RecipeTombstone: Encodable, Sendable {
    let deleted: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case deleted
        case updatedAt = "updated_at"
    }
}

// MARK: - Shopping item DTOs

nonisolated struct RemoteShoppingItem: Codable, Sendable {
    let id: UUID
    let name: String
    let quantity: String
    let aisle: String
    let isChecked: Bool
    let sourceRecipeTitle: String?
    let addedAt: Date
    let deleted: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case aisle
        case isChecked = "is_checked"
        case sourceRecipeTitle = "source_recipe_title"
        case addedAt = "added_at"
        case deleted
        case updatedAt = "updated_at"
    }
}

nonisolated struct RemoteShoppingItemUpsert: Encodable, Sendable {
    let id: UUID
    let userId: String
    let name: String
    let quantity: String
    let aisle: String
    let isChecked: Bool
    let sourceRecipeTitle: String?
    let addedAt: Date
    let deleted: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case quantity
        case aisle
        case isChecked = "is_checked"
        case sourceRecipeTitle = "source_recipe_title"
        case addedAt = "added_at"
        case deleted
        case updatedAt = "updated_at"
    }
}

// MARK: - Planned meal DTOs

nonisolated struct RemotePlannedMeal: Codable, Sendable {
    let id: UUID
    let dayStart: Date
    let mealType: String
    let sortIndex: Int
    let recipeId: UUID?
    let customTitle: String?
    let createdAt: Date
    let deleted: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case dayStart = "day_start"
        case mealType = "meal_type"
        case sortIndex = "sort_index"
        case recipeId = "recipe_id"
        case customTitle = "custom_title"
        case createdAt = "created_at"
        case deleted
        case updatedAt = "updated_at"
    }
}

nonisolated struct RemotePlannedMealUpsert: Encodable, Sendable {
    let id: UUID
    let userId: String
    let dayStart: Date
    let mealType: String
    let sortIndex: Int
    let recipeId: UUID?
    let customTitle: String?
    let createdAt: Date
    let deleted: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case dayStart = "day_start"
        case mealType = "meal_type"
        case sortIndex = "sort_index"
        case recipeId = "recipe_id"
        case customTitle = "custom_title"
        case createdAt = "created_at"
        case deleted
        case updatedAt = "updated_at"
    }
}

// MARK: - Sync Service

/// Two-way syncs the local SwiftData recipe store with the Supabase cloud so
/// recipes follow the signed-in user across devices.
@Observable
final class RecipeSyncService {
    enum SyncState: Equatable {
        case idle
        case syncing
        case synced
        case error
    }

    var state: SyncState = .idle
    var lastSyncedAt: Date?

    private let auth: AuthManager
    private var container: ModelContainer?
    private var isSyncing = false
    private var didUpsertProfile = false

    init(auth: AuthManager) {
        self.auth = auth
    }

    func attach(_ container: ModelContainer) {
        self.container = container
    }

    /// Full two-way sync: ensures the profile exists, pulls remote changes,
    /// then pushes any newer local recipes.
    @MainActor
    func syncNow() async {
        guard let user = auth.user, let container else { return }
        if isSyncing { return }
        isSyncing = true
        state = .syncing
        defer { isSyncing = false }

        let context = container.mainContext

        do {
            try await ensureProfile(user)

            // 1. Fetch the full remote set.
            let remote: [RemoteRecipe] = try await Supabase.select("recipes")
            let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

            // 2. Load local recipes and ensure each has a stable remote id.
            var locals = try context.fetch(FetchDescriptor<Recipe>())
            var localByID: [UUID: Recipe] = [:]
            for recipe in locals {
                let uuid = ensureRemoteID(recipe)
                localByID[uuid] = recipe
            }

            // 3. Pull: apply remote rows onto local store.
            for row in remote {
                if let local = localByID[row.id] {
                    if row.deleted {
                        context.delete(local)
                        localByID[row.id] = nil
                    } else if row.updatedAt > local.updatedAt {
                        apply(row, to: local)
                    }
                } else if !row.deleted {
                    let newRecipe = makeRecipe(from: row)
                    context.insert(newRecipe)
                    localByID[row.id] = newRecipe
                }
            }

            // 4. Push: upload locals that are missing remotely or newer locally.
            locals = try context.fetch(FetchDescriptor<Recipe>())
            var toUpsert: [RemoteRecipeUpsert] = []
            for recipe in locals {
                let uuid = ensureRemoteID(recipe)
                let remoteRow = remoteByID[uuid]
                let isNewer = remoteRow == nil
                    || (!remoteRow!.deleted && recipe.updatedAt > remoteRow!.updatedAt)
                if isNewer {
                    toUpsert.append(makeUpsert(recipe, uuid: uuid, userId: user.id))
                }
            }

            try await Supabase.upsert("recipes", values: toUpsert)

            // 5. Sync the shopping list and weekly meal plan too.
            try await syncShoppingItems(user: user, context: context)
            try await syncPlannedMeals(user: user, context: context, localRecipesByRemoteID: localByID)

            try context.save()
            lastSyncedAt = Date()
            state = .synced
        } catch {
            print("RecipeSync failed: \(error)")
            state = .error
        }
    }

    /// Soft-deletes a recipe in the cloud so the deletion propagates to other
    /// devices. Safe to call even if the recipe was never synced (no-op).
    func deleteRemote(remoteID: String?) async {
        guard auth.user != nil,
              let remoteID,
              let uuid = UUID(uuidString: remoteID) else { return }
        do {
            try await Supabase.update(
                "recipes",
                values: RecipeTombstone(deleted: true, updatedAt: Date()),
                eqColumn: "id",
                eqValue: uuid.uuidString
            )
        } catch {
            print("RecipeSync delete failed: \(error)")
        }
    }

    // MARK: - Shopping list sync

    @MainActor
    private func syncShoppingItems(user: AuthManager.User, context: ModelContext) async throws {
        let remote: [RemoteShoppingItem] = try await Supabase.select("shopping_items")
        let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        var locals = try context.fetch(FetchDescriptor<ShoppingItem>())
        var localByID: [UUID: ShoppingItem] = [:]
        for item in locals {
            localByID[ensureRemoteID(item)] = item
        }

        // Pull remote changes onto the local store.
        for row in remote {
            if let local = localByID[row.id] {
                if row.deleted {
                    context.delete(local)
                    localByID[row.id] = nil
                } else if row.updatedAt > local.updatedAt {
                    apply(row, to: local)
                }
            } else if !row.deleted {
                let new = makeShoppingItem(from: row)
                context.insert(new)
                localByID[row.id] = new
            }
        }

        // Push locals that are new or newer.
        locals = try context.fetch(FetchDescriptor<ShoppingItem>())
        var toUpsert: [RemoteShoppingItemUpsert] = []
        for item in locals {
            let uuid = ensureRemoteID(item)
            let remoteRow = remoteByID[uuid]
            let isNewer = remoteRow == nil || (!remoteRow!.deleted && item.updatedAt > remoteRow!.updatedAt)
            if isNewer {
                toUpsert.append(
                    RemoteShoppingItemUpsert(
                        id: uuid,
                        userId: user.id,
                        name: item.name,
                        quantity: item.quantity,
                        aisle: item.aisleRaw,
                        isChecked: item.isChecked,
                        sourceRecipeTitle: item.sourceRecipeTitle,
                        addedAt: item.addedAt,
                        deleted: false,
                        updatedAt: item.updatedAt
                    )
                )
            }
        }
        try await Supabase.upsert("shopping_items", values: toUpsert)
    }

    private func apply(_ row: RemoteShoppingItem, to item: ShoppingItem) {
        item.name = row.name
        item.quantity = row.quantity
        item.aisleRaw = row.aisle
        item.isChecked = row.isChecked
        item.sourceRecipeTitle = row.sourceRecipeTitle
        item.addedAt = row.addedAt
        item.updatedAt = row.updatedAt
    }

    private func makeShoppingItem(from row: RemoteShoppingItem) -> ShoppingItem {
        ShoppingItem(
            name: row.name,
            quantity: row.quantity,
            aisle: GroceryAisle(rawValue: row.aisle) ?? .other,
            isChecked: row.isChecked,
            sourceRecipeTitle: row.sourceRecipeTitle,
            addedAt: row.addedAt,
            remoteID: row.id.uuidString,
            updatedAt: row.updatedAt
        )
    }

    @discardableResult
    private func ensureRemoteID(_ item: ShoppingItem) -> UUID {
        if let id = item.remoteID, let uuid = UUID(uuidString: id) { return uuid }
        let uuid = UUID()
        item.remoteID = uuid.uuidString
        return uuid
    }

    // MARK: - Meal plan sync

    @MainActor
    private func syncPlannedMeals(
        user: AuthManager.User,
        context: ModelContext,
        localRecipesByRemoteID: [UUID: Recipe]
    ) async throws {
        let remote: [RemotePlannedMeal] = try await Supabase.select("planned_meals")
        let remoteByID = Dictionary(remote.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        var locals = try context.fetch(FetchDescriptor<PlannedMeal>())
        var localByID: [UUID: PlannedMeal] = [:]
        for meal in locals {
            localByID[ensureRemoteID(meal)] = meal
        }

        for row in remote {
            if let local = localByID[row.id] {
                if row.deleted {
                    context.delete(local)
                    localByID[row.id] = nil
                } else if row.updatedAt > local.updatedAt {
                    apply(row, to: local, recipesByRemoteID: localRecipesByRemoteID)
                }
            } else if !row.deleted {
                let new = makePlannedMeal(from: row, recipesByRemoteID: localRecipesByRemoteID)
                context.insert(new)
                localByID[row.id] = new
            }
        }

        locals = try context.fetch(FetchDescriptor<PlannedMeal>())
        var toUpsert: [RemotePlannedMealUpsert] = []
        for meal in locals {
            let uuid = ensureRemoteID(meal)
            let remoteRow = remoteByID[uuid]
            let isNewer = remoteRow == nil || (!remoteRow!.deleted && meal.updatedAt > remoteRow!.updatedAt)
            if isNewer {
                let recipeUUID = meal.recipe?.remoteID.flatMap { UUID(uuidString: $0) }
                toUpsert.append(
                    RemotePlannedMealUpsert(
                        id: uuid,
                        userId: user.id,
                        dayStart: meal.dayStart,
                        mealType: meal.mealTypeRaw,
                        sortIndex: meal.sortIndex,
                        recipeId: recipeUUID,
                        customTitle: meal.customTitle,
                        createdAt: meal.createdAt,
                        deleted: false,
                        updatedAt: meal.updatedAt
                    )
                )
            }
        }
        try await Supabase.upsert("planned_meals", values: toUpsert)
    }

    private func apply(_ row: RemotePlannedMeal, to meal: PlannedMeal, recipesByRemoteID: [UUID: Recipe]) {
        meal.dayStart = row.dayStart
        meal.mealTypeRaw = row.mealType
        meal.sortIndex = row.sortIndex
        meal.customTitle = row.customTitle
        meal.recipe = row.recipeId.flatMap { recipesByRemoteID[$0] }
        meal.updatedAt = row.updatedAt
    }

    private func makePlannedMeal(from row: RemotePlannedMeal, recipesByRemoteID: [UUID: Recipe]) -> PlannedMeal {
        PlannedMeal(
            dayStart: row.dayStart,
            mealType: MealType(rawValue: row.mealType) ?? .dinner,
            sortIndex: row.sortIndex,
            recipe: row.recipeId.flatMap { recipesByRemoteID[$0] },
            customTitle: row.customTitle,
            createdAt: row.createdAt,
            remoteID: row.id.uuidString,
            updatedAt: row.updatedAt
        )
    }

    @discardableResult
    private func ensureRemoteID(_ meal: PlannedMeal) -> UUID {
        if let id = meal.remoteID, let uuid = UUID(uuidString: id) { return uuid }
        let uuid = UUID()
        meal.remoteID = uuid.uuidString
        return uuid
    }

    // MARK: - Helpers

    private func ensureProfile(_ user: AuthManager.User) async throws {
        guard !didUpsertProfile else { return }
        try await Supabase.upsert(
            "profiles",
            value: ProfileUpsert(
                id: user.id,
                email: user.email,
                name: user.name ?? ""
            )
        )
        didUpsertProfile = true
    }

    @discardableResult
    private func ensureRemoteID(_ recipe: Recipe) -> UUID {
        if let id = recipe.remoteID, let uuid = UUID(uuidString: id) {
            return uuid
        }
        let uuid = UUID()
        recipe.remoteID = uuid.uuidString
        return uuid
    }

    private func apply(_ row: RemoteRecipe, to recipe: Recipe) {
        recipe.title = row.title
        recipe.summary = row.summary
        recipe.category = RecipeCategory(rawValue: row.category) ?? .dinner
        recipe.servings = row.servings
        recipe.prepMinutes = row.prepMinutes
        recipe.cookMinutes = row.cookMinutes
        recipe.rating = row.rating
        recipe.isFavorite = row.isFavorite
        recipe.notes = row.notes
        recipe.steps = row.steps
        recipe.ingredients = row.ingredients.map { ingredient(from: $0) }
        recipe.photoData = decodeImage(row.photoBase64)
        recipe.originalPhotoData = decodeImage(row.originalPhotoBase64)
        recipe.originalPhotoPages = decodeImages(row.originalPhotoPages)
        recipe.wasScanned = row.wasScanned
        recipe.updatedAt = row.updatedAt
    }

    private func makeRecipe(from row: RemoteRecipe) -> Recipe {
        Recipe(
            title: row.title,
            summary: row.summary,
            category: RecipeCategory(rawValue: row.category) ?? .dinner,
            servings: row.servings,
            prepMinutes: row.prepMinutes,
            cookMinutes: row.cookMinutes,
            rating: row.rating,
            isFavorite: row.isFavorite,
            notes: row.notes,
            ingredients: row.ingredients.map { ingredient(from: $0) },
            steps: row.steps,
            createdAt: row.createdAt,
            originalPhotoData: decodeImage(row.originalPhotoBase64),
            originalPhotoPages: decodeImages(row.originalPhotoPages),
            photoData: decodeImage(row.photoBase64),
            wasScanned: row.wasScanned,
            remoteID: row.id.uuidString,
            updatedAt: row.updatedAt
        )
    }

    private func makeUpsert(_ recipe: Recipe, uuid: UUID, userId: String) -> RemoteRecipeUpsert {
        let ingredients = recipe.ingredients
            .sorted { $0.sortIndex < $1.sortIndex }
            .map {
                RemoteIngredient(
                    name: $0.name,
                    quantity: $0.quantity,
                    aisle: $0.aisleRaw,
                    sortIndex: $0.sortIndex
                )
            }
        return RemoteRecipeUpsert(
            id: uuid,
            userId: userId,
            title: recipe.title,
            summary: recipe.summary,
            category: recipe.categoryRaw,
            servings: recipe.servings,
            prepMinutes: recipe.prepMinutes,
            cookMinutes: recipe.cookMinutes,
            rating: recipe.rating,
            isFavorite: recipe.isFavorite,
            notes: recipe.notes,
            steps: recipe.steps,
            ingredients: ingredients,
            photoBase64: recipe.photoData?.base64EncodedString(),
            originalPhotoBase64: recipe.originalPhotoData?.base64EncodedString(),
            originalPhotoPages: recipe.originalPhotoPages.isEmpty ? nil : recipe.originalPhotoPages.map { $0.base64EncodedString() },
            wasScanned: recipe.wasScanned,
            deleted: false,
            createdAt: recipe.createdAt,
            updatedAt: recipe.updatedAt
        )
    }

    private func ingredient(from remote: RemoteIngredient) -> Ingredient {
        Ingredient(
            name: remote.name,
            quantity: remote.quantity,
            aisle: GroceryAisle(rawValue: remote.aisle) ?? .other,
            sortIndex: remote.sortIndex
        )
    }

    private func decodeImage(_ base64: String?) -> Data? {
        guard let base64, !base64.isEmpty else { return nil }
        return Data(base64Encoded: base64)
    }

    private func decodeImages(_ base64s: [String]?) -> [Data] {
        guard let base64s else { return [] }
        return base64s.compactMap { Data(base64Encoded: $0) }
    }
}

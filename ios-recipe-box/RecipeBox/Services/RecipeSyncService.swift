//
//  RecipeSyncService.swift
//  RecipeBox
//

import Foundation
import SwiftData
import Supabase

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
            let remote: [RemoteRecipe] = try await supabase
                .from("recipes")
                .select()
                .execute()
                .value
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

            if !toUpsert.isEmpty {
                try await supabase.from("recipes").upsert(toUpsert).execute()
            }

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
            try await supabase
                .from("recipes")
                .update(RecipeTombstone(deleted: true, updatedAt: Date()))
                .eq("id", value: uuid.uuidString)
                .execute()
        } catch {
            print("RecipeSync delete failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func ensureProfile(_ user: AuthManager.User) async throws {
        guard !didUpsertProfile else { return }
        try await supabase.from("profiles").upsert(
            ProfileUpsert(
                id: user.id,
                email: user.email,
                name: user.name ?? ""
            )
        ).execute()
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
}

//
//  RecipeBoxApp.swift
//  RecipeBox
//
//  Created by Rork on June 1, 2026.
//

import SwiftUI
import SwiftData

@main
struct RecipeBoxApp: App {
    @State private var auth = AuthManager()
    @State private var sync: RecipeSyncService
    @State private var subscriptions = SubscriptionStore()

    init() {
        let auth = AuthManager()
        _auth = State(initialValue: auth)
        _sync = State(initialValue: RecipeSyncService(auth: auth))
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Recipe.self,
            Ingredient.self,
            ShoppingItem.self,
            FoodEntry.self,
            DailyLog.self,
            WeightEntry.self,
            PlannedMeal.self,
            Medication.self,
            DoseLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(sync)
                .environment(subscriptions)
                .onAppear {
                    SampleData.seedIfNeeded(sharedModelContainer.mainContext)
                    sync.attach(sharedModelContainer)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

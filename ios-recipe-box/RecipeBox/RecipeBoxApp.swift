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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Recipe.self,
            Ingredient.self,
            ShoppingItem.self,
            FoodEntry.self,
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
            ContentView()
                .onAppear {
                    SampleData.seedIfNeeded(sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

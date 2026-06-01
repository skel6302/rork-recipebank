//
//  ContentView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            RecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book.closed.fill")
                }

            CalorieTrackerView()
                .tabItem {
                    Label("Calories", systemImage: "flame.fill")
                }

            ShoppingListView()
                .tabItem {
                    Label("Shopping", systemImage: "cart.fill")
                }
        }
        .tint(Theme.spice)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Recipe.self, Ingredient.self, ShoppingItem.self, FoodEntry.self], inMemory: true)
}

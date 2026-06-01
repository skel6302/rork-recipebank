//
//  ContentView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// Decides between the welcome (sign-in) screen and the main app, and drives
/// recipe syncing on sign-in and when the app returns to the foreground.
struct RootView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(RecipeSyncService.self) private var sync
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if auth.isLoading {
                loadingView
            } else if !auth.hasAccess {
                WelcomeView()
            } else {
                ContentView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.user?.id)
        .animation(.easeInOut(duration: 0.25), value: auth.isGuest)
        .animation(.easeInOut(duration: 0.25), value: auth.isLoading)
        .onChange(of: auth.user?.id) { _, newValue in
            if newValue != nil {
                Task { await sync.syncNow() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, auth.user != nil {
                Task { await sync.syncNow() }
            }
        }
    }

    private var loadingView: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ProgressView()
                .tint(Theme.spice)
        }
    }
}

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

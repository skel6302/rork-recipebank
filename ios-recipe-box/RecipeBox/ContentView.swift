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
    @Environment(\.scenePhase) private var scenePhase

    @State private var importLink: String?
    @State private var importDraft: ScannedRecipe?

    var body: some View {
        TabView {
            RecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book.closed.fill")
                }

            MealPlannerView()
                .tabItem {
                    Label("Plan", systemImage: "calendar")
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
        .onAppear(perform: checkSharedImport)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { checkSharedImport() }
        }
        .sheet(item: Binding(
            get: { importLink.map { SharedLink(url: $0) } },
            set: { if $0 == nil { importLink = nil } }
        )) { link in
            ImportLinkView(initialLink: link.url) { draft in
                importDraft = draft
            }
        }
        .sheet(item: $importDraft) { draft in
            RecipeEditView(recipe: nil, prefill: draft)
        }
    }

    /// Picks up a link handed in by the Share Extension and opens the import flow.
    private func checkSharedImport() {
        guard importLink == nil, importDraft == nil else { return }
        if let link = SharedImportInbox.takePendingLink() {
            importLink = link
        }
    }
}

/// Wraps a shared link so it can drive an `.sheet(item:)` presentation.
private struct SharedLink: Identifiable {
    let url: String
    var id: String { url }
}

#Preview {
    ContentView()
        .modelContainer(for: [Recipe.self, Ingredient.self, ShoppingItem.self, FoodEntry.self, PlannedMeal.self, Medication.self, DoseLog.self], inMemory: true)
}

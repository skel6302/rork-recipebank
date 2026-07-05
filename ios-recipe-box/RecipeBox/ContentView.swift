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
    @Environment(SubscriptionStore.self) private var subscriptions
    @Query private var recipes: [Recipe]

    @State private var importLink: String?
    @State private var importDraft: ScannedRecipe?
    @State private var showingLimitPaywall = false

    var body: some View {
        TabView {
            RecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book.closed.fill")
                }

            Group {
                if subscriptions.canUseMealPlanning {
                    MealPlannerView()
                } else {
                    LockedFeatureView(
                        title: "Meal Planner",
                        symbol: "calendar",
                        summary: "Plan your whole week of breakfasts, lunches and dinners, then send it to your shopping list in one tap.",
                        bullets: [
                            "Weekly planner with all seven days",
                            "Fill slots from your recipes or a food database",
                            "One-tap week-to-shopping-list",
                        ],
                        requiredTier: .plus
                    )
                }
            }
            .tabItem {
                Label("Plan", systemImage: "calendar")
            }

            Group {
                if subscriptions.canUseCalorieTracking {
                    HealthView()
                } else {
                    LockedFeatureView(
                        title: "Health",
                        symbol: "heart.fill",
                        summary: "Calorie tracking and the GLP-1 companion, together in one tab. Log meals, scan barcodes, and watch your macros add up.",
                        bullets: [
                            "Daily calorie & macro tracking",
                            "Barcode scanning and food search",
                            "AI nutrition estimates for any meal",
                            "GLP-1 tracking as a Pro bonus",
                        ],
                        requiredTier: .plus
                    )
                }
            }
            .tabItem {
                Label("Health", systemImage: "heart.fill")
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
        .sheet(isPresented: $showingLimitPaywall) {
            PaywallView(highlightedTier: .plus)
        }
    }

    /// Picks up a link handed in by the Share Extension and opens the import
    /// flow — unless the free plan's recipe limit is already reached, in which
    /// case the paywall is shown instead.
    private func checkSharedImport() {
        guard importLink == nil, importDraft == nil else { return }
        if let link = SharedImportInbox.takePendingLink() {
            if subscriptions.canAddRecipe(currentCount: recipes.count) {
                importLink = link
            } else {
                showingLimitPaywall = true
            }
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
        .environment(SubscriptionStore())
        .modelContainer(for: [Recipe.self, Ingredient.self, ShoppingItem.self, FoodEntry.self, PlannedMeal.self, Medication.self, DoseLog.self], inMemory: true)
}

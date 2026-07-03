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

    @State private var importLink: String?
    @State private var importDraft: ScannedRecipe?

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
                    CalorieTrackerView()
                } else {
                    LockedFeatureView(
                        title: "Calorie Tracking",
                        symbol: "flame.fill",
                        summary: "Log meals, scan barcodes, and watch your daily calories and macros add up.",
                        bullets: [
                            "Daily calorie & macro tracking",
                            "Barcode scanning and food search",
                            "AI nutrition estimates for any meal",
                        ],
                        requiredTier: .plus
                    )
                }
            }
            .tabItem {
                Label("Calories", systemImage: "flame.fill")
            }

            Group {
                if subscriptions.canUseGLP1 {
                    MedsView()
                } else {
                    LockedFeatureView(
                        title: "GLP-1 Companion",
                        symbol: "syringe.fill",
                        summary: "Track Ozempic, Wegovy, Mounjaro, Zepbound and more — with dose reminders, site rotation and weight progress.",
                        bullets: [
                            "Dose tracking with next-dose countdowns",
                            "Injection-site rotation & reminders",
                            "Weight progress tracking",
                            "GLP-1 nutrition & side-effects guide",
                        ],
                        requiredTier: .pro
                    )
                }
            }
            .tabItem {
                Label("GLP-1", systemImage: "syringe.fill")
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
        .environment(SubscriptionStore())
        .modelContainer(for: [Recipe.self, Ingredient.self, ShoppingItem.self, FoodEntry.self, PlannedMeal.self, Medication.self, DoseLog.self], inMemory: true)
}

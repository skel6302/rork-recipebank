//
//  RecipeListView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// The main recipe browser with search, category filtering, and favorites.
struct RecipeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(RecipeSyncService.self) private var sync
    @Environment(SubscriptionStore.self) private var subscriptions
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]

    @State private var searchText: String = ""
    @State private var selectedCategory: RecipeCategory? = nil
    @State private var showingFavoritesOnly: Bool = false
    @State private var showingAdd: Bool = false
    @State private var showingScanner: Bool = false
    @State private var showingImportLink: Bool = false
    @State private var scanResult: ScannedRecipe?
    @State private var recipeToDelete: Recipe?
    @State private var showingAccount: Bool = false
    @State private var showingLimitAlert: Bool = false
    @State private var showingLimitPaywall: Bool = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var filteredRecipes: [Recipe] {
        recipes.filter { recipe in
            let matchesCategory = selectedCategory == nil || recipe.category == selectedCategory
            let matchesFavorite = !showingFavoritesOnly || recipe.isFavorite
            let matchesSearch = searchText.isEmpty
                || recipe.title.localizedStandardContains(searchText)
                || recipe.ingredients.contains { $0.name.localizedStandardContains(searchText) }
            return matchesCategory && matchesFavorite && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    brandHeader
                    headerStats
                    categoryFilter

                    if filteredRecipes.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(filteredRecipes) { recipe in
                                NavigationLink(value: recipe) {
                                    RecipeCardView(recipe: recipe)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        recipeToDelete = recipe
                                    } label: {
                                        Label("Delete Recipe", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search recipes & ingredients")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAccount = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(Theme.spice)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.snappy) { showingFavoritesOnly.toggle() }
                    } label: {
                        Image(systemName: showingFavoritesOnly ? "heart.fill" : "heart")
                            .foregroundStyle(Theme.spice)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        requireCapacity { showingScanner = true }
                    } label: {
                        Image(systemName: "text.viewfinder")
                            .foregroundStyle(Theme.spice)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            requireCapacity { showingImportLink = true }
                        } label: {
                            Label("Import from Video Link", systemImage: "play.rectangle.on.rectangle")
                        }
                        Button {
                            requireCapacity { showingScanner = true }
                        } label: {
                            Label("Scan a Recipe", systemImage: "text.viewfinder")
                        }
                        Button {
                            requireCapacity { showingAdd = true }
                        } label: {
                            Label("Add Manually", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Theme.spice)
                    }
                }
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(isPresented: $showingAdd) {
                RecipeEditView(recipe: nil)
            }
            .sheet(isPresented: $showingScanner) {
                ScanRecipeView { result in
                    scanResult = result
                }
            }
            .sheet(isPresented: $showingImportLink) {
                ImportLinkView { result in
                    scanResult = result
                }
            }
            .sheet(item: $scanResult) { result in
                RecipeEditView(recipe: nil, prefill: result)
            }
            .sheet(isPresented: $showingAccount) {
                AccountView()
            }
            .sheet(isPresented: $showingLimitPaywall) {
                PaywallView(highlightedTier: .plus)
            }
            .alert("Recipe limit reached", isPresented: $showingLimitAlert) {
                Button("See Plans") { showingLimitPaywall = true }
                Button("Not Now", role: .cancel) { }
            } message: {
                Text("The free plan stores up to \(SubscriptionStore.freeRecipeLimit) recipes. Upgrade to Plus for unlimited recipe storage.")
            }
            .refreshable {
                await sync.syncNow()
            }
            .confirmationDialog(
                "Delete this recipe?",
                isPresented: Binding(
                    get: { recipeToDelete != nil },
                    set: { if !$0 { recipeToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: recipeToDelete
            ) { recipe in
                Button("Delete \(recipe.title)", role: .destructive) {
                    let remoteID = recipe.remoteID
                    modelContext.delete(recipe)
                    try? modelContext.save()
                    Task { await sync.deleteRemote(remoteID: remoteID) }
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    recipeToDelete = nil
                }
                Button("Cancel", role: .cancel) { recipeToDelete = nil }
            } message: { _ in
                Text("This can't be undone.")
            }
        }
        .tint(Theme.spice)
    }

    private var brandHeader: some View {
        HStack {
            Image("BrandMark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 44)
            Spacer()
            syncBadge
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var syncBadge: some View {
        switch sync.state {
        case .syncing:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small).tint(Theme.spice)
                Text("Syncing")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
        case .synced:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.icloud.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Synced")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Theme.sage)
        case .error:
            Button {
                Task { await sync.syncNow() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.icloud.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Retry")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Theme.spice)
            }
            .buttonStyle(.plain)
        case .idle:
            EmptyView()
        }
    }

    /// Runs `action` if the plan allows saving another recipe; otherwise shows
    /// the upgrade prompt.
    private func requireCapacity(_ action: () -> Void) {
        if subscriptions.canAddRecipe(currentCount: recipes.count) {
            action()
        } else {
            showingLimitAlert = true
        }
    }

    private var headerStats: some View {
        HStack(spacing: 12) {
            statPill(
                count: recipes.count,
                label: subscriptions.tier == .free
                    ? "of \(SubscriptionStore.freeRecipeLimit) free recipes"
                    : "Recipes",
                symbol: "book.closed.fill"
            )
            statPill(count: recipes.filter { $0.isFavorite }.count, label: "Favorites", symbol: "heart.fill")
        }
        .padding(.horizontal, 16)
    }

    private func statPill(count: Int, label: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Theme.warmGradient, in: .circle)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(count)")
                    .font(.cookbookSerif(20, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", isSelected: selectedCategory == nil, tint: Theme.spice) {
                    withAnimation(.snappy) { selectedCategory = nil }
                }
                ForEach(RecipeCategory.allCases) { category in
                    chip(
                        title: category.rawValue,
                        symbol: category.symbol,
                        isSelected: selectedCategory == category,
                        tint: category.tint
                    ) {
                        withAnimation(.snappy) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(title: String, symbol: String? = nil, isSelected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                }
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? tint : Theme.paperRaised, in: .capsule)
            .overlay(Capsule().stroke(Theme.ink.opacity(isSelected ? 0 : 0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 56))
                .foregroundStyle(Theme.spice.opacity(0.5))
            Text("No recipes found")
                .font(.cookbookSerif(20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Try a different filter, or add your own recipe.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button {
                    requireCapacity { showingScanner = true }
                } label: {
                    Label("Scan a Recipe", systemImage: "text.viewfinder")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(Theme.warmGradient, in: .capsule)
                }
                .buttonStyle(.plain)
                Button {
                    requireCapacity { showingAdd = true }
                } label: {
                    Label("Add Manually", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.spice)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 30)
    }
}

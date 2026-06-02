//
//  MealRecipePickerView.swift
//  RecipeBox
//

import SwiftUI

/// A lightweight value describing a standalone food chosen for a meal-plan slot.
struct PlannedFood {
    let name: String
    let serving: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}

/// Lets the user fill a meal-plan slot with either a saved recipe or a standalone
/// food (e.g. "a bagel") looked up from the food database, so the planner isn't
/// limited to recipes.
struct MealRecipePickerView: View {
    let recipes: [Recipe]
    let onSelectRecipe: (Recipe) -> Void
    let onSelectFood: (PlannedFood) -> Void

    @Environment(\.dismiss) private var dismiss

    private enum Mode: String, CaseIterable, Identifiable {
        case recipes = "Recipes"
        case foods = "Foods"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .recipes

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Source", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                switch mode {
                case .recipes:
                    RecipePickerList(recipes: recipes) { recipe in
                        onSelectRecipe(recipe)
                        dismiss()
                    }
                case .foods:
                    FoodPickerList { food in
                        onSelectFood(food)
                        dismiss()
                    }
                }
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Add to Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.spice)
                }
            }
        }
        .tint(Theme.spice)
    }
}

// MARK: - Recipes tab

private struct RecipePickerList: View {
    let recipes: [Recipe]
    let onSelect: (Recipe) -> Void

    @State private var searchText = ""

    private var filtered: [Recipe] {
        guard !searchText.isEmpty else { return recipes }
        return recipes.filter {
            $0.title.localizedStandardContains(searchText)
                || $0.ingredients.contains { ing in ing.name.localizedStandardContains(searchText) }
        }
    }

    var body: some View {
        Group {
            if recipes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { recipe in
                            Button {
                                onSelect(recipe)
                            } label: {
                                row(recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search recipes")
    }

    private func row(_ recipe: Recipe) -> some View {
        HStack(spacing: 12) {
            RecipeThumbnail(category: recipe.category, cornerRadius: 12, photoData: recipe.displayPhotoData)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text("\(recipe.category.rawValue) · \(recipe.ingredients.count) ingredients · \(recipe.totalMinutes)m")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.spice)
        }
        .padding(10)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundStyle(Theme.spice.opacity(0.5))
            Text("No recipes yet")
                .font(.cookbookSerif(20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Add recipes in the Recipes tab, or switch to Foods to add a single item.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Foods tab

private struct FoodPickerList: View {
    let onSelect: (PlannedFood) -> Void

    @State private var query = ""
    @State private var results: [AnalyzedFood] = []
    @State private var isSearching = false
    @State private var isEstimating = false
    @State private var errorMessage: String?
    @State private var hasSearched = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if isEstimating || (query.trimmingCharacters(in: .whitespaces).count >= 2 && !isSearching) {
                    aiEstimateButton
                }

                if isSearching {
                    ProgressView()
                        .padding(.top, 30)
                } else if let errorMessage {
                    message(errorMessage, system: "exclamationmark.triangle")
                } else if results.isEmpty && hasSearched {
                    message("No foods found for \"\(query)\". Try a simpler name, or estimate it with AI.", system: "magnifyingglass")
                } else if !hasSearched {
                    hint
                }

                ForEach(results) { food in
                    Button {
                        select(food)
                    } label: {
                        row(food)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .searchable(text: $query, prompt: "Search foods (e.g. bagel)")
        .onSubmit(of: .search) { Task { await runSearch() } }
    }

    private var aiEstimateButton: some View {
        Button {
            Task { await estimateWithAI() }
        } label: {
            HStack(spacing: 10) {
                if isEstimating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(isEstimating ? "Estimating…" : "Estimate \"\(query.trimmingCharacters(in: .whitespaces))\" with AI")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Theme.warmGradient, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(isEstimating)
    }

    private func row(_ food: AnalyzedFood) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.sage)
                .frame(width: 44, height: 44)
                .background(Theme.sage.opacity(0.12), in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text("\(food.calories) cal · \(food.servingDescription)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.spice)
        }
        .padding(10)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private var hint: some View {
        VStack(spacing: 14) {
            Image(systemName: "carrot")
                .font(.system(size: 46))
                .foregroundStyle(Theme.sage.opacity(0.6))
            Text("Add any food")
                .font(.cookbookSerif(20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Search the food database for a single item like a bagel, banana, or yogurt — complete with nutrition.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 36)
        .padding(.horizontal, 24)
    }

    private func message(_ text: String, system: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: system)
                .font(.system(size: 34))
                .foregroundStyle(Theme.inkSoft.opacity(0.5))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 30)
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private func select(_ food: AnalyzedFood) {
        onSelect(
            PlannedFood(
                name: food.name,
                serving: food.servingDescription,
                calories: food.calories,
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat
            )
        )
    }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        isSearching = true
        errorMessage = nil
        hasSearched = true
        defer { isSearching = false }
        do {
            results = try await FoodSearchService.search(trimmed)
        } catch {
            results = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong searching."
        }
    }

    private func estimateWithAI() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        isEstimating = true
        errorMessage = nil
        defer { isEstimating = false }
        do {
            let analysis = try await CalorieAnalyzer.analyze(text: trimmed)
            guard !analysis.items.isEmpty else {
                errorMessage = "Couldn't estimate that. Try a different description."
                return
            }
            // Collapse the AI's items into a single food entry for the slot.
            let name = analysis.mealName.isEmpty ? trimmed.capitalized : analysis.mealName
            let serving = analysis.items.count == 1
                ? analysis.items[0].servingDescription
                : "\(analysis.items.count) items"
            onSelect(
                PlannedFood(
                    name: name,
                    serving: serving,
                    calories: analysis.totalCalories,
                    protein: analysis.totalProtein,
                    carbs: analysis.totalCarbs,
                    fat: analysis.totalFat
                )
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't estimate that right now."
        }
    }
}

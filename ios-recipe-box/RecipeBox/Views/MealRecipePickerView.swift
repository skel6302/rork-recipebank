//
//  MealRecipePickerView.swift
//  RecipeBox
//

import SwiftUI

/// A searchable picker that lets the user choose a recipe to add to a meal-plan slot.
struct MealRecipePickerView: View {
    let recipes: [Recipe]
    let onSelect: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [Recipe] {
        guard !searchText.isEmpty else { return recipes }
        return recipes.filter {
            $0.title.localizedStandardContains(searchText)
                || $0.ingredients.contains { ing in ing.name.localizedStandardContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { recipe in
                                Button {
                                    onSelect(recipe)
                                    dismiss()
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
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Choose a Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.spice)
                }
            }
        }
        .tint(Theme.spice)
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
            Text("Add recipes in the Recipes tab, then plan them here.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

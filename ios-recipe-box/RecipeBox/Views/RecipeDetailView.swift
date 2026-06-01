//
//  RecipeDetailView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// Full recipe view with ingredients, steps, and shopping-list actions.
struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var recipe: Recipe

    @State private var showingEdit = false
    @State private var addedToList = false
    @State private var checkedSteps: Set<Int> = []
    @State private var showingDeleteConfirm = false
    @State private var showingCooked = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 22) {
                    titleBlock
                    metaRow
                    addToListButton
                    cookedButton
                    ingredientsSection
                    stepsSection
                    if !recipe.notes.isEmpty {
                        notesSection
                    }
                }
                .padding(20)
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy) { recipe.isFavorite.toggle() }
                } label: {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(Theme.spice)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingEdit = true } label: {
                        Label("Edit Recipe", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.spice)
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            RecipeEditView(recipe: recipe)
        }
        .sheet(isPresented: $showingCooked) {
            CookedRecipeView(recipe: recipe)
        }
        .confirmationDialog(
            "Delete this recipe?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete \(recipe.title)", role: .destructive) {
                deleteRecipe()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can't be undone.")
        }
        .sheet(isPresented: $showingOriginal) {
            if let data = recipe.originalPhotoData, let uiImage = UIImage(data: data) {
                OriginalPhotoView(image: uiImage)
            }
        }
    }

    @State private var showingOriginal = false

    private var hero: some View {
        Group {
            if let data = recipe.displayPhotoData, let uiImage = UIImage(data: data) {
                Color.black
                    .frame(height: 260)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.3)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                    .overlay(alignment: .topLeading) {
                        if recipe.originalPhotoData != nil {
                            Label("Scanned", systemImage: "text.viewfinder")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(.black.opacity(0.35), in: .capsule)
                                .padding(.top, 56)
                                .padding(.leading, 16)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if recipe.originalPhotoData != nil {
                            Button {
                                showingOriginal = true
                            } label: {
                                Label("View Original", systemImage: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(.ultraThinMaterial, in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .padding(16)
                        }
                    }
            } else {
                RecipeThumbnail(category: recipe.category, cornerRadius: 0)
                    .frame(height: 260)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.25)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.category.rawValue.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(recipe.category.tint)
            Text(recipe.title)
                .font(.cookbookSerif(28, weight: .bold))
                .foregroundStyle(Theme.ink)
            if !recipe.summary.isEmpty {
                Text(recipe.summary)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkSoft)
            }
            StarRating(rating: recipe.rating, size: 16, editable: true) { newValue in
                recipe.rating = newValue
            }
            .padding(.top, 2)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 0) {
            metaItem(value: "\(recipe.prepMinutes)m", label: "Prep", symbol: "timer")
            divider
            metaItem(value: "\(recipe.cookMinutes)m", label: "Cook", symbol: "flame.fill")
            divider
            metaItem(value: "\(recipe.servings)", label: "Serves", symbol: "person.2.fill")
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func metaItem(value: String, label: String, symbol: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Theme.spice)
            Text(value)
                .font(.cookbookSerif(17, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Theme.ink.opacity(0.08)).frame(width: 1, height: 36)
    }

    private var addToListButton: some View {
        Button {
            addAllToShoppingList()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: addedToList ? "checkmark.circle.fill" : "cart.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                Text(addedToList ? "Added to Shopping List" : "Add Ingredients to List")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(addedToList ? AnyShapeStyle(Theme.sage) : AnyShapeStyle(Theme.warmGradient), in: .capsule)
            .shadow(color: Theme.spice.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var cookedButton: some View {
        Button {
            showingCooked = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 17, weight: .semibold))
                Text("I Cooked This")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Theme.spice)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.spice.opacity(0.10), in: .capsule)
            .overlay(Capsule().stroke(Theme.spice.opacity(0.30), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Ingredients", symbol: "list.bullet")
            VStack(spacing: 0) {
                ForEach(Array(recipe.ingredients.sorted { $0.sortIndex < $1.sortIndex }.enumerated()), id: \.element.id) { index, ing in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(ing.aisle == .other ? Theme.inkSoft.opacity(0.4) : recipe.category.tint)
                            .frame(width: 7, height: 7)
                        Text(ing.name)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        if !ing.quantity.isEmpty {
                            Text(ing.quantity)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    .padding(.vertical, 11)
                    if index < recipe.ingredients.count - 1 {
                        Rectangle().fill(Theme.ink.opacity(0.06)).frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Instructions", symbol: "text.line.first.and.arrowtriangle.forward")
            VStack(spacing: 10) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    Button {
                        withAnimation(.snappy) {
                            if checkedSteps.contains(index) { checkedSteps.remove(index) }
                            else { checkedSteps.insert(index) }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(checkedSteps.contains(index) ? Theme.sage : recipe.category.tint)
                                    .frame(width: 28, height: 28)
                                if checkedSteps.contains(index) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text(step)
                                .font(.system(size: 15))
                                .foregroundStyle(checkedSteps.contains(index) ? Theme.inkSoft : Theme.ink)
                                .strikethrough(checkedSteps.contains(index))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                        .background(Theme.paperRaised, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Notes", symbol: "note.text")
            Text(recipe.notes)
                .font(.cookbookSerif(15))
                .italic()
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.cream, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.amber.opacity(0.25), lineWidth: 1))
        }
    }

    private func sectionHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.spice)
            Text(title)
                .font(.cookbookSerif(20, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
    }

    private func deleteRecipe() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        modelContext.delete(recipe)
        try? modelContext.save()
        dismiss()
    }

    private func addAllToShoppingList() {
        for ing in recipe.ingredients {
            let item = ShoppingItem(
                name: ing.name,
                quantity: ing.quantity,
                aisle: ing.aisle,
                sourceRecipeTitle: recipe.title
            )
            modelContext.insert(item)
        }
        try? modelContext.save()
        withAnimation(.snappy) { addedToList = true }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

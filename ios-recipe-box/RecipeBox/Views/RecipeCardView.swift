//
//  RecipeCardView.swift
//  RecipeBox
//

import SwiftUI

/// A cookbook-style card showing a recipe at a glance.
struct RecipeCardView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RecipeThumbnail(category: recipe.category, cornerRadius: 0, photoData: recipe.displayPhotoData)
                .frame(height: 130)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    if recipe.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.black.opacity(0.25), in: .circle)
                            .padding(8)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    Text(recipe.category.rawValue.uppercased())
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.22), in: .capsule)
                        .padding(8)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.cookbookSerif(16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Label("\(recipe.totalMinutes)m", systemImage: "clock")
                    Label("\(recipe.servings)", systemImage: "person.2.fill")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.inkSoft)

                if recipe.rating > 0 {
                    StarRating(rating: recipe.rating, size: 11)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.paperRaised)
        .clipShape(.rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.ink.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Theme.cardShadow, radius: 8, y: 4)
    }
}

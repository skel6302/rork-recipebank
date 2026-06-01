//
//  RecipeThumbnail.swift
//  RecipeBox
//

import SwiftUI

/// A warm gradient thumbnail with the recipe's category symbol.
/// Used as a consistent, appetizing placeholder across the app.
///
/// If `photoData` is supplied and decodes to an image, the real photo is shown
/// instead of the gradient placeholder.
struct RecipeThumbnail: View {
    let category: RecipeCategory
    var cornerRadius: CGFloat = 18
    var photoData: Data? = nil

    var body: some View {
        if let photoData, let uiImage = UIImage(data: photoData) {
            Color(.secondarySystemBackground)
                .overlay {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: cornerRadius))
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [category.tint.opacity(0.95), category.tint.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle decorative rings for depth
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 20)
                .scaleEffect(1.4)
                .offset(x: 60, y: -50)

            Image(systemName: category.symbol)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

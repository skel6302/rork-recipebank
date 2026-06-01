//
//  StarRating.swift
//  RecipeBox
//

import SwiftUI

/// A reusable star rating control. When `editable`, taps update the binding.
struct StarRating: View {
    var rating: Int
    var size: CGFloat = 14
    var editable: Bool = false
    var onChange: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index <= rating ? Theme.amber : Theme.inkSoft.opacity(0.35))
                    .onTapGesture {
                        guard editable else { return }
                        onChange?(index == rating ? 0 : index)
                    }
            }
        }
    }
}

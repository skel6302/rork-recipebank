//
//  OriginalPhotoView.swift
//  RecipeBox
//

import SwiftUI

/// A full-screen, zoomable viewer for the preserved original recipe photo.
struct OriginalPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                scale = min(max(lastScale * value.magnification, 1), 5)
                            }
                            .onEnded { _ in
                                lastScale = scale
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.snappy) {
                            scale = scale > 1 ? 1 : 2.5
                            lastScale = scale
                        }
                    }
            }
            .navigationTitle("Original")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

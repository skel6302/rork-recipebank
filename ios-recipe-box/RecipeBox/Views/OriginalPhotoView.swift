//
//  OriginalPhotoView.swift
//  RecipeBox
//

import SwiftUI

/// A full-screen, zoomable viewer for the preserved original recipe photo(s).
/// When a recipe was scanned across multiple pages, all pages are swipeable.
struct OriginalPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let images: [UIImage]

    @State private var selection: Int = 0
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    init(images: [UIImage]) {
        self.images = images
    }

    /// Convenience for a single-page original.
    init(image: UIImage) {
        self.images = [image]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                TabView(selection: $selection) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(index == selection ? scale : 1)
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
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: images.count > 1 ? .always : .never))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .onChange(of: selection) { _, _ in
                    scale = 1
                    lastScale = 1
                }
            }
            .navigationTitle(images.count > 1 ? "Original · Page \(selection + 1) of \(images.count)" : "Original")
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

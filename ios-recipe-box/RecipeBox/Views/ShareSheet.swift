//
//  ShareSheet.swift
//  RecipeBox
//

import SwiftUI
import UIKit

/// A simple UIKit share sheet wrapper for exporting the shopping list.
struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

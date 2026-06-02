//
//  DocumentScannerView.swift
//  RecipeBox
//

import SwiftUI
import VisionKit

/// A thin SwiftUI wrapper around VisionKit's document camera. It captures one or
/// more pages and returns every scanned page in order, so multi-page recipes
/// (ingredients on one page, method on the next) are read in full.
///
/// The cloud simulator has no camera, so callers should only present this when
/// `VNDocumentCameraViewController.isSupported` is true.
struct DocumentScannerView: UIViewControllerRepresentable {
    var onComplete: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void

        init(onComplete: @escaping ([UIImage]) -> Void) {
            self.onComplete = onComplete
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            onComplete(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onComplete([])
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onComplete([])
        }
    }
}

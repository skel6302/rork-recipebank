//
//  RecipeScanner.swift
//  RecipeBox
//

import Foundation
import UIKit
import Vision

/// The structured result of digitizing a scanned/photographed recipe.
/// Pre-fills the editor so the user can review and correct before saving.
struct ScannedRecipe: Identifiable {
    let id = UUID()
    var title: String
    var summary: String
    var ingredients: [DraftIngredient]
    var steps: [String]
    var rawText: String
    var photoData: Data?
}

/// Runs Apple's Vision text recognition over a photo and parses the result
/// into a usable recipe structure. All heavy work happens off the main actor.
enum RecipeScanner {
    /// Recognizes text in an image and returns the lines in reading order.
    nonisolated static func recognizeLines(in image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = image.cgOrientation

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Full pipeline: read the recipe and keep the original photo.
    ///
    /// We first ask the multimodal model to understand the photo (it ignores
    /// marketing copy, QR codes, allergen notes, and per-serving column noise that
    /// the line-by-line heuristics get wrong). If that fails — offline, not
    /// configured, or an unreadable photo — we fall back to on-device Vision OCR.
    nonisolated static func scan(image: UIImage) async -> ScannedRecipe {
        await scan(images: [image])
    }

    /// Full pipeline for a multi-page recipe. All pages are read together so a
    /// recipe whose method lives on a second page keeps its cooking steps.
    nonisolated static func scan(images: [UIImage]) async -> ScannedRecipe {
        let normalized = images.map { $0.normalizedUp() }
        let photoData = normalized.first?.jpegData(compressionQuality: 0.8)

        if let aiParsed = try? await AIRecipeParser.parse(images: normalized) {
            var result = aiParsed
            result.photoData = photoData
            return result
        }

        var allLines: [String] = []
        for page in normalized {
            allLines.append(contentsOf: await recognizeLines(in: page))
        }
        var parsed = RecipeTextParser.parse(lines: allLines)
        parsed.photoData = photoData
        return parsed
    }
}

extension UIImage {
    /// Returns a copy redrawn with an upright (.up) orientation. Photos taken at an
    /// angle or in landscape carry orientation metadata that makes the recipe appear
    /// sideways/off-kilter; flattening it here fixes both the saved photo and OCR.
    nonisolated func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Maps UIKit image orientation to the Core Graphics orientation Vision expects.
    nonisolated var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

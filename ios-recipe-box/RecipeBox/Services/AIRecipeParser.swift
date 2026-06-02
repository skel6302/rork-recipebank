//
//  AIRecipeParser.swift
//  RecipeBox
//

import Foundation
import UIKit

/// Uses a multimodal model through the Rork proxy to read a photographed recipe
/// (handwritten card, printed page, or a meal-kit card like HelloFresh) and turn
/// it into a clean structured draft. This is far more accurate than line-by-line
/// OCR heuristics: it ignores marketing copy, QR codes, allergen notes, nutrition
/// panels, and per-serving column noise, and keeps only the real recipe.
///
/// Callers should fall back to the on-device OCR parser if this throws, so the
/// feature still works offline or when AI isn't configured.
nonisolated enum AIRecipeParser {
    private static let model = "google/gemini-2.5-flash"

    private static let systemPrompt = """
    You read photos of recipes and return a clean, structured recipe. Sources include \
    handwritten cards, cookbook pages, and meal-kit cards (e.g. HelloFresh, Blue Apron).

    Rules:
    - Extract ONLY the actual recipe. Ignore brand logos, marketing copy, QR codes, \
    barcodes, website URLs, allergen disclaimers, sustainability blurbs, prep/cook time \
    badges, and nutrition panels.
    - The image may be rotated or photographed at an angle. Read it regardless of orientation.
    - For each ingredient, give a concise name (singular, lowercase unless a proper noun) \
    and a quantity. Meal-kit cards often list two quantity columns (e.g. "2 PERSON" and \
    "4 PERSON"); pick the FIRST/smaller serving column for the quantity. Do NOT duplicate items.
    - Combine quantity + unit into the "quantity" field (e.g. "1 tbsp", "¼ cup", "10 oz"). \
    Leave quantity empty if none is shown. Never put the quantity inside the name.
    - COOKING INSTRUCTIONS ARE CRITICAL. Meal-kit cards (HelloFresh, Blue Apron, etc.) lay \
    out the method as a grid of NUMBERED panels, each with a small photo above a paragraph of \
    text (often labeled 1, 2, 3, 4, 5, 6). Read EVERY numbered panel, in order, and turn each \
    one into a step. The instructions are usually on a separate side/half of the card from the \
    ingredients — do not stop after the ingredient list. Transcribe the full instruction text \
    for each step (cooking times, temperatures, and quantities included); do not just write the \
    step's heading or title. Preserve the original numbered order.
    - Only return an empty steps array if the photo genuinely shows NO cooking instructions at \
    all (e.g. an ingredients-only card). Never invent steps that aren't shown.
    - Title: the dish name. If unclear, use a short descriptive title.

    Respond with ONLY a JSON object (no markdown, no code fences) in exactly this shape:
    {
      "title": "Dish name",
      "summary": "one short sentence describing the dish, or empty string",
      "ingredients": [
        { "name": "ingredient name", "quantity": "1 tbsp" }
      ],
      "steps": ["step one", "step two"]
    }
    """

    nonisolated struct ParsedRecipe: Codable {
        struct ParsedIngredient: Codable {
            var name: String
            var quantity: String?
        }
        var title: String
        var summary: String?
        var ingredients: [ParsedIngredient]
        var steps: [String]
    }

    nonisolated enum ParseError: Error {
        case notConfigured
        case imageTooLarge
        case badResponse
        case server(Int)
        case empty
    }

    // MARK: - Public API

    /// Reads a recipe photo and returns a structured draft via the vision model.
    static func parse(image: UIImage) async throws -> ScannedRecipe {
        try await parse(images: [image])
    }

    /// Reads one or more pages of a single recipe (e.g. ingredients on page one,
    /// method on page two) and merges them into one structured draft.
    static func parse(images: [UIImage]) async throws -> ScannedRecipe {
        guard !images.isEmpty else { throw ParseError.empty }

        let encoded = images.compactMap { resizedBase64JPEG(from: $0) }
        guard !encoded.isEmpty else { throw ParseError.imageTooLarge }

        let promptText = encoded.count > 1
            ? "These \(encoded.count) photos are different pages of ONE recipe (for example, ingredients on one page and the cooking method on another). Combine them into a single recipe. Include EVERY numbered cooking instruction/step across ALL pages, in order, with the full text — not just the ingredients."
            : "Read this recipe and return the structured JSON. Include EVERY numbered cooking instruction/step you can see, in order, with the full text — not just the ingredients."

        var content: [[String: Any]] = [["type": "text", "text": promptText]]
        for base64 in encoded {
            content.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]])
        }
        let parsed = try await request(userContent: content)

        let ingredients = parsed.ingredients
            .map { item -> DraftIngredient in
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let quantity = (item.quantity ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return DraftIngredient(name: name, quantity: quantity)
            }
            .filter { !$0.name.isEmpty }

        let steps = parsed.steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !ingredients.isEmpty || !steps.isEmpty else {
            throw ParseError.empty
        }

        let title = parsed.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return ScannedRecipe(
            title: title.isEmpty ? "Scanned Recipe" : title,
            summary: (parsed.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            ingredients: ingredients.isEmpty ? [DraftIngredient()] : ingredients,
            steps: steps.isEmpty ? [""] : steps,
            rawText: "",
            photoData: nil
        )
    }

    // MARK: - Networking

    private static func request(userContent: [[String: Any]]) async throws -> ParsedRecipe {
        let toolkitURL = Config.EXPO_PUBLIC_TOOLKIT_URL
        let secret = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
        guard !toolkitURL.isEmpty, !secret.isEmpty,
              let url = URL(string: "\(toolkitURL)/v2/vercel/v1/chat/completions") else {
            throw ParseError.notConfigured
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent],
            ],
            "temperature": 0.1,
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ParseError.badResponse
        }
        switch http.statusCode {
        case 200: break
        case 413: throw ParseError.imageTooLarge
        default: throw ParseError.server(http.statusCode)
        }

        let completion = try JSONDecoder().decode(ChatCompletion.self, from: data)
        guard let raw = completion.choices.first?.message.content, !raw.isEmpty else {
            throw ParseError.badResponse
        }
        return try decode(raw)
    }

    private struct ChatCompletion: Codable {
        struct Choice: Codable {
            struct Message: Codable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    /// Extracts the JSON object from the model's text (tolerating code fences).
    private static func decode(_ raw: String) throws -> ParsedRecipe {
        let cleaned = stripCodeFences(raw)
        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else {
            throw ParseError.badResponse
        }
        let slice = String(cleaned[start...end])
        guard let jsonData = slice.data(using: .utf8) else {
            throw ParseError.badResponse
        }
        do {
            return try JSONDecoder().decode(ParsedRecipe.self, from: jsonData)
        } catch {
            throw ParseError.badResponse
        }
    }

    private static func stripCodeFences(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            if let firstNewline = t.firstIndex(of: "\n") {
                t = String(t[t.index(after: firstNewline)...])
            }
            if let fenceRange = t.range(of: "```", options: .backwards) {
                t = String(t[..<fenceRange.lowerBound])
            }
        }
        return t
    }

    // MARK: - Image resizing (byte-budget ladder)

    private static func resizedBase64JPEG(from image: UIImage, maxBytes: Int = 3_000_000) -> String? {
        let ladder: [(maxEdge: CGFloat, quality: CGFloat)] = [
            (1600, 0.82), (1280, 0.80), (1024, 0.76), (832, 0.72), (640, 0.68),
        ]
        for step in ladder {
            guard let data = encodeJPEG(image, maxEdge: step.maxEdge, quality: step.quality) else { continue }
            if data.count <= maxBytes {
                return data.base64EncodedString()
            }
        }
        return nil
    }

    private static func encodeJPEG(_ image: UIImage, maxEdge: CGFloat, quality: CGFloat) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxEdge ? maxEdge / longest : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}

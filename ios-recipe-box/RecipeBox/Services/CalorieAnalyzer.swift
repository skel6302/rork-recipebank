//
//  CalorieAnalyzer.swift
//  RecipeBox
//

import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// One identified food item with estimated nutrition.
nonisolated struct AnalyzedFood: Identifiable, Codable {
    var id = UUID()
    var name: String
    var servingDescription: String
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double

    private enum CodingKeys: String, CodingKey {
        case name, servingDescription, calories, protein, carbs, fat
    }
}

/// The full result of analyzing a food photo, recipe, or description.
nonisolated struct MealAnalysis: Codable {
    var mealName: String
    var items: [AnalyzedFood]
    /// A short note about assumptions or confidence the model made.
    var note: String?

    var totalCalories: Int { items.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { items.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Double { items.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { items.reduce(0) { $0 + $1.fat } }
}

nonisolated enum CalorieAnalyzerError: LocalizedError {
    case notConfigured
    case imageTooLarge
    case authError
    case rateLimited
    case badResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "AI features aren't set up yet. Please try again later."
        case .imageTooLarge: return "That photo is too large to analyze. Try a different one."
        case .authError: return "AI features are currently unavailable. Please restart the app."
        case .rateLimited: return "Too many requests. Please wait a moment and try again."
        case .badResponse: return "We couldn't read the nutrition from that. Try again or add it manually."
        case .serverError: return "Something went wrong analyzing your meal. Please try again."
        }
    }
}

/// Uses a multimodal model through the Rork proxy to estimate calories and macros
/// from a food photo, a recipe, or a typed description. All work is off the main actor.
nonisolated enum CalorieAnalyzer {
    private static let model = "google/gemini-2.5-flash"

    private static let systemPrompt = """
    You are a precise nutrition estimation assistant. Given a photo of food, a recipe, \
    or a text description, identify each distinct food item and estimate its nutrition \
    for the portion shown or described. Be realistic about portion sizes.

    Respond with ONLY a JSON object (no markdown, no code fences) in exactly this shape:
    {
      "mealName": "short name for the whole meal",
      "items": [
        {
          "name": "food name",
          "servingDescription": "e.g. 1 cup, 150g, 1 medium",
          "calories": 0,
          "protein": 0,
          "carbs": 0,
          "fat": 0
        }
      ],
      "note": "one short sentence on assumptions or confidence"
    }
    calories is an integer (kcal). protein, carbs and fat are grams as numbers. \
    If you cannot identify any food, return an empty items array.
    """

    // MARK: - Public API

    /// Analyze a photo of a meal.
    static func analyze(image: UIImage) async throws -> MealAnalysis {
        guard let base64 = resizedBase64JPEG(from: image) else {
            throw CalorieAnalyzerError.imageTooLarge
        }
        let content: [[String: Any]] = [
            ["type": "text", "text": "Analyze this meal and estimate its nutrition."],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
        ]
        return try await request(userContent: content)
    }

    /// Analyze a free-text description or recipe.
    static func analyze(text: String) async throws -> MealAnalysis {
        let content: [[String: Any]] = [
            ["type": "text", "text": "Analyze this food/recipe and estimate its nutrition:\n\n\(text)"],
        ]
        return try await request(userContent: content)
    }

    /// Estimate the nutrition for an ENTIRE recipe (all servings combined), given
    /// its title, serving count and ingredient lines. The returned totals cover the
    /// whole dish; divide by the serving count to get per-serving values.
    static func analyzeRecipe(
        title: String,
        servings: Int,
        ingredientLines: [String]
    ) async throws -> MealAnalysis {
        let ingredients = ingredientLines.isEmpty
            ? "(no ingredients listed)"
            : ingredientLines.map { "- \($0)" }.joined(separator: "\n")
        let prompt = """
        Estimate the total nutrition for this ENTIRE recipe as written — the sum of \
        all \(servings) serving(s) combined, not per serving. Use the ingredient \
        quantities to be realistic.

        Recipe: \(title)
        Yields: \(servings) serving(s)
        Ingredients:
        \(ingredients)

        Set mealName to the recipe title. Return the whole-recipe totals.
        """
        let content: [[String: Any]] = [["type": "text", "text": prompt]]
        return try await request(userContent: content)
    }

    // MARK: - Networking

    private static func request(userContent: [[String: Any]]) async throws -> MealAnalysis {
        let toolkitURL = Config.EXPO_PUBLIC_TOOLKIT_URL
        let secret = Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY
        guard !toolkitURL.isEmpty, !secret.isEmpty,
              let url = URL(string: "\(toolkitURL)/v2/vercel/v1/chat/completions") else {
            throw CalorieAnalyzerError.notConfigured
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent],
            ],
            "temperature": 0.2,
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw CalorieAnalyzerError.badResponse
        }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw CalorieAnalyzerError.authError
        case 413: throw CalorieAnalyzerError.imageTooLarge
        case 429: throw CalorieAnalyzerError.rateLimited
        default: throw CalorieAnalyzerError.serverError(http.statusCode)
        }

        let completion = try JSONDecoder().decode(ChatCompletion.self, from: data)
        guard let raw = completion.choices.first?.message.content, !raw.isEmpty else {
            throw CalorieAnalyzerError.badResponse
        }
        return try parse(raw)
    }

    private struct ChatCompletion: Codable {
        struct Choice: Codable {
            struct Message: Codable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    /// Extracts the JSON object from the model's text (tolerating code fences).
    private static func parse(_ raw: String) throws -> MealAnalysis {
        let cleaned = stripCodeFences(raw)
        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else {
            throw CalorieAnalyzerError.badResponse
        }
        let jsonSlice = String(cleaned[start...end])
        guard let jsonData = jsonSlice.data(using: .utf8) else {
            throw CalorieAnalyzerError.badResponse
        }
        do {
            return try JSONDecoder().decode(MealAnalysis.self, from: jsonData)
        } catch {
            throw CalorieAnalyzerError.badResponse
        }
    }

    private static func stripCodeFences(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            // Drop the opening fence line and trailing fence.
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

    /// Re-encodes the image to a base64 JPEG under ~3 MB raw, walking down a
    /// resolution/quality ladder. Returns nil if it can't fit the budget.
    private static func resizedBase64JPEG(from image: UIImage, maxBytes: Int = 3_000_000) -> String? {
        let ladder: [(maxEdge: CGFloat, quality: CGFloat)] = [
            (1280, 0.82), (1024, 0.78), (832, 0.74), (640, 0.70), (512, 0.65),
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

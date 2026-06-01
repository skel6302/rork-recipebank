//
//  RecipeTextParser.swift
//  RecipeBox
//

import Foundation

/// Turns raw OCR lines into a structured recipe using lightweight heuristics:
/// section headers, quantity detection, and step numbering. The result is always
/// editable by the user, so the goal is a helpful first draft, not perfection.
enum RecipeTextParser {
    private enum Section {
        case unknown, ingredients, steps
    }

    /// Common cooking measurement units used to detect ingredient lines.
    private static let units: [String] = [
        "cup", "cups", "tbsp", "tablespoon", "tablespoons", "tsp", "teaspoon", "teaspoons",
        "oz", "ounce", "ounces", "lb", "lbs", "pound", "pounds", "g", "gram", "grams",
        "kg", "ml", "l", "liter", "litre", "clove", "cloves", "pinch", "dash", "can", "cans",
        "slice", "slices", "stick", "sticks", "package", "pkg", "quart", "pint"
    ]

    nonisolated static func parse(lines rawLines: [String]) -> ScannedRecipe {
        let lines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var title = ""
        var summary = ""
        var ingredients: [DraftIngredient] = []
        var steps: [String] = []
        var section: Section = .unknown

        for (index, line) in lines.enumerated() {
            // Capture the first substantial line as the title.
            if title.isEmpty, !isHeader(line), line.count >= 3 {
                title = cleaned(line)
                continue
            }

            if let detected = headerSection(for: line) {
                section = detected
                continue
            }

            switch section {
            case .ingredients:
                ingredients.append(makeIngredient(from: line))
            case .steps:
                steps.append(stripStepNumber(from: line))
            case .unknown:
                // Before we hit a header, classify line by line.
                if looksLikeIngredient(line) {
                    ingredients.append(makeIngredient(from: line))
                } else if looksLikeStep(line) {
                    steps.append(stripStepNumber(from: line))
                } else if summary.isEmpty && index <= 3 {
                    summary = cleaned(line)
                } else {
                    steps.append(cleaned(line))
                }
            }
        }

        if title.isEmpty { title = "Scanned Recipe" }

        return ScannedRecipe(
            title: title,
            summary: summary,
            ingredients: ingredients.isEmpty ? [DraftIngredient()] : ingredients,
            steps: steps.isEmpty ? [""] : steps,
            rawText: lines.joined(separator: "\n"),
            photoData: nil
        )
    }

    // MARK: - Heuristics

    private static func headerSection(for line: String) -> Section? {
        let lower = line.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ": "))
        if ["ingredients", "you will need", "you'll need", "shopping list"].contains(lower) {
            return .ingredients
        }
        if ["instructions", "directions", "method", "steps", "preparation", "how to make"].contains(lower) {
            return .steps
        }
        return nil
    }

    private static func isHeader(_ line: String) -> Bool {
        headerSection(for: line) != nil
    }

    private static func looksLikeIngredient(_ line: String) -> Bool {
        if line.count > 70 { return false }
        let lower = line.lowercased()
        let words = lower.split(whereSeparator: { !$0.isLetter })
        if words.contains(where: { units.contains(String($0)) }) { return true }
        // Starts with a number or fraction (e.g. "2 eggs", "1/2 onion", "½ cup").
        if let first = line.first, first.isNumber || "½⅓¼¾⅔".contains(first) { return true }
        return false
    }

    private static func looksLikeStep(_ line: String) -> Bool {
        // Numbered steps like "1." or "1)" or long descriptive sentences.
        if line.range(of: #"^\d+[\.\):]"#, options: .regularExpression) != nil { return true }
        return line.count > 40
    }

    /// Splits a leading quantity (numbers + unit) from the ingredient name.
    private static func makeIngredient(from line: String) -> DraftIngredient {
        let stripped = cleaned(stripBullet(from: line))
        let tokens = stripped.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return DraftIngredient(name: stripped) }

        var quantityTokens: [String] = []
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            let lower = token.lowercased()
            let isNumeric = token.first.map { $0.isNumber || "½⅓¼¾⅔".contains($0) } ?? false
            let isUnit = units.contains(lower)
            if (isNumeric || isUnit) && quantityTokens.count < 3 {
                quantityTokens.append(token)
                index += 1
            } else {
                break
            }
        }

        let quantity = quantityTokens.joined(separator: " ")
        let name = tokens[index...].joined(separator: " ")
        if name.isEmpty {
            return DraftIngredient(name: quantity)
        }
        return DraftIngredient(name: name, quantity: quantity)
    }

    private static func stripStepNumber(from line: String) -> String {
        let result = line.replacingOccurrences(
            of: #"^\s*\d+[\.\):]\s*"#,
            with: "",
            options: .regularExpression
        )
        return cleaned(result)
    }

    private static func stripBullet(from line: String) -> String {
        line.replacingOccurrences(
            of: #"^\s*[•\-\*\u{2022}]\s*"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func cleaned(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

//
//  FoodSearchService.swift
//  RecipeBox
//

import Foundation

nonisolated enum FoodSearchError: LocalizedError {
    case badResponse
    case network
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .badResponse: return "We couldn't search the food database right now. Try again."
        case .network: return "Couldn't reach the food database. Check your connection and try again."
        case .notConfigured: return "The food database isn't set up yet. Please try again later."
        }
    }
}

/// Searches the USDA FoodData Central branded-foods database by name (e.g. "granola")
/// and returns matching foods with label nutrition, so the meal planner isn't limited
/// to recipes.
nonisolated enum FoodSearchService {
    /// Searches branded foods by free-text name. Results that lack calorie data are dropped.
    static func search(_ query: String, pageSize: Int = 25) async throws -> [AnalyzedFood] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let apiKey = Config.EXPO_PUBLIC_USDA_FDC_API_KEY
        guard !apiKey.isEmpty else { throw FoodSearchError.notConfigured }

        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "dataType", value: "Branded"),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
        ]
        guard let url = components?.url else { throw FoodSearchError.badResponse }

        var req = URLRequest(url: url)
        req.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw FoodSearchError.network
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FoodSearchError.badResponse
        }

        let decoded: SearchResponse
        do {
            decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        } catch {
            throw FoodSearchError.badResponse
        }

        var seen = Set<String>()
        return decoded.foods.compactMap { map($0) }.filter { food in
            // De-duplicate by name + calories so near-identical rows collapse.
            let key = "\(food.name.lowercased())|\(food.calories)"
            return seen.insert(key).inserted
        }
    }

    // MARK: - Mapping

    private static func map(_ food: SearchFood) -> AnalyzedFood? {
        let rawName = food.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawName.isEmpty else { return nil }

        let nutrition = USDANutrition.resolve(food)
        guard let calories = nutrition.calories else { return nil }

        let brand = (food.brandName ?? food.brandOwner)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let titled = rawName.capitalizedIfShouting
        let name = (brand?.isEmpty == false) ? "\(brand!.capitalizedIfShouting) \(titled)" : titled

        return AnalyzedFood(
            name: name,
            servingDescription: nutrition.serving,
            calories: Int(calories.rounded()),
            protein: nutrition.protein.rounded(),
            carbs: nutrition.carbs.rounded(),
            fat: nutrition.fat.rounded()
        )
    }

    // MARK: - DTOs

    private struct SearchResponse: Decodable {
        let foods: [SearchFood]
    }
}

/// A branded food returned by USDA FoodData Central search.
nonisolated struct SearchFood: Decodable {
    let description: String
    let brandOwner: String?
    let brandName: String?
    let servingSize: Double?
    let servingSizeUnit: String?
    let householdServingFullText: String?
    let labelNutrients: LabelNutrients?
    let foodNutrients: [FoodNutrient]?
    let gtinUpc: String?
}

/// Per-serving values straight off the product label (preferred when present).
nonisolated struct LabelNutrients: Decodable {
    let calories: LabelValue?
    let protein: LabelValue?
    let carbohydrates: LabelValue?
    let fat: LabelValue?
}

nonisolated struct LabelValue: Decodable {
    let value: Double?
}

/// Per-100g nutrient values; used as a fallback when there are no label nutrients.
nonisolated struct FoodNutrient: Decodable {
    let nutrientNumber: String?
    let value: Double?
}

/// Resolves calories/macros and a human serving description for a USDA food,
/// preferring per-serving label nutrients and falling back to per-100g nutrients.
nonisolated enum USDANutrition {
    struct Result {
        let calories: Double?
        let protein: Double
        let carbs: Double
        let fat: Double
        let serving: String
    }

    static func resolve(_ food: SearchFood) -> Result {
        // 1) Label nutrients are already per serving — the cleanest source.
        if let label = food.labelNutrients, let cals = label.calories?.value {
            return Result(
                calories: cals,
                protein: label.protein?.value ?? 0,
                carbs: label.carbohydrates?.value ?? 0,
                fat: label.fat?.value ?? 0,
                serving: servingDescription(food, perServing: true)
            )
        }

        // 2) Fall back to per-100g nutrients by USDA nutrient number.
        let byNumber = Dictionary(
            (food.foodNutrients ?? []).compactMap { n -> (String, Double)? in
                guard let num = n.nutrientNumber, let v = n.value else { return nil }
                return (num, v)
            },
            uniquingKeysWith: { first, _ in first }
        )
        if let cals = byNumber["208"] {
            return Result(
                calories: cals,
                protein: byNumber["203"] ?? 0,
                carbs: byNumber["205"] ?? 0,
                fat: byNumber["204"] ?? 0,
                serving: "100 g"
            )
        }

        return Result(calories: nil, protein: 0, carbs: 0, fat: 0, serving: "1 serving")
    }

    static func servingDescription(_ food: SearchFood, perServing: Bool) -> String {
        if let household = food.householdServingFullText?
            .trimmingCharacters(in: .whitespacesAndNewlines), !household.isEmpty {
            return household.capitalizedIfShouting
        }
        if let size = food.servingSize {
            let unit = food.servingSizeUnit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "g"
            let amount = size.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(size)) : String(size)
            return "\(amount) \(unit)"
        }
        return perServing ? "1 serving" : "100 g"
    }
}

nonisolated extension String {
    /// USDA returns many names in ALL CAPS; downcase those for nicer display.
    var capitalizedIfShouting: String {
        let letters = filter { $0.isLetter }
        guard !letters.isEmpty, letters.allSatisfy({ $0.isUppercase }) else { return self }
        return capitalized
    }
}

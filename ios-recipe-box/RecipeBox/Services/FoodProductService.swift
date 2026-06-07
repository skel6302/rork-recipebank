//
//  FoodProductService.swift
//  RecipeBox
//

import Foundation

nonisolated enum FoodProductError: LocalizedError {
    case notFound
    case badResponse
    case network
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .notFound: return "We couldn't find that product. Try scanning again or add it manually."
        case .badResponse: return "That barcode didn't return usable nutrition info. Try adding it manually."
        case .network: return "Couldn't reach the food database. Check your connection and try again."
        case .notConfigured: return "The food database isn't set up yet. Please try again later."
        }
    }
}

/// Looks up packaged-food nutrition by barcode (UPC/GTIN) using USDA FoodData Central.
/// Returns a `MealAnalysis` so the result reuses the existing review/log UI.
nonisolated enum FoodProductService {
    /// Looks up a product by its barcode (UPC/EAN) and maps it into a `MealAnalysis`.
    static func lookup(barcode: String) async throws -> MealAnalysis {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FoodProductError.badResponse }

        let apiKey = Config.EXPO_PUBLIC_USDA_FDC_API_KEY
        guard !apiKey.isEmpty else { throw FoodProductError.notConfigured }

        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "dataType", value: "Branded"),
            URLQueryItem(name: "pageSize", value: "10"),
        ]
        guard let url = components?.url else { throw FoodProductError.badResponse }

        var req = URLRequest(url: url)
        req.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw FoodProductError.network
        }

        guard let http = response as? HTTPURLResponse else { throw FoodProductError.badResponse }
        guard http.statusCode == 200 else { throw FoodProductError.badResponse }

        let decoded: SearchResponse
        do {
            decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        } catch {
            throw FoodProductError.badResponse
        }

        // Prefer an exact barcode match; otherwise take the first usable result.
        let exact = decoded.foods.first { ($0.gtinUpc ?? "").trimmingCharacters(in: .whitespaces) == trimmed }
        guard let product = exact ?? decoded.foods.first else {
            throw FoodProductError.notFound
        }
        return try map(product)
    }

    // MARK: - Mapping

    private static func map(_ food: SearchFood) throws -> MealAnalysis {
        let nutrition = USDANutrition.resolve(food)
        guard let calories = nutrition.calories else { throw FoodProductError.badResponse }

        let baseName = food.description.trimmingCharacters(in: .whitespacesAndNewlines).capitalizedIfShouting
        let name = baseName.isEmpty ? "Scanned Product" : baseName
        let brand = (food.brandName ?? food.brandOwner)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (brand?.isEmpty == false) ? "\(brand!.capitalizedIfShouting) \(name)" : name

        let item = AnalyzedFood(
            name: displayName,
            servingDescription: nutrition.serving,
            calories: Int(calories.rounded()),
            protein: nutrition.protein.rounded(),
            carbs: nutrition.carbs.rounded(),
            fat: nutrition.fat.rounded()
        )

        let note = "Nutrition shown per serving from USDA FoodData Central. Adjust if your portion differs."
        return MealAnalysis(mealName: displayName, items: [item], note: note)
    }

    // MARK: - DTOs

    private struct SearchResponse: Decodable {
        let foods: [SearchFood]
    }
}

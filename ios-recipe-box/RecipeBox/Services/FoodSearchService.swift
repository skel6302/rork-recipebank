//
//  FoodSearchService.swift
//  RecipeBox
//

import Foundation

nonisolated enum FoodSearchError: LocalizedError {
    case badResponse
    case network

    var errorDescription: String? {
        switch self {
        case .badResponse: return "We couldn't search the food database right now. Try again."
        case .network: return "Couldn't reach the food database. Check your connection and try again."
        }
    }
}

/// Searches the free Open Food Facts database by name (e.g. "bagel") and returns
/// matching foods with nutrition, so the meal planner isn't limited to recipes.
nonisolated enum FoodSearchService {
    /// Searches foods by free-text name. Results that lack calorie data are dropped.
    static func search(_ query: String, pageSize: Int = 25) async throws -> [AnalyzedFood] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "fields", value: "product_name,brands,serving_size,nutriments"),
        ]
        guard let url = components?.url else { throw FoodSearchError.badResponse }

        var req = URLRequest(url: url)
        req.setValue("RecipeBank/1.0 (iOS app)", forHTTPHeaderField: "User-Agent")
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
        return decoded.products.compactMap { map($0) }.filter { food in
            // De-duplicate by name + calories so near-identical rows collapse.
            let key = "\(food.name.lowercased())|\(food.calories)"
            return seen.insert(key).inserted
        }
    }

    // MARK: - Mapping

    private static func map(_ product: Product) -> AnalyzedFood? {
        guard let rawName = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty else { return nil }
        let nutriments = product.nutriments ?? Nutriments()

        let hasServing = nutriments.energyKcalServing != nil
        guard let calories = nutriments.energyKcalServing ?? nutriments.energyKcal100g else { return nil }

        let protein = nutriments.proteinsServing ?? nutriments.proteins100g ?? 0
        let carbs = nutriments.carbohydratesServing ?? nutriments.carbohydrates100g ?? 0
        let fat = nutriments.fatServing ?? nutriments.fat100g ?? 0

        let brand = product.brands?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
        let name = (brand?.isEmpty == false) ? "\(brand!) \(rawName)" : rawName

        let serving: String
        if hasServing, let s = product.servingSize?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            serving = s
        } else if hasServing {
            serving = "1 serving"
        } else {
            serving = "100 g"
        }

        return AnalyzedFood(
            name: name,
            servingDescription: serving,
            calories: Int(calories.rounded()),
            protein: protein.rounded(),
            carbs: carbs.rounded(),
            fat: fat.rounded()
        )
    }

    // MARK: - DTOs

    private struct SearchResponse: Decodable {
        let products: [Product]
    }

    private struct Product: Decodable {
        let productName: String?
        let brands: String?
        let servingSize: String?
        let nutriments: Nutriments?

        private enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case brands
            case servingSize = "serving_size"
            case nutriments
        }
    }

    /// Open Food Facts numeric fields can arrive as numbers or strings, so decode leniently.
    private struct Nutriments: Decodable {
        var energyKcalServing: Double?
        var energyKcal100g: Double?
        var proteinsServing: Double?
        var proteins100g: Double?
        var carbohydratesServing: Double?
        var carbohydrates100g: Double?
        var fatServing: Double?
        var fat100g: Double?

        init() {}

        private enum CodingKeys: String, CodingKey {
            case energyKcalServing = "energy-kcal_serving"
            case energyKcal100g = "energy-kcal_100g"
            case proteinsServing = "proteins_serving"
            case proteins100g = "proteins_100g"
            case carbohydratesServing = "carbohydrates_serving"
            case carbohydrates100g = "carbohydrates_100g"
            case fatServing = "fat_serving"
            case fat100g = "fat_100g"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            func value(_ key: CodingKeys) -> Double? {
                if let d = try? c.decode(Double.self, forKey: key) { return d }
                if let s = try? c.decode(String.self, forKey: key) { return Double(s) }
                return nil
            }
            energyKcalServing = value(.energyKcalServing)
            energyKcal100g = value(.energyKcal100g)
            proteinsServing = value(.proteinsServing)
            proteins100g = value(.proteins100g)
            carbohydratesServing = value(.carbohydratesServing)
            carbohydrates100g = value(.carbohydrates100g)
            fatServing = value(.fatServing)
            fat100g = value(.fat100g)
        }
    }
}

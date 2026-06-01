//
//  FoodProductService.swift
//  RecipeBox
//

import Foundation

nonisolated enum FoodProductError: LocalizedError {
    case notFound
    case badResponse
    case network

    var errorDescription: String? {
        switch self {
        case .notFound: return "We couldn't find that product. Try scanning again or add it manually."
        case .badResponse: return "That barcode didn't return usable nutrition info. Try adding it manually."
        case .network: return "Couldn't reach the food database. Check your connection and try again."
        }
    }
}

/// Looks up packaged-food nutrition by barcode using the free Open Food Facts database.
/// Returns a `MealAnalysis` so the result reuses the existing review/log UI.
nonisolated enum FoodProductService {
    /// Looks up a product by its barcode (UPC/EAN) and maps it into a `MealAnalysis`.
    static func lookup(barcode: String) async throws -> MealAnalysis {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(trimmed).json?fields=product_name,brands,serving_size,nutriments") else {
            throw FoodProductError.badResponse
        }

        var req = URLRequest(url: url)
        req.setValue("RecipeBank/1.0 (iOS app)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 30

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw FoodProductError.network
        }

        guard let http = response as? HTTPURLResponse else { throw FoodProductError.badResponse }
        guard http.statusCode == 200 else {
            if http.statusCode == 404 { throw FoodProductError.notFound }
            throw FoodProductError.badResponse
        }

        let decoded: ProductResponse
        do {
            decoded = try JSONDecoder().decode(ProductResponse.self, from: data)
        } catch {
            throw FoodProductError.badResponse
        }

        guard decoded.status == 1, let product = decoded.product else {
            throw FoodProductError.notFound
        }
        return try map(product)
    }

    // MARK: - Mapping

    private static func map(_ product: Product) throws -> MealAnalysis {
        let nutriments = product.nutriments ?? Nutriments()

        // Prefer per-serving values; fall back to per-100g.
        let hasServing = nutriments.energyKcalServing != nil
        let calories = nutriments.energyKcalServing ?? nutriments.energyKcal100g
        let protein = nutriments.proteinsServing ?? nutriments.proteins100g
        let carbs = nutriments.carbohydratesServing ?? nutriments.carbohydrates100g
        let fat = nutriments.fatServing ?? nutriments.fat100g

        guard let calories else { throw FoodProductError.badResponse }

        let baseName = (product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Scanned Product"
        let brand = product.brands?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
        let displayName = (brand?.isEmpty == false) ? "\(brand!) \(baseName)" : baseName

        let serving: String
        if hasServing, let s = product.servingSize?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            serving = s
        } else if hasServing {
            serving = "1 serving"
        } else {
            serving = "100 g"
        }

        let food = AnalyzedFood(
            name: displayName,
            servingDescription: serving,
            calories: Int(calories.rounded()),
            protein: (protein ?? 0).rounded(),
            carbs: (carbs ?? 0).rounded(),
            fat: (fat ?? 0).rounded()
        )

        let note = hasServing
            ? "Nutrition shown per serving from Open Food Facts. Adjust if your portion differs."
            : "Per-serving info wasn't available, so values are per 100 g from Open Food Facts."

        return MealAnalysis(mealName: displayName, items: [food], note: note)
    }

    // MARK: - DTOs

    private struct ProductResponse: Decodable {
        let status: Int
        let product: Product?
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

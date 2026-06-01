//
//  GroceryService.swift
//  RecipeBox
//

import SwiftUI

/// A grocery delivery / pickup service the shopping list can be sent to.
enum GroceryProvider: String, CaseIterable, Identifiable {
    case amazonAlexa = "Alexa Shopping List"
    case instacart = "Instacart"
    case amazonFresh = "Amazon Fresh"
    case walmart = "Walmart"
    case kroger = "Kroger"
    case wholeFoods = "Whole Foods"

    var id: String { rawValue }

    /// Whether this destination is a list to add items to (vs. a store to shop).
    var isListSync: Bool { self == .amazonAlexa }

    var symbol: String {
        switch self {
        case .amazonAlexa: return "mic.fill"
        case .instacart: return "cart.fill"
        case .amazonFresh: return "leaf.fill"
        case .walmart: return "basket.fill"
        case .kroger: return "bag.fill"
        case .wholeFoods: return "carrot.fill"
        }
    }

    var tint: Color {
        switch self {
        case .amazonAlexa: return Color(red: 0.0, green: 0.71, blue: 0.84)
        case .instacart: return Color(red: 0.27, green: 0.66, blue: 0.27)
        case .amazonFresh: return Color(red: 0.36, green: 0.62, blue: 0.40)
        case .walmart: return Color(red: 0.16, green: 0.42, blue: 0.78)
        case .kroger: return Color(red: 0.0, green: 0.36, blue: 0.66)
        case .wholeFoods: return Color(red: 0.13, green: 0.45, blue: 0.27)
        }
    }

    var tagline: String {
        switch self {
        case .amazonAlexa: return "Add items to your Alexa shopping list"
        case .instacart: return "Same-day delivery from local stores"
        case .amazonFresh: return "Fast grocery delivery with Prime"
        case .walmart: return "Pickup & delivery nationwide"
        case .kroger: return "Order from your local Kroger"
        case .wholeFoods: return "Organic groceries via Amazon"
        }
    }

    /// Base storefront / list URL used to open the provider.
    private var baseURL: String {
        switch self {
        case .amazonAlexa: return "https://www.amazon.com/alexaquantum/sp/alexaShoppingList"
        case .instacart: return "https://www.instacart.com/store/s"
        case .amazonFresh: return "https://www.amazon.com/alm/storefront"
        case .walmart: return "https://www.walmart.com/search"
        case .kroger: return "https://www.kroger.com/search"
        case .wholeFoods: return "https://www.amazon.com/fmc/storefront"
        }
    }

    /// Deep link into the native Alexa app, when installed.
    var appURL: URL? {
        switch self {
        case .amazonAlexa: return URL(string: "alexa://")
        default: return nil
        }
    }

    /// Builds a deep link that pre-fills a search for the given items where supported.
    func url(for items: [ShoppingItem]) -> URL? {
        let names = items.map { $0.name }
        let query = names.joined(separator: ", ")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString: String
        switch self {
        case .instacart, .kroger:
            urlString = "\(baseURL)?k=\(encoded)"
        case .walmart:
            urlString = "\(baseURL)?q=\(encoded)"
        default:
            urlString = baseURL
        }
        return URL(string: urlString)
    }
}

/// Builds shareable / sendable representations of a shopping list.
enum GroceryService {
    /// Aggregates ingredients from recipes into shopping items, merging duplicates by name.
    static func shoppingItems(from recipes: [Recipe]) -> [ShoppingItem] {
        var merged: [String: ShoppingItem] = [:]
        for recipe in recipes {
            for ing in recipe.ingredients {
                let key = ing.name.lowercased()
                if let existing = merged[key] {
                    // Combine quantities as a readable note.
                    if !ing.quantity.isEmpty {
                        existing.quantity = existing.quantity.isEmpty
                            ? ing.quantity
                            : "\(existing.quantity) + \(ing.quantity)"
                    }
                } else {
                    merged[key] = ShoppingItem(
                        name: ing.name,
                        quantity: ing.quantity,
                        aisle: ing.aisle,
                        sourceRecipeTitle: recipe.title
                    )
                }
            }
        }
        return Array(merged.values).sorted { $0.aisle.order < $1.aisle.order }
    }

    /// Plain-text export grouped by aisle, suitable for sharing or pasting.
    static func plainText(for items: [ShoppingItem]) -> String {
        let grouped = Dictionary(grouping: items) { $0.aisle }
        var lines: [String] = ["🛒 My Shopping List", ""]
        for aisle in GroceryAisle.allCases {
            guard let group = grouped[aisle], !group.isEmpty else { continue }
            lines.append(aisle.rawValue.uppercased())
            for item in group {
                lines.append("• \(item.displayLine)")
            }
            lines.append("")
        }
        lines.append("Made with Recipe Box")
        return lines.joined(separator: "\n")
    }

    /// Simple one-item-per-line export, ideal for pasting into a list app like Alexa.
    static func listLines(for items: [ShoppingItem]) -> String {
        items.map { $0.displayLine }.joined(separator: "\n")
    }
}

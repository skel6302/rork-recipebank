//
//  GroceryCartService.swift
//  RecipeBox
//

import Foundation
import Supabase

nonisolated struct InstacartLineItem: Encodable, Sendable {
    let name: String
    let quantity: String
    let displayText: String

    enum CodingKeys: String, CodingKey {
        case name
        case quantity
        case displayText = "display_text"
    }
}

nonisolated struct InstacartCartRequest: Encodable, Sendable {
    let title: String
    let items: [InstacartLineItem]
}

nonisolated struct InstacartCartResponse: Codable, Sendable {
    let url: String
}

/// Builds ready-to-checkout grocery carts via provider APIs.
enum GroceryCartService {
    /// Sends the list to Instacart's Developer Platform and returns a shareable cart
    /// URL where the items are pre-loaded. Returns `nil` if Instacart isn't configured
    /// or the call fails, so callers can fall back to the deep-link search flow.
    static func instacartCartURL(for items: [ShoppingItem], title: String = "My Recipe Box List") async -> URL? {
        let lineItems = items
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { InstacartLineItem(name: $0.name, quantity: $0.quantity, displayText: $0.displayLine) }
        guard !lineItems.isEmpty else { return nil }

        do {
            let response: InstacartCartResponse = try await supabase.functions.invoke(
                "instacart-cart",
                options: .init(body: InstacartCartRequest(title: title, items: lineItems))
            )
            return URL(string: response.url)
        } catch {
            print("Instacart cart export failed: \(error)")
            return nil
        }
    }
}

//
//  SubscriptionTier.swift
//  RecipeBox
//

import Foundation

/// Billing cycle options offered on the paywall.
enum BillingCycle {
    case monthly
    case yearly
}

/// RecipeBank's three plans. Basic (free) stores up to 50 recipes plus the
/// grocery list; Plus ($4.99/mo or $29.99/yr) adds unlimited recipes, meal
/// planning and calorie tracking; Pro ($6.99/mo or $39.99/yr) adds the GLP-1
/// companion on top. New subscribers get a 7-day free trial.
enum SubscriptionTier: String, Codable, CaseIterable, Comparable {
    case free
    case plus
    case pro

    /// Ordering rank so tiers can be compared (`tier >= .plus`).
    private var rank: Int {
        switch self {
        case .free: return 0
        case .plus: return 1
        case .pro: return 2
        }
    }

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rank < rhs.rank
    }

    var displayName: String {
        switch self {
        case .free: return "Basic"
        case .plus: return "Plus"
        case .pro: return "Pro"
        }
    }

    var priceLabel: String {
        switch self {
        case .free: return "Free"
        case .plus: return "$4.99/mo · $29.99/yr"
        case .pro: return "$6.99/mo · $39.99/yr"
        }
    }

    var tagline: String {
        switch self {
        case .free: return "Your recipe box, always free"
        case .plus: return "Meal planning & calorie tracking"
        case .pro: return "Everything + the GLP-1 companion"
        }
    }

    /// Features shown on the paywall card for this tier.
    var features: [String] {
        switch self {
        case .free:
            return [
                "Save up to 50 recipes",
                "Import from links, photos & scans",
                "Grocery & shopping list",
            ]
        case .plus:
            return [
                "Unlimited recipe storage",
                "Weekly meal planner",
                "Calorie & macro tracking",
                "Food database search & barcodes",
            ]
        case .pro:
            return [
                "Everything in Plus",
                "GLP-1 dose tracking & reminders",
                "Injection-site rotation",
                "Weight progress tracking",
                "GLP-1 nutrition guide",
            ]
        }
    }
}

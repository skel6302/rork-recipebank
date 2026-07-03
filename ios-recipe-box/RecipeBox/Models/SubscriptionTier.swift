//
//  SubscriptionTier.swift
//  RecipeBox
//

import Foundation

/// The three RecipeBank plans. Free covers recipe storage + grocery list,
/// Plus adds meal planning and calorie counting, Pro unlocks everything
/// including GLP-1 tracking.
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
        case .plus: return "$4.99/mo"
        case .pro: return "$6.99/mo"
        }
    }

    var tagline: String {
        switch self {
        case .free: return "Your recipe box, always free"
        case .plus: return "Plan your week & hit your goals"
        case .pro: return "The full GLP-1 companion"
        }
    }

    /// Store product identifier used once App Store billing is wired up.
    /// Free has no product.
    var productIdentifier: String? {
        switch self {
        case .free: return nil
        case .plus: return "recipebank_plus_monthly"
        case .pro: return "recipebank_pro_monthly"
        }
    }

    /// Features shown on the paywall card for this tier.
    var features: [String] {
        switch self {
        case .free:
            return [
                "Unlimited recipe storage",
                "Import from links, photos & scans",
                "Grocery & shopping list",
            ]
        case .plus:
            return [
                "Everything in Basic",
                "Weekly meal planner",
                "Calorie & macro tracking",
                "Food database search",
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

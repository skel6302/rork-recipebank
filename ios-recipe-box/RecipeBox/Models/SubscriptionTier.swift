//
//  SubscriptionTier.swift
//  RecipeBox
//

import Foundation

/// RecipeBank's two plans. Basic (free) covers recipe storage + grocery
/// list; Pro unlocks everything — meal planning, calorie tracking, and the
/// GLP-1 companion — for $5/month or $30/year.
enum SubscriptionTier: String, Codable, CaseIterable, Comparable {
    case free
    case pro

    /// Ordering rank so tiers can be compared (`tier >= .pro`).
    private var rank: Int {
        switch self {
        case .free: return 0
        case .pro: return 1
        }
    }

    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rank < rhs.rank
    }

    var displayName: String {
        switch self {
        case .free: return "Basic"
        case .pro: return "Pro"
        }
    }

    var priceLabel: String {
        switch self {
        case .free: return "Free"
        case .pro: return "$5/mo · $30/yr"
        }
    }

    var tagline: String {
        switch self {
        case .free: return "Your recipe box, always free"
        case .pro: return "Meal planning, calories & GLP-1"
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
        case .pro:
            return [
                "Everything in Basic",
                "Weekly meal planner",
                "Calorie & macro tracking",
                "Food database search",
                "GLP-1 dose tracking & reminders",
                "Injection-site rotation",
                "Weight progress tracking",
                "GLP-1 nutrition guide",
            ]
        }
    }
}

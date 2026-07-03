//
//  SubscriptionStore.swift
//  RecipeBox
//

import Foundation
import Observation

/// Holds the user's current plan and answers feature-gating questions.
///
/// Billing note: this store currently activates plans locally (founder
/// preview mode) because the RevenueCat connection is still pending. The
/// public surface (`activate`, `restore`, `tier`) is shaped so the RevenueCat
/// SDK can be dropped in behind it without touching any views.
@Observable
final class SubscriptionStore {
    private static let storageKey = "subscription.tier.v1"

    /// The user's active plan.
    private(set) var tier: SubscriptionTier

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = SubscriptionTier(rawValue: raw) {
            tier = saved
        } else {
            tier = .free
        }
    }

    // MARK: - Feature gates

    /// Plus and above: weekly meal planner.
    var canUseMealPlanning: Bool { tier >= .plus }

    /// Plus and above: calorie & macro tracking.
    var canUseCalorieTracking: Bool { tier >= .plus }

    /// Pro only: GLP-1 tracking, reminders, and guide.
    var canUseGLP1: Bool { tier >= .pro }

    /// The cheapest tier that unlocks the given gated feature.
    enum GatedFeature {
        case mealPlanning
        case calorieTracking
        case glp1

        var requiredTier: SubscriptionTier {
            switch self {
            case .mealPlanning, .calorieTracking: return .plus
            case .glp1: return .pro
            }
        }
    }

    // MARK: - Plan changes

    /// Activates a plan. Currently a local unlock (no charge); will run a
    /// RevenueCat purchase once billing is connected.
    func activate(_ newTier: SubscriptionTier) {
        tier = newTier
        UserDefaults.standard.set(newTier.rawValue, forKey: Self.storageKey)
    }

    /// Restores previous purchases. Placeholder until billing is connected —
    /// returns false meaning "nothing to restore".
    func restorePurchases() async -> Bool {
        false
    }
}

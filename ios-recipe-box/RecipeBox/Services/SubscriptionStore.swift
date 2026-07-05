//
//  SubscriptionStore.swift
//  RecipeBox
//

import Foundation
import Observation
import RevenueCat

/// Holds the user's current plan, answers feature-gating questions, and runs
/// real purchases through RevenueCat.
///
/// The "RecipeBank Pro" entitlement maps to `.pro`, "RecipeBank Plus" maps to
/// `.plus`, and everything else is `.free`. Pro products are attached to both
/// entitlements in RevenueCat, so a Pro subscription activates Plus features
/// automatically.
@Observable
final class SubscriptionStore {
    /// RevenueCat entitlement that unlocks meal planning + calorie tracking.
    static let plusEntitlementID = "RecipeBank Plus"

    /// RevenueCat entitlement that unlocks everything, including GLP-1.
    static let proEntitlementID = "RecipeBank Pro"

    /// Maximum number of stored recipes on the free plan.
    static let freeRecipeLimit = 50

    /// The user's active plan.
    private(set) var tier: SubscriptionTier = .free

    /// Packages from the current offering, keyed by paywall option.
    private(set) var plusMonthlyPackage: Package?
    private(set) var plusAnnualPackage: Package?
    private(set) var proMonthlyPackage: Package?
    private(set) var proAnnualPackage: Package?

    /// True while the offering (prices) is being fetched.
    private(set) var isLoadingOfferings = false

    /// True while a purchase is in flight.
    private(set) var isPurchasing = false

    /// User-facing error from the last purchase/restore/load attempt.
    var errorMessage: String?

    init() {
        // Previews and tests may build this store before Purchases.configure
        // runs in the app entry point — skip SDK work in that case.
        guard Purchases.isConfigured else { return }
        Task { await listenForCustomerInfo() }
        Task { await loadOfferings() }
    }

    // MARK: - Feature gates

    /// Plus and up: weekly meal planner.
    var canUseMealPlanning: Bool { tier >= .plus }

    /// Plus and up: calorie & macro tracking.
    var canUseCalorieTracking: Bool { tier >= .plus }

    /// Pro only: GLP-1 tracking, reminders, and guide.
    var canUseGLP1: Bool { tier >= .pro }

    /// Whether another recipe can be saved. Free users are capped at
    /// `freeRecipeLimit`; paid plans are unlimited.
    func canAddRecipe(currentCount: Int) -> Bool {
        tier > .free || currentCount < Self.freeRecipeLimit
    }

    // MARK: - Offerings

    /// The package matching a paywall selection, if it has loaded.
    func package(for tier: SubscriptionTier, cycle: BillingCycle) -> Package? {
        switch (tier, cycle) {
        case (.plus, .monthly): return plusMonthlyPackage
        case (.plus, .yearly): return plusAnnualPackage
        case (.pro, .monthly): return proMonthlyPackage
        case (.pro, .yearly): return proAnnualPackage
        default: return nil
        }
    }

    /// Fetches the current offering so the paywall can show live prices.
    func loadOfferings() async {
        guard Purchases.isConfigured else { return }
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            let current = try await Purchases.shared.offerings().current
            plusMonthlyPackage = current?.package(identifier: "plus_monthly")
            plusAnnualPackage = current?.package(identifier: "plus_annual")
            proMonthlyPackage = current?.package(identifier: "pro_monthly")
            proAnnualPackage = current?.package(identifier: "pro_annual")
        } catch {
            print("[SubscriptionStore] Failed to load offerings: \(error.localizedDescription)")
            errorMessage = "Couldn't load plans. Check your connection and try again."
        }
    }

    // MARK: - Purchases

    /// Runs a RevenueCat purchase for the given package. Entitlement state
    /// updates immediately on success.
    func purchase(_ package: Package) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                apply(result.customerInfo)
            }
        } catch ErrorCode.purchaseCancelledError {
            // User closed the payment sheet — not an error.
        } catch ErrorCode.paymentPendingError {
            // Awaiting approval / extra auth — not a failure.
        } catch {
            print("[SubscriptionStore] Purchase failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Restores previous purchases. Returns true when a paid subscription was
    /// found and re-activated.
    @discardableResult
    func restorePurchases() async -> Bool {
        guard Purchases.isConfigured else { return false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            return tier > .free
        } catch {
            print("[SubscriptionStore] Restore failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Entitlement sync

    /// Streams customer-info updates (purchases, renewals, expirations) so the
    /// plan stays correct across launches and devices.
    private func listenForCustomerInfo() async {
        for await info in Purchases.shared.customerInfoStream {
            apply(info)
        }
    }

    private func apply(_ info: CustomerInfo) {
        if info.entitlements[Self.proEntitlementID]?.isActive == true {
            tier = .pro
        } else if info.entitlements[Self.plusEntitlementID]?.isActive == true {
            tier = .plus
        } else {
            tier = .free
        }
    }
}

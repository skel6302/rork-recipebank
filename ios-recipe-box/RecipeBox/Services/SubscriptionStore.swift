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
/// The "RecipeBank Pro" entitlement (active on either the $5/mo or $30/yr
/// subscription) maps to `SubscriptionTier.pro`; everything else is `.free`.
@Observable
final class SubscriptionStore {
    /// RevenueCat entitlement identifier that unlocks all Pro features.
    static let entitlementID = "RecipeBank Pro"

    /// The user's active plan.
    private(set) var tier: SubscriptionTier = .free

    /// The $5/month package from the current offering.
    private(set) var monthlyPackage: Package?

    /// The $30/year package from the current offering.
    private(set) var annualPackage: Package?

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

    /// Pro: weekly meal planner.
    var canUseMealPlanning: Bool { tier >= .pro }

    /// Pro: calorie & macro tracking.
    var canUseCalorieTracking: Bool { tier >= .pro }

    /// Pro: GLP-1 tracking, reminders, and guide.
    var canUseGLP1: Bool { tier >= .pro }

    // MARK: - Offerings

    /// Fetches the current offering so the paywall can show live prices.
    func loadOfferings() async {
        guard Purchases.isConfigured else { return }
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }
        do {
            let offerings = try await Purchases.shared.offerings()
            monthlyPackage = offerings.current?.monthly
            annualPackage = offerings.current?.annual
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

    /// Restores previous purchases. Returns true when a Pro subscription was
    /// found and re-activated.
    @discardableResult
    func restorePurchases() async -> Bool {
        guard Purchases.isConfigured else { return false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            return tier == .pro
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
        tier = info.entitlements[Self.entitlementID]?.isActive == true ? .pro : .free
    }
}

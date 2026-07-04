//
//  PaywallView.swift
//  RecipeBox
//

import SwiftUI
import RevenueCat

/// RecipeBank Pro paywall in the warm cookbook style. Offers the $5/month and
/// $30/year subscriptions through RevenueCat and includes purchase restore.
struct PaywallView: View {
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    /// Kept for callers that pre-select a tier from a locked tab.
    var highlightedTier: SubscriptionTier = .pro

    private enum BillingCycle {
        case monthly
        case yearly
    }

    @State private var cycle: BillingCycle = .yearly
    @State private var showingNothingToRestore = false
    @State private var justUnlocked = false

    var body: some View {
        @Bindable var subscriptions = subscriptions
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if subscriptions.tier == .pro {
                        currentPlanCard
                    } else {
                        billingCards
                    }
                    featureCard
                    freePlanCard
                    footnote
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            .background(Theme.paper.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { ctaBar }
            .navigationTitle("RecipeBank Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Theme.spice)
                }
            }
        }
        .tint(Theme.spice)
        .task {
            if subscriptions.monthlyPackage == nil || subscriptions.annualPackage == nil {
                await subscriptions.loadOfferings()
            }
        }
        .onChange(of: subscriptions.tier) { _, newTier in
            if newTier == .pro {
                justUnlocked.toggle()
                dismiss()
            }
        }
        .alert("Nothing to restore", isPresented: $showingNothingToRestore) {
            Button("OK") { }
        } message: {
            Text("We couldn't find a previous subscription for this Apple ID.")
        }
        .alert("Something went wrong", isPresented: .init(
            get: { subscriptions.errorMessage != nil },
            set: { if !$0 { subscriptions.errorMessage = nil } }
        )) {
            Button("OK") { subscriptions.errorMessage = nil }
        } message: {
            Text(subscriptions.errorMessage ?? "")
        }
        .sensoryFeedback(.success, trigger: justUnlocked)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.warmGradient).frame(width: 64, height: 64)
                Image(systemName: "crown.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Get more from RecipeBank")
                .font(.cookbookSerif(24, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Meal planning, calorie tracking, and the full GLP-1 companion — one simple plan.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Billing options

    private var billingCards: some View {
        HStack(spacing: 12) {
            BillingCard(
                title: "Monthly",
                price: monthlyPriceLabel,
                per: "per month",
                badge: nil,
                isSelected: cycle == .monthly
            ) {
                withAnimation(.spring(duration: 0.3)) { cycle = .monthly }
            }
            BillingCard(
                title: "Yearly",
                price: yearlyPriceLabel,
                per: "per year · $2.50/mo",
                badge: "SAVE 50%",
                isSelected: cycle == .yearly
            ) {
                withAnimation(.spring(duration: 0.3)) { cycle = .yearly }
            }
        }
    }

    private var monthlyPriceLabel: String {
        subscriptions.monthlyPackage?.storeProduct.localizedPriceString ?? "$5.00"
    }

    private var yearlyPriceLabel: String {
        subscriptions.annualPackage?.storeProduct.localizedPriceString ?? "$30.00"
    }

    private var selectedPackage: Package? {
        cycle == .monthly ? subscriptions.monthlyPackage : subscriptions.annualPackage
    }

    private var currentPlanCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.sage)
            VStack(alignment: .leading, spacing: 2) {
                Text("You're on Pro")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Manage or cancel anytime in Settings → Apple ID → Subscriptions.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.sage.opacity(0.12), in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.sage.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Features

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Everything in Pro")
                .font(.cookbookSerif(18, weight: .bold))
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 9) {
                ForEach(SubscriptionTier.pro.features, id: \.self) { feature in
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.spice)
                        Text(feature)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private var freePlanCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Basic")
                    .font(.cookbookSerif(16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("FREE FOREVER")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Theme.spiceDeep)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.spice.opacity(0.14), in: .capsule)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 7) {
                ForEach(SubscriptionTier.free.features, id: \.self) { feature in
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.sage)
                        Text(feature)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised.opacity(0.6), in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.ink.opacity(0.05), lineWidth: 1))
    }

    // MARK: - CTA

    private var ctaBar: some View {
        VStack(spacing: 10) {
            if subscriptions.tier != .pro {
                Button {
                    guard let package = selectedPackage else { return }
                    Task { await subscriptions.purchase(package) }
                } label: {
                    Group {
                        if subscriptions.isPurchasing || subscriptions.isLoadingOfferings {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(ctaTitle)
                                .font(.system(size: 17, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        selectedPackage == nil && !subscriptions.isLoadingOfferings
                            ? AnyShapeStyle(Theme.inkSoft.opacity(0.35))
                            : AnyShapeStyle(Theme.warmGradient),
                        in: .rect(cornerRadius: 16)
                    )
                }
                .buttonStyle(.plain)
                .disabled(subscriptions.isPurchasing || subscriptions.isLoadingOfferings || selectedPackage == nil)
            }

            Button {
                Task {
                    let restored = await subscriptions.restorePurchases()
                    if !restored && subscriptions.errorMessage == nil {
                        showingNothingToRestore = true
                    }
                }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(.thinMaterial)
    }

    private var ctaTitle: String {
        cycle == .monthly
            ? "Start Pro · \(monthlyPriceLabel)/month"
            : "Start Pro · \(yearlyPriceLabel)/year"
    }

    private var footnote: some View {
        Text("Payment is charged to your Apple ID at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel anytime in Settings.")
            .font(.system(size: 11))
            .foregroundStyle(Theme.inkSoft.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.top, 2)
    }
}

// MARK: - Billing card

private struct BillingCard: View {
    let title: String
    let price: String
    let per: String
    let badge: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 8.5, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Theme.sage, in: .capsule)
                    }
                }
                Text(price)
                    .font(.cookbookSerif(24, weight: .bold))
                    .foregroundStyle(isSelected ? Theme.spice : Theme.ink)
                Text(per)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paperRaised, in: .rect(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? Theme.spice : Theme.ink.opacity(0.06),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? Theme.spice.opacity(0.15) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionStore())
}

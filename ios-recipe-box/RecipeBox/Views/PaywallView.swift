//
//  PaywallView.swift
//  RecipeBox
//

import SwiftUI
import RevenueCat

/// RecipeBank paywall in the warm cookbook style. Offers the Plus and Pro
/// subscriptions (monthly or yearly) through RevenueCat, leads with the 7-day
/// free trial, and includes purchase restore.
struct PaywallView: View {
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    /// Pre-selects a tier when opened from a locked feature.
    let highlightedTier: SubscriptionTier

    @State private var selectedTier: SubscriptionTier
    @State private var cycle: BillingCycle = .yearly
    @State private var showingNothingToRestore = false
    @State private var justUnlocked = false

    init(highlightedTier: SubscriptionTier = .pro) {
        self.highlightedTier = highlightedTier
        _selectedTier = State(initialValue: highlightedTier == .free ? .pro : highlightedTier)
    }

    var body: some View {
        @Bindable var subscriptions = subscriptions
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if subscriptions.tier == .pro {
                        currentPlanCard
                    } else {
                        cycleToggle
                        tierCards
                    }
                    freePlanCard
                    footnote
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            .background(Theme.paper.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { ctaBar }
            .navigationTitle("RecipeBank Plans")
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
            if subscriptions.proMonthlyPackage == nil || subscriptions.plusMonthlyPackage == nil {
                await subscriptions.loadOfferings()
            }
        }
        .onAppear {
            // A Plus subscriber can only move up — keep Pro selected.
            if subscriptions.tier == .plus {
                selectedTier = .pro
            }
        }
        .onChange(of: subscriptions.tier) { oldTier, newTier in
            if newTier > oldTier {
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
            Text("Try everything free for 7 days")
                .font(.cookbookSerif(24, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("Meal planning, calorie tracking — and the GLP-1 companion as a Pro bonus. Cancel anytime during the trial and pay nothing.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Cycle toggle

    private var cycleToggle: some View {
        HStack(spacing: 4) {
            cycleSegment(title: "Monthly", value: .monthly, badge: nil)
            cycleSegment(title: "Yearly", value: .yearly, badge: "SAVE 50%")
        }
        .padding(4)
        .background(Theme.paperRaised, in: .capsule)
        .overlay(Capsule().stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func cycleSegment(title: String, value: BillingCycle, badge: String?) -> some View {
        let isSelected = cycle == value
        return Button {
            withAnimation(.spring(duration: 0.3)) { cycle = value }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                if let badge {
                    Text(badge)
                        .font(.system(size: 8.5, weight: .heavy))
                        .foregroundStyle(isSelected ? Theme.spiceDeep : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(Theme.sage), in: .capsule)
                }
            }
            .foregroundStyle(isSelected ? .white : Theme.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                isSelected ? AnyShapeStyle(Theme.warmGradient) : AnyShapeStyle(Color.clear),
                in: .capsule
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tier cards

    private var tierCards: some View {
        VStack(spacing: 12) {
            TierCard(
                tier: .pro,
                badge: "BEST VALUE",
                price: priceLabel(for: .pro),
                per: cycle == .monthly ? "per month" : "per year",
                isSelected: selectedTier == .pro,
                isCurrent: false
            ) {
                withAnimation(.spring(duration: 0.3)) { selectedTier = .pro }
            }
            TierCard(
                tier: .plus,
                badge: subscriptions.tier == .plus ? "CURRENT PLAN" : nil,
                price: priceLabel(for: .plus),
                per: cycle == .monthly ? "per month" : "per year",
                isSelected: selectedTier == .plus,
                isCurrent: subscriptions.tier == .plus
            ) {
                guard subscriptions.tier != .plus else { return }
                withAnimation(.spring(duration: 0.3)) { selectedTier = .plus }
            }
        }
    }

    private func priceLabel(for tier: SubscriptionTier) -> String {
        if let price = subscriptions.package(for: tier, cycle: cycle)?.storeProduct.localizedPriceString {
            return price
        }
        switch (tier, cycle) {
        case (.plus, .monthly): return "$4.99"
        case (.plus, .yearly): return "$29.99"
        case (.pro, .monthly): return "$6.99"
        default: return "$39.99"
        }
    }

    private var selectedPackage: Package? {
        subscriptions.package(for: selectedTier, cycle: cycle)
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
                            VStack(spacing: 2) {
                                Text(ctaTitle)
                                    .font(.system(size: 17, weight: .bold))
                                Text(ctaSubtitle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .opacity(0.85)
                            }
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
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
        subscriptions.tier == .plus
            ? "Upgrade to Pro"
            : "Start My 7-Day Free Trial"
    }

    private var ctaSubtitle: String {
        let suffix = cycle == .monthly ? "/month" : "/year"
        let price = "\(priceLabel(for: selectedTier))\(suffix)"
        return subscriptions.tier == .plus
            ? "\(price) · cancel anytime"
            : "then \(price) · cancel anytime"
    }

    private var footnote: some View {
        Text("New subscribers get a 7-day free trial — you won't be charged until the trial ends. Payment is charged to your Apple ID at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period. Manage or cancel anytime in Settings.")
            .font(.system(size: 11))
            .foregroundStyle(Theme.inkSoft.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.top, 2)
    }
}

// MARK: - Tier card

private struct TierCard: View {
    let tier: SubscriptionTier
    let badge: String?
    let price: String
    let per: String
    let isSelected: Bool
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        Text(tier.displayName)
                            .font(.cookbookSerif(20, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 8.5, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(isCurrent ? Theme.inkSoft : Theme.sage, in: .capsule)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(price)
                            .font(.cookbookSerif(22, weight: .bold))
                            .foregroundStyle(isSelected ? Theme.spice : Theme.ink)
                        Text(per)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Text(tier.tagline)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(tier.features, id: \.self) { feature in
                        HStack(spacing: 9) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? Theme.spice : Theme.sage)
                            Text(feature)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paperRaised, in: .rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Theme.spice : Theme.ink.opacity(0.06),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: isSelected ? Theme.spice.opacity(0.15) : .clear, radius: 10, y: 4)
            .opacity(isCurrent ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionStore())
}

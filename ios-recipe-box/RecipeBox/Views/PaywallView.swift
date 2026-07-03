//
//  PaywallView.swift
//  RecipeBox
//

import SwiftUI

/// Three-tier plan picker (Basic / Plus / Pro) in the warm cookbook style.
/// Selecting a plan activates it through `SubscriptionStore`.
struct PaywallView: View {
    @Environment(SubscriptionStore.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    /// The tier to pre-select when the paywall opens (e.g. from a locked tab).
    var highlightedTier: SubscriptionTier = .pro

    @State private var selectedTier: SubscriptionTier = .pro
    @State private var showingRestoreAlert = false
    @State private var justActivated = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    ForEach(SubscriptionTier.allCases.reversed(), id: \.self) { tier in
                        PlanCard(
                            tier: tier,
                            isSelected: selectedTier == tier,
                            isCurrent: subscriptions.tier == tier
                        ) {
                            withAnimation(.spring(duration: 0.3)) {
                                selectedTier = tier
                            }
                        }
                    }
                    footnote
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
            .background(Theme.paper.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { ctaBar }
            .navigationTitle("Plans")
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
        .onAppear { selectedTier = highlightedTier }
        .alert("Nothing to restore", isPresented: $showingRestoreAlert) {
            Button("OK") { }
        } message: {
            Text("Purchase restore becomes available once App Store billing is live.")
        }
        .sensoryFeedback(.success, trigger: justActivated)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.warmGradient).frame(width: 64, height: 64)
                Image(systemName: "fork.knife")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Get more from RecipeBank")
                .font(.cookbookSerif(24, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("From a free recipe box to a full GLP-1 companion — pick the plan that fits your journey.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
    }

    // MARK: - CTA

    private var ctaBar: some View {
        VStack(spacing: 10) {
            Button {
                subscriptions.activate(selectedTier)
                justActivated.toggle()
                dismiss()
            } label: {
                Text(ctaTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        subscriptions.tier == selectedTier
                            ? AnyShapeStyle(Theme.inkSoft.opacity(0.35))
                            : AnyShapeStyle(Theme.warmGradient),
                        in: .rect(cornerRadius: 16)
                    )
            }
            .buttonStyle(.plain)
            .disabled(subscriptions.tier == selectedTier)

            Button {
                Task {
                    let restored = await subscriptions.restorePurchases()
                    if !restored { showingRestoreAlert = true }
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
        if subscriptions.tier == selectedTier {
            return "Current Plan"
        }
        switch selectedTier {
        case .free: return "Switch to Basic (Free)"
        case .plus: return "Continue with Plus · $4.99/mo"
        case .pro: return "Continue with Pro · $6.99/mo"
        }
    }

    private var footnote: some View {
        Text("Founder preview: plans unlock instantly and you won't be charged. App Store billing switches on before public release. Subscriptions will renew monthly and can be cancelled anytime in Settings.")
            .font(.system(size: 11))
            .foregroundStyle(Theme.inkSoft.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.top, 2)
    }
}

// MARK: - Plan card

private struct PlanCard: View {
    let tier: SubscriptionTier
    let isSelected: Bool
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(tier.displayName)
                                .font(.cookbookSerif(20, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            if tier == .pro {
                                Text("BEST VALUE")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Theme.sage, in: .capsule)
                            }
                            if isCurrent {
                                Text("CURRENT")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(Theme.spiceDeep)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Theme.spice.opacity(0.14), in: .capsule)
                            }
                        }
                        Text(tier.tagline)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer(minLength: 8)
                    Text(tier.priceLabel)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? Theme.spice : Theme.ink)
                }

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(tier.features, id: \.self) { feature in
                        HStack(spacing: 9) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? Theme.spice : Theme.sage)
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
            .overlay(
                RoundedRectangle(cornerRadius: 20)
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

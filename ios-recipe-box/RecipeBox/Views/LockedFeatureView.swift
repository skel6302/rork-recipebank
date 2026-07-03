//
//  LockedFeatureView.swift
//  RecipeBox
//

import SwiftUI

/// Upsell screen shown in place of a tab the user's plan doesn't include.
/// Explains what the feature does and opens the paywall pre-set to the
/// required tier.
struct LockedFeatureView: View {
    let title: String
    let symbol: String
    let summary: String
    let bullets: [String]
    let requiredTier: SubscriptionTier

    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        heroIcon
                        VStack(spacing: 8) {
                            Text(title)
                                .font(.cookbookSerif(26, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text(summary)
                                .font(.system(size: 14.5))
                                .foregroundStyle(Theme.inkSoft)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        bulletCard
                        unlockButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 34)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(title)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(highlightedTier: requiredTier)
        }
    }

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(Theme.spice.opacity(0.12))
                .frame(width: 96, height: 96)
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.spice)
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Theme.warmGradient, in: .circle)
                .overlay(Circle().stroke(Theme.paper, lineWidth: 3))
                .offset(x: 34, y: 34)
        }
    }

    private var bulletCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(bullets, id: \.self) { bullet in
                HStack(spacing: 11) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.sage)
                    Text(bullet)
                        .font(.system(size: 14.5))
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private var unlockButton: some View {
        Button {
            showingPaywall = true
        } label: {
            VStack(spacing: 2) {
                Text("Unlock with \(requiredTier.displayName)")
                    .font(.system(size: 17, weight: .bold))
                Text(requiredTier.priceLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Theme.warmGradient, in: .rect(cornerRadius: 16))
            .shadow(color: Theme.spice.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}

#Preview {
    LockedFeatureView(
        title: "GLP-1 Tracking",
        symbol: "syringe.fill",
        summary: "Track doses, rotate injection sites, and follow your weight journey.",
        bullets: ["Dose reminders", "Site rotation", "Weight progress"],
        requiredTier: .pro
    )
    .environment(SubscriptionStore())
}

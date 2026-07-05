//
//  GLP1UpsellView.swift
//  RecipeBox
//

import SwiftUI

/// Shown in the Health tab's GLP-1 section when the plan doesn't include it.
/// Keeps the section picker visible so users can hop back to Calories, and
/// pitches the Pro upgrade.
struct GLP1UpsellView: View {
    @Binding var section: HealthSection

    @State private var showingPaywall = false

    private let bullets: [String] = [
        "Dose tracking with next-dose countdowns",
        "Injection-site rotation & reminders",
        "Weight progress tracking",
        "GLP-1 nutrition & side-effects guide",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        HealthSectionPicker(section: $section)
                        heroIcon
                            .padding(.top, 12)
                        VStack(spacing: 8) {
                            Text("GLP-1 Companion")
                                .font(.cookbookSerif(26, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text("A Pro bonus: track Ozempic, Wegovy, Mounjaro, Zepbound and more — with dose reminders, site rotation and weight progress.")
                                .font(.system(size: 14.5))
                                .foregroundStyle(Theme.inkSoft)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        bulletCard
                        unlockButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(highlightedTier: .pro)
        }
    }

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(Theme.spice.opacity(0.12))
                .frame(width: 96, height: 96)
            Image(systemName: "syringe.fill")
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
                Text("Unlock with Pro")
                    .font(.system(size: 17, weight: .bold))
                Text("7 days free · \(SubscriptionTier.pro.priceLabel)")
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
    GLP1UpsellView(section: .constant(.glp1))
        .environment(SubscriptionStore())
}

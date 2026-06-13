//
//  GLP1GuideView.swift
//  RecipeBox
//

import SwiftUI

/// A curated education screen for GLP-1 users: what to eat, what to avoid,
/// managing side effects, and smart habits. Content is bundled in-app.
struct GLP1GuideView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expanded: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        hero
                        ForEach(GLP1Guide.sections) { section in
                            sectionCard(section)
                        }
                        disclaimer
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("GLP-1 Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
        .tint(Theme.spice)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Eating well on GLP-1s")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ink)
            Text("Medications like Ozempic, Wegovy, Mounjaro and Zepbound slow how fast your stomach empties and curb appetite. These habits keep you comfortable and well-nourished.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.warmGradient.opacity(0.12), in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.spice.opacity(0.15), lineWidth: 1))
    }

    private func sectionCard(_ section: GuideSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: section.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(section.tint, in: .rect(cornerRadius: 11))
                Text(section.title)
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
            }
            Text(section.intro)
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)

            VStack(spacing: 0) {
                ForEach(Array(section.tips.enumerated()), id: \.element.id) { index, tip in
                    if index > 0 {
                        Divider().background(Theme.ink.opacity(0.06))
                    }
                    tipRow(tip, tint: section.tint)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func tipRow(_ tip: GuideTip, tint: Color) -> some View {
        let isOpen = expanded.contains(tip.id)
        return Button {
            withAnimation(.snappy) {
                if isOpen { expanded.remove(tip.id) } else { expanded.insert(tip.id) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(tint)
                        .frame(width: 7, height: 7)
                        .padding(.top, 6)
                    Text(tip.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkSoft.opacity(0.5))
                        .padding(.top, 2)
                }
                if isOpen {
                    Text(tip.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.leading, 17)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var disclaimer: some View {
        Text("This guide is general wellness information, not medical advice. Talk to your healthcare provider about your treatment, diet and any side effects.")
            .font(.system(size: 11))
            .foregroundStyle(Theme.inkSoft.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
    }
}

#Preview {
    GLP1GuideView()
}

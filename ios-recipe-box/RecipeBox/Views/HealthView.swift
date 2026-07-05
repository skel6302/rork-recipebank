//
//  HealthView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// The two sections of the combined Health tab.
enum HealthSection: String, CaseIterable, Identifiable {
    case calories = "Calories"
    case glp1 = "GLP-1"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .calories: return "flame.fill"
        case .glp1: return "syringe.fill"
        }
    }
}

/// The combined "Health" tab: calorie & macro tracking plus the GLP-1
/// companion, switched with a segmented control. Calorie tracking requires
/// Plus; the GLP-1 section is a Pro bonus and shows an upsell otherwise.
struct HealthView: View {
    @Environment(SubscriptionStore.self) private var subscriptions
    @State private var section: HealthSection = .calories

    var body: some View {
        switch section {
        case .calories:
            CalorieTrackerView(healthSection: $section)
        case .glp1:
            if subscriptions.canUseGLP1 {
                MedsView(healthSection: $section)
            } else {
                GLP1UpsellView(section: $section)
            }
        }
    }
}

/// Capsule segmented control for switching between Calories and GLP-1.
/// Shows a small lock on GLP-1 when the plan doesn't include it.
struct HealthSectionPicker: View {
    @Environment(SubscriptionStore.self) private var subscriptions
    @Binding var section: HealthSection

    var body: some View {
        HStack(spacing: 4) {
            ForEach(HealthSection.allCases) { item in
                segment(for: item)
            }
        }
        .padding(4)
        .background(Theme.paperRaised, in: .capsule)
        .overlay(Capsule().stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func segment(for item: HealthSection) -> some View {
        let isSelected = section == item
        return Button {
            guard section != item else { return }
            withAnimation(.snappy) { section = item }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.symbol)
                    .font(.system(size: 12, weight: .bold))
                Text(item.rawValue)
                    .font(.system(size: 14, weight: .bold))
                if item == .glp1 && !subscriptions.canUseGLP1 {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .opacity(0.8)
                }
            }
            .foregroundStyle(isSelected ? .white : Theme.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                isSelected ? AnyShapeStyle(Theme.warmGradient) : AnyShapeStyle(Color.clear),
                in: .capsule
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HealthView()
        .environment(SubscriptionStore())
        .modelContainer(for: [Recipe.self, Ingredient.self, ShoppingItem.self, FoodEntry.self, DailyLog.self, WeightEntry.self, Medication.self, DoseLog.self], inMemory: true)
}

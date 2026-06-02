//
//  FoodEntryEditView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// Edit a previously logged food: rename it, move it to a different meal slot,
/// adjust its per-serving nutrition, and dial the portion you actually ate
/// (¼, ½, ¾, full, or any custom amount). Nutrition scales live with the portion.
struct FoodEntryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: FoodEntry

    @State private var name: String = ""
    @State private var mealType: MealType = .snack
    @State private var portion: Double = 1.0

    // Per-serving (full portion) base values, edited directly.
    @State private var baseCalories: Double = 0
    @State private var baseProtein: Double = 0
    @State private var baseCarbs: Double = 0
    @State private var baseFat: Double = 0

    private let presets: [Double] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0]

    private var scaledCalories: Int { Int((baseCalories * portion).rounded()) }
    private var scaledProtein: Double { (baseProtein * portion * 10).rounded() / 10 }
    private var scaledCarbs: Double { (baseCarbs * portion * 10).rounded() / 10 }
    private var scaledFat: Double { (baseFat * portion * 10).rounded() / 10 }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        totalCard
                        nameCard
                        mealTypeCard
                        portionCard
                        nutritionCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                }
            }
            .onAppear(perform: load)
        }
        .tint(Theme.spice)
    }

    // MARK: - Total

    private var totalCard: some View {
        VStack(spacing: 6) {
            Text("\(scaledCalories)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.spice)
                .contentTransition(.numericText())
                .animation(.snappy, value: scaledCalories)
            Text("calories" + (portion != 1 ? " · \(portionLabel(portion)) serving" : ""))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: 10) {
                macroPill("Protein", grams: scaledProtein, tint: Theme.sage)
                macroPill("Carbs", grams: scaledCarbs, tint: Theme.amber)
                macroPill("Fat", grams: scaledFat, tint: Theme.spice)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func macroPill(_ label: String, grams: Double, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(grams.rounded()))g")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
                .animation(.snappy, value: grams)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.14), in: .rect(cornerRadius: 12))
    }

    // MARK: - Name

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardLabel("Name")
            TextField("Food name", text: $name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(14)
                .background(Theme.paperRaised, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
        }
    }

    // MARK: - Meal type

    private var mealTypeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardLabel("Meal")
            HStack(spacing: 8) {
                ForEach(MealType.allCases) { type in
                    Button {
                        mealType = type
                    } label: {
                        Text(type.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(mealType == type ? .white : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(mealType == type ? type.tint : Theme.paperRaised, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Portion

    private var portionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardLabel("Portion")
            Text("How much did you actually eat?")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { value in
                    let isSelected = abs(portion - value) < 0.001
                    Button {
                        withAnimation(.snappy) { portion = value }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(portionLabel(value))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isSelected ? .white : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(isSelected ? Theme.spice : Theme.paperRaised, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Custom")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(portionLabel(portion))×")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.spice)
                Stepper("", value: $portion, in: 0.25...10, step: 0.25)
                    .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.paperRaised, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
        }
    }

    // MARK: - Nutrition (per serving)

    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardLabel("Per Full Serving")
            nutritionRow("Calories", value: $baseCalories, step: 10, unit: "cal")
            Divider().background(Theme.ink.opacity(0.06))
            nutritionRow("Protein", value: $baseProtein, step: 1, unit: "g")
            Divider().background(Theme.ink.opacity(0.06))
            nutritionRow("Carbs", value: $baseCarbs, step: 1, unit: "g")
            Divider().background(Theme.ink.opacity(0.06))
            nutritionRow("Fat", value: $baseFat, step: 1, unit: "g")
        }
        .padding(16)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func nutritionRow(_ label: String, value: Binding<Double>, step: Double, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text("\(Int(value.wrappedValue.rounded())) \(unit)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Stepper("", value: value, in: 0...5000, step: step)
                .labelsHidden()
        }
    }

    // MARK: - Helpers

    private func cardLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
    }

    private func portionLabel(_ value: Double) -> String {
        switch value {
        case 0.25: return "¼"
        case 0.5: return "½"
        case 0.75: return "¾"
        case 1.0: return "1"
        case 1.5: return "1½"
        case 2.0: return "2"
        default:
            if value == value.rounded() { return String(format: "%.0f", value) }
            return String(format: "%.2f", value).replacingOccurrences(of: "0", with: "", options: .backwards, range: nil)
        }
    }

    private func load() {
        name = entry.name
        mealType = entry.mealType
        portion = entry.portion > 0 ? entry.portion : 1.0
        baseCalories = entry.baseCalories
        baseProtein = entry.baseProtein
        baseCarbs = entry.baseCarbs
        baseFat = entry.baseFat
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.name = trimmed.isEmpty ? entry.name : trimmed
        entry.mealType = mealType
        entry.portion = portion
        entry.calories = scaledCalories
        entry.protein = scaledProtein
        entry.carbs = scaledCarbs
        entry.fat = scaledFat
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

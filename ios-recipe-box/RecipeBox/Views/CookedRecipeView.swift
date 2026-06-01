//
//  CookedRecipeView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// "I Cooked This" flow: estimates a recipe's nutrition with AI, lets the user
/// choose how many servings they ate and which meal slot, then logs a FoodEntry
/// to the calorie tracker.
struct CookedRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let recipe: Recipe

    @State private var phase: Phase = .estimating
    @State private var analysis: MealAnalysis?
    @State private var servingsEaten: Double = 1
    @State private var mealType: MealType = MealType.suggested()
    @State private var errorMessage: String?

    private enum Phase: Equatable {
        case estimating
        case ready
        case failed
    }

    /// Total servings the recipe yields (never below 1).
    private var recipeServings: Double { Double(max(recipe.servings, 1)) }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                switch phase {
                case .estimating: estimating
                case .ready: ready
                case .failed: failed
                }
            }
            .navigationTitle("I Cooked This")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(Theme.spice)
        .task { await estimate() }
    }

    // MARK: - Estimating

    private var estimating: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.warmGradient)
                    .frame(width: 88, height: 88)
                    .shadow(color: Theme.spice.opacity(0.35), radius: 14, y: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
            }
            HStack(spacing: 8) {
                ProgressView().tint(Theme.spice)
                Text("Estimating nutrition…")
                    .font(.cookbookSerif(20, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            Text("Reading the ingredients of \(recipe.title) to calculate calories and macros.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Failed

    private var failed: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.spice)
            Text(errorMessage ?? "We couldn't estimate this recipe.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await estimate() }
            } label: {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(Theme.spice, in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Ready

    @ViewBuilder
    private var ready: some View {
        if let analysis {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    calorieCard(analysis)
                    macroSummary(analysis)
                    servingsCard
                    mealTypePicker
                    logButton(analysis)
                }
                .padding(20)
            }
        } else {
            ProgressView().tint(Theme.spice)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            if let data = recipe.displayPhotoData, let uiImage = UIImage(data: data) {
                Color(.secondarySystemBackground)
                    .frame(height: 160)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 20))
            }
            Text(recipe.title)
                .font(.cookbookSerif(24, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
    }

    private func calorieCard(_ analysis: MealAnalysis) -> some View {
        VStack(spacing: 4) {
            Text("\(loggedCalories(analysis))")
                .font(.cookbookSerif(40, weight: .bold))
                .foregroundStyle(Theme.spice)
            Text("calories logged")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
            Text("Whole recipe: \(analysis.totalCalories) cal · \(perServingCalories(analysis)) per serving")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft.opacity(0.8))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func macroSummary(_ analysis: MealAnalysis) -> some View {
        HStack(spacing: 10) {
            macroPill("Protein", grams: scaled(analysis.totalProtein), tint: Theme.sage)
            macroPill("Carbs", grams: scaled(analysis.totalCarbs), tint: Theme.amber)
            macroPill("Fat", grams: scaled(analysis.totalFat), tint: Theme.spice)
        }
    }

    private func macroPill(_ label: String, grams: Double, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(grams.rounded()))g")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.14), in: .rect(cornerRadius: 14))
        .overlay(alignment: .top) {
            Rectangle().fill(tint).frame(height: 3).clipShape(.rect(cornerRadius: 2))
        }
    }

    private var servingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("How much did you eat?")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(servingsLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.spice)
            }
            HStack(spacing: 14) {
                stepButton(symbol: "minus") {
                    servingsEaten = max(0.5, servingsEaten - 0.5)
                }
                Slider(value: $servingsEaten, in: 0.5...recipeServings, step: 0.5)
                    .tint(Theme.spice)
                stepButton(symbol: "plus") {
                    servingsEaten = min(recipeServings, servingsEaten + 0.5)
                }
            }
            Text("Recipe makes \(recipe.servings) serving\(recipe.servings == 1 ? "" : "s").")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func stepButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.spice)
                .frame(width: 38, height: 38)
                .background(Theme.spice.opacity(0.12), in: .circle)
        }
        .buttonStyle(.plain)
    }

    private var mealTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log to")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
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

    private func logButton(_ analysis: MealAnalysis) -> some View {
        Button {
            log(analysis)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Log to Calorie Tracker")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.warmGradient, in: .rect(cornerRadius: 16))
            .shadow(color: Theme.spice.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived values

    private var servingsLabel: String {
        let trimmed = servingsEaten.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(servingsEaten))
            : String(servingsEaten)
        return "\(trimmed) serving\(servingsEaten == 1 ? "" : "s")"
    }

    /// Fraction of the whole recipe the user ate.
    private var portion: Double { servingsEaten / recipeServings }

    private func scaled(_ wholeRecipeValue: Double) -> Double { wholeRecipeValue * portion }

    private func loggedCalories(_ analysis: MealAnalysis) -> Int {
        Int((Double(analysis.totalCalories) * portion).rounded())
    }

    private func perServingCalories(_ analysis: MealAnalysis) -> Int {
        Int((Double(analysis.totalCalories) / recipeServings).rounded())
    }

    // MARK: - Actions

    private func estimate() async {
        await MainActor.run {
            errorMessage = nil
            phase = .estimating
        }
        let lines = recipe.ingredients
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(\.displayLine)
        do {
            let result = try await CalorieAnalyzer.analyzeRecipe(
                title: recipe.title,
                servings: max(recipe.servings, 1),
                ingredientLines: lines
            )
            await MainActor.run {
                guard !result.items.isEmpty else {
                    errorMessage = "We couldn't read enough from this recipe to estimate it. You can still log it manually from the Add Food screen."
                    phase = .failed
                    return
                }
                analysis = result
                phase = .ready
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
                phase = .failed
            }
        }
    }

    private func log(_ analysis: MealAnalysis) {
        let entry = FoodEntry(
            name: recipe.title,
            mealType: mealType,
            servingDescription: servingsLabel,
            calories: loggedCalories(analysis),
            protein: scaled(analysis.totalProtein),
            carbs: scaled(analysis.totalCarbs),
            fat: scaled(analysis.totalFat),
            loggedAt: .now,
            wasAIEstimated: true,
            photoData: recipe.displayPhotoData
        )
        modelContext.insert(entry)
        try? modelContext.save()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        dismiss()
    }
}

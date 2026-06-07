//
//  CalorieRing.swift
//  RecipeBox
//

import SwiftUI

/// A circular progress ring showing calories consumed against a daily goal,
/// with the remaining count in the center.
struct CalorieRing: View {
    let consumed: Int
    let goal: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(consumed) / Double(goal), 1)
    }

    private var remaining: Int { max(goal - consumed, 0) }
    private var isOver: Bool { consumed > goal }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.ink.opacity(0.08), lineWidth: 16)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isOver ? AnyShapeStyle(Color.red.opacity(0.85)) : AnyShapeStyle(Theme.warmGradient),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

            VStack(spacing: 2) {
                Text("\(isOver ? consumed - goal : remaining)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(isOver ? "calories over" : "calories left")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }
}

/// A three-segment donut showing the calorie split between fat, carbs and protein,
/// alongside a legend with each macro's percentage and gram amount.
struct MacroBreakdown: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    private let proteinTint = Theme.sage
    private let carbTint = Theme.amber
    private let fatTint = Theme.spice

    /// Calories contributed by each macro (4/4/9 kcal per gram).
    private var calProtein: Double { protein * 4 }
    private var calCarbs: Double { carbs * 4 }
    private var calFat: Double { fat * 9 }
    private var total: Double { calProtein + calCarbs + calFat }

    private var pctProtein: Double { total > 0 ? calProtein / total : 0 }
    private var pctCarbs: Double { total > 0 ? calCarbs / total : 0 }
    private var pctFat: Double { total > 0 ? calFat / total : 0 }

    var body: some View {
        HStack(spacing: 18) {
            donut
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 10) {
                legendRow("Carbs", tint: carbTint, pct: pctCarbs, grams: carbs)
                legendRow("Fat", tint: fatTint, pct: pctFat, grams: fat)
                legendRow("Protein", tint: proteinTint, pct: pctProtein, grams: protein)
            }
            Spacer(minLength: 0)
        }
    }

    private var donut: some View {
        ZStack {
            Circle().stroke(Theme.ink.opacity(0.08), lineWidth: 14)
            if total > 0 {
                segment(from: 0, to: pctCarbs, tint: carbTint)
                segment(from: pctCarbs, to: pctCarbs + pctFat, tint: fatTint)
                segment(from: pctCarbs + pctFat, to: 1, tint: proteinTint)
            }
            VStack(spacing: 0) {
                Text("\(Int(total.rounded()))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("cal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func segment(from: Double, to: Double, tint: Color) -> some View {
        Circle()
            .trim(from: from, to: max(from, to))
            .stroke(tint, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
            .rotationEffect(.degrees(-90))
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: to)
    }

    private func legendRow(_ label: String, tint: Color, pct: Double, grams: Double) -> some View {
        HStack(spacing: 8) {
            Circle().fill(tint).frame(width: 9, height: 9)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            Text("\(Int((pct * 100).rounded()))%")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("\(Int(grams.rounded()))g")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

/// A thin macro progress bar with a label and gram readout.
struct MacroBar: View {
    let label: String
    let grams: Double
    let goal: Double
    let tint: Color

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(grams / goal, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(Int(grams.rounded()))/\(Int(goal))g")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.08))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(geo.size.width * progress, 0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

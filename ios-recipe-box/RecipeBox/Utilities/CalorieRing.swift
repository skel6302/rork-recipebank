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

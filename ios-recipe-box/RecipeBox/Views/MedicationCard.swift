//
//  MedicationCard.swift
//  RecipeBox
//

import SwiftUI

/// A card on the Meds tab showing a medication's next-dose countdown, dose info,
/// last injection site, and a one-tap "Log dose" button.
struct MedicationCard: View {
    let medication: Medication
    let onLog: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            countdownRow
            Button(action: onLog) {
                Label("Log \(medication.form == .injection ? "injection" : "dose")", systemImage: medication.form.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.warmGradient, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
        .shadow(color: Theme.cardShadow, radius: 10, y: 4)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(medication.tint).frame(width: 46, height: 46)
                Image(systemName: medication.form.symbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text("\(medication.doseLabel) · \(medication.schedule.rawValue.lowercased())")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
            Button(action: onEdit) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 36, height: 36)
                    .background(Theme.paper, in: .circle)
            }
            .buttonStyle(.plain)
        }
    }

    private var countdownRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT DOSE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.inkSoft)
                Text(countdownText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isDue ? Theme.spice : Theme.ink)
            }
            Spacer(minLength: 0)
            if medication.form == .injection {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("NEXT SITE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.inkSoft)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .bold))
                        Text(medication.suggestedSite.short)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(medication.tint)
                }
            }
        }
        .padding(12)
        .background(isDue ? Theme.spice.opacity(0.10) : Theme.paper, in: .rect(cornerRadius: 14))
    }

    private var isDue: Bool {
        medication.nextDueDate <= Date()
    }

    private var countdownText: String {
        let now = Date()
        let due = medication.nextDueDate
        if due <= now { return "Due now" }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: due)).day ?? 0
        let f = DateFormatter()
        if days == 0 {
            f.dateFormat = "h:mm a"
            return "Today · \(f.string(from: due))"
        }
        if days == 1 {
            f.dateFormat = "h:mm a"
            return "Tomorrow · \(f.string(from: due))"
        }
        f.dateFormat = "EEEE"
        return "In \(days) days · \(f.string(from: due))"
    }
}

#Preview {
    MedicationCard(medication: Medication(name: "Wegovy", doseMg: 1.0), onLog: {}, onEdit: {})
        .padding()
        .background(Theme.paper)
}

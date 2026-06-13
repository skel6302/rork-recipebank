//
//  LogDoseView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// Records a dose of a medication: date/time, amount, and (for injections) the
/// body site, with the next rotation site pre-selected.
struct LogDoseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let medication: Medication

    @State private var takenAt: Date = .now
    @State private var doseText: String = ""
    @State private var selectedSite: InjectionSite = .leftAbdomen
    @State private var notes: String = ""

    private var isInjection: Bool { medication.form == .injection }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        header
                        doseCard
                        timeCard
                        if isInjection { siteCard }
                        notesCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Log Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") { save() }
                        .fontWeight(.bold)
                }
            }
            .onAppear(perform: load)
        }
        .tint(Theme.spice)
        .presentationDetents([.large])
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(medication.tint).frame(width: 50, height: 50)
                Image(systemName: medication.form.symbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name)
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text("\(medication.form.actionVerb) · \(medication.schedule.rawValue.lowercased())")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private var doseCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Dose")
                HStack {
                    TextField("\(formatted(medication.doseMg))", text: $doseText)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .keyboardType(.decimalPad)
                    Text("mg")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }

    private var timeCard: some View {
        card {
            DatePicker(selection: $takenAt, in: ...Date()) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(Theme.sage)
                    Text("Taken at")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .tint(Theme.spice)
        }
    }

    private var siteCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    fieldLabel("Injection site")
                    Spacer()
                    Text("Suggested: \(medication.suggestedSite.short)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.spice)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(InjectionSite.allCases) { site in
                        let isSelected = selectedSite == site
                        let isSuggested = medication.suggestedSite == site
                        Button {
                            selectedSite = site
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 6) {
                                Text(site.short)
                                    .font(.system(size: 13, weight: .semibold))
                                if isSuggested && !isSelected {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 10, weight: .bold))
                                }
                            }
                            .foregroundStyle(isSelected ? .white : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(isSelected ? Theme.spice : Theme.paper, in: .rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isSuggested && !isSelected ? Theme.spice.opacity(0.5) : Theme.ink.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var notesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Notes")
                TextField("How are you feeling? Side effects?", text: $notes, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2...5)
            }
        }
    }

    // MARK: - Helpers

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paperRaised, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.inkSoft)
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.2g", value)
    }

    private func load() {
        doseText = formatted(medication.doseMg)
        selectedSite = medication.suggestedSite
    }

    private func save() {
        let dose = Double(doseText.replacingOccurrences(of: ",", with: ".")) ?? medication.doseMg
        let doseLog = DoseLog(
            takenAt: takenAt,
            doseMg: dose,
            site: isInjection ? selectedSite : nil,
            notes: notes,
            medication: medication
        )
        modelContext.insert(doseLog)
        medication.doses.append(doseLog)
        if isInjection {
            medication.lastSite = selectedSite
        }
        try? modelContext.save()
        DoseReminderScheduler.reschedule(medication)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

#Preview {
    LogDoseView(medication: Medication(name: "Wegovy"))
        .modelContainer(for: [Medication.self, DoseLog.self], inMemory: true)
}

//
//  MedicationEditView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// Adds a new medication or edits an existing one, with quick GLP-1 presets,
/// dose, schedule, reminder time and notes.
struct MedicationEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let medication: Medication?

    @State private var name: String = ""
    @State private var form: MedForm = .injection
    @State private var schedule: MedSchedule = .weekly
    @State private var doseText: String = "0.25"
    @State private var doseWeekday: Int = 1
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var remindersEnabled: Bool = true
    @State private var notes: String = ""
    @State private var showingDeleteConfirm = false

    private var isEditing: Bool { medication != nil }

    private let weekdaySymbols: [String] = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        presetRow
                        nameCard
                        formScheduleCard
                        doseCard
                        if schedule == .weekly { weekdayCard }
                        reminderCard
                        notesCard
                        if isEditing { deleteButton }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditing ? "Edit Medication" : "Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
            .confirmationDialog("Delete this medication and its dose history?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { delete() }
            }
        }
        .tint(Theme.spice)
    }

    // MARK: - Presets

    private var presetRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ADD")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GLP1Preset.all) { preset in
                        Button {
                            applyPreset(preset)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: preset.form.symbol)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(preset.name)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(name == preset.name ? .white : Theme.ink)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 14)
                            .background(name == preset.name ? Theme.spice : Theme.paperRaised, in: .capsule)
                            .overlay(Capsule().stroke(Theme.ink.opacity(0.08), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }

    // MARK: - Cards

    private var nameCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Name")
                TextField("e.g. Ozempic", text: $name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .textInputAutocapitalization(.words)
            }
        }
    }

    private var formScheduleCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Form")
                    Picker("Form", selection: $form) {
                        ForEach(MedForm.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Schedule")
                    Picker("Schedule", selection: $schedule) {
                        ForEach(MedSchedule.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var doseCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Dose (mg)")
                HStack {
                    TextField("0.25", text: $doseText)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .keyboardType(.decimalPad)
                    Text("mg")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                }
                if let preset = GLP1Preset.all.first(where: { $0.name == name }) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(preset.commonDoses, id: \.self) { dose in
                                Button {
                                    doseText = formatted(dose)
                                } label: {
                                    Text("\(formatted(dose)) mg")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.spice)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Theme.spice.opacity(0.10), in: .capsule)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .contentMargins(.horizontal, 0)
                }
            }
        }
    }

    private var weekdayCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Dose day")
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { idx in
                        let weekday = idx + 1
                        Button {
                            doseWeekday = weekday
                        } label: {
                            Text(weekdaySymbols[idx])
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(doseWeekday == weekday ? .white : Theme.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(doseWeekday == weekday ? Theme.spice : Theme.paper, in: .rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var reminderCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $remindersEnabled) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(Theme.amber)
                        Text("Dose reminder")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .tint(Theme.spice)
                if remindersEnabled {
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    private var notesCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Notes")
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2...5)
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirm = true
        } label: {
            Label("Delete Medication", systemImage: "trash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.08), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
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

    private func applyPreset(_ preset: GLP1Preset) {
        name = preset.name
        form = preset.form
        schedule = preset.schedule
        if let first = preset.commonDoses.first {
            doseText = formatted(first)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func load() {
        guard let med = medication else { return }
        name = med.name
        form = med.form
        schedule = med.schedule
        doseText = formatted(med.doseMg)
        doseWeekday = med.doseWeekday
        reminderTime = Calendar.current.date(bySettingHour: med.reminderMinutes / 60, minute: med.reminderMinutes % 60, second: 0, of: .now) ?? .now
        remindersEnabled = med.remindersEnabled
        notes = med.notes
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let dose = Double(doseText.replacingOccurrences(of: ",", with: ".")) ?? 0
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let minutes = (comps.hour ?? 9) * 60 + (comps.minute ?? 0)

        let med: Medication
        if let existing = medication {
            med = existing
            med.name = trimmedName
            med.form = form
            med.schedule = schedule
            med.doseMg = dose
            med.doseWeekday = doseWeekday
            med.reminderMinutes = minutes
            med.remindersEnabled = remindersEnabled
            med.notes = notes
        } else {
            med = Medication(
                name: trimmedName,
                form: form,
                schedule: schedule,
                doseMg: dose,
                doseWeekday: doseWeekday,
                reminderMinutes: minutes,
                remindersEnabled: remindersEnabled,
                notes: notes
            )
            modelContext.insert(med)
        }
        try? modelContext.save()
        DoseReminderScheduler.reschedule(med)
        dismiss()
    }

    private func delete() {
        guard let med = medication else { return }
        DoseReminderScheduler.cancel(med)
        modelContext.delete(med)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    MedicationEditView(medication: nil)
        .modelContainer(for: [Medication.self, DoseLog.self], inMemory: true)
}

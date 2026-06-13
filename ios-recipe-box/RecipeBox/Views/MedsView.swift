//
//  MedsView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// The "Meds" tab — GLP-1 medication tracking with next-dose countdowns,
/// one-tap dose logging, injection-site rotation, dose history, and a link to
/// the GLP-1 education guide.
struct MedsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.startedAt, order: .forward) private var medications: [Medication]

    @State private var showingAddMed = false
    @State private var editingMed: Medication?
    @State private var loggingMed: Medication?
    @State private var showingGuide = false

    private var activeMeds: [Medication] {
        medications.filter { $0.isActive }
    }

    private var recentDoses: [DoseLog] {
        medications
            .flatMap { $0.doses }
            .sorted { $0.takenAt > $1.takenAt }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        guideBanner
                        if activeMeds.isEmpty {
                            emptyState
                        } else {
                            ForEach(activeMeds) { med in
                                MedicationCard(
                                    medication: med,
                                    onLog: { loggingMed = med },
                                    onEdit: { editingMed = med }
                                )
                            }
                        }
                        if !recentDoses.isEmpty {
                            historySection
                        }
                        disclaimer
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }

                addButton
            }
            .navigationTitle("Meds")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingGuide = true
                    } label: {
                        Image(systemName: "book.fill")
                            .foregroundStyle(Theme.spice)
                    }
                }
            }
            .sheet(isPresented: $showingAddMed) {
                MedicationEditView(medication: nil)
            }
            .sheet(item: $editingMed) { med in
                MedicationEditView(medication: med)
            }
            .sheet(item: $loggingMed) { med in
                LogDoseView(medication: med)
            }
            .sheet(isPresented: $showingGuide) {
                GLP1GuideView()
            }
            .task {
                _ = await DoseReminderScheduler.requestAuthorization()
            }
        }
        .tint(Theme.spice)
    }

    // MARK: - Guide banner

    private var guideBanner: some View {
        Button {
            showingGuide = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.warmGradient).frame(width: 46, height: 46)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("GLP-1 Guide")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("What to eat, what to avoid, and managing side effects.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft.opacity(0.5))
            }
            .padding(14)
            .background(Theme.paperRaised, in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.spice.opacity(0.12)).frame(width: 72, height: 72)
                Image(systemName: "syringe.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.spice)
            }
            Text("Track your GLP-1")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ink)
            Text("Add Ozempic, Wegovy, Mounjaro, Zepbound, Rybelsus or any pill/shot to get dose reminders, site rotation and a full history.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                showingAddMed = true
            } label: {
                Label("Add a Medication", systemImage: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 22)
                    .background(Theme.warmGradient, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.spiceDeep)
                Text("Recent Doses")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            ForEach(recentDoses) { dose in
                HStack(spacing: 12) {
                    Image(systemName: (dose.medication?.form ?? .injection).symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(dose.medication?.tint ?? Theme.spice, in: .rect(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(dose.medication?.name ?? "Dose") · \(dose.doseLabel)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(doseSubtitle(dose))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func doseSubtitle(_ dose: DoseLog) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d · h:mm a"
        let date = f.string(from: dose.takenAt)
        if let site = dose.site {
            return "\(date) · \(site.short)"
        }
        return date
    }

    private var disclaimer: some View {
        Text("For personal tracking only. Not medical advice — always follow your prescriber's instructions.")
            .font(.system(size: 11))
            .foregroundStyle(Theme.inkSoft.opacity(0.8))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.top, 4)
    }

    // MARK: - Add button

    private var addButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showingAddMed = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(Theme.warmGradient, in: .circle)
                        .shadow(color: Theme.spice.opacity(0.4), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    MedsView()
        .modelContainer(for: [Medication.self, DoseLog.self], inMemory: true)
}

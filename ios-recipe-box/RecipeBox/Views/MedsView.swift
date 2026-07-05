//
//  MedsView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData
import Charts

/// The "GLP-1" tab — medication tracking with next-dose countdowns, one-tap
/// dose logging, injection-site rotation, weight progress, dose history, and
/// a link to the GLP-1 education guide.
struct MedsView: View {
    @Binding var healthSection: HealthSection

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.startedAt, order: .forward) private var medications: [Medication]
    @Query(sort: \WeightEntry.loggedAt, order: .forward) private var weights: [WeightEntry]

    @State private var showingAddMed = false
    @State private var editingMed: Medication?
    @State private var loggingMed: Medication?
    @State private var showingGuide = false
    @State private var showingWeightLog = false
    @State private var weightInput = ""

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
                        HealthSectionPicker(section: $healthSection)
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
                        weightProgressCard
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
            .navigationTitle("GLP-1")
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
            .alert("Log Weight", isPresented: $showingWeightLog) {
                TextField("Weight (lbs)", text: $weightInput)
                    .keyboardType(.decimalPad)
                Button("Save") { saveWeight() }
                Button("Cancel", role: .cancel) { weightInput = "" }
            } message: {
                Text("Enter today's weight in pounds.")
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

    // MARK: - Weight progress

    private var weightProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.sage)
                Text("Weight Progress")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button {
                    weightInput = ""
                    showingWeightLog = true
                } label: {
                    Label("Log", systemImage: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.sage, in: .capsule)
                }
                .buttonStyle(.plain)
            }

            if weights.count >= 2, let first = weights.first, let last = weights.last {
                HStack(spacing: 0) {
                    weightStat(label: "Start", value: first.weightLbs)
                    Spacer()
                    weightStat(label: "Current", value: last.weightLbs)
                    Spacer()
                    changeStat(delta: last.weightLbs - first.weightLbs)
                }

                Chart(weights, id: \.loggedAt) { entry in
                    LineMark(
                        x: .value("Date", entry.loggedAt),
                        y: .value("Weight", entry.weightLbs)
                    )
                    .foregroundStyle(Theme.sage)
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Date", entry.loggedAt),
                        y: .value("Weight", entry.weightLbs)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.sage.opacity(0.25), Theme.sage.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: weightDomain)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing) { _ in
                        AxisGridLine().foregroundStyle(Theme.ink.opacity(0.06))
                        AxisValueLabel()
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .frame(height: 110)
            } else {
                Text("Log your weight as you go — you'll see your journey charted here after a couple of entries.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private var weightDomain: ClosedRange<Double> {
        let values = weights.map { $0.weightLbs }
        let low = (values.min() ?? 0) - 4
        let high = (values.max() ?? 100) + 4
        return low...high
    }

    private func weightStat(label: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.inkSoft.opacity(0.7))
            Text("\(value, specifier: "%.1f") lb")
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ink)
        }
    }

    private func changeStat(delta: Double) -> some View {
        VStack(spacing: 2) {
            Text("CHANGE")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Theme.inkSoft.opacity(0.7))
            HStack(spacing: 3) {
                Image(systemName: delta <= 0 ? "arrow.down" : "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                Text("\(abs(delta), specifier: "%.1f") lb")
                    .font(.system(size: 17, weight: .bold, design: .serif))
            }
            .foregroundStyle(delta <= 0 ? Theme.sage : Theme.spice)
        }
    }

    private func saveWeight() {
        let normalized = weightInput.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0, value < 1500 else {
            weightInput = ""
            return
        }
        modelContext.insert(WeightEntry(weightLbs: value))
        weightInput = ""
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
    MedsView(healthSection: .constant(.glp1))
        .environment(SubscriptionStore())
        .modelContainer(for: [Medication.self, DoseLog.self], inMemory: true)
}

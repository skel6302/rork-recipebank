//
//  CalorieTrackerView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// The calorie tracker tab — a daily dashboard of calories, macros, water,
/// Apple Watch activity, weight and sleep. Days can be "closed out" to build a
/// tracking streak, and past days can be back-filled until they're closed.
struct CalorieTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.loggedAt, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var dailyLogs: [DailyLog]
    @Query(sort: \WeightEntry.loggedAt, order: .reverse) private var weights: [WeightEntry]

    @AppStorage("calorieGoal") private var calorieGoal: Int = 2000
    @AppStorage("proteinGoal") private var proteinGoal: Int = 140
    @AppStorage("carbGoal") private var carbGoal: Int = 220
    @AppStorage("fatGoal") private var fatGoal: Int = 65
    @AppStorage("waterGoal") private var waterGoal: Int = 8
    @AppStorage("startWeight") private var startWeight: Double = 0
    @AppStorage("goalWeight") private var goalWeight: Double = 0

    @State private var selectedDate: Date = .now
    @State private var showingAnalyze = false
    @State private var addMealType: MealType = MealType.suggested()
    @State private var showingGoals = false
    @State private var showingWeight = false
    @State private var health = HealthManager()

    private var todaysEntries: [FoodEntry] {
        allEntries.filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: selectedDate) }
    }

    private var consumed: Int { todaysEntries.reduce(0) { $0 + $1.calories } }
    private var protein: Double { todaysEntries.reduce(0) { $0 + $1.protein } }
    private var carbs: Double { todaysEntries.reduce(0) { $0 + $1.carbs } }
    private var fat: Double { todaysEntries.reduce(0) { $0 + $1.fat } }

    // MARK: - Day state

    private var selectedLog: DailyLog? {
        let start = Calendar.current.startOfDay(for: selectedDate)
        return dailyLogs.first { Calendar.current.isDate($0.day, inSameDayAs: start) }
    }

    private var isDayClosed: Bool { selectedLog?.isClosed ?? false }
    private var waterGlasses: Int { selectedLog?.waterGlasses ?? 0 }

    private var closedDays: Set<Date> {
        Set(dailyLogs.filter { $0.isClosed }.map { Calendar.current.startOfDay(for: $0.day) })
    }

    /// Consecutive closed days ending today or yesterday.
    private var streak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else { return 0 }
        var cursor: Date
        if closedDays.contains(today) { cursor = today }
        else if closedDays.contains(yesterday) { cursor = yesterday }
        else { return 0 }
        var count = 0
        while closedDays.contains(cursor) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    private var currentWeight: Double? {
        weights.first?.weightLbs ?? (startWeight > 0 ? startWeight : nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        weekStrip
                        streakBanner
                        if isDayClosed { closedBanner }
                        summaryCard
                        macrosCard
                        waterCard
                        activityCard
                        weightCard
                        ForEach(MealType.allCases) { type in
                            mealSection(type)
                        }
                        doneTrackingButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                    .padding(.top, 8)
                }

                if !isDayClosed { addButton }
            }
            .navigationTitle("Calories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingGoals = true
                    } label: {
                        Image(systemName: "target")
                            .foregroundStyle(Theme.spice)
                    }
                }
            }
            .sheet(isPresented: $showingAnalyze) {
                AnalyzeFoodView(initialMealType: addMealType, logDate: selectedDate)
            }
            .sheet(isPresented: $showingGoals) {
                goalsSheet
            }
            .sheet(isPresented: $showingWeight) {
                weightSheet
            }
            .task {
                await health.requestAuthorization()
            }
            .onAppear {
                // Always default to today when returning to the tracker.
                if !Calendar.current.isDateInToday(selectedDate) {
                    selectedDate = .now
                }
            }
            .onChange(of: selectedDate) { _, newValue in
                Task { await health.refresh(for: newValue) }
            }
        }
        .tint(Theme.spice)
    }

    // MARK: - Week strip

    private var weekStrip: some View {
        HStack(spacing: 6) {
            ForEach(weekDays(), id: \.self) { day in
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                let isToday = Calendar.current.isDateInToday(day)
                let dayClosed = closedDays.contains(Calendar.current.startOfDay(for: day))
                Button {
                    withAnimation(.snappy) { selectedDate = day }
                } label: {
                    VStack(spacing: 4) {
                        Text(weekdayLetter(day))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : Theme.inkSoft)
                        Text(dayNumber(day))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isSelected ? .white : Theme.ink)
                        Circle()
                            .fill(dayClosed ? (isSelected ? Color.white : Theme.sage) : .clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(isSelected ? Theme.spice : Theme.paperRaised, in: .rect(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isToday && !isSelected ? Theme.spice.opacity(0.5) : Theme.ink.opacity(0.06), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Streak

    private var streakBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.warmGradient).frame(width: 44, height: 44)
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(streak > 0 ? "\(streak)-day streak" : "Start your streak")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(streak > 0
                     ? "Close out each day to keep it going."
                     : "Tap “Done Logging” to close out today.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private var closedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(Theme.sage)
            Text("This day is closed and counts toward your streak.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            Button("Reopen") { toggleClosed() }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.spice)
        }
        .padding(14)
        .background(Theme.sage.opacity(0.12), in: .rect(cornerRadius: 14))
    }

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(spacing: 18) {
            CalorieRing(consumed: consumed, goal: calorieGoal)
                .frame(width: 150, height: 150)

            VStack(alignment: .leading, spacing: 12) {
                statLine(symbol: "flame.fill", tint: Theme.spice, label: "Goal", value: "\(calorieGoal)")
                statLine(symbol: "fork.knife", tint: Theme.sage, label: "Eaten", value: "\(consumed)")
                if health.activeCalories > 0 {
                    statLine(symbol: "bolt.fill", tint: Theme.amber, label: "Burned", value: "\(health.activeCalories)")
                }
                statLine(
                    symbol: "chart.line.uptrend.xyaxis",
                    tint: Theme.spiceDeep,
                    label: consumed > calorieGoal ? "Over" : "Left",
                    value: "\(abs(calorieGoal - consumed))"
                )
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
        .shadow(color: Theme.cardShadow, radius: 10, y: 4)
    }

    private func statLine(symbol: String, tint: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint, in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var macrosCard: some View {
        VStack(spacing: 14) {
            MacroBar(label: "Protein", grams: protein, goal: Double(proteinGoal), tint: Theme.sage)
            MacroBar(label: "Carbs", grams: carbs, goal: Double(carbGoal), tint: Theme.amber)
            MacroBar(label: "Fat", grams: fat, goal: Double(fatGoal), tint: Theme.spice)
        }
        .padding(18)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Water

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.30, green: 0.55, blue: 0.78))
                Text("Water")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(waterGlasses) of \(waterGoal) · 8oz")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            HStack(spacing: 8) {
                ForEach(0..<waterGoal, id: \.self) { index in
                    Button {
                        setWater(index + 1 == waterGlasses ? index : index + 1)
                    } label: {
                        Image(systemName: index < waterGlasses ? "drop.fill" : "drop")
                            .font(.system(size: 22))
                            .foregroundStyle(index < waterGlasses
                                             ? Color(red: 0.30, green: 0.55, blue: 0.78)
                                             : Theme.inkSoft.opacity(0.35))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDayClosed)
                }
            }
        }
        .padding(18)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
        .opacity(isDayClosed ? 0.6 : 1)
    }

    // MARK: - Activity (Apple Watch / Health)

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "applewatch")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.sage)
                Text("Activity")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }

            if !health.isAvailable {
                Text("Connect this app on your iPhone to sync steps, calories and sleep from Apple Watch and Health.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                HStack(spacing: 10) {
                    metricTile(symbol: "shoeprints.fill", tint: Theme.amber, value: "\(health.steps)", label: "Steps")
                    metricTile(symbol: "bolt.fill", tint: Theme.spice, value: "\(health.activeCalories)", label: "Cal Burned")
                }
                HStack(spacing: 10) {
                    metricTile(symbol: "figure.run", tint: Theme.sage, value: "\(health.exerciseMinutes)m", label: "Exercise")
                    metricTile(
                        symbol: "bed.double.fill",
                        tint: Color(red: 0.45, green: 0.40, blue: 0.70),
                        value: health.sleepHours > 0 ? String(format: "%.1fh", health.sleepHours) : "—",
                        label: "Sleep"
                    )
                }
            }
        }
        .padding(18)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func metricTile(symbol: String, tint: Color, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(tint, in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.10), in: .rect(cornerRadius: 14))
    }

    // MARK: - Weight

    private var weightCard: some View {
        Button {
            showingWeight = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.spiceDeep)
                    Text("Weight")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft.opacity(0.5))
                }

                if let current = currentWeight {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.1f", current))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        Text("lbs")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                        Spacer()
                        if goalWeight > 0 {
                            Text("Goal \(String(format: "%.0f", goalWeight)) lbs")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    if startWeight > 0, goalWeight > 0, startWeight != goalWeight {
                        weightProgress(current: current)
                    }
                } else {
                    Text("Tap to set your starting weight and goal.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paperRaised, in: .rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func weightProgress(current: Double) -> some View {
        let total = abs(startWeight - goalWeight)
        let done = abs(startWeight - current)
        let progress = total > 0 ? min(done / total, 1) : 0
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.08))
                    Capsule()
                        .fill(Theme.warmGradient)
                        .frame(width: max(geo.size.width * progress, 0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
                }
            }
            .frame(height: 8)
            Text("\(String(format: "%.1f", abs(current - goalWeight))) lbs to goal")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: - Meal sections

    private func mealSection(_ type: MealType) -> some View {
        let entries = todaysEntries.filter { $0.mealType == type }
        let sectionCalories = entries.reduce(0) { $0 + $1.calories }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: type.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(type.tint)
                Text(type.rawValue)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if sectionCalories > 0 {
                    Text("\(sectionCalories) cal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                if !isDayClosed {
                    Button {
                        addMealType = type
                        showingAnalyze = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(type.tint)
                    }
                    .buttonStyle(.plain)
                }
            }

            if entries.isEmpty {
                Text(isDayClosed ? "Nothing logged" : "No food logged yet")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .background(Theme.paperRaised.opacity(0.5), in: .rect(cornerRadius: 14))
            } else {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        foodRow(entry)
                        if entry.id != entries.last?.id {
                            Divider().background(Theme.ink.opacity(0.06))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
            }
        }
    }

    private func foodRow(_ entry: FoodEntry) -> some View {
        HStack(spacing: 12) {
            Group {
                if let data = entry.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        entry.mealType.tint.opacity(0.18)
                        Image(systemName: "fork.knife")
                            .font(.system(size: 16))
                            .foregroundStyle(entry.mealType.tint)
                    }
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("P \(Int(entry.protein.rounded()))")
                    Text("C \(Int(entry.carbs.rounded()))")
                    Text("F \(Int(entry.fat.rounded()))")
                }
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Text("\(entry.calories)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.spice)
            + Text(" cal")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.vertical, 10)
        .contextMenu {
            if !isDayClosed {
                Button(role: .destructive) {
                    modelContext.delete(entry)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Done tracking

    private var doneTrackingButton: some View {
        Button {
            toggleClosed()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isDayClosed ? "lock.open.fill" : "checkmark.seal.fill")
                Text(isDayClosed ? "Reopen This Day" : "Done Logging \(dayLabel)")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(isDayClosed ? Theme.spice : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isDayClosed ? AnyShapeStyle(Theme.paperRaised) : AnyShapeStyle(Theme.sage),
                in: .rect(cornerRadius: 16)
            )
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(isDayClosed ? 0.12 : 0), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private var dayLabel: String {
        Calendar.current.isDateInToday(selectedDate) ? "Today" : dayNumberWithMonth(selectedDate)
    }

    // MARK: - Add button

    private var addButton: some View {
        VStack {
            Spacer()
            Button {
                addMealType = MealType.suggested()
                showingAnalyze = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("Add Food")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 15)
                .padding(.horizontal, 28)
                .background(Theme.spice, in: .capsule)
                .shadow(color: Theme.spice.opacity(0.4), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 18)
        }
    }

    // MARK: - Goals sheet

    private var goalsSheet: some View {
        NavigationStack {
            Form {
                Section("Daily Goals") {
                    goalStepper("Calories", value: $calorieGoal, range: 1000...5000, step: 50, unit: "cal")
                    goalStepper("Protein", value: $proteinGoal, range: 30...300, step: 5, unit: "g")
                    goalStepper("Carbs", value: $carbGoal, range: 50...500, step: 5, unit: "g")
                    goalStepper("Fat", value: $fatGoal, range: 20...200, step: 5, unit: "g")
                    goalStepper("Water", value: $waterGoal, range: 4...16, step: 1, unit: "glasses")
                }
            }
            .navigationTitle("Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingGoals = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(Theme.spice)
    }

    private func goalStepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue) \(unit)")
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    // MARK: - Weight sheet

    private var weightSheet: some View {
        NavigationStack {
            Form {
                Section("Goals") {
                    weightStepper("Starting Weight", value: $startWeight)
                    weightStepper("Goal Weight", value: $goalWeight)
                }
                Section("Log Today") {
                    Button {
                        logWeight()
                    } label: {
                        Label("Log Current Weight", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.spice)
                    }
                    if let current = currentWeight {
                        HStack {
                            Text("Current")
                            Spacer()
                            Text("\(String(format: "%.1f", current)) lbs")
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                }
                if !weights.isEmpty {
                    Section("History") {
                        ForEach(weights.prefix(10)) { entry in
                            HStack {
                                Text(entry.loggedAt, style: .date)
                                    .font(.system(size: 14))
                                Spacer()
                                Text("\(String(format: "%.1f", entry.weightLbs)) lbs")
                                    .foregroundStyle(Theme.inkSoft)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(weights[index]) }
                        }
                    }
                }
            }
            .navigationTitle("Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingWeight = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(Theme.spice)
    }

    private func weightStepper(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            if value.wrappedValue > 0 {
                Text("\(String(format: "%.1f", value.wrappedValue)) lbs")
                    .foregroundStyle(Theme.inkSoft)
            } else {
                Text("Not set")
                    .foregroundStyle(Theme.inkSoft.opacity(0.6))
            }
            Stepper("", value: value, in: 0...600, step: 0.5)
                .labelsHidden()
        }
    }

    // MARK: - Mutations

    private func dayLog(createIfMissing: Bool) -> DailyLog? {
        if let existing = selectedLog { return existing }
        guard createIfMissing else { return nil }
        let log = DailyLog(day: selectedDate)
        modelContext.insert(log)
        return log
    }

    private func setWater(_ count: Int) {
        guard !isDayClosed else { return }
        let log = dayLog(createIfMissing: true)
        log?.waterGlasses = max(0, count)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func toggleClosed() {
        let log = dayLog(createIfMissing: true)
        let nowClosed = !(log?.isClosed ?? false)
        log?.isClosed = nowClosed
        if nowClosed {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func logWeight() {
        // Seed from the last known weight, or the starting weight.
        let base = currentWeight ?? (startWeight > 0 ? startWeight : 150)
        let entry = WeightEntry(weightLbs: base)
        modelContext.insert(entry)
        if startWeight == 0 { startWeight = base }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Date helpers

    private func weekDays() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    private func weekdayLetter(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEEE"
        return f.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    private func dayNumberWithMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

#Preview {
    CalorieTrackerView()
        .modelContainer(for: [Recipe.self, Ingredient.self, ShoppingItem.self, FoodEntry.self, DailyLog.self, WeightEntry.self], inMemory: true)
}

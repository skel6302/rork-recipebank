//
//  CalorieTrackerView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// The calorie tracker tab — a daily dashboard of calories and macros, fed by
/// AI-analyzed food photos and descriptions, inspired by modern calorie trackers.
struct CalorieTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.loggedAt, order: .reverse) private var allEntries: [FoodEntry]

    @AppStorage("calorieGoal") private var calorieGoal: Int = 2000
    @AppStorage("proteinGoal") private var proteinGoal: Int = 140
    @AppStorage("carbGoal") private var carbGoal: Int = 220
    @AppStorage("fatGoal") private var fatGoal: Int = 65

    @State private var selectedDate: Date = .now
    @State private var showingAnalyze = false
    @State private var addMealType: MealType = MealType.suggested()
    @State private var showingGoals = false

    private var todaysEntries: [FoodEntry] {
        allEntries.filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: selectedDate) }
    }

    private var consumed: Int { todaysEntries.reduce(0) { $0 + $1.calories } }
    private var protein: Double { todaysEntries.reduce(0) { $0 + $1.protein } }
    private var carbs: Double { todaysEntries.reduce(0) { $0 + $1.carbs } }
    private var fat: Double { todaysEntries.reduce(0) { $0 + $1.fat } }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        weekStrip
                        summaryCard
                        macrosCard
                        ForEach(MealType.allCases) { type in
                            mealSection(type)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                    .padding(.top, 8)
                }

                addButton
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
                AnalyzeFoodView(initialMealType: addMealType)
            }
            .sheet(isPresented: $showingGoals) {
                goalsSheet
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
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
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

    // MARK: - Summary

    private var summaryCard: some View {
        HStack(spacing: 18) {
            CalorieRing(consumed: consumed, goal: calorieGoal)
                .frame(width: 150, height: 150)

            VStack(alignment: .leading, spacing: 14) {
                statLine(symbol: "flame.fill", tint: Theme.spice, label: "Goal", value: "\(calorieGoal)")
                statLine(symbol: "fork.knife", tint: Theme.sage, label: "Eaten", value: "\(consumed)")
                statLine(
                    symbol: "chart.line.uptrend.xyaxis",
                    tint: Theme.amber,
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

            if entries.isEmpty {
                Text("No food logged yet")
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
            Button(role: .destructive) {
                modelContext.delete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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
        .presentationDetents([.medium])
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
}

#Preview {
    CalorieTrackerView()
        .modelContainer(for: [Recipe.self, Ingredient.self, ShoppingItem.self, FoodEntry.self], inMemory: true)
}

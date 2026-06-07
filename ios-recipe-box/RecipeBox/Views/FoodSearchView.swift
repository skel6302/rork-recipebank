//
//  FoodSearchView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// A fast food-logging search. Search the food database by name, re-add foods
/// you've logged before, or re-log a whole past meal — each with a single tap.
/// Everything you add logs straight to the selected day and meal slot.
struct FoodSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.loggedAt, order: .reverse) private var allEntries: [FoodEntry]

    /// The day new entries are logged to (supports back-dating).
    var logDate: Date = .now
    /// The meal slot to log into; the user can change it in the header.
    var initialMealType: MealType = MealType.suggested()

    @State private var mealType: MealType = MealType.suggested()
    @State private var scope: Scope = .all
    @State private var query = ""
    @State private var dbResults: [AnalyzedFood] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var addedCount = 0

    private enum Scope: String, CaseIterable, Identifiable {
        case all = "All"
        case myFoods = "My Foods"
        case meals = "Meals"
        case database = "Database"
        var id: String { rawValue }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Derived data

    /// Distinct foods the user has logged before (most recent first), filtered by query.
    private var myFoods: [FoodEntry] {
        var seen = Set<String>()
        var result: [FoodEntry] = []
        for entry in allEntries {
            let key = "\(entry.name.lowercased())|\(entry.baseCalories.rounded())"
            if seen.contains(key) { continue }
            if !trimmedQuery.isEmpty, !entry.name.localizedStandardContains(trimmedQuery) { continue }
            seen.insert(key)
            result.append(entry)
            if result.count >= 60 { break }
        }
        return result
    }

    /// Past meals (2+ items logged to the same day & slot), grouped for one-tap re-logging.
    private var pastMeals: [LoggedMeal] {
        let cal = Calendar.current
        var groups: [String: [FoodEntry]] = [:]
        var order: [String] = []
        for entry in allEntries {
            let day = cal.startOfDay(for: entry.loggedAt)
            let key = "\(day.timeIntervalSince1970)|\(entry.mealTypeRaw)"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(entry)
        }
        var meals: [LoggedMeal] = []
        for key in order {
            guard let entries = groups[key], entries.count >= 2 else { continue }
            let meal = LoggedMeal(entries: entries)
            if !trimmedQuery.isEmpty {
                let matches = meal.title.localizedStandardContains(trimmedQuery)
                    || entries.contains { $0.name.localizedStandardContains(trimmedQuery) }
                if !matches { continue }
            }
            meals.append(meal)
            if meals.count >= 30 { break }
        }
        return meals
    }

    private var entryTimestamp: Date {
        let cal = Calendar.current
        if cal.isDateInToday(logDate) { return .now }
        let time = cal.dateComponents([.hour, .minute, .second], from: Date())
        return cal.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: cal.startOfDay(for: logDate)
        ) ?? logDate
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                VStack(spacing: 0) {
                    mealPicker
                    scopePicker
                    resultsList
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.spice)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    } label: {
                        Text(addedCount > 0 ? "Done (\(addedCount))" : "Done")
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(Theme.spice)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods")
            .onSubmit(of: .search) { Task { await runSearch() } }
            .onChange(of: query) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    dbResults = []
                    hasSearched = false
                    errorMessage = nil
                }
            }
            .onAppear { mealType = initialMealType }
        }
        .tint(Theme.spice)
    }

    // MARK: - Meal slot

    private var mealPicker: some View {
        HStack(spacing: 8) {
            ForEach(MealType.allCases) { type in
                Button {
                    withAnimation(.snappy) { mealType = type }
                } label: {
                    Text(type.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(mealType == type ? .white : Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(mealType == type ? type.tint : Theme.paperRaised, in: .capsule)
                        .overlay(Capsule().stroke(Theme.ink.opacity(0.06), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var scopePicker: some View {
        Picker("Scope", selection: $scope) {
            ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                switch scope {
                case .all:
                    allContent
                case .myFoods:
                    myFoodsContent
                case .meals:
                    mealsContent
                case .database:
                    databaseContent
                }
            }
            .padding(16)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private var allContent: some View {
        let foods = Array(myFoods.prefix(6))
        if !foods.isEmpty {
            sectionHeader("My Foods", symbol: "clock.arrow.circlepath")
            ForEach(foods) { entry in foodRow(entry) }
        }
        if !trimmedQuery.isEmpty {
            sectionHeader("Database", symbol: "magnifyingglass")
            databaseContent
        } else if foods.isEmpty {
            emptyHint
        }
    }

    @ViewBuilder
    private var myFoodsContent: some View {
        if myFoods.isEmpty {
            message(trimmedQuery.isEmpty
                    ? "Foods you log will show up here for quick re-adding."
                    : "No logged foods match \"\(trimmedQuery)\".",
                    system: "fork.knife")
        } else {
            ForEach(myFoods) { entry in foodRow(entry) }
        }
    }

    @ViewBuilder
    private var mealsContent: some View {
        if pastMeals.isEmpty {
            message(trimmedQuery.isEmpty
                    ? "Meals you've logged (with two or more items) appear here so you can re-log the whole plate at once."
                    : "No past meals match \"\(trimmedQuery)\".",
                    system: "takeoutbag.and.cup.and.straw.fill")
        } else {
            ForEach(pastMeals) { meal in mealRow(meal) }
        }
    }

    @ViewBuilder
    private var databaseContent: some View {
        if isSearching {
            ProgressView().tint(Theme.spice).padding(.top, 24)
        } else if let errorMessage {
            message(errorMessage, system: "exclamationmark.triangle")
        } else if dbResults.isEmpty && hasSearched {
            message("No foods found for \"\(trimmedQuery)\". Try a simpler name.", system: "magnifyingglass")
        } else if !hasSearched && scope == .database {
            message("Search the food database for any item — granola, yogurt, a candy bar — with full nutrition facts.", system: "barcode.viewfinder")
        }
        ForEach(dbResults) { food in databaseRow(food) }
    }

    private func sectionHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.spice)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Rows

    private func foodRow(_ entry: FoodEntry) -> some View {
        AddRow(
            title: entry.name,
            subtitle: "\(Int(entry.baseCalories.rounded())) cal · P \(Int(entry.baseProtein.rounded())) C \(Int(entry.baseCarbs.rounded())) F \(Int(entry.baseFat.rounded()))",
            tint: mealType.tint,
            photoData: entry.photoData
        ) {
            logFood(
                name: entry.name,
                serving: entry.servingDescription,
                calories: Int(entry.baseCalories.rounded()),
                protein: entry.baseProtein,
                carbs: entry.baseCarbs,
                fat: entry.baseFat,
                wasAI: entry.wasAIEstimated,
                photoData: entry.photoData
            )
        }
    }

    private func databaseRow(_ food: AnalyzedFood) -> some View {
        AddRow(
            title: food.name,
            subtitle: "\(food.calories) cal · \(food.servingDescription)",
            tint: Theme.sage,
            photoData: nil
        ) {
            logFood(
                name: food.name,
                serving: food.servingDescription,
                calories: food.calories,
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat,
                wasAI: false,
                photoData: nil
            )
        }
    }

    private func mealRow(_ meal: LoggedMeal) -> some View {
        AddRow(
            title: meal.title,
            subtitle: "\(meal.totalCalories) cal · \(meal.items.count) items\n\(meal.itemSummary)",
            tint: meal.slot.tint,
            photoData: meal.photoData,
            symbol: meal.slot.symbol
        ) {
            logMeal(meal)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(Theme.sage.opacity(0.55))
            Text("Find any food")
                .font(.cookbookSerif(20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Type a food to search the database, or re-add something you logged before.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal, 24)
    }

    private func message(_ text: String, system: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: system)
                .font(.system(size: 34))
                .foregroundStyle(Theme.inkSoft.opacity(0.5))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 28)
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private func runSearch() async {
        guard trimmedQuery.count >= 2 else { return }
        isSearching = true
        hasSearched = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            dbResults = try await FoodSearchService.search(trimmedQuery)
        } catch {
            dbResults = []
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong searching."
        }
    }

    private func logFood(
        name: String,
        serving: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        wasAI: Bool,
        photoData: Data?
    ) {
        let entry = FoodEntry(
            name: name,
            mealType: mealType,
            servingDescription: serving,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            loggedAt: entryTimestamp,
            wasAIEstimated: wasAI,
            photoData: photoData,
            portion: 1.0
        )
        modelContext.insert(entry)
        addedCount += 1
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func logMeal(_ meal: LoggedMeal) {
        for item in meal.items {
            logFood(
                name: item.name,
                serving: item.serving,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                wasAI: item.wasAI,
                photoData: nil
            )
        }
    }
}

// MARK: - Logged meal grouping

/// A snapshot of a previously logged meal (a day + slot with multiple items),
/// used to re-log the whole plate at once.
private struct LoggedMeal: Identifiable {
    struct Item {
        let name: String
        let serving: String
        let calories: Int
        let protein: Double
        let carbs: Double
        let fat: Double
        let wasAI: Bool
    }

    let id: String
    let title: String
    let slot: MealType
    let items: [Item]
    let totalCalories: Int
    let photoData: Data?

    init(entries: [FoodEntry]) {
        let slot = entries.first?.mealType ?? .snack
        let day = Calendar.current.startOfDay(for: entries.first?.loggedAt ?? .now)
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        self.id = "\(day.timeIntervalSince1970)|\(slot.rawValue)"
        self.title = "\(f.string(from: day)) \(slot.rawValue)"
        self.slot = slot
        self.totalCalories = entries.reduce(0) { $0 + $1.calories }
        self.photoData = entries.first(where: { $0.photoData != nil })?.photoData
        self.items = entries.map {
            Item(
                name: $0.name,
                serving: $0.servingDescription,
                calories: $0.calories,
                protein: $0.protein,
                carbs: $0.carbs,
                fat: $0.fat,
                wasAI: $0.wasAIEstimated
            )
        }
    }

    var itemSummary: String {
        items.map(\.name).prefix(3).joined(separator: ", ")
    }
}

// MARK: - Add row

/// A search-result row with a leading thumbnail/icon and a tap-to-add button that
/// flashes a checkmark when the item is logged.
private struct AddRow: View {
    let title: String
    let subtitle: String
    let tint: Color
    let photoData: Data?
    var symbol: String = "fork.knife"
    let onAdd: () -> Void

    @State private var justAdded = false

    var body: some View {
        Button {
            onAdd()
            withAnimation(.snappy) { justAdded = true }
            Task {
                try? await Task.sleep(for: .seconds(1.1))
                withAnimation(.snappy) { justAdded = false }
            }
        } label: {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: justAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(justAdded ? Theme.sage : tint)
                    .symbolEffect(.bounce, value: justAdded)
            }
            .padding(10)
            .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(justAdded ? Theme.sage.opacity(0.5) : Theme.ink.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let photoData, let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 46, height: 46)
                .clipShape(.rect(cornerRadius: 12))
        } else {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.14), in: .rect(cornerRadius: 12))
        }
    }
}

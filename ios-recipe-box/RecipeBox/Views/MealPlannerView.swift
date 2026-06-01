//
//  MealPlannerView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// A weekly meal planner: assign recipes to each day's meal slots, browse by week,
/// and push every planned ingredient straight to the shopping list (AnyList-style).
struct MealPlannerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlannedMeal.sortIndex) private var allPlanned: [PlannedMeal]
    @Query(sort: \Recipe.title) private var recipes: [Recipe]

    /// Monday-aligned start of the currently displayed week.
    @State private var weekStart: Date = MealPlannerView.startOfWeek(for: .now)
    @State private var pickerTarget: SlotTarget?
    @State private var addedToList = false
    @State private var showingClearConfirm = false

    /// A specific day + meal slot being filled.
    private struct SlotTarget: Identifiable {
        let day: Date
        let meal: MealType
        var id: String { "\(day.timeIntervalSince1970)-\(meal.rawValue)" }
    }

    private let mealSlots: [MealType] = [.breakfast, .lunch, .dinner]

    private var weekDays: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var plannedThisWeek: [PlannedMeal] {
        guard let end = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) else { return [] }
        return allPlanned.filter { $0.dayStart >= weekStart && $0.dayStart < end }
    }

    private var weekIngredientCount: Int {
        plannedThisWeek.reduce(0) { $0 + ($1.recipe?.ingredients.count ?? 0) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.paper.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        weekSwitcher
                        ForEach(weekDays, id: \.self) { day in
                            dayCard(day)
                        }
                        Color.clear.frame(height: weekIngredientCount > 0 ? 96 : 16)
                    }
                    .padding(16)
                }

                if weekIngredientCount > 0 {
                    sendToListBar
                }
            }
            .navigationTitle("Meal Plan")
            .toolbar {
                if !plannedThisWeek.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            showingClearConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Theme.spice)
                        }
                    }
                }
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(item: $pickerTarget) { target in
                MealRecipePickerView(recipes: recipes) { recipe in
                    assign(recipe: recipe, to: target)
                }
            }
            .confirmationDialog(
                "Clear this week's plan?",
                isPresented: $showingClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear Week", role: .destructive) { clearWeek() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes every planned meal for the week shown.")
            }
        }
        .tint(Theme.spice)
    }

    // MARK: - Week switcher

    private var weekSwitcher: some View {
        HStack(spacing: 12) {
            Button {
                changeWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.spice)
                    .frame(width: 38, height: 38)
                    .background(Theme.paperRaised, in: .circle)
                    .overlay(Circle().stroke(Theme.ink.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(weekLabel)
                    .font(.cookbookSerif(18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(weekRange)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)

            Button {
                changeWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.spice)
                    .frame(width: 38, height: 38)
                    .background(Theme.paperRaised, in: .circle)
                    .overlay(Circle().stroke(Theme.ink.opacity(0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var weekLabel: String {
        let thisWeek = MealPlannerView.startOfWeek(for: .now)
        let diff = Calendar.current.dateComponents([.weekOfYear], from: thisWeek, to: weekStart).weekOfYear ?? 0
        switch diff {
        case 0: return "This Week"
        case 1: return "Next Week"
        case -1: return "Last Week"
        default: return "Week of"
        }
    }

    private var weekRange: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(f.string(from: weekStart)) – \(f.string(from: end))"
    }

    // MARK: - Day card

    private func dayCard(_ day: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(dayName(day))
                    .font(.cookbookSerif(17, weight: .bold))
                    .foregroundStyle(isToday ? Theme.spice : Theme.ink)
                Text(dayNumber(day))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                if isToday {
                    Text("TODAY")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.spice, in: .capsule)
                }
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(mealSlots) { meal in
                    mealSlotRow(day: day, meal: meal)
                }
            }
        }
        .padding(14)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isToday ? Theme.spice.opacity(0.4) : Theme.ink.opacity(0.06), lineWidth: isToday ? 1.5 : 1)
        )
    }

    private func mealSlotRow(day: Date, meal: MealType) -> some View {
        let meals = plannedThisWeek
            .filter { Calendar.current.isDate($0.dayStart, inSameDayAs: day) && $0.mealType == meal }
            .sorted { $0.sortIndex < $1.sortIndex }
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: meal.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(meal.tint)
                .frame(width: 22, height: 22)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(meal.rawValue.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.7)
                    .foregroundStyle(Theme.inkSoft.opacity(0.8))

                if meals.isEmpty {
                    Button {
                        pickerTarget = SlotTarget(day: day, meal: meal)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Add a recipe")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(Theme.inkSoft.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 12)
                        .background(Theme.ink.opacity(0.03), in: .rect(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(Theme.ink.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(meals) { planned in
                        plannedRow(planned)
                    }
                    Button {
                        pickerTarget = SlotTarget(day: day, meal: meal)
                    } label: {
                        Label("Add another", systemImage: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.spice)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func plannedRow(_ planned: PlannedMeal) -> some View {
        Group {
            if let recipe = planned.recipe {
                NavigationLink(value: recipe) {
                    plannedRowContent(planned)
                }
                .buttonStyle(.plain)
            } else {
                plannedRowContent(planned)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                remove(planned)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                remove(planned)
            } label: {
                Label("Remove from Plan", systemImage: "trash")
            }
        }
    }

    private func plannedRowContent(_ planned: PlannedMeal) -> some View {
        HStack(spacing: 10) {
            if let recipe = planned.recipe {
                RecipeThumbnail(category: recipe.category, cornerRadius: 8, photoData: recipe.displayPhotoData)
                    .frame(width: 38, height: 38)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(planned.displayTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let recipe = planned.recipe {
                    Text("\(recipe.ingredients.count) ingredients · \(recipe.totalMinutes)m")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()
            if planned.recipe != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft.opacity(0.5))
            }
        }
        .padding(8)
        .background(Theme.paper, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.ink.opacity(0.05), lineWidth: 1))
        .contentShape(Rectangle())
    }

    // MARK: - Send to list

    private var sendToListBar: some View {
        Button {
            sendWeekToShoppingList()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: addedToList ? "checkmark.circle.fill" : "cart.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                Text(addedToList ? "Added to Shopping List" : "Add Week to Shopping List")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(addedToList ? AnyShapeStyle(Theme.sage) : AnyShapeStyle(Theme.warmGradient), in: .capsule)
            .shadow(color: Theme.spice.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func assign(recipe: Recipe, to target: SlotTarget) {
        let existing = plannedThisWeek.filter {
            Calendar.current.isDate($0.dayStart, inSameDayAs: target.day) && $0.mealType == target.meal
        }
        let planned = PlannedMeal(
            dayStart: target.day,
            mealType: target.meal,
            sortIndex: existing.count,
            recipe: recipe
        )
        modelContext.insert(planned)
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func remove(_ planned: PlannedMeal) {
        withAnimation(.snappy) { modelContext.delete(planned) }
        try? modelContext.save()
    }

    private func clearWeek() {
        withAnimation {
            for planned in plannedThisWeek {
                modelContext.delete(planned)
            }
        }
        try? modelContext.save()
    }

    private func sendWeekToShoppingList() {
        // Merge duplicate ingredients across the week's recipes by name.
        var merged: [String: ShoppingItem] = [:]
        for planned in plannedThisWeek {
            guard let recipe = planned.recipe else { continue }
            for ing in recipe.ingredients {
                let key = ing.name.lowercased()
                if let existing = merged[key] {
                    if !ing.quantity.isEmpty {
                        existing.quantity = existing.quantity.isEmpty
                            ? ing.quantity
                            : "\(existing.quantity) + \(ing.quantity)"
                    }
                } else {
                    merged[key] = ShoppingItem(
                        name: ing.name,
                        quantity: ing.quantity,
                        aisle: ing.aisle,
                        sourceRecipeTitle: recipe.title
                    )
                }
            }
        }
        for item in merged.values {
            modelContext.insert(item)
        }
        try? modelContext.save()
        withAnimation(.snappy) { addedToList = true }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { addedToList = false }
        }
    }

    private func changeWeek(by offset: Int) {
        guard let newStart = Calendar.current.date(byAdding: .weekOfYear, value: offset, to: weekStart) else { return }
        withAnimation(.snappy) {
            weekStart = newStart
            addedToList = false
        }
    }

    // MARK: - Formatting

    private func dayName(_ day: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: day)
    }

    private func dayNumber(_ day: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: day)
    }

    /// Monday-aligned start of the week containing the given date.
    static func startOfWeek(for date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }
}

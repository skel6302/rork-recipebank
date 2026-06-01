//
//  ShoppingListView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData

/// The shopping list, grouped by aisle, with checkoff and grocery-sync entry point.
struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.addedAt, order: .reverse) private var items: [ShoppingItem]

    @State private var newItemName: String = ""
    @State private var showingSync = false
    @State private var showingShare = false

    private var groupedItems: [(aisle: GroceryAisle, items: [ShoppingItem])] {
        let grouped = Dictionary(grouping: items) { $0.aisle }
        return GroceryAisle.allCases.compactMap { aisle in
            guard let group = grouped[aisle], !group.isEmpty else { return nil }
            return (aisle, group.sorted { !$0.isChecked && $1.isChecked })
        }
    }

    private var remainingCount: Int { items.filter { !$0.isChecked }.count }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Theme.paper.ignoresSafeArea()

                if items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            progressCard
                            ForEach(groupedItems, id: \.aisle) { group in
                                aisleSection(group.aisle, items: group.items)
                            }
                            Color.clear.frame(height: 90)
                        }
                        .padding(16)
                    }
                }

                if !items.isEmpty {
                    syncBar
                }
            }
            .navigationTitle("Shopping List")
            .safeAreaInset(edge: .top) {
                addBar
            }
            .toolbar {
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showingShare = true
                            } label: {
                                Label("Share / Export", systemImage: "square.and.arrow.up")
                            }
                            Button(role: .destructive) {
                                clearChecked()
                            } label: {
                                Label("Clear Checked", systemImage: "checkmark.circle")
                            }
                            Button(role: .destructive) {
                                clearAll()
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(Theme.spice)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSync) {
                GrocerySyncView(items: items.filter { !$0.isChecked })
            }
            .sheet(isPresented: $showingShare) {
                ShareSheet(text: GroceryService.plainText(for: items.filter { !$0.isChecked }))
            }
        }
        .tint(Theme.spice)
    }

    private var addBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(Theme.spice)
            TextField("Add an item…", text: $newItemName)
                .submitLabel(.done)
                .onSubmit(addItem)
            if !newItemName.isEmpty {
                Button("Add", action: addItem)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.spice)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.paperRaised)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.ink.opacity(0.06)).frame(height: 1)
        }
    }

    private var progressCard: some View {
        let total = items.count
        let done = total - remainingCount
        let progress = total == 0 ? 0 : Double(done) / Double(total)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(remainingCount == 0 ? "All done! 🎉" : "\(remainingCount) items to get")
                    .font(.cookbookSerif(18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(done)/\(total)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.08))
                    Capsule()
                        .fill(Theme.warmGradient)
                        .frame(width: max(8, geo.size.width * progress))
                        .animation(.snappy, value: progress)
                }
            }
            .frame(height: 10)
        }
        .padding(16)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func aisleSection(_ aisle: GroceryAisle, items: [ShoppingItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: aisle.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.spice)
                Text(aisle.rawValue.uppercased())
                    .font(.system(size: 12, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    itemRow(item)
                    if item.id != items.last?.id {
                        Rectangle().fill(Theme.ink.opacity(0.06)).frame(height: 1).padding(.leading, 44)
                    }
                }
            }
            .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
        }
    }

    private func itemRow(_ item: ShoppingItem) -> some View {
        Button {
            withAnimation(.snappy) { item.isChecked.toggle() }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isChecked ? Theme.sage : Theme.inkSoft.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(item.isChecked ? Theme.inkSoft : Theme.ink)
                        .strikethrough(item.isChecked)
                    if let source = item.sourceRecipeTitle {
                        Text(source)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkSoft.opacity(0.8))
                    }
                }
                Spacer()
                if !item.quantity.isEmpty {
                    Text(item.quantity)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var syncBar: some View {
        Button {
            showingSync = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "cart.fill.badge.plus")
                    .font(.system(size: 18, weight: .semibold))
                Text("Send to Grocery Service")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.warmGradient, in: .capsule)
            .shadow(color: Theme.spice.opacity(0.35), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .disabled(remainingCount == 0)
        .opacity(remainingCount == 0 ? 0.5 : 1)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "cart")
                .font(.system(size: 56))
                .foregroundStyle(Theme.spice.opacity(0.5))
            Text("Your list is empty")
                .font(.cookbookSerif(20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Add items above, or tap “Add to List” on any recipe.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private func addItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let draft = DraftIngredient(name: trimmed)
        let item = ShoppingItem(name: trimmed, aisle: draft.guessedAisle)
        modelContext.insert(item)
        newItemName = ""
    }

    private func clearChecked() {
        withAnimation {
            for item in items where item.isChecked {
                modelContext.delete(item)
            }
        }
    }

    private func clearAll() {
        withAnimation {
            for item in items {
                modelContext.delete(item)
            }
        }
    }
}

//
//  RecipeEditView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData
import PhotosUI

/// Create or edit a recipe. Pass `nil` to create a new one.
struct RecipeEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(RecipeSyncService.self) private var sync

    let recipe: Recipe?
    /// Optional scanned draft used to pre-fill the form for a new recipe.
    var prefill: ScannedRecipe? = nil

    @State private var title: String = ""
    @State private var summary: String = ""
    @State private var category: RecipeCategory = .dinner
    @State private var servings: Int = 2
    @State private var prepMinutes: Int = 10
    @State private var cookMinutes: Int = 20
    @State private var notes: String = ""
    @State private var ingredients: [DraftIngredient] = [DraftIngredient()]
    @State private var steps: [String] = [""]
    @State private var originalPhotoData: Data? = nil
    @State private var originalPhotoPages: [Data] = []
    @State private var photoData: Data? = nil
    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var showingCamera: Bool = false
    @State private var didLoad: Bool = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// All original-scan pages currently held in the editor.
    private var displayPages: [Data] {
        if !originalPhotoPages.isEmpty { return originalPhotoPages }
        if let originalPhotoData { return [originalPhotoData] }
        return []
    }

    private var isEditing: Bool { recipe != nil }
    private var navigationTitle: String {
        if isEditing { return "Edit Recipe" }
        return prefill != nil ? "Review Scan" : "New Recipe"
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection

                Section("Recipe") {
                    TextField("Title", text: $title)
                    TextField("Short description", text: $summary, axis: .vertical)
                    Picker("Category", selection: $category) {
                        ForEach(RecipeCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.symbol).tag(cat)
                        }
                    }
                }

                Section("Details") {
                    Stepper("Servings: \(servings)", value: $servings, in: 1...20)
                    Stepper("Prep: \(prepMinutes) min", value: $prepMinutes, in: 0...240, step: 5)
                    Stepper("Cook: \(cookMinutes) min", value: $cookMinutes, in: 0...480, step: 5)
                }

                Section("Ingredients") {
                    ForEach($ingredients) { $ing in
                        HStack {
                            TextField("Qty", text: $ing.quantity)
                                .frame(width: 70)
                                .foregroundStyle(Theme.inkSoft)
                            TextField("Ingredient", text: $ing.name)
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }
                    Button {
                        ingredients.append(DraftIngredient())
                    } label: {
                        Label("Add Ingredient", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.spice)
                    }
                }

                Section("Instructions") {
                    ForEach($steps.indices, id: \.self) { index in
                        HStack(alignment: .top) {
                            Text("\(index + 1).")
                                .foregroundStyle(Theme.spice)
                                .fontWeight(.bold)
                            TextField("Step", text: $steps[index], axis: .vertical)
                        }
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    Button {
                        steps.append("")
                    } label: {
                        Label("Add Step", systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.spice)
                    }
                }

                if !displayPages.isEmpty {
                    Section(displayPages.count > 1 ? "Original Scan (\(displayPages.count) pages)" : "Original Scan") {
                        ForEach(Array(displayPages.enumerated()), id: \.offset) { index, data in
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .clipShape(.rect(cornerRadius: 12))
                                    .overlay(alignment: .topTrailing) {
                                        if displayPages.count > 1 {
                                            let pageLabel = "Page " + String(index + 1)
                                            Text(pageLabel)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 9)
                                                .padding(.vertical, 5)
                                                .background(.black.opacity(0.45), in: .capsule)
                                                .padding(10)
                                        }
                                    }
                                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                            }
                        }
                        Text("We kept every page of the source so you always have the original.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }

                Section("Notes") {
                    TextField("Personal notes, tips, swaps…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
            .onChange(of: pickedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        photoData = normalized(image)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                FoodCameraPicker { image in
                    showingCamera = false
                    if let image { photoData = normalized(image) }
                }
                .ignoresSafeArea()
            }
        }
        .tint(Theme.spice)
    }

    private var photoSection: some View {
        Section("Photo") {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Color(.secondarySystemBackground)
                    .frame(height: 180)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 12))
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                Label(photoData == nil ? "Add a Photo" : "Choose Different Photo", systemImage: "photo.on.rectangle.angled")
                    .foregroundStyle(Theme.spice)
            }

            if cameraAvailable {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take a Photo", systemImage: "camera.fill")
                        .foregroundStyle(Theme.spice)
                }
            }

            if photoData != nil {
                Button(role: .destructive) {
                    photoData = nil
                    pickedItem = nil
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            }
        }
    }

    /// Redraws an image upright at a sensible max size so off-kilter EXIF
    /// orientation and huge files don't cause layout or storage issues.
    private func normalized(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1600
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        if let prefill, recipe == nil {
            title = prefill.title
            summary = prefill.summary
            ingredients = prefill.ingredients.isEmpty ? [DraftIngredient()] : prefill.ingredients
            steps = prefill.steps.isEmpty ? [""] : prefill.steps
            originalPhotoData = prefill.photoData
            originalPhotoPages = prefill.pagePhotos
            return
        }

        guard let recipe else { return }
        originalPhotoData = recipe.originalPhotoData
        originalPhotoPages = recipe.originalPhotoPages
        photoData = recipe.photoData
        title = recipe.title
        summary = recipe.summary
        category = recipe.category
        servings = recipe.servings
        prepMinutes = recipe.prepMinutes
        cookMinutes = recipe.cookMinutes
        notes = recipe.notes
        ingredients = recipe.ingredients
            .sorted { $0.sortIndex < $1.sortIndex }
            .map { DraftIngredient(name: $0.name, quantity: $0.quantity, aisle: $0.aisle) }
        if ingredients.isEmpty { ingredients = [DraftIngredient()] }
        steps = recipe.steps.isEmpty ? [""] : recipe.steps
    }

    private func save() {
        let cleanIngredients = ingredients
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .enumerated()
            .map { index, draft in
                Ingredient(name: draft.name, quantity: draft.quantity, aisle: draft.guessedAisle, sortIndex: index)
            }
        let cleanSteps = steps.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        if let recipe {
            recipe.title = title
            recipe.summary = summary
            recipe.category = category
            recipe.servings = servings
            recipe.prepMinutes = prepMinutes
            recipe.cookMinutes = cookMinutes
            recipe.notes = notes
            recipe.ingredients = cleanIngredients
            recipe.steps = cleanSteps
            recipe.originalPhotoData = originalPhotoData
            recipe.originalPhotoPages = originalPhotoPages
            recipe.photoData = photoData
            recipe.touch()
        } else {
            let newRecipe = Recipe(
                title: title,
                summary: summary,
                category: category,
                servings: servings,
                prepMinutes: prepMinutes,
                cookMinutes: cookMinutes,
                notes: notes,
                ingredients: cleanIngredients,
                steps: cleanSteps,
                originalPhotoData: originalPhotoData,
                originalPhotoPages: originalPhotoPages,
                photoData: photoData,
                wasScanned: prefill != nil
            )
            modelContext.insert(newRecipe)
        }
        try? modelContext.save()
        Task { await sync.syncNow() }
        dismiss()
    }
}

/// Lightweight editable ingredient row with simple aisle inference.
struct DraftIngredient: Identifiable {
    let id = UUID()
    var name: String = ""
    var quantity: String = ""
    var aisle: GroceryAisle = .other

    /// Naively infers a grocery aisle from the ingredient name.
    var guessedAisle: GroceryAisle {
        let n = name.lowercased()
        let map: [(GroceryAisle, [String])] = [
            (.produce, ["lettuce", "tomato", "onion", "garlic", "carrot", "pepper", "basil", "lemon", "lime", "cabbage", "apple", "banana", "spinach", "potato"]),
            (.meat, ["chicken", "beef", "pork", "salmon", "fish", "shrimp", "bacon", "turkey", "sausage"]),
            (.dairy, ["milk", "cheese", "butter", "egg", "cream", "yogurt", "parmesan", "buttermilk"]),
            (.bakery, ["bread", "bun", "bagel", "tortilla"]),
            (.frozen, ["frozen", "ice cream", "ice"]),
            (.spices, ["salt", "pepper", "cumin", "paprika", "cinnamon", "oregano", "spice"]),
            (.beverages, ["espresso", "coffee", "tea", "juice", "soda", "wine"])
        ]
        for (aisle, keywords) in map where keywords.contains(where: { n.contains($0) }) {
            return aisle
        }
        return aisle == .other ? .pantry : aisle
    }
}

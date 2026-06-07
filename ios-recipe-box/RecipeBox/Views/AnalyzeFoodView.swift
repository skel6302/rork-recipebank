//
//  AnalyzeFoodView.swift
//  RecipeBox
//

import SwiftUI
import SwiftData
import PhotosUI

/// Capture or describe a meal, let AI estimate its nutrition, review/adjust,
/// and log it to the calorie tracker.
struct AnalyzeFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.loggedAt, order: .reverse) private var allEntries: [FoodEntry]

    /// Pre-fills the meal slot (e.g. breakfast) when opened from a section.
    var initialMealType: MealType = MealType.suggested()

    /// The day the food should be logged to (supports back-dating). Defaults to now.
    var logDate: Date = .now

    @State private var phase: Phase = .choosing
    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var descriptionText = ""
    @State private var showingDescribe = false
    @State private var showingBarcode = false
    @State private var showingSearch = false

    @State private var capturedImage: UIImage?
    @State private var analysis: MealAnalysis?
    @State private var mealType: MealType = MealType.suggested()
    @State private var portion: Double = 1.0
    @State private var errorMessage: String?

    private let portionPresets: [Double] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0]

    private enum Phase: Equatable {
        case choosing
        case processing
        case result
    }

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// The most recently logged distinct foods for the current meal slot, used as
    /// one-tap suggestions (e.g. your usual breakfast items).
    private var suggestions: [FoodEntry] {
        var seen = Set<String>()
        var result: [FoodEntry] = []
        for entry in allEntries where entry.mealType == mealType {
            let key = entry.name.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(entry)
            if result.count >= 8 { break }
        }
        return result
    }

    /// Timestamp to stamp on new entries — keeps the current time but uses the
    /// selected day so back-dated entries land on the right date.
    private var entryTimestamp: Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(logDate) { return .now }
        let now = Date()
        let time = calendar.dateComponents([.hour, .minute, .second], from: now)
        return calendar.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: calendar.startOfDay(for: logDate)
        ) ?? logDate
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                switch phase {
                case .choosing: chooser
                case .processing: processing
                case .result: result
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                FoodCameraPicker { image in
                    showingCamera = false
                    if let image { process(image) }
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showingBarcode) {
                BarcodeScannerView { code in
                    showingBarcode = false
                    lookupBarcode(code)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                loadPhoto(newItem)
            }
            .onAppear { mealType = initialMealType }
        }
        .tint(Theme.spice)
    }

    // MARK: - Chooser

    private var chooser: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero

                if !suggestions.isEmpty {
                    suggestionsSection
                        .padding(.horizontal, 20)
                }

                VStack(spacing: 14) {
                    choiceCard(
                        title: "Search Foods",
                        subtitle: "Look up any food's nutrition, or re-add foods and meals you've logged before.",
                        symbol: "magnifyingglass",
                        tint: Theme.sage
                    ) { showingSearch = true }

                    if cameraAvailable {
                        choiceCard(
                            title: "Snap a Photo",
                            subtitle: "Point at your plate — AI reads the calories and macros.",
                            symbol: "camera.fill",
                            tint: Theme.spice
                        ) { showingCamera = true }
                    } else {
                        cameraUnavailableNote
                    }

                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        choiceCardLabel(
                            title: "Choose a Photo",
                            subtitle: "Analyze a picture of food from your library.",
                            symbol: "photo.on.rectangle.angled",
                            tint: Color(red: 0.45, green: 0.40, blue: 0.70)
                        )
                    }
                    .buttonStyle(.plain)

                    choiceCard(
                        title: "Scan a Barcode",
                        subtitle: "Scan a packaged food and pull its nutrition facts instantly.",
                        symbol: "barcode.viewfinder",
                        tint: Theme.spiceDeep
                    ) { showingBarcode = true }

                    choiceCard(
                        title: "Describe It",
                        subtitle: "Type a meal or paste a recipe and we'll estimate it.",
                        symbol: "text.alignleft",
                        tint: Theme.amber
                    ) { showingDescribe = true }
                }
                .padding(.horizontal, 20)

                if let errorMessage {
                    errorBanner(errorMessage)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 12)
        }
        .sheet(isPresented: $showingDescribe) { describeSheet }
        .sheet(isPresented: $showingSearch) {
            FoodSearchView(logDate: logDate, initialMealType: mealType)
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(mealType.tint)
                Text("Recent in \(mealType.rawValue)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            VStack(spacing: 8) {
                ForEach(suggestions) { entry in
                    Button {
                        quickAdd(entry)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.ink)
                                    .lineLimit(1)
                                Text("\(entry.calories) cal · P \(Int(entry.protein.rounded())) C \(Int(entry.carbs.rounded())) F \(Int(entry.fat.rounded()))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(mealType.tint)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Theme.paperRaised, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.warmGradient)
                    .frame(width: 92, height: 92)
                    .shadow(color: Theme.spice.opacity(0.35), radius: 14, y: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("What did you eat?")
                .font(.cookbookSerif(24, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Snap, pick, or describe a meal and let AI estimate the calories and macros instantly.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .padding(.top, 16)
    }

    private func choiceCard(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            choiceCardLabel(title: title, subtitle: subtitle, symbol: symbol, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func choiceCardLabel(title: String, subtitle: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(tint, in: .rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkSoft.opacity(0.5))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private var cameraUnavailableNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 20))
                .foregroundStyle(Theme.amber)
            Text("Install this app on your device via the Rork App to snap food with the camera. You can still choose a photo or describe your meal.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cream, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.amber.opacity(0.25), lineWidth: 1))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.spice)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.spice.opacity(0.08), in: .rect(cornerRadius: 14))
    }

    // MARK: - Describe sheet

    private var describeSheet: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text("Describe your meal in plain words — e.g. \"2 scrambled eggs, toast with butter, and a black coffee.\"")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.inkSoft)

                    TextEditor(text: $descriptionText)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .frame(minHeight: 160)
                        .background(Theme.paperRaised, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink.opacity(0.08), lineWidth: 1))

                    Button {
                        showingDescribe = false
                        processDescription()
                    } label: {
                        Text("Estimate Nutrition")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.spice, in: .rect(cornerRadius: 14))
                    }
                    .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Describe Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingDescribe = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(Theme.spice)
    }

    // MARK: - Processing

    private var processing: some View {
        VStack(spacing: 18) {
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipShape(.rect(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.08), lineWidth: 1))
            } else {
                ProgressView().controlSize(.large).tint(Theme.spice)
            }
            HStack(spacing: 8) {
                ProgressView().tint(Theme.spice)
                Text("Analyzing your meal…")
                    .font(.cookbookSerif(20, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            Text("Estimating calories, protein, carbs and fat.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Result

    @ViewBuilder
    private var result: some View {
        if let analysis {
            ScrollView {
                VStack(spacing: 18) {
                    if let capturedImage {
                        Color(.secondarySystemBackground)
                            .frame(height: 200)
                            .overlay {
                                Image(uiImage: capturedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadius: 20))
                    }

                    VStack(spacing: 6) {
                        Text(analysis.mealName)
                            .font(.cookbookSerif(24, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        Text("\(scaled(analysis.totalCalories)) calories")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.spice)
                            .contentTransition(.numericText())
                            .animation(.snappy, value: portion)
                    }

                    macroSummary(analysis)

                    mealTypePicker

                    portionPicker

                    itemsList(analysis)

                    if let note = analysis.note, !note.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(Theme.sage)
                            Text(note)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.paperRaised, in: .rect(cornerRadius: 14))
                    }

                    saveButton(analysis)
                }
                .padding(20)
            }
        } else {
            ProgressView().tint(Theme.spice)
        }
    }

    private func macroSummary(_ analysis: MealAnalysis) -> some View {
        HStack(spacing: 10) {
            macroPill("Protein", grams: analysis.totalProtein * portion, tint: Theme.sage)
            macroPill("Carbs", grams: analysis.totalCarbs * portion, tint: Theme.amber)
            macroPill("Fat", grams: analysis.totalFat * portion, tint: Theme.spice)
        }
    }

    private func scaled(_ value: Int) -> Int { Int((Double(value) * portion).rounded()) }

    private var portionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Portion eaten")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                ForEach(portionPresets, id: \.self) { value in
                    let isSelected = abs(portion - value) < 0.001
                    Button {
                        withAnimation(.snappy) { portion = value }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(portionLabel(value))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isSelected ? .white : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(isSelected ? Theme.spice : Theme.paperRaised, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func portionLabel(_ value: Double) -> String {
        switch value {
        case 0.25: return "¼"
        case 0.5: return "½"
        case 0.75: return "¾"
        case 1.0: return "1"
        case 1.5: return "1½"
        case 2.0: return "2"
        default: return String(format: "%.2g", value)
        }
    }

    private func macroPill(_ label: String, grams: Double, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(grams.rounded()))g")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.14), in: .rect(cornerRadius: 14))
        .overlay(alignment: .top) {
            Rectangle().fill(tint).frame(height: 3).clipShape(.rect(cornerRadius: 2))
        }
    }

    private var mealTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log to")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: 8) {
                ForEach(MealType.allCases) { type in
                    Button {
                        mealType = type
                    } label: {
                        Text(type.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(mealType == type ? .white : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(mealType == type ? type.tint : Theme.paperRaised, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func itemsList(_ analysis: MealAnalysis) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(analysis.items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if !item.servingDescription.isEmpty {
                            Text(item.servingDescription)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    Spacer()
                    Text("\(item.calories) cal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.spice)
                }
                .padding(.vertical, 12)
                if index < analysis.items.count - 1 {
                    Divider().background(Theme.ink.opacity(0.06))
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func saveButton(_ analysis: MealAnalysis) -> some View {
        Button {
            save(analysis)
        } label: {
            Text("Log This Meal")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.spice, in: .rect(cornerRadius: 16))
                .shadow(color: Theme.spice.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func loadPhoto(_ item: PhotosPickerItem) {
        errorMessage = nil
        phase = .processing
        Task {
            guard
                let data = try? await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                phase = .choosing
                return
            }
            await runImageAnalysis(image)
        }
    }

    private func process(_ image: UIImage) {
        errorMessage = nil
        phase = .processing
        Task { await runImageAnalysis(image) }
    }

    private func lookupBarcode(_ code: String) {
        errorMessage = nil
        capturedImage = nil
        phase = .processing
        Task {
            do {
                let result = try await FoodProductService.lookup(barcode: code)
                await present(result)
            } catch {
                await fail(error)
            }
        }
    }

    private func processDescription() {
        let text = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        errorMessage = nil
        capturedImage = nil
        phase = .processing
        Task {
            do {
                let result = try await CalorieAnalyzer.analyze(text: text)
                await present(result)
            } catch {
                await fail(error)
            }
        }
    }

    private func runImageAnalysis(_ image: UIImage) async {
        await MainActor.run { capturedImage = image }
        do {
            let result = try await CalorieAnalyzer.analyze(image: image)
            await present(result)
        } catch {
            await fail(error)
        }
    }

    @MainActor
    private func present(_ result: MealAnalysis) {
        guard !result.items.isEmpty else {
            errorMessage = "We couldn't find any food to analyze. Try another photo or describe it."
            phase = .choosing
            return
        }
        analysis = result
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        phase = .result
    }

    @MainActor
    private func fail(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
        phase = .choosing
    }

    private func save(_ analysis: MealAnalysis) {
        let entry = FoodEntry(
            name: analysis.mealName,
            mealType: mealType,
            servingDescription: analysis.items.map(\.name).joined(separator: ", "),
            calories: scaled(analysis.totalCalories),
            protein: (analysis.totalProtein * portion * 10).rounded() / 10,
            carbs: (analysis.totalCarbs * portion * 10).rounded() / 10,
            fat: (analysis.totalFat * portion * 10).rounded() / 10,
            loggedAt: entryTimestamp,
            wasAIEstimated: true,
            photoData: capturedImage?.jpegData(compressionQuality: 0.7),
            portion: portion
        )
        modelContext.insert(entry)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        dismiss()
    }

    /// Re-logs a previously eaten food for this meal slot with one tap.
    private func quickAdd(_ source: FoodEntry) {
        let entry = FoodEntry(
            name: source.name,
            mealType: mealType,
            servingDescription: source.servingDescription,
            calories: source.calories,
            protein: source.protein,
            carbs: source.carbs,
            fat: source.fat,
            loggedAt: entryTimestamp,
            wasAIEstimated: source.wasAIEstimated,
            photoData: source.photoData
        )
        modelContext.insert(entry)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        dismiss()
    }
}

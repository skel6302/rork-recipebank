//
//  ScanRecipeView.swift
//  RecipeBox
//

import SwiftUI
import PhotosUI
import VisionKit

/// Entry point for digitizing a physical recipe — a handwritten card from grandma
/// or a printed meal-kit card. Lets the user capture with the camera (on device)
/// or pick a photo, then runs OCR and hands back a `ScannedRecipe` draft.
struct ScanRecipeView: View {
    @Environment(\.dismiss) private var dismiss

    /// Called with the digitized draft once scanning finishes.
    var onScanned: (ScannedRecipe) -> Void

    @State private var phase: Phase = .choosing
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showingCamera = false

    private enum Phase: Equatable {
        case choosing
        case processing
    }

    private var cameraSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                switch phase {
                case .choosing:
                    chooser
                case .processing:
                    processing
                }
            }
            .navigationTitle("Scan Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                DocumentScannerView { images in
                    showingCamera = false
                    if !images.isEmpty {
                        process(images)
                    }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                loadPhotos(newItems)
            }
        }
        .tint(Theme.spice)
    }

    // MARK: - Chooser

    private var chooser: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero

                VStack(spacing: 14) {
                    if cameraSupported {
                        captureCard(
                            title: "Scan with Camera",
                            subtitle: "Capture every page — scan multiple pages and we'll combine them into one recipe.",
                            symbol: "doc.viewfinder",
                            tint: Theme.spice
                        ) {
                            showingCamera = true
                        }
                    } else {
                        cameraUnavailableNote
                    }

                    PhotosPicker(selection: $photoItems, maxSelectionCount: 6, matching: .images, photoLibrary: .shared()) {
                        captureCardLabel(
                            title: "Choose Photos",
                            subtitle: "Import one or more pages of a handwritten or printed recipe.",
                            symbol: "photo.on.rectangle.angled",
                            tint: Theme.sage
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)

                tipBlock
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 12)
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.warmGradient)
                    .frame(width: 92, height: 92)
                    .shadow(color: Theme.spice.opacity(0.35), radius: 14, y: 6)
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Digitize any recipe")
                .font(.cookbookSerif(24, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("We'll read the text and turn it into an editable recipe — and keep a photo of the original.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .padding(.top, 16)
    }

    private func captureCard(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            captureCardLabel(title: title, subtitle: subtitle, symbol: symbol, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func captureCardLabel(title: String, subtitle: String, symbol: String, tint: Color) -> some View {
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
            Text("Install this app on your device via the Rork App to scan with the camera. You can still import a photo below.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cream, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.amber.opacity(0.25), lineWidth: 1))
    }

    private var tipBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Tips for a clean scan", systemImage: "lightbulb.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.spice)
            tip("Lay the recipe flat with good, even lighting.")
            tip("Recipe spread across pages? Scan or pick every page — we'll merge them.")
            tip("After scanning, review the draft — you can fix any words.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Theme.sage).frame(width: 5, height: 5).padding(.top, 6)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: - Processing

    private var processing: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.spice)
            Text("Reading your recipe…")
                .font(.cookbookSerif(20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Recognizing the text and organizing ingredients and steps.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Actions

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        phase = .processing
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    images.append(image)
                }
            }
            guard !images.isEmpty else {
                phase = .choosing
                return
            }
            await runScan(on: images)
        }
    }

    private func process(_ images: [UIImage]) {
        phase = .processing
        Task { await runScan(on: images) }
    }

    private func runScan(on images: [UIImage]) async {
        let result = await RecipeScanner.scan(images: images)
        await MainActor.run {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            onScanned(result)
            dismiss()
        }
    }
}

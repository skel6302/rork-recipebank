//
//  ImportLinkView.swift
//  RecipeBox
//

import SwiftUI

/// Lets the user paste (or pre-fill from the share sheet) a TikTok / Instagram /
/// YouTube link and pull the recipe out of the post into an editable draft.
struct ImportLinkView: View {
    @Environment(\.dismiss) private var dismiss

    /// Optional link to start with (e.g. handed in by the Share Extension).
    var initialLink: String = ""

    /// Called with the parsed draft once import succeeds.
    var onImported: (ScannedRecipe) -> Void

    @State private var link: String = ""
    @State private var phase: Phase = .input
    @State private var errorMessage: String?

    private enum Phase: Equatable {
        case input
        case importing
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()
                switch phase {
                case .input:
                    inputForm
                case .importing:
                    importing
                }
            }
            .navigationTitle("Import from Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(phase == .importing)
                }
            }
        }
        .tint(Theme.spice)
        .onAppear {
            if link.isEmpty, !initialLink.isEmpty {
                link = initialLink
                startImport()
            }
        }
    }

    // MARK: - Input

    private var inputForm: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero

                VStack(alignment: .leading, spacing: 10) {
                    Text("Paste a link")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)

                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .foregroundStyle(Theme.spice)
                        TextField("https://www.tiktok.com/…", text: $link)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .submitLabel(.go)
                            .onSubmit(startImport)
                        if !link.isEmpty {
                            Button {
                                link = ""
                                errorMessage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.inkSoft.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(Theme.paperRaised, in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink.opacity(0.08), lineWidth: 1))

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.spice)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 20)

                Button(action: startImport) {
                    Label("Pull Recipe from Link", systemImage: "wand.and.stars")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Theme.warmGradient, in: .capsule)
                        .opacity(RecipeLinkImporter.looksLikeURL(link) ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(!RecipeLinkImporter.looksLikeURL(link))
                .padding(.horizontal, 20)

                howItWorks
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
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Save a recipe from a link")
                .font(.cookbookSerif(23, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text("Found a recipe on TikTok, Instagram, YouTube, or any recipe website? Paste the link and we'll read the page and turn it into an editable recipe.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 12)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How it works", systemImage: "lightbulb.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.spice)
            step("Copy a link from TikTok, Instagram, YouTube, or a recipe website, then paste it here.")
            step("We read the post or page and pull out the ingredients and steps.")
            step("Review the draft and tweak anything before saving it to your book.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func step(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Theme.sage).frame(width: 5, height: 5).padding(.top, 6)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: - Importing

    private var importing: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.spice)
            Text("Reading the post…")
                .font(.cookbookSerif(20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Fetching the caption and pulling out ingredients and steps.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Actions

    private func startImport() {
        guard RecipeLinkImporter.looksLikeURL(link) else {
            errorMessage = "That doesn't look like a valid link."
            return
        }
        errorMessage = nil
        phase = .importing
        let target = link
        Task {
            do {
                let draft = try await RecipeLinkImporter.importRecipe(from: target)
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    onImported(draft)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    errorMessage = (error as? RecipeLinkImporter.ImportError)?.errorDescription
                        ?? error.localizedDescription
                    phase = .input
                }
            }
        }
    }
}

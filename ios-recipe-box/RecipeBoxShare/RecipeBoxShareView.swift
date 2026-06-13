import SwiftUI
import UniformTypeIdentifiers

/// Captures a link shared from TikTok / Instagram / YouTube (or any app), stashes
/// it in the shared App Group, and tells the user to open RecipeBank to finish
/// turning the post into a recipe.
struct ShareView: View {
    let extensionContext: NSExtensionContext?

    @State private var phase: Phase = .loading
    @State private var capturedLink: String = ""

    private enum Phase: Equatable {
        case loading
        case saved
        case noLink
    }

    /// Must match the App Group on both the app and extension targets.
    private static let appGroup = "group.app.rork.ghaf572vbc9s69qm73bfp"
    private static let pendingKey = "pendingImportLink"

    private let paper = Color(red: 0.98, green: 0.96, blue: 0.92)
    private let spice = Color(red: 0.80, green: 0.33, blue: 0.16)
    private let ink = Color(red: 0.18, green: 0.14, blue: 0.10)

    var body: some View {
        ZStack {
            paper.ignoresSafeArea()
            VStack(spacing: 18) {
                switch phase {
                case .loading:
                    ProgressView().tint(spice)
                    Text("Reading the link…")
                        .font(.headline)
                        .foregroundStyle(ink)
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(spice)
                    Text("Saved to RecipeBank")
                        .font(.title3.bold())
                        .foregroundStyle(ink)
                    Text("Open RecipeBank to review this post and add it to your recipe book.")
                        .font(.subheadline)
                        .foregroundStyle(ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    Button("Done") { close() }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(spice, in: .capsule)
                        .padding(.top, 6)
                case .noLink:
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(spice)
                    Text("No link found")
                        .font(.title3.bold())
                        .foregroundStyle(ink)
                    Text("Share a recipe post from TikTok, Instagram, or YouTube using the Share → Copy Link option.")
                        .font(.subheadline)
                        .foregroundStyle(ink.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    Button("Close") { close() }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(spice, in: .capsule)
                        .padding(.top, 6)
                }
            }
            .padding()
        }
        .task { await loadSharedLink() }
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func loadSharedLink() async {
        let link = await extractLink()
        await MainActor.run {
            guard let link, !link.isEmpty else {
                phase = .noLink
                return
            }
            capturedLink = link
            if let defaults = UserDefaults(suiteName: Self.appGroup) {
                defaults.set(link, forKey: Self.pendingKey)
                defaults.set(Date().timeIntervalSince1970, forKey: "\(Self.pendingKey)At")
            }
            phase = .saved
        }
    }

    /// Pulls the first URL out of the shared items, checking explicit URL
    /// attachments first and then any text that contains a link.
    private func extractLink() async -> String? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) as? URL {
                        return url.absoluteString
                    }
                }
            }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) as? String,
                       let found = firstURL(in: text) {
                        return found
                    }
                }
            }
        }
        // Some apps put the link in the item's attributedContentText.
        for item in items {
            if let text = item.attributedContentText?.string, let found = firstURL(in: text) {
                return found
            }
        }
        return nil
    }

    private func firstURL(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let match = detector.firstMatch(in: text, options: [], range: range)
        return match?.url?.absoluteString
    }
}

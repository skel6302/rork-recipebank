//
//  RecipeLinkImporter.swift
//  RecipeBox
//

import Foundation

/// The post metadata returned by the `resolve-recipe-link` edge function.
nonisolated struct ResolvedPost: Codable, Sendable {
    let platform: String
    let title: String
    let author: String
    let caption: String
    let resolvedUrl: String
}

/// Pulls a recipe out of a shared social-video link (TikTok, Instagram,
/// YouTube, etc.). It first resolves the link server-side to get the post's
/// caption + title, then asks the AI parser to turn that text into a structured
/// recipe draft the user can review and save.
nonisolated enum RecipeLinkImporter {
    enum ImportError: LocalizedError {
        case invalidURL
        case couldNotResolve
        case noRecipeFound
        case underlying(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "That doesn't look like a valid link. Paste the full URL of the post."
            case .couldNotResolve:
                return "We couldn't read that post. It may be private, or the platform blocked us. Try copying the caption text and adding the recipe manually."
            case .noRecipeFound:
                return "We read the post but couldn't find a recipe in it. The caption may not include the ingredients and steps."
            case let .underlying(message):
                return message
            }
        }
    }

    /// Recognizable recipe-bearing video hosts. Other links are still attempted,
    /// but this powers quick client-side validation and friendly messaging.
    static func looksLikeURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: normalized), let host = url.host, host.contains(".") else {
            return false
        }
        return true
    }

    /// Full pipeline: resolve the link, then parse it into a recipe draft.
    static func importRecipe(from link: String) async throws -> ScannedRecipe {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard looksLikeURL(trimmed) else { throw ImportError.invalidURL }

        // 1. Ask the server resolver first (handles redirects, web pages, og: tags).
        var resolved: ResolvedPost? = try? await Supabase.invokeFunction(
            "resolve-recipe-link",
            body: ResolveRequestBody(url: trimmed)
        )
        if let server = resolved, server.caption.isEmpty, server.title.isEmpty {
            resolved = nil
        }

        // 2. On-device oEmbed fallback. TikTok/YouTube block the server's datacenter
        // IP (returning a generic page with no recipe text), but the phone's own
        // network can reach their oEmbed endpoint, which returns the full caption.
        if resolved == nil || (resolved?.caption.isEmpty ?? true) {
            if let oembed = await fetchOEmbed(for: trimmed) {
                resolved = oembed
            }
        }

        guard let post = resolved, !post.caption.isEmpty || !post.title.isEmpty else {
            throw ImportError.couldNotResolve
        }

        do {
            return try await AIRecipeParser.parse(
                postTitle: post.title,
                caption: post.caption,
                sourceURL: post.resolvedUrl
            )
        } catch AIRecipeParser.ParseError.empty {
            throw ImportError.noRecipeFound
        } catch {
            throw ImportError.underlying("Couldn't read the recipe right now. Please try again.")
        }
    }

    private nonisolated struct ResolveRequestBody: Encodable, Sendable {
        let url: String
    }

    // MARK: - On-device oEmbed fallback

    private nonisolated struct OEmbedResponse: Decodable, Sendable {
        let title: String?
        let authorName: String?

        enum CodingKeys: String, CodingKey {
            case title
            case authorName = "author_name"
        }
    }

    /// Fetches the post caption directly from the platform's public oEmbed endpoint.
    /// On TikTok/YouTube the oEmbed `title` field carries the full caption text —
    /// exactly the ingredients + steps we need. Short links resolve automatically.
    private static func fetchOEmbed(for link: String) async -> ResolvedPost? {
        let normalized = link.contains("://") ? link : "https://\(link)"
        guard let host = URL(string: normalized)?.host?.lowercased() else { return nil }

        let platform: String
        let endpoint: String
        if host.contains("tiktok") {
            platform = "tiktok"
            endpoint = "https://www.tiktok.com/oembed?url=\(escape(normalized))"
        } else if host.contains("youtube") || host.contains("youtu.be") {
            platform = "youtube"
            endpoint = "https://www.youtube.com/oembed?url=\(escape(normalized))&format=json"
        } else {
            return nil
        }

        guard let url = URL(string: endpoint) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
                forHTTPHeaderField: "User-Agent"
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(OEmbedResponse.self, from: data)
            let caption = decoded.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !caption.isEmpty else { return nil }
            return ResolvedPost(
                platform: platform,
                title: caption,
                author: decoded.authorName ?? "",
                caption: caption,
                resolvedUrl: normalized
            )
        } catch {
            return nil
        }
    }

    private static func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
    }
}

private extension CharacterSet {
    /// Characters safe inside a URL query *value* (stricter than `.urlQueryAllowed`,
    /// which leaves `&`, `=`, `?` unescaped and would corrupt the wrapped URL).
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}

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

        let post: ResolvedPost
        do {
            post = try await Supabase.invokeFunction(
                "resolve-recipe-link",
                body: ResolveRequestBody(url: trimmed)
            )
        } catch {
            throw ImportError.couldNotResolve
        }

        guard !post.caption.isEmpty || !post.title.isEmpty else {
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
}

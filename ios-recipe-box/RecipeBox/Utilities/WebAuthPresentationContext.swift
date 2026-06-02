//
//  WebAuthPresentationContext.swift
//  RecipeBox
//

import AuthenticationServices
import UIKit

/// Provides the key window as the presentation anchor for
/// `ASWebAuthenticationSession` (used by external OAuth flows such as Kroger).
class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

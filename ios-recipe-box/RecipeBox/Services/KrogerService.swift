//
//  KrogerService.swift
//  RecipeBox
//

import SwiftUI
import AuthenticationServices

// MARK: - Wire models

nonisolated struct KrogerTokenRequest: Encodable, Sendable {
    let grantType: String
    let code: String?
    let redirectUri: String?
    let refreshToken: String?
    let clientId: String
}

nonisolated struct KrogerTokenResult: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
}

nonisolated struct KrogerCartLineItem: Encodable, Sendable {
    let name: String
    let quantity: Int
}

nonisolated struct KrogerCartRequest: Encodable, Sendable {
    let accessToken: String
    let items: [KrogerCartLineItem]
    let clientId: String
}

nonisolated struct KrogerCartResult: Decodable, Sendable {
    let added: Int
    let total: Int
    let unmatched: [String]
}

/// The outcome of sending a list to the user's Kroger cart.
enum KrogerSendOutcome {
    case success(added: Int, total: Int, unmatched: [String])
    case needsSignIn
    case notConfigured
    case noMatches
    case failed(String)
}

/// Connects the shopping list to a customer's Kroger cart via the Kroger Cart API.
/// OAuth runs through `ASWebAuthenticationSession`; the client secret stays on the
/// backend, which also maps item names to UPCs before adding them to the cart.
@MainActor
@Observable
final class KrogerService {
    static let shared = KrogerService()

    var isConnected: Bool = KeychainHelper.get("kroger_refresh_token") != nil
    var isSending = false

    // Read from the generated config dictionary so this compiles whether or not
    // the Kroger env vars have been provisioned yet. Once they're added, the
    // values flow through automatically.
    private let clientId = Config.allValues["EXPO_PUBLIC_KROGER_CLIENT_ID"] ?? ""
    private let redirectURI = Config.allValues["EXPO_PUBLIC_KROGER_REDIRECT_URI"] ?? ""
    private var webAuthSession: ASWebAuthenticationSession?

    /// True only when the integration has the credentials it needs to run.
    var isAvailable: Bool {
        !clientId.isEmpty && !redirectURI.isEmpty
    }

    // MARK: - OAuth

    /// Launches Kroger sign-in and stores the resulting tokens. Returns true on success.
    func connect() async -> Bool {
        guard isAvailable else { return false }
        do {
            let code = try await authorize()
            try await exchange(code: code)
            isConnected = true
            return true
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return false
        } catch {
            print("Kroger connect failed: \(error)")
            return false
        }
    }

    func disconnect() {
        KeychainHelper.delete("kroger_access_token")
        KeychainHelper.delete("kroger_refresh_token")
        KeychainHelper.delete("kroger_token_expiry")
        isConnected = false
    }

    private func authorize() async throws -> String {
        guard let scheme = URL(string: redirectURI)?.scheme else {
            throw KrogerError.misconfigured
        }

        var components = URLComponents(string: "https://api.kroger.com/v1/connect/oauth2/authorize")
        components?.queryItems = [
            URLQueryItem(name: "scope", value: "cart.basic:write"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
        ]
        guard let url = components?.url else { throw KrogerError.misconfigured }

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] callbackURL, error in
                self?.webAuthSession = nil
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: KrogerError.noCode)
                    return
                }
                continuation.resume(returning: code)
            }
            self.webAuthSession = session
            session.presentationContextProvider = WebAuthPresentationContext.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func exchange(code: String) async throws {
        let result: KrogerTokenResult = try await Supabase.invokeFunction(
            "kroger-token",
            body: KrogerTokenRequest(
                grantType: "authorization_code",
                code: code,
                redirectUri: redirectURI,
                refreshToken: nil,
                clientId: clientId
            )
        )
        store(result)
    }

    /// Returns a valid access token, refreshing it if expired. Nil if not connected.
    private func validAccessToken() async -> String? {
        if let token = KeychainHelper.get("kroger_access_token"),
           let expiryString = KeychainHelper.get("kroger_token_expiry"),
           let expiry = TimeInterval(expiryString),
           Date().timeIntervalSince1970 < expiry - 60 {
            return token
        }

        guard let refresh = KeychainHelper.get("kroger_refresh_token") else { return nil }
        do {
            let result: KrogerTokenResult = try await Supabase.invokeFunction(
                "kroger-token",
                body: KrogerTokenRequest(
                    grantType: "refresh_token",
                    code: nil,
                    redirectUri: nil,
                    refreshToken: refresh,
                    clientId: clientId
                )
            )
            store(result)
            return result.accessToken
        } catch {
            print("Kroger token refresh failed: \(error)")
            return nil
        }
    }

    private func store(_ result: KrogerTokenResult) {
        KeychainHelper.set("kroger_access_token", value: result.accessToken)
        if let refresh = result.refreshToken {
            KeychainHelper.set("kroger_refresh_token", value: refresh)
        }
        let expiry = Date().timeIntervalSince1970 + Double(result.expiresIn)
        KeychainHelper.set("kroger_token_expiry", value: String(expiry))
    }

    // MARK: - Cart

    /// Sends the shopping list to the customer's Kroger cart, connecting first if needed.
    func sendToCart(_ items: [ShoppingItem]) async -> KrogerSendOutcome {
        guard isAvailable else { return .notConfigured }

        if !isConnected {
            let connected = await connect()
            guard connected else { return .needsSignIn }
        }

        guard let token = await validAccessToken() else {
            // Stored refresh token is no longer valid — ask the user to reconnect.
            disconnect()
            let connected = await connect()
            guard connected, let fresh = await validAccessToken() else { return .needsSignIn }
            return await pushCart(items, token: fresh)
        }

        return await pushCart(items, token: token)
    }

    private func pushCart(_ items: [ShoppingItem], token: String) async -> KrogerSendOutcome {
        let lineItems = items
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { KrogerCartLineItem(name: $0.name, quantity: Self.leadingQuantity($0.quantity)) }
        guard !lineItems.isEmpty else { return .noMatches }

        isSending = true
        defer { isSending = false }

        do {
            let result: KrogerCartResult = try await Supabase.invokeFunction(
                "kroger-cart",
                body: KrogerCartRequest(accessToken: token, items: lineItems, clientId: clientId)
            )
            return .success(added: result.added, total: result.total, unmatched: result.unmatched)
        } catch {
            let description = "\(error)"
            if description.contains("kroger_unauthorized") {
                disconnect()
                return .needsSignIn
            }
            if description.contains("no_matches") { return .noMatches }
            if description.contains("not_configured") { return .notConfigured }
            print("Kroger cart send failed: \(error)")
            return .failed("We couldn't reach Kroger. Please try again.")
        }
    }

    /// Pulls a leading integer quantity out of a free-text amount like "2 cups". Defaults to 1.
    private static func leadingQuantity(_ text: String) -> Int {
        let digits = text.prefix { $0.isNumber }
        if let value = Int(digits), value > 0 { return min(value, 24) }
        return 1
    }
}

private enum KrogerError: Error {
    case misconfigured
    case noCode
}

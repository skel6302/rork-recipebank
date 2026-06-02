//
//  AuthManager.swift
//  RecipeBox
//

import SwiftUI

/// Handles email/password authentication via Supabase Auth (GoTrue) and token
/// storage. The issued access token is stored in the Keychain and forwarded by
/// `Supabase` as the bearer token, so PostgREST Row Level Security sees the
/// signed-in user.
@Observable
class AuthManager {
    var user: User?
    var isLoading = true
    var isSigningIn = false
    var showError = false
    var errorMessage = ""
    /// Set after a successful sign-up that still needs email confirmation.
    var infoMessage: String?
    /// True when the user chose to use the app without an account.
    var isGuest = UserDefaults.standard.bool(forKey: "RORK_GUEST_MODE")

    /// Whether the app should show the main UI (signed in or browsing as guest).
    var hasAccess: Bool { user != nil || isGuest }

    private let supabaseURL = Config.EXPO_PUBLIC_SUPABASE_URL
    private let anonKey = Config.EXPO_PUBLIC_SUPABASE_ANON_KEY

    private var authBase: String { "\(supabaseURL)/auth/v1" }

    struct User: Codable {
        let id: String
        let email: String
        let name: String?
        let picture: String?
    }

    init() {
        Task { await checkAuth() }
    }

    // MARK: - Token decoding

    /// Decode the JWT payload to extract user info and check expiration.
    private func userFromToken(_ token: String) -> User? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }

        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let data = Data(base64Encoded: base64) else { return nil }

        struct Metadata: Codable {
            let name: String?
            let full_name: String?
            let avatar_url: String?
        }
        struct JWTPayload: Codable {
            let sub: String
            let email: String?
            let exp: TimeInterval?
            let user_metadata: Metadata?
        }

        guard let payload = try? JSONDecoder().decode(JWTPayload.self, from: data) else { return nil }

        if let exp = payload.exp, Date(timeIntervalSince1970: exp) < Date() {
            return nil
        }

        let name = payload.user_metadata?.name ?? payload.user_metadata?.full_name
        return User(
            id: payload.sub,
            email: payload.email ?? "",
            name: name,
            picture: payload.user_metadata?.avatar_url
        )
    }

    // MARK: - Session lifecycle

    @MainActor
    func checkAuth() async {
        defer { isLoading = false }

        if let accessToken = KeychainHelper.get("access_token"),
           let user = userFromToken(accessToken) {
            self.user = user
            return
        }

        if KeychainHelper.get("refresh_token") != nil {
            await refreshToken()
        }
    }

    /// Enter the app without an account. Recipes stay on this device until you sign in.
    @MainActor
    func continueAsGuest() {
        isGuest = true
        UserDefaults.standard.set(true, forKey: "RORK_GUEST_MODE")
    }

    // MARK: - Email / password

    @MainActor
    func register(name: String, email: String, password: String) async {
        isSigningIn = true
        defer { isSigningIn = false }
        infoMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValid(email: trimmedEmail) else {
            setError("Please enter a valid email address.")
            return
        }
        guard password.count >= 6 else {
            setError("Password must be at least 6 characters.")
            return
        }

        guard let url = URL(string: "\(authBase)/signup") else {
            setError("Invalid configuration.")
            return
        }

        let body: [String: Any] = [
            "email": trimmedEmail,
            "password": password,
            "data": ["name": trimmedName],
        ]

        do {
            let data = try await postJSON(url: url, body: body)
            // A confirmed-immediately project returns a full session; a project
            // requiring email confirmation returns just the user with no token.
            if let session = try? JSONDecoder().decode(SessionResponse.self, from: data),
               let accessToken = session.access_token {
                storeSession(access: accessToken, refresh: session.refresh_token)
                finishSignIn(token: accessToken)
            } else {
                infoMessage = "Account created. Please check your email to confirm your address, then sign in."
            }
        } catch let AuthError.server(message) {
            setError(message)
        } catch {
            setError("Couldn't create your account. Please try again.")
        }
    }

    @MainActor
    func signIn(email: String, password: String) async {
        isSigningIn = true
        defer { isSigningIn = false }
        infoMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValid(email: trimmedEmail), !password.isEmpty else {
            setError("Please enter your email and password.")
            return
        }

        guard let url = URL(string: "\(authBase)/token?grant_type=password") else {
            setError("Invalid configuration.")
            return
        }

        do {
            let data = try await postJSON(url: url, body: [
                "email": trimmedEmail,
                "password": password,
            ])
            let session = try JSONDecoder().decode(SessionResponse.self, from: data)
            guard let accessToken = session.access_token else {
                setError("Sign in failed. Please try again.")
                return
            }
            storeSession(access: accessToken, refresh: session.refresh_token)
            finishSignIn(token: accessToken)
        } catch let AuthError.server(message) {
            setError(message)
        } catch {
            setError("Couldn't sign you in. Please check your details and try again.")
        }
    }

    @MainActor
    private func refreshToken() async {
        guard let storedRefreshToken = KeychainHelper.get("refresh_token"),
              let url = URL(string: "\(authBase)/token?grant_type=refresh_token") else {
            user = nil
            return
        }

        do {
            let data = try await postJSON(url: url, body: ["refresh_token": storedRefreshToken])
            let session = try JSONDecoder().decode(SessionResponse.self, from: data)
            guard let accessToken = session.access_token else {
                await signOut()
                return
            }
            storeSession(access: accessToken, refresh: session.refresh_token)
            user = userFromToken(accessToken)
        } catch {
            await signOut()
        }
    }

    @MainActor
    func signOut() async {
        KeychainHelper.delete("access_token")
        KeychainHelper.delete("refresh_token")
        isGuest = false
        UserDefaults.standard.set(false, forKey: "RORK_GUEST_MODE")
        user = nil
    }

    // MARK: - Helpers

    @MainActor
    private func finishSignIn(token: String) {
        isGuest = false
        UserDefaults.standard.set(false, forKey: "RORK_GUEST_MODE")
        user = userFromToken(token)
    }

    private func storeSession(access: String, refresh: String?) {
        KeychainHelper.set("access_token", value: access)
        if let refresh {
            KeychainHelper.set("refresh_token", value: refresh)
        }
    }

    /// POSTs a JSON body to a GoTrue endpoint, returning the response data or
    /// throwing `AuthError.server` with a user-friendly message on failure.
    private func postJSON(url: URL, body: [String: Any]) async throws -> Data {
        guard !supabaseURL.isEmpty, !anonKey.isEmpty else {
            throw AuthError.server("This build is missing its configuration. Please install the latest build.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.server("No response from server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthError.server(parseError(data))
        }
        return data
    }

    /// Pulls a readable message out of a GoTrue error response.
    private func parseError(_ data: Data) -> String {
        struct GoTrueError: Codable {
            let error_description: String?
            let msg: String?
            let message: String?
            let error: String?
        }
        if let decoded = try? JSONDecoder().decode(GoTrueError.self, from: data) {
            return decoded.error_description ?? decoded.msg ?? decoded.message ?? decoded.error ?? "Something went wrong."
        }
        return "Something went wrong. Please try again."
    }

    private func isValid(email: String) -> Bool {
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Response Types

private struct SessionResponse: Codable {
    let access_token: String?
    let refresh_token: String?
}

enum AuthError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        }
    }
}

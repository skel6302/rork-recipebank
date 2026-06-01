//
//  WelcomeView.swift
//  RecipeBox
//

import SwiftUI
import AuthenticationServices

/// Sign-in screen shown when no user is authenticated. Matches the warm
/// cookbook aesthetic and offers Apple / Google sign-in.
struct WelcomeView: View {
    @Environment(AuthManager.self) private var auth

    var body: some View {
        @Bindable var auth = auth

        ZStack {
            backdrop

            VStack(spacing: 0) {
                Spacer()

                Image("BrandMark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 260, maxHeight: 70)
                    .padding(.bottom, 18)

                Text("Your recipes, on every device.")
                    .font(.cookbookSerif(19, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                featureList
                    .padding(.top, 30)

                Spacer()

                signInButtons
                    .padding(.horizontal, 28)

                Text("Sign in to back up and sync your recipes securely.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .padding(.horizontal, 40)
            }
        }
        .alert("Sign-in Error", isPresented: $auth.showError) {
            Button("OK") { }
        } message: {
            Text(auth.errorMessage)
        }
    }

    private var backdrop: some View {
        LinearGradient(
            colors: [Theme.cream, Theme.paper],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            Theme.warmGradient
                .frame(height: 220)
                .opacity(0.10)
                .blur(radius: 40)
                .ignoresSafeArea()
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 16) {
            featureRow(symbol: "icloud.fill", text: "Automatic cloud backup")
            featureRow(symbol: "iphone.and.arrow.forward", text: "Sync across all your devices")
            featureRow(symbol: "lock.fill", text: "Private to your account")
        }
        .padding(.horizontal, 50)
    }

    private func featureRow(symbol: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Theme.warmGradient, in: .circle)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Spacer()
        }
    }

    private var signInButtons: some View {
        VStack(spacing: 12) {
            if auth.isSigningIn {
                ProgressView()
                    .padding(.bottom, 4)
            }

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email, .fullName]
            } onCompletion: { _ in
                Task { await auth.signIn(provider: "apple") }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(.rect(cornerRadius: 14))
            .disabled(auth.isSigningIn)

            Button {
                Task { await auth.signIn(provider: "google") }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Sign in with Google")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(.white, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(auth.isSigningIn)
        }
    }
}

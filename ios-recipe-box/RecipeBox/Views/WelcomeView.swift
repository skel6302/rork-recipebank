//
//  WelcomeView.swift
//  RecipeBox
//

import SwiftUI

/// Sign-in / registration screen shown when no user is authenticated. Matches
/// the warm cookbook aesthetic and uses email + password accounts.
struct WelcomeView: View {
    @Environment(AuthManager.self) private var auth

    private enum Mode {
        case signIn
        case register
    }

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, email, password
    }

    var body: some View {
        @Bindable var auth = auth

        ZStack {
            backdrop

            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 40)

                    formCard
                        .padding(.horizontal, 24)
                        .padding(.top, 28)

                    Button {
                        focusedField = nil
                        auth.continueAsGuest()
                    } label: {
                        Text("Continue without an account")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 18)

                    Text("Create an account to back up and sync across devices, or continue and add an account later.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSoft.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.bottom, 32)
                        .padding(.horizontal, 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .alert("Something went wrong", isPresented: $auth.showError) {
            Button("OK") { }
        } message: {
            Text(auth.errorMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            Image("BrandMark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 240, maxHeight: 64)

            Text(mode == .signIn ? "Welcome back." : "Create your account.")
                .font(.cookbookSerif(20, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text(mode == .signIn
                 ? "Sign in to sync your recipes everywhere."
                 : "Your recipes, backed up and on every device.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(spacing: 16) {
            segmentedControl

            if let info = auth.infoMessage {
                Text(info)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Theme.spice.opacity(0.10), in: .rect(cornerRadius: 12))
            }

            if mode == .register {
                field(
                    icon: "person.fill",
                    placeholder: "Name",
                    text: $name,
                    field: .name,
                    submit: .name
                )
                .textContentType(.name)
                .submitLabel(.next)
            }

            field(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                field: .email,
                submit: .email
            )
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.next)

            secureField

            primaryButton

            switchModeButton
        }
        .padding(20)
        .background(Theme.cream, in: .rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Theme.ink.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Theme.ink.opacity(0.06), radius: 18, y: 8)
    }

    private var segmentedControl: some View {
        HStack(spacing: 6) {
            modeTab(title: "Sign In", value: .signIn)
            modeTab(title: "Register", value: .register)
        }
        .padding(4)
        .background(Theme.paper, in: .capsule)
    }

    private func modeTab(title: String, value: Mode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = value
                auth.infoMessage = nil
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(mode == value ? .white : Theme.inkSoft)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background {
                    if mode == value {
                        Capsule().fill(Theme.warmGradient)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func field(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        submit: Field
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.spice)
                .frame(width: 22)
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink)
                .focused($focusedField, equals: field)
                .onSubmit { advanceFocus(from: submit) }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Theme.paper, in: .rect(cornerRadius: 14))
    }

    private var secureField: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.spice)
                .frame(width: 22)
            SecureField(mode == .register ? "Password (min. 6 characters)" : "Password", text: $password)
                .font(.system(size: 16))
                .foregroundStyle(Theme.ink)
                .textContentType(mode == .register ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Theme.paper, in: .rect(cornerRadius: 14))
    }

    private var primaryButton: some View {
        Button {
            submit()
        } label: {
            ZStack {
                if auth.isSigningIn {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(mode == .signIn ? "Sign In" : "Create Account")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.warmGradient, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(auth.isSigningIn)
        .opacity(auth.isSigningIn ? 0.7 : 1)
        .padding(.top, 4)
    }

    private var switchModeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                mode = mode == .signIn ? .register : .signIn
                auth.infoMessage = nil
            }
        } label: {
            Text(mode == .signIn
                 ? "New here? Create an account"
                 : "Already have an account? Sign in")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.spice)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func advanceFocus(from field: Field) {
        switch field {
        case .name: focusedField = .email
        case .email: focusedField = .password
        case .password: submit()
        }
    }

    private func submit() {
        focusedField = nil
        Task {
            switch mode {
            case .signIn:
                await auth.signIn(email: email, password: password)
            case .register:
                await auth.register(name: name, email: email, password: password)
            }
        }
    }

    // MARK: - Backdrop

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
}

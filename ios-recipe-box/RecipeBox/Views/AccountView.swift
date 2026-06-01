//
//  AccountView.swift
//  RecipeBox
//

import SwiftUI

/// Account sheet showing the signed-in user, sync status, and sign-out.
struct AccountView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(RecipeSyncService.self) private var sync
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    profileCard
                    syncCard
                    signOutButton
                }
                .padding(20)
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .tint(Theme.spice)
                }
            }
        }
        .tint(Theme.spice)
    }

    private var profileCard: some View {
        VStack(spacing: 14) {
            avatar

            if let user = auth.user {
                if let name = user.name, !name.isEmpty {
                    Text(name)
                        .font(.cookbookSerif(22, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                Text(user.email)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private var avatar: some View {
        Group {
            if let picture = auth.user?.picture, let url = URL(string: picture) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    initialsCircle
                }
            } else {
                initialsCircle
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(.circle)
        .overlay(Circle().stroke(Theme.amber.opacity(0.35), lineWidth: 2))
    }

    private var initialsCircle: some View {
        Theme.warmGradient
            .overlay {
                Text(initials)
                    .font(.cookbookSerif(30, weight: .bold))
                    .foregroundStyle(.white)
            }
    }

    private var initials: String {
        let source = auth.user?.name?.isEmpty == false ? auth.user?.name : auth.user?.email
        guard let source, let first = source.first else { return "?" }
        return String(first).uppercased()
    }

    private var syncCard: some View {
        HStack(spacing: 14) {
            Image(systemName: syncSymbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Theme.sage, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(syncTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(syncSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Button {
                Task { await sync.syncNow() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.spice)
            }
            .disabled(sync.state == .syncing)
        }
        .padding(16)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private var syncSymbol: String {
        switch sync.state {
        case .syncing: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.icloud.fill"
        default: return "checkmark.icloud.fill"
        }
    }

    private var syncTitle: String {
        switch sync.state {
        case .syncing: return "Syncing…"
        case .error: return "Sync issue"
        default: return "Recipes backed up"
        }
    }

    private var syncSubtitle: String {
        switch sync.state {
        case .syncing: return "Saving your recipes to the cloud"
        case .error: return "We'll retry automatically"
        default:
            if let date = sync.lastSyncedAt {
                return "Last synced \(date.formatted(date: .omitted, time: .shortened))"
            }
            return "Your recipes sync across devices"
        }
    }

    private var signOutButton: some View {
        Button(role: .destructive) {
            Task {
                await auth.signOut()
                dismiss()
            }
        } label: {
            Text("Sign Out")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.red.opacity(0.10), in: .capsule)
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
    }
}

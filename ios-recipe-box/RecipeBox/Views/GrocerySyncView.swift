//
//  GrocerySyncView.swift
//  RecipeBox
//

import SwiftUI
import UIKit

/// Lets the user send their shopping list to a grocery delivery / pickup service.
struct GrocerySyncView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let items: [ShoppingItem]

    @State private var selectedProvider: GroceryProvider? = nil
    @State private var showingShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    summaryCard

                    VStack(alignment: .leading, spacing: 10) {
                        Text("CHOOSE A SERVICE")
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(0.8)
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.leading, 4)

                        ForEach(GroceryProvider.allCases) { provider in
                            providerRow(provider)
                        }
                    }

                    copyExportRow
                }
                .padding(16)
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Send to Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.spice)
                }
            }
            .safeAreaInset(edge: .bottom) {
                sendButton
            }
            .sheet(isPresented: $showingShare) {
                ShareSheet(text: GroceryService.plainText(for: items))
            }
        }
        .tint(Theme.spice)
    }

    private var summaryCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "cart.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Theme.warmGradient, in: .circle)
            Text("\(items.count) items ready")
                .font(.cookbookSerif(20, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Send your list to a grocery service for delivery or pickup. We'll open the store with your items prepared to search.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.paperRaised, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
    }

    private func providerRow(_ provider: GroceryProvider) -> some View {
        Button {
            withAnimation(.snappy) { selectedProvider = provider }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: provider.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(provider.tint, in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(provider.tagline)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: selectedProvider == provider ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selectedProvider == provider ? provider.tint : Theme.inkSoft.opacity(0.3))
            }
            .padding(14)
            .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedProvider == provider ? provider.tint : Theme.ink.opacity(0.06),
                            lineWidth: selectedProvider == provider ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var copyExportRow: some View {
        HStack(spacing: 12) {
            actionTile(title: "Copy List", symbol: "doc.on.doc.fill") {
                UIPasteboard.general.string = GroceryService.plainText(for: items)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            actionTile(title: "Share", symbol: "square.and.arrow.up.fill") {
                showingShare = true
            }
        }
    }

    private func actionTile(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.spice)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.paperRaised, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.ink.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var sendButton: some View {
        Button {
            sendToProvider()
        } label: {
            HStack(spacing: 10) {
                if let provider = selectedProvider {
                    Image(systemName: provider.symbol)
                    Text(provider.isListSync ? "Add to \(provider.rawValue)" : "Open \(provider.rawValue)")
                } else {
                    Text("Select a service")
                }
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                selectedProvider == nil
                    ? AnyShapeStyle(Theme.inkSoft.opacity(0.4))
                    : AnyShapeStyle(selectedProvider!.tint),
                in: .capsule
            )
            .shadow(color: (selectedProvider?.tint ?? .clear).opacity(0.35), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(selectedProvider == nil)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func sendToProvider() {
        guard let provider = selectedProvider else { return }
        // Copy the list so users can paste any items the destination can't pre-fill.
        UIPasteboard.general.string = provider.isListSync
            ? GroceryService.listLines(for: items)
            : GroceryService.plainText(for: items)

        // For list destinations (Alexa), prefer the native app, fall back to the web list.
        if let appURL = provider.appURL {
            openURL(appURL) { accepted in
                if !accepted, let web = provider.url(for: items) {
                    openURL(web)
                }
            }
            return
        }

        if let url = provider.url(for: items) {
            openURL(url)
        }
    }
}

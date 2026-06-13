//
//  SharedImportInbox.swift
//  RecipeBox
//

import Foundation

/// Bridges links handed in by the Share Extension. The extension writes the
/// shared URL into the App Group's shared `UserDefaults`; the main app reads and
/// clears it when it next becomes active, then kicks off the import flow.
nonisolated enum SharedImportInbox {
    /// Must match the App Group configured on both the app and extension targets.
    private static let appGroup = "group.app.rork.ghaf572vbc9s69qm73bfp"
    private static let pendingKey = "pendingImportLink"

    /// Returns and clears any link waiting from the share sheet.
    static func takePendingLink() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return nil }
        guard let link = defaults.string(forKey: pendingKey), !link.isEmpty else { return nil }
        defaults.removeObject(forKey: pendingKey)
        defaults.removeObject(forKey: "\(pendingKey)At")
        return link
    }
}

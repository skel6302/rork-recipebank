//
//  HealthManager.swift
//  RecipeBox
//

import Foundation

/// Surfaces Apple Watch / Health activity data (steps, active calories, exercise
/// minutes, sleep) for a given day.
///
/// HealthKit is a *restricted* Apple capability: it can only be linked and signed
/// with a provisioning profile that Apple has explicitly enabled for HealthKit.
/// Rork installs to your device with ad-hoc (free) signing, which cannot carry
/// that entitlement, so linking the HealthKit framework makes the install step
/// fail deterministically. To keep on-device installs working, this manager
/// exposes the same API but reports Health data as unavailable. When the app is
/// shipped through TestFlight / the App Store (where HealthKit can be properly
/// provisioned), the live HealthKit reads can be restored.
@Observable
@MainActor
final class HealthManager {
    /// Today's (or selected day's) step count.
    var steps: Int = 0
    /// Active energy burned, in kilocalories.
    var activeCalories: Int = 0
    /// Apple exercise minutes.
    var exerciseMinutes: Int = 0
    /// Sleep duration in hours for the night ending on the selected day.
    var sleepHours: Double = 0

    /// True once the user has granted (or been prompted for) Health access.
    var isAuthorized: Bool = false
    /// Whether Health data is available on this device at all.
    let isAvailable: Bool = false

    /// Requests read access, then loads today's data. No-op while HealthKit is
    /// not provisioned for this build.
    func requestAuthorization() async {}

    /// Refreshes all metrics for the given day. No-op while HealthKit is not
    /// provisioned for this build.
    func refresh(for date: Date) async {}
}

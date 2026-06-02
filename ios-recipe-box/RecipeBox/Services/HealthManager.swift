//
//  HealthManager.swift
//  RecipeBox
//

import Foundation
import HealthKit

/// Surfaces Apple Watch / Health activity data (steps, active calories, exercise
/// minutes, sleep) for a given day by reading from HealthKit.
///
/// Data such as steps, active energy, exercise minutes and sleep is recorded by
/// Apple Watch and synced into the iPhone's Health database, which this manager
/// reads. HealthKit requires the `com.apple.developer.healthkit` entitlement and
/// is only available on real devices (TestFlight / App Store builds), not in the
/// simulator. On unsupported builds every read is a graceful no-op.
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
    let isAvailable: Bool = HKHealthStore.isHealthDataAvailable()

    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let active = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(active)
        }
        if let exercise = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exercise)
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }

    /// Requests read access, then loads today's data.
    func requestAuthorization() async {
        guard isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await refresh(for: .now)
        } catch {
            print("HealthKit authorization failed: \(error.localizedDescription)")
        }
    }

    /// Refreshes all metrics for the given day.
    func refresh(for date: Date) async {
        guard isAvailable else { return }
        async let stepCount = sum(.stepCount, unit: .count(), on: date)
        async let calories = sum(.activeEnergyBurned, unit: .kilocalorie(), on: date)
        async let exercise = sum(.appleExerciseTime, unit: .minute(), on: date)
        async let sleep = sleepHours(forNightEnding: date)

        let (s, c, e, sl) = await (stepCount, calories, exercise, sleep)
        steps = Int(s.rounded())
        activeCalories = Int(c.rounded())
        exerciseMinutes = Int(e.rounded())
        sleepHours = sl
    }

    // MARK: - Quantity sums

    private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, on date: Date) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    // MARK: - Sleep

    /// Total asleep hours for the night that ends on the morning of `date`.
    private func sleepHours(forNightEnding date: Date) async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        // Window: from 6pm the previous evening to noon on the selected day.
        guard
            let windowStart = calendar.date(byAdding: .hour, value: -6, to: dayStart),
            let windowEnd = calendar.date(byAdding: .hour, value: 12, to: dayStart)
        else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                let seconds = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: seconds / 3600.0)
            }
            store.execute(query)
        }
    }
}

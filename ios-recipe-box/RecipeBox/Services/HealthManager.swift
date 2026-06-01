//
//  HealthManager.swift
//  RecipeBox
//

import Foundation
import HealthKit

/// Reads Apple Watch / Health activity data (steps, active calories, exercise
/// minutes, sleep) for a given day. Degrades gracefully when HealthKit is
/// unavailable (e.g. in the simulator) or permission hasn't been granted.
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
        var types = Set<HKObjectType>()
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(energy) }
        if let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) { types.insert(exercise) }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
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
            isAuthorized = false
        }
    }

    /// Refreshes all metrics for the given day.
    func refresh(for date: Date) async {
        guard isAvailable else { return }
        async let s = sumQuantity(.stepCount, unit: .count(), date: date)
        async let c = sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), date: date)
        async let e = sumQuantity(.appleExerciseTime, unit: .minute(), date: date)
        async let sleep = fetchSleepHours(for: date)
        let (steps, cals, ex, sl) = await (s, c, e, sleep)
        self.steps = Int(steps.rounded())
        self.activeCalories = Int(cals.rounded())
        self.exerciseMinutes = Int(ex.rounded())
        self.sleepHours = sl
    }

    // MARK: - Queries

    private func sumQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, date: Date) async -> Double {
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
            ) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Total asleep time (in hours) for the night ending on the given day.
    private func fetchSleepHours(for date: Date) async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        // Sleep window: 6pm the previous evening through noon of the selected day.
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
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                ]
                let total = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: total / 3600.0)
            }
            store.execute(query)
        }
    }
}

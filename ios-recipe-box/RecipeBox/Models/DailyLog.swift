//
//  DailyLog.swift
//  RecipeBox
//

import Foundation
import SwiftData

/// Per-day tracking state: whether the user has "closed out" the day (Done Logging)
/// and how many 8oz glasses of water they drank. One record per calendar day.
@Model
final class DailyLog {
    /// Start-of-day timestamp, used as the unique day key.
    @Attribute(.unique) var day: Date

    /// True once the user taps "Done Logging" for the day. Closed days are locked
    /// from further edits and count toward the tracking streak.
    var isClosed: Bool

    /// Number of 8oz glasses of water logged for the day.
    var waterGlasses: Int

    init(day: Date, isClosed: Bool = false, waterGlasses: Int = 0) {
        self.day = Calendar.current.startOfDay(for: day)
        self.isClosed = isClosed
        self.waterGlasses = waterGlasses
    }
}

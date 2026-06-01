//
//  WeightEntry.swift
//  RecipeBox
//

import Foundation
import SwiftData

/// A single body-weight measurement (in pounds) logged on a given day.
@Model
final class WeightEntry {
    var loggedAt: Date
    var weightLbs: Double

    init(loggedAt: Date = .now, weightLbs: Double) {
        self.loggedAt = loggedAt
        self.weightLbs = weightLbs
    }
}

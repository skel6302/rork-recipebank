//
//  DoseLog.swift
//  RecipeBox
//

import Foundation
import SwiftData

/// A single recorded dose of a medication, with date/time, amount, and (for
/// injections) the body site used so users can rotate sites.
@Model
final class DoseLog {
    var takenAt: Date
    var doseMg: Double
    var siteRaw: String?
    var notes: String

    /// The medication this dose belongs to.
    @Relationship var medication: Medication?

    init(
        takenAt: Date = .now,
        doseMg: Double,
        site: InjectionSite? = nil,
        notes: String = "",
        medication: Medication? = nil
    ) {
        self.takenAt = takenAt
        self.doseMg = doseMg
        self.siteRaw = site?.rawValue
        self.notes = notes
        self.medication = medication
    }

    var site: InjectionSite? {
        get { siteRaw.flatMap { InjectionSite(rawValue: $0) } }
        set { siteRaw = newValue?.rawValue }
    }

    var doseLabel: String {
        let trimmed = doseMg.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", doseMg)
            : String(format: "%.2g", doseMg)
        return "\(trimmed) mg"
    }
}

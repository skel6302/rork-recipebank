//
//  Medication.swift
//  RecipeBox
//

import Foundation
import SwiftData
import SwiftUI

/// The delivery form of a GLP-1 medication.
enum MedForm: String, Codable, CaseIterable, Identifiable {
    case injection = "Injection"
    case oralPill = "Pill"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .injection: return "syringe.fill"
        case .oralPill: return "pills.fill"
        }
    }

    var actionVerb: String {
        switch self {
        case .injection: return "Inject"
        case .oralPill: return "Take"
        }
    }
}

/// How often a medication is taken.
enum MedSchedule: String, Codable, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case daily = "Daily"

    var id: String { rawValue }

    var cadenceDays: Int { self == .weekly ? 7 : 1 }
}

/// A rotating injection site, so users avoid reusing the same spot.
enum InjectionSite: String, Codable, CaseIterable, Identifiable {
    case leftAbdomen = "Left Abdomen"
    case rightAbdomen = "Right Abdomen"
    case leftThigh = "Left Thigh"
    case rightThigh = "Right Thigh"
    case leftArm = "Left Upper Arm"
    case rightArm = "Right Upper Arm"

    var id: String { rawValue }

    var short: String {
        switch self {
        case .leftAbdomen: return "L. Abdomen"
        case .rightAbdomen: return "R. Abdomen"
        case .leftThigh: return "L. Thigh"
        case .rightThigh: return "R. Thigh"
        case .leftArm: return "L. Arm"
        case .rightArm: return "R. Arm"
        }
    }

    /// The next site in a sensible rotation order.
    var next: InjectionSite {
        let all = InjectionSite.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }
}

/// A GLP-1 (or related) medication the user is taking, with its dose and schedule.
@Model
final class Medication {
    /// Stable identifier used for scheduling/cancelling local notifications.
    var reminderID: String = UUID().uuidString
    var name: String
    var formRaw: String
    var scheduleRaw: String

    /// Current dose in milligrams (e.g. 0.5, 2.4).
    var doseMg: Double

    /// For weekly meds: the weekday the dose is due (1 = Sunday ... 7 = Saturday).
    var doseWeekday: Int

    /// Reminder time of day, stored as minutes since midnight.
    var reminderMinutes: Int

    /// Whether to schedule a local notification reminder.
    var remindersEnabled: Bool

    /// Last injection site used, for rotation suggestions (nil for pills).
    var lastSiteRaw: String?

    var startedAt: Date
    var isActive: Bool
    var notes: String

    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medication)
    var doses: [DoseLog] = []

    init(
        name: String,
        form: MedForm = .injection,
        schedule: MedSchedule = .weekly,
        doseMg: Double = 0.25,
        doseWeekday: Int = 1,
        reminderMinutes: Int = 9 * 60,
        remindersEnabled: Bool = true,
        lastSite: InjectionSite? = nil,
        startedAt: Date = .now,
        isActive: Bool = true,
        notes: String = ""
    ) {
        self.name = name
        self.formRaw = form.rawValue
        self.scheduleRaw = schedule.rawValue
        self.doseMg = doseMg
        self.doseWeekday = doseWeekday
        self.reminderMinutes = reminderMinutes
        self.remindersEnabled = remindersEnabled
        self.lastSiteRaw = lastSite?.rawValue
        self.startedAt = startedAt
        self.isActive = isActive
        self.notes = notes
    }

    var form: MedForm {
        get { MedForm(rawValue: formRaw) ?? .injection }
        set { formRaw = newValue.rawValue }
    }

    var schedule: MedSchedule {
        get { MedSchedule(rawValue: scheduleRaw) ?? .weekly }
        set { scheduleRaw = newValue.rawValue }
    }

    var lastSite: InjectionSite? {
        get { lastSiteRaw.flatMap { InjectionSite(rawValue: $0) } }
        set { lastSiteRaw = newValue?.rawValue }
    }

    /// The site to suggest for the next injection (rotated from the last one).
    var suggestedSite: InjectionSite {
        (lastSite ?? .rightArm).next
    }

    var doseLabel: String {
        let trimmed = doseMg.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", doseMg)
            : String(format: "%.2g", doseMg)
        return "\(trimmed) mg"
    }

    /// The most recent recorded dose, if any.
    var lastDose: DoseLog? {
        doses.max(by: { $0.takenAt < $1.takenAt })
    }

    /// The next time a dose is due, based on the last dose (or start date) and schedule.
    var nextDueDate: Date {
        let cal = Calendar.current
        let anchor = lastDose?.takenAt ?? startedAt
        if schedule == .daily {
            // Next reminder time today or tomorrow.
            let base = cal.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now
            return base > .now ? base : (cal.date(byAdding: .day, value: 1, to: base) ?? base)
        }
        // Weekly: 7 days from the anchor, then align to the chosen weekday/time.
        let due = cal.date(byAdding: .day, value: 7, to: anchor) ?? anchor
        var comps = cal.dateComponents([.year, .month, .day], from: due)
        comps.hour = reminderMinutes / 60
        comps.minute = reminderMinutes % 60
        return cal.date(from: comps) ?? due
    }

    var tint: Color {
        form == .injection ? Theme.spice : Theme.sage
    }
}

/// Common GLP-1 medications offered as quick presets in the editor.
struct GLP1Preset: Identifiable {
    let name: String
    let form: MedForm
    let schedule: MedSchedule
    let commonDoses: [Double]
    var id: String { name }

    static let all: [GLP1Preset] = [
        GLP1Preset(name: "Ozempic", form: .injection, schedule: .weekly, commonDoses: [0.25, 0.5, 1.0, 2.0]),
        GLP1Preset(name: "Wegovy", form: .injection, schedule: .weekly, commonDoses: [0.25, 0.5, 1.0, 1.7, 2.4]),
        GLP1Preset(name: "Mounjaro", form: .injection, schedule: .weekly, commonDoses: [2.5, 5, 7.5, 10, 12.5, 15]),
        GLP1Preset(name: "Zepbound", form: .injection, schedule: .weekly, commonDoses: [2.5, 5, 7.5, 10, 12.5, 15]),
        GLP1Preset(name: "Trulicity", form: .injection, schedule: .weekly, commonDoses: [0.75, 1.5, 3.0, 4.5]),
        GLP1Preset(name: "Saxenda", form: .injection, schedule: .daily, commonDoses: [0.6, 1.2, 1.8, 2.4, 3.0]),
        GLP1Preset(name: "Rybelsus", form: .oralPill, schedule: .daily, commonDoses: [3, 7, 14]),
    ]
}

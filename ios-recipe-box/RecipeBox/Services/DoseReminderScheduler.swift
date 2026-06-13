//
//  DoseReminderScheduler.swift
//  RecipeBox
//

import Foundation
import UserNotifications

/// Schedules local notifications reminding the user when a GLP-1 dose is due.
/// Uses local notifications only (no push), so no special entitlement is needed.
enum DoseReminderScheduler {
    /// Stable notification identifier for a medication.
    private static func identifier(for med: Medication) -> String {
        "dose-reminder-\(med.reminderID)"
    }

    /// Requests notification permission. Safe to call repeatedly.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Re-schedules the reminder for a single medication. Removes any existing one
    /// first, then adds a repeating reminder if enabled and the med is active.
    static func reschedule(_ med: Medication) {
        let center = UNUserNotificationCenter.current()
        let id = identifier(for: med)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard med.isActive, med.remindersEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(med.name) dose due"
        content.body = med.form == .injection
            ? "Time for your \(med.doseLabel) injection. Tap to log it."
            : "Time for your \(med.doseLabel) dose. Tap to log it."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = med.reminderMinutes / 60
        dateComponents.minute = med.reminderMinutes % 60
        if med.schedule == .weekly {
            dateComponents.weekday = med.doseWeekday
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    /// Cancels a medication's pending reminder.
    static func cancel(_ med: Medication) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: med)])
    }
}

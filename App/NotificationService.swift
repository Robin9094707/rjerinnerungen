import Foundation
import Observation
@preconcurrency import UserNotifications

extension Notification.Name {
    static let rjNotificationAction = Notification.Name("RJNotificationAction")
}

enum RJNotificationAction: String {
    case complete = "RJ_COMPLETE"
    case snooze = "RJ_SNOOZE"
    case open = "RJ_OPEN"
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let rawID = response.notification.request.content.userInfo["reminderID"] as? String
        NotificationCenter.default.post(
            name: .rjNotificationAction,
            object: nil,
            userInfo: [
                "action": response.actionIdentifier,
                "reminderID": rawID ?? ""
            ]
        )
    }
}

@MainActor
@Observable
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    func configure() {
        let complete = UNNotificationAction(
            identifier: RJNotificationAction.complete.rawValue,
            title: "Erledigt",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: RJNotificationAction.snooze.rawValue,
            title: "10 Minuten später",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: "RJ_REMINDER",
            actions: [complete, snooze],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    func refreshAuthorization() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            let allowed = try await center.requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await refreshAuthorization()
            DebugLogger.shared.log("Notification authorization: \(allowed)")
            return allowed
        } catch {
            DebugLogger.shared.log("Notification authorization error: \(error)")
            return false
        }
    }

    func schedule(_ reminder: ReminderItem) async throws {
        cancel(reminder.id)
        guard reminder.notificationEnabled,
              !reminder.completed,
              let dueDate = reminder.dueDate else { return }

        if authorizationStatus == .notDetermined {
            _ = await requestAuthorization()
        }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.details.isEmpty ? "Deine Erinnerung ist jetzt fällig." : reminder.details
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "RJ_REMINDER"
        content.threadIdentifier = "RJ_REMINDERS"
        content.targetContentIdentifier = reminder.id.uuidString
        content.userInfo = ["reminderID": reminder.id.uuidString]
        content.interruptionLevel = reminder.priority == .high || reminder.priority == .urgent
            ? .timeSensitive
            : .active

        let calendar = Calendar.current
        let trigger: UNCalendarNotificationTrigger
        switch reminder.recurrence {
        case .never:
            guard dueDate > .now else { return }
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        case .daily:
            let components = calendar.dateComponents([.hour, .minute], from: dueDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case .weekly:
            let components = calendar.dateComponents([.weekday, .hour, .minute], from: dueDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case .monthly:
            let components = calendar.dateComponents([.day, .hour, .minute], from: dueDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        }

        try await center.add(
            UNNotificationRequest(
                identifier: identifier(for: reminder.id),
                content: content,
                trigger: trigger
            )
        )
        DebugLogger.shared.log("Reminder notification scheduled: \(reminder.id)")
    }

    func snooze(_ reminder: ReminderItem, minutes: Int = 10) async throws {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = "Noch einmal erinnert – \(minutes) Minuten später."
        content.sound = .default
        content.categoryIdentifier = "RJ_REMINDER"
        content.userInfo = ["reminderID": reminder.id.uuidString]
        content.interruptionLevel = reminder.priority == .urgent ? .timeSensitive : .active
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(max(1, minutes) * 60),
            repeats: false
        )
        try await center.add(
            UNNotificationRequest(
                identifier: snoozeIdentifier(for: reminder.id),
                content: content,
                trigger: trigger
            )
        )
    }

    func cancel(_ id: UUID) {
        let ids = [identifier(for: id), snoozeIdentifier(for: id)]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func clearBadge() {
        center.setBadgeCount(0)
    }

    private func identifier(for id: UUID) -> String { "reminder-\(id.uuidString)" }
    private func snoozeIdentifier(for id: UUID) -> String { "reminder-\(id.uuidString)-snooze" }
}

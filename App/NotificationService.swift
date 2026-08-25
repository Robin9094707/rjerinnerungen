import CoreLocation
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

enum RJNotificationError: LocalizedError {
    case permissionDenied
    case noSchedulingCapacity

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Benachrichtigungen sind nicht erlaubt. Aktiviere sie in den iOS-Einstellungen."
        case .noSchedulingCapacity:
            "iOS hat aktuell keinen freien Platz für weitere geplante Hinweise. Öffne die App später erneut, damit die nächsten Wiederholungen nachgeladen werden."
        }
    }
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
            title: "Später erinnern",
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
            let allowed = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorization()
            DebugLogger.shared.log("Notification authorization: \(allowed)")
            return allowed
        } catch {
            DebugLogger.shared.log("Notification authorization error: \(error)")
            return false
        }
    }

    @discardableResult
    func schedule(_ reminder: ReminderItem) async throws -> Int {
        cancel(reminder.id)
        guard reminder.notificationEnabled, !reminder.completed else { return 0 }

        if authorizationStatus == .notDetermined { _ = await requestAuthorization() }
        guard authorizationStatus == .authorized
            || authorizationStatus == .provisional
            || authorizationStatus == .ephemeral
        else { throw RJNotificationError.permissionDenied }

        let pendingCount = await center.pendingNotificationRequests().count
        var remainingCapacity = max(0, 60 - pendingCount)
        var scheduled = 0

        if let dueDate = normalizedStartDate(for: reminder), remainingCapacity > 0 {
            let leadTimes = Array(Set(reminder.notificationLeadTimes.map { max(0, $0) } + [0])).sorted()
            let occurrences = reminder.effectiveRecurrence.upcomingDates(
                startingAt: dueDate,
                after: .now,
                limit: min(16, max(1, remainingCapacity / max(1, leadTimes.count)))
            )
            outer: for (occurrenceIndex, occurrence) in occurrences.enumerated() {
                for leadTime in leadTimes {
                    guard remainingCapacity > 0 else { break outer }
                    let fireDate = occurrence.addingTimeInterval(TimeInterval(-leadTime))
                    guard fireDate > .now else { continue }
                    let content = content(for: reminder, leadTime: leadTime)
                    let components = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute, .second],
                        from: fireDate
                    )
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let identifier = timeIdentifier(
                        for: reminder.id,
                        occurrence: occurrenceIndex,
                        leadTime: leadTime
                    )
                    try await center.add(UNNotificationRequest(
                        identifier: identifier,
                        content: content,
                        trigger: trigger
                    ))
                    scheduled += 1
                    remainingCapacity -= 1
                }
            }
        }

        if let location = reminder.locationTrigger, remainingCapacity > 0 {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                radius: min(10_000, max(50, location.radius)),
                identifier: locationIdentifier(for: reminder.id)
            )
            region.notifyOnEntry = location.event == .enter
            region.notifyOnExit = location.event == .exit
            let trigger = UNLocationNotificationTrigger(region: region, repeats: location.repeats)
            let content = content(for: reminder, location: location)
            try await center.add(UNNotificationRequest(
                identifier: locationIdentifier(for: reminder.id),
                content: content,
                trigger: trigger
            ))
            scheduled += 1
        }

        if scheduled == 0, reminder.dueDate != nil || reminder.locationTrigger != nil {
            throw RJNotificationError.noSchedulingCapacity
        }
        DebugLogger.shared.log("Reminder notifications scheduled: \(reminder.id), count \(scheduled)")
        return scheduled
    }

    func refresh(_ reminders: [ReminderItem]) async {
        for reminder in reminders where !reminder.completed && reminder.notificationEnabled && !reminder.alarmEscalation {
            do { try await schedule(reminder) }
            catch { DebugLogger.shared.log("Reminder refresh warning \(reminder.id): \(error)") }
        }
    }

    func snooze(_ reminder: ReminderItem, minutes: Int? = nil) async throws {
        let delay = max(1, minutes ?? reminder.snoozeMinutes)
        let content = content(for: reminder, leadTime: 0)
        content.body = "Noch einmal erinnert – \(delay) Minuten später."
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(delay * 60),
            repeats: false
        )
        try await center.add(UNNotificationRequest(
            identifier: snoozeIdentifier(for: reminder.id),
            content: content,
            trigger: trigger
        ))
    }

    func cancel(_ id: UUID) {
        var identifiers = [
            legacyIdentifier(for: id),
            snoozeIdentifier(for: id),
            locationIdentifier(for: id)
        ]
        for occurrence in 0..<20 {
            for lead in [0, 300, 900, 1_800, 3_600, 7_200, 86_400, 172_800] {
                identifiers.append(timeIdentifier(for: id, occurrence: occurrence, leadTime: lead))
            }
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func clearBadge() {
        center.setBadgeCount(0)
    }

    private func normalizedStartDate(for reminder: ReminderItem) -> Date? {
        guard let dueDate = reminder.dueDate else { return nil }
        guard !reminder.hasTime else { return dueDate }
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dueDate)
    }

    private func content(for reminder: ReminderItem, leadTime: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        if !reminder.details.isEmpty {
            content.body = reminder.details
        } else if leadTime > 0 {
            content.body = "Beginnt " + leadTimeTitle(leadTime) + "."
        } else {
            content.body = "Deine Erinnerung ist jetzt fällig."
        }
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "RJ_REMINDER"
        content.threadIdentifier = "RJ_REMINDERS"
        content.targetContentIdentifier = reminder.id.uuidString
        content.userInfo = ["reminderID": reminder.id.uuidString]
        content.interruptionLevel = reminder.priority == .high || reminder.priority == .urgent
            ? .timeSensitive
            : .active
        return content
    }

    private func content(
        for reminder: ReminderItem,
        location: ReminderLocationTrigger
    ) -> UNMutableNotificationContent {
        let content = content(for: reminder, leadTime: 0)
        content.body = reminder.details.isEmpty
            ? "\(location.event.title): \(location.name)"
            : reminder.details
        content.threadIdentifier = "RJ_LOCATION_REMINDERS"
        return content
    }

    private func leadTimeTitle(_ seconds: Int) -> String {
        switch seconds {
        case 300: "in 5 Minuten"
        case 900: "in 15 Minuten"
        case 1_800: "in 30 Minuten"
        case 3_600: "in 1 Stunde"
        case 7_200: "in 2 Stunden"
        case 86_400: "morgen"
        case 172_800: "in 2 Tagen"
        default: "bald"
        }
    }

    private func legacyIdentifier(for id: UUID) -> String { "reminder-\(id.uuidString)" }
    private func timeIdentifier(for id: UUID, occurrence: Int, leadTime: Int) -> String {
        "rj-reminder-\(id.uuidString)-\(occurrence)-\(leadTime)"
    }
    private func snoozeIdentifier(for id: UUID) -> String { "rj-reminder-\(id.uuidString)-snooze" }
    private func locationIdentifier(for id: UUID) -> String { "rj-location-\(id.uuidString)" }
}

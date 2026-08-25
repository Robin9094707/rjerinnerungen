import Foundation
import UserNotifications

struct NotificationStatusSnapshot {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var alertSetting: UNNotificationSetting = .notSupported
    var soundSetting: UNNotificationSetting = .notSupported
    var timeSensitiveSetting: UNNotificationSetting = .notSupported
    var criticalAlertSetting: UNNotificationSetting = .notSupported

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
    }
}

actor NotificationService {
    static let shared = NotificationService()

    static let categoryIdentifier = "RJ_REMINDER"
    static let doneAction = "RJ_DONE"
    static let snooze5Action = "RJ_SNOOZE_5"
    static let snooze15Action = "RJ_SNOOZE_15"
    static let snooze60Action = "RJ_SNOOZE_60"

    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound, .providesAppNotificationSettings])
    }

    func requestCriticalAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.criticalAlert])
    }

    func status() async -> NotificationStatusSnapshot {
        let settings = await center.notificationSettings()
        return NotificationStatusSnapshot(
            authorizationStatus: settings.authorizationStatus,
            alertSetting: settings.alertSetting,
            soundSetting: settings.soundSetting,
            timeSensitiveSetting: settings.timeSensitiveSetting,
            criticalAlertSetting: settings.criticalAlertSetting
        )
    }

    func schedule(_ reminder: RJReminder) async throws {
        await cancel(reminderID: reminder.id)
        guard reminder.notificationEnabled, reminder.hasDueDate, !reminder.isCompleted else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            throw NotificationError.permissionMissing
        }

        let criticalAllowed = settings.criticalAlertSetting == .enabled
        let offsets = ([0] + reminder.preAlertMinutes.filter { $0 > 0 }).sorted()
        var requestCount = 0

        for offset in offsets {
            let fireDate = reminder.dueDate.addingTimeInterval(TimeInterval(-offset * 60))
            if reminder.recurrence == .none && fireDate <= .now { continue }

            let triggers = makeTriggers(for: reminder.recurrence, fireDate: fireDate)
            for (index, trigger) in triggers.enumerated() {
                guard requestCount < 10 else { break }
                let content = makeContent(for: reminder, offsetMinutes: offset, criticalAllowed: criticalAllowed)
                let identifier = "rj.reminder.\(reminder.id.uuidString).\(offset).\(index)"
                try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
                requestCount += 1
            }
        }

        await MainActor.run {
            DebugLogger.shared.log("Scheduled \(requestCount) notification request(s) for \(reminder.id.uuidString)")
        }
    }

    func scheduleSnooze(from content: UNNotificationContent, minutes: Int) async throws {
        guard let mutable = content.mutableCopy() as? UNMutableNotificationContent else { return }
        mutable.subtitle = "Erneut erinnert nach \(minutes) Min."
        mutable.userInfo["snoozed"] = true
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(minutes, 1) * 60), repeats: false)
        let request = UNNotificationRequest(identifier: "rj.snooze.\(UUID().uuidString)", content: mutable, trigger: trigger)
        try await center.add(request)
    }

    func scheduleTest(priority: ReminderPriority) async throws {
        let settings = await center.notificationSettings()
        let allowed = settings.criticalAlertSetting == .enabled
        let sample = RJReminder(title: "RJ Ultra Test", notes: "So klingt eine \(priority.title)-Erinnerung.", dueDate: .now.addingTimeInterval(4), priority: priority)
        let content = makeContent(for: sample, offsetMinutes: 0, criticalAllowed: allowed)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 4, repeats: false)
        try await center.add(UNNotificationRequest(identifier: "rj.test.\(UUID().uuidString)", content: content, trigger: trigger))
    }

    func cancel(reminderID: UUID) async {
        let pending = await center.pendingNotificationRequests()
        let prefix = "rj.reminder.\(reminderID.uuidString)."
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func pendingCount() async -> Int {
        let requests = await center.pendingNotificationRequests()
        return requests.count
    }

    private func makeContent(for reminder: RJReminder, offsetMinutes: Int, criticalAllowed: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.notes.isEmpty ? bodyText(for: reminder, offsetMinutes: offsetMinutes) : reminder.notes
        content.categoryIdentifier = Self.categoryIdentifier
        content.threadIdentifier = "rj-reminders"
        content.userInfo = [
            "reminderID": reminder.id.uuidString,
            "snoozeMinutes": reminder.snoozeMinutes,
            "priority": reminder.priority.rawValue
        ]
        content.badge = 1
        content.relevanceScore = relevanceScore(for: reminder.priority)

        switch reminder.priority {
        case .low:
            content.interruptionLevel = .passive
            content.sound = nil
        case .normal, .important:
            content.interruptionLevel = .active
            content.sound = UNNotificationSound(named: UNNotificationSoundName("rj_chime.wav"))
        case .high, .urgent:
            content.interruptionLevel = .timeSensitive
            content.sound = UNNotificationSound(named: UNNotificationSoundName("rj_urgent.wav"))
        case .ultra:
            if criticalAllowed {
                content.interruptionLevel = .critical
                content.sound = UNNotificationSound.criticalSoundNamed(UNNotificationSoundName("rj_ultra.wav"), withAudioVolume: 1.0)
            } else {
                content.interruptionLevel = .timeSensitive
                content.sound = UNNotificationSound(named: UNNotificationSoundName("rj_ultra.wav"))
            }
        }
        return content
    }

    private func bodyText(for reminder: RJReminder, offsetMinutes: Int) -> String {
        if offsetMinutes > 0 {
            return "In \(offsetMinutes) Minuten • \(reminder.category.title)"
        }
        return reminder.recurrence == .none ? reminder.category.title : "\(reminder.category.title) • \(reminder.recurrence.title)"
    }

    private func relevanceScore(for priority: ReminderPriority) -> Double {
        switch priority {
        case .low: 0.1
        case .normal: 0.3
        case .important: 0.5
        case .high: 0.75
        case .urgent: 0.9
        case .ultra: 1.0
        }
    }

    private func makeTriggers(for recurrence: ReminderRecurrence, fireDate: Date) -> [UNNotificationTrigger] {
        let calendar = Calendar.current
        switch recurrence {
        case .none:
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            return [UNCalendarNotificationTrigger(dateMatching: components, repeats: false)]
        case .daily:
            let components = calendar.dateComponents([.hour, .minute], from: fireDate)
            return [UNCalendarNotificationTrigger(dateMatching: components, repeats: true)]
        case .weekdays:
            let time = calendar.dateComponents([.hour, .minute], from: fireDate)
            return (2...6).map { weekday in
                var components = DateComponents()
                components.weekday = weekday
                components.hour = time.hour
                components.minute = time.minute
                return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            }
        case .weekly:
            let components = calendar.dateComponents([.weekday, .hour, .minute], from: fireDate)
            return [UNCalendarNotificationTrigger(dateMatching: components, repeats: true)]
        case .monthly:
            let components = calendar.dateComponents([.day, .hour, .minute], from: fireDate)
            return [UNCalendarNotificationTrigger(dateMatching: components, repeats: true)]
        case .yearly:
            let components = calendar.dateComponents([.month, .day, .hour, .minute], from: fireDate)
            return [UNCalendarNotificationTrigger(dateMatching: components, repeats: true)]
        }
    }
}

enum NotificationError: LocalizedError {
    case permissionMissing

    var errorDescription: String? {
        switch self {
        case .permissionMissing: "Benachrichtigungen sind für RJ Ultra Erinnerungen nicht freigegeben."
        }
    }
}

import EventKit
import Foundation

@MainActor
final class AppleRemindersService {
    static let shared = AppleRemindersService()
    private let store = EKEventStore()

    private init() {}

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestFullAccessToReminders { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func fetchImportableReminders() async throws -> [ReminderTransferRecord] {
        if authorizationStatus != .fullAccess {
            let granted = try await requestAccess()
            guard granted else { throw AppleReminderError.permissionDenied }
        }

        let predicate = store.predicateForReminders(in: nil)
        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { values in
                continuation.resume(returning: values ?? [])
            }
        }

        return reminders
            .filter { !$0.isCompleted }
            .map(convert)
            .sorted { $0.dueDate < $1.dueDate }
    }

    func export(_ item: RJReminder) async throws {
        if authorizationStatus != .fullAccess {
            let granted = try await requestAccess()
            guard granted else { throw AppleReminderError.permissionDenied }
        }
        guard let calendar = store.defaultCalendarForNewReminders() else {
            throw AppleReminderError.noDefaultList
        }

        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar
        reminder.title = item.title
        reminder.notes = item.notes.isEmpty ? nil : item.notes
        reminder.priority = ekPriority(item.priority)

        if item.hasDueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.dueDate)
            reminder.addAlarm(EKAlarm(absoluteDate: item.dueDate))
        }

        if let rule = recurrenceRule(for: item.recurrence) {
            reminder.addRecurrenceRule(rule)
        }

        try store.save(reminder, commit: true)
        DebugLogger.shared.log("Exported reminder to Apple Reminders: \(item.id.uuidString)")
    }

    private func convert(_ reminder: EKReminder) -> ReminderTransferRecord {
        let due = reminder.dueDateComponents.flatMap { components -> Date? in
            var copy = components
            copy.calendar = copy.calendar ?? Calendar.current
            return copy.date
        } ?? .now.addingTimeInterval(3600)

        let recurrence = reminder.recurrenceRules?.first.map { rule -> ReminderRecurrence in
            switch rule.frequency {
            case .daily: .daily
            case .weekly: .weekly
            case .monthly: .monthly
            case .yearly: .yearly
            @unknown default: .none
            }
        } ?? .none

        let priority: ReminderPriority = switch reminder.priority {
        case 1...3: .high
        case 4...6: .important
        case 7...9: .low
        default: .normal
        }

        let item = RJReminder(
            title: reminder.title ?? "Apple Erinnerung",
            notes: reminder.notes ?? "",
            dueDate: due,
            hasDueDate: reminder.dueDateComponents != nil,
            priority: priority,
            category: .personal,
            recurrence: recurrence,
            tags: ["Apple Import"],
            preAlertMinutes: [],
            notificationEnabled: true,
            liveActivityEnabled: false,
            snoozeMinutes: 10,
            importedFromApple: true,
            externalIdentifier: reminder.calendarItemIdentifier
        )
        return ReminderTransferRecord(item)
    }

    private func ekPriority(_ priority: ReminderPriority) -> Int {
        switch priority {
        case .ultra, .urgent, .high: 1
        case .important: 5
        case .normal: 0
        case .low: 9
        }
    }

    private func recurrenceRule(for recurrence: ReminderRecurrence) -> EKRecurrenceRule? {
        switch recurrence {
        case .none:
            nil
        case .daily, .weekdays:
            EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly:
            EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .monthly:
            EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        case .yearly:
            EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
        }
    }
}

enum AppleReminderError: LocalizedError {
    case permissionDenied
    case noDefaultList

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Kein Zugriff auf Apple Erinnerungen."
        case .noDefaultList: "Apple Erinnerungen hat keine Standardliste für neue Einträge."
        }
    }
}

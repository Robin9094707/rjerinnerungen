import Foundation
import Observation
@preconcurrency import EventKit

@MainActor
@Observable
final class EventKitService {
    static let shared = EventKitService()

    private let eventStore = EKEventStore()

    private(set) var eventAuthorization = EKEventStore.authorizationStatus(for: .event)
    private(set) var reminderAuthorization = EKEventStore.authorizationStatus(for: .reminder)
    private(set) var events: [CalendarEventSnapshot] = []
    private(set) var systemReminders: [SystemReminderSnapshot] = []
    var lastError: String?

    func refreshAuthorization() {
        eventAuthorization = EKEventStore.authorizationStatus(for: .event)
        reminderAuthorization = EKEventStore.authorizationStatus(for: .reminder)
    }

    func requestEventAccess() async -> Bool {
        do {
            let allowed = try await eventStore.requestFullAccessToEvents()
            refreshAuthorization()
            if allowed { await refresh() }
            return allowed
        } catch {
            lastError = error.localizedDescription
            DebugLogger.shared.log("EventKit event permission error: \(error)")
            return false
        }
    }

    func requestReminderAccess() async -> Bool {
        do {
            let allowed = try await eventStore.requestFullAccessToReminders()
            refreshAuthorization()
            if allowed { await refresh() }
            return allowed
        } catch {
            lastError = error.localizedDescription
            DebugLogger.shared.log("EventKit reminder permission error: \(error)")
            return false
        }
    }

    func refresh(
        from startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now,
        to endDate: Date = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    ) async {
        refreshAuthorization()

        if eventAuthorization == .fullAccess {
            let predicate = eventStore.predicateForEvents(
                withStart: startDate,
                end: endDate,
                calendars: nil
            )
            events = eventStore.events(matching: predicate).map { event in
                CalendarEventSnapshot(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Termin",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    calendarTitle: event.calendar.title,
                    colorComponents: event.calendar.cgColor.components?.map(Double.init) ?? [0, 0.7, 1, 1],
                    location: event.location
                )
            }
        } else {
            events = []
        }

        if reminderAuthorization == .fullAccess {
            let predicate = eventStore.predicateForReminders(in: nil)
            let reminders = await withCheckedContinuation { continuation in
                eventStore.fetchReminders(matching: predicate) { values in
                    continuation.resume(returning: values ?? [])
                }
            }
            systemReminders = reminders.map { reminder in
                SystemReminderSnapshot(
                    id: reminder.calendarItemIdentifier,
                    title: reminder.title ?? "Erinnerung",
                    dueDate: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                    completed: reminder.isCompleted,
                    calendarTitle: reminder.calendar.title
                )
            }
        } else {
            systemReminders = []
        }
    }

    func createEvent(
        title: String,
        notes: String,
        startDate: Date,
        endDate: Date,
        allDay: Bool
    ) async throws {
        if eventAuthorization != .fullAccess {
            guard await requestEventAccess() else {
                throw EventKitServiceError.eventsDenied
            }
        }
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw EventKitServiceError.noCalendar
        }
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = notes.isEmpty ? nil : notes
        event.startDate = startDate
        event.endDate = max(endDate, startDate.addingTimeInterval(60))
        event.isAllDay = allDay
        event.calendar = calendar
        try eventStore.save(event, span: .thisEvent, commit: true)
        await refresh()
    }

    func exportReminder(_ item: ReminderItem) async throws -> String {
        if reminderAuthorization != .fullAccess {
            guard await requestReminderAccess() else {
                throw EventKitServiceError.remindersDenied
            }
        }
        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            throw EventKitServiceError.noReminderList
        }
        let reminder: EKReminder
        if let identifier = item.systemReminderIdentifier,
           let existing = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder {
            reminder = existing
        } else {
            reminder = EKReminder(eventStore: eventStore)
        }
        reminder.title = item.title
        reminder.notes = item.details.isEmpty ? nil : item.details
        reminder.priority = switch item.priority {
        case .urgent: 1
        case .high: 3
        case .normal: 5
        case .low: 9
        }
        reminder.calendar = calendar
        for alarm in reminder.alarms ?? [] { reminder.removeAlarm(alarm) }
        for rule in reminder.recurrenceRules ?? [] { reminder.removeRecurrenceRule(rule) }
        if let dueDate = item.dueDate {
            let components: Set<Calendar.Component> = item.hasTime
                ? [.calendar, .timeZone, .year, .month, .day, .hour, .minute]
                : [.calendar, .timeZone, .year, .month, .day]
            reminder.dueDateComponents = Calendar.current.dateComponents(components, from: dueDate)
            for seconds in item.notificationLeadTimes {
                reminder.addAlarm(EKAlarm(relativeOffset: TimeInterval(-max(0, seconds))))
            }
            if let recurrence = eventKitRecurrence(for: item.effectiveRecurrence) {
                reminder.addRecurrenceRule(recurrence)
            }
        } else {
            reminder.dueDateComponents = nil
        }
        try eventStore.save(reminder, commit: true)
        await refresh()
        return reminder.calendarItemIdentifier
    }

    private func eventKitRecurrence(for rule: RJRecurrenceRule) -> EKRecurrenceRule? {
        guard rule.isRepeating else { return nil }
        let frequency: EKRecurrenceFrequency = switch rule.frequency {
        case .hourly: .daily // EventKit reminders have no hourly recurrence; keep a daily system copy.
        case .daily: .daily
        case .weekly: .weekly
        case .monthly: .monthly
        case .yearly: .yearly
        case .never: .daily
        }
        let end: EKRecurrenceEnd?
        if let occurrenceLimit = rule.occurrenceLimit {
            end = EKRecurrenceEnd(occurrenceCount: max(1, occurrenceLimit))
        } else if let endDate = rule.endDate {
            end = EKRecurrenceEnd(end: endDate)
        } else {
            end = nil
        }

        if rule.frequency == .weekly, !rule.weekdays.isEmpty {
            let days = rule.weekdays.map { EKRecurrenceDayOfWeek($0.eventKitWeekday) }
            return EKRecurrenceRule(
                recurrenceWith: frequency,
                interval: max(1, rule.interval),
                daysOfTheWeek: days,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: end
            )
        }
        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: max(1, rule.interval),
            end: end
        )
    }
}

private extension RJWeekday {
    var eventKitWeekday: EKWeekday {
        switch self {
        case .sunday: .sunday
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        }
    }
}

enum EventKitServiceError: LocalizedError {
    case eventsDenied
    case remindersDenied
    case noCalendar
    case noReminderList

    var errorDescription: String? {
        switch self {
        case .eventsDenied: "Kein Zugriff auf Apple Kalender."
        case .remindersDenied: "Kein Zugriff auf Apple Erinnerungen."
        case .noCalendar: "iOS hat keinen beschreibbaren Standardkalender gefunden."
        case .noReminderList: "iOS hat keine beschreibbare Erinnerungsliste gefunden."
        }
    }
}

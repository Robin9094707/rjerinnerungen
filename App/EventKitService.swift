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
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = item.title
        reminder.notes = item.details.isEmpty ? nil : item.details
        reminder.priority = switch item.priority {
        case .urgent: 1
        case .high: 3
        case .normal: 5
        case .low: 9
        }
        reminder.calendar = calendar
        if let dueDate = item.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.calendar, .timeZone, .year, .month, .day, .hour, .minute],
                from: dueDate
            )
            reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        }
        try eventStore.save(reminder, commit: true)
        await refresh()
        return reminder.calendarItemIdentifier
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

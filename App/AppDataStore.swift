import Foundation
import Observation

@MainActor
@Observable
final class AppDataStore {
    private(set) var reminders: [ReminderItem]
    private(set) var notes: [NoteItem]
    private(set) var alarms: [AlarmRecord]

    var lastError: String?
    var selectedDate: Date = .now

    init() {
        reminders = AppPersistence.load([ReminderItem].self, from: AppPersistence.remindersURL) ?? []
        notes = AppPersistence.load([NoteItem].self, from: AppPersistence.notesURL) ?? []
        alarms = AppPersistence.load([AlarmRecord].self, from: AppPersistence.alarmsURL) ?? []
    }

    var activeReminders: [ReminderItem] {
        reminders
            .filter { !$0.completed }
            .sorted {
                switch ($0.dueDate, $1.dueDate) {
                case let (left?, right?): left < right
                case (.some, .none): true
                case (.none, .some): false
                case (.none, .none): $0.createdAt > $1.createdAt
                }
            }
    }

    var pinnedNotes: [NoteItem] {
        notes.filter(\.pinned).sorted { $0.updatedAt > $1.updatedAt }
    }

    var upcomingAlarms: [AlarmRecord] {
        alarms
            .filter(\.enabled)
            .sorted {
                ($0.nextFireDate() ?? .distantFuture) < ($1.nextFireDate() ?? .distantFuture)
            }
    }

    func bootstrap() async {
        NotificationService.shared.configure()
        await NotificationService.shared.refreshAuthorization()
        await EventKitService.shared.refresh()
        DebugLogger.shared.load()
        DebugLogger.shared.log("App data loaded: \(reminders.count) reminders, \(notes.count) notes, \(alarms.count) alarms")
    }

    func upsertReminder(_ item: ReminderItem, exportToSystem: Bool = false) async {
        var value = item
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.title.isEmpty else {
            lastError = "Eine Erinnerung braucht einen Titel."
            return
        }
        value.updatedAt = .now

        do {
            if exportToSystem, value.systemReminderIdentifier == nil {
                value.systemReminderIdentifier = try await EventKitService.shared.exportReminder(value)
            }
            if value.completed {
                NotificationService.shared.cancel(value.id)
                ScheduledAlarmService.shared.cancel(value.id)
            } else if value.alarmEscalation {
                try await ScheduledAlarmService.shared.scheduleEscalation(for: value)
                NotificationService.shared.cancel(value.id)
            } else {
                ScheduledAlarmService.shared.cancel(value.id)
                try await NotificationService.shared.schedule(value)
            }
            replaceOrInsert(&reminders, value: value)
            try AppPersistence.save(reminders, to: AppPersistence.remindersURL)
            Haptics.success()
        } catch {
            lastError = error.localizedDescription
            DebugLogger.shared.log("Save reminder failed: \(error)")
        }
    }

    func toggleReminder(_ id: UUID) async {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        var item = reminders[index]
        item.completed.toggle()
        await upsertReminder(item)
    }

    func deleteReminder(_ id: UUID) {
        NotificationService.shared.cancel(id)
        ScheduledAlarmService.shared.cancel(id)
        reminders.removeAll { $0.id == id }
        saveReminders()
    }

    func duplicateSystemReminder(_ item: SystemReminderSnapshot) async {
        let reminder = ReminderItem(
            title: item.title,
            dueDate: item.dueDate,
            completed: item.completed,
            systemReminderIdentifier: item.id
        )
        await upsertReminder(reminder)
    }

    func upsertNote(_ item: NoteItem) {
        var value = item
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.title.isEmpty {
            value.title = value.body.split(separator: "\n").first.map(String.init) ?? "Neue Notiz"
        }
        value.updatedAt = .now
        replaceOrInsert(&notes, value: value)
        do {
            try AppPersistence.save(notes, to: AppPersistence.notesURL)
            Haptics.success()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteNote(_ id: UUID) {
        notes.removeAll { $0.id == id }
        do {
            try AppPersistence.save(notes, to: AppPersistence.notesURL)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func upsertAlarm(_ item: AlarmRecord) async {
        var value = item
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.title.isEmpty { value.title = "Wecker" }
        do {
            ScheduledAlarmService.shared.cancel(value.id)
            if value.enabled {
                try await ScheduledAlarmService.shared.schedule(value)
            }
            replaceOrInsert(&alarms, value: value)
            try AppPersistence.save(alarms, to: AppPersistence.alarmsURL)
            Haptics.success()
        } catch {
            lastError = error.localizedDescription
            DebugLogger.shared.log("Save alarm failed: \(error)")
        }
    }

    func setAlarmEnabled(_ id: UUID, enabled: Bool) async {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        var alarm = alarms[index]
        alarm.enabled = enabled
        await upsertAlarm(alarm)
    }

    func deleteAlarm(_ id: UUID) {
        ScheduledAlarmService.shared.cancel(id)
        alarms.removeAll { $0.id == id }
        do {
            try AppPersistence.save(alarms, to: AppPersistence.alarmsURL)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func handleNotificationAction(_ notification: Notification) {
        guard let rawID = notification.userInfo?["reminderID"] as? String,
              let id = UUID(uuidString: rawID),
              let action = notification.userInfo?["action"] as? String,
              let reminder = reminders.first(where: { $0.id == id }) else { return }

        if action == RJNotificationAction.complete.rawValue {
            Task { await toggleReminder(id) }
        } else if action == RJNotificationAction.snooze.rawValue {
            Task {
                do {
                    try await NotificationService.shared.snooze(reminder)
                } catch {
                    lastError = error.localizedDescription
                }
            }
        }
    }

    func exportURL() -> URL? {
        try? AppPersistence.exportAll(reminders: reminders, notes: notes, alarms: alarms)
    }

    private func saveReminders() {
        do {
            try AppPersistence.save(reminders, to: AppPersistence.remindersURL)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func replaceOrInsert<T: Identifiable>(_ values: inout [T], value: T) where T.ID: Equatable {
        if let index = values.firstIndex(where: { $0.id == value.id }) {
            values[index] = value
        } else {
            values.insert(value, at: 0)
        }
    }
}

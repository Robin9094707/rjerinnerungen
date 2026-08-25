import Foundation
import Observation

@MainActor
@Observable
final class AppDataStore {
    private(set) var reminders: [ReminderItem]
    private(set) var notes: [NoteItem]
    private(set) var noteFolders: [NoteFolder]
    private(set) var alarms: [AlarmRecord]

    var lastError: String?
    var selectedDate: Date = .now

    init() {
        reminders = AppPersistence.load([ReminderItem].self, from: AppPersistence.remindersURL) ?? []
        notes = AppPersistence.load([NoteItem].self, from: AppPersistence.notesURL) ?? []
        noteFolders = AppPersistence.load([NoteFolder].self, from: AppPersistence.noteFoldersURL) ?? []
        alarms = AppPersistence.load([AlarmRecord].self, from: AppPersistence.alarmsURL) ?? []
        if noteFolders.isEmpty {
            noteFolders = [
                NoteFolder(name: "Persönlich", symbol: "person.crop.circle.fill", color: .cyan),
                NoteFolder(name: "Arbeit", symbol: "briefcase.fill", color: .blue),
                NoteFolder(name: "Ideen", symbol: "lightbulb.fill", color: .purple)
            ]
            try? AppPersistence.save(noteFolders, to: AppPersistence.noteFoldersURL)
        }
    }

    var activeReminders: [ReminderItem] {
        reminders.filter { !$0.completed }.sorted {
            switch ($0.dueDate, $1.dueDate) {
            case let (left?, right?): left < right
            case (.some, .none): true
            case (.none, .some): false
            case (.none, .none): $0.createdAt > $1.createdAt
            }
        }
    }

    var activeNotes: [NoteItem] {
        notes.filter { !$0.isTrashed && !$0.archived }
    }

    var trashedNotes: [NoteItem] {
        notes.filter(\.isTrashed).sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    var pinnedNotes: [NoteItem] {
        activeNotes.filter(\.pinned).sorted { $0.updatedAt > $1.updatedAt }
    }

    var noteTags: [String] {
        Array(Set(activeNotes.flatMap(\.normalizedTags))).sorted()
    }

    var upcomingAlarms: [AlarmRecord] {
        alarms.filter(\.enabled).sorted {
            ($0.nextFireDate() ?? .distantFuture) < ($1.nextFireDate() ?? .distantFuture)
        }
    }

    func bootstrap() async {
        NotificationService.shared.configure()
        await NotificationService.shared.refreshAuthorization()
        await EventKitService.shared.refresh()
        LocationService.shared.requestCurrentLocation()
        DebugLogger.shared.load()
        await NotificationService.shared.refresh(reminders)
        DebugLogger.shared.log(
            "App data loaded: \(reminders.count) reminders, \(notes.count) notes, \(alarms.count) alarms, \(noteFolders.count) folders"
        )
    }

    func reloadFromDisk() {
        reminders = AppPersistence.load([ReminderItem].self, from: AppPersistence.remindersURL) ?? reminders
        notes = AppPersistence.load([NoteItem].self, from: AppPersistence.notesURL) ?? notes
        noteFolders = AppPersistence.load([NoteFolder].self, from: AppPersistence.noteFoldersURL) ?? noteFolders
        alarms = AppPersistence.load([AlarmRecord].self, from: AppPersistence.alarmsURL) ?? alarms
        CustomSoundStore.shared.reloadFromDisk()
    }

    @discardableResult
    func upsertReminder(_ item: ReminderItem, exportToSystem: Bool = false) async -> Bool {
        lastError = nil
        var value = item
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.title.isEmpty else {
            lastError = "Eine Erinnerung braucht einen Titel."
            return false
        }
        value.tags = value.normalizedTags
        value.listName = value.listName.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.listName.isEmpty { value.listName = "Allgemein" }
        value.notificationLeadTimes = Array(Set(value.notificationLeadTimes.map { max(0, $0) } + [0])).sorted()
        value.snoozeMinutes = min(120, max(1, value.snoozeMinutes))
        value.recurrenceRule?.interval = max(1, value.recurrenceRule?.interval ?? 1)
        value.updatedAt = .now

        let previous = reminders
        replaceOrInsert(&reminders, value: value)
        do {
            try AppPersistence.save(reminders, to: AppPersistence.remindersURL)
        } catch {
            reminders = previous
            lastError = "Die Erinnerung konnte lokal nicht gespeichert werden: \(error.localizedDescription)"
            DebugLogger.shared.log("Save reminder persistence failed: \(error)")
            return false
        }

        var warnings: [String] = []
        if exportToSystem || value.systemReminderIdentifier != nil {
            do {
                value.systemReminderIdentifier = try await EventKitService.shared.exportReminder(value)
                replaceOrInsert(&reminders, value: value)
                try AppPersistence.save(reminders, to: AppPersistence.remindersURL)
            } catch {
                warnings.append("Apple Erinnerungen: \(error.localizedDescription)")
                DebugLogger.shared.log("System reminder export warning: \(error)")
            }
        }

        if value.completed {
            NotificationService.shared.cancel(value.id)
            ScheduledAlarmService.shared.cancel(value.id)
        } else if value.alarmEscalation,
                  !value.effectiveRecurrence.isRepeating,
                  value.locationTrigger == nil {
            NotificationService.shared.cancel(value.id)
            do {
                try await ScheduledAlarmService.shared.scheduleEscalation(for: value)
            } catch {
                var fallback = value
                fallback.notificationEnabled = true
                fallback.alarmEscalation = false
                do { try await NotificationService.shared.schedule(fallback) }
                catch { DebugLogger.shared.log("Reminder fallback warning: \(error)") }
                warnings.append("AlarmKit konnte nicht aktiviert werden; ein normaler Hinweis wurde als Ersatz geplant.")
                DebugLogger.shared.log("AlarmKit reminder warning: \(error)")
            }
        } else {
            ScheduledAlarmService.shared.cancel(value.id)
            do { try await NotificationService.shared.schedule(value) }
            catch {
                warnings.append(error.localizedDescription)
                DebugLogger.shared.log("Reminder notification warning: \(error)")
            }
        }

        if !warnings.isEmpty {
            lastError = "Erinnerung wurde gespeichert.\n\n" + warnings.joined(separator: "\n")
        }
        Haptics.success()
        return true
    }

    func toggleReminder(_ id: UUID) async {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        var item = reminders[index]
        item.completed.toggle()
        _ = await upsertReminder(item)
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
        _ = await upsertReminder(reminder)
    }

    @discardableResult
    func upsertNote(_ item: NoteItem) -> Bool {
        lastError = nil
        var value = item
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.title.isEmpty {
            value.title = value.body.split(separator: "\n").first.map(String.init) ?? "Neue Notiz"
        }
        value.tags = value.normalizedTags
        value.updatedAt = .now
        let previous = notes
        replaceOrInsert(&notes, value: value)
        do {
            try AppPersistence.save(notes, to: AppPersistence.notesURL)
            Haptics.success()
            return true
        } catch {
            notes = previous
            lastError = error.localizedDescription
            return false
        }
    }

    func moveNoteToTrash(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].deletedAt = .now
        notes[index].pinned = false
        notes[index].updatedAt = .now
        saveNotes()
    }

    func restoreNote(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].deletedAt = nil
        notes[index].updatedAt = .now
        saveNotes()
    }

    func permanentlyDeleteNote(_ id: UUID) {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        note.attachments.forEach(NoteMediaStore.delete)
        note.recordings.forEach(NoteMediaStore.delete)
        notes.removeAll { $0.id == id }
        saveNotes()
    }

    func emptyNoteTrash() {
        trashedNotes.forEach { note in
            note.attachments.forEach(NoteMediaStore.delete)
            note.recordings.forEach(NoteMediaStore.delete)
        }
        notes.removeAll { $0.isTrashed }
        saveNotes()
    }

    @discardableResult
    func upsertFolder(_ item: NoteFolder) -> Bool {
        lastError = nil
        var value = item
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.name.isEmpty else {
            lastError = "Der Ordner braucht einen Namen."
            return false
        }
        value.updatedAt = .now
        replaceOrInsert(&noteFolders, value: value)
        do {
            try AppPersistence.save(noteFolders, to: AppPersistence.noteFoldersURL)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func deleteFolder(_ id: UUID) {
        noteFolders.removeAll { $0.id == id }
        for index in notes.indices where notes[index].folderID == id {
            notes[index].folderID = nil
            notes[index].updatedAt = .now
        }
        do {
            try AppPersistence.save(noteFolders, to: AppPersistence.noteFoldersURL)
            try AppPersistence.save(notes, to: AppPersistence.notesURL)
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func upsertAlarm(_ item: AlarmRecord) async -> Bool {
        lastError = nil
        var value = item
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.title.isEmpty { value.title = "Wecker" }
        value.snoozeMinutes = min(30, max(1, value.snoozeMinutes))
        value.preAlertMinutes = min(60, max(0, value.preAlertMinutes))

        let previous = alarms
        replaceOrInsert(&alarms, value: value)
        do {
            try AppPersistence.save(alarms, to: AppPersistence.alarmsURL)
        } catch {
            alarms = previous
            lastError = "Der Wecker konnte lokal nicht gespeichert werden: \(error.localizedDescription)"
            return false
        }

        ScheduledAlarmService.shared.cancel(value.id)
        if value.enabled {
            do { try await ScheduledAlarmService.shared.schedule(value) }
            catch {
                lastError = "Wecker wurde gespeichert, konnte aber nicht in AlarmKit aktiviert werden: \(error.localizedDescription)"
                DebugLogger.shared.log("Save alarm scheduling warning: \(error)")
            }
        }
        Haptics.success()
        return true
    }

    func setAlarmEnabled(_ id: UUID, enabled: Bool) async {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        var alarm = alarms[index]
        alarm.enabled = enabled
        _ = await upsertAlarm(alarm)
    }

    func deleteAlarm(_ id: UUID) {
        ScheduledAlarmService.shared.cancel(id)
        alarms.removeAll { $0.id == id }
        saveAlarms()
    }

    func replaceSoundReferences(_ fileName: String, with replacement: String = "default") async {
        let affected = alarms.filter { $0.soundFile == fileName }
        for var alarm in affected {
            alarm.soundFile = replacement
            _ = await upsertAlarm(alarm)
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
                do { try await NotificationService.shared.snooze(reminder) }
                catch { lastError = error.localizedDescription }
            }
        }
    }

    func exportURL() -> URL? {
        try? AppPersistence.exportAll(
            reminders: reminders,
            notes: notes,
            noteFolders: noteFolders,
            alarms: alarms,
            customSounds: CustomSoundStore.shared.sounds
        )
    }

    private func saveReminders() {
        do { try AppPersistence.save(reminders, to: AppPersistence.remindersURL) }
        catch { lastError = error.localizedDescription }
    }
    private func saveNotes() {
        do { try AppPersistence.save(notes, to: AppPersistence.notesURL) }
        catch { lastError = error.localizedDescription }
    }
    private func saveAlarms() {
        do { try AppPersistence.save(alarms, to: AppPersistence.alarmsURL) }
        catch { lastError = error.localizedDescription }
    }

    private func replaceOrInsert<T: Identifiable>(_ values: inout [T], value: T) where T.ID: Equatable {
        if let index = values.firstIndex(where: { $0.id == value.id }) { values[index] = value }
        else { values.insert(value, at: 0) }
    }
}

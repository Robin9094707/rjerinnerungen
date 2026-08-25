import Foundation
import Observation
import SwiftData
import UIKit

@MainActor
@Observable
final class ReminderCoordinator {
    var notificationStatus = NotificationStatusSnapshot()
    var pendingNotificationCount = 0
    var message: String?
    var errorMessage: String?

    func bootstrap(context: ModelContext) async {
        await refreshSystemStatus()
        await processNotificationActions(context: context)
        await importQuickIntentInbox(context: context)
        BackgroundRefreshService.schedule()
    }

    func refreshSystemStatus() async {
        notificationStatus = await NotificationService.shared.status()
        pendingNotificationCount = await NotificationService.shared.pendingCount()
    }

    func requestNotifications() async {
        do {
            _ = try await NotificationService.shared.requestAuthorization()
            await refreshSystemStatus()
            message = "Benachrichtigungen wurden aktualisiert."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func schedule(_ reminder: RJReminder) async {
        do {
            try await NotificationService.shared.schedule(reminder)
            await refreshSystemStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func complete(_ reminder: RJReminder, context: ModelContext) async {
        reminder.isCompleted = true
        reminder.completedAt = .now
        reminder.modifiedAt = .now
        try? context.save()
        await NotificationService.shared.cancel(reminderID: reminder.id)
        await LiveActivityService.shared.end(for: reminder.id)
        Haptics.success()
    }

    func reopen(_ reminder: RJReminder, context: ModelContext) async {
        reminder.isCompleted = false
        reminder.completedAt = nil
        reminder.modifiedAt = .now
        try? context.save()
        await schedule(reminder)
    }

    func delete(_ reminder: RJReminder, context: ModelContext) async {
        await NotificationService.shared.cancel(reminderID: reminder.id)
        await LiveActivityService.shared.end(for: reminder.id)
        context.delete(reminder)
        try? context.save()
        Haptics.warning()
    }

    func rebuildNotifications(for reminders: [RJReminder]) async {
        let sorted = reminders
            .filter { !$0.isCompleted && $0.notificationEnabled && $0.hasDueDate }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(40)

        for reminder in sorted {
            do { try await NotificationService.shared.schedule(reminder) }
            catch { DebugLogger.shared.log("Rebuild failed for \(reminder.id): \(error.localizedDescription)") }
        }
        await refreshSystemStatus()
        message = "Benachrichtigungen für die nächsten Erinnerungen wurden neu aufgebaut."
    }

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func processNotificationActions(context: ModelContext) async {
        let ids = Set(NotificationActionInbox.consumeCompleted())
        guard !ids.isEmpty else { return }
        let descriptor = FetchDescriptor<RJReminder>()
        guard let reminders = try? context.fetch(descriptor) else { return }
        for reminder in reminders where ids.contains(reminder.id) {
            reminder.isCompleted = true
            reminder.completedAt = .now
            reminder.modifiedAt = .now
            await NotificationService.shared.cancel(reminderID: reminder.id)
            await LiveActivityService.shared.end(for: reminder.id)
        }
        try? context.save()
    }

    private func importQuickIntentInbox(context: ModelContext) async {
        let records = QuickIntentInbox.consume()
        var inserted: [RJReminder] = []
        for record in records {
            let reminder = RJReminder(
                title: record.title,
                notes: "Über Siri/Kurzbefehle erstellt",
                dueDate: record.dueDate,
                priority: record.priority
            )
            context.insert(reminder)
            inserted.append(reminder)
        }
        if !records.isEmpty {
            try? context.save()
            for reminder in inserted { await schedule(reminder) }
        }
    }
}

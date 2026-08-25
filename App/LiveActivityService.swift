import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private init() {}

    var activitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(for reminder: RJReminder) async throws {
        guard reminder.hasDueDate else { throw LiveActivityError.missingDueDate }
        await end(for: reminder.id)

        let attributes = ReminderActivityAttributes(
            reminderID: reminder.id,
            title: reminder.title,
            priorityName: reminder.priority.title,
            symbolName: reminder.priority.symbolName
        )
        let state = ReminderActivityAttributes.ContentState(
            dueDate: reminder.dueDate,
            subtitle: reminder.notes.isEmpty ? reminder.category.title : reminder.notes,
            isSnoozed: false
        )
        _ = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: reminder.dueDate.addingTimeInterval(3600)),
            pushType: nil
        )
        DebugLogger.shared.log("Live Activity started for \(reminder.id.uuidString)")
    }

    func end(for reminderID: UUID) async {
        for activity in Activity<ReminderActivityAttributes>.activities where activity.attributes.reminderID == reminderID {
            await activity.end(activity.content, dismissalPolicy: .immediate)
        }
    }
}

enum LiveActivityError: LocalizedError {
    case missingDueDate
    var errorDescription: String? { "Für eine Live Activity braucht die Erinnerung ein Datum." }
}

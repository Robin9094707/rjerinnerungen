import ActivityKit
import Foundation

struct ReminderActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var dueDate: Date
        var subtitle: String
        var isSnoozed: Bool
    }

    var reminderID: UUID
    var title: String
    var priorityName: String
    var symbolName: String
}

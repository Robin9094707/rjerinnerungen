import Foundation

enum NotificationActionInbox {
    private static let completedKey = "RJCompletedFromNotifications"

    static func enqueueCompleted(_ id: UUID) {
        var values = UserDefaults.standard.stringArray(forKey: completedKey) ?? []
        if !values.contains(id.uuidString) {
            values.append(id.uuidString)
            UserDefaults.standard.set(values, forKey: completedKey)
        }
    }

    static func consumeCompleted() -> [UUID] {
        let values = UserDefaults.standard.stringArray(forKey: completedKey) ?? []
        UserDefaults.standard.removeObject(forKey: completedKey)
        return values.compactMap(UUID.init(uuidString:))
    }
}

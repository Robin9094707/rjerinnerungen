import Foundation
import UIKit

extension Notification.Name {
    static let rjQuickAction = Notification.Name("RJQuickAction")
}

enum RJQuickAction: String, Sendable {
    case newReminder = "eu.rjuhas.zeitzentrale.quick.new-reminder"
    case newNote = "eu.rjuhas.zeitzentrale.quick.new-note"
    case newTimer = "eu.rjuhas.zeitzentrale.quick.new-timer"
    case newAlarm = "eu.rjuhas.zeitzentrale.quick.new-alarm"
}

enum QuickActionCenter {
    private static let pendingKey = "RJPendingQuickAction"

    static func receive(_ shortcutItem: UIApplicationShortcutItem) {
        UserDefaults.standard.set(shortcutItem.type, forKey: pendingKey)
        NotificationCenter.default.post(
            name: .rjQuickAction,
            object: nil,
            userInfo: ["type": shortcutItem.type]
        )
    }

    static func consumePending() -> RJQuickAction? {
        guard let raw = UserDefaults.standard.string(forKey: pendingKey) else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingKey)
        return RJQuickAction(rawValue: raw)
    }
}

final class RJAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            QuickActionCenter.receive(item)
            return false
        }
        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        QuickActionCenter.receive(shortcutItem)
        completionHandler(RJQuickAction(rawValue: shortcutItem.type) != nil)
    }
}

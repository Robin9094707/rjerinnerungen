import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerNotificationCategories(center: center)
        BackgroundRefreshService.register()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundRefreshService.schedule()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
    }

    private func registerNotificationCategories(center: UNUserNotificationCenter) {
        let done = UNNotificationAction(identifier: NotificationService.doneAction, title: "Erledigt", options: [])
        let snooze5 = UNNotificationAction(identifier: NotificationService.snooze5Action, title: "+5 Min.", options: [])
        let snooze15 = UNNotificationAction(identifier: NotificationService.snooze15Action, title: "+15 Min.", options: [])
        let snooze60 = UNNotificationAction(identifier: NotificationService.snooze60Action, title: "+1 Std.", options: [])
        let category = UNNotificationCategory(
            identifier: NotificationService.categoryIdentifier,
            actions: [done, snooze5, snooze15, snooze60],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let reminderID = (content.userInfo["reminderID"] as? String).flatMap(UUID.init(uuidString:))

        switch response.actionIdentifier {
        case NotificationService.doneAction:
            if let reminderID { NotificationActionInbox.enqueueCompleted(reminderID) }
            completionHandler()
        case NotificationService.snooze5Action:
            Task { try? await NotificationService.shared.scheduleSnooze(from: content, minutes: 5); completionHandler() }
        case NotificationService.snooze15Action:
            Task { try? await NotificationService.shared.scheduleSnooze(from: content, minutes: 15); completionHandler() }
        case NotificationService.snooze60Action:
            Task { try? await NotificationService.shared.scheduleSnooze(from: content, minutes: 60); completionHandler() }
        default:
            completionHandler()
        }
    }
}

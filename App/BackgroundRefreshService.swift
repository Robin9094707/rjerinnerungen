import BackgroundTasks
import UserNotifications

// Local notifications are responsible for exact reminder delivery.
// BGAppRefreshTask is deliberately only used for opportunistic maintenance.
enum BackgroundRefreshService {
    static let identifier = "eu.rjuhas.ultrareminders.refresh"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            schedule()
            let work = Task {
                _ = await UNUserNotificationCenter.current().pendingNotificationRequests()
                refreshTask.setTaskCompleted(success: !Task.isCancelled)
            }
            refreshTask.expirationHandler = { work.cancel() }
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = .now.addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

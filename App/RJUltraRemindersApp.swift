import SwiftData
import SwiftUI

@main
struct RJUltraRemindersApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var coordinator = ReminderCoordinator()

    private let container: ModelContainer = {
        do {
            return try ModelContainer(for: RJReminder.self)
        } catch {
            fatalError("SwiftData container could not be created: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(coordinator)
                .modelContainer(container)
        }
    }
}

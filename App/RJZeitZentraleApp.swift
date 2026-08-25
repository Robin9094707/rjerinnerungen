import SwiftUI
import UserNotifications

@main
struct RJZeitZentraleApp: App {
    @UIApplicationDelegateAdaptor(RJAppDelegate.self) private var appDelegate
    @State private var timerStore = TimerStore()
    @State private var appStore = AppDataStore()
    @State private var router = AppRouter()

    private let notificationDelegate: NotificationDelegate

    init() {
        let delegate = NotificationDelegate()
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate

        UserDefaults.standard.register(defaults: [
            "hapticsEnabled": true,
            "keepScreenAwake": false,
            "defaultSound": "glass_chime.wav",
            "iCloudSyncEnabled": false,
            "didCompleteOnboarding": false
        ])
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(timerStore)
                .environment(appStore)
                .environment(router)
                .tint(.cyan)
                .onOpenURL { router.handle($0) }
                .task {
                    let cloudResult = await ICloudSyncService.shared.bootstrap()
                    if cloudResult == .downloaded {
                        timerStore.reloadFromDisk()
                        appStore.reloadFromDisk()
                    }
                    async let timerBoot: Void = timerStore.bootstrap()
                    async let dataBoot: Void = appStore.bootstrap()
                    _ = await (timerBoot, dataBoot)
                }
        }
    }
}

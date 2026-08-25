import SwiftUI
import UIKit

struct RootView: View {
    @Environment(TimerStore.self) private var timerStore
    @Environment(AppDataStore.self) private var appStore
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = false

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab("Zentrale", systemImage: "sparkles.rectangle.stack.fill", value: .center) {
                DashboardView()
            }

            Tab("Planer", systemImage: "calendar", value: .planner) {
                PlannerView()
            }

            Tab("Timer", systemImage: "timer", value: .timers) {
                TimerHomeView()
            }

            Tab("Notizen", systemImage: "note.text", value: .notes) {
                NotesHomeView()
            }

            Tab("Mehr", systemImage: "square.grid.2x2.fill", value: .more) {
                MoreView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .fullScreenCover(
            isPresented: Binding(
                get: { !didCompleteOnboarding },
                set: { if !$0 { didCompleteOnboarding = true } }
            )
        ) {
            OnboardingView {
                didCompleteOnboarding = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .rjNotificationAction)) {
            appStore.handleNotificationAction($0)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                UIApplication.shared.isIdleTimerDisabled = keepScreenAwake && !timerStore.activeTimers.isEmpty
                NotificationService.shared.clearBadge()
                Task {
                    await timerStore.syncFromSystem()
                    await EventKitService.shared.refresh()
                }
            } else {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .onChange(of: keepScreenAwake) { _, enabled in
            UIApplication.shared.isIdleTimerDisabled = enabled && !timerStore.activeTimers.isEmpty
        }
        .onChange(of: timerStore.activeTimers.count) { _, count in
            UIApplication.shared.isIdleTimerDisabled = keepScreenAwake && count > 0
        }
        .alert(
            "RJ ZeitZentrale",
            isPresented: Binding(
                get: { appStore.lastError != nil || timerStore.lastError != nil },
                set: { visible in
                    if !visible {
                        appStore.lastError = nil
                        timerStore.lastError = nil
                    }
                }
            )
        ) {
            Button("OK") {
                appStore.lastError = nil
                timerStore.lastError = nil
            }
        } message: {
            Text(appStore.lastError ?? timerStore.lastError ?? "Unbekannter Fehler")
        }
    }
}

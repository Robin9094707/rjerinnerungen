import AlarmKit
import EventKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(AppDataStore.self) private var appStore
    @Environment(TimerStore.self) private var timerStore

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    @AppStorage("defaultSound") private var defaultSound = "glass_chime.wav"
    @AppStorage("didCompleteOnboarding") private var didCompleteOnboarding = true

    @State private var alarmService = AlarmKitService.shared
    @State private var notificationService = NotificationService.shared
    @State private var eventService = EventKitService.shared
    @State private var showDebug = false

    var body: some View {
        Form {
            Section("Systemhinweise") {
                permissionRow(
                    "Benachrichtigungen",
                    symbol: "app.badge.fill",
                    status: notificationText,
                    color: notificationService.authorizationStatus == .authorized ? .green : .orange
                ) {
                    Task { _ = await notificationService.requestAuthorization() }
                }

                permissionRow(
                    "AlarmKit-Wecker",
                    symbol: "alarm.waves.left.and.right.fill",
                    status: alarmText,
                    color: alarmService.authorizationState == .authorized ? .green : .orange
                ) {
                    Task { _ = await alarmService.requestAuthorization() }
                }

                Text("Dringende Erinnerungen können zeitkritisch zugestellt oder als echter AlarmKit-Wecker eskaliert werden. Apples Critical-Alerts-Sonderrecht ist bewusst nicht enthalten, weil es eine individuelle Freigabe von Apple benötigt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Apple Kalender & Erinnerungen") {
                permissionRow(
                    "Kalender",
                    symbol: "calendar",
                    status: eventAccessText,
                    color: hasEventAccess ? .green : .orange
                ) {
                    Task { _ = await eventService.requestEventAccess() }
                }
                permissionRow(
                    "Apple Erinnerungen",
                    symbol: "checklist.checked",
                    status: reminderAccessText,
                    color: hasReminderAccess ? .green : .orange
                ) {
                    Task { _ = await eventService.requestReminderAccess() }
                }
                Text("Die Verknüpfung ist optional. Ohne Zugriff funktionieren alle internen Erinnerungen, Notizen, Timer und Wecker weiter.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Bedienung") {
                Toggle("Haptisches Feedback", isOn: $hapticsEnabled)
                Toggle("Display bei laufendem Timer wach halten", isOn: $keepScreenAwake)
                Picker("Standard-Timerton", selection: $defaultSound) {
                    ForEach(TimerSoundCatalog.all) { sound in
                        Label(sound.title, systemImage: sound.symbol).tag(sound.fileName)
                    }
                }
                Button("Standardton testen", systemImage: "speaker.wave.2") {
                    SoundPlayer.shared.preview(defaultSound)
                }
            }

            Section("Systemintegration") {
                LabeledContent("Liquid Glass", value: "Aktiv")
                LabeledContent("Dynamic Island", value: "AlarmKit")
                LabeledContent("Live Activities", value: "Aktiv")
                LabeledContent("Widgets", value: "Quick Capture & Timer")
                LabeledContent("Control Center", value: "5 Min & Pomodoro")
                LabeledContent("Siri / Kurzbefehle", value: "Timer")
            }

            Section("Daten & Diagnose") {
                if let url = appStore.exportURL() {
                    ShareLink(item: url) {
                        Label("Planer, Notizen und Wecker exportieren", systemImage: "square.and.arrow.up")
                    }
                }
                if let url = timerStore.exportURL() {
                    ShareLink(item: url) {
                        Label("Timer-Daten exportieren", systemImage: "timer")
                    }
                }
                Button("Debug-Konsole", systemImage: "ladybug.fill") { showDebug = true }
                Button("Onboarding erneut zeigen", systemImage: "sparkles") {
                    didCompleteOnboarding = false
                }
            }

            Section("RJ ZeitZentrale") {
                LabeledContent("Version", value: "1.0 (1)")
                LabeledContent("Minimum", value: "iOS 26.1")
                LabeledContent("Datenmodell", value: "lokal & privat")
            }
        }
        .navigationTitle("Einstellungen")
        .sheet(isPresented: $showDebug) { DebugConsoleView() }
        .task {
            alarmService.refreshAuthorization()
            await notificationService.refreshAuthorization()
            eventService.refreshAuthorization()
        }
    }

    private func permissionRow(
        _ title: String,
        symbol: String,
        status: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            Button(status, action: action)
                .foregroundStyle(color)
        }
    }

    private var alarmText: String {
        switch alarmService.authorizationState {
        case .authorized: "Erlaubt"
        case .denied: "Abgelehnt"
        case .notDetermined: "Erlauben"
        @unknown default: "Unbekannt"
        }
    }

    private var notificationText: String {
        switch notificationService.authorizationStatus {
        case .authorized, .provisional, .ephemeral: "Erlaubt"
        case .denied: "Abgelehnt"
        case .notDetermined: "Erlauben"
        @unknown default: "Unbekannt"
        }
    }

    private var hasEventAccess: Bool {
        eventService.eventAuthorization == .fullAccess || eventService.eventAuthorization == .authorized
    }
    private var hasReminderAccess: Bool {
        eventService.reminderAuthorization == .fullAccess || eventService.reminderAuthorization == .authorized
    }
    private var eventAccessText: String { hasEventAccess ? "Verbunden" : "Verbinden" }
    private var reminderAccessText: String { hasReminderAccess ? "Verbunden" : "Verbinden" }
}

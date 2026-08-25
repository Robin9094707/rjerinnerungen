import AlarmKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers
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
    @State private var locationService = LocationService.shared
    @State private var cloudService = ICloudSyncService.shared
    @State private var soundStore = CustomSoundStore.shared
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

            Section("Standort-Erinnerungen") {
                permissionRow(
                    "Ortungsdienste",
                    symbol: "location.fill",
                    status: locationService.statusText,
                    color: locationService.isAlwaysAuthorized ? .green : .orange
                ) {
                    locationService.requestLocationReminderAccess()
                }
                Text("Für Hinweise beim Betreten oder Verlassen eines Ortes benötigt iOS die Freigabe „Immer“. Die App verfolgt deinen Standort nicht dauerhaft; iOS überwacht nur deine gespeicherten Radien.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Optionale iCloud-Synchronisierung") {
                Toggle(
                    "Daten und Medien synchronisieren",
                    isOn: Binding(
                        get: { cloudService.isEnabled },
                        set: { enabled in
                            Task {
                                do {
                                    let result = try await cloudService.setEnabled(enabled)
                                    if result == .downloaded {
                                        appStore.reloadFromDisk()
                                        timerStore.reloadFromDisk()
                                    }
                                } catch {
                                    appStore.lastError = error.localizedDescription
                                }
                            }
                        }
                    )
                )
                .disabled(!cloudService.isAvailable && !cloudService.isEnabled)
                LabeledContent("Verfügbarkeit", value: cloudService.isAvailable ? "Bereit" : "Nicht in Signatur")
                LabeledContent("Status", value: cloudService.lastStatus)
                if cloudService.isEnabled {
                    Button("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath.icloud") {
                        Task {
                            do {
                                let result = try await cloudService.synchronize()
                                if result == .downloaded {
                                    appStore.reloadFromDisk()
                                    timerStore.reloadFromDisk()
                                }
                            } catch {
                                appStore.lastError = error.localizedDescription
                            }
                        }
                    }
                    .disabled(cloudService.isSynchronizing)
                }
                Text("Bei normalem Sideloading bleibt iCloud aus. Es funktioniert nur, wenn dein eigenes Provisioning Profile den passenden iCloud-Container enthält. Beim ersten Aktivieren wird eine vorhandene Cloud-Kopie übernommen; andernfalls werden lokale Daten hochgeladen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Bedienung") {
                Toggle("Haptisches Feedback", isOn: $hapticsEnabled)
                Toggle("Display bei laufendem Timer wach halten", isOn: $keepScreenAwake)
                Picker("Standard-Timerton", selection: $defaultSound) {
                    ForEach(soundStore.catalogItems) { sound in
                        Label(sound.title, systemImage: sound.symbol).tag(sound.fileName)
                    }
                }
                Button("Standardton testen", systemImage: "speaker.wave.2") {
                    SoundPlayer.shared.preview(defaultSound)
                }
                NavigationLink {
                    CustomSoundLibraryView()
                } label: {
                    LabeledContent("Eigene Wecktöne", value: "\(soundStore.sounds.count)")
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
                LabeledContent("Version", value: "2.0 (2)")
                LabeledContent("Minimum", value: "iOS 26.1")
                LabeledContent("Datenmodell", value: "lokal • iCloud optional")
            }
        }
        .navigationTitle("Einstellungen")
        .sheet(isPresented: $showDebug) { DebugConsoleView() }
        .task {
            alarmService.refreshAuthorization()
            await notificationService.refreshAuthorization()
            eventService.refreshAuthorization()
            locationService.requestCurrentLocation()
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
        eventService.eventAuthorization == .fullAccess
    }
    private var hasReminderAccess: Bool {
        eventService.reminderAuthorization == .fullAccess
    }
    private var eventAccessText: String { hasEventAccess ? "Verbunden" : "Verbinden" }
    private var reminderAccessText: String { hasReminderAccess ? "Verbunden" : "Verbinden" }
}

struct CustomSoundLibraryView: View {
    @Environment(AppDataStore.self) private var appStore
    @Environment(TimerStore.self) private var timerStore
    @State private var soundStore = CustomSoundStore.shared
    @State private var showImporter = false
    @State private var pendingDelete: CustomAlarmSound?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Mitgeliefert") {
                ForEach(TimerSoundCatalog.all) { sound in
                    Button {
                        SoundPlayer.shared.preview(sound.fileName)
                    } label: {
                        Label(sound.title, systemImage: sound.symbol)
                    }
                }
            }

            Section {
                if soundStore.sounds.isEmpty {
                    ContentUnavailableView(
                        "Keine eigenen Töne",
                        systemImage: "music.note.list",
                        description: Text("Importiere WAV, AIFF oder CAF mit höchstens 30 Sekunden.")
                    )
                }
                ForEach(soundStore.sounds) { sound in
                    HStack {
                        Button {
                            SoundPlayer.shared.preview(sound.fileName)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(sound.title)
                                Text(DurationFormat.clock(sound.duration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) { pendingDelete = sound } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            } header: {
                Text("Eigene Töne")
            } footer: {
                Text("Aktive Timer behalten ihren Ton. Ein verwendeter Ton kann deshalb erst gelöscht werden, wenn der Timer beendet ist.")
            }
        }
        .navigationTitle("Wecktöne")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Importieren", systemImage: "plus") { showImporter = true }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                let sound = try soundStore.importSound(from: url)
                SoundPlayer.shared.preview(sound.fileName)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .alert("Eigenen Ton löschen?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Abbrechen", role: .cancel) { pendingDelete = nil }
            Button("Löschen", role: .destructive) {
                guard let sound = pendingDelete else { return }
                delete(sound)
                pendingDelete = nil
            }
        } message: {
            Text("Wecker und Presets, die diesen Ton verwenden, werden auf den Systemton umgestellt.")
        }
        .alert("Wecktöne", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unbekannter Fehler")
        }
    }

    private func delete(_ sound: CustomAlarmSound) {
        if timerStore.activeTimers.contains(where: { $0.soundFile == sound.fileName }) {
            errorMessage = "Dieser Ton wird gerade von einem aktiven Timer verwendet. Beende den Timer zuerst."
            return
        }
        SoundPlayer.shared.stop()
        Task {
            await appStore.replaceSoundReferences(sound.fileName)
            timerStore.replaceSoundReferences(sound.fileName)
            if UserDefaults.standard.string(forKey: "defaultSound") == sound.fileName {
                UserDefaults.standard.set("default", forKey: "defaultSound")
            }
            do { try soundStore.delete(sound) }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

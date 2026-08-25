import EventKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Query(sort: \RJReminder.dueDate, order: .forward) private var reminders: [RJReminder]
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderCoordinator.self) private var coordinator

    @State private var testPriority: ReminderPriority = .high
    @State private var showingExporter = false
    @State private var exportDocument = ReminderBackupDocument(backup: ReminderBackup(reminders: []))
    @State private var showingImporter = false
    @State private var isImportingApple = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Benachrichtigungen") {
                    statusRow("Berechtigung", value: authorizationText(coordinator.notificationStatus.authorizationStatus), symbol: "bell.badge")
                    statusRow("Time Sensitive", value: settingText(coordinator.notificationStatus.timeSensitiveSetting), symbol: "exclamationmark.triangle")
                    statusRow("Critical Alerts", value: settingText(coordinator.notificationStatus.criticalAlertSetting), symbol: "bolt.shield")
                    statusRow("Geplante Requests", value: "\(coordinator.pendingNotificationCount)", symbol: "calendar.badge.clock")

                    Button("Benachrichtigungen erlauben") {
                        Task { await coordinator.requestNotifications() }
                    }

                    Button("Critical-Alert-Zugriff anfragen") {
                        Task {
                            do {
                                _ = try await NotificationService.shared.requestCriticalAuthorization()
                                await coordinator.refreshSystemStatus()
                            } catch {
                                coordinator.errorMessage = "Critical Alerts benötigen zusätzlich das spezielle Apple-Entitlement. \(error.localizedDescription)"
                            }
                        }
                    }

                    Button("iOS-Benachrichtigungseinstellungen öffnen") { coordinator.openSystemNotificationSettings() }

                    Picker("Test-Priorität", selection: $testPriority) {
                        ForEach(ReminderPriority.allCases) { Text($0.title).tag($0) }
                    }
                    Button("Test in 4 Sekunden senden") {
                        Task {
                            do { try await NotificationService.shared.scheduleTest(priority: testPriority) }
                            catch { coordinator.errorMessage = error.localizedDescription }
                        }
                    }
                }

                Section("Apple Erinnerungen") {
                    statusRow("EventKit", value: eventKitStatusText(AppleRemindersService.shared.authorizationStatus), symbol: "checklist")
                    Button {
                        importFromApple()
                    } label: {
                        HStack {
                            Label("Apple-Erinnerungen importieren", systemImage: "square.and.arrow.down")
                            if isImportingApple { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isImportingApple)
                    Text("Import liest nur nach deiner Freigabe. Bereits importierte Einträge werden über ihre Apple-ID nicht erneut angelegt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Backup & Migration") {
                    Button("JSON-Backup exportieren") {
                        let backup = ReminderBackup(reminders: reminders.map(ReminderTransferRecord.init))
                        exportDocument = ReminderBackupDocument(backup: backup)
                        showingExporter = true
                    }
                    Button("JSON-Backup importieren") { showingImporter = true }
                    Button("Benachrichtigungen neu aufbauen") {
                        Task { await coordinator.rebuildNotifications(for: reminders) }
                    }
                }

                Section("Live Activities") {
                    statusRow("ActivityKit", value: LiveActivityService.shared.activitiesEnabled ? "Verfügbar" : "Deaktiviert", symbol: "waveform.path.ecg.rectangle")
                    Text("Live Activities sind optional pro Erinnerung. Sie zeigen den Countdown auf Sperrbildschirm und Dynamic Island; normale Notifications bleiben unabhängig davon aktiv.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Diagnose") {
                    NavigationLink("Debug-Konsole") { DebugConsoleView() }
                    Button("Systemstatus aktualisieren") { Task { await coordinator.refreshSystemStatus() } }
                }

                Section("Über RJ Ultra Erinnerungen") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Datenhaltung", value: "Lokal via SwiftData")
                    Text("Critical Alerts, die Stummmodus und Fokus übergehen, funktionieren nur mit Apples besonderem Critical-Alert-Entitlement. Ohne dieses Entitlement fällt Ultra automatisch auf Time Sensitive zurück.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Mehr")
            .task { await coordinator.refreshSystemStatus() }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "RJ-Ultra-Erinnerungen-Backup.json"
            ) { result in
                if case .failure(let error) = result { coordinator.errorMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { importBackup(from: url) }
                case .failure(let error): coordinator.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func importFromApple() {
        isImportingApple = true
        Task { @MainActor in
            defer { isImportingApple = false }
            do {
                let records = try await AppleRemindersService.shared.fetchImportableReminders()
                let existingExternalIDs = Set(reminders.compactMap(\.externalIdentifier))
                var imported = 0
                for record in records where record.externalIdentifier.map({ !existingExternalIDs.contains($0) }) ?? true {
                    let model = record.makeModel()
                    modelContext.insert(model)
                    imported += 1
                }
                try modelContext.save()
                coordinator.message = "\(imported) Apple-Erinnerung(en) importiert."
            } catch {
                coordinator.errorMessage = error.localizedDescription
            }
        }
    }

    private func importBackup(from url: URL) {
        Task { @MainActor in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let backup = try JSONDecoder.rjBackup.decode(ReminderBackup.self, from: data)
                let existingIDs = Set(reminders.map(\.id))
                var added = 0
                for record in backup.reminders where !existingIDs.contains(record.id) {
                    modelContext.insert(record.makeModel())
                    added += 1
                }
                try modelContext.save()
                coordinator.message = "\(added) Erinnerung(en) aus Backup importiert."
            } catch {
                coordinator.errorMessage = error.localizedDescription
            }
        }
    }

    private func statusRow(_ label: String, value: String, symbol: String) -> some View {
        LabeledContent {
            Text(value).foregroundStyle(.secondary)
        } label: {
            Label(label, systemImage: symbol)
        }
    }

    private func authorizationText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "Nicht gefragt"
        case .denied: "Abgelehnt"
        case .authorized: "Erlaubt"
        case .provisional: "Vorläufig"
        case .ephemeral: "Temporär"
        @unknown default: "Unbekannt"
        }
    }

    private func settingText(_ status: UNNotificationSetting) -> String {
        switch status {
        case .notSupported: "Nicht unterstützt"
        case .disabled: "Aus"
        case .enabled: "An"
        @unknown default: "Unbekannt"
        }
    }

    private func eventKitStatusText(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "Nicht gefragt"
        case .restricted: "Eingeschränkt"
        case .denied: "Abgelehnt"
        case .fullAccess: "Vollzugriff"
        case .writeOnly: "Nur Schreiben"
        @unknown default: "Unbekannt"
        }
    }
}

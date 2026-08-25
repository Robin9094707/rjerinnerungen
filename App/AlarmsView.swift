import SwiftUI
import UniformTypeIdentifiers

struct AlarmsView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var showNewAlarm = false
    @State private var editingAlarm: AlarmRecord?
    @State private var pendingDelete: AlarmRecord?

    var body: some View {
        ZStack {
            UltraBackground()
            if store.alarms.isEmpty {
                ContentUnavailableView(
                    "Noch keine Wecker",
                    systemImage: "alarm.waves.left.and.right",
                    description: Text("AlarmKit-Wecker erscheinen prominent im iOS-System und unterstützen Snooze.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 13) {
                        ForEach(store.alarms.sorted(by: alarmSort)) { alarm in
                            alarmCard(alarm)
                        }
                    }
                    .padding()
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Wecker")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewAlarm = true
                } label: {
                    Label("Neuer Wecker", systemImage: "plus")
                }
                .buttonStyle(.glassProminent)
            }
        }
        .sheet(isPresented: $showNewAlarm) { AlarmEditorView() }
        .sheet(item: $editingAlarm) { AlarmEditorView(alarm: $0) }
        .alert("Wecker löschen?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Abbrechen", role: .cancel) { pendingDelete = nil }
            Button("Löschen", role: .destructive) {
                if let alarm = pendingDelete { store.deleteAlarm(alarm.id) }
                pendingDelete = nil
            }
        } message: {
            Text("Der Wecker wird auch aus AlarmKit, Lock Screen und Dynamic Island entfernt.")
        }
        .onChange(of: router.showNewAlarm) { _, requested in
            if requested {
                showNewAlarm = true
                router.showNewAlarm = false
            }
        }
        .onChange(of: router.requestedAlarmID) { _, id in
            guard let id, let value = store.alarms.first(where: { $0.id == id }) else { return }
            editingAlarm = value
            router.requestedAlarmID = nil
        }
    }

    private func alarmCard(_ alarm: AlarmRecord) -> some View {
        Button {
            editingAlarm = alarm
        } label: {
            UltraGlassCard {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(alarm.accent.color.opacity(0.16))
                            .frame(width: 48, height: 48)
                        Image(systemName: "alarm.waves.left.and.right.fill")
                            .foregroundStyle(alarm.accent.color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(alarm.fireDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(alarm.title).font(.headline)
                        Text(alarm.repeatSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(
                        "Aktiv",
                        isOn: Binding(
                            get: { alarm.enabled },
                            set: { enabled in
                                Task { await store.setAlarmEnabled(alarm.id, enabled: enabled) }
                            }
                        )
                    )
                    .labelsHidden()
                    .tint(alarm.accent.color)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Bearbeiten", systemImage: "pencil") { editingAlarm = alarm }
            Button("Löschen", systemImage: "trash", role: .destructive) {
                pendingDelete = alarm
            }
        }
    }

    private func alarmSort(_ left: AlarmRecord, _ right: AlarmRecord) -> Bool {
        (left.nextFireDate() ?? .distantFuture) < (right.nextFireDate() ?? .distantFuture)
    }
}

struct AlarmEditorView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var alarm: AlarmRecord
    @State private var repeating: Bool
    @State private var soundStore = CustomSoundStore.shared
    @State private var showSoundImporter = false
    @State private var showDiscardConfirmation = false
    @State private var importError: String?

    private let original: AlarmRecord

    init(alarm: AlarmRecord? = nil) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        let defaultDate = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        let value = alarm ?? AlarmRecord(title: "Guten Morgen", fireDate: defaultDate)
        original = value
        _alarm = State(initialValue: value)
        _repeating = State(initialValue: value.isRepeating)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Zeit",
                        selection: $alarm.fireDate,
                        in: repeating ? Date.distantPast...Date.distantFuture : Date.now...Date.distantFuture,
                        displayedComponents: repeating ? .hourAndMinute : [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    TextField("Name", text: $alarm.title)
                }

                Section("Wiederholung") {
                    Toggle("Wiederholen", isOn: $repeating)
                    if repeating {
                        weekdayPicker
                        Text(alarm.repeatSummary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Weckverhalten") {
                    Stepper("Snooze: \(alarm.snoozeMinutes) Minuten", value: $alarm.snoozeMinutes, in: 1...30)
                    Stepper(
                        alarm.preAlertMinutes == 0
                            ? "Keine Voranzeige"
                            : "Voranzeige: \(alarm.preAlertMinutes) Minuten",
                        value: $alarm.preAlertMinutes,
                        in: 0...60,
                        step: 5
                    )
                    Picker("Ton", selection: $alarm.soundFile) {
                        ForEach(soundStore.catalogItems) { sound in
                            Label(sound.title, systemImage: sound.symbol).tag(sound.fileName)
                        }
                    }
                    Button("Ton testen", systemImage: "speaker.wave.2.fill") {
                        SoundPlayer.shared.preview(alarm.soundFile)
                    }
                    Button("Eigenen Ton importieren", systemImage: "square.and.arrow.down") {
                        showSoundImporter = true
                    }
                    Text("WAV, AIFF oder CAF • maximal 30 Sekunden. Die Datei wird in Apples Library/Sounds-Bereich der App kopiert.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Farbe") {
                    HStack {
                        ForEach(TimerAccentToken.allCases) { accent in
                            Button {
                                alarm.accent = accent
                            } label: {
                                AccentDot(accent: accent, selected: alarm.accent == accent)
                            }
                            .buttonStyle(.plain)
                            Spacer(minLength: 5)
                        }
                    }
                }

                Section {
                    Label(
                        "Dieser Wecker verwendet AlarmKit. iOS zeigt ihn prominent mit Systemton, Snooze, Lock-Screen-Oberfläche und Dynamic Island.",
                        systemImage: "checkmark.shield.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(alarm.title.isEmpty ? "Neuer Wecker" : "Wecker")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: repeating) { _, value in
                if value && alarm.weekdays.isEmpty {
                    alarm.weekdays = [.monday, .tuesday, .wednesday, .thursday, .friday]
                } else if !value {
                    alarm.weekdays = []
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        if alarm != original || repeating != original.isRepeating {
                            showDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        if !repeating { alarm.weekdays = [] }
                        Task {
                            let saved = await store.upsertAlarm(alarm)
                            if saved { dismiss() }
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(repeating && alarm.weekdays.isEmpty)
                }
            }
            .interactiveDismissDisabled(alarm != original || repeating != original.isRepeating)
            .fileImporter(
                isPresented: $showSoundImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let url = try result.get().first else { return }
                    let imported = try soundStore.importSound(from: url)
                    alarm.soundFile = imported.fileName
                    SoundPlayer.shared.preview(imported.fileName)
                } catch {
                    importError = error.localizedDescription
                }
            }
            .alert("Änderungen verwerfen?", isPresented: $showDiscardConfirmation) {
                Button("Weiter bearbeiten", role: .cancel) {}
                Button("Verwerfen", role: .destructive) { dismiss() }
            } message: {
                Text("Nicht gespeicherte Wecker-Einstellungen gehen verloren.")
            }
            .alert("Eigener Weckerton", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "Unbekannter Fehler")
            }
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 7) {
            ForEach(RJWeekday.allCases) { day in
                Button {
                    if alarm.weekdays.contains(day) {
                        alarm.weekdays.removeAll { $0 == day }
                    } else {
                        alarm.weekdays.append(day)
                    }
                    Haptics.selection()
                } label: {
                    Text(day.shortTitle)
                        .font(.caption.bold())
                        .frame(width: 34, height: 34)
                        .background(
                            alarm.weekdays.contains(day) ? AnyShapeStyle(alarm.accent.color.gradient) : AnyShapeStyle(.clear),
                            in: Circle()
                        )
                        .foregroundStyle(alarm.weekdays.contains(day) ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.shortTitle)
            }
        }
    }
}

import CoreLocation
import MapKit
import SwiftUI

struct ReminderEditorView: View {
    private enum EndMode: String, CaseIterable, Identifiable {
        case never = "Nie"
        case date = "Enddatum"
        case count = "Anzahl"
        var id: String { rawValue }
    }

    private struct LeadOption: Identifiable {
        let seconds: Int
        let title: String
        var id: Int { seconds }
    }

    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var reminder: ReminderItem
    @State private var recurrenceRule: RJRecurrenceRule
    @State private var hasDueDate: Bool
    @State private var exportToSystem = false
    @State private var tagsText: String
    @State private var endMode: EndMode
    @State private var showLocationPicker = false
    @State private var showLocationRemoveConfirmation = false
    @State private var showDiscardConfirmation = false
    @State private var isSaving = false

    private let original: ReminderItem
    private let leadOptions = [
        LeadOption(seconds: 0, title: "Zur Fälligkeit"),
        LeadOption(seconds: 300, title: "5 Min. vorher"),
        LeadOption(seconds: 900, title: "15 Min. vorher"),
        LeadOption(seconds: 1_800, title: "30 Min. vorher"),
        LeadOption(seconds: 3_600, title: "1 Std. vorher"),
        LeadOption(seconds: 7_200, title: "2 Std. vorher"),
        LeadOption(seconds: 86_400, title: "1 Tag vorher"),
        LeadOption(seconds: 172_800, title: "2 Tage vorher")
    ]

    init(reminder: ReminderItem? = nil) {
        let value = reminder ?? ReminderItem(
            title: "",
            dueDate: Calendar.current.date(byAdding: .hour, value: 1, to: .now)
        )
        original = value
        let rule = value.effectiveRecurrence
        _reminder = State(initialValue: value)
        _recurrenceRule = State(initialValue: rule)
        _hasDueDate = State(initialValue: value.dueDate != nil)
        _tagsText = State(initialValue: value.tags.map { "#\($0)" }.joined(separator: " "))
        if rule.occurrenceLimit != nil { _endMode = State(initialValue: .count) }
        else if rule.endDate != nil { _endMode = State(initialValue: .date) }
        else { _endMode = State(initialValue: .never) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Erinnerung") {
                    TextField("Titel", text: $reminder.title)
                    TextField("Notizen und Details", text: $reminder.details, axis: .vertical)
                        .lineLimit(2...8)
                    TextField("Liste", text: $reminder.listName)
                    TextField("Tags, z. B. #arbeit #wichtig", text: $tagsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Start") {
                    Toggle("Datum festlegen", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Startdatum", selection: dueDateBinding, displayedComponents: .date)
                        Toggle("Mit Uhrzeit", isOn: $reminder.hasTime)
                        if reminder.hasTime {
                            DatePicker("Startzeit", selection: dueDateBinding, displayedComponents: .hourAndMinute)
                        } else {
                            Label("Ganztägige Hinweise werden um 09:00 Uhr geplant.", systemImage: "sun.max")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if hasDueDate {
                    recurrenceSection
                    notificationSection
                }

                locationSection

                Section("Priorität & Verhalten") {
                    Picker("Priorität", selection: $reminder.priority) {
                        ForEach(RJPriority.allCases) { value in
                            Label(value.title, systemImage: value.symbol).tag(value)
                        }
                    }

                    Toggle("Benachrichtigung", isOn: $reminder.notificationEnabled)
                        .disabled(!hasDueDate && reminder.locationTrigger == nil)

                    Stepper(
                        "Später erinnern: \(reminder.snoozeMinutes) Min.",
                        value: $reminder.snoozeMinutes,
                        in: 1...120
                    )

                    Toggle("Als Systemwecker eskalieren", isOn: $reminder.alarmEscalation)
                        .disabled(!alarmEscalationAllowed)

                    if reminder.alarmEscalation {
                        Label(
                            "AlarmKit ist für einen einmaligen Zeitpunkt aktiv. Sollte AlarmKit ablehnen, speichert die App trotzdem und plant automatisch einen normalen Hinweis.",
                            systemImage: "bell.and.waves.left.and.right.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    } else if reminder.priority == .high || reminder.priority == .urgent {
                        Label(
                            "Hohe Prioritäten werden als zeitkritisch angefordert. iOS berücksichtigt dabei deine Fokus-Einstellungen.",
                            systemImage: "exclamationmark.shield"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Apple-Integration") {
                    Toggle("Auch in Apple Erinnerungen sichern", isOn: $exportToSystem)
                        .disabled(reminder.systemReminderIdentifier != nil)
                    if reminder.systemReminderIdentifier != nil {
                        Label("Mit Apple Erinnerungen verknüpft", systemImage: "checkmark.icloud.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle(reminder.title.isEmpty ? "Neue Erinnerung" : "Erinnerung")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasUnsavedChanges)
            .onChange(of: recurrenceRule.frequency) { _, value in
                if value != .weekly { recurrenceRule.weekdays = [] }
                if value == .never {
                    recurrenceRule.endDate = nil
                    recurrenceRule.occurrenceLimit = nil
                    endMode = .never
                }
                if recurrenceRule.isRepeating { reminder.alarmEscalation = false }
            }
            .onChange(of: endMode) { _, value in
                switch value {
                case .never:
                    recurrenceRule.endDate = nil
                    recurrenceRule.occurrenceLimit = nil
                case .date:
                    recurrenceRule.occurrenceLimit = nil
                    recurrenceRule.endDate = recurrenceRule.endDate
                        ?? Calendar.current.date(byAdding: .month, value: 1, to: dueDateBinding.wrappedValue)
                case .count:
                    recurrenceRule.endDate = nil
                    recurrenceRule.occurrenceLimit = recurrenceRule.occurrenceLimit ?? 10
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: requestDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .buttonStyle(.glassProminent)
                        .disabled(
                            isSaving
                            || reminder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Sichere …")
                        .padding(22)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                }
            }
            .alert("Änderungen verwerfen?", isPresented: $showDiscardConfirmation) {
                Button("Weiter bearbeiten", role: .cancel) {}
                Button("Verwerfen", role: .destructive) { dismiss() }
            } message: {
                Text("Nicht gespeicherte Änderungen gehen verloren.")
            }
            .sheet(isPresented: $showLocationPicker) {
                ReminderLocationPickerView(initial: reminder.locationTrigger) { location in
                    reminder.locationTrigger = location
                    reminder.notificationEnabled = true
                }
            }
        }
    }

    private var recurrenceSection: some View {
        Section("Individuelle Wiederholung") {
            Picker("Rhythmus", selection: $recurrenceRule.frequency) {
                ForEach(RJRecurrenceFrequency.allCases) { value in Text(value.title).tag(value) }
            }
            if recurrenceRule.isRepeating {
                Stepper(
                    "Alle \(recurrenceRule.interval) \(recurrenceRule.frequency.unitTitle)",
                    value: $recurrenceRule.interval,
                    in: 1...99
                )
                if recurrenceRule.frequency == .weekly {
                    weekdayPicker
                }
                Picker("Ende", selection: $endMode) {
                    ForEach(EndMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                if endMode == .date {
                    DatePicker(
                        "Enddatum",
                        selection: recurrenceEndDateBinding,
                        in: dueDateBinding.wrappedValue...Date.distantFuture,
                        displayedComponents: .date
                    )
                } else if endMode == .count {
                    Stepper(
                        "Nach \(recurrenceRule.occurrenceLimit ?? 10) Terminen",
                        value: occurrenceLimitBinding,
                        in: 2...999
                    )
                }
                Label(recurrenceRule.summary, systemImage: "repeat")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var notificationSection: some View {
        Section("Vorwarnungen") {
            ForEach(leadOptions) { option in
                Toggle(option.title, isOn: leadTimeBinding(option.seconds))
            }
            Text("iOS hält höchstens eine begrenzte Anzahl geplanter Hinweise bereit. RJ ZeitZentrale lädt beim Öffnen automatisch die nächsten Wiederholungen nach.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var locationSection: some View {
        Section("Ort") {
            if let location = reminder.locationTrigger {
                Label(location.summary, systemImage: location.event.symbol)
                Text(location.address).font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Button("Bearbeiten", systemImage: "map") { showLocationPicker = true }
                    Spacer()
                    Button("Entfernen", systemImage: "trash", role: .destructive) {
                        showLocationRemoveConfirmation = true
                    }
                }
            } else {
                Button("Orts-Erinnerung hinzufügen", systemImage: "location.circle.fill") {
                    showLocationPicker = true
                }
            }
            Text("iOS kann beim Betreten oder Verlassen eines Radius erinnern. Ein standortabhängiger AlarmKit-Wecker ist von Apple nicht vorgesehen; deshalb erscheint ein zeitkritischer Hinweis.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .alert("Orts-Auslöser entfernen?", isPresented: $showLocationRemoveConfirmation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Entfernen", role: .destructive) { reminder.locationTrigger = nil }
        } message: {
            Text("Die gespeicherte Zeit-Erinnerung bleibt erhalten; nur der Standort-Radius wird entfernt.")
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(RJWeekday.allCases) { day in
                Button {
                    if recurrenceRule.weekdays.contains(day) {
                        recurrenceRule.weekdays.removeAll { $0 == day }
                    } else {
                        recurrenceRule.weekdays.append(day)
                    }
                    Haptics.selection()
                } label: {
                    Text(day.shortTitle)
                        .font(.caption.bold())
                        .frame(width: 34, height: 34)
                        .background(
                            recurrenceRule.weekdays.contains(day)
                                ? AnyShapeStyle(Color.cyan.gradient)
                                : AnyShapeStyle(Color.secondary.opacity(0.1)),
                            in: Circle()
                        )
                        .foregroundStyle(recurrenceRule.weekdays.contains(day) ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.fullTitle)
            }
        }
    }

    private var alarmEscalationAllowed: Bool {
        hasDueDate
            && reminder.dueDate.map { $0 > .now } == true
            && !recurrenceRule.isRepeating
            && reminder.locationTrigger == nil
    }

    private var hasUnsavedChanges: Bool {
        reminder != original
            || recurrenceRule != original.effectiveRecurrence
            || hasDueDate != (original.dueDate != nil)
            || tagsText != original.tags.map { "#\($0)" }.joined(separator: " ")
            || exportToSystem
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { reminder.dueDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now },
            set: { reminder.dueDate = $0 }
        )
    }

    private var recurrenceEndDateBinding: Binding<Date> {
        Binding(
            get: {
                recurrenceRule.endDate
                    ?? Calendar.current.date(byAdding: .month, value: 1, to: dueDateBinding.wrappedValue)
                    ?? dueDateBinding.wrappedValue
            },
            set: { recurrenceRule.endDate = $0 }
        )
    }

    private var occurrenceLimitBinding: Binding<Int> {
        Binding(
            get: { recurrenceRule.occurrenceLimit ?? 10 },
            set: { recurrenceRule.occurrenceLimit = $0 }
        )
    }

    private func leadTimeBinding(_ seconds: Int) -> Binding<Bool> {
        Binding(
            get: { reminder.notificationLeadTimes.contains(seconds) },
            set: { enabled in
                if enabled { reminder.notificationLeadTimes.append(seconds) }
                else if seconds != 0 { reminder.notificationLeadTimes.removeAll { $0 == seconds } }
                reminder.notificationLeadTimes = Array(Set(reminder.notificationLeadTimes + [0])).sorted()
            }
        )
    }

    private func requestDismiss() {
        if hasUnsavedChanges { showDiscardConfirmation = true }
        else { dismiss() }
    }

    private func save() {
        if !hasDueDate {
            reminder.dueDate = nil
            reminder.recurrence = .never
            reminder.recurrenceRule = nil
            reminder.alarmEscalation = false
        } else {
            if recurrenceRule.frequency == .weekly, recurrenceRule.weekdays.isEmpty,
               let dueDate = reminder.dueDate,
               let weekday = RJWeekday(rawValue: Calendar.current.component(.weekday, from: dueDate)) {
                recurrenceRule.weekdays = [weekday]
            }
            reminder.recurrence = .never
            reminder.recurrenceRule = recurrenceRule
        }
        if !alarmEscalationAllowed { reminder.alarmEscalation = false }
        if reminder.alarmEscalation { reminder.priority = .urgent }
        reminder.tags = tagsText.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        isSaving = true
        Task {
            let saved = await store.upsertReminder(reminder, exportToSystem: exportToSystem)
            isSaving = false
            if saved { dismiss() }
        }
    }
}

struct ReminderLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var locationService = LocationService.shared
    @State private var query = ""
    @State private var results: [RJPlaceResult] = []
    @State private var selected: RJPlaceResult?
    @State private var customName: String
    @State private var radius: Double
    @State private var event: RJLocationEvent
    @State private var repeats: Bool
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var camera: MapCameraPosition = .automatic

    private let onSave: (ReminderLocationTrigger) -> Void

    init(initial: ReminderLocationTrigger?, onSave: @escaping (ReminderLocationTrigger) -> Void) {
        self.onSave = onSave
        if let initial {
            let place = RJPlaceResult(
                id: "initial-\(initial.latitude),\(initial.longitude)",
                name: initial.name,
                address: initial.address,
                latitude: initial.latitude,
                longitude: initial.longitude
            )
            _selected = State(initialValue: place)
            _customName = State(initialValue: initial.name)
            _radius = State(initialValue: initial.radius)
            _event = State(initialValue: initial.event)
            _repeats = State(initialValue: initial.repeats)
            _camera = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: initial.latitude, longitude: initial.longitude),
                latitudinalMeters: max(800, initial.radius * 4),
                longitudinalMeters: max(800, initial.radius * 4)
            )))
        } else {
            _customName = State(initialValue: "")
            _radius = State(initialValue: 150)
            _event = State(initialValue: .enter)
            _repeats = State(initialValue: true)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ort suchen") {
                    HStack {
                        TextField("Adresse oder Ort", text: $query)
                            .submitLabel(.search)
                            .onSubmit(search)
                        Button(action: search) {
                            if isSearching { ProgressView() }
                            else { Image(systemName: "magnifyingglass") }
                        }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                    }
                    Button("Aktuellen Standort verwenden", systemImage: "location.fill") {
                        locationService.requestCurrentLocation()
                        if let place = locationService.currentPlace() { select(place) }
                    }
                    if !locationService.isAlwaysAuthorized {
                        Button("Standort immer erlauben", systemImage: "location.circle") {
                            locationService.requestLocationReminderAccess()
                        }
                        Text("Für zuverlässige Hinweise bei geschlossener App benötigt iOS die Freigabe „Immer“ und aktivierte Hintergrundaktualisierung.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !results.isEmpty {
                    Section("Treffer") {
                        ForEach(results) { place in
                            Button {
                                select(place)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(place.name).foregroundStyle(.primary)
                                    Text(place.address).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let selected {
                    Section("Ausgewählter Ort") {
                        Map(position: $camera) {
                            Marker(
                                selected.name,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: selected.latitude,
                                    longitude: selected.longitude
                                )
                            )
                        }
                        .frame(height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        TextField("Eigener Ortsname", text: $customName)
                        Text(selected.address).font(.footnote).foregroundStyle(.secondary)
                    }

                    Section("Feinabstimmung") {
                        Picker("Auslösen", selection: $event) {
                            ForEach(RJLocationEvent.allCases) { value in
                                Label(value.title, systemImage: value.symbol).tag(value)
                            }
                        }
                        Toggle("Bei jedem Ereignis erinnern", isOn: $repeats)
                        LabeledContent("Radius", value: "\(Int(radius)) m")
                        Slider(value: $radius, in: 50...5_000, step: 50)
                        Text("Kleine Radien können durch GPS- und Gebäudeeinflüsse ungenauer sein. 100–250 Meter funktionieren meist zuverlässiger.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Orts-Erinnerung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        guard let selected else { return }
                        onSave(ReminderLocationTrigger(
                            name: customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? selected.name
                                : customName.trimmingCharacters(in: .whitespacesAndNewlines),
                            address: selected.address,
                            latitude: selected.latitude,
                            longitude: selected.longitude,
                            radius: radius,
                            event: event,
                            repeats: repeats
                        ))
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(selected == nil)
                }
            }
            .alert("Ortssuche", isPresented: Binding(
                get: { searchError != nil },
                set: { if !$0 { searchError = nil } }
            )) {
                Button("OK") { searchError = nil }
            } message: {
                Text(searchError ?? "Unbekannter Fehler")
            }
        }
    }

    private func search() {
        isSearching = true
        Task {
            do { results = try await locationService.search(query) }
            catch { searchError = error.localizedDescription }
            isSearching = false
        }
    }

    private func select(_ place: RJPlaceResult) {
        selected = place
        customName = place.name
        camera = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
            latitudinalMeters: max(800, radius * 4),
            longitudinalMeters: max(800, radius * 4)
        ))
        Haptics.selection()
    }
}

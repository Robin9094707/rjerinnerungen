import SwiftData
import SwiftUI

struct ReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderCoordinator.self) private var coordinator

    private let existing: RJReminder?

    @State private var title: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var priority: ReminderPriority
    @State private var category: ReminderCategory
    @State private var recurrence: ReminderRecurrence
    @State private var tagsText: String
    @State private var preAlerts: Set<Int>
    @State private var notificationEnabled: Bool
    @State private var liveActivityEnabled: Bool
    @State private var snoozeMinutes: Int

    private let preAlertChoices = [5, 10, 15, 30, 60, 120, 1440]

    init(reminder: RJReminder? = nil) {
        existing = reminder
        _title = State(initialValue: reminder?.title ?? "")
        _notes = State(initialValue: reminder?.notes ?? "")
        _hasDueDate = State(initialValue: reminder?.hasDueDate ?? true)
        _dueDate = State(initialValue: reminder?.dueDate ?? Date.now.addingTimeInterval(3600))
        _priority = State(initialValue: reminder?.priority ?? .normal)
        _category = State(initialValue: reminder?.category ?? .personal)
        _recurrence = State(initialValue: reminder?.recurrence ?? .none)
        _tagsText = State(initialValue: reminder?.tags.joined(separator: ", ") ?? "")
        _preAlerts = State(initialValue: Set(reminder?.preAlertMinutes ?? []))
        _notificationEnabled = State(initialValue: reminder?.notificationEnabled ?? true)
        _liveActivityEnabled = State(initialValue: reminder?.liveActivityEnabled ?? false)
        _snoozeMinutes = State(initialValue: reminder?.snoozeMinutes ?? 10)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Erinnerung") {
                    TextField("Was soll ich nicht vergessen?", text: $title, axis: .vertical)
                        .font(.headline)
                    TextField("Notizen, Details, Links …", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section("Zeit") {
                    Toggle("Termin verwenden", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Fällig", selection: $dueDate)
                        Picker("Wiederholen", selection: $recurrence) {
                            ForEach(ReminderRecurrence.allCases) { value in Text(value.title).tag(value) }
                        }
                    }
                }

                Section("Priorität") {
                    ForEach(ReminderPriority.allCases) { value in
                        Button {
                            priority = value
                            Haptics.impact(.light)
                        } label: {
                            HStack(alignment: .top) {
                                Image(systemName: value.symbolName).frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(value.title).foregroundStyle(.primary)
                                    Text(value.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if priority == value { Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue) }
                            }
                        }
                    }
                }

                Section("Organisation") {
                    Picker("Kategorie", selection: $category) {
                        ForEach(ReminderCategory.allCases) { value in Label(value.title, systemImage: value.symbolName).tag(value) }
                    }
                    TextField("Tags, mit Komma getrennt", text: $tagsText)
                        .textInputAutocapitalization(.never)
                }

                Section("Benachrichtigung") {
                    Toggle("Benachrichtigung", isOn: $notificationEnabled)
                        .disabled(!hasDueDate)
                    if notificationEnabled && hasDueDate {
                        Text("Vorwarnungen")
                            .font(.subheadline.weight(.semibold))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(preAlertChoices, id: \.self) { minutes in
                                    if preAlerts.contains(minutes) {
                                        Button(preAlertLabel(minutes)) { preAlerts.remove(minutes) }
                                            .buttonStyle(.borderedProminent)
                                    } else {
                                        Button(preAlertLabel(minutes)) { preAlerts.insert(minutes) }
                                            .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                        Picker("Standard-Snooze", selection: $snoozeMinutes) {
                            ForEach([5, 10, 15, 30, 60], id: \.self) { Text("\($0) Min.").tag($0) }
                        }
                    }
                }

                Section("Live Activity") {
                    Toggle("Auf Sperrbildschirm/Dynamic Island erlauben", isOn: $liveActivityEnabled)
                    Text("Die Live Activity wird in der Detailansicht bewusst gestartet. So bleibt sie optional und verbraucht nicht unnötig Systemressourcen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(existing == nil ? "Neue Erinnerung" : "Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func preAlertLabel(_ minutes: Int) -> String {
        if minutes == 1440 { return "1 Tag" }
        if minutes >= 60 { return "\(minutes / 60) Std." }
        return "\(minutes) Min."
    }

    private func save() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        let reminder: RJReminder
        if let existing {
            reminder = existing
            reminder.title = cleanedTitle
            reminder.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            reminder.dueDate = dueDate
            reminder.hasDueDate = hasDueDate
            reminder.priority = priority
            reminder.category = category
            reminder.recurrence = recurrence
            reminder.tags = tags
            reminder.preAlertMinutes = preAlerts.sorted()
            reminder.notificationEnabled = notificationEnabled && hasDueDate
            reminder.liveActivityEnabled = liveActivityEnabled
            reminder.snoozeMinutes = snoozeMinutes
            reminder.modifiedAt = .now
        } else {
            reminder = RJReminder(
                title: cleanedTitle,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                dueDate: dueDate,
                hasDueDate: hasDueDate,
                priority: priority,
                category: category,
                recurrence: recurrence,
                tags: tags,
                preAlertMinutes: preAlerts.sorted(),
                notificationEnabled: notificationEnabled && hasDueDate,
                liveActivityEnabled: liveActivityEnabled,
                snoozeMinutes: snoozeMinutes
            )
            modelContext.insert(reminder)
        }

        do {
            try modelContext.save()
            Haptics.success()
            Task { await coordinator.schedule(reminder) }
            dismiss()
        } catch {
            coordinator.errorMessage = error.localizedDescription
        }
    }
}

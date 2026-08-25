import SwiftUI

struct ReminderEditorView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var reminder: ReminderItem
    @State private var hasDueDate: Bool
    @State private var exportToSystem = false

    init(reminder: ReminderItem? = nil) {
        let value = reminder ?? ReminderItem(
            title: "",
            dueDate: Calendar.current.date(byAdding: .hour, value: 1, to: .now)
        )
        _reminder = State(initialValue: value)
        _hasDueDate = State(initialValue: value.dueDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Erinnerung") {
                    TextField("Titel", text: $reminder.title)
                    TextField("Details (optional)", text: $reminder.details, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("Zeit") {
                    Toggle("Termin", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(
                            "Datum",
                            selection: dueDateBinding,
                            displayedComponents: .date
                        )
                        Toggle("Mit Uhrzeit", isOn: $reminder.hasTime)
                        if reminder.hasTime {
                            DatePicker(
                                "Uhrzeit",
                                selection: dueDateBinding,
                                displayedComponents: .hourAndMinute
                            )
                        }
                        Picker("Wiederholen", selection: $reminder.recurrence) {
                            ForEach(RJRecurrence.allCases) { value in
                                Text(value.title).tag(value)
                            }
                        }
                    }
                }

                Section("Priorität") {
                    Picker("Stufe", selection: $reminder.priority) {
                        ForEach(RJPriority.allCases) { value in
                            Label(value.title, systemImage: value.symbol).tag(value)
                        }
                    }

                    Toggle("Lokale Benachrichtigung", isOn: $reminder.notificationEnabled)
                        .disabled(!hasDueDate || reminder.alarmEscalation)

                    Toggle("Als Systemwecker eskalieren", isOn: $reminder.alarmEscalation)
                        .disabled(!hasDueDate || reminder.recurrence != .never)

                    if reminder.alarmEscalation {
                        Label(
                            "AlarmKit zeigt einen prominenten Systemwecker mit Ton und Snooze. Das ist stärker als eine normale Benachrichtigung.",
                            systemImage: "bell.and.waves.left.and.right.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    } else if reminder.priority == .high || reminder.priority == .urgent {
                        Label(
                            "Hohe und dringende Hinweise werden als zeitkritisch angefordert. iOS entscheidet anhand deiner Systemeinstellungen über die Zustellung im Fokus.",
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
                        Label("Bereits mit Apple Erinnerungen verknüpft", systemImage: "checkmark.icloud.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle(reminder.title.isEmpty ? "Neue Erinnerung" : "Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        if !hasDueDate {
                            reminder.dueDate = nil
                            reminder.notificationEnabled = false
                            reminder.alarmEscalation = false
                            reminder.recurrence = .never
                        }
                        if reminder.alarmEscalation {
                            reminder.notificationEnabled = false
                            reminder.priority = .urgent
                        }
                        Task {
                            await store.upsertReminder(reminder, exportToSystem: exportToSystem)
                            if store.lastError == nil { dismiss() }
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(reminder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { reminder.dueDate ?? Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now },
            set: { reminder.dueDate = $0 }
        )
    }
}

import SwiftData
import SwiftUI

struct ReminderDetailView: View {
    let reminder: RJReminder
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderCoordinator.self) private var coordinator
    @State private var editing = false
    @State private var liveActivityRunning = false

    var body: some View {
        ZStack {
            UltraBackground()
            ScrollView {
                VStack(spacing: 16) {
                    UltraCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                Image(systemName: reminder.priority.symbolName)
                                    .font(.largeTitle)
                                Spacer()
                                PriorityBadge(priority: reminder.priority)
                            }
                            Text(reminder.title)
                                .font(.largeTitle.bold())
                            if !reminder.notes.isEmpty {
                                Text(reminder.notes).foregroundStyle(.secondary)
                            }
                        }
                    }

                    UltraCard {
                        VStack(alignment: .leading, spacing: 12) {
                            detailLine("Kategorie", value: reminder.category.title, symbol: reminder.category.symbolName)
                            detailLine("Termin", value: reminder.hasDueDate ? reminder.dueDate.formatted(date: .long, time: .shortened) : "Ohne Termin", symbol: "calendar")
                            detailLine("Wiederholung", value: reminder.recurrence.title, symbol: "repeat")
                            detailLine("Snooze", value: "\(reminder.snoozeMinutes) Minuten", symbol: "zzz")
                            if !reminder.tags.isEmpty {
                                detailLine("Tags", value: reminder.tags.joined(separator: ", "), symbol: "tag")
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        Button {
                            Task {
                                if reminder.isCompleted {
                                    await coordinator.reopen(reminder, context: modelContext)
                                } else {
                                    await coordinator.complete(reminder, context: modelContext)
                                }
                            }
                        } label: {
                            Label(reminder.isCompleted ? "Wieder öffnen" : "Als erledigt markieren", systemImage: reminder.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        if reminder.liveActivityEnabled && reminder.hasDueDate && !reminder.isCompleted {
                            Button {
                                Task {
                                    do {
                                        if liveActivityRunning {
                                            await LiveActivityService.shared.end(for: reminder.id)
                                            liveActivityRunning = false
                                        } else {
                                            try await LiveActivityService.shared.start(for: reminder)
                                            liveActivityRunning = true
                                        }
                                    } catch { coordinator.errorMessage = error.localizedDescription }
                                }
                            } label: {
                                Label(liveActivityRunning ? "Live Activity beenden" : "Live Activity starten", systemImage: "waveform.path.ecg.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        Button {
                            Task {
                                do {
                                    try await AppleRemindersService.shared.export(reminder)
                                    coordinator.message = "In Apple Erinnerungen exportiert."
                                } catch { coordinator.errorMessage = error.localizedDescription }
                            }
                        } label: {
                            Label("Zu Apple Erinnerungen exportieren", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        ShareLink(item: shareText) {
                            Label("Als Text teilen", systemImage: "square.and.arrow.up.on.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Bearbeiten") { editing = true } }
        .sheet(isPresented: $editing) { ReminderEditorView(reminder: reminder) }
    }

    private func detailLine(_ label: String, value: String, symbol: String) -> some View {
        HStack(alignment: .top) {
            Label(label, systemImage: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
            Spacer(minLength: 0)
        }
    }

    private var shareText: String {
        var parts = [reminder.title]
        if reminder.hasDueDate { parts.append(reminder.dueDate.formatted(date: .long, time: .shortened)) }
        if !reminder.notes.isEmpty { parts.append(reminder.notes) }
        return parts.joined(separator: "\n")
    }
}

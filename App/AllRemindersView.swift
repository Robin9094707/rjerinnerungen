import SwiftData
import SwiftUI

private enum ReminderListFilter: String, CaseIterable, Identifiable {
    case open
    case completed
    case all
    case ultra

    var id: String { rawValue }
    var title: String {
        switch self {
        case .open: "Offen"
        case .completed: "Erledigt"
        case .all: "Alle"
        case .ultra: "Ultra/Dringend"
        }
    }
}

struct AllRemindersView: View {
    @Query(sort: \RJReminder.dueDate, order: .forward) private var reminders: [RJReminder]
    @Environment(\.modelContext) private var modelContext
    @Environment(ReminderCoordinator.self) private var coordinator
    @State private var searchText = ""
    @State private var filter: ReminderListFilter = .open
    @State private var showingNewReminder = false

    private var filtered: [RJReminder] {
        reminders.filter { reminder in
            let stateMatches: Bool = switch filter {
            case .open: !reminder.isCompleted
            case .completed: reminder.isCompleted
            case .all: true
            case .ultra: !reminder.isCompleted && (reminder.priority == .ultra || reminder.priority == .urgent)
            }
            let textMatches = searchText.isEmpty || reminder.title.localizedCaseInsensitiveContains(searchText) || reminder.notes.localizedCaseInsensitiveContains(searchText) || reminder.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return stateMatches && textMatches
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()
                List {
                    Section {
                        Picker("Filter", selection: $filter) {
                            ForEach(ReminderListFilter.allCases) { value in Text(value.title).tag(value) }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(Color.clear)

                    if filtered.isEmpty {
                        EmptyStateCard(title: "Nichts gefunden", message: "Passe Suche oder Filter an oder erstelle eine neue Erinnerung.", symbol: "magnifyingglass")
                            .listRowBackground(Color.clear)
                    } else {
                        Section("Erinnerungen") {
                            ForEach(filtered) { reminder in
                                NavigationLink { ReminderDetailView(reminder: reminder) } label: { ReminderRow(reminder: reminder) }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            Task {
                                                if reminder.isCompleted {
                                                    await coordinator.reopen(reminder, context: modelContext)
                                                } else {
                                                    await coordinator.complete(reminder, context: modelContext)
                                                }
                                            }
                                        } label: {
                                            Label(reminder.isCompleted ? "Wieder öffnen" : "Erledigt", systemImage: reminder.isCompleted ? "arrow.uturn.backward" : "checkmark")
                                        }
                                        .tint(.green)
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task { await coordinator.delete(reminder, context: modelContext) }
                                        } label: { Label("Löschen", systemImage: "trash") }
                                    }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Alle Erinnerungen")
            .searchable(text: $searchText, prompt: "Titel, Notiz oder Tag")
            .toolbar {
                Button { showingNewReminder = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $showingNewReminder) { ReminderEditorView() }
        }
    }
}

import SwiftData
import SwiftUI

struct TodayView: View {
    @Query(sort: \RJReminder.dueDate, order: .forward) private var reminders: [RJReminder]
    @State private var showingNewReminder = false

    private var active: [RJReminder] { reminders.filter { !$0.isCompleted } }
    private var overdue: [RJReminder] { active.filter(\.isOverdue) }
    private var today: [RJReminder] { active.filter { $0.hasDueDate && Calendar.current.isDateInToday($0.dueDate) && !$0.isOverdue } }
    private var upcoming: [RJReminder] {
        let end = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .distantFuture
        return active.filter { $0.hasDueDate && $0.dueDate > .now && !Calendar.current.isDateInToday($0.dueDate) && $0.dueDate <= end }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()
                List {
                    Section {
                        dashboard
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }

                    reminderSection("Überfällig", items: overdue, symbol: "exclamationmark.triangle.fill")
                    reminderSection("Heute", items: today, symbol: "sun.max.fill")
                    reminderSection("Nächste 7 Tage", items: upcoming, symbol: "calendar")

                    if overdue.isEmpty && today.isEmpty && upcoming.isEmpty {
                        EmptyStateCard(title: "Alles ruhig", message: "Keine offenen Erinnerungen in den nächsten sieben Tagen.", symbol: "checkmark.seal.fill")
                            .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("RJ Ultra")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewReminder = true; Haptics.impact(.light) } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Neue Erinnerung")
                }
            }
            .sheet(isPresented: $showingNewReminder) { ReminderEditorView() }
        }
    }

    private var dashboard: some View {
        UltraCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dein Fokus")
                            .font(.title2.bold())
                        Text("\(active.count) offen • \(overdue.count) überfällig")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .font(.largeTitle)
                        .symbolRenderingMode(.hierarchical)
                }
                Button {
                    showingNewReminder = true
                } label: {
                    Label("Ultra-Erinnerung hinzufügen", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func reminderSection(_ title: String, items: [RJReminder], symbol: String) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { reminder in
                    NavigationLink { ReminderDetailView(reminder: reminder) } label: { ReminderRow(reminder: reminder) }
                }
            } header: {
                Label(title, systemImage: symbol)
            }
        }
    }
}

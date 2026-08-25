import SwiftUI

struct MoreView: View {
    @Environment(AppDataStore.self) private var store
    @Environment(TimerStore.self) private var timerStore

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()
                ScrollView {
                    LazyVStack(spacing: 14) {
                        UltraGlassCard {
                            HStack(spacing: 14) {
                                Image(systemName: "square.grid.2x2.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [RJTheme.cyan, RJTheme.violet],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Werkzeuge & System").font(.title2.bold())
                                    Text("Wecker, Verlauf, Suche, Export und Berechtigungen")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        destination("Wecker", subtitle: "AlarmKit, Wiederholung & Snooze", symbol: "alarm.waves.left.and.right.fill", color: .orange) {
                            AlarmsView()
                        }
                        destination("Timer-Presets", subtitle: "Eigene Schnellstarts", symbol: "square.grid.2x2", color: .cyan) {
                            PresetsView()
                        }
                        destination("Timer-Verlauf", subtitle: "Statistik und Historie", symbol: "chart.bar.xaxis", color: .purple) {
                            HistoryView()
                        }
                        destination("Alles durchsuchen", subtitle: "Notizen, Erinnerungen und Wecker", symbol: "magnifyingglass", color: .blue) {
                            UniversalSearchView()
                        }
                        destination("Einstellungen", subtitle: "Berechtigungen, Verhalten & Diagnose", symbol: "gearshape.fill", color: .gray) {
                            SettingsView()
                        }

                        if let url = store.exportURL() {
                            ShareLink(item: url) {
                                UltraGlassCard {
                                    Label("Kompletten Datenexport teilen", systemImage: "square.and.arrow.up")
                                        .font(.headline)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        Text("RJ ZeitZentrale 1.0 • iOS 26.1+")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                    }
                    .padding()
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Mehr")
        }
    }

    private func destination<Destination: View>(
        _ title: String,
        subtitle: String,
        symbol: String,
        color: Color,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            UltraGlassCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(color.opacity(0.16))
                            .frame(width: 46, height: 46)
                        Image(systemName: symbol)
                            .font(.title3)
                            .foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.headline)
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct UniversalSearchView: View {
    @Environment(AppDataStore.self) private var store
    @State private var query = ""

    var body: some View {
        List {
            if query.isEmpty {
                ContentUnavailableView(
                    "Alles finden",
                    systemImage: "magnifyingglass",
                    description: Text("Durchsuche Erinnerungen, Notizen und Wecker gleichzeitig.")
                )
            } else {
                if !matchingReminders.isEmpty {
                    Section("Erinnerungen") {
                        ForEach(matchingReminders) { item in
                            Label(item.title, systemImage: item.priority.symbol)
                        }
                    }
                }
                if !matchingNotes.isEmpty {
                    Section("Notizen") {
                        ForEach(matchingNotes) { item in
                            VStack(alignment: .leading) {
                                Text(item.title)
                                Text(item.preview).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
                if !matchingAlarms.isEmpty {
                    Section("Wecker") {
                        ForEach(matchingAlarms) { item in
                            LabeledContent(item.title, value: item.fireDate.formatted(date: .omitted, time: .shortened))
                        }
                    }
                }
                if matchingReminders.isEmpty && matchingNotes.isEmpty && matchingAlarms.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .navigationTitle("Suche")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
    }

    private var matchingReminders: [ReminderItem] {
        store.reminders.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.details.localizedCaseInsensitiveContains(query)
        }
    }
    private var matchingNotes: [NoteItem] {
        store.notes.filter {
            $0.title.localizedCaseInsensitiveContains(query) || $0.body.localizedCaseInsensitiveContains(query)
        }
    }
    private var matchingAlarms: [AlarmRecord] {
        store.alarms.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }
}

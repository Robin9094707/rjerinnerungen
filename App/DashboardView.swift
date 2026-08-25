import SwiftUI

struct DashboardView: View {
    @Environment(AppDataStore.self) private var appStore
    @Environment(TimerStore.self) private var timerStore
    @Environment(AppRouter.self) private var router

    @State private var showReminder = false
    @State private var showNote = false
    @State private var showAlarm = false
    @State private var showTimer = false

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
                        hero
                        metrics
                        quickActions
                        nextUp
                        activeTimer
                    }
                    .padding()
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("RJ ZeitZentrale")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Erinnerung", systemImage: "checklist") { showReminder = true }
                        Button("Notiz", systemImage: "note.text.badge.plus") { showNote = true }
                        Button("Wecker", systemImage: "alarm.waves.left.and.right") { showAlarm = true }
                        Button("Timer", systemImage: "timer") { showTimer = true }
                    } label: {
                        Label("Neu", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .sheet(isPresented: $showReminder) { ReminderEditorView() }
            .sheet(isPresented: $showNote) { NoteEditorView() }
            .sheet(isPresented: $showAlarm) { AlarmEditorView() }
            .sheet(isPresented: $showTimer) { NewTimerView() }
            .onChange(of: router.showNewAlarm) { _, requested in
                if requested {
                    showAlarm = true
                    router.showNewAlarm = false
                }
            }
        }
    }

    private var hero: some View {
        UltraGlassCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [RJTheme.cyan, RJTheme.violet],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)
                    Image(systemName: greetingSymbol)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.title2.bold())
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(context.date.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(statusLine)
                        .font(.caption)
                        .foregroundStyle(.cyan)
                        .lineLimit(1)
                }
                Spacer()
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            RJMetric(
                value: "\(appStore.activeReminders.count)",
                label: "offene Erinnerungen",
                symbol: "checklist",
                color: .cyan
            )
            RJMetric(
                value: "\(timerStore.activeTimers.count)",
                label: "aktive Timer",
                symbol: "timer",
                color: .orange
            )
            RJMetric(
                value: "\(appStore.activeNotes.count)",
                label: "Notizen",
                symbol: "note.text",
                color: .purple
            )
            RJMetric(
                value: "\(appStore.upcomingAlarms.count)",
                label: "aktive Wecker",
                symbol: "alarm.waves.left.and.right.fill",
                color: .pink
            )
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            RJSectionHeader(title: "Schnell erfassen", subtitle: "Ein Tipp – sofort gespeichert")
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    quickButton("Erinnern", symbol: "checkmark.circle.fill", color: .cyan) {
                        showReminder = true
                    }
                    quickButton("Notieren", symbol: "square.and.pencil", color: .purple) {
                        showNote = true
                    }
                    quickButton("Wecken", symbol: "alarm.fill", color: .orange) {
                        showAlarm = true
                    }
                    quickButton("Timer", symbol: "timer", color: .pink) {
                        showTimer = true
                    }
                }
            }
        }
    }

    private var nextUp: some View {
        VStack(alignment: .leading, spacing: 10) {
            RJSectionHeader(title: "Als Nächstes", symbol: "clock.badge")
            if let reminder = appStore.activeReminders.first {
                Button {
                    router.selectedTab = .planner
                    router.requestedReminderID = reminder.id
                } label: {
                    UltraGlassCard {
                        HStack(spacing: 13) {
                            Image(systemName: reminder.priority.symbol)
                                .font(.title2)
                                .foregroundStyle(reminder.priority.color)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.title).font(.headline).lineLimit(1)
                                Text(reminder.dueDate?.formatted(date: .abbreviated, time: .shortened) ?? "Ohne Termin")
                                    .font(.caption)
                                    .foregroundStyle(reminder.isOverdue ? .red : .secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else if let alarm = appStore.upcomingAlarms.first {
                UltraGlassCard {
                    Label {
                        VStack(alignment: .leading) {
                            Text(alarm.title).font(.headline)
                            Text(alarm.nextFireDate()?.formatted(date: .abbreviated, time: .shortened) ?? alarm.repeatSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "alarm.waves.left.and.right.fill")
                            .foregroundStyle(alarm.accent.color)
                    }
                }
            } else {
                EmptyCard(
                    title: "Alles ruhig",
                    message: "Füge eine Erinnerung oder einen Wecker hinzu.",
                    systemImage: "checkmark.seal.fill"
                )
            }
        }
    }

    @ViewBuilder
    private var activeTimer: some View {
        if let timer = timerStore.activeTimers.first {
            VStack(alignment: .leading, spacing: 10) {
                RJSectionHeader(title: "Live", subtitle: "Auf Lock Screen und Dynamic Island", symbol: "waveform.path.ecg")
                TimerCardView(timerID: timer.id)
            }
        }
    }

    private func quickButton(
        _ title: String,
        symbol: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.impact(.light)
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(title)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: "Guten Morgen, Robin"
        case 11..<18: "Hallo Robin"
        case 18..<23: "Guten Abend, Robin"
        default: "Noch wach, Robin?"
        }
    }

    private var greetingSymbol: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: "sun.max.fill"
        case 11..<18: "sparkles"
        case 18..<23: "sun.horizon.fill"
        default: "moon.stars.fill"
        }
    }

    private var statusLine: String {
        if appStore.activeReminders.contains(where: \.isOverdue) { return "Eine Erinnerung wartet auf dich" }
        if timerStore.activeTimers.count > 0 { return "Deine Timer laufen zuverlässig im System" }
        return "Alles im Blick"
    }
}

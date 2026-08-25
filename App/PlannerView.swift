import EventKit
import SwiftUI

struct PlannerView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case calendar = "Kalender"
        case reminders = "Erinnerungen"
        var id: String { rawValue }
    }

    @Environment(AppDataStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var eventService = EventKitService.shared
    @State private var mode: Mode = .calendar
    @State private var selectedDate = Date.now
    @State private var visibleMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var editingReminder: ReminderItem?
    @State private var showNewReminder = false
    @State private var pendingDelete: ReminderItem?

    var body: some View {
        NavigationStack {
            ZStack {
                UltraBackground()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        Picker("Ansicht", selection: $mode) {
                            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        if mode == .calendar {
                            calendarContent
                        } else {
                            reminderContent
                        }
                    }
                    .padding()
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Planer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewReminder = true
                    } label: {
                        Label("Neue Erinnerung", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .sheet(isPresented: $showNewReminder) { ReminderEditorView() }
            .sheet(item: $editingReminder) { ReminderEditorView(reminder: $0) }
            .alert("Erinnerung löschen?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )) {
                Button("Abbrechen", role: .cancel) { pendingDelete = nil }
                Button("Löschen", role: .destructive) {
                    if let reminder = pendingDelete { store.deleteReminder(reminder.id) }
                    pendingDelete = nil
                }
            } message: {
                Text("Geplante Hinweise und ein zugehöriger AlarmKit-Wecker werden ebenfalls entfernt.")
            }
            .refreshable { await eventService.refresh() }
            .onChange(of: router.showNewReminder) { _, requested in
                if requested {
                    showNewReminder = true
                    router.showNewReminder = false
                }
            }
            .onChange(of: router.requestedReminderID) { _, id in
                guard let id, let item = store.reminders.first(where: { $0.id == id }) else { return }
                editingReminder = item
                router.requestedReminderID = nil
            }
        }
    }

    private var calendarContent: some View {
        VStack(spacing: 16) {
            UltraGlassCard {
                MonthCalendarView(
                    month: $visibleMonth,
                    selectedDate: $selectedDate,
                    markedDates: markedDates
                )
            }

            if eventService.eventAuthorization != .fullAccess {
                permissionCard
            }

            VStack(alignment: .leading, spacing: 10) {
                RJSectionHeader(
                    title: selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                    subtitle: "Erinnerungen und Kalendertermine",
                    symbol: "calendar.day.timeline.left"
                )

                if selectedReminders.isEmpty && selectedEvents.isEmpty {
                    EmptyCard(
                        title: "Freier Tag",
                        message: "Für diesen Tag ist noch nichts eingetragen.",
                        systemImage: "calendar.badge.checkmark"
                    )
                } else {
                    ForEach(selectedReminders) { reminder in
                        ReminderRow(reminder: reminder) {
                            Task { await store.toggleReminder(reminder.id) }
                        } edit: {
                            editingReminder = reminder
                        }
                    }
                    ForEach(selectedEvents) { event in
                        eventRow(event)
                    }
                }
            }
        }
    }

    private var reminderContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if store.activeReminders.isEmpty {
                EmptyCard(
                    title: "Alles erledigt",
                    message: "Neue Erinnerungen erscheinen hier – mit Priorität, Wiederholung und AlarmKit-Eskalation.",
                    systemImage: "checkmark.circle.fill"
                )
            } else {
                ForEach(store.activeReminders) { reminder in
                    ReminderRow(reminder: reminder) {
                        Task { await store.toggleReminder(reminder.id) }
                    } edit: {
                        editingReminder = reminder
                    }
                    .contextMenu {
                        Button("Bearbeiten", systemImage: "pencil") { editingReminder = reminder }
                        Button("Löschen", systemImage: "trash", role: .destructive) {
                            pendingDelete = reminder
                        }
                    }
                }
            }

            if !store.reminders.filter(\.completed).isEmpty {
                DisclosureGroup("Erledigt (\(store.reminders.filter(\.completed).count))") {
                    ForEach(store.reminders.filter(\.completed)) { reminder in
                        ReminderRow(reminder: reminder) {
                            Task { await store.toggleReminder(reminder.id) }
                        } edit: {
                            editingReminder = reminder
                        }
                    }
                }
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 22))
            }

            if eventService.reminderAuthorization == .fullAccess {
                systemReminders
            } else {
                Button {
                    Task { _ = await eventService.requestReminderAccess() }
                } label: {
                    Label("Apple Erinnerungen verbinden", systemImage: "checklist.checked")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var permissionCard: some View {
        UltraGlassCard {
            HStack(spacing: 13) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Apple Kalender verbinden").font(.headline)
                    Text("Zeigt Termine freiwillig in dieser Monatsansicht.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Erlauben") {
                    Task { _ = await eventService.requestEventAccess() }
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private var systemReminders: some View {
        VStack(alignment: .leading, spacing: 10) {
            RJSectionHeader(title: "Aus Apple Erinnerungen", subtitle: "Nur angezeigt, bis du sie übernimmst")
            ForEach(eventService.systemReminders.filter { !$0.completed }.prefix(8)) { item in
                UltraGlassCard {
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text(item.title).font(.headline)
                            Text(item.calendarTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Übernehmen") {
                            Task { await store.duplicateSystemReminder(item) }
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
        }
    }

    private func eventRow(_ event: CalendarEventSnapshot) -> some View {
        UltraGlassCard {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(eventColor(event))
                    .frame(width: 5, height: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title).font(.headline)
                    Text(event.isAllDay ? "Ganztägig" : event.startDate.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "location.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(event.calendarTitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var selectedReminders: [ReminderItem] {
        store.reminders.filter { $0.occurs(on: selectedDate) }
    }

    private var selectedEvents: [CalendarEventSnapshot] {
        eventService.events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) }
    }

    private var markedDates: Set<Date> {
        let calendar = Calendar.current
        let monthDays = calendar.range(of: .day, in: .month, for: visibleMonth)?.compactMap {
            calendar.date(bySetting: .day, value: $0, of: visibleMonth)
        } ?? []
        let reminderDates = monthDays.filter { day in
            store.reminders.contains { !$0.completed && $0.occurs(on: day, calendar: calendar) }
        }.map(calendar.startOfDay)
        let eventDates = eventService.events.map(\.startDate).map(calendar.startOfDay)
        return Set(reminderDates + eventDates)
    }

    private func eventColor(_ event: CalendarEventSnapshot) -> Color {
        guard event.colorComponents.count >= 3 else { return .cyan }
        return Color(
            red: event.colorComponents[0],
            green: event.colorComponents[1],
            blue: event.colorComponents[2]
        )
    }
}

struct MonthCalendarView: View {
    @Binding var month: Date
    @Binding var selectedDate: Date
    let markedDates: Set<Date>

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    moveMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.glass)

                Spacer()
                Button {
                    month = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
                    selectedDate = .now
                } label: {
                    Text(month.formatted(.dateTime.month(.wide).year()))
                        .font(.headline)
                }
                .buttonStyle(.plain)
                Spacer()

                Button {
                    moveMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.glass)
            }

            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        Button {
                            selectedDate = date
                            Haptics.selection()
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.subheadline.bold())
                                    .frame(width: 34, height: 30)
                                    .background(
                                        calendar.isDate(date, inSameDayAs: selectedDate)
                                            ? AnyShapeStyle(Color.cyan.gradient)
                                            : AnyShapeStyle(Color.clear),
                                        in: Circle()
                                    )
                                    .foregroundStyle(
                                        calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary
                                    )
                                Circle()
                                    .fill(markedDates.contains(calendar.startOfDay(for: date)) ? Color.orange : Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                    } else {
                        Color.clear.frame(height: 37)
                    }
                }
            }
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var days: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let dayRange = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let dates = dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }
        return Array(repeating: nil, count: leading) + dates.map(Optional.some)
    }

    private func moveMonth(_ delta: Int) {
        guard let value = calendar.date(byAdding: .month, value: delta, to: month) else { return }
        withAnimation(.smooth) {
            month = calendar.dateInterval(of: .month, for: value)?.start ?? value
        }
    }
}

struct ReminderRow: View {
    let reminder: ReminderItem
    let toggle: () -> Void
    let edit: () -> Void

    var body: some View {
        UltraGlassCard {
            HStack(spacing: 12) {
                Button(action: toggle) {
                    Image(systemName: reminder.completed ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(reminder.completed ? .green : reminder.priority.color)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(reminder.completed ? "Als offen markieren" : "Als erledigt markieren")

                Button(action: edit) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(reminder.title)
                                .font(.headline)
                                .strikethrough(reminder.completed)
                            if reminder.alarmEscalation {
                                Image(systemName: "alarm.waves.left.and.right.fill")
                                    .foregroundStyle(.orange)
                                    .accessibilityLabel("AlarmKit-Wecker")
                            }
                        }
                        if let dueDate = reminder.dueDate {
                            Text(dueDate.formatted(date: .abbreviated, time: reminder.hasTime ? .shortened : .omitted))
                                .font(.caption)
                                .foregroundStyle(reminder.isOverdue ? .red : .secondary)
                        } else {
                            Text("Ohne Termin")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if reminder.effectiveRecurrence.isRepeating {
                            Label(reminder.recurrenceSummary, systemImage: "repeat")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let location = reminder.locationTrigger {
                            Label(location.name, systemImage: location.event.symbol)
                                .font(.caption2)
                                .foregroundStyle(.cyan)
                        }
                        if !reminder.normalizedTags.isEmpty {
                            Text(reminder.normalizedTags.prefix(3).map { "#\($0)" }.joined(separator: "  "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Image(systemName: reminder.priority.symbol)
                    .foregroundStyle(reminder.priority.color)
            }
        }
    }
}

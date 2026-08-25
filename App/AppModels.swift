import Foundation
import SwiftUI

enum RJPriority: String, Codable, CaseIterable, Identifiable, Sendable {
    case low, normal, high, urgent
    var id: String { rawValue }
    var title: String {
        switch self { case .low: "Niedrig"; case .normal: "Normal"; case .high: "Hoch"; case .urgent: "Dringend" }
    }
    var symbol: String {
        switch self {
        case .low: "arrow.down.circle"
        case .normal: "circle"
        case .high: "exclamationmark.circle.fill"
        case .urgent: "bell.and.waves.left.and.right.fill"
        }
    }
    var color: Color {
        switch self { case .low: .blue; case .normal: .cyan; case .high: .orange; case .urgent: .red }
    }
}

enum RJWeekday: Int, Codable, CaseIterable, Identifiable, Sendable {
    case monday = 2, tuesday = 3, wednesday = 4, thursday = 5, friday = 6, saturday = 7, sunday = 1
    var id: Int { rawValue }
    var shortTitle: String {
        switch self {
        case .monday: "Mo"; case .tuesday: "Di"; case .wednesday: "Mi"; case .thursday: "Do"
        case .friday: "Fr"; case .saturday: "Sa"; case .sunday: "So"
        }
    }
    var fullTitle: String {
        switch self {
        case .monday: "Montag"; case .tuesday: "Dienstag"; case .wednesday: "Mittwoch"; case .thursday: "Donnerstag"
        case .friday: "Freitag"; case .saturday: "Samstag"; case .sunday: "Sonntag"
        }
    }
    var localeWeekday: Locale.Weekday {
        switch self {
        case .monday: .monday; case .tuesday: .tuesday; case .wednesday: .wednesday; case .thursday: .thursday
        case .friday: .friday; case .saturday: .saturday; case .sunday: .sunday
        }
    }
}

// Retained so 1.0 JSON data migrates without losing any reminder.
enum RJRecurrence: String, Codable, CaseIterable, Identifiable, Sendable {
    case never, daily, weekly, monthly
    var id: String { rawValue }
    var title: String {
        switch self { case .never: "Nie"; case .daily: "Täglich"; case .weekly: "Wöchentlich"; case .monthly: "Monatlich" }
    }
}

enum RJRecurrenceFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case never, hourly, daily, weekly, monthly, yearly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .never: "Nie"; case .hourly: "Stündlich"; case .daily: "Täglich"
        case .weekly: "Wöchentlich"; case .monthly: "Monatlich"; case .yearly: "Jährlich"
        }
    }
    var unitTitle: String {
        switch self {
        case .never: "–"; case .hourly: "Stunde(n)"; case .daily: "Tag(e)"
        case .weekly: "Woche(n)"; case .monthly: "Monat(e)"; case .yearly: "Jahr(e)"
        }
    }
}

struct RJRecurrenceRule: Codable, Hashable, Sendable {
    var frequency: RJRecurrenceFrequency = .never
    var interval: Int = 1
    var weekdays: [RJWeekday] = []
    var endDate: Date?
    var occurrenceLimit: Int?

    var isRepeating: Bool { frequency != .never }
    var summary: String {
        guard isRepeating else { return "Einmalig" }
        var text = interval == 1 ? frequency.title : "Alle \(interval) \(frequency.unitTitle)"
        if frequency == .weekly, !weekdays.isEmpty {
            text += " • " + weekdays.sorted(by: Self.weekdaySort).map(\.shortTitle).joined(separator: ", ")
        }
        if let occurrenceLimit {
            text += " • \(occurrenceLimit)×"
        } else if let endDate {
            text += " • bis \(endDate.formatted(date: .abbreviated, time: .omitted))"
        }
        return text
    }

    func upcomingDates(
        startingAt start: Date,
        after boundary: Date = .distantPast,
        limit: Int = 32,
        calendar: Calendar = .current
    ) -> [Date] {
        let resultLimit = max(1, limit)
        let safeInterval = max(1, interval)
        let totalLimit = occurrenceLimit.map { max(1, $0) }
        var result: [Date] = []

        func canUse(_ candidate: Date, occurrenceNumber: Int) -> Bool {
            if let endDate, candidate > endDate { return false }
            if let totalLimit, occurrenceNumber > totalLimit { return false }
            return true
        }

        if frequency == .never {
            return start >= boundary && canUse(start, occurrenceNumber: 1) ? [start] : []
        }

        if frequency == .weekly {
            let fallback = RJWeekday(rawValue: calendar.component(.weekday, from: start)).map { [$0] } ?? []
            let selected = Set(weekdays.isEmpty ? fallback : weekdays)
            let startDay = calendar.startOfDay(for: start)
            let startWeek = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? startDay
            let time = calendar.dateComponents([.hour, .minute, .second], from: start)
            var day = startDay
            var occurrenceNumber = 0

            for _ in 0..<(366 * 60) {
                guard result.count < resultLimit else { break }
                let candidateWeek = calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
                let weekDistance = calendar.dateComponents([.weekOfYear], from: startWeek, to: candidateWeek).weekOfYear ?? 0
                let weekday = RJWeekday(rawValue: calendar.component(.weekday, from: day))
                if weekDistance >= 0,
                   weekDistance.isMultiple(of: safeInterval),
                   weekday.map(selected.contains) == true,
                   let candidate = calendar.date(
                    bySettingHour: time.hour ?? 0,
                    minute: time.minute ?? 0,
                    second: time.second ?? 0,
                    of: day
                   ), candidate >= start {
                    occurrenceNumber += 1
                    guard canUse(candidate, occurrenceNumber: occurrenceNumber) else { break }
                    if candidate >= boundary { result.append(candidate) }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            return result
        }

        let component: Calendar.Component
        switch frequency {
        case .hourly: component = .hour
        case .daily: component = .day
        case .monthly: component = .month
        case .yearly: component = .year
        case .never, .weekly: component = .day
        }
        let maximumIterations = min(totalLimit ?? 50_000, 50_000)
        for index in 0..<maximumIterations {
            guard result.count < resultLimit else { break }
            let candidate: Date?
            if index == 0 { candidate = start }
            else { candidate = calendar.date(byAdding: component, value: safeInterval * index, to: start) }
            guard let candidate else { break }
            guard canUse(candidate, occurrenceNumber: index + 1) else { break }
            if candidate >= boundary { result.append(candidate) }
        }
        return result
    }

    func occurs(on date: Date, startingAt start: Date, calendar: Calendar = .current) -> Bool {
        let boundary = calendar.startOfDay(for: date).addingTimeInterval(-1)
        return upcomingDates(startingAt: start, after: boundary, limit: 1, calendar: calendar)
            .contains { calendar.isDate($0, inSameDayAs: date) }
    }

    private static func weekdaySort(_ left: RJWeekday, _ right: RJWeekday) -> Bool {
        let order: [RJWeekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        return (order.firstIndex(of: left) ?? 0) < (order.firstIndex(of: right) ?? 0)
    }
}

enum RJLocationEvent: String, Codable, CaseIterable, Identifiable, Sendable {
    case enter, exit
    var id: String { rawValue }
    var title: String { self == .enter ? "Beim Betreten" : "Beim Verlassen" }
    var symbol: String { self == .enter ? "location.fill" : "location.slash.fill" }
}

struct ReminderLocationTrigger: Codable, Hashable, Sendable {
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var radius: Double = 150
    var event: RJLocationEvent = .enter
    var repeats: Bool = true
    var summary: String { "\(event.title) • \(name) • \(Int(radius)) m" }
}

struct ReminderItem: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var details: String = ""
    var dueDate: Date?
    var hasTime: Bool = true
    var priority: RJPriority = .normal
    var recurrence: RJRecurrence = .never
    var recurrenceRule: RJRecurrenceRule?
    var notificationEnabled: Bool = true
    var notificationLeadTimes: [Int] = [0]
    var snoozeMinutes: Int = 10
    var alarmEscalation: Bool = false
    var locationTrigger: ReminderLocationTrigger?
    var listName: String = "Allgemein"
    var tags: [String] = []
    var completed: Bool = false
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var systemReminderIdentifier: String?

    var isOverdue: Bool {
        guard !completed, let dueDate else { return false }
        return dueDate < .now && !effectiveRecurrence.isRepeating
    }
    var effectiveRecurrence: RJRecurrenceRule {
        if let recurrenceRule { return recurrenceRule }
        switch recurrence {
        case .never: return RJRecurrenceRule()
        case .daily: return RJRecurrenceRule(frequency: .daily)
        case .weekly:
            let weekday = dueDate.flatMap { RJWeekday(rawValue: Calendar.current.component(.weekday, from: $0)) }
            return RJRecurrenceRule(frequency: .weekly, weekdays: weekday.map { [$0] } ?? [])
        case .monthly: return RJRecurrenceRule(frequency: .monthly)
        }
    }
    var recurrenceSummary: String { effectiveRecurrence.summary }
    var normalizedTags: [String] { Array(Set(tags.map(Self.normalizeTag).filter { !$0.isEmpty })).sorted() }
    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let dueDate else { return false }
        return effectiveRecurrence.occurs(on: date, startingAt: dueDate, calendar: calendar)
    }
    static func normalizeTag(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .replacingOccurrences(of: " ", with: "-").lowercased()
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, details, dueDate, hasTime, priority, recurrence, recurrenceRule
        case notificationEnabled, notificationLeadTimes, snoozeMinutes, alarmEscalation
        case locationTrigger, listName, tags, completed, createdAt, updatedAt, systemReminderIdentifier
    }
    init(
        id: UUID = UUID(), title: String, details: String = "", dueDate: Date? = nil,
        hasTime: Bool = true, priority: RJPriority = .normal, recurrence: RJRecurrence = .never,
        recurrenceRule: RJRecurrenceRule? = nil, notificationEnabled: Bool = true,
        notificationLeadTimes: [Int] = [0], snoozeMinutes: Int = 10,
        alarmEscalation: Bool = false, locationTrigger: ReminderLocationTrigger? = nil,
        listName: String = "Allgemein", tags: [String] = [], completed: Bool = false,
        createdAt: Date = .now, updatedAt: Date = .now, systemReminderIdentifier: String? = nil
    ) {
        self.id = id; self.title = title; self.details = details; self.dueDate = dueDate
        self.hasTime = hasTime; self.priority = priority; self.recurrence = recurrence
        self.recurrenceRule = recurrenceRule; self.notificationEnabled = notificationEnabled
        self.notificationLeadTimes = notificationLeadTimes; self.snoozeMinutes = snoozeMinutes
        self.alarmEscalation = alarmEscalation; self.locationTrigger = locationTrigger
        self.listName = listName; self.tags = tags; self.completed = completed
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.systemReminderIdentifier = systemReminderIdentifier
    }
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try box.decode(String.self, forKey: .title)
        details = try box.decodeIfPresent(String.self, forKey: .details) ?? ""
        dueDate = try box.decodeIfPresent(Date.self, forKey: .dueDate)
        hasTime = try box.decodeIfPresent(Bool.self, forKey: .hasTime) ?? true
        priority = try box.decodeIfPresent(RJPriority.self, forKey: .priority) ?? .normal
        recurrence = try box.decodeIfPresent(RJRecurrence.self, forKey: .recurrence) ?? .never
        recurrenceRule = try box.decodeIfPresent(RJRecurrenceRule.self, forKey: .recurrenceRule)
        notificationEnabled = try box.decodeIfPresent(Bool.self, forKey: .notificationEnabled) ?? true
        notificationLeadTimes = try box.decodeIfPresent([Int].self, forKey: .notificationLeadTimes) ?? [0]
        snoozeMinutes = try box.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 10
        alarmEscalation = try box.decodeIfPresent(Bool.self, forKey: .alarmEscalation) ?? false
        locationTrigger = try box.decodeIfPresent(ReminderLocationTrigger.self, forKey: .locationTrigger)
        listName = try box.decodeIfPresent(String.self, forKey: .listName) ?? "Allgemein"
        tags = try box.decodeIfPresent([String].self, forKey: .tags) ?? []
        completed = try box.decodeIfPresent(Bool.self, forKey: .completed) ?? false
        createdAt = try box.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try box.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        systemReminderIdentifier = try box.decodeIfPresent(String.self, forKey: .systemReminderIdentifier)
    }
}

enum NoteColorToken: String, Codable, CaseIterable, Identifiable, Sendable {
    case cyan, blue, purple, pink, orange, green
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self { case .cyan: .cyan; case .blue: .blue; case .purple: .purple; case .pink: .pink; case .orange: .orange; case .green: .green }
    }
}

struct NoteFolder: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String
    var symbol: String = "folder.fill"
    var color: NoteColorToken = .cyan
    var createdAt: Date = .now
    var updatedAt: Date = .now
}

enum NoteAttachmentKind: String, Codable, Sendable { case image }
struct NoteAttachment: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var kind: NoteAttachmentKind = .image
    var fileName: String
    var createdAt: Date = .now
    var caption: String = ""
}
struct VoiceRecording: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var fileName: String
    var duration: TimeInterval
    var createdAt: Date = .now
    var title: String = "Sprachnotiz"
}

struct NoteItem: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var body: String = ""
    var color: NoteColorToken = .cyan
    var pinned: Bool = false
    var folderID: UUID?
    var tags: [String] = []
    var attachments: [NoteAttachment] = []
    var recordings: [VoiceRecording] = []
    var archived: Bool = false
    var deletedAt: Date?
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var preview: String {
        let stripped = body.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "").replacingOccurrences(of: "#", with: "")
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Keine weiteren Inhalte" : trimmed
    }
    var normalizedTags: [String] { Array(Set(tags.map(ReminderItem.normalizeTag).filter { !$0.isEmpty })).sorted() }
    var hasMedia: Bool { !attachments.isEmpty || !recordings.isEmpty }
    var isTrashed: Bool { deletedAt != nil }

    private enum CodingKeys: String, CodingKey {
        case id, title, body, color, pinned, folderID, tags, attachments, recordings
        case archived, deletedAt, createdAt, updatedAt
    }
    init(
        id: UUID = UUID(), title: String, body: String = "", color: NoteColorToken = .cyan,
        pinned: Bool = false, folderID: UUID? = nil, tags: [String] = [],
        attachments: [NoteAttachment] = [], recordings: [VoiceRecording] = [],
        archived: Bool = false, deletedAt: Date? = nil, createdAt: Date = .now, updatedAt: Date = .now
    ) {
        self.id = id; self.title = title; self.body = body; self.color = color; self.pinned = pinned
        self.folderID = folderID; self.tags = tags; self.attachments = attachments; self.recordings = recordings
        self.archived = archived; self.deletedAt = deletedAt; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try box.decode(String.self, forKey: .title)
        body = try box.decodeIfPresent(String.self, forKey: .body) ?? ""
        color = try box.decodeIfPresent(NoteColorToken.self, forKey: .color) ?? .cyan
        pinned = try box.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        folderID = try box.decodeIfPresent(UUID.self, forKey: .folderID)
        tags = try box.decodeIfPresent([String].self, forKey: .tags) ?? []
        attachments = try box.decodeIfPresent([NoteAttachment].self, forKey: .attachments) ?? []
        recordings = try box.decodeIfPresent([VoiceRecording].self, forKey: .recordings) ?? []
        archived = try box.decodeIfPresent(Bool.self, forKey: .archived) ?? false
        deletedAt = try box.decodeIfPresent(Date.self, forKey: .deletedAt)
        createdAt = try box.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try box.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

struct CustomAlarmSound: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var fileName: String
    var duration: TimeInterval
    var importedAt: Date = .now
}

struct AlarmRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var fireDate: Date
    var weekdays: [RJWeekday] = []
    var enabled: Bool = true
    var soundFile: String = "default"
    var snoozeMinutes: Int = 9
    var preAlertMinutes: Int = 0
    var accent: TimerAccentToken = .purple
    var createdAt: Date = .now
    var isRepeating: Bool { !weekdays.isEmpty }
    var repeatSummary: String {
        guard isRepeating else { return "Einmalig" }
        if Set(weekdays) == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) { return "Werktags" }
        if Set(weekdays) == Set(RJWeekday.allCases) { return "Täglich" }
        let order: [RJWeekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        return weekdays.sorted { (order.firstIndex(of: $0) ?? 0) < (order.firstIndex(of: $1) ?? 0) }
            .map(\.shortTitle).joined(separator: ", ")
    }
    func nextFireDate(after date: Date = .now, calendar: Calendar = .current) -> Date? {
        if !isRepeating { return fireDate > date ? fireDate : nil }
        let hour = calendar.component(.hour, from: fireDate), minute = calendar.component(.minute, from: fireDate)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date),
                  let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { continue }
            let weekday = calendar.component(.weekday, from: candidate)
            if weekdays.contains(where: { $0.rawValue == weekday }), candidate > date { return candidate }
        }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, fireDate, weekdays, enabled, soundFile, snoozeMinutes, preAlertMinutes, accent, createdAt
    }
    init(
        id: UUID = UUID(), title: String, fireDate: Date, weekdays: [RJWeekday] = [],
        enabled: Bool = true, soundFile: String = "default", snoozeMinutes: Int = 9,
        preAlertMinutes: Int = 0, accent: TimerAccentToken = .purple, createdAt: Date = .now
    ) {
        self.id = id; self.title = title; self.fireDate = fireDate; self.weekdays = weekdays
        self.enabled = enabled; self.soundFile = soundFile; self.snoozeMinutes = snoozeMinutes
        self.preAlertMinutes = preAlertMinutes; self.accent = accent; self.createdAt = createdAt
    }
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        id = try box.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try box.decode(String.self, forKey: .title)
        fireDate = try box.decode(Date.self, forKey: .fireDate)
        weekdays = try box.decodeIfPresent([RJWeekday].self, forKey: .weekdays) ?? []
        enabled = try box.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        soundFile = try box.decodeIfPresent(String.self, forKey: .soundFile) ?? "default"
        snoozeMinutes = try box.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 9
        preAlertMinutes = try box.decodeIfPresent(Int.self, forKey: .preAlertMinutes) ?? 0
        accent = try box.decodeIfPresent(TimerAccentToken.self, forKey: .accent) ?? .purple
        createdAt = try box.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }
}

struct CalendarEventSnapshot: Identifiable, Hashable, Sendable {
    let id: String, title: String
    let startDate: Date, endDate: Date
    let isAllDay: Bool, calendarTitle: String
    let colorComponents: [Double]
    let location: String?
}

struct SystemReminderSnapshot: Identifiable, Hashable, Sendable {
    let id: String, title: String
    let dueDate: Date?
    let completed: Bool, calendarTitle: String
}

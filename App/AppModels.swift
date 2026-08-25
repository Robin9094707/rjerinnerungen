import Foundation
import SwiftUI

enum RJPriority: String, Codable, CaseIterable, Identifiable, Sendable {
    case low
    case normal
    case high
    case urgent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Niedrig"
        case .normal: "Normal"
        case .high: "Hoch"
        case .urgent: "Dringend"
        }
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
        switch self {
        case .low: .blue
        case .normal: .cyan
        case .high: .orange
        case .urgent: .red
        }
    }
}

enum RJRecurrence: String, Codable, CaseIterable, Identifiable, Sendable {
    case never
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: "Nie"
        case .daily: "Täglich"
        case .weekly: "Wöchentlich"
        case .monthly: "Monatlich"
        }
    }
}

struct ReminderItem: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var details: String = ""
    var dueDate: Date?
    var hasTime: Bool = true
    var priority: RJPriority = .normal
    var recurrence: RJRecurrence = .never
    var notificationEnabled: Bool = true
    var alarmEscalation: Bool = false
    var completed: Bool = false
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var systemReminderIdentifier: String?

    var isOverdue: Bool {
        guard !completed, let dueDate else { return false }
        return dueDate < .now
    }

    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let dueDate else { return false }
        if calendar.isDate(dueDate, inSameDayAs: date) { return true }
        guard dueDate <= date else { return false }
        switch recurrence {
        case .never:
            return false
        case .daily:
            return true
        case .weekly:
            return calendar.component(.weekday, from: dueDate) == calendar.component(.weekday, from: date)
        case .monthly:
            return calendar.component(.day, from: dueDate) == calendar.component(.day, from: date)
        }
    }
}

enum NoteColorToken: String, Codable, CaseIterable, Identifiable, Sendable {
    case cyan
    case blue
    case purple
    case pink
    case orange
    case green

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .cyan: .cyan
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        case .orange: .orange
        case .green: .green
        }
    }
}

struct NoteItem: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var body: String = ""
    var color: NoteColorToken = .cyan
    var pinned: Bool = false
    var createdAt: Date = .now
    var updatedAt: Date = .now

    var preview: String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Keine weiteren Inhalte" : trimmed
    }
}

enum RJWeekday: Int, Codable, CaseIterable, Identifiable, Sendable {
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    case sunday = 1

    var id: Int { rawValue }

    var shortTitle: String {
        switch self {
        case .monday: "Mo"
        case .tuesday: "Di"
        case .wednesday: "Mi"
        case .thursday: "Do"
        case .friday: "Fr"
        case .saturday: "Sa"
        case .sunday: "So"
        }
    }

    var localeWeekday: Locale.Weekday {
        switch self {
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        case .sunday: .sunday
        }
    }
}

struct AlarmRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var fireDate: Date
    var weekdays: [RJWeekday] = []
    var enabled: Bool = true
    var soundFile: String = "default"
    var snoozeMinutes: Int = 9
    var accent: TimerAccentToken = .purple
    var createdAt: Date = .now

    var isRepeating: Bool { !weekdays.isEmpty }

    var repeatSummary: String {
        guard isRepeating else { return "Einmalig" }
        if Set(weekdays) == Set([.monday, .tuesday, .wednesday, .thursday, .friday]) {
            return "Werktags"
        }
        if Set(weekdays) == Set(RJWeekday.allCases) { return "Täglich" }
        return weekdays.sorted { $0.rawValue < $1.rawValue }.map(\.shortTitle).joined(separator: ", ")
    }

    func nextFireDate(after date: Date = .now, calendar: Calendar = .current) -> Date? {
        if !isRepeating { return fireDate > date ? fireDate : nil }
        let hour = calendar.component(.hour, from: fireDate)
        let minute = calendar.component(.minute, from: fireDate)
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date),
                  let candidate = calendar.date(
                    bySettingHour: hour,
                    minute: minute,
                    second: 0,
                    of: day
                  ) else { continue }
            let weekday = calendar.component(.weekday, from: candidate)
            if weekdays.contains(where: { $0.rawValue == weekday }), candidate > date {
                return candidate
            }
        }
        return nil
    }
}

struct CalendarEventSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let colorComponents: [Double]
    let location: String?
}

struct SystemReminderSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let dueDate: Date?
    let completed: Bool
    let calendarTitle: String
}

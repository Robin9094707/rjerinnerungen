import Foundation
import SwiftData

@Model
final class RJReminder {
    @Attribute(.unique) var id: UUID
    var title: String
    var notes: String
    var dueDate: Date
    var hasDueDate: Bool
    var priorityRaw: String
    var categoryRaw: String
    var recurrenceRaw: String
    var tags: [String]
    var preAlertMinutes: [Int]
    var isCompleted: Bool
    var notificationEnabled: Bool
    var liveActivityEnabled: Bool
    var snoozeMinutes: Int
    var createdAt: Date
    var modifiedAt: Date
    var completedAt: Date?
    var importedFromApple: Bool
    var externalIdentifier: String?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueDate: Date = .now.addingTimeInterval(3600),
        hasDueDate: Bool = true,
        priority: ReminderPriority = .normal,
        category: ReminderCategory = .personal,
        recurrence: ReminderRecurrence = .none,
        tags: [String] = [],
        preAlertMinutes: [Int] = [],
        notificationEnabled: Bool = true,
        liveActivityEnabled: Bool = false,
        snoozeMinutes: Int = 10,
        importedFromApple: Bool = false,
        externalIdentifier: String? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.hasDueDate = hasDueDate
        self.priorityRaw = priority.rawValue
        self.categoryRaw = category.rawValue
        self.recurrenceRaw = recurrence.rawValue
        self.tags = tags
        self.preAlertMinutes = preAlertMinutes
        self.isCompleted = false
        self.notificationEnabled = notificationEnabled
        self.liveActivityEnabled = liveActivityEnabled
        self.snoozeMinutes = snoozeMinutes
        self.createdAt = .now
        self.modifiedAt = .now
        self.completedAt = nil
        self.importedFromApple = importedFromApple
        self.externalIdentifier = externalIdentifier
    }

    var priority: ReminderPriority {
        get { ReminderPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    var category: ReminderCategory {
        get { ReminderCategory(rawValue: categoryRaw) ?? .personal }
        set { categoryRaw = newValue.rawValue }
    }

    var recurrence: ReminderRecurrence {
        get { ReminderRecurrence(rawValue: recurrenceRaw) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }

    var isOverdue: Bool {
        hasDueDate && !isCompleted && dueDate < .now
    }
}

enum ReminderPriority: String, Codable, CaseIterable, Identifiable {
    case low
    case normal
    case important
    case high
    case urgent
    case ultra

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: "Niedrig"
        case .normal: "Normal"
        case .important: "Wichtig"
        case .high: "Hoch"
        case .urgent: "Dringend"
        case .ultra: "Ultra"
        }
    }

    var subtitle: String {
        switch self {
        case .low: "Leise und unaufdringlich"
        case .normal: "Normale Erinnerung"
        case .important: "Deutlich hervorgehoben"
        case .high: "Time Sensitive"
        case .urgent: "Time Sensitive + starke Haptik"
        case .ultra: "Kritisch, falls Apple-Entitlement vorhanden; sonst Time Sensitive"
        }
    }

    var symbolName: String {
        switch self {
        case .low: "arrow.down.circle"
        case .normal: "bell"
        case .important: "exclamationmark.circle"
        case .high: "exclamationmark.triangle"
        case .urgent: "bolt.circle"
        case .ultra: "bolt.shield.fill"
        }
    }

    var sortRank: Int {
        switch self {
        case .low: 0
        case .normal: 1
        case .important: 2
        case .high: 3
        case .urgent: 4
        case .ultra: 5
        }
    }
}

enum ReminderCategory: String, Codable, CaseIterable, Identifiable {
    case personal
    case work
    case shopping
    case health
    case finance
    case travel
    case home
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: "Privat"
        case .work: "Arbeit"
        case .shopping: "Einkaufen"
        case .health: "Gesundheit"
        case .finance: "Finanzen"
        case .travel: "Unterwegs"
        case .home: "Zuhause"
        case .custom: "Sonstiges"
        }
    }

    var symbolName: String {
        switch self {
        case .personal: "person.crop.circle"
        case .work: "briefcase"
        case .shopping: "cart"
        case .health: "heart"
        case .finance: "eurosign.circle"
        case .travel: "location"
        case .home: "house"
        case .custom: "square.grid.2x2"
        }
    }
}

enum ReminderRecurrence: String, Codable, CaseIterable, Identifiable {
    case none
    case daily
    case weekdays
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Nie"
        case .daily: "Täglich"
        case .weekdays: "Mo–Fr"
        case .weekly: "Wöchentlich"
        case .monthly: "Monatlich"
        case .yearly: "Jährlich"
        }
    }
}

struct ReminderTransferRecord: Codable, Identifiable {
    var id: UUID
    var title: String
    var notes: String
    var dueDate: Date
    var hasDueDate: Bool
    var priority: ReminderPriority
    var category: ReminderCategory
    var recurrence: ReminderRecurrence
    var tags: [String]
    var preAlertMinutes: [Int]
    var isCompleted: Bool
    var notificationEnabled: Bool
    var liveActivityEnabled: Bool
    var snoozeMinutes: Int
    var createdAt: Date
    var modifiedAt: Date
    var completedAt: Date?
    var importedFromApple: Bool
    var externalIdentifier: String?

    init(_ reminder: RJReminder) {
        id = reminder.id
        title = reminder.title
        notes = reminder.notes
        dueDate = reminder.dueDate
        hasDueDate = reminder.hasDueDate
        priority = reminder.priority
        category = reminder.category
        recurrence = reminder.recurrence
        tags = reminder.tags
        preAlertMinutes = reminder.preAlertMinutes
        isCompleted = reminder.isCompleted
        notificationEnabled = reminder.notificationEnabled
        liveActivityEnabled = reminder.liveActivityEnabled
        snoozeMinutes = reminder.snoozeMinutes
        createdAt = reminder.createdAt
        modifiedAt = reminder.modifiedAt
        completedAt = reminder.completedAt
        importedFromApple = reminder.importedFromApple
        externalIdentifier = reminder.externalIdentifier
    }

    func makeModel() -> RJReminder {
        let item = RJReminder(
            id: id,
            title: title,
            notes: notes,
            dueDate: dueDate,
            hasDueDate: hasDueDate,
            priority: priority,
            category: category,
            recurrence: recurrence,
            tags: tags,
            preAlertMinutes: preAlertMinutes,
            notificationEnabled: notificationEnabled,
            liveActivityEnabled: liveActivityEnabled,
            snoozeMinutes: snoozeMinutes,
            importedFromApple: importedFromApple,
            externalIdentifier: externalIdentifier
        )
        item.isCompleted = isCompleted
        item.createdAt = createdAt
        item.modifiedAt = modifiedAt
        item.completedAt = completedAt
        return item
    }
}

struct ReminderBackup: Codable {
    var formatVersion: Int = 1
    var exportedAt: Date = .now
    var reminders: [ReminderTransferRecord]
}

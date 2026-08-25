import AppIntents
import Foundation

struct QuickIntentRecord: Codable {
    var title: String
    var dueDate: Date
    var priority: ReminderPriority
}

enum QuickIntentInbox {
    private static let key = "RJQuickIntentInbox"

    static func append(_ record: QuickIntentRecord) {
        var values = consume(shouldClear: false)
        values.append(record)
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func consume() -> [QuickIntentRecord] { consume(shouldClear: true) }

    private static func consume(shouldClear: Bool) -> [QuickIntentRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let values = try? JSONDecoder().decode([QuickIntentRecord].self, from: data) else { return [] }
        if shouldClear { UserDefaults.standard.removeObject(forKey: key) }
        return values
    }
}

enum ShortcutPriority: String, AppEnum {
    case normal
    case important
    case urgent
    case ultra

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Priorität")
    static var caseDisplayRepresentations: [ShortcutPriority: DisplayRepresentation] = [
        .normal: "Normal",
        .important: "Wichtig",
        .urgent: "Dringend",
        .ultra: "Ultra"
    ]

    var modelValue: ReminderPriority {
        switch self {
        case .normal: .normal
        case .important: .important
        case .urgent: .urgent
        case .ultra: .ultra
        }
    }
}

struct QuickReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Schnelle RJ-Erinnerung"
    static var description = IntentDescription("Erstellt eine Erinnerung in RJ Ultra Erinnerungen und plant die Benachrichtigung sofort.")

    @Parameter(title: "Titel") var reminderTitle: String
    @Parameter(title: "In wie vielen Minuten?") var minutes: Int
    @Parameter(title: "Priorität", default: .normal) var priority: ShortcutPriority

    static var parameterSummary: some ParameterSummary {
        let summary: ParameterSummaryString<QuickReminderIntent> =
            "Erinnere mich an \(.$reminderTitle) in \(.$minutes) Minuten"
        return Summary(summary)
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let safeMinutes = min(max(minutes, 1), 10_080)
        let dueDate = Date.now.addingTimeInterval(TimeInterval(safeMinutes * 60))
        let record = QuickIntentRecord(title: reminderTitle, dueDate: dueDate, priority: priority.modelValue)
        QuickIntentInbox.append(record)

        let item = RJReminder(title: reminderTitle, dueDate: dueDate, priority: priority.modelValue)
        try? await NotificationService.shared.schedule(item)
        return .result(dialog: "Erinnerung für \(safeMinutes) Minuten angelegt.")
    }
}

struct RJUltraRemindersShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickReminderIntent(),
            phrases: [
                "Neue Erinnerung mit \(.applicationName)",
                "Erinnere mich mit \(.applicationName)"
            ],
            shortTitle: "Ultra Erinnerung",
            systemImageName: "bell.badge.fill"
        )
    }
}

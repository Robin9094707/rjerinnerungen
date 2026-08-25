import AlarmKit
import AppIntents
import Foundation

private enum QuickTimerIntentRunner {
    static func start(minutes: Int, label: String) async throws -> String {
        guard AlarmManager.shared.authorizationState == .authorized else {
            return "Öffne RJ ZeitZentrale einmal und erlaube AlarmKit."
        }

        let safeMinutes = min(max(minutes, 1), 720)
        let title = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(safeMinutes)-Minuten-Timer"
            : label

        let record = TimerRecord(
            title: title,
            symbol: safeMinutes >= 20 ? "brain.head.profile.fill" : "timer",
            accent: safeMinutes >= 20 ? .pink : .cyan,
            soundFile: "glass_chime.wav",
            duration: TimeInterval(safeMinutes * 60)
        )

        try await RJAlarmFactory.schedule(record, duration: record.originalDuration)
        return "\(record.title) läuft."
    }
}

struct StartQuickTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Timer starten"
    static var description = IntentDescription("Startet sofort einen Systemtimer in RJ ZeitZentrale.")

    @Parameter(title: "Minuten")
    var minutes: Int

    @Parameter(title: "Name")
    var label: String

    init(minutes: Int, label: String) {
        self.minutes = minutes
        self.label = label
    }

    init() {
        self.minutes = 5
        self.label = "Timer"
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await QuickTimerIntentRunner.start(
            minutes: minutes,
            label: label
        )
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct StartFiveMinuteTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "5-Minuten-Timer"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await QuickTimerIntentRunner.start(
            minutes: 5,
            label: "5 Minuten"
        )
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct StartPomodoroTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pomodoro starten"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await QuickTimerIntentRunner.start(
            minutes: 25,
            label: "Pomodoro"
        )
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

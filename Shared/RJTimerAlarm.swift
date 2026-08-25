import AlarmKit
import ActivityKit
import AppIntents
import Foundation
import SwiftUI

enum RJAlarmKind: String, Codable, Hashable, Sendable {
    case timer
    case scheduledAlarm
}

struct RJTimerAlarmMetadata: AlarmMetadata {
    var timerID: String
    var title: String
    var symbol: String
    var accent: TimerAccentToken
    var originalDuration: TimeInterval
    var soundFile: String
    var kind: RJAlarmKind = .timer
    var fireDate: Date? = nil
}

enum RJAlarmFactory {
    static func attributes(for timer: TimerRecord) -> AlarmAttributes<RJTimerAlarmMetadata> {
        let repeatButton = AlarmButton(
            text: "Wiederholen",
            textColor: timer.accent.color,
            systemImageName: "repeat"
        )

        let alertTitle = LocalizedStringResource(stringLiteral: "\(timer.title) ist fertig")
        let countdownTitle = LocalizedStringResource(stringLiteral: timer.title)

        let alert = AlarmPresentation.Alert(
            title: alertTitle,
            secondaryButton: repeatButton,
            secondaryButtonBehavior: .countdown
        )

        let pauseButton = AlarmButton(
            text: "Pause",
            textColor: timer.accent.color,
            systemImageName: "pause.fill"
        )

        let countdown = AlarmPresentation.Countdown(
            title: countdownTitle,
            pauseButton: pauseButton
        )

        let resumeButton = AlarmButton(
            text: "Fortsetzen",
            textColor: timer.accent.color,
            systemImageName: "play.fill"
        )

        let paused = AlarmPresentation.Paused(
            title: "Timer pausiert",
            resumeButton: resumeButton
        )

        let metadata = RJTimerAlarmMetadata(
            timerID: timer.id.uuidString,
            title: timer.title,
            symbol: timer.symbol,
            accent: timer.accent,
            originalDuration: timer.originalDuration,
            soundFile: timer.soundFile
        )

        return AlarmAttributes(
            presentation: AlarmPresentation(
                alert: alert,
                countdown: countdown,
                paused: paused
            ),
            metadata: metadata,
            tintColor: timer.accent.color
        )
    }

    static func configuration(
        for timer: TimerRecord,
        duration: TimeInterval
    ) -> AlarmManager.AlarmConfiguration<RJTimerAlarmMetadata> {
        let safeDuration = max(1, duration)
        let countdown = Alarm.CountdownDuration(
            preAlert: safeDuration,
            postAlert: safeDuration
        )
        let sound: AlertConfiguration.AlertSound =
            timer.soundFile == "default" ? .default : .named(timer.soundFile)

        return AlarmManager.AlarmConfiguration(
            countdownDuration: countdown,
            schedule: nil,
            attributes: attributes(for: timer),
            stopIntent: StopRJAlarmIntent(alarmID: timer.id.uuidString),
            secondaryIntent: nil,
            sound: sound
        )
    }

    static func schedule(_ timer: TimerRecord, duration: TimeInterval) async throws {
        _ = try await AlarmManager.shared.schedule(
            id: timer.id,
            configuration: configuration(for: timer, duration: duration)
        )
    }
}

struct PauseRJAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Timer pausieren"

    @Parameter(title: "Alarm-ID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try AlarmManager.shared.pause(id: id)
        }
        return .result()
    }
}

struct ResumeRJAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Timer fortsetzen"

    @Parameter(title: "Alarm-ID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try AlarmManager.shared.resume(id: id)
        }
        return .result()
    }
}

struct StopRJAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Timer stoppen"

    @Parameter(title: "Alarm-ID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }
        return .result()
    }
}

struct RepeatRJAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Timer wiederholen"

    @Parameter(title: "Alarm-ID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try AlarmManager.shared.countdown(id: id)
        }
        return .result()
    }
}

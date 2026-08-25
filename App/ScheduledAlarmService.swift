import AlarmKit
import ActivityKit
import Foundation
import Observation
import SwiftUI

enum ScheduledAlarmError: LocalizedError {
    case permissionDenied
    case invalidDate

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "AlarmKit wurde nicht erlaubt. Aktiviere Systemwecker in den Einstellungen."
        case .invalidDate:
            "Der Weckzeitpunkt liegt nicht in der Zukunft."
        }
    }
}

@MainActor
@Observable
final class ScheduledAlarmService {
    static let shared = ScheduledAlarmService()

    func schedule(_ alarm: AlarmRecord) async throws {
        guard await AlarmKitService.shared.ensureAuthorization() else {
            throw ScheduledAlarmError.permissionDenied
        }

        let schedule: Alarm.Schedule
        if alarm.isRepeating {
            let components = Calendar.current.dateComponents([.hour, .minute], from: alarm.fireDate)
            let time = Alarm.Schedule.Relative.Time(
                hour: components.hour ?? 7,
                minute: components.minute ?? 0
            )
            let days = alarm.weekdays.map(\.localeWeekday)
            schedule = .relative(
                Alarm.Schedule.Relative(
                    time: time,
                    repeats: .weekly(days)
                )
            )
        } else {
            guard alarm.fireDate > .now else { throw ScheduledAlarmError.invalidDate }
            schedule = .fixed(alarm.fireDate)
        }

        let metadata = RJTimerAlarmMetadata(
            timerID: alarm.id.uuidString,
            title: alarm.title,
            symbol: "alarm.waves.left.and.right.fill",
            accent: alarm.accent,
            originalDuration: TimeInterval(alarm.snoozeMinutes * 60),
            soundFile: alarm.soundFile,
            kind: .scheduledAlarm,
            fireDate: alarm.nextFireDate()
        )
        let stopButton = AlarmButton(
            text: "Stoppen",
            textColor: .white,
            systemImageName: "stop.circle.fill"
        )
        let snoozeButton = AlarmButton(
            text: "Snooze",
            textColor: alarm.accent.color,
            systemImageName: "zzz"
        )
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.title),
            stopButton: stopButton,
            secondaryButton: snoozeButton,
            secondaryButtonBehavior: .countdown
        )
        let countdown = AlarmPresentation.Countdown(
            title: "Snooze: \(alarm.title)",
            pauseButton: AlarmButton(
                text: "Pause",
                textColor: alarm.accent.color,
                systemImageName: "pause.fill"
            )
        )
        let paused = AlarmPresentation.Paused(
            title: "Snooze pausiert",
            resumeButton: AlarmButton(
                text: "Fortsetzen",
                textColor: alarm.accent.color,
                systemImageName: "play.fill"
            )
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(
                alert: alert,
                countdown: countdown,
                paused: paused
            ),
            metadata: metadata,
            tintColor: alarm.accent.color
        )
        let sound: AlertConfiguration.AlertSound = alarm.soundFile == "default"
            ? .default
            : .named(alarm.soundFile)
        let configuration = AlarmManager.AlarmConfiguration(
            countdownDuration: Alarm.CountdownDuration(
                preAlert: nil,
                postAlert: TimeInterval(max(1, alarm.snoozeMinutes) * 60)
            ),
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopRJAlarmIntent(alarmID: alarm.id.uuidString),
            secondaryIntent: nil,
            sound: sound
        )
        _ = try await AlarmManager.shared.schedule(id: alarm.id, configuration: configuration)
        DebugLogger.shared.log("AlarmKit wake alarm scheduled: \(alarm.id)")
    }

    func scheduleEscalation(for reminder: ReminderItem) async throws {
        guard let dueDate = reminder.dueDate else { throw ScheduledAlarmError.invalidDate }
        let alarm = AlarmRecord(
            id: reminder.id,
            title: reminder.title,
            fireDate: dueDate,
            weekdays: [],
            enabled: true,
            soundFile: "default",
            snoozeMinutes: 9,
            accent: .orange
        )
        try await schedule(alarm)
    }

    func cancel(_ id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
    }
}

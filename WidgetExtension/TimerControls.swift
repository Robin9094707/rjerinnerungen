import AppIntents
import SwiftUI
import WidgetKit

struct FiveMinuteControl: ControlWidget {
    static let kind = "eu.rjuhas.zeitzentrale.control.5min"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartFiveMinuteTimerIntent()) {
                Label("5-Min-Timer", systemImage: "timer")
            }
        }
        .displayName("5-Minuten-Timer")
        .description("Startet sofort einen 5-Minuten-Systemtimer.")
    }
}

struct PomodoroControl: ControlWidget {
    static let kind = "eu.rjuhas.zeitzentrale.control.pomodoro"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartPomodoroTimerIntent()) {
                Label("Pomodoro", systemImage: "brain.head.profile.fill")
            }
        }
        .displayName("Pomodoro")
        .description("Startet sofort einen 25-Minuten-Fokustimer.")
    }
}

import AppIntents

struct RJZeitZentraleShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFiveMinuteTimerIntent(),
            phrases: [
                "Starte fünf Minuten mit \(.applicationName)",
                "Fünf Minuten in \(.applicationName)"
            ],
            shortTitle: "5-Minuten-Timer",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: StartPomodoroTimerIntent(),
            phrases: [
                "Starte Pomodoro mit \(.applicationName)",
                "Fokus mit \(.applicationName)"
            ],
            shortTitle: "Pomodoro",
            systemImageName: "brain.head.profile.fill"
        )
    }
}

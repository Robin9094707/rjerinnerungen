import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case center
        case planner
        case timers
        case notes
        case more
    }

    var selectedTab: Tab = .center
    var requestedTimerID: UUID?
    var requestedAlarmID: UUID?
    var requestedReminderID: UUID?
    var requestedNoteID: UUID?
    var showNewReminder = false
    var showNewNote = false
    var showNewTimer = false
    var showNewAlarm = false

    func handle(_ url: URL) {
        guard url.scheme == "rjzentrale" else { return }
        let rawID = url.pathComponents.dropFirst().first

        switch url.host {
        case "timer":
            selectedTab = .timers
            requestedTimerID = rawID.flatMap(UUID.init(uuidString:))
        case "alarm":
            selectedTab = .more
            requestedAlarmID = rawID.flatMap(UUID.init(uuidString:))
        case "reminder":
            selectedTab = .planner
            requestedReminderID = rawID.flatMap(UUID.init(uuidString:))
        case "note":
            selectedTab = .notes
            requestedNoteID = rawID.flatMap(UUID.init(uuidString:))
        case "new-reminder":
            selectedTab = .planner
            showNewReminder = true
        case "new-note":
            selectedTab = .notes
            showNewNote = true
        case "new-timer":
            selectedTab = .timers
            showNewTimer = true
        case "new-alarm":
            selectedTab = .center
            showNewAlarm = true
        default:
            selectedTab = .center
        }
    }

    func handle(_ action: RJQuickAction) {
        switch action {
        case .newReminder:
            selectedTab = .planner
            showNewReminder = true
        case .newNote:
            selectedTab = .notes
            showNewNote = true
        case .newTimer:
            selectedTab = .timers
            showNewTimer = true
        case .newAlarm:
            selectedTab = .center
            showNewAlarm = true
        }
    }
}

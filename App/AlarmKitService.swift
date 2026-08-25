import ActivityKit
import AlarmKit
import Foundation
import Observation

@MainActor
@Observable
final class AlarmKitService {
    static let shared = AlarmKitService()

    private(set) var authorizationState = AlarmManager.shared.authorizationState

    func refreshAuthorization() {
        authorizationState = AlarmManager.shared.authorizationState
    }

    func requestAuthorization() async -> Bool {
        do {
            let state = try await AlarmManager.shared.requestAuthorization()
            authorizationState = state
            DebugLogger.shared.log("AlarmKit authorization: \(String(describing: state))")
            return state == .authorized
        } catch {
            DebugLogger.shared.log("AlarmKit authorization error: \(error)")
            return false
        }
    }

    func ensureAuthorization() async -> Bool {
        refreshAuthorization()
        switch authorizationState {
        case .authorized:
            return true
        case .notDetermined:
            return await requestAuthorization()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func schedule(_ timer: TimerRecord, duration: TimeInterval) async throws {
        guard await ensureAuthorization() else {
            throw TimerServiceError.alarmPermissionDenied
        }
        try await RJAlarmFactory.schedule(timer, duration: duration)
        DebugLogger.shared.log("AlarmKit scheduled \(timer.id) \(timer.title) \(duration)s")
    }

    func pause(id: UUID) throws {
        try AlarmManager.shared.pause(id: id)
        DebugLogger.shared.log("AlarmKit pause \(id)")
    }

    func resume(id: UUID) throws {
        try AlarmManager.shared.resume(id: id)
        DebugLogger.shared.log("AlarmKit resume \(id)")
    }

    func stop(id: UUID) {
        do {
            try AlarmManager.shared.stop(id: id)
        } catch {
            try? AlarmManager.shared.cancel(id: id)
        }
        DebugLogger.shared.log("AlarmKit stop \(id)")
    }

    func cancel(id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
        DebugLogger.shared.log("AlarmKit cancel \(id)")
    }

    func currentAlarms() -> [Alarm] {
        (try? AlarmManager.shared.alarms) ?? []
    }
}

enum TimerServiceError: LocalizedError {
    case alarmPermissionDenied
    case invalidDuration

    var errorDescription: String? {
        switch self {
        case .alarmPermissionDenied:
            "AlarmKit ist nicht erlaubt. Aktiviere die Berechtigung in RJ ZeitZentrale oder in den iOS-Einstellungen."
        case .invalidDuration:
            "Die Timer-Dauer muss mindestens eine Sekunde betragen."
        }
    }
}

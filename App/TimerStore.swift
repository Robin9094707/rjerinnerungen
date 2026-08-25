import ActivityKit
import AlarmKit
import Foundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class TimerStore {
    private(set) var timers: [TimerRecord] = []
    private(set) var presets: [TimerPreset] = []
    private(set) var history: [TimerHistoryEntry] = []

    var lastError: String?
    var lastCompletedTimer: TimerRecord?

    private var alarmObservationTask: Task<Void, Never>?

    init() {
        load()
        if presets.isEmpty {
            presets = TimerPresetDefaults.values
            savePresets()
        }
    }

    var activeTimers: [TimerRecord] {
        timers
            .filter(\.isActive)
            .sorted {
                if $0.state == .alerting && $1.state != .alerting { return true }
                if $1.state == .alerting && $0.state != .alerting { return false }
                return $0.remaining() < $1.remaining()
            }
    }

    var finishedTimers: [TimerRecord] {
        timers.filter { !$0.isActive }
    }

    func bootstrap() async {
        DebugLogger.shared.load()
        await syncFromSystem()
        observeAlarmKit()
        reconcileMissingAlarms()
    }

    func startTimer(
        title: String,
        duration: TimeInterval,
        symbol: String,
        accent: TimerAccentToken,
        soundFile: String,
        favorite: Bool = false
    ) async {
        guard duration >= 1 else {
            lastError = TimerServiceError.invalidDuration.localizedDescription
            return
        }

        let record = TimerRecord(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Timer" : title,
            symbol: symbol,
            accent: accent,
            soundFile: soundFile,
            duration: duration,
            favorite: favorite
        )

        do {
            try await AlarmKitService.shared.schedule(record, duration: duration)
            timers.removeAll { $0.id == record.id }
            timers.insert(record, at: 0)
            saveTimers()
            Haptics.success()
        } catch {
            lastError = error.localizedDescription
            DebugLogger.shared.log("Start timer failed: \(error)")
        }
    }

    func startPreset(_ preset: TimerPreset) async {
        await startTimer(
            title: preset.title,
            duration: preset.duration,
            symbol: preset.symbol,
            accent: preset.accent,
            soundFile: preset.soundFile,
            favorite: preset.favorite
        )
    }

    func pause(_ id: UUID) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        var record = timers[index]
        guard record.state == .running else { return }

        do {
            try AlarmKitService.shared.pause(id: id)
            record.elapsedBeforeRun = record.elapsed()
            record.startedAt = nil
            record.state = .paused
            timers[index] = record
            saveTimers()
            Haptics.impact(.soft)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func resume(_ id: UUID) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        var record = timers[index]
        guard record.state == .paused else { return }

        do {
            try AlarmKitService.shared.resume(id: id)
            record.startedAt = .now
            record.state = .running
            timers[index] = record
            saveTimers()
            Haptics.impact(.soft)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop(_ id: UUID, recordHistory: Bool = true) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        var record = timers[index]
        let elapsed = record.elapsed()

        AlarmKitService.shared.stop(id: id)
        record.elapsedBeforeRun = elapsed
        record.startedAt = nil
        record.state = .stopped
        timers[index] = record

        if recordHistory && elapsed > 0.5 {
            history.insert(
                TimerHistoryEntry(
                    timerID: record.id,
                    title: record.title,
                    plannedDuration: record.originalDuration,
                    actualDuration: elapsed,
                    finishedAt: .now,
                    outcome: .stopped,
                    accent: record.accent
                ),
                at: 0
            )
            saveHistory()
        }

        saveTimers()
        Haptics.warning()
    }

    func restart(_ id: UUID) async {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        var record = timers[index]
        AlarmKitService.shared.cancel(id: id)

        record.elapsedBeforeRun = 0
        record.startedAt = .now
        record.state = .running

        do {
            try await AlarmKitService.shared.schedule(record, duration: record.originalDuration)
            timers[index] = record
            saveTimers()
            Haptics.success()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addTime(_ id: UUID, seconds: TimeInterval) async {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        var record = timers[index]
        let remaining = record.remaining()
        let newRemaining = max(1, remaining + seconds)

        AlarmKitService.shared.cancel(id: id)

        record.originalDuration = newRemaining
        record.elapsedBeforeRun = 0
        record.startedAt = .now
        record.state = .running

        do {
            try await AlarmKitService.shared.schedule(record, duration: newRemaining)
            timers[index] = record
            saveTimers()
            Haptics.impact(.light)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteTimer(_ id: UUID) {
        AlarmKitService.shared.cancel(id: id)
        timers.removeAll { $0.id == id }
        saveTimers()
    }

    func replaceSoundReferences(_ fileName: String, with replacement: String = "default") {
        for index in timers.indices where timers[index].soundFile == fileName {
            // Active AlarmKit timers keep their already-copied system sound until
            // they finish. Deletion is blocked by the UI while one is active.
            timers[index].soundFile = replacement
        }
        for index in presets.indices where presets[index].soundFile == fileName {
            presets[index].soundFile = replacement
        }
        saveTimers()
        savePresets()
    }

    func addPreset(_ preset: TimerPreset) {
        presets.insert(preset, at: 0)
        savePresets()
    }

    func deletePresets(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        savePresets()
    }

    func deletePreset(_ id: UUID) {
        presets.removeAll { $0.id == id }
        savePresets()
    }

    func togglePresetFavorite(_ id: UUID) {
        guard let index = presets.firstIndex(where: { $0.id == id }) else { return }
        presets[index].favorite.toggle()
        savePresets()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        saveHistory()
    }

    func exportURL() -> URL? {
        try? AppPersistence.exportTimerBundle(
            timers: timers,
            presets: presets,
            history: history
        )
    }

    func syncFromSystem() async {
        let activities = Activity<AlarmAttributes<RJTimerAlarmMetadata>>.activities
        var seen = Set<UUID>()

        for activity in activities {
            let state = activity.content.state
            let id = state.alarmID
            seen.insert(id)

            let metadata = activity.attributes.metadata

            if timers.firstIndex(where: { $0.id == id }) == nil {
                let title = metadata?.title ?? "System-Timer"
                var adopted = TimerRecord(
                    id: id,
                    title: title,
                    symbol: metadata?.symbol ?? "timer",
                    accent: metadata?.accent ?? .cyan,
                    soundFile: metadata?.soundFile ?? "glass_chime.wav",
                    duration: metadata?.originalDuration ?? 60
                )
                apply(state: state, to: &adopted)
                timers.insert(adopted, at: 0)
                DebugLogger.shared.log("AlarmKit-Timer übernommen: \(id)")
            } else if let index = timers.firstIndex(where: { $0.id == id }) {
                var updated = timers[index]
                apply(state: state, to: &updated)
                timers[index] = updated
            }
        }

        let systemIDs = Set(AlarmKitService.shared.currentAlarms().map(\.id))
        for index in timers.indices {
            guard timers[index].isActive else { continue }
            let id = timers[index].id
            if !seen.contains(id) && !systemIDs.contains(id) {
                finishMissingTimer(at: index)
            }
        }

        saveTimers()
    }

    func reconcileMissingAlarms() {
        let systemIDs = Set(AlarmKitService.shared.currentAlarms().map(\.id))
        for index in timers.indices {
            guard timers[index].isActive else { continue }
            if !systemIDs.contains(timers[index].id) && timers[index].remaining() <= 1 {
                completeTimer(at: index)
            }
        }
        saveTimers()
    }

    private func observeAlarmKit() {
        alarmObservationTask?.cancel()
        alarmObservationTask = Task { [weak self] in
            for await _ in AlarmManager.shared.alarmUpdates {
                guard !Task.isCancelled else { break }
                await self?.syncFromSystem()
            }
        }
    }

    private func apply(
        state: AlarmPresentationState,
        to record: inout TimerRecord
    ) {
        switch state.mode {
        case .countdown(let countdown):
            record.originalDuration = countdown.totalCountdownDuration
            record.elapsedBeforeRun = countdown.previouslyElapsedDuration
            record.startedAt = countdown.startDate
            record.state = .running

        case .paused(let paused):
            record.originalDuration = paused.totalCountdownDuration
            record.elapsedBeforeRun = paused.previouslyElapsedDuration
            record.startedAt = nil
            record.state = .paused

        case .alert:
            record.elapsedBeforeRun = record.originalDuration
            record.startedAt = nil
            record.state = .alerting

        @unknown default:
            break
        }
    }

    private func finishMissingTimer(at index: Int) {
        if timers[index].remaining() <= 1 || timers[index].state == .alerting {
            completeTimer(at: index)
        } else {
            var record = timers[index]
            record.elapsedBeforeRun = record.elapsed()
            record.startedAt = nil
            record.state = .stopped
            timers[index] = record
        }
    }

    private func completeTimer(at index: Int) {
        var record = timers[index]
        guard record.state != .completed else { return }

        record.elapsedBeforeRun = record.originalDuration
        record.startedAt = nil
        record.state = .completed
        timers[index] = record

        if !history.contains(where: { $0.timerID == record.id && $0.outcome == .completed }) {
            history.insert(
                TimerHistoryEntry(
                    timerID: record.id,
                    title: record.title,
                    plannedDuration: record.originalDuration,
                    actualDuration: record.originalDuration,
                    finishedAt: .now,
                    outcome: .completed,
                    accent: record.accent
                ),
                at: 0
            )
            saveHistory()
        }

        lastCompletedTimer = record
        Haptics.success()
    }

    func reloadFromDisk() {
        load()
    }

    private func load() {
        timers = AppPersistence.load([TimerRecord].self, from: AppPersistence.timersURL) ?? []
        presets = AppPersistence.load([TimerPreset].self, from: AppPersistence.presetsURL) ?? []
        history = AppPersistence.load([TimerHistoryEntry].self, from: AppPersistence.historyURL) ?? []
    }

    private func saveTimers() {
        do {
            try AppPersistence.save(timers, to: AppPersistence.timersURL)
        } catch {
            DebugLogger.shared.log("Save timers error: \(error)")
            lastError = "Timer konnten nicht gespeichert werden: \(error.localizedDescription)"
        }
    }

    private func savePresets() {
        do {
            try AppPersistence.save(presets, to: AppPersistence.presetsURL)
        } catch {
            DebugLogger.shared.log("Save presets error: \(error)")
            lastError = "Timer-Presets konnten nicht gespeichert werden: \(error.localizedDescription)"
        }
    }

    private func saveHistory() {
        do {
            try AppPersistence.save(history, to: AppPersistence.historyURL)
        } catch {
            DebugLogger.shared.log("Save history error: \(error)")
            lastError = "Timer-Verlauf konnte nicht gespeichert werden: \(error.localizedDescription)"
        }
    }
}

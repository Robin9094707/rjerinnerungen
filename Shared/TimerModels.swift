import Foundation
import SwiftUI

enum TimerRunState: String, Codable, Hashable, Sendable {
    case running
    case paused
    case alerting
    case completed
    case stopped
}

enum TimerAccentToken: String, Codable, CaseIterable, Identifiable, Sendable {
    case cyan
    case blue
    case purple
    case orange
    case green
    case pink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cyan: "Cyan"
        case .blue: "Blau"
        case .purple: "Lila"
        case .orange: "Orange"
        case .green: "Grün"
        case .pink: "Pink"
        }
    }

    var color: Color {
        switch self {
        case .cyan: .cyan
        case .blue: .blue
        case .purple: .purple
        case .orange: .orange
        case .green: .green
        case .pink: .pink
        }
    }
}

struct TimerRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var symbol: String
    var accent: TimerAccentToken
    var soundFile: String
    var originalDuration: TimeInterval
    var elapsedBeforeRun: TimeInterval
    var startedAt: Date?
    var state: TimerRunState
    var createdAt: Date
    var favorite: Bool

    init(
        id: UUID = UUID(),
        title: String,
        symbol: String = "timer",
        accent: TimerAccentToken = .cyan,
        soundFile: String = "glass_chime.wav",
        duration: TimeInterval,
        favorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.symbol = symbol
        self.accent = accent
        self.soundFile = soundFile
        self.originalDuration = max(duration, 1)
        self.elapsedBeforeRun = 0
        self.startedAt = Date()
        self.state = .running
        self.createdAt = Date()
        self.favorite = favorite
    }

    func elapsed(at date: Date = .now) -> TimeInterval {
        let liveElapsed: TimeInterval
        if state == .running, let startedAt {
            liveElapsed = max(0, date.timeIntervalSince(startedAt))
        } else {
            liveElapsed = 0
        }
        return min(originalDuration, max(0, elapsedBeforeRun + liveElapsed))
    }

    func remaining(at date: Date = .now) -> TimeInterval {
        max(0, originalDuration - elapsed(at: date))
    }

    func progress(at date: Date = .now) -> Double {
        guard originalDuration > 0 else { return 1 }
        return min(1, max(0, elapsed(at: date) / originalDuration))
    }

    var isActive: Bool {
        state == .running || state == .paused || state == .alerting
    }
}

struct TimerPreset: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var duration: TimeInterval
    var symbol: String
    var accent: TimerAccentToken
    var soundFile: String
    var favorite: Bool = false
}

struct TimerHistoryEntry: Codable, Identifiable, Hashable, Sendable {
    enum Outcome: String, Codable, Hashable, Sendable {
        case completed
        case stopped
    }

    var id: UUID = UUID()
    var timerID: UUID
    var title: String
    var plannedDuration: TimeInterval
    var actualDuration: TimeInterval
    var finishedAt: Date
    var outcome: Outcome
    var accent: TimerAccentToken
}

enum TimerSoundCatalog {
    struct Item: Identifiable, Hashable {
        let id: String
        let title: String
        let fileName: String
        let symbol: String
    }

    static let all: [Item] = [
        .init(id: "glass", title: "Glass Chime", fileName: "glass_chime.wav", symbol: "sparkles"),
        .init(id: "bell", title: "Soft Bell", fileName: "soft_bell.wav", symbol: "bell"),
        .init(id: "pulse", title: "Digital Pulse", fileName: "digital_pulse.wav", symbol: "waveform"),
        .init(id: "system", title: "System", fileName: "default", symbol: "iphone.radiowaves.left.and.right")
    ]

    static func title(for file: String) -> String {
        all.first(where: { $0.fileName == file })?.title
            ?? URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
    }
}

enum TimerPresetDefaults {
    static let values: [TimerPreset] = [
        .init(title: "1 Minute", duration: 60, symbol: "1.circle.fill", accent: .cyan, soundFile: "glass_chime.wav", favorite: true),
        .init(title: "5 Minuten", duration: 5 * 60, symbol: "cup.and.saucer.fill", accent: .blue, soundFile: "glass_chime.wav", favorite: true),
        .init(title: "10 Minuten", duration: 10 * 60, symbol: "timer", accent: .purple, soundFile: "soft_bell.wav", favorite: true),
        .init(title: "Pomodoro", duration: 25 * 60, symbol: "brain.head.profile.fill", accent: .pink, soundFile: "digital_pulse.wav", favorite: true),
        .init(title: "Deep Work", duration: 50 * 60, symbol: "bolt.fill", accent: .orange, soundFile: "digital_pulse.wav"),
        .init(title: "Power Nap", duration: 20 * 60, symbol: "bed.double.fill", accent: .purple, soundFile: "soft_bell.wav"),
        .init(title: "Tee", duration: 4 * 60, symbol: "mug.fill", accent: .green, soundFile: "soft_bell.wav"),
        .init(title: "Workout", duration: 45 * 60, symbol: "figure.strengthtraining.traditional", accent: .orange, soundFile: "digital_pulse.wav")
    ]
}

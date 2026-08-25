import Foundation

enum AppPersistence {
    static var root: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("RJZeitZentrale", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var timersURL: URL { root.appendingPathComponent("timers.json") }
    static var presetsURL: URL { root.appendingPathComponent("timer-presets.json") }
    static var historyURL: URL { root.appendingPathComponent("timer-history.json") }
    static var remindersURL: URL { root.appendingPathComponent("reminders.json") }
    static var notesURL: URL { root.appendingPathComponent("notes.json") }
    static var alarmsURL: URL { root.appendingPathComponent("alarms.json") }

    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch {
            return nil
        }
    }

    static func save<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    static func exportTimerBundle(
        timers: [TimerRecord],
        presets: [TimerPreset],
        history: [TimerHistoryEntry]
    ) throws -> URL {
        struct Export: Codable {
            let exportedAt: Date
            let timers: [TimerRecord]
            let presets: [TimerPreset]
            let history: [TimerHistoryEntry]
        }

        let url = root.appendingPathComponent("RJ-ZeitZentrale-Timer-Export.json")
        try save(
            Export(exportedAt: .now, timers: timers, presets: presets, history: history),
            to: url
        )
        return url
    }

    static func exportAll(
        reminders: [ReminderItem],
        notes: [NoteItem],
        alarms: [AlarmRecord]
    ) throws -> URL {
        struct Export: Codable {
            let formatVersion: Int
            let exportedAt: Date
            let reminders: [ReminderItem]
            let notes: [NoteItem]
            let alarms: [AlarmRecord]
        }

        let url = root.appendingPathComponent("RJ-ZeitZentrale-Export.json")
        try save(
            Export(
                formatVersion: 1,
                exportedAt: .now,
                reminders: reminders,
                notes: notes,
                alarms: alarms
            ),
            to: url
        )
        return url
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

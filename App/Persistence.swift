import Foundation

enum AppPersistence {
    private static let manager = FileManager.default

    static let root: URL = prepareRoot()
    static let attachmentsDirectory: URL = directory(named: "Attachments", inside: root)
    static let recordingsDirectory: URL = directory(named: "Recordings", inside: root)
    static let customSoundsDirectory: URL = {
        let library = manager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return directory(named: "Sounds", inside: library)
    }()

    static var timersURL: URL { root.appendingPathComponent("timers.json") }
    static var presetsURL: URL { root.appendingPathComponent("timer-presets.json") }
    static var historyURL: URL { root.appendingPathComponent("timer-history.json") }
    static var remindersURL: URL { root.appendingPathComponent("reminders.json") }
    static var notesURL: URL { root.appendingPathComponent("notes.json") }
    static var noteFoldersURL: URL { root.appendingPathComponent("note-folders.json") }
    static var alarmsURL: URL { root.appendingPathComponent("alarms.json") }
    static var customSoundsMetadataURL: URL { root.appendingPathComponent("custom-sounds.json") }

    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch {
            return nil
        }
    }

    static func save<T: Encodable>(_ value: T, to url: URL) throws {
        try ensureParent(of: url)
        let data = try encoder.encode(value)
        // completeFileProtection blocked AlarmKit background callbacks while the
        // phone was locked. Until-first-unlock still protects the data at boot,
        // while allowing timers to persist their state reliably afterwards.
        try data.write(to: url, options: .atomic)
        try? manager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        Task { @MainActor in ICloudSyncService.shared.noteLocalChange() }
    }

    static func write(_ data: Data, to url: URL) throws {
        try ensureParent(of: url)
        try data.write(to: url, options: .atomic)
        try? manager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        Task { @MainActor in ICloudSyncService.shared.noteLocalChange() }
    }

    static func removeMediaFile(named fileName: String, from directory: URL) {
        let safeName = URL(fileURLWithPath: fileName).lastPathComponent
        try? manager.removeItem(at: directory.appendingPathComponent(safeName))
        Task { @MainActor in ICloudSyncService.shared.noteLocalChange() }
    }

    static func mediaURL(named fileName: String, in directory: URL) -> URL {
        directory.appendingPathComponent(URL(fileURLWithPath: fileName).lastPathComponent)
    }

    static func exportTimerBundle(
        timers: [TimerRecord],
        presets: [TimerPreset],
        history: [TimerHistoryEntry]
    ) throws -> URL {
        struct Export: Codable {
            let formatVersion: Int
            let exportedAt: Date
            let timers: [TimerRecord]
            let presets: [TimerPreset]
            let history: [TimerHistoryEntry]
        }
        let url = root.appendingPathComponent("RJ-ZeitZentrale-Timer-Export.json")
        try save(
            Export(formatVersion: 2, exportedAt: .now, timers: timers, presets: presets, history: history),
            to: url
        )
        return url
    }

    static func exportAll(
        reminders: [ReminderItem],
        notes: [NoteItem],
        noteFolders: [NoteFolder],
        alarms: [AlarmRecord],
        customSounds: [CustomAlarmSound]
    ) throws -> URL {
        struct Export: Codable {
            let formatVersion: Int
            let exportedAt: Date
            let reminders: [ReminderItem]
            let notes: [NoteItem]
            let noteFolders: [NoteFolder]
            let alarms: [AlarmRecord]
            let customSounds: [CustomAlarmSound]
        }
        let url = root.appendingPathComponent("RJ-ZeitZentrale-Export.json")
        try save(
            Export(
                formatVersion: 2,
                exportedAt: .now,
                reminders: reminders,
                notes: notes,
                noteFolders: noteFolders,
                alarms: alarms,
                customSounds: customSounds
            ),
            to: url
        )
        return url
    }

    static func reloadableDataFiles() -> [String] {
        [
            timersURL.lastPathComponent,
            presetsURL.lastPathComponent,
            historyURL.lastPathComponent,
            remindersURL.lastPathComponent,
            notesURL.lastPathComponent,
            noteFoldersURL.lastPathComponent,
            alarmsURL.lastPathComponent,
            customSoundsMetadataURL.lastPathComponent
        ]
    }

    private static func prepareRoot() -> URL {
        let applicationSupport = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let target = applicationSupport.appendingPathComponent("RJZeitZentrale", isDirectory: true)
        try? manager.createDirectory(
            at: target,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )

        let documents = manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let legacy = documents.appendingPathComponent("RJZeitZentrale", isDirectory: true)
        migrateLegacyFiles(from: legacy, to: target)
        return target
    }

    private static func migrateLegacyFiles(from legacy: URL, to target: URL) {
        guard manager.fileExists(atPath: legacy.path),
              let children = try? manager.contentsOfDirectory(
                at: legacy,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else { return }

        for source in children {
            let destination = target.appendingPathComponent(source.lastPathComponent)
            guard !manager.fileExists(atPath: destination.path) else { continue }
            do {
                try manager.copyItem(at: source, to: destination)
                try? manager.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: destination.path
                )
            } catch {
                // Loading still falls back to an empty collection; the original
                // Documents copy is deliberately never deleted during migration.
            }
        }
    }

    private static func directory(named name: String, inside parent: URL) -> URL {
        let url = parent.appendingPathComponent(name, isDirectory: true)
        try? manager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
        return url
    }

    private static func ensureParent(of url: URL) throws {
        try manager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        )
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

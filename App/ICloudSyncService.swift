import Foundation
import Observation

enum ICloudSyncResult: String, Sendable {
    case uploaded
    case downloaded
    case unchanged

    var title: String {
        switch self {
        case .uploaded: "Zu iCloud hochgeladen"
        case .downloaded: "Von iCloud geladen"
        case .unchanged: "Bereits aktuell"
        }
    }
}

enum ICloudSyncError: LocalizedError {
    case unavailable
    case notEnabled

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "iCloud ist für diese Signatur nicht verfügbar. Die App benötigt ein Provisioning Profile mit iCloud-Documents-Entitlement."
        case .notEnabled:
            "Aktiviere die optionale iCloud-Synchronisierung zuerst in den Einstellungen."
        }
    }
}

@MainActor
@Observable
final class ICloudSyncService {
    static let shared = ICloudSyncService()

    private struct Manifest: Codable {
        let schemaVersion: Int
        let modifiedAt: Date
    }

    private enum Key {
        static let enabled = "iCloudSyncEnabled"
        static let localModification = "iCloudLocalModification"
        static let lastSuccess = "iCloudLastSuccess"
    }

    private let manager = FileManager.default
    private var uploadTask: Task<Void, Never>?
    private(set) var isSynchronizing = false
    private(set) var lastStatus = "Nicht synchronisiert"
    private(set) var lastSuccess: Date?

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.enabled) }
        set { UserDefaults.standard.set(newValue, forKey: Key.enabled) }
    }

    var isAvailable: Bool {
        manager.ubiquityIdentityToken != nil && containerURL != nil
    }

    private var containerURL: URL? {
        manager.url(forUbiquityContainerIdentifier: nil)
    }

    private init() {
        lastSuccess = UserDefaults.standard.object(forKey: Key.lastSuccess) as? Date
        if let lastSuccess {
            lastStatus = "Zuletzt " + lastSuccess.formatted(date: .abbreviated, time: .shortened)
        }
    }

    func setEnabled(_ enabled: Bool) async throws -> ICloudSyncResult? {
        guard !enabled || isAvailable else { throw ICloudSyncError.unavailable }
        let wasEnabled = isEnabled
        isEnabled = enabled
        if enabled {
            // On a newly connected device, an existing cloud copy wins. This
            // prevents fresh default folders/presets from overwriting real data.
            return try await synchronize(preferExistingCloud: !wasEnabled)
        }
        uploadTask?.cancel()
        lastStatus = "Deaktiviert"
        return nil
    }

    func noteLocalChange() {
        guard !isSynchronizing else { return }
        UserDefaults.standard.set(Date(), forKey: Key.localModification)
        guard isEnabled, isAvailable else { return }

        uploadTask?.cancel()
        uploadTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            _ = try? await self?.synchronize(forceUpload: true)
        }
    }

    func bootstrap() async -> ICloudSyncResult? {
        guard isEnabled, isAvailable else { return nil }
        return try? await synchronize()
    }

    func synchronize(
        forceUpload: Bool = false,
        preferExistingCloud: Bool = false
    ) async throws -> ICloudSyncResult {
        guard isEnabled else { throw ICloudSyncError.notEnabled }
        guard let containerURL else { throw ICloudSyncError.unavailable }

        isSynchronizing = true
        lastStatus = "Synchronisiere …"
        defer { isSynchronizing = false }

        let cloudRoot = containerURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("RJZeitZentrale", isDirectory: true)
        try manager.createDirectory(at: cloudRoot, withIntermediateDirectories: true)

        let manifestURL = cloudRoot.appendingPathComponent("sync-manifest.json")
        let cloudManifest = loadManifest(from: manifestURL)
        let localModified = (UserDefaults.standard.object(forKey: Key.localModification) as? Date)
            ?? newestLocalModificationDate()

        let result: ICloudSyncResult
        if preferExistingCloud, let cloudManifest {
            try download(from: cloudRoot)
            UserDefaults.standard.set(cloudManifest.modifiedAt, forKey: Key.localModification)
            result = .downloaded
        } else if forceUpload || cloudManifest == nil || localModified > (cloudManifest?.modifiedAt ?? .distantPast) {
            try upload(to: cloudRoot, modifiedAt: localModified)
            result = .uploaded
        } else if let cloudManifest, cloudManifest.modifiedAt > localModified {
            try download(from: cloudRoot)
            UserDefaults.standard.set(cloudManifest.modifiedAt, forKey: Key.localModification)
            result = .downloaded
        } else {
            result = .unchanged
        }

        let now = Date()
        lastSuccess = now
        lastStatus = result.title
        UserDefaults.standard.set(now, forKey: Key.lastSuccess)
        DebugLogger.shared.log("iCloud sync: \(result.rawValue)")
        return result
    }

    private func upload(to cloudRoot: URL, modifiedAt: Date) throws {
        let cloudData = cloudRoot.appendingPathComponent("Data", isDirectory: true)
        let cloudSounds = cloudRoot.appendingPathComponent("Sounds", isDirectory: true)
        try mirrorDirectory(from: AppPersistence.root, to: cloudData)
        try mirrorDirectory(from: AppPersistence.customSoundsDirectory, to: cloudSounds)

        let manifest = Manifest(schemaVersion: 2, modifiedAt: modifiedAt)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(manifest).write(
            to: cloudRoot.appendingPathComponent("sync-manifest.json"),
            options: .atomic
        )
    }

    private func download(from cloudRoot: URL) throws {
        let cloudData = cloudRoot.appendingPathComponent("Data", isDirectory: true)
        let cloudSounds = cloudRoot.appendingPathComponent("Sounds", isDirectory: true)
        if manager.fileExists(atPath: cloudData.path) {
            try copyContents(from: cloudData, to: AppPersistence.root)
        }
        if manager.fileExists(atPath: cloudSounds.path) {
            try copyContents(from: cloudSounds, to: AppPersistence.customSoundsDirectory)
        }
    }

    private func mirrorDirectory(from source: URL, to destination: URL) throws {
        if manager.fileExists(atPath: destination.path) {
            try manager.removeItem(at: destination)
        }
        try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try manager.copyItem(at: source, to: destination)
    }

    private func copyContents(from source: URL, to destination: URL) throws {
        try manager.createDirectory(at: destination, withIntermediateDirectories: true)
        let children = try manager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        for child in children {
            let target = destination.appendingPathComponent(child.lastPathComponent)
            if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
            try manager.copyItem(at: child, to: target)
        }
    }

    private func loadManifest(from url: URL) -> Manifest? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Manifest.self, from: data)
    }

    private func newestLocalModificationDate() -> Date {
        let urls = (try? manager.contentsOfDirectory(
            at: AppPersistence.root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return urls.compactMap {
            try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        }.compactMap { $0 }.max() ?? .now
    }
}

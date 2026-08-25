import AVFoundation
import Foundation
import Observation

enum CustomSoundError: LocalizedError {
    case unsupportedFormat
    case tooLong
    case invalidAudio
    case duplicateName

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            "Unterstützt werden WAV-, AIFF-, AIF- und CAF-Dateien."
        case .tooLong:
            "Eigene Systemtöne dürfen höchstens 30 Sekunden lang sein."
        case .invalidAudio:
            "Die Audiodatei konnte nicht gelesen werden."
        case .duplicateName:
            "Ein Ton mit diesem Namen wurde bereits importiert."
        }
    }
}

@MainActor
@Observable
final class CustomSoundStore {
    static let shared = CustomSoundStore()

    private(set) var sounds: [CustomAlarmSound]
    var lastError: String?

    var catalogItems: [TimerSoundCatalog.Item] {
        TimerSoundCatalog.all + sounds.map {
            TimerSoundCatalog.Item(
                id: $0.id.uuidString,
                title: $0.title,
                fileName: $0.fileName,
                symbol: "music.note"
            )
        }
    }

    private init() {
        sounds = AppPersistence.load(
            [CustomAlarmSound].self,
            from: AppPersistence.customSoundsMetadataURL
        ) ?? []
        removeMissingMetadata()
    }

    func reloadFromDisk() {
        sounds = AppPersistence.load(
            [CustomAlarmSound].self,
            from: AppPersistence.customSoundsMetadataURL
        ) ?? []
        removeMissingMetadata()
    }

    func importSound(from source: URL) throws -> CustomAlarmSound {
        lastError = nil
        let didAccess = source.startAccessingSecurityScopedResource()
        defer { if didAccess { source.stopAccessingSecurityScopedResource() } }

        let ext = source.pathExtension.lowercased()
        guard ["wav", "aiff", "aif", "caf"].contains(ext) else {
            throw CustomSoundError.unsupportedFormat
        }

        let probe: AVAudioPlayer
        do { probe = try AVAudioPlayer(contentsOf: source) }
        catch { throw CustomSoundError.invalidAudio }
        guard probe.duration > 0 else { throw CustomSoundError.invalidAudio }
        guard probe.duration <= 30 else { throw CustomSoundError.tooLong }

        let title = source.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sounds.contains(where: { $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame }) else {
            throw CustomSoundError.duplicateName
        }

        let fileName = "rj-custom-\(UUID().uuidString).\(ext)"
        let target = AppPersistence.mediaURL(named: fileName, in: AppPersistence.customSoundsDirectory)
        do {
            let data = try Data(contentsOf: source)
            try AppPersistence.write(data, to: target)
        } catch {
            throw CustomSoundError.invalidAudio
        }

        let sound = CustomAlarmSound(title: title, fileName: fileName, duration: probe.duration)
        sounds.append(sound)
        sounds.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        try persist()
        Haptics.success()
        return sound
    }

    func delete(_ sound: CustomAlarmSound) throws {
        AppPersistence.removeMediaFile(named: sound.fileName, from: AppPersistence.customSoundsDirectory)
        sounds.removeAll { $0.id == sound.id }
        try persist()
    }

    func title(for fileName: String) -> String {
        sounds.first(where: { $0.fileName == fileName })?.title
            ?? TimerSoundCatalog.title(for: fileName)
    }

    func url(for fileName: String) -> URL? {
        let url = AppPersistence.mediaURL(named: fileName, in: AppPersistence.customSoundsDirectory)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func persist() throws {
        try AppPersistence.save(sounds, to: AppPersistence.customSoundsMetadataURL)
    }

    private func removeMissingMetadata() {
        sounds.removeAll { url(for: $0.fileName) == nil }
        try? persist()
    }
}

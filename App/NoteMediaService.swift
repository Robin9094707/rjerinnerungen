import AVFoundation
import CoreTransferable
import Foundation
import Observation
import UIKit
import UniformTypeIdentifiers

struct ImportedNotePhoto: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            ImportedNotePhoto(data: data)
        }
    }
}

enum NoteMediaError: LocalizedError {
    case invalidImage
    case microphoneDenied
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: "Das ausgewählte Bild konnte nicht gelesen werden."
        case .microphoneDenied: "Der Mikrofonzugriff wurde nicht erlaubt. Aktiviere ihn in den iOS-Einstellungen."
        case .recordingFailed: "Die Sprachnotiz konnte nicht aufgenommen werden."
        }
    }
}

enum NoteMediaStore {
    static func importImage(_ data: Data) throws -> NoteAttachment {
        guard let source = UIImage(data: data) else { throw NoteMediaError.invalidImage }
        let image = resized(source, maximumDimension: 2_048)
        guard let output = image.jpegData(compressionQuality: 0.86) else {
            throw NoteMediaError.invalidImage
        }
        let fileName = "note-image-\(UUID().uuidString).jpg"
        try AppPersistence.write(
            output,
            to: AppPersistence.mediaURL(named: fileName, in: AppPersistence.attachmentsDirectory)
        )
        return NoteAttachment(fileName: fileName)
    }

    static func image(for attachment: NoteAttachment) -> UIImage? {
        let url = AppPersistence.mediaURL(named: attachment.fileName, in: AppPersistence.attachmentsDirectory)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func delete(_ attachment: NoteAttachment) {
        AppPersistence.removeMediaFile(named: attachment.fileName, from: AppPersistence.attachmentsDirectory)
    }

    static func delete(_ recording: VoiceRecording) {
        AppPersistence.removeMediaFile(named: recording.fileName, from: AppPersistence.recordingsDirectory)
    }

    private static func resized(_ image: UIImage, maximumDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maximumDimension else { return image }
        let scale = maximumDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

@MainActor
@Observable
final class VoiceNoteService: NSObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var currentRecordingURL: URL?
    private var meterTask: Task<Void, Never>?

    private(set) var isRecording = false
    private(set) var recordingDuration: TimeInterval = 0
    private(set) var recordingLevel: Float = -60
    private(set) var playingRecordingID: UUID?

    func startRecording() async throws {
        stopPlayback()
        guard await requestPermission() else { throw NoteMediaError.microphoneDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true)

        let url = AppPersistence.recordingsDirectory
            .appendingPathComponent("voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128_000
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        guard recorder.prepareToRecord(), recorder.record() else {
            throw NoteMediaError.recordingFailed
        }

        self.recorder = recorder
        currentRecordingURL = url
        isRecording = true
        recordingDuration = 0
        recordingLevel = -60
        startMetering()
    }

    func stopRecording() -> VoiceRecording? {
        guard let recorder, let url = currentRecordingURL else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        meterTask?.cancel()
        self.recorder = nil
        currentRecordingURL = nil
        isRecording = false
        recordingDuration = 0
        recordingLevel = -60
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard duration >= 0.25 else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        ICloudSyncService.shared.noteLocalChange()
        return VoiceRecording(fileName: url.lastPathComponent, duration: duration)
    }

    func cancelRecording() {
        guard let url = currentRecordingURL else { return }
        recorder?.stop()
        recorder = nil
        meterTask?.cancel()
        currentRecordingURL = nil
        isRecording = false
        recordingDuration = 0
        try? FileManager.default.removeItem(at: url)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func togglePlayback(_ recording: VoiceRecording) {
        if playingRecordingID == recording.id {
            stopPlayback()
            return
        }
        stopPlayback()
        let url = AppPersistence.mediaURL(named: recording.fileName, in: AppPersistence.recordingsDirectory)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            playingRecordingID = recording.id
        } catch {
            DebugLogger.shared.log("Voice playback error: \(error)")
            playingRecordingID = nil
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        playingRecordingID = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stopPlayback() }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard !flag else { return }
        Task { @MainActor in
            DebugLogger.shared.log("Voice recording ended unsuccessfully")
        }
    }

    private func requestPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func startMetering() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while let self, self.isRecording, !Task.isCancelled {
                self.recorder?.updateMeters()
                self.recordingDuration = self.recorder?.currentTime ?? 0
                self.recordingLevel = self.recorder?.averagePower(forChannel: 0) ?? -60
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}

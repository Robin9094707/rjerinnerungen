import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class SoundPlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundPlayer()

    private var player: AVAudioPlayer?
    private(set) var playingFile: String?

    func preview(_ file: String) {
        stop()
        guard file != "default" else {
            Haptics.success()
            return
        }

        let base = (file as NSString).deletingPathExtension
        let ext = (file as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: ext) else {
            DebugLogger.shared.log("Sound nicht gefunden: \(file)")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            playingFile = file
        } catch {
            DebugLogger.shared.log("Sound preview error: \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingFile = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.playingFile = nil
        }
    }
}

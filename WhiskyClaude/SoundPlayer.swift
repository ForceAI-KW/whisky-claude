import AVFoundation
import Foundation

final class SoundPlayer {
    static let shared = SoundPlayer()
    private var players: [String: AVAudioPlayer] = [:]

    private init() {}

    func play(_ name: String) {
        guard SettingsManager.shared.soundsEnabled else { return }
        if let cached = players[name] {
            cached.currentTime = 0
            cached.play()
            return
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            NSLog("[WhiskyClaude] sound asset missing: \(name).mp3")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[name] = player
            player.play()
        } catch {
            NSLog("[WhiskyClaude] sound load failed for \(name): \(error)")
        }
    }
}

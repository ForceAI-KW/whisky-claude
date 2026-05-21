import AVFoundation
import Foundation

final class SoundPlayer {
    static let shared = SoundPlayer()
    private var players: [String: AVAudioPlayer] = [:]

    private init() {}

    func play(_ name: String) {
        guard SettingsManager.shared.soundsEnabled else {
            NSLog("[WhiskyClaude] SoundPlayer.play(\(name)) skipped — soundsEnabled is false")
            return
        }
        NSLog("[WhiskyClaude] SoundPlayer.play(\(name)) firing")

        if let cached = players[name] {
            cached.stop()        // stop any in-flight playback
            cached.currentTime = 0
            cached.volume = 1.0
            let ok = cached.play()
            if !ok { NSLog("[WhiskyClaude] SoundPlayer.play returned false for \(name)") }
            return
        }
        // Bundled assets are real WAV files (RIFF PCM, 24kHz mono). Look up
        // by the actual extension; fall through to .mp3 for any caller that
        // bundles a true MP3 in future.
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav")
                     ?? Bundle.main.url(forResource: name, withExtension: "mp3") else {
            NSLog("[WhiskyClaude] sound asset missing: \(name).wav or .mp3")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.volume = 1.0
            players[name] = player
            let ok = player.play()
            if !ok { NSLog("[WhiskyClaude] SoundPlayer.play returned false for new player \(name)") }
        } catch {
            NSLog("[WhiskyClaude] sound load failed for \(name): \(error)")
        }
    }
}

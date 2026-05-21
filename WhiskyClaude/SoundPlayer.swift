import AVFoundation
import Foundation

final class SoundPlayer {
    static let shared = SoundPlayer()
    private var players: [String: AVAudioPlayer] = [:]
    /// Tracks the last time each named sound was played. Used to debounce
    /// rapid identical replays — Claude Code's Notification hook fires
    /// every ~30s while the user is still being prompted, and we don't
    /// want to keep saying "Whisky is done, Ahmed" over and over.
    private var lastPlayedAt: [String: CFTimeInterval] = [:]
    /// Minimum interval between identical sound replays (seconds).
    private let debounceInterval: CFTimeInterval = 30.0

    private init() {}

    func play(_ name: String) {
        guard SettingsManager.shared.soundsEnabled else {
            NSLog("[WhiskyClaude] SoundPlayer.play(\(name)) skipped — soundsEnabled is false")
            return
        }
        // Debounce: skip if the same sound played within the last 30s. Claude
        // Code's Notification hook fires periodically while a user is still
        // being prompted, which would otherwise produce a repetitive announcement.
        let now = CACurrentMediaTime()
        if let last = lastPlayedAt[name], now - last < debounceInterval {
            NSLog("[WhiskyClaude] SoundPlayer.play(\(name)) debounced — last played \(Int(now - last))s ago")
            return
        }
        lastPlayedAt[name] = now
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

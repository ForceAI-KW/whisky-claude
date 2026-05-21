import AVFoundation
import Foundation

final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [String: AVAudioPlayer] = [:]
    /// Tracks the last time each named sound was played. Used to debounce
    /// rapid identical replays — Claude Code's Notification hook fires
    /// every ~30s while the user is still being prompted, and we don't
    /// want to keep saying "Whisky is done, Ahmad" over and over.
    private var lastPlayedAt: [String: CFTimeInterval] = [:]
    /// Minimum interval between identical sound replays (seconds).
    private let debounceInterval: CFTimeInterval = 30.0

    private init() {}

    /// Drop any cached player for `name` so the next play() re-loads from
    /// disk. Called by SettingsManager when the user picks a new custom
    /// sound file (or resets to default).
    func invalidateCache(for name: String) {
        players.removeValue(forKey: name)
        lastPlayedAt.removeValue(forKey: name)
    }

    /// Play a sound by logical name ("waitingForInput" / "taskCompleted").
    /// Resolves the audio source in this order:
    ///   1. A user-picked custom file path in SettingsManager
    ///   2. The bundled .wav resource
    ///   3. The bundled .mp3 fallback (for true-MP3 files added later)
    func play(_ name: String) {
        guard SettingsManager.shared.soundsEnabled else {
            NSLog("[WhiskyClaude] SoundPlayer.play(\(name)) skipped — soundsEnabled is false")
            return
        }
        let now = CACurrentMediaTime()
        if let last = lastPlayedAt[name], now - last < debounceInterval {
            NSLog("[WhiskyClaude] SoundPlayer.play(\(name)) debounced — last played \(Int(now - last))s ago")
            return
        }
        lastPlayedAt[name] = now
        NSLog("[WhiskyClaude] SoundPlayer.play(\(name)) firing")

        if let cached = players[name] {
            cached.stop()
            cached.currentTime = 0
            cached.volume = 1.0
            let ok = cached.play()
            if !ok { NSLog("[WhiskyClaude] SoundPlayer.play returned false for \(name)") }
            return
        }

        guard let url = resolveURL(for: name) else {
            NSLog("[WhiskyClaude] sound asset missing for \(name)")
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

    /// Play immediately bypassing the debounce — used by the Settings preview
    /// buttons so users can audition their custom sound choice on demand.
    func preview(_ name: String) {
        lastPlayedAt.removeValue(forKey: name)
        invalidateCache(for: name)
        play(name)
    }

    /// Returns the URL of the user-picked custom file (if set and readable)
    /// or the bundled default for the given logical name.
    private func resolveURL(for name: String) -> URL? {
        if let customPath = SettingsManager.shared.customSoundPath(for: name),
           !customPath.isEmpty,
           FileManager.default.isReadableFile(atPath: customPath) {
            return URL(fileURLWithPath: customPath)
        }
        return Bundle.main.url(forResource: name, withExtension: "wav")
            ?? Bundle.main.url(forResource: name, withExtension: "mp3")
    }
}

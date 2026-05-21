import AVFoundation
import Foundation
import Speech

/// On-device speech recognition for wake phrases ("hey claude" / "hey whisky").
/// Uses `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` so audio
/// never leaves the Mac. Tap is shared via SharedMicCapture so it co-exists
/// with the clap detector on the same mic input.
///
/// Recognition is restarted when the task completes or errors to keep listening
/// continuously, avoiding SFSpeechRecognitionRequest buffer accumulation.
final class KeywordRecognizer: NSObject {
    static let shared = KeywordRecognizer()

    /// Fired on the main queue when a wake phrase is detected.
    var onWakeWord: (() -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var isRunning = false
    private var lastFireAt: CFTimeInterval = 0
    private static let consumerId = "keyword-recognizer"
    private static let wakePhrases: Set<String> = ["hey claude", "hey whisky"]
    /// Re-arm cooldown — after a wake-word fire, ignore subsequent detections
    /// for this long to avoid the partial-transcript echo.
    private static let cooldown: CFTimeInterval = 3.0

    private override init() { super.init() }

    func start() {
        guard !isRunning else { return }
        guard let recognizer, recognizer.isAvailable else {
            NSLog("[WhiskyClaude] KeywordRecognizer: SFSpeechRecognizer unavailable")
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.startListening()
                default:
                    NSLog("[WhiskyClaude] KeywordRecognizer: speech permission \(status.rawValue)")
                }
            }
        }
    }

    private func startListening() {
        guard let recognizer else { return }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if #available(macOS 13.0, *), recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        } else {
            NSLog("[WhiskyClaude] KeywordRecognizer: on-device recognition not available, using server (audio leaves Mac)")
        }
        self.request = req

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let transcript = result.bestTranscription.formattedString.lowercased()
                self.checkForWakePhrase(transcript)
            }
            if error != nil || result?.isFinal == true {
                // Restart so we keep listening
                DispatchQueue.main.async { self.restart() }
            }
        }

        let ok = SharedMicCapture.shared.register(id: Self.consumerId) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        if !ok {
            NSLog("[WhiskyClaude] KeywordRecognizer: failed to register mic consumer")
            task?.cancel()
            task = nil
            request = nil
            return
        }
        isRunning = true
        NSLog("[WhiskyClaude] KeywordRecognizer started")
    }

    func stop() {
        guard isRunning else { return }
        SharedMicCapture.shared.unregister(id: Self.consumerId)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRunning = false
        lastFireAt = 0
        NSLog("[WhiskyClaude] KeywordRecognizer stopped")
    }

    private func restart() {
        guard isRunning else { return }
        SharedMicCapture.shared.unregister(id: Self.consumerId)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        startListening()
    }

    private func checkForWakePhrase(_ transcript: String) {
        let now = CACurrentMediaTime()
        guard now - lastFireAt > Self.cooldown else { return }
        for phrase in Self.wakePhrases {
            if transcript.contains(phrase) {
                NSLog("[WhiskyClaude] wake word: \"\(phrase)\" in transcript")
                lastFireAt = now
                DispatchQueue.main.async { [weak self] in
                    self?.onWakeWord?()
                }
                // Restart so the same phrase doesn't keep matching in the
                // accumulating partial transcript.
                DispatchQueue.main.async { [weak self] in self?.restart() }
                return
            }
        }
    }
}

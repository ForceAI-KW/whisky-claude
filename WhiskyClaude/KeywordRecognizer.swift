import AVFoundation
import Foundation
import Speech

/// On-device speech recognition for wake phrases ("hey claude" / "hey whisky").
/// Uses `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` so audio
/// never leaves the Mac. Audio capture is shared via SharedMicCapture so this
/// co-exists with the clap detector on the same mic tap.
///
/// After a wake-phrase fires, the recognition task is restarted (cancel + new
/// request + new task) while LEAVING the mic capture untouched — that keeps
/// the AVAudioEngine running steadily across many wake-word triggers.
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
    /// Apple's recognizer transcribes "whisky" several different ways
    /// depending on accent + audio quality (whiskey, whisky, wiski, risky,
    /// etc.) so we accept every common variant. "Claude" is mostly stable
    /// but is sometimes misheard as "cloud" or "clod" — include those too.
    private static let wakePhrases: Set<String> = [
        "hey claude", "hey cloud", "hey clod",
        "hey whisky", "hey whiskey", "hey wiski", "hey wiskey",
        "hey risky", "hi claude", "hi whisky", "hi whiskey",
    ]

    /// Ignore subsequent matches within this many seconds after a fire — gives
    /// the partial-transcript window time to clear after we restart the task.
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
                    self.beginListening()
                default:
                    NSLog("[WhiskyClaude] KeywordRecognizer: speech auth status=\(status.rawValue)")
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        SharedMicCapture.shared.unregister(id: Self.consumerId)
        teardownTask()
        isRunning = false
        lastFireAt = 0
        NSLog("[WhiskyClaude] KeywordRecognizer stopped")
    }

    /// First-time start: install the audio consumer + spin up the first task.
    private func beginListening() {
        spinUpNewTask()

        let ok = SharedMicCapture.shared.register(id: Self.consumerId) { [weak self] buffer, _ in
            // Closure reads `self?.request` each call — if restartTask() swapped
            // it underneath, the next buffer flows into the new request.
            self?.request?.append(buffer)
        }
        if !ok {
            NSLog("[WhiskyClaude] KeywordRecognizer: SharedMicCapture register failed")
            teardownTask()
            return
        }
        isRunning = true
        NSLog("[WhiskyClaude] KeywordRecognizer started")
    }

    /// Swap to a fresh request + recognition task. Mic stays registered.
    private func restartTask() {
        teardownTask()
        spinUpNewTask()
    }

    private func teardownTask() {
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }

    private func spinUpNewTask() {
        guard let recognizer else { return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        self.request = req

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let transcript = result.bestTranscription.formattedString.lowercased()
                // Log every partial so we can see what the recognizer thinks
                // it's hearing. Filter via:
                //   log stream --predicate 'process == "WhiskyClaude"' --info | grep partial
                NSLog("[WhiskyClaude] speech partial: \"\(transcript)\"")
                self.checkForWakePhrase(transcript)
            }
            // SFSpeechRecognizer terminates the task on error (e.g. timeout
            // after ~1min of silence) or when the request hits isFinal=true.
            // Always spin a fresh one so we keep listening indefinitely.
            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.isRunning else { return }
                    self.restartTask()
                }
            }
        }
    }

    private func checkForWakePhrase(_ transcript: String) {
        let now = CACurrentMediaTime()
        guard now - lastFireAt > Self.cooldown else { return }
        for phrase in Self.wakePhrases {
            if transcript.contains(phrase) {
                NSLog("[WhiskyClaude] wake word: \"\(phrase)\" matched in transcript")
                lastFireAt = now
                DispatchQueue.main.async { [weak self] in self?.onWakeWord?() }
                // Swap to a fresh transcript so the same phrase doesn't keep matching
                DispatchQueue.main.async { [weak self] in self?.restartTask() }
                return
            }
        }
    }
}

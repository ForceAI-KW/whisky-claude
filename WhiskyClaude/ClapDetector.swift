import AVFoundation
import Foundation
import SoundAnalysis

/// Detects a SLAP on the Mac — a single sharp percussive impact. Originally
/// this class did double-clap detection, but Ahmad's environment + the
/// 500ms-window SoundAnalysis classifier produced unreliable matches.
/// Slap is more reliable because:
///   - The classifier has solid percussion labels (knock, thump, drum,
///     "tapping a hard surface", etc.) trained on percussive hits
///   - Single-event detection — no timing-gate logic between two events
///   - Slapping the Mac is a natural physical gesture for "hey, do something"
///
/// Despite the class still being named ClapDetector + onDoubleClap (kept for
/// call-site stability), behavior is now single-impact slap detection.
final class ClapDetector: NSObject {
    static let shared = ClapDetector()

    /// Fired on the main queue when a slap impact is detected.
    /// (Kept the property name for back-compat with AppDelegate's wiring.)
    var onDoubleClap: (() -> Void)?

    private var analyzer: SNAudioStreamAnalyzer?
    private var request: SNClassifySoundRequest?
    private let analysisQueue = DispatchQueue(label: "WhiskyClaude.slapAnalysis")

    private var isRunning = false
    private var lastFireAt: CFTimeInterval = 0

    /// Cooldown after a fire — don't trigger again within this window so a
    /// natural slap (which lasts a few hundred ms in the classifier's eyes)
    /// only counts as one event.
    private let cooldown: CFTimeInterval = 1.5

    /// Sensitivity 0..1 → confidence threshold 0.35 (lenient) ... 0.80 (strict).
    private var confidenceThreshold: Double = 0.55

    /// SoundAnalysis classifier labels that count as a "slap" — any sharp
    /// percussive impact. Multiple labels because Apple's classifier emits
    /// slightly different ones depending on the surface material + intensity.
    private static let slapIdentifiers: Set<String> = [
        "slap, smack",
        "smack, smacking lips",
        "knock",
        "thump, thud",
        "drum",
        "tap",
        "tapping_(hand)",
        "hands",
        "clapping",                  // a hard one-hand clap can register here too
        "finger_snapping",
    ]
    private static let consumerId = "slap-detector"

    private override init() { super.init() }

    /// Maps 0..1 user-facing sensitivity to the confidence threshold.
    func setSensitivity(_ s: Double) {
        let clamped = max(0, min(1, s))
        confidenceThreshold = 0.35 + 0.45 * clamped
    }

    func start() {
        guard !isRunning else { return }
        guard let format = SharedMicCapture.shared.inputFormat,
              format.sampleRate > 0, format.channelCount > 0 else {
            NSLog("[WhiskyClaude] SlapDetector: input format unusable")
            return
        }

        let streamAnalyzer = SNAudioStreamAnalyzer(format: format)
        do {
            let req = try SNClassifySoundRequest(classifierIdentifier: .version1)
            req.overlapFactor = 0.5
            try streamAnalyzer.add(req, withObserver: self)
            self.analyzer = streamAnalyzer
            self.request = req
        } catch {
            NSLog("[WhiskyClaude] SoundAnalysis setup failed: \(error)")
            return
        }

        let ok = SharedMicCapture.shared.register(id: Self.consumerId) { [weak self] buffer, time in
            self?.analysisQueue.async {
                self?.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
        }
        if !ok {
            NSLog("[WhiskyClaude] SlapDetector: failed to register mic consumer")
            analyzer?.removeAllRequests()
            analyzer = nil
            request = nil
            return
        }
        isRunning = true
        NSLog("[WhiskyClaude] SlapDetector started (threshold=\(confidenceThreshold))")
    }

    func stop() {
        guard isRunning else { return }
        SharedMicCapture.shared.unregister(id: Self.consumerId)
        analyzer?.removeAllRequests()
        analyzer = nil
        request = nil
        isRunning = false
        lastFireAt = 0
        NSLog("[WhiskyClaude] SlapDetector stopped")
    }

    private func handleSlapDetected() {
        let now = CACurrentMediaTime()
        guard now - lastFireAt > cooldown else { return }
        lastFireAt = now
        DispatchQueue.main.async { [weak self] in
            self?.onDoubleClap?()
        }
    }
}

extension ClapDetector: SNResultsObserving {
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classification = result as? SNClassificationResult else { return }

        // Find the best slap-related match above threshold.
        // First log any high-confidence percussive hit for tuning visibility.
        if let any = classification.classifications.first(where: {
            Self.slapIdentifiers.contains($0.identifier) && $0.confidence > 0.25
        }) {
            NSLog("[WhiskyClaude] slap-detect: \(any.identifier) conf=\(String(format: "%.2f", any.confidence)) threshold=\(String(format: "%.2f", confidenceThreshold))")
        }

        let hit = classification.classifications.first { c in
            Self.slapIdentifiers.contains(c.identifier) && c.confidence >= confidenceThreshold
        }
        guard hit != nil else { return }

        DispatchQueue.main.async { [weak self] in
            self?.handleSlapDetected()
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        NSLog("[WhiskyClaude] SoundAnalysis request failed: \(error)")
    }

    func requestDidComplete(_ request: SNRequest) {}
}

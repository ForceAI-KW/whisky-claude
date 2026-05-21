import AVFoundation
import Foundation
import SoundAnalysis

/// Detects double-clap audio events using Apple's on-device SoundAnalysis
/// classifier (`SNClassifierIdentifier.version1`). The classifier ships with
/// macOS and runs entirely on-device — audio is never persisted, transmitted,
/// or shared with Apple.
///
/// Two `clapping` (or `applause`) classifications above the sensitivity-driven
/// confidence threshold, separated by 100-600ms, fire `onDoubleClap`.
final class ClapDetector: NSObject {
    static let shared = ClapDetector()

    /// Fired on the main queue when a double-clap is detected.
    var onDoubleClap: (() -> Void)?

    private let engine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private var request: SNClassifySoundRequest?
    private let analysisQueue = DispatchQueue(label: "com.ahmadsharaf.WhiskyClaude.clapAnalysis")

    private var isRunning = false
    private var lastClapAt: CFTimeInterval = 0

    /// Min/max gap between two claps to count as a double-clap.
    private let minGap: CFTimeInterval = 0.10
    private let maxGap: CFTimeInterval = 0.60

    /// Confidence threshold for a single clap classification.
    /// Sensitivity 0 (lenient) → 0.5 ; sensitivity 1 (strict) → 0.9.
    private var confidenceThreshold: Double = 0.7

    /// Sound classifier identifiers we accept as a "clap".
    /// `clapping` is the primary single-clap identifier; `applause` is what
    /// the classifier emits when many claps overlap (occasionally fires on a
    /// solo two-hand clap with reverb — accepting both improves recall).
    private static let clapIdentifiers: Set<String> = ["clapping", "applause"]

    private override init() { super.init() }

    /// Maps 0..1 user-facing sensitivity to the Apple confidence threshold.
    /// 0 = lenient (fires more readily, threshold 0.5).
    /// 1 = strict  (fires only on very confident matches, threshold 0.9).
    func setSensitivity(_ s: Double) {
        let clamped = max(0, min(1, s))
        confidenceThreshold = 0.5 + 0.4 * clamped
    }

    func start() {
        guard !isRunning else { return }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            NSLog("[WhiskyClaude] ClapDetector: input format unusable (sr=\(format.sampleRate), ch=\(format.channelCount))")
            return
        }

        let streamAnalyzer = SNAudioStreamAnalyzer(format: format)
        do {
            let req = try SNClassifySoundRequest(classifierIdentifier: .version1)
            try streamAnalyzer.add(req, withObserver: self)
            self.analyzer = streamAnalyzer
            self.request = req
        } catch {
            NSLog("[WhiskyClaude] SoundAnalysis setup failed: \(error)")
            return
        }

        // Buffer size 8192 ≈ 185ms at 44.1kHz — a balance between classifier
        // latency (longer windows let the model see more context) and double-clap
        // gap resolution (we need to distinguish 100-600ms gaps).
        input.installTap(onBus: 0, bufferSize: 8192, format: format) { [weak self] buffer, time in
            self?.analysisQueue.async {
                self?.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
        }

        do {
            try engine.start()
            isRunning = true
            NSLog("[WhiskyClaude] ClapDetector started (SoundAnalysis, threshold=\(confidenceThreshold))")
        } catch {
            NSLog("[WhiskyClaude] engine.start() failed: \(error)")
            input.removeTap(onBus: 0)
            analyzer?.removeAllRequests()
            analyzer = nil
            request = nil
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        analyzer?.removeAllRequests()
        analyzer = nil
        request = nil
        isRunning = false
        lastClapAt = 0
        NSLog("[WhiskyClaude] ClapDetector stopped")
    }

    private func handleClapDetected() {
        let now = CACurrentMediaTime()
        let dt = now - lastClapAt
        if dt > minGap && dt < maxGap {
            DispatchQueue.main.async { [weak self] in
                self?.onDoubleClap?()
            }
            lastClapAt = 0   // reset so a third clap doesn't immediately re-trigger
        } else {
            lastClapAt = now
        }
    }
}

extension ClapDetector: SNResultsObserving {
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classification = result as? SNClassificationResult else { return }

        // Find the best matching clap-related identifier above the threshold.
        let hit = classification.classifications.first { c in
            Self.clapIdentifiers.contains(c.identifier) &&
                c.confidence >= confidenceThreshold
        }
        guard hit != nil else { return }

        // SNResultsObserving callbacks run on the analyzer's queue. Bounce to
        // main for state mutation + the user callback.
        DispatchQueue.main.async { [weak self] in
            self?.handleClapDetected()
        }
    }

    func request(_ request: SNRequest, didFailWithError error: Error) {
        NSLog("[WhiskyClaude] SoundAnalysis request failed: \(error)")
    }

    func requestDidComplete(_ request: SNRequest) {
        // Stream analysis doesn't normally complete; called on engine teardown.
    }
}

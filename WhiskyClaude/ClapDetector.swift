import AVFoundation
import Foundation
import SoundAnalysis

/// Detects double-clap audio via Apple's on-device SoundAnalysis classifier
/// (`SNClassifierIdentifier.version1`). Hooks into SharedMicCapture so it
/// co-exists with the keyword recognizer.
///
/// Key tuning decisions vs. v2.0:
/// - overlapFactor = 0.5 so the classifier fires every ~500ms (was 0.0 = 1/s)
/// - Gap window widened to 0.30-1.50s to match the new 500ms firing cadence
/// - Threshold floor lowered: sensitivity 0..1 → 0.35..0.80 (was 0.5..0.9)
/// - NSLog of every clap-identifier result for threshold tuning
final class ClapDetector: NSObject {
    static let shared = ClapDetector()

    /// Fired on the main queue when a double-clap is detected.
    var onDoubleClap: (() -> Void)?

    private var analyzer: SNAudioStreamAnalyzer?
    private var request: SNClassifySoundRequest?
    private let analysisQueue = DispatchQueue(label: "com.ahmadsharaf.WhiskyClaude.clapAnalysis")

    private var isRunning = false
    private var lastClapAt: CFTimeInterval = 0

    /// SoundAnalysis fires classifications every ~500ms (overlapFactor 0.5)
    /// from a 1-second sliding window. A real double-clap produces 2 consecutive
    /// high-confidence results separated by roughly 0.5s. Allow 0.3-1.5s gap.
    private let minGap: CFTimeInterval = 0.30
    private let maxGap: CFTimeInterval = 1.50

    /// Sensitivity 0..1 → confidence threshold 0.35 (lenient) ... 0.80 (strict).
    private var confidenceThreshold: Double = 0.55

    private static let clapIdentifiers: Set<String> = ["clapping", "applause"]
    private static let consumerId = "clap-detector"

    private override init() { super.init() }

    /// Maps 0..1 user-facing sensitivity to the Apple confidence threshold.
    func setSensitivity(_ s: Double) {
        let clamped = max(0, min(1, s))
        confidenceThreshold = 0.35 + 0.45 * clamped
    }

    func start() {
        guard !isRunning else { return }
        guard let format = SharedMicCapture.shared.inputFormat,
              format.sampleRate > 0, format.channelCount > 0 else {
            NSLog("[WhiskyClaude] ClapDetector: input format unusable")
            return
        }

        let streamAnalyzer = SNAudioStreamAnalyzer(format: format)
        do {
            let req = try SNClassifySoundRequest(classifierIdentifier: .version1)
            req.overlapFactor = 0.5   // every 500ms, see last 1s of audio
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
            NSLog("[WhiskyClaude] ClapDetector: failed to register mic consumer")
            analyzer?.removeAllRequests()
            analyzer = nil
            request = nil
            return
        }
        isRunning = true
        NSLog("[WhiskyClaude] ClapDetector started (threshold=\(confidenceThreshold))")
    }

    func stop() {
        guard isRunning else { return }
        SharedMicCapture.shared.unregister(id: Self.consumerId)
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

        // Log everything matching a clap identifier (helps tune threshold).
        if let any = classification.classifications.first(where: { Self.clapIdentifiers.contains($0.identifier) }) {
            NSLog("[WhiskyClaude] clap-detect: \(any.identifier) conf=\(String(format: "%.2f", any.confidence)) threshold=\(String(format: "%.2f", confidenceThreshold))")
        }

        // Find the best matching clap-related identifier above the threshold.
        let hit = classification.classifications.first { c in
            Self.clapIdentifiers.contains(c.identifier) && c.confidence >= confidenceThreshold
        }
        guard hit != nil else { return }

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

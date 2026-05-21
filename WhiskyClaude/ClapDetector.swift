import AVFoundation
import Foundation

/// Detects double-clap audio events using amplitude + timing analysis.
///
/// A clap is a sudden RMS spike above the configured threshold. Two such
/// spikes within 100ms-600ms count as a double-clap and fire `onDoubleClap`.
/// All audio analysis happens in-buffer on the audio thread; nothing is stored.
///
/// Microphone permission is requested by AVAudioEngine on first `start()`.
/// The mic indicator on macOS shows ON while this is running — that's normal.
final class ClapDetector {
    static let shared = ClapDetector()

    var onDoubleClap: (() -> Void)?

    private let engine = AVAudioEngine()
    private var isRunning = false
    private var lastClapAt: CFTimeInterval = 0
    private let minGap: CFTimeInterval = 0.10   // 100ms — closer than this is one clap echo
    private let maxGap: CFTimeInterval = 0.60   // 600ms — wider than this is unrelated noise
    /// Sensitivity 0..1 maps to RMS threshold 0.08 (strict) ... 0.02 (lenient).
    private var rmsThreshold: Float = 0.05

    private init() {}

    func setSensitivity(_ s: Double) {
        let clamped = max(0, min(1, s))
        rmsThreshold = Float(0.08 - 0.06 * clamped)
    }

    func start() {
        guard !isRunning else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // Sanity: input format may be 0Hz / 0 channels if the mic isn't usable.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            NSLog("[WhiskyClaude] ClapDetector: input format unusable (sr=\(format.sampleRate), ch=\(format.channelCount))")
            return
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        do {
            try engine.start()
            isRunning = true
            NSLog("[WhiskyClaude] ClapDetector started")
        } catch {
            NSLog("[WhiskyClaude] ClapDetector start failed: \(error)")
            // Remove the tap so a future retry can install fresh.
            input.removeTap(onBus: 0)
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        NSLog("[WhiskyClaude] ClapDetector stopped")
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let chans = buffer.floatChannelData else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }
        let samples = chans[0]
        var sumSq: Float = 0
        for i in 0..<n { sumSq += samples[i] * samples[i] }
        let rms = sqrt(sumSq / Float(n))

        guard rms > rmsThreshold else { return }
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

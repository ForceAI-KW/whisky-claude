import AVFoundation
import Foundation

/// Single owner of the AVAudioEngine input tap. Fans buffers out to multiple
/// registered consumers (clap detector, keyword recognizer, future analyzers).
/// Idempotent start/stop — multiple consumers calling start() only initialize
/// once; stop() only tears down when the last consumer unregisters.
final class SharedMicCapture {
    static let shared = SharedMicCapture()

    private let engine = AVAudioEngine()
    private var consumers: [String: (AVAudioPCMBuffer, AVAudioTime) -> Void] = [:]
    private var isRunning = false
    private let lock = NSLock()

    private init() {}

    var inputFormat: AVAudioFormat? {
        engine.inputNode.outputFormat(forBus: 0)
    }

    /// Register a consumer. If this is the first registration, starts the engine.
    /// Returns false if the engine couldn't start (mic permission denied, format
    /// invalid, etc.) — in that case the consumer is NOT registered.
    @discardableResult
    func register(id: String, consumer: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        consumers[id] = consumer
        if !isRunning {
            return startUnlocked()
        }
        return true
    }

    /// Unregister a consumer. If this was the last one, stops the engine.
    func unregister(id: String) {
        lock.lock()
        defer { lock.unlock() }
        consumers.removeValue(forKey: id)
        if consumers.isEmpty {
            stopUnlocked()
        }
    }

    private func startUnlocked() -> Bool {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            NSLog("[WhiskyClaude] SharedMicCapture: input format unusable")
            consumers.removeAll()
            return false
        }
        input.installTap(onBus: 0, bufferSize: 8192, format: format) { [weak self] buffer, time in
            guard let self else { return }
            // Snapshot under lock to avoid concurrent mutation while iterating
            self.lock.lock()
            let callbacks = Array(self.consumers.values)
            self.lock.unlock()
            for cb in callbacks {
                cb(buffer, time)
            }
        }
        do {
            try engine.start()
            isRunning = true
            NSLog("[WhiskyClaude] SharedMicCapture started (sr=\(format.sampleRate) ch=\(format.channelCount))")
            return true
        } catch {
            NSLog("[WhiskyClaude] SharedMicCapture engine.start failed: \(error)")
            input.removeTap(onBus: 0)
            consumers.removeAll()
            return false
        }
    }

    private func stopUnlocked() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        NSLog("[WhiskyClaude] SharedMicCapture stopped")
    }
}

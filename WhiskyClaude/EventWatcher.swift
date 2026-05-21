import Foundation
import Combine

/// Watches ~/.claude/pet-events/ for new JSON event files written by Claude Code hooks.
/// Each event sets `ExternalEventState.shared.current`, then the file is deleted.
/// NotchDisplayState.current merges this external state with the panel's internal
/// session states (priority order encoded there).
final class EventWatcher {
    static let shared = EventWatcher()

    private let dir: URL
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private let queue = DispatchQueue(label: "com.ahmadsharaf.WhiskyClaude.eventWatcher")

    private struct Event: Decodable {
        let type: String
        let message: String?
    }

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        dir = home.appendingPathComponent(".claude/pet-events", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func start() {
        stop()
        fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("[WhiskyClaude] EventWatcher: open() failed: \(String(cString: strerror(errno)))")
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write], queue: queue
        )
        src.setEventHandler { [weak self] in self?.scan() }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fd, fd >= 0 { close(fd) }
            self?.fd = -1
        }
        source = src
        src.resume()
        // Drain anything already queued before app launch
        scan()
        NSLog("[WhiskyClaude] EventWatcher: watching \(dir.path)")
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func scan() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let files = contents
            .filter { $0.pathExtension == "json" }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a < b
            }
        for file in files {
            if let data = try? Data(contentsOf: file),
               let event = try? JSONDecoder().decode(Event.self, from: data) {
                DispatchQueue.main.async {
                    ExternalEventState.shared.apply(type: event.type)
                }
            }
            try? FileManager.default.removeItem(at: file)
        }
    }
}

/// Mirrors NotchDisplayState but driven by external file events. The aggregate
/// NotchDisplayState.current merges this with the embedded terminal panel's
/// session states (see NotchWindow.swift).
@Observable
final class ExternalEventState {
    static let shared = ExternalEventState()
    private(set) var current: NotchDisplayState = .idle
    private var idleTimer: Timer?

    private init() {}

    func apply(type: String) {
        let state: NotchDisplayState
        switch type {
        case "thinking", "working": state = .working
        case "attention":           state = .waitingForInput
        case "done":                state = .taskCompleted
        default:                    state = .idle
        }
        self.current = state
        scheduleIdleDrift()
        NotificationCenter.default.post(name: .WhiskyClaudeNotchStatusChanged, object: nil)
    }

    private func scheduleIdleDrift() {
        idleTimer?.invalidate()
        // Attention + done drift back to idle fast (after the user has noticed);
        // working/thinking hold longer because they're transient during normal use.
        let delay: TimeInterval = (current == .waitingForInput || current == .taskCompleted) ? 5 : 30
        idleTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.current = .idle
            NotificationCenter.default.post(name: .WhiskyClaudeNotchStatusChanged, object: nil)
        }
    }
}

import AppKit

/// Owns the menu-bar status item icon. The icon is the Claude logo (loaded
/// from the `ClaudeLogo` asset catalog). On `attention`/`done` state changes,
/// the button alpha pulses to draw the user's attention.
final class MenuBarIcon {
    private let statusItem: NSStatusItem
    private var pulseRemaining: Int = 0

    init(statusItem: NSStatusItem) {
        self.statusItem = statusItem
        if let image = NSImage(named: "ClaudeLogo") {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = false   // we want the Claude orange color, not a template
            statusItem.button?.image = image
        } else {
            // Fallback: SF Symbol if the asset isn't bundled yet (build-time race).
            statusItem.button?.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "Whisky Claude")
        }
        statusItem.button?.imagePosition = .imageOnly
    }

    func onStateChange(_ state: AttentionKind) {
        switch state {
        case .waitingForInput:
            pulse(times: 3)
        case .taskCompleted:
            pulse(times: 2)
        case .working, .idle:
            // No animation for transient working state; idle is the resting state.
            break
        }
    }

    /// Triple/double alpha pulse: 1 → 0.35 → 1, ~150ms per half. Used as the
    /// visual "attention please" without any window/notch overlay.
    private func pulse(times: Int) {
        guard let button = statusItem.button else { return }
        pulseRemaining = times * 2   // each pulse is two animation steps
        scheduleNextPulseStep(button: button)
    }

    private func scheduleNextPulseStep(button: NSStatusBarButton) {
        guard pulseRemaining > 0 else {
            button.alphaValue = 1.0
            return
        }
        let goingDim = pulseRemaining % 2 == 0
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            button.animator().alphaValue = goingDim ? 0.35 : 1.0
        }, completionHandler: { [weak self] in
            self?.pulseRemaining -= 1
            self?.scheduleNextPulseStep(button: button)
        })
    }
}

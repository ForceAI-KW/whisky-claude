import AppKit
import QuartzCore

/// Owns the menu-bar status item icon. The icon is the Claude logo (loaded
/// from the `ClaudeLogo` asset catalog). On `attention`/`done` state changes,
/// the button scales up and back using a CAKeyframeAnimation so the icon
/// visibly pops even on dark-mode menu bars where alpha changes are subtle.
final class MenuBarIcon {
    private let statusItem: NSStatusItem

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

    /// Scale-bounce animation: 1.0 → 1.35 → 1.0 per bounce, using a
    /// CAKeyframeAnimation. Visible even at small menu-bar size and in dark mode.
    private func pulse(times: Int) {
        guard let button = statusItem.button else { return }
        button.wantsLayer = true
        guard let layer = button.layer else { return }

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        var values: [Double] = [1.0]
        var keyTimes: [NSNumber] = [0.0]
        let perBounce = 1.0 / Double(times)
        for i in 0..<times {
            values.append(1.35)
            values.append(1.0)
            keyTimes.append(NSNumber(value: perBounce * (Double(i) + 0.5)))
            keyTimes.append(NSNumber(value: perBounce * Double(i + 1)))
        }
        scale.values = values
        scale.keyTimes = keyTimes
        scale.duration = Double(times) * 0.35
        scale.calculationMode = .cubic
        // Anchor at center so scaling doesn't shift the icon off the bar
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.add(scale, forKey: "bounce")
    }
}

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

    /// Per Ahmad: the menu-bar icon stays STATIC — it's just the app logo
    /// indicating Whisky Claude is running. All attention-grabbing happens
    /// via the mascot under the notch + the sound.
    func onStateChange(_ state: AttentionKind) {
        // intentionally no animation
    }
}

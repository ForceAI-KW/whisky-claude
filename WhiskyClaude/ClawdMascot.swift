import AppKit
import SwiftUI

/// Clawd — the Claude Code pixel mascot. Maps each Claude Code attention state
/// to a POOL of animation names; `MascotContent` cycles within the pool over
/// time so the mascot rotates through its repertoire instead of looping one clip.
///
/// Animations are bundled as asset-catalog data sets (clawd-*.gif). Source art:
/// clawd-on-desk (github.com/rullerzhou-afk/clawd-on-desk, AGPL-3.0) — used
/// locally as a Claude Code helper, credit to the author + Anthropic's Clawd.
enum ClawdPose {
    /// Pose pool for a given attention state. First entry is the "primary" pose.
    static func pool(for kind: AttentionKind) -> [String] {
        switch kind {
        case .idle:
            // Calm-but-alive repertoire while nothing is happening.
            return ["clawd-idle", "clawd-idle-reading", "clawd-juggling",
                    "clawd-sweeping", "clawd-headphones-groove", "clawd-conducting",
                    "clawd-carrying"]
        case .working:
            // Claude is doing work → heads-down "typing on a laptop" repertoire.
            return ["clawd-typing", "clawd-thinking", "clawd-debugger", "clawd-building"]
        case .waitingForInput:
            // Needs you in real time → alert / notification.
            return ["clawd-notification"]
        case .taskCompleted:
            // Done → celebrate.
            return ["clawd-happy"]
        }
    }

    /// Seconds each variant stays on screen before cycling to the next in its pool.
    static let variantInterval: Double = 24.0

    /// Resolve the concrete gif name for a state at a given elapsed time.
    static func name(for kind: AttentionKind, at elapsed: TimeInterval) -> String {
        let p = pool(for: kind)
        guard !p.isEmpty else { return "clawd-idle" }
        let i = Int(elapsed / variantInterval) % p.count
        return p[i]
    }
}

/// NSImageView that reports NO intrinsic size, so SwiftUI's `.frame(...)` fully
/// controls how big it is. Without this, the view advertises the GIF's native
/// canvas (~302×300) as its intrinsic size and blows past the requested frame.
final class FittedImageView: NSImageView {
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }
}

/// Plays a bundled animated GIF (asset-catalog data set), nearest-neighbor scaled
/// so the pixel art stays crisp. The image is fit INSIDE the requested frame.
struct ClawdGIFView: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> FittedImageView {
        let v = FittedImageView()
        v.imageScaling = .scaleProportionallyUpOrDown
        v.imageAlignment = .alignCenter
        v.animates = true
        v.wantsLayer = true
        v.layer?.magnificationFilter = .nearest
        v.layer?.minificationFilter = .nearest
        v.setContentHuggingPriority(.defaultLow, for: .horizontal)
        v.setContentHuggingPriority(.defaultLow, for: .vertical)
        v.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        context.coordinator.current = name
        load(name, into: v)
        return v
    }

    func updateNSView(_ v: FittedImageView, context: Context) {
        guard context.coordinator.current != name else { return }
        context.coordinator.current = name
        load(name, into: v)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var current: String = "" }

    private func load(_ name: String, into v: FittedImageView) {
        guard let data = NSDataAsset(name: name)?.data, let img = NSImage(data: data) else { return }
        v.image = img
        v.animates = true
    }
}

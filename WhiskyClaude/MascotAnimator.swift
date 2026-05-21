import Foundation
import CoreVideo
import QuartzCore

/// Frame-by-frame mascot jump animator.
/// Reports a Y-offset (points) per tick via `onTick`.
/// Y > 0 means "up" (the call site applies the offset with negative SwiftUI y).
final class MascotAnimator {
    static let shared = MascotAnimator()

    /// Called on the main queue once per display frame with the current Y-offset.
    var onTick: ((CGFloat) -> Void)?

    private var displayLink: CVDisplayLink?
    private var opaqueRef: Unmanaged<MascotAnimator>?
    private var startTime: CFTimeInterval = 0
    private var duration: CFTimeInterval = 0
    private var jumpHeight: CGFloat = 0
    private var repeats: Int = 0

    private init() {}

    /// Jump 3× by default (waitingForInput).
    func jump(height: CGFloat = 14, perJump: CFTimeInterval = 0.35, repeats: Int = 3) {
        stop()
        self.jumpHeight = height
        self.duration = perJump * Double(repeats)
        self.repeats = repeats
        self.startTime = CACurrentMediaTime()
        startDisplayLink()
    }

    /// Bounce 2× by default (taskCompleted). Same waveform as `jump`, shorter/lower
    /// defaults — kept as a named alias so callers express intent.
    func bounce(height: CGFloat = 9, perJump: CFTimeInterval = 0.3, repeats: Int = 2) {
        jump(height: height, perJump: perJump, repeats: repeats)
    }

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        self.displayLink = link

        // Retain self once for the CVDisplayLink callback. The matching release
        // happens in `stop()` when an animation is cancelled, OR inline below when
        // the animation runs to completion. Tracking the retain in `opaqueRef`
        // avoids the double-release race that would otherwise happen on rapid
        // re-trigger (jump() → stop() → jump() with an in-flight callback).
        let retain = Unmanaged.passRetained(self)
        self.opaqueRef = retain

        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, userInfo) -> CVReturn in
            guard let userInfo else { return kCVReturnError }
            let me = Unmanaged<MascotAnimator>.fromOpaque(userInfo).takeUnretainedValue()
            let elapsed = CACurrentMediaTime() - me.startTime
            if elapsed >= me.duration {
                DispatchQueue.main.async {
                    me.onTick?(0)
                    me.releaseOpaqueAndStop(matching: userInfo)
                }
                return kCVReturnSuccess
            }
            let perJump = me.duration / Double(me.repeats)
            let local = elapsed.truncatingRemainder(dividingBy: perJump) / perJump
            // sin curve: 0 → 1 → 0 over each jump
            let y = me.jumpHeight * CGFloat(sin(local * .pi))
            DispatchQueue.main.async { me.onTick?(y) }
            return kCVReturnSuccess
        }, retain.toOpaque())

        CVDisplayLinkStart(link)
    }

    /// Called from the completion branch of the CVDisplayLink callback (on the
    /// main queue). Releases the retain ONLY if it still matches the userInfo
    /// pointer that fired this callback — if `stop()` already replaced/released
    /// the retain (because a newer animation started), this is a no-op.
    private func releaseOpaqueAndStop(matching userInfo: UnsafeMutableRawPointer) {
        guard let ref = opaqueRef, ref.toOpaque() == userInfo else { return }
        opaqueRef = nil
        if let link = displayLink {
            CVDisplayLinkStop(link)
            self.displayLink = nil
        }
        ref.release()
    }

    /// Cancel any in-flight animation. Safe to call from main thread at any time.
    func stop() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            self.displayLink = nil
        }
        if let ref = opaqueRef {
            opaqueRef = nil
            ref.release()
        }
    }
}

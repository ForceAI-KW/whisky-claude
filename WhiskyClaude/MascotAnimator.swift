import Foundation
import CoreVideo
import QuartzCore

/// Frame-by-frame mascot jump animator.
/// Reports a Y-offset (points) per tick via `onTick`.
/// Y > 0 means "up" (the call site applies the offset with negative SwiftUI y).
final class MascotAnimator {
    static let shared = MascotAnimator()

    var onTick: ((CGFloat) -> Void)?

    private var displayLink: CVDisplayLink?
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

    /// Bounce 2× by default (taskCompleted).
    func bounce(height: CGFloat = 9, perJump: CFTimeInterval = 0.3, repeats: Int = 2) {
        jump(height: height, perJump: perJump, repeats: repeats)
    }

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        self.displayLink = link

        let opaque = Unmanaged.passRetained(self)
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, userInfo) -> CVReturn in
            guard let userInfo else { return kCVReturnError }
            let me = Unmanaged<MascotAnimator>.fromOpaque(userInfo).takeUnretainedValue()
            let elapsed = CACurrentMediaTime() - me.startTime
            if elapsed >= me.duration {
                DispatchQueue.main.async { me.onTick?(0) }
                me.stop()
                Unmanaged<MascotAnimator>.fromOpaque(userInfo).release()
                return kCVReturnSuccess
            }
            let perJump = me.duration / Double(me.repeats)
            let local = elapsed.truncatingRemainder(dividingBy: perJump) / perJump
            // sin curve: 0 → 1 → 0 over each jump
            let y = me.jumpHeight * CGFloat(sin(local * .pi))
            DispatchQueue.main.async { me.onTick?(y) }
            return kCVReturnSuccess
        }, opaque.toOpaque())

        CVDisplayLinkStart(link)
    }

    func stop() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            self.displayLink = nil
        }
    }
}

import AppKit
import SwiftUI

/// A borderless, click-through floating panel that shows a bouncing Claude
/// character at the top-center of the main screen when attention or done
/// events fire. Auto-hides ~2 seconds after the animation completes.
final class MascotWindow: NSPanel {
    private let state = MascotAnimationState()
    private var hostingView: NSView?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        hasShadow = false
        isOpaque = false
        animationBehavior = .none
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .transient]
        alphaValue = 0

        let hv = NSHostingView(rootView: MascotContent(state: state))
        if let cv = contentView {
            hv.frame = cv.bounds
            hv.autoresizingMask = [.width, .height]
            hv.wantsLayer = true
            hv.layer?.backgroundColor = .clear
            cv.addSubview(hv)
            cv.wantsLayer = true
            cv.layer?.masksToBounds = false
        }
        hostingView = hv
        positionAtTopCenter()
        orderOut(nil)
    }

    private func positionAtTopCenter() {
        guard let screen = NSScreen.main else { return }
        let f = screen.frame
        let visible = screen.visibleFrame
        let w: CGFloat = 120
        let h: CGFloat = 140
        // 10pt below the visible-frame top (which is just below the menu bar)
        let y = visible.maxY - h - 10
        let x = f.midX - w / 2
        setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    }

    func show(kind: MascotBounceKind) {
        positionAtTopCenter()
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            animator().alphaValue = 1.0
        }
        state.trigger(kind: kind) { [weak self] in
            self?.hideAfterDelay()
        }
    }

    private func hideAfterDelay() {
        // Linger ~0.5s after the bounce completes so the user sees the final
        // resting state, then fade out + hide.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                self.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                self?.orderOut(nil)
            })
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

enum MascotBounceKind {
    case attention   // 3 bounces, higher
    case done        // 2 bounces, gentler
}

/// Drives the bounce animation. The SwiftUI view observes this via @Observable.
@Observable
final class MascotAnimationState {
    var bounceTrigger: Int = 0
    var currentKind: MascotBounceKind = .attention

    /// Triggers a bounce animation. `completion` is called after the visible
    /// motion finishes (matches the longest expected animation duration).
    func trigger(kind: MascotBounceKind, completion: @escaping () -> Void) {
        currentKind = kind
        bounceTrigger += 1
        let duration: Double = (kind == .attention) ? 1.2 : 0.9
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: completion)
    }
}

/// SwiftUI view that animates the Claude character using the
/// `bounceTrigger` counter on MascotAnimationState as a value-change cue.
struct MascotContent: View {
    var state: MascotAnimationState
    @State private var yOffset: CGFloat = 0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Image("ClaudeLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                .offset(y: yOffset)
                .rotationEffect(.degrees(rotation))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onChange(of: state.bounceTrigger) { _, _ in
            runBounce(kind: state.currentKind)
        }
    }

    private func runBounce(kind: MascotBounceKind) {
        // Reset
        yOffset = 0
        rotation = 0

        let bounces: Int = (kind == .attention) ? 3 : 2
        let peakHeight: CGFloat = (kind == .attention) ? 36 : 24
        let perBounce: Double = (kind == .attention) ? 0.4 : 0.45
        let wobbleDeg: Double = (kind == .attention) ? 8 : 4

        for i in 0..<bounces {
            let start = Double(i) * perBounce
            let up = perBounce * 0.45

            // Up
            DispatchQueue.main.asyncAfter(deadline: .now() + start) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    yOffset = -peakHeight
                    rotation = (i % 2 == 0) ? wobbleDeg : -wobbleDeg
                }
            }
            // Down
            DispatchQueue.main.asyncAfter(deadline: .now() + start + up) {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.55)) {
                    yOffset = 0
                    rotation = 0
                }
            }
        }
    }
}

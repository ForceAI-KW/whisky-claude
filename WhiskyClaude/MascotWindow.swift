import AppKit
import SwiftUI

/// Always-visible floating panel showing the Claude character "around" the
/// macOS notch. Sits with its center on the notch's bottom edge — so the upper
/// half of the mascot is clipped by the hardware notch (no display there) and
/// the lower half peeks out below it onto the desktop. Minimises the desktop
/// footprint to roughly half the mascot height.
///
/// Idle animation: gentle vertical bob + tiny rotation, runs forever.
/// Attention/done overlay: a bigger downward "peek out" plus rotation wobble,
/// layered on top of idle. After the bounce, settles back to resting position
/// (idle continues).
final class MascotWindow: NSPanel {
    private let hostView: NSHostingView<MascotContent>
    private let state = MascotAnimationState()
    private var screenObserver: Any?

    /// Visible logical size of the mascot inside the window.
    /// Roughly tracks the menu-bar / notch height (~37pt) — small enough not to
    /// extend horizontally beyond the notch, big enough to read at a glance.
    static let mascotSize: CGFloat = 36

    /// Padding around the mascot for the idle/attention motion to occur inside
    /// the window bounds without clipping. Kept tight so we don't grab a huge
    /// region of the menu-bar that could overlap menu items.
    private static let windowPadding: CGFloat = 24

    init() {
        hostView = NSHostingView(rootView: MascotContent(state: state))
        super.init(
            contentRect: NSRect(x: 0, y: 0,
                                width: Self.mascotSize + Self.windowPadding,
                                height: Self.mascotSize + Self.windowPadding),
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
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        alphaValue = 1.0

        if let cv = contentView {
            hostView.frame = cv.bounds
            hostView.autoresizingMask = [.width, .height]
            hostView.wantsLayer = true
            hostView.layer?.backgroundColor = .clear
            cv.addSubview(hostView)
            cv.wantsLayer = true
            cv.layer?.masksToBounds = false
        }

        positionAtNotch()
        observeScreenChanges()
        applyVisibility(SettingsManager.shared.mascotVisible)
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Position the window so the mascot's vertical center lines up with the
    /// notch's bottom edge (= menu bar's bottom edge on a notch Mac). Half the
    /// mascot sits behind the notch outline (clipped — invisible because
    /// there's no display in the notch) and half peeks out onto the desktop.
    /// Horizontally centered on the screen so it stays within the notch's
    /// horizontal width (≈180pt on M-series), well clear of menu items.
    private func positionAtNotch() {
        guard let screen = NSScreen.builtIn else { return }
        let frame = screen.frame
        let visible = screen.visibleFrame
        let w = Self.mascotSize + Self.windowPadding
        let h = Self.mascotSize + Self.windowPadding
        let notchBottom = visible.maxY   // = screen.maxY - menuBarHeight
        // Window center y = notchBottom → window y origin = notchBottom - h/2
        let y = notchBottom - h / 2
        let x = frame.midX - w / 2
        setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.positionAtNotch()
        }
    }

    /// Toggle visibility based on the user setting.
    func applyVisibility(_ visible: Bool) {
        if visible {
            positionAtNotch()
            orderFrontRegardless()
        } else {
            orderOut(nil)
        }
    }

    /// Trigger an additional bounce on top of the persistent idle animation.
    func triggerBounce(kind: MascotBounceKind) {
        state.trigger(kind: kind)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

enum MascotBounceKind {
    case attention   // bigger peek-out
    case done        // smaller peek-out
}

@Observable
final class MascotAnimationState {
    var bounceTrigger: Int = 0
    var currentKind: MascotBounceKind = .attention

    func trigger(kind: MascotBounceKind) {
        currentKind = kind
        bounceTrigger += 1
    }
}

/// SwiftUI view rendering the Claude character. Two layered animations:
///   - Persistent idle: a small sin-curve y-bob + slow rotation wobble, runs
///     forever via TimelineView at ~30fps. Amplitude is small (±1.5pt) so the
///     mascot stays mostly within the notch boundary and the visible peek
///     below the notch is stable.
///   - Attention/done bounce: a DOWNWARD spring offset added on top of idle,
///     so the mascot briefly "peeks further out" from below the notch. Repeats
///     a few times then settles back. Bounce amplitude is capped so the peek
///     stays close to the menu bar (minimal desktop intrusion).
struct MascotContent: View {
    @State var state: MascotAnimationState

    @State private var bounceOffset: CGFloat = 0
    @State private var bounceRotation: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let idleY = sin(elapsed * 2 * .pi / 2.4) * 1.5     // 2.4s cycle, ±1.5pt
            let idleRot = sin(elapsed * 2 * .pi / 3.8) * 1.0   // 3.8s cycle, ±1°

            Image("ClaudeLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: MascotWindow.mascotSize, height: MascotWindow.mascotSize)
                .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 2)
                .offset(y: idleY + bounceOffset)
                .rotationEffect(.degrees(idleRot + bounceRotation))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onChange(of: state.bounceTrigger) { _, _ in
            runBounce(kind: state.currentKind)
        }
    }

    /// Peek-out bounce: mascot shifts DOWNWARD (positive y in SwiftUI) to
    /// reveal more of itself from below the notch, then springs back. The
    /// downward direction is deliberate — moving up would push the mascot
    /// further into the notch outline where there's no display, making the
    /// bounce invisible.
    private func runBounce(kind: MascotBounceKind) {
        bounceOffset = 0
        bounceRotation = 0

        let bounces: Int = (kind == .attention) ? 3 : 2
        let peakHeight: CGFloat = (kind == .attention) ? 10 : 6
        let perBounce: Double = (kind == .attention) ? 0.34 : 0.40
        let wobbleDeg: Double = (kind == .attention) ? 5 : 3

        for i in 0..<bounces {
            let start = Double(i) * perBounce
            let down = perBounce * 0.45
            DispatchQueue.main.asyncAfter(deadline: .now() + start) {
                withAnimation(.spring(response: 0.20, dampingFraction: 0.55)) {
                    bounceOffset = peakHeight    // positive = downward = more visible
                    bounceRotation = (i % 2 == 0) ? wobbleDeg : -wobbleDeg
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + start + down) {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.55)) {
                    bounceOffset = 0
                    bounceRotation = 0
                }
            }
        }
    }
}

// MARK: - NSScreen helper

extension NSScreen {
    /// Returns the built-in display (the one with the notch), or the main screen as fallback.
    static var builtIn: NSScreen? {
        screens.first { screen in
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            return CGDisplayIsBuiltin(id) != 0
        } ?? main
    }
}

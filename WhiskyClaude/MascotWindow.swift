import AppKit
import SwiftUI

/// Always-visible floating panel showing the Claude character just below the
/// macOS notch. Continuously runs an idle float animation. When attention or
/// done events fire, layers a more energetic bounce on top of the idle motion.
final class MascotWindow: NSPanel {
    private let hostView: NSHostingView<MascotContent>
    private let state = MascotAnimationState()
    private var screenObserver: Any?
    /// Visible logical size of the mascot inside the window.
    static let mascotSize: CGFloat = 56
    /// Window padding around the mascot — gives room for the idle float +
    /// the bigger attention bounce to remain inside the window bounds.
    private static let windowPadding: CGFloat = 40

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

        positionUnderNotch()
        observeScreenChanges()
        // Apply current visibility setting
        applyVisibility(SettingsManager.shared.mascotVisible)
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Position the window directly under the notch, centered horizontally,
    /// with the mascot's TOP just below the menu bar's BOTTOM edge.
    /// On Macs without a notch (external display, older Mac), positions at
    /// top-center under the menu bar as a graceful fallback.
    private func positionUnderNotch() {
        guard let screen = NSScreen.builtIn else { return }
        let frame = screen.frame
        let visible = screen.visibleFrame
        let w = Self.mascotSize + Self.windowPadding
        let h = Self.mascotSize + Self.windowPadding
        let menuBarBottom = visible.maxY
        // Window's top edge sits a few pt below the menu bar bottom so the
        // mascot has clear breathing room and never overlaps the bar.
        let topGap: CGFloat = 4
        let y = menuBarBottom - h - topGap
        let x = frame.midX - w / 2
        setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.positionUnderNotch()
        }
    }

    /// Toggle visibility based on the user setting. When hidden, the panel is
    /// ordered out so it stops rendering frames (saves a bit of CPU). When
    /// shown again, re-positions in case the screen layout changed while hidden.
    func applyVisibility(_ visible: Bool) {
        if visible {
            positionUnderNotch()
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
    case attention   // 3 bounces, higher
    case done        // 2 bounces, gentler
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
///   - Persistent idle: a sin-curve y-bob that runs forever via a TimelineView
///     publisher. Small amplitude (~3pt), ~2s cycle.
///   - Attention/done bounce: a higher-amplitude offset added ON TOP of the
///     idle bob, triggered by `state.bounceTrigger` increments.
struct MascotContent: View {
    @State var state: MascotAnimationState

    @State private var bounceOffset: CGFloat = 0
    @State private var bounceRotation: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let idleY = sin(elapsed * 2 * .pi / 2.0) * 3.0   // 2s cycle, 3pt amplitude
            let idleRot = sin(elapsed * 2 * .pi / 3.5) * 1.5  // 3.5s cycle, ±1.5deg

            Image("ClaudeLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: MascotWindow.mascotSize, height: MascotWindow.mascotSize)
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
                .offset(y: idleY + bounceOffset)
                .rotationEffect(.degrees(idleRot + bounceRotation))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onChange(of: state.bounceTrigger) { _, _ in
            runBounce(kind: state.currentKind)
        }
    }

    /// Layered bounce on top of the persistent idle motion. Animates
    /// `bounceOffset` and `bounceRotation` via SwiftUI springs, scheduled
    /// over a short duration.
    private func runBounce(kind: MascotBounceKind) {
        bounceOffset = 0
        bounceRotation = 0

        let bounces: Int = (kind == .attention) ? 3 : 2
        let peakHeight: CGFloat = (kind == .attention) ? 28 : 18
        let perBounce: Double = (kind == .attention) ? 0.36 : 0.42
        let wobbleDeg: Double = (kind == .attention) ? 8 : 4

        for i in 0..<bounces {
            let start = Double(i) * perBounce
            let up = perBounce * 0.45
            DispatchQueue.main.asyncAfter(deadline: .now() + start) {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
                    bounceOffset = -peakHeight
                    bounceRotation = (i % 2 == 0) ? wobbleDeg : -wobbleDeg
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + start + up) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
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
    /// Re-added here after NotchWindow.swift was removed in the v2 refactor.
    static var builtIn: NSScreen? {
        screens.first { screen in
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            return CGDisplayIsBuiltin(id) != 0
        } ?? main
    }
}

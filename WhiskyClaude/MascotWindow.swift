import AppKit
import SwiftUI

/// Always-visible floating panel hosting the Claude character. The mascot
/// "lives" around the notch — it paces left/right along the notch's bottom
/// edge, peeks up into the notch, hops in place, and tilts as it walks.
/// Horizontally constrained to stay strictly within the notch's outline so
/// menu items left/right of the notch are never covered.
///
/// On attention/done events, layers a more energetic peek-out + rotation
/// wobble on top of the ambient walking behavior.
final class MascotWindow: NSPanel {
    private let hostView: NSHostingView<MascotContent>
    private let state = MascotAnimationState()
    private var screenObserver: Any?

    /// Visible logical size of the mascot.
    static let mascotSize: CGFloat = 36

    /// Half-width of the area the mascot can roam in. Together with
    /// `mascotSize`, this defines the full window width (2*roam + mascot).
    /// Capped so the WHOLE window stays inside the notch's horizontal
    /// extent (~180pt on M-series) — never covers menu items.
    static let roamHalfWidth: CGFloat = 50

    /// Vertical padding above + below the mascot for bob / peek-out room.
    private static let verticalPadding: CGFloat = 30

    init() {
        hostView = NSHostingView(rootView: MascotContent(state: state))
        let w = Self.mascotSize + Self.roamHalfWidth * 2
        let h = Self.mascotSize + Self.verticalPadding * 2
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
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
    /// notch's bottom edge (= menu bar bottom on a notch Mac), centered
    /// horizontally on the screen. The window's full width (mascot + roam
    /// area) stays strictly inside the notch's horizontal extent.
    private func positionAtNotch() {
        guard let screen = NSScreen.builtIn else { return }
        let frame = screen.frame
        let visible = screen.visibleFrame
        let w = Self.mascotSize + Self.roamHalfWidth * 2
        let h = Self.mascotSize + Self.verticalPadding * 2
        let notchBottom = visible.maxY
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

    /// Trigger an additional bounce on top of the ambient walking behavior.
    func triggerBounce(kind: MascotBounceKind) {
        state.trigger(kind: kind)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

enum MascotBounceKind {
    case attention
    case done
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

/// SwiftUI view rendering the Claude character with an ambient "playing
/// around the notch" behavior loop layered with attention/done bounces.
///
/// **Ambient behavior** (deterministic loop, ~22s cycle): the mascot drifts
/// to the left edge of the roam range, pauses, walks across to the right
/// edge, pauses, walks back. During walks the mascot bobs up/down in a
/// walking gait and tilts forward slightly. During pauses it does a
/// gentle in-place bob.
///
/// **Attention/done bounce**: triggered by `state.bounceTrigger`, adds a
/// downward springy peek-out + rotation wobble on top of the ambient motion.
struct MascotContent: View {
    @State var state: MascotAnimationState

    @State private var bounceOffset: CGFloat = 0
    @State private var bounceRotation: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let pose = ambientPose(at: elapsed)

            Image("ClaudeLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: MascotWindow.mascotSize, height: MascotWindow.mascotSize)
                .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 2)
                .offset(x: pose.x, y: pose.y + bounceOffset)
                .rotationEffect(.degrees(pose.rotation + bounceRotation))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onChange(of: state.bounceTrigger) { _, _ in
            runBounce(kind: state.currentKind)
        }
    }

    /// Compute the ambient (idle / walking) pose at a given absolute time.
    /// Returns x/y offsets (relative to the SwiftUI Image's natural center)
    /// and a rotation in degrees.
    private func ambientPose(at t: TimeInterval) -> (x: CGFloat, y: CGFloat, rotation: Double) {
        let cycleDuration: Double = 22.0
        let cycle = t.truncatingRemainder(dividingBy: cycleDuration)
        let roam = MascotWindow.roamHalfWidth

        // Segments of the loop (durations sum to cycleDuration):
        //   0.0  - 4.0  : idle in CENTER          (4s)
        //   4.0  - 7.0  : walk CENTER -> LEFT      (3s)
        //   7.0  - 10.0 : idle at LEFT             (3s)
        //  10.0 - 14.0  : walk LEFT -> RIGHT       (4s, crosses center)
        //  14.0 - 17.0  : idle at RIGHT            (3s)
        //  17.0 - 20.0  : walk RIGHT -> CENTER     (3s)
        //  20.0 - 22.0  : idle in CENTER (settle)  (2s)

        let baseX: CGFloat
        let walking: Bool
        let walkDir: CGFloat   // -1 = moving left, +1 = right, 0 = idle

        switch cycle {
        case 0..<4:
            baseX = 0; walking = false; walkDir = 0
        case 4..<7:
            let f = (cycle - 4) / 3
            baseX = -roam * smoothstep(f); walking = true; walkDir = -1
        case 7..<10:
            baseX = -roam; walking = false; walkDir = 0
        case 10..<14:
            let f = (cycle - 10) / 4
            baseX = -roam + (2 * roam) * smoothstep(f); walking = true; walkDir = +1
        case 14..<17:
            baseX = roam; walking = false; walkDir = 0
        case 17..<20:
            let f = (cycle - 17) / 3
            baseX = roam * (1 - smoothstep(f)); walking = true; walkDir = -1
        default:
            baseX = 0; walking = false; walkDir = 0
        }

        // Idle: gentle ±1.5pt bob, ±1.0° wobble
        let idleY = sin(t * 2 * .pi / 2.4) * 1.5
        let idleRot = sin(t * 2 * .pi / 3.8) * 1.0

        // Walking gait: a faster, more pronounced bob (±3pt) + lean ±5°
        // toward the walking direction
        let gaitY = walking ? sin(t * 2 * .pi / 0.55) * 3.0 : 0
        let gaitRot = walking ? Double(walkDir) * 5.0 : 0

        return (
            x: baseX,
            y: idleY + gaitY,
            rotation: idleRot + gaitRot
        )
    }

    /// Smooth ease in/out for the walk segments — start slow, accelerate in
    /// the middle, decelerate at the end. Keeps the motion from feeling robotic.
    private func smoothstep(_ x: Double) -> CGFloat {
        let clamped = max(0, min(1, x))
        return CGFloat(clamped * clamped * (3 - 2 * clamped))
    }

    /// Peek-out bounce layered on top of the ambient walking pose.
    private func runBounce(kind: MascotBounceKind) {
        bounceOffset = 0
        bounceRotation = 0

        let bounces: Int = (kind == .attention) ? 3 : 2
        let peakHeight: CGFloat = (kind == .attention) ? 12 : 8
        let perBounce: Double = (kind == .attention) ? 0.34 : 0.40
        let wobbleDeg: Double = (kind == .attention) ? 6 : 4

        for i in 0..<bounces {
            let start = Double(i) * perBounce
            let down = perBounce * 0.45
            DispatchQueue.main.asyncAfter(deadline: .now() + start) {
                withAnimation(.spring(response: 0.20, dampingFraction: 0.55)) {
                    bounceOffset = peakHeight    // downward — more visible below the notch
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

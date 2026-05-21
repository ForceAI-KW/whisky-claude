import AppKit
import SwiftUI

/// Always-visible floating panel hosting the Claude character. Choreography:
///   - Mascot sits on the LEFT side of the notch, dancing in place for ~1min
///   - Walks down + across to the RIGHT side
///   - Sits there dancing for ~1min
///   - Walks back to the LEFT
///   - Repeat
///
/// The window spans wider than the notch so the mascot can roam to the left
/// and right edges. Vertically, the mascot stays at or below the notch's
/// bottom edge so it never covers menu items in any horizontal position.
///
/// On attention/done events, an additional peek-out + rotation wobble is
/// layered on top of the ambient choreography.
final class MascotWindow: NSPanel {
    private let hostView: NSHostingView<MascotContent>
    private let state = MascotAnimationState()
    private var screenObserver: Any?

    /// Visible logical size of the mascot.
    static let mascotSize: CGFloat = 36

    /// How far left or right of center the mascot can roam. Big enough to
    /// clearly position it BESIDE the notch (notch is ~180pt wide, so a
    /// ~140pt offset places the mascot just past the notch's left/right edge).
    /// Mascot is always vertically BELOW the menu bar so the wider range
    /// doesn't cover menu items.
    static let roamHalfWidth: CGFloat = 140

    /// Vertical padding above + below the mascot inside the window.
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

    /// Position the window so the mascot's TOP edge sits right at the notch's
    /// bottom edge (= menu bar bottom on a notch Mac), centered horizontally.
    /// The window extends roamHalfWidth to each side from screen midX so the
    /// mascot can roam between the notch's LEFT and RIGHT outside edges while
    /// staying vertically below the menu bar (never covering menu items).
    private func positionAtNotch() {
        guard let screen = NSScreen.builtIn else { return }
        let frame = screen.frame
        let visible = screen.visibleFrame
        let w = Self.mascotSize + Self.roamHalfWidth * 2
        let h = Self.mascotSize + Self.verticalPadding * 2
        let notchBottom = visible.maxY
        let mascotCenterY = notchBottom - Self.mascotSize / 2
        let y = mascotCenterY - h / 2
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

    /// Trigger an additional bounce on top of the ambient choreography.
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

/// SwiftUI view rendering the Claude character with the side-to-side
/// choreography:
///   - 60s dance at LEFT side of notch
///   - 8s walk LEFT → RIGHT
///   - 60s dance at RIGHT side of notch
///   - 8s walk RIGHT → LEFT
///   - Repeat
///
/// "Dancing" = bigger bob + rotation wobble + occasional little hops in place.
/// "Walking" = horizontal travel with a footstep gait + lean toward direction.
///
/// Attention/done events layer a downward springy peek-out on top of either
/// motion state.
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

    /// Cycle constants (sum to cycleDuration).
    /// User wanted "1 minute" dancing on each side — that's 60s each.
    private static let danceDuration: Double = 60.0
    private static let walkDuration: Double = 8.0
    private static let cycleDuration: Double = (danceDuration + walkDuration) * 2.0  // 136s

    /// Compute the ambient pose at a given absolute time. Returns x/y offsets
    /// and a rotation angle in degrees.
    private func ambientPose(at t: TimeInterval) -> (x: CGFloat, y: CGFloat, rotation: Double) {
        let cycle = t.truncatingRemainder(dividingBy: Self.cycleDuration)
        let roam = MascotWindow.roamHalfWidth

        // Segment boundaries
        let s1 = Self.danceDuration                  // 60  — finish dancing LEFT
        let s2 = s1 + Self.walkDuration              // 68  — finish walking LEFT -> RIGHT
        let s3 = s2 + Self.danceDuration             // 128 — finish dancing RIGHT
        // s4 = cycleDuration                        // 136 — finish walking RIGHT -> LEFT

        let baseX: CGFloat
        let dancing: Bool
        let walking: Bool
        let walkDir: CGFloat   // -1 left, +1 right, 0 stationary

        if cycle < s1 {
            // Dance at LEFT side of notch
            baseX = -roam
            dancing = true; walking = false; walkDir = 0
        } else if cycle < s2 {
            // Walk LEFT -> RIGHT
            let f = (cycle - s1) / Self.walkDuration
            baseX = -roam + (2 * roam) * smoothstep(f)
            dancing = false; walking = true; walkDir = +1
        } else if cycle < s3 {
            // Dance at RIGHT side of notch
            baseX = roam
            dancing = true; walking = false; walkDir = 0
        } else {
            // Walk RIGHT -> LEFT
            let f = (cycle - s3) / Self.walkDuration
            baseX = roam - (2 * roam) * smoothstep(f)
            dancing = false; walking = true; walkDir = -1
        }

        // Gentle base bob (always present, downward-only so the top edge
        // never crosses into the clipped notch zone)
        let baseBobY = (1.0 + sin(t * 2 * .pi / 2.4)) * 1.0   // 0..+2
        let baseRot = sin(t * 2 * .pi / 3.8) * 1.0

        // Dancing: bigger amplitude bob + rotation + an occasional hop in place
        let danceBobY: CGFloat = dancing ? (1.0 + sin(t * 2 * .pi / 0.9)) * 2.5 : 0   // 0..+5
        let danceRot: Double  = dancing ? sin(t * 2 * .pi / 1.3) * 7.0 : 0            // ±7°
        // Occasional hop — every 5s, brief 0.4s downward hop
        let hopY: CGFloat
        if dancing {
            let hopCycle = 5.0
            let hopPos = t.truncatingRemainder(dividingBy: hopCycle)
            hopY = hopPos < 0.4 ? sin((hopPos / 0.4) * .pi) * 6.0 : 0   // 0..+6 then 0
        } else {
            hopY = 0
        }

        // Walking gait: footstep cadence bob (0..+3) + lean toward direction
        let gaitY: CGFloat = walking ? (1.0 + sin(t * 2 * .pi / 0.55)) * 1.5 : 0
        let gaitRot = walking ? Double(walkDir) * 5.0 : 0

        return (
            x: baseX,
            y: baseBobY + danceBobY + hopY + gaitY,
            rotation: baseRot + danceRot + gaitRot
        )
    }

    /// Smooth ease in/out for the walk segments.
    private func smoothstep(_ x: Double) -> CGFloat {
        let clamped = max(0, min(1, x))
        return CGFloat(clamped * clamped * (3 - 2 * clamped))
    }

    /// Peek-out bounce layered on top of the ambient choreography (attention/done).
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
                    bounceOffset = peakHeight
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
    static var builtIn: NSScreen? {
        screens.first { screen in
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            return CGDisplayIsBuiltin(id) != 0
        } ?? main
    }
}

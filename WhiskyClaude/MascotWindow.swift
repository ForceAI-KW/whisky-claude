import AppKit
import SwiftUI

/// Always-visible floating panel hosting the Claude character. The mascot is
/// SEATED beside the notch (left edge or right edge), grounded — its top
/// edge is anchored to the menu bar's bottom so it looks like it's sitting
/// on a ledge rather than floating in mid-air.
///
/// Choreography (~136s loop):
///   0   - 60s  : seated at LEFT side of notch, dancing (shimmy)
///   60  - 68s  : walk LEFT → RIGHT with real footstep gait + duck under notch
///   68  - 128s : seated at RIGHT side of notch, dancing (shimmy)
///   128 - 136s : walk RIGHT → LEFT
///   repeat
///
/// Dance is HORIZONTAL shimmy + rotation wobble — no vertical bouncing (per
/// user request). Walking has footstep impact dips. Resting between beats has
/// a barely-perceptible breathing scale pulse so the mascot doesn't look frozen.
///
/// Positions are derived from the live notch geometry via
/// `NSScreen.builtIn.auxiliaryTopLeftArea/auxiliaryTopRightArea` — never guessed.
final class MascotWindow: NSPanel {
    private let hostView: NSHostingView<MascotContent>
    private let state = MascotAnimationState()
    private var screenObserver: Any?

    /// Visible logical size of the mascot.
    static let mascotSize: CGFloat = 32

    /// Gap between the notch's left/right edge and the mascot when seated.
    /// Small but non-zero so the mascot doesn't look glued to the notch.
    static let seatGap: CGFloat = 6

    /// Vertical padding inside the window for the dancing shimmy / walking
    /// gait to render without clipping. Kept tight.
    private static let verticalPadding: CGFloat = 20

    /// Computed at init from live screen measurements — distance from screen
    /// center to each "seat" position. Bigger than half the notch width.
    private var seatHalfWidth: CGFloat = 140

    init() {
        hostView = NSHostingView(rootView: MascotContent(state: state))

        // Compute the window width to accommodate the measured seat positions.
        let initialSeatHalf = Self.measureSeatHalfWidth()
        let w = Self.mascotSize + initialSeatHalf * 2 + 20   // 20pt slack for shimmy
        let h = Self.mascotSize + Self.verticalPadding * 2

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        self.seatHalfWidth = initialSeatHalf

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

        // Hand the live seat distance to the SwiftUI content so its motion
        // ranges line up with the measured screen geometry.
        state.seatHalfWidth = initialSeatHalf

        positionAtNotch()
        observeScreenChanges()
        applyVisibility(SettingsManager.shared.mascotVisible)
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Measure how far from screen center each seat position should be.
    /// Reads the live notch dimensions; falls back to a sensible default
    /// for Macs without a notch.
    private static func measureSeatHalfWidth() -> CGFloat {
        guard let screen = NSScreen.builtIn,
              let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else {
            return 110   // sensible default for older Macs
        }
        let notchLeftEdge = leftArea.maxX
        let notchRightEdge = rightArea.minX
        let screenMidX = screen.frame.midX
        // Distance from screen midX to each notch edge.
        let halfNotchWidth = (notchRightEdge - notchLeftEdge) / 2
        // Seat positions: just past the notch edge + the mascot's own half-width + the gap.
        return halfNotchWidth + mascotSize / 2 + seatGap
    }

    /// Position the window centered on screen midX with the mascot's top
    /// edge anchored to the menu bar's bottom — gives a "sitting on a ledge"
    /// look instead of floating in mid-air.
    private func positionAtNotch() {
        guard let screen = NSScreen.builtIn else { return }
        let frame = screen.frame
        let visible = screen.visibleFrame

        // Refresh the measured seat distance (screen reconfig may have changed it).
        let seatHalf = Self.measureSeatHalfWidth()
        self.seatHalfWidth = seatHalf
        state.seatHalfWidth = seatHalf

        let w = Self.mascotSize + seatHalf * 2 + 20
        let h = Self.mascotSize + Self.verticalPadding * 2
        let notchBottom = visible.maxY
        // Mascot center y: mascotSize/2 below the menu bar bottom so the
        // mascot's TOP touches the menu bar bottom exactly.
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

    func applyVisibility(_ visible: Bool) {
        if visible {
            positionAtNotch()
            orderFrontRegardless()
        } else {
            orderOut(nil)
        }
    }

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

/// State observed by the SwiftUI content. Carries the live seat-half-width
/// so the SwiftUI motion math always matches the measured geometry.
@Observable
final class MascotAnimationState {
    var bounceTrigger: Int = 0
    var currentKind: MascotBounceKind = .attention
    var seatHalfWidth: CGFloat = 140

    func trigger(kind: MascotBounceKind) {
        currentKind = kind
        bounceTrigger += 1
    }
}

/// SwiftUI view rendering the Claude character with grounded, realistic
/// motion. Three ambient states drive the loop: DANCING, WALKING, and brief
/// SETTLE transitions. No vertical bouncing during dance (per spec — dance
/// is horizontal shimmy + rotation + breathing scale). Footstep dips ground
/// the walk. Tiny breathing scale at all times so the mascot is never frozen.
struct MascotContent: View {
    @State var state: MascotAnimationState

    /// Layered attention/done bounce offset + rotation. Set by `runBounce`.
    @State private var bounceOffset: CGFloat = 0
    @State private var bounceRotation: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let pose = ambientPose(at: elapsed)

            Image("ClaudeLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: MascotWindow.mascotSize, height: MascotWindow.mascotSize)
                .scaleEffect(pose.scale)
                // Heavier shadow so the mascot reads as "sitting on" the menu
                // bar's bottom edge instead of floating.
                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)
                .offset(x: pose.x, y: pose.y + bounceOffset)
                .rotationEffect(.degrees(pose.rotation + bounceRotation))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onChange(of: state.bounceTrigger) { _, _ in
            runBounce(kind: state.currentKind)
        }
    }

    // MARK: - Choreography

    /// User wanted "1 minute dancing on each side".
    private static let danceDuration: Double = 60.0
    private static let walkDuration: Double = 8.0
    private static let cycleDuration: Double = (danceDuration + walkDuration) * 2.0   // 136s

    /// Compute the ambient pose at a given absolute time. Returns x/y/scale/rotation
    /// in the window's local coordinate space.
    private func ambientPose(at t: TimeInterval) -> (x: CGFloat, y: CGFloat, scale: CGFloat, rotation: Double) {
        let cycle = t.truncatingRemainder(dividingBy: Self.cycleDuration)
        let seat = state.seatHalfWidth

        let s1 = Self.danceDuration                  //  60  end dance LEFT
        let s2 = s1 + Self.walkDuration              //  68  end walk LEFT -> RIGHT
        let s3 = s2 + Self.danceDuration             // 128  end dance RIGHT

        // Universal breathing scale — barely perceptible (1.0 .. 1.018) at
        // a slow 3.5s cycle. Keeps the mascot alive even when "still".
        let breathScale: CGFloat = 1.0 + (1.0 + CGFloat(sin(t * 2 * .pi / 3.5))) * 0.009

        if cycle < s1 {
            // DANCE LEFT
            let danceX = sin(t * 2 * .pi * 3.5) * 3.0          // 3.5 Hz, ±3pt horizontal shimmy
            let danceRot = sin(t * 2 * .pi * 2.0) * 9.0        // 2 Hz, ±9° rotation wobble
            // Tiny secondary jitter in rotation to break the perfectly periodic feel
            let microRot = sin(t * 2 * .pi * 7.3) * 2.0        // 7.3 Hz, ±2° flutter
            // Scale "drop" on the beat — 1 Hz pulse: 1.0 .. 1.05
            let beatScale: CGFloat = 1.0 + max(0, CGFloat(sin(t * 2 * .pi * 1.0))) * 0.05
            return (
                x: -seat + danceX,
                y: 0,
                scale: breathScale * beatScale,
                rotation: danceRot + microRot
            )
        } else if cycle < s2 {
            // WALK LEFT -> RIGHT
            let f = (cycle - s1) / Self.walkDuration           // 0..1
            let easedF = smoothstep(f)
            let baseX = -seat + (2 * seat) * easedF

            // Footstep: brief downward dip + slight bob per step (1.6 Hz = ~brisk pace)
            let stepPhase = (t * 1.6).truncatingRemainder(dividingBy: 1.0)
            // Impact bob: down 2pt at the first 35% of each step, then back
            let footstep: CGFloat = stepPhase < 0.35
                ? sin(stepPhase / 0.35 * .pi) * 2.0
                : 0
            // Lean forward in walking direction
            let lean = 5.0   // +5° leaning right
            // Mascot dips under the notch as it passes through the middle —
            // brief vertical dip + scale-down so it looks like it's ducking.
            let middleDist = abs(baseX) / seat   // 1 at edges, 0 at center
            let duckScale: CGFloat = 1.0 - (1.0 - CGFloat(middleDist)) * 0.08
            let duckY: CGFloat = (1.0 - CGFloat(middleDist)) * 1.5
            return (
                x: baseX,
                y: footstep + duckY,
                scale: breathScale * duckScale,
                rotation: lean
            )
        } else if cycle < s3 {
            // DANCE RIGHT — same as LEFT but mirrored
            let danceX = sin(t * 2 * .pi * 3.5) * 3.0
            let danceRot = sin(t * 2 * .pi * 2.0) * 9.0
            let microRot = sin(t * 2 * .pi * 7.3) * 2.0
            let beatScale: CGFloat = 1.0 + max(0, CGFloat(sin(t * 2 * .pi * 1.0))) * 0.05
            return (
                x: seat + danceX,
                y: 0,
                scale: breathScale * beatScale,
                rotation: danceRot + microRot
            )
        } else {
            // WALK RIGHT -> LEFT
            let f = (cycle - s3) / Self.walkDuration
            let easedF = smoothstep(f)
            let baseX = seat - (2 * seat) * easedF

            let stepPhase = (t * 1.6).truncatingRemainder(dividingBy: 1.0)
            let footstep: CGFloat = stepPhase < 0.35
                ? sin(stepPhase / 0.35 * .pi) * 2.0
                : 0
            let lean = -5.0   // leaning left
            let middleDist = abs(baseX) / seat
            let duckScale: CGFloat = 1.0 - (1.0 - CGFloat(middleDist)) * 0.08
            let duckY: CGFloat = (1.0 - CGFloat(middleDist)) * 1.5
            return (
                x: baseX,
                y: footstep + duckY,
                scale: breathScale * duckScale,
                rotation: lean
            )
        }
    }

    /// Cubic smoothstep ease in/out for walk transitions.
    private func smoothstep(_ x: Double) -> CGFloat {
        let clamped = max(0, min(1, x))
        return CGFloat(clamped * clamped * (3 - 2 * clamped))
    }

    /// Attention/done peek-out — bigger downward dip + rotation wobble layered
    /// on top of the ambient choreography. Always goes DOWN (more visible),
    /// never UP (would clip into the notch's no-display zone).
    private func runBounce(kind: MascotBounceKind) {
        bounceOffset = 0
        bounceRotation = 0

        let bounces: Int = (kind == .attention) ? 3 : 2
        let peakHeight: CGFloat = (kind == .attention) ? 14 : 9
        let perBounce: Double = (kind == .attention) ? 0.32 : 0.38
        let wobbleDeg: Double = (kind == .attention) ? 8 : 5

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
    /// Returns the built-in display (the one with the notch), or main as fallback.
    static var builtIn: NSScreen? {
        screens.first { screen in
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
            return CGDisplayIsBuiltin(id) != 0
        } ?? main
    }
}

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

    /// Visible logical size of the mascot. Matches the original icon footprint.
    static let mascotSize: CGFloat = 32

    /// Clear gap between the notch's left/right edge and the mascot when
    /// seated. Big enough that the mascot reads as "beside the notch", not
    /// "hugging the notch's corner".
    static let seatGap: CGFloat = 50

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

    /// Switch Clawd's animation pool to match the live Claude Code state
    /// (idle / working / waitingForInput / taskCompleted).
    func setAttention(_ kind: AttentionKind) {
        state.currentAttention = kind
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
    /// Live Claude Code state — drives which Clawd animation pool plays.
    var currentAttention: AttentionKind = .idle

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

    /// Layered attention/done bounce offset + rotation + scale. Set by `runBounce`.
    @State private var bounceOffset: CGFloat = 0
    @State private var bounceRotation: Double = 0
    @State private var bounceScale: CGFloat = 1.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let pose = ambientPose(at: elapsed)
            // Clawd animation chosen by live Claude Code state, cycling through
            // each state's pool over time so it rotates through its repertoire.
            let gif = ClawdPose.name(for: state.currentAttention, at: elapsed)

            ClawdGIFView(name: gif)
                .frame(width: MascotWindow.mascotSize, height: MascotWindow.mascotSize)
                .clipped()
                .scaleEffect(pose.scale * bounceScale)
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
            // DANCE LEFT — calm Trump-style head nod + body sway.
            // Two slow sine waves at slightly different frequencies so the
            // body sway and head nod drift in and out of phase, producing
            // an organic, never-quite-repeating sway. NO vertical bouncing,
            // NO rapid shake — paced like someone swaying gently to music.
            let sway = sin(t * 2 * .pi * 0.55) * 2.5           // 0.55 Hz, ±2.5pt
            let nod  = sin(t * 2 * .pi * 0.45) * 4.5           // 0.45 Hz, ±4.5°
            // Slight emphasis on each beat (~2s per beat) — barely visible scale tick.
            let beatScale: CGFloat = 1.0 + max(0, CGFloat(sin(t * 2 * .pi * 0.5))) * 0.025
            return (
                x: -seat + sway,
                y: 0,
                scale: breathScale * beatScale,
                rotation: nod
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
            // DANCE RIGHT — same calm sway as LEFT, mirrored seat position.
            let sway = sin(t * 2 * .pi * 0.55) * 2.5
            let nod  = sin(t * 2 * .pi * 0.45) * 4.5
            let beatScale: CGFloat = 1.0 + max(0, CGFloat(sin(t * 2 * .pi * 0.5))) * 0.025
            return (
                x: seat + sway,
                y: 0,
                scale: breathScale * beatScale,
                rotation: nod
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

    /// Attention/done "freak out" — DRAMATIC layered animation designed to
    /// grab attention. Combines a big downward peek, full rotation spin, and
    /// a scale-pop. Overrides the ambient choreography's offsets via the
    /// shared bounceOffset/bounceRotation channels.
    ///
    /// Attention = wilder: 3 jumps + full 360° spin + big scale pulses
    /// Done      = calmer celebration: 2 jumps + half-spin + smaller pulse
    private func runBounce(kind: MascotBounceKind) {
        bounceOffset = 0
        bounceRotation = 0
        bounceScale = 1.0

        let isAttention = (kind == .attention)
        let bounces: Int = isAttention ? 3 : 2
        let peakHeight: CGFloat = isAttention ? 22 : 14
        let perBounce: Double = isAttention ? 0.34 : 0.40
        let popScale: CGFloat = isAttention ? 1.45 : 1.25
        // Total rotation across all bounces — full 360° for attention,
        // half-rotation for done.
        let totalRotation: Double = isAttention ? 360.0 : 180.0

        for i in 0..<bounces {
            let start = Double(i) * perBounce
            let down = perBounce * 0.45

            // Mid-air: peak height + scale pop + cumulative rotation
            DispatchQueue.main.asyncAfter(deadline: .now() + start) {
                withAnimation(.spring(response: 0.20, dampingFraction: 0.55)) {
                    bounceOffset = peakHeight
                    bounceScale = popScale
                    // Distribute the total rotation across the bounces so the
                    // final landing has the character right-side-up again.
                    bounceRotation = totalRotation * Double(i + 1) / Double(bounces)
                }
            }
            // Landing: snap back to baseline
            DispatchQueue.main.asyncAfter(deadline: .now() + start + down) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.55)) {
                    bounceOffset = 0
                    bounceScale = 1.0
                    // Only reset rotation on the FINAL landing so the spin
                    // looks continuous across bounces.
                    if i == bounces - 1 {
                        bounceRotation = 0
                    }
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

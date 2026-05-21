import Foundation
import IOKit
import IOKit.pwr_mgt

/// Holds an IOPMAssertion that keeps the Mac (and optionally the display)
/// awake while Whisky Claude is running. Granular enough that the user can
/// toggle it on/off live via Settings without restarting the app.
///
/// Uses `kIOPMAssertPreventUserIdleSystemSleep` — prevents the system from
/// sleeping due to user inactivity. Display sleep + manual `caffeinate`-style
/// commands are not blocked; only the timer-based idle sleep is held off.
/// Releasing the assertion (or quitting the app) restores normal sleep.
final class SleepBlocker {
    static let shared = SleepBlocker()

    private var assertionID: IOPMAssertionID = 0
    private var isActive = false
    private let reason = "Whisky Claude is running" as CFString

    private init() {}

    /// Start preventing system idle sleep. Idempotent.
    func start() {
        guard !isActive else { return }
        let ret = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        if ret == kIOReturnSuccess {
            isActive = true
            NSLog("[WhiskyClaude] SleepBlocker started — system idle sleep prevented")
        } else {
            NSLog("[WhiskyClaude] SleepBlocker: IOPMAssertionCreate failed: \(ret)")
        }
    }

    /// Release the assertion. Mac returns to normal sleep behavior.
    func stop() {
        guard isActive else { return }
        let ret = IOPMAssertionRelease(assertionID)
        if ret == kIOReturnSuccess {
            NSLog("[WhiskyClaude] SleepBlocker stopped")
        } else {
            NSLog("[WhiskyClaude] SleepBlocker: IOPMAssertionRelease failed: \(ret)")
        }
        isActive = false
        assertionID = 0
    }

    /// Apply the current SettingsManager value. Called from the settings
    /// toggle's `didSet` and from AppDelegate at launch.
    func applySetting(_ enabled: Bool) {
        if enabled {
            start()
        } else {
            stop()
        }
    }
}

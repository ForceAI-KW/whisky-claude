import AppKit
import ApplicationServices
import Foundation
import Sparkle

/// Bridges the SwiftUI Settings "Automatically check for updates" toggle to the
/// live Sparkle updater (which AppDelegate owns). The updater itself persists
/// the preference; this just exposes a get/set the Toggle can bind to.
final class SUUpdaterBridge {
    static let shared = SUUpdaterBridge()
    weak var updater: SPUUpdater?
    var autoCheck: Bool {
        get { updater?.automaticallyChecksForUpdates ?? true }
        set { updater?.automaticallyChecksForUpdates = newValue }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menuBarIcon: MenuBarIcon!
    private var mascotWindow: MascotWindow!

    /// Sparkle updater — automatic background checks + the "Check for Updates…"
    /// menu item. `startingUpdater: true` begins the scheduled-check timer.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var statusObserver: Any?

    /// Last time `openClaudeInTerminal` actually fired. Used to debounce
    /// rapid re-triggers from the slap / wake-word / menu paths so two
    /// slaps or three "hey whisky"s only open ONE Terminal session.
    private var lastOpenedAt: CFTimeInterval = 0
    private let openDebounceInterval: CFTimeInterval = 5.0

    /// One-shot guard so the missing-Accessibility alert only fires once
    /// per launch (the trigger callbacks can fire many times in a row).
    private var didShowAccessibilityAlert = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[WhiskyClaude] launched")

        #if DEBUG
        StealthDecoderSelfCheck.run()
        #endif

        // Expose the Sparkle updater to the Settings "Automatically check for
        // updates" toggle via the bridge.
        SUUpdaterBridge.shared.updater = updaterController.updater

        // 1. Menu bar icon + dropdown
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menuBarIcon = MenuBarIcon(statusItem: statusItem)
        statusItem.menu = buildMenu()

        // 1b. Floating mascot window (shows on attention/done, hidden at idle)
        mascotWindow = MascotWindow()

        // 2. External Claude Code hook event watcher
        EventWatcher.shared.start()

        // 3. React to state changes — animate icon + play sound
        statusObserver = NotificationCenter.default.addObserver(
            forName: .WhiskyClaudeNotchStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let kind = AttentionState.shared.current
            NSLog("[WhiskyClaude] state observer fired, kind=\(kind)")
            self?.menuBarIcon.onStateChange(kind)
            // Switch Clawd's animation pool to match the live state.
            self?.mascotWindow.setAttention(kind)
            // Sounds: attention → "waitingForInput", done → "taskCompleted".
            // Same MP3 filenames Notchy used so we don't have to rename assets.
            switch kind {
            case .waitingForInput:  SoundPlayer.shared.play("waitingForInput")
            case .taskCompleted:    SoundPlayer.shared.play("taskCompleted")
            case .working, .idle:   break
            }
            // Persistent mascot now runs idle animation forever; just trigger a bigger
            // bounce overlay on attention/done.
            switch kind {
            case .waitingForInput:
                self?.mascotWindow.triggerBounce(kind: .attention)
            case .taskCompleted:
                self?.mascotWindow.triggerBounce(kind: .done)
            case .working, .idle:
                break
            }
        }

        // React to mascot visibility setting changes.
        NotificationCenter.default.addObserver(
            forName: .WhiskyClaudeMascotVisibilityChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.mascotWindow.applyVisibility(SettingsManager.shared.mascotVisible)
        }

        // 4. Clap detector (opt-in via Settings)
        ClapDetector.shared.setSensitivity(SettingsManager.shared.clapSensitivity)
        ClapDetector.shared.onDoubleClap = { [weak self] in self?.openClaudeInTerminal() }
        if SettingsManager.shared.clapTriggerEnabled {
            ClapDetector.shared.start()
        }

        // 5. Wake-word recognizer (opt-in via Settings)
        KeywordRecognizer.shared.onWakeWord = { [weak self] in self?.openClaudeInTerminal() }
        if SettingsManager.shared.wakeWordEnabled {
            KeywordRecognizer.shared.start()
        }

        // 6. Hold off system idle sleep (default ON via Settings).
        SleepBlocker.shared.applySetting(SettingsManager.shared.preventSleep)

        // 7. Log Accessibility-trust state so the diagnostic shows up in
        // Console.app right after launch — useful for forkers who haven't
        // granted the permission yet. The actual prompt is deferred to the
        // first Open-in-Terminal attempt so users don't get pestered if
        // they never use that path.
        NSLog("[WhiskyClaude] AXIsProcessTrusted=\(AXIsProcessTrusted())")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Release the sleep assertion explicitly. IOKit cleans up on process
        // exit anyway, but doing it here is hygienic and makes the log clearer.
        SleepBlocker.shared.stop()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open Claude in Terminal", action: #selector(openClaudeInTerminalAction), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        // Stealth typing / privacy mode: decode Arabic-layout gibberish (typed
        // with the Arabic keyboard switched on so a shoulder-surfer sees
        // nonsense) back to English, in place, on the clipboard.
        let decodeStealthItem = NSMenuItem(title: "Decode Stealth Clipboard", action: #selector(decodeStealthClipboardAction), keyEquivalent: "d")
        decodeStealthItem.keyEquivalentModifierMask = [.command, .option]
        decodeStealthItem.target = self
        menu.addItem(decodeStealthItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let updatesItem = NSMenuItem(title: "Check for Updates\u{2026}", action: #selector(checkForUpdatesAction(_:)), keyEquivalent: "")
        updatesItem.target = self
        menu.addItem(updatesItem)

        menu.addItem(NSMenuItem.separator())

        // Quit must target NSApp (not self) so #selector resolves to
        // NSApplication.terminate(_:). Setting `target = self` on the loop
        // below broke this — AppDelegate has no terminate(_:) method, so
        // the action silently failed and clicking 'Quit' did nothing.
        let quitItem = NSMenuItem(title: "Quit Whisky Claude", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        return menu
    }

    @objc private func checkForUpdatesAction(_ sender: Any?) {
        updaterController.checkForUpdates(sender)
    }

    @objc private func openClaudeInTerminalAction() {
        // Explicit menu click — user definitely meant it, skip debounce.
        openClaudeInTerminal(debounced: false)
    }

    /// Reads the clipboard, decodes Arabic-layout "stealth typing" gibberish
    /// back to English (see StealthDecoder), and writes the result back to
    /// the clipboard in place. No-ops silently if the clipboard has no text.
    @objc private func decodeStealthClipboardAction() {
        let pb = NSPasteboard.general
        guard let text = pb.string(forType: .string), !text.isEmpty else {
            NSLog("[WhiskyClaude] Decode Stealth Clipboard — clipboard has no text, nothing to decode")
            NSSound.beep()
            return
        }

        let decoded = StealthDecoder.decode(text)
        pb.clearContents()
        pb.setString(decoded, forType: .string)
        NSLog("[WhiskyClaude] Decode Stealth Clipboard — clipboard updated")

        // Reuse existing feedback so this doesn't need its own UI: the
        // "task completed" cue sound plus a mascot bounce.
        SoundPlayer.shared.play("taskCompleted")
        mascotWindow.triggerBounce(kind: .done)
    }

    /// Opens Terminal.app and runs `claude` in the user's home directory.
    ///
    /// - Parameter debounced: when true (default — used by slap + wake-word
    ///   callbacks), re-entry within `openDebounceInterval` is silently
    ///   dropped so two slaps or three "hey whisky"s only open ONE session.
    ///   When false (menu-click path), every call opens a fresh session
    ///   because the user explicitly asked for one — no debounce needed.
    func openClaudeInTerminal(debounced: Bool = true) {
        if debounced {
            let now = CACurrentMediaTime()
            if now - lastOpenedAt < openDebounceInterval {
                NSLog("[WhiskyClaude] openClaudeInTerminal debounced — fired \(Int(now - lastOpenedAt))s ago")
                return
            }
            lastOpenedAt = now
        } else {
            // Still record the timestamp so a subsequent slap/wake-word right
            // after a manual click is still debounced (avoids surprise double-opens).
            lastOpenedAt = CACurrentMediaTime()
        }

        let home = NSHomeDirectory().replacingOccurrences(of: "\"", with: "\\\"")
        // Raw shell command for the clipboard-paste path (no AppleScript escaping).
        let command = "cd '\(NSHomeDirectory())' && claude"

        // Two AppleScript variants — keystroke path needs Accessibility, plain
        // `do script` path does not. Pick based on whether Terminal already has
        // a window AND whether we have Accessibility trust. If we'd need to
        // keystroke but can't, fall back to opening a new window (so the user
        // still gets a Claude session) AND surface the permission gap via an
        // alert + Settings deep-link, exactly once per launch.
        //
        // Why Accessibility, not Automation: `System Events keystroke` is a
        // keyboard event injection. That's gated by Privacy → Accessibility,
        // a separate TCC bucket from Privacy → Automation (which only covers
        // `tell application "X"` Apple Events). The two are commonly conflated;
        // grant'ing Automation alone does not unlock keystrokes.
        let trusted = AXIsProcessTrusted()
        let useKeystroke = trusted   // only attempt the new-tab path if we can

        // For the new-tab path we inject the command via the CLIPBOARD + Cmd+V
        // sent as PHYSICAL KEY CODES, NOT `keystroke "<string>"`. Two layout traps:
        //   1. `keystroke "cd … && claude"` types each char through the ACTIVE
        //      KEYBOARD LAYOUT → under a non-Latin layout (e.g. Arabic) the Latin
        //      command becomes garbage like `'/ششش/شششش' && ششش`.
        //   2. Even `keystroke "v" using {command down}` fails under Arabic —
        //      System Events can't map the Latin 'v' to a key in that layout, so
        //      no paste fires (verified: file-based test created nothing under
        //      Arabic with `keystroke "v"`, but PASSED with `key code 9`).
        // Fix: physical key codes are layout-independent — `key code 17` (T),
        // `key code 9` (V), `key code 36` (Return) — and paste injects the literal
        // clipboard text. We snapshot + restore the user's clipboard around it.
        let savedClipboard = useKeystroke ? snapshotPasteboard() : nil
        if useKeystroke {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(command, forType: .string)
            // Restore the user's clipboard once the (synchronous) AppleScript has
            // run and Terminal has consumed the paste. Scheduled now so it fires
            // even if executeAndReturnError errors out early.
            if let savedClipboard {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    Self.restorePasteboard(savedClipboard)
                }
            }
        }

        let script: String
        if useKeystroke {
            // New-tab-in-front-window path. (1) Cmd+T (key code 17) opens a new
            // tab in Terminal's frontmost window (it takes keyboard focus).
            // (2) Cmd+V (key code 9) pastes the command into that focused tab.
            // (3) Return (key code 36) runs it. All physical key codes → layout-
            // independent.
            //
            // Why not `do script "cmd" in <window>` / `in selected tab of <window>`:
            // Terminal resolves both to tab 1, not the newly-created tab, so the
            // command leaks into the source tab (verified 2026-05-28).
            //
            // No-window edge case: `do script "cmd"` (no `in` clause) creates a
            // fresh Terminal window AND runs the command in it (layout-safe — no
            // keystrokes), so the clipboard is unused on that branch.
            script = """
            tell application "Terminal" to activate
            delay 0.15
            tell application "Terminal"
                if (count of windows) is 0 then
                    do script "cd '\(home)' && claude"
                else
                    tell application "System Events"
                        tell process "Terminal"
                            key code 17 using {command down}
                            delay 0.35
                            key code 9 using {command down}
                            delay 0.2
                            key code 36
                        end tell
                    end tell
                end if
            end tell
            """
        } else {
            // Degraded path: open a fresh window. Still functional, just not
            // the "new tab in existing window" UX Ahmad wants.
            script = """
            tell application "Terminal"
                activate
                do script "cd '\(home)' && claude"
            end tell
            """
        }

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            NSLog("[WhiskyClaude] failed to create AppleScript")
            showOpenTerminalAlert(title: "Couldn't open Terminal",
                                  message: "Whisky Claude couldn't build the AppleScript that launches Terminal. This is a bug — please file an issue.")
            return
        }
        let result = appleScript.executeAndReturnError(&error)
        if let error {
            NSLog("[WhiskyClaude] AppleScript error: \(error)")
            handleAppleScriptError(error)
            return
        }
        _ = result

        if !trusted && !didShowAccessibilityAlert {
            // The fallback ran successfully (new window opened), but the user
            // asked for a new tab. Tell them once how to upgrade the UX.
            didShowAccessibilityAlert = true
            showAccessibilityAlert()
        }
    }

    /// Deep-copy the current clipboard so we can restore it after a Cmd+V inject.
    /// Preserves every representation (text, rtf, images, …), not just plain text.
    private func snapshotPasteboard() -> [NSPasteboardItem] {
        NSPasteboard.general.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []
    }

    /// Restore a previously snapshotted clipboard.
    private static func restorePasteboard(_ items: [NSPasteboardItem]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if !items.isEmpty { pb.writeObjects(items) }
    }

    /// Inspect an NSAppleScript error and route to the right user-visible message.
    /// Surfaces the silent-failure modes that previously only hit NSLog.
    private func handleAppleScriptError(_ error: NSDictionary) {
        // -1743 = errAEEventNotPermitted (Automation denied for target app)
        // -1719 = errAEAccessorNotFound (window vanished mid-script)
        //  1002 = "not allowed to send keystrokes" (Accessibility denied)
        let code = (error[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
        switch code {
        case 1002:
            if !didShowAccessibilityAlert {
                didShowAccessibilityAlert = true
                showAccessibilityAlert()
            }
        case -1743:
            showOpenTerminalAlert(
                title: "Terminal automation blocked",
                message: "macOS blocked Whisky Claude from automating Terminal.app. Open System Settings → Privacy & Security → Automation and enable 'Terminal' under Whisky Claude.",
                openPanel: "Privacy_Automation")
        default:
            let raw = (error[NSAppleScript.errorMessage] as? String) ?? "Unknown AppleScript error (\(code))."
            showOpenTerminalAlert(title: "Couldn't open Terminal", message: raw)
        }
    }

    /// User-facing alert with a button that deep-links to System Settings →
    /// Privacy & Security → Accessibility so the user can grant the
    /// permission without hunting through Settings.
    private func showAccessibilityAlert() {
        showOpenTerminalAlert(
            title: "Grant Accessibility to open Terminal in a new tab",
            message: """
            Whisky Claude needs Accessibility permission to send Cmd+T to Terminal so it can open a new tab inside your existing window (instead of a fresh window every time).

            Open System Settings → Privacy & Security → Accessibility and enable Whisky Claude. You'll only need to do this once.
            """,
            openPanel: "Privacy_Accessibility")
    }

    /// Generic NSAlert helper with an optional "Open Settings" button.
    /// `openPanel` is the System Settings deep-link anchor (e.g.
    /// `Privacy_Accessibility`, `Privacy_Automation`). nil hides the button.
    private func showOpenTerminalAlert(title: String, message: String, openPanel: String? = nil) {
        // Ensure we're on the main thread — slap/wake-word callbacks can fire
        // off audio queues.
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.showOpenTerminalAlert(title: title, message: message, openPanel: openPanel)
            }
            return
        }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        if openPanel != nil {
            alert.addButton(withTitle: "Open Settings")
        }
        alert.addButton(withTitle: "OK")

        // Bring the alert to the front even though we're an LSUIElement app —
        // otherwise the user might never see it.
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if let openPanel, response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(openPanel)") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func showSettings() {
        SettingsWindowController.shared.show()
    }
}

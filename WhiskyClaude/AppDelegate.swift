import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menuBarIcon: MenuBarIcon!
    private var mascotWindow: MascotWindow!
    private var statusObserver: Any?

    /// Last time `openClaudeInTerminal` actually fired. Used to debounce
    /// rapid re-triggers from the slap / wake-word / menu paths so two
    /// slaps or three "hey whisky"s only open ONE Terminal session.
    private var lastOpenedAt: CFTimeInterval = 0
    private let openDebounceInterval: CFTimeInterval = 5.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[WhiskyClaude] launched")

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

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

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

    @objc private func openClaudeInTerminalAction() {
        openClaudeInTerminal()
    }

    /// Opens Terminal.app and runs `claude` in the user's home directory.
    /// Wired to the menu item, the slap callback, and the wake-word callback.
    /// Debounces re-entry within `openDebounceInterval` so two slaps or
    /// three "hey whisky"s only open ONE session.
    func openClaudeInTerminal() {
        let now = CACurrentMediaTime()
        if now - lastOpenedAt < openDebounceInterval {
            NSLog("[WhiskyClaude] openClaudeInTerminal debounced — fired \(Int(now - lastOpenedAt))s ago")
            return
        }
        lastOpenedAt = now

        let home = NSHomeDirectory().replacingOccurrences(of: "\"", with: "\\\"")
        // If Terminal already has at least one window open, create a NEW TAB
        // inside the front window via Cmd+T then run `claude` in it. Otherwise
        // (no windows) just do a plain `do script`, which opens a fresh window.
        //
        // Terminal.app's AppleScript dictionary has no first-class "new tab in
        // window" command — the standard workaround is to keystroke Cmd+T via
        // System Events, then aim `do script` at the (now-current) front window.
        // This requires the System Events automation permission. We already need
        // it for the Login Item registration in install.sh, so users have
        // typically granted it. If they haven't, the script still falls through
        // to the no-windows branch (a new window) rather than failing silently.
        let script = """
        tell application "Terminal"
            activate
            if (count of windows) is 0 then
                do script "cd '\(home)' && claude"
            else
                tell application "System Events"
                    tell process "Terminal"
                        keystroke "t" using {command down}
                    end tell
                end tell
                delay 0.25
                do script "cd '\(home)' && claude" in window 1
            end if
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            NSLog("[WhiskyClaude] failed to create AppleScript")
            return
        }
        appleScript.executeAndReturnError(&error)
        if let error {
            NSLog("[WhiskyClaude] AppleScript error: \(error)")
        }
    }

    @objc private func showSettings() {
        SettingsWindowController.shared.show()
    }
}

import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menuBarIcon: MenuBarIcon!
    private var statusObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[WhiskyClaude] launched")

        // 1. Menu bar icon + dropdown
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menuBarIcon = MenuBarIcon(statusItem: statusItem)
        statusItem.menu = buildMenu()

        // 2. External Claude Code hook event watcher
        EventWatcher.shared.start()

        // 3. React to state changes — animate icon + play sound
        statusObserver = NotificationCenter.default.addObserver(
            forName: .WhiskyClaudeNotchStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let kind = AttentionState.shared.current
            self?.menuBarIcon.onStateChange(kind)
            // Sounds: attention → "waitingForInput", done → "taskCompleted".
            // Same MP3 filenames Notchy used so we don't have to rename assets.
            switch kind {
            case .waitingForInput:  SoundPlayer.shared.play("waitingForInput")
            case .taskCompleted:    SoundPlayer.shared.play("taskCompleted")
            case .working, .idle:   break
            }
        }

        // 4. Clap detector (opt-in via Settings)
        ClapDetector.shared.setSensitivity(SettingsManager.shared.clapSensitivity)
        ClapDetector.shared.onDoubleClap = { [weak self] in self?.openClaudeInTerminal() }
        if SettingsManager.shared.clapTriggerEnabled {
            ClapDetector.shared.start()
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Claude in Terminal", action: #selector(openClaudeInTerminalAction), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Settings\u{2026}", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit Whisky Claude", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items {
            item.target = self
        }
        return menu
    }

    @objc private func openClaudeInTerminalAction() {
        openClaudeInTerminal()
    }

    /// Opens Terminal.app and runs `claude` in the user's home directory.
    /// Wired to both the menu item and the double-clap callback.
    func openClaudeInTerminal() {
        let home = NSHomeDirectory().replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(home)' && claude"
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

import AppKit
import Foundation

/// In-process uninstaller for Whisky Claude. Walks through every install
/// side-effect and reverses it:
///   1. Remove Claude Code hooks from ~/.claude/settings.json (preserves
///      any non-Whisky hooks the user has configured)
///   2. Delete the pet-event helper at ~/.claude/scripts/wc-event.sh
///   3. Delete the pet-events dir + any leftover events
///   4. Delete the wc-event log + the logs dir if empty
///   5. Remove the macOS Login Item registration
///   6. Release the IOPMAssertion (so the Mac returns to normal sleep)
///   7. Reset Whisky Claude's UserDefaults so a future re-install starts fresh
///   8. Delete /Applications/Whisky Claude.app and quit the process
///
/// All filesystem operations are best-effort — if a step fails (file already
/// gone, permission denied), we log it and continue. The user only sees a
/// single confirmation dialog before the sequence runs, then an info dialog
/// at the end if any step had non-trivial errors.
enum Uninstaller {

    /// Presents an NSAlert confirmation, then runs the uninstall sequence
    /// if the user confirms. Called from Settings > About.
    static func confirmAndUninstall() {
        let alert = NSAlert()
        alert.messageText = "Uninstall Whisky Claude?"
        alert.informativeText = """
        This will:
          • Remove the app from /Applications
          • Remove the Claude Code hooks (Stop / Notification / PreToolUse / UserPromptSubmit)
          • Remove the pet-event helper at ~/.claude/scripts/wc-event.sh
          • Remove the Login Item registration
          • Quit the app

        Your Claude Code installation, settings, and other hooks (if any) are NOT touched.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        // Make Cancel the default to avoid accidental destructive Enter-press.
        alert.buttons[1].keyEquivalent = "\r"
        alert.buttons[0].keyEquivalent = ""

        // Bring the alert to the front (we're an LSUIElement app — no
        // activation by default).
        NSApp.activate(ignoringOtherApps: true)

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        runUninstall()
    }

    /// The actual sequence. Public for testing / scripted use; the normal
    /// entry point is `confirmAndUninstall()`.
    static func runUninstall() {
        var errors: [String] = []

        // 1. Hooks
        do {
            try removeClaudeCodeHooks()
        } catch {
            errors.append("hooks: \(error.localizedDescription)")
        }

        // 2. Helper script
        let helperPath = NSString(string: "~/.claude/scripts/wc-event.sh").expandingTildeInPath
        tryRemove(path: helperPath, label: "helper script", errors: &errors)

        // 3. Pet-events dir
        let petEventsDir = NSString(string: "~/.claude/pet-events").expandingTildeInPath
        tryRemove(path: petEventsDir, label: "pet-events dir", errors: &errors)

        // 4. Log file
        let logFile = NSString(string: "~/.claude/logs/wc-event.log").expandingTildeInPath
        tryRemove(path: logFile, label: "log file", errors: &errors)
        // Remove the logs dir if it's empty (don't touch it if user has other logs)
        let logsDir = NSString(string: "~/.claude/logs").expandingTildeInPath
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: logsDir),
           contents.isEmpty {
            try? FileManager.default.removeItem(atPath: logsDir)
        }

        // 5. Login Item
        removeLoginItem(errors: &errors)

        // 6. Sleep assertion
        SleepBlocker.shared.stop()

        // 7. UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }

        // 8. App bundle + quit
        // Schedule the app-removal + quit on a background task so the user sees
        // a confirmation dialog FIRST, then the app exits cleanly. If we delete
        // the bundle while it's still running, AppKit can get unhappy.
        let appPath = "/Applications/Whisky Claude.app"
        // Show summary BEFORE we exit so user knows what happened.
        showCompletionAlert(errors: errors)

        // Schedule the actual app-removal + termination as the very last act.
        // Async on main so the alert dismisses fully before the process exits.
        DispatchQueue.main.async {
            // rm -rf in shell — Foundation's removeItem on the running app's
            // own bundle works on macOS (the binary is mmapped but the dir
            // entries can be unlinked).
            do {
                try FileManager.default.removeItem(atPath: appPath)
                NSLog("[WhiskyClaude] removed \(appPath)")
            } catch {
                NSLog("[WhiskyClaude] failed to remove \(appPath): \(error)")
            }
            NSApp.terminate(nil)
        }
    }

    // MARK: - Step helpers

    /// Remove the 4 Whisky Claude hooks from ~/.claude/settings.json.
    /// Preserves any other hooks the user has configured.
    private static func removeClaudeCodeHooks() throws {
        let settingsPath = NSString(string: "~/.claude/settings.json").expandingTildeInPath
        let url = URL(fileURLWithPath: settingsPath)
        guard FileManager.default.fileExists(atPath: settingsPath) else { return }

        let data = try Data(contentsOf: url)
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "Uninstaller", code: 1, userInfo: [NSLocalizedDescriptionKey: "settings.json is not a JSON object"])
        }

        // Timestamped backup so the user can recover if something goes wrong.
        let backupURL = url.appendingPathExtension("bak.\(Int(Date().timeIntervalSince1970))")
        try? FileManager.default.copyItem(at: url, to: backupURL)

        // Remove our 4 hook keys while leaving any others intact.
        let ourHookEvents = ["Stop", "Notification", "PreToolUse", "UserPromptSubmit"]
        if var hooks = json["hooks"] as? [String: Any] {
            for event in ourHookEvents {
                // Only remove if the command references our helper — if the user
                // manually replaced it with something else, leave that alone.
                if let entries = hooks[event] as? [[String: Any]],
                   isOurHookGroup(entries) {
                    hooks.removeValue(forKey: event)
                }
            }
            if hooks.isEmpty {
                json.removeValue(forKey: "hooks")
            } else {
                json["hooks"] = hooks
            }
        }

        let out = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: url, options: .atomic)
    }

    /// Returns true if every entry's inner hook command path contains the
    /// Whisky Claude helper script — used to avoid clobbering user-customized
    /// hooks at the same event names.
    private static func isOurHookGroup(_ entries: [[String: Any]]) -> Bool {
        for entry in entries {
            guard let inner = entry["hooks"] as? [[String: Any]] else { return false }
            for h in inner {
                let cmd = h["command"] as? String ?? ""
                if !cmd.contains("wc-event.sh") { return false }
            }
        }
        return true
    }

    private static func tryRemove(path: String, label: String, errors: inout [String]) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        do {
            try FileManager.default.removeItem(atPath: path)
            NSLog("[WhiskyClaude] uninstaller: removed \(label) at \(path)")
        } catch {
            NSLog("[WhiskyClaude] uninstaller: failed to remove \(label): \(error)")
            errors.append("\(label): \(error.localizedDescription)")
        }
    }

    private static func removeLoginItem(errors: inout [String]) {
        let script = """
        tell application "System Events"
            if exists login item "Whisky Claude" then
                delete login item "Whisky Claude"
            end if
        end tell
        """
        var asError: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            errors.append("login item: failed to create AppleScript")
            return
        }
        appleScript.executeAndReturnError(&asError)
        if let asError {
            // Common case: the user denied Automation permission for our app.
            // The Login Item just stays registered — System Settings can clear it.
            let msg = (asError[NSAppleScript.errorMessage] as? String) ?? "unknown"
            NSLog("[WhiskyClaude] uninstaller: login item removal AppleScript error: \(msg)")
            errors.append("login item: \(msg) — remove manually via System Settings > General > Login Items")
        }
    }

    /// Shows a brief modal summary of any errors. If nothing failed, returns
    /// immediately without bothering the user.
    private static func showCompletionAlert(errors: [String]) {
        if errors.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Whisky Claude uninstalled"
            alert.informativeText = "Goodbye 👋"
            alert.runModal()
            return
        }
        let alert = NSAlert()
        alert.messageText = "Uninstalled with warnings"
        alert.informativeText = "Most cleanup steps completed, but:\n\n" +
            errors.map { "  • \($0)" }.joined(separator: "\n")
        alert.alertStyle = .warning
        alert.runModal()
    }
}

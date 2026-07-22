import SwiftUI

@main
struct WhiskyClaudeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The status-bar menu's "Settings…" is the primary entry point (a
        // floating NSWindow via SettingsWindowController). This Settings scene
        // exists only because an App needs a non-window-opening scene; point it
        // at the real content so the standard app-menu "Settings…" / ⌘, shows
        // the actual settings instead of a blank window.
        Settings {
            SettingsContentView()
        }
    }
}

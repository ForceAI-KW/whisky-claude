import SwiftUI

@main
struct WhiskyClaudeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The status-item menu's "Settings…" (a floating NSWindow via
        // SettingsWindowController) is the sole settings entry. An App needs a
        // scene, and Settings is the only one that doesn't force a window open at
        // launch; its auto-added app-menu "Settings…"/⌘, item is suppressed via
        // the .commands modifier below, so this scene is inert and never shown.
        Settings {
            EmptyView()
        }
        .commands {
            // Remove SwiftUI's auto-added app-menu "Settings…" (⌘,) command so the
            // status-item menu's "Settings…" (a floating NSWindow) is the SOLE
            // settings entry — no duplicate/blank window. Runtime NSMenu removal
            // doesn't stick (SwiftUI re-adds it on every menu update); this is the
            // supported declarative suppression.
            CommandGroup(replacing: .appSettings) { }
        }
    }
}

import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable {
    case about = "About"
    case general = "General"
    case voice = "Voice"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .voice:   return "mic"
        case .about:   return "info.circle"
        }
    }
}

struct SettingsContentView: View {
    @State private var selectedTab: SettingsTab = .about

    var body: some View {
        TabView(selection: $selectedTab) {
            AboutTab()
                .tabItem { Label(SettingsTab.about.rawValue, systemImage: SettingsTab.about.icon) }
                .tag(SettingsTab.about)

            GeneralTab()
                .tabItem { Label(SettingsTab.general.rawValue, systemImage: SettingsTab.general.icon) }
                .tag(SettingsTab.general)

            VoiceTab()
                .tabItem { Label(SettingsTab.voice.rawValue, systemImage: SettingsTab.voice.icon) }
                .tag(SettingsTab.voice)
        }
        .frame(width: 460, height: 280)
    }
}

struct GeneralTab: View {
    @Bindable private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Toggle(isOn: $settings.soundsEnabled) {
                Text("Play sound on Claude Code attention + completion")
                Text("Audio fires when Claude Code's Notification or Stop hook triggers — uses your bundled custom MP3s.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct VoiceTab: View {
    @Bindable private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Toggle(isOn: $settings.clapTriggerEnabled) {
                Text("Double-clap to open Claude in Terminal")
                Text("Uses Apple's on-device sound classifier (SoundAnalysis framework). Audio is analyzed locally on your Mac and is never recorded, stored, or sent anywhere. macOS will ask for microphone permission when you enable this.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if settings.clapTriggerEnabled {
                HStack {
                    Text("Sensitivity")
                    Slider(value: $settings.clapSensitivity, in: 0...1) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("Lenient").font(.caption)
                    } maximumValueLabel: {
                        Text("Strict").font(.caption)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("Whisky Claude")
                .font(.title2.bold())

            Text("by Ahmad Sharaf")
                .font(.body)
                .foregroundStyle(.secondary)

            Text("Fork of Notchy by Adam Lyttle (MIT)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 24) {
                Button("Source") {
                    if let url = URL(string: "https://github.com/ForceAI-KW/whisky-claude") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)

                Button("Upstream (Notchy)") {
                    if let url = URL(string: "https://github.com/adamlyttleapps/notchy") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if let existing = window {
            existing.level = .floating
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let content = SettingsContentView()
        let hostingView = NSHostingView(rootView: content)

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Whisky Claude Settings"
        win.contentView = hostingView
        win.center()
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = win
    }
}

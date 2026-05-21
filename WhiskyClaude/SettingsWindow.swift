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
            Toggle(isOn: $settings.mascotVisible) {
                Text("Show Claude mascot around the notch")
                Text("A small Claude character lives just below your notch and idles gently. It bounces a bit harder when Claude Code wants your attention.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: $settings.soundsEnabled) {
                Text("Play sound on Claude Code attention + completion")
                Text("Audio fires when Claude Code's Notification or Stop hook triggers — uses your bundled custom MP3s.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: $settings.preventSleep) {
                Text("Keep Mac awake while Whisky Claude is running")
                Text("Holds off system idle sleep so long Claude Code sessions aren't interrupted. The display can still dim or sleep based on your system settings.")
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
            Section {
                Toggle(isOn: $settings.clapTriggerEnabled) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundStyle(.tint)
                        Text("Slap the Mac")
                            .font(.body.weight(.medium))
                        if settings.clapTriggerEnabled {
                            ListeningPill()
                        }
                    }
                    Text("Give your Mac a single firm slap (on the lid, desk, or palm-rest) to open Claude in Terminal. Uses Apple's on-device sound classifier.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if settings.clapTriggerEnabled {
                    HStack {
                        Text("Sensitivity")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $settings.clapSensitivity, in: 0...1) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("Lenient").font(.caption2).foregroundStyle(.secondary)
                        } maximumValueLabel: {
                            Text("Strict").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 22)
                }
            } header: {
                Text("Voice triggers")
                    .font(.callout.bold())
                    .padding(.top, 4)
            } footer: {
                Text("Audio is analyzed locally on your Mac. Nothing is recorded, stored, or sent anywhere. macOS will prompt you for microphone (and speech recognition) permission the first time you enable these.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
            }

            Section {
                Toggle(isOn: $settings.wakeWordEnabled) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .foregroundStyle(.tint)
                        Text("Wake word")
                            .font(.body.weight(.medium))
                        if settings.wakeWordEnabled {
                            ListeningPill()
                        }
                    }
                    Text("Say \"hey claude\" or \"hey whisky\" to open Claude in Terminal. Uses Apple's on-device Speech framework.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Small pill shown next to an active trigger label.
private struct ListeningPill: View {
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            Text("listening")
                .font(.caption2)
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(Color.green.opacity(0.10), in: Capsule())
        .onAppear { pulse = true }
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 10) {
            Image("ClaudeLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 80, height: 80)

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

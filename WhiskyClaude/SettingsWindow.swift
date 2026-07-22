import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
        .frame(width: 460, height: 460)
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
                Text("Audio fires when Claude Code's Notification or Stop hook triggers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if settings.soundsEnabled {
                SoundPickerRow(
                    label: "Attention sound",
                    icon: "bell.fill",
                    currentPath: settings.customAttentionSoundPath,
                    previewName: "waitingForInput",
                    onPick: { path in settings.customAttentionSoundPath = path },
                    onReset: { settings.customAttentionSoundPath = nil }
                )
                SoundPickerRow(
                    label: "Done sound",
                    icon: "checkmark.seal.fill",
                    currentPath: settings.customDoneSoundPath,
                    previewName: "taskCompleted",
                    onPick: { path in settings.customDoneSoundPath = path },
                    onReset: { settings.customDoneSoundPath = nil }
                )
            }

            Toggle(isOn: $settings.preventSleep) {
                Text("Keep Mac awake while Whisky Claude is running")
                Text("Holds off system idle sleep so long Claude Code sessions aren't interrupted. The display can still dim or sleep based on your system settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: Binding(
                get: { SUUpdaterBridge.shared.autoCheck },
                set: { SUUpdaterBridge.shared.autoCheck = $0 }
            )) {
                Text("Automatically check for updates")
                Text("Checks for new versions in the background. You can also check anytime from the menu bar → Check for Updates….")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack(spacing: 6) {
                    Image(systemName: "eye.slash.fill")
                        .foregroundStyle(.tint)
                    Text("Stealth typing / privacy mode")
                        .font(.body.weight(.medium))
                }
                Text("Type English with the Arabic keyboard layout switched on and the screen shows Arabic gibberish instead of readable text. Menu bar → Decode Stealth Clipboard (⌘⌥D) converts the clipboard back to English in place.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Privacy")
                    .font(.callout.bold())
                    .padding(.top, 4)
            }
        }
        .formStyle(.grouped)
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

            Spacer()

            // Uninstall — single-click entry point that walks through every
            // install side-effect and reverses it after a confirmation dialog.
            Button(role: .destructive) {
                Uninstaller.confirmAndUninstall()
            } label: {
                Label("Uninstall Whisky Claude…", systemImage: "trash")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
    }
}

/// Compact row used in Settings > General for each customisable sound.
/// Shows the current file (custom or default), a "Choose…" file picker,
/// a "Preview" button, and a "Reset" button when a custom file is picked.
private struct SoundPickerRow: View {
    let label: String
    let icon: String
    let currentPath: String?
    /// Logical sound name passed to SoundPlayer.preview (matches the bundle resource name).
    let previewName: String
    let onPick: (String) -> Void
    let onReset: () -> Void

    private var displayName: String {
        if let path = currentPath, !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        return "Default (bundled)"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.callout)
                Text(displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()

            Button {
                SoundPlayer.shared.preview(previewName)
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            .help("Preview")

            Button("Choose\u{2026}") { pickFile() }
                .buttonStyle(.bordered)
                .controlSize(.small)

            if currentPath != nil {
                Button("Reset") { onReset() }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
            }
        }
        .padding(.leading, 22)
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose a sound file for \(label.lowercased())"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .mp3, .wav, .aiff, .mpeg4Audio]
        panel.level = .floating

        if panel.runModal() == .OK, let url = panel.url {
            onPick(url.path)
        }
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
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 460),
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

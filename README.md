# Whisky Claude

> A native macOS companion for [Claude Code](https://claude.com/claude-code). A little orange Claude character lives beside the notch on your MacBook, dances calmly when idle, and bounces + plays a sound when Claude Code needs your attention.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift 6](https://img.shields.io/badge/Swift-6-orange) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

---

## What it does

When you run `claude` in any terminal — Terminal.app, iTerm, Warp, whatever — Whisky Claude reacts via Claude Code's hook system:

| Claude Code event | What happens |
|---|---|
| Notification (Claude needs your input) | Mascot does a dramatic 360° spin + scale pop + **plays an attention sound** |
| Stop (Claude finished its turn) | Mascot does a celebratory half-spin + **plays a done sound** |
| Idle | Mascot lives its life — paces between the left and right side of the notch, dances calmly in place (Trump-style head nod + body sway), peeks up into the notch occasionally |

Plus:

- **"Hey Claude" / "Hey Whisky"** wake words — on-device via Apple's `Speech` framework. Audio never leaves your Mac.
- **Pick your own sounds** — Settings → General lets you replace the bundled attention + done audio with any local file (`.mp3` / `.wav` / `.m4a` / `.aiff` / `.caf`). Preview button next to each picker so you can audition before saving.
- **Keeps your Mac awake** so long-running Claude Code sessions don't get interrupted by system idle sleep. (Display sleep still respected.)
- **Menu bar icon** — static Claude logo; click for Open Terminal / Settings / Quit.

## Privacy

- **No network calls.** Everything runs locally.
- **Microphone audio** (used only when the wake-word recognizer is enabled — **off by default**) is analyzed in-buffer and immediately discarded. It is never saved to disk, never sent anywhere.
- **Claude Code hooks** write event payloads to `~/.claude/pet-events/`. Each event is consumed within milliseconds and deleted.
- Sandboxing intentionally disabled — needs to read `~/.claude/pet-events/` and post an `IOPMAssertion`.

## Install

```bash
git clone https://github.com/ForceAI-KW/whisky-claude.git
cd whisky-claude
./scripts/install.sh
```

The installer:
1. Builds the Release config and signs with a stable self-signed certificate if one is installed in your login keychain (falls back to ad-hoc otherwise — see [Persistent permissions](#persistent-permissions) below)
2. Detects a change of signing identity vs the previously-installed copy and resets stale TCC grants only when needed
3. Copies the app to `/Applications/Whisky Claude.app`
4. Installs the Claude Code hook helper to `~/.claude/scripts/wc-event.sh`
5. Wires the 4 hooks (`Stop`, `Notification`, `PreToolUse`, `UserPromptSubmit`) into `~/.claude/settings.json` — safely, preserving any other hooks you already have
6. Registers as a macOS Login Item so it auto-starts at login
7. Cleans up build artifacts so they don't appear as duplicate apps in Spotlight

### Persistent permissions (v1.2.0+)

By default `./scripts/install.sh` ad-hoc-signs the binary, which means every reinstall produces a new code signature — and macOS keys TCC grants (Accessibility, Microphone, Speech Recognition) to that signature. Result: you re-grant after every reinstall.

To make grants survive reinstalls, drop a stable self-signed code-signing certificate into your login keychain named **"Ahmad Sharaf Code Signing"** (rename to taste; just update the `SIGN_ID` variable in `scripts/install.sh` to match). One-time setup with OpenSSL + `security import` — recipe in [docs/STABLE_CODESIGN.md](docs/STABLE_CODESIGN.md) (TBD; see commit history for the full procedure). Once installed, every future `./scripts/install.sh` keeps the same Designated Requirement and your grants persist forever.

The installer also handles the migration: if you've already installed Whisky Claude with ad-hoc signing and then add a stable cert, the next install detects the DR change and calls `tccutil reset` for every relevant TCC bucket so you get one clean round of prompts. From then on, no more re-grants.

### Uninstall

Either:
- **From the app**: Menu bar icon → Settings → About → "Uninstall Whisky Claude…"
- **From the shell**: `./scripts/uninstall.sh`

Both paths walk through every install side-effect in reverse and back up `~/.claude/settings.json` before modifying it.

## How it works

```
┌─ Claude Code session anywhere ──────────────────┐
│  Hook fires                                     │
│  (Stop / Notification / PreToolUse / UserPrompt)│
│                  │                              │
│                  ▼                              │
│  ~/.claude/scripts/wc-event.sh                  │
│  (writes event JSON atomically via mv)          │
│                  │                              │
│                  ▼                              │
│  ~/.claude/pet-events/<uuid>.json               │
└─────────────────────────────────────────────────┘
                   │
                   ▼
┌─ Whisky Claude ─────────────────────────────────┐
│  EventWatcher  (DispatchSource on the dir)      │
│       │                                         │
│       ▼                                         │
│  AttentionState.apply  →  NotificationCenter    │
│       │           │                │            │
│       ▼           ▼                ▼            │
│  MascotWindow  SoundPlayer    MenuBarIcon       │
│  .triggerBounce  .play            (static)      │
└─────────────────────────────────────────────────┘
```

The mascot is a borderless `NSPanel` at `statusBar` level, positioned using `NSScreen.builtIn.auxiliaryTopLeftArea`/`auxiliaryTopRightArea` so it reads real notch measurements, not guesses. It's `ignoresMouseEvents = true` so it never intercepts clicks, and constrained horizontally to the notch's outline so it never covers menu items in apps with long menu bars (Xcode, Logic, Final Cut).

More detail in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Requirements

- macOS 13 or later (tested on macOS 26)
- A MacBook with a notch is ideal; works on un-notched Macs too (mascot anchors to menu bar bottom)
- For wake words: microphone + Speech Recognition permission (macOS prompts on first use)
- **To open Terminal as a new tab in your existing window** (vs. a new window every time): Accessibility permission. The first time you click "Open Claude in Terminal" or say the wake word, Whisky Claude shows a one-shot dialog with a button that deep-links to System Settings → Privacy & Security → Accessibility. Without it, Terminal still opens — just as a new window. With ad-hoc signing the binary's signature changes on every reinstall (you'd re-grant each time); see [Persistent permissions](#persistent-permissions) above for the stable-cert setup that fixes this once and for all.

## Settings

Click the menu bar icon → **Settings…**

- **General** — toggle the mascot, sounds, "keep Mac awake", **and pick custom audio files** for attention + done events (with a one-click preview button)
- **Voice** — opt into wake words ("hey Claude" / "hey Whisky")
- **About** — version info, links, and the uninstall button

## Credits

Whisky Claude is a heavily modified fork of [**Notchy**](https://github.com/adamlyttleapps/notchy) by [Adam Lyttle](https://github.com/adamlyttleapps), licensed under MIT. Many architectural decisions (NSPanel-over-notch, status item ownership, SwiftUI hosted in AppKit) came from his work. The mascot, choreography, voice triggers, Claude Code integration, and uninstall flow are original.

The Claude character icon is the [Claude Code logo](https://www.anthropic.com), redrawn as a vector. "Claude" is a trademark of Anthropic.

## Contributing

Bug reports + PRs welcome.

## License

[MIT](LICENSE) — same as upstream Notchy.

# Whisky Claude — Architecture Reference

Whisky Claude is a forked + modified Notchy.app that puts a Claude mascot in the macOS notch,
animates it on Claude Code activity, and supports a single-slap trigger to open a new Claude terminal session.
Fork attribution: MIT, see LICENSE.

This document describes what the codebase actually contains. For the implementation plan that produced
it, see `docs/plans/2026-05-21-whisky-claude-fork.md`. For session-startup guidance, see `CLAUDE.md`.

---

## Source tree

```
WhiskyClaude/
├── WhiskyClaudeApp.swift       — @main SwiftUI App; NSApplicationDelegateAdaptor → AppDelegate. Body is an empty Settings scene.
├── AppDelegate.swift           — Owns NSStatusItem (via MenuBarIcon), MascotWindow, EventWatcher, ClapDetector,
│                                 KeywordRecognizer, SleepBlocker. Entry point for slap/wake-word → openClaudeInTerminal().
├── ClapDetector.swift          — SharedMicCapture + SNClassifySoundRequest (version1 classifier).
│                                 Broad percussive label set (knock, thump, drum, tap, tapping_hand, clapping).
│                                 One qualifying hit above threshold + 1.5 s cooldown fires onDoubleClap (the callback;
│                                 semantics are single-slap). Sensitivity slider maps 0..1 → threshold 0.35..0.80.
├── ClawdMascot.swift           — GIF mascot renderer. Loads clawd-*.gif asset sets, cycles animation frames,
│                                 switches pose on state changes (idle / working / waitingForInput / taskCompleted).
├── EventWatcher.swift          — DispatchSource on ~/.claude/pet-events/. Scans + deletes JSON files on .write.
│                                 Hosts ExternalEventState (@Observable singleton) with idle-drift timers.
├── KeywordRecognizer.swift     — On-device wake-word detection via Apple Speech framework.
│                                 Recognizes "hey claude" / "hey whisky"; fires onWakeWord → openClaudeInTerminal().
│                                 Gated by SettingsManager.wakeWordEnabled (default OFF).
├── MascotWindow.swift          — Borderless NSPanel at statusBar level over the notch. Hosts ClawdMascot.
│                                 Constrained horizontally to notch outline; ignoresMouseEvents = true.
├── MenuBarIcon.swift           — NSStatusItem ownership. Static Claude logo; menu: Open Terminal / Settings / Quit.
├── SettingsManager.swift       — @Observable UserDefaults-backed flags: mascotEnabled, soundsEnabled,
│                                 keepAwakeEnabled, clapTriggerEnabled, clapSensitivity, wakeWordEnabled,
│                                 attentionSoundURL, doneSoundURL.
├── SettingsWindow.swift        — 3 tabs (About, General, Voice). Singleton NSWindowController.
├── SharedMicCapture.swift      — Shared AVAudioEngine + input tap; feeds both ClapDetector and KeywordRecognizer
│                                 from a single audio session to avoid TCC double-prompt.
├── SleepBlocker.swift          — IOPMAssertion wrapper; prevents system idle sleep while Claude is working.
├── SoundPlayer.swift           — AVAudioPlayer wrapper. Plays .wav files from Bundle or a user-supplied URL.
│                                 1 s debounce to prevent double-fires. Gated by SettingsManager.soundsEnabled.
├── Uninstaller.swift           — Removes /Applications/Whisky Claude.app, unregisters Login Item, reverses
│                                 hook patches in ~/.claude/settings.json (backs up first).
└── WhiskyClaudeApp.swift       — (see top entry)
```

---

## External IPC: ~/.claude/pet-events/

Whisky Claude reacts to Claude Code activity running OUTSIDE the embedded terminal panel (native Terminal,
iTerm, any external session) via a file-based event queue.

### Event JSON schema

```json
{
  "type": "thinking" | "working" | "attention" | "done",
  "ts":   "2026-05-21T14:32:00Z",
  "session_id": "...",
  "message": "..."
}
```

### Flow

- **Writer**: `~/.claude/scripts/wc-event.sh <event_type>` — reads the Claude Code hook JSON payload from stdin,
  writes a UUID-named `.json` file to `~/.claude/pet-events/`.
- **Watcher**: `EventWatcher.swift` opens the directory with `DispatchSource.makeFileSystemObjectSource(..., eventMask: [.write])`.
  On each write event it scans all `.json` files (sorted by mtime), decodes, calls `ExternalEventState.shared.apply(type:)`,
  then deletes each file.
- **Mapping** (in `ExternalEventState.apply`):
  - `"thinking"` / `"working"` → `.working`
  - `"attention"` → `.waitingForInput`
  - `"done"` → `.taskCompleted`
  - anything else → `.idle`
- **Idle drift**: attention/done auto-return to `.idle` after 5 s; working/thinking after 30 s.
- **Priority merge** (`NotchDisplayState.current` in `NotchWindow.swift`): external `waitingForInput` and `taskCompleted`
  beat all session states. Session `taskCompleted` > session `waitingForInput` > session `working` > external `working` > `.idle`.
  The entire merge short-circuits to `.idle` when `claudeIntegrationEnabled` is false.

---

## Hook installation

`scripts/install-hooks.sh` idempotently patches `~/.claude/settings.json` with four hooks:

| Hook | wc-event.sh arg | maps to |
|---|---|---|
| `UserPromptSubmit` | `thinking` | `.working` |
| `PreToolUse` | `working` | `.working` |
| `Notification` | `attention` | `.waitingForInput` |
| `Stop` | `done` | `.taskCompleted` |

All hooks run async (`"async": true`). The helper at `scripts/dot-claude/wc-event.sh` must be copied to
`~/.claude/scripts/wc-event.sh` before running the installer (the script enforces this). A timestamped backup
of `settings.json` is made before any modification.

---

## Slap-trigger pipeline

- Opt-in. Default OFF. Enable via Settings → Voice tab.
- `ClapDetector.shared.start()` uses `SharedMicCapture` (shared AVAudioEngine) to install a tap (~185ms buffers at 44.1kHz).
- Each buffer is handed to `SNAudioStreamAnalyzer` running `SNClassifySoundRequest(classifierIdentifier: .version1)`.
- On each `SNClassificationResult`, the detector checks for any label in the broad percussive set
  `{"knock", "thump, thud", "drum", "tap", "tapping_(hand)", "clapping"}` with `confidence >= confidenceThreshold`.
  The wide label set captures a single hard desk-slap regardless of exact classifier label.
- Sensitivity slider (0..1) maps to confidence threshold 0.35..0.80 via `confidenceThreshold = 0.35 + 0.45 * sensitivity`.
- **One** qualifying match, subject to a 1.5 s cooldown from the last fire, invokes `onDoubleClap` (the callback name
  is kept for compatibility; the trigger is a single slap, not two claps).
- `onDoubleClap` → `AppDelegate.openClaudeInTerminal()` (opens Terminal.app via AppleScript; no embedded panel).
- All classification is on-device. No audio is persisted, buffered across calls, or transmitted.
- `ClapDetector.stop()` removes the tap. `SettingsManager.clapTriggerEnabled` drives start/stop.

---

## Notch geometry

Key constraints (all in `NotchWindow.swift`):

- `notchWidth` is detected from `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` on the built-in display.
  Default fallback: 180pt.
- `hoverGrowX = 0` — the pill never grows horizontally past `notchWidth`. Commit `a733396` introduced this cap to
  prevent menu bar items being hidden on Macs with long menu bars (Xcode, Logic, Final Cut, etc.).
- When any state is non-idle, the pill grows **downward** by `expandedExtraHeight = 22pt` (static constant, line 376).
  Width stays at `notchWidth`.
- Mascot animation is rendered inside `MascotWindow` (a separate NSPanel); it does not affect the notch pill geometry.
- Hover state (mouse over notch) applies `hoverGrowX / 2` lateral inset — which is 0, so no visual change, but the
  code path still runs. The ear-drawing paths in `NotchPillView` are intact (see §Inert code below).
- Collapse is debounced 0.5 s to avoid rapid cycling when terminal status flickers at session boundaries.

---

## Build + install

**Debug build** (no codesign required):
```
xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude -configuration Debug \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```
Output: `build/Build/Products/Debug/WhiskyClaude.app`.

**Release + install + Login Item**: `scripts/install.sh` — builds Release, copies to `/Applications/WhiskyClaude.app`,
registers as a Login Item via `SMAppService.mainApp`.

**Uninstall**: `scripts/uninstall.sh` — removes from `/Applications`, unregisters Login Item.

No tests or linting are configured.

---

## What was removed from upstream Notchy

| Feature | Commit |
|---|---|
| XcodeDetector + Xcode project auto-detection | `8479044` |
| CheckpointManager + Cmd+S git snapshots | `5287400` |
| `face.imageset` asset | `2e64519` |
| Horizontal pill expansion on hover (`hoverGrowX` was > 0 upstream) | `a733396` |
| Original Notchy mascot / bot face art | `b1c8ca8` |

The reference clone at `~/Desktop/projects/_external/notchy/` is untouched and serves as a diff anchor.

---

## Inert code (intentionally kept)

`NotchPillView.updateShape()` (line ~462 in `NotchWindow.swift`) contains ear-drawing code paths that reference
`NotchPillView.earRadius`. With `hoverGrowX = 0`, the ears never visually protrude — the computed ear rects
are zero-width in practice. The drawing code still executes on every frame but has no visible effect.

This code is not removed to minimize divergence from upstream Notchy and simplify future merges.

---

## Sounds

```
WhiskyClaude/Sounds/
├── waitingForInput.wav   — plays on .waitingForInput (custom attention sound)
└── taskCompleted.wav     — plays on .taskCompleted (custom done sound)
```

`SoundPlayer` uses `AVAudioPlayer`, gated by `SettingsManager.soundsEnabled` and a 1 s debounce
to prevent double-fires. Sounds are loaded from `Bundle.main` unless overridden by a user-supplied URL
(Settings → General → custom sound picker).

---

## Open items

- Production codesign + notarization — current build is ad-hoc only (`CODE_SIGN_IDENTITY="-"`).

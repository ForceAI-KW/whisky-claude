# Whisky Claude — Architecture Reference

Whisky Claude is a forked + modified Notchy.app that puts a Claude mascot in the macOS notch,
animates it on Claude Code activity, and supports a double-clap to open a new Claude terminal session.
Fork attribution: MIT, see LICENSE.

This document describes what the codebase actually contains. For the implementation plan that produced
it, see `docs/plans/2026-05-21-whisky-claude-fork.md`. For session-startup guidance, see `CLAUDE.md`.

---

## Source tree

```
WhiskyClaude/
├── WhiskyClaudeApp.swift       — @main SwiftUI App; NSApplicationDelegateAdaptor → AppDelegate. Body is an empty Settings scene.
├── AppDelegate.swift           — Owns NSStatusItem, TerminalPanel, NotchWindow. Wires EventWatcher, ClapDetector,
│                                 hover-tracking, global backtick hotkey. Entry point for double-clap → new session.
├── NotchWindow.swift           — Always-visible NSPanel over the notch. Pill geometry + bounce animation.
│                                 Contains NotchDisplayState enum + ExternalEventState merge logic.
│                                 NotchPillView (NSView) + NotchPillContent (SwiftUI overlay) defined here.
├── BotFaceView.swift           — SF Symbol mascot (Claude orange #FF7700). Per-state symbol + tint.
│                                 Listens to MascotAnimator.shared.onTick; triggers jump()/bounce() on state changes.
├── MascotAnimator.swift        — CVDisplayLink-driven sin-curve Y-offset. jump() + bounce() as named aliases.
│                                 Generation-tracked Unmanaged retain avoids double-release on rapid re-trigger.
├── EventWatcher.swift          — DispatchSource on ~/.claude/pet-events/. Scans + deletes JSON files on .write.
│                                 Hosts ExternalEventState (@Observable singleton) with idle-drift timers.
├── ClapDetector.swift          — AVAudioEngine input tap + SNClassifySoundRequest (version1 classifier).
│                                 Two clapping/applause hits within 100-600ms fire onDoubleClap. Sensitivity slider
│                                 maps 0..1 → confidence threshold 0.5..0.9.
├── SessionStore.swift          — @Observable singleton. TerminalSession list + active selection. Sound playback
│                                 (AVAudioPlayer). Sleep prevention (IOPMAssertion). Session persistence (UserDefaults).
│                                 idle→taskCompleted transition has 3s delay to avoid working→idle flickers.
├── TerminalManager.swift       — [UUID: ClickThroughTerminalView] dict. Creates LocalProcessTerminalView per session,
│                                 spawns user's login shell + sends `cd <dir> && clear && claude`. Reads terminal buffer
│                                 (debounced 150ms) and classifies output into TerminalStatus states.
├── TerminalPanel.swift         — Borderless NSPanel below status item. Hosts PanelContentView. Hides on resign-key
│                                 unless pinned.
├── TerminalSession.swift       — Value type: id, projectName, projectPath?, workingDirectory, terminalStatus,
│                                 generation, hasStarted, hasBeenSelected, workingStartedAt. PersistedSession Codable.
├── TerminalSessionView.swift   — NSViewRepresentable. Attaches/detaches ClickThroughTerminalView to a container
│                                 based on active session ID.
├── PanelContentView.swift      — SwiftUI root of the panel: SessionTabBar + active session content area.
├── SessionTabBar.swift         — Tab UI per session; dot color reflects TerminalStatus. Rename/close context menu.
└── SettingsManager.swift       — @Observable UserDefaults-backed flags: showNotch, soundsEnabled,
                                  claudeIntegrationEnabled, clapTriggerEnabled, clapSensitivity.
    SettingsWindow.swift        — 4 tabs (About, General, Integrations, Voice). Singleton NSWindowController.
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

## Clap-trigger pipeline

- Opt-in. Default OFF. Enable via Settings → Voice tab.
- `ClapDetector.shared.start()` installs an 8192-sample tap on `AVAudioEngine.inputNode` (~185ms buffers at 44.1kHz).
- Each buffer is handed to `SNAudioStreamAnalyzer` running `SNClassifySoundRequest(classifierIdentifier: .version1)`.
- On each `SNClassificationResult`, the detector checks for any classification in `{"clapping", "applause"}` with
  `confidence >= confidenceThreshold`. `applause` is included because the classifier sometimes emits it for a solo
  two-hand clap with reverb.
- Sensitivity slider (0..1) maps to confidence threshold 0.5..0.9 via `confidenceThreshold = 0.5 + 0.4 * sensitivity`.
- Two qualifying matches where the gap between them is 100–600ms fire `onDoubleClap`.
- `onDoubleClap` → `SessionStore.createQuickSession()` + `showPanelBelowStatusItem()`.
- All classification is on-device. No audio is persisted, buffered across calls, or transmitted.
- `ClapDetector.stop()` removes the tap and stops the engine. `SettingsManager.clapTriggerEnabled` drives start/stop.

---

## Notch geometry

Key constraints (all in `NotchWindow.swift`):

- `notchWidth` is detected from `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` on the built-in display.
  Default fallback: 180pt.
- `hoverGrowX = 0` — the pill never grows horizontally past `notchWidth`. Commit `a733396` introduced this cap to
  prevent menu bar items being hidden on Macs with long menu bars (Xcode, Logic, Final Cut, etc.).
- When any state is non-idle, the pill grows **downward** by `expandedExtraHeight = 22pt` (static constant, line 376).
  Width stays at `notchWidth`.
- Mascot jump animation Y-offset is applied via `.offset(y: -jumpY)` inside `BotFaceView` — the SwiftUI view moves
  inside the pill; the pill frame itself does not grow further.
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
├── waitingForInput.mp3   — plays on .waitingForInput (Notchy upstream asset)
└── taskCompleted.mp3     — plays on .taskCompleted (Notchy upstream asset)
```

`SessionStore.playSound(named:)` uses `AVAudioPlayer`, gated by `SettingsManager.soundsEnabled` and a 1 s debounce
to prevent double-fires. Sounds are loaded from `Bundle.main`.

**Task 5 pending**: `waitingForInput.mp3` should be replaced with Ahmad's custom attention sound once the file is
provided. Drop-in replacement — same filename, same bundle location.

---

## Open items

- **Task 5**: swap `waitingForInput.mp3` for Ahmad's custom sound (file not yet provided).
- Voice keyword detection ("hey claude") via Speech framework — sibling feature to clap, not wired.
- Custom mascot PNG or lottie in place of the SF Symbol.
- Production codesign + notarization — current build is ad-hoc only (`CODE_SIGN_IDENTITY="-"`).

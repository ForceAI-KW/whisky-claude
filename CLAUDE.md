# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

Whisky Claude is a fork of Notchy (https://github.com/adamlyttleapps/notchy, MIT) being modified into a macOS app where a Claude mascot lives in the notch, jumps + plays a custom sound when Claude Code needs the user's attention, and supports a double-clap voice trigger to open a Claude terminal session. The base architecture (NotchWindow, terminal panel, Xcode detection, settings UI, checkpoints) is inherited from upstream Notchy — see the Architecture section below for what's there. Modifications happen task-by-task per the implementation plan at `docs/plans/2026-05-21-whisky-claude-fork.md`.

Reference clone (upstream, untouched): `~/Desktop/projects/_external/notchy/` — used as a diff anchor when merging upstream changes.

## Build

Open `WhiskyClaude.xcodeproj` in Xcode and build (Cmd+B), or from the command line:

```bash
xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude -configuration Debug -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
```

The built app is at `build/Build/Products/Debug/WhiskyClaude.app`. Ad-hoc codesign (no Apple Developer cert required).

There are no tests or linting configured yet.

## Architecture (inherited from Notchy, modifications in progress)

**App lifecycle**: `WhiskyClaudeApp` (in `WhiskyClaude/WhiskyClaudeApp.swift`) uses `@NSApplicationDelegateAdaptor` to delegate to `AppDelegate`, which owns the `NSStatusItem` (menu bar icon), the `TerminalPanel`, and the `NotchWindow`. The SwiftUI `App` body is an empty `Settings` scene — all UI lives in the panel and notch window.

**Notch integration**: `NotchWindow` is an always-visible `NSPanel` positioned over the MacBook notch. It detects notch dimensions via `NSScreen.auxiliaryTopLeftArea`/`auxiliaryTopRightArea`, tracks mouse hover to trigger the main panel, and expands with a bounce animation (via `CVDisplayLinkWrapper`) when any session is working. `NotchPillContent` (SwiftUI) renders status icons (spinner, checkmark, warning) inside the pill. `NotchDisplayState` computes a priority-based aggregate status across all sessions. (**Task 2 of the plan caps horizontal expansion at notchWidth so apps with long menu bars never have buttons hidden.**)

**Session management**: `SessionStore` (singleton, `@Observable`) holds the list of `TerminalSession` values and the active selection. It coordinates with `XcodeDetector` to discover open Xcode projects via AppleScript (with a CGWindow title fallback). Sessions use lazy terminal startup. The store also manages sleep prevention (`IOPMAssertion`) while Claude is working, and polls for Xcode projects every 5 seconds when pinned.

**Terminal status detection**: `ClickThroughTerminalView` (subclass of `LocalProcessTerminalView`) reads the terminal buffer on every `dataReceived` (debounced 150ms) and classifies the output into `TerminalStatus` states: `.working` (spinner chars + token counter), `.waitingForInput` (user prompt `❯`), `.interrupted`, `.idle`. The `idle → taskCompleted` transition uses a 3-second delay to avoid false positives from brief working→idle flickers.

**Terminal embedding**: `TerminalManager` (singleton) owns a `[UUID: LocalProcessTerminalView]` dictionary. Terminals are created on demand, spawning the user's login shell, then sending `cd <project-dir> && clear && claude`. `TerminalSessionView` is an `NSViewRepresentable` that attaches/detaches the terminal view to a container based on the active session ID.

**Panel**: `TerminalPanel` is an `NSPanel` (borderless, floating, non-activating) that shows/hides below the notch or status item. It hides on resign-key unless pinned. Supports Cmd+S for checkpoints. `PanelContentView` composes the tab bar and terminal area.

**Tab bar**: `SessionTabBar` renders tabs with a green/gray dot indicating whether the Xcode project is still open. Tabs support rename (via context menu) and close.

**Checkpoints**: `CheckpointManager` creates git snapshots using custom refs (`refs/WhiskyClaude-snapshots/<project>/<timestamp>`). It uses a temporary `GIT_INDEX_FILE` to avoid disturbing the user's staging area. Checkpoints can be created (Cmd+S or menu), listed, and restored.

**Hover behavior**: `AppDelegate` manages a dual interaction model — notch hover opens the panel with mouse-tracking that auto-hides when the cursor leaves, while status item click opens normally with resign-key hiding. The backtick key (keyCode 50) is a global hotkey to toggle the panel.

## Modifications planned

See `docs/plans/2026-05-21-whisky-claude-fork.md` for the implementation plan. Active modifications:

1. Cap pill horizontal width to notchWidth (no menu-bar interference)
2. Replace Notchy's bot face with "Clawd", the Claude Code pixel mascot — animated
   GIFs that change pose by live Claude Code state (idle / working=typing /
   waitingForInput=notification / taskCompleted=happy), cycling variants for
   variety. Rendered via `ClawdGIFView` (NSImageView, nearest-neighbor) inside the
   existing notch choreography in `MascotWindow`. **Art is LOCAL-ONLY:** the
   `clawd-*.gif` data sets are gitignored (clawd-on-desk, AGPL-3.0 — credit to the
   author + Anthropic's Clawd) and never pushed to this public MIT repo. Without
   them the mascot simply renders nothing; supply your own
   `WhiskyClaude/Assets.xcassets/clawd-*.dataset/` gifs locally. **In a git
   worktree** the ignored art is NOT copied by `git worktree add`, so a fresh
   worktree builds with no mascot art — run `scripts/link-local-art.sh` to
   symlink it from the primary checkout (auto-run by `new-task-worktree.sh`).
3. Add jump-animation when waiting for input + bounce on task complete
4. Custom attention + done sounds (user-provided)
5. External Claude Code event hooks via `~/.claude/pet-events/` watcher
6. Opt-in double-clap voice trigger (AVAudioEngine)
7. Install to `/Applications/Whisky Claude.app` as a Login Item

## Dependencies

- **Sparkle 2.x** (SPM, `sparkle-project/Sparkle`) — in-app auto-update. The project's only SPM package.
- AVFoundation — clap detection (system framework, already linked).
- (NOTE: SwiftTerm is **not** linked — the terminal is opened via AppleScript in `openClaudeInTerminal`, not embedded. `Package.resolved` lists only Sparkle. The "terminal embedding / SwiftTerm / sessions / tabs / checkpoints" parts of the Architecture section above are inherited-from-Notchy description and do not reflect the current stripped-down app.)

## Auto-update (Sparkle)

`AppDelegate` owns an `SPUStandardUpdaterController` (auto-checks on) + a "Check for Updates…" menu item; Settings → General has an "Automatically check for updates" toggle (via `SUUpdaterBridge`). Feed = `appcast.xml` at repo root, served from `raw.githubusercontent.com/.../master/appcast.xml` (`SUFeedURL`), binaries = GitHub Release assets, integrity = EdDSA (`SUPublicEDKey` in Info.plist; private key in login Keychain, never committed). **Info.plist is explicit** (`WhiskyClaude/Info.plist`, `GENERATE_INFOPLIST_FILE = NO`) — `INFOPLIST_KEY_*` only supports an allowlist, so arbitrary keys like `SUFeedURL`/`SUPublicEDKey` need a real plist; it's excluded from the synchronized group's resource copy via a `PBXFileSystemSynchronizedBuildFileExceptionSet`. Cut releases with `./scripts/release.sh <version>` — see `docs/RELEASING.md`.

## Entitlements + TCC permissions

The app requires `com.apple.security.automation.apple-events` for AppleScript communication with Xcode + Terminal. Task 7 adds `NSMicrophoneUsageDescription` for the clap detector.

**Accessibility (TCC) — runtime grant, NOT an entitlement:** opening Terminal as a new TAB in the existing window injects key events via `System Events`, gated by Privacy → Accessibility (a separate TCC bucket from Privacy → Automation). `AppDelegate.openClaudeInTerminal` checks `AXIsProcessTrusted()` and:
- if trusted → "new tab in front window" path: copies `cd '<home>' && claude` to the clipboard, then sends **physical key codes** `key code 17` (Cmd+T), `key code 9` (Cmd+V), `key code 36` (Return), and restores the clipboard. **Key codes + clipboard are KEYBOARD-LAYOUT-INDEPENDENT** — the earlier `keystroke "<string>"` (and even `keystroke "v" using {command down}`) garbled/failed under non-Latin layouts e.g. Arabic. See `memory/feedback-keystroke-injection-layout-independent.md`.
- if not → falls back to plain `do script` (new window) AND shows a one-shot NSAlert with an "Open Settings" deep-link to Privacy & Security → Accessibility

Each `./scripts/install.sh` replaces the binary with a new ad-hoc signature, which invalidates the Accessibility grant. Users must re-grant after every install. This is documented in README "Requirements".

## Standing rules from global config (cross-project)

These are enforced globally in `~/.claude/CLAUDE.md`. Summarized here for
contributors who don't have access to the global config. Read the source file
for the full context.

1. **Memory pipeline after every commit** — `nohup ~/.claude/scripts/update-memory-pipeline.sh all` fires after each commit. Not optional.
   Reference: `~/.claude/projects/-Users-ahmadsharaf/memory/MEMORY.md`

2. **Scoped memory = source of truth, MEMORY.md = index** — detailed lessons live in `feedback-*.md` / `project-*.md` files; MEMORY.md is the pointer table.
   Reference: `~/.claude/projects/-Users-ahmadsharaf/memory/MEMORY.md`

3. **Fix everything, no "non-blocking ignored" category** — warnings and lint errors are treated as failures.
   Reference: `~/.claude/projects/-Users-ahmadsharaf/memory/feedback-ai-security-checklist.md`

4. **Never defer a task unless Ahmad explicitly asks** — don't leave partial work or TODOs without a signal.

5. **Session auto-config** — Remote Control auto-starts, session names to `basename($PWD)`.

6. **Documentation parity** — every feature ships with docs in the same session (local commit + remote push).
   Reference: `~/.claude/CLAUDE.md` §"Plan-before-code for big changes"

7. **Multi-step Redis sentinel for reminders** — stepped reminder queues (e.g. cart abandoned 1h/4h/24h cadence) use Redis sentinel keys to track which step fired, not simple TTL locks.
   Reference: `~/.claude/projects/-Users-ahmadsharaf-Desktop-projects-force-website-builder/memory/`

8. **Discoverability status-chip pattern for buried features** — any feature with a toggle buried 3+ taps deep MUST surface its state on the Settings overview card (e.g. "DM ordering: ON/OFF" chip on the WhatsApp connection card).
   Reference: commit `917a268a` (FWB)

9. **Version-agnostic lookup for externally-versioned names** — Meta template names can be renamed via Reset-to-Draft. Dropdowns must resolve by base-name match (strip `_v2`, `_v3` suffixes) not exact-name lookup.
   Reference: commit `1507ef67` (FWB)

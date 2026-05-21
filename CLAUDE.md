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
2. Replace Notchy's bot face with a state-aware Claude mascot (SF Symbol, Claude orange)
3. Add jump-animation when waiting for input + bounce on task complete
4. Custom attention + done sounds (user-provided)
5. External Claude Code event hooks via `~/.claude/pet-events/` watcher
6. Opt-in double-clap voice trigger (AVAudioEngine)
7. Install to `/Applications/Whisky Claude.app` as a Login Item

## Dependencies

- **SwiftTerm** (`migueldeicaza/SwiftTerm`) — terminal emulator view (`LocalProcessTerminalView`)
- (Task 7 adds AVFoundation usage for clap detection — already linked.)

## Entitlements

The app requires `com.apple.security.automation.apple-events` for AppleScript communication with Xcode. Task 7 adds `NSMicrophoneUsageDescription` for the clap detector.

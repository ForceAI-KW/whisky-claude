# Whisky Claude Implementation Plan (fork-and-modify)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fork Notchy.app (provided as `~/Downloads/notchy-main.zip`) and modify in place into "Whisky Claude" — a macOS app that:

1. Lives in the notch always (already what Notchy does)
2. Shows a Claude mascot (instead of Notchy's bot face)
3. Jumps + plays a custom sound when Claude Code needs attention
4. **Does NOT obscure menu bar items** even when other apps render menus past the notch (this is the hard constraint — Notchy's current `notchWidth + 80` expansion violates this)
5. Has a settings panel for runtime control (extends Notchy's existing `SettingsWindow`)
6. **Clap-trigger** that opens a Claude terminal session when the user claps twice (reuses Notchy's terminal panel; new feature)
7. Auto-launches at login, always running

**Architecture:** Rename-and-extend, NOT clean room. Notchy already implements 80% of what we need: `NotchWindow` (notch-positioned NSPanel), `NotchDisplayState` (priority state machine), terminal panel with hover behavior, `SettingsManager` + `SettingsWindow` (UserDefaults-backed), bounce animation via `CVDisplayLinkWrapper`, `ClickThroughTerminalView` that auto-spawns `claude`. We **rename** the project, **constrain horizontal expansion** to fit inside the notch, **swap** the bot face + sounds, **add** a jump animation + clap detector + Claude Code event hooks.

**Tech Stack:**
- Existing: Swift 6 + SwiftUI + AppKit, SwiftTerm (terminal), AppleScript (Xcode detection), AVAudioPlayer
- New: AVCaptureSession + AVAudioEngine (clap detection), `DispatchSource.makeFileSystemObjectSource` (Claude Code event watcher), microphone permission

**Reference (NOT modified):** `~/Desktop/projects/_external/notchy/Notchy/` — original upstream clone, kept as the upstream-diff anchor.

**Source-of-truth zip:** `~/Downloads/notchy-main.zip` — what we extract + rename.

---

## File rename map (Notchy → WhiskyClaude)

| Old | New |
|---|---|
| Project folder | `~/Downloads/notchy-main/` after unzip → `~/Desktop/projects/whisky-claude/` |
| Xcode target name | `Notchy` → `WhiskyClaude` |
| `BotdockApp.swift` (the `@main` struct) | `WhiskyClaudeApp.swift` |
| `struct NotchyApp: App` | `struct WhiskyClaudeApp: App` |
| Bundle id | `com.notchy.app` (or whatever it currently is) → `com.ahmadsharaf.WhiskyClaude` |
| `CFBundleDisplayName` | `Notchy` → `Whisky Claude` |
| `CFBundleName` | `Notchy` → `WhiskyClaude` |
| `.NotchyNotchStatusChanged` notification name | `.WhiskyClaudeStatusChanged` |
| `BotFaceView.swift` → asset `face` | `ClaudeFaceView.swift` → asset `claude-face` |
| `Sounds/taskCompleted.mp3` | replaced with user-provided sound (Task 5) |
| `Sounds/waitingForInput.mp3` | replaced with user-provided sound (Task 5) |
| `/Applications/Notchy.app` | `/Applications/Whisky Claude.app` |
| Existing build output `Build/Notchy.app` | regenerated as `WhiskyClaude.app` |
| About-tab text "Notchy by Adam Lyttle" | "Whisky Claude — forked from Notchy by Adam Lyttle (MIT)" |

---

## Hard constraint: no menu bar interference

Notchy currently expands the pill from `notchWidth` to `notchWidth + 80` when "working" (NotchWindow.swift:180-182, `expandWithBounce`). On the M-series notch (~180px) that's 260px total — extends 40px to each side **into the menu bar area** where some apps (Xcode, Final Cut, Logic) render menu items that wrap past the notch.

Two fixes layered together:

1. **Hard cap horizontal width at `notchWidth`** in `expandWithBounce` + `applyHoverGrow`. The pill stays exactly the notch's width on top.
2. **Allow vertical growth downward** — the mascot can hop 20-30px below the notch into desktop area (no menu bar there, no app windows render at the very top of the screen by default).

Net effect: the mascot lives + animates entirely below or inside the notch outline, never side-extends into menu bar territory.

---

## Task 1: Extract + rename + first build

**Files:**
- Source: `~/Downloads/notchy-main.zip`
- Target dir: `~/Desktop/projects/whisky-claude/`

- [ ] **Step 1: Extract zip + relocate**

```bash
cd /tmp
unzip -o ~/Downloads/notchy-main.zip
# Move to project home, preserving the docs/plans dir we already created
rsync -av --exclude='docs/plans' /tmp/notchy-main/ ~/Desktop/projects/whisky-claude/
ls ~/Desktop/projects/whisky-claude/
```

Expected: project root has `Notchy/`, `Notchy.xcodeproj/`, `Build/`, `CLAUDE.md`, `LICENSE`, `README.md`, plus our `docs/plans/`.

- [ ] **Step 2: Wipe Notchy's prebuilt `Build/` (we'll regenerate)**

```bash
rm -rf ~/Desktop/projects/whisky-claude/Build
```

- [ ] **Step 3: Rename project directory + Xcode target name**

```bash
cd ~/Desktop/projects/whisky-claude
mv Notchy WhiskyClaude
mv Notchy.xcodeproj WhiskyClaude.xcodeproj
# Rename the schema xcsettings file referencing "Notchy"
find WhiskyClaude.xcodeproj -depth -name "*Notchy*" -execdir bash -c 'mv "$0" "${0//Notchy/WhiskyClaude}"' {} \;
```

- [ ] **Step 4: Search-and-replace `Notchy` → `WhiskyClaude` in project file + sources**

Note: case-sensitive `Notchy` → `WhiskyClaude` (preserves the existing CamelCase) and `notchy` → `whiskyclaude` for bundle id fragments.

```bash
cd ~/Desktop/projects/whisky-claude

# Project file (Xcode pbxproj uses both forms)
sed -i.bak 's/Notchy/WhiskyClaude/g' WhiskyClaude.xcodeproj/project.pbxproj
# Inside xcscheme files
find WhiskyClaude.xcodeproj -name "*.xcscheme" -exec sed -i.bak 's/Notchy/WhiskyClaude/g' {} \;

# Swift source: replace identifier references (keep DisplayName "Whisky Claude" for separate edit)
find WhiskyClaude -name "*.swift" -exec sed -i.bak 's/NotchyApp/WhiskyClaudeApp/g' {} \;
find WhiskyClaude -name "*.swift" -exec sed -i.bak 's/Notchy/WhiskyClaude/g' {} \;

# Notification name extension `.NotchyNotchStatusChanged` → `.WhiskyClaudeStatusChanged`
# (the rename above handles it via the substring replacement; verify)
grep -rn "NotchyNotchStatusChanged\|WhiskyClaudeNotchStatusChanged" WhiskyClaude/

# Clean up sed backups
find . -name "*.bak" -delete
```

Expected: grep shows the new identifier `WhiskyClaudeNotchStatusChanged` (notification name now wraps the substring replace).

- [ ] **Step 5: Fix file renames inside `WhiskyClaude/` folder**

```bash
cd ~/Desktop/projects/whisky-claude/WhiskyClaude
mv BotdockApp.swift WhiskyClaudeApp.swift
mv Notchy.entitlements WhiskyClaude.entitlements
# Inside project.pbxproj: update file references
cd ..
sed -i.bak 's|BotdockApp.swift|WhiskyClaudeApp.swift|g; s|Notchy.entitlements|WhiskyClaude.entitlements|g' WhiskyClaude.xcodeproj/project.pbxproj
rm WhiskyClaude.xcodeproj/project.pbxproj.bak
```

- [ ] **Step 6: Update bundle id + display name in `project.pbxproj`**

Open `WhiskyClaude.xcodeproj/project.pbxproj` and find lines like `PRODUCT_BUNDLE_IDENTIFIER = ...`. Replace with `com.ahmadsharaf.WhiskyClaude`. Also find any `PRODUCT_NAME` references and set to `WhiskyClaude`.

Use `grep` first to see the current state:

```bash
grep -n "PRODUCT_BUNDLE_IDENTIFIER\|PRODUCT_NAME\|INFOPLIST_KEY_CFBundleDisplayName\|MARKETING_VERSION" \
    ~/Desktop/projects/whisky-claude/WhiskyClaude.xcodeproj/project.pbxproj
```

Then update with `sed`:

```bash
cd ~/Desktop/projects/whisky-claude
sed -i.bak -E 's|PRODUCT_BUNDLE_IDENTIFIER = [^;]+;|PRODUCT_BUNDLE_IDENTIFIER = com.ahmadsharaf.WhiskyClaude;|g' WhiskyClaude.xcodeproj/project.pbxproj
sed -i.bak -E 's|INFOPLIST_KEY_CFBundleDisplayName = [^;]+;|INFOPLIST_KEY_CFBundleDisplayName = "Whisky Claude";|g' WhiskyClaude.xcodeproj/project.pbxproj
rm WhiskyClaude.xcodeproj/project.pbxproj.bak
```

- [ ] **Step 7: First build**

```bash
cd ~/Desktop/projects/whisky-claude
xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude \
    -configuration Debug -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`. The built app is at `build/Build/Products/Debug/WhiskyClaude.app`.

If the build fails, the most likely cause is the `pbxproj` rename leaving dangling references. Resolve by opening `WhiskyClaude.xcodeproj` in Xcode and letting it auto-fix file paths, then re-run.

- [ ] **Step 8: Smoke-test the build**

```bash
killall WhiskyClaude Notchy 2>/dev/null || true
open ~/Desktop/projects/whisky-claude/build/Build/Products/Debug/WhiskyClaude.app
sleep 2
ps aux | grep -v grep | grep WhiskyClaude
```

Expected: WhiskyClaude process is running. Pill visible in notch (still showing Notchy's bot face — we replace that in Task 4).

- [ ] **Step 9: Initialize git + first commit**

```bash
cd ~/Desktop/projects/whisky-claude
killall WhiskyClaude 2>/dev/null || true
# Fresh git repo (don't carry Notchy's history)
rm -rf .git
git init
git add .
git commit -m "chore: fork Notchy and rename to Whisky Claude

Forked from adamlyttleapps/notchy (MIT). See LICENSE for upstream notice.
All references renamed Notchy → WhiskyClaude. Bundle id: com.ahmadsharaf.WhiskyClaude.
Display name: Whisky Claude."
```

- [ ] **Step 10: Update LICENSE attribution + About tab**

In `WhiskyClaude/SettingsWindow.swift`, find `AboutTab` and update:

```swift
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("Whisky Claude")
                .font(.title2.bold())

            Text("Forked from Notchy by Adam Lyttle (MIT)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("github.com/adamlyttleapps/notchy") {
                if let url = URL(string: "https://github.com/adamlyttleapps/notchy") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

Append a NOTICE block to `LICENSE`:

```bash
cat >> ~/Desktop/projects/whisky-claude/LICENSE <<'EOF'

---

Whisky Claude is a modified fork of Notchy (https://github.com/adamlyttleapps/notchy).
Original copyright © Adam Lyttle, MIT licensed.
Modifications © 2026 Ahmad Sharaf.
EOF
```

- [ ] **Step 11: Commit**

```bash
cd ~/Desktop/projects/whisky-claude
git add WhiskyClaude/SettingsWindow.swift LICENSE
git commit -m "chore: update About tab + LICENSE attribution"
```

---

## Task 2: Constrain horizontal animation (the menu-bar-interference fix)

**Goal:** Cap pill width at `notchWidth` so apps with long menu bars (Xcode, Logic) don't have buttons obscured. Allow downward growth only.

**Files:**
- Modify: `WhiskyClaude/NotchWindow.swift`

- [ ] **Step 1: Find every place that adds horizontal padding**

```bash
cd ~/Desktop/projects/whisky-claude
grep -n "notchWidth + 80\|notchWidth + \|hoverGrowX\|earRadius" WhiskyClaude/NotchWindow.swift
```

Expected matches (line numbers approximate):
- `expandWithBounce` — uses `notchWidth + 80`
- `checkMouse` — uses `isExpanded ? notchWidth + 80 : notchWidth`
- `hoverGrowX` constant — adds `earRadius * 2` extra horizontal width

- [ ] **Step 2: Patch `expandWithBounce` to grow vertically only**

In `NotchWindow.swift`, locate `expandWithBounce()`. Change the `targetWidth` + `targetFrame` block:

Before:
```swift
let targetWidth: CGFloat = notchWidth + 80
var targetFrame = NSRect(
    x: screenFrame.midX - targetWidth / 2,
    y: screenFrame.maxY - notchHeight,
    width: targetWidth,
    height: notchHeight
)
```

After (keeps width at notchWidth, grows height downward):
```swift
// Whisky Claude: never grow horizontally past the notch outline (avoids
// covering menu bar items in apps with long menus).
let targetWidth: CGFloat = notchWidth
let extraHeight: CGFloat = 22   // room for the mascot to hop down
var targetFrame = NSRect(
    x: screenFrame.midX - targetWidth / 2,
    y: screenFrame.maxY - notchHeight - extraHeight,
    width: targetWidth,
    height: notchHeight + extraHeight
)
```

- [ ] **Step 3: Patch `collapse` to revert to the same downward-only geometry**

In `collapse()`, find the equivalent `targetFrame` block and replace with the un-extended `notchWidth × notchHeight` rect (Notchy's original collapsed shape is already correct — just verify after the change in step 2).

- [ ] **Step 4: Patch `checkMouse` to use notchWidth (no +80)**

Find:
```swift
let effectiveWidth = isExpanded ? notchWidth + 80 : notchWidth
```

Replace with:
```swift
let effectiveWidth = notchWidth
```

- [ ] **Step 5: Zero out `hoverGrowX` (no horizontal ear protrusion)**

Find:
```swift
private static let hoverGrowX: CGFloat = 0 + NotchPillView.earRadius * 2
```

Replace with:
```swift
// Whisky Claude: no horizontal grow on hover (keeps menu bar buttons accessible).
private static let hoverGrowX: CGFloat = 0
```

The ears were the visual flourish that protruded horizontally on hover; the bottom-extending body still works without them. (Optional: skip the ear-curve drawing entirely. Leave it for now — `earProtrusion = 0` makes it invisible.)

- [ ] **Step 6: Rebuild + visual check**

```bash
cd ~/Desktop/projects/whisky-claude
xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude -configuration Debug -derivedDataPath build build 2>&1 | tail -5
killall WhiskyClaude 2>/dev/null
open build/Build/Products/Debug/WhiskyClaude.app
```

Visual test: open Xcode (or any app with a long menu bar). Verify menu items past the notch ARE visible — the pill no longer extends over them. The mascot pill stays inside the notch outline horizontally.

- [ ] **Step 7: Commit**

```bash
git add WhiskyClaude/NotchWindow.swift
git commit -m "fix: cap pill at notchWidth so menu bar items are never hidden"
```

---

## Task 3: Replace bot face with Claude mascot

**Goal:** Swap Notchy's `BotFaceView` + `face` asset with a Claude character.

**Files:**
- Modify: `WhiskyClaude/BotFaceView.swift` → rename `ClaudeFaceView.swift` (rename happened in Task 1 search-replace; verify with `ls`)
- Modify: `WhiskyClaude/Assets.xcassets/face.imageset/` → swap PNGs

**Asset source:** for v1, use an SF Symbol (`sparkle` tinted Claude-orange #FF7700) so we don't need to ship a PNG. A real Claude character sprite can drop in later.

- [ ] **Step 1: Locate the existing face asset**

```bash
ls ~/Desktop/projects/whisky-claude/WhiskyClaude/Assets.xcassets/
ls ~/Desktop/projects/whisky-claude/WhiskyClaude/Assets.xcassets/face.imageset/ 2>/dev/null
```

Expected: `face.imageset/` exists with `face.png` + `face@2x.png` + `Contents.json`.

- [ ] **Step 2: Replace `BotFaceView`'s body with an SF Symbol that reacts to state**

The view is referenced from `NotchPillContent` in `NotchWindow.swift` (line ~594) as `BotFaceView()`. Rename + replace its body:

```swift
import SwiftUI

struct BotFaceView: View {
    // Drives sprite + tint from the global notch state machine.
    private var displayState: NotchDisplayState { .current }

    var body: some View {
        Image(systemName: symbolName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(tint)
            .symbolRenderingMode(.hierarchical)
            .clipped()
            .animation(.spring(duration: 0.3), value: displayState)
    }

    private var symbolName: String {
        switch displayState {
        case .idle:              return "sparkle"
        case .working:           return "sparkles"
        case .waitingForInput:   return "exclamationmark.bubble.fill"
        case .taskCompleted:     return "checkmark.seal.fill"
        }
    }

    private var tint: Color {
        switch displayState {
        case .idle:              return Color(red: 1.0, green: 0.47, blue: 0.0)  // #FF7700 Claude orange
        case .working:           return .cyan
        case .waitingForInput:   return .orange
        case .taskCompleted:     return .green
        }
    }
}

#Preview {
    BotFaceView()
        .frame(width: 30, height: 30)
        .padding()
        .background(Color.black)
}
```

(Filename stays `BotFaceView.swift` to minimize diff vs upstream — the view name is what matters. Rename optional.)

- [ ] **Step 3: Build + visual check**

```bash
cd ~/Desktop/projects/whisky-claude
xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude -configuration Debug -derivedDataPath build build 2>&1 | tail -5
killall WhiskyClaude 2>/dev/null
open build/Build/Products/Debug/WhiskyClaude.app
```

Visual: notch should show an orange sparkle. If a Claude session is active and working, it should switch to cyan sparkles.

- [ ] **Step 4: Commit**

```bash
git add WhiskyClaude/BotFaceView.swift
git commit -m "feat: replace bot face with Claude-orange SF Symbol mascot"
```

---

## Task 4: Jump animation on waitingForInput

**Goal:** When `NotchDisplayState.current == .waitingForInput`, the mascot bounces vertically (up 14pt → 0, repeat 3×). Same `CVDisplayLinkWrapper` pattern Notchy uses for expand-with-bounce.

**Files:**
- Create: `WhiskyClaude/MascotAnimator.swift`
- Modify: `WhiskyClaude/BotFaceView.swift`

- [ ] **Step 1: Write `MascotAnimator.swift`**

```swift
import Foundation
import CoreVideo
import QuartzCore

/// Frame-by-frame jump animator. Reports a Y-offset (points) per tick.
/// Uses CVDisplayLink for smooth refresh-rate-matched updates.
final class MascotAnimator {
    static let shared = MascotAnimator()

    var onTick: ((CGFloat) -> Void)?

    private var displayLink: CVDisplayLink?
    private var startTime: CFTimeInterval = 0
    private var duration: CFTimeInterval = 0
    private var jumpHeight: CGFloat = 0
    private var repeats: Int = 0

    private init() {}

    func jump(height: CGFloat = 14, perJump: CFTimeInterval = 0.35, repeats: Int = 3) {
        stop()
        self.jumpHeight = height
        self.duration = perJump * Double(repeats)
        self.repeats = repeats
        self.startTime = CACurrentMediaTime()
        startDisplayLink()
    }

    func bounce(height: CGFloat = 9, perJump: CFTimeInterval = 0.3, repeats: Int = 2) {
        jump(height: height, perJump: perJump, repeats: repeats)
    }

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        self.displayLink = link

        let opaque = Unmanaged.passRetained(self)
        CVDisplayLinkSetOutputCallback(link, { (_, _, _, _, _, userInfo) -> CVReturn in
            guard let userInfo else { return kCVReturnError }
            let me = Unmanaged<MascotAnimator>.fromOpaque(userInfo).takeUnretainedValue()
            let elapsed = CACurrentMediaTime() - me.startTime
            if elapsed >= me.duration {
                DispatchQueue.main.async { me.onTick?(0) }
                me.stop()
                Unmanaged<MascotAnimator>.fromOpaque(userInfo).release()
                return kCVReturnSuccess
            }
            let perJump = me.duration / Double(me.repeats)
            let local = elapsed.truncatingRemainder(dividingBy: perJump) / perJump
            let y = me.jumpHeight * CGFloat(sin(local * .pi))
            DispatchQueue.main.async { me.onTick?(y) }
            return kCVReturnSuccess
        }, opaque.toOpaque())

        CVDisplayLinkStart(link)
    }

    func stop() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            self.displayLink = nil
        }
    }
}
```

- [ ] **Step 2: Wire animator to `BotFaceView` via state transitions**

Update `BotFaceView.swift`:

```swift
import SwiftUI

struct BotFaceView: View {
    private var displayState: NotchDisplayState { .current }
    @State private var jumpY: CGFloat = 0

    var body: some View {
        Image(systemName: symbolName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(tint)
            .symbolRenderingMode(.hierarchical)
            .clipped()
            .offset(y: -jumpY)
            .animation(.spring(duration: 0.3), value: displayState)
            .onAppear {
                MascotAnimator.shared.onTick = { y in
                    DispatchQueue.main.async { jumpY = y }
                }
            }
            .onChange(of: displayState) { _, new in
                switch new {
                case .waitingForInput:  MascotAnimator.shared.jump()
                case .taskCompleted:    MascotAnimator.shared.bounce()
                default: break
                }
            }
    }

    private var symbolName: String {
        switch displayState {
        case .idle:              return "sparkle"
        case .working:           return "sparkles"
        case .waitingForInput:   return "exclamationmark.bubble.fill"
        case .taskCompleted:     return "checkmark.seal.fill"
        }
    }

    private var tint: Color {
        switch displayState {
        case .idle:              return Color(red: 1.0, green: 0.47, blue: 0.0)
        case .working:           return .cyan
        case .waitingForInput:   return .orange
        case .taskCompleted:     return .green
        }
    }
}
```

- [ ] **Step 3: Build + visual test**

```bash
cd ~/Desktop/projects/whisky-claude
xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude -configuration Debug -derivedDataPath build build 2>&1 | tail -5
killall WhiskyClaude 2>/dev/null
open build/Build/Products/Debug/WhiskyClaude.app
```

To trigger waitingForInput, open a Claude session in Notchy's panel and let it ask for input. The mascot should hop 3 times.

- [ ] **Step 4: Commit**

```bash
git add WhiskyClaude/MascotAnimator.swift WhiskyClaude/BotFaceView.swift
git commit -m "feat: mascot jumps 3× on waitingForInput, bounces 2× on taskCompleted"
```

---

## Task 5: Custom sounds (user-provided)

**Goal:** Replace Notchy's `taskCompleted.mp3` + `waitingForInput.mp3` with the user-provided custom attention sound + a custom done sound.

**Files:**
- Replace: `WhiskyClaude/Sounds/waitingForInput.mp3` (the "attention" sound)
- Replace: `WhiskyClaude/Sounds/taskCompleted.mp3` (the "done" sound)

> **Input needed from Ahmad:** path to the custom attention sound. Done sound is optional — can fall back to system Funk.aiff if not provided.

- [ ] **Step 1: Locate existing sounds**

```bash
ls -la ~/Desktop/projects/whisky-claude/WhiskyClaude/Sounds/
```

Expected: `taskCompleted.mp3` (10.4 KB) + `waitingForInput.mp3` (13.9 KB).

- [ ] **Step 2: Convert + install the user-provided attention sound**

Place the user's sound path in `$SRC`. Supported formats: `.mp3`, `.wav`, `.m4a`, `.aiff`, `.caf`. Use `afconvert` to normalize to MP3 if the source is something AVAudioPlayer can't play. (AVAudioPlayer handles all of the above natively, so conversion is only for size — usually skip.)

```bash
SRC="<USER_PROVIDES>"   # e.g. ~/Downloads/my-attention.wav
DEST=~/Desktop/projects/whisky-claude/WhiskyClaude/Sounds/waitingForInput.mp3
EXT="${SRC##*.}"

if [ "${EXT,,}" = "mp3" ] || [ "${EXT,,}" = "wav" ] || [ "${EXT,,}" = "m4a" ] || [ "${EXT,,}" = "aiff" ] || [ "${EXT,,}" = "caf" ]; then
    # Keep original; just copy with the Notchy-expected filename.
    cp "$SRC" "$DEST"
else
    # Re-encode to mp3
    afconvert -f mp4f -d aac "$SRC" "$DEST"
fi
ls -la "$DEST"
```

Note: filename stays `waitingForInput.mp3` to avoid changing Notchy's sound-loading code (`SessionStore.swift` references this filename — see Task 5 step 4 verification).

- [ ] **Step 3: Done sound — copy system Funk.aiff or user-provided**

```bash
# If user provides a done sound, use that; otherwise use Funk.
DONE_SRC="${DONE_SRC:-/System/Library/Sounds/Funk.aiff}"
cp "$DONE_SRC" ~/Desktop/projects/whisky-claude/WhiskyClaude/Sounds/taskCompleted.mp3
```

- [ ] **Step 4: Verify the sound-loading path in Notchy code**

```bash
grep -rn "taskCompleted\|waitingForInput\|playSound\|AVAudioPlayer" ~/Desktop/projects/whisky-claude/WhiskyClaude/
```

Confirm both filenames are referenced and the existing `AVAudioPlayer` call loads them from the bundle. (If Notchy uses a `Sound` enum, adapt accordingly.)

- [ ] **Step 5: Rebuild + audible check**

```bash
cd ~/Desktop/projects/whisky-claude
xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude -configuration Debug -derivedDataPath build build 2>&1 | tail -5
killall WhiskyClaude 2>/dev/null
open build/Build/Products/Debug/WhiskyClaude.app
```

Trigger a waitingForInput state (in a Claude session). The new sound should play.

- [ ] **Step 6: Commit**

```bash
cd ~/Desktop/projects/whisky-claude
git add WhiskyClaude/Sounds
git commit -m "feat: install custom attention + done sounds"
```

---

## Task 6: Claude Code event hooks → `WhiskyClaudeStatusChanged` notification

**Goal:** Outside of an active terminal session inside Notchy, Whisky Claude should still react to Claude Code activity in OTHER terminals (e.g., the user runs `claude` in iTerm). Use the Claude Code hook system: hooks write JSON event files into `~/.claude/pet-events/`, the app watches the directory and posts `.WhiskyClaudeStatusChanged` (already wired into Notchy's NotchWindow update logic).

**Files:**
- Create: `WhiskyClaude/EventWatcher.swift`
- Create: `~/.claude/scripts/wc-event.sh` (hook helper)
- Create: `scripts/install-hooks.sh`
- Modify: `WhiskyClaude/AppDelegate.swift` (call `EventWatcher.shared.start()`)

**Event JSON schema:**
```json
{
  "type": "attention" | "thinking" | "working" | "done" | "idle",
  "ts": "2026-05-21T14:32:00Z",
  "session_id": "...",
  "message": "..."
}
```

**Type → NotchDisplayState mapping:**

| event type | NotchDisplayState | hook |
|---|---|---|
| `thinking` | `.working` (no separate UI state) | `UserPromptSubmit` |
| `working` | `.working` | `PreToolUse` |
| `attention` | `.waitingForInput` | `Notification` |
| `done` | `.taskCompleted` | `Stop` |
| `idle` | `.idle` | synthetic timeout |

- [ ] **Step 1: Write `EventWatcher.swift`**

```swift
import Foundation
import Combine

final class EventWatcher {
    static let shared = EventWatcher()

    private let dir: URL
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private let queue = DispatchQueue(label: "com.ahmadsharaf.WhiskyClaude.eventWatcher")

    private struct Event: Decodable {
        let type: String
        let message: String?
    }

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        dir = home.appendingPathComponent(".claude/pet-events", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func start() {
        stop()
        fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("[WhiskyClaude] EventWatcher open failed: \(String(cString: strerror(errno)))")
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write], queue: queue
        )
        src.setEventHandler { [weak self] in self?.scan() }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fd, fd >= 0 { close(fd) }
            self?.fd = -1
        }
        source = src
        src.resume()
        scan()
        NSLog("[WhiskyClaude] watching \(dir.path)")
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func scan() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        let files = contents
            .filter { $0.pathExtension == "json" }
            .sorted {
                let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return a < b
            }
        for file in files {
            if let data = try? Data(contentsOf: file),
               let event = try? JSONDecoder().decode(Event.self, from: data) {
                DispatchQueue.main.async {
                    ExternalEventState.shared.apply(type: event.type)
                }
            }
            try? FileManager.default.removeItem(at: file)
        }
    }
}

/// Mirrors Notchy's NotchDisplayState but driven by external file events instead
/// of internal terminal-buffer parsing. ExternalEventState merges with
/// NotchDisplayState.current to drive UI.
@Observable
final class ExternalEventState {
    static let shared = ExternalEventState()
    private(set) var current: NotchDisplayState = .idle
    private var idleTimer: Timer?

    private init() {}

    func apply(type: String) {
        let state: NotchDisplayState
        switch type {
        case "thinking", "working": state = .working
        case "attention":           state = .waitingForInput
        case "done":                state = .taskCompleted
        default:                    state = .idle
        }
        self.current = state
        scheduleIdleDrift()
        NotificationCenter.default.post(name: .WhiskyClaudeStatusChanged, object: nil)
    }

    private func scheduleIdleDrift() {
        idleTimer?.invalidate()
        let delay: TimeInterval = (current == .waitingForInput || current == .taskCompleted) ? 5 : 30
        idleTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.current = .idle
            NotificationCenter.default.post(name: .WhiskyClaudeStatusChanged, object: nil)
        }
    }
}
```

- [ ] **Step 2: Modify `NotchDisplayState.current` to also consider ExternalEventState**

In `NotchWindow.swift`, find the `NotchDisplayState.current` static computed property and update:

```swift
static var current: NotchDisplayState {
    guard SettingsManager.shared.claudeIntegrationEnabled else { return .idle }
    let sessions = SessionStore.shared.sessions
    let external = ExternalEventState.shared.current

    // Priority: explicit external "attention"/"done" > internal session states.
    if external == .waitingForInput { return .waitingForInput }
    if external == .taskCompleted   { return .taskCompleted   }

    if sessions.contains(where: { $0.terminalStatus == .taskCompleted   }) { return .taskCompleted   }
    if sessions.contains(where: { $0.terminalStatus == .waitingForInput }) { return .waitingForInput }
    if sessions.contains(where: { $0.terminalStatus == .working         }) { return .working         }
    if external == .working { return .working }
    return .idle
}
```

- [ ] **Step 3: Start the watcher in `AppDelegate`**

Find `applicationDidFinishLaunching` in `WhiskyClaude/AppDelegate.swift` and add at the end:

```swift
EventWatcher.shared.start()
```

- [ ] **Step 4: Add `EventWatcher.swift` to the Xcode target**

The auto-detect by Xcode usually picks up new `.swift` files in the source tree. If not, manually add via Xcode UI — but the `project.pbxproj` auto-resolves on next `xcodebuild` since the source dir is referenced as a folder.

Verify:
```bash
cd ~/Desktop/projects/whisky-claude
xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude -configuration Debug -derivedDataPath build build 2>&1 | tail -10
```

If "EventWatcher not found", manually edit `WhiskyClaude.xcodeproj/project.pbxproj` to add a `PBXBuildFile` + `PBXFileReference` entry for `EventWatcher.swift`. Or just open the project in Xcode once to let it auto-add (`open WhiskyClaude.xcodeproj` → Xcode picks up the file → close).

- [ ] **Step 5: Write `~/.claude/scripts/wc-event.sh`**

```bash
#!/bin/bash
# Whisky Claude hook helper — writes a pet-event JSON for WhiskyClaude.app to consume.
set -u
EVENT_TYPE="${1:-idle}"
EVENTS_DIR="$HOME/.claude/pet-events"
mkdir -p "$EVENTS_DIR"

payload=$(cat 2>/dev/null || echo '{}')

if command -v jq >/dev/null 2>&1; then
    session_id=$(printf '%s' "$payload" | jq -r '.session_id // ""')
    message=$(printf '%s' "$payload" | jq -r '.message // ""')
else
    session_id=""
    message=""
fi

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
uuid=$(uuidgen | tr 'A-Z' 'a-z')

cat > "$EVENTS_DIR/$uuid.json" <<EOF
{
  "type": "$EVENT_TYPE",
  "ts": "$ts",
  "session_id": "$session_id",
  "message": $(printf '%s' "$message" | jq -Rs . 2>/dev/null || echo '""')
}
EOF
```

```bash
chmod +x ~/.claude/scripts/wc-event.sh
```

- [ ] **Step 6: Write `scripts/install-hooks.sh`**

```bash
#!/bin/bash
# Idempotently install Whisky Claude hooks into ~/.claude/settings.json.
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
HELPER="$HOME/.claude/scripts/wc-event.sh"

[ -f "$HELPER" ] || { echo "ERROR: $HELPER missing" >&2; exit 1; }

cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)"

tmp=$(mktemp)
jq '
  .hooks = (
    (.hooks // {}) |
    .Stop              = [{hooks: [{type: "command", command: "'"$HELPER"' done",       async: true}]}] |
    .Notification      = [{hooks: [{type: "command", command: "'"$HELPER"' attention",  async: true}]}] |
    .PreToolUse        = [{hooks: [{type: "command", command: "'"$HELPER"' working",    async: true}]}] |
    .UserPromptSubmit  = [{hooks: [{type: "command", command: "'"$HELPER"' thinking",   async: true}]}]
  )
' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"

echo "✓ Whisky Claude hooks installed"
```

- [ ] **Step 7: Run the installer + verify JSON**

```bash
chmod +x ~/Desktop/projects/whisky-claude/scripts/install-hooks.sh
~/Desktop/projects/whisky-claude/scripts/install-hooks.sh
jq empty ~/.claude/settings.json && echo "valid JSON"
```

- [ ] **Step 8: End-to-end smoke**

```bash
# Drop a manual attention event
echo '{"session_id":"smoke","message":"hi"}' > ~/.claude/pet-events/test.json
sleep 1
# Mascot should hop + play attention sound. Verify event was consumed:
ls ~/.claude/pet-events/    # should be empty
```

- [ ] **Step 9: Commit**

```bash
cd ~/Desktop/projects/whisky-claude
mkdir -p scripts/dot-claude
cp ~/.claude/scripts/wc-event.sh scripts/dot-claude/wc-event.sh
git add WhiskyClaude/EventWatcher.swift WhiskyClaude/NotchWindow.swift WhiskyClaude/AppDelegate.swift scripts/install-hooks.sh scripts/dot-claude/
git commit -m "feat: external Claude Code event hooks via ~/.claude/pet-events watcher"
```

---

## Task 7: Clap detection (opt-in via Settings)

**Goal:** When the user double-claps within 600ms, open Notchy's terminal panel + start a new Claude session (reuse existing `SessionStore.shared.addSession()` / `TerminalPanel.show()` paths).

**Files:**
- Create: `WhiskyClaude/ClapDetector.swift`
- Modify: `WhiskyClaude/SettingsManager.swift` (add `clapTriggerEnabled`, `clapSensitivity`)
- Modify: `WhiskyClaude/SettingsWindow.swift` (new "Voice Trigger" tab)
- Modify: `WhiskyClaude/Info.plist` (add `NSMicrophoneUsageDescription`)
- Modify: `WhiskyClaude/AppDelegate.swift` (wire detector start/stop)

**Privacy note**: Off by default. When ON, the mascot pill shows a small mic-icon overlay so the user always knows the app is listening. Audio is analyzed in-memory frame-by-frame and immediately discarded — never persisted, never transmitted.

- [ ] **Step 1: Add `NSMicrophoneUsageDescription` to `Info.plist`**

Open `WhiskyClaude/Info.plist` and add:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Whisky Claude listens for double-clap to open a Claude terminal session. Audio is analyzed locally and never stored or sent anywhere.</string>
```

- [ ] **Step 2: Extend `SettingsManager.swift`**

Add to `SettingsManager`:

```swift
var clapTriggerEnabled: Bool {
    didSet { UserDefaults.standard.set(clapTriggerEnabled, forKey: "clapTriggerEnabled") }
}

var clapSensitivity: Double {   // 0.0 (lenient) ... 1.0 (strict)
    didSet { UserDefaults.standard.set(clapSensitivity, forKey: "clapSensitivity") }
}
```

In `init()`:
```swift
if defaults.object(forKey: "clapTriggerEnabled") == nil { defaults.set(false, forKey: "clapTriggerEnabled") }
if defaults.object(forKey: "clapSensitivity") == nil   { defaults.set(0.5,   forKey: "clapSensitivity") }
clapTriggerEnabled = defaults.bool(forKey: "clapTriggerEnabled")
clapSensitivity    = defaults.double(forKey: "clapSensitivity")
```

- [ ] **Step 3: Write `ClapDetector.swift`**

```swift
import AVFoundation
import Combine

/// Detects two claps within a short window using amplitude + transient analysis.
/// - Each clap: sudden RMS spike above threshold for ~30-80ms.
/// - Double-clap: two such spikes within 100-600ms.
/// All audio analysis happens in-buffer; nothing is stored.
final class ClapDetector {
    static let shared = ClapDetector()

    var onDoubleClap: (() -> Void)?

    private let engine = AVAudioEngine()
    private var isRunning = false
    private var lastClapAt: CFTimeInterval = 0
    private let minGap: CFTimeInterval = 0.1
    private let maxGap: CFTimeInterval = 0.6
    /// Sensitivity 0..1 maps to RMS threshold 0.08 (strict) ... 0.02 (lenient).
    private var rmsThreshold: Float = 0.05

    private init() {}

    func setSensitivity(_ s: Double) {
        let clamped = max(0, min(1, s))
        rmsThreshold = Float(0.08 - 0.06 * clamped)
    }

    func start() {
        guard !isRunning else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        do {
            try engine.start()
            isRunning = true
            NSLog("[WhiskyClaude] ClapDetector started")
        } catch {
            NSLog("[WhiskyClaude] ClapDetector start failed: \(error)")
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        NSLog("[WhiskyClaude] ClapDetector stopped")
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let chans = buffer.floatChannelData else { return }
        let n = Int(buffer.frameLength)
        let samples = chans[0]
        var sumSq: Float = 0
        for i in 0..<n { sumSq += samples[i] * samples[i] }
        let rms = sqrt(sumSq / Float(n))

        guard rms > rmsThreshold else { return }
        let now = CACurrentMediaTime()
        let dt = now - lastClapAt
        if dt > minGap && dt < maxGap {
            DispatchQueue.main.async { [weak self] in
                self?.onDoubleClap?()
            }
            lastClapAt = 0   // reset so a third clap doesn't immediately re-trigger
        } else {
            lastClapAt = now
        }
    }
}
```

- [ ] **Step 4: Wire it from `AppDelegate`**

In `applicationDidFinishLaunching`, after `EventWatcher.shared.start()`:

```swift
ClapDetector.shared.setSensitivity(SettingsManager.shared.clapSensitivity)
ClapDetector.shared.onDoubleClap = { [weak self] in
    NSLog("[WhiskyClaude] double-clap detected — opening Claude terminal")
    // Reuse Notchy's existing panel-open + new-session paths.
    // SessionStore.shared.addSession(projectPath: nil) creates a fresh tab.
    SessionStore.shared.addSession(projectPath: NSHomeDirectory())
    self?.terminalPanel?.show()    // assuming AppDelegate already holds terminalPanel
}
if SettingsManager.shared.clapTriggerEnabled {
    ClapDetector.shared.start()
}
```

> Note: The exact API names (`addSession`, `terminalPanel`) need verification against Notchy's current `SessionStore` / `AppDelegate`. Confirm during execution and adjust. If the method signatures differ, use what's already there.

- [ ] **Step 5: Observe `clapTriggerEnabled` and start/stop the detector**

Inside `SettingsManager.swift`'s `clapTriggerEnabled.didSet`, add:

```swift
if clapTriggerEnabled {
    ClapDetector.shared.start()
} else {
    ClapDetector.shared.stop()
}
```

(Or post a notification AppDelegate observes — pick whichever is closer to Notchy's existing pattern for `showNotch`.)

- [ ] **Step 6: Add "Voice Trigger" tab to Settings**

In `SettingsWindow.swift`, add to `SettingsTab`:

```swift
case voice = "Voice"
```

```swift
var icon: String {
    switch self {
    case .general: return "gearshape"
    case .integrations: return "puzzlepiece"
    case .voice: return "mic"
    case .about: return "info.circle"
    }
}
```

Add a `VoiceTab` view:

```swift
struct VoiceTab: View {
    @Bindable private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Toggle(isOn: $settings.clapTriggerEnabled) {
                Text("Double-clap to open Claude")
                Text("Listens to the microphone. Audio is analyzed locally and never stored.")
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
                    .onChange(of: settings.clapSensitivity) { _, new in
                        ClapDetector.shared.setSensitivity(new)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
```

Add to `SettingsContentView`'s `TabView`:

```swift
VoiceTab()
    .tabItem { Label(SettingsTab.voice.rawValue, systemImage: SettingsTab.voice.icon) }
    .tag(SettingsTab.voice)
```

- [ ] **Step 7: Build + grant mic permission + smoke test**

```bash
cd ~/Desktop/projects/whisky-claude
xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude -configuration Debug -derivedDataPath build build 2>&1 | tail -5
killall WhiskyClaude 2>/dev/null
open build/Build/Products/Debug/WhiskyClaude.app
```

In the app's Settings → Voice tab, flip on "Double-clap to open Claude". macOS will prompt for microphone permission — allow. Then clap twice within 600ms — a new Claude terminal should open in Notchy's panel.

- [ ] **Step 8: Commit**

```bash
git add WhiskyClaude/ClapDetector.swift WhiskyClaude/SettingsManager.swift WhiskyClaude/SettingsWindow.swift WhiskyClaude/AppDelegate.swift WhiskyClaude/Info.plist
git commit -m "feat: opt-in double-clap to open a Claude terminal session"
```

---

## Task 8: Install to /Applications + login item

**Goal:** Build Release, ad-hoc codesign, copy to /Applications/, register as Login Item so it's "always open".

**Files:**
- Create: `scripts/install.sh`
- Create: `scripts/uninstall.sh`

- [ ] **Step 1: Write `scripts/install.sh`**

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ build Release"
xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude -configuration Release -derivedDataPath build clean build | tail -5

APP="build/Build/Products/Release/WhiskyClaude.app"
[ -d "$APP" ] || { echo "build output missing"; exit 1; }

# Rename product on disk so /Applications/ entry reads as "Whisky Claude.app"
RENAMED="build/Build/Products/Release/Whisky Claude.app"
rm -rf "$RENAMED"
cp -R "$APP" "$RENAMED"

echo "→ ad-hoc codesign"
codesign --force --deep --sign - "$RENAMED"

echo "→ install to /Applications"
osascript -e 'tell application "WhiskyClaude" to quit' 2>/dev/null || true
osascript -e 'tell application "Whisky Claude" to quit' 2>/dev/null || true
sleep 0.5
rm -rf "/Applications/Whisky Claude.app"
cp -R "$RENAMED" "/Applications/"

echo "→ install hooks + helper"
mkdir -p ~/.claude/scripts
cp scripts/dot-claude/wc-event.sh ~/.claude/scripts/wc-event.sh
chmod +x ~/.claude/scripts/wc-event.sh
scripts/install-hooks.sh

echo "→ launch"
open "/Applications/Whisky Claude.app"

echo "→ register login item"
osascript <<'EOF'
tell application "System Events"
    if not (exists login item "Whisky Claude") then
        make login item at end with properties {path:"/Applications/Whisky Claude.app", hidden:false}
    end if
end tell
EOF

echo "✓ installed, running, will auto-launch at login"
```

- [ ] **Step 2: Write `scripts/uninstall.sh`**

```bash
#!/bin/bash
set -uo pipefail

osascript -e 'tell application "Whisky Claude" to quit' 2>/dev/null || true
sleep 0.5
rm -rf "/Applications/Whisky Claude.app"

# Remove our 4 hooks (preserve any others)
if [ -f ~/.claude/settings.json ]; then
    cp ~/.claude/settings.json ~/.claude/settings.json.bak.$(date +%s)
    tmp=$(mktemp)
    jq 'del(.hooks.Stop, .hooks.Notification, .hooks.PreToolUse, .hooks.UserPromptSubmit) |
        if (.hooks // {}) == {} then del(.hooks) else . end' \
       ~/.claude/settings.json > "$tmp"
    mv "$tmp" ~/.claude/settings.json
fi
rm -f ~/.claude/scripts/wc-event.sh

osascript <<'EOF' 2>/dev/null
tell application "System Events"
    if exists login item "Whisky Claude" then delete login item "Whisky Claude"
end tell
EOF

echo "✓ uninstalled"
```

- [ ] **Step 3: Run installer**

```bash
chmod +x ~/Desktop/projects/whisky-claude/scripts/install.sh ~/Desktop/projects/whisky-claude/scripts/uninstall.sh
~/Desktop/projects/whisky-claude/scripts/install.sh
```

- [ ] **Step 4: Verify**

```bash
ls "/Applications/Whisky Claude.app/Contents/MacOS/"
codesign -dv "/Applications/Whisky Claude.app" 2>&1 | head -5
ps aux | grep -v grep | grep -i "Whisky"
osascript -e 'tell application "System Events" to get name of every login item' | tr ',' '\n' | grep -i Whisky
```

- [ ] **Step 5: Reboot test (optional)**

Reboot — verify Whisky Claude reappears in the notch automatically.

- [ ] **Step 6: Commit**

```bash
cd ~/Desktop/projects/whisky-claude
git add scripts/install.sh scripts/uninstall.sh
git commit -m "feat: install/uninstall scripts with login item registration"
```

---

## Task 9: Polish + ARCHITECTURE.md

- [ ] **Step 1: Write `docs/ARCHITECTURE.md`** — what we changed vs upstream Notchy, file-by-file. Cover: `NotchWindow` horizontal-cap diff, `BotFaceView` reskin, `EventWatcher`, `ClapDetector`, new Settings tab.
- [ ] **Step 2: Final commit + push** (optional — no remote yet; user adds one when ready)

---

## Risks + open questions

1. **Project file `pbxproj` rename brittleness** — Task 1 step 4 uses sed across `project.pbxproj`. If the build fails after the rename, open `WhiskyClaude.xcodeproj` in Xcode once and let it self-heal file references. Worst case: open the Notchy project fresh, rename Target via Xcode UI (Project Navigator → click target name → rename), then export.

2. **SessionStore API surface** — Task 7 assumes `SessionStore.shared.addSession(projectPath:)` exists. Verify during execution (`grep -n "addSession\|sessions.append" WhiskyClaude/SessionStore.swift`). If the signature differs, adapt the call site.

3. **Microphone permission** — first-run prompt requires the user to approve in System Settings. Settings tab message clarifies what's being analyzed and that nothing is stored.

4. **Clap false positives** — pure amplitude threshold is imperfect (cabinet slams, hand-claps from neighbors, etc.). The "two within 600ms" gate cuts most of them. If false-positive rate is bad in practice, we can add a frequency-domain check (claps are broadband; speech/music has more concentrated low-mid energy) in a v2. For v1 the amplitude+timing gate is fine.

5. **Naming preservation** — we keep filenames `BotFaceView.swift` and `Sounds/waitingForInput.mp3` to minimize the diff vs upstream Notchy. This makes future merges from upstream easier (if Adam Lyttle ships a Notchy update we want).

6. **Reference clone** at `~/Desktop/projects/_external/notchy/` is left untouched — it's the upstream-diff anchor. Don't modify it.

---

## Spec coverage check (self-review)

| Spec requirement | Task(s) |
|---|---|
| Fork Notchy, rename to "Whisky Claude" | Task 1 |
| Claude mascot in the notch | Task 3 |
| Jumps + plays custom sound on attention | Task 4 + Task 5 |
| No menu bar interference (hard constraint) | Task 2 |
| Settings panel for runtime control | Task 7 step 6 (extends existing) |
| Clap to open Claude terminal | Task 7 |
| Always running + auto-launch | Task 8 (login item) |
| External Claude Code session integration | Task 6 (hook watcher) |

No gaps.

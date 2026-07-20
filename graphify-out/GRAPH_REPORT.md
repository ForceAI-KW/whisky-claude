# Graph Report - whisky-claude  (2026-07-20)

## Corpus Check
- 23 files · ~94,409 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 347 nodes · 391 edges · 25 communities (18 shown, 7 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 4 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d9af120f`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]

## God Nodes (most connected - your core abstractions)
1. `AppDelegate` - 15 edges
2. `Whisky Claude Implementation Plan (fork-and-modify)` - 14 edges
3. `Task 1: Extract + rename + first build` - 14 edges
4. `Task 7: Clap detection (opt-in via Settings)` - 13 edges
5. `Auto-Update (Sparkle) Implementation Plan` - 12 edges
6. `Task 6: Claude Code event hooks → `WhiskyClaudeStatusChanged` notification` - 12 edges
7. `MascotWindow` - 11 edges
8. `Whisky Claude` - 11 edges
9. `Whisky Claude — Architecture Reference` - 11 edges
10. `KeywordRecognizer` - 10 edges

## Surprising Connections (you probably didn't know these)
- `MascotContent` --inherits--> `View`  [EXTRACTED]
  WhiskyClaude/MascotWindow.swift →   _Bridges community 12 → community 2_
- `AppDelegate` --inherits--> `NSObject`  [EXTRACTED]
  WhiskyClaude/AppDelegate.swift →   _Bridges community 13 → community 4_
- `ClapDetector` --inherits--> `NSObject`  [EXTRACTED]
  WhiskyClaude/ClapDetector.swift →   _Bridges community 13 → community 6_

## Communities (25 total, 7 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.05
Nodes (42): code:bash (ls ~/Desktop/projects/whisky-claude/WhiskyClaude/Assets.xcas), code:swift (import SwiftUI), code:bash (cd ~/Desktop/projects/whisky-claude), code:bash (git add WhiskyClaude/BotFaceView.swift), code:swift (import Foundation), code:swift (import SwiftUI), code:bash (cd ~/Desktop/projects/whisky-claude), code:bash (git add WhiskyClaude/MascotAnimator.swift WhiskyClaude/BotFa) (+34 more)

### Community 1 - "Community 1"
Cohesion: 0.05
Nodes (36): Auto-Update (Sparkle) Implementation Plan, code:block1 (/* Begin XCRemoteSwiftPackageReference section */), code:bash (git add WhiskyClaude.xcodeproj/project.pbxproj), code:swift (/// Sparkle updater — automatic background checks + the "Che), code:swift (let checkForUpdates = NSMenuItem(title: "Check for Updates…"), code:swift (@objc private func checkForUpdatesAction(_ sender: Any?) {), code:bash (xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyCla), code:bash (git add WhiskyClaude/AppDelegate.swift) (+28 more)

### Community 2 - "Community 2"
Cohesion: 0.14
Nodes (8): NSPanel, MascotAnimationState, MascotBounceKind, attention, done, MascotContent, MascotWindow, NSScreen

### Community 3 - "Community 3"
Cohesion: 0.13
Nodes (11): Decodable, Equatable, AttentionKind, idle, taskCompleted, waitingForInput, working, AttentionState (+3 more)

### Community 4 - "Community 4"
Cohesion: 0.16
Nodes (4): NSApplicationDelegate, AppDelegate, SUUpdaterBridge, MenuBarIcon

### Community 5 - "Community 5"
Cohesion: 0.11
Nodes (17): Build + install, Clap-trigger pipeline, code:block1 (WhiskyClaude/), code:json ({), code:block3 (xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyCla), code:block4 (WhiskyClaude/Sounds/), Event JSON schema, External IPC: ~/.claude/pet-events/ (+9 more)

### Community 6 - "Community 6"
Cohesion: 0.13
Nodes (8): CaseIterable, SNResultsObserving, String, ClapDetector, SettingsTab, about, general, voice

### Community 7 - "Community 7"
Cohesion: 0.12
Nodes (15): code:bash (git clone https://github.com/ForceAI-KW/whisky-claude.git), code:block2 (┌─ Claude Code session anywhere ──────────────────┐), Contributing, Credits, How it works, Install, License, Persistent permissions (v1.2.0+) (+7 more)

### Community 8 - "Community 8"
Cohesion: 0.12
Nodes (15): App side, Architecture, Components (units), Context / constraints, Decision, Docs (parity, same session), Error handling, Feed / hosting (+7 more)

### Community 9 - "Community 9"
Cohesion: 0.14
Nodes (14): code:bash (cd /tmp), code:bash (cd ~/Desktop/projects/whisky-claude), code:swift (struct AboutTab: View {), code:bash (cat >> ~/Desktop/projects/whisky-claude/LICENSE <<'EOF'), code:bash (cd ~/Desktop/projects/whisky-claude), code:bash (rm -rf ~/Desktop/projects/whisky-claude/Build), code:bash (cd ~/Desktop/projects/whisky-claude), code:bash (cd ~/Desktop/projects/whisky-claude) (+6 more)

### Community 10 - "Community 10"
Cohesion: 0.22
Nodes (6): NSImageView, NSViewRepresentable, ClawdGIFView, ClawdPose, Coordinator, FittedImageView

### Community 11 - "Community 11"
Cohesion: 0.17
Nodes (12): code:json ({), code:swift (import Foundation), code:swift (static var current: NotchDisplayState {), code:swift (EventWatcher.shared.start()), code:bash (cd ~/Desktop/projects/whisky-claude), code:bash (#!/bin/bash), code:bash (chmod +x ~/.claude/scripts/wc-event.sh), code:bash (#!/bin/bash) (+4 more)

### Community 12 - "Community 12"
Cohesion: 0.29
Nodes (8): View, AboutTab, GeneralTab, ListeningPill, SettingsContentView, SettingsWindowController, SoundPickerRow, VoiceTab

### Community 14 - "Community 14"
Cohesion: 0.18
Nodes (9): Architecture (inherited from Notchy, modifications in progress), Auto-update (Sparkle), Build, code:bash (xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyCla), Dependencies, Entitlements + TCC permissions, Modifications planned, Standing rules from global config (cross-project) (+1 more)

### Community 15 - "Community 15"
Cohesion: 0.2
Nodes (10): code:bash (cd ~/Desktop/projects/whisky-claude), code:swift (let targetWidth: CGFloat = notchWidth + 80), code:swift (// Whisky Claude: never grow horizontally past the notch out), code:swift (let effectiveWidth = isExpanded ? notchWidth + 80 : notchWid), code:swift (let effectiveWidth = notchWidth), code:swift (private static let hoverGrowX: CGFloat = 0 + NotchPillView.e), code:swift (// Whisky Claude: no horizontal grow on hover (keeps menu ba), code:bash (cd ~/Desktop/projects/whisky-claude) (+2 more)

### Community 17 - "Community 17"
Cohesion: 0.22
Nodes (8): code:bash (./scripts/release.sh <version>      # e.g. ./scripts/release), code:bash (build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_), code:bash (build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_), Manual update test (do this after the first release), Notarization / Gatekeeper, One command, Releasing Whisky Claude, The signing keys (one-time)

### Community 18 - "Community 18"
Cohesion: 0.25
Nodes (7): code:bash (# Confirm the bundle's signature is ad-hoc (not signed by an), Reporting a vulnerability, Security policy, Threat model, Verifying a build, What we don't do, What Whisky Claude touches on your system

### Community 23 - "Community 23"
Cohesion: 0.5
Nodes (3): Attribution, Raw source assets, Swapping in your own

## Knowledge Gaps
- **164 isolated node(s):** `about`, `general`, `voice`, `attention`, `done` (+159 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Whisky Claude Implementation Plan (fork-and-modify)` connect `Community 0` to `Community 9`, `Community 11`, `Community 15`?**
  _High betweenness centrality (0.045) - this node is a cross-community bridge._
- **Why does `AppDelegate` connect `Community 4` to `Community 13`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Why does `ClapDetector` connect `Community 6` to `Community 13`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **What connects `about`, `general`, `voice` to the rest of the system?**
  _164 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Community 2` be split into smaller, more focused modules?**
  _Cohesion score 0.14 - nodes in this community are weakly interconnected._
# Auto-Update (Sparkle) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:executing-plans or subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add in-app auto-update to Whisky Claude via Sparkle, with a local `release.sh` that publishes signed builds to GitHub Releases + an `appcast.xml` feed.

**Architecture:** Sparkle 2.x (SPM, the project's FIRST SPM package) drives update checks; an `SPUStandardUpdaterController` in `AppDelegate` provides automatic checks + a "Check for Updates…" menu item; releases are built/signed/published locally by `scripts/release.sh`; the feed is `appcast.xml` at repo root served via raw.githubusercontent.com; binaries are GitHub Release assets; EdDSA keys sign each update (private key in Keychain).

**Tech Stack:** Swift/AppKit, Sparkle 2.x, Xcode 16 (objectVersion 77, generated Info.plist), `gh` CLI, bash.

**Reality notes (verified 2026-06-06):**
- No existing SPM deps — `Package.resolved` empty, no `import SwiftTerm`. Sparkle is the first package → its pbxproj objects are added from scratch.
- Generated Info.plist (`GENERATE_INFOPLIST_FILE = YES`) → Sparkle keys via `INFOPLIST_KEY_*` build settings.
- `MARKETING_VERSION = 1.2.0`, `CURRENT_PROJECT_VERSION = 3`, bundle id `com.ahmadsharaf.WhiskyClaude`, not sandboxed, `LSUIElement = YES`.

---

## File structure

- Modify `WhiskyClaude.xcodeproj/project.pbxproj` — add Sparkle SPM package + product dep + Frameworks build file; add `INFOPLIST_KEY_SUFeedURL` + `INFOPLIST_KEY_SUPublicEDKey` to both build configs; bump version build settings (release.sh does the bumps later).
- Modify `WhiskyClaude/AppDelegate.swift` — own `SPUStandardUpdaterController`, add "Check for Updates…" menu item.
- Modify `WhiskyClaude/SettingsManager.swift` + `WhiskyClaude/SettingsWindow.swift` — "Automatically check for updates" toggle.
- Create `appcast.xml` (repo root) — the feed.
- Create `scripts/release.sh` — publish pipeline.
- Create `docs/RELEASING.md` — runbook.
- Modify `README.md`, `CLAUDE.md` — docs parity.

---

## Task 1: Add Sparkle SPM package to the Xcode project

**Files:** Modify `WhiskyClaude.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add the four pbxproj objects.** In `project.pbxproj`:

  (a) New `XCRemoteSwiftPackageReference` (add a `/* Begin/End XCRemoteSwiftPackageReference section */` near the other package-less sections):
  ```
  /* Begin XCRemoteSwiftPackageReference section */
  		SP000001 /* XCRemoteSwiftPackageReference "Sparkle" */ = {
  			isa = XCRemoteSwiftPackageReference;
  			repositoryURL = "https://github.com/sparkle-project/Sparkle";
  			requirement = {
  				kind = upToNextMajorVersion;
  				minimumVersion = 2.6.0;
  			};
  		};
  /* End XCRemoteSwiftPackageReference section */
  ```
  (b) New `XCSwiftPackageProductDependency`:
  ```
  /* Begin XCSwiftPackageProductDependency section */
  		SP000002 /* Sparkle */ = {
  			isa = XCSwiftPackageProductDependency;
  			package = SP000001 /* XCRemoteSwiftPackageReference "Sparkle" */;
  			productName = Sparkle;
  		};
  /* End XCSwiftPackageProductDependency section */
  ```
  (c) New `PBXBuildFile` (in the PBXBuildFile section):
  ```
  		SP000003 /* Sparkle in Frameworks */ = {isa = PBXBuildFile; productRef = SP000002 /* Sparkle */; };
  ```
  (d) Wire references:
  - PBXProject `packageReferences = ( SP000001 /* … "Sparkle" */, );`
  - target `packageProductDependencies = ( SP000002 /* Sparkle */, );`
  - Frameworks build phase `files = ( SP000003 /* Sparkle in Frameworks */, );`

  (IDs `SP00000x` are placeholders — use any unique 24-hex-uppercase IDs not already present.)

- [ ] **Step 2: Resolve + build to validate.**

  Run:
  ```bash
  cd ~/Desktop/projects/whisky-claude
  xcodebuild -project WhiskyClaude.xcodeproj -resolvePackageDependencies 2>&1 | tail -5
  xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude -configuration Debug \
    -derivedDataPath build CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "Sparkle|error:|BUILD SUCCEEDED|BUILD FAILED" | tail -8
  ```
  Expected: `Package.resolved` now pins Sparkle; `BUILD SUCCEEDED`. If the pbxproj edit is malformed (`BUILD FAILED`/"unable to read project"), `git checkout WhiskyClaude.xcodeproj/project.pbxproj` and retry.

- [ ] **Step 3: Commit.**
  ```bash
  git add WhiskyClaude.xcodeproj/project.pbxproj WhiskyClaude.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
  git commit -m "build: add Sparkle 2.x via SPM (first package dependency)"
  ```

## Task 2: Generate the EdDSA signing keys

**Files:** none committed (keys live in Keychain). Produces the public key string for Task 3.

- [ ] **Step 1: Locate Sparkle's `generate_keys`** (resolved by Task 1):
  ```bash
  GEN=$(find ~/Library/Developer/Xcode/DerivedData ~/Desktop/projects/whisky-claude/build -name generate_keys -path "*Sparkle*" 2>/dev/null | head -1)
  echo "$GEN"
  ```
  If empty: download `Sparkle-2.6.x.tar.xz` from github.com/sparkle-project/Sparkle/releases, extract, use its `bin/generate_keys`.

- [ ] **Step 2: Generate keys (idempotent — stores private key in Keychain, prints public key):**
  ```bash
  "$GEN"   # prints: "<base64 public key>" and stores private key in login Keychain item "https://sparkle-project.org"
  ```
  Copy the printed public key (base64). If a key already exists it prints the existing public key. **Back it up** (see RELEASING.md).

- [ ] **Step 3:** No commit (no repo changes). Record the public key for Task 3.

## Task 3: Inject Sparkle Info.plist keys

**Files:** Modify `WhiskyClaude.xcodeproj/project.pbxproj` (both Debug + Release `buildSettings`)

- [ ] **Step 1:** Add to BOTH configurations' `buildSettings` (next to the existing `INFOPLIST_KEY_*`):
  ```
  INFOPLIST_KEY_SUFeedURL = "https://raw.githubusercontent.com/ForceAI-KW/whisky-claude/master/appcast.xml";
  INFOPLIST_KEY_SUPublicEDKey = "<PUBLIC_KEY_FROM_TASK_2>";
  ```

- [ ] **Step 2: Build + verify the keys land in the built Info.plist.**
  ```bash
  xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude -configuration Debug \
    -derivedDataPath build CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "BUILD SUCCEEDED|error:" | tail -3
  plutil -extract SUFeedURL raw build/Build/Products/Debug/WhiskyClaude.app/Contents/Info.plist
  plutil -extract SUPublicEDKey raw build/Build/Products/Debug/WhiskyClaude.app/Contents/Info.plist
  ```
  Expected: the feed URL + public key print.

- [ ] **Step 3: Commit.**
  ```bash
  git add WhiskyClaude.xcodeproj/project.pbxproj
  git commit -m "build: Sparkle SUFeedURL + SUPublicEDKey in Info.plist"
  ```

## Task 4: Wire the updater + "Check for Updates…" menu item

**Files:** Modify `WhiskyClaude/AppDelegate.swift`

- [ ] **Step 1:** At top of `AppDelegate.swift`, `import Sparkle`. Add a stored property:
  ```swift
  /// Sparkle updater — automatic background checks + the "Check for Updates…" item.
  private let updaterController = SPUStandardUpdaterController(startingUpdater: true,
                                                              updaterDelegate: nil,
                                                              userDriverDelegate: nil)
  ```

- [ ] **Step 2:** In `buildMenu()`, add (above the Quit item):
  ```swift
  let checkForUpdates = NSMenuItem(title: "Check for Updates…",
                                   action: #selector(checkForUpdatesAction(_:)),
                                   keyEquivalent: "")
  checkForUpdates.target = self
  menu.addItem(checkForUpdates)
  menu.addItem(.separator())
  ```
  And the action:
  ```swift
  @objc private func checkForUpdatesAction(_ sender: Any?) {
      updaterController.checkForUpdates(sender)
  }
  ```

- [ ] **Step 3: Build + run; manually verify.**
  ```bash
  xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude -configuration Debug \
    -derivedDataPath build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "BUILD SUCCEEDED|error:" | tail -3
  pkill -9 -x WhiskyClaude; open build/Build/Products/Debug/WhiskyClaude.app
  ```
  Manual: click the menu-bar icon → "Check for Updates…". Since `appcast.xml` doesn't exist yet (404), Sparkle shows an error dialog — acceptable at this stage (proves wiring). No crash.

- [ ] **Step 4: Commit.**
  ```bash
  git add WhiskyClaude/AppDelegate.swift
  git commit -m "feat(update): Sparkle updater + Check for Updates menu item"
  ```

## Task 5: "Automatically check for updates" toggle in Settings

**Files:** Modify `WhiskyClaude/SettingsManager.swift`, `WhiskyClaude/SettingsWindow.swift`, `WhiskyClaude/AppDelegate.swift`

- [ ] **Step 1:** Sparkle already persists `automaticallyChecksForUpdates` in UserDefaults; bind a SwiftUI `Toggle` to it. In `SettingsWindow.swift` General section add:
  ```swift
  Toggle("Automatically check for updates", isOn: Binding(
      get: { SUUpdaterBridge.shared.autoCheck },
      set: { SUUpdaterBridge.shared.autoCheck = $0 }))
  ```
  (Requires `import Sparkle` in SettingsWindow.swift.)

- [ ] **Step 2:** Add a tiny bridge so the toggle reaches the updater instance. In `AppDelegate.swift`, after creating `updaterController`, set `SUUpdaterBridge.shared.updater = updaterController.updater`. Create the bridge (new small type in AppDelegate.swift or its own file):
  ```swift
  final class SUUpdaterBridge {
      static let shared = SUUpdaterBridge()
      weak var updater: SPUUpdater?
      var autoCheck: Bool {
          get { updater?.automaticallyChecksForUpdates ?? true }
          set { updater?.automaticallyChecksForUpdates = newValue }
      }
  }
  ```

- [ ] **Step 3: Build + verify toggle reflects/sets state.**
  ```bash
  xcodebuild … build 2>&1 | grep -E "BUILD SUCCEEDED|error:" | tail -3
  ```
  Manual: open Settings → General → toggle exists, flipping it persists across relaunch.

- [ ] **Step 4: Commit.**
  ```bash
  git add WhiskyClaude/AppDelegate.swift WhiskyClaude/SettingsWindow.swift WhiskyClaude/SettingsManager.swift
  git commit -m "feat(update): auto-check-for-updates toggle in Settings"
  ```

## Task 6: appcast.xml skeleton

**Files:** Create `appcast.xml`

- [ ] **Step 1:** Create `appcast.xml` at repo root:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
      <title>Whisky Claude</title>
      <link>https://raw.githubusercontent.com/ForceAI-KW/whisky-claude/master/appcast.xml</link>
      <description>Whisky Claude updates</description>
      <language>en</language>
      <!-- release.sh prepends <item> entries here -->
    </channel>
  </rss>
  ```

- [ ] **Step 2: Validate + commit.**
  ```bash
  xmllint --noout appcast.xml && echo "valid XML"
  git add appcast.xml && git commit -m "feat(update): appcast.xml feed skeleton"
  git push origin feat/auto-update   # so SUFeedURL (raw master) resolves after merge
  ```
  (The feed only resolves once on `master`; full end-to-end test happens after merge in Task 9.)

## Task 7: scripts/release.sh

**Files:** Create `scripts/release.sh`

- [ ] **Step 1:** Create `scripts/release.sh` (chmod +x):
  ```bash
  #!/bin/bash
  # Whisky Claude — cut + publish a release that Sparkle can auto-update to.
  # Usage: ./scripts/release.sh <version>   e.g. ./scripts/release.sh 1.3.0
  set -euo pipefail
  cd "$(dirname "$0")/.."

  VERSION="${1:?usage: release.sh <version> (e.g. 1.3.0)}"
  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "✗ version must be semver"; exit 1; }
  [ -z "$(git status --porcelain)" ] || { echo "✗ working tree not clean"; exit 1; }

  PROJ="WhiskyClaude.xcodeproj"; SCHEME="WhiskyClaude"; APPNAME="Whisky Claude"
  REPO="ForceAI-KW/whisky-claude"
  REL="build/Build/Products/Release"
  ZIP="WhiskyClaude-${VERSION}.zip"

  # 1. version bump (monotonic build number = existing + 1)
  BUILD=$(( $(sed -n 's/.*CURRENT_PROJECT_VERSION = \([0-9]*\);/\1/p' "$PROJ/project.pbxproj" | head -1) + 1 ))
  sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = ${VERSION};/g" "$PROJ/project.pbxproj"
  sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = ${BUILD};/g" "$PROJ/project.pbxproj"

  # 2. build Release + codesign (stable cert if present, else ad-hoc)
  xcodebuild -project "$PROJ" -scheme "$SCHEME" -configuration Release -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO clean build | tail -3
  APP="$REL/${APPNAME}.app"; rm -rf "$APP"; cp -R "$REL/WhiskyClaude.app" "$APP"
  SIGN_ID="Ahmad Sharaf Code Signing"
  if security find-certificate -c "$SIGN_ID" >/dev/null 2>&1; then
      codesign --force --deep --sign "$SIGN_ID" "$APP"
  else codesign --force --deep --sign - "$APP"; fi

  # 3. zip
  ( cd "$REL" && ditto -c -k --keepParent "${APPNAME}.app" "$OLDPWD/$ZIP" )

  # 4. EdDSA sign the zip
  SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData build -name sign_update -path "*Sparkle*" 2>/dev/null | head -1)
  [ -n "$SIGN_UPDATE" ] || { echo "✗ sign_update not found (resolve Sparkle first)"; exit 1; }
  SIGINFO=$("$SIGN_UPDATE" "$ZIP")   # -> sparkle:edSignature="…" length="…"
  LEN=$(stat -f%z "$ZIP")

  # 5. GitHub Release + asset
  gh release create "v${VERSION}" "$ZIP" --repo "$REPO" --title "v${VERSION}" \
     --notes "Whisky Claude ${VERSION}" 2>&1 | tail -2
  URL="https://github.com/${REPO}/releases/download/v${VERSION}/${ZIP}"

  # 6. prepend appcast item
  PUBDATE=$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S +0000")
  ITEM="    <item>
        <title>${VERSION}</title>
        <pubDate>${PUBDATE}</pubDate>
        <sparkle:version>${BUILD}</sparkle:version>
        <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
        <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
        <enclosure url=\"${URL}\" type=\"application/octet-stream\" length=\"${LEN}\" ${SIGINFO} />
    </item>"
  python3 - "$ITEM" <<'PY'
  import sys, re
  item = sys.argv[1]
  p = "appcast.xml"; s = open(p).read()
  s = re.sub(r"(<language>en</language>\n)", r"\1" + item + "\n", s, count=1)
  open(p, "w").write(s)
  PY
  xmllint --noout appcast.xml

  # 7. commit + push + tag
  git add "$PROJ/project.pbxproj" appcast.xml
  git commit -m "release: v${VERSION}"
  git tag "v${VERSION}"
  git push origin HEAD --tags
  rm -f "$ZIP"
  echo "✓ released v${VERSION}"
  ```

- [ ] **Step 2: Lint (don't publish yet).**
  ```bash
  chmod +x scripts/release.sh
  bash -n scripts/release.sh && echo "syntax ok"
  ```

- [ ] **Step 3: Commit.**
  ```bash
  git add scripts/release.sh && git commit -m "feat(update): release.sh publish pipeline"
  ```

## Task 8: Docs (parity)

**Files:** Modify `README.md`, `CLAUDE.md`; Create `docs/RELEASING.md`

- [ ] **Step 1:** `docs/RELEASING.md` — keys (where the EdDSA private key lives in Keychain + how to back it up/rotate), `./scripts/release.sh <version>` usage, the manual update-test checklist, and the "first download needs right-click→Open; updates are seamless" note.
- [ ] **Step 2:** `README.md` — add "Updating" section (auto-checks + Check for Updates…); keep the install-from-source path.
- [ ] **Step 3:** `CLAUDE.md` — under Dependencies replace the stale "SwiftTerm" line (not actually linked) with "Sparkle (auto-update)"; add a short "Auto-update" subsection (updater in AppDelegate, appcast, release.sh, keys in Keychain).
- [ ] **Step 4: Commit.**
  ```bash
  git add README.md CLAUDE.md docs/RELEASING.md
  git commit -m "docs: auto-update (README Updating, RELEASING.md, CLAUDE.md)"
  ```

## Task 9: Merge, then end-to-end release test

- [ ] **Step 1:** Merge `feat/auto-update` → `master` (`--no-ff`), push. (SUFeedURL points at raw master, so the feed must be on master.)
- [ ] **Step 2:** Reinstall current build as the baseline (`./scripts/install.sh`) so a real v1.2.0 (build 3) app is running.
- [ ] **Step 3:** Cut the first real update: `./scripts/release.sh 1.2.1`. Verify: GitHub Release `v1.2.1` exists with the zip; `appcast.xml` on master has the `<item>` with a valid `sparkle:edSignature`.
- [ ] **Step 4:** In the running app → "Check for Updates…" → Sparkle detects 1.2.1 → installs → app relaunches. Confirm `mdls -name kMDItemVersion "/Applications/Whisky Claude.app"` shows `1.2.1`.
- [ ] **Step 5:** Update memory (the pbxproj-first-SPM + Sparkle-keys lessons) + run the memory pipeline.

---

## Self-review

- **Spec coverage:** Sparkle dep (T1), keys (T2), Info.plist keys (T3), updater+menu (T4), settings toggle (T5), appcast (T6), release.sh (T7), docs (T8), e2e test (T9) — all spec sections mapped.
- **Placeholders:** `<PUBLIC_KEY_FROM_TASK_2>` and the `SP00000x` pbxproj IDs are values produced during execution, not unresolved decisions. No "TBD/handle errors" hand-waving.
- **Consistency:** `SUUpdaterBridge` defined in T5 used only in T5; `updaterController`/`checkForUpdatesAction` consistent across T4–T5; build commands consistent.
- **Risk:** T1 pbxproj edit is the fragile step — it has an explicit resolve+build validation and a `git checkout` rollback.

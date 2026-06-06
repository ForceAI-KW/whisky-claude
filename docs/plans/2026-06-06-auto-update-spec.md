# Spec — In-app Auto-Update (Sparkle)

**Date:** 2026-06-06
**Status:** approved (design), pending implementation
**Goal:** Let users update Whisky Claude from inside the app — automatic background checks + a manual "Check for Updates…" — instead of re-running `install.sh`.

## Context / constraints

- App is **self-signed** (stable cert "Ahmad Sharaf Code Signing"), **not Apple-notarized**, no Apple Developer Program.
- Public repo `ForceAI-KW/whisky-claude`, **MIT**. Currently distributed build-from-source via `scripts/install.sh`; **no GitHub Releases exist yet**.
- Xcode 16 project, `GENERATE_INFOPLIST_FILE = YES` (no explicit Info.plist — custom keys via `INFOPLIST_KEY_*`). `MARKETING_VERSION = 1.2.0`, `CURRENT_PROJECT_VERSION = 3`. Bundle id `com.ahmadsharaf.WhiskyClaude`. `LSUIElement = YES` (menu-bar agent).
- Existing SPM dep: SwiftTerm. `gh` CLI authed as ForceAI-KW.

## Decision

**Sparkle 2.x** (MIT) + **local `scripts/release.sh`** + **GitHub Releases** for binaries + **`appcast.xml`** committed at repo root (served via `raw.githubusercontent.com`).

Rejected: lightweight self-rolled checker (more bespoke UI/security work), CI publishing (can't reach the local signing cert), Homebrew cask (not in-app), notarization + delta updates (YAGNI now).

## Architecture

### App side
- Add **Sparkle 2.x** via SPM (pin to a 2.x exact/up-to-next-major version). Link `Sparkle` to the `WhiskyClaude` target. Requires editing `project.pbxproj` to mirror the SwiftTerm package reference (remote package + product dependency + Frameworks build file).
- `SPUStandardUpdaterController` owned by `AppDelegate` (`startingUpdater: true`), created at launch. It manages automatic checks + the update UI.
- **Status-bar menu:** add "Check for Updates…" → `updater.checkForUpdates(nil)`. Place it above "Quit".
- **Settings → General:** "Automatically check for updates" toggle bound to `updater.automaticallyChecksForUpdates`.
- **Info.plist keys** (via build settings, both Debug + Release):
  - `INFOPLIST_KEY_SUFeedURL = https://raw.githubusercontent.com/ForceAI-KW/whisky-claude/master/appcast.xml`
  - `INFOPLIST_KEY_SUPublicEDKey = <public EdDSA key>`
  - `INFOPLIST_KEY_SUEnableInstallerLauncherService` not needed (no privileged installer; app is user-writable in /Applications).
- Sandbox: app is **not** sandboxed → no XPC services needed for Sparkle.

### Keys / security
- Generate EdDSA key pair once with Sparkle's `generate_keys`. **Private key stays in the macOS Keychain** (Sparkle stores it there); **never committed**. Public key string → `INFOPLIST_KEY_SUPublicEDKey`.
- Each release zip is EdDSA-signed (`sign_update`); Sparkle verifies the signature before installing → integrity guaranteed despite no notarization.
- In-place update of the already-user-trusted app does not re-trigger Gatekeeper. First-ever download still needs right-click→Open (unchanged from today; documented).

### Release flow — `scripts/release.sh <version>`
1. Validate arg `<version>` (semver) and a clean git tree.
2. Set `MARKETING_VERSION = <version>`; bump `CURRENT_PROJECT_VERSION` (monotonic integer).
3. Release build + codesign with the stable cert (reuse `install.sh`'s build/sign logic).
4. Zip the `.app` → `WhiskyClaude-<version>.zip`.
5. EdDSA-sign the zip with Sparkle's `sign_update` → `sparkle:edSignature` + length.
6. `gh release create v<version> --title … --notes …` and upload the zip as the asset.
7. Prepend a new `<item>` to `appcast.xml` (title, `sparkle:version` = CURRENT_PROJECT_VERSION, `sparkle:shortVersionString` = MARKETING_VERSION, `<enclosure url=… sparkle:edSignature=… length=…/>`, `pubDate`, optional notes link).
8. `git commit` (version bump + appcast) + `git push` + push tag.

### Feed / hosting
- `appcast.xml` at repo root, fetched from `raw.githubusercontent.com/ForceAI-KW/whisky-claude/master/appcast.xml`.
- Enclosure URLs point at the GitHub Release asset download URLs.

### Sparkle CLI tools
- `generate_keys` + `sign_update` ship inside the Sparkle SPM artifact (under the resolved package's `artifacts`/`bin`). `release.sh` locates them in DerivedData (or a pinned path); if absent, download the matching Sparkle tarball. Document the resolved path in `RELEASING.md`.

## Components (units)
- `UpdaterController` (thin wrapper around `SPUStandardUpdaterController`) — exposes `checkForUpdates()` + the auto-check toggle binding. Owned by AppDelegate.
- Menu item wiring in `AppDelegate.buildMenu()`.
- Settings toggle in `SettingsWindow`/`SettingsManager` (mirror existing toggles).
- `scripts/release.sh` — the publish pipeline.
- `appcast.xml` — the feed.

## Error handling
- Sparkle surfaces its own errors (no feed, bad signature, network) via its UI; no custom handling needed for v1.
- `release.sh`: `set -euo pipefail`; abort on dirty tree, missing `gh`/cert/Sparkle tools, or failed signature; never push a partial release.

## Testing / verification
- Build with Sparkle linked succeeds (Debug + Release), no warnings.
- `appcast.xml` is well-formed XML with a valid `<item>` after a dry `release.sh`.
- **End-to-end (manual, the real gate):** install v1.2.0 → `release.sh 1.2.1` → launch v1.2.0 → "Check for Updates…" detects 1.2.1 → installs → relaunches as 1.2.1. (No automated test for Sparkle UI; documented manual checklist in `RELEASING.md`.)

## Docs (parity, same session)
- README "Updating" section (auto-update + how first install still works).
- `docs/RELEASING.md` runbook (keys, `release.sh` usage, manual update test, key-rotation note).
- CLAUDE.md: Dependencies (+Sparkle), a short Auto-Update section.

## Out of scope (YAGNI)
Delta updates, CI publishing, Apple notarization, legacy DSA keys, in-app release-notes styling beyond a notes link.

## Risks
- **pbxproj SPM edit** is the fragile step (hand-adding the Sparkle package). Mitigate by mirroring the SwiftTerm entries exactly + building immediately to validate.
- EdDSA private key loss → can't ship updates that verify against the shipped public key; back up the key (Keychain item) — noted in `RELEASING.md`.

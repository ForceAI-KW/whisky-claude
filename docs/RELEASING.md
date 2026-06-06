# Releasing Whisky Claude

Whisky Claude auto-updates via [Sparkle](https://sparkle-project.org). Cutting a
release = build + sign + publish so existing installs pick it up automatically.

## One command

```bash
./scripts/release.sh <version>      # e.g. ./scripts/release.sh 1.3.0
```

It will:
1. Bump `MARKETING_VERSION` to `<version>` and increment `CURRENT_PROJECT_VERSION`.
2. Build Release + codesign with the stable cert (`Ahmad Sharaf Code Signing`, ad-hoc fallback).
3. Zip the app and **EdDSA-sign** the zip with Sparkle's `sign_update`.
4. Create a GitHub Release `v<version>` and upload the zip.
5. Prepend an `<item>` to `appcast.xml` and commit + push + tag.

Prereqs: clean git tree, `gh` authed, Sparkle resolved (any prior build does this),
and the EdDSA private key in your Keychain (below).

## The signing keys (one-time)

The EdDSA key pair was generated once with Sparkle's `generate_keys`:

```bash
build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
```

- **Public key** lives in `WhiskyClaude/Info.plist` under `SUPublicEDKey`
  (`uwphgwYx7cawf3GqkcSOpyBUeLSIWpOKbu/ILq/KwWg=`). Sparkle uses it to verify updates.
- **Private key** is stored in the **login Keychain** (item `https://sparkle-project.org`,
  account `ed25519`). It is **never** committed.

**Back it up** (losing it means you can't ship updates that verify against the
shipped public key):

```bash
build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle_private_key.txt
# store sparkle_private_key.txt somewhere safe + OFFLINE, then delete the file
```

To restore on another machine: `generate_keys -f sparkle_private_key.txt`.

## Notarization / Gatekeeper

The app is **self-signed, not Apple-notarized** (no Apple Developer Program).
- **Updates** of an already-installed (user-trusted) app install seamlessly —
  Sparkle's EdDSA signature guarantees integrity; Gatekeeper isn't re-triggered.
- A **first-ever download** is quarantined: right-click → Open once (or run
  `./scripts/install.sh` to build from source). This is unchanged from before.

## Manual update test (do this after the first release)

1. Have an older version installed + running (e.g. `./scripts/install.sh` at the
   current version).
2. `./scripts/release.sh <newer-version>`.
3. App menu bar → **Check for Updates…** → Sparkle should offer the new version →
   install → app relaunches.
4. Confirm: `mdls -name kMDItemVersion "/Applications/Whisky Claude.app"`.

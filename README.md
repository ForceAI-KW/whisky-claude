# Whisky Claude

A Claude mascot that lives in the macOS notch. Animates + plays a sound when Claude Code needs your attention. Double-clap to open a Claude terminal session.

Fork of [Notchy](https://github.com/adamlyttleapps/notchy) by Adam Lyttle (MIT). See `LICENSE` for attribution.

## Build

```bash
xcodebuild -project WhiskyClaude.xcodeproj -scheme WhiskyClaude \
    -configuration Debug -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build
open build/Build/Products/Debug/WhiskyClaude.app
```

## Install (Release + Login Item)

```bash
./scripts/install.sh    # built in Task 8 of the plan
```

## Architecture

See `CLAUDE.md` for the inherited Notchy architecture + `docs/plans/2026-05-21-whisky-claude-fork.md` for active modifications.

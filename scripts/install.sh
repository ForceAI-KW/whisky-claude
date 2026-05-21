#!/bin/bash
# Whisky Claude — end-to-end installer.
# 1. Build Release
# 2. Ad-hoc codesign
# 3. Copy to /Applications/Whisky Claude.app
# 4. Install pet-event helper + Claude Code hooks
# 5. Register as a Login Item
# Idempotent — safe to re-run.

set -euo pipefail
cd "$(dirname "$0")/.."

PROJECT="WhiskyClaude.xcodeproj"
SCHEME="WhiskyClaude"
TARGET_NAME="Whisky Claude"          # display name with space
SOURCE_APP="build/Build/Products/Release/WhiskyClaude.app"
RENAMED_APP="build/Build/Products/Release/${TARGET_NAME}.app"
INSTALL_PATH="/Applications/${TARGET_NAME}.app"

echo "→ generating Release build"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
    -derivedDataPath build \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    clean build | tail -5

if [ ! -d "$SOURCE_APP" ]; then
    echo "✗ build output missing at $SOURCE_APP" >&2
    exit 1
fi

# Rename the product on disk so /Applications/Whisky Claude.app matches the
# display name. We work on a copy so we don't disturb the build output Xcode
# might re-touch on the next incremental build.
rm -rf "$RENAMED_APP"
cp -R "$SOURCE_APP" "$RENAMED_APP"

echo "→ ad-hoc codesign"
codesign --force --deep --sign - "$RENAMED_APP"

echo "→ installing to /Applications"
# Quit the running instance, if any.
osascript -e "tell application \"${TARGET_NAME}\" to quit" 2>/dev/null || true
osascript -e "tell application \"WhiskyClaude\" to quit" 2>/dev/null || true
sleep 0.5
rm -rf "$INSTALL_PATH"
cp -R "$RENAMED_APP" "$INSTALL_PATH"

# Clean up build artifacts so they don't appear in Spotlight as duplicate
# copies of the app. The /Applications copy is the only one users should see.
rm -rf "$SOURCE_APP" "$RENAMED_APP"

echo "→ installing pet-event helper"
mkdir -p ~/.claude/scripts
cp scripts/dot-claude/wc-event.sh ~/.claude/scripts/wc-event.sh
chmod +x ~/.claude/scripts/wc-event.sh

echo "→ wiring Claude Code hooks"
scripts/install-hooks.sh

echo "→ launching"
open "$INSTALL_PATH"

echo "→ registering Login Item"
osascript <<EOF
tell application "System Events"
    if not (exists login item "${TARGET_NAME}") then
        make login item at end with properties {path:"${INSTALL_PATH}", hidden:false}
    end if
end tell
EOF

cat <<EOF

✓ Installed.
  App:        ${INSTALL_PATH}
  Helper:     ${HOME}/.claude/scripts/wc-event.sh
  Hooks:      ${HOME}/.claude/settings.json (Stop/Notification/PreToolUse/UserPromptSubmit)
  Login Item: registered, will auto-launch each login

Uninstall:    ./scripts/uninstall.sh
EOF

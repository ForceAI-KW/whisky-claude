#!/bin/bash
# Whisky Claude — reverse install.sh.
# 1. Quit running instance
# 2. Remove /Applications/Whisky Claude.app
# 3. Remove the 4 hooks added by install-hooks.sh (preserve any others)
# 4. Remove pet-event helper
# 5. Remove Login Item

set -uo pipefail

TARGET_NAME="Whisky Claude"
INSTALL_PATH="/Applications/${TARGET_NAME}.app"
SETTINGS="$HOME/.claude/settings.json"

echo "→ quitting app"
osascript -e "tell application \"${TARGET_NAME}\" to quit" 2>/dev/null || true
sleep 0.5

echo "→ removing app bundle"
rm -rf "$INSTALL_PATH"

echo "→ removing hooks from settings.json"
if [ -f "$SETTINGS" ]; then
    cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)"
    tmp=$(mktemp)
    jq 'del(.hooks.Stop, .hooks.Notification, .hooks.PreToolUse, .hooks.UserPromptSubmit) |
        if (.hooks // {}) == {} then del(.hooks) else . end' \
       "$SETTINGS" > "$tmp"
    mv "$tmp" "$SETTINGS"
fi

echo "→ removing pet-event helper"
rm -f ~/.claude/scripts/wc-event.sh

echo "→ removing Login Item"
osascript <<EOF 2>/dev/null || true
tell application "System Events"
    if exists login item "${TARGET_NAME}" then delete login item "${TARGET_NAME}"
end tell
EOF

# pet-events directory is intentionally left alone (could contain unprocessed
# events from other tools); remove manually if you want.

echo "✓ Whisky Claude uninstalled."

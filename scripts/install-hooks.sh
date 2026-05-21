#!/bin/bash
# Idempotently install Whisky Claude hooks into ~/.claude/settings.json.
# Safe to re-run. Creates a timestamped backup of settings.json before modifying.

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
HELPER="$HOME/.claude/scripts/wc-event.sh"

if [ ! -f "$HELPER" ]; then
    echo "ERROR: helper script not installed at $HELPER" >&2
    echo "Copy first: cp scripts/dot-claude/wc-event.sh ~/.claude/scripts/" >&2
    exit 1
fi

if [ ! -f "$SETTINGS" ]; then
    echo "ERROR: $SETTINGS does not exist. Run Claude Code at least once first." >&2
    exit 1
fi

# Backup before modifying
cp "$SETTINGS" "$SETTINGS.bak.$(date +%s)"

tmp=$(mktemp)
jq '
  .hooks = (
    (.hooks // {}) |
    .Stop              = [{hooks: [{type: "command", command: "'"$HELPER"' done"}]}] |
    .Notification      = [{hooks: [{type: "command", command: "'"$HELPER"' attention"}]}] |
    .PreToolUse        = [{hooks: [{type: "command", command: "'"$HELPER"' working"}]}] |
    .UserPromptSubmit  = [{hooks: [{type: "command", command: "'"$HELPER"' thinking"}]}]
  )
' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"

echo "✓ Whisky Claude hooks installed in $SETTINGS"
echo "  Backup: $SETTINGS.bak.*"
echo "  Hook invocations log: ~/.claude/logs/wc-event.log"

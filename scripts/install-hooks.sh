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

# Backup before modifying.
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

echo "✓ Whisky Claude hooks installed in $SETTINGS"
echo "  Backup: $SETTINGS.bak.*"

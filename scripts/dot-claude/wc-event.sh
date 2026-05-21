#!/bin/bash
# Whisky Claude hook helper — writes a pet-event JSON for WhiskyClaude.app to consume.
# Invoked from ~/.claude/settings.json hooks block.
# Usage: wc-event.sh <event_type>   (event_type: attention | thinking | working | done | idle)

set -u
EVENT_TYPE="${1:-idle}"
EVENTS_DIR="$HOME/.claude/pet-events"
mkdir -p "$EVENTS_DIR"

# Hook payload comes in on stdin as JSON (see Claude Code hook docs).
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

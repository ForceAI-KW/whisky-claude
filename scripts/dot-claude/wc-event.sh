#!/bin/bash
# Whisky Claude hook helper — writes a pet-event JSON for WhiskyClaude.app
# to consume + logs every invocation to ~/.claude/logs/wc-event.log so the
# user can verify hooks are firing from real Claude Code sessions.
# Usage: wc-event.sh <event_type>   (attention | thinking | working | done | idle)

set -u
EVENT_TYPE="${1:-idle}"
LOG="$HOME/.claude/logs/wc-event.log"
EVENTS_DIR="$HOME/.claude/pet-events"

mkdir -p "$(dirname "$LOG")" "$EVENTS_DIR"

# Read hook payload from stdin (Claude Code's hook spec sends JSON here).
payload=$(cat 2>/dev/null || echo '{}')

# Append a one-line summary + the full payload to the log. Use ISO8601 UTC
# so log entries sort naturally even across timezones.
ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
{
    echo "[$ts] event=$EVENT_TYPE pid=$$ ppid=$PPID payload_bytes=${#payload}"
    if [ -n "$payload" ] && [ "$payload" != "{}" ]; then
        printf '  payload: %s\n' "$payload"
    fi
} >> "$LOG" 2>&1

# Extract identifying fields with jq if available; otherwise leave blank.
if command -v jq >/dev/null 2>&1; then
    session_id=$(printf '%s' "$payload" | jq -r '.session_id // ""')
    message=$(printf '%s' "$payload" | jq -r '.message // ""')
else
    session_id=""
    message=""
fi

uuid=$(uuidgen | tr 'A-Z' 'a-z')

cat > "$EVENTS_DIR/$uuid.json" <<EOF
{
  "type": "$EVENT_TYPE",
  "ts": "$ts",
  "session_id": "$session_id",
  "message": $(printf '%s' "$message" | jq -Rs . 2>/dev/null || echo '""')
}
EOF

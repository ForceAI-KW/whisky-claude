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

# Rotate the log if it has grown past ~20MB. This runs on every hook event,
# so keep it cheap: a single stat-based size check, no `wc -l`, no extra
# subprocesses beyond mv/chmod (and those only fire when we actually rotate).
# Keeps exactly one generation (wc-event.log.1) and preserves the 600 perms
# the log is created with (it previously leaked credentials).
MAX_LOG_BYTES=$((20 * 1024 * 1024))
if [ -f "$LOG" ]; then
    log_size=$(stat -f %z "$LOG" 2>/dev/null || echo 0)
    if [ "$log_size" -gt "$MAX_LOG_BYTES" ]; then
        mv -f "$LOG" "$LOG.1"
        : > "$LOG"
        chmod 600 "$LOG"
    fi
fi

# Read hook payload from stdin (Claude Code's hook spec sends JSON here).
payload=$(cat 2>/dev/null || echo '{}')

# Append a one-line summary + the full payload to the log. Use ISO8601 UTC
# so log entries sort naturally even across timezones.
ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# NOTE: never log the raw payload — it carries tool_input.command verbatim,
# which routinely contains live DATABASE_URLs, PATs and API keys. The metadata
# line below is enough to verify hooks are firing.
{
    echo "[$ts] event=$EVENT_TYPE pid=$$ ppid=$PPID payload_bytes=${#payload}"
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
final="$EVENTS_DIR/$uuid.json"
tmp="$EVENTS_DIR/$uuid.json.tmp"

# Write to a .tmp file FIRST, then rename atomically to .json. This avoids
# a race where the watcher (DispatchSource on .write events) reads the file
# while we're still streaming bytes into it — Swift's JSONDecoder would
# see truncated content and silently drop the event. The .tmp suffix means
# the watcher's `pathExtension == "json"` filter ignores it during writing.
cat > "$tmp" <<EOF
{
  "type": "$EVENT_TYPE",
  "ts": "$ts",
  "session_id": "$session_id",
  "message": $(printf '%s' "$message" | jq -Rs . 2>/dev/null || echo '""')
}
EOF
mv "$tmp" "$final"

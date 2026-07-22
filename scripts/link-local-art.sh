#!/usr/bin/env bash
# Link the local-only (gitignored) Clawd mascot art into THIS checkout.
#
# WHY THIS EXISTS: the clawd-*.dataset gifs are AGPL art (clawd-on-desk) kept
# OUT of this public MIT repo via .gitignore, so they live only in the primary
# checkout's working tree. `git worktree add` does NOT copy gitignored/untracked
# files, so a fresh worktree builds an Assets.car with zero mascot art and the
# mascot window renders nothing (window present, character absent). This relinks
# the art from a sibling checkout that has it. Idempotent — safe to re-run.
#
# Usage: scripts/link-local-art.sh   (run from anywhere inside the checkout)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # checkout root
ASSETS_REL="WhiskyClaude/Assets.xcassets"

# Find a sibling git worktree that actually HAS the clawd art to source from.
SRC=""
while IFS= read -r line; do
  case "$line" in
    worktree\ *)
      wt="${line#worktree }"
      [ "$wt" = "$HERE" ] && continue
      if compgen -G "$wt/$ASSETS_REL/clawd-"*.dataset >/dev/null 2>&1; then
        SRC="$wt"; break
      fi
      ;;
  esac
done < <(git -C "$HERE" worktree list --porcelain)

if [ -z "$SRC" ]; then
  echo "⚠️  link-local-art: no sibling checkout with clawd-*.dataset art found."
  echo "    The mascot will render nothing. Supply gifs under"
  echo "    $HERE/$ASSETS_REL/clawd-*.dataset/ manually (see .gitignore + CLAUDE.md)."
  exit 0
fi

linked=0
for d in "$SRC/$ASSETS_REL"/clawd-*.dataset; do
  [ -d "$d" ] || continue
  dst="$HERE/$ASSETS_REL/$(basename "$d")"
  [ -e "$dst" ] && continue          # already present (real copy or existing link)
  ln -s "$d" "$dst"
  linked=$((linked + 1))
done
echo "✅ link-local-art: linked $linked clawd dataset(s) from $SRC"

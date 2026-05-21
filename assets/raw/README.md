# Raw source assets

These are the original (un-processed, un-renamed) source assets bundled
with Whisky Claude. They're here so anyone forking the project can remix
the icon, swap the sounds, or use them as a starting point for their own
mascot variants.

| file | what | where it ends up in the build |
|---|---|---|
| `claude-logo.svg` | Vector source for the Claude character | `WhiskyClaude/Assets.xcassets/ClaudeLogo.imageset/ClaudeLogo.svg` (vector-preserved) + rasterized into every AppIcon size at build time |
| `claude-logo.png` | 640×640 raster from the Claude Code brand kit | Reference only |
| `claude-logo.webp` | WebP variant | Reference only |
| `attention.mp3` | TTS voice clip — "Whisky needs you, Ahmad" — used for the Notification hook | Bundled as `WhiskyClaude/Sounds/waitingForInput.wav` (RIFF PCM 16-bit 24kHz mono, despite the .mp3 extension on the source) |
| `done.mp3` | TTS voice clip — "Whisky is done, Ahmad" — used for the Stop hook | Bundled as `WhiskyClaude/Sounds/taskCompleted.wav` |

## Swapping in your own

Easiest path: Settings → General → Choose… (file picker per sound). No
rebuild needed.

For a hard-coded swap that ships with the bundle:
1. Replace `WhiskyClaude/Sounds/waitingForInput.wav` with your file
2. Rebuild via `scripts/install.sh`

For a new mascot icon:
1. Replace `WhiskyClaude/Assets.xcassets/ClaudeLogo.imageset/ClaudeLogo.svg`
2. Re-run the AppIcon raster step (see `/tmp/render_appicon.swift` in the
   commit history or the equivalent `sips`/`NSImage` workflow)
3. Rebuild

## Attribution

- **Claude logo** — Claude Code's official mascot, by Anthropic. "Claude"
  is a trademark of Anthropic; please respect their brand guidelines.
- **TTS clips** — generated via NoteGPT TTS for Ahmad Sharaf's personal use.
  Replace these if you fork the project for your own brand.

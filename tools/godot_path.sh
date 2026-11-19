#!/usr/bin/env bash
# Print the Godot binary to use, or fail. Sourced logic shared by every script in this repo so
# there is exactly ONE lookup order:
#   1. $GODOT, if set
#   2. the macOS app at /Applications/Godot.app (a Mac desktop)
#   3. ~/godot-bin/godot (where .claude/hooks/session-start.sh installs it in a cloud VM, and the
#      path CI caches)
#   4. `godot` on PATH (a Linux desktop)
# The fallback chain matters: $CLAUDE_ENV_FILE is unset in some remote environments, so the hook
# cannot always export $GODOT, and a script that only read $GODOT would find no engine.
if [ -n "${GODOT:-}" ] && [ -x "$GODOT" ]; then echo "$GODOT"; exit 0; fi
for c in /Applications/Godot.app/Contents/MacOS/Godot "$HOME/godot-bin/godot" "$(command -v godot 2>/dev/null || true)"; do
	if [ -n "$c" ] && [ -x "$c" ]; then echo "$c"; exit 0; fi
done
echo "error: no Godot found. Set GODOT=/path/to/godot (see README → Setup)." >&2
exit 1

#!/usr/bin/env bash
# Tap every button on one or more screens the way a finger would. Exits 1 if any is DEAD.
#   tools/touch_probe.sh res://scenes/title_screen.tscn [more scenes...]
#   TOUCH_SIZE=2340x1080 TOUCH_LAYOUT=STICK_AB tools/touch_probe.sh res://samples/sample_game/game.tscn
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="$(tools/godot_path.sh)" || exit 1
fail=0
for scene in "$@"; do
	out="$(TOUCH_SCENE="$scene" "$GODOT" --headless --path . res://tools/touch_probe.tscn --quit-after 1200 2>&1)"
	code=$?
	grep -E "^TOUCH_PROBE|SCRIPT ERROR" <<<"$out"
	if [ $code -ne 0 ] || grep -q "SCRIPT ERROR" <<<"$out" || ! grep -q "TOUCH_PROBE RESULT" <<<"$out"; then
		echo "FAIL: $scene"; fail=1
	fi
done
exit $fail

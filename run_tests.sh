#!/usr/bin/env bash
# The one test command. Run it before every commit; CI runs exactly this.
#
#   ./run_tests.sh                 import, smoke-load every scene, run every GUT test
#   ./run_tests.sh test_save       only test files whose name contains "test_save"
#   REPEAT=50 ./run_tests.sh x     run the selection 50 times — the flake check
#
# Hardened against GUT's worst habit: a test file that fails to PARSE is skipped with a warning
# and the suite still prints a cheerful green. That has hidden 11 and then 20 tests in projects
# this template came from. The grep for "Ignoring script" / "Failed to load script" below is why
# that cannot happen here. Do not weaken it.
set -euo pipefail
cd "$(dirname "$0")"
GODOT="$(tools/godot_path.sh)"
SELECT="${1:-}"
REPEAT="${REPEAT:-1}"
# Tests exercise real saves; keep them off the developer's own save file.
export GAME_SAVE_PATH="user://test_suite_save.json"

echo "== engine: $("$GODOT" --version | head -1)"
echo "== import"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

# Godot exits 0 even when a scene logs a SCRIPT ERROR, so read the output.
ERR_RE="SCRIPT ERROR|Parse Error|Failed to (load|instantiate)|Invalid call|Invalid access"
smoke() {
	local scene="$1" out
	out="$("$GODOT" --headless --path . "$scene" --quit-after 60 2>&1)" || {
		echo "$out"; echo "FAIL: $scene — Godot exited non-zero"; exit 1; }
	if grep -qE "$ERR_RE" <<<"$out"; then
		echo "$out" | grep -E -A3 "$ERR_RE" | head -20
		echo "FAIL: $scene — script error while loading/running it headless"; exit 1
	fi
}

if [ -z "$SELECT" ]; then
	echo "== smoke: every scene under scenes/ and samples/ loads and runs 60 frames cleanly"
	n=0
	while IFS= read -r f; do smoke "res://$f"; n=$((n+1)); done \
		< <(find scenes samples -name '*.tscn' 2>/dev/null | sort)
	echo "   $n scenes ok"
fi

gut_args=(-s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit)
[ -n "$SELECT" ] && gut_args+=("-gselect=$SELECT")

for i in $(seq 1 "$REPEAT"); do
	[ "$REPEAT" -gt 1 ] && echo "== GUT run $i/$REPEAT" || echo "== GUT"
	out="$("$GODOT" --headless --path . "${gut_args[@]}" 2>&1)" || true
	[ "$REPEAT" -gt 1 ] || echo "$out" | grep -vE "^\s*$" | tail -40
	if grep -qE "Ignoring script .* because it does not extend GutTest|Failed to load script .*tests/|Parse Error" <<<"$out"; then
		grep -E "Ignoring script|Failed to load script|Parse Error|SCRIPT ERROR" <<<"$out" | head -10
		echo "FAIL: a test script failed to load and GUT skipped it. The suite did NOT run."
		echo "      Usually a type-inference error: write 'var x: Type = ...' not 'var x := untyped.call()'."
		exit 1
	fi
	if grep -qE "Failing Tests[: ]+[1-9]|^\s*Failing\s+[1-9]" <<<"$out"; then
		[ "$REPEAT" -gt 1 ] && echo "$out" | tail -60
		echo "FAIL: GUT reported failing tests (run $i/$REPEAT)"; exit 1
	fi
	if ! grep -qiE "All tests passed|Passing Tests[: ]+[0-9]|^\s*Passing\s+[0-9]" <<<"$out"; then
		echo "$out" | tail -40
		echo "FAIL: GUT printed no summary — the suite crashed or selected nothing"; exit 1
	fi
	if grep -qE "SCRIPT ERROR" <<<"$out"; then
		grep -E -A2 "SCRIPT ERROR" <<<"$out" | head -20
		echo "FAIL: script error during the test run"; exit 1
	fi
done
echo "== all checks passed"

#!/usr/bin/env bash
# ONE COMMAND TO PROVE A CHANGE WORKS. Writes proof/<name>/ and a self-contained index.html that
# the agent publishes as an Artifact (see .claude/skills/verify/SKILL.md).
#
#   tools/verify.sh <name> <scene> [options]
#
#   <scene>        what to record. Usually an Autoplay demo (tools/autoplay/autoplay.gd) that drives
#                  the real game with real input and check()s the result; any scene works.
#   --frames N     capture length cap at 30 fps (default 600 = 20 s). An Autoplay demo quits when done.
#   --size WxH     capture resolution (default 1280x720)
#   --touch a,b    also run the touch probe on these screens (res:// paths)
#   --touch-sim    draw the phone's on-screen controls in the capture
#   --audio "ARGS" gate on audio: extra tools/audio_profile.py args, e.g. "--quiet-below 0.01 --max-quiet-run 5"
#   --no-tests     skip ./run_tests.sh (only when you just ran it)
#   --title "T"    page title (default: <name>)
#
# Produces: clip.mp4 (with sound), sheet.png (10 frames), last.png, run.log (VERIFY/AUTOPLAY lines),
# tests.txt, touch.txt, audio.txt, manifest.json, index.html. Exit 1 if anything failed.
#
# READ sheet.png YOURSELF BEFORE PUBLISHING. A green run of a capture that shows the wrong thing
# proves nothing — suspect the harness before the game.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
NAME="${1:?usage: tools/verify.sh <name> <scene> [options]}"; SCENE="${2:?scene res:// path}"; shift 2
FRAMES=600; SIZE=1280x720; TOUCH=""; AUDIO=""; TESTS=1; TITLE="$NAME"
while [ $# -gt 0 ]; do
	case "$1" in
		--frames) FRAMES="$2"; shift 2 ;;
		--size) SIZE="$2"; shift 2 ;;
		--touch) TOUCH="$2"; shift 2 ;;
		--touch-sim) export TOUCH_SIM=1; shift ;;
		--audio) AUDIO="$2"; shift 2 ;;
		--no-tests) TESTS=0; shift ;;
		--title) TITLE="$2"; shift 2 ;;
		*) echo "unknown option $1" >&2; exit 2 ;;
	esac
done
OUT="proof/$NAME"; rm -rf "$OUT"; mkdir -p "$OUT"
declare -A R; declare -A N

if [ $TESTS = 1 ]; then
	echo "== tests"
	if ./run_tests.sh > "$OUT/tests.txt" 2>&1; then R[tests]=pass; else R[tests]=fail; fi
	N[tests]="$(grep -oE 'Passing Tests +[0-9]+' "$OUT/tests.txt" | tail -1 | sed 's/  */ /g') — ./run_tests.sh"
else R[tests]=skip; N[tests]="skipped for this run"; fi

echo "== capture $SCENE ($FRAMES frames max, $SIZE)"
tools/render.sh video "$SCENE" "$OUT/clip.avi" "$FRAMES" "$SIZE" > "$OUT/render.txt" 2>&1
cap=$?
# render.sh greps the log; get the full VERIFY/AUTOPLAY lines from its output.
grep -E "^(AUTOPLAY|VERIFY)" "$OUT/render.txt" > "$OUT/run.log" || true
if [ $cap -ne 0 ] || [ ! -s "$OUT/clip.avi" ]; then
	R[checks]=fail; N[checks]="capture failed — see render.txt"; cat "$OUT/render.txt" | tail -15
else
	pass=$(grep -c "^VERIFY PASS" "$OUT/run.log"); fail=$(grep -c "^VERIFY FAIL" "$OUT/run.log")
	if [ "$fail" -gt 0 ]; then R[checks]=fail; elif [ "$pass" -gt 0 ]; then R[checks]=pass; else R[checks]=warn; fi
	N[checks]="$pass passed, $fail failed"
	[ "$pass$fail" = "00" ] && N[checks]="no check() calls — recorded only"
	ffmpeg -y -loglevel error -i "$OUT/clip.avi" -vf "scale='min(1280,iw)':-2" -c:v libx264 -preset veryfast -crf 30 \
		-pix_fmt yuv420p -c:a aac -b:a 96k -movflags +faststart "$OUT/clip.mp4"
	nframes=$(ffprobe -v error -count_packets -select_streams v:0 -show_entries stream=nb_read_packets -of csv=p=0 "$OUT/clip.avi")
	nth=$(( nframes / 10 )); [ $nth -lt 1 ] && nth=1
	tools/render.sh sheet "$OUT/clip.avi" "$OUT/sheet.png" "$nth" 5x2 >/dev/null
	ffmpeg -y -loglevel error -sseof -0.2 -i "$OUT/clip.avi" -frames:v 1 -update 1 "$OUT/last.png" || true
	FRAMES="$nframes"
	if ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$OUT/clip.avi" | grep -q .; then
		ffmpeg -y -loglevel error -i "$OUT/clip.avi" -map 0:a -c:a pcm_s16le "$OUT/audio.wav"
		# shellcheck disable=SC2086
		if python3 tools/audio_profile.py "$OUT/audio.wav" $AUDIO > "$OUT/audio.txt" 2>&1; then
			R[audio]=pass; N[audio]="$( [ -n "$AUDIO" ] && echo "gated: $AUDIO" || echo "profiled (not gated — pass --audio to gate)")"
		else R[audio]=fail; N[audio]="audio check failed: $AUDIO"; fi
		peak="$(awk '/^peak/{print $2; exit}' "$OUT/audio.txt")"
		N[audio]="${N[audio]} · peak ${peak:-?}"
		# Silence is not a pass. Unless the run was gated (and a gate decided), call it out.
		if [ -z "$AUDIO" ] && awk -v p="${peak:-0}" 'BEGIN{exit !(p < 0.0001)}'; then
			R[audio]=warn; N[audio]="SILENT — the capture has no sound (peak ${peak:-0}). Fine for a silent screen; a bug anywhere music or effects should play."
		fi
		rm -f "$OUT/audio.wav"
	else R[audio]=skip; N[audio]="no audio track"; fi
	rm -f "$OUT/clip.avi"
fi

if [ -n "$TOUCH" ]; then
	echo "== touch probe"
	IFS=',' read -ra scenes <<<"$TOUCH"
	if tools/touch_probe.sh "${scenes[@]}" > "$OUT/touch.txt" 2>&1; then R[touch]=pass; else R[touch]=fail; fi
	N[touch]="$(grep -c 'TOUCH_PROBE RESULT' "$OUT/touch.txt") screen(s): $(grep 'RESULT' "$OUT/touch.txt" | sed 's/.*RESULT //' | paste -sd ';' -)"
else R[touch]=skip; N[touch]="no screens given (--touch)"; fi

overall=pass
for k in tests checks touch audio; do [ "${R[$k]:-skip}" = fail ] && overall=fail; done
renderer="${RENDERER:-mobile}"; [ "$renderer" = mobile ] && renderer="Mobile renderer (Vulkan)" || renderer="Compatibility renderer"
python3 - "$OUT" <<PY
import json, sys, datetime
json.dump({
  "name": "$NAME", "title": """$TITLE""", "scene": "$SCENE", "frames": "$FRAMES", "size": "$SIZE",
  "renderer": "$renderer", "commit": "$(git rev-parse --short HEAD 2>/dev/null || echo none)$(git diff --quiet 2>/dev/null || echo '+changes')",
  "when": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"), "overall": "$overall",
  "results": {"tests": "${R[tests]}", "checks": "${R[checks]}", "touch": "${R[touch]}", "audio": "${R[audio]}"},
  "notes": {"tests": """${N[tests]}""", "checks": """${N[checks]}""", "touch": """${N[touch]}""", "audio": """${N[audio]}"""},
}, open(sys.argv[1] + "/manifest.json", "w"), indent=1)
PY
python3 tools/proof_page.py "$OUT" >/dev/null
echo
for k in tests checks touch audio; do printf '  %-7s %-5s %s\n' "$k" "${R[$k]}" "${N[$k]}"; done
echo "  OVERALL $overall"
echo "  proof:  $OUT/index.html   sheet: $OUT/sheet.png   ($(du -h "$OUT/index.html" | cut -f1))"
[ $overall = pass ]

#!/usr/bin/env bash
# Record a scene's AUDIO and profile it for gaps, clicks and silence.
#
#   tools/audio_capture.sh <scene> <name> [frames=1800] [-- audio_profile.py args]
#   tools/audio_capture.sh res://samples/sample_game/orb_run_demo.tscn game 1800 -- --seams
#
# Movie Maker writes a real PCM track even under the Dummy audio driver, so a machine with no
# sound card records exactly what a player would hear. The video is recorded at 256x144 because
# here it is pure overhead.
#
# CAPTURE THE WHOLE THING. Audio bugs live at the joins — a loop point, a track change, a scene
# change — and those are seconds or minutes apart. A short capture of a screen can look perfect
# while the long one finds a five-second hole between tracks.
set -euo pipefail
cd "$(dirname "$0")/.."
SCENE="${1:?usage: $0 <scene> <name> [frames] [-- profile args]}"; NAME="${2:-audio}"; FRAMES="${3:-1800}"
EXTRA=(); if [ "${4:-}" = "--" ]; then shift 4; EXTRA=("$@"); fi
OUT="proof/audio"; mkdir -p "$OUT"; touch proof/.gdignore
tools/render.sh video "$SCENE" "$OUT/$NAME.avi" "$FRAMES" 256x144 >/dev/null
ffmpeg -y -v error -i "$OUT/$NAME.avi" -map 0:a -c:a pcm_s16le "$OUT/$NAME.wav" && rm -f "$OUT/$NAME.avi"
python3 tools/audio_profile.py "$OUT/$NAME.wav" "${EXTRA[@]}"
echo "wav kept at $OUT/$NAME.wav"

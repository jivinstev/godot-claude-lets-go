#!/usr/bin/env bash
# Record samples/cutscene/intro_source.tscn with Movie Maker and transcode it to the Theora
# .ogv the game plays. Re-run after changing the source scene.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
tools/render.sh video res://samples/cutscene/intro_source.tscn "$tmp/intro.avi" 210 1280x720
ffmpeg -y -loglevel error -i "$tmp/intro.avi" -vf scale=960:540 -c:v libtheora -q:v 6 \
	-c:a libvorbis -q:a 4 samples/assets/video/intro.ogv
rm -rf "$tmp"
ls -lh samples/assets/video/intro.ogv

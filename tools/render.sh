#!/usr/bin/env bash
# Run Godot with a real renderer — on a Mac/desktop directly, in a headless cloud VM through
# Xvfb + Mesa's software Vulkan (lavapipe). Every capture tool goes through this.
#
#   tools/render.sh shot  <scene> <out.png> [settle_frames=40] [WxH=1280x720]
#   tools/render.sh video <scene> <out.avi> [frames=300] [WxH=1280x720]     # Movie Maker, with audio
#   tools/render.sh sheet <in.avi|mp4> <out.png> [every_nth=30] [cols x rows=5x2] [crop=w:h:x:y]
#   tools/render.sh run   -- <godot args...>
#
# RENDERER=mobile (default) | compat. Mobile is what this project ships (project.godot), and the
# only backend whose output is evidence about what a phone shows; compat (OpenGL/llvmpipe) is
# faster but ignores some material features. `--headless` renders NOTHING — never use it for
# captures.
#
# Speed in a cloud VM: ~8 frames/s at 1280x720. 300 frames (10 s of game) ≈ 40 s.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$("$ROOT/tools/godot_path.sh")"
RENDERER="${RENDERER:-mobile}"
LVP=/usr/share/vulkan/icd.d/lvp_icd.json

sw() {
	# A desktop with a display (macOS, or Linux with $DISPLAY): just run it on the GPU.
	if [ "$(uname)" = "Darwin" ] || [ -n "${DISPLAY:-}" ] || ! command -v xvfb-run >/dev/null; then
		"$GODOT" --rendering-method "$([ "$RENDERER" = compat ] && echo gl_compatibility || echo mobile)" "$@"
		return
	fi
	if [ "$RENDERER" = "mobile" ] && [ -f "$LVP" ]; then
		# VK_DRIVER_FILES, not the deprecated VK_ICD_FILENAMES: with the old name current loaders
		# ignore it and Godot silently falls back to OpenGL — you capture the wrong renderer.
		xvfb-run -a -s "-screen 0 1920x1080x24" env VK_DRIVER_FILES="$LVP" \
			"$GODOT" --rendering-method mobile --rendering-driver vulkan --audio-driver Dummy "$@"
	else
		[ "$RENDERER" = "mobile" ] && echo "warning: no lavapipe — using Compatibility, which is NOT the shipping renderer" >&2
		xvfb-run -a -s "-screen 0 1920x1080x24" env LIBGL_ALWAYS_SOFTWARE=true GALLIUM_DRIVER=llvmpipe \
			"$GODOT" --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy "$@"
	fi
}

# Errors worth surfacing from a capture run. Godot exits 0 on script errors, so read the log.
ERR_RE="SCRIPT ERROR|Parse Error|Failed to (load|instantiate)"

cmd="${1:-}"; shift || true
case "$cmd" in
	shot)
		scene="${1:?scene}"; out="${2:?out.png}"; settle="${3:-40}"; res="${4:-1280x720}"
		mkdir -p "$(dirname "$out")"
		log="$(sw --resolution "$res" --path "$ROOT" res://tools/screenshot_scene.tscn -- "$scene" "$(realpath -m "$out")" "$settle" 2>&1)" || true
		grep -E "$ERR_RE" <<<"$log" && { echo "error: the scene logged script errors" >&2; exit 1; }
		[ -s "$out" ] || { echo "$log" | tail -20; echo "error: no PNG produced" >&2; exit 1; }
		echo "wrote $out"
		;;
	video)
		scene="${1:?scene}"; out="${2:?out.avi}"; frames="${3:-300}"; res="${4:-1280x720}"
		mkdir -p "$(dirname "$out")"
		# --fixed-fps ties game time to written frames: without it the software renderer's real
		# frame time leaks into delta and the motion races. Scenes driven by a wall clock must
		# switch to frame time under Movie Maker (see tools/autoplay/autoplay.gd).
		log="$(sw --write-movie "$(realpath -m "$out")" --fixed-fps 30 --disable-vsync --quit-after "$frames" \
			--resolution "$res" --path "$ROOT" "$scene" 2>&1)" || true
		grep -E "$ERR_RE" <<<"$log" && { echo "error: the scene logged script errors" >&2; exit 1; }
		grep -E "^(AUTOPLAY|VERIFY)" <<<"$log" || true
		[ -s "$out" ] || { echo "$log" | tail -20; echo "error: no video produced" >&2; exit 1; }
		echo "wrote $out ($frames frames)"
		;;
	sheet)
		in="${1:?in}"; out="${2:?out.png}"; nth="${3:-30}"; tile="${4:-5x2}"; crop="${5:-}"
		vf="select='not(mod(n\\,$nth))'"
		[ -n "$crop" ] && vf="$vf,crop=$crop"
		vf="$vf,scale=480:-1,tile=$tile:padding=4:color=white"
		ffmpeg -y -loglevel error -i "$in" -vf "$vf" -frames:v 1 -update 1 "$out"
		echo "wrote $out"
		;;
	run)
		[ "${1:-}" = "--" ] && shift
		sw "$@"
		;;
	*)
		sed -n '2,14p' "$0"; exit 1 ;;
esac

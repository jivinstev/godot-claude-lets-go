#!/bin/bash
# SessionStart hook — provision a Claude Code cloud VM so it can run the tests AND render
# screenshots, video and audio of the game. See docs/cloud-vm.md.
#
# Runs only in a remote Claude Code session ($CLAUDE_CODE_REMOTE=true) on Linux, so it never
# touches a developer's Mac. Idempotent and quiet: installs only what is missing, renders nothing.
#
# Everything it downloads is reachable on Claude Code's DEFAULT network policy:
#   - Ubuntu's apt archive (xvfb, mesa + lavapipe, ffmpeg)
#   - github.com release assets (the Godot binary)
#
# A hook in .claude/hooks/ does nothing on its own — .claude/settings.json registers it.
set -uo pipefail

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
[ "$(uname)" = "Linux" ] || exit 0

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
GODOT_VERSION="$(tr -d '[:space:]' < "$ROOT/godot-version" 2>/dev/null || echo 4.7-stable)"
GODOT_BIN="$HOME/godot-bin/godot"

echo "[setup] provisioning Godot $GODOT_VERSION + software rendering…"

# 1. System packages. mesa-vulkan-drivers is NOT optional: it provides lavapipe, without which
#    only the Compatibility renderer runs, and this project ships the Mobile renderer.
need_apt=0
for b in xvfb-run ffmpeg unzip curl; do command -v "$b" >/dev/null 2>&1 || need_apt=1; done
[ -f /usr/share/vulkan/icd.d/lvp_icd.json ] || need_apt=1
if [ "$need_apt" = 1 ] && command -v apt-get >/dev/null 2>&1; then
	SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
	$SUDO apt-get update -qq >/dev/null 2>&1
	$SUDO apt-get install -y -qq xvfb libgl1 libegl1 libgl1-mesa-dri libglu1-mesa mesa-vulkan-drivers \
		libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libxext6 libxrender1 \
		libfontconfig1 libfreetype6 unzip curl ffmpeg >/dev/null 2>&1 \
		&& echo "[setup] installed xvfb, mesa (llvmpipe + lavapipe), ffmpeg" \
		|| echo "[setup] WARN: apt install hit problems — see docs/cloud-vm.md"
fi

# 2. Godot, if the installed one is missing or a different version.
have=""; [ -x "$GODOT_BIN" ] && have="$("$GODOT_BIN" --version 2>/dev/null | head -1)"
want_prefix="$(echo "$GODOT_VERSION" | tr '-' '.')"   # 4.7-stable -> 4.7.stable
if [[ "$have" != "$want_prefix"* ]]; then
	mkdir -p "$(dirname "$GODOT_BIN")"
	url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
	tmp="$(mktemp -d)"
	if curl -fsSL --retry 3 "$url" -o "$tmp/godot.zip" && unzip -oq "$tmp/godot.zip" -d "$tmp"; then
		mv -f "$tmp/Godot_v${GODOT_VERSION}_linux.x86_64" "$GODOT_BIN" && chmod +x "$GODOT_BIN"
		echo "[setup] Godot $("$GODOT_BIN" --version | head -1) → $GODOT_BIN"
	else
		echo "[setup] WARN: could not download $url"
	fi
	rm -rf "$tmp"
fi

# 3. Import once so the first test run / render doesn't pay for it. Quiet; failure is harmless.
[ -x "$GODOT_BIN" ] && ( cd "$ROOT" && timeout 300 "$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true )

# Convenience only — every script finds the engine itself (tools/godot_path.sh).
[ -n "${CLAUDE_ENV_FILE:-}" ] && echo "export GODOT=$GODOT_BIN" >> "$CLAUDE_ENV_FILE"

echo "[setup] ready — ./run_tests.sh | tools/verify.sh | see CLAUDE.md"
exit 0

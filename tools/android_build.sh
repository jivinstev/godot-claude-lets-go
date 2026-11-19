#!/usr/bin/env bash
# Build a signed debug APK HERE — the fallback when CI isn't an option (out of Actions minutes,
# or you need a build right now). The default is CI: push a commit with [apk] in its message.
#
#   tools/android_build.sh                 build → build/<repo>.apk, verify the signature
#   tools/android_build.sh --publish       …and push it to the `media` branch, print a link
#
# Works on Claude Code's DEFAULT network policy, without Google's SDK (dl.google.com is blocked):
#   - apksigner / zipalign / adb come from Ubuntu's apt archive, laid out as an SDK at
#     /usr/lib/android-sdk — exactly the shape Godot's export checks for
#   - export templates (~1.2 GB, once) come from github.com/godotengine/godot-builds
#   - the preset uses use_gradle_build=false, so no Gradle and no NDK
# On a Mac, install the Android SDK + export templates per README → "Build an APK on your Mac".
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
GODOT="$(tools/godot_path.sh)"
PUBLISH=0; [ "${1:-}" = "--publish" ] && PUBLISH=1
ver_raw="$("$GODOT" --version | head -1)"            # 4.7.stable.official.<hash>
VER="$(echo "$ver_raw" | cut -d. -f1-3)"             # 4.7.stable
TAG="$(echo "$VER" | sed 's/\.\([^.]*\)$/-\1/')"     # 4.7-stable
ESVER="$(echo "$ver_raw" | cut -d. -f1,2)"           # 4.7
if [ "$(uname)" = "Darwin" ]; then
	TPL_DIR="$HOME/Library/Application Support/Godot/export_templates/$VER"
	SDK="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
	ES="$HOME/Library/Application Support/Godot/editor_settings-$ESVER.tres"
else
	TPL_DIR="$HOME/.local/share/godot/export_templates/$VER"
	SDK="${ANDROID_SDK_ROOT:-/usr/lib/android-sdk}"
	ES="$HOME/.config/godot/editor_settings-$ESVER.tres"
	if [ ! -x "$SDK/build-tools/debian/apksigner" ] && command -v apt-get >/dev/null; then
		echo "==> installing apksigner, zipalign, adb, JDK (apt)"
		SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO=sudo
		$SUDO apt-get install -y -qq apksigner zipalign adb default-jdk-headless >/dev/null
	fi
fi
if [ ! -f "$TPL_DIR/android_debug.apk" ]; then
	echo "==> downloading export templates $TAG (~1.2 GB, once)"
	tmp="$(mktemp -d)"
	curl -fL --retry 3 -o "$tmp/t.tpz" "https://github.com/godotengine/godot-builds/releases/download/$TAG/Godot_v${TAG}_export_templates.tpz"
	unzip -q "$tmp/t.tpz" -d "$tmp" && mkdir -p "$TPL_DIR" && cp "$tmp"/templates/* "$TPL_DIR/" && rm -rf "$tmp"
fi
JDK="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")}"
mkdir -p "$(dirname "$ES")"; [ -f "$ES" ] || printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$ES"
grep -vE '^export/android/(android_sdk_path|java_sdk_path|debug_keystore|debug_keystore_user|debug_keystore_pass) ' "$ES" > "$ES.tmp" || true
cat >> "$ES.tmp" <<EOT
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JDK"
export/android/debug_keystore = "$ROOT/ci/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
EOT
mv "$ES.tmp" "$ES"

APK="$ROOT/build/$(basename "$ROOT").apk"; mkdir -p build; rm -f "$APK"
echo "==> exporting"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-debug "Android" "$APK" 2>&1 | grep -iE "error|warn" | grep -viE "daemon" | head -10 || true
[ -s "$APK" ] || { echo "error: no APK produced (see messages above)" >&2; exit 1; }
SIGNER="$(ls "$SDK"/build-tools/*/apksigner 2>/dev/null | sort | tail -1)"
if [ -n "$SIGNER" ]; then "$SIGNER" verify "$APK" && echo "==> signature verified"; fi
echo "==> $APK ($(du -h "$APK" | cut -f1))"
[ $PUBLISH = 1 ] && tools/publish_media.sh "$APK"
exit 0

#!/usr/bin/env bash
# Give your fork its own identity in one go.
#   tools/rename_game.sh "Space Goats" com.yourname.spacegoats
# Sets the window/title-screen name (project.godot) and the Android package id (export_presets.cfg).
# The APK file is named after your GitHub repository automatically.
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="${1:?usage: tools/rename_game.sh \"Game Name\" com.you.game}"
PKG="${2:?package id like com.you.game}"
[[ "$PKG" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]] || { echo "error: package id must look like com.you.game (lowercase)" >&2; exit 1; }
esc="$(printf '%s' "$NAME" | sed 's/[\/&"]/\\&/g')"
sed -i.bak "s/^config\/name=.*/config\/name=\"$esc\"/" project.godot
sed -i.bak "s/^package\/unique_name=.*/package\/unique_name=\"$PKG\"/" export_presets.cfg
sed -i.bak "s/^package\/name=.*/package\/name=\"$esc\"/" export_presets.cfg
rm -f project.godot.bak export_presets.cfg.bak
grep -E '^config/name' project.godot; grep -E '^package/(unique_)?name' export_presets.cfg

#!/usr/bin/env bash
# FALLBACK ONLY. Commit files (a clip, a contact sheet, an APK) to the orphan `media` branch and
# print a GitHub link that opens on a phone (works for private repos when logged in).
#
#   tools/publish_media.sh <file> [more files...]      → media/<YYYY-MM-DD>/<file>
#
# The defaults are better: proof pages go out as Artifacts, APKs as GitHub Releases. Use this
# only when those are not available. It never touches your working branch: it uses a separate
# worktree at ../<repo>-media.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BRANCH=media
WT="$ROOT/../$(basename "$ROOT")-media"
slug="$(git -C "$ROOT" remote get-url origin | sed -E 's#(git@github.com:|https?://[^/]*github.com/)##; s#^.*/git/##; s#\.git$##')"
[ $# -gt 0 ] || { sed -n '2,10p' "$0"; exit 1; }

if [ ! -d "$WT/.git" ] && [ ! -f "$WT/.git" ]; then
	if git -C "$ROOT" fetch -q origin "$BRANCH" 2>/dev/null; then
		git -C "$ROOT" worktree add -q "$WT" "origin/$BRANCH" -B "$BRANCH"
	else
		git -C "$ROOT" worktree add -q --detach "$WT"
		git -C "$WT" checkout -q --orphan "$BRANCH"
		git -C "$WT" rm -rfq . >/dev/null 2>&1 || true
		printf '# media\n\nClips, sheets and APKs published by tools/publish_media.sh. Not code.\n' > "$WT/README.md"
		git -C "$WT" add README.md && git -C "$WT" commit -qm "Start the media branch"
	fi
fi
git -C "$WT" pull -q --ff-only origin "$BRANCH" 2>/dev/null || true
day="$(date +%Y-%m-%d)"; mkdir -p "$WT/$day"
for f in "$@"; do cp "$f" "$WT/$day/"; git -C "$WT" add "$day/$(basename "$f")"; done
git -C "$WT" commit -qm "media: $(for f in "$@"; do basename "$f"; done | paste -sd ' ' -)"
for i in 1 2 3 4; do git -C "$WT" push -q -u origin "$BRANCH" && break; sleep $((2 ** i)); done
for f in "$@"; do echo "https://github.com/$slug/blob/$BRANCH/$day/$(basename "$f")"; done

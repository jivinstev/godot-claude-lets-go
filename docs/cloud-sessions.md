# Claude Code cloud sessions

Open this repo (or your fork) in [Claude Code on the web](https://claude.ai/code) and the session
provisions itself: `.claude/hooks/session-start.sh` runs at session start (registered in
`.claude/settings.json`) and installs, only if missing:

| What | From | Why |
|---|---|---|
| Godot (version in `godot-version`) | `github.com` release assets | run, test, export |
| `xvfb`, Mesa (`llvmpipe` OpenGL + `lavapipe` Vulkan), `ffmpeg` | Ubuntu apt archive | render real frames with no GPU or display; encode clips |

First run takes about two minutes; then `./run_tests.sh`, `tools/verify.sh` and the rest just
work. The hook does nothing on a Mac or any non-cloud machine.

## Network: works on the Default policy

Everything the template does was verified on Claude Code's **Default** (limited) network policy
with **no extra allowed hosts**:

| Need | Host(s) | Default policy |
|---|---|---|
| Godot binary, export templates | `github.com` → `release-assets.githubusercontent.com` | ✅ allowed |
| Render/video packages, Android signing tools | Ubuntu apt mirrors | ✅ allowed (package managers) |
| Push branches, open PRs, CI | GitHub (via the session's git proxy and GitHub tools) | ✅ |
| Android SDK from Google | `dl.google.com` | ❌ blocked — **not needed**: see [building-apks.md](building-apks.md) |

### Optional: let Claude download CC0 assets

The usual free-asset sites are blocked by default. If you want Claude to fetch assets itself, add
the hosts you use to your environment's **allowed hosts** (claude.ai → Claude Code → your
environment → Network access → *Limited* + allowed hosts). Otherwise download on your own machine
and commit the files.

| Site | Hosts to allow |
|---|---|
| Kenney | `kenney.nl` |
| Quaternius / Poly Pizza | `quaternius.com`, `poly.pizza`, `static.poly.pizza` |
| Poly Haven | `polyhaven.com`, `dl.polyhaven.org` |
| ambientCG | `ambientcg.com` |
| OpenGameArt | `opengameart.org` |
| Freesound | `freesound.org`, `cdn.freesound.org` |

These hosts are a starting point, not tested from a session: downloads sometimes redirect to a
CDN host. If a fetch is refused, the proxy's error names the host to add.

Every asset still needs a `CREDITS.md` row before it is imported.

## What a VM can and cannot tell you

It can: run the game, play it through real input, record frames on the shipping Mobile renderer,
record the real audio mix, tap every button. About 8 frames/s of rendering at 1280×720 — a
20-second capture takes about a minute.

It cannot: tell you whether it feels good, whether the mix sounds good, what the frame rate or
latency is on a phone, or whether a physical controller works. That is what the APK is for.

## GitHub in a cloud session

There is no `gh` CLI in the VM. Claude uses the GitHub MCP tools for issues and pull requests, and
plain `git push` for branches — which is also how it triggers an APK build (`[apk]` in a commit
message; see [building-apks.md](building-apks.md)).

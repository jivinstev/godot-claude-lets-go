# godot-claude-lets-go — build plan

Status: **APPROVED 2026-11-19, executing.** This file is the source of truth while the template is
being built; each phase's checkbox is ticked by the change that finishes it, so a fresh session
can resume from here. It is deleted (or moved to `docs/`) once the repo is ready to open source.

## Goal

A forkable, MIT-licensed Godot 4.7 starter where **Claude Code on the web builds a feature, plays
it, records it, and proves it works**, with no setup beyond "Use this template" + open a session.
Extracted from the infrastructure of two private games, with none of their gameplay.

A fork gets, by default:

1. **Cloud session provisioning** — a SessionStart hook installs Godot, software Vulkan/OpenGL
   (lavapipe / llvmpipe), Xvfb and ffmpeg. Measured: works on the **default** network policy.
2. **One-command tests** — `./run_tests.sh` (GUT, hardened against GUT's silent "skip a file that
   failed to parse and report green" failure).
3. **Autonomous verification** — stills, video, contact sheets, audio capture + profiling, and a
   touch probe that taps every button the way a finger does. Bundled behind one entry point,
   `tools/verify.sh`, that writes a proof folder the agent publishes as an Artifact.
4. **Verification on by default** — `CLAUDE.md` defines "done" as *demonstrated*, and a
   `/verify` skill tells the agent what evidence each kind of change needs.
5. **APK builds that respect free CI minutes** — on `[apk]` in a commit message, and on every PR
   merged to `main`; published as a GitHub Release with a direct download link. Plus the
   **local fallback**: build the APK inside the cloud session and commit it to a `media` branch.
6. **Mac** — compatible, not built: the README says how to install Godot on a Mac, open the
   project, run it and run the tests (`run_tests.sh` already finds `/Applications/Godot.app`).
7. **Reusable building blocks** — touch controls (virtual pad, several layouts), scene transitions,
   save/load, audio manager + music, video cutscenes with subtitles, a touch-safe menu base and
   pause menu.
8. **Samples + a tiny sample game** that exercise every building block, so CI keeps them honest.
9. **A short README**: setup, what you get, starter prompts.

## What the research found (evidence, not assumptions)

- **Network: zero firewall holes needed for the core loop.** Tested from this session on the
  Default (limited) policy: Godot + export templates download from GitHub releases ✅; Ubuntu apt
  (xvfb, mesa, ffmpeg, apksigner, zipalign) ✅; `dl.google.com` ❌ — not needed, because the
  local APK path uses apt's signing tools and `use_gradle_build=false`.
  **Blocked:** CC0 asset sites (opengameart, kenney.nl, freesound, archive.org). So the samples use
  **procedurally generated** art/audio/video plus CC0 assets already vendored in PPP. The README
  lists the asset hosts as *optional* allowlist entries for people who want to pull CC0 packs.
- **Which source is more mature:** Rocktopia for the hook, `run_tests.sh` hardening, `cloud_render.sh`,
  audio capture, touch probe, save manager, audio manager, menu base; PPP for the generic virtual
  pad, cutscene player + SRT subtitles, confirm overlay, scene-transition queueing, Android docs.
  Bugs to not copy: Rocktopia's Android scripts default to a stale `GODOT` path; PPP's runner lacks
  the GUT-skip check; Rocktopia links to docs that only exist in PPP.
- **How you ask for verification** (from your PPP/Rocktopia sessions): *"verify with video and share
  the video and contact sheet"*, *"capture the vid in realistic gameplay"*, *"before and after vids"*,
  *"screenshots or vids of a few options"*, *"double check yourself with a couple videos"*,
  *"run the test 50 times to make sure it doesn't flake"*. Recurring frustration: a fix reported
  done that wasn't ("3rd time I've asked"). So the default is: **no "done" without a clip of the
  real repro path**, variants side by side when it's a taste call, APKs sparingly.
- **Mac:** PPP was developed in the Godot editor on a Mac. Decision: instructions only, no Mac
  export or CI build. Mac-sensitive things to keep right: no Linux-only paths in game code,
  scripts use POSIX/bash that also runs on macOS's bash 3.2 where they're meant for desktops.

## Repo layout (main)

```
README.md                  short: setup, what you get, starter prompts
CLAUDE.md                  how agents work here: definition of done, verification ladder, rules
CREDITS.md                 every asset, its license, before import
LICENSE                    MIT (exists)
godot-version              one line: 4.7-stable — read by hook, scripts and CI
project.godot              Mobile renderer, landscape, touch→mouse emulation off
export_presets.cfg         Android (arm64, no gradle)
run_tests.sh
.claude/
  settings.json            registers the SessionStart hook
  hooks/session-start.sh   provisions the VM (idempotent, desktop-safe)
  skills/verify/SKILL.md   what evidence each change type needs, and how to publish it
.github/workflows/
  ci.yml                   tests on PRs and on main (not every branch push — minutes)
  build.yml                APK on [apk] or PR-merged-to-main → GitHub Release
ci/debug.keystore          public Android debug key (debug only, documented as such)
addons/gut/                GUT 9.6.0, MIT
scripts/autoload/          SceneDirector, TouchControls, AudioManager, SaveManager, Locale(opt)
scripts/ui/                BaseScreen (touch drag-scroll, pinned buttons), PauseMenu, ConfirmOverlay
scripts/cutscene/          CutscenePlayer + SRT subtitles
scenes/title_screen.tscn   THE starting point: title, "Play", "Samples", "Quit"
samples/                   self-contained, deletable in one `rm -rf`
  sample_game/             ~300 lines: a tiny game (below)
  cutscene/                generated .ogv + .srt, skippable
  touch_layouts/           the virtual-pad configurations side by side
  scene_3d/                a lit 3D scene with a CC0 character, proves the Mobile renderer
tools/
  verify.sh                ONE entry point → proof/<name>/{shots,clip.mp4,sheet.png,audio.txt,touch.txt,index.html}
  cloud_render.sh          shot | video | sheet  (Mobile renderer by default)
  screenshot_scene.*       still of any scene after N frames
  touch_probe.*            taps every visible button via the real input path
  audio_capture.sh + audio_profile.py
  autoplay/                the "self-driving scene" pattern used for gameplay video
  android_setup.sh + android_build.sh   local APK fallback
  publish_media.sh         FALLBACK ONLY: push a clip/APK to the orphan `media` branch, print its URL
  rename_game.sh           set game name, package id, APK name in one go
tests/unit/                tests for every building block and the sample game
tests/support/             AudioProbe, input helpers
docs/                      cloud-vm, android-build, verification, touch-controls — linked from README
```

## The sample game (deliberately tiny)

**"Orb Run"** (working name): a top-down 2D arena. Move with the virtual stick / WASD / a gamepad,
collect 10 orbs before a 30 s timer runs out, avoid two wandering hazards. Music loop, pickup and
hit sounds, a win/lose screen, best time saved to disk, pause menu. New Game plays a 5-second
intro cutscene first (skippable). That touches every building block once: input, touch layout,
scene transitions, audio, save, cutscene, menus, pause.

It ships with an **autoplay bot** (steers toward the nearest orb) so the agent can record a real
playthrough with sound — that recording is the proof Artifact. Assets are generated by checked-in
scripts (shapes/gradients, synthesized SFX and a short chiptune loop, the cutscene rendered by
Godot's Movie Maker and transcoded to Theora), so licensing is trivially clean. One vendored CC0
Quaternius model appears in the 3D sample.

## Verification by default — how it's wired

1. `CLAUDE.md` **Definition of done**: tests green *and* the evidence from the ladder that can see
   the change (tests → still → video+sheet → audio capture → touch probe → device). Uncertainty is
   stated, not hidden. "Fixed" requires a clip of the repro path. Taste calls get variants.
2. `/verify` skill: picks the evidence for the change type, runs `tools/verify.sh`, `Read`s the
   contact sheet itself before showing anyone, then publishes `proof/<name>/index.html` as an
   **Artifact** (video embedded, sheet, test summary, touch + audio verdicts). Fallback only when
   Artifacts aren't available: `SendUserFile`, then `tools/publish_media.sh`. Binaries on branches
   are a last resort, never the default.
3. `CLAUDE.md` tells the agent to run `/verify` before saying a feature is done — no Stop hook (your
   past sessions show blocking Stop hooks were more irritating than useful).

## CI-minute policy

| Event | Tests | APK |
|---|---|---|
| push to a branch | no (agent runs them in-session) | only if message has `[apk]` |
| pull request | yes | no |
| PR merged to main | yes | **yes** → Release `build-pr-N` |
| manual | — | yes (Actions button) |

Releases are pruned (last 5 PR builds, last 10 `[apk]` builds); no run artifacts (storage quota).
Godot + templates are cached.

## Phases (each ends with its own verification)

- [x] **P0 Skeleton** — project, `godot-version`, hook, `run_tests.sh`, GUT, dummy title screen.
      *Verify:* fresh-VM run of the hook, tests green, a deliberately broken test file makes the
      runner fail (proves the hardening), still of the title screen.
- [ ] **P1 Verification tools** — cloud_render, screenshot, touch probe, audio capture/profile,
      autoplay pattern, `verify.sh`, `/verify` skill. *Verify:* run each against the title screen;
      touch probe reports every button `ok`; a planted covered button reads `DEAD`.
- [ ] **P2 Building blocks** — SceneDirector, TouchControls (+ layouts), AudioManager, SaveManager,
      BaseScreen, PauseMenu, ConfirmOverlay, CutscenePlayer. Unit tests each. *Verify:* touch probe
      on every menu; audio probe asserts sound starts/stops.
- [ ] **P3 Samples + sample game + generated assets + CREDITS.md.** *Verify:* autoplay playthrough
      video with audio, contact sheet, audio profile with no gaps, touch probe on every screen,
      the full proof Artifact.
- [ ] **P4 Builds** — export presets, `build.yml`, `ci.yml`, local `android_*` fallback,
      `publish_media.sh`, `rename_game.sh`. *Verify:* an `[apk]` push produces a Release with a
      working download URL (the default); the local fallback builds and `apksigner verify` passes.
- [ ] **P5 Docs** — README (short), CLAUDE.md, docs/, starter prompts. *Verify:* a **fresh cloud
      session** on the default environment, given only a starter prompt, adds a small feature and
      publishes its own proof Artifact — the real test of "works for a fork".
- [ ] **P6 Open-source readiness** — scrub (no private repo names, game slugs, paths, secrets),
      license check on every vendored file, final proof Artifact + APK link to you.

## Starter prompts (README draft)

- *"Read CLAUDE.md. Replace the title screen's Play button with a [genre] game where [one-sentence
  idea]. Use the `[layout]` touch layout. Verify it with a gameplay video and send me the proof."*
- *"Add a 10-second intro cutscene before the game starts, with subtitles. Use a placeholder video
  for now and show me it playing."*
- *"Give me three options for [the HUD / the camera / the menu style] as screenshots side by side;
  I'll pick one."*
- *"[Bug description]. File an issue, reproduce it on video, fix it, and show me before and after."*
- *"Build me an APK so I can try it on my phone."*

## Out of scope

Networking/online, macOS/iOS/Windows/web export (documented as "should work, untested"), store
signing/notarization, an asset library beyond what the samples need, porting either game's systems
(rhythm engine, overworld, NPC crowds, per-seat raw input routing).

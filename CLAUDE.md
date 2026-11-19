# CLAUDE.md

A Godot **4.7** game project (GDScript, **Mobile** renderer) built to be developed by Claude Code
— in the cloud or on a Mac — with every change **played, recorded and proven** before it is called
done. Targets: **Android** (phones, touch) and **macOS** (run from the Godot editor).

`scenes/title_screen.tscn` is the starting point. `scenes/game.tscn` is a placeholder for the
game. `samples/` holds working examples of every building block (delete the folder to drop them).

---

## How we work

Take pride in three things equally:

- **The quality of the work** — correct, robust, clear. One thing done well beats three almost-working.
- **The honesty of your communication** — say what you verified and what you did not. "Done" is
  something you *demonstrate*, not something you claim. Catching your own incomplete work before
  the user does is a win.
- **The thoroughness of your method** — evidence before theory, reproduction before diagnosis,
  verification before declaration, root cause before patch.

### The lesson that matters most

**A game renders convincingly long before it is playable, and a test suite cannot see the
difference.** A button covered by an invisible Control, a camera that never shows the action, a
sound that never plays, a touch control sitting on top of a menu: each passes every unit test and
looks fine in a screenshot of the wrong moment.

## Definition of done — verification is ON by default

After **any** change a player could see, hear or touch (gameplay, menus, input, visuals, audio,
cutscenes, scene flow), and before saying it works:

1. `./run_tests.sh` is green — and a new test exists for new logic.
2. **Run the `/verify` skill** (`.claude/skills/verify/SKILL.md`): an `Autoplay` demo drives the
   real game with real input and `check()`s the outcome; `tools/verify.sh` records it with sound on
   the shipping renderer, makes a contact sheet, profiles the audio and taps every button.
3. **Read the contact sheet yourself**, then publish `proof/<name>/index.html` as an **Artifact**
   and give the user the link.
4. Report plainly: what was checked, what passed, what was **not** verifiable here (feel, mix
   quality, latency, device performance, real controllers).

A **bug fix** is proven by a capture of the exact repro path (before *and* after when you can).
A **taste call** (camera, HUD, look) gets 2–3 variants side by side for the user to choose.
Pure refactors and doc edits need only the tests. If you cannot verify something, say so — never
imply it.

## Commands

| What | Command |
|---|---|
| All tests (smoke-loads every scene, then GUT) | `./run_tests.sh` |
| One test file, 50 times (flake check) | `REPEAT=50 ./run_tests.sh test_save` |
| Prove a change (video, sheet, checks, touch, audio → proof page) | `tools/verify.sh <name> <demo.tscn> [--touch a,b] [--touch-sim] [--audio "..."]` |
| A still of any scene | `tools/render.sh shot res://path.tscn out.png [frames]` |
| A video of any scene (Movie Maker, with audio) | `tools/render.sh video res://path.tscn out.avi [frames]` |
| Can a finger reach every button? | `tools/touch_probe.sh res://a.tscn [...]` (`TOUCH_LAYOUT=FULL`, `TOUCH_SIZE=2340x1080`) |
| Audio of a scene, profiled for gaps and clicks | `tools/audio_capture.sh res://scene.tscn name [frames]` |
| APK (default): CI builds it, posts a Release | commit with `[apk]` in the message and push |
| APK (fallback): build here | `tools/android_build.sh [--publish]` |
| Rename the game / package id | `tools/rename_game.sh "Name" com.you.game` |

Every script finds Godot itself (`tools/godot_path.sh`): `$GODOT`, then `/Applications/Godot.app`,
then `~/godot-bin/godot` (cloud VM), then `godot` on PATH.

## The verification ladder — use the cheapest rung that can see the bug

1. **Tests** (`tests/unit/`, GUT) — logic, state, geometry. Cannot see rendering.
2. **Stills** — layout, colour, framing. One frame: blind to anything transient.
3. **Video + contact sheet** — anything that moves, flashes, transitions or responds to input.
   Read ONE tiled image to see ten moments.
4. **Audio capture** — Movie Maker writes the real mix even with no sound card. Short captures hide
   the bugs: audio breaks at *joins* (loops, track changes, scene changes), so capture across them.
   One quiet window is usually the music; only a *run* means it stopped. Check the source file
   before blaming code.
5. **Touch probe** — taps every visible button through the real input path and every CanvasLayer;
   fails on `DEAD` (covered) and `UNDER` (overlaps an on-screen control). Existence ≠ reachability.
   Disabled buttons are listed, not probed: if a screen starts with some disabled, give it a
   `func touch_probe_setup() -> void` that puts it in a state where they're enabled.
6. **A real phone** (APK) — feel, latency, performance, mix quality. Not verifiable here; say so.

**When a capture looks wrong, suspect the harness first** (a demo that never reached the scene, a
wait too short), then the game. **Render on the renderer you ship** — `tools/render.sh` defaults to
Mobile (Vulkan via lavapipe in a VM); Compatibility silently ignores some material features.
**When a fix and its test both pass, revert the fix and watch the test go red.**

**Verification never touches the player's save.** `run_tests.sh`, `tools/verify.sh`,
`tools/touch_probe.sh` and every `Autoplay` demo point `SaveManager` at a throwaway file via the
`GAME_SAVE_PATH` env var. To prove something **survives a restart**, call
`launch_fresh("res://some_scene.tscn")` from the demo: a second Godot process that reads the same
throwaway save and returns what it printed.

## Map

| Path | What |
|---|---|
| `scripts/autoload/` | `SceneDirector` (fades, queued changes, test seam), `TouchControls` (on-screen pad layouts), `AudioManager` (music crossfade, SFX, volumes), `SaveManager` (atomic, tolerant, versioned JSON) |
| `scripts/ui/` | `BaseScreen` (menu base: tap/pad/keys, drag-scroll, pinned exit), `PauseMenu`, `ConfirmOverlay`, `UiStyle` (look) |
| `scripts/cutscene/` | `CutscenePlayer` (Theora video + SRT subtitles + skip + preload), `Srt` |
| `tools/autoplay/autoplay.gd` | `Autoplay` — the base class for every verification demo |
| `tools/demos/`, `samples/**/_demo` | demos; copy one to start |
| `samples/` | Orb Run (sample game + bot demo), cutscene, touch layouts, 3D scene |
| `tests/unit/`, `tests/support/` | GUT tests; `AudioProbe` (hear a bus), `RealWindow`, `Tone` |
| `docs/` | cloud sessions & network, building APKs, verification details |

## Rules learned the hard way

Each cost real debugging in the projects this template came from. Don't undo them without
understanding why they exist.

- **GUT silently skips a test file that fails to parse** and still reports green. `run_tests.sh`
  fails the build on `Ignoring script` / `Failed to load script`. If you see that failure, your
  suite did not run — usually `var x := untyped.call()`; write `var x: Type = ...`.
- **Godot exits 0 on script errors.** The runner and render tools grep the log instead.
- **Headless windows are 64×64.** Anything that injects touch/mouse positions must force a real
  window size first (`RealWindow.use(self)`, the touch probe does it itself).
- **`--headless` renders nothing.** Captures go through `tools/render.sh` (Xvfb + lavapipe in a VM).
- **Under Movie Maker, game time ≠ wall time.** `--fixed-fps 30` ties delta to written frames; use
  timers / delta, never `Time.get_ticks_msec()`, for anything that must line up with the capture.
- **Menus are tap-to-click; there is no virtual pad behind them.** Every player-facing screen must
  be operable by tapping its own controls. Mouse emulation from touch is off (on purpose), so
  Godot's `ScrollContainer` cannot be dragged — `BaseScreen` implements drag-scroll in `_input`.
- **`Control` defaults to `MOUSE_FILTER_STOP`.** A decorative Control laid over a button silently
  eats its taps. Set `MOUSE_FILTER_IGNORE` on anything that is not meant to be tapped.
- **Never use `Window` / `Popup` / `*Dialog` for player UI** — an embedded subwindow draws above the
  touch layer and fingers cannot reach it. Use `ConfirmOverlay` or an in-tree `CanvasLayer`.
- **Whatever paints touch controls must stand down when a menu opens over it.** The stick claims
  the left half of the screen. `PauseMenu` does this; anything new that overlays gameplay must too.
- **Touch controls emit raw joypad events, never actions**, so the InputMap is the single source of
  truth and a Bluetooth pad behaves identically. Don't route touch through `ui_*` actions.
- **A gain change mid-waveform is a click.** Ramp volume (≥40 ms); `AudioManager` does.
- **`SubViewport` inherits its parent's `World3D`** — set `own_world_3d = true` for a separate view.
- **`MultiMesh` instance data is not readable headlessly** — mirror what tests need in your own state.
- **`int("0xFF")` is 0** — use `String.hex_to_int()`.
- **`JSON.parse_string()` logs an engine error on bad input** — use `JSON.new().parse()` where bad
  input is expected (GUT counts engine errors as test failures).
- **Anchor scripted edits to the END of a function, not to a comment** — an inserted `func` in the
  middle of another orphans everything below it.

## Project settings that matter

- `renderer/rendering_method="mobile"` — ships on phones; captures use the same.
- `textures/vram_compression/import_etc2_astc=true` — required for Android export.
- `pointing/emulate_mouse_from_touch=false` — so a touch never doubles as a mouse click.
- Landscape, 1280×720 base, `canvas_items` stretch with `expand` aspect.
- Input actions: `move_left/right/up/down`, `action_a`, `action_b`, `pause` (+ built-in `ui_*`).

## Shipping

- **One branch per change, PR into `main`.** Name branches after the work (or take the
  `claude/...` branch the session gave you). Write `Closes #N` in PRs that fix an issue.
- **APKs cost CI minutes — build them sparingly**: at the end of a milestone, for an
  Android-specific fix, or when the user asks. A proof video usually answers "does it work".
  Ask for one with a commit whose message contains `[apk]`; merges to `main` build automatically.
  Hand the user the `…/releases/download/apk-N/<repo>.apk` link as a bare line.
- **Fallback, only if CI can't**: `tools/android_build.sh --publish` (media branch). Don't commit
  binaries to working branches.
- **Check `state` / `merged`, not `mergeable_state`, before saying a PR is open** — the latter
  reads `unknown` on PRs that merged minutes ago.
- **In a cloud session there is no `gh` CLI** — use the GitHub MCP tools for issues and PRs.
- For long work, keep the plan in a checked-in `.md` with checkboxes, so a fresh session (or a
  cheaper model) can resume where this one stopped.

## Assets

Every asset gets a row in `CREDITS.md` **before** it is imported. Prefer CC0; vendor files into the
repo rather than hot-linking. Godot plays video only as Ogg Theora (`.ogv`) — convert with
`ffmpeg -i in.mp4 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 out.ogv`. Use `.ogg` for music,
`.wav` for short sounds. Keep this file true: if you change how something works, fix the line here
in the same commit.

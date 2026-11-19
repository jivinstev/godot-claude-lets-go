---
name: verify
description: Prove a change to this Godot game works by playing it — record real gameplay with sound, check it, and publish a proof page (video, contact sheet, checks, touch and audio results) as an Artifact. Use after ANY change to gameplay, visuals, menus, audio, input or scenes, BEFORE saying it is done; and whenever the user asks to verify, test, check, "show me", "send a video/screenshot", "before and after", or "options side by side".
---

# Verify a change

"Done" in this repo means **demonstrated**: the user can watch it work. Tests alone are not
enough — this kind of game renders convincingly long before it is playable, and a unit test
cannot see a button covered by an overlay, a camera that misses the action, or a sound that
never plays.

## 1. Pick the evidence that can actually see the change

| Change | Minimum evidence |
|---|---|
| Pure logic (scoring, saves, rules) | a unit test in `tests/unit/` — and revert the fix once to watch it go red |
| Anything on screen that is static (layout, colour, HUD) | a still (`tools/render.sh shot`) — Read the PNG |
| Anything that moves, animates, transitions, or responds to input | **video + contact sheet via `tools/verify.sh`** |
| Menus, buttons, any tappable control | the above **plus `--touch <screens>`** — phones have no cursor |
| Music, sound effects, cutscenes | the above **plus `--audio "--quiet-below 0.01 --max-quiet-run 4"`** |
| A bug fix | a capture of **the exact repro path**, before (if you can) and after |
| A taste call (camera, HUD, style) | 2–3 variants side by side; let the user pick |

What none of these can tell you: whether it *feels* right, whether the mix sounds good, real
latency, real-device performance. Say so; that is what an APK on a phone is for.

## 2. Write a demo that plays the real game

Copy `tools/demos/title_demo.gd` (+ its one-line `.tscn`). Extend `Autoplay`, drive the game
through the **same input a player uses** (`tap_button`, `tap`, `press`, `hold`, `stick`), and
`check()` the outcome. Calling game functions directly proves the function, not the feature.

Make it realistic: show the actual interaction the user cares about (the collision, the reaction,
the crowd moving), long enough to see it — and for audio, long enough to cross every join
(track changes, loops, scene changes). Short captures hide seam bugs.

## 3. Run it

```bash
tools/verify.sh <name> res://tools/demos/<demo>.tscn \
    --touch res://scenes/<screen>.tscn[,more] [--touch-sim] [--audio "..."] --title "<What changed>"
```

It runs the tests, records on the shipping (Mobile) renderer with real audio, makes a contact
sheet, profiles the audio, taps every button, and writes `proof/<name>/index.html`.
`--touch-sim` draws the phone's on-screen controls into the capture.

## 4. Look before you show

**Read `proof/<name>/sheet.png` yourself.** Does it show the thing you claim? If the capture is
wrong, suspect the harness first (a demo that never reached the scene, a wait too short, a
camera pointed elsewhere) — then the game. Do not publish a proof you have not looked at.
A `warn` on audio means silence: fine for a silent screen, a bug anywhere sound should play.

## 5. Publish the proof page as an Artifact (the default)

Load the `artifact-design` skill if this session has not yet, then publish
`proof/<name>/index.html` with the Artifact tool (icon: `video`; description: one sentence on what
was verified). The page is self-contained — video and images are embedded — so nothing else is
needed. Re-running verify on the same name and republishing the same path updates the same link.

Fallbacks, only if Artifacts are unavailable: `SendUserFile` with `clip.mp4` + `sheet.png`; and
last of all `tools/publish_media.sh` (commits media to an orphan `media` branch). Never commit
proof media to a working branch.

## 6. Report honestly

Give the link, then one or two lines: what was checked, what passed, and what was **not**
verified (feel, audio quality, device performance, real controllers). If anything failed, say so
first and fix it before calling the work done.

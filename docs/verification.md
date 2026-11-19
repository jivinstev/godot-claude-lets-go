# How verification works

The short version is in `CLAUDE.md` and `.claude/skills/verify/SKILL.md`. This is the detail.

## The proof page

`tools/verify.sh <name> <scene>` writes `proof/<name>/` (git-ignored):

| File | What |
|---|---|
| `clip.mp4` | the capture, H.264 + AAC, with the game's real audio |
| `sheet.png` | ten evenly spaced frames in one image — what the agent reads |
| `last.png` | the final frame |
| `run.log` | every `AUTOPLAY` step and `VERIFY PASS/FAIL` line |
| `tests.txt`, `touch.txt`, `audio.txt` | raw output of each check |
| `index.html` | everything above in one self-contained page (media embedded) |

The page is what gets published as an Artifact. It opens with the verdict, then a row per check
(tests, gameplay checks, touch reachability, audio), then the video, sheet and details.

## Writing a demo

```gdscript
extends Autoplay

func run() -> void:
	await goto("res://scenes/title_screen.tscn")
	await tap_button("Play")
	await hold("move_right", 1.5)
	check(scene().player.position.x > 600, "holding right moves the player right")
```

| Step | Does |
|---|---|
| `goto(path)` | change scene immediately, wait 3 frames |
| `tap_button(text)` / `tap(pos)` | real `InputEventScreenTouch` at the button's centre / a point |
| `press(action)` / `hold(action, sec)` / `down` / `up` | an `InputEventAction` for an InputMap action |
| `stick(dir, sec)` / `set_stick(dir)` | left-stick axis events, as a pad sends |
| `wait(sec)` / `wait_frames(n)` / `wait_until(cond, timeout, each_frame)` | game-time waits |
| `check(ok, what)` | records `VERIFY PASS/FAIL what` (escape a literal `%` as `%%` when formatting) |
| `launch_fresh(scene)` | run a second, fresh Godot process on the same save; returns its output — proves persistence |
| `scene()`, `find_button(text)` | the current scene; a visible button by text |

Rules: drive the game through input, not by calling its functions. Show the interaction the user
cares about, for long enough to see it. A bot that steers from game state is fine (see
`samples/sample_game/orb_run_demo.gd`) — as long as what it *does* goes through the stick and
buttons.

## Touch probe verdicts

| Verdict | Meaning |
|---|---|
| `ok` | a tap at its centre reached it |
| `DEAD` | on screen, unreachable — something covers it (often a Control with the default `MOUSE_FILTER_STOP`) |
| `UNDER` | reachable at the centre, but part of it lies under an on-screen touch control |
| `off` | outside the viewport; needs scrolling first |
| `moved` | the screen rebuilt before its turn; re-run before believing it |
| `small` | under 44 px — too small for a thumb (warning) |
| `disabled` | not probed; counted in RESULT. Enable it from the screen's `touch_probe_setup()` |

`TOUCH_LAYOUT=FULL` probes with a gameplay layout drawn on top; `TOUCH_SIZE=2340x1080` a real panel.

## Audio checks

`--audio "--quiet-below 0.01 --max-quiet-run 4"` gates the run: fail if more than 4 consecutive
half-second windows are quiet. Add `--seams` to look for clicks. Without `--audio`, the audio is
profiled but only *silence* is flagged (as a warning). One quiet window is usually the music; a run
means it stopped. Check the source file before blaming code.

Inside tests, `AudioProbe.listen_to("Music")` puts a capture on a bus and returns real levels:
silence reads 0.0, a playing sound ~0.5.

## Saves during verification

Every tool sets `GAME_SAVE_PATH=user://verify_save.json` (tests: `user://test_suite_save.json`), and
`SaveManager` uses it instead of the real save — so a demo that presses "Reset progress", or one
that crashes halfway, cannot damage the player's data.

## Lessons already paid for

- A **centre tap passed** a button that a shoulder trigger half-covered; the contact sheet showed it.
  The probe now checks overlap geometrically (`UNDER`).
- A demo at a **non-native capture size** tapped the wrong place, because input events are in window
  pixels; `Autoplay` now converts.
- A capture that quietly **records nothing useful** still "passes". Read the sheet.
- A **dry run from a fresh session** found that verification wrote over the real save, a crashed
  capture produced no page at all, and disabled buttons were skipped without a word. All fixed.
  Running the template cold, from a starter prompt, is the best test it has.

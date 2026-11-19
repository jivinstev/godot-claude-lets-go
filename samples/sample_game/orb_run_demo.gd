extends Autoplay
## A full session of Orb Run, played through the REAL input path, with checks along the way:
## samples menu → cutscene (skipped by two taps) → game (a bot steers the stick) → pause by
## tapping the on-screen II → resume → win → results screen → best time saved.
##
##   tools/verify.sh orb-run res://samples/sample_game/orb_run_demo.tscn --touch-sim --frames 1500 \
##       --audio "--quiet-below 0.005 --max-quiet-run 6"
##
## The bot only reads game state to decide where to steer; everything it DOES goes through the
## stick and buttons, as a player's thumb would.

var game: Node2D


func run() -> void:
	SaveManager.save_path = "user://demo_save.json"   # never touch a real player's best time
	SaveManager.clear()
	await goto("res://samples/samples_menu.tscn")
	await wait(0.8)
	await tap_button("Orb Run — a tiny game")
	await wait(2.6)
	var cut := scene() as CutscenePlayer
	check(cut != null, "the intro cutscene plays first")
	if cut:
		check(cut.position_sec() > 1.0, "the cutscene video is advancing (%.1f s in)" % cut.position_sec())
		check(cut.current_subtitle() != "", "a subtitle is showing: \"%s\"" % cut.current_subtitle().replace("\n", " "))
	await tap(Vector2(640, 360), "tap once (shows the skip hint)")
	await wait(0.4)
	await tap(Vector2(640, 360), "tap again (skips)")
	var started := await wait_until(func(): return scene() != null and scene().name == "OrbRun", 3.0)
	check(started, "skipping the cutscene starts the game")
	if not started:
		return
	game = scene()
	await wait(0.5)
	check(AudioManager.is_music_playing(), "music is playing in game")
	check(TouchControls.layout == TouchControls.Layout.STICK_A, "the game shows the stick + A layout")

	# Play for a while, dashing now and then.
	await wait_until(func(): return game.collected >= 4, 12.0, _steer)
	check(game.collected >= 4, "the stick moves the player into orbs (%d collected)" % game.collected)

	# Pause with the on-screen button, through the touch overlay.
	set_stick(Vector2.ZERO)
	var pause_btn: Dictionary = TouchControls.controls().filter(func(c): return c.label == "II")[0]
	await tap(pause_btn.center, "tap the on-screen pause button")
	await wait(0.6)
	check(get_tree().paused, "the on-screen II pauses the game")
	var frozen: float = game.time_left
	await wait(0.8)
	check(is_equal_approx(frozen, game.time_left), "the clock stops while paused")
	await tap_button("Resume")
	await wait(0.3)
	check(not get_tree().paused, "Resume unpauses")

	await wait_until(func(): return game.state != 0, 25.0, _steer)
	set_stick(Vector2.ZERO)
	check(game.state == 1, "the bot wins: %d orbs in %.1f s" % [game.collected, game.elapsed])
	var at_results := await wait_until(func(): return scene() != null and scene().name == "Results", 4.0)
	check(at_results, "winning goes to the results screen")
	await wait(1.5)
	check(float(SaveManager.get_value("orb_run", "best_time", 0.0)) > 0.0, "the best time is saved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://demo_save.json"))


var _dash_timer := 0.0


## Steer toward the nearest orb, pushed away from spikes that are close.
func _steer() -> void:
	if not is_instance_valid(game) or game.state != 0 or get_tree().paused:
		return
	var p: Vector2 = game.player
	var best := Vector2.ZERO
	var best_d := INF
	for o in game.orbs:
		if p.distance_to(o) < best_d:
			best_d = p.distance_to(o)
			best = o
	var dir := (best - p).normalized()
	for h in game.hazards:
		var away: Vector2 = p - h.pos
		if away.length() < 140.0:
			dir += away.normalized() * (140.0 - away.length()) / 50.0
	set_stick(dir.normalized())
	_dash_timer -= get_process_delta_time()
	if best_d > 260.0 and _dash_timer <= 0.0:
		_dash_timer = 1.2
		press("action_a", 0.05)

extends GutTest
## The sample game's rules. (The full session — menus, cutscene, touch, pause — is checked by
## samples/sample_game/orb_run_demo.gd under tools/verify.sh, where real input can be used.)

const ORB_RUN := preload("res://samples/sample_game/orb_run.tscn")
var g: Node2D
var _save := ""


func before_each() -> void:
	_save = SaveManager.save_path
	SaveManager.save_path = "user://test_orb_save.json"
	SaveManager.clear()
	SceneDirector.capture_only = true
	g = ORB_RUN.instantiate()
	g.rng_seed = 1
	add_child_autofree(g)
	await wait_process_frames(1)
	g.hazards.clear()                 # rules under test, not dodging


func after_each() -> void:
	SceneDirector.capture_only = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_orb_save.json"))
	SaveManager.save_path = _save
	SaveManager.load_game()
	AudioManager.stop_music(0.0)


func test_touching_an_orb_collects_it_and_respawns_one() -> void:
	g.player = g.orbs[0]
	await wait_process_frames(2)
	assert_eq(g.collected, 1)
	assert_eq(g.orbs.size(), g.ORBS_ON_FIELD, "a new orb replaces it")


func test_a_spike_costs_three_seconds_once() -> void:
	g.hazards.append({"pos": g.player, "vel": Vector2.ZERO})
	var before: float = g.time_left
	await wait_process_frames(3)
	assert_almost_eq(before - g.time_left, g.HIT_PENALTY, 0.2, "one hit, then invulnerable briefly")


func test_running_out_of_time_loses() -> void:
	g.time_left = 0.01
	await wait_process_frames(2)
	assert_eq(g.state, 2)
	assert_false(g.last_result.won)


func test_tenth_orb_wins_and_saves_best_time() -> void:
	g.collected = g.GOAL - 1
	g.player = g.orbs[0]
	await wait_process_frames(2)
	assert_eq(g.state, 1)
	assert_true(g.last_result.new_best)
	assert_gt(float(SaveManager.get_value("orb_run", "best_time", 0.0)), 0.0)


func test_a_slower_win_does_not_replace_the_best() -> void:
	SaveManager.set_value("orb_run", "best_time", 0.001)
	g.collected = g.GOAL - 1
	g.player = g.orbs[0]
	await wait_process_frames(2)
	assert_false(g.last_result.new_best)
	assert_eq(SaveManager.get_value("orb_run", "best_time"), 0.001)


func test_uses_the_stick_and_a_layout() -> void:
	assert_eq(TouchControls.layout, TouchControls.Layout.STICK_A)

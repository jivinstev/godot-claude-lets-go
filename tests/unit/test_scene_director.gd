extends GutTest


func after_each() -> void:
	SceneDirector.capture_only = false


func test_capture_only_records_instead_of_changing() -> void:
	SceneDirector.capture_only = true
	SceneDirector.goto("res://scenes/game.tscn")
	assert_eq(SceneDirector.last_target, "res://scenes/game.tscn")
	assert_false(SceneDirector.is_busy())


func test_quit_is_recorded_under_capture_only() -> void:
	SceneDirector.capture_only = true
	SceneDirector.quit()
	assert_eq(SceneDirector.last_target, "quit")


func test_fade_covers_the_touch_controls() -> void:
	assert_gt(SceneDirector.layer, TouchControls.layer)

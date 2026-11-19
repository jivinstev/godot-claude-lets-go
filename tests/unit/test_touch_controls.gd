extends GutTest
## The on-screen controls emit what a real pad would, so InputMap actions fire.


func before_all() -> void:
	RealWindow.use(self)


func before_each() -> void:
	TouchControls.simulate_touchscreen(true)


func after_each() -> void:
	TouchControls.set_layout(TouchControls.Layout.NONE)
	TouchControls.release_all()
	await wait_frames(2)


func _control(label: String) -> Dictionary:
	for c in TouchControls.controls():
		if c.label == label:
			return c
	return {}


func _touch(pos: Vector2, down: bool, index: int = 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = down
	Input.parse_input_event(e)


func test_none_draws_nothing() -> void:
	TouchControls.set_layout(TouchControls.Layout.NONE)
	assert_false(TouchControls.is_painting())


func test_layouts_have_the_controls_they_promise() -> void:
	var want := {
		TouchControls.Layout.STICK_A: ["", "A", "II"],
		TouchControls.Layout.STICK_AB: ["", "A", "B", "II"],
		TouchControls.Layout.DPAD_AB: ["", "A", "B", "II"],
		TouchControls.Layout.FULL: ["", "A", "B", "X", "Y", "LT", "RT", "II"],
	}
	for l in want:
		TouchControls.set_layout(l)
		var labels := TouchControls.controls().map(func(c): return c.label)
		labels.sort(); var w: Array = want[l].duplicate(); w.sort()
		assert_eq(labels, w, "layout %s" % TouchControls.Layout.keys()[l])
		assert_true(TouchControls.is_painting())


func test_tapping_a_fires_action_a() -> void:
	TouchControls.set_layout(TouchControls.Layout.STICK_AB)
	_touch(_control("A").center, true)
	await wait_frames(2)
	assert_true(Input.is_action_pressed("action_a"), "A pulses JOY_BUTTON_A → action_a")
	_touch(_control("A").center, false)
	await wait_frames(TouchControls.PULSE_FRAMES + 2)
	assert_false(Input.is_action_pressed("action_a"), "the pulse releases on its own")


func test_pause_button_fires_pause() -> void:
	TouchControls.set_layout(TouchControls.Layout.STICK_A)
	_touch(_control("II").center, true)
	await wait_frames(2)
	assert_true(Input.is_action_pressed("pause"))


func test_dragging_the_stick_moves() -> void:
	TouchControls.set_layout(TouchControls.Layout.STICK_AB)
	var c: Vector2 = TouchControls.controls()[0].center
	_touch(c, true)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = c + Vector2(90, 0)
	Input.parse_input_event(d)
	await wait_frames(2)
	assert_gt(Input.get_action_strength("move_right"), 0.5)
	_touch(c, false)
	await wait_frames(2)
	assert_eq(Input.get_action_strength("move_right"), 0.0, "releasing recentres the stick")


func test_dpad_holds_a_direction() -> void:
	TouchControls.set_layout(TouchControls.Layout.DPAD_AB)
	var c: Vector2 = TouchControls.controls()[0].center
	_touch(c + Vector2(0, -70), true)
	await wait_frames(2)
	assert_true(Input.is_action_pressed("move_up"))
	_touch(c + Vector2(0, -70), false)
	await wait_frames(2)
	assert_false(Input.is_action_pressed("move_up"))


func test_changing_layout_releases_held_input() -> void:
	TouchControls.set_layout(TouchControls.Layout.STICK_AB)
	var c: Vector2 = TouchControls.controls()[0].center
	_touch(c + Vector2(-90, 0), true)
	await wait_frames(2)
	assert_gt(Input.get_action_strength("move_left"), 0.5)
	TouchControls.set_layout(TouchControls.Layout.NONE)
	await wait_frames(2)
	assert_eq(Input.get_action_strength("move_left"), 0.0, "a held stick must not carry into a menu")

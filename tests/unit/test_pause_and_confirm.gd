extends GutTest

var _host: Node


func before_each() -> void:
	_host = Node.new()
	add_child_autofree(_host)
	TouchControls.simulate_touchscreen(true)
	TouchControls.set_layout(TouchControls.Layout.STICK_AB)


func after_each() -> void:
	get_tree().paused = false
	TouchControls.set_layout(TouchControls.Layout.NONE)


func test_pause_menu_pauses_hides_touch_and_restores() -> void:
	var m := PauseMenu.open(_host, [{"text": "Resume"}, {"text": "Quit", "action": func(): pass}])
	await wait_process_frames(2)
	assert_true(get_tree().paused)
	assert_eq(TouchControls.layout, TouchControls.Layout.NONE, "the stick would sit over the menu")
	assert_eq(get_viewport().gui_get_focus_owner(), m.buttons()[0], "the safe option takes focus")
	m.buttons()[0].pressed.emit()
	await wait_process_frames(2)
	assert_false(get_tree().paused)
	assert_eq(TouchControls.layout, TouchControls.Layout.STICK_AB)


func test_pause_menu_action_runs_and_unpauses() -> void:
	var ran := [false]
	var m := PauseMenu.open(_host, [{"text": "Resume"}, {"text": "Do it", "action": func(): ran[0] = true}])
	await wait_process_frames(1)
	m.buttons()[1].pressed.emit()
	assert_true(ran[0])
	assert_false(get_tree().paused)


func test_confirm_focuses_the_safe_choice_and_answers() -> void:
	var answer := [null]
	var ask := func(): answer[0] = await ConfirmOverlay.ask(_host, "Sure?", "Yes", "No")
	ask.call()
	await wait_process_frames(2)
	var o: ConfirmOverlay = null
	for c in _host.get_children():
		if c is ConfirmOverlay:
			o = c
	assert_not_null(o)
	assert_eq(get_viewport().gui_get_focus_owner(), o.buttons()[1], "the safe choice (No) takes focus")
	o.buttons()[0].pressed.emit()
	await wait_process_frames(1)
	assert_eq(answer[0], true)

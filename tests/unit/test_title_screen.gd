extends GutTest
## The title screen: the one scene every fork starts from.

var _screen: BaseScreen


func before_each() -> void:
	SceneDirector.capture_only = true
	SceneDirector.visited.clear()
	_screen = load("res://scenes/title_screen.tscn").instantiate()
	add_child_autofree(_screen)
	await wait_process_frames(2)


func after_each() -> void:
	SceneDirector.capture_only = false


func _button(text: String) -> Button:
	for b in _screen.buttons():
		if b.text == text:
			return b
	return null


func test_play_goes_to_the_game_scene() -> void:
	_button("Play").pressed.emit()
	assert_eq(SceneDirector.last_target, "res://scenes/game.tscn")


func test_a_button_has_focus_so_pads_and_keyboards_work() -> void:
	assert_not_null(get_viewport().gui_get_focus_owner(), "something must hold focus on open")


func test_samples_entry_exists_only_when_samples_do() -> void:
	var has := ResourceLoader.exists("res://samples/samples_menu.tscn")
	assert_eq(_button("Samples") != null, has)

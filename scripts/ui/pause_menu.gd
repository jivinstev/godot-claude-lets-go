class_name PauseMenu
extends CanvasLayer
## A pause menu for any gameplay scene. Pauses the tree, hides the touch controls while it is up
## (they would sit over these buttons), and restores both on resume.
##
##   func _unhandled_input(e):
##       if e.is_action_pressed("pause"):
##           PauseMenu.open(self, [
##               {"text": "Resume"},                                        # safe option FIRST
##               {"text": "Restart", "action": func(): SceneDirector.goto(scene_file_path)},
##               {"text": "Quit to title", "action": func(): SceneDirector.goto("res://scenes/title_screen.tscn")},
##           ])
##
## The safe option comes first and takes focus, so a stray press can't end the run. An entry
## without "action" just resumes. Pause / Esc / pad-B also resume. Layer 100: above the HUD,
## below the touch controls' layer.

signal resumed

const DIM := Color(0, 0, 0, 0.55)

var _prev_layout: int
var _buttons: Array[Button] = []


static func open(host: Node, entries: Array) -> PauseMenu:
	var m := PauseMenu.new()
	m.layer = 100
	m.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(m)
	m._build(entries)
	return m


func buttons() -> Array[Button]:
	return _buttons


func _build(entries: Array) -> void:
	_prev_layout = TouchControls.layout
	TouchControls.set_layout(TouchControls.Layout.NONE)
	get_tree().paused = true
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override(&"font", UiStyle.FONT_DISPLAY)
	title.add_theme_font_size_override(&"font_size", 56)
	title.add_theme_color_override(&"font_color", UiStyle.TITLE)
	box.add_child(title)
	for e in entries:
		var b := Button.new()
		b.text = e["text"]
		b.custom_minimum_size = UiStyle.BUTTON_MIN
		UiStyle.style_button(b)
		b.pressed.connect(_choose.bind(e.get("action", Callable())))
		box.add_child(b)
		_buttons.append(b)
	if not _buttons.is_empty():
		_buttons[0].grab_focus.call_deferred()


func _choose(action: Callable) -> void:
	if action.is_valid():
		get_tree().paused = false
		queue_free()
		action.call()
	else:
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
	get_tree().paused = false
	TouchControls.set_layout(_prev_layout)
	resumed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()

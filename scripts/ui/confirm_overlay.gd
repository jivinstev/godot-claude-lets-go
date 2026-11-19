class_name ConfirmOverlay
extends CanvasLayer
## "Are you sure?" without a Godot Dialog (which draws above the touch layer and can't be tapped).
##
##   if await ConfirmOverlay.ask(self, "Quit to the title? Progress is lost.", "Quit", "Keep playing"):
##       SceneDirector.goto("res://scenes/title_screen.tscn")
##
## The SAFE choice (the second button) takes focus, and Back / Esc cancels.

signal answered(yes: bool)

var _buttons: Array[Button] = []


static func ask(host: Node, question: String, yes_text: String = "Yes", no_text: String = "Cancel") -> bool:
	var o := ConfirmOverlay.new()
	o.layer = 110
	o.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(o)
	o._build(question, yes_text, no_text)
	var yes: bool = await o.answered
	return yes


func buttons() -> Array[Button]:
	return _buttons


func _build(question: String, yes_text: String, no_text: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	var q := Label.new()
	q.text = question
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size.x = 560
	q.add_theme_font_override(&"font", UiStyle.FONT_BODY)
	q.add_theme_font_size_override(&"font_size", 30)
	box.add_child(q)
	for pair in [[yes_text, true], [no_text, false]]:
		var b := Button.new()
		b.text = pair[0]
		b.custom_minimum_size = UiStyle.BUTTON_MIN
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		UiStyle.style_button(b)
		b.pressed.connect(_answer.bind(pair[1]))
		box.add_child(b)
		_buttons.append(b)
	_buttons[1].grab_focus.call_deferred()


func _answer(yes: bool) -> void:
	if is_queued_for_deletion():
		return
	answered.emit(yes)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer(false)

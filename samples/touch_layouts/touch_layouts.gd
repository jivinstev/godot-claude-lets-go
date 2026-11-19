extends Control
## Every TouchControls layout, live: pick one and see which InputMap actions it fires.
## Shown on a desktop too (simulated), so you can try them with a mouse-less touch emulator or
## just look. Buttons sit on the RIGHT half on purpose: with a stick or d-pad layout, the whole
## left half of the screen belongs to the thumb that steers, and a button there would never get
## the tap — and they sit below y=130 because the FULL layout's shoulder triggers own the top
## corners. tools/touch_probe.sh with TOUCH_LAYOUT=FULL fails if either rule is broken.

const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "action_a", "action_b", "pause"]
const LAYOUTS := [TouchControls.Layout.STICK_A, TouchControls.Layout.STICK_AB,
	TouchControls.Layout.DPAD_AB, TouchControls.Layout.FULL]

var index := 0
var _name: Label
var _readout: Label
var _x_btn_seen := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiStyle.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_name = _label(Vector2(690, 240), 44, UiStyle.TITLE, UiStyle.FONT_DISPLAY)
	_readout = _label(Vector2(690, 305), 24, UiStyle.TEXT, UiStyle.FONT_BODY)
	_button("Next layout", Vector2(660, 150), _next)
	_button("Back", Vector2(910, 150), _back)
	TouchControls.simulate_touchscreen(true)
	_apply()


func _next() -> void:
	index = (index + 1) % LAYOUTS.size()
	_apply()


func _back() -> void:
	SceneDirector.goto("res://samples/samples_menu.tscn")


func _apply() -> void:
	TouchControls.set_layout(LAYOUTS[index])
	_name.text = TouchControls.Layout.keys()[LAYOUTS[index]]


func _process(_dt: float) -> void:
	var lines: PackedStringArray = []
	for a in ACTIONS:
		var s := Input.get_action_strength(a)
		lines.append("%-11s %s" % [a, "●" if s > 0.05 else "·"])
	_readout.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()


func _label(pos: Vector2, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _button(text: String, pos: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(220, 60)
	UiStyle.style_button(b)
	b.pressed.connect(action)
	add_child(b)
	return b

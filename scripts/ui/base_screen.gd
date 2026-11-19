class_name BaseScreen
extends Control
## Base class for full-screen menus. A screen is one script that overrides build():
##
##   extends BaseScreen
##   func build() -> void:
##       add_title("Options")
##       add_button("Back", func(): goto("res://scenes/title_screen.tscn"))
##
## Works identically with touch, mouse, keyboard and gamepad. The rules it enforces:
##  - TAP TO CLICK. Menus have no virtual pad behind them; the finger is the cursor. So every
##    screen must be fully operable by tapping its own buttons (tools/touch_probe checks this).
##  - FOCUS ON OPEN, so a pad or keyboard has something to activate immediately.
##  - ui_cancel (Esc / pad B) calls on_cancel() — override it to go back.
##  - DRAG TO SCROLL, implemented here in _input. Godot's ScrollContainer touch scrolling relies on
##    mouse emulation, which this project turns off, so without this a long screen cannot scroll
##    on a phone. It must be _input, not _unhandled_input: the Control under the finger consumes
##    the drag before _unhandled_input ever runs.
##  - Anything needed to LEAVE the screen goes in add_pinned_button(): outside the scroller, so a
##    long list can never push the way out off-screen.
##  - Never use Window / Popup / *Dialog for player UI: an embedded subwindow draws above the touch
##    controls' layer and fingers cannot reach it. Use ConfirmOverlay / in-tree Controls.

const SCROLL_STEP := 90.0
const DRAG_TAP_SLOP := 12.0

var _root: VBoxContainer
var _menu: VBoxContainer
var _scroll: ScrollContainer
var _footer: VBoxContainer
var _buttons: Array[Button] = []
var _drag_dy := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_frame()
	build()
	_focus_first.call_deferred()


## Override to fill the screen.
func build() -> void:
	pass


## Override for what Back / Esc / pad-B does on this screen.
func on_cancel() -> void:
	pass


func goto(path: String) -> void:
	SceneDirector.goto(path)


func add_title(text: String) -> Label:
	return _label(text, UiStyle.FONT_DISPLAY, UiStyle.TITLE_SIZE, UiStyle.TITLE)


func add_text(text: String, dim: bool = false, font_size: int = UiStyle.TEXT_SIZE) -> Label:
	var l := _label(text, UiStyle.FONT_BODY, font_size, UiStyle.DIM if dim else UiStyle.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 640
	return l


func add_spacer(height: int = 16) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(c)
	return c


func add_button(text: String, action: Callable) -> Button:
	if _menu == null:
		_menu = VBoxContainer.new()
		_menu.alignment = BoxContainer.ALIGNMENT_CENTER
		_menu.add_theme_constant_override("separation", 12)
		_root.add_child(_menu)
	return make_button(_menu, text, action)


## The way out. Always visible, never scrolls away.
func add_pinned_button(text: String, action: Callable) -> Button:
	return make_button(_footer, text, action)


func make_button(parent: Node, text: String, action: Callable, min_size: Vector2 = UiStyle.BUTTON_MIN) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(b)
	if action.is_valid():
		b.pressed.connect(action)
	parent.add_child(b)
	_buttons.append(b)
	return b


func buttons() -> Array[Button]:
	return _buttons


func has_overflow() -> bool:
	return _scroll != null and _root.size.y > _scroll.size.y + 1.0


func scroll_by(amount: float) -> void:
	_scroll.scroll_vertical = int(clampf(_scroll.scroll_vertical + amount, 0.0, maxf(0.0, _root.size.y - _scroll.size.y)))


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l


func _build_frame() -> void:
	var bg := ColorRect.new()
	bg.color = UiStyle.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var frame := VBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	frame.add_child(margin)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	margin.add_child(_scroll)
	_root = VBoxContainer.new()
	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", 18)
	_scroll.add_child(_root)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 28)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pad)
	_footer = VBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_CENTER
	pad.add_child(_footer)


func _focus_first() -> void:
	for b in _buttons:
		if is_instance_valid(b) and b.is_visible_in_tree() and not b.disabled:
			b.grab_focus()
			return


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			_drag_dy = 0.0
		elif _drag_dy > DRAG_TAP_SLOP:
			_drag_dy = 0.0
			get_viewport().set_input_as_handled()   # the end of a scroll is not a tap
	elif event is InputEventScreenDrag and has_overflow():
		var d := event as InputEventScreenDrag
		_drag_dy += absf(d.relative.y)
		scroll_by(-d.relative.y)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		accept_event()
		on_cancel()
	elif has_overflow() and event.is_action_pressed(&"ui_down", true):
		scroll_by(SCROLL_STEP)
	elif has_overflow() and event.is_action_pressed(&"ui_up", true):
		scroll_by(-SCROLL_STEP)

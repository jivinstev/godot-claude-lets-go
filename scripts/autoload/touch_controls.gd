extends CanvasLayer
## On-screen controls for phones. Picks one of a few LAYOUTS; each control emits the SAME raw
## joypad events a real controller would (stick axes, JOY_BUTTON_*, trigger axes) via
## Input.parse_input_event. So it knows nothing about your game: the InputMap (project.godot)
## turns those events into actions, and a real Bluetooth pad works identically.
##
##   func _ready():                                   # in a gameplay scene
##       TouchControls.set_layout(TouchControls.Layout.STICK_AB)
##
## Layouts:
##   NONE        nothing drawn. Menus — they are tap-to-click, the finger IS the cursor.
##   STICK_A     analog stick (left half of screen) + A                   — one-button games
##   STICK_AB    analog stick + A, B                                      — most action games
##   DPAD_AB     4-way d-pad + A, B                                       — grid / retro games
##   FULL        analog stick + A, B, X, Y + LT, RT                       — everything
## Every layout except NONE also draws a pause button (top-right) that sends Start → "pause".
##
## Rules (each one a bug somewhere before):
##  - SceneDirector resets to NONE on every scene change; a gameplay scene opts in.
##  - Anything that opens a menu over gameplay (PauseMenu does) must set NONE while it is up,
##    or the stick's half of the screen sits over the menu's buttons and eats the taps.
##  - Face buttons PULSE for PULSE_FRAMES rather than tracking the finger, so a very short tap
##    still produces an edge that is_action_just_pressed() can see.
##  - Draws only on a touchscreen. simulate_touchscreen(true) — or env TOUCH_SIM=1 — forces it on,
##    so desktop captures and tests see exactly what a phone shows.

enum Layout { NONE, STICK_A, STICK_AB, DPAD_AB, FULL }

const LAYER := 128
const STICK_RADIUS := 100.0
const FACE_R := 50.0
const TRIG_R := 46.0
const PAUSE_R := 34.0
const MARGIN := 150.0
const PULSE_FRAMES := 8

var layout: Layout = Layout.NONE

var _hud: Control
var _touch := false            # a touchscreen exists (or is simulated)
var _vp := Vector2.ZERO
var _controls: Array = []      # {kind, label, code, center, radius, color}
var _claims := {}              # touch index -> control dict (stick, dpad, trigger)
var _pulses := {}              # JOY_BUTTON -> frames left
var _knob := Vector2.ZERO
var _dpad_held := -1


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.draw.connect(_draw_hud)
	add_child(_hud)
	get_viewport().size_changed.connect(_rebuild)
	_touch = DisplayServer.is_touchscreen_available() or OS.get_environment("TOUCH_SIM") == "1"
	_rebuild()


func set_layout(l: Layout) -> void:
	if l == layout:
		return
	release_all()
	layout = l
	_rebuild()


func simulate_touchscreen(on: bool) -> void:
	_touch = on or DisplayServer.is_touchscreen_available()
	_rebuild()


## Whether controls are actually being drawn (and accepting touches) right now.
func is_painting() -> bool:
	return visible and _touch and layout != Layout.NONE


## The controls of the current layout — for tests and the touch probe.
func controls() -> Array:
	return _controls.duplicate(true)


func release_all() -> void:
	for code in _pulses.keys():
		_emit_button(code, false)
	_pulses.clear()
	for c in _claims.values():
		match c.kind:
			"trigger": _emit_axis(c.code, 0.0)
			"dpad": if _dpad_held >= 0: _emit_button(_dpad_held, false)
	_dpad_held = -1
	_claims.clear()
	_knob = Vector2.ZERO
	_emit_axis(JOY_AXIS_LEFT_X, 0.0)
	_emit_axis(JOY_AXIS_LEFT_Y, 0.0)
	_hud.queue_redraw()


func _rebuild() -> void:
	_vp = get_viewport().get_visible_rect().size
	_controls = []
	visible = _touch and layout != Layout.NONE
	set_process(visible)
	set_process_input(visible)
	if not visible:
		_hud.queue_redraw()
		return
	var left := Vector2(MARGIN, _vp.y - MARGIN)
	var face := Vector2(_vp.x - 170.0, _vp.y - 160.0)
	var gap := 76.0
	if layout == Layout.DPAD_AB:
		_controls.append({"kind": "dpad", "label": "", "code": -1, "center": left, "radius": STICK_RADIUS, "color": Color.WHITE})
	else:
		_controls.append({"kind": "stick", "label": "", "code": -1, "center": left, "radius": STICK_RADIUS, "color": Color.WHITE})
	var a := {"kind": "button", "label": "A", "code": JOY_BUTTON_A, "center": face + Vector2(0, gap * 0.6), "radius": FACE_R, "color": Color(0.3, 0.8, 0.35)}
	var b := {"kind": "button", "label": "B", "code": JOY_BUTTON_B, "center": face + Vector2(gap, -gap * 0.3), "radius": FACE_R, "color": Color(0.9, 0.3, 0.3)}
	match layout:
		Layout.STICK_A:
			a.center = face + Vector2(gap * 0.5, 0)
			a.radius = FACE_R * 1.3
			_controls.append(a)
		Layout.STICK_AB, Layout.DPAD_AB:
			_controls.append_array([a, b])
		Layout.FULL:
			a.center = face + Vector2(0, gap)
			b.center = face + Vector2(gap, 0)
			_controls.append_array([a, b,
				{"kind": "button", "label": "X", "code": JOY_BUTTON_X, "center": face + Vector2(-gap, 0), "radius": FACE_R, "color": Color(0.3, 0.5, 0.95)},
				{"kind": "button", "label": "Y", "code": JOY_BUTTON_Y, "center": face + Vector2(0, -gap), "radius": FACE_R, "color": Color(0.95, 0.8, 0.2)},
				{"kind": "trigger", "label": "LT", "code": JOY_AXIS_TRIGGER_LEFT, "center": Vector2(MARGIN * 0.7, 70), "radius": TRIG_R, "color": Color(0.85, 0.85, 0.85)},
				{"kind": "trigger", "label": "RT", "code": JOY_AXIS_TRIGGER_RIGHT, "center": Vector2(_vp.x - MARGIN * 0.7 - 90, 70), "radius": TRIG_R, "color": Color(0.85, 0.85, 0.85)}])
	_controls.append({"kind": "button", "label": "II", "code": JOY_BUTTON_START, "center": Vector2(_vp.x - 60, 60), "radius": PAUSE_R, "color": Color(0.8, 0.8, 0.85)})
	_hud.queue_redraw()


func _process(_dt: float) -> void:
	if _pulses.is_empty():
		return
	for code in _pulses.keys():
		_pulses[code] -= 1
		if _pulses[code] <= 0:
			_emit_button(code, false)
			_pulses.erase(code)
	_hud.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_on_press(t.index, t.position)
		else:
			_on_release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		var c: Variant = _claims.get(d.index)
		if c is Dictionary:
			_on_move(c, d.position)


func _on_press(index: int, pos: Vector2) -> void:
	for c in _controls:
		if c.kind in ["button", "trigger"] and pos.distance_to(c.center) <= c.radius * 1.25:
			if c.kind == "button":
				_emit_button(c.code, true)
				_pulses[c.code] = PULSE_FRAMES
			else:
				_claims[index] = c
				_emit_axis(c.code, 1.0)
			get_viewport().set_input_as_handled()
			_hud.queue_redraw()
			return
	# Anywhere else on the left half drives the stick / d-pad, so a thumb need not hit it exactly.
	if pos.x < _vp.x * 0.5 and not _controls.is_empty() and _controls[0].kind in ["stick", "dpad"]:
		_claims[index] = _controls[0]
		_on_move(_controls[0], pos)
		get_viewport().set_input_as_handled()


func _on_move(c: Dictionary, pos: Vector2) -> void:
	var off: Vector2 = pos - c.center
	if c.kind == "stick":
		off = off.limit_length(STICK_RADIUS)
		_knob = off
		_emit_axis(JOY_AXIS_LEFT_X, off.x / STICK_RADIUS)
		_emit_axis(JOY_AXIS_LEFT_Y, off.y / STICK_RADIUS)
	elif c.kind == "dpad":
		var dir := -1
		if off.length() > STICK_RADIUS * 0.25:
			if absf(off.x) > absf(off.y):
				dir = JOY_BUTTON_DPAD_RIGHT if off.x > 0 else JOY_BUTTON_DPAD_LEFT
			else:
				dir = JOY_BUTTON_DPAD_DOWN if off.y > 0 else JOY_BUTTON_DPAD_UP
		if dir != _dpad_held:
			if _dpad_held >= 0:
				_emit_button(_dpad_held, false)
			if dir >= 0:
				_emit_button(dir, true)
			_dpad_held = dir
	_hud.queue_redraw()


func _on_release(index: int) -> void:
	var c: Variant = _claims.get(index)
	_claims.erase(index)
	if not (c is Dictionary):
		return
	match c.kind:
		"stick":
			_knob = Vector2.ZERO
			_emit_axis(JOY_AXIS_LEFT_X, 0.0)
			_emit_axis(JOY_AXIS_LEFT_Y, 0.0)
		"dpad":
			if _dpad_held >= 0:
				_emit_button(_dpad_held, false)
			_dpad_held = -1
		"trigger":
			_emit_axis(c.code, 0.0)
	_hud.queue_redraw()


func _emit_axis(axis: int, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)


func _emit_button(code: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = code
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	Input.parse_input_event(e)


func _draw_hud() -> void:
	if not is_painting():
		return
	var font := ThemeDB.fallback_font
	var held := {}
	for c in _claims.values():
		held[c.label] = true
	for c in _controls:
		match c.kind:
			"stick":
				_hud.draw_circle(c.center, c.radius, Color(1, 1, 1, 0.12))
				_hud.draw_arc(c.center, c.radius, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
				_hud.draw_circle(c.center + _knob, c.radius * 0.42, Color(1, 1, 1, 0.35))
			"dpad":
				var arm: float = c.radius * 0.36
				for d in [[Vector2.UP, JOY_BUTTON_DPAD_UP], [Vector2.DOWN, JOY_BUTTON_DPAD_DOWN],
						[Vector2.LEFT, JOY_BUTTON_DPAD_LEFT], [Vector2.RIGHT, JOY_BUTTON_DPAD_RIGHT]]:
					var p: Vector2 = c.center + d[0] * c.radius * 0.62
					var lit: bool = _dpad_held == d[1]
					_hud.draw_rect(Rect2(p - Vector2(arm, arm), Vector2(arm, arm) * 2), Color(1, 1, 1, 0.5 if lit else 0.16))
				_hud.draw_arc(c.center, c.radius, 0, TAU, 48, Color(1, 1, 1, 0.4), 2.0)
			_:
				var lit: bool = _pulses.has(c.code) if c.kind == "button" else held.has(c.label)
				var col: Color = c.color
				_hud.draw_circle(c.center, c.radius, Color(col.r, col.g, col.b, 0.55 if lit else 0.22))
				_hud.draw_arc(c.center, c.radius, 0, TAU, 40, Color(1, 1, 1, 0.6), 3.0)
				var fs := 24
				var w := font.get_string_size(c.label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
				_hud.draw_string(font, c.center + Vector2(-w * 0.5, fs * 0.35), c.label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(1, 1, 1, 0.92))

extends Node
## CAN A FINGER REACH EVERY BUTTON ON THIS SCREEN?
##
##   TOUCH_SCENE=res://scenes/title_screen.tscn godot --headless --path . res://tools/touch_probe.tscn
##   TOUCH_SIZE=2340x1080 ...                      # a real phone panel (default: project size)
##   TOUCH_LAYOUT=STICK_AB ...                     # with a gameplay touch layout drawn on top
##
## Runs the screen STANDALONE and taps every visible, enabled Button at its centre with a real
## InputEventScreenTouch pushed through Input.parse_input_event — the path a real finger takes:
## Input → root viewport → every CanvasLayer in z-order → Control picking. So a button covered by
## an overlay, by a full-screen Control with the default MOUSE_FILTER_STOP, or by the touch
## controls fails here exactly as it would in a hand. Existence is not reachability.
##
## Verdicts:  ok    the tap reached it
##            DEAD  on screen and unreachable — a bug (almost always something covering it)
##            off   outside the viewport (needs scrolling first) — not a failure by itself
##            moved the screen rebuilt before this button's turn — re-run if it matters
##            small reached, but under 44 px tall/wide — too small for a thumb (warning)
##            UNDER its centre works, but part of it lies under an on-screen touch control (stick
##                  zone, a face button, a trigger), so a thumb on that part fires the control
##                  instead — a bug. A tap at the exact centre cannot see this; the geometry can.
## Exits 1 if anything is DEAD or UNDER.
##
## SceneDirector.capture_only is on, so a button that navigates is recorded, not followed.
## Hook: if the screen has `func touch_probe_setup() -> void`, it is called before probing.

var _screen: Node
var _fired := {}
var _seen := {}
var _order: Array[String] = []
var _present := {}
var _moved := {}
var _at := -1
var _frame := 0


static func _key(r: Rect2) -> String:
	return "%d,%d" % [roundi(r.position.x), roundi(r.position.y)]


func _ready() -> void:
	# Headless opens a 64x64 window; a 1280x720 layout spills outside it and EVERYTHING reads as
	# dead. Always force a real size.
	var w := int(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	var h := int(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	var s := OS.get_environment("TOUCH_SIZE")
	if s.contains("x"):
		w = int(s.split("x")[0]); h = int(s.split("x")[1])
	get_window().size = Vector2i(w, h)
	get_window().content_scale_size = Vector2i(w, h)
	SceneDirector.capture_only = true
	TouchControls.simulate_touchscreen(true)
	var path := OS.get_environment("TOUCH_SCENE")
	if path.is_empty():
		path = ProjectSettings.get_setting("application/run/main_scene")
	_screen = load(path).instantiate()
	add_child(_screen)
	if _screen.has_method("touch_probe_setup"):
		_screen.call("touch_probe_setup")
	var lay := OS.get_environment("TOUCH_LAYOUT")
	if lay != "":
		TouchControls.set_layout(TouchControls.Layout[lay])
	print("TOUCH_PROBE scene=%s window=%s layout=%s" % [path, get_window().size, TouchControls.Layout.keys()[TouchControls.layout]])


func _process(_dt: float) -> void:
	_frame += 1
	if _frame < 8:
		return   # let layout settle; a Control on frame 0 has no size
	_collect()
	if _at < 0:
		_order.assign(_seen.keys())
		_order.sort()
		print("TOUCH_PROBE targets=%d" % _order.size())
		_at = 0
		return
	if _at >= _order.size():
		_report()
		return
	var k := _order[_at]
	if _present.has(k):
		var at: Vector2 = (_seen[k].rect as Rect2).get_center()
		for down in [true, false]:
			var e := InputEventScreenTouch.new()
			e.index = 0
			e.position = at
			e.pressed = down
			Input.parse_input_event(e)
	else:
		_moved[k] = true
	_at += 1


func _collect() -> void:
	_present.clear()
	for n in _walk(get_tree().root):
		var b := n as Button
		if b == null or not b.is_visible_in_tree() or b.disabled:
			continue
		var r := b.get_global_rect()
		if r.get_area() <= 0.0:
			continue
		var k := _key(r)
		# Overlap is judged the FIRST time a button is seen: a tap on an earlier button may change
		# the layout (a "next layout" button does), and the screen as first shown is what counts.
		var under: String = _seen[k].under if _seen.has(k) else _under_touch_control(r)
		_seen[k] = {"label": b.text if b.text != "" else "<%s>" % b.name, "rect": r, "under": under}
		_present[k] = true
		if not b.pressed.is_connected(_on_fired):
			b.pressed.connect(_on_fired.bind(k))


func _on_fired(k: String) -> void:
	_fired[k] = true


func _report() -> void:
	var dead: Array[String] = []
	var moved := 0
	var off := 0
	var small := 0
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	for k in _order:
		var info: Dictionary = _seen[k]
		var r: Rect2 = info.rect
		var ok: bool = _fired.has(k)
		if _moved.has(k) and not ok:
			moved += 1
			print("TOUCH_PROBE moved %-28s" % info.label)
			continue
		if not view.encloses(Rect2(r.get_center(), Vector2.ONE)):
			off += 1
			print("TOUCH_PROBE off   %-28s at %s" % [info.label, k])
			continue
		var verdict := "ok" if ok else "DEAD"
		var under: String = info.under
		if ok and under != "":
			verdict = "UNDER"
			ok = false
			info.label = "%s (under %s)" % [info.label, under]
		elif ok and minf(r.size.x, r.size.y) < 44.0:
			verdict = "small"
			small += 1
		print("TOUCH_PROBE %-5s %-28s %.0fx%.0f at %s" % [verdict, info.label, r.size.x, r.size.y, k])
		if not ok:
			dead.append(info.label)
	var tested := _order.size() - moved - off
	print("TOUCH_PROBE RESULT %d/%d reachable (%d off-screen, %d moved, %d small)" % [tested - dead.size(), tested, off, moved, small])
	if not dead.is_empty():
		print("TOUCH_PROBE DEAD: " + ", ".join(dead))
	get_tree().quit(1 if not dead.is_empty() else 0)


## Which on-screen touch control (if any) claims part of this rectangle.
func _under_touch_control(r: Rect2) -> String:
	if not TouchControls.is_painting():
		return ""
	var half := get_viewport().get_visible_rect().size.x * 0.5
	for c in TouchControls.controls():
		var reach: float = c.radius * 1.25            # TouchControls' own hit radius
		var nearest := Vector2(clampf(c.center.x, r.position.x, r.end.x), clampf(c.center.y, r.position.y, r.end.y))
		if nearest.distance_to(c.center) <= reach:
			return c.label if c.label != "" else c.kind
		# The stick / d-pad also claims any touch on the left half that hits no other control.
		if c.kind in ["stick", "dpad"] and r.position.x < half:
			return c.kind + " zone (left half)"
	return ""


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out

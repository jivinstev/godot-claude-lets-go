extends CanvasLayer
## Scene changes, always through a short fade to black.
##
##   SceneDirector.goto("res://scenes/title_screen.tscn")
##
## - The fade lives on layer 200, above the on-screen touch controls (128), so it covers them too.
## - A request made DURING a fade is queued, not dropped: the latest one wins and runs as soon as
##   the current transition ends. (Dropping it silently is how a menu tap "did nothing" elsewhere.)
## - Before every change the touch overlay is reset to the menu layout and released, so a held
##   stick can't carry into the next scene. A gameplay scene picks its own layout in _ready().
## - The tree is unpaused on every change, so leaving a paused game never strands the next scene.
##
## Test seam: with `capture_only = true`, goto() records the target instead of changing scenes,
## so a test can walk menus without the scene being swapped out from under the test runner.

signal scene_changed(path: String)

const LAYER := 200
const FADE_OUT_SEC := 0.25
const FADE_IN_SEC := 0.25

var capture_only := false
var last_target := ""
var visited: PackedStringArray = []

var _fade: ColorRect
var _busy := false
var _queued := ""


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.visible = false
	add_child(_fade)


func is_busy() -> bool:
	return _busy


func goto(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("SceneDirector: no scene at %s" % path)
		return
	if capture_only:
		last_target = path
		visited.append(path)
		return
	if _busy:
		_queued = path
		return
	_busy = true
	_before_change()
	await _tween_alpha(1.0, FADE_OUT_SEC)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	scene_changed.emit(path)
	await _tween_alpha(0.0, FADE_IN_SEC)
	_fade.visible = false
	_busy = false
	if _queued != "":
		var next := _queued
		_queued = ""
		goto(next)


## Quit the app. Under capture_only (tests, the touch probe) the quit is recorded, not performed.
func quit() -> void:
	if capture_only:
		last_target = "quit"
		visited.append("quit")
		return
	get_tree().quit()


## Immediate change with no fade (tools and tests).
func goto_now(path: String) -> void:
	_before_change()
	get_tree().change_scene_to_file(path)


func _before_change() -> void:
	get_tree().paused = false
	TouchControls.set_layout(TouchControls.Layout.NONE)


func _tween_alpha(a: float, sec: float) -> void:
	_fade.visible = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", a, sec)
	await t.finished

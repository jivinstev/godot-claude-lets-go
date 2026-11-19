class_name Autoplay
extends Node
## Drive the REAL game with REAL input, and assert what happens — the engine of every
## gameplay video and of autonomous verification.
##
##   # tools/demos/my_feature_demo.gd   (+ a one-node .tscn using it)
##   extends Autoplay
##   func run() -> void:
##       await goto("res://scenes/title_screen.tscn")
##       await tap_button("Play")                  # a real InputEventScreenTouch at its centre
##       await hold("move_right", 1.5)             # InputMap action, held
##       await press("action_a")
##       check(get_tree().current_scene.name == "Game", "Play opens the game")
##
##   tools/verify.sh my_feature res://tools/demos/my_feature_demo.tscn
##
## - Survives scene changes (it detaches itself from the scene being replaced).
## - Taps and presses are drawn as a white "finger" ring in captures, so a viewer sees the input.
## - Timing uses game time, which Movie Maker's --fixed-fps ties to written frames — so a capture
##   shows exactly what a player would see, however slow the software renderer is.
## - check() prints "VERIFY PASS|FAIL <what>"; tools/verify.sh collects them and fails the run on
##   any FAIL. At the end it prints "VERIFY RESULT passed/total" and quits.
## - Set TOUCH_SIM=1 to draw the phone's touch controls in the capture.
## - Use the same input path a player does. Calling game functions directly proves the function,
##   not the feature: a button covered by an overlay still "works" if you call its handler.

var _checks := 0
var _failed := 0
var _markers: CanvasLayer
var _game_time := 0.0   ## seconds of GAME time — what a viewer of the capture sees


## Override with the scripted session.
func run() -> void:
	pass


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A demo presses real buttons: never against the player's own save. (verify.sh sets this too;
	# this covers a demo run by hand. SaveManager loaded already, so re-point and reload it.)
	if OS.get_environment("GAME_SAVE_PATH") == "":
		OS.set_environment("GAME_SAVE_PATH", "user://verify_save.json")
		SaveManager.save_path = "user://verify_save.json"
		SaveManager.load_game()
	if OS.get_environment("TOUCH_SIM") == "1":
		TouchControls.simulate_touchscreen(true)
	_markers = CanvasLayer.new()
	_markers.layer = 250
	add_child(_markers)
	# Hand "current scene" to a placeholder so the first goto() frees it, not us.
	var placeholder := Node.new()
	placeholder.name = "AutoplayPlaceholder"
	get_tree().root.add_child.call_deferred(placeholder)
	await get_tree().process_frame
	get_tree().current_scene = placeholder
	log_line("start")
	await run()
	await wait(0.5)
	print("VERIFY RESULT %d/%d" % [_checks - _failed, _checks])
	get_tree().quit(1 if _failed > 0 else 0)


func _process(dt: float) -> void:
	_game_time += dt


# --- steps ------------------------------------------------------------------------------------

func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, false).timeout


func wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Change scene directly (no fade) and let it settle.
func goto(path: String) -> void:
	log_line("goto " + path)
	SceneDirector.goto_now(path)
	await wait_frames(3)


## Tap the first visible, enabled Button whose text is `text`. Fails the check if none exists.
func tap_button(text: String) -> void:
	var b := find_button(text)
	if b == null:
		check(false, "button '%s' is on screen" % text)
		return
	await tap(b.get_global_rect().get_center(), "tap '%s'" % text)


## A finger tap at a screen position: press, ~3 frames, release.
func tap(pos: Vector2, why: String = "") -> void:
	log_line(why if why != "" else "tap %s" % pos)
	_mark(pos)
	_touch(pos, true)
	await wait_frames(3)
	_touch(pos, false)
	await wait_frames(6)


## Press and release an InputMap action (e.g. "action_a", "pause", "ui_accept").
func press(action: String, hold_sec: float = 0.1) -> void:
	log_line("press " + action)
	_action(action, true)
	await wait(hold_sec)
	_action(action, false)
	await wait_frames(2)


func hold(action: String, sec: float) -> void:
	log_line("hold %s %.1fs" % [action, sec])
	_action(action, true)
	await wait(sec)
	_action(action, false)


## Start holding an action without waiting (combine several, e.g. a diagonal); release with up().
func down(action: String) -> void:
	_action(action, true)


func up(action: String) -> void:
	_action(action, false)


## Push the left analog stick (as a real pad would) for `sec` seconds.
func stick(dir: Vector2, sec: float) -> void:
	log_line("stick %s %.1fs" % [dir, sec])
	_axis(JOY_AXIS_LEFT_X, dir.x)
	_axis(JOY_AXIS_LEFT_Y, dir.y)
	await wait(sec)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_axis(JOY_AXIS_LEFT_Y, 0.0)


## Hold the left stick at `dir` until changed (call every frame to steer a bot).
func set_stick(dir: Vector2) -> void:
	_axis(JOY_AXIS_LEFT_X, dir.x)
	_axis(JOY_AXIS_LEFT_Y, dir.y)


## Wait until `cond` returns true, or `timeout` seconds pass. Returns whether it came true.
func wait_until(cond: Callable, timeout: float, every_frame: Callable = Callable()) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		if every_frame.is_valid():
			every_frame.call()
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()


## Prove something survives a restart: run a SECOND, fresh Godot process (headless) on `scene`
## and return everything it printed. It inherits GAME_SAVE_PATH, so it reads the same save the
## demo just wrote. Have the scene (or a tiny probe scene) print what you want to check, then:
##   var out := launch_fresh("res://tools/demos/print_settings.tscn")
##   check(out.contains("music=0.5"), "the setting survives a relaunch")
func launch_fresh(scene_path: String, frames: int = 30) -> String:
	var out: Array = []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), scene_path, "--quit-after", str(frames)]
	OS.execute(OS.get_executable_path(), args, out, true)
	log_line("launched a fresh instance of %s" % scene_path)
	return "\n".join(out)


## Record an assertion about the running game.
## Beware a literal % in `what` if you build it with the % operator: escape it as %%.
func check(ok: bool, what: String) -> bool:
	_checks += 1
	if not ok:
		_failed += 1
	print("VERIFY %s %s" % ["PASS" if ok else "FAIL", what])
	return ok


func log_line(msg: String) -> void:
	print("AUTOPLAY %6.2fs %s" % [_game_time, msg])


func scene() -> Node:
	return get_tree().current_scene


func find_button(text: String) -> Button:
	for n in _walk(get_tree().root):
		var b := n as Button
		if b and b.text == text and b.is_visible_in_tree() and not b.disabled:
			return b
	return null


# --- plumbing ---------------------------------------------------------------------------------

func _touch(pos: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	# Input events arrive in WINDOW pixels; game positions are in VIEWPORT pixels. They only match
	# when the window is exactly the project size — at any other capture size (or a phone panel)
	# an unconverted tap lands somewhere else entirely and "nothing responds".
	e.position = get_tree().root.get_final_transform() * pos
	e.pressed = down
	Input.parse_input_event(e)


func _action(action: String, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	e.strength = 1.0 if down else 0.0
	Input.parse_input_event(e)


func _axis(axis: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = v
	Input.parse_input_event(e)


func _mark(pos: Vector2) -> void:
	var ring := _Ring.new()
	ring.position = pos
	_markers.add_child(ring)


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out


class _Ring extends Node2D:
	var _life := 0.45
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(dt: float) -> void:
		_life -= dt
		if _life <= 0.0:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var k := clampf(_life / 0.45, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 26.0, Color(1, 1, 1, 0.35 * k))
		draw_arc(Vector2.ZERO, 26.0 + (1.0 - k) * 14.0, 0, TAU, 32, Color(1, 1, 1, 0.9 * k), 3.0)

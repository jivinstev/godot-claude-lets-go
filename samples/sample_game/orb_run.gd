extends Node2D
## ORB RUN — the sample game. Collect 10 orbs in 30 seconds; red spikes cost you 3 seconds.
## Move: stick / WASD / arrows. Dash: A / Space. Pause: Start / Esc / the on-screen II.
##
## Deliberately small (one file, drawn in code, no art files) so it reads as an example of how the
## template's pieces fit: TouchControls layout, AudioManager music + sfx, PauseMenu, SaveManager
## best time, SceneDirector to the results screen.
##
## Everything a test or a bot needs is public state: `player`, `orbs`, `hazards`, `collected`,
## `time_left`, `state`. Set `rng_seed` for a reproducible layout (the demo does).

enum State { PLAYING, WON, LOST }

const GOAL := 10
const TIME_LIMIT := 30.0
const SPEED := 380.0
const DASH_SPEED := 1000.0
const DASH_SEC := 0.16
const DASH_COOLDOWN := 0.7
const PLAYER_R := 22.0
const ORB_R := 14.0
const HAZARD_R := 26.0
const HIT_PENALTY := 3.0
const INVULN_SEC := 1.0
const ORBS_ON_FIELD := 3
const ARENA := Rect2(40, 90, 1200, 600)
const RESULTS := "res://samples/sample_game/results.tscn"

const MUSIC := preload("res://samples/assets/audio/music_loop.ogg")
const SFX_PICKUP := preload("res://samples/assets/audio/pickup.wav")
const SFX_HIT := preload("res://samples/assets/audio/hit.wav")
const SFX_DASH := preload("res://samples/assets/audio/dash.wav")
const SFX_WIN := preload("res://samples/assets/audio/win.wav")
const SFX_LOSE := preload("res://samples/assets/audio/lose.wav")

## Shared with the results screen.
static var last_result := {}

var rng_seed := -1
var state := State.PLAYING
var player := ARENA.get_center()
var facing := Vector2.RIGHT
var orbs: Array[Vector2] = []
var hazards: Array[Dictionary] = []
var collected := 0
var time_left := TIME_LIMIT
var elapsed := 0.0

var _rng := RandomNumberGenerator.new()
var _dash_left := 0.0
var _dash_cool := 0.0
var _invuln := 0.0
var _pops: Array[Dictionary] = []   # floating "+1" / "-3s" text
var _hud_orbs: Label
var _hud_time: Label
var _t := 0.0


func _ready() -> void:
	if OS.get_environment("ORB_SEED") != "":
		rng_seed = int(OS.get_environment("ORB_SEED"))
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	for i in ORBS_ON_FIELD:
		orbs.append(_free_spot())
	for v in [Vector2(260, 190), Vector2(-220, 240)]:
		hazards.append({"pos": _free_spot(), "vel": v})
	TouchControls.set_layout(TouchControls.Layout.STICK_A)
	AudioManager.play_music(MUSIC)
	_build_hud()


func _process(dt: float) -> void:
	_t += dt
	for p in _pops:
		p.life -= dt
		p.pos.y -= 50 * dt
	_pops = _pops.filter(func(p): return p.life > 0.0)
	if state == State.PLAYING:
		_step(dt)
	_hud_orbs.text = "Orbs  %d / %d" % [collected, GOAL]
	_hud_time.text = "%.1f s" % maxf(time_left, 0.0)
	_hud_time.add_theme_color_override(&"font_color", Color(1, 0.4, 0.35) if time_left < 8.0 else UiStyle.TEXT)
	queue_redraw()


func _step(dt: float) -> void:
	elapsed += dt
	time_left -= dt
	_dash_cool -= dt
	_invuln -= dt
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.1:
		facing = dir.normalized()
	if Input.is_action_just_pressed("action_a") and _dash_cool <= 0.0:
		_dash_left = DASH_SEC
		_dash_cool = DASH_COOLDOWN
		AudioManager.play_sfx(SFX_DASH, 0.05)
	var speed := DASH_SPEED if _dash_left > 0.0 else SPEED
	var v := (facing if _dash_left > 0.0 else dir) * speed
	_dash_left -= dt
	player = (player + v * dt).clamp(ARENA.position + Vector2.ONE * PLAYER_R, ARENA.end - Vector2.ONE * PLAYER_R)

	for i in orbs.size():
		if player.distance_to(orbs[i]) < PLAYER_R + ORB_R:
			collected += 1
			_pop(orbs[i], "+1", Color(1, 0.85, 0.3))
			AudioManager.play_sfx(SFX_PICKUP, 0.04)
			orbs[i] = _free_spot()
			if collected >= GOAL:
				_end(State.WON)
				return
	for h in hazards:
		h.pos += h.vel * dt
		for axis in 2:
			if h.pos[axis] < ARENA.position[axis] + HAZARD_R or h.pos[axis] > ARENA.end[axis] - HAZARD_R:
				h.vel[axis] = -h.vel[axis]
				h.pos[axis] = clampf(h.pos[axis], ARENA.position[axis] + HAZARD_R, ARENA.end[axis] - HAZARD_R)
		if _invuln <= 0.0 and player.distance_to(h.pos) < PLAYER_R + HAZARD_R - 4.0:
			time_left -= HIT_PENALTY
			_invuln = INVULN_SEC
			player += (player - h.pos).normalized() * 60.0
			_pop(player, "-3 s", Color(1, 0.4, 0.35))
			AudioManager.play_sfx(SFX_HIT)
	if time_left <= 0.0:
		_end(State.LOST)


func _end(s: State) -> void:
	state = s
	var best := float(SaveManager.get_value("orb_run", "best_time", 0.0))
	var new_best := s == State.WON and (best <= 0.0 or elapsed < best)
	if new_best:
		SaveManager.set_value("orb_run", "best_time", elapsed)
		SaveManager.save()
	last_result = {"won": s == State.WON, "collected": collected, "time": elapsed,
		"best": float(SaveManager.get_value("orb_run", "best_time", 0.0)), "new_best": new_best}
	AudioManager.stop_music(0.4)
	AudioManager.play_sfx(SFX_WIN if s == State.WON else SFX_LOSE)
	TouchControls.set_layout(TouchControls.Layout.NONE)
	await get_tree().create_timer(1.4).timeout
	SceneDirector.goto(RESULTS)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.PLAYING and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		PauseMenu.open(self, [
			{"text": "Resume"},
			{"text": "Restart", "action": func(): SceneDirector.goto(scene_file_path)},
			{"text": "Quit to samples", "action": func(): SceneDirector.goto("res://samples/samples_menu.tscn")},
		])


func _free_spot() -> Vector2:
	for attempt in 40:
		var p := Vector2(_rng.randf_range(ARENA.position.x + 50, ARENA.end.x - 50),
			_rng.randf_range(ARENA.position.y + 50, ARENA.end.y - 50))
		if p.distance_to(player) > 160.0:
			return p
	return ARENA.get_center()


func _pop(at: Vector2, text: String, color: Color) -> void:
	_pops.append({"pos": at, "text": text, "color": color, "life": 0.8})


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	_hud_orbs = _hud_label(hud, Vector2(48, 24))
	_hud_time = _hud_label(hud, Vector2(560, 24))


func _hud_label(parent: Node, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_override(&"font", UiStyle.FONT_DISPLAY)
	l.add_theme_font_size_override(&"font_size", 40)
	l.add_theme_color_override(&"font_color", UiStyle.TEXT)
	parent.add_child(l)
	return l


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), UiStyle.BG)
	draw_rect(ARENA, Color(0.1, 0.12, 0.24))
	for x in range(int(ARENA.position.x), int(ARENA.end.x), 50):
		draw_line(Vector2(x, ARENA.position.y), Vector2(x, ARENA.end.y), Color(1, 1, 1, 0.04))
	for y in range(int(ARENA.position.y), int(ARENA.end.y), 50):
		draw_line(Vector2(ARENA.position.x, y), Vector2(ARENA.end.x, y), Color(1, 1, 1, 0.04))
	draw_rect(ARENA, Color(0.35, 0.75, 1.0, 0.5), false, 3.0)
	for o in orbs:
		var pulse := 1.0 + 0.15 * sin(_t * 6.0 + o.x)
		draw_circle(o, ORB_R * 2.2 * pulse, Color(1, 0.8, 0.2, 0.12))
		draw_circle(o, ORB_R * pulse, Color(1, 0.82, 0.25))
		draw_circle(o + Vector2(-4, -4), ORB_R * 0.35, Color(1, 1, 0.9, 0.9))
	for h in hazards:
		var pts := PackedVector2Array()
		for k in 16:
			var r := HAZARD_R * (1.0 if k % 2 == 0 else 0.55)
			pts.append(h.pos + Vector2.from_angle(k * TAU / 16 + _t * 3.0) * r)
		draw_colored_polygon(pts, Color(0.95, 0.3, 0.3))
	var blink := _invuln > 0.0 and int(_t * 12) % 2 == 0
	if not blink:
		if _dash_left > 0.0:
			draw_circle(player - facing * 18, PLAYER_R * 0.9, Color(0.35, 0.85, 1.0, 0.35))
		draw_circle(player, PLAYER_R, Color(0.35, 0.85, 1.0))
		var side := facing.orthogonal() * 7.0
		for s in [side, -side]:
			draw_circle(player + facing * 8 + s, 5.0, Color.WHITE)
			draw_circle(player + facing * 10 + s, 2.5, Color(0.05, 0.08, 0.16))
	var font := UiStyle.FONT_DISPLAY
	for p in _pops:
		draw_string(font, p.pos, p.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color(p.color, clampf(p.life / 0.8, 0, 1)))

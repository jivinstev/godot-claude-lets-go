extends Node3D
## A small 3D scene on the Mobile renderer: sky, sun with shadows, a CC0 animated character
## (Quaternius, see CREDITS.md) you walk around with the stick, and a follow camera.
## A / Space waves. Pause / Esc / II opens the pause menu.
##
## Built in code so the whole example is readable top to bottom in one file.

const MODEL := preload("res://samples/assets/models/Hoodie.glb")
const SPEED := 4.0
const TURN := 10.0

var character: Node3D
var anim: AnimationPlayer
var camera: Camera3D
var _waving := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.55, 0.32)
	ground.material_override = gm
	add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 14:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var h := rng.randf_range(0.6, 2.6)
		bm.size = Vector3(1, h, 1)
		box.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.from_hsv(rng.randf(), 0.45, 0.9)
		box.material_override = m
		var a := rng.randf() * TAU
		box.position = Vector3(cos(a), 0, sin(a)) * rng.randf_range(6, 14) + Vector3(0, h / 2, 0)
		add_child(box)
	character = MODEL.instantiate()
	add_child(character)
	anim = character.find_children("*", "AnimationPlayer", true, false)[0]
	_play("Idle")
	camera = Camera3D.new()
	camera.fov = 60
	add_child(camera)
	_follow(1.0)
	TouchControls.set_layout(TouchControls.Layout.STICK_A)


func _process(dt: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Move relative to the camera, so "up" on the stick is always "away from me".
	var fwd := -camera.global_basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var dir := (right * input.x - fwd * input.y)
	_waving -= dt
	if dir.length() > 0.1:
		_waving = 0.0
		character.position += dir.limit_length(1.0) * SPEED * dt
		var target := atan2(dir.x, dir.z)
		character.rotation.y = lerp_angle(character.rotation.y, target, minf(1.0, TURN * dt))
		_play("Run")
	elif _waving <= 0.0:
		_play("Idle")
	if Input.is_action_just_pressed("action_a"):
		_waving = 1.6
		_play("Wave")
	_follow(dt)


func _follow(dt: float) -> void:
	var want := character.position + Vector3(0, 3.2, 6.0)
	camera.position = camera.position.lerp(want, minf(1.0, 4.0 * dt))
	camera.look_at(character.position + Vector3(0, 1.0, 0))


func _play(name: String) -> void:
	var full := "CharacterArmature|" + name
	if anim.current_animation != full and anim.has_animation(full):
		anim.play(full, 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		PauseMenu.open(self, [
			{"text": "Resume"},
			{"text": "Back to samples", "action": func(): SceneDirector.goto("res://samples/samples_menu.tscn")},
		])

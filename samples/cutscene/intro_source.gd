extends Node2D
## The animation that tools/gen_sample_cutscene.sh RECORDS into samples/assets/video/intro.ogv.
## Not played in the game — the .ogv is. It is here to show one way to make a cutscene without
## a video editor: animate a scene, record it with Movie Maker, transcode to Theora.
## (Any video works: see CutscenePlayer for the ffmpeg line that converts an .mp4.)

const LENGTH := 7.0
var _t := 0.0
var _stars: Array[Vector3] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 140:
		_stars.append(Vector3(rng.randf() * 1280, rng.randf() * 720, rng.randf_range(0.3, 1.0)))
	AudioManager.play_music(preload("res://samples/assets/audio/music_loop.ogg"), 0.8)


func _process(dt: float) -> void:
	_t += dt
	if _t > 6.2 and AudioManager.is_music_playing():
		AudioManager.stop_music(0.7)
	queue_redraw()


func _ease(a: float, b: float) -> float:
	return smoothstep(a, b, _t)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.05, 0.11))
	for s in _stars:
		var x := fposmod(s.x - _t * 60.0 * s.z, 1280.0)
		draw_circle(Vector2(x, s.y), 1.6 * s.z, Color(1, 1, 1, 0.3 + 0.6 * s.z))
	# An orb sweeps across, leaving a trail
	var k := _ease(0.3, 2.2)
	var orb := Vector2(lerpf(-60, 640, k), 360 + sin(k * PI) * -120)
	for i in 12:
		draw_circle(orb - Vector2(i * 14, -i * 3) * (1.0 - k * 0.5), 18 - i, Color(1, 0.8, 0.25, 0.08 * (12 - i)))
	draw_circle(orb, 30 + 6 * sin(_t * 6), Color(1, 0.82, 0.25))
	var font := UiStyle.FONT_DISPLAY
	var a := _ease(1.6, 2.4)
	var sz := int(lerpf(60, 150, a))
	_center_text(font, "ORB RUN", Vector2(640, 250), sz, Color(1, 0.8, 0.2, a))
	var b := _ease(3.0, 3.6) * (1.0 - _ease(6.3, 6.9))
	_center_text(UiStyle.FONT_BODY, "Ten orbs.  Thirty seconds.  Mind the spikes.", Vector2(640, 520), 34, Color(1, 1, 1, b))
	var spike := Vector2(lerpf(1380, 980, _ease(3.6, 5.0)), 600)
	var pts := PackedVector2Array()
	for i in 16:
		pts.append(spike + Vector2.from_angle(i * TAU / 16 + _t * 3) * (34.0 if i % 2 == 0 else 19.0))
	draw_colored_polygon(pts, Color(0.95, 0.3, 0.3, _ease(3.6, 4.0)))
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, _ease(6.4, 7.0)))


func _center_text(font: Font, text: String, at: Vector2, size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, at + Vector2(-w / 2, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

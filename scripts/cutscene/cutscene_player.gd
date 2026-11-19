class_name CutscenePlayer
extends Control
## A full-screen video cutscene with optional subtitles, then on to the next scene.
##
## Make one by creating a scene whose root is a Control with this script, and set the three
## exports in the Inspector (or in the .tscn). See samples/cutscene/intro_cutscene.tscn.
##
## - Video must be Ogg Theora (.ogv) — the only format Godot plays natively. Convert anything with:
##     ffmpeg -i in.mp4 -c:v libtheora -q:v 7 -c:a libvorbis -q:a 5 out.ogv
## - Letterboxed to 16:9 on any screen; black bars, never stretched.
## - Skippable (if `skippable`): tap anywhere, or ui_accept / ui_cancel / pause. A hint appears
##   on the first input, so an accidental tap doesn't throw the scene away; a second one skips.
## - The next scene loads on a background thread WHILE the video plays, so it starts instantly.

signal finished

@export_file("*.ogv") var video_path := ""
@export_file("*.srt") var subtitles_path := ""
@export_file("*.tscn") var next_scene := "res://scenes/title_screen.tscn"
@export var skippable := true

var _video: VideoStreamPlayer
var _subs: Label
var _hint: Label
var _cues: Array[Dictionary] = []
var _done := false
var _armed := false
var _time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var fit := AspectRatioContainer.new()
	fit.ratio = 16.0 / 9.0
	fit.set_anchors_preset(Control.PRESET_FULL_RECT)
	fit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fit)
	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	fit.add_child(_video)
	_subs = _make_label(34, true)
	_hint = _make_label(22, false)
	var touch := DisplayServer.is_touchscreen_available() or OS.get_environment("TOUCH_SIM") == "1"
	_hint.text = "Tap again to skip" if touch else "Press again to skip"
	_hint.visible = false
	if subtitles_path != "":
		_cues = Srt.load_file(subtitles_path)
	if ResourceLoader.exists(next_scene):
		ResourceLoader.load_threaded_request(next_scene)
	if video_path != "" and ResourceLoader.exists(video_path):
		_video.stream = load(video_path)
		_video.finished.connect(_finish)
		AudioManager.stop_music(0.3)
		_video.play()
	else:
		push_warning("CutscenePlayer: no video at '%s' — skipping straight on" % video_path)
		_finish.call_deferred()


## Seconds into the cutscene (the video clock when it has one).
func position_sec() -> float:
	return _video.stream_position if _video.is_playing() else _time


func current_subtitle() -> String:
	return _subs.text


func _process(dt: float) -> void:
	_time += dt
	if not _cues.is_empty():
		_subs.text = Srt.text_at(_cues, position_sec())


func _input(event: InputEvent) -> void:
	if not skippable or _done:
		return
	var tapped := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var clicked := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if tapped or clicked or event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if _armed:
			_finish()
		else:
			_armed = true
			_hint.visible = true


func _finish() -> void:
	if _done:
		return
	_done = true
	_video.stop()
	finished.emit()
	SceneDirector.goto(next_scene)


func _make_label(font_size: int, bottom: bool) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if bottom else HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if bottom else VERTICAL_ALIGNMENT_TOP
	l.add_theme_font_override(&"font", UiStyle.FONT_BODY)
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_constant_override(&"outline_size", 8)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	# Full-width strip anchored to the bottom (subtitles) or the top (skip hint), so text of any
	# length stays on screen instead of growing off an edge.
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.anchor_top = 1.0 if bottom else 0.0
	l.anchor_bottom = 1.0 if bottom else 0.0
	l.offset_left = 40
	l.offset_right = -40
	l.offset_top = -190 if bottom else 24
	l.offset_bottom = -56 if bottom else 80
	return l

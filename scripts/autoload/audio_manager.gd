extends Node
## Music and sound effects.
##
##   AudioManager.play_music(preload("res://.../loop.ogg"))      # crossfades from whatever plays
##   AudioManager.play_sfx(preload("res://.../pickup.wav"), 0.1) # 0.1 = ±10% random pitch
##   AudioManager.set_volume("Music", 0.5)                        # 0..1, saved in settings
##
## Rules this follows, each from a bug that shipped past a green test suite elsewhere:
##  - NEVER STEP A GAIN mid-waveform. An instant volume change is a click. Every level change here
##    is ramped over at least FADE_MIN_SEC.
##  - Sounds belong to this autoload, not to the scene that asked for them, so a pickup sound
##    played on the frame you change scenes still finishes.
##  - Runs while the tree is paused, so menus over a paused game still make sound.
##
## Buses (default_bus_layout.tres): Master → Music, SFX.

const FADE_MIN_SEC := 0.04
const SFX_VOICES := 12
const SILENT_DB := -60.0

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_a = _make_player("Music")
	_music_b = _make_player("Music")
	_music_current = _music_a
	for i in SFX_VOICES:
		_sfx.append(_make_player("SFX"))
	for bus in ["Master", "Music", "SFX"]:
		_apply_volume(bus, float(SaveManager.get_value("settings", "volume_" + bus, 1.0)))


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"
	add_child(p)
	return p


## Play `stream` as music, crossfading from the current track over `fade_sec`. Playing the
## track that is already playing does nothing (so re-entering a menu doesn't restart it).
## Loop by setting `loop` on the imported stream (Import dock → Loop), or pass loop=true.
func play_music(stream: AudioStream, fade_sec: float = 0.6, loop: bool = true) -> void:
	if stream == null:
		stop_music(fade_sec)
		return
	if _music_current.playing and _music_current.stream == stream:
		return
	if loop:
		_set_loop(stream)
	var old := _music_current
	var new := _music_b if old == _music_a else _music_a
	new.stream = stream
	new.volume_db = SILENT_DB
	new.play()
	_music_current = new
	var f := maxf(fade_sec, FADE_MIN_SEC)
	create_tween().tween_property(new, "volume_db", 0.0, f)
	if old.playing:
		var t := create_tween()
		t.tween_property(old, "volume_db", SILENT_DB, f)
		t.tween_callback(old.stop)


func stop_music(fade_sec: float = 0.6) -> void:
	var p := _music_current
	if not p.playing:
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", SILENT_DB, maxf(fade_sec, FADE_MIN_SEC))
	t.tween_callback(p.stop)


func is_music_playing() -> bool:
	return _music_current.playing


func current_music() -> AudioStream:
	return _music_current.stream if _music_current.playing else null


## Fire-and-forget sound effect. `pitch_jitter` adds variety to repeated sounds.
func play_sfx(stream: AudioStream, pitch_jitter: float = 0.0, volume_db: float = 0.0) -> AudioStreamPlayer:
	if stream == null:
		return null
	var p := _sfx[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter) if pitch_jitter > 0.0 else 1.0
	p.play()
	return p


## Bus volume as 0..1 (linear amplitude). Ramped over FADE_MIN_SEC (an instant step is a click)
## and written to disk under settings/volume_<bus> — pass persist=false to skip the save.
func set_volume(bus: String, linear: float, persist: bool = true) -> void:
	linear = clampf(linear, 0.0, 1.0)
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	var from := db_to_linear(AudioServer.get_bus_volume_db(i)) if not AudioServer.is_bus_mute(i) else 0.0
	AudioServer.set_bus_mute(i, false)
	var t := create_tween()
	t.tween_method(func(v: float): AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001))), from, linear, FADE_MIN_SEC)
	t.tween_callback(func(): _apply_volume(bus, linear))
	SaveManager.set_value("settings", "volume_" + bus, linear)
	if persist:
		SaveManager.save()


func get_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(i)) if i >= 0 else 0.0


func _apply_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.0)


static func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			# loop_end is in frames; 0 means "nothing set" for a generated stream.
			if w.loop_end <= 0:
				var bytes_per_frame := (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)
				w.loop_end = w.data.size() / bytes_per_frame

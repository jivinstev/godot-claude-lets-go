extends GutTest
## Real samples from the mixer (the Dummy driver still mixes): AudioProbe hears what plays.

var _probe: AudioProbe


func after_each() -> void:
	AudioManager.stop_music(0.0)
	if _probe:
		_probe.stop()
	AudioManager.set_volume("Music", 1.0)
	await wait_seconds(0.2)


func test_sfx_is_audible_on_the_sfx_bus() -> void:
	_probe = AudioProbe.listen_to("SFX")
	AudioManager.play_sfx(Tone.make(660, 0.6))
	var level := await _probe.level_over(self, 0.3)
	assert_gt(level, AudioProbe.AUDIBLE, "a played sound effect reaches the SFX bus")


func test_music_plays_and_stops() -> void:
	_probe = AudioProbe.listen_to("Music")
	AudioManager.play_music(Tone.make(220, 2.0), 0.05)
	await wait_seconds(0.2)
	assert_gt(await _probe.level_over(self, 0.3), AudioProbe.AUDIBLE, "music is audible")
	AudioManager.stop_music(0.05)
	await wait_seconds(0.3)
	_probe.clear()
	assert_lt(await _probe.level_over(self, 0.3), AudioProbe.AUDIBLE, "stopping music silences it")


func test_replaying_the_current_track_does_not_restart_it() -> void:
	var t := Tone.make(220, 3.0)
	AudioManager.play_music(t, 0.05)
	await wait_seconds(0.5)
	AudioManager.play_music(t, 0.05)
	await wait_frames(2)
	assert_eq(AudioManager.current_music(), t)


func test_volume_zero_mutes_and_is_saved() -> void:
	AudioManager.set_volume("Music", 0.0)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	assert_eq(SaveManager.get_value("settings", "volume_Music"), 0.0)

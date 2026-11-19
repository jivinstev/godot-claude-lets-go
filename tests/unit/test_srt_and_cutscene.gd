extends GutTest

const SAMPLE := "﻿1\r\n00:00:00,500 --> 00:00:02,000\r\nHello\r\n\r\n2\r\n00:00:02.000 --> 00:00:04,250\r\nTwo\r\nlines\r\n\r\njunk --> nonsense\r\nignored\r\n"


func test_parses_cues_with_crlf_bom_and_dot_millis() -> void:
	var cues := Srt.parse(SAMPLE)
	assert_eq(cues.size(), 2, "the malformed block is skipped, not fatal")
	assert_almost_eq(cues[0].start, 0.5, 0.001)
	assert_eq(cues[0].text, "Hello", "the first cue survives (it was dropped on Android elsewhere)")
	assert_almost_eq(cues[1].end, 4.25, 0.001)
	assert_eq(cues[1].text, "Two\nlines")


func test_text_at() -> void:
	var cues := Srt.parse(SAMPLE)
	assert_eq(Srt.text_at(cues, 0.1), "")
	assert_eq(Srt.text_at(cues, 1.0), "Hello")
	assert_eq(Srt.text_at(cues, 3.0), "Two\nlines")


func test_cutscene_without_video_moves_on() -> void:
	SceneDirector.capture_only = true
	var c := CutscenePlayer.new()
	c.video_path = "res://does/not/exist.ogv"
	c.next_scene = "res://scenes/game.tscn"
	add_child_autofree(c)
	await wait_process_frames(3)
	assert_eq(SceneDirector.last_target, "res://scenes/game.tscn")
	SceneDirector.capture_only = false

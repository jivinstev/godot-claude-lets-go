class_name Srt
extends RefCounted
## SubRip (.srt) subtitles → [{start, end, text}] in seconds, sorted by start.
##
## Scans for timecode lines ("-->") instead of splitting on blank lines: the blank-line split
## dropped the FIRST cue on exported Android builds in the project this came from. Malformed
## blocks are skipped, never fatal. Multi-line cues are joined with "\n".


static func load_file(path: String) -> Array[Dictionary]:
	if not FileAccess.file_exists(path):
		push_warning("Srt: no file at %s" % path)
		return []
	return parse(FileAccess.get_file_as_string(path))


static func parse(text: String) -> Array[Dictionary]:
	var cues: Array[Dictionary] = []
	text = text.replace("\r\n", "\n").replace("\r", "\n").trim_prefix("﻿")
	var lines := text.split("\n")
	var i := 0
	while i < lines.size():
		var t := _timecode(lines[i].strip_edges())
		if t.is_empty():
			i += 1
			continue
		var body: PackedStringArray = []
		var j := i + 1
		while j < lines.size() and lines[j].strip_edges() != "":
			body.append(lines[j].strip_edges())
			j += 1
		if not body.is_empty():
			cues.append({"start": t.start, "end": t.end, "text": "\n".join(body)})
		i = j
	cues.sort_custom(func(a, b): return a.start < b.start)
	return cues


## The cue text showing at `t` seconds, or "".
static func text_at(cues: Array[Dictionary], t: float) -> String:
	for c in cues:
		if t >= c.start and t < c.end:
			return c.text
	return ""


static func _timecode(line: String) -> Dictionary:
	var halves := line.split("-->")
	if halves.size() != 2:
		return {}
	var a := _seconds(halves[0].strip_edges())
	var b := _seconds(halves[1].strip_edges().split(" ")[0])
	return {} if a < 0.0 or b < 0.0 else {"start": a, "end": b}


static func _seconds(s: String) -> float:
	var p := s.replace(",", ".").split(":")
	if p.size() != 3 or not p[0].is_valid_int() or not p[1].is_valid_int() or not p[2].is_valid_float():
		return -1.0
	return p[0].to_int() * 3600.0 + p[1].to_int() * 60.0 + p[2].to_float()

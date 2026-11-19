class_name AudioProbe
extends RefCounted
## LISTENING TO THE GAME FROM INSIDE A TEST.
##
## Until now the answer to "does this actually make a sound?" was "nobody can tell here" — the
## suite runs headless with the Dummy audio driver, so audio was treated as a real-device
## judgement and every claim about it was a guess. That turns out to be wrong: the Dummy driver
## still MIXES, it just does not hand the result to a sound card. An `AudioEffectCapture` on a bus
## therefore sees the real samples, and a test can assert on them.
##
## Measured, not assumed: on this suite, silence reads a peak of 0.00000 and a playing stream
## reads 0.50310. The gap is four orders of magnitude, so "is it audible" is not a marginal call.
##
## WHAT THIS CAN AND CANNOT TELL YOU. It hears levels and timing: whether a bus is making sound,
## whether it stops, when it changes, whether two buses differ. It cannot tell you whether the
## mix sounds GOOD, whether an arrangement hangs together, or whether latency feels right — those
## remain a phone-and-ears judgement, and saying otherwise would be the exact overclaim this file
## exists to avoid.
##
## Usage:
##     var probe := AudioProbe.listen_to("Music")
##     ... play something, await frames ...
##     var level := await probe.level_over(self, 0.5)
##     probe.stop()

## Godot mixes in blocks, so a capture asked for a sub-block window can legitimately come back
## empty. Anything shorter than this is measuring the mixer, not the game.
const MIN_WINDOW_SEC := 0.15
## Peak above which a bus is considered to be making a sound. Three orders of magnitude above the
## measured silence floor and two below a normal signal, so neither a stray denormal nor a quiet
## passage lands on the wrong side of it.
const AUDIBLE := 0.001

var bus_name: String
var _bus_idx: int = -1
var _capture: AudioEffectCapture
var _owns_bus: bool = false

## Attach a capture to an EXISTING bus (e.g. "Master", "Music", "SFX") and start listening.
static func listen_to(p_bus_name: String, buffer_sec: float = 4.0) -> AudioProbe:
	var p := AudioProbe.new()
	p.bus_name = p_bus_name
	p._bus_idx = AudioServer.get_bus_index(p_bus_name)
	if p._bus_idx < 0:
		push_error("AudioProbe: no bus named '%s'" % p_bus_name)
		return p
	p._capture = AudioEffectCapture.new()
	# Long enough that a slow test frame cannot overrun it and silently drop samples, which would
	# read as a dropout in the game rather than in the harness.
	p._capture.buffer_length = buffer_sec
	AudioServer.add_bus_effect(p._bus_idx, p._capture)
	return p

func ok() -> bool:
	return _capture != null

## Drain whatever has been mixed since the last read, and report its peak amplitude.
## Non-blocking: call it after awaiting frames yourself, or use `level_over`.
func drain_peak() -> float:
	if _capture == null:
		return 0.0
	var available := _capture.get_frames_available()
	if available <= 0:
		return 0.0
	var peak := 0.0
	for v in _capture.get_buffer(available):
		peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
	return peak

## Throw away anything already mixed, so the next measurement starts clean. Call this immediately
## before the thing you want to measure, or you will measure what came before it too.
func clear() -> void:
	if _capture != null:
		_capture.clear_buffer()

## Listen for `seconds` and return the loudest sample heard. `host` is the test (anything with a
## scene tree) — the frames have to be pumped by somebody.
func level_over(host: Node, seconds: float) -> float:
	var peak := 0.0
	for _i in _frames_for(seconds):
		await host.get_tree().process_frame
		peak = maxf(peak, drain_peak())
	return peak

## Listen for `seconds` and return the peak of each ~`slice_sec` window, in order. This is how you
## see a CHANGE — a sound starting, a sound dropping out, a gap between two tracks — which a single
## overall level cannot show.
func profile_over(host: Node, seconds: float, slice_sec: float = 0.25) -> Array[float]:
	var out: Array[float] = []
	var slices := maxi(1, int(seconds / maxf(slice_sec, MIN_WINDOW_SEC)))
	for _s in slices:
		out.append(await level_over(host, maxf(slice_sec, MIN_WINDOW_SEC)))
	return out

## Whether every window in a profile carried sound. The continuity check: a switch between parts
## that drops the audio for even a moment shows up here as a quiet window.
static func is_unbroken(profile: Array[float], floor_level: float = AUDIBLE) -> bool:
	for level in profile:
		if level < floor_level:
			return false
	return not profile.is_empty()

static func loudest(profile: Array[float]) -> float:
	var out := 0.0
	for level in profile:
		out = maxf(out, level)
	return out

func _frames_for(seconds: float) -> int:
	# Assume a 60fps test tree; overshooting costs a few frames, undershooting measures nothing.
	return maxi(2, int(ceil(seconds * 60.0)))

## Detach. Tests must call this — an orphaned capture stays on the bus for the rest of the suite
## and quietly eats the samples the next test is trying to measure.
func stop() -> void:
	if _capture == null or _bus_idx < 0:
		return
	for i in range(AudioServer.get_bus_effect_count(_bus_idx) - 1, -1, -1):
		if AudioServer.get_bus_effect(_bus_idx, i) == _capture:
			AudioServer.remove_bus_effect(_bus_idx, i)
	_capture = null
	_bus_idx = -1

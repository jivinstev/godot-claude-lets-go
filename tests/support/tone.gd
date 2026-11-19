class_name Tone
## A generated sine tone, for tests that need something audible without shipping a file.

static func make(freq: float = 440.0, seconds: float = 1.0, rate: int = 22050) -> AudioStreamWAV:
	var n := int(seconds * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(sin(TAU * freq * i / rate) * 12000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w

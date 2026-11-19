#!/usr/bin/env python3
"""Generate the samples' sound effects and music loop — original, CC0, no downloads.

    python3 tools/gen_sample_audio.py        # writes samples/assets/audio/*

Why generated: Claude Code's default network policy blocks the usual CC0 asset sites, and a
generator is its own licence record. Replace these with real assets whenever you like (add a
CREDITS.md row first). Pure stdlib; ffmpeg converts the music to Ogg Vorbis.
"""
import math, os, random, struct, subprocess, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "samples", "assets", "audio")
os.makedirs(OUT, exist_ok=True)
rnd = random.Random(7)


def write(name, samples):
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 30000)) for s in samples))
    return path


def square(f, t, duty=0.5):
    return 1.0 if (f * t) % 1.0 < duty else -1.0


def tri(f, t):
    x = (f * t) % 1.0
    return 4 * abs(x - 0.5) - 1


def env(i, n, a=0.005, r=0.05):
    t, d = i / RATE, n / RATE
    return min(1.0, t / a if a else 1.0) * min(1.0, (d - t) / r if r else 1.0)


def note(freq, sec, wave_fn=square, vol=0.3, a=0.005, r=0.05, slide=0.0):
    n = int(sec * RATE)
    return [wave_fn(freq * (1 + slide * i / n), i / RATE) * vol * env(i, n, a, r) for i in range(n)]


def hz(semis_from_a4):
    return 440.0 * 2 ** (semis_from_a4 / 12)


# --- sound effects ---------------------------------------------------------------------------
pickup = []
for s in [3, 7, 10, 15]:                      # C E G C, quick arpeggio up
    pickup += note(hz(s + 12), 0.045, square, 0.25, r=0.02)
write("pickup.wav", pickup)

hit = [((rnd.random() * 2 - 1) * 0.6 + square(90 - 50 * i / 11025, i / RATE) * 0.4) * (1 - i / 11025) ** 2
       for i in range(11025)]
write("hit.wav", hit)

dash = [(rnd.random() * 2 - 1) * 0.35 * math.sin(math.pi * i / 8820) for i in range(8820)]
write("dash.wav", dash)

win = []
for s in [3, 7, 10, 15, 19, 22]:
    win += note(hz(s), 0.09, square, 0.25, r=0.03)
win += note(hz(27), 0.5, tri, 0.4, r=0.3)
write("win.wav", win)

lose = []
for s in [10, 6, 3, -2]:
    lose += note(hz(s), 0.18, square, 0.22, slide=-0.03, r=0.06)
lose += note(hz(-5), 0.5, tri, 0.35, r=0.35)
write("lose.wav", lose)

# --- music loop: 8 bars, 128 bpm, C–Am–F–G. Exactly loop-length, so it loops seamlessly. ----
BPM = 128
beat = 60 / BPM
bars = 8
n_total = int(round(bars * 4 * beat * RATE))
mix = [0.0] * n_total


def add(at_beat, samples):
    start = int(round(at_beat * beat * RATE))
    for i, s in enumerate(samples):
        j = start + i
        if j < n_total:
            mix[j] += s


chords = [[3, 7, 10], [0, 3, 7], [-4, 0, 3], [-2, 2, 5]]      # C, Am, F, G (semitones from A4)
melody = [15, 12, 10, 12, 15, 17, 15, 12,   12, 10, 7, 10, 12, 15, 12, 10,
          8, 10, 12, 15, 17, 15, 12, 10,    10, 12, 14, 17, 19, 17, 14, 12]
for bar in range(bars):
    ch = chords[bar % 4]
    root = ch[0] - 24
    for b in range(4):                                         # bass: root on beats, octave on offbeats
        add(bar * 4 + b, note(hz(root), beat * 0.45, square, 0.16, r=0.03))
        add(bar * 4 + b + 0.5, note(hz(root + 12), beat * 0.3, square, 0.10, r=0.03))
    for k in range(8):                                         # arpeggio pad, eighth notes
        add(bar * 4 + k * 0.5, note(hz(ch[k % 3]), beat * 0.42, lambda f, t: square(f, t, 0.25), 0.05, r=0.04))
    if bar >= 2:                                               # lead enters on bar 3
        for k in range(4):
            m = melody[((bar - 2) * 4 + k) % len(melody)]
            add(bar * 4 + k, note(hz(m), beat * 0.85, tri, 0.20, a=0.01, r=0.12))
    for b in range(4):                                         # drums: kick 1&3, snare 2&4, hats
        t0 = bar * 4 + b
        if b % 2 == 0:
            add(t0, [math.sin(2 * math.pi * (110 - 70 * i / 4410) * i / RATE) * 0.5 * (1 - i / 4410) for i in range(4410)])
        else:
            add(t0, [(rnd.random() * 2 - 1) * 0.22 * (1 - i / 5000) ** 2 for i in range(5000)])
        add(t0 + 0.5, [(rnd.random() * 2 - 1) * 0.07 * (1 - i / 1500) for i in range(1500)])

peak = max(abs(s) for s in mix)
mix = [s / peak * 0.85 for s in mix]                          # normalise with headroom
wav = write("music_loop.wav", mix)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4",
                os.path.join(OUT, "music_loop.ogg")], check=True)
os.remove(wav)
for f in sorted(os.listdir(OUT)):
    print("%-16s %6.1f KB" % (f, os.path.getsize(os.path.join(OUT, f)) / 1024))

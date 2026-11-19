#!/usr/bin/env python3
"""Read the audio out of a captured clip and say what it actually did.

WHY THIS EXISTS. Godot's Movie Maker (`--write-movie out.avi`) writes a real PCM audio track
alongside the video, and it does so even under `--audio-driver Dummy` — so a headless machine with
no sound card can still record exactly what a player would hear. That makes "is this screen
silent?", "did the music drop out when I switched?" and "is there a click where one sound ends and the next starts?"
answerable from a capture instead of being deferred to a human with a phone.

WHAT IT LOOKS FOR, and why each one matters:

  gaps        A RUN of near-silent windows. One quiet window is usually the music — real music
              contains rests — a bass part can be digitally silent for a whole bar. Only a
              RUN means the audio actually stopped. Check the source file before blaming code.
  seams       A step in the waveform: a sound restarted or cut off mid-decay, or a volume stepped
              instead of ramped. Audible as a click, and invisible to every other kind of test.
  transitions What happens either side of a moment you name (a track change, a scene change): the
              level before, the level after, and whether there is a hole between them.

It is deliberately dependency-free (stdlib `wave` + `array`; numpy is not installed here) and
reports numbers rather than verdicts, so the caller decides what counts as a failure.

Usage:
    tools/audio_capture.sh res://samples/sample_game/demo.tscn game 900      # capture + profile
    tools/audio_profile.py clip.wav --seams
    tools/audio_profile.py clip.wav --at 23.3,47.0 --window 0.5
    tools/audio_profile.py clip.wav --quiet-below 0.01 --max-quiet-run 3

Exit status is 1 if a named check fails, so it can gate a build.
"""

import argparse
import array
import statistics
import sys
import wave

# Below this, a 16-bit window is indistinguishable from digital silence.
SILENCE = 1e-4
# Window used for seam scanning. Short enough to localise a click to a musical instant.
SEAM_WINDOW_SEC = 0.02


def read_mono(path):
    """Return (samples, rate). Left channel only — plenty for level and seam work, and half the
    samples to walk in pure Python."""
    with wave.open(path, "rb") as w:
        if w.getsampwidth() != 2:
            sys.exit("expected 16-bit PCM; got %d-byte samples" % w.getsampwidth())
        rate, channels = w.getframerate(), w.getnchannels()
        raw = w.readframes(w.getnframes())
    samples = array.array("h")
    samples.frombytes(raw)
    if channels > 1:
        samples = samples[::channels]
    return samples, rate


def window_stats(samples, rate, window_sec):
    """Yield (t, peak, rms) per window, normalised to 0..1."""
    per = max(1, int(rate * window_sec))
    for start in range(0, len(samples), per):
        chunk = samples[start:start + per]
        if not chunk:
            break
        peak = 0
        squares = 0
        for s in chunk:
            a = -s if s < 0 else s
            if a > peak:
                peak = a
            squares += s * s
        yield (start / rate, peak / 32768.0, (squares / len(chunk)) ** 0.5 / 32768.0)


def seam_scan(samples, rate):
    """Per short window, the largest sample-to-sample jump. A hard cut between two takes shows up
    as a step far larger than anything the music itself produces."""
    per = max(2, int(rate * SEAM_WINDOW_SEC))
    out = []
    prev = samples[0] if samples else 0
    for start in range(0, len(samples), per):
        chunk = samples[start:start + per]
        if len(chunk) < 2:
            break
        biggest = 0
        last = prev
        for s in chunk:
            d = s - last
            if d < 0:
                d = -d
            if d > biggest:
                biggest = d
            last = s
        prev = last
        out.append((start / rate, biggest / 32768.0))
    return out


def report_gaps(rows, quiet_below, max_run, window):
    run = 0
    worst_run = 0
    worst_at = 0.0
    for t, peak, _rms in rows:
        if peak < quiet_below:
            run += 1
            if run > worst_run:
                worst_run, worst_at = run, t - (run - 1) * window
        else:
            run = 0
    print()
    if worst_run > max_run:
        print("FAIL gaps: %d consecutive quiet windows (%.2fs) starting at %.2fs"
              % (worst_run, worst_run * window, worst_at))
        return False
    print("OK gaps: longest quiet run %d window(s) (%.2fs), within the %d allowed"
          % (worst_run, worst_run * window, max_run))
    return True


def report_seams(samples, rate, factor, top, floor=None, context_sec=2.0):
    """Flag steps that stand out AGAINST THEIR OWN NEIGHBOURHOOD.

    Comparing against a whole-file median does not work: a drum kit is nothing but sharp attacks,
    so featuring the drummer made every kick read as a cut, and the first run of this tool
    reported ten "seams" that were all just the drums. A real seam is a step that is abrupt
    RELATIVE TO THE MUSIC AROUND IT — loud in a passage of quiet ones — which is what a take being
    chopped off mid-decay looks like and what a kick drum among other kick drums does not.
    """
    jumps = seam_scan(samples, rate)
    if not jumps:
        return True
    # AN ABSOLUTE FLOOR AS WELL AS A RATIO. Relative-only scoring divides by a near-zero local
    # median during a quiet passage, so a barely-audible tick in near-silence scored 1300x and
    # buried anything real. A click you can actually hear is a big step in absolute terms too.
    loudest = max(j for _t, j in jumps)
    if floor is None:
        floor = max(0.05, 0.15 * loudest)
    per_context = max(1, int(context_sec / SEAM_WINDOW_SEC))
    scored = []
    for i, (t, j) in enumerate(jumps):
        if j < floor:
            continue
        lo = max(0, i - per_context // 2)
        hi = min(len(jumps), i + per_context // 2)
        neighbourhood = [m for _t, m in jumps[lo:hi]]
        local = statistics.median(neighbourhood) or 1e-6
        scored.append((t, j, j / local))

    ranked = sorted(scored, key=lambda p: -p[2])[:top]
    overall = statistics.median([j for _t, j in jumps]) or 1e-6
    print()
    print("seams: %d windows of %.0fms, median jump %.5f, loudest %.5f"
          % (len(jumps), SEAM_WINDOW_SEC * 1000, overall, loudest))
    print("       %d candidate(s) above the %.3f floor, scored against a %.1fs neighbourhood"
          % (len(scored), floor, context_sec))
    if not scored:
        print("OK seams: no step loud enough to be a click")
        return True
    print("  t(s)     jump     x local")
    flagged = 0
    for t, j, ratio in ranked:
        mark = "  <-- SEAM" if ratio >= factor else ""
        if ratio >= factor:
            flagged += 1
        print("  %7.2f  %.5f  %7.1f%s" % (t, j, ratio, mark))
    print()
    if flagged:
        print("NOTE seams: %d window(s) jump >= %.0fx their local median. A step that abrupt "
              "against its own surroundings is a take being cut off, which is audible as a click."
              % (flagged, factor))
    else:
        print("OK seams: nothing stood out by %.0fx against its neighbourhood" % factor)
    return flagged == 0


def report_transitions(samples, rate, times, span):
    """Level either side of each named moment, and the quietest instant between them."""
    print()
    print("transitions (+/- %.2fs around each named moment):" % span)
    print("  at(s)    before    after     min in between   verdict")
    ok = True
    for t in times:
        a0, a1 = max(0.0, t - span), t
        b0, b1 = t, t + span
        before = _rms(samples, rate, a0, a1)
        after = _rms(samples, rate, b0, b1)
        hole = _min_peak(samples, rate, a1 - 0.05, b0 + 0.15)
        verdict = "ok"
        if before > SILENCE and after < SILENCE:
            verdict = "STOPPED"
            ok = False
        elif hole < SILENCE and before > SILENCE and after > SILENCE:
            verdict = "GAP"
            ok = False
        print("  %6.2f   %.5f   %.5f   %.5f          %s" % (t, before, after, hole, verdict))
    return ok


def _slice(samples, rate, t0, t1):
    return samples[max(0, int(t0 * rate)):max(0, int(t1 * rate))]


def _rms(samples, rate, t0, t1):
    chunk = _slice(samples, rate, t0, t1)
    if not chunk:
        return 0.0
    return (sum(s * s for s in chunk) / len(chunk)) ** 0.5 / 32768.0


def _min_peak(samples, rate, t0, t1, step=0.02):
    """The quietest short window in a range — a hole between two takes shows up here even when the
    average either side looks healthy."""
    chunk = _slice(samples, rate, t0, t1)
    per = max(1, int(rate * step))
    if len(chunk) < per:
        return 1.0
    worst = 1.0
    for start in range(0, len(chunk) - per, per):
        peak = 0
        for s in chunk[start:start + per]:
            a = -s if s < 0 else s
            if a > peak:
                peak = a
        worst = min(worst, peak / 32768.0)
    return worst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("wav")
    ap.add_argument("--window", type=float, default=0.5, help="level window in seconds")
    ap.add_argument("--skip", type=float, default=0.0, help="ignore the first N seconds")
    ap.add_argument("--quiet-below", type=float, default=None,
                    help="peak below this counts as a quiet window (0..1)")
    ap.add_argument("--max-quiet-run", type=int, default=1,
                    help="how many CONSECUTIVE quiet windows are tolerable; 1 allows a musical "
                         "rest, which real music really does contain")
    ap.add_argument("--seams", action="store_true", help="scan for hard cuts between takes")
    ap.add_argument("--seam-factor", type=float, default=8.0,
                    help="flag a jump this many times the median (default 8)")
    ap.add_argument("--seam-top", type=int, default=10, help="how many jumps to list")
    ap.add_argument("--seam-floor", type=float, default=None,
                    help="ignore steps quieter than this in absolute terms (default: 15%% of the "
                         "loudest step, min 0.05) — a click has to be loud, not just sudden")
    ap.add_argument("--at", type=str, default="",
                    help="comma-separated seconds to inspect as transitions")
    ap.add_argument("--at-span", type=float, default=0.5, help="seconds either side of --at")
    ap.add_argument("--no-profile", action="store_true", help="skip the per-window table")
    args = ap.parse_args()

    samples, rate = read_mono(args.wav)
    if not samples:
        sys.exit("no audio in %s" % args.wav)
    rows = [r for r in window_stats(samples, rate, args.window) if r[0] >= args.skip]
    if not rows:
        sys.exit("no audio windows read from %s" % args.wav)

    print("file        %s" % args.wav)
    print("length      %.2fs @ %dHz" % (len(samples) / rate, rate))
    print("windows     %d x %.2fs (skipped first %.2fs)" % (len(rows), args.window, args.skip))
    print("peak        %.4f" % max(r[1] for r in rows))
    print("mean rms    %.4f" % (sum(r[2] for r in rows) / len(rows)))
    print("silent      %d window(s) below %.5f" % (len([r for r in rows if r[1] < SILENCE]), SILENCE))

    if not args.no_profile:
        print()
        print("t(s)    peak    rms")
        for t, peak, rms in rows:
            print("%6.2f  %.4f  %.4f  %s" % (t, peak, rms, "#" * int(peak * 40)))

    ok = True
    if args.quiet_below is not None:
        ok &= report_gaps(rows, args.quiet_below, args.max_quiet_run, args.window)
    if args.seams:
        # A seam is reported, not failed on: the engine may restart a sound by design, so some
        # step is expected. The number is what tells you whether it got worse.
        report_seams(samples, rate, args.seam_factor, args.seam_top, args.seam_floor)
    if args.at:
        times = [float(x) for x in args.at.split(",") if x.strip()]
        ok &= report_transitions(samples, rate, times, args.at_span)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Build proof/<name>/index.html from what tools/verify.sh captured.

One self-contained page (video and images embedded as data: URIs, no external files) so it can
be published as a claude.ai Artifact, sent as a file, or opened locally — identically.

    python3 tools/proof_page.py proof/<name>
"""
import base64, html, json, os, re, sys

d = sys.argv[1]
m = json.load(open(os.path.join(d, "manifest.json")))
esc = html.escape


def b64(path, mime):
    p = os.path.join(d, path)
    if not os.path.exists(p):
        return None
    return "data:%s;base64,%s" % (mime, base64.b64encode(open(p, "rb").read()).decode())


def read(path):
    p = os.path.join(d, path)
    return open(p, errors="replace").read() if os.path.exists(p) else ""


ANSI = re.compile(r"\x1b\[[0-9;]*m")


def chip(state):
    label = {"pass": "Pass", "fail": "Fail", "skip": "Not run", "warn": "Check"}[state]
    return '<span class="chip %s">%s</span>' % (state, label)


checks = [l for l in read("run.log").splitlines() if l.startswith("VERIFY PASS") or l.startswith("VERIFY FAIL")]
steps = [l[len("AUTOPLAY "):] for l in read("run.log").splitlines() if l.startswith("AUTOPLAY ")]
touch = [l for l in read("touch.txt").splitlines() if l.startswith("TOUCH_PROBE")]
audio = ANSI.sub("", read("audio.txt")).strip()
tests = ANSI.sub("", read("tests.txt")).strip()
tests_tail = "\n".join(l for l in tests.splitlines() if l.strip())[-2500:]

rows = []
for key, title in [("tests", "Unit tests"), ("checks", "Gameplay checks"), ("touch", "Touch reachability"), ("audio", "Audio")]:
    s = m["results"].get(key, "skip")
    rows.append('<div class="row"><span>%s</span>%s<span class="note">%s</span></div>'
                % (title, chip(s), esc(m.get("notes", {}).get(key, ""))))

video = b64("clip.mp4", "video/mp4")
sheet = b64("sheet.png", "image/png")
overall = m["overall"]

check_items = "".join(
    '<li class="%s"><span class="mark">%s</span>%s</li>' % (
        "ok" if l.startswith("VERIFY PASS") else "bad", "✓" if l.startswith("VERIFY PASS") else "✗",
        esc(l.split(" ", 2)[2] if len(l.split(" ", 2)) > 2 else l)) for l in checks
) or '<li class="none">This capture made no assertions. A demo that only records proves less than one that checks.</li>'

touch_rows = ""
for l in touch:
    mm = re.match(r"TOUCH_PROBE (ok|DEAD|off|moved|small)\s+(.*?)\s{2,}(.*)$", l)
    if mm:
        touch_rows += '<tr><td><span class="v %s">%s</span></td><td>%s</td><td class="mono">%s</td></tr>' % (
            mm.group(1).lower(), mm.group(1), esc(mm.group(2)), esc(mm.group(3)))
    elif "RESULT" in l or "scene=" in l:
        touch_rows += '<tr class="sum"><td colspan="3" class="mono">%s</td></tr>' % esc(l.replace("TOUCH_PROBE ", ""))

title = m.get("title") or m["name"]
page = """<title>%(title)s proof</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&family=Inter:wght@400;600&family=JetBrains+Mono:wght@400&display=swap">
<style>
/* Layout: one reading column — verdict, then the evidence in the order a reviewer checks it. */
:root {
  --bg: #f4f6fb; --panel: #ffffff; --fg: #141a2e; --dim: #5b6480; --line: #dde2ee;
  --accent: #2f6fe4; --pass: #138a4b; --pass-bg: #e3f5ea; --fail: #c0362c; --fail-bg: #fbe6e4;
  --warn: #9a6400; --warn-bg: #fbf0d9; --skip-bg: #eceff5;
  --display: "Space Grotesk", ui-sans-serif, system-ui, sans-serif;
  --body: "Inter", ui-sans-serif, system-ui, sans-serif;
  --mono: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #0d1222; --panel: #151c31; --fg: #e8ecf7; --dim: #98a2bf; --line: #27304a;
  --accent: #6c9cff; --pass: #4cd38a; --pass-bg: #12301f; --fail: #ff7a6e; --fail-bg: #3a1714;
  --warn: #f0be5a; --warn-bg: #33270f; --skip-bg: #1e2640; color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #0d1222; --panel: #151c31; --fg: #e8ecf7; --dim: #98a2bf; --line: #27304a;
  --accent: #6c9cff; --pass: #4cd38a; --pass-bg: #12301f; --fail: #ff7a6e; --fail-bg: #3a1714;
  --warn: #f0be5a; --warn-bg: #33270f; --skip-bg: #1e2640; color-scheme: dark }
body { background: var(--bg); color: var(--fg); font: 15px/1.55 var(--body); }
main { max-width: 980px; margin: 0 auto; padding-block: 28px 64px;
  padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px));
  display: grid; gap: 22px; }
header { display: grid; gap: 6px; }
.eyebrow { font: 600 12px var(--body); letter-spacing: .08em; text-transform: uppercase; color: var(--dim); }
h1 { font: 700 clamp(26px, 5vw, 38px)/1.1 var(--display); margin: 0; text-wrap: balance; }
h2 { font: 600 18px var(--display); margin: 0 0 10px; }
.meta { color: var(--dim); font: 13px var(--mono); display: flex; flex-wrap: wrap; gap: 4px 16px; }
.verdict { display: inline-flex; align-items: center; gap: 10px; font: 700 15px var(--display); padding: 6px 14px;
  border-radius: 999px; width: fit-content; }
.verdict.pass { background: var(--pass-bg); color: var(--pass); } .verdict.fail { background: var(--fail-bg); color: var(--fail); }
section { background: var(--panel); border: 1px solid var(--line); border-radius: 14px; padding: 18px; min-width: 0; }
.summary { display: grid; gap: 2px; }
.row { display: grid; grid-template-columns: 170px 80px 1fr; gap: 12px; align-items: center; padding: 8px 0; border-bottom: 1px solid var(--line); }
.row:last-child { border-bottom: 0; }
.note { color: var(--dim); font-size: 13px; min-width: 0; }
.chip { font: 600 12px var(--body); padding: 2px 10px; border-radius: 999px; text-align: center; }
.chip.pass { background: var(--pass-bg); color: var(--pass); } .chip.fail { background: var(--fail-bg); color: var(--fail); }
.chip.warn { background: var(--warn-bg); color: var(--warn); } .chip.skip { background: var(--skip-bg); color: var(--dim); }
video, .sheet { width: 100%%; max-width: 100%%; border-radius: 10px; background: #000; display: block; }
.sheet { background: transparent; }
.cap { color: var(--dim); font-size: 13px; margin-top: 8px; }
ul.checks { list-style: none; margin: 0; padding: 0; display: grid; gap: 6px; }
ul.checks li { display: flex; gap: 10px; align-items: baseline; }
.mark { font-weight: 700; width: 1em; } li.ok .mark { color: var(--pass); } li.bad .mark { color: var(--fail); }
li.bad { color: var(--fail); } li.none { color: var(--dim); }
.scroll { overflow-x: auto; }
table { border-collapse: collapse; width: 100%%; font-size: 14px; }
td { padding: 5px 8px; border-bottom: 1px solid var(--line); vertical-align: top; }
tr.sum td { color: var(--dim); }
.v { font: 600 12px var(--mono); padding: 1px 7px; border-radius: 6px; }
.v.ok { background: var(--pass-bg); color: var(--pass); } .v.dead { background: var(--fail-bg); color: var(--fail); }
.v.off, .v.moved { background: var(--skip-bg); color: var(--dim); } .v.small { background: var(--warn-bg); color: var(--warn); }
.mono, pre { font: 12.5px/1.5 var(--mono); }
pre { margin: 0; white-space: pre-wrap; word-break: break-word; color: var(--fg); }
details summary { cursor: pointer; color: var(--accent); font-weight: 600; }
details[open] summary { margin-bottom: 10px; }
summary:focus-visible, a:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
@media (max-width: 560px) { .row { grid-template-columns: 1fr auto; } .row .note { grid-column: 1 / -1; } }
</style>
<main>
<header>
  <span class="eyebrow">Verification proof</span>
  <h1>%(title)s</h1>
  <span class="verdict %(ov)s">%(ovtext)s</span>
  <div class="meta"><span>%(when)s</span><span>commit %(commit)s</span><span>%(scene)s</span>
  <span>%(frames)s frames @ 30 fps · %(res)s · %(renderer)s</span></div>
</header>
<section class="summary">%(rows)s</section>
%(video)s
%(sheet)s
<section><h2>What the run checked</h2><ul class="checks">%(checks)s</ul>%(steps)s</section>
%(touch)s
%(audio)s
<section><h2>Unit tests</h2><details><summary>Show test output</summary><pre>%(tests)s</pre></details></section>
</main>
""" % {
    "title": esc(title), "ov": overall, "ovtext": "All checks passed" if overall == "pass" else "Something failed — see below",
    "when": esc(m["when"]), "commit": esc(m["commit"]), "scene": esc(m["scene"]), "frames": m["frames"],
    "res": esc(m["size"]), "renderer": esc(m["renderer"]), "rows": "".join(rows),
    "video": ('<section><h2>Gameplay capture</h2><video controls playsinline preload="metadata" src="%s"></video>'
              '<p class="cap">Recorded by the game itself (Movie Maker) on the shipping renderer, with its real audio track. '
              'White rings mark simulated taps.</p></section>' % video) if video else "",
    "sheet": ('<section><h2>Contact sheet</h2><img class="sheet" alt="Ten evenly spaced frames from the capture" src="%s">'
              '<p class="cap">Ten moments, left to right, top to bottom.</p></section>' % sheet) if sheet else "",
    "checks": check_items,
    "steps": ('<details style="margin-top:12px"><summary>Input script (%d steps, game time)</summary><pre>%s</pre></details>'
              % (len(steps), esc("\n".join(steps)))) if steps else "",
    "touch": ('<section><h2>Touch reachability</h2><div class="scroll"><table>%s</table></div>'
              '<p class="cap">Every visible button tapped at its centre with a real touch event, through every layer the game draws.</p></section>'
              % touch_rows) if touch_rows else "",
    "audio": ('<section><h2>Audio profile</h2><details><summary>Show levels and gaps</summary><pre>%s</pre></details></section>'
              % esc(audio)) if audio else "",
    "tests": esc(tests_tail or "Not run for this proof."),
}
open(os.path.join(d, "index.html"), "w").write(page)
print("wrote %s (%.1f MB)" % (os.path.join(d, "index.html"), os.path.getsize(os.path.join(d, "index.html")) / 1e6))

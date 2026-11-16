"""Animates the story's paintings on a Google Colab GPU, with Google's `colab` command-line tool (signed in as the owner).

    python tools/video/animate.py run 1,2 [--gpu A100] [--area 884736] [--steps 40] [--seed 0] [--keep]
                                          [--fast] [--suffix=-fast]   # the Lightning add-on: 4 steps, about 4 minutes a clip
    python tools/video/animate.py watchdog 150      # releases the machine after that many minutes, whatever happens
    python tools/video/animate.py status
    python tools/video/animate.py stop

`run` starts a machine (or uses the one that is up), uploads the paintings (tools/art/story_source_<n>.*) and
animate_worker.py, follows the worker's log and downloads each finished clip to build/social/anim/story-<n>.mp4 (a clip
that is already there is not made again: delete it to redo it). It releases the machine at the end, unless --keep.
A machine that is up uses the owner's compute units whether it works or not (an A100: 8.88 an hour in November 2026), so start a
`watchdog` beside every run and look at `status` afterwards.
What moves in each painting is PROMPTS below: gentle things that can go on for ever (rocking, bobbing, blinking),
because a clip is played forwards and then backwards under a whole page of the story.
"""
import argparse
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "build", "social", "anim")
SESSION = "story"
ENV = dict(os.environ, PYTHONUTF8="1", PYTHONIOENCODING="utf-8")
LOOK = "A bright, glossy 3D cartoon film. "
END = " Smooth, gentle, continuous motion. The camera does not move."
PROMPTS = {
    1: "The chubby fisherman in a straw hat laughs and wiggles the tiny silver fish he holds up; his moustache and shoulders bounce as he "
       "chuckles. The wooden rowboat rocks gently on the green river and ripples spread around it. The red and white bobber swings on its "
       "line. Sunbeams shimmer through the leaves and the waterfall flows. Under the boat the huge red whale drifts slowly beneath the "
       "surface, its big eye looks up at the red lunchbox and blinks.",
    2: "The fisherman laughs and pulls on his bent fishing rod; the grilled fish on the line swings and steams, drops fall from it and the "
       "splash below ripples. The rowboat rocks gently. The volcano glows, its lava flows slowly, smoke and steam rise from the sea. "
       "Under the water a big eye blinks.",
    3: "At a sunny harbour fish stall the bearded merchant laughs and holds up the treasure map, which flutters a little in the breeze. The "
       "fisherman in the straw hat grins, bounces with excitement and waves the fish he pays with. Behind them the gigantic red whale "
       "leaps over the sea with a big splash and dolphins jump from the waves. The striped awning sways and the lantern swings.",
    4: "The small wooden rowboat floats on a sea of pink and golden clouds at sunset, bobbing gently. The fisherman in a straw hat sniffles "
       "and smiles, his long red scarf flutters in the wind and a little puff of breath leaves his nose. The clouds roll slowly like "
       "waves, waterfalls pour from the floating islands, the lantern flickers, the bobber bobs. A huge red fin glides slowly through "
       "the clouds.",
    5: "In deep starry space the fisherman floats in his rowboat wearing a round glass helmet, laughing and kicking his feet. The happy pink "
       "worms wriggle and float out of the tin, the fishing line drifts in slow curls, the lantern glows and sways. Stars twinkle and "
       "small rocks tumble slowly. The gigantic red whale swims slowly past the big moon, waving its tail, leaving a sparkling trail of "
       "stars. Weightless slow motion.",
    6: "On a wooden dock by a glowing green alien sea, four small round aliens with many eyes giggle, blink and point down into the water, "
       "bouncing a little. The fisherman kneels beside them, holds a swaying lantern and peers down with wide eyes. The glowing "
       "mushrooms pulse softly, the water ripples and glitters, bubbles rise. Deep under the dock an enormous green eye looks left and "
       "right and blinks slowly.",
    7: "On the dark sea floor the fisherman in an old brass diving helmet sits in his rowboat, smiling, threading a wriggling worm onto his "
       "hook; bubbles rise from his helmet. His lantern flickers warmly. Behind him the gigantic red whale sleeps on a mountain of yellow "
       "rubber ducks, breathing slowly so that its body rises and falls; its half-open eye looks at the fisherman and slowly closes. "
       "Jellyfish drift and pulse in the dark water, small bubbles float up, crystals glimmer.",
}
SPECS = """
import subprocess
for c in ("nvidia-smi --query-gpu=name,memory.total --format=csv,noheader", "free -g | head -2", "df -h /content | tail -1",
          "python -c 'import torch, diffusers, transformers; print(torch.__version__, diffusers.__version__, transformers.__version__)'"):
    r = subprocess.run(c, shell=True, capture_output=True, text=True)
    print((r.stdout or r.stderr).strip()[-300:])
"""
TAIL = """
import os, pathlib
p = pathlib.Path('/content/worker.log')
t = p.read_text() if p.exists() else '(no log yet)'
print('\\n'.join(t.splitlines()[-5:]))
if 'WORKER FAILED' in t or not p.exists():
    for f in ('/content/worker.out', '/content/pip.out'):
        if os.path.exists(f): print(f, pathlib.Path(f).read_text()[-700:])
print('STATE:', 'FAILED' if 'WORKER FAILED' in t else ('DONE' if 'ALL DONE' in t else 'WORKING'))
print('FILES:', ' '.join(sorted(f for f in os.listdir('/content/out') if f.endswith('.mp4') and '.part' not in f)) if os.path.isdir('/content/out') else '')
"""
START = """
import os, subprocess
running = 'animate_worker' in subprocess.run('ps aux', shell=True, capture_output=True, text=True).stdout
if not running:
    if os.path.exists('/content/worker.log'): os.remove('/content/worker.log')
    # (Colab's torchao is too old for the add-on loader, which gives up when it finds one; nothing here needs it)
    subprocess.Popen("cd /content && nohup sh -c 'pip install -q ftfy > /content/pip.out 2>&1; pip uninstall -y -q torchao >> /content/pip.out 2>&1; "
                     "python /content/animate_worker.py' >> /content/worker.out 2>&1 &", shell=True)
print('worker already running' if running else 'worker started')
"""


def colab(*args, check=True, timeout=600):
    proc = subprocess.Popen(["colab", *args], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, text=True,
                            errors="replace", env=ENV)
    try:
        out, _ = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)      # (the tool sometimes hangs)
        raise
    if check and proc.returncode:
        raise RuntimeError("colab %s failed: %s" % (" ".join(args), out[-800:]))
    return out


def retry(fn, tries=5):
    for attempt in range(tries):
        try:
            return fn()
        except (RuntimeError, subprocess.TimeoutExpired):
            if attempt == tries - 1:
                raise
            time.sleep(5)


def remote(code, timeout=75):
    """run a little Python on the machine and return what it printed"""
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False, encoding="utf-8") as fh:
        fh.write(code)
    try:
        return retry(lambda: colab("exec", "-s", SESSION, "-f", fh.name, timeout=timeout))
    finally:
        os.unlink(fh.name)


def has_session():
    return re.search(r"\b%s\b" % SESSION, colab("sessions", check=False, timeout=90)) is not None


def source(n):
    found = [p for ext in ("png", "webp", "jpg", "jpeg") for p in glob.glob(os.path.join(ROOT, "tools", "art", "story_source_%d.%s" % (n, ext)))]
    return found[0] if found else None


def stop():
    print(colab("stop", "-s", SESSION, check=False, timeout=120)[-300:].strip(), flush=True)
    print(colab("usage", check=False, timeout=90)[-200:].strip(), flush=True)


def run(pages, gpu, area, steps, seed, release, fast=False, suffix=""):
    os.makedirs(OUT, exist_ok=True)
    todo = [n for n in pages if source(n) and not os.path.exists(os.path.join(OUT, "story-%d%s.mp4" % (n, suffix)))]
    if not todo:
        print("nothing to do: those clips are in build/social/anim already")
        return
    if has_session():
        print('using the "%s" machine that is up' % SESSION, flush=True)
    else:
        print("starting a %s machine" % gpu, flush=True)
        print(colab("new", "-s", SESSION, "--gpu", gpu, "--high-mem", timeout=400)[-300:].strip(), flush=True)
    print(remote("import os\nfor d in ('/content/in', '/content/out'): os.makedirs(d, exist_ok=True)\n" + SPECS).strip(), flush=True)
    jobs = [{"name": "story-%d%s" % (n, suffix), "image": os.path.basename(source(n)), "prompt": LOOK + PROMPTS[n] + END, "area": area,
             "steps": 4 if fast else steps, "guidance": 1.0 if fast else 3.5, "lightning": fast, "seed": seed} for n in todo]
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as fh:
        json.dump(jobs, fh)
    ups = [(fh.name, "/content/jobs.json"), (os.path.join(HERE, "animate_worker.py"), "/content/animate_worker.py")]
    ups += [(source(n), "/content/in/" + os.path.basename(source(n))) for n in todo]
    for local, there in ups:
        retry(lambda: colab("upload", "-s", SESSION, local, there, timeout=180))
    os.unlink(fh.name)
    print(remote(START).strip(), flush=True)
    t0, said, lost = time.time(), "", 0
    while True:
        time.sleep(45)
        try:
            text = remote(TAIL)
            log, files = text.split("FILES:")[0].strip(), text.split("FILES:")[-1]
            for name in re.findall(r"story-\d+[\w-]*\.mp4", files):
                local = os.path.join(OUT, name)
                if not os.path.exists(local):
                    retry(lambda: colab("download", "-s", SESSION, "/content/out/" + name, local + ".part", timeout=400))
                    os.replace(local + ".part", local)
                    print("[%5.1f min] downloaded %s" % ((time.time() - t0) / 60, name), flush=True)
            last = log.splitlines()[-1] if log else ""
            if last != said:
                said = last
                print("[%5.1f min] %s" % ((time.time() - t0) / 60, last[:150]), flush=True)
            if "STATE: FAILED" in text:
                print(text[-2500:], flush=True)
                break
            if all(os.path.exists(os.path.join(OUT, "story-%d%s.mp4" % (n, suffix))) for n in todo):   # (a clip shows only when whole)
                print("ALL DONE", flush=True)
                break
            lost = 0
        except (RuntimeError, subprocess.TimeoutExpired) as exc:
            print("cannot reach the machine: %s" % str(exc)[-200:], flush=True)
            lost = lost + 1 if "not found" in str(exc) else 0
            if lost >= 3:
                print("the machine is gone", flush=True)
                return
    if release:
        stop()


def watchdog(minutes):
    """whatever else happens, the machine is released when the minutes are up"""
    end, seen, misses = time.time() + minutes * 60, False, 0
    while time.time() < end:
        time.sleep(120)
        try:
            up = has_session()
        except (RuntimeError, subprocess.TimeoutExpired):
            continue
        misses = 0 if up else misses + 1
        if seen and misses >= 3:                  # (the tool sometimes answers with nothing: one miss proves little)
            print("the machine is gone already")
            return
        seen = seen or up
    print("time is up: releasing the machine", flush=True)
    stop()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")       # (the machine's logs have progress bars in them)
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["run", "watchdog", "status", "stop"])
    ap.add_argument("what", nargs="?", default="")
    ap.add_argument("--gpu", default="A100")
    ap.add_argument("--area", type=int, default=1152 * 768)
    ap.add_argument("--steps", type=int, default=40)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--keep", action="store_true")         # keep the machine when the run is done (to run voice.py on it, say)
    ap.add_argument("--fast", action="store_true")
    ap.add_argument("--suffix", default="")
    a = ap.parse_args()
    if a.command == "run":
        run([int(x) for x in a.what.split(",") if x] or sorted(PROMPTS), a.gpu, a.area, a.steps, a.seed, not a.keep, a.fast, a.suffix)
    elif a.command == "watchdog":
        watchdog(float(a.what or 120))
    elif a.command == "stop":
        stop()
    else:
        print(colab("sessions", check=False, timeout=90)[-500:].strip())
        print(colab("usage", check=False, timeout=90)[-300:].strip())
        if has_session():
            print(remote(TAIL).strip())

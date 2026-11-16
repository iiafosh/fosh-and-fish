"""The story videos' narrator: every sentence of the story spoken by the open Kokoro-82M voice model (Apache 2.0), on a
Google Colab machine (the owner's account), into build/social/voice/<voice>/ for story.py --voice=<voice>.

    python tools/video/voice.py [af_heart,bm_george]     # the voices (default: VOICES); sentences already made are skipped

It uses the machine animate.py has up (the voice runs on its processor, beside the animation on the graphics card), or
starts a machine without a graphics card and releases it again at the end. Kokoro needs Python 3.12 and Colab has 3.13,
so the first time on a machine it gets its own small Python there (/content/kenv, made with uv: about two minutes).
Voices: af_ and am_ are American English, bf_ and bm_ British (Kokoro's VOICES.md lists them all).
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import animate as a  # noqa: E402
from story import VOICE_DIR, VOICE_SPEED, cards_of, chapters, said, voice_file  # noqa: E402

VOICES = ["af_heart", "bm_george", "am_michael"]
SETUP = r'''
import subprocess
cmd = """cd /content && ( [ -x /content/kenv/bin/python ] || ( pip install -q uv && uv venv -q --seed -p 3.12 /content/kenv
  && uv pip install -q --python /content/kenv/bin/python torch --index-url https://download.pytorch.org/whl/cpu
  && uv pip install -q --python /content/kenv/bin/python "kokoro>=0.9.4" soundfile ) ) > /content/voice_setup.out 2>&1
  ; apt-get -qq -y install espeak-ng >> /content/voice_setup.out 2>&1
  ; /content/kenv/bin/python -c "import kokoro; print('KOKORO', kokoro.__version__)" 2>&1 | tail -3"""
r = subprocess.run(cmd.replace(chr(10), " "), shell=True, capture_output=True, text=True)
print(r.stdout[-400:])
if 'KOKORO' not in r.stdout:
    print(open('/content/voice_setup.out').read()[-1200:])
'''
START = r'''
import os, subprocess
for f in ('/content/voice.log', '/content/voice.zip'):
    if os.path.exists(f): os.remove(f)
subprocess.Popen('cd /content && nohup /content/kenv/bin/python /content/voice_worker.py >> /content/voice.out 2>&1 &', shell=True)
print('voice worker started')
'''
TAIL = r'''
import pathlib
p = pathlib.Path('/content/voice.log')
t = p.read_text() if p.exists() else ''
print(t.strip().splitlines()[-1] if t.strip() else '(no log yet)')
if 'VOICE FAILED' in t:
    q = pathlib.Path('/content/voice.out')
    print(q.read_text()[-800:] if q.exists() else '')
print('STATE:', 'FAILED' if 'VOICE FAILED' in t else ('DONE' if 'VOICE DONE' in t else 'WORKING'))
'''


def main(voices):
    chs = chapters()
    texts = sorted({t for n, ch in enumerate(chs, 1) for t, _big in cards_of(ch, n, len(chs))})
    jobs = [{"out": os.path.relpath(voice_file(v, t), VOICE_DIR).replace(os.sep, "/"), "text": said(t), "voice": v, "speed": VOICE_SPEED}
            for v in voices for t in texts if not os.path.exists(voice_file(v, t))]
    if not jobs:
        print("every sentence is spoken already, in", ", ".join(voices))
        return
    print("%d sentences to speak (%s)" % (len(jobs), ", ".join(voices)), flush=True)
    started = not a.has_session()
    if started:
        print("starting a machine without a graphics card", flush=True)
        print(a.colab("new", "-s", a.SESSION, timeout=400)[-200:].strip(), flush=True)
    try:
        print(a.remote(SETUP, timeout=900).strip(), flush=True)
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as fh:
            json.dump(jobs, fh)
        for local, there in ((fh.name, "/content/voice_jobs.json"), (os.path.join(a.HERE, "voice_worker.py"), "/content/voice_worker.py")):
            a.retry(lambda: a.colab("upload", "-s", a.SESSION, local, there, timeout=180))
        os.unlink(fh.name)
        print(a.remote(START).strip(), flush=True)
        t0, said_last = time.time(), ""
        while True:
            time.sleep(20)
            try:
                text = a.remote(TAIL)
            except (RuntimeError, subprocess.TimeoutExpired) as exc:
                print("cannot reach the machine: %s" % str(exc)[-150:], flush=True)
                continue
            last = text.split("STATE:")[0].strip()
            if last != said_last:
                said_last = last
                print("[%4.1f min] %s" % ((time.time() - t0) / 60, last[-300:]), flush=True)
            if "STATE: FAILED" in text:
                sys.exit("the voice worker failed")
            if "STATE: DONE" in text:
                break
        zpath = os.path.join(VOICE_DIR, "_voice.zip")
        os.makedirs(VOICE_DIR, exist_ok=True)
        a.retry(lambda: a.colab("download", "-s", a.SESSION, "/content/voice.zip", zpath, timeout=400))
        with zipfile.ZipFile(zpath) as z:
            names = [m for m in z.namelist() if re.fullmatch(r"[a-z]{2}_[a-z]+/[0-9a-f]{12}\.wav", m)]   # (only what it should hold)
            for m in names:
                z.extract(m, VOICE_DIR)
        os.remove(zpath)
        print("%d sentences in build/social/voice" % len(names), flush=True)
    finally:
        if started:
            a.stop()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    main([v for v in (sys.argv[1].split(",") if len(sys.argv) > 1 else VOICES) if v])

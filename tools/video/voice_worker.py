"""Runs on the Colab machine, in its own Python 3.12 (/content/kenv): tools/video/voice.py uploads it and starts it there.

Reads /content/voice_jobs.json, a list of {"out", "text", "voice", "speed"}, and speaks each line with the open
Kokoro-82M voice model (Apache 2.0, about 330 MB, downloaded to the machine) on the machine's processor:
/content/voice/<out>, a 24 kHz mono 16-bit WAV. Then /content/voice.zip holds them all. A line for every few sentences
goes to /content/voice.log, which ends with VOICE DONE or VOICE FAILED.
"""
import json
import os
import time
import traceback
import zipfile

LOG = "/content/voice.log"
OUT = "/content/voice"


def log(msg):
    with open(LOG, "a") as f:
        f.write("%s %s\n" % (time.strftime("%H:%M:%S"), msg))


def main():
    import numpy as np
    import soundfile as sf
    from kokoro import KPipeline
    jobs = json.load(open("/content/voice_jobs.json"))
    log("%d lines to speak" % len(jobs))
    pipes, t0 = {}, time.time()
    for k, job in enumerate(jobs):
        lang = job["voice"][0]                       # af_/am_ American English, bf_/bm_ British
        if lang not in pipes:
            try:
                pipes[lang] = KPipeline(lang_code=lang, repo_id="hexgrad/Kokoro-82M", device="cpu")
            except TypeError:
                pipes[lang] = KPipeline(lang_code=lang, repo_id="hexgrad/Kokoro-82M")
        parts = []
        for _gs, _ps, audio in pipes[lang](job["text"], voice=job["voice"], speed=float(job.get("speed", 1.0)), split_pattern=None):
            if audio is not None:
                parts.append(audio.detach().cpu().numpy() if hasattr(audio, "detach") else np.asarray(audio))
        out = os.path.join(OUT, job["out"])
        os.makedirs(os.path.dirname(out), exist_ok=True)
        sf.write(out, np.concatenate(parts).astype(np.float32), 24000, subtype="PCM_16")
        if k % 15 == 0:
            log("%d/%d lines, %.0f s" % (k + 1, len(jobs), time.time() - t0))
    with zipfile.ZipFile("/content/voice.zip", "w", zipfile.ZIP_STORED) as z:
        for job in jobs:
            z.write(os.path.join(OUT, job["out"]), job["out"])
    log("VOICE DONE %d lines in %.0f s" % (len(jobs), time.time() - t0))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        log("VOICE FAILED " + traceback.format_exc()[-1500:].replace(chr(10), " | "))

"""Prepare build/boom for the KABOOM video (tools/blender/boom_video.py, tools/video/edit_boom.py):
static Fredoka instances for Blender (it can't pick a weight of the variable font; needs fontTools) and
the gameplay clips (JPEG sequences) cut from a --reelyt recording.

    python tools/mock_supabase.py --port 54321          (the recording signs up on this local test server)
    godot --path . --write-movie build/boom/footage/reel.avi --fixed-fps 30 -- --reelyt
          --backend-url=http://127.0.0.1:54321 --backend-key=test > build/boom/footage/reel_log.txt
          (with a 1920x1080 window: a temporary override.cfg with window_width/height_override)
    python tools/video/boom_prep.py
"""
import os
import re
import shutil
import subprocess
import sys

import imageio_ffmpeg

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WORK = os.path.join(ROOT, "build", "boom")
REEL = os.path.join(WORK, "footage", "reel.avi")
LOG = os.path.join(WORK, "footage", "reel_log.txt")
CLIPS = os.path.join(WORK, "clips")
FF = imageio_ffmpeg.get_ffmpeg_exe()
FRAME_OFFSET = -2                 # MARK frames (frames drawn) run a little ahead of the movie writer
PHONE = (720, 40, 480, 1000)      # the in-game phone's screen in the 1920x1080 recording (x, y, w, h)


def fonts():
    src = os.path.join(ROOT, "assets", "third_party", "fonts", "Fredoka.ttf")
    for name, loc in [("Fredoka-Logo.ttf", {"wght": 700, "wdth": 104}),     # make_brand.py's logo letters
                      ("Fredoka-Bold.ttf", {"wght": 700, "wdth": 100}),
                      ("Fredoka-Semi.ttf", {"wght": 600, "wdth": 100})]:
        out = os.path.join(WORK, name)
        if not os.path.exists(out):
            from fontTools.ttLib import TTFont                 # pip install fonttools skia-pathops
            from fontTools.varLib import instancer
            # REMOVE: merge overlapping contours (the f's crossbar over its stem): Blender fills even-odd,
            # so an overlap would turn into a hole
            instancer.instantiateVariableFont(TTFont(src), loc, overlap=instancer.OverlapMode.REMOVE).save(out)
            print("font", name)


def marks():
    m = {}
    for line in open(LOG, encoding="utf-8", errors="ignore"):
        g = re.match(r"MARK (\d+) (\S+)", line)
        if g:
            m.setdefault(g.group(2), []).append(int(g.group(1)) + FRAME_OFFSET)
    return m


def cut(name, ranges, crop=None, size=(1920, 1080)):
    """ranges: [(first movie frame, count, step)] -> clips/name/0001.jpg ..."""
    out = os.path.join(CLIPS, name)
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    tmp = os.path.join(out, "_part")
    n = 0
    for a, count, step in ranges:
        os.makedirs(tmp, exist_ok=True)
        sel = "select='between(n\\,%d\\,%d)*not(mod(n-%d\\,%d))'" % (a, a + count * step - 1, a, step)
        vf = [sel]
        if crop:
            vf.append("crop=%d:%d:%d:%d" % (crop[2], crop[3], crop[0], crop[1]))
        vf.append("scale=%d:%d:flags=lanczos" % size)
        subprocess.run([FF, "-v", "error", "-i", REEL, "-vf", ",".join(vf), "-vsync", "0", "-q:v", "2",
                        os.path.join(tmp, "%04d.jpg")], check=True)
        for f in sorted(os.listdir(tmp)):
            n += 1
            os.replace(os.path.join(tmp, f), os.path.join(out, "%04d.jpg" % n))
        shutil.rmtree(tmp)
    print("clip", name, n, "frames")
    return n


def main():
    os.makedirs(WORK, exist_ok=True)
    fonts()
    if not os.path.exists(REEL):
        sys.exit("no recording at " + REEL + " (see the docstring)")
    m = marks()
    cut("reel", [(m["mg_win"][0] - 40, 60, 1)])                         # Reel it in! ... PERFECT!
    cut("boats", [(m["boat_" + b][0] + 4, 15, 1) for b in ("Gold_Boat", "Sky_Cruiser", "Space_Shuttle", "Alien_Raft")])
    cut("fishtok", [(m["phone"][0], 60, 1)], crop=PHONE, size=(480, 1000))
    cut("board", [(m["acct_board"][0] - 4, 60, 1)])
    cut("hero", [(m["hero"][1], 45, 1)])


if __name__ == "__main__":
    main()

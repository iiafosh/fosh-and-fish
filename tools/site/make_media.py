"""Media for the website (site/): a short silent gameplay loop, feature screenshots and web-sized brand art.

    python tools/site/make_media.py WORK

WORK holds reel.avi + reel_log.txt from the clean --reelyt recording (see tools/video/edit_yt.py for how
to record it). Writes site/media/gameplay.mp4 (+ poster), site/img/feat-*.webp, site/img/hero.webp,
site/img/logo.png, site/img/og.jpg and the favicons.
"""
import os
import re
import subprocess
import sys

import imageio_ffmpeg
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SITE = os.path.join(ROOT, "site")
BRAND = os.path.join(ROOT, "assets", "brand")
FF = imageio_ffmpeg.get_ffmpeg_exe()
W, H, FPS = 1920, 1080, 30
SRC_SCALE = 1.5                                   # marks are logged in the 1280x720 canvas


def marks(work):
    out = {}
    for line in open(os.path.join(work, "reel_log.txt"), encoding="utf-8", errors="ignore"):
        m = re.match(r"MARK (\d+) (\S+) (-?\d+) (-?\d+) (-?\d+) (-?\d+)", line)
        if m:
            f, name, bx, by, ox, oy = m.groups()
            out.setdefault(name, []).append({"f": int(f), "boat": (int(ox) * SRC_SCALE, int(oy) * SRC_SCALE)})
    return out


def frame(work, f):
    raw = subprocess.run([FF, "-loglevel", "error", "-ss", "%.3f" % (f / FPS), "-i", os.path.join(work, "reel.avi"),
                          "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True, check=True).stdout
    return Image.frombuffer("RGB", (W, H), raw)


def crop(img, cx, cy, cw):
    ch = cw * 9 / 16
    x = min(max(cx - cw / 2, 0), W - cw)
    y = min(max(cy - ch / 2, 0), H - ch)
    return img.crop((int(x), int(y), int(x + cw), int(y + ch)))


def clip_args(start_f, cx, cy, cw, dur):
    ch = cw * 9 / 16
    x = int(min(max(cx - cw / 2, 0), W - cw))
    y = int(min(max(cy - ch / 2, 0), H - ch))
    return ["-ss", "%.3f" % (start_f / FPS), "-t", "%.2f" % dur], "crop=%d:%d:%d:%d,scale=1280:720:flags=lanczos,setsar=1,fps=30" % (int(cw), int(ch), x, y)


def main(work):
    mk = marks(work)
    os.makedirs(os.path.join(SITE, "img"), exist_ok=True)
    os.makedirs(os.path.join(SITE, "media"), exist_ok=True)
    m1 = lambda n, i=0: mk[n][i]
    boat = lambda n, i=0: mk[n][i]["boat"]
    # ---- the gameplay loop: six short shots with crossfades
    shots = [
        (m1("hero", 1)["f"] - 20, W / 2, H / 2, 1920, 2.6),
        (m1("mg_play")["f"] + 6, W / 2, H / 2 + 20, 1400, 2.6),
        (m1("dance")["f"] + 6, boat("dance")[0], boat("dance")[1] - 60, 900, 2.2),
        (m1("sail_go")["f"] + 6, W / 2, H / 2, 1920, 3.0),
        (m1("phone")["f"] + 20, W / 2, H / 2 - 20, 1300, 2.4),
        (m1("boat_Sky_Cruiser")["f"] + 6, boat("boat_Sky_Cruiser")[0], boat("boat_Sky_Cruiser")[1], 1100, 2.4),
    ]
    xf = 0.45
    cmd = [FF, "-y", "-loglevel", "error"]
    filters = []
    for i, (f, cx, cy, cw, dur) in enumerate(shots):
        a, flt = clip_args(f, cx, cy, cw, dur)
        cmd += a + ["-i", os.path.join(work, "reel.avi")]
        filters.append("[%d:v]%s[v%d]" % (i, flt, i))
    last, t = "v0", shots[0][4]
    for i in range(1, len(shots)):
        out = "x%d" % i
        filters.append("[%s][v%d]xfade=transition=fade:duration=%.2f:offset=%.2f[%s]" % (last, i, xf, t - xf, out))
        t += shots[i][4] - xf
        last = out
    mp4 = os.path.join(SITE, "media", "gameplay.mp4")
    cmd += ["-filter_complex", ";".join(filters), "-map", "[%s]" % last, "-an", "-c:v", "libx264", "-preset", "slow",
            "-crf", "30", "-pix_fmt", "yuv420p", "-movflags", "+faststart", mp4]
    subprocess.run(cmd, check=True)
    poster = frame(work, shots[0][0] + 30).resize((1280, 720), Image.LANCZOS)
    poster.save(os.path.join(SITE, "media", "gameplay.jpg"), quality=78)
    # ---- feature screenshots
    feats = {
        "minigame": (m1("mg_win")["f"] + 8, W / 2, H / 2 + 10, 1300),
        "captain": (m1("happy")["f"] + 6, boat("happy")[0], boat("happy")[1] - 70, 760),
        "sail": (m1("sail_arrive")["f"] + 20, boat("sail_arrive")[0] + 300, H / 2, 1700),
        "fishtok": (m1("phone")["f"] + 40, W / 2, H / 2 - 30, 1250),
        "online": (m1("acct_board")["f"] - 2, W / 2, H / 2, 1560),
        "boats": (m1("boat_Sky_Cruiser")["f"] + 10, boat("boat_Sky_Cruiser")[0], boat("boat_Sky_Cruiser")[1] - 20, 1000),
    }
    for name, (f, cx, cy, cw) in feats.items():
        crop(frame(work, f), cx, cy, cw).resize((960, 540), Image.LANCZOS).save(os.path.join(SITE, "img", "feat-%s.webp" % name), quality=80)
    # ---- brand art for the web
    Image.open(os.path.join(ROOT, "assets", "launcher", "launcher_bg.jpg")).save(os.path.join(SITE, "img", "hero.webp"), quality=80)
    lg = Image.open(os.path.join(BRAND, "logo.png"))
    lg.resize((640, int(lg.size[1] * 640 / lg.size[0])), Image.LANCZOS).save(os.path.join(SITE, "img", "logo.png"), optimize=True)
    Image.open(os.path.join(BRAND, "social_1280x640.png")).convert("RGB").save(os.path.join(SITE, "img", "og.jpg"), quality=85)
    for n in (64, 180, 512):
        Image.open(os.path.join(BRAND, "icon_%d.png" % n)).save(os.path.join(SITE, "img", "icon-%d.png" % n), optimize=True)
    for root, _, files in os.walk(SITE):
        for fn in files:
            if fn.endswith((".mp4", ".jpg", ".webp", ".png")):
                p = os.path.join(root, fn)
                print("%-28s %5d KB" % (os.path.relpath(p, SITE), os.path.getsize(p) // 1024))


if __name__ == "__main__":
    main(sys.argv[1])

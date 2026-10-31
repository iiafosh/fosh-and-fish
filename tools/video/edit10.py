"""fosh&fish 1.0 marketing videos, edited from the --reel10 recording. Sound effects only (no music).

  trailer   ~32 s  16x9 + 9x16   the 1.0 launch trailer (YouTube, the Google Play promo video)
  shiny     ~14 s  9x16 + 1x1    ad: "Only 3,000 exist"  (TikTok / Reels / Shorts, feeds)
  boss      ~15 s  9x16 + 1x1    ad: "Something HUGE is coming"
  events    ~14 s  9x16 + 1x1    ad: "Every 10 minutes..."
  bumper      6 s  16x9 + 9x16   a 6-second bumper ad
  plus a 1280x720 thumbnail for the trailer.

    godot --path . --fullscreen --write-movie WORK/reel.avi --fixed-fps 30 -- --reel10 > WORK/reel_log.txt
        (on a 1920x1080 screen)
    python tools/video/edit10.py WORK OUT [trailer,shiny,boss,events,bumper] [--thumb | --thumb-only]

Sound: the game's own audio from the recording, a water bed under everything, and CC0 effects
(tools/video/music.py / music_boom.py synths, Kenney Impact + Interface Sounds, rubberduck's water SFX).
"""
import math
import os
import random
import re
import subprocess
import sys
import wave

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "art"))
import make_brand as MB  # noqa: E402
import music  # noqa: E402
import music_boom as MBX  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
WORK, OUT = sys.argv[1], sys.argv[2]
FF = imageio_ffmpeg.get_ffmpeg_exe()
FPS, SR = 30, 48000
BEAT = 15                                    # the pacing unit: half a second
W, H = 1920, 1080                            # source size
SRC_SCALE = 1.5                              # marks are logged in the 1280x720 canvas
FONT = MB.FONT
WHITE, GOLD, MINT, DEEP = (255, 255, 255), (255, 204, 72), MB.MINT, MB.DEEP
RED = (239, 68, 68)

_fonts = {}


def font(size, weight=700):
    key = (size, weight)
    if key not in _fonts:
        f = ImageFont.truetype(FONT, size)
        f.set_variation_by_axes([weight, 100])
        _fonts[key] = f
    return _fonts[key]


# ------------------------------------------------------------------ marks
marks = {}
for line in open(os.path.join(WORK, "reel_log.txt"), encoding="utf-8", errors="ignore"):
    m = re.match(r"MARK (\d+) (\S+) (-?\d+) (-?\d+) (-?\d+) (-?\d+)", line)
    if m:
        f, name, bx, by, ox, oy = m.groups()
        marks.setdefault(name, []).append({"f": int(f), "bob": (int(bx) * SRC_SCALE, int(by) * SRC_SCALE),
                                           "boat": (int(ox) * SRC_SCALE, int(oy) * SRC_SCALE)})
FRAME_OFFSET = -2                            # frames_drawn runs a little ahead of the movie writer


def mk(name, i=0):
    return marks[name][min(i, len(marks[name]) - 1)]


def mid(m, k=0.5):
    (bx, by), (ox, oy) = m["bob"], m["boat"]
    return (ox + (bx - ox) * k, oy + (by - oy) * k)


C = (W * 0.5, H * 0.5)
BANNER = (W * 0.5, H * 0.3)                  # the banners, top middle
SHINY = (W * 0.5, H * 0.41)                  # the shiny card
CARD = (W * 0.86, H * 0.25)                  # the catch card, top right


# ------------------------------------------------------------------- cuts
class Cut:
    """a list of shots: source frame, length in beats, zoom from -> to, focus, caption [(word, gold)], effects:
    flash / chroma / whip on the cut, shake=px, slam="WORD", big=[(word, beat)], count=(pre, n, post),
    label="pill", hits=[frame] (a hit sound), boom (a big hit), riser (builds into the shot), game=gain"""

    def __init__(self, name, formats):
        self.name, self.formats, self.shots = name, formats, []

    def shot(self, src, beats, z0, z1, focus, caption=None, tag=None, whoosh=False, label=None, **fx):
        self.shots.append(dict(id=len(self.shots), src=src + FRAME_OFFSET, n=int(beats * BEAT), z0=z0, z1=z1, focus=focus,
                               caption=caption, tag=tag, whoosh=whoosh, label=label, fx=fx))

    def end(self, beats, cta="Play free"):
        self.shots.append(dict(id=len(self.shots), src=None, tag="end", n=int(beats * BEAT), whoosh=True, fx={"cta": cta},
                               caption=None, label=None))

    @property
    def total(self):
        return sum(s["n"] for s in self.shots)


HIT = dict(flash=True, chroma=True, shake=26, hits=[0])


def cut_trailer():
    c = Cut("trailer", ["16x9", "9x16"])
    h = mk("hero")
    c.shot(h["f"] - 4, 4, 1.25, 1.42, mid(h), caption=[("A", False), ("cozy", False), ("fishing", False), ("game", False)],
           game=0.8)
    h2 = mk("hero", 1)
    c.shot(h2["f"] + 8, 4, 1.1, 1.22, mid(h2), tag="title", shake=30, boom=True, riser=True)
    s = mk("shiny")
    c.shot(s["f"] + 6, 4, 1.3, 1.5, SHINY, caption=[("Shiny", True), ("fish", False)], flash=True, chroma=True, whoosh=True,
           sparkle=True)
    c.shot(s["f"] + 48, 4, 1.5, 1.62, SHINY, count=("", 3000, ""), caption=[("Only", False), ("3,000", True), ("of", False),
                                                                             ("each", False)], hold=True, ticks=True)
    g = mk("golden_start")
    c.shot(g["f"] + 6, 4, 1.15, 1.3, BANNER, caption=[("An", False), ("event", True), ("every", False), ("10", True),
                                                     ("minutes", False)], whip=True, whoosh=True)
    k = mk("koi")
    c.shot(k["f"] - 8, 2, 1.3, 1.42, BANNER, label="Golden Hour", whip=True, whoosh=True)
    f = mk("frenzy_cast", 1)
    c.shot(f["f"] + 4, 2, 1.3, 1.45, mid(f), label="Fish Frenzy", whip=True, whoosh=True)
    t = mk("treasure_cast", 1)
    c.shot(t["f"] + 24, 2, 1.2, 1.32, mid(t), label="Treasure Tide", whip=True, whoosh=True)
    mm = mk("meteor_cast")
    c.shot(mm["f"] - 6, 2, 1.1, 1.22, C, label="Meteor Shower", whip=True, whoosh=True)
    b = mk("boss_start")
    c.shot(b["f"] + 4, 4, 1.05, 1.22, BANNER, big=[("BOSS", 0), ("FISH!", 1)], hits=[0, 15], game=0.35, riser=True)
    bh = mk("boss_hit", 1)
    c.shot(bh["f"] + 18, 3, 1.3, 1.45, mid(bh), caption=[("Wear", False), ("it", False), ("down", True)], whip=True,
           whoosh=True)
    bm = mk("boss_mg")
    c.shot(bm["f"] - 2, 3, 1.25, 1.35, C, caption=[("Reel", True), ("it", False), ("in!", True)], whip=True, whoosh=True)
    bc = mk("boss_caught")
    c.shot(bc["f"] + 2, 4, 1.25, 1.42, BANNER, slam="CAUGHT!", boom=True, **HIT)
    sl = mk("sell")
    c.shot(sl["f"] - 2, 3, 1.15, 1.3, (W * 0.45, H * 0.55), caption=[("Cash", True), ("in", False)], whip=True, whoosh=True)
    st = mk("starfall")
    c.shot(st["f"] - 2, 4, 1.8, 2.0, st["boat"], caption=[("Exclusive", True), ("rods", False)], label="Starfall Rod",
           whip=True, whoosh=True)
    bk = mk("book")
    c.shot(bk["f"] + 8, 4, 1.05, 1.16, C, caption=[("Collect", False), ("them", False), ("all", True)], whip=True,
           whoosh=True)
    c.end(8)
    return c


def cut_shiny():
    c = Cut("shiny", ["9x16", "1x1"])
    s = mk("shiny")
    c.shot(s["f"] + 4, 4, 1.35, 1.55, SHINY, big=[("ONLY", 0), ("3,000", 1), ("EXIST", 2)], hits=[0, 15, 30], game=0.4,
           sparkle=True)
    c.shot(s["f"] + 50, 4, 1.5, 1.66, SHINY, caption=[("Every", False), ("shiny", True), ("is", False), ("numbered", False)],
           whip=True, whoosh=True)
    bk = mk("book")
    c.shot(bk["f"] + 8, 5, 1.1, 1.25, (W * 0.5, H * 0.58), caption=[("Collect", False), ("all", False), ("20", True)],
           whip=True, whoosh=True)
    mm = mk("meteor_start")
    c.shot(mm["f"] + 10, 4, 1.15, 1.3, BANNER, caption=[("Meteor", True), ("Showers:", True), ("5x", False),
                                                       ("shinies", False)], whip=True, whoosh=True)
    c.end(10, "Catch yours")
    return c


def cut_boss():
    c = Cut("boss", ["9x16", "1x1"])
    b = mk("boss_start")
    c.shot(b["f"] - 20, 4, 1.0, 1.12, C, big=[("SOMETHING", 0), ("HUGE", 1), ("IS COMING", 2)], hits=[0, 15, 30], game=0.3,
           dark=True, riser=True)
    c.shot(b["f"] + 4, 4, 1.15, 1.3, BANNER, caption=[("The", False), ("Leviathan", True)], flash=True, shake=22, boom=True)
    bh = mk("boss_hit")
    c.shot(bh["f"] + 18, 3, 1.3, 1.45, mid(bh), caption=[("Every", False), ("catch", True), ("hurts", False), ("it", False)],
           whip=True, whoosh=True)
    bm = mk("boss_mg")
    c.shot(bm["f"] - 2, 4, 1.25, 1.38, C, caption=[("Reel", True), ("it", False), ("in!", True)], whip=True, whoosh=True)
    bc = mk("boss_caught")
    c.shot(bc["f"] + 2, 5, 1.25, 1.45, BANNER, slam="CAUGHT!", boom=True, **HIT)
    c.end(10, "Play free")
    return c


def cut_events():
    c = Cut("events", ["9x16", "1x1"])
    g = mk("golden_start")
    c.shot(g["f"] + 4, 4, 1.15, 1.3, BANNER, big=[("EVERY", 0), ("10", 1), ("MINUTES", 2)], hits=[0, 15, 30], game=0.35)
    k = mk("koi")
    c.shot(k["f"] - 8, 2, 1.3, 1.42, BANNER, label="Golden Hour", caption=[("x2", True), ("money", False)], whip=True,
           whoosh=True)
    f = mk("frenzy_cast", 1)
    c.shot(f["f"] + 4, 2, 1.3, 1.45, mid(f), label="Fish Frenzy", caption=[("2x", True), ("faster", False)], whip=True,
           whoosh=True)
    t = mk("treasure_cast", 1)
    c.shot(t["f"] + 24, 2, 1.2, 1.32, mid(t), label="Treasure Tide", caption=[("3x", True), ("treasure", False)], whip=True,
           whoosh=True)
    mm = mk("meteor_cast")
    c.shot(mm["f"] - 6, 2, 1.1, 1.22, C, label="Meteor Shower", caption=[("5x", True), ("shinies", False)], whip=True,
           whoosh=True)
    b = mk("boss_start")
    c.shot(b["f"] + 4, 3, 1.1, 1.25, BANNER, label="Boss Fish!", caption=[("and", False), ("a", False), ("BOSS", True)],
           flash=True, shake=20, boom=True)
    bc = mk("boss_caught")
    c.shot(bc["f"] + 2, 3, 1.25, 1.4, BANNER, slam="CAUGHT!", **HIT)
    c.end(9, "Play free")
    return c


def cut_bumper():
    c = Cut("bumper", ["16x9", "9x16"])
    s = mk("shiny")
    c.shot(s["f"] + 4, 6, 1.35, 1.6, SHINY, big=[("3,000", 0), ("SHINIES", 1)], hits=[0, 15], game=0.45, sparkle=True)
    c.end(6, "Catch yours")
    return c


CUTS = {"trailer": cut_trailer, "shiny": cut_shiny, "boss": cut_boss, "events": cut_events, "bumper": cut_bumper}


# ------------------------------------------------------------ decoding
def read_frames(start, count):
    cmd = [FF, "-loglevel", "error", "-ss", f"{max(0, start) / FPS:.4f}", "-i", os.path.join(WORK, "reel.avi"),
           "-frames:v", str(count), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    n = len(raw) // (W * H * 3)
    frames = [Image.frombuffer("RGB", (W, H), raw[i * W * H * 3:(i + 1) * W * H * 3]) for i in range(n)]
    while len(frames) < count:
        frames.append(frames[-1])
    return frames


def ease_out_back(x):
    c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2


def ease_in_out(x):
    return 0.5 - 0.5 * math.cos(math.pi * min(1, max(0, x)))


def camera(img, zoom, focus, out_w, out_h):
    """a zoomed window of the source around focus, in the output's shape, kept inside the frame"""
    aspect = out_w / out_h
    ch = H / zoom
    cw = ch * aspect
    if cw > W:
        cw = W
        ch = cw / aspect
    x = min(max(focus[0] - cw / 2, 0), W - cw)
    y = min(max(focus[1] - ch / 2, 0), H - ch)
    return img.resize((out_w, out_h), Image.BICUBIC, box=(x, y, x + cw, y + ch))


# ------------------------------------------------------------- graphics
def outlined(d, xy, text, f, fill, size, anchor="mm", shadow=True):
    sw = max(3, int(size * 0.09))
    if shadow:
        d.text((xy[0] + size * 0.04, xy[1] + size * 0.07), text, font=f, fill=(0, 0, 0, 120), anchor=anchor,
               stroke_width=sw, stroke_fill=(0, 0, 0, 120))
    d.text(xy, text, font=f, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=DEEP)


def text_layer(words, size, t, max_w):
    """words pop in one by one (one every 3 frames): white, gold keywords, a deep-sea outline"""
    f = font(size, 700)
    spacing = size * 0.28
    widths = [f.getlength(w) for w, _ in words]
    total = sum(widths) + spacing * (len(words) - 1)
    pad = int(size * 0.6)
    layer = Image.new("RGBA", (int(total + pad * 2), int(size * 1.9)), (0, 0, 0, 0))
    x = pad
    for i, ((w, gold), ww) in enumerate(zip(words, widths)):
        k = (t - i * 3) / 9
        if k <= 0:
            x += ww + spacing
            continue
        sc = ease_out_back(min(1, k))
        glyph = Image.new("RGBA", (int(ww + size), int(size * 1.9)), (0, 0, 0, 0))
        outlined(ImageDraw.Draw(glyph), (size * 0.5, size * 0.95), w, f, GOLD if gold else WHITE, size, anchor="lm")
        if sc != 1:
            gw, gh = glyph.size
            glyph = glyph.resize((max(1, int(gw * sc)), max(1, int(gh * sc))), Image.BICUBIC)
            ox, oy = int((gw - glyph.size[0]) / 2), int((gh - glyph.size[1]) / 2)
        else:
            ox = oy = 0
        layer.alpha_composite(glyph, (int(x - size * 0.5 + ox), oy))
        x += ww + spacing
    if layer.size[0] > max_w:
        r = max_w / layer.size[0]
        layer = layer.resize((max_w, int(layer.size[1] * r)), Image.BICUBIC)
    return layer


_big = {}


def big_text(word, size, color=GOLD):
    """a huge outlined word with a hard shadow (slams, counters, hooks)"""
    key = (word, size, color)
    if key not in _big:
        f = font(size, 700)
        w = int(f.getlength(word) + size * 0.8)
        lay = Image.new("RGBA", (w, int(size * 1.45)), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        sw = max(3, int(size * 0.085))
        d.text((w / 2 + size * 0.05, size * 0.74 + size * 0.07), word, font=f, fill=(0, 0, 0, 150), anchor="mm",
               stroke_width=sw, stroke_fill=(0, 0, 0, 150))
        d.text((w / 2, size * 0.74), word, font=f, fill=color, anchor="mm", stroke_width=sw, stroke_fill=DEEP)
        _big[key] = lay
    return _big[key]


def pill(text, size, color=DEEP, alpha=215, fg=WHITE):
    f = font(size, 650)
    w = f.getlength(text)
    p = Image.new("RGBA", (int(w + size * 1.4), int(size * 1.7)), (0, 0, 0, 0))
    d = ImageDraw.Draw(p)
    d.rounded_rectangle((0, 0, p.size[0] - 1, p.size[1] - 1), int(size * 0.85), fill=color + (alpha,))
    d.text((p.size[0] / 2, p.size[1] / 2), text, font=f, fill=fg, anchor="mm")
    return p


ICON = Image.open(os.path.join(ROOT, "assets", "brand", "icon_1024.png")).convert("RGBA")
LOGO = MB.logo(1.0)                           # the white chunky wordmark with the leaping fish (817 px wide)


_scaled = {}


def scaled(img, width):
    key = (id(img), int(width))
    if key not in _scaled:
        _scaled[key] = img.resize((int(width), int(img.size[1] * width / img.size[0])), Image.LANCZOS)
    return _scaled[key]


def paste_center(canvas, layer, cx, cy, scale=1.0, alpha=1.0):
    if scale <= 0.01 or alpha <= 0.01:
        return
    if scale != 1.0:
        layer = layer.resize((max(1, int(layer.size[0] * scale)), max(1, int(layer.size[1] * scale))), Image.BICUBIC)
    if alpha < 1.0:
        a = layer.getchannel("A").point(lambda v: int(v * alpha))
        layer = layer.copy()
        layer.putalpha(a)
    canvas.alpha_composite(layer, (int(cx - layer.size[0] / 2), int(cy - layer.size[1] / 2)))


def flash(canvas, amount, color=(255, 252, 240)):
    if amount > 0:
        canvas.alpha_composite(Image.new("RGBA", canvas.size, color + (int(255 * min(1, amount)),)))


def vignette(size):
    w, h = size
    v = Image.radial_gradient("L").resize((w, h)).point(lambda p: int(min(255, p * 0.5)))
    layer = Image.new("RGBA", (w, h), (6, 22, 30, 0))
    layer.putalpha(v)
    return layer


def rgb_split(c, amt):
    if amt < 1:
        return c
    r, g, b, a = c.split()
    return Image.merge("RGBA", (ImageChops.offset(r, -amt, 0), g, ImageChops.offset(b, amt, 0), a))


def whip_blur(c, amt):
    """horizontal motion blur (squash the width, stretch it back)"""
    if amt < 1.05:
        return c
    w, h = c.size
    return c.resize((max(8, int(w / amt)), h), Image.BILINEAR).resize((w, h), Image.BILINEAR)


def glint(r):
    """a 4-point sparkle with a soft halo (the shiny look)"""
    n = int(r * 4)
    cc = n / 2
    k = r * 0.17
    m = Image.new("L", (n, n), 0)
    ImageDraw.Draw(m).polygon([(cc, cc - r), (cc + k, cc - k), (cc + r, cc), (cc + k, cc + k), (cc, cc + r), (cc - k, cc + k),
                               (cc - r, cc), (cc - k, cc - k)], fill=255)
    halo = Image.new("L", (n, n), 0)
    ImageDraw.Draw(halo).ellipse((cc - r * 0.45, cc - r * 0.45, cc + r * 0.45, cc + r * 0.45), fill=255)
    lay = Image.new("RGBA", (n, n), (255, 247, 214, 0))
    lay.putalpha(ImageChops.lighter(m, halo.filter(ImageFilter.GaussianBlur(r * 0.3)).point(lambda v: int(v * 0.8))))
    return lay


GLINT = glint(40)


def sparkles(c, i, seed, n=7):
    """glints that twinkle around the frame (each grows and shrinks on its own clock)"""
    rng = random.Random(seed)
    ow, oh = c.size
    for j in range(n):
        x, y = rng.uniform(0.08, 0.92) * ow, rng.uniform(0.1, 0.8) * oh
        ph = rng.uniform(0, 1)
        k = math.sin(math.pi * ((i / 24.0 + ph) % 1.0))
        paste_center(c, GLINT, x, y, 0.3 + 0.7 * k * rng.uniform(0.6, 1.0), k)


# ------------------------------------------------------------- layouts
FORMATS = {"16x9": (1920, 1080), "9x16": (1080, 1920), "1x1": (1080, 1080)}
VIGS = {k: vignette(v) for k, v in FORMATS.items()}
UI = {"16x9": 1.0, "1x1": 0.8, "9x16": 0.82}            # text scale per format


def game_view(fmt, img, zoom, focus):
    ow, oh = FORMATS[fmt]
    if fmt != "9x16":
        return camera(img, zoom, focus, ow, oh).convert("RGBA")
    # vertical: a blurred backdrop and a square gameplay window in the middle
    bg = camera(img, 1.0, (W / 2, H / 2), 1080 * 9 // 16 * 2, 1920).filter(ImageFilter.GaussianBlur(30))
    bg = bg.resize((1080, 1920)).convert("RGBA")
    bg.alpha_composite(Image.new("RGBA", bg.size, (8, 30, 40, 120)))
    sq = camera(img, zoom, focus, 1080, 1080).convert("RGBA")
    mask = Image.new("L", (1080, 1080), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1079, 1079), 48, fill=255)
    bg.paste(sq, (0, 420), mask)
    return bg


def caption_pos(fmt):
    ow, oh = FORMATS[fmt]
    if fmt == "9x16":
        return ow / 2, 300, ow - 80, 120
    if fmt == "1x1":
        return ow / 2, oh - 140, ow - 80, 104
    return ow / 2, oh - 150, ow - 200, 118


def center_y(fmt):
    """the middle of the gameplay picture"""
    return 420 + 540 if fmt == "9x16" else FORMATS[fmt][1] / 2


def count_y(fmt):
    return {"16x9": 170, "1x1": 150, "9x16": 1620}[fmt]


def words_y(fmt, lines):
    """where big words go: the lower third (16x9, 1x1), or the band above the game window (9x16)"""
    ow, oh = FORMATS[fmt]
    if fmt == "9x16":
        return 230
    return oh * (0.78 if lines == 1 else 0.72)


_layouts = {}


def big_layout(fmt, words):
    """the hook words as lines (greedy, by width): each word's layer and its centre"""
    key = (fmt, words)
    if key not in _layouts:
        ow, oh = FORMATS[fmt]
        size = {"16x9": 150, "1x1": 118, "9x16": 126}[fmt]
        layers = [big_text(w, size, GOLD if j % 2 else WHITE) for j, (w, _b) in enumerate(words)]
        lines, widths = [[]], [0.0]
        for j, lay in enumerate(layers):
            lw = lay.size[0] * 0.86
            if lines[-1] and widths[-1] + lw > ow * 0.92:
                lines.append([])
                widths.append(0.0)
            lines[-1].append(j)
            widths[-1] += lw
        line_h = layers[0].size[1] * 0.74
        y0 = words_y(fmt, len(lines))
        pos = {}
        for li, line in enumerate(lines):
            y = y0 + (li - (len(lines) - 1) / 2) * line_h
            x = ow / 2 - widths[li] / 2
            for j in line:
                lw = layers[j].size[0] * 0.86
                pos[j] = (x + lw / 2, y)
                x += lw
        _layouts[key] = (layers, pos)
    return _layouts[key]


def _band(fmt):
    ow, oh = FORMATS[fmt]
    g = Image.linear_gradient("L").resize((ow, oh)).point(lambda v: int(185 * min(1, max(0, (v - 120) / 110))))
    lay = Image.new("RGBA", (ow, oh), (6, 20, 28, 0))
    lay.putalpha(g)
    return lay


BANDS = {f: _band(f) for f in ("16x9", "1x1")}


FOOTER = Image.new("RGBA", (760, 170), (0, 0, 0, 0))
FOOTER.alpha_composite(ICON.resize((120, 120), Image.LANCZOS), (0, 25))
_lg = scaled(LOGO, 300)
FOOTER.alpha_composite(_lg, (150, int(85 - _lg.size[1] / 2)))


def draw_frame(cut, fmt, s, i, img):
    ow, oh = FORMATS[fmt]
    tag = s.get("tag")
    if tag == "end":
        return end_card(fmt, i, s)
    fx = s["fx"]
    k = i / max(1, s["n"] - 1)
    zoom = s["z0"] + (s["z1"] - s["z0"]) * ease_in_out(k)
    zoom *= 1 + 0.09 * max(0, 1 - i / 6) ** 2               # a punch-in on every cut
    focus = s["focus"]
    amp = fx.get("shake", 0) * max(0.0, 1 - i / 12) ** 1.5
    if amp:
        rng = random.Random(s["id"] * 1000 + i)
        focus = (focus[0] + rng.uniform(-amp, amp) * 3, focus[1] + rng.uniform(-amp, amp) * 3)
    c = game_view(fmt, img, zoom, focus)
    c.alpha_composite(VIGS[fmt])
    sc = UI[fmt]
    cx, cy, mw, size = caption_pos(fmt)
    if fx.get("dark"):
        c.alpha_composite(Image.new("RGBA", c.size, (4, 10, 16, 150)))
    if fx.get("sparkle"):
        sparkles(c, i, s["id"] * 7 + 1)
    if tag == "title":
        c.alpha_composite(Image.new("RGBA", c.size, (8, 30, 40, int(110 * min(1, i / 5)))))
        tsc = ease_out_back(min(1, i / 8)) * {"16x9": 1.0, "1x1": 0.85, "9x16": 1.0}[fmt] * (1 + 0.5 * max(0, 1 - i / 4))
        tcy = oh * (0.42 if fmt != "9x16" else 0.4)
        paste_center(c, scaled(LOGO, 760), ow / 2, tcy, tsc)
        if i > 10:
            paste_center(c, pill("THE 1.0 UPDATE", int(54 * sc), color=(214, 86, 52), alpha=240), ow / 2, tcy + 300 * tsc,
                         ease_out_back(min(1, (i - 10) / 7)))
    if fx.get("big"):
        beat = i / BEAT
        words = fx["big"]
        shown = [j for j, (_w, b0) in enumerate(words) if beat >= b0]
        if shown:
            layers, pos = big_layout(fmt, tuple(words))
            if fmt != "9x16" and not fx.get("dark"):             # a soft shade under the words, the game stays visible
                c.alpha_composite(BANDS[fmt])
            for j in shown:
                age = i - words[j][1] * BEAT
                slam = 1.0 + 0.8 * max(0.0, 1 - age / 6) ** 2
                paste_center(c, layers[j], pos[j][0], pos[j][1], slam, min(1.0, 0.35 + age / 4))
    if fx.get("slam"):
        slam = 1.0 + 1.2 * max(0.0, 1 - i / 5) ** 2
        if fmt != "9x16":
            c.alpha_composite(BANDS[fmt])
        paste_center(c, big_text(fx["slam"], int(200 * sc)), ow / 2, words_y(fmt, 1), slam)
    if fx.get("count"):
        pre, target, post = fx["count"]
        k2 = min(1.0, i / 18)
        val = int(round(target * (1 - (1 - k2) ** 3)))
        pop = 1.0 + 0.35 * max(0.0, 1 - abs(i - 19) / 4)
        paste_center(c, big_text("%s%s%s" % (pre, f"{val:,}", post), int(170 * sc)), ow / 2, count_y(fmt), pop)
    if s.get("label"):
        lab = pill(s["label"], 44 if fmt == "16x9" else 40)
        paste_center(c, lab, lab.size[0] / 2 + 50, 70 if fmt != "9x16" else 470, ease_out_back(min(1, i / 6)))
    if fmt == "9x16" and tag != "title":
        paste_center(c, FOOTER, ow / 2, 1790)                    # the brand under the gameplay window
    if s.get("caption"):
        paste_center(c, text_layer(s["caption"], size, 99 if fx.get("hold") else i, mw), cx, cy)
    if fx.get("whip") and i < 5:
        c = whip_blur(c, 1 + 14 * (1 - i / 5) ** 2)
    if fx.get("chroma") and i < 7:
        c = rgb_split(c, int(16 * (1 - i / 7)))
    if fx.get("flash") and i < 5:
        flash(c, 0.9 * (1 - i / 5))
    if tag == "title" and i < 6:
        flash(c, 1 - i / 6)
    return c


# ------------------------------------------------------------- end card
ART = Image.open(MB.ART).convert("RGB")


def _cover(img, ow, oh, fx=0.3):
    """the painted art cropped to fill ow x oh (fx: where to look across, 0 = left)"""
    s = max(ow / img.size[0], oh / img.size[1])
    w, h = img.size[0] * s, img.size[1] * s
    x = (w - ow) * fx
    return img.resize((ow, oh), Image.LANCZOS, box=(x / s, (h - oh) / 2 / s, (x + ow) / s, ((h - oh) / 2 + oh) / s))


END_BG = {f: _cover(ART, *FORMATS[f], fx=0.25 if f == "9x16" else 0.5).convert("RGBA") for f in FORMATS}


def end_card(fmt, i, s):
    """the painted dock, the logo, "Play free", foshfish.xyz and where to play"""
    ow, oh = FORMATS[fmt]
    sc = {"16x9": 1.0, "1x1": 0.82, "9x16": 1.0}[fmt]
    bg = END_BG[fmt].copy()
    shade = Image.new("RGBA", bg.size, (6, 26, 34, int(120 * min(1, i / 8))))
    bg.alpha_composite(shade)
    sparkles(bg, i, 99 + len(fmt), 6)
    top = oh * {"16x9": 0.3, "1x1": 0.3, "9x16": 0.3}[fmt]
    lw = {"16x9": 820, "1x1": 760, "9x16": 900}[fmt]
    paste_center(bg, scaled(LOGO, lw), ow / 2, top, ease_out_back(min(1, i / 10)))
    if i > 6:
        sticker = pill("NEW 1.0", int(40 * sc), color=(255, 196, 46), alpha=255, fg=DEEP)
        paste_center(bg, sticker.rotate(8, Image.BICUBIC, expand=True), ow / 2 + lw * 0.42, top - lw * 0.26,
                     ease_out_back(min(1, (i - 6) / 7)))
    cta_y = top + lw * 0.42 + 70 * sc
    if i > 12:
        k = ease_out_back(min(1, (i - 12) / 8))
        btn = pill(s["fx"].get("cta", "Play free"), int(74 * sc), color=MINT, alpha=255, fg=DEEP)
        pulse = 1 + 0.04 * math.sin(max(0, i - 24) / 4.0)
        paste_center(bg, btn, ow / 2, cta_y, k * pulse)
    if i > 18:
        a = min(1, (i - 18) / 8)
        f = font(int(46 * sc), 650)
        lay = Image.new("RGBA", (ow, int(90 * sc)), (0, 0, 0, 0))
        outlined(ImageDraw.Draw(lay), (ow / 2, 45 * sc), "foshfish.xyz", f, WHITE, int(46 * sc))
        paste_center(bg, lay, ow / 2, cta_y + 125 * sc, 1, a)
    if i > 24:
        plats = ["Android", "Windows", "Linux", "Web"]
        for j, p in enumerate(plats):
            kk = (i - 24 - j * 3) / 7
            if kk <= 0:
                continue
            chip = pill(p, int(32 * sc))
            if fmt == "9x16":
                px, py = ow / 2 + (j % 2 - 0.5) * 300, cta_y + 240 * sc + (j // 2) * 78
            else:
                gap = {"16x9": 250, "1x1": 230}[fmt]
                px, py = ow / 2 + (j - 1.5) * gap, cta_y + 225 * sc
            paste_center(bg, chip, px, py, ease_out_back(min(1, kk)))
    flash(bg, 0.85 * (1 - i / 5))
    fade = (i - (s["n"] - 12)) / 12
    if fade > 0:
        bg.alpha_composite(Image.new("RGBA", bg.size, (6, 26, 34, int(255 * min(1, fade)))))
    return bg


# --------------------------------------------------------------- audio
_game = None


def game_audio():
    global _game
    if _game is None:
        raw = subprocess.run([FF, "-loglevel", "error", "-i", os.path.join(WORK, "reel.avi"), "-vn", "-f", "s16le",
                              "-ac", "2", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
        _game = np.frombuffer(raw, np.int16).reshape(-1, 2).astype(np.float32) / 32768
    return _game


def stereo(x):
    return np.stack([x, x], 1).astype(np.float32)


def build_audio(cut):
    """sound effects only: the game's sounds, a water bed, whooshes on cuts, hits on the words, booms on the
    big moments, a riser into them, ticks on the counter, a chime on the end card"""
    game = game_audio()
    n = int((cut.total / FPS + 1.0) * SR)
    out = np.zeros((n, 2), np.float32)

    def add(sig, at, gain):
        if sig.ndim == 1:
            sig = stereo(sig)
        a = max(0, int(at))
        seg = sig[:max(0, min(len(sig), n - a))]
        out[a:a + len(seg)] += seg * gain

    bed, _ = MBX.sample("x_splash_sfx/loop_water_01.ogg")
    bed = np.tile(bed, int(n / len(bed)) + 2)[:n] * MBX.fades(n, 0.6, 1.2)
    add(bed, 0, 0.1)
    wsh = music.whoosh(0.4)
    hit = music.kick(0.4) * 0.9 + music.noise_hit(0.4, 0.06, hp=0.8) * 0.5
    boom = MBX.sub_boom(1.6) * 0.8 + MBX.crash(1.6) * 0.5
    punch, _ = MBX.kenney("impactPunch_heavy", 1)
    tick, _ = MBX.kenney("tick", 1)
    t = 0
    for s in cut.shots:
        a = int(t / FPS * SR)
        dur = s["n"] / FPS
        fx = s["fx"]
        if s.get("src") is not None:
            g0 = int(s["src"] / FPS * SR)
            seg = game[g0:g0 + int(dur * SR)]
            ramp = np.minimum(1, np.minimum(np.arange(len(seg)), np.arange(len(seg))[::-1]) / 480.0)[:, None]
            add(seg * ramp, a, fx.get("game", 0.6))
        if s.get("whoosh"):
            add(wsh, a - int(0.22 * SR), 0.35)
        for hf in fx.get("hits", []):
            add(hit, a + int(hf / FPS * SR), 0.5)
            add(punch, a + int(hf / FPS * SR), 0.35)
        if fx.get("slam"):
            add(punch, a, 0.5)
        if fx.get("boom"):
            add(boom, a, 0.55)
        if fx.get("riser"):
            r = music.riser(1.2)
            add(r, a - len(r), 0.3)
        if fx.get("ticks"):
            for f in range(0, 18, 2):
                add(tick, a + int(f / FPS * SR), 0.22)
        if fx.get("sparkle"):
            for j in range(4):
                add(MBX.chirp(2400 + 300 * j), a + int((6 + j * 9) / FPS * SR), 0.12)
        if s.get("tag") == "title":
            add(boom, a, 0.6)
        if s.get("tag") == "end":
            bell, _ = MBX.kenney("impactBell_heavy", 0)
            add(bell, a + int(12 / FPS * SR), 0.3)
            add(MBX.chirp(2800), a + int(14 / FPS * SR), 0.15)
        t += s["n"]
    out = np.tanh(out * 1.1) / np.tanh(1.1)
    path = os.path.join(WORK, f"mix_{cut.name}.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(out, -1, 1) * 32767).astype(np.int16).tobytes())
    return path


# --------------------------------------------------------------- render
def render(cut):
    audio = build_audio(cut)
    os.makedirs(OUT, exist_ok=True)
    procs = {}
    for fmt in cut.formats:
        ow, oh = FORMATS[fmt]
        path = os.path.join(OUT, f"fosh-and-fish-1.0-{cut.name}-{fmt}.mp4")
        procs[fmt] = subprocess.Popen(
            [FF, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{ow}x{oh}", "-r", str(FPS),
             "-i", "-", "-i", audio, "-af", "loudnorm=I=-14:TP=-1.5:LRA=9,alimiter=limit=0.89",
             "-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-profile:v", "high",
             "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-shortest", "-movflags", "+faststart", path],
            stdin=subprocess.PIPE)
    frame_no = 0
    for si, s in enumerate(cut.shots):
        src = read_frames(s["src"], s["n"]) if s.get("src") is not None else None
        for i in range(s["n"]):
            img = src[i] if src else None
            for fmt in cut.formats:
                procs[fmt].stdin.write(draw_frame(cut, fmt, s, i, img).convert("RGB").tobytes())
            frame_no += 1
        print(f"{cut.name}: shot {si + 1}/{len(cut.shots)} ({frame_no}/{cut.total})", flush=True)
    for p in procs.values():
        p.stdin.close()
        p.wait()


# ------------------------------------------------------------ thumbnail
def thumbnail():
    """1280x720: the shiny reveal up close, the logo, a big 1.0"""
    tw, th = 1280, 720
    s = mk("shiny")
    frame = read_frames(s["f"] + 30 + FRAME_OFFSET, 1)[0]
    c = camera(frame, 1.5, (W * 0.34, H * 0.42), tw, th).convert("RGBA")       # the card on the right
    c.alpha_composite(vignette((tw, th)))
    shade = Image.linear_gradient("L").rotate(-90).resize((tw, th)).point(lambda p: int(min(255, p * 1.4) * 0.85))
    dark = Image.new("RGBA", (tw, th), (6, 26, 34, 0))
    dark.putalpha(shade)
    c.alpha_composite(dark)                                    # darker on the left for the text
    paste_center(c, scaled(LOGO, 470), 300, 175)
    paste_center(c, big_text("1.0", 230), 290, 440)
    paste_center(c, pill("SHINY FISH + EVENTS", 34, color=(214, 86, 52), alpha=240), 300, 625)
    sparkles(c, 7, 5, 6)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "fosh-and-fish-1.0-thumbnail.png")
    c.convert("RGB").save(path)
    print("thumbnail", path)


if __name__ == "__main__":
    args = [a for a in sys.argv[3:] if not a.startswith("--")]
    names = args[0].split(",") if args else list(CUTS)
    if "--thumb-only" in sys.argv:
        names = []
    for name in names:
        cut = CUTS[name]()
        print(name, cut.total, "frames", round(cut.total / FPS, 1), "s", cut.formats, flush=True)
        if "--plan" not in sys.argv:
            render(cut)
    if "--thumb" in sys.argv or "--thumb-only" in sys.argv:
        thumbnail()

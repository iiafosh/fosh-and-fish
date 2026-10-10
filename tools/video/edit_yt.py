"""YouTube cut of the fosh&fish 0.5 trailer, edited from the --reelyt recording.

A hook montage (one-beat slams), a title slam on the impact, a 0.1 -> 0.5 before/after slider, then every
feature (mini-game, captain, sailing, FishTok, online accounts + leaderboard, in-game updates), a break that
builds "17 NEW BOATS" and a drop into the boat parade. Speed ramps, shake, flash frames, RGB-split hits,
whip blur, slam text and counters on top of the edit.py / edit05.py camera, captions and layouts.
Music: tools/video/music_yt.py (same 120 BPM grid: one beat = 15 frames, one bar = 60).

    python tools/mock_supabase.py --port 54321            (the online part signs up on this local test server)
    godot --path . --write-movie WORK/reel.avi --fixed-fps 30 -- --reelyt --backend-url=http://127.0.0.1:54321 --backend-key=test > WORK/reel_log.txt
        (with a 1920x1080 window override in override.cfg)
    python tools/video/music_yt.py WORK/music.wav
    python tools/video/edit_yt.py WORK OUT [16x9,9x16,1x1] [--thumb]
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

sys.path.insert(0, os.path.dirname(__file__))
import music  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WORK, OUT = sys.argv[1], sys.argv[2]
FF = imageio_ffmpeg.get_ffmpeg_exe()
FPS, SR = 30, 48000
BEAT = 15                                    # frames per beat at 120 BPM
W, H = 1920, 1080                            # source size
SRC_SCALE = 1.5                              # marks are logged in the 1280x720 canvas
FONT = os.path.join(ROOT, "assets", "third_party", "fonts", "Fredoka.ttf")
CREAM, BROWN, GOLD, TEAL = (255, 246, 226), (46, 32, 22), (255, 204, 72), (47, 143, 158)

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
    return marks[name][i]


def mid(m, k=0.5):
    (bx, by), (ox, oy) = m["bob"], m["boat"]
    return (ox + (bx - ox) * k, oy + (by - oy) * k)


# ------------------------------------------------------------- shot list
# each shot: src start frame, length in beats, zoom from->to, focus (x, y) in source px, caption
# (list of (word, gold)), a top-left label, a whoosh into the cut, and effects (fx):
#   flash, chroma, whip      on the first frames of the cut
#   shake=px                 decaying camera shake
#   slam="WORD"              one big word slammed onto the shot
#   slowmo=(from, speed)     speed ramp from that fraction of the shot on
#   count=(pre, n, post)     a number counting up
#   big=[(word, beat), ...]  words landing on beats (the break)
#   f1=(x, y)                focus to drift to
#   hits=[frame, ...]        hit sounds;  game=gain of the game audio (default 0.5)
shots = []


def shot(src, beats, z0, z1, focus, caption=None, tag=None, whoosh=False, label=None, **fx):
    shots.append(dict(id=len(shots), src=src + FRAME_OFFSET, n=beats * BEAT, z0=z0, z1=z1, focus=focus,
                      caption=caption, tag=tag, whoosh=whoosh, label=label, fx=fx))


C = (W * 0.5, H * 0.5)
hero = marks["hero"]
HIT = dict(flash=True, chroma=True, shake=30, hits=[0], game=0.25)
# bar 0: HOOK - four one-beat slams
shot(mk("mg_win")["f"] + 6, 1, 1.5, 1.62, C, slam="THE", **HIT)
b = mk("boat_Sky_Cruiser")
shot(b["f"] + 10, 1, 1.8, 1.95, b["boat"], slam="BIGGEST", **HIT)
shot(mk("phone")["f"] + 30, 1, 1.45, 1.6, (W * 0.5, H * 0.45), slam="UPDATE", **HIT)
b = mk("boat_Dark_Explorer")
shot(b["f"] + 10, 1, 1.8, 1.95, b["boat"], slam="YET", **HIT)
# bar 1: TITLE slam on the music impact
shot(hero[2]["f"] - 8, 4, 1.15, 1.25, mid(hero[2]), tag="title", shake=34)
# bar 2: 0.1 -> 0.5 before / after
shot(hero[1]["f"] - 10, 4, 1.0, 1.06, mid(hero[1]), tag="beforeafter", whoosh=True)
# bar 3: tap the water
t = marks["tap"]
shot(t[0]["f"] - 4, 4, 1.45, 1.3, t[0]["bob"], caption=[("Tap", True), ("the", False), ("water", False)],
     whip=True, whoosh=True)
# bars 4-5: Reel it in!, then the win in slow motion with a counter
shot(mk("mg_play")["f"] - 4, 4, 1.25, 1.38, C, caption=[("Reel", True), ("it", False), ("in!", True)],
     whip=True, whoosh=True)
shot(mk("mg_win")["f"] - 12, 4, 1.35, 1.65, C, count=("+", 75, "% FISH"), slowmo=(0.3, 0.3), flash=True, shake=22,
     chroma=True, hits=[12], game=0.35)
# bar 6: meet the captain (dance, then the fist pump)
d = mk("dance")
shot(d["f"] + 6, 2, 2.2, 2.5, d["boat"], caption=[("Meet", False), ("the", False), ("captain", True)],
     whip=True, whoosh=True)
h = mk("happy")
shot(h["f"] + 4, 2, 2.5, 2.75, h["boat"], caption=[("Meet", False), ("the", False), ("captain", True)], shake=10,
     hold=True)
# bars 7-8: sail through a sea lane into the next biome
sg = mk("sail_go")
shot(sg["f"] + 6, 4, 1.2, 1.32, sg["boat"], caption=[("Sail", True), ("to", False), ("new", False), ("waters", False)],
     whip=True, whoosh=True)
shot(mk("sail_wipe")["f"] - 14, 2, 1.0, 1.08, C, whip=True)
sa = mk("sail_arrive")
shot(sa["f"] + 2, 2, 1.3, 1.15, sa["boat"], label="Volcanic", flash=True, shake=14)
# bars 9-10: FishTok
shot(mk("phone")["f"] - 10, 4, 1.3, 1.42, (W * 0.5, H * 0.5), caption=[("FishTok", True)], whip=True, whoosh=True)
shot(mk("phone")["f"] + 40, 4, 1.45, 1.6, (W * 0.5, H * 0.42), caption=[("Trending", False), ("fish", False)],
     count=("+", 50, "%"), chroma=True, flash=True)
# bars 11-12: online - accounts + cloud save, then the global leaderboard
shot(mk("acct_in")["f"] - 6, 4, 1.04, 1.16, (W * 0.5, H * 0.46), caption=[("Online", True), ("accounts", False)],
     label="Cloud save", whip=True, whoosh=True)
shot(mk("acct_board")["f"] - 4, 4, 1.06, 1.55, (W * 0.5, H * 0.5), f1=(W * 0.42, H * 0.72),
     caption=[("Global", False), ("leaderboard", True)], flash=True)
# bar 13: in-game updates (the button, then ready to restart)
shot(mk("upd_avail")["f"] - 6, 2, 1.1, 1.3, (W * 0.5, H * 0.45), f1=(W * 0.35, H * 0.38),
     caption=[("One-tap", True), ("updates", False)], whip=True, whoosh=True)
shot(mk("upd_ready")["f"] - 2, 2, 1.3, 1.4, (W * 0.35, H * 0.38), caption=[("One-tap", True), ("updates", False)],
     hold=True, flash=True)
# bars 14-15: BREAK - slow push, words land on the beat, black before the drop
shot(hero[0]["f"] + 30, 8, 1.1, 1.5, mid(hero[0]), slowmo=(0.0, 0.5), game=0.2,
     big=[("17", 0), ("NEW", 2), ("BOATS", 4)], hits=[0, 30, 60], blackout=6)
# bars 16-19: DROP - the boat parade, a cut every 2 beats
parade = [("Speedboat", "Ocean"), ("Yacht", "Ocean"), ("Cruise_Ship", "Ocean"), ("Gold_Boat", "Ocean"),
          ("Sky_Cruiser", "Sky"), ("Space_Shuttle", "Space"), ("Alien_Raft", "Alien"), ("Dark_Explorer", "Abyss")]
for n, (name, biome) in enumerate(parade):
    m = mk("boat_" + name)
    shot(m["f"] + 8, 2, 1.75 if n % 2 == 0 else 1.5, 1.55 if n % 2 == 0 else 1.7, m["boat"], label=biome,
         caption=[(name.replace("_", " "), True)], flash=n == 0, chroma=True, shake=26 if n == 0 else 12,
         whip=n % 2 == 1, hits=[0] if n == 0 else [], game=0.3)
# bars 20-21: free to play on every platform
e = marks["end"]
shot(e[0]["f"] - 10, 8, 1.0, 1.14, mid(e[0]), caption=[("Free", True), ("to", False), ("play", False)],
     tag="platforms", flash=True)
# bars 22-23: end card (final chord)
shots.append(dict(id=len(shots), tag="end", n=8 * BEAT + 30, whoosh=True, fx={}))

TOTAL = sum(s["n"] for s in shots)
print("timeline", TOTAL, "frames", TOTAL / FPS, "s")


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


def src_index(s):
    """source frame for every output frame: 1:1, or a speed ramp (slowmo=(from_frac, speed))"""
    sm = s["fx"].get("slowmo")
    out, pos = [], 0.0
    for i in range(s["n"]):
        out.append(int(pos))
        pos += sm[1] if (sm and i >= sm[0] * s["n"]) else 1.0
    return out


def ease_out_back(x):
    c1, c3 = 1.70158, 2.70158
    return 1 + c3 * (x - 1) ** 3 + c1 * (x - 1) ** 2


def ease_in_out(x):
    return 0.5 - 0.5 * math.cos(math.pi * min(1, max(0, x)))


def camera(img, zoom, focus, out_w, out_h):
    """Crop a zoomed window of the source around focus with the output aspect, keep it inside the frame."""
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
def text_layer(words, size, t, max_w):
    """Words pop in one by one (one every 3 frames), gold keywords, thick outline + shadow."""
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
        gd = ImageDraw.Draw(glyph)
        gd.text((size * 0.5 + 4, size * 0.95 + 6), w, font=f, anchor="lm", fill=(0, 0, 0, 110),
                stroke_width=int(size * 0.1), stroke_fill=(0, 0, 0, 110))
        gd.text((size * 0.5, size * 0.95), w, font=f, anchor="lm", fill=GOLD if gold else CREAM,
                stroke_width=int(size * 0.1), stroke_fill=BROWN)
        if sc != 1:
            gw, gh = glyph.size
            glyph = glyph.resize((max(1, int(gw * sc)), max(1, int(gh * sc))), Image.BICUBIC)
            ox = int((gw - glyph.size[0]) / 2)
            oy = int((gh - glyph.size[1]) / 2)
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
    """Huge outlined word with a hard drop shadow (slams, counters, the break)."""
    key = (word, size, color)
    if key not in _big:
        f = font(size, 700)
        w = int(f.getlength(word) + size * 0.8)
        lay = Image.new("RGBA", (w, int(size * 1.45)), (0, 0, 0, 0))
        d = ImageDraw.Draw(lay)
        sw = max(3, int(size * 0.085))
        d.text((w / 2 + size * 0.05, size * 0.74 + size * 0.07), word, font=f, fill=(0, 0, 0, 150), anchor="mm",
               stroke_width=sw, stroke_fill=(0, 0, 0, 150))
        d.text((w / 2, size * 0.74), word, font=f, fill=color, anchor="mm", stroke_width=sw, stroke_fill=BROWN)
        _big[key] = lay
    return _big[key]


def pill(text, size, color=TEAL):
    f = font(size, 650)
    w = f.getlength(text)
    p = Image.new("RGBA", (int(w + size * 1.4), int(size * 1.7)), (0, 0, 0, 0))
    d = ImageDraw.Draw(p)
    d.rounded_rectangle((0, 0, p.size[0] - 1, p.size[1] - 1), int(size * 0.85), fill=color + (235,))
    d.text((p.size[0] / 2, p.size[1] / 2), text, font=f, fill=CREAM, anchor="mm")
    return p


ICON = Image.open(os.path.join(ROOT, "assets", "brand", "icon_512.png")).convert("RGBA")


def title_art(scale=1.0):
    """fosh&fish wordmark, same style as the brand art."""
    size = int(170 * scale)
    f = font(size, 700)
    text = "fosh&fish"
    w = int(f.getlength(text) + size)
    img = Image.new("RGBA", (w, int(size * 1.6)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = w / 2, size * 0.8
    for r in range(size // 9, 0, -2):
        for a in range(0, 360, 30):
            d.text((cx + math.cos(math.radians(a)) * r, cy + math.sin(math.radians(a)) * r + size * 0.06), text,
                   font=f, fill=(40, 28, 18, 255), anchor="mm")
    for a in range(0, 360, 20):
        d.text((cx + math.cos(math.radians(a)) * size * 0.07, cy + math.sin(math.radians(a)) * size * 0.07), text,
               font=f, fill=BROWN + (255,), anchor="mm")
    d.text((cx, cy), text, font=f, fill=(255, 216, 92, 255), anchor="mm")
    hi = Image.new("RGBA", img.size, (0, 0, 0, 0))          # soft top highlight, blended (not overwritten)
    ImageDraw.Draw(hi).text((cx, cy - size * 0.05), text, font=f, fill=(255, 236, 160, 90), anchor="mm")
    img.alpha_composite(hi)
    return img


TITLE = title_art()
FOOTER = Image.new("RGBA", (760, 150), (0, 0, 0, 0))
FOOTER.alpha_composite(ICON.resize((120, 120)), (0, 15))
_t = title_art(0.62)
FOOTER.alpha_composite(_t, (130, int(75 - _t.size[1] / 2)))
OLD_UI = Image.open(os.path.join(os.path.dirname(__file__), "before_0.1.jpg")).convert("RGB").resize((W, H), Image.BICUBIC)


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


def flash(canvas, amount, color=(255, 250, 235)):
    if amount > 0:
        canvas.alpha_composite(Image.new("RGBA", canvas.size, color + (int(255 * min(1, amount)),)))


def vignette(size):
    w, h = size
    v = Image.radial_gradient("L").resize((w, h)).point(lambda p: int(min(255, p * 0.55)))
    layer = Image.new("RGBA", (w, h), (10, 18, 30, 0))
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


# ------------------------------------------------------------- layouts
FORMATS = {"16x9": (1920, 1080), "9x16": (1080, 1920), "1x1": (1080, 1080)}
VIGS = {k: vignette(v) for k, v in FORMATS.items()}
UI = {"16x9": 1.0, "1x1": 0.78, "9x16": 0.8}            # text scale per format


def game_view(fmt, img, zoom, focus):
    ow, oh = FORMATS[fmt]
    if fmt != "9x16":
        return camera(img, zoom, focus, ow, oh).convert("RGBA")
    # vertical: blurred backdrop + square gameplay window in the middle
    bg = camera(img, 1.0, (W / 2, H / 2), 1080 * 9 // 16 * 2, 1920).filter(ImageFilter.GaussianBlur(30))
    bg = bg.resize((1080, 1920)).convert("RGBA")
    bg.alpha_composite(Image.new("RGBA", bg.size, (12, 30, 44, 120)))
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
        return ow / 2, oh - 150, ow - 80, 104
    return ow / 2, oh - 150, ow - 200, 118


def center_y(fmt):
    """middle of the gameplay picture"""
    return 420 + 540 if fmt == "9x16" else FORMATS[fmt][1] / 2


def count_y(fmt):
    return {"16x9": 170, "1x1": 150, "9x16": 1620}[fmt]


def draw_frame(fmt, s, i, img):
    ow, oh = FORMATS[fmt]
    tag = s.get("tag")
    if tag == "end":
        return end_card(fmt, i)
    fx = s["fx"]
    k = i / max(1, s["n"] - 1)
    zoom = s["z0"] + (s["z1"] - s["z0"]) * ease_in_out(k)
    zoom *= 1 + 0.09 * max(0, 1 - i / 6) ** 2               # punch-in on every cut
    focus = s["focus"]
    if fx.get("f1"):
        e = ease_in_out(k)
        focus = (focus[0] + (fx["f1"][0] - focus[0]) * e, focus[1] + (fx["f1"][1] - focus[1]) * e)
    amp = fx.get("shake", 0) * max(0.0, 1 - i / 12) ** 1.5
    if amp:
        rng = random.Random(s["id"] * 1000 + i)
        focus = (focus[0] + rng.uniform(-amp, amp) * 3, focus[1] + rng.uniform(-amp, amp) * 3)
    c = game_view(fmt, img, zoom, focus)
    if tag == "beforeafter":
        old = game_view(fmt, OLD_UI, zoom, focus)
        x = int(ow * (0.9 - 0.8 * ease_in_out((i - 6) / (s["n"] - 22))))
        c.paste(old.crop((0, 0, x, oh)), (0, 0))
    c.alpha_composite(VIGS[fmt])
    sc = UI[fmt]
    cx, cy, mw, size = caption_pos(fmt)
    if tag == "beforeafter":
        d = ImageDraw.Draw(c)
        y0, y1 = (420, 1500) if fmt == "9x16" else (0, oh)
        d.rectangle((x - 4, y0, x + 4, y1), fill=(255, 255, 255, 255))
        my = (y0 + y1) / 2
        d.ellipse((x - 30, my - 30, x + 30, my + 30), fill=CREAM + (255,), outline=BROWN, width=5)
        d.polygon([(x - 18, my), (x - 6, my - 10), (x - 6, my + 10)], fill=BROWN)
        d.polygon([(x + 18, my), (x + 6, my - 10), (x + 6, my + 10)], fill=BROWN)
        ly = 300 if fmt == "9x16" else 80
        paste_center(c, pill("0.1  before", int(42 * sc), color=(120, 110, 100)), ow * 0.2, ly, ease_out_back(min(1, i / 8)))
        paste_center(c, pill("0.5  now", int(42 * sc)), ow * 0.8, ly, ease_out_back(min(1, max(0, i - 4) / 8)))
    if tag == "title":
        c.alpha_composite(Image.new("RGBA", c.size, (14, 30, 44, int(120 * min(1, i / 5)))))
        tsc = ease_out_back(min(1, i / 8)) * {"16x9": 1.0, "1x1": 0.85, "9x16": 0.95}[fmt] * (1 + 0.5 * max(0, 1 - i / 4))
        tcy = oh * (0.46 if fmt != "9x16" else 0.42)
        paste_center(c, ICON.resize((230, 230)), ow / 2, tcy - 190 * tsc, tsc)
        paste_center(c, TITLE, ow / 2, tcy + 40 * tsc, tsc)
        if i > 12:
            paste_center(c, pill("THE 0.5 UPDATE", int(52 * sc), color=(214, 96, 52)), ow / 2, tcy + 215 * tsc,
                         ease_out_back(min(1, (i - 12) / 7)))
        if i > 26:
            paste_center(c, pill("a cozy fishing game  ·  by afosh", int(34 * sc)), ow / 2, tcy + 310 * tsc, 1,
                         min(1, (i - 26) / 6))
    if fx.get("big"):
        beat = i / BEAT
        shown = [(w, b0) for w, b0 in fx["big"] if beat >= b0]
        if shown:
            c.alpha_composite(Image.new("RGBA", c.size, (8, 20, 30, 140)))
            bsize = int(200 * sc) if fmt == "16x9" else int(230 * sc)
            words = []
            for w, b0 in shown:
                age = i - b0 * BEAT
                if w.isdigit():
                    w = str(max(1, round(int(w) * min(1.0, age / 12))))
                words.append((w, age))
            layers = [big_text(w, bsize, GOLD if j == 0 else CREAM) for j, (w, _) in enumerate(words)]
            full = [big_text(w, bsize, GOLD if j == 0 else CREAM) for j, (w, _) in enumerate(fx["big"])]
            if fmt == "16x9":                                   # one line, laid out at its final width
                widths = [l.size[0] * 0.86 for l in full]
                x = ow / 2 - sum(widths) / 2
                pos = []
                for wdt in widths:
                    pos.append((x + wdt / 2, center_y(fmt)))
                    x += wdt
            else:                                               # stacked
                step = bsize * 1.05
                pos = [(ow / 2, center_y(fmt) + (j - 1) * step) for j in range(len(full))]
            for j, (lay, (w, age)) in enumerate(zip(layers, words)):
                slam = 1.0 + 0.8 * max(0.0, 1 - age / 6) ** 2
                paste_center(c, lay, pos[j][0], pos[j][1], slam, min(1.0, 0.35 + age / 4))
    if fx.get("slam"):
        slam = 1.0 + 1.2 * max(0.0, 1 - i / 5) ** 2
        paste_center(c, big_text(fx["slam"], int(230 * sc)), ow / 2, center_y(fmt), slam)
    if fx.get("count"):
        pre, target, post = fx["count"]
        k2 = min(1.0, i / 16)
        val = int(round(target * (1 - (1 - k2) ** 3)))
        pop = 1.0 + 0.35 * max(0.0, 1 - abs(i - 17) / 4)
        paste_center(c, big_text("%s%d%s" % (pre, val, post), int(150 * sc)), ow / 2, count_y(fmt), pop)
    if s.get("label"):
        lab = pill(s["label"], 44 if fmt == "16x9" else 40, color=(59, 44, 32))
        paste_center(c, lab, lab.size[0] / 2 + 50, 70 if fmt != "9x16" else 470, ease_out_back(min(1, i / 6)))
    if fmt == "9x16" and tag != "title":
        paste_center(c, FOOTER, ow / 2, 1800)                   # brand footer under the gameplay window
    if s.get("caption"):
        layer = text_layer(s["caption"], size, 99 if fx.get("hold") else i, mw)
        paste_center(c, layer, cx, cy)
    if tag == "platforms" and i > 20:
        plats = ["Browser", "Windows", "Android", "Linux"]
        for j, ptxt in enumerate(plats):
            kk = (i - 20 - j * 5) / 8
            if kk <= 0:
                continue
            p = pill(ptxt, 38 if fmt == "16x9" else 34)
            if fmt == "9x16":
                px, py = ow / 2 + (j % 2 - 0.5) * 300, 1580 + (j // 2) * 80
            else:
                gap = 300 if fmt == "16x9" else 250
                px, py = ow / 2 + (j - 1.5) * gap, oh - 260 if fmt == "16x9" else oh - 250
            paste_center(c, p, px, py, ease_out_back(min(1, kk)))
    # cut effects
    if fx.get("whip") and i < 5:
        c = whip_blur(c, 1 + 14 * (1 - i / 5) ** 2)
    if fx.get("chroma") and i < 7:
        c = rgb_split(c, int(16 * (1 - i / 7)))
    if fx.get("flash") and i < 5:
        flash(c, 0.9 * (1 - i / 5))
    if tag == "title" and i < 6:
        flash(c, 1 - i / 6)
    if fx.get("blackout") and i >= s["n"] - fx["blackout"]:
        flash(c, (i - (s["n"] - fx["blackout"]) + 1) / fx["blackout"], (0, 0, 0))
    return c


END_BG = read_frames(marks["hero"][0]["f"], 1)[0]       # clean gameplay behind the end card


def end_card(fmt, i):
    ow, oh = FORMATS[fmt]
    bg = camera(END_BG, 1.0 + 0.04 * i / 270, (W * 0.45, H * 0.5), ow, oh).filter(ImageFilter.GaussianBlur(14)).convert("RGBA")
    bg.alpha_composite(Image.new("RGBA", bg.size, (233, 220, 196, 215)))
    s = {"16x9": 1.0, "1x1": 0.8, "9x16": 1.0}[fmt]
    top = oh * {"16x9": 0.2, "1x1": 0.2, "9x16": 0.28}[fmt]
    paste_center(bg, ICON.resize((int(260 * s), int(260 * s))), ow / 2, top, ease_out_back(min(1, i / 10)))
    paste_center(bg, TITLE, ow / 2, top + 250 * s, ease_out_back(min(1, max(0, i - 4) / 10)) * s * 0.9)
    f = font(int(72 * s), 700)
    if i > 14:
        layer = Image.new("RGBA", (ow, int(110 * s)), (0, 0, 0, 0))
        ImageDraw.Draw(layer).text((ow / 2, 55 * s), "Play free now", font=f, fill=BROWN, anchor="mm")
        paste_center(bg, layer, ow / 2, top + 440 * s, 1, min(1, (i - 14) / 6))
    rows = [("Browser & phone", "iiafosh.github.io/fosh-and-fish"), ("Windows · Android · Linux", "github.com/iiafosh/fosh-and-fish")]
    for j, (k_, v) in enumerate(rows):
        kk = (i - 22 - j * 6) / 9
        if kk <= 0:
            continue
        if fmt == "16x9":
            box_w, fs = 1300, 34
        else:
            box_w, fs = 960, 30
        row = Image.new("RGBA", (box_w, int(fs * 2.6) if fmt == "16x9" else int(fs * 3.6)), (0, 0, 0, 0))
        d = ImageDraw.Draw(row)
        d.rounded_rectangle((2, 2, row.size[0] - 3, row.size[1] - 3), 34, fill=(251, 245, 232, 255), outline=TEAL + (255,), width=4)
        if fmt == "16x9":
            d.text((40, row.size[1] / 2), k_, font=font(fs, 650), fill=TEAL, anchor="lm")
            d.text((box_w - 40, row.size[1] / 2), v, font=font(fs, 550), fill=BROWN, anchor="rm")
        else:
            d.text((box_w / 2, row.size[1] * 0.32), k_, font=font(fs, 650), fill=TEAL, anchor="mm")
            d.text((box_w / 2, row.size[1] * 0.7), v, font=font(fs, 550), fill=BROWN, anchor="mm")
        y = top + (560 if fmt == "16x9" else 540) * s + j * (row.size[1] + 22)
        x_off = (1 - ease_out_back(min(1, kk))) * 80
        paste_center(bg, row, ow / 2 + x_off, y, 1, min(1, kk * 1.5))
    if i > 50:
        layer = Image.new("RGBA", (ow, 60), (0, 0, 0, 0))
        ImageDraw.Draw(layer).text((ow / 2, 30), "0.5 beta  ·  made by afosh  ·  tell me what to add next!", font=font(30, 500),
                                   fill=(120, 96, 70), anchor="mm")
        paste_center(bg, layer, ow / 2, oh - 70, 1, min(1, (i - 50) / 10))
    flash(bg, 0.8 * (1 - i / 5))
    fade = max(0, (i - (8 * BEAT + 10)) / 20)
    if fade > 0:
        bg.alpha_composite(Image.new("RGBA", bg.size, (233, 220, 196, int(255 * min(1, fade)))))
    return bg


# --------------------------------------------------------------- audio
def read_wav(path):
    with wave.open(path) as w:
        return np.frombuffer(w.readframes(w.getnframes()), np.int16).reshape(-1, 2).astype(np.float32) / 32768


def build_audio():
    raw = subprocess.run([FF, "-loglevel", "error", "-i", os.path.join(WORK, "reel.avi"), "-vn", "-f", "s16le",
                          "-ac", "2", "-ar", str(SR), "-"], capture_output=True, check=True).stdout
    game = np.frombuffer(raw, np.int16).reshape(-1, 2).astype(np.float32) / 32768
    mus = read_wav(os.path.join(WORK, "music.wav"))
    n = int((TOTAL / FPS + 1.5) * SR)
    out = np.zeros((n, 2), np.float32)
    m = min(n, len(mus))
    out[:m] += mus[:m] * 0.8
    wsh = music.whoosh(0.4)[:, None] * np.ones((1, 2))
    hit = (music.kick(0.4) * 0.9 + music.noise_hit(0.4, 0.06, hp=0.8) * 0.5)[:, None] * np.ones((1, 2))

    def add(sig, at, gain):
        a = max(0, at)
        seg = sig[:max(0, min(len(sig), n - a))]
        out[a:a + len(seg)] += seg * gain

    t = 0
    for s in shots:
        dur = s["n"] / FPS
        a = int(t / FPS * SR)
        if s.get("src") is not None:
            g0 = int(s["src"] / FPS * SR)
            seg = game[g0:g0 + int(dur * SR)]
            fade = np.minimum(1, np.minimum(np.arange(len(seg)), np.arange(len(seg))[::-1]) / 480.0)[:, None]
            add(seg * fade, a, s["fx"].get("game", 0.5))
        if s.get("whoosh"):
            add(wsh, a - int(0.25 * SR), 0.35)
        for hf in s["fx"].get("hits", []):
            add(hit, a + int(hf / FPS * SR), 0.5)
        t += s["n"]
    out = np.tanh(out * 1.1) / np.tanh(1.1)
    path = os.path.join(WORK, "mix.wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(out, -1, 1) * 32767).astype(np.int16).tobytes())
    return path


# --------------------------------------------------------------- render
def render(fmts):
    audio = build_audio()
    os.makedirs(OUT, exist_ok=True)
    procs = {}
    for fmt in fmts:
        ow, oh = FORMATS[fmt]
        path = os.path.join(OUT, f"fosh-and-fish-0.5-yt-{fmt}.mp4")
        procs[fmt] = subprocess.Popen(
            [FF, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{ow}x{oh}", "-r", str(FPS),
             "-i", "-", "-i", audio,
             "-af", "highshelf=f=7000:g=-4,equalizer=f=3000:t=q:w=1:g=2,loudnorm=I=-14:TP=-1.5:LRA=9",
             "-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-profile:v", "high",
             "-color_range", "tv", "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-shortest", "-movflags", "+faststart", path],
            stdin=subprocess.PIPE)
    frame_no = 0
    for si, s in enumerate(shots):
        if s.get("src") is not None:
            idx = src_index(s)
            src = read_frames(s["src"], idx[-1] + 1)
        for i in range(s["n"]):
            img = src[idx[i]] if s.get("src") is not None else None
            for fmt in fmts:
                procs[fmt].stdin.write(draw_frame(fmt, s, i, img).convert("RGB").tobytes())
            frame_no += 1
        print(f"shot {si + 1}/{len(shots)} done ({frame_no}/{TOTAL})", flush=True)
    for p in procs.values():
        p.stdin.close()
        p.wait()


# ------------------------------------------------------------ thumbnail
def thumbnail():
    """1280x720 YouTube thumbnail: the gold boat up close, the wordmark and a big 0.5 UPDATE."""
    tw, th = 1280, 720
    b = mk("boat_Gold_Boat")
    frame = read_frames(b["f"] + 8 + FRAME_OFFSET, 1)[0]
    c = camera(frame, 2.0, (b["boat"][0] - 140, b["boat"][1] - 20), tw, th).convert("RGBA")
    c.alpha_composite(vignette((tw, th)))
    shade = Image.linear_gradient("L").rotate(-90).resize((tw, th)).point(lambda p: int(min(255, p * 1.3) * 0.8))
    dark = Image.new("RGBA", (tw, th), (10, 22, 34, 0))
    dark.putalpha(shade)
    c.alpha_composite(dark)                                   # darker on the left for the text
    paste_center(c, title_art(0.62), 330, 120)
    paste_center(c, big_text("0.5", 250), 300, 345)
    paste_center(c, big_text("UPDATE", 130, CREAM), 330, 545)
    paste_center(c, pill("17 NEW BOATS", 34, color=(214, 96, 52)), 1060, 80)
    paste_center(c, pill("ONLINE + MINI-GAME", 30), 1060, 640)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "fosh-and-fish-0.5-yt-thumbnail.png")
    c.convert("RGB").save(path)
    print("thumbnail", path)


if __name__ == "__main__":
    args = [a for a in sys.argv[3:] if not a.startswith("--")]
    if "--thumb" in sys.argv:
        thumbnail()
    if "--thumb-only" not in sys.argv:
        render(args[0].split(",") if args else list(FORMATS))

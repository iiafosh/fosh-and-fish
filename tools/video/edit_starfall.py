"""The fosh&fish 1.0 ad "STARFALL" (vertical 9:16, 24 s, made like a mobile-game ad: the payoff first, then
how you get it, then PLAY): the Blender frames (tools/blender/starfall_video.py) with the hits (shake, zoom,
flashes, speed lines) and the ad's layer drawn on top: the hook line, captions, a hand that taps to cast and
holds to reel (the game's own controls), the in-game shiny card, the collection grid, three event bands cut
from the Leviathan trailer, and the end card (PLAY FREE, tapped), with the soundtrack
(tools/video/music_starfall.py). Captions as in the KABOOM edit (tools/video/edit_boom.py).
No ratings, reviews or download counts: there are none to show yet.

    python tools/video/edit_starfall.py [--preview F,F,...]

Needs build/starfall/frames/0000-0719.png, build/boom10/frames (the event bands) and build/starfall/music.wav.
Writes build/starfall/fosh-and-fish-1.0-ad-starfall-9x16.mp4 and -cover.jpg (or preview_####.jpg).
"""
import math
import os
import subprocess
import sys

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(__file__))
import starfall_timeline as T  # noqa: E402
import edit_boom as EB  # noqa: E402
from edit_boom import back_out, brand_text, ease_out, pill, place, pop  # noqa: E402

ROOT = EB.ROOT
WORK = os.path.join(ROOT, "build", "starfall")
FRAMES = os.path.join(WORK, "frames")
B10_FRAMES = os.path.join(ROOT, "build", "boom10", "frames")
SHINY = os.path.join(ROOT, "assets", "vf", "shiny")
FF = imageio_ffmpeg.get_ffmpeg_exe()
W, H = T.W, T.H
DEEP, MINT, WHITE = EB.DEEP, EB.MINT, EB.WHITE
GOLD = (255, 215, 94)           # the game's shiny gold, #ffd75e
INDIGO = (99, 102, 241)         # Meteor Shower
RED = (239, 68, 68)
CARD = (27, 16, 54)             # the shiny card, #1b1036
LILAC = (196, 181, 253)         # #c4b5fd
HERO, HERO_FILE = "Hot Cod", "hot_cod.png"
SERIAL, SUPPLY = 42, 3000
TOP, SUB = 300, 432             # caption rows (clear of the apps' top bar; the bottom fifth is theirs too)

# ------------------------------------------------------------------- hits
# (frame, shake strength, zoom punch, flash, rgb split frames)
HITS = [(T.HOOK_BURST, 0.9, 0.10, 0.8, 3), (60, 0.25, 0.04, 0.45, 1), (180, 0.3, 0.04, 0.4, 1),
        (T.TAP, 0.1, 0.015, 0.0, 0), (T.BITE, 0.35, 0.03, 0.0, 1), (T.BURST, 1.0, 0.12, 1.0, 4),
        (T.HANG, 0.2, 0.03, 0.3, 0), (480, 0.2, 0.03, 0.5, 1), (600, 0.3, 0.04, 0.5, 1),
        (T.LOGO_FISH, 0.15, 0.02, 0.0, 0), (T.END_HIT, 0.2, 0.03, 0.25, 0)]
HITS += [(f, 0.22, 0.02, 0.12, 0) for f in (98, 122, 168)]          # the stars that land close
HITS += [(f, 0.12, 0.012, 0.0, 0) for f in T.LEAPS]
HITS += [(f, 0.2, 0.02, 0.0, 0) for f in T.LOGO_HITS[1:]]
HITS += [(f + 4, 0.25, 0.02, 0.0, 1) for f in T.EXTRA_IN]

NOISE = np.random.default_rng(5).normal(size=(T.TOTAL + 64, 3))
for _ in range(2):
    NOISE[1:-1] = (NOISE[:-2] + NOISE[1:-1] * 2 + NOISE[2:]) / 4


def camera_fx(f):
    """-> (dx, dy, rot_deg, zoom, flash 0..1, rgb split px); reeling in shakes all the way to the burst"""
    dx = dy = rot = 0.0
    zoom, flash, split = 1.0, 0.0, 0
    for hf, sh, zp, fl, rs in HITS:
        t = f - hf
        if t < 0 or t > 40:
            continue
        k = math.exp(-t / 7.0) * sh
        dx += NOISE[f, 0] * 26 * k
        dy += NOISE[f, 1] * 22 * k
        rot += NOISE[f, 2] * 1.4 * k
        zoom += zp * math.exp(-t / 3.5)
        if fl:
            flash = max(flash, fl * max(0.0, 1 - t / 4.0) ** 1.5)
        if t < rs:
            split = max(split, int(10 * sh * (1 - t / max(1, rs))))
    if T.REEL <= f < T.BURST:
        k = 0.1 + 0.3 * (f - T.REEL) / float(T.BURST - T.REEL)
        dx += NOISE[f, 0] * 26 * k
        dy += NOISE[f, 1] * 22 * k
    return dx, dy, rot, zoom, flash, split


def speed_at(f):
    if T.HOOK_BURST <= f < 30:
        return 0.6 * (1 - (f - T.HOOK_BURST) / 26.0)
    if T.REEL + 6 <= f < T.BURST:
        return 0.25 + 0.6 * (f - T.REEL - 6) / float(T.BURST - T.REEL - 6)
    if T.BURST <= f < T.BURST + 14:
        return 0.8 * (1 - (f - T.BURST) / 14.0)
    return 0.0


def _affine(z, rot, dx, dy):
    """edit_boom._affine for the vertical frame"""
    a = math.radians(rot)
    ca, sa = math.cos(a) / z, math.sin(a) / z
    cx, cy = W / 2, H / 2
    ox, oy = cx + dx, cy + dy
    return (ca, sa, cx - ca * ox - sa * oy, -sa, ca, cy + sa * ox - ca * oy)


def picture(f):
    im = Image.open(os.path.join(FRAMES, "%04d.png" % f)).convert("RGB")
    dx, dy, rot, zoom, flash, split = camera_fx(f)
    im = im.transform(im.size, Image.AFFINE, _affine(zoom * 1.04, rot, dx, dy), resample=Image.BICUBIC)
    if split:
        r, g, b = im.split()
        im = Image.merge("RGB", (ImageChops.offset(r, split, 0), g, ImageChops.offset(b, -split, 0)))
    im = im.convert("RGBA")
    im.alpha_composite(EB.vignette(im.size))
    EB.speed_lines(im, f, speed_at(f))
    if flash > 0:
        im = Image.blend(im, Image.new("RGBA", im.size, (255, 255, 255, 255)), min(1.0, flash))
    return im


# --------------------------------------------------------------- captions
def fit(im, s, frac=0.92):
    return min(s, W * frac / max(1, im.width)) if s else s


def cap(c, f, text, size, edge, y, f_on, f_off, s_mul=1.0):
    s, a = pop(f, f_on, f_off)
    if a > 0:
        im = brand_text(text, size, edge=edge)
        place(c, im, W / 2, y, fit(im, s * s_mul), a)


def beat_pulse(f):
    """a little kick on every beat"""
    return 1.0 + 0.06 * math.exp(-((f % 15) / 3.0))


def captions(c, f):
    # 0:00 the hook (on screen from the first frame: it's the thumbnail too), bumped by the burst
    bump = 1.0 + 0.16 * math.exp(-(f - T.HOOK_BURST) / 3.0) if f >= T.HOOK_BURST else 1.0
    cap(c, f, "ONLY 3,000 EXIST", 124, GOLD, TOP, -8, 58, bump)
    cap(c, f, "OF EACH SHINY FISH", 56, LILAC, SUB, 18, 58)
    # 0:02 the stars: the Meteor Shower (in the game: shiny fish turn up five times as often)
    cap(c, f, "METEOR SHOWER", 112, INDIGO, TOP, 64, 178)
    cap(c, f, "SHINIES 5x MORE OFTEN", 56, GOLD, SUB, 78, 178)
    # 0:06 the shinies
    cap(c, f, "RARE SHINY FISH", 116, GOLD, TOP, 184, 298)
    cap(c, f, "EVERY ONE IS NUMBERED", 56, LILAC, SUB, 198, 298)
    # 0:10 the catch
    cap(c, f, "TAP TO CAST", 120, MINT, TOP, T.TAP - 6, T.BITE - 2)
    cap(c, f, "A BITE!", 120, RED, TOP, T.BITE, T.REEL)
    cap(c, f, "REEL IT IN!", 124, GOLD, TOP, T.REEL, T.BURST, beat_pulse(f))


# ------------------------------------------------------------------ the hand
def _hand():
    """a white cartoon glove pointing up (drawn at 2x, then halved), its fingertip at HAND_TIP"""
    S = 2
    w, h = 300, 420
    im = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ol = 9

    def box(b, grow=0):
        return tuple(v * S + (-grow if i < 2 else grow) * S for i, v in enumerate(b))

    finger = (112, 14, 172, 222)
    palm = (64, 160, 236, 344)
    curls = [(164, 150, 214, 236), (200, 172, 246, 250), (230, 198, 270, 262)]
    thumb = (26, 188, 104, 282)
    cuff = (78, 330, 222, 396)
    # one dark outline round the whole glove, then the white on top
    for b, r in [(finger, 30), (palm, 54), (cuff, 18)] + [(b, 24) for b in curls]:
        d.rounded_rectangle(box(b, ol), (r + ol) * S, fill=DEEP)
    d.ellipse(box(thumb, ol), fill=DEEP)
    d.rounded_rectangle(box(palm), 54 * S, fill=WHITE)
    for b in curls[::-1]:                                     # the curled fingers, each with its own line
        d.rounded_rectangle(box(b), 24 * S, fill=WHITE, outline=DEEP, width=5 * S)
    d.rounded_rectangle(box(finger), 30 * S, fill=WHITE)
    d.ellipse(box(thumb), fill=WHITE, outline=DEEP, width=5 * S)
    d.rounded_rectangle(box(cuff), 18 * S, fill=MINT, outline=DEEP, width=6 * S)
    d.line([(124 * S, 60 * S), (124 * S, 120 * S)], fill=(220, 232, 240), width=8 * S)   # a little shine
    im = im.resize((w, h), Image.LANCZOS)
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    sh.putalpha(im.getchannel("A").point(lambda v: int(v * 0.35)))
    out = Image.new("RGBA", (w + 30, h + 30), (0, 0, 0, 0))
    out.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8)), (16, 20))
    out.alpha_composite(im, (0, 0))
    out = out.rotate(22, Image.BICUBIC, expand=True)          # leaning in from the bottom right
    a = math.radians(22)                                      # where the fingertip went
    cx, cy = (w + 30) / 2, (h + 30) / 2
    tx, ty = 142 - cx, 16 - cy
    nx, ny = tx * math.cos(a) + ty * math.sin(a), -tx * math.sin(a) + ty * math.cos(a)
    return out, (out.width / 2 + nx, out.height / 2 + ny)


HAND, HAND_TIP = _hand()


def ripple(c, x, y, t):
    """rings spreading from a tap, t = frames since it"""
    if t < 0 or t > 18:
        return
    lay = Image.new("RGBA", c.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for k in (0, 6):
        u = (t - k) / 12.0
        if 0 <= u <= 1:
            r = 24 + 120 * ease_out(u, 2)
            d.ellipse((x - r, y - r, x + r, y + r), outline=(255, 255, 255, int(230 * (1 - u))), width=10)
    c.alpha_composite(lay)


def hand(c, x, y, press=0.0, alpha=1.0):
    """the hand with its fingertip on (x, y); press 0..1 squashes it onto the screen"""
    s = 1.0 - 0.08 * press
    tx, ty = HAND_TIP
    im = HAND if s == 1.0 else HAND.resize((int(HAND.width * s), int(HAND.height * s)), Image.BICUBIC)
    if alpha < 1.0:
        im = im.copy()
        im.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
    c.alpha_composite(im, (int(x - tx * s), int(y - ty * s + 8 * press)))


def slide(f, f_in, f_out, x, y, dur=8):
    """where the hand is while it comes in from the bottom right, and goes back out"""
    if f < f_in or f >= f_out + dur:
        return None
    if f < f_in + dur:
        k = 1 - ease_out((f - f_in) / float(dur), 3)
    elif f >= f_out:
        k = ((f - f_out) / float(dur)) ** 2
    else:
        k = 0.0
    return x + 520 * k, y + 760 * k


def taps(c, f):
    # TAP TO CAST: on the glow, where the bobber goes
    p = slide(f, T.TAP - 14, T.TAP + 8, 400, 1060)
    if p:
        press = 1.0 if T.TAP <= f < T.TAP + 3 else 0.0
        hand(c, p[0], p[1], press)
        ripple(c, 400, 1060, f - T.TAP)
    # REEL IT IN: hold (touch anywhere) while the reel ring fills
    rx, ry = 560, 1380
    p = slide(f, T.REEL - 10, T.BURST, rx, ry)
    if p:
        hold = T.REEL <= f < T.BURST
        if hold:
            reel_ring(c, f, rx, ry)
        hand(c, p[0], p[1], 1.0 if hold else 0.0)


def reel_ring(c, f, x, y):
    """the reel ring round the finger, filling up (as in the game's mini-game)"""
    u = min(1.0, (f - T.REEL) / float(T.BURST - 4 - T.REEL))
    r = 132
    lay = Image.new("RGBA", (2 * r + 60, 2 * r + 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    o = 30
    d.ellipse((o - 6, o - 6, o + 2 * r + 6, o + 2 * r + 6), outline=DEEP + (200,), width=34)
    d.ellipse((o, o, o + 2 * r, o + 2 * r), outline=(255, 255, 255, 70), width=22)
    if u > 0:
        d.arc((o, o, o + 2 * r, o + 2 * r), -90, -90 + 360 * u, fill=GOLD + (255,), width=22)
    if u >= 1.0:                                              # full: it flashes
        d.ellipse((o, o, o + 2 * r, o + 2 * r), outline=(255, 255, 255, 255), width=22)
    s = 1.0 + (0.12 * math.exp(-(f - (T.BURST - 4)) / 2.0) if f >= T.BURST - 4 else 0.0)
    place(c, lay, x, y, s * beat_pulse(f) ** 0.5)
    place(c, brand_text("HOLD!", 52, edge=GOLD), x - 10, y - r - 70, beat_pulse(f))


# ------------------------------------------------------------ the shiny card
def commas(n):
    return "{:,}".format(n)


_card = {}


def shiny_card(serial):
    """the game's shiny card (vf_v1_ui.celebrate): dark purple, a gold rim, the icon, SHINY!, the name, the number"""
    if serial in _card:
        return _card[serial]
    w, h, pad = 960, 330, 40
    im = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    glow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle((pad, pad, pad + w, pad + h), 44, fill=GOLD + (150,))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(22)))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((pad, pad, pad + w, pad + h), 44, fill=CARD + (245,), outline=GOLD, width=6)
    icon = Image.open(os.path.join(SHINY, HERO_FILE)).convert("RGBA").resize((268, 268), Image.LANCZOS)
    im.alpha_composite(icon, (pad + 26, pad + (h - 268) // 2))
    x = pad + 26 + 268 + 22
    room = pad + w - 30 - x
    name = "Shiny " + HERO
    nf = EB.font(78)
    while nf.getlength(name) > room and nf.size > 40:
        nf = EB.font(nf.size - 2)
    d.text((x, pad + 34), "SHINY!", font=EB.font(46), fill=GOLD)
    d.text((x, pad + 88), name, font=nf, fill=WHITE)
    d.text((x, pad + 184), "No. %04d of %s" % (serial, commas(SUPPLY)), font=EB.font(52), fill=(255, 255, 255))
    d.text((x, pad + 250), "%s left in the world" % commas(SUPPLY - serial), font=EB.font(40, False), fill=LILAC)
    _card[serial] = im
    return im


def card(c, f):
    f_on = T.HANG + 4
    if not f_on <= f < 480:
        return
    s, a = pop(f, f_on, 480, out=5)
    k = min(1.0, max(0.0, (f - (T.HANG + 6)) / 18.0))         # the number rolls up to ours (ticks in the music)
    serial = max(1, int(round(SERIAL * ease_out(k, 2))))
    place(c, shiny_card(serial), W / 2, 1300, s, a)


# --------------------------------------------------------- the collection
NAMES = sorted(n for n in os.listdir(SHINY) if n.endswith(".png"))
TILE, GAP = 172, 16
_tiles = {}


def tile(name, lit):
    k = (name, lit)
    if k not in _tiles:
        im = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle((2, 2, TILE - 3, TILE - 3), 30, fill=(CARD if lit else (16, 12, 40)) + (235,),
                            outline=GOLD if lit else (90, 84, 140), width=5)
        icon = Image.open(os.path.join(SHINY, name)).convert("RGBA").resize((150, 150), Image.LANCZOS)
        if not lit:                                           # not caught yet: a silhouette
            sil = Image.new("RGBA", icon.size, (52, 44, 100, 255))
            sil.putalpha(icon.getchannel("A"))
            icon = sil
        im.alpha_composite(icon, ((TILE - 150) // 2, (TILE - 150) // 2))
        _tiles[k] = im
    return _tiles[k]


def collection(c, f):
    if not 480 <= f < 540:
        return
    s, a = pop(f, 480, 540, out=5)
    panel = Image.new("RGBA", (W - 70, 1210), (0, 0, 0, 0))
    ImageDraw.Draw(panel).rounded_rectangle((0, 0, panel.width - 1, panel.height - 1), 52, fill=(10, 6, 34, 200),
                                            outline=GOLD + (140,), width=4)
    place(c, panel, W / 2, 935, s, a)
    cap(c, f, "COLLECT ALL 20", 104, GOLD, 440, 482, 540)
    cap(c, f, "3,000 OF EACH  ·  EVERY ONE NUMBERED", 40, LILAC, 1438, 500, 540)
    for i, name in enumerate(NAMES):
        ts, ta = pop(f, T.GRID + 2 * i, 540, out=5)
        if ta <= 0:
            continue
        lit = name == HERO_FILE or f >= 522 + i * 0.8
        x = W / 2 + (i % 5 - 2) * (TILE + GAP)
        y = 1000 + (i // 5 - 1.5) * (TILE + GAP)
        place(c, tile(name, lit), x, y, ts, ta)
        flip = f - (522 + i * 0.8)
        if name != HERO_FILE and 0 <= flip < 3:               # a white blink as it lights up
            bl = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
            ImageDraw.Draw(bl).rounded_rectangle((2, 2, TILE - 3, TILE - 3), 30, fill=(255, 255, 255, int(200 * (1 - flip / 3))))
            place(c, bl, x, y, ts, ta)


# --------------------------------------------------------------- the events
EVENT_COLS = [(255, 182, 39), (20, 184, 166), RED]
BW, BH = 1000, 420
_mask = None


def band(src_f, color, label, sub):
    global _mask
    im = Image.open(os.path.join(B10_FRAMES, "%04d.png" % src_f)).convert("RGB").resize((BW, int(BW * 9 / 16)),
                                                                                         Image.BILINEAR)
    top = (im.height - BH) // 2
    im = im.crop((0, top, BW, top + BH)).convert("RGBA")
    if _mask is None:
        _mask = Image.new("L", (BW, BH), 0)
        ImageDraw.Draw(_mask).rounded_rectangle((0, 0, BW - 1, BH - 1), 34, fill=255)
    im.putalpha(_mask)
    out = Image.new("RGBA", (BW + 40, BH + 40), (0, 0, 0, 0))
    sh = Image.new("RGBA", out.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((20, 26, 20 + BW, 26 + BH), 34, fill=(0, 0, 0, 120))
    out.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10)))
    out.alpha_composite(im, (20, 20))
    ImageDraw.Draw(out).rounded_rectangle((20, 20, 20 + BW - 1, 20 + BH - 1), 34, outline=WHITE, width=6)
    p = pill(label, 44, bg=color)
    out.alpha_composite(p, (46, 44))
    s = brand_text(sub, 46, edge=color)
    out.alpha_composite(s, (20 + BW - s.width - 14, 20 + BH - s.height - 6))
    return out


def events(c, f):
    if not T.EXTRAS[0] <= f < T.EXTRAS[1]:
        return
    lay = Image.new("RGBA", c.size, (5, 4, 26, 110))             # the night sky, dimmed behind the bands
    c.alpha_composite(lay)
    cap(c, f, "+ AN EVENT EVERY 10 MINUTES", 60, MINT, 250, T.EXTRAS[0] - 2, T.EXTRAS[1])
    for i, ((src, label, sub), f_in, col) in enumerate(zip(T.EXTRA_SHOTS, T.EXTRA_IN, EVENT_COLS)):
        if f < f_in:
            continue
        u = min(1.0, (f - f_in) / 9.0)
        dx = (1 - back_out(u)) * 1150 * (-1 if i % 2 == 0 else 1)
        a = min(1.0, (T.EXTRAS[1] - f) / 4.0)
        place(c, band(src + (f - f_in), col, label, sub), W / 2 + dx, 570 + i * 450, 1.0, a)


# ---------------------------------------------------------------- end card
def button(press):
    im = Image.new("RGBA", (760, 230), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = 20, 14, 740, 194
    dy = int(14 * press)
    d.rounded_rectangle((x0, y0 + 20, x1, y1 + 20), 90, fill=(176, 120, 0), outline=DEEP, width=7)
    d.rounded_rectangle((x0, y0 + dy, x1, y1 + dy), 90, fill=(255, 210, 63), outline=DEEP, width=7)
    d.rounded_rectangle((x0 + 34, y0 + 16 + dy, x1 - 34, y0 + 70 + dy), 40, fill=(255, 236, 150))
    t = brand_text("PLAY FREE", 96, fill=WHITE, edge=(255, 160, 30), depth=7)
    im.alpha_composite(t, ((im.width - t.width) // 2, (y0 + y1) // 2 + dy - t.height // 2 + 4))
    return im


def end_card(c, f):
    if f < 636:
        return
    s, a = pop(f, 638, 99999)
    place(c, pill("THE 1.0 UPDATE", 58, bg=GOLD), W / 2, 1045, s, a)
    cap(c, f, "SHINY FISH  ·  EVENTS  ·  BOSS FISH", 50, INDIGO, 1165, 646, 99999)
    bs, ba = pop(f, T.END_HIT - 5, 99999)
    if ba > 0:
        press = 1.0 if any(t <= f < t + 4 for t in T.END_TAPS) else 0.0
        pulse = 1.0 + 0.035 * math.sin((f - T.END_HIT) * 2 * math.pi / 15.0) if f > T.END_HIT + 6 else 1.0
        place(c, button(press), W / 2, 1350, bs * pulse, ba)
    us, ua = pop(f, T.END_HIT + 2, 99999)
    if ua > 0:
        url = brand_text("foshfish.xyz", 50, edge=MINT, depth=3)
        place(c, url, W / 2, 1510, us, ua)
    p = slide(f, T.END_TAPS[0] - 12, 99999, 700, 1365)
    if p:
        t = min((f - t0 for t0 in T.END_TAPS if f >= t0), default=-1)
        press = 1.0 if 0 <= t < 4 else 0.0
        hand(c, p[0], p[1], press)
        ripple(c, 700, 1365, t)


# ------------------------------------------------------------------ frames
def frame(f):
    c = picture(f)
    captions(c, f)
    taps(c, f)
    card(c, f)
    collection(c, f)
    events(c, f)
    end_card(c, f)
    return c.convert("RGB")


AUDIO = ["-af", "loudnorm=I=-14:TP=-1.5:LRA=9,alimiter=limit=0.89", "-c:a", "aac", "-b:a", "256k", "-ar", "48000"]


def encoder(path, audio):
    """the music comes out at the apps' -14 LUFS (it's mixed hot: -9 LUFS, true peaks over 0 dB)"""
    return subprocess.Popen([FF, "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H),
                             "-r", str(T.FPS), "-i", "-", "-i", audio,
                             "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p"] + AUDIO +
                            ["-shortest", "-movflags", "+faststart", path], stdin=subprocess.PIPE)


def main(args):
    if "--preview" in args:
        for f in [int(x) for x in args[args.index("--preview") + 1].split(",")]:
            frame(f).save(os.path.join(WORK, "preview_%04d.jpg" % f), quality=90)
        return
    out = os.path.join(WORK, "fosh-and-fish-1.0-ad-starfall-9x16.mp4")
    enc = encoder(out, os.path.join(WORK, "music.wav"))
    for f in range(T.TOTAL):
        enc.stdin.write(frame(f).tobytes())
        if f % 60 == 0:
            print("frame", f, flush=True)
    enc.stdin.close()
    enc.wait()
    frame(40).save(os.path.join(WORK, "fosh-and-fish-1.0-ad-starfall-cover.jpg"), quality=92)   # the hero + the hook
    print("done:", out)


if __name__ == "__main__":
    main(sys.argv[1:])

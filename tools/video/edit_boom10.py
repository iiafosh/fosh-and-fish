"""The fosh&fish 1.0 trailer, "THE LEVIATHAN": cuts the Blender frames (tools/blender/boom10_video.py)
together with the soundtrack (tools/video/music10.py), adds the hits (camera shake, zoom punches, white
flashes, an RGB split), the comic words, speed lines, the captions and the Leviathan's health bar, and
encodes the MP4s. Built on the KABOOM edit (tools/video/edit_boom.py: its captions, pills and 9x16 layout).

    python tools/video/edit_boom10.py [--formats 16x9,9x16] [--thumb] [--preview F,F,...]
    python tools/video/edit_boom10.py --ads [leviathan,shiny,events]

Needs build/boom10/frames/0000-1139.png, build/boom10/overlays/word_*/ (+ KABOOM's build/boom/overlays) and
build/boom10/music.wav. Writes build/boom10/fosh-and-fish-1.0-trailer-{16x9,9x16}.mp4, the thumbnail, and
with --ads the 15-second vertical ads cut from the trailer on bar lines (picture and music together).
"""
import math
import os
import random
import subprocess
import sys
import wave

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import boom10_timeline as T  # noqa: E402
import edit_boom as EB  # noqa: E402
from edit_boom import back_out, brand_text, ease_out, pill, place, pop  # noqa: E402

ROOT = EB.ROOT
WORK = os.path.join(ROOT, "build", "boom10")
FRAMES = os.path.join(WORK, "frames")
OVERLAYS = [os.path.join(WORK, "overlays"), EB.OVERLAYS]
FF = imageio_ffmpeg.get_ffmpeg_exe()
W, H = T.W, T.H
DEEP, MINT, WHITE = EB.DEEP, EB.MINT, EB.WHITE
GOLD = (255, 204, 72)
RED = (239, 68, 68)

# ------------------------------------------------------------------- hits
# (frame, shake strength, zoom punch, flash, rgb split frames)
HITS = [(T.BREACH, 1.0, 0.12, 1.0, 4), (T.BIG_KABOOM, 1.2, 0.15, 1.0, 5), (T.LOGO_FISH, 0.15, 0.02, 0.0, 0),
        (T.FINALE_FISH, 0.15, 0.02, 0.0, 0), (T.END_HIT, 0.2, 0.03, 0.25, 0), (180, 0.3, 0.05, 0.7, 2),
        (T.SHINY_FREEZE, 0.3, 0.05, 0.6, 1), (T.HOOKED, 0.45, 0.04, 0.0, 1), (T.BOSS_JUMP + 3, 0.85, 0.08, 0.5, 2),
        (T.ROD_SPIN, 0.2, 0.03, 0.0, 0), (T.BOSS_SURFACE, 0.4, 0.05, 0.4, 1), (600, 0.3, 0.04, 0.4, 1)]
HITS += [(f, 0.22, 0.025, 0.0, 0) for f in T.LOGO_HITS[1:] + T.FINALE_HITS]
HITS += [(f, 0.4, 0.06, 0.55, 1) for _, f in T.EVENTS]
HITS += [(f, 0.45, 0.05, 0.3, 1) for f in T.RODS]
HITS += [(f, 0.25, 0.02, 0.15, 0) for f in T.METEORS]
HITS += [(f, 0.5, 0.04, 0.0, 1) for f in T.SLAPS]
HITS += [(f, 0.12, 0.012, 0.0, 0) for f in T.CHESTS]

NOISE = np.random.default_rng(5).normal(size=(T.TOTAL + 64, 3))
for _ in range(2):
    NOISE[1:-1] = (NOISE[:-2] + NOISE[1:-1] * 2 + NOISE[2:]) / 4


def camera_fx(f):
    """-> (dx, dy, rot_deg, zoom, flash 0..1, rgb split px); the reel-in build shakes all the way"""
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
    if T.REEL <= f < T.BIG_KABOOM:
        k = 0.12 + 0.3 * (f - T.REEL) / float(T.BIG_KABOOM - T.REEL)
        dx += NOISE[f, 0] * 26 * k
        dy += NOISE[f, 1] * 22 * k
    return dx, dy, rot, zoom, flash, split


# --------------------------------------------------------------- captions
EVENT_NAMES = {"golden": ("GOLDEN HOUR", "x2 MONEY", (255, 182, 39)), "frenzy": ("FISH FRENZY", "CASTS 2x FASTER", (20, 184, 166)),
               "treasure": ("TREASURE TIDE", "3x TREASURE", (168, 85, 247)), "meteor": ("METEOR SHOWER", "5x SHINY FISH", (99, 102, 241))}
ROD_NAMES = [("STARFALL ROD", (99, 102, 241)), ("PEARL ROD", (95, 224, 189)), ("LEGEND ROD", (239, 68, 68))]


def hp_at(f):
    if f < T.HOOKED:
        return 25.0
    if f < T.REEL:
        return 25.0 - 10.0 * (f - T.HOOKED) / float(T.REEL - T.HOOKED)
    if f < T.BOSS_JUMP:
        return 15.0 - 11.0 * (f - T.REEL) / float(T.BOSS_JUMP - T.REEL)
    return max(0.0, 4.0 - 4.0 * (f - T.BOSS_JUMP) / float(T.BIG_KABOOM - 4 - T.BOSS_JUMP))


def hp_bar(c, f, cx, y, scale=1.0):
    """the boss's health bar: LEVIATHAN, a red bar that drains, n / 25"""
    w, h = int(620 * scale), int(34 * scale)
    lay = Image.new("RGBA", (w + 20, h + int(70 * scale)), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    hp = hp_at(f)
    top = int(54 * scale)
    d.rounded_rectangle((10, top, 10 + w, top + h), h // 2, fill=(30, 10, 20, 230), outline=DEEP + (255,), width=4)
    fw = max(0, int((w - 8) * hp / 25.0))
    if fw > 0:
        d.rounded_rectangle((14, top + 4, 14 + fw, top + h - 4), (h - 8) // 2, fill=RED + (255,))
    lay.alpha_composite(brand_text("LEVIATHAN", int(40 * scale), edge=RED, depth=4), (10, 0))
    num = brand_text("%d / 25" % int(math.ceil(hp)), int(34 * scale), edge=RED, depth=3)
    lay.alpha_composite(num, (w + 10 - num.width, 4))
    place(c, lay, cx, y, 1.0, 1.0)


def captions(c, f, layout):
    tall = layout == "9x16"
    cw, ch = c.size
    band_top, band_h = (0, ch) if not tall else EB.layout_band(c)
    below = band_top + band_h
    k = 1.0 if not tall else 1.25

    def at_bottom(dy=0.86):
        return ch * 0.5 + band_h * 0.5 + 170 if tall else ch * dy

    if tall and 10 <= f < T.BREACH - 2:                          # (vertical) a hook above the picture
        s, a = pop(f, 10, T.BREACH - 2)
        place(c, brand_text("wait for it...", int(64 * k), edge=MINT, depth=5), cw / 2, band_top / 2 + 20, s, a)
    if tall and f >= 1026:
        s, a = pop(f, 1026, 10 ** 6)
        place(c, brand_text("cozy fishing.", int(64 * k), edge=MINT, depth=5), cw / 2, band_top / 2 - 40, s, a)
        s, a = pop(f, 1030, 10 ** 6)
        place(c, brand_text("legendary catches.", int(64 * k), edge=RED, depth=5), cw / 2, band_top / 2 + 60, s, a)
    # the calm ... and the shadow
    if 8 <= f < 64:
        txt = "just a chill day at sea..."
        n = min(len(txt), max(0, int((f - 8) / 1.1)))
        a = 1.0 if f < 60 else (64 - f) / 4.0
        if n:
            place(c, brand_text(txt[:n], int(58 * k), edge=(120, 205, 236), depth=4), cw / 2, at_bottom(0.87), 1.0, a)
    if 68 <= f < T.BREACH - 2:
        txt = "...wait. what is THAT?"
        n = min(len(txt), max(0, int((f - 68) / 1.0)))
        a = 1.0 if f < T.BREACH - 6 else (T.BREACH - 2 - f) / 4.0
        if n:
            place(c, brand_text(txt[:n], int(60 * k), edge=RED, depth=4), cw / 2, at_bottom(0.87), 1.0, a)
    # the update, under the logo
    s, a = pop(f, 216, 241)
    if s:
        place(c, pill("THE 1.0 UPDATE", int(60 * k), bg=GOLD), cw / 2, at_bottom(0.86), s, a)
    # shiny fish
    s, a = pop(f, T.SHINY_LEAPS[0] + 2, T.SHINY_FREEZE)
    if s:
        y = at_bottom(0.82)
        big = brand_text("SHINY FISH", int(118 * k), edge=GOLD, depth=10)
        place(c, big, cw / 2, y, s, a)
        place(c, brand_text("NEW IN 1.0", int(40 * k), edge=GOLD, depth=3), cw / 2, y - big.height * 0.5 * s - 6, s, a)
    s, a = pop(f, T.SHINY_FREEZE + 2, 361, out=4)
    if s:
        y = at_bottom(0.83)
        big = brand_text("ONLY 3,000", int(118 * k), edge=GOLD, depth=10)
        place(c, big, cw / 2, y, s, a)
        place(c, brand_text("OF EACH SPECIES  ·  EVERY ONE NUMBERED", int(36 * k), edge=GOLD, depth=3), cw / 2,
              y + big.height * 0.5 * s + 14, s, a)
    # the events
    s, a = pop(f, T.EVENTS[0][1] + 2, T.RODS[0] - 4)
    if s:
        y = (below + 150 if tall else 64)
        place(c, brand_text("AN EVENT EVERY 10 MINUTES", int(50 * k), edge=MINT, depth=5), cw / 2, y, s, a)
    for i, (name, f0) in enumerate(T.EVENTS):
        f1 = T.EVENTS[i + 1][1] if i + 1 < len(T.EVENTS) else 600
        s, a = pop(f, f0 + 2, f1 + 1, out=4)
        if s:
            label, sub, col = EVENT_NAMES[name]
            big = brand_text(label, int(112 * k), edge=col, depth=10)
            y = at_bottom(0.82)
            place(c, big, cw / 2, y, s, a)
            place(c, brand_text(sub, int(42 * k), edge=col, depth=3), cw / 2, y - big.height * 0.5 * s - 6, s, a)
    # the rods
    s, a = pop(f, T.RODS[0] + 2, 718)
    if s:
        y = (below + 150 if tall else 66)
        place(c, brand_text("EXCLUSIVE RODS", int(76 * k), edge=GOLD, depth=7), cw / 2, y, s, a)
    for i, ((name, col), fr) in enumerate(zip(ROD_NAMES, T.RODS)):
        s, a = pop(f, fr + 4, 718)
        if s:
            x = (0.21 + 0.29 * i) * cw
            y = at_bottom(0.93) if not tall else below - 30
            place(c, brand_text(name, int(40 * k), edge=col, depth=4), x, y, s, a)
    # the boss
    s, a = pop(f, T.BOSS_SURFACE + 2, T.HOOKED + 2)
    if s:
        y = at_bottom(0.82)
        big = brand_text("BOSS FISH!", int(120 * k), edge=RED, depth=10)
        place(c, big, cw / 2, y, s, a)
        place(c, brand_text("THE LEVIATHAN", int(42 * k), edge=RED, depth=3), cw / 2, y - big.height * 0.5 * s - 6, s, a)
    if T.BOSS_SURFACE + 6 <= f < T.BIG_KABOOM:
        a = min(1.0, (f - T.BOSS_SURFACE - 6) / 6.0)
        y = (below + 160 if tall else 74)
        hp_bar(c, f, cw / 2, y, k * a if a < 1 else k)
    s, a = pop(f, T.HOOKED + 6, T.REEL)
    if s:
        place(c, brand_text("every catch wears it down", int(58 * k), edge=RED, depth=5), cw / 2, at_bottom(0.87), s, a)
    if T.REEL + 2 <= f < T.BIG_KABOOM - 6:
        s, a = pop(f, T.REEL + 2, T.BIG_KABOOM - 6)
        beat = 1.0 + 0.08 * max(0.0, 1 - ((f - T.REEL) % 15) / 6.0)
        place(c, brand_text("REEL IT IN!", int(118 * k), edge=GOLD, depth=10), cw / 2, at_bottom(0.83), s * beat, a)
    # the end card
    if f >= 1012:
        s, a = pop(f, 1012, 10 ** 6)
        sticker = pill("NEW 1.0", int(46 * k), bg=GOLD)
        if tall:
            place(c, sticker, cw * 0.78, band_top + band_h * 0.18, s, a, rot=10)
        else:
            place(c, sticker, cw * 0.73, ch * 0.13, s, a, rot=10)
    if f >= 1024:
        s, a = pop(f, 1024, 10 ** 6)
        y0 = at_bottom(0.74) if not tall else below + 140
        place(c, pill("PLAY FREE", int(64 * k)), cw / 2, y0, s, a)
        s, a = pop(f, 1032, 10 ** 6)
        place(c, brand_text("foshfish.xyz", int(84 * k), edge=MINT, depth=7), cw / 2, y0 + 118 * k, s, a)
        s, a = pop(f, 1040, 10 ** 6)
        place(c, brand_text("Windows  ·  Android  ·  Linux  ·  Web", int(36 * k), edge=MINT, depth=3, bold=False),
              cw / 2, y0 + 200 * k, s, a)


# ------------------------------------------------------------ comic words
WORD_HITS = [("word_sploosh", T.BREACH + 1, 0.5, 0.33, 1000, -6), ("word_kaching", T.EVENTS[0][1] + 4, 0.28, 0.3, 620, -6),
             ("word_splash", T.FRENZY_LEAPS[2], 0.7, 0.28, 520, 7), ("word_shiny", T.SHINY_FREEZE, 0.76, 0.24, 600, 8),
             ("word_boom", T.METEORS[1], 0.64, 0.3, 560, -5), ("word_whoosh", T.BOSS_JUMP + 4, 0.28, 0.25, 560, -8),
             ("word_caught", T.BIG_KABOOM, 0.5, 0.45, 1150, 5)]
_ovl = {}


def overlay(name, i):
    k = (name, i)
    if k not in _ovl:
        _ovl[k] = None
        for d in OVERLAYS:
            p = os.path.join(d, name, "%04d.png" % i)
            if os.path.exists(p):
                _ovl[k] = Image.open(p).convert("RGBA")
                break
    return _ovl[k]


def words(c, f):
    for name, f0, x, y, width, tilt in WORD_HITS:
        i = f - f0 + 1
        if 1 <= i <= 34:
            im = overlay(name, i)
            if im is not None:
                place(c, im, x * W, y * H, width / 900.0, 1.0, rot=tilt)


def speed_at(f):
    if T.BREACH + 4 <= f < 172:
        return 0.7 * (1 - (f - T.BREACH - 4) / float(172 - T.BREACH - 4))
    if T.REEL + 10 <= f < T.BIG_KABOOM - 6:
        return 0.3 + 0.7 * (f - T.REEL - 10) / float(T.BIG_KABOOM - 6 - T.REEL - 10)
    return 0.0


# ------------------------------------------------------------------ frames
def picture(f):
    im = Image.open(os.path.join(FRAMES, "%04d.png" % f)).convert("RGB")
    dx, dy, rot, zoom, flash, split = camera_fx(f)
    im = im.transform(im.size, Image.AFFINE, EB._affine(zoom * 1.04, rot, dx, dy), resample=Image.BICUBIC)
    if split:
        r, g, b = im.split()
        im = Image.merge("RGB", (ImageChops.offset(r, split, 0), g, ImageChops.offset(b, -split, 0)))
    im = im.convert("RGBA")
    im.alpha_composite(EB.vignette(im.size))
    words(im, f)
    EB.speed_lines(im, f, speed_at(f))
    if flash > 0:
        im = Image.blend(im, Image.new("RGBA", im.size, (255, 255, 255, 255)), min(1.0, flash))
    return im


def frame_16x9(f, pic=None):
    im = (pic or picture(f)).copy()
    captions(im, f, "16x9")
    return im.convert("RGB")


def frame_9x16(f, pic=None):
    from PIL import ImageFilter
    pic = pic or picture(f)
    cw, ch = 1080, 1920
    c = Image.new("RGBA", (cw, ch), DEEP + (255,))
    bg = pic.resize((int(ch * 16 / 9), ch), Image.BILINEAR).crop(((int(ch * 16 / 9) - cw) // 2, 0,
                                                                  (int(ch * 16 / 9) - cw) // 2 + cw, ch))
    bg = Image.blend(bg.filter(ImageFilter.GaussianBlur(28)), Image.new("RGBA", bg.size, DEEP + (255,)), 0.45)
    c.alpha_composite(bg)
    top, bh = EB.layout_band(c)
    c.alpha_composite(pic.resize((cw, bh), Image.LANCZOS), (0, top))
    if 236 <= f < 1020:
        a = min(1.0, (f - 236) / 6.0) * min(1.0, (1020 - f) / 6.0)
        place(c, EB.LOGO, cw / 2, top / 2 + 10, 520.0 / EB.LOGO.width, a)
    captions(c, f, "9x16")
    return c.convert("RGB")


# ------------------------------------------------------------------ encode
def encoder(path, size, audio):
    return subprocess.Popen([FF, "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % size,
                             "-r", str(T.FPS), "-i", "-", "-i", audio,
                             "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p",
                             "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart", path],
                            stdin=subprocess.PIPE)


def main(args):
    fmts = ["16x9", "9x16"]
    if "--formats" in args:
        fmts = args[args.index("--formats") + 1].split(",")
    if "--preview" in args:
        for f in [int(x) for x in args[args.index("--preview") + 1].split(",")]:
            pic = picture(f)
            frame_16x9(f, pic).save(os.path.join(WORK, "preview_%04d.jpg" % f), quality=90)
            if "9x16" in fmts:
                frame_9x16(f, pic).save(os.path.join(WORK, "preview916_%04d.jpg" % f), quality=90)
        return
    music_wav = os.path.join(WORK, "music.wav")
    encs = {}
    if "16x9" in fmts:
        encs["16x9"] = encoder(os.path.join(WORK, "fosh-and-fish-1.0-trailer-16x9.mp4"), (W, H), music_wav)
    if "9x16" in fmts:
        encs["9x16"] = encoder(os.path.join(WORK, "fosh-and-fish-1.0-trailer-9x16.mp4"), (1080, 1920), music_wav)
    for f in range(T.TOTAL):
        pic = picture(f)
        if "16x9" in encs:
            encs["16x9"].stdin.write(frame_16x9(f, pic).tobytes())
        if "9x16" in encs:
            encs["9x16"].stdin.write(frame_9x16(f, pic).tobytes())
        if f % 60 == 0:
            print("frame", f, flush=True)
    for e in encs.values():
        e.stdin.close()
        e.wait()
    print("done:", ", ".join(encs))
    if "--thumb" in args:
        thumbnail()


# ------------------------------------------------------------------- ads
# 15-second vertical ads cut from the trailer on bar lines: (from, to) frame ranges, picture and music together
ADS = {"leviathan": [(0, 240), (900, 1110)],
       "shiny": [(180, 360), (540, 600), (960, 1110)],
       "events": [(180, 240), (360, 600), (960, 1110)]}
SR = 48000


def read_wav(path):
    with wave.open(path) as w:
        return np.frombuffer(w.readframes(w.getnframes()), np.int16).reshape(-1, 2).astype(np.float32) / 32768


def ads(names):
    mus = read_wav(os.path.join(WORK, "music.wav"))
    for name in names:
        segs = ADS[name]
        parts = []
        xf = int(0.015 * SR)
        for a, b in segs:
            seg = mus[int(a / T.FPS * SR):int(b / T.FPS * SR)].copy()
            seg[:xf] *= np.linspace(0, 1, xf)[:, None]
            seg[-xf:] *= np.linspace(1, 0, xf)[:, None]
            parts.append(seg)
        audio = np.concatenate(parts)
        fade = int(0.5 * SR)
        audio[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
        apath = os.path.join(WORK, "ad_%s.wav" % name)
        with wave.open(apath, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(audio, -1, 1) * 32767).astype(np.int16).tobytes())
        enc = encoder(os.path.join(WORK, "fosh-and-fish-1.0-ad-%s-9x16.mp4" % name), (1080, 1920), apath)
        n = 0
        total = sum(b - a for a, b in segs)
        for a, b in segs:
            for f in range(a, b):
                im = frame_9x16(f)
                if total - n <= 15:                                # fade to the deep sea at the very end
                    k = (total - n) / 15.0
                    im = Image.blend(Image.new("RGB", im.size, DEEP), im, k)
                enc.stdin.write(im.tobytes())
                n += 1
        enc.stdin.close()
        enc.wait()
        print("ad", name, "%.1f s" % (total / T.FPS), flush=True)


# ------------------------------------------------------------- thumbnail
def thumbnail():
    """1280x720: the Leviathan in the air above the little boat, SPLOOSH, the logo, THE 1.0 UPDATE"""
    im = Image.open(os.path.join(FRAMES, "%04d.png" % 170)).convert("RGBA")
    im.alpha_composite(EB.vignette(im.size))
    word = overlay("word_sploosh", 14)
    if word is not None:
        place(im, word, W * 0.22, H * 0.24, 0.85, 1.0, rot=-8)
    place(im, EB.LOGO, W * 0.79, H * 0.72, 0.55)
    place(im, pill("THE 1.0 UPDATE", 74, bg=GOLD), W * 0.79, H * 0.93, 1.0)
    im.convert("RGB").resize((1280, 720), Image.LANCZOS).save(os.path.join(WORK, "fosh-and-fish-1.0-thumbnail.png"))
    print("thumbnail saved")


if __name__ == "__main__":
    a = sys.argv[1:]
    if "--ads" in a:
        i = a.index("--ads")
        names = a[i + 1].split(",") if len(a) > i + 1 and not a[i + 1].startswith("--") else list(ADS)
        ads(names)
    elif "--thumb-only" in a:
        thumbnail()
    else:
        main(a)

"""The fosh&fish KABOOM video: cuts the Blender frames (tools/blender/boom_video.py) together with the
soundtrack (tools/video/music_boom.py), adds the hits (camera shake, zoom punches, white flashes, an RGB
split), the comic words, speed lines and the captions, and encodes the MP4s.

    python tools/video/edit_boom.py [OUT_DIR] [--formats 16x9,9x16] [--thumb]
    python tools/video/edit_boom.py OUT_DIR --remux build/boom/sfx.wav sfx     (same videos, another soundtrack)

Needs build/boom/frames/0000-1139.png, build/boom/overlays/word_*/ and build/boom/music.wav.
16x9 is the YouTube cut; 9x16 (Shorts / TikTok / Reels) puts the same picture in a tall frame with a
blurred copy behind it and the captions above and below.
"""
import math
import os
import random
import subprocess
import sys

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
import boom_timeline as T  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WORK = os.path.join(ROOT, "build", "boom")
FRAMES = os.path.join(WORK, "frames")
OVERLAYS = os.path.join(WORK, "overlays")
FF = imageio_ffmpeg.get_ffmpeg_exe()
W, H = T.W, T.H
FONT_BOLD = os.path.join(WORK, "Fredoka-Bold.ttf")
FONT_SEMI = os.path.join(WORK, "Fredoka-Semi.ttf")
DEEP = (11, 41, 48)
MINT = (95, 224, 189)
WHITE = (255, 255, 255)


def ease_out(t, p=3):
    t = min(1.0, max(0.0, t))
    return 1 - (1 - t) ** p


def back_out(t, s=2.0):
    t = min(1.0, max(0.0, t)) - 1
    return t * t * ((s + 1) * t + s) + 1


# ------------------------------------------------------------------- hits
# (frame, shake strength, zoom punch, flash, rgb split frames)
HITS = [(T.KABOOM, 1.0, 0.12, 1.0, 4), (T.ERUPTION, 0.75, 0.06, 0.35, 2), (T.BIG_KABOOM, 1.2, 0.15, 1.0, 5),
        (T.LOGO_FISH, 0.15, 0.02, 0.0, 0), (T.FINALE_FISH, 0.15, 0.02, 0.0, 0), (T.SURVEYOR + 6, 0.5, 0.04, 0.0, 1),
        (T.END_HIT, 0.2, 0.03, 0.25, 0), (180, 0.3, 0.05, 0.7, 2), (840, 0.35, 0.05, 0.5, 1)]
HITS += [(f, 0.22, 0.025, 0.0, 0) for f in T.LOGO_HITS[1:] + T.FINALE_HITS]
HITS += [(f, 0.4, 0.06, 0.55, 1) for _, f in T.WORLDS]
HITS += [(f, 0.45, 0.05, 0.0, 1) for f in T.SCREENS]
HITS += [(f, 0.12, 0.012, 0.0, 0) for f in T.BOAT_PASSES]

rnd_shake = np.random.default_rng(5)
NOISE = rnd_shake.normal(size=(T.TOTAL + 64, 3))
for _ in range(2):                                         # smooth it a little so shakes wobble, not jitter
    NOISE[1:-1] = (NOISE[:-2] + NOISE[1:-1] * 2 + NOISE[2:]) / 4


def camera_fx(f):
    """-> (dx, dy, rot_deg, zoom, flash 0..1, rgb split px)"""
    dx = dy = rot = 0.0
    zoom = 1.0
    flash = 0.0
    split = 0
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
    return dx, dy, rot, zoom, flash, split


# ---------------------------------------------------------------- captions
_fonts = {}


def font(size, bold=True):
    k = (size, bold)
    if k not in _fonts:
        _fonts[k] = ImageFont.truetype(FONT_BOLD if bold else FONT_SEMI, size)
    return _fonts[k]


_txt = {}


def brand_text(text, size, fill=WHITE, edge=(120, 205, 236), line=DEEP, depth=None, bold=True, shadow=True):
    """chunky caption like the logo: a white face over a coloured 3D edge, a thin dark rim round both and a
    soft shadow"""
    k = (text, size, fill, edge, line, depth, bold, shadow)
    if k in _txt:
        return _txt[k]
    f = font(size, bold)
    depth = int(size * 0.09) if depth is None else depth
    ol = max(2, int(round(size * 0.055)))
    l, t, r, b = f.getbbox(text, stroke_width=ol)
    pad = ol + depth + int(size * 0.3)
    w, h = r - l + pad * 2, b - t + pad * 2
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ox, oy = pad - l, pad - t
    if shadow:
        sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((ox, oy + depth + size * 0.05), text, font=f, fill=line + (110,),
                                stroke_width=ol, stroke_fill=line + (110,))
        im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(size * 0.09)))
    d = ImageDraw.Draw(im)
    for i in range(depth, -1, -1):                       # the dark rim round the whole stack
        d.text((ox, oy + i), text, font=f, fill=line, stroke_width=ol, stroke_fill=line)
    for i in range(depth, 0, -1):                        # the coloured 3D edge
        d.text((ox, oy + i), text, font=f, fill=edge)
    d.text((ox, oy), text, font=f, fill=fill)
    _txt[k] = im
    return im


def pill(text, size, bg=MINT, fg=DEEP, line=DEEP):
    k = ("pill", text, size, bg, fg)
    if k in _txt:
        return _txt[k]
    f = font(size)
    l, t, r, b = f.getbbox(text)
    tw, th = r - l, b - t
    px, py = int(size * 0.7), int(size * 0.42)
    w, h = tw + px * 2, th + py * 2
    depth = int(size * 0.12)
    im = Image.new("RGBA", (w + 8, h + depth + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((4, 4 + depth, 4 + w, 4 + h + depth), h // 2, fill=(40, 150, 125), outline=line, width=4)
    d.rounded_rectangle((4, 4, 4 + w, 4 + h), h // 2, fill=bg, outline=line, width=4)
    d.text((4 + px - l, 4 + py - t), text, font=f, fill=fg)
    _txt[k] = im
    return im


def place(canvas, im, cx, cy, scale=1.0, alpha=1.0, rot=0.0):
    if scale <= 0.01 or alpha <= 0.01:
        return
    if abs(scale - 1.0) > 1e-3 or rot:
        w, h = max(1, int(im.width * scale)), max(1, int(im.height * scale))
        im = im.resize((w, h), Image.BICUBIC)
        if rot:
            im = im.rotate(rot, Image.BICUBIC, expand=True)
    if alpha < 1.0:
        a = im.getchannel("A").point(lambda v: int(v * alpha))
        im = im.copy()
        im.putalpha(a)
    canvas.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))


def pop(f, f_on, f_off, out=6):
    """scale, alpha for a caption that pops in at f_on and shrinks away before f_off"""
    if f < f_on or f >= f_off:
        return 0.0, 0.0
    s = back_out((f - f_on) / 6.0)
    a = min(1.0, (f - f_on) / 2.0)
    if f >= f_off - out:
        k = (f_off - f) / float(out)
        s *= 0.6 + 0.4 * k
        a *= k
    return s, a


WORLD_NAMES = {"river": ("THE RIVER", (62, 199, 224)), "volcanic": ("VOLCANO", (255, 122, 47)),
               "ocean": ("THE OCEAN", (47, 123, 255)), "sky": ("THE SKY", (255, 122, 192)),
               "space": ("SPACE!", (142, 108, 255)), "alien": ("ALIEN SEAS", (76, 217, 100)),
               "abyss": ("THE ABYSS", (106, 45, 189))}
SCREEN_LABELS = ["REEL IT IN!", "17 BOATS · 7 WORLDS", "GO VIRAL ON FISHTOK", "PLAY ONLINE · CLOUD SAVES"]


def captions(c, f, layout):
    """draw this frame's captions; layout: '16x9' (over the picture) or '9x16' (picture is in a band, text
    goes above / below it: c is the tall canvas, band = (top, height))"""
    tall = layout == "9x16"
    cw, ch = c.size
    band_top, band_h = (0, ch) if not tall else layout_band(c)
    below = band_top + band_h
    k = 1.0 if not tall else 1.25

    def at_bottom(dy=0.86):
        return (ch * 0.5 + band_h * 0.5 + 170 if tall else ch * dy)

    # (vertical only) a hook above the picture, and the tagline above the end card
    if tall and 10 <= f < T.KABOOM - 2:
        s, a = pop(f, 10, T.KABOOM - 2)
        place(c, brand_text("wait for it...", int(64 * k), edge=MINT, depth=5), cw / 2, band_top / 2 + 20, s, a)
    if tall and f >= 1026:
        s, a = pop(f, 1026, 10 ** 6)
        place(c, brand_text("cozy fishing.", int(64 * k), edge=MINT, depth=5), cw / 2, band_top / 2 - 40, s, a)
        s, a = pop(f, 1030, 10 ** 6)
        place(c, brand_text("explosive catches.", int(64 * k), edge=(255, 122, 47), depth=5), cw / 2,
              band_top / 2 + 60, s, a)
    # the cozy lie
    if 8 <= f < T.HUSH:
        txt = "just a chill little fishing game..."
        n = min(len(txt), max(0, int((f - 8) / 1.1)))
        im = brand_text(txt[:n] if n < len(txt) else txt, int(58 * k), edge=(120, 205, 236), depth=4)
        a = 1.0 if f < T.HUSH - 4 else (T.HUSH - f) / 4.0
        if n:
            place(c, im, cw / 2, at_bottom(0.87), 1.0, a)
    # tagline under the logo
    s, a = pop(f, 218, 241)
    if s:
        place(c, brand_text("cozy fishing.  explosive catches.", int(54 * k), edge=MINT, depth=5), cw / 2,
              at_bottom(0.88), s, a)
    # the seven worlds
    for i, (name, f0) in enumerate(T.WORLDS):
        f1 = T.WORLDS[i + 1][1] if i + 1 < len(T.WORLDS) else T.SCREENS[0]
        s, a = pop(f, f0 + 2, f1 + 1, out=4)
        if s:
            label, col = WORLD_NAMES[name]
            big = brand_text(label, int(118 * k), edge=col, depth=10)
            y = at_bottom(0.82)
            place(c, big, cw / 2, y, s, a)
            small = brand_text("WORLD %d OF 7" % (i + 1), int(40 * k), edge=col, depth=3)
            place(c, small, cw / 2, y - big.height * 0.5 * s - 6, s, a)
    # the real game
    for i, (lbl, f0) in enumerate(zip(SCREEN_LABELS, T.SCREENS)):
        f1 = T.SCREENS[i + 1] if i + 1 < len(T.SCREENS) else 840
        s, a = pop(f, f0 + 3, f1 - 2)
        if s:
            y = (below + 150 if tall else 70)
            place(c, brand_text(lbl, int(70 * k), edge=MINT, depth=6), cw / 2, y, s, a, rot=0)
    if 600 <= f < 840:
        a = min(1.0, (f - 600) / 6.0) * (1.0 if f < 834 else (840 - f) / 6.0)
        place(c, brand_text("real gameplay", int(30 * k), edge=MINT, depth=2), cw - 170 * k if not tall else cw / 2,
              ch - 46 if not tall else below + 260, 1.0, a * 0.9)
    # the boat counter
    if T.BOAT_PASSES[0] <= f < T.BIG_KABOOM - 3:
        n = sum(1 for p in T.BOAT_PASSES if f >= p)
        up = T.SURVEYOR + 12                             # the 17th has surfaced
        n = 17 if f >= up else n
        last = up if f >= up else max(p for p in T.BOAT_PASSES if f >= p)
        s = 1.0 + 0.25 * math.exp(-(f - last) / 3.0)
        y = below + 160 if tall else 120
        place(c, brand_text("%d BOATS" % n if n < 17 else "17 BOATS!", int(96 * k), edge=(255, 204, 72), depth=8),
              cw / 2, y, s, 1.0)
    # the end card
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
# (overlay, first frame, centre x, centre y (fractions of the picture), width in px, tilt)
WORD_HITS = [("word_kaboom", T.KABOOM, 0.47, 0.42, 1000, -6), ("word_boom", T.ERUPTION + 1, 0.57, 0.26, 620, 6),
             ("word_whoosh", T.SKY_PASS - 8, 0.68, 0.24, 560, -8), ("word_splash", T.LEAPS["ocean"][0] + 3, 0.3, 0.3, 520, 7),
             ("word_kaboom", T.BIG_KABOOM, 0.5, 0.45, 1150, 5)]
_ovl = {}


def overlay(name, i):
    k = (name, i)
    if k not in _ovl:
        p = os.path.join(OVERLAYS, name, "%04d.png" % i)
        _ovl[k] = Image.open(p).convert("RGBA") if os.path.exists(p) else None
    return _ovl[k]


def words(c, f):
    for name, f0, x, y, width, tilt in WORD_HITS:
        i = f - f0 + 1
        if 1 <= i <= 34:
            im = overlay(name, i)
            if im is not None:                       # the burst is ~900 px wide in the 1600 px overlay
                place(c, im, x * W, y * H, width / 900.0, 1.0, rot=tilt)


# ------------------------------------------------------------- speed lines
def speed_lines(c, f, strength):
    if strength <= 0.01:
        return
    rnd = random.Random(f // 2)
    lay = Image.new("RGBA", c.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    cx, cy = c.width / 2, c.height / 2
    R = math.hypot(cx, cy)
    for _ in range(int(40 + 60 * strength)):
        a = rnd.uniform(0, 2 * math.pi)
        r0 = R * rnd.uniform(0.42, 0.75) * (1.1 - 0.3 * strength)
        wd = rnd.uniform(0.006, 0.02)
        p0 = (cx + math.cos(a) * r0, cy + math.sin(a) * r0)
        p1 = (cx + math.cos(a - wd) * R * 1.1, cy + math.sin(a - wd) * R * 1.1)
        p2 = (cx + math.cos(a + wd) * R * 1.1, cy + math.sin(a + wd) * R * 1.1)
        d.polygon([p0, p1, p2], fill=(255, 255, 255, int(150 * strength)))
    c.alpha_composite(lay)


def speed_at(f):
    if 156 <= f < 180:
        return (f - 156) / 24.0
    if 896 <= f < T.BIG_KABOOM - 8:
        return 0.35 + 0.65 * (f - 896) / float(T.BIG_KABOOM - 8 - 896)
    return 0.0


# ------------------------------------------------------------------ frames
VIGNETTE = None


def vignette(size):
    global VIGNETTE
    if VIGNETTE is None or VIGNETTE.size != size:
        w, h = size
        y, x = np.mgrid[0:h, 0:w]
        r = np.hypot((x - w / 2) / (w / 2), (y - h / 2) / (h / 2))
        a = np.clip((r - 0.75) / 0.7, 0, 1) ** 1.6 * 110
        VIGNETTE = Image.fromarray(np.dstack([np.zeros((h, w, 3)), a]).astype(np.uint8), "RGBA")
    return VIGNETTE


def picture(f):
    """the 3D frame with this frame's camera hits applied (RGBA, W x H)"""
    im = Image.open(os.path.join(FRAMES, "%04d.png" % f)).convert("RGB")
    dx, dy, rot, zoom, flash, split = camera_fx(f)
    z = zoom * 1.04                                   # a little overscan so the shake never shows an edge
    im = im.transform(im.size, Image.AFFINE, _affine(z, rot, dx, dy), resample=Image.BICUBIC)
    if split:
        r, g, b = im.split()
        r = ImageChops.offset(r, split, 0)
        b = ImageChops.offset(b, -split, 0)
        im = Image.merge("RGB", (r, g, b))
    im = im.convert("RGBA")
    im.alpha_composite(vignette(im.size))
    words(im, f)
    speed_lines(im, f, speed_at(f))
    if flash > 0:
        im = Image.blend(im, Image.new("RGBA", im.size, (255, 255, 255, 255)), min(1.0, flash))
    return im


def _affine(z, rot, dx, dy):
    """PIL maps each output pixel back to the input: zoom z and turn rot about the centre, then shift (dx, dy)"""
    a = math.radians(rot)
    ca, sa = math.cos(a) / z, math.sin(a) / z
    cx, cy = W / 2, H / 2
    ox, oy = cx + dx, cy + dy
    return (ca, sa, cx - ca * ox - sa * oy, -sa, ca, cy + sa * ox - ca * oy)


def layout_band(c):
    cw, ch = c.size
    bh = int(cw * 9 / 16)
    return (ch - bh) // 2 - 60, bh


def frame_16x9(f):
    im = picture(f)
    captions(im, f, "16x9")
    return im.convert("RGB")


def frame_9x16(f, pic=None):
    pic = pic or picture(f)
    cw, ch = 1080, 1920
    c = Image.new("RGBA", (cw, ch), DEEP + (255,))
    bg = pic.resize((int(ch * 16 / 9), ch), Image.BILINEAR).crop(((int(ch * 16 / 9) - cw) // 2, 0,
                                                                  (int(ch * 16 / 9) - cw) // 2 + cw, ch))
    bg = bg.filter(ImageFilter.GaussianBlur(28))
    bg = Image.blend(bg, Image.new("RGBA", bg.size, DEEP + (255,)), 0.45)
    c.alpha_composite(bg)
    top, bh = layout_band(c)
    band = pic.resize((cw, bh), Image.LANCZOS)
    c.alpha_composite(band, (0, top))
    if 236 <= f < 1020:                                  # the logo above the picture (the 3D one is in it before/after)
        a = min(1.0, (f - 236) / 6.0) * min(1.0, (1020 - f) / 6.0)
        place(c, LOGO, cw / 2, top / 2 + 10, 520.0 / LOGO.width, a)
    captions(c, f, "9x16")
    return c.convert("RGB")


LOGO = Image.open(os.path.join(ROOT, "assets", "brand", "logo.png")).convert("RGBA")


# ------------------------------------------------------------------ encode
def encoder(path, size):
    return subprocess.Popen([FF, "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % size,
                             "-r", str(T.FPS), "-i", "-", "-i", os.path.join(WORK, "music.wav"),
                             "-c:v", "libx264", "-preset", "slow", "-crf", "17", "-pix_fmt", "yuv420p",
                             "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart", path],
                            stdin=subprocess.PIPE)


def main():
    args = sys.argv[1:]
    out = WORK if not args or args[0].startswith("--") else args[0]
    fmts = ["16x9"]
    if "--formats" in args:
        fmts = args[args.index("--formats") + 1].split(",")
    os.makedirs(out, exist_ok=True)
    first, last = 0, T.TOTAL
    if "--range" in args:
        first, last = (int(x) for x in args[args.index("--range") + 1].split("-"))
    if "--preview" in args:
        # contact frames only (no encode): out/preview_####.jpg
        for f in [int(x) for x in args[args.index("--preview") + 1].split(",")]:
            frame_16x9(f).save(os.path.join(out, "preview_%04d.jpg" % f), quality=90)
            if "9x16" in fmts:
                frame_9x16(f).save(os.path.join(out, "preview916_%04d.jpg" % f), quality=90)
        return
    encs = {}
    if "16x9" in fmts:
        encs["16x9"] = encoder(os.path.join(out, "fosh-and-fish-kaboom-16x9.mp4"), (W, H))
    if "9x16" in fmts:
        encs["9x16"] = encoder(os.path.join(out, "fosh-and-fish-kaboom-9x16.mp4"), (1080, 1920))
    for f in range(first, last):
        pic = picture(f)
        if "16x9" in encs:
            im = pic.copy()
            captions(im, f, "16x9")
            encs["16x9"].stdin.write(im.convert("RGB").tobytes())
        if "9x16" in encs:
            encs["9x16"].stdin.write(frame_9x16(f, pic).tobytes())
        if f % 60 == 0:
            print("frame", f, flush=True)
    for e in encs.values():
        e.stdin.close()
        e.wait()
    print("done:", ", ".join(os.path.join(out, "fosh-and-fish-kaboom-%s.mp4" % k) for k in encs))
    if "--thumb" in args:
        thumbnail(out)


def remux(out, audio, suffix):
    """the same pictures with another soundtrack (e.g. sound effects only): copies the video streams"""
    for fmt in ("16x9", "9x16"):
        src = os.path.join(out, "fosh-and-fish-kaboom-%s.mp4" % fmt)
        if not os.path.exists(src):
            continue
        dst = os.path.join(out, "fosh-and-fish-kaboom-%s-%s.mp4" % (suffix, fmt))
        subprocess.run([FF, "-v", "error", "-y", "-i", src, "-i", audio, "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy",
                        "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart", dst], check=True)
        print("remuxed", dst)


def thumb_only():
    thumbnail(sys.argv[sys.argv.index("--thumb-only") + 1] if len(sys.argv) > sys.argv.index("--thumb-only") + 1 else WORK)


def thumbnail(out):
    """YouTube thumbnail: the giant pufferfish mid-blast, the KABOOM word, the logo"""
    im = Image.open(os.path.join(FRAMES, "%04d.png" % (T.KABOOM + 26))).convert("RGBA")   # clean: no shake, no words
    im.alpha_composite(vignette(im.size))
    word = overlay("word_kaboom", 14)
    if word is not None:
        place(im, word, W * 0.77, H * 0.28, 1.0, 1.0, rot=8)
    place(im, LOGO, W * 0.8, H * 0.76, 0.6)
    im.convert("RGB").resize((1280, 720), Image.LANCZOS).save(os.path.join(out, "fosh-and-fish-kaboom-thumbnail.png"))
    print("thumbnail saved")


if __name__ == "__main__":
    if "--remux" in sys.argv:
        i = sys.argv.index("--remux")
        remux(sys.argv[1] if not sys.argv[1].startswith("--") else WORK, sys.argv[i + 1], sys.argv[i + 2])
    elif "--thumb-only" in sys.argv:
        thumb_only()
    else:
        main()

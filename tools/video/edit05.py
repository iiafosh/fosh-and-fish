"""Edit the fosh&fish 0.5 trailer from the clean --reel05 recording (mini-game, captain, sailing, FishTok, new boats).

Beat-synced cuts at 120 BPM (one beat = 15 frames), punch-in camera moves aimed at the
logged action points, animated captions with gold keywords, an animated title and end
card, original music (music.py) with the game's own sounds underneath, whooshes on the
cuts, and -14 LUFS delivery in 16:9, 9:16 and 1:1.

    python tools/video/edit.py WORK_DIR OUT_DIR
WORK_DIR holds reel.avi, reel_log.txt (MARK lines) and music.wav.
"""
import math
import os
import re
import subprocess
import sys
import wave

import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

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
BIOMES = ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien", "Abyss"]

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
# each shot: src start frame, length in beats, zoom from->to, focus (x, y) in source px,
# caption (list of (word, gold)), whoosh on entry
shots = []


def shot(src, beats, z0, z1, focus, caption=None, tag=None, whoosh=False, label=None):
    shots.append(dict(src=src + FRAME_OFFSET, n=beats * BEAT, z0=z0, z1=z1, focus=focus,
                      caption=caption, tag=tag, whoosh=whoosh, label=label))


hero = marks["hero"]
# bar 0: hook - a big catch, punching in
shot(hero[1]["f"] - 6, 4, 1.05, 1.32, mid(hero[1], 0.55))
# bar 1: title over the gameplay
shot(hero[2]["f"] - 8, 4, 1.15, 1.25, mid(hero[2]), tag="title")
# bar 2: tap the water (lands where you tap)
t = marks["tap"]
shot(t[0]["f"] - 4, 4, 1.45, 1.3, t[0]["bob"], caption=[("Tap", True), ("the", False), ("water", False)])
# bars 3-4: the Reel it in! mini-game
shot(mk("mg_play")["f"] - 4, 4, 1.25, 1.35, (W * 0.5, H * 0.5), caption=[("Reel", True), ("it", False), ("in!", True)], whoosh=True)
shot(mk("mg_win")["f"] - 8, 4, 1.35, 1.2, (W * 0.5, H * 0.5), caption=[("+75%", True), ("fish", False)])
# bar 5: meet the captain
d = mk("dance")
shot(d["f"] + 4, 4, 2.1, 2.4, d["boat"], caption=[("Meet", False), ("the", False), ("captain", True)], whoosh=True)
# bars 6-7: sail through a sea lane into the next biome
sg = mk("sail_go")
shot(sg["f"] + 6, 4, 1.2, 1.3, sg["boat"], caption=[("Sail", True), ("to", False), ("new", False), ("waters", False)], whoosh=True)
shot(mk("sail_wipe")["f"] - 14, 2, 1.0, 1.05, (W * 0.5, H * 0.5))
sa = mk("sail_arrive")
shot(sa["f"] - 4, 2, 1.25, 1.15, sa["boat"], label="Volcanic")
# bars 8-9: FishTok
shot(mk("phone")["f"] - 10, 4, 1.35, 1.45, (W * 0.5, H * 0.5), caption=[("FishTok", True)], whoosh=True)
shot(mk("phone")["f"] + 30, 4, 1.45, 1.55, (W * 0.5, H * 0.42), caption=[("Trending", False), ("fish", False), ("+50%", True)])
# bars 10-11: new boats across the biomes
for b in ["Sky", "Space", "Alien", "Abyss"]:
    m = marks["boat_" + b][0]
    shot(m["f"] + 8, 2, 1.55, 1.45, m["boat"], label=b, whoosh=True, caption=[("17", True), ("new", False), ("boats", False)])
# bars 12-13: wide hero shot + platforms
e = marks["end"]
shot(e[0]["f"] - 10, 8, 1.0, 1.14, mid(e[0]), caption=[("Free", True), ("to", False), ("play", False)], tag="platforms")
# bars 14-15: end card
shots.append(dict(tag="end", n=8 * BEAT + 30, whoosh=True))

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
        gd.text((size * 0.5 + 4, size * 0.95 + 6), w, font=f, anchor="mm" if False else "lm", fill=(0, 0, 0, 110),
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


def flash(canvas, amount):
    if amount > 0:
        canvas.alpha_composite(Image.new("RGBA", canvas.size, (255, 250, 235, int(255 * min(1, amount)))))


def vignette(size):
    w, h = size
    v = Image.radial_gradient("L").resize((w, h)).point(lambda p: int(min(255, p * 0.55)))
    layer = Image.new("RGBA", (w, h), (10, 18, 30, 0))
    layer.putalpha(v)
    return layer


# ------------------------------------------------------------- layouts
FORMATS = {"16x9": (1920, 1080), "9x16": (1080, 1920), "1x1": (1080, 1080)}
VIGS = {k: vignette(v) for k, v in FORMATS.items()}


def game_view(fmt, img, zoom, focus):
    ow, oh = FORMATS[fmt]
    if fmt == "16x9":
        return camera(img, zoom, focus, ow, oh).convert("RGBA")
    if fmt == "1x1":
        return camera(img, zoom * 1.0, focus, ow, oh).convert("RGBA")
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


def draw_frame(fmt, s, i, img):
    ow, oh = FORMATS[fmt]
    tag = s.get("tag")
    if tag == "end":
        return end_card(fmt, i)
    k = i / max(1, s["n"] - 1)
    zoom = s["z0"] + (s["z1"] - s["z0"]) * ease_in_out(k)
    zoom *= 1 + 0.06 * max(0, 1 - i / 6)                # little punch on every cut
    c = game_view(fmt, img, zoom, s["focus"])
    c.alpha_composite(VIGS[fmt])
    cx, cy, mw, size = caption_pos(fmt)
    if tag == "title":
        c.alpha_composite(Image.new("RGBA", c.size, (14, 30, 44, int(110 * min(1, i / 5)))))
        sc = ease_out_back(min(1, i / 10)) * {"16x9": 1.0, "1x1": 0.85, "9x16": 0.95}[fmt]
        tcy = oh * (0.46 if fmt != "9x16" else 0.42)
        paste_center(c, ICON.resize((230, 230)), ow / 2, tcy - 190 * sc, sc)
        paste_center(c, TITLE, ow / 2, tcy + 40 * sc, sc)
        if i > 14:
            paste_center(c, pill("a cozy fishing game  ·  by afosh", 40 if fmt == "16x9" else 34), ow / 2,
                         tcy + 210 * sc, 1, min(1, (i - 14) / 6))
        flash(c, 1 - i / 6)
    if s.get("label"):
        lab = pill(s["label"], 44 if fmt == "16x9" else 40, color=(59, 44, 32))
        paste_center(c, lab, lab.size[0] / 2 + 50, 70 if fmt != "9x16" else 470, ease_out_back(min(1, i / 6)))
    if fmt == "9x16" and tag != "title":
        # brand footer under the gameplay window
        paste_center(c, FOOTER, ow / 2, 1800)
    if s.get("caption"):
        layer = text_layer(s["caption"], size, i if not s.get("label") or s["label"] == "River" else 99, mw)
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
        ImageDraw.Draw(layer).text((ow / 2, 30), "0.5 beta  ·  made by afosh  ·  feedback welcome!", font=font(30, 500),
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
    t = 0
    for s in shots:
        dur = s["n"] / FPS
        a = int(t / FPS * SR)
        if s.get("src") is not None:
            g0 = int(s["src"] / FPS * SR)
            seg = game[g0:g0 + int(dur * SR)]
            fade = np.minimum(1, np.minimum(np.arange(len(seg)), np.arange(len(seg))[::-1]) / 480.0)[:, None]
            out[a:a + len(seg)] += seg * fade * 0.55
        if s.get("whoosh"):
            wsh = music.whoosh(0.4)[:, None] * np.array([[1.0, 1.0]])
            b = max(0, a - int(0.25 * SR))
            out[b:b + len(wsh)] += wsh * 0.35
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
        path = os.path.join(OUT, f"fosh-and-fish-0.5-trailer-{fmt}.mp4")
        procs[fmt] = subprocess.Popen(
            [FF, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{ow}x{oh}", "-r", str(FPS),
             "-i", "-", "-i", audio,
             "-af", "highshelf=f=7000:g=-4,equalizer=f=3000:t=q:w=1:g=2,loudnorm=I=-14:TP=-1.5:LRA=9",
             "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-profile:v", "high",
             "-color_range", "tv", "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-shortest", "-movflags", "+faststart", path],
            stdin=subprocess.PIPE)
    frame_no = 0
    for si, s in enumerate(shots):
        src = read_frames(s["src"], s["n"]) if s.get("src") is not None else [None] * s["n"]
        for i in range(s["n"]):
            for fmt in fmts:
                procs[fmt].stdin.write(draw_frame(fmt, s, i, src[i]).convert("RGB").tobytes())
            frame_no += 1
        print(f"shot {si + 1}/{len(shots)} done ({frame_no}/{TOTAL})", flush=True)
    for p in procs.values():
        p.stdin.close()
        p.wait()


if __name__ == "__main__":
    fmts = sys.argv[3].split(",") if len(sys.argv) > 3 else list(FORMATS)
    render(fmts)

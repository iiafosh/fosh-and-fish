"""Title-screen (launcher) art from tools/art/launcher_source_v2.png: the bay picture the owner had made on
2026-11-14 (an image model, 1536x1024, from the prompt in that day's chat). The painting before it is still here as
tools/art/launcher_source_hq.webp (git history has the tool that prepared it).

    python tools/art/make_launcher.py            then: python tools/art/make_brand.py painted, python tools/web_shell.py

Writes
  assets/launcher/launcher_bg.jpg     1920x1080: the 16:9 middle of the picture, enlarged and sharpened a touch
  assets/launcher/launcher_masks.png  480x270: R = open water (shimmer), G = leaves (sway)

The launcher (scripts/vf/vf_launcher.gd) animates the picture with these masks: water shimmer and sparkles, swaying
leaves, bobber ripples, lantern glow, a passing gull and a slow camera drift. The points it needs (the bobber, the
lamps) are fractions of the picture: BOBBER and LANTERNS here are what vf_launcher.gd has. Change them together.
"""
import colorsys
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "tools", "art", "launcher_source_v2.png")
OUT = os.path.join(ROOT, "assets", "launcher")
W, H = 1920, 1080
TOP = 80                             # rows cut from the top of the 3:2 picture (the rest comes off the bottom)
HORIZON = 0.282                      # sea horizon, as a fraction of the height
BOBBER = (0.4455, 0.7035)
LANTERNS = [(0.2455, 0.4040), (0.1190, 0.4350)]      # the lamp on the post, the lit window
# blue things that aren't water (x0, y0, x1, y1): the hut's shutters and towel, the captain, the boat's stripe
NOT_WATER = [(0.0, 0.28, 0.17, 0.74), (0.25, 0.43, 0.345, 0.64), (0.08, 0.73, 0.265, 0.92)]
# where leaves sway (x0, y0, x1, y1, flowers too): the palm in the corner and its long frond, the bushes bottom left
LEAVES = [(0.0, 0.0, 0.30, 0.125, False), (0.13, 0.0, 0.21, 0.175, False), (0.0, 0.63, 0.075, 0.84, False),
          (0.0, 0.84, 0.115, 1.0, True)]


def background(src: Image.Image) -> Image.Image:
    sw, sh = src.size
    th = round(sw * 9 / 16)
    im = src.crop((0, TOP, sw, TOP + th)).resize((W, H), Image.LANCZOS)        # (a 1.25x enlargement)
    return im.filter(ImageFilter.UnsharpMask(radius=1.4, percent=55, threshold=2))


def masks(bg: Image.Image) -> Image.Image:
    mw, mh = 480, 270
    small = np.asarray(bg.resize((mw, mh), Image.LANCZOS)).astype(np.float32) / 255.0
    water = np.zeros((mh, mw), np.float32)
    leaves = np.zeros((mh, mw), np.float32)
    for y in range(mh):
        fy = y / mh
        for x in range(mw):
            fx = x / mw
            r, g, b = small[y, x]
            h, s, v = colorsys.rgb_to_hsv(r, g, b)
            hue = h * 360
            if fy > HORIZON + 0.012 and 160 <= hue <= 235 and s > 0.28 and v > 0.35:
                if not any(x0 <= fx <= x1 and y0 <= fy <= y1 for x0, y0, x1, y1 in NOT_WATER):
                    water[y, x] = 1.0
            for x0, y0, x1, y1, flowers in LEAVES:
                if x0 <= fx <= x1 and y0 <= fy <= y1 and s > 0.35 and (60 <= hue <= 160 or (flowers and (hue < 25 or hue > 330))):
                    leaves[y, x] = 1.0
    w = Image.fromarray((water * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(2))
    lv = Image.fromarray((leaves * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(4))
    # the shimmer fades in from the horizon (far water barely moves)
    ramp = np.clip((np.arange(mh)[:, None] / mh - HORIZON) / 0.25, 0, 1)
    w = Image.fromarray((np.asarray(w).astype(np.float32) * (0.35 + 0.65 * ramp)).astype(np.uint8))
    zero = Image.new("L", (mw, mh), 0)
    return Image.merge("RGB", (w, lv, zero))


def check(bg: Image.Image, m: Image.Image, path: str) -> None:
    """a look at what the launcher will animate: water tinted red, leaves green, the bobber and the lamps marked"""
    im = bg.resize((1280, 720), Image.LANCZOS).convert("RGB")
    big = m.resize((1280, 720), Image.BILINEAR)
    r, g, _ = big.split()
    im = Image.composite(Image.new("RGB", im.size, (255, 40, 40)), im, r.point(lambda v: int(v * 0.45)))
    im = Image.composite(Image.new("RGB", im.size, (40, 255, 40)), im, g.point(lambda v: int(v * 0.6)))
    d = ImageDraw.Draw(im)
    for px, py in [BOBBER] + LANTERNS:
        d.ellipse((px * 1280 - 9, py * 720 - 9, px * 1280 + 9, py * 720 + 9), outline=(255, 255, 0), width=3)
    im.save(path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    bg = background(Image.open(SRC).convert("RGB"))
    bg.save(os.path.join(OUT, "launcher_bg.jpg"), quality=90, optimize=True, progressive=True)
    m = masks(bg)
    m.save(os.path.join(OUT, "launcher_masks.png"), optimize=True)
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    check(bg, m, os.path.join(ROOT, "build", "launcher_check.png"))
    for n in ["launcher/launcher_bg.jpg", "launcher/launcher_masks.png"]:
        p = os.path.join(ROOT, "assets", n)
        print(n, Image.open(p).size, os.path.getsize(p) // 1024, "KB")

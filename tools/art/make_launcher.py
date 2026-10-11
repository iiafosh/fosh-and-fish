"""Title-screen (launcher) art from tools/art/launcher_source.webp (the owner's illustration).

    python tools/art/make_launcher.py

Writes
  assets/launcher/launcher_bg.jpg     1920x1080, upscaled, cleaned, sharpened and graded a touch warmer
  assets/launcher/launcher_masks.png  480x270: R = open water (shimmer), G = foreground leaves (sway)
  assets/brand/wordmark.png           the fosh&fish wordmark (same style as the trailers), transparent

The launcher (scripts/vf/vf_launcher.gd) animates the picture with these masks: water shimmer and
sparkles, swaying leaves, bobber ripples, lantern glow, a passing gull and a slow camera drift.
"""
import colorsys
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "tools", "art", "launcher_source.webp")
OUT = os.path.join(ROOT, "assets", "launcher")
FONT = os.path.join(ROOT, "assets", "third_party", "fonts", "Fredoka.ttf")
W, H = 1920, 1080
HORIZON = 0.272                      # sea horizon, as a fraction of the height


def background(src: Image.Image) -> Image.Image:
    # exact 16:9, then a clean upscale
    sw, sh = src.size
    th = round(sw * 9 / 16)
    top = max(0, (sh - th) // 2)
    im = src.crop((0, top, sw, top + min(th, sh))).resize((W, H), Image.LANCZOS)
    im = im.filter(ImageFilter.SMOOTH_MORE)                                   # soften compression blocks
    im = im.filter(ImageFilter.UnsharpMask(radius=1.8, percent=85, threshold=2))
    im = ImageEnhance.Color(im).enhance(1.07)
    im = ImageEnhance.Contrast(im).enhance(1.05)
    a = np.asarray(im).astype(np.float32) / 255.0
    lum = a.mean(axis=2, keepdims=True)
    warm = np.array([1.025, 1.005, 0.985], np.float32)                        # sunnier highlights
    a = a * (1 + (warm - 1) * np.clip(lum * 1.4, 0, 1))
    return Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))


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
            if fy > HORIZON + 0.012 and 165 <= hue <= 235 and s > 0.28 and v > 0.35:
                water[y, x] = 1.0
            in_corner = (fx < 0.36 and fy > 0.62) or (fx > 0.8 and fy > 0.68)
            if in_corner and 60 <= hue <= 150 and s > 0.35:
                leaves[y, x] = 1.0
    w = Image.fromarray((water * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(2))
    lv = Image.fromarray((leaves * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(4))
    # the shimmer fades in from the horizon (far water barely moves)
    ramp = np.clip((np.arange(mh)[:, None] / mh - HORIZON) / 0.25, 0, 1)
    w = Image.fromarray((np.asarray(w).astype(np.float32) * (0.35 + 0.65 * ramp)).astype(np.uint8))
    zero = Image.new("L", (mw, mh), 0)
    return Image.merge("RGB", (w, lv, zero))


def wordmark(scale=1.0) -> Image.Image:
    size = int(170 * scale)
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_axes([700, 100])
    text = "fosh&fish"
    w = int(f.getlength(text) + size)
    img = Image.new("RGBA", (w, int(size * 1.6)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = w / 2, size * 0.8
    for r in range(size // 9, 0, -2):                                         # extruded dark edge
        for a in range(0, 360, 30):
            d.text((cx + math.cos(math.radians(a)) * r, cy + math.sin(math.radians(a)) * r + size * 0.06), text,
                   font=f, fill=(40, 28, 18, 255), anchor="mm")
    for a in range(0, 360, 20):
        d.text((cx + math.cos(math.radians(a)) * size * 0.07, cy + math.sin(math.radians(a)) * size * 0.07), text,
               font=f, fill=(46, 32, 22, 255), anchor="mm")
    d.text((cx, cy), text, font=f, fill=(255, 216, 92, 255), anchor="mm")
    hi = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(hi).text((cx, cy - size * 0.05), text, font=f, fill=(255, 236, 160, 90), anchor="mm")
    img.alpha_composite(hi)
    return img.crop(img.getbbox())


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    bg = background(Image.open(SRC).convert("RGB"))
    bg.save(os.path.join(OUT, "launcher_bg.jpg"), quality=90, optimize=True, progressive=True)
    masks(bg).save(os.path.join(OUT, "launcher_masks.png"), optimize=True)
    wordmark(1.0).save(os.path.join(ROOT, "assets", "brand", "wordmark.png"), optimize=True)
    for n in ["launcher/launcher_bg.jpg", "launcher/launcher_masks.png", "brand/wordmark.png"]:
        p = os.path.join(ROOT, "assets", n)
        print(n, Image.open(p).size, os.path.getsize(p) // 1024, "KB")

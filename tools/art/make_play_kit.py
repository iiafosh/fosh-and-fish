"""Google Play store art for fosh&fish 1.0 (what you upload in Play Console -> Store listing).

    python tools/art/make_play_kit.py            everything
    python tools/art/make_play_kit.py feature    just the feature graphic (quick look)
    python tools/art/make_play_kit.py shots      just the screenshots

Writes to store/play/ (Godot ignores the folder, exports leave it out):
  icon_512.png               the app icon (from assets/brand/icon_1024.png, tools/art/make_brand.py)
  feature_1024x500.png       the feature graphic: the painted cover scene, the logo, glowing shiny fish
                             under the water, a NEW 1.0 sticker and three things 1.0 brings
  screenshots/*.png          1920x1080 game screenshots (the game's --play-shots capture, fullscreen:
                             your screen must be 1920x1080, and the game covers it for about a minute)
The listing texts are in store/play/listing.md.
"""
import math
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_brand as MB  # noqa: E402

ROOT = MB.ROOT
OUT = os.path.join(ROOT, "store", "play")
GODOT = os.environ.get("GODOT", r"C:\Program Files\Godot\Godot_console.exe")


def icon():
    Image.open(os.path.join(MB.BRAND, "icon_1024.png")).convert("RGBA").resize((512, 512), Image.LANCZOS) \
        .save(os.path.join(OUT, "icon_512.png"), optimize=True)


SS = 2          # the overlays are drawn at 2x and scaled down, for clean edges
GOLD = (255, 206, 84)


def screen(base, light):
    """light added like a glow (screen blend): 1 - (1 - base)(1 - light), the light's alpha is its strength"""
    b = np.asarray(base.convert("RGB"), np.float32) / 255.0
    lt = np.asarray(light, np.float32) / 255.0
    out = 1.0 - (1.0 - b) * (1.0 - lt[..., :3] * lt[..., 3:4])
    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8)).convert("RGBA")


def glow_fish(tint, light, center, w, flip=False, angle=0.0, strength=1.0):
    """a shiny swimming under the surface, in the shape of the logo's fish: a golden body (tint, laid over the
    water) inside a soft glow (light, added to it)"""
    m = MB.fish_mask(int(w))
    if flip:
        m = m.transpose(Image.FLIP_LEFT_RIGHT)
    if angle:
        m = m.rotate(angle, Image.BICUBIC, expand=True)
    pad = int(w * 0.5)
    big = Image.new("L", (m.size[0] + pad * 2, m.size[1] + pad * 2), 0)
    big.paste(m, (pad, pad))
    at = (int(center[0] - big.size[0] / 2), int(center[1] - big.size[1] / 2))
    body = Image.new("RGBA", big.size, (255, 184, 34, 0))
    body.putalpha(big.filter(ImageFilter.GaussianBlur(w * 0.025)).point(lambda v: int(v * 0.7 * strength)))
    tint.alpha_composite(body, at)
    halo = big.filter(ImageFilter.GaussianBlur(w * 0.17)).point(lambda v: int(v * 0.7 * strength))
    core = big.filter(ImageFilter.MinFilter(max(3, int(w * 0.08)) | 1)).filter(ImageFilter.GaussianBlur(w * 0.05))
    glow = Image.new("RGBA", big.size, GOLD + (0,))
    glow.putalpha(ImageChops.lighter(halo, core.point(lambda v: int(v * 0.6 * strength))))
    light.alpha_composite(glow, at)


def sparkle(light, center, r, color=(255, 248, 222)):
    """a 4-point glint with a soft halo"""
    n = int(r * 4)
    c = n / 2
    k = r * 0.17
    m = Image.new("L", (n, n), 0)
    ImageDraw.Draw(m).polygon([(c, c - r), (c + k, c - k), (c + r, c), (c + k, c + k), (c, c + r), (c - k, c + k), (c - r, c),
                               (c - k, c - k)], fill=255)
    halo = Image.new("L", (n, n), 0)
    ImageDraw.Draw(halo).ellipse((c - r * 0.45, c - r * 0.45, c + r * 0.45, c + r * 0.45), fill=255)
    halo = halo.filter(ImageFilter.GaussianBlur(r * 0.3)).point(lambda v: int(v * 0.8))
    layer = Image.new("RGBA", (n, n), color + (0,))
    layer.putalpha(ImageChops.lighter(m, halo))
    light.alpha_composite(layer, (int(center[0] - c), int(center[1] - c)))


def badge(ui, center, r, angle=-14.0):
    """a gold "NEW 1.0" sticker"""
    n = int(r * 2.8)
    c = n / 2
    pts = []
    for i in range(28):
        rr = r if i % 2 == 0 else r * 0.86
        a = math.pi * i / 14
        pts.append((c + math.cos(a) * rr, c + math.sin(a) * rr))
    b = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    sh = Image.new("L", (n, n), 0)
    ImageDraw.Draw(sh).polygon([(x + r * 0.05, y + r * 0.1) for x, y in pts], fill=255)
    b.paste(Image.new("RGBA", (n, n), MB.SHADOW + (255,)), (0, 0), sh.filter(ImageFilter.GaussianBlur(r * 0.07)).point(lambda v: int(v * 0.55)))
    d = ImageDraw.Draw(b)
    d.polygon(pts, fill=(255, 196, 46, 255))
    d.ellipse((c - r * 0.72, c - r * 0.72, c + r * 0.72, c + r * 0.72), outline=(255, 238, 170, 255), width=max(2, int(r * 0.05)))
    d.text((c, c - r * 0.3), "NEW", font=MB.font(int(r * 0.3), 700, 100), fill=MB.DEEP, anchor="mm")
    d.text((c, c + r * 0.14), "1.0", font=MB.font(int(r * 0.66), 700, 112), fill=MB.DEEP, anchor="mm")
    b = b.rotate(-angle, Image.BICUBIC)
    ui.alpha_composite(b, (int(center[0] - c), int(center[1] - c)))


def _icon(d, kind, x, y, s, color):
    """tiny drawn icons for the chips: shiny (a glint), events (a bolt), worlds (a globe)"""
    if kind == "shiny":
        k = s * 0.2
        d.polygon([(x, y - s), (x + k, y - k), (x + s, y), (x + k, y + k), (x, y + s), (x - k, y + k), (x - s, y), (x - k, y - k)], fill=color)
    elif kind == "bolt":
        d.polygon([(x + s * 0.25, y - s), (x - s * 0.6, y + s * 0.15), (x - s * 0.02, y + s * 0.15), (x - s * 0.25, y + s),
                   (x + s * 0.6, y - s * 0.15), (x + s * 0.02, y - s * 0.15)], fill=color)
    else:
        w = max(2, int(s * 0.2))
        d.ellipse((x - s, y - s, x + s, y + s), outline=color, width=w)
        d.ellipse((x - s * 0.45, y - s, x + s * 0.45, y + s), outline=color, width=w)
        d.line((x - s, y, x + s, y), fill=color, width=w)


def chips(ui, cx, cy, items, size):
    """a row of little pills, like the tagline: (icon, text, icon colour)"""
    f = MB.font(size, 600, 100)
    h = size * 1.8
    widths = [f.getlength(t) + h * 1.45 for _i, t, _c in items]
    gap = size * 0.6
    x = cx - (sum(widths) + gap * (len(items) - 1)) / 2
    layer = Image.new("RGBA", ui.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for (kind, text, col), w in zip(items, widths):
        d.rounded_rectangle((x, cy - h / 2, x + w, cy + h / 2), int(h / 2), fill=(11, 41, 48, 165))
        _icon(d, kind, x + h * 0.58, cy, size * 0.42, col + (255,))
        d.text((x + h * 1.02, cy), text, font=f, fill=(255, 255, 255, 255), anchor="lm")
        x += w + gap
    ui.alpha_composite(layer)


def feature():
    """the painted cover scene with the fisher on the pier and the logo out over the open sea; under the water
    the golden glow of shiny fish (one about to take the bobber), a NEW 1.0 sticker and what 1.0 brings"""
    w, h = 1024, 500
    art = Image.open(MB.ART).convert("RGB")
    s = w / art.size[0]
    art = art.resize((w, int(art.size[1] * s + 0.5)), Image.LANCZOS)
    y = 34
    c = art.crop((0, y, w, y + h)).convert("RGBA")
    W, H = w * SS, h * SS
    tint = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    light = Image.new("RGBA", (W, H), GOLD + (0,))
    for (fx, fy, fw, flip, ang, st) in [(398, 424, 96, True, -16, 1.0), (452, 214, 64, False, 8, 0.75), (612, 470, 74, False, -6, 0.8)]:
        glow_fish(tint, light, (fx * SS, fy * SS), fw * SS, flip, ang, st)
    c.alpha_composite(tint.resize((w, h), Image.LANCZOS))
    c = screen(c, light.resize((w, h), Image.LANCZOS))         # the glow over the gold: they shine
    sparks = Image.new("RGBA", (W, H), GOLD + (0,))
    for (sx, sy, sr) in [(424, 396, 13), (352, 446, 8), (478, 196, 9), (646, 452, 10), (470, 76, 10)]:
        sparkle(sparks, (sx * SS, sy * SS), sr * SS)
    c = screen(c, sparks.resize((w, h), Image.LANCZOS))
    ui = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lg = MB.logo(1.0)
    lw = 430
    lg = lg.resize((lw * SS, int(lg.size[1] * lw * SS / lg.size[0])), Image.LANCZOS)
    lx, ly = int(0.69 * w - lw / 2), 34
    ui.alpha_composite(lg, (lx * SS, ly * SS))
    f = MB.font(22 * SS, 500, 100)
    text = "a cozy fishing game"
    tw = f.getlength(text)
    th = f.size * 1.9
    px, py = (lx + lw / 2) * SS, ly * SS + lg.size[1] + th * 0.45
    pill = Image.new("RGBA", ui.size, (0, 0, 0, 0))
    ImageDraw.Draw(pill).rounded_rectangle((px - tw / 2 - th * 0.6, py - th / 2, px + tw / 2 + th * 0.6, py + th / 2), int(th / 2),
                                           fill=(11, 41, 48, 150))
    ui.alpha_composite(pill)
    ImageDraw.Draw(ui).text((px, py), text, font=f, fill=(255, 255, 255), anchor="mm")
    chips(ui, px, py + th * 1.25, [("shiny", "Shiny fish", GOLD), ("bolt", "Live events", MB.MINT), ("globe", "7 worlds", (150, 220, 255))],
          17 * SS)
    badge(ui, (950 * SS, 212 * SS), 44 * SS)
    c.alpha_composite(ui.resize((w, h), Image.LANCZOS))
    c.convert("RGB").save(os.path.join(OUT, "feature_1024x500.png"), optimize=True)


def shots():
    d = os.path.join(OUT, "screenshots")
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    subprocess.run([GODOT, "--path", ROOT, "--fullscreen", "--", f"--capture={d}", "--play-shots"], check=True)
    for n in sorted(os.listdir(d)):
        im = Image.open(os.path.join(d, n))
        if im.size != (1920, 1080):
            sys.exit(f"{n} is {im.size[0]}x{im.size[1]}, not 1920x1080: run it on a 1920x1080 screen")
        im.convert("RGB").save(os.path.join(d, n), optimize=True)      # (Play takes no alpha in screenshots)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    open(os.path.join(OUT, ".gdignore"), "w").close()
    want = sys.argv[1:] or ["icon", "feature", "shots"]
    for k in want:
        {"icon": icon, "feature": feature, "shots": shots}[k]()
    for root, _dirs, files in os.walk(OUT):
        for n in sorted(files):
            if n.endswith(".png"):
                p = os.path.join(root, n)
                print(os.path.relpath(p, ROOT), Image.open(p).size, os.path.getsize(p) // 1024, "KB")

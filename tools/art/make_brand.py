"""fosh&fish brand kit (the 0.5.11 rebrand: white, chunky, tilted lettering with a leaping fish,
deep-sea teal and mint), all drawn here from the Fredoka font and simple shapes.

    python tools/art/make_brand.py            everything
    python tools/art/make_brand.py logo       just assets/brand/logo.png (quick look)

Writes to assets/brand/:
  logo.png                     stacked "fosh & fish" logo, transparent (title screen, covers, splash)
  icon_{64..1024}.png, icon.ico, android_192.png, android_fg_432.png, android_bg_432.png
  splash.png                   boot / web loading screen (deep sea, logo)
  cover_1920x1080.png, cover_1280x720.png, social_1280x640.png, itch_cover_630x500.png
The covers use assets/launcher/launcher_bg.jpg (tools/art/make_launcher.py).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BRAND = os.path.join(ROOT, "assets", "brand")
FONT = os.path.join(ROOT, "assets", "third_party", "fonts", "Fredoka.ttf")
ART = os.path.join(ROOT, "assets", "launcher", "launcher_bg.jpg")

WHITE = (255, 255, 255)
ICE = (214, 244, 255)          # the cool underside of the letters
EDGE = (120, 205, 236)         # the 3D edge
SHADOW = (8, 52, 72)
DEEP = (11, 41, 48)            # #0b2930
SEA = (18, 69, 79)             # #12454f
MINT = (95, 224, 189)          # #5fe0bd
AQUA = (47, 195, 198)


def font(size, wght=700, wdth=112):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_axes([wght, wdth])
    return f


def text_mask(text, size, wdth=104, track=-0.012):
    """chunky letters set tight (negative tracking, like the reference)"""
    f = font(size, 700, wdth)
    adv = [f.getlength(ch) for ch in text]
    total = sum(adv) + track * size * (len(text) - 1)
    m = Image.new("L", (int(total + size), int(size * 1.6)), 0)
    d = ImageDraw.Draw(m)
    x = size * 0.3
    for ch, a in zip(text, adv):
        d.text((x, size * 0.25), ch, font=f, fill=255)
        x += a + track * size
    return m.crop(m.getbbox())


def fish_mask(w):
    """a plump, friendly fish, nose to the right: forked tail, top fin, small eye (a hole) and a smile"""
    h = int(w * 0.62)
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((w * 0.24, h * 0.14, w * 0.99, h * 0.9), fill=255)                                       # body
    d.polygon([(w * 0.34, h * 0.52), (w * 0.03, h * 0.12), (w * 0.15, h * 0.52), (w * 0.03, h * 0.94)], fill=255)  # forked tail
    d.polygon([(w * 0.47, h * 0.2), (w * 0.58, h * 0.0), (w * 0.72, h * 0.18)], fill=255)              # top fin
    er = h * 0.062
    ex, ey = w * 0.81, h * 0.42
    d.ellipse((ex - er, ey - er, ex + er, ey + er), fill=0)                                             # eye
    d.arc((w * 0.74, h * 0.48, w * 0.95, h * 0.74), 25, 105, fill=0, width=max(2, int(w * 0.022)))      # smile
    d.arc((w * 0.5, h * 0.3, w * 0.64, h * 0.76), 300, 60, fill=0, width=max(2, int(w * 0.018)))       # gill
    return m


def drop_mask(s):
    """a water droplet, point up"""
    m = Image.new("L", (s, int(s * 1.45)), 0)
    d = ImageDraw.Draw(m)
    d.ellipse((0, s * 0.45, s, s * 1.45), fill=255)
    d.polygon([(s * 0.5, 0), (s * 0.06, s * 0.82), (s * 0.94, s * 0.82)], fill=255)
    return m


def swoosh_mask(w, h):
    """a bold wave of splash under the second line: thin at the start, fat in the middle, curling up into a
    pointed tip at the right end"""
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    top, bot = [], []
    n = 80
    for i in range(n + 1):
        t = i / n
        x = t * w
        rise = max(0.0, (t - 0.55) / 0.45) ** 1.7                 # the curl at the end
        y = h * (0.78 - 0.10 * math.sin(math.pi * t) - 0.66 * rise)
        th = h * 0.44 * (math.sin(math.pi * min(1.0, t * 1.0)) ** 0.7) * (1.0 - 0.5 * rise) + 1.5
        top.append((x, y - th * 0.55))
        bot.append((x, y + th * 0.45))
    d.polygon(top + bot[::-1], fill=255)
    return m


def paste_mask(canvas, mask, xy, angle=0.0):
    if angle:
        mask = mask.rotate(angle, resample=Image.BICUBIC, expand=True)
    canvas.paste(255, (int(xy[0]), int(xy[1])), mask) if False else canvas.paste(Image.new("L", mask.size, 255), (int(xy[0]), int(xy[1])), mask)


def styled(mask, scale=1.0, depth=None, shadow=True):
    """white letters with a cool gradient, a light-blue 3D edge and a soft deep-sea shadow"""
    depth = int(round((depth if depth is not None else 9) * scale))
    pad = int(40 * scale)
    W, H = mask.size[0] + pad * 2, mask.size[1] + pad * 2 + depth
    base = Image.new("L", (W, H), 0)
    base.paste(mask, (pad, pad))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if shadow:
        sh = base.copy()
        sh = ImageChops.offset(sh, int(6 * scale), int(depth + 10 * scale))
        sh = sh.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(7 * scale))
        out.paste(Image.new("RGBA", (W, H), SHADOW + (255,)), (0, 0), sh.point(lambda v: int(v * 0.55)))
    # extruded edge (stacked copies going down)
    edge_rgba = Image.new("RGBA", (W, H), EDGE + (255,))
    for i in range(depth, 0, -1):
        out.paste(edge_rgba, (0, 0), ImageChops.offset(base, 0, i))
    # a thin darker rim so it reads over white clouds too
    rim = base.filter(ImageFilter.MaxFilter(3))
    out.paste(Image.new("RGBA", (W, H), (60, 150, 190, 255)), (0, 0), ImageChops.subtract(rim, base).point(lambda v: int(v * 0.6)))
    # white face with a cool gradient towards the bottom of each line
    g = np.linspace(0.0, 1.0, H)[:, None]
    face = np.zeros((H, W, 3), np.float32)
    for c in range(3):
        face[..., c] = WHITE[c] + (ICE[c] - WHITE[c]) * np.clip((g - 0.35) / 0.65, 0, 1)
    out.paste(Image.fromarray(face.astype(np.uint8)).convert("RGBA"), (0, 0), base)
    # a soft highlight along the top
    hl = ImageChops.subtract(base, ImageChops.offset(base, 0, int(5 * scale))).filter(ImageFilter.GaussianBlur(1.2 * scale))
    out.paste(Image.new("RGBA", (W, H), (255, 255, 255, 255)), (0, 0), hl.point(lambda v: int(v * 0.5)))
    return out


def logo(scale=1.0, tilt=6.0):
    s = scale
    l1 = text_mask("fosh", int(300 * s))
    amp = text_mask("&", int(170 * s))
    l2 = text_mask("fish", int(300 * s))
    fish = fish_mask(int(170 * s))
    drops = [drop_mask(int(44 * s)), drop_mask(int(32 * s)), drop_mask(int(24 * s))]
    W = int(max(l1.size[0] + fish.size[0] + 20 * s, l2.size[0] + 210 * s) + 60 * s)
    H = int(l1.size[1] + l2.size[1] + 40 * s)
    m = Image.new("L", (W, H), 0)
    m.paste(255, (0, 0), l1)
    fx = l1.size[0] - 10 * s
    m.paste(Image.new("L", fish.rotate(18, expand=True, resample=Image.BICUBIC).size, 255), (int(fx), int(20 * s)),
            fish.rotate(18, expand=True, resample=Image.BICUBIC))
    y2 = l1.size[1] + 26 * s
    x2 = 160 * s
    m.paste(255, (int(x2 - amp.size[0] * 1.08), int(y2 + 30 * s)), amp)
    m.paste(255, (int(x2), int(y2)), l2)
    # (no splash wave under "fish": at small sizes it read as an underline - the leaping fish is the accent)
    m = m.crop(m.getbbox())
    st = styled(m, s)
    if tilt:
        st = st.rotate(tilt, resample=Image.BICUBIC, expand=True)
    return st.crop(st.getbbox())


# ------------------------------------------------------------------ icons
def rounded(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size - 1, size - 1), radius, fill=255)
    return m


def sea_gradient(w, h, top=AQUA, bottom=SEA, glow=True):
    y = np.linspace(0, 1, h)[:, None, None]
    x = np.linspace(-1, 1, w)[None, :, None]
    t = np.array(top, np.float32)[None, None, :]
    b = np.array(bottom, np.float32)[None, None, :]
    a = t + (b - t) * (y ** 0.9)
    if glow:
        r = np.sqrt(x ** 2 + ((y - 0.2) * 1.4) ** 2)
        a = a + np.clip(1 - r, 0, 1) * 38
    return Image.fromarray(np.clip(a.repeat(w, 1) if a.shape[1] == 1 else a, 0, 255).astype(np.uint8)[..., :3])


def icon_art(size, bg=True):
    """the app icon: a white fish leaping out of a splash on a sea-teal tile"""
    s = size / 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if bg:
        tile = sea_gradient(size, size).convert("RGBA")
        img.paste(tile, (0, 0), rounded(size, int(230 * s)))
    art = Image.new("L", (size, size), 0)
    # water: two waves across the lower part
    d = ImageDraw.Draw(art)
    for k, (yy, amp_, th) in enumerate([(0.74, 26, 34), (0.86, 20, 26)]):
        pts = []
        for i in range(81):
            x = size * (0.12 + 0.76 * i / 80)
            y = size * yy + math.sin(i / 80 * math.pi * 3 + k) * amp_ * s
            pts.append((x, y))
        d.line(pts, fill=255, width=int(th * s), joint="curve")
        for p in (pts[0], pts[-1]):
            r = th * s / 2
            d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=255)
    fish = fish_mask(int(600 * s)).rotate(28, expand=True, resample=Image.BICUBIC)
    art.paste(255, (int(size * 0.5 - fish.size[0] / 2 + 10 * s), int(size * 0.18)), fish)
    for (dx, dy, ds, ang) in [(0.2, 0.52, 70, 30), (0.29, 0.4, 48, 20), (0.78, 0.5, 56, -25), (0.84, 0.38, 36, -15)]:
        dm = drop_mask(int(ds * s)).rotate(ang, expand=True, resample=Image.BICUBIC)
        art.paste(255, (int(size * dx), int(size * dy)), dm)
    # shadow + white art + a soft gloss
    sh = ImageChops.offset(art, int(10 * s), int(16 * s)).filter(ImageFilter.GaussianBlur(14 * s))
    img.paste(Image.new("RGBA", (size, size), SHADOW + (255,)), (0, 0), sh.point(lambda v: int(v * 0.45)))
    edge = ImageChops.offset(art, 0, int(9 * s))
    img.paste(Image.new("RGBA", (size, size), EDGE + (255,)), (0, 0), edge)
    face = Image.new("RGBA", (size, size), WHITE + (255,))
    img.paste(face, (0, 0), art)
    if bg:
        gl = Image.new("L", (size, size), 0)
        ImageDraw.Draw(gl).ellipse((-0.3 * size, -0.62 * size, 1.3 * size, 0.42 * size), fill=60)
        gl = ImageChops.multiply(gl, rounded(size, int(230 * s))).filter(ImageFilter.GaussianBlur(8 * s))
        img.paste(Image.new("RGBA", (size, size), (255, 255, 255, 255)), (0, 0), gl)
    return img


def save_icons():
    big = icon_art(1024)
    big.save(os.path.join(BRAND, "icon_1024.png"))
    for n in [512, 256, 192, 180, 144, 128, 64]:
        big.resize((n, n), Image.LANCZOS).save(os.path.join(BRAND, "icon_%d.png" % n))
    big.resize((192, 192), Image.LANCZOS).save(os.path.join(BRAND, "android_192.png"))
    big.save(os.path.join(BRAND, "icon.ico"), sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    # Android adaptive: the art inside the 66% safe zone over a full-bleed sea background
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    inner = icon_art(300, bg=False)
    fg.alpha_composite(inner, (66, 66))
    fg.save(os.path.join(BRAND, "android_fg_432.png"))
    sea_gradient(432, 432).save(os.path.join(BRAND, "android_bg_432.png"))


# ------------------------------------------------------------------ splash + covers
def splash():
    w, h = 1920, 1080
    bg = sea_gradient(w, h, top=SEA, bottom=DEEP).convert("RGBA")
    lg = logo(1.05)
    bg.alpha_composite(lg, ((w - lg.size[0]) // 2, (h - lg.size[1]) // 2 - 40))
    f = font(34, 500, 100)
    d = ImageDraw.Draw(bg)
    d.text((w / 2, (h + lg.size[1]) / 2 + 30), "a cozy fishing game  ·  by afosh", font=f, fill=(169, 214, 216), anchor="mm")
    bg.convert("RGB").save(os.path.join(BRAND, "splash.png"), optimize=True)


def cover(w, h, logo_w, pos, name, tagline=True, crop_focus=(0.5, 0.5)):
    art = Image.open(ART).convert("RGB")
    s = max(w / art.size[0], h / art.size[1])
    art = art.resize((int(art.size[0] * s + 0.5), int(art.size[1] * s + 0.5)), Image.LANCZOS)
    x = int((art.size[0] - w) * crop_focus[0])
    y = int((art.size[1] - h) * crop_focus[1])
    c = art.crop((x, y, x + w, y + h)).convert("RGBA")
    lg = logo(1.0)
    lg = lg.resize((logo_w, int(lg.size[1] * logo_w / lg.size[0])), Image.LANCZOS)
    lx, ly = int(pos[0] * w - lg.size[0] / 2), int(pos[1] * h - lg.size[1] / 2)
    c.alpha_composite(lg, (lx, ly))
    if tagline:
        f = font(max(16, int(logo_w * 0.052)), 500, 100)
        text = "a cozy fishing game  ·  by afosh"
        tw = f.getlength(text)
        th = f.size * 1.9
        px, py = lx + lg.size[0] / 2, ly + lg.size[1] + th * 0.45
        pill = Image.new("RGBA", c.size, (0, 0, 0, 0))
        ImageDraw.Draw(pill).rounded_rectangle((px - tw / 2 - th * 0.6, py - th / 2, px + tw / 2 + th * 0.6, py + th / 2), int(th / 2),
                                               fill=(11, 41, 48, 140))
        c.alpha_composite(pill)
        ImageDraw.Draw(c).text((px, py), text, font=f, fill=(255, 255, 255), anchor="mm")
    c.convert("RGB").save(os.path.join(BRAND, name), optimize=True)


if __name__ == "__main__":
    os.makedirs(BRAND, exist_ok=True)
    lg = logo(1.0)
    lg.save(os.path.join(BRAND, "logo.png"), optimize=True)
    print("logo.png", lg.size)
    if "logo" in sys.argv[1:]:
        sys.exit()
    save_icons()
    splash()
    cover(1920, 1080, 720, (0.33, 0.24), "cover_1920x1080.png")
    cover(1280, 720, 480, (0.33, 0.24), "cover_1280x720.png")
    cover(1280, 640, 470, (0.33, 0.25), "social_1280x640.png")
    cover(630, 500, 330, (0.5, 0.25), "itch_cover_630x500.png", crop_focus=(0.12, 0.5))
    for n in sorted(os.listdir(BRAND)):
        if n.endswith((".png", ".ico")):
            print(n, os.path.getsize(os.path.join(BRAND, n)) // 1024, "KB")

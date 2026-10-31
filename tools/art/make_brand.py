"""fosh&fish brand kit: chunky golden 3D letters, a life ring for the "o", a leaping fish.

    python tools/art/make_brand.py            everything
    python tools/art/make_brand.py logo       just assets/brand/logo.png (quick look)

Writes to assets/brand/:
  logo.png                     stacked "fosh & fish" logo, transparent (title screen, covers, splash)
  icon_{64..1024}.png, icon.ico, android_192.png, android_fg_432.png, android_bg_432.png
  splash.png                   boot / web loading screen (deep sea, logo)
  cover_1920x1080.png, cover_1280x720.png, social_1280x640.png, itch_cover_630x500.png
The art comes from Blender: tools/blender/render_assets.py -- brand (assets/brand/src).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
from scipy.ndimage import distance_transform_edt, gaussian_filter, map_coordinates, median_filter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BRAND = os.path.join(ROOT, "assets", "brand")
SRC = os.path.join(BRAND, "src")               # tools/blender/render_assets.py -- brand
NAVY = (13, 43, 58)
FONT = os.path.join(ROOT, "assets", "third_party", "fonts", "Fredoka.ttf")
ART = os.path.join(ROOT, "assets", "launcher", "title_bg.jpg")

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


def sticker(img, width, color=NAVY, shadow=True, shadow_y=None):
    """a thick, even, rounded outline around everything in the picture (and a soft shadow under it): whatever it's
    put on, it stands out, and the pieces read as one thing"""
    pad = int(width * 3.2)
    w, h = img.size
    out = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    a = np.zeros((h + pad * 2, w + pad * 2), np.float32)
    a[pad:pad + h, pad:pad + w] = np.asarray(img.getchannel("A"), np.float32) / 255.0
    dist = distance_transform_edt(a < 0.5)
    ring = np.clip(width + 1.0 - dist, 0.0, 1.0)                            # 1 inside the outline, soft at its edge
    mask = Image.fromarray((ring * 255).astype(np.uint8))
    if shadow:
        sy = int(width * 0.9) if shadow_y is None else shadow_y
        sh = ImageChops.offset(mask, 0, sy).filter(ImageFilter.GaussianBlur(width * 0.7))
        out.paste(Image.new("RGBA", out.size, SHADOW + (255,)), (0, 0), sh.point(lambda v: int(v * 0.42)))
    out.paste(Image.new("RGBA", out.size, color + (255,)), (0, 0), mask)
    out.alpha_composite(img, (pad, pad))
    return out.crop(out.getbbox())


def logo(scale=1.0):
    """the 3D logo (tools/blender/vf_brand.py) as a sticker, about 1000 px wide at scale 1"""
    raw = Image.open(os.path.join(SRC, "logo_3d.png")).convert("RGBA")
    raw = raw.crop(raw.getbbox())
    width = int(1000 * scale)
    raw = raw.resize((width, int(raw.size[1] * width / raw.size[0])), Image.LANCZOS)
    return sticker(raw, max(4, int(width * 0.013)))


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


def icon_tile(size):
    """sunny water: bright at the top, deep at the bottom, with a soft wave across it"""
    y = np.linspace(0, 1, size)[:, None, None]
    top, bot = np.array((132, 226, 236), np.float32), np.array((16, 112, 140), np.float32)
    a = np.repeat(top + (bot - top) * y ** 1.15, size, axis=1)
    tile = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert("RGBA")
    d = Image.new("L", (size, size), 0)
    pts = [(0, size)]
    for i in range(81):
        x = size * i / 80
        pts.append((x, size * 0.7 + math.sin(i / 80 * math.pi * 2.6 + 0.4) * size * 0.028))
    pts.append((size, size))
    ImageDraw.Draw(d).polygon(pts, fill=255)
    tile.paste(Image.new("RGBA", (size, size), (10, 86, 116, 255)), (0, 0), d.point(lambda v: int(v * 0.5)))
    return tile


def icon_art(size, bg=True):
    """the app icon: a fish leaping through a life ring (tools/blender/vf_brand.py) on sunny water"""
    s = size / 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if bg:
        img.paste(icon_tile(size), (0, 0), rounded(size, int(230 * s)))
    raw = Image.open(os.path.join(SRC, "icon_3d.png")).convert("RGBA")
    raw = raw.crop(raw.getbbox())
    k = size * 0.86 / max(raw.size)
    art = raw.resize((int(raw.size[0] * k), int(raw.size[1] * k)), Image.LANCZOS)
    art = sticker(art, max(2, int(size * 0.012)))
    img.alpha_composite(art, ((size - art.size[0]) // 2, (size - art.size[1]) // 2))
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
    icon_tile(432).convert("RGB").save(os.path.join(BRAND, "android_bg_432.png"))


# ------------------------------------------------------------------ the loading screen's picture
def title():
    """The layers of tools/blender/vf_brand.py render_title -> what the game loads (assets/launcher):
    title_bg.jpg (with the world mirrored in the water, and the boat's reflection and foam), title_boat.png (it bobs),
    title_masks.png (R the water, G what the wind moves, for the title screen's shader). -> the boat's place, 0..1"""
    rgb = lambda n: np.asarray(Image.open(os.path.join(SRC, n)).convert("RGB"), np.float32) / 255.0
    a = rgb("title_a.png")
    H, W = a.shape[:2]
    mask = Image.open(os.path.join(SRC, "title_mask.png")).convert("RGBA")
    water = np.asarray(mask.getchannel("A").resize((W, H), Image.BILINEAR), np.float32) / 255.0
    # the reflection: each column mirrored about where the water starts in it, the waves breaking it up more further out
    wet = water > 0.5
    top = np.where(wet.any(axis=0), wet.argmax(axis=0), H)
    top = gaussian_filter(median_filter(top, size=15).astype(np.float32), sigma=26.0)     # (no seams where the dock and the shop start)
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    far = np.clip((yy - top[None, :]) / (H - top[None, :] + 1.0), 0.0, 1.0)
    wob = np.sin(yy * 0.19 + xx * 0.012) + 0.6 * np.sin(yy * 0.41 - xx * 0.021 + 1.3) + 0.35 * np.sin(yy * 0.83 + 2.1)
    sx = np.clip(xx + wob * (1.0 + far * 6.0), 0, W - 1)
    sy = np.clip(top[None, :] - (yy - top[None, :]) * 0.92, 0, H - 1)
    mirror = np.stack([map_coordinates(a[..., c], [sy, sx], order=1) for c in range(3)], axis=-1)
    mirror = gaussian_filter(mirror, sigma=(3.5, 1.0, 0))
    mirror = mirror * 0.72 + a * 0.28                                 # (calmer: it never quite hides the water's colour)
    k = (0.62 - 0.44 * far)[..., None] * water[..., None]
    out = a * (1.0 - k) + mirror * k
    # small dark and light ripples, more of them near the camera
    n = gaussian_filter(np.random.default_rng(5).normal(0, 1, (H, W)), sigma=(1.1, 9.0))
    n = n / n.std()
    out = out + (np.clip(n, -2.0, 2.0) * (0.012 + 0.016 * far) * water)[..., None]
    # the boat: its reflection and the foam along its waterline
    boat = np.asarray(Image.open(os.path.join(SRC, "title_boat.png")).convert("RGBA"), np.float32) / 255.0
    # (the columns of the hull itself, not the rod and the line: the lowest thick run of pixels)
    thick = gaussian_filter((boat[..., 3] > 0.5).astype(np.float32), sigma=(6.0, 0)) > 0.45
    keel = np.where(thick.any(axis=0), H - 1 - thick[::-1].argmax(axis=0), -1)
    keel[keel < H * 0.8] = -1                                         # (that's the rod, or his legs: the hull sits lower)
    cols = np.where(keel >= 0)[0]
    x0, x1 = int(cols.min()), int(cols.max())
    keel = median_filter(keel, size=9)
    has = (keel >= 0)[None, :]
    # (smooth, or the foam and the reflection come out in stair steps; the columns with no hull take their neighbours' value)
    filled = np.interp(np.arange(W), np.where(keel >= 0)[0], keel[keel >= 0]).astype(np.float32)
    ky = gaussian_filter(filled, sigma=4.0)[None, :]
    below = np.clip((yy - ky) / 170.0, 0.0, 1.0)
    bsx = np.clip(xx + wob * (1.0 + below * 7.0), 0, W - 1)
    bsy = np.clip(ky - (yy - ky) * 0.95, 0, H - 1)
    refl = np.stack([map_coordinates(boat[..., c], [bsy, bsx], order=1) for c in range(4)], axis=-1)
    refl = gaussian_filter(refl, sigma=(1.8, 0.6, 0))
    ra = refl[..., 3] * (yy > ky) * has * (0.55 - 0.3 * below)
    out = out * (1.0 - ra[..., None]) + refl[..., :3] * ra[..., None]
    shade = gaussian_filter(((yy > ky) & (yy < ky + 26) & has).astype(np.float32), sigma=(7.0, 9.0)) * 0.3
    out = out * (1.0 - shade[..., None]) + np.array((0.02, 0.14, 0.22), np.float32) * shade[..., None]
    fn = gaussian_filter(np.random.default_rng(9).normal(0, 1, (H, W)), sigma=(1.0, 7.0))
    fn = fn / fn.std()
    d = np.abs(yy - ky - 2.0 - fn * 2.0)
    foam = np.clip(1.0 - d / 4.0, 0.0, 1.0) * has * water
    out = out * (1.0 - foam[..., None] * 0.9) + foam[..., None] * 0.9
    # a soft, warm vignette
    r = np.sqrt(((xx / W - 0.5) * 1.15) ** 2 + ((yy / H - 0.5) * 1.05) ** 2)
    out = out * (1.0 - np.clip(r - 0.42, 0.0, 1.0)[..., None] * np.array((0.28, 0.36, 0.42), np.float32))
    bg = Image.fromarray((np.clip(out, 0.0, 1.0) * 255).astype(np.uint8))
    d = os.path.join(ROOT, "assets", "launcher")
    os.makedirs(d, exist_ok=True)
    bg.save(os.path.join(d, "title_bg.jpg"), quality=90, optimize=True)
    # the boat, trimmed
    bi = Image.open(os.path.join(SRC, "title_boat.png")).convert("RGBA")
    box = bi.getbbox()
    bi.crop(box).save(os.path.join(d, "title_boat.png"), optimize=True)
    # R the water, G what sways
    sway = Image.open(os.path.join(SRC, "title_sway.png")).convert("L").resize((W // 2, H // 2), Image.BILINEAR)
    m = Image.merge("RGB", (mask.getchannel("A").resize((W // 2, H // 2), Image.BILINEAR), sway, Image.new("L", (W // 2, H // 2), 0)))
    m.save(os.path.join(d, "title_masks.png"), optimize=True)
    place = [round(box[0] / W, 4), round(box[1] / H, 4), round(box[2] / W, 4), round(box[3] / H, 4)]
    print("title_boat at", place, "waterline at x", x0, x1)
    return place


# ------------------------------------------------------------------ splash + covers
def splash():
    """boot / web loading screen: the title picture and the logo, small to download"""
    w, h = 1024, 576
    bg = Image.open(ART).convert("RGB").resize((w, h), Image.LANCZOS).convert("RGBA")
    boat = Image.open(os.path.join(SRC, "title_boat.png")).convert("RGBA").resize((w, h), Image.LANCZOS)
    bg.alpha_composite(boat)
    lg = logo(0.36)
    bg.alpha_composite(lg, (int(w * 0.035), int(h * 0.06)))
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
    title()
    if "title" in sys.argv[1:]:
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

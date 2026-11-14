"""The fish, from pictures the owner had made (an image model; the prompts are in the chat of 2026-11-14), in place of
the Blender ones: tools/art/fish_source_<n>.webp, three to a sheet, side on, on flat grey.

Each fish is cut from the grey, then:
  assets/vf/fish/<slug>.png   its picture (catch card, Fish Book, shop): 256 px, where the old one was, the same size
  assets/vf/mini/<slug>.png   the side view that swims (Reel it in!, the aquarium, FishTok skits): 4 frames of 224 px.
                              The picture is one still, so the swim is made here: the tail half bends up and down and
                              shortens (as a tail does when it swings towards you); the head, eye and mouth stay put.
  assets/vf/shiny/<slug>.png  its shiny: another colour (SHINY), a gold rim and three twinkles
  manifest.json mini.fish     where its eye and mouth are, how big the eye is, the skin colour by the eye ("lid"), a
                              second eye if it shows two ("eye2"), and "own": true: the picture has a face already, so
                              the game leaves it alone and only draws over it for a blink, a nap or a fright.

    python tools/art/make_fish.py [slug ...]     -> the files above, and build/fish_check.png
    then: godot --headless --path . --import     (or the game keeps showing the old pictures)

tools/blender/render_assets.py and render_v1.py would put the old ones back: run this again after them.
"""
import colorsys
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "vf")
# name, sheet, the box it is in (x0, x1), its eye (x, y, radius of the white) and mouth (x, y), measured on the sheet,
# where the bend starts (0 nose .. 1 tail), how far it bends, and anything odd about it:
#   eye2: a second eye; glow: a box where light spills onto the grey (cut soft); sway: it hangs down, so it sways instead
FISH = [
    ("Raw Fish", 2, 50, 630, (516.4, 317.4, 29.8), (553, 366), 0.42, 0.05, {}),
    ("Raw Salmon", 2, 708, 1311, (1200.0, 309.8, 30.7), (1248, 360), 0.42, 0.05, {}),
    ("Cod", 1, 20, 680, (545.5, 307.0, 28.0), (602, 346), 0.42, 0.05, {}),
    ("Tropical Fish", 2, 1416, 1925, (1813.0, 301.0, 31.0), (1869, 349), 0.6, 0.045, {}),
    ("Pufferfish", 1, 760, 1230, (1102.5, 284.5, 29.5), (1160, 322), 0.66, 0.045, {}),
    ("Fiery Pufferfish", 3, 37, 524, (401.4, 288.8, 35.1), (465, 333), 0.66, 0.045, {}),
    ("Hot Cod", 3, 631, 1311, (1185.6, 300.8, 35.4), (1245, 347), 0.42, 0.05, {}),
    ("Squid", 3, 1394, 1965, (1848.2, 303.2, 36.9), (1906, 347), 0.35, 0.05, {}),
    ("Turtle", 4, 27, 631, (511.8, 239.2, 29.4), (562, 294), 0.55, 0.02, {}),
    ("Dolphin", 4, 650, 1341, (1166.6, 250.8, 31.9), (1248, 312), 0.45, 0.05, {}),
    ("Guardian", 4, 1383, 1967, (1827.6, 290.0, 41.5), (1852, 385), 0.62, 0.03, {}),
    ("Emerald Squid", 5, 53, 619, (338.4, 342.0, 34.2), (411, 369), 0.5, 0.03, {"sway": True}),
    ("Rainbow Fish", 5, 671, 1268, (1137.2, 295.6, 39.9), (1206, 347), 0.5, 0.05, {}),
    ("Space Fish", 5, 1340, 1950, (1818.2, 314.4, 36.0), (1891, 362), 0.5, 0.05, {}),
    ("Galactic Crab", 6, 60, 653, (429.5, 251.5, 40.0), (390, 353), 0.5, 0.0, {"eye2": (302.6, 256.4, 40.0)}),
    ("Shark", 1, 1330, 1990, (1844.0, 321.0, 29.0), (1870, 382), 0.45, 0.05, {}),
    ("Alien Fish", 6, 671, 1338, (1108.0, 315.2, 40.5), (1183, 371), 0.5, 0.045, {"glow": (1170, 130, 1338, 300)}),
    ("Artifact Fish", 6, 1331, 1953, (1811.0, 313.0, 42.0), (1882, 363), 0.5, 0.04, {}),
    ("Dark Puffer", 7, 73, 793, (589.4, 345.6, 59.4), (704, 426), 0.7, 0.04, {}),
    ("Dark Tuna", 7, 922, 1916, (1728.0, 357.4, 48.6), (1807, 445), 0.45, 0.05, {}),
]
MINI_CELL, MINI_FRAMES = 224, 4
MINI_BOX = (11, 213, 150)        # the old ones: from x, to x, and no taller than this
PIC_BOX = (16, 231, 190)
SHINY_BOX = (30, 226, 170)       # a little smaller: room for the rim and the twinkles
GOLD = (255, 207, 58)


def slug(name: str) -> str:
    return name.lower().replace(" ", "_")


def cut(rgb: np.ndarray, bg: float, glow=None):
    """the fish off the grey: (RGB with the rim cleaned, alpha 0..1). glow: a box where its light fades into the grey."""
    diff = np.abs(rgb - bg).max(axis=2)
    lab, _ = ndimage.label(diff <= 9.0)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    solid = ndimage.binary_fill_holes(~np.isin(lab, edge[edge > 0]))
    lab2, n = ndimage.label(solid)                       # the fish is the biggest thing here
    if n > 1:
        sizes = ndimage.sum(solid, lab2, range(1, n + 1))
        solid = lab2 == (1 + int(np.argmax(sizes)))
    core = ndimage.binary_erosion(solid, iterations=2)   # the rim is half grey: its colour comes from just inside
    idx = ndimage.distance_transform_edt(~core, return_distances=False, return_indices=True)
    col = np.where(core[..., None], rgb, rgb[idx[0], idx[1]])
    alpha = ndimage.gaussian_filter(ndimage.binary_erosion(solid, iterations=1).astype(np.float32), 0.9)
    if glow:                                             # light on grey: the less it differs, the more see-through
        x0, y0, x1, y1 = glow
        soft = np.clip((diff[y0:y1, x0:x1] - 4.0) / 55.0, 0.0, 1.0)
        pure = bg + (rgb[y0:y1, x0:x1] - bg) / np.maximum(soft, 0.08)[..., None]
        col[y0:y1, x0:x1] = np.clip(pure, 0, 255)
        alpha[y0:y1, x0:x1] *= soft
    return col, np.clip(alpha, 0.0, 1.0)


def swim(col: np.ndarray, alpha: np.ndarray, bend_from: float, amp: float, phase: float, sway_from=None):
    """one frame: the tail half bent (up or down) and drawn in a little, the rest as it is. sway_from: for one that
    hangs down (a squid seen from the front), everything below that row swings from side to side instead."""
    if amp <= 0.0: return col, alpha
    h, w = alpha.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    if sway_from is not None:
        ys = np.nonzero(alpha.max(axis=1) > 0.5)[0]
        k = np.clip((yy - sway_from) / (float(ys.max()) - sway_from), 0.0, 1.2)
        k = k * k
        dx = amp * (float(ys.max()) - float(ys.min())) * k * np.sin(phase + yy * 0.012)
        dy = np.zeros_like(dx)
    else:
        xs = np.nonzero(alpha.max(axis=0) > 0.5)[0]
        x_tail, x_nose = float(xs.min()), float(xs.max())
        length = x_nose - x_tail
        u = np.clip((x_nose - xx) / length, 0.0, 1.2)
        k = np.clip((u - bend_from) / (1.0 - bend_from), 0.0, 1.2)
        k = k * k * (3.0 - 2.0 * np.minimum(k, 1.0))    # eases in: no kink where the bend starts
        dy = amp * length * k * math.sin(phase)
        dx = 0.045 * length * k * math.sin(phase) ** 2   # towards the head
    pre = np.dstack([col * alpha[..., None], alpha])
    out = [ndimage.map_coordinates(pre[..., c], [yy - dy, xx - dx], order=1, mode="constant", cval=0.0) for c in range(4)]
    a = np.clip(out[3], 0.0, 1.0)
    return np.clip(np.dstack(out[:3]) / np.maximum(a, 1e-4)[..., None], 0, 255), a


def to_image(col: np.ndarray, alpha: np.ndarray) -> Image.Image:
    return Image.fromarray(np.dstack([col, alpha * 255.0]).round().astype(np.uint8), "RGBA")


def place(img: Image.Image, bbox, cell: int, box):
    """fitted where the old one was: (the cell, scale, offset) so a source point p lands at p * scale + offset"""
    x0, x1, hmax = box
    bw, bh = bbox[2] - bbox[0], bbox[3] - bbox[1]
    s = min((x1 - x0) / bw, hmax / bh)
    small = img.resize((max(1, round(img.width * s)), max(1, round(img.height * s))), Image.LANCZOS)
    ox = (x0 + x1) * 0.5 - (bbox[0] + bbox[2]) * 0.5 * s
    oy = cell * 0.5 - (bbox[1] + bbox[3]) * 0.5 * s
    out = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
    out.alpha_composite(small, (round(ox), round(oy)))
    return out, s, (round(ox), round(oy))


# The shinies: another colour for each, as tools/blender/render_v1.py picked them (its SHINY table: the same hues).
#   shift: turn every colour round until its main one is this hue (x saturation)      tint: a grey fish takes this hue
#   set: everything this hue (x saturation, and lightened towards white by 1 - b)      silver: its gold goes silver
SHINY = {
    "Raw Fish": ("tint", 46, 0.55, 1.0), "Raw Salmon": ("shift", 199, 1.0, 1.0), "Cod": ("shift", 334, 1.15, 1.0),
    "Tropical Fish": ("shift", 210, 1.0, 1.0), "Pufferfish": ("shift", 145, 1.0, 1.0), "Fiery Pufferfish": ("shift", 217, 1.0, 1.0),
    "Hot Cod": ("shift", 262, 1.0, 1.0), "Squid": ("shift", 160, 1.3, 1.0), "Turtle": ("shift", 217, 1.0, 1.0),
    "Dolphin": ("shift", 330, 1.0, 1.0), "Guardian": ("shift", 262, 1.0, 1.0), "Emerald Squid": ("shift", 0, 1.0, 1.0),
    "Rainbow Fish": ("set", 45, 1.0, 1.0), "Space Fish": ("shift", 175, 1.0, 1.0), "Galactic Crab": ("shift", 0, 1.0, 1.0),
    "Shark": ("shift", 225, 2.2, 1.0), "Alien Fish": ("shift", 350, 1.0, 1.0), "Artifact Fish": ("silver", 0, 0.12, 1.0),
    "Dark Puffer": ("set", 270, 0.15, 0.4), "Dark Tuna": ("shift", 0, 1.0, 1.0),
}


def recolour(col: np.ndarray, alpha: np.ndarray, spec, keep: np.ndarray) -> np.ndarray:
    """its shiny colours. keep: 0..1, where the picture stays as it is (the eyes, the mouth)."""
    mode, hue, a, b = spec
    hsv = np.asarray(Image.fromarray(col.round().astype(np.uint8), "RGB").convert("HSV")).astype(np.float32) / 255.0
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    target = hue / 360.0
    if mode == "shift":
        w = alpha * s * (1.0 - keep)
        main = math.atan2(float((np.sin(h * math.tau) * w).sum()), float((np.cos(h * math.tau) * w).sum())) / math.tau
        h2, s2, v2 = (h + target - main) % 1.0, np.clip(s * a, 0, 1), v
    elif mode == "tint":
        h2, s2, v2 = np.full_like(h, target), np.clip(s + a * np.clip((0.95 - v) / 0.35, 0, 1), 0, 1), v
    elif mode == "set":
        h2, s2, v2 = np.full_like(h, target), np.clip(s * a, 0, 1), 1.0 - (1.0 - v) * b
    else:                                                # silver: the gold loses its colour, the rest turns pink
        gold = (h > 20 / 360.0) & (h < 65 / 360.0)
        h2, s2, v2 = np.where(gold, h, (h + 140 / 360.0) % 1.0), np.where(gold, s * a, s), np.where(gold, np.clip(v * 1.05, 0, 1), v)
    out = np.asarray(Image.fromarray((np.dstack([h2, s2, v2]) * 255.0).round().astype(np.uint8), "HSV").convert("RGB")).astype(np.float32)
    return out * (1.0 - keep[..., None]) + col * keep[..., None]


def shiny_card(fish: Image.Image) -> Image.Image:
    """the recoloured fish in its cell, with a gold rim and three twinkles"""
    a = np.asarray(fish)[..., 3].astype(np.float32) / 255.0
    rim = np.clip(ndimage.gaussian_filter(ndimage.grey_dilation(a, size=(7, 7)), 0.7), 0, 1)
    out = Image.fromarray(np.dstack([np.full(a.shape + (3,), GOLD, np.float32), rim * 255.0]).round().astype(np.uint8), "RGBA")
    out.alpha_composite(fish)
    x0, y0, x1, y1 = fish.getchannel("A").getbbox()
    d = ImageDraw.Draw(out)
    for (fx, fy, r) in [(0.1, -0.02, 15), (0.93, 0.12, 11), (0.3, 1.02, 9)]:
        cx = min(max(x0 + (x1 - x0) * fx, r + 2), 254 - r)
        cy = min(max(y0 + (y1 - y0) * fy, r + 2), 254 - r)
        pts = []
        for i in range(8):
            rr = r if i % 2 == 0 else r * 0.3
            pts.append((cx + math.sin(i * math.pi / 4) * rr, cy - math.cos(i * math.pi / 4) * rr))
        d.polygon(pts, fill=(255, 247, 194, 255), outline=(214, 158, 46, 255))
    return out


def main() -> None:
    only = set(sys.argv[1:])
    man_path = os.path.join(OUT, "manifest.json")
    man = json.load(open(man_path, encoding="utf-8"))
    sheets = {}
    rows = []
    for name, sheet_n, bx0, bx1, eye, mouth, bend_from, amp, odd in FISH:
        if only and slug(name) not in only: continue
        if sheet_n not in sheets:
            px = np.asarray(Image.open(os.path.join(ROOT, "tools", "art", "fish_source_%d.webp" % sheet_n)).convert("RGB")).astype(np.float32)
            sheets[sheet_n] = (px, float(np.median(np.concatenate([px[:6].reshape(-1, 3), px[-6:].reshape(-1, 3)]))))
        sheet, bg = sheets[sheet_n]
        pad = 40
        part = np.full((sheet.shape[0] + pad * 2, bx1 - bx0 + pad * 2, 3), bg, np.float32)
        part[pad:-pad, pad:-pad] = sheet[:, bx0:bx1]
        glow = odd.get("glow")
        if glow: glow = (glow[0] - bx0 + pad, glow[1] + pad, glow[2] - bx0 + pad, glow[3] + pad)
        col, alpha = cut(part, bg, glow)
        ys, xs = np.nonzero(alpha > 0.5)
        bbox = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        ex, ey, er = eye[0] - bx0 + pad, eye[1] + pad, eye[2]
        mx, my = mouth[0] - bx0 + pad, mouth[1] + pad
        gy, gx = np.mgrid[0:part.shape[0], 0:part.shape[1]]
        far = np.hypot(gx - ex, gy - ey)
        lid = np.median(part[(far > er * 1.2) & (far < er * 1.5) & (alpha > 0.99)], axis=0)
        eyes = [(ex, ey, er)]
        if "eye2" in odd: eyes.append((odd["eye2"][0] - bx0 + pad, odd["eye2"][1] + pad, odd["eye2"][2]))

        pic, _, _ = place(to_image(col, alpha), bbox, 256, PIC_BOX)
        pic.save(os.path.join(OUT, "fish", slug(name) + ".png"))

        keep = np.clip(1.3 - np.hypot(gx - mx, gy - my) / (er * 0.9), 0, 1)       # the mouth stays red, the eyes as they are
        for (x, y, r) in eyes: keep = np.maximum(keep, np.clip((r * 1.25 - np.hypot(gx - x, gy - y)) / 4.0, 0, 1))
        small, _, _ = place(to_image(recolour(col, alpha, SHINY[name], keep.astype(np.float32)), alpha), bbox, 256, SHINY_BOX)
        shiny = shiny_card(small)
        shiny.save(os.path.join(OUT, "shiny", slug(name) + ".png"))

        strip = Image.new("RGBA", (MINI_CELL * MINI_FRAMES, MINI_CELL), (0, 0, 0, 0))
        s, off = 1.0, (0, 0)
        for f in range(MINI_FRAMES):
            fc, fa = swim(col, alpha, bend_from, amp, f * math.tau / MINI_FRAMES, (ey + er) if odd.get("sway") else None)
            cell, s, off = place(to_image(fc, fa), bbox, MINI_CELL, MINI_BOX)
            strip.alpha_composite(cell, (f * MINI_CELL, 0))
        strip.save(os.path.join(OUT, "mini", slug(name) + ".png"))
        at = lambda x, y: [round(float(x * s + off[0]) / MINI_CELL, 4), round(float(y * s + off[1]) / MINI_CELL, 4)]
        info = {"eye": at(ex, ey), "mouth": at(mx, my), "er": round(float(er * 1.04 * s) / MINI_CELL / 1.9, 4),   # (the game draws it 1.9 x this)
                "lid": "#%02x%02x%02x" % tuple(int(v) for v in lid), "own": True}
        if len(eyes) > 1: info["eye2"] = at(eyes[1][0], eyes[1][1])
        man["mini"]["fish"][name] = info
        print(name, "scale", round(s, 3), info)
        rows.append([pic, shiny, strip])
    with open(man_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True)       # (as tools/blender/render_assets.py writes it)
    per = (len(rows) + 1) // 2
    check = Image.new("RGBA", (704 * 2, 128 * max(1, per)), (38, 96, 110, 255))
    for i, (pic, shiny, strip) in enumerate(rows):
        x, y = (i // per) * 704, (i % per) * 128
        check.alpha_composite(pic.resize((128, 128), Image.LANCZOS), (x, y))
        check.alpha_composite(shiny.resize((128, 128), Image.LANCZOS), (x + 128, y))
        check.alpha_composite(strip.resize((448, 112), Image.LANCZOS), (x + 256, y + 8))
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    check.convert("RGB").save(os.path.join(ROOT, "build", "fish_check.png"))


if __name__ == "__main__":
    main()

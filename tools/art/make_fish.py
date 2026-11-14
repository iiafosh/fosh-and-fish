"""Fish from a picture the owner had made (an image model; the prompt is in the chat of 2026-11-14), in place of the
Blender ones: a trial with three (tools/art/fish_source_test.webp: cod, pufferfish, shark, side on, on flat grey).

Each fish is cut from the grey, then:
  assets/vf/fish/<slug>.png   its picture (catch card, Fish Book, shop): 256 px, where the old one was, the same size
  assets/vf/mini/<slug>.png   the side view that swims (Reel it in!, the aquarium): 4 frames of 224 px. The picture is
                              one still, so the swim is made here: the tail half bends up and down and shortens
                              (as a tail does when it swings towards you); the head, eye and mouth stay put.
  manifest.json mini.fish     where its eye and mouth are, how big the eye is, the skin colour by the eye ("lid"),
                              and "own": true: the picture has a face already, so the game draws its eye over the
                              painted one (glossy, same place, same size) and leaves the mouth alone.

    python tools/art/make_fish.py        -> the files above, and build/fish_check.png

tools/blender/render_assets.py --only=fish,mini would put the old ones back: run this again after it.
"""
import json
import math
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "tools", "art", "fish_source_test.webp")
OUT = os.path.join(ROOT, "assets", "vf")
BG = 206.0
# name, the box it is in (x0, x1), its eye (x, y, radius of the white) and mouth, measured on the picture,
# where the bend starts (0 nose .. 1 tail), how far it bends
FISH = [("Cod", (20, 680), (545.5, 307.0, 28.0), (602, 346), 0.42, 0.05),
        ("Pufferfish", (760, 1230), (1102.5, 284.5, 29.5), (1160, 322), 0.66, 0.045),
        ("Shark", (1330, 1990), (1844.0, 321.0, 29.0), (1870, 382), 0.45, 0.05)]
MINI_CELL, MINI_FRAMES = 224, 4
MINI_BOX = (11, 213, 150)        # the old ones: from x, to x, and no taller than this
PIC_BOX = (16, 231, 190)


def slug(name: str) -> str:
    return name.lower().replace(" ", "_")


def cut(rgb: np.ndarray):
    """the fish off the grey: (RGB with the rim cleaned, alpha 0..1)"""
    diff = np.abs(rgb - BG).max(axis=2)
    lab, _ = ndimage.label(diff <= 9.0)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bg = np.isin(lab, edge[edge > 0])
    solid = ndimage.binary_fill_holes(~bg)
    lab2, n = ndimage.label(solid)                       # the fish is the biggest thing here
    if n > 1:
        sizes = ndimage.sum(solid, lab2, range(1, n + 1))
        solid = lab2 == (1 + int(np.argmax(sizes)))
    core = ndimage.binary_erosion(solid, iterations=2)   # the rim is half grey: its colour comes from just inside
    idx = ndimage.distance_transform_edt(~core, return_distances=False, return_indices=True)
    col = rgb[idx[0], idx[1]]
    col = np.where(core[..., None], rgb, col)
    alpha = ndimage.gaussian_filter(ndimage.binary_erosion(solid, iterations=1).astype(np.float32), 0.9)
    return col, np.clip(alpha, 0.0, 1.0)


def swim(col: np.ndarray, alpha: np.ndarray, bend_from: float, amp: float, phase: float):
    """one frame: the tail half bent (up or down) and drawn in a little, the rest as it is"""
    h, w = alpha.shape
    xs = np.nonzero(alpha.max(axis=0) > 0.5)[0]
    x_tail, x_nose = float(xs.min()), float(xs.max())
    length = x_nose - x_tail
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u = np.clip((x_nose - xx) / length, 0.0, 1.2)
    k = np.clip((u - bend_from) / (1.0 - bend_from), 0.0, 1.2)
    k = k * k * (3.0 - 2.0 * np.minimum(k, 1.0))        # eases in: no kink where the bend starts
    dy = amp * length * k * math.sin(phase)
    dx = 0.045 * length * k * math.sin(phase) ** 2       # towards the head
    out = []
    pre = np.dstack([col * alpha[..., None], alpha])
    for c in range(4):
        out.append(ndimage.map_coordinates(pre[..., c], [yy - dy, xx - dx], order=1, mode="constant", cval=0.0))
    a = np.clip(out[3], 0.0, 1.0)
    rgb = np.dstack(out[:3]) / np.maximum(a, 1e-4)[..., None]
    return np.clip(rgb, 0, 255), a


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


def main() -> None:
    sheet = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32)
    man_path = os.path.join(OUT, "manifest.json")
    man = json.load(open(man_path, encoding="utf-8"))
    check = []
    for name, (bx0, bx1), eye, mouth, bend_from, amp in FISH:
        pad = 40
        part = np.full((sheet.shape[0] + pad * 2, bx1 - bx0 + pad * 2, 3), BG, np.float32)
        part[pad:-pad, pad:-pad] = sheet[:, bx0:bx1]
        col, alpha = cut(part)
        ys, xs = np.nonzero(alpha > 0.5)
        bbox = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        ex, ey, er = eye[0] - bx0 + pad, eye[1] + pad, eye[2]
        mx, my = mouth[0] - bx0 + pad, mouth[1] + pad
        gy, gx = np.mgrid[0:part.shape[0], 0:part.shape[1]]
        far = np.hypot(gx - ex, gy - ey)
        lid = np.median(part[(far > er * 1.2) & (far < er * 1.5) & (alpha > 0.99)], axis=0)

        pic, _, _ = place(to_image(col, alpha), bbox, 256, PIC_BOX)
        pic.save(os.path.join(OUT, "fish", slug(name) + ".png"))

        strip = Image.new("RGBA", (MINI_CELL * MINI_FRAMES, MINI_CELL), (0, 0, 0, 0))
        s, off = 1.0, (0, 0)
        for f in range(MINI_FRAMES):
            fc, fa = swim(col, alpha, bend_from, amp, f * math.tau / MINI_FRAMES)
            cell, s, off = place(to_image(fc, fa), bbox, MINI_CELL, MINI_BOX)
            strip.alpha_composite(cell, (f * MINI_CELL, 0))
        strip.save(os.path.join(OUT, "mini", slug(name) + ".png"))
        man["mini"]["fish"][name] = {
            "eye": [round(float(ex * s + off[0]) / MINI_CELL, 4), round(float(ey * s + off[1]) / MINI_CELL, 4)],
            "mouth": [round(float(mx * s + off[0]) / MINI_CELL, 4), round(float(my * s + off[1]) / MINI_CELL, 4)],
            "er": round(float(er * 1.04 * s) / MINI_CELL / 1.9, 4),          # (the game draws it 1.9 x this)
            "lid": "#%02x%02x%02x" % tuple(int(v) for v in lid),
            "own": True}
        print(name, "eye", (round(ex), round(ey)), "r", round(er, 1), "scale", round(s, 3), man["mini"]["fish"][name])
        check += [pic, strip]
    with open(man_path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(man, f, indent=1, sort_keys=True)
    w = 256 + MINI_CELL * MINI_FRAMES
    sheet_img = Image.new("RGBA", (w, 256 * len(FISH)), (38, 96, 110, 255))
    for i in range(len(FISH)):
        sheet_img.alpha_composite(check[i * 2], (0, i * 256))
        sheet_img.alpha_composite(check[i * 2 + 1], (256, i * 256 + 16))
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    sheet_img.convert("RGB").save(os.path.join(ROOT, "build", "fish_check.png"))


if __name__ == "__main__":
    main()

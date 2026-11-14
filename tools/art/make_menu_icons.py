"""The Menu's big icons from tools/art/menu_icons_source.png: a 4x4 sheet the owner had made on 2026-11-14 (an image
model, the prompt is in that day's chat). The sheet's "transparent" background is full of faint coloured specks, so each
icon is cut from its cell, the specks are dropped (anything nearly see-through, and small islands), and it's fitted
into a 256 px square.

    python tools/art/make_menu_icons.py        -> assets/vf/ui/menu/<name>.png, and build/menu_icons_check.png
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "tools", "art", "menu_icons_source.png")
OUT = os.path.join(ROOT, "assets", "vf", "ui", "menu")
COLS = [(25, 300), (327, 611), (643, 912), (955, 1228)]
ROWS = [(15, 302), (342, 609), (640, 917), (956, 1236)]
NAMES = ["shop", "map", "fish_book", "charms",
         "quests", "leaderboard", "derby", "friends",
         "events", "prestige", "pets", "buffs",
         "achievements", "guide", "settings", "daily"]
SIZE = 256


def cut(sheet: np.ndarray, r: int, c: int) -> Image.Image:
    (y0, y1), (x0, x1) = ROWS[r], COLS[c]
    m = 12
    cell = sheet[max(0, y0 - m):y1 + m, max(0, x0 - m):x1 + m].astype(np.float32)
    a = cell[..., 3]
    a = np.clip((a - 60.0) / (235.0 - 60.0), 0.0, 1.0)                 # the specks are nearly see-through; the icons nearly solid
    lab, n = ndimage.label(a > 0.5)
    if n > 1:                                                        # small islands go (sparks that belong stay: they're big)
        sizes = ndimage.sum(np.ones_like(a), lab, range(1, n + 1))
        keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= 260])
        keep = ndimage.binary_dilation(keep, iterations=2)
        a = a * keep
    cell[..., 3] = a * 255.0
    im = Image.fromarray(cell.astype(np.uint8), "RGBA")
    im = im.crop(im.getbbox())
    k = (SIZE - 12) / max(im.size)
    im = im.resize((max(1, round(im.size[0] * k)), max(1, round(im.size[1] * k))), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    out.alpha_composite(im, ((SIZE - im.size[0]) // 2, (SIZE - im.size[1]) // 2))
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sheet = np.asarray(Image.open(SRC).convert("RGBA"))
    check = Image.new("RGB", (4 * 280, 4 * 280), (18, 78, 90))
    for i, name in enumerate(NAMES):
        im = cut(sheet, i // 4, i % 4)
        im.save(os.path.join(OUT, name + ".png"), optimize=True)
        check.paste(im, ((i % 4) * 280 + 12, (i // 4) * 280 + 12), im)
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    check.save(os.path.join(ROOT, "build", "menu_icons_check.png"))
    print(len(NAMES), "icons ->", OUT, sum(os.path.getsize(os.path.join(OUT, n + ".png")) for n in NAMES) // 1024, "KB")

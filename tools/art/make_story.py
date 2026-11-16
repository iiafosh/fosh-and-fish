"""The story's pictures (Menu -> Story, scripts/vf/vf_story.gd), from the owner's paintings.

    python tools/art/make_story.py                    # the seven pages and the Menu's icon
    Godot_console.exe --headless --path . --import    # so the game finds them

Pages: tools/art/story_source_<n>.(png|webp|jpg|jpeg), n = 1..7. story_source_1 is the River's page, 2 the Volcanic
waters, 3 the Ocean, 4 the Sky, 5 Space, 6 the Alien seas, 7 the Abyss (docs/STORY.md says what each one shows). Each
becomes assets/vf/story/<biome>.jpg, 1200x800: a picture of another shape is cut to its middle. A page without a
painting shows the biome's own backdrop.

Icon: tools/art/story_icon_source.* is the Story tile's picture in the Menu, a storybook on a flat grey backdrop. The
backdrop goes (the grey that reaches the picture's edge) and the book is fitted into 256 px like the other Menu icons
(make_menu_icons.py) -> assets/vf/ui/menu/story.png, and build/story/icon_check.png to look at.

A new picture also gets an .import beside it that keeps it lossy, like the enter screen's painting and the other Menu
icons (a lossless painting would add about 1.5 MB to the download, each).
"""
import glob
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools", "art")
OUT = os.path.join(ROOT, "assets", "vf", "story")
ICON_OUT = os.path.join(ROOT, "assets", "vf", "ui", "menu", "story.png")
CHECK = os.path.join(ROOT, "build", "story", "icon_check.png")
BIOMES = ["river", "volcanic", "ocean", "sky", "space", "alien", "abyss"]      # VFData.BIOME_ORDER, as file names
SIZE = (1200, 800)
ICON_SIZE = 256
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=1
compress/lossy_quality=0.9
mipmaps/generate=true
"""


def sources(stem: str) -> list:
    return [p for ext in ("png", "webp", "jpg", "jpeg") for p in glob.glob(os.path.join(SRC, "%s.%s" % (stem, ext)))]


def keep_lossy(dst: str) -> None:
    """Godot fills in the rest of an .import the first time it imports the picture"""
    if not os.path.exists(dst + ".import"):
        with open(dst + ".import", "w", newline="\n") as f:
            f.write(IMPORT)


def fit(im: Image.Image) -> Image.Image:
    """the middle of the picture, in the page's shape"""
    w, h = im.size
    want = SIZE[0] / SIZE[1]
    if w / h > want:
        cw = int(round(h * want))
        im = im.crop(((w - cw) // 2, 0, (w - cw) // 2 + cw, h))
    else:
        ch = int(round(w / want))
        im = im.crop((0, (h - ch) // 2, w, (h - ch) // 2 + ch))
    return im.resize(SIZE, Image.LANCZOS)


def cut_icon(src: str) -> Image.Image:
    """the book without its grey backdrop, in the Menu icons' square"""
    rgb = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
    rim = np.concatenate([rgb[:12].reshape(-1, 3), rgb[-12:].reshape(-1, 3), rgb[:, :12].reshape(-1, 3), rgb[:, -12:].reshape(-1, 3)])
    far = np.abs(rgb - np.median(rim, axis=0)).max(axis=2)             # how far a pixel is from the backdrop's grey
    lab, _ = ndimage.label(far < 26.0)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    book = ~np.isin(lab, edge[edge > 0])                                # the backdrop: the grey that reaches the edge
    book = ndimage.binary_erosion(book, iterations=2)                   # (the outermost pixels are half grey)
    lab, n = ndimage.label(book)
    if n > 1:                                                           # specks go
        sizes = ndimage.sum(book, lab, range(1, n + 1))
        book = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= 400])
    a = ndimage.gaussian_filter(book.astype(np.float32), 0.7)
    im = Image.fromarray(np.dstack([rgb, a * 255.0]).astype(np.uint8), "RGBA")
    im = im.crop(im.getchannel("A").getbbox())
    k = (ICON_SIZE - 12) / max(im.size)
    im = im.resize((max(1, round(im.size[0] * k)), max(1, round(im.size[1] * k))), Image.LANCZOS)
    out = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    out.alpha_composite(im, ((ICON_SIZE - im.size[0]) // 2, (ICON_SIZE - im.size[1]) // 2))
    return out


def icon_check(im: Image.Image) -> None:
    """the icon on the Menu's teal and on the cards' cream, big and at the tile's size: a grey rim would show here"""
    os.makedirs(os.path.dirname(CHECK), exist_ok=True)
    check = Image.new("RGB", (2 * 280 + 2 * 110, 280), (18, 78, 90))
    check.paste((255, 246, 224), (280, 0, 560, 280))
    check.paste((255, 246, 224), (670, 0, 780, 280))
    small = im.resize((84, 84), Image.LANCZOS)
    check.paste(im, (12, 12), im)
    check.paste(im, (292, 12), im)
    check.paste(small, (573, 98), small)
    check.paste(small, (683, 98), small)
    check.save(CHECK)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for n, slug in enumerate(BIOMES, 1):
        found = sources("story_source_%d" % n)
        if not found:
            print("%d %-9s no picture yet (tools/art/story_source_%d.png)" % (n, slug, n))
            continue
        dst = os.path.join(OUT, slug + ".jpg")
        fit(Image.open(found[0]).convert("RGB")).save(dst, quality=90, optimize=True, progressive=True)
        keep_lossy(dst)
        print("%d %-9s %s -> assets/vf/story/%s.jpg (%d KB)" % (n, slug, os.path.basename(found[0]), slug, os.path.getsize(dst) // 1024))
        made += 1
    found = sources("story_icon_source")
    if found:
        im = cut_icon(found[0])
        im.save(ICON_OUT, optimize=True)
        keep_lossy(ICON_OUT)
        icon_check(im)
        print("icon        %s -> assets/vf/ui/menu/story.png (%d KB), check build/story/icon_check.png" % (os.path.basename(found[0]), os.path.getsize(ICON_OUT) // 1024))
    else:
        print("icon        no picture yet (tools/art/story_icon_source.png)")
    print("%d of %d pages have a painting. Now run: Godot_console.exe --headless --path . --import" % (made, len(BIOMES)))


if __name__ == "__main__":
    main()

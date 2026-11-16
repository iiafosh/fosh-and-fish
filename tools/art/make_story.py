"""The story's pictures (Menu -> Story, scripts/vf/vf_story.gd), from the owner's paintings.

    python tools/art/make_story.py                    # every tools/art/story_source_<n>.(png|webp|jpg|jpeg), n = 1..7
    Godot_console.exe --headless --path . --import    # so the game finds them

story_source_1 is the River's page, 2 the Volcanic waters, 3 the Ocean, 4 the Sky, 5 Space, 6 the Alien seas, 7 the Abyss
(docs/STORY.md says what each one shows). Each becomes assets/vf/story/<biome>.jpg, 1200x800: a picture of another shape
is cut to its middle. A new picture also gets an .import beside it that keeps it lossy, like the enter screen's painting
(a lossless one would add about 1.5 MB to the download, each). A page without a painting shows the biome's own backdrop.
"""
import glob
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools", "art")
OUT = os.path.join(ROOT, "assets", "vf", "story")
BIOMES = ["river", "volcanic", "ocean", "sky", "space", "alien", "abyss"]      # VFData.BIOME_ORDER, as file names
SIZE = (1200, 800)
IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=1
compress/lossy_quality=0.9
mipmaps/generate=true
"""


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


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for n, slug in enumerate(BIOMES, 1):
        found = [p for ext in ("png", "webp", "jpg", "jpeg") for p in glob.glob(os.path.join(SRC, "story_source_%d.%s" % (n, ext)))]
        if not found:
            print("%d %-9s no picture yet (tools/art/story_source_%d.png)" % (n, slug, n))
            continue
        dst = os.path.join(OUT, slug + ".jpg")
        fit(Image.open(found[0]).convert("RGB")).save(dst, quality=90, optimize=True, progressive=True)
        if not os.path.exists(dst + ".import"):
            with open(dst + ".import", "w", newline="\n") as f:
                f.write(IMPORT)
        print("%d %-9s %s -> assets/vf/story/%s.jpg (%d KB)" % (n, slug, os.path.basename(found[0]), slug, os.path.getsize(dst) // 1024))
        made += 1
    print("%d of %d pages have a painting. Now run: Godot_console.exe --headless --path . --import" % (made, len(BIOMES)))


if __name__ == "__main__":
    main()

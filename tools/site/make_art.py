"""The website's pictures (site/img) from the art sources, without the gameplay recording tools/site/make_media.py needs.

    python tools/site/make_art.py

Writes site/img/hero.webp (the page's background: tools/art/website_source.png, the bay at golden hour with friends
fishing, the owner's picture of 2026-11-14), og.jpg (the link preview: the same picture with the logo), logo.png and
the favicons (from assets/brand: run tools/art/make_brand.py first).
"""
import os

from PIL import Image, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
IMG = os.path.join(ROOT, "site", "img")
BRAND = os.path.join(ROOT, "assets", "brand")
SRC = os.path.join(ROOT, "tools", "art", "website_source.png")
TOP = 60                                  # rows cut from the top of the 3:2 picture for 16:9


def main():
    src = Image.open(SRC).convert("RGB")
    w = src.size[0]
    hero = src.crop((0, TOP, w, TOP + round(w * 9 / 16))).resize((1920, 1080), Image.LANCZOS)
    hero = hero.filter(ImageFilter.UnsharpMask(radius=1.4, percent=45, threshold=2))
    hero.save(os.path.join(IMG, "hero.webp"), quality=84, method=6)
    logo = Image.open(os.path.join(BRAND, "logo.png")).convert("RGBA")
    # the link preview, 2:1: the picture with the logo in the sky
    og = src.crop((0, 40, w, 40 + w // 2)).resize((1280, 640), Image.LANCZOS).convert("RGBA")
    lw = 380
    lg = logo.resize((lw, round(lw * logo.height / logo.width)), Image.LANCZOS)
    shadow = Image.new("RGBA", og.size, (0, 0, 0, 0))
    shadow.paste((6, 38, 52, 150), ((1280 - lw) // 2, 18 + 8), lg.split()[3])
    og.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(10)))
    og.alpha_composite(lg, ((1280 - lw) // 2, 18))
    og.convert("RGB").save(os.path.join(IMG, "og.jpg"), quality=88, optimize=True, progressive=True)
    logo.resize((640, round(640 * logo.height / logo.width)), Image.LANCZOS).save(os.path.join(IMG, "logo.png"), optimize=True)
    for n in [64, 180, 512]:
        Image.open(os.path.join(BRAND, "icon_%d.png" % n)).save(os.path.join(IMG, "icon-%d.png" % n), optimize=True)
    for n in sorted(os.listdir(IMG)):
        print(n, Image.open(os.path.join(IMG, n)).size, os.path.getsize(os.path.join(IMG, n)) // 1024, "KB")


if __name__ == "__main__":
    main()

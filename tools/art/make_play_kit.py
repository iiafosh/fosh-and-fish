"""Google Play store art for fosh&fish 1.0 (what you upload in Play Console -> Store listing).

    python tools/art/make_play_kit.py            everything
    python tools/art/make_play_kit.py feature    just the feature graphic (quick look)
    python tools/art/make_play_kit.py shots      just the screenshots

Writes to store/play/ (Godot ignores the folder, exports leave it out):
  icon_512.png               the app icon (from assets/brand/icon_1024.png, tools/art/make_brand.py)
  feature_1024x500.png       the feature graphic: the painted cover scene and the logo
  screenshots/*.png          1920x1080 game screenshots (the game's --play-shots capture, fullscreen:
                             your screen must be 1920x1080, and the game covers it for about a minute)
The listing texts are in store/play/listing.md.
"""
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_brand as MB  # noqa: E402

ROOT = MB.ROOT
OUT = os.path.join(ROOT, "store", "play")
GODOT = os.environ.get("GODOT", r"C:\Program Files\Godot\Godot_console.exe")


def icon():
    Image.open(os.path.join(MB.BRAND, "icon_1024.png")).convert("RGBA").resize((512, 512), Image.LANCZOS) \
        .save(os.path.join(OUT, "icon_512.png"), optimize=True)


def feature():
    """the painted cover scene with the fisher on the pier, and the logo out over the open sea"""
    w, h = 1024, 500
    art = Image.open(MB.ART).convert("RGB")
    s = w / art.size[0]
    art = art.resize((w, int(art.size[1] * s + 0.5)), Image.LANCZOS)
    y = 34
    c = art.crop((0, y, w, y + h)).convert("RGBA")
    lg = MB.logo(1.0)
    lw = 430
    lg = lg.resize((lw, int(lg.size[1] * lw / lg.size[0])), Image.LANCZOS)
    lx, ly = int(0.69 * w - lw / 2), 38
    c.alpha_composite(lg, (lx, ly))
    f = MB.font(22, 500, 100)
    text = "a cozy fishing game"
    tw = f.getlength(text)
    th = f.size * 1.9
    px, py = lx + lw / 2, ly + lg.size[1] + th * 0.55
    pill = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(pill).rounded_rectangle((px - tw / 2 - th * 0.6, py - th / 2, px + tw / 2 + th * 0.6, py + th / 2), int(th / 2),
                                           fill=(11, 41, 48, 150))
    c.alpha_composite(pill)
    ImageDraw.Draw(c).text((px, py), text, font=f, fill=(255, 255, 255), anchor="mm")
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

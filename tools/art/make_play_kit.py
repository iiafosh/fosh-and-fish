"""Google Play store art for fosh&fish 1.0 (what you upload in Play Console -> Store listing).

    python tools/art/make_play_kit.py            everything
    python tools/art/make_play_kit.py feature    just the feature graphic (quick look)
    python tools/art/make_play_kit.py shots      just the screenshots

Writes to store/play/ (Godot ignores the folder, exports leave it out):
  icon_512.png               the app icon (from assets/brand/icon_1024.png, tools/art/make_brand.py)
  feature_1024x500.png       the feature graphic: the cover scene, the logo and the 1.0 art
  screenshots/*.png          1920x1080 game screenshots (the game's --play-shots capture, fullscreen:
                             your screen must be 1920x1080, and the game covers it for about a minute)
The listing texts are in store/play/listing.md.
"""
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_brand as MB  # noqa: E402

ROOT = MB.ROOT
OUT = os.path.join(ROOT, "store", "play")
VF = os.path.join(ROOT, "assets", "vf")
GODOT = os.environ.get("GODOT", r"C:\Program Files\Godot\Godot_console.exe")


def icon():
    Image.open(os.path.join(MB.BRAND, "icon_1024.png")).convert("RGBA").resize((512, 512), Image.LANCZOS) \
        .save(os.path.join(OUT, "icon_512.png"), optimize=True)


BLENDER = os.environ.get("BLENDER", "D:/Blender/blender-4.2.3-windows-x64/blender.exe")
HERO = os.path.join(OUT, "art")          # big renders of the 1.0 art (tools/blender/render_v1.py --size 640)


def hero_art():
    need = [os.path.join(HERO, "event", "leviathan.png"), os.path.join(HERO, "shiny", "rainbow_fish.png")]
    if not all(os.path.exists(p) for p in need):
        subprocess.run([BLENDER, "-b", "--factory-startup", "--python", os.path.join(ROOT, "tools", "blender", "render_v1.py"),
                        "--", "event", "shiny", "--only", "leviathan,rainbow_fish", "--size", "640", "--out", HERO], check=True)
    return need


def sprite(path, height, angle=0.0):
    """a render, trimmed, scaled to a height, with a soft shadow under it"""
    im = Image.open(path).convert("RGBA")
    im = im.crop(im.getbbox())
    if angle:
        im = im.rotate(angle, Image.BICUBIC, expand=True)
        im = im.crop(im.getbbox())
    s = height / im.size[1]
    im = im.resize((max(1, int(im.size[0] * s)), int(height)), Image.LANCZOS)
    pad = 24
    out = Image.new("RGBA", (im.size[0] + pad * 2, im.size[1] + pad * 2), (0, 0, 0, 0))
    sh = Image.new("L", out.size, 0)
    sh.paste(im.getchannel("A"), (pad + 6, pad + 10))
    sh = sh.filter(ImageFilter.GaussianBlur(9)).point(lambda v: int(v * 0.35))
    out.paste(Image.new("RGBA", out.size, (6, 40, 60, 255)), (0, 0), sh)
    out.alpha_composite(im, (pad, pad))
    return out


def twinkle(c, xy, r, color=(255, 246, 200)):
    """a 4-point glint, like the shinies have in game"""
    x, y = xy
    k = r * 0.22
    ImageDraw.Draw(c).polygon([(x, y - r), (x + k, y - k), (x + r, y), (x + k, y + k), (x, y + r), (x - k, y + k), (x - r, y),
                               (x - k, y - k)], fill=color + (255,))


def feature():
    w, h = 1024, 500
    art = Image.open(MB.ART).convert("RGB")
    s = w / art.size[0]
    art = art.resize((w, int(art.size[1] * s + 0.5)), Image.LANCZOS)
    y = 40
    c = art.crop((0, y, w, y + h)).convert("RGBA")
    # the logo and its line, over the pier (like the covers)
    lg = MB.logo(1.0)
    lw = 380
    lg = lg.resize((lw, int(lg.size[1] * lw / lg.size[0])), Image.LANCZOS)
    lx, ly = int(0.29 * w - lw / 2), 26
    c.alpha_composite(lg, (lx, ly))
    f = MB.font(21, 500, 100)
    text = "a cozy fishing game"
    tw = f.getlength(text)
    th = f.size * 1.9
    px, py = lx + lw / 2, ly + lg.size[1] + th * 0.5
    pill = Image.new("RGBA", c.size, (0, 0, 0, 0))
    ImageDraw.Draw(pill).rounded_rectangle((px - tw / 2 - th * 0.6, py - th / 2, px + tw / 2 + th * 0.6, py + th / 2), int(th / 2),
                                           fill=(11, 41, 48, 150))
    c.alpha_composite(pill)
    ImageDraw.Draw(c).text((px, py), text, font=f, fill=(255, 255, 255), anchor="mm")
    # what 1.0 brings, out on the open sea: the boss breaching, a shiny leaping
    lev, shiny = hero_art()
    sp = sprite(lev, 330)
    c.alpha_composite(sp, (w - sp.size[0] + 10, 70))
    sp = sprite(shiny, 160, 18)
    sx, sy = 455, 292
    c.alpha_composite(sp, (sx, sy))
    for dx, dy, r in [(-8, 18, 16), (sp.size[0] - 10, 4, 22), (sp.size[0] * 0.55, sp.size[1] - 6, 12)]:
        twinkle(c, (sx + dx, sy + dy), r)
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

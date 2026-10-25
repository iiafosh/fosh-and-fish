"""Static ads for fosh&fish 1.0: four ideas, each in the four sizes ad networks ask for.

    python tools/art/make_ads.py [shiny,boss,events,cozy]

  shiny   "Only 3,000 exist."             the shiny reveal           (store/play/screenshots/2_shiny.png)
  boss    "Something HUGE is coming"      the Leviathan in the lava  (3_boss.png)
  events  "Every 10 minutes, a new event" Golden Hour, a Golden Koi  (1_event_fish.png)
  cozy    "Cast. Catch. Collect."         the painted dock           (assets/launcher/launcher_bg.jpg)

  sizes   1200x628 (link / display ads), 1080x1080 (feeds), 1080x1350 (4:5 feeds), 1080x1920 (stories, reels)

Writes store/ads/<idea>_<size>.jpg (the screenshots come from make_play_kit.py shots). Texts for the ads are
in store/ads/ad_copy.md.
"""
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_brand as MB  # noqa: E402

ROOT = MB.ROOT
OUT = os.path.join(ROOT, "store", "ads")
SHOTS = os.path.join(ROOT, "store", "play", "screenshots")
WHITE, GOLD, DEEP, MINT = (255, 255, 255), (255, 204, 72), MB.DEEP, MB.MINT
SIZES = {"1200x628": (1200, 628), "1080x1080": (1080, 1080), "1080x1350": (1080, 1350), "1080x1920": (1080, 1920)}

# idea: picture, where to look in it (x, y, 0..1), how close (1 = the whole picture fits the short side),
#       headline lines [(text, gold)], the line under it, the button
IDEAS = {
    "shiny": (os.path.join(SHOTS, "2_shiny.png"), (0.5, 0.36), 1.45,
              [[("Only", False), ("3,000", True)], [("exist.", False)]], "Catch a numbered shiny fish", "Play free"),
    "boss": (os.path.join(SHOTS, "3_boss.png"), (0.5, 0.42), 1.25,
             [[("Something", False)], [("HUGE", True), ("is", False), ("coming", False)]], "Catch the Leviathan", "Play free"),
    "events": (os.path.join(SHOTS, "1_event_fish.png"), (0.5, 0.33), 1.3,
               [[("Every", False), ("10", True), ("minutes,", False)], [("a", False), ("new", False), ("event", True)]],
               "Golden Hour  ·  Meteor Showers  ·  Boss Fish", "Play free"),
    "cozy": (MB.ART, (0.3, 0.5), 1.0, [[("Cast.", False), ("Catch.", True)], [("Collect.", False)]],
             "a cozy fishing game with 20 fish to collect", "Play free"),
}


def cover(img, ow, oh, focus, zoom):
    """the picture cropped to ow x oh around focus (0..1), zoom 1 = fills the frame"""
    s = max(ow / img.size[0], oh / img.size[1]) * zoom
    cw, ch = min(ow / s, img.size[0]), min(oh / s, img.size[1])
    x = max(0.0, min(focus[0] * img.size[0] - cw / 2, img.size[0] - cw))
    y = max(0.0, min(focus[1] * img.size[1] - ch / 2, img.size[1] - ch))
    return img.resize((ow, oh), Image.LANCZOS, box=(x, y, x + cw, y + ch))


def outlined_line(words, size):
    """a line of chunky words: white, gold keywords, a deep-sea outline and a soft shadow"""
    f = MB.font(size, 700, 104)
    sp = size * 0.26
    widths = [f.getlength(w) for w, _ in words]
    pad = int(size * 0.35)
    w = int(sum(widths) + sp * (len(words) - 1) + pad * 2)
    h = int(size * 1.4)
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d, ds = ImageDraw.Draw(lay), ImageDraw.Draw(sh)
    sw = max(3, int(size * 0.09))
    x = pad
    for (word, gold), ww in zip(words, widths):
        ds.text((x + size * 0.03, h / 2 + size * 0.07), word, font=f, fill=(0, 0, 0, 140), anchor="lm", stroke_width=sw,
                stroke_fill=(0, 0, 0, 140))
        d.text((x, h / 2), word, font=f, fill=GOLD if gold else WHITE, anchor="lm", stroke_width=sw, stroke_fill=DEEP)
        x += ww + sp
    sh = sh.filter(ImageFilter.GaussianBlur(size * 0.04))
    sh.alpha_composite(lay)
    return sh


def pill(text, size, color=DEEP, alpha=210, fg=WHITE, weight=650):
    f = MB.font(size, weight, 100)
    w = f.getlength(text)
    p = Image.new("RGBA", (int(w + size * 1.6), int(size * 1.85)), (0, 0, 0, 0))
    d = ImageDraw.Draw(p)
    d.rounded_rectangle((0, 0, p.size[0] - 1, p.size[1] - 1), int(p.size[1] / 2), fill=color + (alpha,))
    d.text((p.size[0] / 2, p.size[1] / 2), text, font=f, fill=fg, anchor="mm")
    return p


def button(text, size):
    """the mint "Play free" button, with a darker lip"""
    f = MB.font(size, 700, 104)
    w = f.getlength(text)
    bw, bh = int(w + size * 1.9), int(size * 1.9)
    b = Image.new("RGBA", (bw, bh + int(size * 0.18)), (0, 0, 0, 0))
    d = ImageDraw.Draw(b)
    d.rounded_rectangle((0, int(size * 0.18), bw - 1, bh + int(size * 0.18) - 1), bh // 2, fill=(40, 160, 130, 255))
    d.rounded_rectangle((0, 0, bw - 1, bh - 1), bh // 2, fill=MINT + (255,))
    d.text((bw / 2, bh / 2), text, font=f, fill=DEEP, anchor="mm")
    return b


def glint(r):
    n = int(r * 4)
    c = n / 2
    k = r * 0.17
    m = Image.new("L", (n, n), 0)
    ImageDraw.Draw(m).polygon([(c, c - r), (c + k, c - k), (c + r, c), (c + k, c + k), (c, c + r), (c - k, c + k), (c - r, c),
                               (c - k, c - k)], fill=255)
    halo = Image.new("L", (n, n), 0)
    ImageDraw.Draw(halo).ellipse((c - r * 0.45, c - r * 0.45, c + r * 0.45, c + r * 0.45), fill=255)
    lay = Image.new("RGBA", (n, n), (255, 247, 214, 0))
    lay.putalpha(ImageChops.lighter(m, halo.filter(ImageFilter.GaussianBlur(r * 0.3)).point(lambda v: int(v * 0.8))))
    return lay


def put(c, layer, cx, cy):
    c.alpha_composite(layer, (int(cx - layer.size[0] / 2), int(cy - layer.size[1] / 2)))


def fit(layer, max_w):
    if layer.size[0] <= max_w:
        return layer
    return layer.resize((int(max_w), int(layer.size[1] * max_w / layer.size[0])), Image.LANCZOS)


def shade(size, frm, to, axis="y", color=(6, 26, 34), strength=0.85):
    """a dark gradient from frm to to (0..1 along the axis) so text reads over the picture"""
    w, h = size
    g = Image.linear_gradient("L").resize((w, h) if axis == "y" else (h, w))
    if axis == "x":
        g = g.rotate(90, expand=True).transpose(Image.FLIP_LEFT_RIGHT)
    lo, hi = int(frm * 255), int(to * 255)
    g = g.point(lambda v: int(255 * strength * min(1, max(0, (v - lo) / max(1, hi - lo)))))
    lay = Image.new("RGBA", (w, h), color + (0,))
    lay.putalpha(g)
    return lay


def framed(pic, w, h, focus, zoom):
    """the screenshot as a card: rounded corners, a thin white rim and a soft shadow"""
    w, h = int(w), int(h)
    img = cover(pic, w, h, focus, zoom).convert("RGBA")
    r = int(min(w, h) * 0.06)
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, h - 1), r, fill=255)
    pad = int(min(w, h) * 0.08)
    out = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    sh = Image.new("L", out.size, 0)
    sh.paste(m, (pad + int(pad * 0.15), pad + int(pad * 0.3)))
    out.paste(Image.new("RGBA", out.size, (0, 10, 16, 255)), (0, 0), sh.filter(ImageFilter.GaussianBlur(pad * 0.4)).point(lambda v: int(v * 0.6)))
    rim = Image.new("L", (w + 8, h + 8), 0)
    ImageDraw.Draw(rim).rounded_rectangle((0, 0, w + 7, h + 7), r + 4, fill=255)
    out.paste(Image.new("RGBA", rim.size, (255, 255, 255, 235)), (pad - 4, pad - 4), rim)
    out.paste(img, (pad, pad), m)
    return out


def backdrop(pic, ow, oh):
    b = cover(pic, ow, oh, (0.5, 0.5), 1.0).filter(ImageFilter.GaussianBlur(26)).convert("RGBA")
    b.alpha_composite(Image.new("RGBA", (ow, oh), (6, 26, 34, 150)))
    return b


def make(idea, size_key):
    src, focus, zoom, lines, sub, cta = IDEAS[idea]
    ow, oh = SIZES[size_key]
    pic = Image.open(src).convert("RGB")
    land = ow > oh
    painted = idea == "cozy"
    logo = MB.logo(1.0)

    def logo_w(wd):
        return logo.resize((int(wd), int(logo.size[1] * wd / logo.size[0])), Image.LANCZOS)

    if land:
        hs, bs, ss = 64, 40, 22
    else:
        hs, bs, ss = {"1080x1080": (88, 46, 28), "1080x1350": (100, 50, 30), "1080x1920": (116, 56, 32)}[size_key]
    head = [outlined_line(l, hs) for l in lines]
    btn = button(cta, bs)
    subp = pill(sub, ss, alpha=200)

    def column(c, x, y, max_w):
        for l in head:
            l = fit(l, max_w)
            put(c, l, x, y + l.size[1] / 2)
            y += l.size[1] * 0.8
        return y

    if land and painted:                                    # the painted dock, the words out on the open sea
        c = cover(pic, ow, oh, (0.45, 0.5), 1.0).convert("RGBA")
        c.alpha_composite(shade((ow, oh), 0.35, 1.0, axis="x", strength=0.55))
        x0 = ow * 0.7
        lg = logo_w(280)
        put(c, lg, x0, 26 + lg.size[1] / 2)
        y = column(c, x0, 26 + lg.size[1] - 4, ow * 0.52)
        put(c, fit(subp, ow * 0.55), x0, y + 34)
        put(c, btn, x0, oh - 62)
    elif land:                                              # the screenshot card on the right, the words on the left
        c = backdrop(pic, ow, oh)
        card = framed(pic, 650, 650 * 9 / 16, focus, zoom)
        put(c, card, ow - card.size[0] / 2 - 18, oh / 2)
        x0 = 255
        lg = logo_w(250)
        put(c, lg, x0, 22 + lg.size[1] / 2)
        y = column(c, x0, 22 + lg.size[1], 470)
        put(c, fit(subp, 470), x0, y + 28)
        put(c, btn, x0, oh - 60)
    else:
        c = backdrop(pic, ow, oh)
        if size_key == "1080x1080":
            y = column(c, ow / 2, 40, ow * 0.92)
            card = framed(pic, 960, 540, focus if not painted else (0.5, 0.5), zoom if not painted else 1.0)
            put(c, card, ow / 2, y + card.size[1] / 2 - 26)
            lg = logo_w(250)
            put(c, lg, 60 + lg.size[0] / 2, oh - 30 - lg.size[1] / 2)
            put(c, btn, ow - 70 - btn.size[0] / 2, oh - 30 - lg.size[1] / 2)
        else:
            tall = size_key == "1080x1920"
            lg = logo_w(470 if tall else 340)
            top = 90 if tall else 36
            put(c, lg, ow / 2, top + lg.size[1] / 2)
            y = column(c, ow / 2, top + lg.size[1] + (30 if tall else 6), ow * 0.92)
            ch = 780 if tall else 551                         # (tall: a taller card fills the screen)
            card = framed(pic, 980, ch, focus if not painted else (0.3, 0.5), zoom if not painted else 1.0)
            put(c, card, ow / 2, y + card.size[1] / 2 - 20 + (40 if tall else 0))
            y += card.size[1] - 40 + (40 if tall else 0)
            put(c, fit(subp, ow * 0.9), ow / 2, y + (10 if tall else 30))
            put(c, btn, ow / 2, y + (150 if tall else 130))
            if tall:
                f = MB.font(40, 600, 100)
                lay = Image.new("RGBA", (ow, 80), (0, 0, 0, 0))
                ImageDraw.Draw(lay).text((ow / 2, 40), "foshfish.xyz", font=f, fill=(220, 245, 240, 230), anchor="mm")
                put(c, lay, ow / 2, y + 262)
    if idea == "shiny":                                       # a few glints for the shiny one
        sc = min(ow, oh) / 1080
        g = glint(40 * sc)
        for gx, gy, k in [(0.12, 0.36, 1.0), (0.9, 0.3, 0.7), (0.82, 0.62, 0.55), (0.2, 0.7, 0.5)]:
            gl = g.resize((max(1, int(g.size[0] * k)), max(1, int(g.size[1] * k))), Image.LANCZOS)
            put(c, gl, ow * gx, oh * gy)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{idea}_{size_key}.jpg")
    c.convert("RGB").save(path, quality=92, optimize=True, subsampling=0)
    return path


if __name__ == "__main__":
    ideas = sys.argv[1].split(",") if len(sys.argv) > 1 else list(IDEAS)
    for idea in ideas:
        for size_key in SIZES:
            p = make(idea, size_key)
            print(os.path.relpath(p, ROOT), os.path.getsize(p) // 1024, "KB")

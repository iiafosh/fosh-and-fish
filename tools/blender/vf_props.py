"""Bait, chest, charm and UI icon models."""
import math
import random

from mathutils import Vector

import vf_models as M
from vf_kit import cone, cube, cyl, deform, extrude_poly, hexc, ico, sphere, toon, torus, tube


def _rot(ob, x=0, y=0, z=0):
    ob.rotation_euler = (math.radians(x), math.radians(y), math.radians(z))
    return ob


# ------------------------------------------------------------------ baits
def worms():
    out = []
    for i, (dx, dy, ph) in enumerate([(0, 0, 0), (0.3, 0.5, 1.4), (-0.4, 0.3, 2.6)]):
        pts = [(dx + math.cos(t * 1.7 + ph) * 0.45 + t * 0.15 - 0.4, dy + math.sin(t * 2.1 + ph) * 0.35, 0.08 * t)
               for t in [k * 0.5 for k in range(7)]]
        out.append(tube(pts, 0.11, mat=toon("#f08a9a"), taper=(1.0, 0.75)))
    for o in out:
        o["outline_k"] = 0.7
    return out


def leeches():
    out = []
    for dx, dy, r in [(0, 0, 10), (0.55, 0.45, -25)]:
        b = sphere(loc=(dx, dy, 0), scale=(0.75, 0.32, 0.22), rot=(0, 0, r), mat=toon("#3c3a2a"))
        out.append(b)
        out.append(sphere(loc=(dx + 0.65 * math.cos(math.radians(r)), dy + 0.65 * math.sin(math.radians(r)), 0.02),
                          scale=(0.14, 0.14, 0.1), mat=toon("#8c3a3a")))
        for k in range(4):
            ring = torus(loc=(dx + (k - 1.5) * 0.25 * math.cos(math.radians(r)), dy + (k - 1.5) * 0.25 * math.sin(math.radians(r)), 0),
                         R=0.27 - abs(k - 1.5) * 0.04, r=0.02, rot=(0, 90, r), mat=toon("#5a5640"))
            ring["no_outline"] = True
            out.append(ring)
    return out


def _horseshoe(color, tip="#d0d6e0", gem=None):
    out = []
    arc = [(math.cos(a) * 0.62, 0, math.sin(a) * 0.62) for a in [k * math.pi / 8 for k in range(9)]]
    out.append(tube(arc, 0.22, mat=toon(color, spec=0.3)))
    for s in (1, -1):
        leg = cyl(loc=(s * 0.62, 0, -0.45), r=0.22, depth=0.8, mat=toon(color, spec=0.3))
        out.append(leg)
        out.append(cyl(loc=(s * 0.62, 0, -0.98), r=0.225, depth=0.3, mat=toon(tip, spec=0.6)))
    if gem:
        out.append(ico(loc=(0, -0.22, 0.62), scale=0.2, mat=toon(gem, emit=0.5, spec=0.6)))
    return out


def magnet():
    return _horseshoe("#e0322b")


def artifact_magnet():
    return _horseshoe("#e0b23a", tip="#5ff2ff", gem="#3ff2e4")


def wise_bait():
    out = [sphere(scale=0.6, mat=toon("#4f7dff", emit=0.35, spec=0.5))]
    out.append(sphere(loc=(0.15, -0.3, 0.25), scale=0.18, mat=toon("#cfe0ff", flat_glow=True)))
    out[-1]["no_outline"] = True
    for k in range(3):
        o = torus(R=0.85 + k * 0.08, r=0.025, rot=(70, 20 * k, 30 * k), mat=toon("#9fc4ff", emit=0.6))
        o["outline_k"] = 0.4
        out.append(o)
    for a in range(5):
        p = (math.cos(a * 1.3) * 1.1, math.sin(a * 2.1) * 0.4, math.sin(a * 1.3) * 1.0)
        s = extrude_poly(M.star_pts(0.12, 0.05, 4), 0.03, loc=p, mat=toon("#ffffff", flat_glow=True))
        s["no_outline"] = True
        out.append(_rot(s, 90))
    return out


def fish_bait():
    spec = dict(top="#b8c4cc", belly="#eef3f6", fin="#8fa0aa", L=0.8, H=0.32, W=0.18)
    parts = M.build_fish(spec)
    hook = tube([(0.1, 0, 0.55), (0.1, 0, -0.15), (0.0, 0, -0.32), (-0.18, 0, -0.18), (-0.18, 0, -0.05)], 0.03,
                mat=toon("#d0d6e0", spec=0.6))
    return parts + [hook]


def magic_bait():
    out = [ico(scale=0.55, sub=2, mat=toon("#b04dff", emit=0.45, spec=0.5))]
    out.append(sphere(scale=0.3, mat=toon("#ffd6ff", flat_glow=True)))
    out[-1]["no_outline"] = True
    sw = tube([(math.cos(t) * (0.7 + t * 0.05), math.sin(t) * (0.7 + t * 0.05), (t - 3) * 0.12)
               for t in [k * 0.6 for k in range(11)]], 0.04, mat=toon("#ff9cf0", emit=0.7))
    sw["outline_k"] = 0.4
    out.append(sw)
    for a in range(6):
        p = (math.cos(a) * 1.0, math.sin(a * 1.7) * 0.5, math.sin(a) * 0.9)
        st = extrude_poly(M.star_pts(0.13, 0.05, 4), 0.03, loc=p, mat=toon("#fff5a0", flat_glow=True))
        st["no_outline"] = True
        out.append(_rot(st, 90))
    return out


def support_bait():
    h = extrude_poly(M._heart_pts(0.85), 0.35, mat=toon("#ff4f8b", spec=0.4, emit=0.15), bevel=0.08)
    _rot(h, 90)
    plus = extrude_poly([(-0.08, -0.25), (0.08, -0.25), (0.08, -0.08), (0.25, -0.08), (0.25, 0.08), (0.08, 0.08),
                         (0.08, 0.25), (-0.08, 0.25), (-0.08, 0.08), (-0.25, 0.08), (-0.25, -0.08), (-0.08, -0.08)],
                        0.1, loc=(0, -0.22, 0.05), mat=toon("#ffffff"))
    _rot(plus, 90)
    return [h, plus]


# ----------------------------------------------------------------- chests
CHEST_COLORS = {
    "common":    ("#9a6a3c", "#6b6f78", None),
    "uncommon":  ("#9a6a3c", "#3fbf6a", None),
    "rare":      ("#2f5d9a", "#d0d6e0", "#4fb3ff"),
    "epic":      ("#5a2d8a", "#e0b23a", "#c77dff"),
    "legendary": ("#b5541c", "#ffd23f", "#ffb21f"),
    "artifact":  ("#2a6e6a", "#e0b23a", "#3ff2e4"),
    "super":     ("#ff4fb0", "#ffffff", "#ff9cf0"),
}


def chest(tier):
    wood, metal, glow = CHEST_COLORS[tier]
    out = [cube(loc=(0, 0, 0.4), scale=(1.6, 1.0, 0.8), mat=toon(wood), bevel=0.04)]
    lid = cyl(loc=(0, 0, 0.8), r=0.5, depth=1.6, rot=(0, 90, 0), mat=toon(wood), verts=20, scale=(1, 1, 0.75))
    out.append(lid)
    for x in (-0.55, 0.55):
        out.append(cube(loc=(x, 0, 0.4), scale=(0.16, 1.04, 0.84), mat=toon(metal, spec=0.5)))
        band = torus(loc=(x, 0, 0.8), R=0.5, r=0.06, rot=(0, 90, 0), mat=toon(metal, spec=0.5), scale=(1, 1, 0.75), seg=24)
        out.append(band)
    out.append(cube(loc=(0, -0.52, 0.72), scale=(0.3, 0.08, 0.36), mat=toon(metal, spec=0.6), bevel=0.03))
    out.append(cyl(loc=(0, -0.57, 0.7), r=0.05, depth=0.04, rot=(90, 0, 0), mat=toon("#1a1420")))
    if glow:
        gem = ico(loc=(0, -0.58, 0.95), scale=0.11, mat=toon(glow, emit=0.8, spec=0.6))
        out.append(gem)
    if tier in ("legendary", "artifact", "super"):
        for i in range(5):
            a = i / 5 * math.tau
            st = extrude_poly(M.star_pts(0.12, 0.05, 4), 0.03, loc=(math.cos(a) * 1.05, -0.3, 0.8 + math.sin(a) * 0.75),
                              mat=toon("#ffffff", flat_glow=True))
            st["no_outline"] = True
            out.append(_rot(st, 90))
    if tier == "artifact":
        for x in (-0.3, 0.3):
            r = cube(loc=(x, -0.51, 0.3), scale=(0.18, 0.02, 0.18), rot=(0, 45, 0), mat=toon("#3ff2e4", emit=0.8))
            r["no_outline"] = True
            out.append(r)
    return out


# ----------------------------------------------------------------- charms
def _amulet(color, symbol_parts):
    ring = torus(R=0.78, r=0.1, rot=(90, 0, 0), mat=toon("#e0b23a", spec=0.6), seg=40)
    disc = cyl(r=0.72, depth=0.16, rot=(90, 0, 0), mat=toon(color, spec=0.25), verts=40)
    bail = torus(loc=(0, 0, 0.95), R=0.14, r=0.05, rot=(0, 0, 0), mat=toon("#e0b23a", spec=0.6))
    out = [ring, disc, bail]
    for sp in symbol_parts:
        sp.location.y -= 0.1
        out.append(sp)
    return out


def _sym(points, color="#ffffff", depth=0.08, scale=1.0):
    ob = extrude_poly([(x * scale, y * scale) for x, y in points], depth, mat=toon(color, spec=0.3))
    return _rot(ob, 90)


def charm_marketing():
    coin = cyl(r=0.36, depth=0.08, rot=(90, 0, 0), mat=toon("#ffd23f", spec=0.6))
    coin.location.y -= 0.02
    return _amulet("#2e8b57", [coin, _sym([(-0.05, -0.25), (0.05, -0.25), (0.05, 0.25), (-0.05, 0.25)], "#b8860b")])


def charm_endurance():
    return _amulet("#c0392b", [_sym(M._heart_pts(0.42), "#ffd6dc")])


def charm_haste():
    return _amulet("#2f6bff", [_sym([(0.1, 0.45), (-0.22, -0.02), (0.0, -0.02), (-0.1, -0.45), (0.24, 0.06), (0.02, 0.06)],
                                    "#fff27a")])


def charm_quantity():
    parts = []
    for i, (x, z) in enumerate([(-0.17, -0.16), (0.17, -0.16), (0.0, 0.14)]):
        c = cube(loc=(x, -0.1, z), scale=(0.28, 0.1, 0.28), mat=toon("#ffe6a0"), bevel=0.02)
        parts.append(c)
    return _amulet("#8e5a2b", parts)


def charm_worker():
    head = _sym([(-0.3, 0.15), (0.3, 0.15), (0.3, 0.32), (-0.3, 0.32)], "#d0d6e0")
    handle = _sym([(-0.05, -0.4), (0.05, -0.4), (0.05, 0.15), (-0.05, 0.15)], "#c48a52")
    return _amulet("#5a6068", [head, handle])


def charm_treasure():
    box = cube(loc=(0, -0.1, -0.05), scale=(0.5, 0.1, 0.32), mat=toon("#9a6a3c"), bevel=0.02)
    lid = cube(loc=(0, -0.1, 0.17), scale=(0.52, 0.1, 0.14), mat=toon("#b5803f"), bevel=0.02)
    lock = cube(loc=(0, -0.17, 0.06), scale=(0.08, 0.04, 0.1), mat=toon("#ffd23f"))
    return _amulet("#1f6f8b", [box, lid, lock])


def charm_quality():
    return _amulet("#7a3fb0", [_sym(M.star_pts(0.42, 0.18, 5), "#ffe27a")])


def charm_experience():
    return _amulet("#2aa04a", [_sym([(0, 0.42), (0.32, 0.05), (0.12, 0.05), (0.12, -0.38), (-0.12, -0.38), (-0.12, 0.05),
                                     (-0.32, 0.05)], "#eaffd0")])


# --------------------------------------------------------------------- ui
def coins():
    out = []
    for i in range(5):
        out.append(cyl(loc=(random.uniform(-0.04, 0.04), random.uniform(-0.04, 0.04), i * 0.16), r=0.6, depth=0.14,
                       mat=toon("#ffcf3f", spec=0.6), verts=32))
    top = cyl(loc=(0.75, -0.2, 0.5), r=0.6, depth=0.14, rot=(70, 0, 20), mat=toon("#ffcf3f", spec=0.6), verts=32)
    out.append(top)
    s = extrude_poly(M.star_pts(0.3, 0.13, 5), 0.05, mat=toon("#e0a01f"))
    s.location = (0.0, 0, 0.72)
    out.append(s)
    return out


def xp_star():
    s = extrude_poly(M.star_pts(1.0, 0.45, 5), 0.35, mat=toon("#5ad16a", spec=0.4, emit=0.15), bevel=0.06)
    return [_rot(s, 90)]


def hook():
    h = tube([(0, 0, 1.2), (0, 0, -0.3), (-0.12, 0, -0.62), (-0.45, 0, -0.62), (-0.6, 0, -0.35), (-0.55, 0, -0.1)],
             0.09, mat=toon("#cfd6dc", spec=0.6))
    barb = cone(loc=(-0.5, 0, -0.08), r1=0.12, r2=0.0, depth=0.25, rot=(0, 30, 0), mat=toon("#cfd6dc", spec=0.6))
    eye = torus(loc=(0, 0, 1.32), R=0.14, r=0.05, rot=(90, 0, 0), mat=toon("#cfd6dc", spec=0.6))
    return [h, barb, eye]


def bucket():
    b = cone(r1=0.62, r2=0.8, depth=1.1, mat=toon("#4f86c6"), verts=28)
    rim = torus(loc=(0, 0, 0.55), R=0.8, r=0.06, mat=toon("#d0d6e0", spec=0.5))
    handle = tube([(-0.78, 0, 0.55), (0, 0, 1.25), (0.78, 0, 0.55)], 0.035, mat=toon("#d0d6e0"))
    fish = []
    for i, c in enumerate(["#6f8fa8", "#ffb02e", "#c86b5a"]):
        tail = cone(loc=(-0.3 + i * 0.3, 0, 0.75 + i * 0.05), r1=0.18, r2=0.0, depth=0.4, rot=(0, 0, 0), mat=toon(c),
                    verts=3, smooth=False)
        fish.append(tail)
    return [b, rim, handle] + fish


def shop():
    stall = cube(loc=(0, 0, 0.35), scale=(1.8, 0.9, 0.7), mat=toon("#9a6a3c"), bevel=0.03)
    out = [stall]
    for x in (-0.85, 0.85):
        out.append(cyl(loc=(x, 0.35, 1.0), r=0.05, depth=1.4, mat=toon("#7a4a26")))
    awn = cube(loc=(0, 0.05, 1.7), scale=(2.0, 1.1, 0.12), rot=(-12, 0, 0), mat=toon("#e8553b"))
    out.append(awn)
    for i in range(4):
        s = cube(loc=(-0.75 + i * 0.5, -0.52, 1.66), scale=(0.25, 0.05, 0.12), mat=toon("#ffffff"))
        s["no_outline"] = True
        out.append(s)
    out.append(sphere(loc=(-0.4, -0.2, 0.85), scale=(0.3, 0.12, 0.14), mat=toon("#6f8fa8")))
    out.append(sphere(loc=(0.35, -0.2, 0.85), scale=(0.25, 0.25, 0.25), mat=toon("#ffd23f")))
    return out


def compass():
    body = cyl(r=0.9, depth=0.25, rot=(90, 0, 0), mat=toon("#c9a24a", spec=0.5), verts=40)
    face = cyl(loc=(0, -0.13, 0), r=0.75, depth=0.02, rot=(90, 0, 0), mat=toon("#f6f1e2"), verts=40)
    face["no_outline"] = True
    n = _sym([(0, 0.62), (0.13, 0), (-0.13, 0)], "#e0322b", 0.04)
    s = _sym([(0, -0.62), (0.13, 0), (-0.13, 0)], "#3a3f55", 0.04)
    n.location.y = s.location.y = -0.17
    knob = cyl(loc=(0, 0, 1.02), r=0.12, depth=0.18, mat=toon("#c9a24a", spec=0.5))
    return [body, face, n, s, knob]


def bolt():
    b = extrude_poly([(0.25, 1.0), (-0.45, -0.05), (0.0, -0.05), (-0.25, -1.0), (0.5, 0.15), (0.05, 0.15)], 0.3,
                     mat=toon("#ffd23f", spec=0.4, emit=0.2), bevel=0.04)
    return [_rot(b, 90)]


def scroll():
    paper = cube(scale=(1.2, 0.05, 1.4), mat=toon("#f3e3b5"))
    out = [paper]
    for z in (0.72, -0.72):
        out.append(cyl(loc=(0, 0, z), r=0.13, depth=1.45, rot=(0, 90, 0), mat=toon("#c48a52")))
    for i in range(4):
        l = cube(loc=(0, -0.04, 0.4 - i * 0.25), scale=(0.8 - (i % 2) * 0.25, 0.02, 0.05), mat=toon("#8a6a3a"))
        l["no_outline"] = True
        out.append(l)
    return out


def crown():
    base = cyl(r=0.8, depth=0.5, mat=toon("#ffcf3f", spec=0.6), verts=10)
    out = [base]
    for i in range(5):
        a = i / 5 * math.tau
        out.append(cone(loc=(math.cos(a) * 0.72, math.sin(a) * 0.72, 0.55), r1=0.2, r2=0.0, depth=0.6, verts=6,
                        mat=toon("#ffcf3f", spec=0.6), smooth=False))
        out.append(sphere(loc=(math.cos(a) * 0.72, math.sin(a) * 0.72, 0.9), scale=0.08, mat=toon("#ffffff")))
    for i, c in enumerate(["#3a7bff", "#e0322b", "#2ecc71"]):
        a = -math.pi / 2 + (i - 1) * 0.6
        out.append(ico(loc=(math.cos(a) * 0.8, math.sin(a) * 0.8, 0.0), scale=0.13, mat=toon(c, emit=0.4, spec=0.6)))
    return out


def stats_icon():
    out = []
    for i, (h, c) in enumerate([(0.6, "#4fb3ff"), (1.0, "#5ad16a"), (1.5, "#ffd23f")]):
        out.append(cube(loc=(-0.55 + i * 0.55, 0, h / 2), scale=(0.4, 0.4, h), mat=toon(c), bevel=0.03))
    return out


def gear():
    pts = []
    for i in range(32):
        a = i / 32 * math.tau
        r = 0.9 if (i // 2) % 2 == 0 else 0.7
        pts.append((math.cos(a) * r, math.sin(a) * r))
    g = extrude_poly(pts, 0.3, mat=toon("#9aa7b2", spec=0.5))
    hole = cyl(loc=(0, -0.16, 0), r=0.3, depth=0.05, rot=(90, 0, 0), mat=toon("#3a3f44"))
    hole["no_outline"] = True
    return [_rot(g, 90), hole]


def calendar():
    page = cube(scale=(1.4, 0.12, 1.3), mat=toon("#f6f1e2"), bevel=0.04)
    top = cube(loc=(0, 0, 0.55), scale=(1.42, 0.14, 0.3), mat=toon("#e0322b"), bevel=0.04)
    out = [page, top]
    for x in (-0.4, 0.4):
        out.append(torus(loc=(x, 0, 0.75), R=0.1, r=0.03, rot=(0, 90, 0), mat=toon("#9aa7b2")))
    for i in range(3):
        for j in range(3):
            d = cube(loc=(-0.38 + i * 0.38, -0.07, 0.12 - j * 0.3), scale=(0.2, 0.02, 0.15),
                     mat=toon("#3a3f55" if (i + j) % 4 else "#ffd23f"))
            d["no_outline"] = True
            out.append(d)
    return out


PROPS = {
    "baits": {"Worms": worms, "Leeches": leeches, "Magnet": magnet, "Wise Bait": wise_bait, "Fish": fish_bait,
              "Artifact Magnet": artifact_magnet, "Magic Bait": magic_bait, "Support Bait": support_bait},
    "chests": {k: (lambda k=k: chest(k)) for k in CHEST_COLORS},
    "charms": {"marketing": charm_marketing, "endurance": charm_endurance, "haste": charm_haste,
               "quantity": charm_quantity, "worker": charm_worker, "treasure": charm_treasure,
               "quality": charm_quality, "experience": charm_experience},
    "ui": {"money": coins, "xp": xp_star, "hooks": hook, "inventory": bucket, "shop": shop, "biomes": compass,
           "boosts": bolt, "quests": scroll, "prestige": crown, "stats": stats_icon, "settings": gear, "daily": calendar},
}

PROP_VIEW = {
    "baits": {"rot": (70, 0, 20)},
    "chests": {"rot": (70, 0, 28), "outline": 0.04},
    "charms": {"rot": (88, 0, 10), "outline": 0.03},
    "ui": {"rot": (75, 0, 22), "outline": 0.04},
}

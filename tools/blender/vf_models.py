"""Procedural models for Virtual Fisher: fish, pets, exotic fish."""
import colorsys
import math
import random

import bmesh
import bpy
from mathutils import Vector

from vf_kit import (cone, cube, cyl, deform, extrude_poly, hexc, ico, join, mix, outline_all,
                    sphere, toon, torus, tube, vcolor)


# ===================================================================== FISH
# Fish face +X. Body length ~2 units.
FISH_SPECS = {
    # name: body colours (top, belly), fin colour, shape tweaks
    "Raw Fish":         dict(top="#6f8fa8", belly="#dfe9ef", fin="#57738a", L=1.0, H=0.42, W=0.26),
    "Raw Salmon":       dict(top="#c86b5a", belly="#f6c4ae", fin="#a8574a", L=1.1, H=0.38, W=0.25, spots="#7d3f36"),
    "Cod":              dict(top="#9a8a5c", belly="#efe6c8", fin="#7e7049", L=1.05, H=0.44, W=0.28, spots="#6b5d3a", barbel=True),
    "Tropical Fish":    dict(top="#ffb02e", belly="#fff1c9", fin="#2b7de9", L=0.85, H=0.62, W=0.18, stripes="#ffffff", sail=True),
    "Pufferfish":       dict(top="#e8c547", belly="#fff6d6", fin="#d39b2a", puffer=True, spike="#f4ead0"),
    "Fiery Pufferfish": dict(top="#ff6a1f", belly="#ffd08a", fin="#d23c12", puffer=True, spike="#ffe066", flames=True),
    "Hot Cod":          dict(top="#e2452b", belly="#ffc38a", fin="#b52a1d", L=1.05, H=0.44, W=0.28, glow_line="#ffd23f", flames=True),
    "Squid":            dict(squid=True, top="#c9a3e6", belly="#f0e1fb", fin="#a678cf"),
    "Turtle":           dict(turtle=True, top="#4fa45a", belly="#d9c48e", fin="#7cc36b"),
    "Dolphin":          dict(dolphin=True, top="#6f97c2", belly="#e7eef6", fin="#5b82ad"),
    "Guardian":         dict(guardian=True, top="#5fa59b", belly="#e48a3c", fin="#e48a3c"),
    "Emerald Squid":    dict(squid=True, top="#26c46b", belly="#c5f7d9", fin="#119953", gem=True),
    "Rainbow Fish":     dict(rainbow=True, top="#ffffff", belly="#ffffff", fin="#ff6bd6", L=1.0, H=0.5, W=0.22, sail=True),
    "Space Fish":       dict(top="#3a2a8a", belly="#8f7dff", fin="#c56bff", L=1.0, H=0.48, W=0.24, stars=True, glow_fin=True),
    "Galactic Crab":    dict(crab=True, top="#5a3ec8", belly="#b99cff", fin="#ff7bd5", stars=True),
    "Shark":            dict(shark=True, top="#6b7d8c", belly="#eef2f4", fin="#5c6c7a"),
    "Alien Fish":       dict(top="#23c48f", belly="#c4ffe8", fin="#a24bff", L=1.0, H=0.5, W=0.26, alien=True),
    "Artifact Fish":    dict(top="#c99a2e", belly="#f0d784", fin="#2fd3c6", L=1.0, H=0.5, W=0.26, runes="#3ff2e4", metal=True),
    "Dark Puffer":      dict(top="#2a1840", belly="#5a3a80", fin="#9b4dff", puffer=True, spike="#c77dff", glow_spikes=True),
    "Dark Tuna":        dict(top="#151b2e", belly="#3c4466", fin="#3b4a8a", L=1.25, H=0.46, W=0.3, glow_line="#5ff2ff", tuna=True),
}

EXOTIC_SPECS = {
    "gold":    dict(top="#f5c542", belly="#fff1a8", fin="#d99a1e", L=1.0, H=0.5, W=0.26, metal=True, eye_cute=True),
    "emerald": dict(top="#18b86a", belly="#9df5c4", fin="#0d8a4c", L=1.0, H=0.5, W=0.26, faceted=True, gemglow=0.25),
    "lava":    dict(top="#2a1a1a", belly="#4a2620", fin="#ff5a1f", L=1.0, H=0.5, W=0.26, cracks="#ff7a1f", flames=True),
    "diamond": dict(top="#8fe9ff", belly="#e9fbff", fin="#5ad0f0", L=1.0, H=0.5, W=0.26, faceted=True, gemglow=0.35),
    "azure":   dict(top="#2f6bff", belly="#9fc4ff", fin="#1a3fbf", L=1.0, H=0.5, W=0.26, glow_fin=True, gemglow=0.3, stars=True),
}

PET_SPECS = {
    "Puffer":    dict(top="#f2c94c", belly="#fff6d6", fin="#e0a52b", puffer=True, spike="#fff2c4", cute=True),
    "Zebrafish": dict(top="#6fb6ff", belly="#eaf5ff", fin="#4c8fe0", L=0.95, H=0.42, W=0.22, zebra="#1e3a6a", cute=True),
    "Dolphin":   dict(dolphin=True, top="#7fa8d6", belly="#eef4fb", fin="#6690c0", cute=True),
    "Axolotl":   dict(axolotl=True, top="#ffb3c7", belly="#ffe1ea", fin="#ff7aa2", cute=True),
    "Tuna":      dict(top="#2d4a7a", belly="#dfe8f2", fin="#f2c230", L=1.2, H=0.5, W=0.3, tuna=True, cute=True),
}


def _fish_body(spec):
    L, H, W = spec.get("L", 1.0), spec.get("H", 0.45), spec.get("W", 0.25)
    seg = 10 if spec.get("faceted") else 64
    rings = 6 if spec.get("faceted") else 24
    body = sphere(scale=1.0, seg=seg, rings=rings, smooth=not spec.get("faceted"))
    tuna = spec.get("tuna")

    def shape(co):
        x = co.x
        # round head, body narrows toward the tail peduncle
        k = 1.0 if x > 0.15 else 1.0 - (0.62 if tuna else 0.5) * ((0.15 - x) / 1.15) ** 1.3
        return Vector((x * L, co.y * W * k, co.z * H * k + 0.06 * H * max(0.0, x)))
    deform(body, shape)
    top, belly = hexc(spec["top"]), hexc(spec["belly"])

    def paint(co, n):
        zt = min(1.0, max(0.0, (co.z / H + 0.35) / 0.9))
        c = mix(belly, top, zt ** 1.3)
        x = co.x / L
        if spec.get("rainbow"):
            hue = (x * 0.45 + 0.55) % 1.0
            r, g, b = colorsys.hsv_to_rgb(hue, 0.65, 1.0)
            c = mix(hexc("#%02x%02x%02x" % (int(r * 255), int(g * 255), int(b * 255))), belly, 0.25 * (1 - zt))
        if spec.get("stripes") and (int((x + 1) * 3.2) % 2 == 1) and abs(x) < 0.75:
            c = hexc(spec["stripes"])
        if spec.get("zebra") and (int((x + 1) * 6.5) % 2 == 1) and x < 0.6:
            c = mix(c, hexc(spec["zebra"]), 0.85)
        if spec.get("spots"):
            h = math.sin(co.x * 37.0) * math.sin(co.y * 41.0 + 1.3) * math.sin(co.z * 29.0 + 0.7)
            if h > 0.45 and zt > 0.45:
                c = hexc(spec["spots"])
        if spec.get("glow_line") and abs(co.z / H) < 0.06:
            c = hexc(spec["glow_line"])
        if spec.get("runes") and (abs(x - 0.15) < 0.035 or abs(x + 0.3) < 0.035):
            c = hexc(spec["runes"])
        if spec.get("cracks"):
            h = abs(math.sin(co.x * 23 + co.z * 17) + math.sin(co.y * 19 - co.z * 13))
            if h < 0.18:
                c = hexc(spec["cracks"])
        return c
    vcolor(body, paint)
    glow = 0.0
    if spec.get("glow_line") or spec.get("runes") or spec.get("cracks"):
        glow = 0.25
    glow = spec.get("gemglow", glow)
    body.data.materials.append(toon(None, vcol="col", spec=0.55 if spec.get("metal") or spec.get("faceted") else 0.12,
                                    emit=glow, key=("fishbody", spec["top"], spec["belly"], glow, spec.get("metal"), spec.get("faceted"))))
    return body, L, H, W


def _tail(L, H, color, forked=True, scale=1.0, vertical=True):
    s = scale
    if forked:
        pts = [(0, 0), (-0.55 * s, 0.55 * s), (-0.42 * s, 0.05 * s), (-0.55 * s, -0.55 * s)]
    else:
        pts = [(0, 0), (-0.5 * s, 0.4 * s), (-0.5 * s, -0.4 * s)]
    ob = extrude_poly(pts, 0.05, mat=toon(color))
    ob.rotation_euler = (math.radians(90), 0, 0) if vertical else (0, 0, 0)
    ob.location = (-L * 0.92, 0, 0)
    ob.scale = (1, H * 2.0, 1) if vertical else (1, H * 2.0, 1)
    return ob


def _fin(pts, loc, rot, color, thick=0.04):
    ob = extrude_poly(pts, thick, mat=toon(color))
    ob.rotation_euler = [math.radians(a) for a in rot]
    ob.location = loc
    return ob


def _eyes(L, H, W, x=0.62, z=0.12, size=0.11, cute=False, glow=None):
    parts = []
    s = size * (1.7 if cute else 1.0)
    for side in (1, -1):
        y = side * W * 0.62
        white = sphere(loc=(L * x, y, H * z), scale=s, mat=toon("#ffffff" if not glow else glow, emit=0.6 if glow else 0.0))
        pupil = sphere(loc=(L * x + s * 0.25, y + side * s * 0.55, H * z + s * 0.05), scale=s * 0.62,
                       mat=toon("#141018", shade=1.0, rim=0.0))
        parts += [white, pupil]
        if cute:
            parts.append(sphere(loc=(L * x + s * 0.45, y + side * s * 0.95, H * z + s * 0.3), scale=s * 0.2,
                                mat=toon("#ffffff", flat_glow=True)))
    for p in parts:
        p["no_outline"] = True
    return parts


def _std_fins(spec, L, H, W):
    fin = spec["fin"]
    parts = [_tail(L, H, fin, forked=not spec.get("round_tail"), scale=1.0 if not spec.get("tuna") else 1.2)]
    if spec.get("sail"):
        parts.append(_fin([(-0.5, 0), (0.35, 0), (0.1, 0.55), (-0.35, 0.5)], (0, 0, H * 0.82), (90, 0, 0), fin))
        parts.append(_fin([(-0.4, 0), (0.25, 0), (-0.25, -0.4)], (0, 0, -H * 0.8), (90, 0, 0), fin))
    else:
        parts.append(_fin([(-0.35, 0), (0.3, 0), (-0.15, 0.32)], (-0.05, 0, H * 0.85), (90, 0, 0), fin))
    for side in (1, -1):
        parts.append(_fin([(0, 0), (-0.32, 0.12), (-0.28, -0.08)], (L * 0.28, side * W * 0.85, -H * 0.25),
                          (90 + side * 20, 0, side * 15), fin, 0.03))
    if spec.get("glow_fin"):
        for p in parts:
            p.data.materials[0] = toon(fin, emit=0.5)
    return parts


def _spikes(radius, color, n=26, length=0.24, glow=False):
    out = []
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        y = 1 - (i / (n - 1)) * 2
        r = math.sqrt(1 - y * y)
        th = golden * i
        d = Vector((math.cos(th) * r, y, math.sin(th) * r))
        if d.x > 0.75:
            continue
        c = cone(r1=0.06, r2=0.0, depth=length, verts=6, mat=toon(color, emit=0.6 if glow else 0.0), smooth=False)
        c.location = d * (radius + length * 0.35)
        c.rotation_mode = "QUATERNION"
        c.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
        c["outline_k"] = 0.35
        out.append(c)
    return out


def _flames(at, scale=0.6):
    out = []
    for i, (dx, h) in enumerate([(-0.18, 0.9), (0.0, 1.25), (0.18, 0.85)]):
        out.append(cone(loc=(at[0] + dx * scale, at[1], at[2] + h * scale * 0.4), r1=0.13 * scale, r2=0.0,
                        depth=h * scale * 0.8, verts=8, mat=toon("#ffb21f", emit=0.85), smooth=False))
        out.append(cone(loc=(at[0] + dx * scale, at[1], at[2] + h * scale * 0.3), r1=0.08 * scale, r2=0.0,
                        depth=h * scale * 0.5, verts=8, mat=toon("#fff2a0", emit=1.0), smooth=False))
    return out


def _sparkles(L, H, W, color="#ffffff", n=9):
    out = []
    rnd = random.Random(7)
    for _ in range(n):
        p = Vector((rnd.uniform(-0.7, 0.7) * L, rnd.uniform(-1, 1) * W * 0.95, rnd.uniform(-0.2, 0.75) * H))
        s = ico(loc=p, scale=0.035, mat=toon(color, flat_glow=True), sub=1)
        s["no_outline"] = True
        out.append(s)
    return out


def build_fish(spec):
    """Returns list of objects (+X forward)."""
    if spec.get("puffer"):
        return _puffer(spec)
    if spec.get("squid"):
        return _squid(spec)
    if spec.get("turtle"):
        return _turtle(spec)
    if spec.get("dolphin") or spec.get("shark"):
        return _dolphin_shark(spec)
    if spec.get("guardian"):
        return _guardian(spec)
    if spec.get("crab"):
        return _crab(spec)
    if spec.get("axolotl"):
        return _axolotl(spec)
    body, L, H, W = _fish_body(spec)
    parts = [body] + _std_fins(spec, L, H, W)
    parts += _eyes(L, H, W, cute=spec.get("cute"), glow="#b8ff6a" if spec.get("alien") else None)
    if spec.get("barbel"):
        parts.append(tube([(L * 0.86, 0, -H * 0.3), (L * 0.95, 0, -H * 0.55), (L * 0.9, 0, -H * 0.7)], 0.015,
                          mat=toon(spec["fin"])))
    if spec.get("alien"):
        for side in (1, -1):
            parts.append(tube([(L * 0.5, side * 0.05, H * 0.8), (L * 0.6, side * 0.15, H * 1.25), (L * 0.85, side * 0.2, H * 1.45)],
                              0.02, mat=toon(spec["fin"])))
            parts.append(sphere(loc=(L * 0.85, side * 0.2, H * 1.45), scale=0.07, mat=toon("#b8ff6a", emit=0.9)))
    if spec.get("flames"):
        parts += _flames((-0.1, 0, H * 0.95), 0.55)
    if spec.get("stars"):
        parts += _sparkles(L, H, W)
    if spec.get("metal") or spec.get("faceted"):
        parts += _sparkles(L, H, W, n=5)
    return parts


def _puffer(spec):
    R = 0.62
    body = sphere(scale=R, seg=32, rings=16)
    top, belly = hexc(spec["top"]), hexc(spec["belly"])
    vcolor(body, lambda co, n: mix(belly, top, min(1.0, max(0.0, (co.z / R + 0.3) / 0.9))))
    body.data.materials.append(toon(None, vcol="col", key=("puffbody", spec["top"], spec["belly"])))
    parts = [body]
    parts += _spikes(R, spec["spike"], glow=spec.get("glow_spikes"))
    parts.append(_tail(R * 0.9, 0.3, spec["fin"], forked=False, scale=0.7))
    for side in (1, -1):
        parts.append(_fin([(0, 0), (-0.25, 0.15), (-0.22, -0.1)], (R * 0.3, side * R * 0.92, -0.05), (90 + side * 25, 0, 0),
                          spec["fin"], 0.03))
    parts += _eyes(R, R, R, x=0.72, z=0.32, size=0.13, cute=spec.get("cute"))
    mouth = torus(loc=(R * 0.98, 0, -0.08), R=0.07, r=0.025, rot=(0, 90, 0), mat=toon("#c0505a"))
    parts.append(mouth)
    if spec.get("flames"):
        parts += _flames((0, 0, R * 0.9), 0.65)
    return parts


def _squid(spec):
    mantle = sphere(scale=1.0, seg=32, rings=16)
    deform(mantle, lambda co: Vector((co.x * 0.95 - 0.1 * co.x ** 2, co.y * 0.5 * (0.45 + 0.55 * (1 - co.x) / 2) ** 0.5,
                                       co.z * 0.5 * (0.45 + 0.55 * (1 - co.x) / 2) ** 0.5)))
    top, belly = hexc(spec["top"]), hexc(spec["belly"])

    def paint(co, n):
        c = mix(belly, top, min(1.0, max(0.0, co.z / 0.36 + 0.5)))
        if math.sin(co.x * 26) * math.sin(co.y * 30) > 0.6:
            c = mix(c, hexc(spec["fin"]), 0.6)
        return c
    vcolor(mantle, paint)
    mantle.data.materials.append(toon(None, vcol="col", emit=0.15 if spec.get("gem") else 0.0, spec=0.3 if spec.get("gem") else 0.1,
                                      key=("squid", spec["top"])))
    mantle.location.x = 0.35
    parts = [mantle]
    # head fin at the back (pointing +X since squid swims backwards; we flip: tentacles at -X)
    for side in (1, -1):
        parts.append(_fin([(0, 0), (0.45, side * 0.35), (0.55, 0)], (0.85, 0, 0), (0, 0, 0), spec["fin"], 0.03))
    rnd = random.Random(3)
    for i in range(8):
        a = (i / 8) * math.tau
        y, z = math.cos(a) * 0.17, math.sin(a) * 0.17
        wig = rnd.uniform(-0.12, 0.12)
        pts = [(-0.55, y, z), (-0.9, y * 1.4 + wig, z * 1.2 - 0.05), (-1.25, y * 1.7 - wig, z * 1.3 - 0.12)]
        t = tube(pts, 0.06, mat=toon(spec["fin"]), taper=(1.0, 0.3))
        t["outline_k"] = 0.6
        parts.append(t)
    head = sphere(loc=(-0.5, 0, 0), scale=(0.26, 0.24, 0.24), mat=toon(spec["top"]))
    parts.append(head)
    for side in (1, -1):
        e = sphere(loc=(-0.5, side * 0.2, 0.08), scale=0.08, mat=toon("#ffffff"))
        p = sphere(loc=(-0.53, side * 0.26, 0.08), scale=0.05, mat=toon("#141018", rim=0))
        e["no_outline"] = p["no_outline"] = True
        parts += [e, p]
    if spec.get("gem"):
        parts.append(ico(loc=(0.4, 0, 0.36), scale=0.12, mat=toon("#7dffb0", emit=0.6, spec=0.5)))
    # face +X: rotate the whole thing later by caller if needed
    return parts


def _turtle(spec):
    shell = sphere(scale=(0.85, 0.65, 0.42), seg=12, rings=8, smooth=False)
    deform(shell, lambda co: Vector((co.x, co.y, max(co.z, -0.05 * 0.42))))

    def paint(co, n):
        hexa = (math.sin(co.x * 9) + math.sin(co.y * 10 + co.x * 4)) > 0.9
        return hexc("#2f6e3a") if hexa else hexc(spec["top"])
    vcolor(shell, paint)
    shell.data.materials.append(toon(None, vcol="col", key=("turtle", spec["top"])))
    plate = sphere(loc=(0, 0, -0.04), scale=(0.8, 0.6, 0.12), mat=toon(spec["belly"]))
    head = sphere(loc=(0.95, 0, 0.08), scale=(0.3, 0.22, 0.2), mat=toon(spec["fin"]))
    parts = [shell, plate, head]
    for sx, sy, ang in [(0.45, 1, 35), (0.45, -1, -35), (-0.5, 1, 140), (-0.5, -1, -140)]:
        fl = sphere(loc=(sx, sy * 0.66, -0.04), scale=(0.42 if sx > 0 else 0.28, 0.13, 0.05), rot=(0, 0, ang),
                    mat=toon(spec["fin"]))
        parts.append(fl)
    parts += _eyes(1.12, 0.2, 0.3, x=1.0, z=0.7, size=0.06)
    return parts


def _dolphin_shark(spec):
    shark = spec.get("shark")
    body = sphere(scale=1.0, seg=40, rings=20)
    L, H, W = 1.25, 0.36, 0.3

    def shape(co):
        t = (co.x + 1) / 2
        k = 0.25 + 0.75 * math.sin(math.pi * min(1.0, 0.12 + t * 0.95)) ** 0.7
        return Vector((co.x * L, co.y * W * k, co.z * H * k))
    deform(body, shape)
    top, belly = hexc(spec["top"]), hexc(spec["belly"])
    vcolor(body, lambda co, n: mix(belly, top, 1.0 if co.z > -0.02 - 0.05 * co.x else 0.0))
    body.data.materials.append(toon(None, vcol="col", key=("dolph", spec["top"], spec["belly"])))
    parts = [body]
    fin = spec["fin"]
    if shark:
        parts.append(_fin([(-0.3, 0), (0.3, 0), (-0.15, 0.6)], (0.0, 0, H * 0.82), (90, 0, 0), fin, 0.05))
        parts.append(_fin([(0, 0), (-0.55, 0.62), (-0.35, 0.0), (-0.45, -0.38)], (-L * 0.92, 0, 0), (90, 0, 0), fin, 0.05))
        for i in range(3):
            g = cube(loc=(L * 0.52 - i * 0.07, W * 0.55, 0.0), scale=(0.015, 0.02, 0.16), mat=toon("#3d4852"))
            g2 = cube(loc=(L * 0.52 - i * 0.07, -W * 0.55, 0.0), scale=(0.015, 0.02, 0.16), mat=toon("#3d4852"))
            g["no_outline"] = g2["no_outline"] = True
            parts += [g, g2]
        mouth = cube(loc=(L * 0.8, 0, -H * 0.35), scale=(0.25, 0.2, 0.02), rot=(0, -10, 0), mat=toon("#3d1f24"))
        parts.append(mouth)
    else:
        parts.append(_fin([(-0.25, 0), (0.25, 0), (-0.2, 0.42)], (-0.05, 0, H * 0.85), (90, 0, 0), fin, 0.05))
        flukes = _fin([(0, 0), (-0.42, 0.45), (-0.3, 0.0), (-0.42, -0.45)], (-L * 0.92, 0, 0), (0, 0, 0), fin, 0.05)
        parts.append(flukes)
        beak = cone(loc=(L * 1.02, 0, -0.05), r1=0.11, r2=0.06, depth=0.28, rot=(0, 90, 0), mat=toon(spec["top"]))
        parts.append(beak)
    for side in (1, -1):
        parts.append(_fin([(0, 0), (-0.38, 0.1), (-0.32, -0.12)], (L * 0.35, side * W * 0.75, -H * 0.4),
                          (90 + side * 30, 0, side * 20), fin, 0.03))
    parts += _eyes(L, H, W, x=0.7, z=0.25, size=0.07, cute=spec.get("cute"))
    return parts


def _guardian(spec):
    body = cube(scale=(1.0, 0.9, 0.9), mat=toon(spec["top"]), bevel=0.05)
    parts = [body]
    stripe = cube(loc=(0, 0, -0.38), scale=(1.02, 0.92, 0.14), mat=toon(spec["belly"]))
    parts.append(stripe)
    eye_w = cube(loc=(0.505, 0, 0.05), scale=(0.02, 0.42, 0.42), mat=toon("#f2f2e8"))
    eye_i = cube(loc=(0.52, 0, 0.05), scale=(0.02, 0.24, 0.24), mat=toon("#b4532a"))
    eye_p = cube(loc=(0.535, 0, 0.05), scale=(0.02, 0.1, 0.1), mat=toon("#141018"))
    for e in (eye_w, eye_i, eye_p):
        e["no_outline"] = True
    parts += [eye_w, eye_i, eye_p]
    for fx in (-0.35, 0.0, 0.35):
        for d, rot in [((fx, 0, 0.5), (0, 0, 0)), ((fx, 0.5, 0), (-90, 0, 0)), ((fx, -0.5, 0), (90, 0, 0))]:
            parts.append(cone(loc=(d[0], d[1] * 1.18, d[2] * 1.18), r1=0.06, r2=0.0, depth=0.3, rot=rot, verts=4,
                              mat=toon("#e9dfc6"), smooth=False))
    for i, s in enumerate([0.42, 0.32, 0.22]):
        parts.append(cube(loc=(-0.6 - i * 0.32, 0, -0.05 - i * 0.04), scale=(0.3, s, s), mat=toon(spec["top"]), bevel=0.02))
    parts.append(_fin([(0, 0), (-0.3, 0.3), (-0.3, -0.3)], (-1.42, 0, -0.18), (90, 0, 0), spec["fin"], 0.05))
    return parts


def _crab(spec):
    body = sphere(scale=(0.7, 0.85, 0.36), seg=24, rings=12)
    top, belly = hexc(spec["top"]), hexc(spec["belly"])
    vcolor(body, lambda co, n: mix(belly, top, min(1.0, max(0.0, co.z / 0.36 + 0.4))))
    body.data.materials.append(toon(None, vcol="col", key=("crab", spec["top"])))
    parts = [body]
    leg = toon(spec["fin"])
    for side in (1, -1):
        for i in range(3):
            x = -0.3 + i * 0.25
            parts.append(tube([(x, side * 0.7, 0), (x - 0.15, side * 1.05, 0.18), (x - 0.25, side * 1.2, -0.35)], 0.05,
                              mat=leg, taper=(1.0, 0.5)))
        parts.append(tube([(0.4, side * 0.6, 0.05), (0.75, side * 0.85, 0.2), (0.95, side * 0.7, 0.25)], 0.07, mat=leg))
        claw = sphere(loc=(1.05, side * 0.68, 0.28), scale=(0.25, 0.16, 0.14), mat=toon(spec["fin"]))
        pinch = cone(loc=(1.3, side * 0.68, 0.35), r1=0.07, r2=0.0, depth=0.25, rot=(0, 90, 0), mat=toon(spec["fin"]))
        parts += [claw, pinch]
        parts.append(tube([(0.45, side * 0.18, 0.25), (0.55, side * 0.22, 0.55)], 0.03, mat=leg))
        e = sphere(loc=(0.55, side * 0.22, 0.6), scale=0.08, mat=toon("#ffffff"))
        p = sphere(loc=(0.61, side * 0.24, 0.62), scale=0.045, mat=toon("#141018", rim=0))
        e["no_outline"] = p["no_outline"] = True
        parts += [e, p]
    if spec.get("stars"):
        parts += _sparkles(0.75, 0.4, 0.8, n=10)
    return parts


def _axolotl(spec):
    body = sphere(scale=1.0, seg=32, rings=16)
    deform(body, lambda co: Vector((co.x * 0.95, co.y * 0.32, co.z * 0.3)))
    body.data.materials.append(toon(spec["top"]))
    head = sphere(loc=(0.85, 0, 0.08), scale=(0.42, 0.45, 0.34), mat=toon(spec["top"]))
    parts = [body, head]
    parts.append(_fin([(0, 0), (-0.75, 0.3), (-0.85, 0.0), (-0.7, -0.2)], (-0.7, 0, 0.0), (90, 0, 0), spec["fin"], 0.03))
    for side in (1, -1):
        for j, (dz, ang) in enumerate([(0.25, 35), (0.1, 15), (-0.05, -5)]):
            g = cone(loc=(0.72, side * 0.45, 0.12 + dz), r1=0.05, r2=0.02, depth=0.32,
                     rot=(side * (90 - ang), 0, 0), mat=toon(spec["fin"]))
            parts.append(g)
        for lx in (0.5, -0.4):
            parts.append(sphere(loc=(lx, side * 0.36, -0.2), scale=(0.1, 0.14, 0.06), mat=toon(spec["top"])))
    parts += _eyes(1.0, 0.34, 0.6, x=0.98, z=0.6, size=0.06, cute=True)
    smile = torus(loc=(1.22, 0, -0.02), R=0.08, r=0.015, rot=(0, 90, 0), mat=toon("#b04a6a"))
    smile["no_outline"] = True
    parts.append(smile)
    return parts


# ============================================================ fisherman
def build_fisherman(scale=1.0, shirt="#e8553b", pants="#2f4a7a", hat="#f2c14e", skin="#f2c6a0", straw=False):
    """Standing angler facing +X holding a rod over the side. Returns (parts, rod_tip)."""
    s = scale
    parts = []
    for side in (1, -1):
        parts.append(cyl(loc=(0, side * 0.12 * s, 0.38 * s), r=0.09 * s, depth=0.76 * s, mat=toon(pants)))
        parts.append(cube(loc=(0.05 * s, side * 0.12 * s, 0.04 * s), scale=(0.28 * s, 0.14 * s, 0.1 * s), mat=toon("#3a2a22"),
                          bevel=0.02 * s))
    torso = sphere(loc=(0, 0, 1.05 * s), scale=(0.24 * s, 0.3 * s, 0.38 * s), mat=toon(shirt))
    parts.append(torso)
    vest = sphere(loc=(0.02 * s, 0, 1.0 * s), scale=(0.25 * s, 0.31 * s, 0.3 * s), mat=toon("#4e7a3a"))
    parts.append(vest)
    head = sphere(loc=(0.02 * s, 0, 1.62 * s), scale=0.21 * s, mat=toon(skin))
    parts.append(head)
    nose = sphere(loc=(0.22 * s, 0, 1.6 * s), scale=0.05 * s, mat=toon(skin))
    parts.append(nose)
    for side in (1, -1):
        e = sphere(loc=(0.18 * s, side * 0.08 * s, 1.67 * s), scale=0.03 * s, mat=toon("#1a1420", rim=0))
        e["no_outline"] = True
        parts.append(e)
    if straw:
        parts.append(cone(loc=(0.02 * s, 0, 1.86 * s), r1=0.62 * s, r2=0.03 * s, depth=0.34 * s, mat=toon("#e3c27e"), verts=40))
        parts.append(torus(loc=(0.02 * s, 0, 1.93 * s), R=0.27 * s, r=0.025 * s, mat=toon("#2f8f8a"), seg=32, mseg=8))
        parts.append(sphere(loc=(0.02 * s, 0, 2.03 * s), scale=0.05 * s, mat=toon("#c9a35c")))
    else:
        parts.append(cyl(loc=(0.02 * s, 0, 1.8 * s), r=0.2 * s, depth=0.16 * s, mat=toon(hat)))
        parts.append(cyl(loc=(0.02 * s, 0, 1.73 * s), r=0.32 * s, depth=0.03 * s, mat=toon(hat), verts=32))
    if straw:
        parts.append(cube(loc=(-0.24 * s, 0, 1.0 * s), scale=(0.18 * s, 0.38 * s, 0.5 * s), mat=toon("#c9a35c"), bevel=0.04 * s))
    parts.append(cyl(loc=(0.02 * s, 0, 1.79 * s), r=0.205 * s, depth=0.05 * s, mat=toon("#b5462f")))
    # arms reaching forward to the rod grip
    grip = Vector((0.45 * s, 0.0, 1.05 * s))
    for side in (1, -1):
        sh = Vector((0.0, side * 0.3 * s, 1.3 * s))
        el = Vector((0.25 * s, side * 0.25 * s, 1.0 * s))
        parts.append(tube([sh, el, grip + Vector((0, side * 0.05 * s, 0))], 0.07 * s, mat=toon(shirt)))
        parts.append(sphere(loc=grip + Vector((0, side * 0.06 * s, 0)), scale=0.075 * s, mat=toon(skin)))
    # rod
    butt = grip + Vector((-0.25 * s, 0, -0.18 * s))
    tip = grip + Vector((1.55 * s, 0, 1.25 * s))
    parts.append(tube([butt, grip, tip], 0.035 * s, mat=toon("#3a2a22"), taper=(1.2, 0.35)))
    parts.append(cyl(loc=grip + Vector((-0.12 * s, 0.08 * s, -0.12 * s)), r=0.07 * s, depth=0.06 * s,
                     rot=(90, 0, 0), mat=toon("#c0c6cc", spec=0.4)))
    return parts, tip


# ================================================================== RODS
ROD_SPECS = {
    "Plastic Rod":         dict(blank="#4aa3ff", grip="#ffd23f", reel="#e9eef2"),
    "Improved Rod":        dict(blank="#3fbf6a", grip="#2a2a2a", reel="#cfd6dc"),
    "Steel Rod":           dict(blank="#9aa7b2", grip="#3a3f44", reel="#dfe5ea", metal=True),
    "Fiberglass Rod":      dict(blank="#f5f1e6", grip="#ff7a2f", reel="#ff7a2f", wraps="#ff7a2f"),
    "Heavy Rod":           dict(blank="#5a3a24", grip="#2b1d14", reel="#8c8c8c", thick=1.6),
    "Alloy Rod":           dict(blank="#2fb5a8", grip="#b07a3a", reel="#c9a066", metal=True),
    "Lava Rod":            dict(blank="#2a1c1c", grip="#45302a", reel="#ff6a1f", glow="#ff6a1f"),
    "Magma Rod":           dict(blank="#d1361d", grip="#2a1c1c", reel="#ffb21f", glow="#ffd23f", flames=True),
    "Oceanium Rod":        dict(blank="#3fd2e0", grip="#1f5f8a", reel="#e8fbff", pearl=True),
    "Golden Rod":          dict(blank="#f5c542", grip="#8a5a1e", reel="#ffe27a", metal=True),
    "Superium Rod":        dict(blank="#f2f6fa", grip="#1e88e5", reel="#4fc3f7", wraps="#4fc3f7", metal=True),
    "Infinity Rod":        dict(blank="#d4a017", grip="#6b3fa0", reel="#f5c542", metal=True, stones=True),
    "Floating Rod":        dict(blank="#9b6bff", grip="#2b1f4a", reel="#e0d4ff", glow="#c9b3ff", rings=True),
    "Sky Rod":             dict(blank="#8fd3ff", grip="#ffffff", reel="#ffffff", wings=True),
    "Meteor Rod":          dict(blank="#5b4636", grip="#2a211b", reel="#ff8a3d", meteor=True),
    "Space Rod":           dict(blank="#1b1f4a", grip="#0d0f24", reel="#c9d3ff", glow="#8e9bff", sparkle=True),
    "Alien Rod":           dict(blank="#33d17a", grip="#3d2a66", reel="#b8ff6a", glow="#b8ff6a", segments=True),
    "Ultimate Depths Rod": dict(blank="#0f5e6e", grip="#08272e", reel="#5ff2ff", glow="#5ff2ff", wraps="#5ff2ff"),
    "Abyssal Supermagnet": dict(blank="#3a3f55", grip="#1a1c26", reel="#d0d6e0", magnet=True),
    "Dark Rod":            dict(blank="#1a1024", grip="#0b0710", reel="#9b4dff", glow="#c77dff", wraps="#9b4dff"),
    "Supporter Rod":       dict(blank="#ff7ac0", grip="#6a2a8a", reel="#ffd6ef", heart=True, wraps="#ffffff"),
}


def build_rod(spec, strip=False):
    """Rod along a diagonal in the XZ plane, tip upper-right.

    strip=True leaves out the line and bobber (used for the in-hand rod)."""
    th = spec.get("thick", 1.0)
    d = Vector((1, 0, 1)).normalized()
    L = 3.0
    base = Vector((-1.1, 0, -1.1))
    tip = base + d * L
    parts = []
    glow = 0.5 if spec.get("glow") else 0.0
    blank_mat = toon(spec["blank"], spec=0.6 if spec.get("metal") else 0.15, emit=0.15 if spec.get("glow") else 0.0)
    parts.append(tube([base + d * 0.75, base + d * 1.8, tip], 0.05 * th, mat=blank_mat, taper=(1.0, 0.3)))
    parts.append(tube([base, base + d * 0.8], 0.085 * th, mat=toon(spec["grip"]), taper=(1.0, 0.9)))
    parts.append(cyl(loc=base + d * 0.82, r=0.1 * th, depth=0.09, rot=(0, 45, 0), mat=toon(spec["reel"], spec=0.5)))
    # reel
    rc = base + d * 0.55 + Vector((0.12, 0, -0.12))
    parts.append(cyl(loc=rc, r=0.2, depth=0.15, rot=(90, 0, 0), mat=toon(spec["reel"], spec=0.5)))
    parts.append(cyl(loc=rc + Vector((0, 0.1, 0)), r=0.12, depth=0.06, rot=(90, 0, 0), mat=toon(spec.get("glow", "#5a6068"),
                                                                                                  emit=glow)))
    parts.append(tube([rc + Vector((0, 0.13, 0)), rc + Vector((0.12, 0.2, -0.1))], 0.025, mat=toon(spec["grip"])))
    # guides
    for i, t in enumerate([1.3, 1.85, 2.35, 2.75]):
        g = torus(loc=base + d * t + Vector((0.06, 0, -0.06)), R=0.06 - i * 0.008, r=0.012, rot=(0, 45, 0),
                  mat=toon("#d8dde2", spec=0.5), seg=16, mseg=6)
        parts.append(g)
    if spec.get("wraps"):
        for t in (1.25, 1.8, 2.3):
            parts.append(cyl(loc=base + d * t, r=0.058 * th * (1 - t / 4.2), depth=0.05, rot=(0, 45, 0),
                             mat=toon(spec["wraps"], emit=glow)))
    # line + bobber
    hang = tip + Vector((0.0, 0, -1.35))
    if strip:
        hang = tip + d * 0.25
    else:
        parts.append(tube([tip, tip + Vector((0.05, 0, -0.7)), hang], 0.008, mat=toon("#f2f2f2", flat_glow=True)))
        parts.append(sphere(loc=hang, scale=0.12, mat=toon("#ff4b3e")))
        parts.append(sphere(loc=hang + Vector((0, 0, 0.08)), scale=(0.12, 0.12, 0.06), mat=toon("#ffffff")))
    if spec.get("stones"):
        for i, c in enumerate(["#3fa9ff", "#ff3b3b", "#a64dff", "#ffd23f", "#33d17a", "#ff8a1f"]):
            parts.append(ico(loc=base + d * (0.9 + i * 0.32) + Vector((0, 0.06, 0)), scale=0.07, mat=toon(c, emit=0.5, spec=0.5)))
    if spec.get("rings"):
        for t in (1.4, 2.2):
            parts.append(torus(loc=base + d * t, R=0.22, r=0.02, rot=(0, 45, 0), mat=toon(spec["glow"], emit=0.8)))
    if spec.get("wings"):
        for side in (1, -1):
            w = extrude_poly([(0, 0), (-0.45, 0.35), (-0.25, 0.1), (-0.5, 0.05), (-0.2, -0.05)], 0.03,
                             mat=toon("#ffffff"))
            w.location = base + d * 0.4 + Vector((0, side * 0.05, 0))
            w.rotation_euler = (math.radians(90 * side), math.radians(-45), 0)
            parts.append(w)
    if spec.get("meteor"):
        parts.append(ico(loc=base + d * 0.05, scale=0.24, sub=1, mat=toon("#6b5546")))
        for _ in range(3):
            parts.append(ico(loc=base + d * 0.05 + Vector((random.uniform(-.15, .15), 0.12, random.uniform(-.15, .15))),
                             scale=0.06, mat=toon("#ff8a3d", emit=0.9)))
    if spec.get("sparkle"):
        for t in (1.0, 1.7, 2.4):
            parts.append(ico(loc=base + d * t + Vector((0.12, 0.05, 0.1)), scale=0.04, mat=toon("#ffffff", flat_glow=True)))
    if spec.get("segments"):
        for t in (1.1, 1.5, 1.9, 2.3, 2.6):
            parts.append(torus(loc=base + d * t, R=0.06, r=0.02, rot=(0, 45, 0), mat=toon(spec["glow"], emit=0.7), seg=16,
                               mseg=6))
    if spec.get("magnet"):
        mag = torus(loc=hang + Vector((0, 0, -0.05)), R=0.2, r=0.07, rot=(90, 0, 0), mat=toon("#e0322b"))
        deform(mag, lambda co: Vector((co.x, co.y, co.z)) if co.z < 0.05 else Vector((co.x, co.y, 0.05)))
        parts.append(mag)
        for side in (1, -1):
            parts.append(cube(loc=hang + Vector((side * 0.2, 0, 0.05)), scale=(0.15, 0.15, 0.12), mat=toon("#d0d6e0", spec=0.5)))
    if spec.get("pearl"):
        parts.append(sphere(loc=base + d * 0.05, scale=0.13, mat=toon("#f4fbff", spec=0.6)))
    if spec.get("heart"):
        h = extrude_poly(_heart_pts(0.22), 0.1, mat=toon("#ff4f9a", emit=0.25))
        h.location = base + d * 0.02
        h.rotation_euler = (math.radians(90), 0, 0)
        parts.append(h)
    if spec.get("flames"):
        parts += _flames(tuple(base + d * 1.6), 0.35)
    if strip:
        return parts, base, tip
    return parts


def _heart_pts(s):
    pts = []
    for i in range(24):
        t = i / 24 * math.tau
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 16 * s, y / 16 * s))
    return pts


def star_pts(r1, r2, n=5):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.pi / 2 + i * math.pi / n
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts

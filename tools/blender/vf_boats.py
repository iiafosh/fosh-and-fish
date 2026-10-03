"""17 Virtual Fisher boats. Bow faces +X, waterline at z=0.

build_boat(name) -> (parts, deck_anchor) where deck_anchor is where the
fisherman's feet go.
"""
import math

import bmesh
import bpy
from mathutils import Vector

from vf_kit import cone, cube, cyl, deform, extrude_poly, hexc, ico, mix, sphere, toon, torus, tube, vcolor

BOAT_ORDER = ["Rowboat", "Fishing Boat", "Speedboat", "Pontoon", "Sailboat", "Yacht", "Luxury Yacht",
              "Cruise Ship", "Gold Boat", "Sky Cruiser", "Satellite", "Space Shuttle", "Cruiser",
              "Alien Raft", "Alien Submarine", "Dark Explorer", "Abyssal Surveyor"]

FISHER_SCALE = {"Yacht": 1.15, "Luxury Yacht": 1.3, "Cruise Ship": 1.7, "Gold Boat": 1.15, "Sky Cruiser": 1.25,
                "Space Shuttle": 1.3, "Cruiser": 1.4, "Alien Submarine": 1.15, "Dark Explorer": 1.25,
                "Abyssal Surveyor": 1.3}


def hull(L, W, H, top, bottom, stripe=None, bow=0.92, sheer=0.3, keel=1.6, rise=0.45, metal=False, glow_stripe=0.0):
    """Subdivided box shaped into a boat hull. Spans z in [-0.35H, 0.65H]."""
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.active_object
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=18, use_grid_fill=True)
    bm.to_mesh(me)
    bm.free()

    def shape(co):
        t = co.x + 0.5            # 0 stern .. 1 bow
        zz = co.z + 0.5           # 0 keel .. 1 gunwale
        w = 1.0 - bow * max(0.0, (t - 0.5) / 0.5) ** 1.7
        w *= 1.0 - 0.18 * max(0.0, (0.1 - t) / 0.1)
        w *= (0.25 + 0.75 * zz ** (1.0 / keel))
        z = (zz - 0.35) * H
        z += sheer * H * t ** 2.2 * zz
        z += rise * H * max(0.0, (t - 0.55) / 0.45) ** 2 * (1 - zz)
        return Vector((co.x * L, co.y * W * w, z))
    deform(ob, shape)
    tc, bc = hexc(top), hexc(bottom)
    sc = hexc(stripe) if stripe else None

    def paint(co, n):
        zt = co.z
        if zt < 0.02 * H:
            return bc
        if sc and abs(zt - 0.2 * H) < 0.06 * H:
            return sc
        return tc
    vcolor(ob, paint, per_face=True)
    ob.data.materials.append(toon(None, vcol="col", spec=0.5 if metal else 0.1, emit=glow_stripe,
                                  key=("hull", top, bottom, stripe, metal, glow_stripe)))
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def deck_plate(L, W, z, color, inset=0.9, bow=0.92):
    pts = []
    n = 14
    for i in range(n + 1):
        t = i / n
        w = 1.0 - bow * max(0.0, (t - 0.5) / 0.5) ** 1.7
        pts.append(((t - 0.5) * L * inset, w * W * 0.5 * inset))
    pts += [(x, -y) for x, y in reversed(pts)]
    ob = extrude_poly(pts, 0.06, mat=toon(color))
    ob.location = (0, 0, z)
    return ob


def windows(x0, x1, z, n, h=0.18, y=0.0, color="#2b3a55", side_w=0.5, glow=0.0, round_=False):
    out = []
    step = (x1 - x0) / max(1, n - 1) if n > 1 else 0
    for i in range(n):
        x = x0 + step * i
        for s in (1, -1):
            if round_:
                w = cyl(loc=(x, s * side_w, z), r=h * 0.5, depth=0.04, rot=(90, 0, 0), mat=toon(color, emit=glow), verts=16)
            else:
                w = cube(loc=(x, s * side_w, z), scale=(h * 1.2, 0.04, h), mat=toon(color, emit=glow))
            w["no_outline"] = True
            out.append(w)
    return out


def rail(x0, x1, z, side_w, color="#e6e9ee", posts=6, h=0.35):
    out = []
    for s in (1, -1):
        out.append(tube([(x0, s * side_w, z + h), (x1, s * side_w, z + h)], 0.025, mat=toon(color)))
        for i in range(posts):
            x = x0 + (x1 - x0) * i / max(1, posts - 1)
            c = cyl(loc=(x, s * side_w, z + h / 2), r=0.02, depth=h, mat=toon(color))
            c["outline_k"] = 0.5
            out.append(c)
    return out


def cabin(x, z, l, w, h, color, roof=None, win="#2b3a55", nwin=2, glow=0.0, bevel=0.06):
    out = [cube(loc=(x, 0, z + h / 2), scale=(l, w, h), mat=toon(color), bevel=bevel)]
    if roof:
        out.append(cube(loc=(x, 0, z + h + 0.04), scale=(l * 1.08, w * 1.08, 0.08), mat=toon(roof), bevel=0.02))
    out += windows(x - l * 0.3, x + l * 0.3, z + h * 0.6, nwin, h=min(0.22, h * 0.35), side_w=w / 2 + 0.01, color=win, glow=glow)
    front = cube(loc=(x + l / 2 + 0.01, 0, z + h * 0.62), scale=(0.04, w * 0.7, h * 0.32), mat=toon(win, emit=glow))
    front["no_outline"] = True
    out.append(front)
    return out


def flag(x, z, color="#e8553b", h=1.2):
    pole = cyl(loc=(x, 0, z + h / 2), r=0.025, depth=h, mat=toon("#d9dde2"))
    f = extrude_poly([(0, 0), (-0.5, 0.15), (0, 0.3)], 0.02, mat=toon(color))
    f.rotation_euler = (math.radians(90), 0, 0)
    f.location = (x, 0, z + h - 0.3)
    return [pole, f]


# ------------------------------------------------------------------ boats
def rowboat():
    p = [hull(3.2, 1.3, 0.75, "#a8703f", "#7a4a26", "#d8b27a", bow=0.85, sheer=0.35, rise=0.5)]
    for x in (-0.6, 0.35):
        p.append(cube(loc=(x, 0, 0.32), scale=(0.3, 1.1, 0.06), mat=toon("#c48a52")))
    for s in (1, -1):
        p.append(tube([(-0.1, s * 0.55, 0.45), (-0.5, s * 1.35, 0.0), (-0.75, s * 1.6, -0.2)], 0.035, mat=toon("#c48a52")))
        p.append(cube(loc=(-0.78, s * 1.63, -0.22), scale=(0.35, 0.03, 0.14), rot=(0, 25, 0), mat=toon("#c48a52")))
    p.append(cube(loc=(-1.1, 0, 0.38), scale=(0.4, 0.5, 0.3), mat=toon("#4aa3d8"), bevel=0.04))
    return p, (0.25, 0, 0.36)


def fishing_boat():
    p = [hull(4.6, 1.6, 1.0, "#f2f0e8", "#c4382e", "#2f5d8a", sheer=0.3)]
    p.append(deck_plate(4.4, 1.5, 0.62, "#b58d5c"))
    p += cabin(-1.2, 0.65, 1.3, 1.2, 1.0, "#f2f0e8", roof="#2f5d8a", nwin=2)
    p.append(cyl(loc=(-1.2, 0, 2.3), r=0.04, depth=1.4, mat=toon("#d9dde2")))
    p.append(cube(loc=(-1.2, 0, 2.7), scale=(0.6, 0.05, 0.05), mat=toon("#d9dde2")))
    p.append(cyl(loc=(-1.6, 0.3, 1.9), r=0.09, depth=0.5, mat=toon("#3a3f44")))
    p.append(cyl(loc=(-0.2, 0, 1.4), r=0.05, depth=1.5, mat=toon("#e0a82e")))
    p.append(cyl(loc=(-0.65, 0, 1.75), r=0.035, depth=1.1, rot=(0, -60, 0), mat=toon("#e0a82e")))
    p.append(tube([(-1.12, 0, 2.02), (-1.12, 0, 1.4)], 0.01, mat=toon("#d9dde2")))
    p.append(torus(loc=(-1.12, 0, 1.36), R=0.06, r=0.015, rot=(90, 0, 0), mat=toon("#d9dde2")))
    for i in range(4):
        p.append(cube(loc=(-0.1 + i * 0.25, 0.45, 0.78), scale=(0.2, 0.3, 0.25), mat=toon("#5aa0d8" if i % 2 else "#f2c14e"),
                      bevel=0.03))
    return p, (0.85, 0, 0.66)


def speedboat():
    p = [hull(4.2, 1.5, 0.75, "#f4f6f8", "#1f3a6a", "#ff4b3e", bow=0.95, sheer=0.15, rise=0.6)]
    p.append(deck_plate(3.8, 1.35, 0.42, "#2a2f3a"))
    ws = extrude_poly([(0, 0), (0.6, 0), (0, 0.45)], 1.2, mat=toon("#9ad8ff", emit=0.15, alpha=0.75))
    ws.rotation_euler = (math.radians(90), 0, 0)
    ws.location = (0.2, 0, 0.47)
    ws["no_outline"] = True
    p.append(ws)
    p.append(cube(loc=(-0.6, 0, 0.62), scale=(0.7, 1.0, 0.3), mat=toon("#ff4b3e"), bevel=0.08))
    p.append(cube(loc=(-2.2, 0, 0.55), scale=(0.35, 0.4, 0.7), mat=toon("#2a2f3a"), bevel=0.06))
    p.append(cube(loc=(-2.2, 0, 0.95), scale=(0.45, 0.45, 0.25), mat=toon("#e9eef2"), bevel=0.06))
    return p, (-0.9, 0, 0.45)


def pontoon():
    p = []
    for s in (1, -1):
        pt = cyl(loc=(0, s * 0.75, 0.05), r=0.32, depth=4.4, rot=(0, 90, 0), mat=toon("#cfd6dc", spec=0.5))
        p.append(pt)
        p.append(sphere(loc=(2.2, s * 0.75, 0.05), scale=(0.5, 0.32, 0.32), mat=toon("#cfd6dc", spec=0.5)))
    p.append(cube(loc=(0, 0, 0.45), scale=(4.6, 2.1, 0.12), mat=toon("#c9a173"), bevel=0.03))
    p.append(cube(loc=(0, 0, 0.36), scale=(4.6, 2.1, 0.08), mat=toon("#2f5d8a")))
    p += rail(-2.1, 2.1, 0.5, 1.0, posts=7, h=0.45)
    for x in (-1.6, 0.0):
        for s in (1, -1):
            c = cyl(loc=(x, s * 0.9, 1.25), r=0.03, depth=1.5, mat=toon("#d9dde2"))
            p.append(c)
    p.append(cube(loc=(-0.8, 0, 2.0), scale=(1.9, 2.0, 0.06), mat=toon("#1f3a6a"), bevel=0.02))
    p.append(cube(loc=(-1.5, 0, 0.75), scale=(0.9, 1.6, 0.4), mat=toon("#e8553b"), bevel=0.1))
    return p, (1.2, 0, 0.52)


def sailboat():
    p = [hull(4.6, 1.5, 1.0, "#f6f3ea", "#1f3a6a", "#e8553b", sheer=0.3)]
    p.append(deck_plate(4.3, 1.4, 0.62, "#c9a173"))
    p.append(cube(loc=(-1.0, 0, 0.85), scale=(1.1, 0.9, 0.4), mat=toon("#f6f3ea"), bevel=0.08))
    p += windows(-1.3, -0.7, 0.85, 3, h=0.12, side_w=0.46, round_=True)
    p.append(cyl(loc=(-0.3, 0, 3.2), r=0.06, depth=5.2, mat=toon("#d9c49a")))
    p.append(cyl(loc=(-1.25, 0, 1.25), r=0.045, depth=1.9, rot=(0, 90, 0), mat=toon("#d9c49a")))
    main = extrude_poly([(0, 0), (-1.8, 0), (-0.05, 4.4)], 0.03, mat=toon("#fffdf5"))
    main.rotation_euler = (math.radians(90), 0, 0)
    main.location = (-0.33, 0, 1.3)
    jib = extrude_poly([(0, 0), (1.9, 0), (0, 4.0)], 0.03, mat=toon("#ffe6c4"))
    jib.rotation_euler = (math.radians(90), 0, 0)
    jib.location = (-0.22, 0, 0.9)
    p += [main, jib]
    p.append(tube([(-0.3, 0, 5.75), (2.25, 0, 0.75)], 0.012, mat=toon("#d9dde2")))
    p += flag(-0.3, 5.75, "#e8553b", 0.4)
    return p, (1.2, 0, 0.66)


def yacht():
    p = [hull(6.2, 1.9, 1.2, "#f7f8fa", "#1c2b45", "#c9a24a", sheer=0.25, bow=0.95)]
    p.append(deck_plate(5.9, 1.8, 0.78, "#c9a173"))
    p += cabin(-0.6, 0.8, 2.8, 1.5, 0.75, "#f7f8fa", nwin=4)
    p += cabin(-0.9, 1.55, 1.7, 1.3, 0.55, "#f7f8fa", roof="#1c2b45", nwin=2)
    ws = cube(loc=(0.9, 0, 1.15), scale=(0.08, 1.4, 0.4), rot=(0, -35, 0), mat=toon("#2b3a55"))
    p.append(ws)
    p += rail(1.2, 2.7, 0.8, 0.75, posts=5, h=0.3)
    p.append(cyl(loc=(-0.9, 0, 2.5), r=0.04, depth=0.8, mat=toon("#d9dde2")))
    p.append(torus(loc=(-0.9, 0, 2.85), R=0.14, r=0.03, rot=(90, 0, 0), mat=toon("#d9dde2")))
    return p, (1.75, 0, 0.82)


def luxury_yacht():
    p = [hull(7.4, 2.2, 1.45, "#fbfbfd", "#16203a", "#d4af37", sheer=0.22, bow=0.96, metal=True)]
    p.append(deck_plate(7.0, 2.1, 0.95, "#c9a173"))
    p += cabin(-0.7, 0.95, 3.8, 1.9, 0.8, "#fbfbfd", nwin=5, win="#1d2b4a")
    p += cabin(-1.0, 1.75, 2.7, 1.7, 0.7, "#fbfbfd", nwin=3, win="#1d2b4a")
    p += cabin(-1.3, 2.45, 1.6, 1.5, 0.55, "#fbfbfd", roof="#d4af37", nwin=2, win="#1d2b4a")
    p.append(cube(loc=(-1.3, 0, 3.25), scale=(0.15, 0.15, 0.5), mat=toon("#d4af37", spec=0.6)))
    p.append(sphere(loc=(-1.3, 0, 3.6), scale=0.22, mat=toon("#e8eef5", spec=0.4)))
    p += rail(1.3, 3.2, 0.95, 0.85, posts=6, h=0.32, color="#d4af37")
    pool = cube(loc=(-2.6, 0, 1.0), scale=(1.0, 1.2, 0.1), mat=toon("#4fd1ff", emit=0.2))
    p.append(pool)
    return p, (2.2, 0, 1.0)


def cruise_ship():
    p = [hull(9.5, 2.6, 2.1, "#fbfbfd", "#1b3a8a", "#c0392b", sheer=0.12, bow=0.9, rise=0.35)]
    p.append(deck_plate(9.0, 2.5, 1.4, "#c9a173"))
    for i, (l, z) in enumerate([(7.2, 1.4), (6.4, 2.05), (5.4, 2.7)]):
        p.append(cube(loc=(-0.6 - i * 0.2, 0, z + 0.32), scale=(l, 2.2 - i * 0.1, 0.62), mat=toon("#fbfbfd"), bevel=0.05))
        p += windows(-3.6 + i * 0.4, 2.4 - i * 0.6, z + 0.36, 14 - i * 2, h=0.16, side_w=1.11 - i * 0.05,
                     color="#1d2b4a" if i else "#4fb3ff", glow=0.2 if i == 0 else 0.0)
    p += windows(-3.8, 3.4, 0.75, 16, h=0.13, side_w=1.15, round_=True, color="#1d2b4a")
    for x in (-2.4, -0.8):
        p.append(cyl(loc=(x, 0, 3.85), r=0.42, depth=1.1, mat=toon("#c0392b"), scale=(1.25, 0.85, 1)))
        p.append(cyl(loc=(x, 0, 4.42), r=0.43, depth=0.18, mat=toon("#1c1c22"), scale=(1.25, 0.85, 1)))
    p.append(cube(loc=(1.6, 0, 3.3), scale=(1.4, 1.9, 0.35), mat=toon("#fbfbfd"), bevel=0.05))
    p += windows(1.1, 2.2, 3.32, 4, h=0.14, side_w=0.96, color="#1d2b4a")
    p += flag(3.6, 1.45, "#1b3a8a", 0.8)
    return p, (3.0, 0, 1.45)


def gold_boat():
    p = [hull(5.6, 1.8, 1.2, "#f5c542", "#a8741a", "#c0392b", sheer=0.45, metal=True, rise=0.55)]
    p.append(deck_plate(5.3, 1.7, 0.85, "#7a2b2b"))
    p += cabin(-1.0, 0.88, 1.8, 1.3, 0.75, "#f5c542", roof="#c0392b", nwin=2, win="#5a1a1a")
    crown = cyl(loc=(-1.0, 0, 1.95), r=0.35, depth=0.3, mat=toon("#ffd75e", spec=0.7), verts=10)
    p.append(crown)
    for i in range(5):
        a = i / 5 * math.tau
        p.append(cone(loc=(-1.0 + math.cos(a) * 0.32, math.sin(a) * 0.32, 2.2), r1=0.08, r2=0.0, depth=0.25,
                      mat=toon("#ffd75e", spec=0.7), verts=6, smooth=False))
    p.append(ico(loc=(-1.0, 0.36, 1.95), scale=0.09, mat=toon("#e0322b", emit=0.4, spec=0.6)))
    p.append(cone(loc=(3.0, 0, 1.45), r1=0.25, r2=0.0, depth=0.9, rot=(0, 70, 0), mat=toon("#ffd75e", spec=0.7)))
    p += rail(0.7, 2.4, 0.88, 0.7, posts=5, h=0.3, color="#ffd75e")
    return p, (1.5, 0, 0.9)


def sky_cruiser():
    p = [hull(5.4, 1.6, 1.0, "#e9f3ff", "#7a8ca8", "#4fb3ff", sheer=0.3, bow=0.95)]
    p.append(deck_plate(5.1, 1.5, 0.65, "#c9a173"))
    env = sphere(loc=(-0.6, 0, 3.6), scale=(2.6, 1.1, 1.0), mat=toon("#ffffff"))
    p.append(env)
    for s in (1, -1):
        p.append(tube([(-1.8, s * 0.6, 0.7), (-1.6, s * 0.8, 2.7)], 0.03, mat=toon("#7a5a3a")))
        p.append(tube([(0.8, s * 0.6, 0.7), (0.6, s * 0.8, 2.7)], 0.03, mat=toon("#7a5a3a")))
        wing = extrude_poly([(0, 0), (-1.4, 0), (-1.0, 1.3), (-0.2, 1.2)], 0.06, mat=toon("#4fb3ff"))
        wing.location = (-0.3, s * 0.75, 0.5)
        wing.rotation_euler = (math.radians(-90 * s + (10 * s)), 0, 0)
        p.append(wing)
    for x in (-3.2, 2.0):
        p.append(cone(loc=(x - 0.2 if x < 0 else x, 0, 3.6), r1=0.4, r2=0.1, depth=0.6, rot=(0, -90 if x < 0 else 90, 0),
                      mat=toon("#4fb3ff")))
    prop = cube(loc=(-3.4, 0, 3.6), scale=(0.06, 1.4, 0.18), mat=toon("#7a5a3a"))
    p.append(prop)
    p.append(cube(loc=(-0.6, 0, 2.55), scale=(1.4, 0.7, 0.4), mat=toon("#4fb3ff"), bevel=0.06))
    p += windows(-1.1, -0.1, 2.58, 3, h=0.14, side_w=0.36, round_=True)
    return p, (1.3, 0, 0.68)


def satellite():
    p = [cube(loc=(0, 0, 0.6), scale=(1.4, 1.2, 1.2), mat=toon("#d6a53a", spec=0.6), bevel=0.06)]
    p.append(cube(loc=(0, 0, 1.25), scale=(1.5, 1.3, 0.1), mat=toon("#cfd6dc", spec=0.4)))
    for s in (1, -1):
        p.append(cyl(loc=(0, s * 1.0, 0.6), r=0.05, depth=0.8, rot=(90, 0, 0), mat=toon("#cfd6dc")))
        panel = cube(loc=(0, s * 2.2, 0.6), scale=(1.1, 1.7, 0.05), mat=toon("#2f4fd1", spec=0.4))
        p.append(panel)
        for k in range(3):
            g = cube(loc=(0, s * (1.6 + k * 0.6), 0.63), scale=(1.12, 0.03, 0.02), mat=toon("#cfd6dc"))
            g["no_outline"] = True
            p.append(g)
    dish = sphere(loc=(-0.95, 0, 1.0), scale=(0.15, 0.55, 0.55), mat=toon("#f2f4f6"))
    p.append(dish)
    p.append(cyl(loc=(-1.25, 0, 1.0), r=0.03, depth=0.5, rot=(0, 90, 0), mat=toon("#cfd6dc")))
    p.append(sphere(loc=(-1.5, 0, 1.0), scale=0.06, mat=toon("#ff4b3e", emit=0.8)))
    p.append(cyl(loc=(0.4, 0.3, 1.6), r=0.02, depth=0.7, mat=toon("#cfd6dc")))
    p.append(sphere(loc=(0.4, 0.3, 1.98), scale=0.06, mat=toon("#5ff2ff", emit=0.8)))
    return p, (0.15, 0, 1.3)


def space_shuttle():
    body = cyl(loc=(0, 0, 0.6), r=0.75, depth=5.0, rot=(0, 90, 0), mat=toon("#f4f6f8"), verts=32)
    nose = sphere(loc=(2.5, 0, 0.6), scale=(1.2, 0.75, 0.75), mat=toon("#f4f6f8"))
    tipc = sphere(loc=(3.35, 0, 0.55), scale=(0.45, 0.38, 0.38), mat=toon("#22252c"))
    belly = cube(loc=(0.2, 0, 0.0), scale=(5.4, 1.3, 0.25), mat=toon("#22252c"), bevel=0.1)
    p = [body, nose, tipc, belly]
    wing = extrude_poly([(-2.4, 0), (1.2, 0), (-1.8, 2.4), (-2.6, 2.4)], 0.12, mat=toon("#f4f6f8"))
    wing2 = extrude_poly([(-2.4, 0), (1.2, 0), (-1.8, -2.4), (-2.6, -2.4)], 0.12, mat=toon("#f4f6f8"))
    for w in (wing, wing2):
        w.location = (0, 0, 0.2)
        p.append(w)
    tail = extrude_poly([(-2.6, 0), (-1.2, 0), (-2.4, 2.0), (-2.9, 2.0)], 0.1, mat=toon("#f4f6f8"))
    tail.rotation_euler = (math.radians(90), 0, 0)
    tail.location = (0, 0, 1.2)
    p.append(tail)
    for s in (0.35, -0.35):
        p.append(cone(loc=(-2.75, s, 0.75), r1=0.3, r2=0.18, depth=0.5, rot=(0, 90, 0), mat=toon("#3a3f44")))
        p.append(cone(loc=(-3.05, s, 0.75), r1=0.22, r2=0.0, depth=0.4, rot=(0, -90, 0), mat=toon("#5ff2ff", emit=0.9)))
    p += windows(2.3, 2.7, 1.05, 2, h=0.16, side_w=0.55, color="#22252c")
    p.append(cube(loc=(-0.4, 0, 1.36), scale=(3.0, 1.2, 0.05), mat=toon("#e3e6ea")))
    return p, (0.4, 0, 1.38)


def cruiser():
    p = [hull(6.4, 2.0, 1.2, "#7c8796", "#3a414c", "#5ff2ff", bow=0.98, sheer=0.05, rise=0.3, metal=True, glow_stripe=0.3)]
    p.append(deck_plate(6.0, 1.9, 0.78, "#5c6672", bow=0.98))
    p.append(cube(loc=(-1.0, 0, 1.25), scale=(2.4, 1.4, 0.9), mat=toon("#8a95a5", spec=0.4), bevel=0.04))
    p.append(cube(loc=(-1.3, 0, 1.95), scale=(1.2, 1.0, 0.55), mat=toon("#8a95a5", spec=0.4), bevel=0.04))
    p += windows(-1.7, -0.9, 2.0, 3, h=0.12, side_w=0.51, color="#5ff2ff", glow=0.8)
    for z, s in [(1.1, 0.5), (1.1, -0.5)]:
        p.append(cyl(loc=(-3.25, s, z), r=0.32, depth=0.6, rot=(0, 90, 0), mat=toon("#3a414c")))
        p.append(cone(loc=(-3.75, s, z), r1=0.26, r2=0.0, depth=0.6, rot=(0, -90, 0), mat=toon("#5ff2ff", emit=0.9)))
    for x in (0.9, 1.7):
        p.append(cyl(loc=(x, 0, 1.0), r=0.3, depth=0.25, mat=toon("#5c6672")))
        p.append(cyl(loc=(x + 0.4, 0, 1.12), r=0.06, depth=0.8, rot=(0, 90, 0), mat=toon("#3a414c")))
    p.append(cyl(loc=(-1.3, 0, 2.7), r=0.03, depth=0.9, mat=toon("#cfd6dc")))
    p.append(sphere(loc=(-1.3, 0, 3.15), scale=0.07, mat=toon("#ff4b3e", emit=0.8)))
    return p, (2.3, 0, 0.82)


def alien_raft():
    disc = cyl(loc=(0, 0, 0.1), r=2.2, depth=0.4, mat=toon("#5a3a8a"), verts=40, scale=(1.25, 0.8, 1))
    ring = torus(loc=(0, 0, 0.1), R=2.25, r=0.12, mat=toon("#7dff9a", emit=0.8), scale=(1.25, 0.8, 1), seg=48)
    top = cyl(loc=(0, 0, 0.32), r=2.0, depth=0.06, mat=toon("#3d2a66"), verts=40, scale=(1.25, 0.8, 1))
    p = [disc, ring, top]
    for x, y, h, c in [(-1.6, 0.4, 1.3, "#7dff9a"), (-1.2, -0.6, 0.9, "#c77dff"), (-2.0, -0.2, 0.7, "#5ff2ff")]:
        p.append(cone(loc=(x, y, 0.35 + h / 2), r1=0.22, r2=0.0, depth=h, mat=toon(c, emit=0.5, spec=0.4), verts=5, smooth=False))
    stem = tube([(1.4, 0.3, 0.35), (1.5, 0.3, 1.1), (1.3, 0.3, 1.6)], 0.07, mat=toon("#c77dff"))
    cap = sphere(loc=(1.3, 0.3, 1.7), scale=(0.45, 0.45, 0.22), mat=toon("#7dff9a", emit=0.3))
    p += [stem, cap]
    for i in range(6):
        a = i / 6 * math.tau
        p.append(sphere(loc=(math.cos(a) * 2.6, math.sin(a) * 1.65, 0.1), scale=0.12, mat=toon("#b8ff6a", emit=0.9)))
    return p, (0.2, 0, 0.36)


def alien_submarine():
    body = sphere(loc=(0, 0, 0.5), scale=(3.0, 1.0, 0.95), mat=toon("#6b3fa0"), seg=40, rings=20)
    p = [body]
    p.append(cube(loc=(-0.3, 0, 1.55), scale=(1.4, 0.7, 0.7), mat=toon("#7d4fc0"), bevel=0.25))
    p.append(sphere(loc=(0.35, 0, 1.6), scale=(0.35, 0.32, 0.3), mat=toon("#7dff9a", emit=0.6, alpha=0.9)))
    p += windows(-1.6, 1.6, 0.6, 5, h=0.26, side_w=0.88, round_=True, color="#7dff9a", glow=0.9)
    for s in (1, -1):
        fin = extrude_poly([(0, 0), (-1.0, 0), (-1.3, 0.9), (-0.4, 0.5)], 0.08, mat=toon("#c77dff"))
        fin.rotation_euler = (math.radians(90 * s), 0, 0)
        fin.location = (-2.0, s * 0.3, 0.6)
        p.append(fin)
    for i in range(5):
        y = -0.5 + i * 0.25
        p.append(tube([(-2.6, y, 0.3), (-3.3, y * 1.3, 0.1 - i * 0.05), (-3.9, y * 1.5, 0.35)], 0.07, mat=toon("#c77dff"),
                      taper=(1.0, 0.3)))
    p.append(cyl(loc=(2.6, 0, 0.5), r=0.18, depth=0.3, rot=(0, 90, 0), mat=toon("#7dff9a", emit=0.8)))
    return p, (-0.9, 0, 1.92)


def dark_explorer():
    p = [hull(6.0, 1.9, 1.3, "#1d1726", "#0d0a12", "#b34dff", bow=0.97, sheer=0.35, rise=0.55, glow_stripe=0.6)]
    p.append(deck_plate(5.7, 1.8, 0.85, "#2a2236", bow=0.97))
    p.append(extrude_poly([(-1.3, 0), (0.6, 0), (0.0, 1.1), (-1.1, 1.0)], 1.3, mat=toon("#2a2236")))
    p[-1].rotation_euler = (math.radians(90), 0, 0)
    p[-1].location = (-0.8, 0, 0.88)
    p += windows(-1.6, -0.6, 1.45, 3, h=0.16, side_w=0.66, color="#c77dff", glow=0.9)
    for x in (1.2, 1.8, 2.4):
        p.append(cone(loc=(x, 0, 1.15 + (x - 1.2) * 0.15), r1=0.12, r2=0.0, depth=0.5, mat=toon("#3a2f4a"), verts=4,
                      smooth=False))
    p.append(cyl(loc=(2.75, 0, 1.55), r=0.03, depth=0.9, rot=(0, -30, 0), mat=toon("#3a2f4a")))
    p.append(sphere(loc=(3.0, 0, 1.95), scale=0.16, mat=toon("#c77dff", emit=0.9)))
    return p, (1.4, 0, 0.88)


def abyssal_surveyor():
    p = [hull(6.6, 2.1, 1.3, "#163a46", "#0b1d24", "#ffd23f", sheer=0.15, bow=0.9, glow_stripe=0.3)]
    p.append(deck_plate(6.2, 2.0, 0.85, "#2c4a54"))
    p += cabin(-1.6, 0.88, 2.0, 1.6, 0.9, "#1f4d5a", roof="#ffd23f", nwin=3, win="#5ff2ff", glow=0.6)
    gond = sphere(loc=(-0.2, 0, -0.8), scale=0.75, mat=toon("#e0a82e", spec=0.4))
    p.append(gond)
    p += windows(-0.3, -0.3, -0.75, 1, h=0.35, side_w=0.72, round_=True, color="#5ff2ff", glow=0.9)
    p.append(cyl(loc=(-0.2, 0, -0.05), r=0.18, depth=0.6, mat=toon("#3a414c")))
    for x in (2.2, 1.4):
        p.append(cyl(loc=(x, 0.7, 1.05), r=0.12, depth=0.3, rot=(0, 70, 0), mat=toon("#3a414c")))
        p.append(cone(loc=(x + 0.25, 0.7, 1.1), r1=0.13, r2=0.22, depth=0.18, rot=(0, -70, 0),
                      mat=toon("#fff2a0", emit=1.0)))
    p.append(tube([(-0.2, 0, 0.9), (0.4, 0, 2.6), (1.3, 0, 2.3)], 0.06, mat=toon("#ffd23f")))
    p.append(tube([(1.3, 0, 2.3), (1.3, 0, 1.2)], 0.012, mat=toon("#d9dde2")))
    return p, (2.2, 0, 0.88)


BUILDERS = {
    "Rowboat": rowboat, "Fishing Boat": fishing_boat, "Speedboat": speedboat, "Pontoon": pontoon,
    "Sailboat": sailboat, "Yacht": yacht, "Luxury Yacht": luxury_yacht, "Cruise Ship": cruise_ship,
    "Gold Boat": gold_boat, "Sky Cruiser": sky_cruiser, "Satellite": satellite, "Space Shuttle": space_shuttle,
    "Cruiser": cruiser, "Alien Raft": alien_raft, "Alien Submarine": alien_submarine,
    "Dark Explorer": dark_explorer, "Abyssal Surveyor": abyssal_surveyor,
}


def build_boat(name):
    parts, deck = BUILDERS[name]()
    return parts, deck

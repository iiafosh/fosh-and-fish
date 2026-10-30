"""High-angle (top-down) biome scenes, boat sprites and swimming-fish sprites.

One analytic height function h(x, y) drives BOTH the terrain mesh (Python)
and the water shader (node graph), so depth colour, transparency and
shoreline foam line up exactly with the coast.
"""
import math
import os
import random

import bmesh
import bpy
from mathutils import Vector

import vf_kit as K
import vf_models as M
import vf_boats as B
import vf_shop as SH
import vf_vendor as V
from vf_biomes import palm, pine, mushroom, crystal
from vf_kit import cone, cube, cyl, hexc, ico, sphere, toon, torus, tube

W = 1920
CAM_ROT = (55, 0, 0)        # a three-quarter view: buildings show their walls, boats their hulls, trees their trunks
CAM_LOC = (0, -28.93, 20.53)
LENS = 34
BOAT_SPOT = (-4.0, -3.0)
BOBBER_SPOT = (4.0, 0.5)
X0, X1, Y0, Y1 = -46, 46, -16, 52
EXTRA_AVOID = []      # (x, y, r) kept clear of scattered props (merchant stall)

BIOMES = {
    "River":    dict(shore=8, slope=0.42, deep=3.0, max_a=0.66, water=("#a4f0dc", "#1f94ac"),
                     seabed=("#e4d6a2", "#3f908c"), sand="#efdcab", land="#8ccb6c", land2="#68ae58",
                     ambient="#8e98a6", sun=(42, 0, 28)),
    "Volcanic": dict(shore=9, slope=0.36, deep=4.0, max_a=0.94, water=("#ffd86a", "#d4380d"),
                     seabed=("#5a3020", "#3a1208"), sand="#3a3236", land="#4a3c3c", land2="#2e2626",
                     ambient="#9a7a74", sun=(45, 0, 35), glow="#ff7a1f", foam="#ffe9a0"),
    "Ocean":    dict(shore=9, slope=0.26, deep=5.5, max_a=0.62, water=("#9ff3e6", "#2a9ec4"),
                     seabed=("#f0e2bc", "#5a9ab0"), sand="#f2e4c0", land="#8ccc6c", land2="#6ab25a",
                     ambient="#9aa6b0", sun=(42, 0, 28)),
    "Sky":      dict(shore=9, slope=0.3, deep=10.0, max_a=0.6, water=("#ffe0f2", "#a89cff"),
                     seabed=("#ffffff", "#c8c0ff"), sand="#f4f0ff", land="#9ad87a", land2="#7cc36b",
                     ambient="#b0a8c0", sun=(40, 0, 20)),
    "Space":    dict(shore=9, slope=0.32, deep=6.0, max_a=0.8, water=("#b49cff", "#1a0f4a"),
                     seabed=("#4a3a7a", "#140c2a"), sand="#5a4a6e", land="#6a5a7a", land2="#4a3e5a",
                     ambient="#7a70a0", sun=(45, 0, 40), glow="#c9b3ff", foam="#e2d8ff"),
    "Alien":    dict(shore=9, slope=0.34, deep=5.0, max_a=0.78, water=("#9affd8", "#0f5a4a"),
                     seabed=("#2f5a52", "#122a2a"), sand="#6a5a8a", land="#5a3a8a", land2="#46307a",
                     ambient="#7a9a90", sun=(45, 0, 200), glow="#7dffcf", foam="#d4ffef"),
    "Abyss":    dict(shore=10, slope=0.3, deep=8.0, max_a=0.9, water=("#3a7aaa", "#020818"),
                     seabed=("#1a2a44", "#05080f"), sand="#2a3048", land="#1f2638", land2="#161b2a",
                     ambient="#5a6680", sun=(55, 0, 90), glow="#5ff2ff", foam="#a8ecff"),
}


# --------------------------------------------------------- height function
class Num:
    S = staticmethod(math.sin)
    MAX = staticmethod(max)


class E:
    """Node-graph expression value with arithmetic operators."""
    nt = None

    def __init__(self, sock):
        self.sock = sock

    @classmethod
    def _op(cls, op, a, b=None):
        n = cls.nt.nodes.new("ShaderNodeMath")
        n.operation = op
        for i, v in enumerate([a, b] if b is not None else [a]):
            if isinstance(v, E):
                cls.nt.links.new(v.sock, n.inputs[i])
            else:
                n.inputs[i].default_value = float(v)
        return E(n.outputs[0])

    def __add__(self, o): return E._op("ADD", self, o)
    __radd__ = __add__
    def __mul__(self, o): return E._op("MULTIPLY", self, o)
    __rmul__ = __mul__
    def __sub__(self, o): return E._op("SUBTRACT", self, o)
    def __rsub__(self, o): return E._op("SUBTRACT", o, self)
    def __neg__(self): return E._op("MULTIPLY", self, -1.0)


class Nodes:
    @staticmethod
    def S(v): return E._op("SINE", v)

    @staticmethod
    def MAX(a, b): return E._op("MAXIMUM", a, b)


def height(x, y, P, o):
    ys = P["shore"] + 3.5 * o.S(0.11 * x + 1.0) + 2.2 * o.S(0.27 * x + 2.3)
    raw = (y - ys) * P["slope"] + 0.45 * o.S(0.37 * x + 0.2) * o.S(0.31 * y + 1.1) + 0.3 * o.S(0.9 * x + 0.45 * y)
    land = o.MAX(raw, 0.0)
    h = raw - 0.55 * land
    return o.MAX(h, -P["deep"])


def H(x, y, P):
    return height(x, y, P, Num)


# ---------------------------------------------------------------- terrain
def terrain(P, rnd):
    nx, ny = 230, 170
    verts, faces = [], []
    for j in range(ny):
        for i in range(nx):
            x = X0 + (X1 - X0) * i / (nx - 1)
            y = Y0 + (Y1 - Y0) * j / (ny - 1)
            verts.append((x, y, H(x, y, P)))
    for j in range(ny - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + 1, a + nx + 1, a + nx))
    me = bpy.data.meshes.new("terrain")
    me.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new("terrain", me)
    bpy.context.collection.objects.link(ob)
    sb0, sb1 = hexc(P["seabed"][0]), hexc(P["seabed"][1])
    sand, land, land2 = hexc(P["sand"]), hexc(P["land"]), hexc(P["land2"])

    def paint(co, n):
        z = co.z
        speck = 1.0 + 0.05 * math.sin(co.x * 3.1 + math.sin(co.y * 2.3) * 2) * math.sin(co.y * 2.7)
        if z < -0.5:
            t = min(1.0, (-z - 0.5) / (P["deep"] - 0.5))
            c = K.mix(sb0, sb1, t ** 0.8)
        elif z < 0.35:
            c = K.mix(sand, sb0, max(0.0, min(1.0, -z / 0.5)))
        elif z < 0.9:
            c = K.mix(sand, land, (z - 0.35) / 0.55)
        else:
            c = K.mix(land, land2, 0.5 + 0.5 * math.sin(co.x * 0.4) * math.sin(co.y * 0.5))
        return tuple(max(0.0, min(1.0, v * speck)) if i < 3 else v for i, v in enumerate(c))
    K.vcolor(ob, paint)
    ob.data.materials.append(toon(None, vcol="col", rim=0.0, key=("terrain", P["sand"])))
    for p in ob.data.polygons:
        p.use_smooth = True
    ob["no_outline"] = True
    return ob


def water(P, mask=False):
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    ob = bpy.context.active_object
    ob.scale = (X1 - X0, Y1 - Y0, 1)
    ob.location = ((X0 + X1) / 2, (Y0 + Y1) / 2, 0.0)
    ob["no_outline"] = True
    m = bpy.data.materials.new("water")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    E.nt = nt
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    x, y = E(sep.outputs["X"]), E(sep.outputs["Y"])
    d = -height(x, y, P, Nodes)                       # water depth (>0 in water)

    def clamp01(v, lo, hi):
        n = nt.nodes.new("ShaderNodeMapRange")
        n.inputs["From Min"].default_value = lo
        n.inputs["From Max"].default_value = hi
        nt.links.new(v.sock, n.inputs["Value"])
        return n.outputs[0]

    if mask:
        # R = water, G = depth 0..1 (0 = shore). Alpha 0 on land.
        comb = nt.nodes.new("ShaderNodeCombineColor")
        comb.inputs[0].default_value = 1.0
        nt.links.new(clamp01(d, 0.0, P["deep"]), comb.inputs[1])
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(comb.outputs[0], em.inputs[0])
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mx = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(clamp01(d, 0.0, 0.05), mx.inputs[0])
        nt.links.new(tr.outputs[0], mx.inputs[1])
        nt.links.new(em.outputs[0], mx.inputs[2])
        nt.links.new(mx.outputs[0], out.inputs[0])
        m.surface_render_method = "BLENDED"
        ob.data.materials.append(m)
        return ob

    ramp = nt.nodes.new("ShaderNodeValToRGB")
    K._ramp_stops(ramp.color_ramp, [(0.0, P["water"][0]), (1.0, P["water"][1])])
    ramp.color_ramp.interpolation = "EASE"
    nt.links.new(clamp01(d, 0.2, P["deep"] * 0.9), ramp.inputs[0])
    # foam: solid at the waterline + a broken second band
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 0.9
    noise.inputs["Detail"].default_value = 4.0
    nt.links.new(geo.outputs["Position"], noise.inputs["Vector"])
    nz = E(noise.outputs["Fac"])
    band1 = clamp01(d - 0.6 * (nz - 0.5), 0.22, 0.12)          # 1 at shore -> 0
    band2v = d - 0.55 - 0.9 * (nz - 0.5)
    b2 = nt.nodes.new("ShaderNodeMapRange")
    b2.interpolation_type = "STEPPED"
    b2.inputs["Steps"].default_value = 1.0
    b2.inputs["From Min"].default_value = -0.09
    b2.inputs["From Max"].default_value = 0.09
    absn = E._op("ABSOLUTE", band2v)
    inv = 0.09 - absn
    nt.links.new(inv.sock, b2.inputs["Value"])
    b2.inputs["From Min"].default_value = 0.0
    b2.inputs["From Max"].default_value = 0.04
    foam = E._op("MAXIMUM", E(band1), E(b2.outputs[0]) * 0.85)
    mixc = nt.nodes.new("ShaderNodeMix")
    mixc.data_type = "RGBA"
    nt.links.new(foam.sock, mixc.inputs[0])
    nt.links.new(ramp.outputs[0], mixc.inputs[6])
    mixc.inputs[7].default_value = K.hexc(P.get("foam", "#ffffff"))
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(mixc.outputs[2], em.inputs[0])
    alpha = nt.nodes.new("ShaderNodeMapRange")
    alpha.inputs["From Min"].default_value = 0.0
    alpha.inputs["From Max"].default_value = P["deep"] * 0.75
    alpha.inputs["To Min"].default_value = 0.06
    alpha.inputs["To Max"].default_value = P["max_a"]
    nt.links.new(d.sock, alpha.inputs["Value"])
    a_total = E._op("MAXIMUM", E(alpha.outputs[0]), foam)
    land_cut = clamp01(d, -0.02, 0.02)
    a_final = a_total * E(land_cut)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(a_final.sock, mx.inputs[0])
    nt.links.new(tr.outputs[0], mx.inputs[1])
    nt.links.new(em.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs[0])
    m.surface_render_method = "BLENDED"
    ob.data.materials.append(m)
    return ob


# ------------------------------------------------------------------ props
def coral(loc, s, cols, rnd):
    base = ico(loc=(loc[0], loc[1], loc[2] - 0.02 * s), scale=(1.15 * s, 0.75 * s, 0.25 * s), sub=2, mat=toon("#b8b09a"), smooth=True)
    base["no_outline"] = True
    out = [base]
    for i in range(9):
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(0.1, 1.0) * s
        p = (loc[0] + math.cos(a) * r, loc[1] + math.sin(a) * r * 0.7, loc[2] + 0.3 * s)
        c = rnd.choice(cols)
        if i % 3 == 0:
            for k in range(3):
                out.append(cone(loc=(p[0] + rnd.uniform(-.15, .15) * s, p[1] + rnd.uniform(-.15, .15) * s, p[2] + 0.35 * s),
                                r1=0.09 * s, r2=0.02 * s, depth=0.8 * s, rot=(rnd.uniform(-25, 25), rnd.uniform(-25, 25), 0),
                                mat=toon(c), verts=6))
        else:
            out.append(ico(loc=p, scale=rnd.uniform(0.25, 0.45) * s, sub=2, mat=toon(c), smooth=True))
    return out


def rock(loc, s, col="#9aa0a6"):
    r = ico(loc=(loc[0], loc[1], loc[2] + 0.2 * s), scale=(s, s * 0.85, s * 0.6), sub=2, mat=toon(col), smooth=True)
    return [r]


def weed(loc, s, col):
    out = []
    for k in range(4):
        a = k * 1.6
        out.append(cone(loc=(loc[0] + math.cos(a) * 0.15 * s, loc[1] + math.sin(a) * 0.15 * s, loc[2] + 0.45 * s),
                        r1=0.06 * s, r2=0.0, depth=1.0 * s, rot=(math.cos(a) * 25, math.sin(a) * 25, 0), mat=toon(col), verts=5))
    return out


def dock(x, y_shore, length, z=0.55):
    wood, dark = "#b07a4a", "#7a5232"
    out = []
    for i in range(int(length / 0.55)):
        out.append(cube(loc=(x, y_shore - i * 0.55, z), scale=(2.2, 0.48, 0.12), mat=toon(wood if i % 2 else "#a8723f"), bevel=0.03))
    for i in range(0, int(length / 2.2) + 1):
        for s in (-1, 1):
            out.append(cyl(loc=(x + s * 1.05, y_shore - i * 2.2, z - 1.0), r=0.14, depth=2.6, mat=toon(dark), verts=10))
    end = y_shore - length
    out.append(cube(loc=(x - 0.6, end + 0.9, z + 0.32), scale=(0.6, 0.6, 0.5), mat=toon("#c48a52"), bevel=0.04))
    out.append(cyl(loc=(x + 0.6, end + 1.4, z + 0.35), r=0.28, depth=0.6, mat=toon("#9a6a3c"), verts=14))
    out.append(torus(loc=(x + 0.5, end + 0.3, z + 0.1), R=0.28, r=0.05, mat=toon("#d8c49a")))
    return out


def lily(loc, s):
    p = cyl(loc=(loc[0], loc[1], 0.03), r=0.45 * s, depth=0.04, mat=toon("#4f9a4a"), verts=14)
    f = sphere(loc=(loc[0] + 0.1 * s, loc[1], 0.1), scale=(0.15 * s, 0.15 * s, 0.1 * s), mat=toon("#ffb3d1"))
    return [p, f]


def scatter(P, rnd, n, zmin, zmax, fn, avoid=()):
    out = []
    tries = 0
    while len([1 for _ in range(1)]) and n > 0 and tries < n * 60:
        tries += 1
        x = rnd.uniform(-22, 22)
        y = rnd.uniform(-13, 19)
        z = H(x, y, P)
        if not (zmin <= z <= zmax):
            continue
        if any((x - a) ** 2 + (y - b) ** 2 < r * r for a, b, r in list(avoid) + EXTRA_AVOID):
            continue
        out += fn((x, y, z), rnd)
        n -= 1
    return out


def kn(name, s, folder=None, tint=None, hsv=None):
    """Kenney / KayKit model placer for scatter(): fn(p, rnd) -> [obj]."""
    def f(p, r):
        names = name if isinstance(name, (list, tuple)) else [name]
        o = V.place(r.choice(names), p, s * r.uniform(0.85, 1.2), folder=folder or V.NATURE, tint=tint, rnd=r, hsv=hsv)
        return [o]
    return f


def cloud(p, r):
    """a soft bank of cloud below the haze"""
    out = []
    w = r.uniform(1.2, 2.4)
    for k in range(r.randint(3, 6)):
        a = r.uniform(0, math.tau)
        d = r.uniform(0.2, 1.3) * w
        c = ico(loc=(p[0] + math.cos(a) * d * 1.3, p[1] + math.sin(a) * d * 0.7, p[2] + 0.5), scale=(r.uniform(0.7, 1.3) * w, r.uniform(0.6, 1.0) * w, r.uniform(0.35, 0.6) * w),
                sub=2, mat=toon("#ffffff"), smooth=True)
        c["no_outline"] = True
        out.append(c)
    return out


# KayKit's Forest Nature pack, by size
F = V.FOREST
TREES = ["Tree_1_A", "Tree_1_B", "Tree_1_C", "Tree_3_A", "Tree_3_B"]
PINES = ["Tree_4_A", "Tree_4_B", "Tree_4_C"]
UMBRELLAS = ["Tree_3_A", "Tree_3_B", "Tree_3_C"]
BARE = ["Tree_Bare_1_A", "Tree_Bare_1_B", "Tree_Bare_1_C", "Tree_Bare_2_A", "Tree_Bare_2_B"]
BUSHES = ["Bush_1_C", "Bush_1_D", "Bush_3_B", "Bush_3_C", "Bush_4_C", "Bush_4_D"]
GRASS = ["Grass_1_B", "Grass_1_C", "Grass_2_B", "Grass_2_C"]
ROCKS = ["Rock_1_E", "Rock_1_F", "Rock_1_G", "Rock_2_C", "Rock_2_D", "Rock_3_E", "Rock_3_F", "Rock_3_G", "Rock_3_H"]
BOULDERS = ["Rock_3_D", "Rock_3_E", "Rock_3_F", "Rock_3_G", "Rock_3_H"]       # round: the boxy ones look like crates under water


def build_scene(name, P):
    rnd = random.Random(7 + len(name))
    avoid = [(BOAT_SPOT[0], BOAT_SPOT[1], 7.0), (BOBBER_SPOT[0], BOBBER_SPOT[1], 3.0)]
    parts = [terrain(P, rnd)]
    WC = V.WATERCRAFT
    reeds = kn(GRASS, 1.5, F, hsv=(0.5, 0.8, 0.9))

    if name in ("River", "Ocean"):
        cols = ["#ffb3c7", "#c9a3ff", "#ffd27a", "#7fd6ff", "#ff8a7a"]
        if name == "Ocean":
            parts += scatter(P, rnd, 14, -3.6, -0.6, lambda p, r: coral(p, r.uniform(1.1, 1.8), cols, r), avoid)
            parts += scatter(P, rnd, 14, 0.25, 3.0, kn(["tree_palmTall", "tree_palmBend", "tree_palmDetailedTall", "tree_palmShort"], 2.8))
            parts += scatter(P, rnd, 12, 0.5, 3.0, kn(BUSHES, 0.8, F))
            parts += scatter(P, rnd, 10, 0.2, 3.0, kn(["flower_yellowB", "flower_redB"], 3.4))
            parts += scatter(P, rnd, 30, 0.2, 3.0, kn(GRASS, 1.0, F))
            parts += scatter(P, rnd, 2, -3.5, -2.0, lambda p, r: [V.place("chest", (p[0], p[1], p[2] + 0.1), 1.3, folder=V.GLB, rnd=r)], avoid)
        else:
            parts += scatter(P, rnd, 20, 0.7, 3.0, kn(TREES, 0.72, F))
            parts += scatter(P, rnd, 10, 0.7, 3.0, kn(PINES, 0.62, F))
            parts += scatter(P, rnd, 18, 0.5, 3.0, kn(BUSHES, 0.8, F))
            parts += scatter(P, rnd, 14, 0.25, 3.0, kn(["flower_redA", "flower_yellowA", "flower_purpleB"], 3.6))
            parts += scatter(P, rnd, 50, 0.3, 3.0, kn(GRASS, 1.0, F))
            parts += scatter(P, rnd, 10, -0.5, 0.05, reeds, avoid)
            parts += scatter(P, rnd, 10, -1.4, -0.2, lambda p, r: [V.place(r.choice(["lily_large", "lily_small"]), (p[0], p[1], 0.02), 2.4, rnd=r)], avoid)
            parts += scatter(P, rnd, 5, 0.3, 3.0, kn(["stump_round", "mushroom_redGroup"], 3.0))
        parts += scatter(P, rnd, 12, -2.5, -0.3, reeds, avoid)
        parts += scatter(P, rnd, 10, -P["deep"], -0.2, kn(BOULDERS, 0.85, F), avoid)
        parts += scatter(P, rnd, 5, 0.4, 3.0, kn(ROCKS, 0.7, F))
        sx = 9.0
        sy = P["shore"] + 3.5 * math.sin(0.11 * sx + 1.0) + 2.2 * math.sin(0.27 * sx + 2.3)
        parts += dock(sx, sy + 1.5, 9.0)
        moored = V.place("boat-row-small", (sx + 2.9, sy - 5.5, -0.12), 1.5, rot_z=math.radians(8), folder=WC)
        parts.append(moored)
    elif name == "Volcanic":
        dark = (0.5, 0.55, 0.45)
        parts += scatter(P, rnd, 14, 0.3, 3.0, kn(ROCKS, 1.3, F, hsv=dark))
        parts += scatter(P, rnd, 10, -P["deep"], -0.4, kn(BOULDERS, 1.0, F, hsv=dark), avoid)
        parts += scatter(P, rnd, 14, 0.35, 3.0, kn(BARE, 1.0, F, tint="#2a2024"))
        for _ in range(10):
            def vent(p, r):
                v = cyl(loc=(p[0], p[1], p[2] + 0.1), r=0.35, depth=0.3, mat=toon(P["glow"], flat_glow=True), verts=10)
                v["no_outline"] = True
                return [v, torus(loc=(p[0], p[1], p[2] + 0.2), R=0.5, r=0.18, mat=toon("#2a1c1c"))]
            parts += scatter(P, rnd, 1, -3.5, -0.6, vent, avoid)
        parts += scatter(P, rnd, 8, 1.0, 3.0, lambda p, r: [cone(loc=(p[0], p[1], p[2] + 1.0), r1=1.4, r2=0.3, depth=2.2,
                                                                  verts=8, mat=toon("#3a2626"), smooth=False)])
    elif name == "Sky":
        blossom = (0.13, 0.8, 1.7)          # pink crowns, lilac trunks
        parts += scatter(P, rnd, 30, -P["deep"], -1.0, cloud, avoid)
        parts += scatter(P, rnd, 16, 0.3, 3.0, kn(TREES, 0.62, F, hsv=blossom))
        parts += scatter(P, rnd, 14, 0.25, 3.0, kn(BUSHES, 0.7, F, hsv=blossom))
        parts += scatter(P, rnd, 16, 0.2, 3.0, kn(["flower_purpleA", "flower_yellowC"], 3.4))
        parts += scatter(P, rnd, 30, 0.25, 3.0, kn(GRASS, 1.0, F))
        parts += scatter(P, rnd, 6, 0.6, 3.0, kn(ROCKS, 1.0, F, hsv=(0.5, 0.4, 1.3)))
    elif name == "Space":
        moon = (0.75, 0.6, 0.8)
        parts += scatter(P, rnd, 26, -P["deep"], -0.6, lambda p, r: [crystal(p, r.uniform(1.0, 2.6), r.choice(["#c9b3ff", "#7dd6ff", "#ff9cf0"]))], avoid)
        parts += scatter(P, rnd, 16, 0.2, 3.0, kn(ROCKS, 1.2, F, hsv=moon))
        parts += scatter(P, rnd, 14, 0.4, 3.0, lambda p, r: [crystal(p, r.uniform(0.8, 2.0), r.choice(["#c9b3ff", "#7dd6ff", "#ff9cf0"]))])
        parts += scatter(P, rnd, 60, -P["deep"], -0.5, lambda p, r: [ico(loc=p, scale=0.08, sub=1, mat=toon("#ffffff", flat_glow=True))])
    elif name == "Alien":
        cols = ["#7dffcf", "#c77dff", "#5ff2ff", "#b8ff6a"]
        weird = (0.98, 1.1, 1.2)            # violet-teal crowns, cyan trunks
        parts += scatter(P, rnd, 10, -3.5, -0.6, lambda p, r: coral(p, r.uniform(0.8, 1.3), cols, r), avoid)
        parts += scatter(P, rnd, 12, 0.3, 3.0, lambda p, r: mushroom(p, r.uniform(0.6, 1.0), cap=r.choice(["#c77dff", "#7dff9a"])))
        parts += scatter(P, rnd, 10, 0.35, 3.0, kn(UMBRELLAS, 0.8, F, hsv=weird))
        parts += scatter(P, rnd, 12, 0.25, 3.0, kn(BUSHES, 0.8, F, hsv=weird))
        parts += scatter(P, rnd, 14, 0.4, 3.0, lambda p, r: [crystal(p, r.uniform(1.0, 2.2), r.choice(cols))])
    elif name == "Abyss":
        cols = ["#5ff2ff", "#c77dff", "#9fffd0"]
        deep = (0.62, 0.55, 0.5)
        parts += scatter(P, rnd, 16, -P["deep"], -1.0, lambda p, r: weed(p, r.uniform(1.2, 2.2), r.choice(cols)), avoid)
        parts += scatter(P, rnd, 10, -P["deep"], -1.0, kn(BOULDERS, 1.1, F, hsv=deep), avoid)
        parts += scatter(P, rnd, 2, -P["deep"], -2.0, lambda p, r: [V.place("chest", (p[0], p[1], p[2] + 0.1), 1.4, folder=V.GLB, rnd=r)], avoid)
        parts += scatter(P, rnd, 12, 0.3, 3.0, kn(ROCKS, 1.4, F, hsv=deep))
        parts += scatter(P, rnd, 10, 0.3, 3.0, kn(BARE, 1.0, F, tint="#3a5a7a"))
        parts += scatter(P, rnd, 50, -P["deep"], -0.5, lambda p, r: [ico(loc=(p[0], p[1], p[2] + 0.3), scale=0.1, sub=1,
                                                                          mat=toon(r.choice(cols), flat_glow=True))])
    return parts


SHOP_AT = (930.0, 322.0)        # where the door should be, scene px: in the gap between the HUD's top left and top right, even on a phone
SHOP_X = (725.0, 1140.0)        # the whole shop stays in that gap
SHOP_TOP = 118.0                # (a wide phone only shows the scene from about y = 100)


def shop_spot(P, cam):
    """Where the shop's origin goes: near SHOP_AT, in the HUD's gap. Where the land is too short it stands in the
    shallows just off the beach, on its posts."""
    from bpy_extras.object_utils import world_to_camera_view
    sc = bpy.context.scene

    def px(p):
        v = world_to_camera_view(sc, cam, Vector(p))
        return v.x * W, (1 - v.y) * 1080
    for top in (SHOP_TOP, 100.0, 80.0, 60.0):
        best, best_d = None, 1e12
        for yi in range(-10, 60):
            for xi in range(-70, 40):
                x, y = xi * 0.5, yi * 0.5
                loc = (x, y, max(H(x, y, P), 0.25) + 0.2)
                pts = [px(SH.to_world(k, loc)) for k in SH.key_points()]
                if min(p[1] for p in pts) < top or min(p[0] for p in pts) < SHOP_X[0] or max(p[0] for p in pts) > SHOP_X[1]:
                    continue
                back = SH.to_world((0.0, SH.Y1, 0.0), loc)
                if H(back[0], back[1], P) < -0.7:
                    continue
                o = px(loc)
                d = (o[0] - SHOP_AT[0]) ** 2 + (o[1] - SHOP_AT[1]) ** 2
                if d < best_d:
                    best, best_d = loc, d
        if best:
            return best
    return (0.0, 10.0, max(H(0.0, 10.0, P), 0.25) + 0.2)


def convex_hull(pts):
    """the points around pts, in order (Andrew's monotone chain)"""
    pts = sorted(map(tuple, pts))

    def half(seq):
        out = []
        for q in seq:
            while len(out) > 1 and (out[-1][0] - out[-2][0]) * (q[1] - out[-2][1]) - (out[-1][1] - out[-2][1]) * (q[0] - out[-2][0]) <= 0:
                out.pop()
            out.append(q)
        return out[:-1]
    return [list(q) for q in half(pts) + half(pts[::-1])]


def render_scene(name, path, mask_path):
    P = BIOMES[name]
    K.clear_scene()
    V.clear_library()
    K.SOFT[0] = True
    K.FOG.update({"color": None, "amount": 0.0})
    K.setup_render(W, 1080, samples=48, transparent=False)
    K.setup_world(P["ambient"], 1.0, sky=[(0, P["water"][1]), (1, P["water"][1])])
    s = K.sun(P["sun"], 1.0)
    s.data.angle = math.radians(7)
    bpy.context.scene.eevee.use_shadows = True
    cam = K.make_camera(CAM_ROT, ortho=False, lens=LENS)
    cam.location = CAM_LOC
    bpy.context.view_layer.update()
    spot = shop_spot(P, cam)
    EXTRA_AVOID[:] = [SH.to_world(k, spot)[:2] + (r,) for k, r in (((0.0, 2.0, 0), 7.5), ((3.5, -1.0, 0), 5.5), ((-3.0, -1.5, 0), 4.5), ((0.0, -5.0, 0), 5.0))]
    parts = build_scene(name, P)
    shop, keeper, smoke = SH.build(spot, name)
    parts += shop
    parts.append(water(P))
    K.outline_all(parts, 0.04)
    K.render(path)
    # water mask (quarter res): everything but water held out
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = W // 4, 1080 // 4
    sc.render.film_transparent = True
    sc.render.image_settings.color_mode = "RGBA"
    sc.eevee.taa_render_samples = 4
    for o in list(bpy.data.objects):
        if o.type == "MESH" and o.name.startswith("Plane"):
            bpy.data.objects.remove(o)
        elif o.type == "MESH":
            o.is_holdout = True
    water(P, mask=True)
    K.render(mask_path)
    sc.render.resolution_x, sc.render.resolution_y = W, 1080
    from bpy_extras.object_utils import world_to_camera_view
    bpy.context.view_layer.update()

    def px(p):
        v = world_to_camera_view(sc, cam, Vector(p))
        return [round(v.x, 4), round(1 - v.y, 4)]
    a = px((BOAT_SPOT[0], BOAT_SPOT[1], 0))
    b = px((BOAT_SPOT[0] + 1, BOAT_SPOT[1], 0))
    K.SOFT[0] = False
    EXTRA_AVOID[:] = []
    m = px(keeper)
    m2 = px(keeper + Vector((1, 0, 0)))
    corners = [px(k) for k in (SH.to_world(q, spot) for q in SH.key_points())]
    e = {"merchant": m, "merchant_unit_px": round((m2[0] - m[0]) * W, 3),
         "shop": [min(c[0] for c in corners), min(c[1] for c in corners), max(c[0] for c in corners), max(c[1] for c in corners)],
         "shop_outline": convex_hull(corners),
         "boat": a, "bobber": px((BOBBER_SPOT[0], BOBBER_SPOT[1], 0)), "unit_px": round((b[0] - a[0]) * W, 3),
         "water": list(P["water"]), "glow": P.get("glow", "#ffffff")}
    if name not in SH.NO_SMOKE:
        e["smoke"] = px(smoke)
    return e


# ------------------------------------------------------------ boat sprites
def clip_below(parts, z=-0.03):
    bpy.ops.object.select_all(action="DESELECT")
    meshes = [p for p in parts if p.type == "MESH"]
    for p in meshes:
        p.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    keep = []
    for p in meshes:
        bm = bmesh.new()
        bm.from_mesh(p.data)
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, 0, 1), clear_inner=True)
        bm.to_mesh(p.data)
        bm.free()
        if len(p.data.vertices) == 0:
            bpy.data.objects.remove(p)
        else:
            keep.append(p)
    return keep


FOAM_PAD = 1.5          # the foam image covers this much more than the boat's sprite, around the same centre
FOAM_SIZE = 320
FOOT_Z = 0.35           # the hull's footprint on the water: everything up to here


def footprint(parts):
    """The hull near the waterline, flattened onto the water: one mesh. -> (object, floats: nothing reaches the water)"""
    bm = bmesh.new()
    floats = True
    for p in parts:
        if p.type != "MESH":
            continue
        one = bmesh.new()
        one.from_mesh(p.data)
        one.transform(p.matrix_world)
        geom = one.verts[:] + one.edges[:] + one.faces[:]
        bmesh.ops.bisect_plane(one, geom=geom, plane_co=(0, 0, FOOT_Z), plane_no=(0, 0, 1), clear_outer=True)
        if len(one.faces) > 0:
            floats = False
        me = bpy.data.meshes.new("foot")
        one.to_mesh(me)
        one.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    if floats:                     # a flying craft: its whole shape, for the shadow it casts
        for p in parts:
            if p.type == "MESH":
                me = p.data.copy()
                me.transform(p.matrix_world)
                bm.from_mesh(me)
                bpy.data.meshes.remove(me)
    for v in bm.verts:
        v.co.z = 0.0
    me = bpy.data.meshes.new("footprint")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("footprint", me)
    bpy.context.collection.objects.link(ob)
    return ob, floats


def _soft(a, r):
    """three box blurs of radius r: about a gaussian of that sigma"""
    import numpy as np
    for _ in range(3):
        for axis in (0, 1):
            c = np.cumsum(np.pad(a, [(r + 1, r) if k == axis else (0, 0) for k in (0, 1)]), axis=axis)
            hi, lo = np.take(c, range(2 * r + 1, c.shape[axis]), axis=axis), np.take(c, range(0, c.shape[axis] - 2 * r - 1), axis=axis)
            a = (hi - lo) / (2 * r + 1)
    return a


def render_foam(cam, foot, path, unit_px):
    """The footprint, blurred, saved as an image: 1 under the hull, about 0.5 at its edge, 0 a little way out.
    The stage's vf_foam.gdshader draws foam and a shadow on the water from it."""
    import numpy as np
    import tempfile
    sc = bpy.context.scene
    hidden = [o for o in bpy.data.objects if o.type == "MESH" and o is not foot and not o.hide_render]
    for o in hidden:
        o.hide_render = True
    foot.data.materials.append(toon("#ffffff", flat_glow=True))
    k = cam.data.ortho_scale
    cam.data.ortho_scale = k * FOAM_PAD
    n = FOAM_SIZE * 2
    tmp = os.path.join(tempfile.mkdtemp(), "foot.png")
    K.render(tmp)
    cam.data.ortho_scale = k
    for o in hidden:
        o.hide_render = False
    im = bpy.data.images.load(tmp)
    a = np.array(im.pixels[:], dtype=np.float32).reshape(n, n, 4)[..., 3]
    bpy.data.images.remove(im)
    a = (a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2]) / 4.0
    a = _soft(a, max(2, int(round(0.32 * unit_px * FOAM_SIZE / n / FOAM_PAD))))
    px = np.ones((FOAM_SIZE, FOAM_SIZE, 4), dtype=np.float32)
    px[..., 0] = px[..., 1] = px[..., 2] = np.clip(a, 0.0, 1.0)
    out = bpy.data.images.new("foam", FOAM_SIZE, FOAM_SIZE, alpha=False)
    out.pixels = px.ravel().tolist()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


def render_boat_top(name, path):
    K.clear_scene()
    K.SOFT[0] = True
    K.setup_render(640, 640, samples=32)
    K.setup_world("#9aa6b0", 1.0)
    s = K.sun((42, 0, 28), 1.0)
    s.data.angle = math.radians(7)
    cam = K.make_camera(CAM_ROT, ortho=True)
    parts, deck = B.build_boat(name)
    seat = B.find_seat(parts, deck)
    foot, floats = footprint(parts)
    foot.hide_render = True
    allp = clip_below(parts)
    K.outline_all(allp, 0.035)
    K.frame_ortho(cam, allp, 1.06)
    W2 = 640
    cx, cy, scale, aspect = cam["frame"]
    if path:
        K.render(path)
        foot.hide_render = False
        render_foam(cam, foot, os.path.join(os.path.dirname(os.path.dirname(path)), "boats_foam", os.path.basename(path)), W2 / scale)
    d = K.project(cam, deck)
    st = K.project(cam, seat)
    o = K.project(cam, (0, 0, 0))
    K.SOFT[0] = False
    e = {"deck": [d[0] / W2, d[1] / W2], "seat": [st[0] / W2, st[1] / W2], "origin": [o[0] / W2, o[1] / W2],
         "unit_px": round(W2 / scale, 3), "foam_pad": FOAM_PAD}
    if floats:
        e["floats"] = True
    return e


def render_fish_top(name, spec, path):
    K.clear_scene()
    K.SOFT[0] = True
    K.setup_render(160, 160, samples=16)
    K.setup_world("#9aa6b0", 1.0)
    K.sun((20, 0, 30), 1.0)
    cam = K.make_camera((0, 0, 0), ortho=True)
    parts = M.build_fish(spec)
    K.outline_all(parts, 0.03)
    K.frame_ortho(cam, parts, 1.08)
    K.render(path)
    K.SOFT[0] = False

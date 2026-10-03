"""High-angle (top-down) biome scenes, boat sprites and swimming-fish sprites.

One analytic height function h(x, y) drives BOTH the terrain mesh (Python)
and the water shader (node graph), so depth colour, transparency and
shoreline foam line up exactly with the coast.
"""
import math
import random

import bmesh
import bpy
from mathutils import Vector

import vf_kit as K
import vf_models as M
import vf_boats as B
import vf_vendor as V
from vf_biomes import palm, pine, mushroom, crystal
from vf_kit import cone, cube, cyl, hexc, ico, sphere, toon, torus, tube

W = 1920
CAM_ROT = (30, 0, 0)
CAM_LOC = (0, -17.5, 31)
LENS = 34
BOAT_SPOT = (-4.0, -3.0)
BOBBER_SPOT = (4.0, 0.5)
X0, X1, Y0, Y1 = -46, 46, -16, 52
EXTRA_AVOID = []      # (x, y, r) kept clear of scattered props (merchant stall)

BIOMES = {
    "River":    dict(shore=8, slope=0.42, deep=3.0, max_a=0.6, water=("#9ce6d6", "#2f8a9a"),
                     seabed=("#d8c896", "#6f8f72"), sand="#e9d7a6", land="#82c46c", land2="#5fa65a",
                     ambient="#8e98a6", sun=(42, 0, 28)),
    "Volcanic": dict(shore=9, slope=0.36, deep=4.0, max_a=0.8, water=("#ffb27a", "#8a2414"),
                     seabed=("#4a3a3a", "#2a1414"), sand="#3a3236", land="#4a3c3c", land2="#2e2626",
                     ambient="#9a7a74", sun=(45, 0, 35), glow="#ff7a1f"),
    "Ocean":    dict(shore=9, slope=0.26, deep=5.5, max_a=0.62, water=("#9ff3e6", "#2a9ec4"),
                     seabed=("#f0e2bc", "#5a9ab0"), sand="#f2e4c0", land="#8ccc6c", land2="#6ab25a",
                     ambient="#9aa6b0", sun=(42, 0, 28)),
    "Sky":      dict(shore=9, slope=0.3, deep=10.0, max_a=0.6, water=("#ffe0f2", "#a89cff"),
                     seabed=("#ffffff", "#c8c0ff"), sand="#f4f0ff", land="#9ad87a", land2="#7cc36b",
                     ambient="#b0a8c0", sun=(40, 0, 20)),
    "Space":    dict(shore=9, slope=0.32, deep=6.0, max_a=0.8, water=("#b49cff", "#1a0f4a"),
                     seabed=("#4a3a7a", "#140c2a"), sand="#5a4a6e", land="#6a5a7a", land2="#4a3e5a",
                     ambient="#7a70a0", sun=(45, 0, 40), glow="#c9b3ff"),
    "Alien":    dict(shore=9, slope=0.34, deep=5.0, max_a=0.78, water=("#9affd8", "#0f5a4a"),
                     seabed=("#2f5a52", "#122a2a"), sand="#6a5a8a", land="#5a3a8a", land2="#46307a",
                     ambient="#7a9a90", sun=(45, 0, 200), glow="#7dffcf"),
    "Abyss":    dict(shore=10, slope=0.3, deep=8.0, max_a=0.9, water=("#3a7aaa", "#020818"),
                     seabed=("#1a2a44", "#05080f"), sand="#2a3048", land="#1f2638", land2="#161b2a",
                     ambient="#5a6680", sun=(55, 0, 90), glow="#5ff2ff"),
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
        speck = 0.04 * math.sin(co.x * 3.1 + math.sin(co.y * 2.3) * 2) * math.sin(co.y * 2.7)
        if z < -0.5:
            t = min(1.0, (-z - 0.5) / (P["deep"] - 0.5))
            c = K.mix(sb0, sb1, t ** 0.8)
        elif z < 0.35:
            c = K.mix(sand, sb0, max(0.0, min(1.0, -z / 0.5)))
        elif z < 0.9:
            c = K.mix(sand, land, (z - 0.35) / 0.55)
        else:
            c = K.mix(land, land2, 0.5 + 0.5 * math.sin(co.x * 0.4) * math.sin(co.y * 0.5))
        return tuple(max(0.0, min(1.0, v + speck)) if i < 3 else v for i, v in enumerate(c))
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
    mixc.inputs[7].default_value = (1, 1, 1, 1)
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
    out = [ico(loc=(loc[0], loc[1], loc[2] + 0.1 * s), scale=(1.4 * s, 0.9 * s, 0.35 * s), sub=2, mat=toon("#b8c4c8"))]
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


def hut(x, y, z):
    out = [cube(loc=(x, y, z + 1.1), scale=(3.2, 2.6, 2.2), mat=toon("#c98a5a"), bevel=0.05)]
    roof = cone(loc=(x, y, z + 2.9), r1=2.6, r2=0.0, depth=1.6, verts=4, rot=(0, 0, 45), scale=(1.25, 1.05, 1), mat=toon("#9a4a3a"),
                smooth=False)
    out.append(roof)
    out.append(cube(loc=(x, y - 1.31, z + 0.8), scale=(0.7, 0.04, 1.3), mat=toon("#3f6fa0")))
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


def kn(name, s, folder=None, tint=None):
    """Kenney model placer for scatter(): fn(p, rnd) -> [obj]."""
    def f(p, r):
        names = name if isinstance(name, (list, tuple)) else [name]
        o = V.place(r.choice(names), p, s * r.uniform(0.85, 1.2), folder=folder or V.NATURE, tint=tint, rnd=r)
        return [o]
    return f


def build_scene(name, P):
    rnd = random.Random(7 + len(name))
    avoid = [(BOAT_SPOT[0], BOAT_SPOT[1], 7.0), (BOBBER_SPOT[0], BOBBER_SPOT[1], 3.0)]
    parts = [terrain(P, rnd)]
    WC = V.WATERCRAFT
    land_rocks = ["rock_largeA", "rock_largeB", "rock_largeD", "rock_largeE"]
    seaweed = kn(["plant_flatTall", "grass_large", "grass_leafsLarge"], 3.2, tint="#3f9a6a")

    if name in ("River", "Ocean"):
        cols = ["#ffb3c7", "#c9a3ff", "#ffd27a", "#7fd6ff", "#ff8a7a"]
        if name == "Ocean":
            parts += scatter(P, rnd, 14, -3.6, -0.6, lambda p, r: coral(p, r.uniform(1.1, 1.8), cols, r), avoid)
            parts += scatter(P, rnd, 14, 0.25, 3.0, kn(["tree_palmTall", "tree_palmBend", "tree_palmDetailedTall", "tree_palmShort"], 2.8))
            parts += scatter(P, rnd, 10, 0.2, 3.0, kn(["plant_bushSmall", "flower_yellowB", "flower_redB", "plant_bush"], 3.4))
            parts += scatter(P, rnd, 2, -3.5, -2.0, lambda p, r: [V.place("chest", (p[0], p[1], p[2] + 0.1), 1.3, folder=V.GLB, rnd=r)], avoid)
        else:
            parts += scatter(P, rnd, 22, 0.35, 3.0, kn(["tree_pineRoundA", "tree_pineRoundC", "tree_pineTallA_detailed", "tree_default", "tree_oak"], 2.6))
            parts += scatter(P, rnd, 18, 0.25, 3.0, kn(["plant_bush", "plant_bushDetailed", "plant_bushLarge"], 2.0))
            parts += scatter(P, rnd, 14, 0.2, 3.0, kn(["flower_redA", "flower_yellowA", "flower_purpleB", "plant_bushSmall"], 3.6))
            parts += scatter(P, rnd, 8, -0.4, 0.1, kn(["grass_large", "plant_flatTall"], 3.0, tint="#5a9a4a"), avoid)
            parts += scatter(P, rnd, 10, -1.4, -0.2, lambda p, r: [V.place(r.choice(["lily_large", "lily_small"]), (p[0], p[1], 0.02), 2.4, rnd=r)], avoid)
            parts += scatter(P, rnd, 6, 0.2, 3.0, kn(["log_large", "stump_round", "mushroom_redGroup"], 3.0))
        parts += scatter(P, rnd, 12, -2.5, -0.3, seaweed, avoid)
        parts += scatter(P, rnd, 10, -P["deep"], 0.6, kn(land_rocks, 2.2), avoid)
        sx = 9.0
        sy = P["shore"] + 3.5 * math.sin(0.11 * sx + 1.0) + 2.2 * math.sin(0.27 * sx + 2.3)
        parts += dock(sx, sy + 1.5, 9.0)
        moored = V.place("boat-row-small", (sx + 2.6, sy - 4.5, -0.15), 2.2, rot_z=math.radians(80), folder=WC)
        parts.append(moored)
        if name == "Ocean":
            parts += hut(sx - 0.2, sy + 4.5, H(sx, sy + 4.5, P))
    elif name == "Volcanic":
        parts += scatter(P, rnd, 18, -P["deep"], 2.5, kn(["rock_tallA", "rock_tallC", "rock_largeC", "rock_largeE"], 2.4, tint="#3a2c2c"), avoid)
        for _ in range(10):
            def vent(p, r):
                v = cyl(loc=(p[0], p[1], p[2] + 0.1), r=0.35, depth=0.3, mat=toon(P["glow"], flat_glow=True), verts=10)
                v["no_outline"] = True
                return [v, torus(loc=(p[0], p[1], p[2] + 0.2), R=0.5, r=0.18, mat=toon("#2a1c1c"))]
            parts += scatter(P, rnd, 1, -3.5, -0.6, vent, avoid)
        parts += scatter(P, rnd, 8, 1.0, 3.0, lambda p, r: [cone(loc=(p[0], p[1], p[2] + 1.0), r1=1.4, r2=0.3, depth=2.2,
                                                                  verts=8, mat=toon("#3a2626"), smooth=False)])
    elif name == "Sky":
        parts += scatter(P, rnd, 40, -P["deep"], -1.0, lambda p, r: [ico(loc=(p[0], p[1], p[2] + 0.5), scale=r.uniform(0.8, 2.0),
                                                                          sub=2, mat=toon("#ffffff"), smooth=True)], avoid)
        parts += scatter(P, rnd, 14, 0.3, 3.0, kn(["tree_fat", "tree_plateau", "tree_detailed"], 2.6))
        parts += scatter(P, rnd, 16, 0.2, 3.0, kn(["flower_purpleA", "flower_yellowC", "plant_bushSmall"], 3.4))
        parts += scatter(P, rnd, 6, 0.6, 3.0, lambda p, r: rock(p, r.uniform(0.4, 0.9), "#d8d0e8"))
    elif name == "Space":
        parts += scatter(P, rnd, 26, -P["deep"], -0.6, lambda p, r: [crystal(p, r.uniform(1.0, 2.6), r.choice(["#c9b3ff", "#7dd6ff", "#ff9cf0"]))], avoid)
        parts += scatter(P, rnd, 18, 0.2, 3.0, kn(land_rocks, 2.2, tint="#7a6a8a"))
        parts += scatter(P, rnd, 60, -P["deep"], -0.5, lambda p, r: [ico(loc=p, scale=0.08, sub=1, mat=toon("#ffffff", flat_glow=True))])
    elif name == "Alien":
        cols = ["#7dffcf", "#c77dff", "#5ff2ff", "#b8ff6a"]
        parts += scatter(P, rnd, 10, -3.5, -0.6, lambda p, r: coral(p, r.uniform(0.8, 1.3), cols, r), avoid)
        parts += scatter(P, rnd, 12, 0.3, 3.0, lambda p, r: mushroom(p, r.uniform(0.6, 1.0), cap=r.choice(["#c77dff", "#7dff9a"])))
        parts += scatter(P, rnd, 10, 0.2, 3.0, kn(["mushroom_tanTall", "mushroom_redTall"], 2.6, tint="#b07dff"))
        parts += scatter(P, rnd, 14, 0.4, 3.0, lambda p, r: [crystal(p, r.uniform(1.0, 2.2), r.choice(cols))])
    elif name == "Abyss":
        cols = ["#5ff2ff", "#c77dff", "#9fffd0"]
        parts += scatter(P, rnd, 16, -P["deep"], -1.0, lambda p, r: weed(p, r.uniform(1.2, 2.2), r.choice(cols)), avoid)
        parts += scatter(P, rnd, 10, -P["deep"], -1.0, kn(land_rocks, 2.4, tint="#2a3450"), avoid)
        parts += scatter(P, rnd, 2, -P["deep"], -2.0, lambda p, r: [V.place("chest", (p[0], p[1], p[2] + 0.1), 1.4, folder=V.GLB, rnd=r)], avoid)
        parts += scatter(P, rnd, 8, 0.2, 3.0, lambda p, r: [cyl(loc=(p[0], p[1], p[2] + 1.2), r=0.45, depth=2.6, verts=8,
                                                                 mat=toon("#3a4466"), smooth=False)])
        parts += scatter(P, rnd, 50, -P["deep"], -0.5, lambda p, r: [ico(loc=(p[0], p[1], p[2] + 0.3), scale=0.1, sub=1,
                                                                          mat=toon(r.choice(cols), flat_glow=True))])
    return parts


def merchant_spot(P, cam):
    """A flat bit of land in the upper-left of the frame (below the HUD)."""
    from bpy_extras.object_utils import world_to_camera_view
    sc = bpy.context.scene
    best, best_d = None, 1e9
    for min_h in (0.45, 0.25, 0.05):
        for xi in range(-24, 10):
            for yi in range(0, 22):
                x, y = xi * 1.0, yi * 1.0
                if min(H(x + dx, y + dy, P) for dx, dy in ((0, 0), (2, 0), (-2, 0), (0, 1.5), (0, -1.5))) < min_h:
                    continue
                v = world_to_camera_view(sc, cam, Vector((x, y, H(x, y, P))))
                u, w = v.x, 1 - v.y
                if not (0.05 < u < 0.45 and 0.24 < w < 0.5):
                    continue
                d = (u - 0.2) ** 2 + (w - 0.36) ** 2
                if d < best_d:
                    best, best_d = (x, y, H(x, y, P)), d
        if best:
            return best
    return (-12.0, 8.0, H(-12.0, 8.0, P))


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
    spot = merchant_spot(P, cam)
    EXTRA_AVOID[:] = [(spot[0], spot[1], 4.5)]
    parts = build_scene(name, P)
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
    m = px(spot)
    m2 = px((spot[0] + 1, spot[1], spot[2]))
    return {"merchant": m, "merchant_unit_px": round((m2[0] - m[0]) * W, 3),
            "boat": a, "bobber": px((BOBBER_SPOT[0], BOBBER_SPOT[1], 0)), "unit_px": round((b[0] - a[0]) * W, 3),
            "water": list(P["water"]), "glow": P.get("glow", "#ffffff")}


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


def render_boat_top(name, path):
    K.clear_scene()
    K.SOFT[0] = True
    K.setup_render(640, 640, samples=32)
    K.setup_world("#9aa6b0", 1.0)
    s = K.sun((42, 0, 28), 1.0)
    s.data.angle = math.radians(7)
    cam = K.make_camera(CAM_ROT, ortho=True)
    parts, deck = B.build_boat(name)
    allp = clip_below(parts)
    K.outline_all(allp, 0.035)
    K.frame_ortho(cam, allp, 1.06)
    K.render(path)
    W2 = 640
    cx, cy, scale, aspect = cam["frame"]
    d = K.project(cam, deck)
    o = K.project(cam, (0, 0, 0))
    K.SOFT[0] = False
    return {"deck": [d[0] / W2, d[1] / W2], "origin": [o[0] / W2, o[1] / W2], "unit_px": round(W2 / scale, 3),
            "fisher_scale": B.FISHER_SCALE.get(name, 1.0)}


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

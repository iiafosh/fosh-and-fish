"""The residents you find when sailing: three per biome, each a real little model seen from the game's camera. vf_life
renders them into assets/vf/life/find_<id>.png, the same kind of picture as the duck and the bottle.
The water is z = 0 and the camera looks from -Y and above, so a resident looks at -Y (at you) or +X (right).
"""
import math

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

import vf_kit as K
import vf_models as M
import vf_topdown as TD
from vf_kit import cone, cube, cyl, extrude_poly, hexc, ico, mix, sphere, toon, torus, tube


def _s(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def _paint(ob, fn, key, **kw):
    """fn(local position, normal) -> colour"""
    K.vcolor(ob, fn)
    ob.data.materials.clear()
    ob.data.materials.append(toon(None, vcol="col", key=("find", key), **kw))
    return ob


def _thin(ob, k=0.35):
    ob["outline_k"] = k
    return ob


def _bare(*obs):
    for o in obs:
        o["no_outline"] = True
    return list(obs)


def _dice(ob, cuts):
    """more vertices, for colours to land on"""
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def _sheet(verts, faces, thick, col=None):
    """flat pieces with a real thickness, so the outline works on them"""
    me = bpy.data.meshes.new("sheet")
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new("sheet", me)
    bpy.context.collection.objects.link(ob)
    if col:
        ob.data.materials.append(toon(col))
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    mod = ob.modifiers.new("t", "SOLIDIFY")
    mod.thickness = thick
    mod.offset = 0.0
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob["outline_even"] = False
    return ob


def _eye(at, r=0.06):
    """a black bead with a glint"""
    x, y, z = at
    e = sphere(loc=at, scale=r, mat=toon("#141018", shade=1.0, rim=0.0), seg=16, rings=8)
    s = sphere(loc=(x + r * 0.28, y - r * 0.62, z + r * 0.5), scale=r * 0.33, mat=toon("#ffffff", flat_glow=True), seg=10, rings=6)
    return _bare(e, s)


def _goggle(at, r, look=(0.0, -0.82, 0.57), pupil=0.55):
    """a big white eye looking at you (or wherever)"""
    w = sphere(loc=at, scale=r, mat=toon("#ffffff"), seg=20, rings=10)
    d = Vector(look).normalized() * r * 0.62
    c = Vector(at) + d
    p = sphere(loc=c, scale=r * pupil, mat=toon("#141018", shade=1.0, rim=0.0), seg=14, rings=8)
    s = sphere(loc=c + Vector((r * 0.16, -r * 0.3, r * 0.28)), scale=r * 0.17, mat=toon("#ffffff", flat_glow=True), seg=8, rings=5)
    w["outline_k"] = 0.6
    return [w] + _bare(p, s)


def _happy(at, r=0.07, along=(1, 0, 0), col="#2a1a14"):
    """an eye shut in bliss: a little upside-down U"""
    a, c = Vector(along), Vector(at)
    return _bare(tube([c - a * r, c + Vector((0, 0, r * 0.75)), c + a * r], 0.018, mat=toon(col, shade=1.0, rim=0.0), res=6))


def _turn(parts, rot, at=(0, 0, 0)):
    """lean the whole model"""
    bpy.context.view_layer.update()
    a = Matrix.Translation(at)
    m = a @ Euler([math.radians(r) for r in rot]).to_matrix().to_4x4() @ a.inverted()
    for p in parts:
        p.matrix_world = m @ p.matrix_world
    return parts


def _small_fish(at, length=0.3, col="#ff9a2e", fin="#e0641c"):
    """the sort of fish that is always in the wrong place, heading +X"""
    x, y, z = at
    b = sphere(loc=at, scale=(length, length * 0.68, length * 0.72), mat=toon(col), seg=20, rings=10)
    t = cone(loc=(x - length * 1.15, y, z), r1=length * 0.55, r2=0.0, depth=length * 0.75, rot=(0, 90, 0), verts=4, mat=toon(fin), smooth=False)
    t.scale = (1.0, 0.35, 1.0)
    return [b, t]


# ------------------------------------------------------------------- River
def _otter():
    fur, paw = "#96623a", "#6a4226"
    body = sphere(loc=(-0.18, 0, 0.1), scale=(0.62, 0.45, 0.33), seg=48, rings=24)
    _paint(body, lambda co, n: mix(hexc(fur), hexc("#f6e7cb"), _s((co.z - 0.25) / 0.32) * _s((0.85 - abs(co.y)) / 0.3)), "otter")
    head = sphere(loc=(0.54, -0.02, 0.31), scale=(0.38, 0.37, 0.32), mat=toon(fur))
    muzzle = sphere(loc=(0.74, -0.08, 0.4), scale=(0.2, 0.25, 0.15), mat=toon("#f6e7cb"))
    nose = sphere(loc=(0.88, -0.1, 0.5), scale=(0.07, 0.09, 0.05), mat=toon("#2a1a14"))
    tail = tube([(-0.72, 0, 0.07), (-0.94, 0, 0.1), (-1.14, 0, 0.27)], 0.12, mat=toon(paw), taper=(1.0, 0.3))
    clam = sphere(loc=(0.02, 0, 0.47), scale=(0.2, 0.23, 0.085), mat=toon("#ffb0b8"))
    parts = [body, head, muzzle, nose, tail, clam]
    for i in (-0.12, 0.0, 0.12):
        parts += _bare(tube([(-0.05, i * 0.6, 0.55), (0.14, i * 1.3, 0.52)], 0.011, mat=toon("#d9707e", shade=1.0, rim=0.0), res=4))
    for s in (1, -1):
        ear = sphere(loc=(0.34, s * 0.34, 0.46), scale=0.1, mat=toon(paw))
        arm = tube([(-0.18, s * 0.36, 0.28), (0.0, s * 0.28, 0.46)], 0.07, mat=toon(fur))
        pad = sphere(loc=(0.03, s * 0.24, 0.49), scale=(0.11, 0.09, 0.075), mat=toon(paw))
        foot = sphere(loc=(-0.68, s * 0.27, 0.32), scale=(0.15, 0.1, 0.12), mat=toon(paw))
        parts += [ear, arm, pad, foot]
        parts += _happy((0.5, -0.02 + s * 0.2, 0.615), 0.08, along=(1, 0, 0))
        parts.append(_thin(tube([(0.76, s * 0.22 - 0.08, 0.42), (0.82, s * 0.5 - 0.08, 0.5)], 0.008, mat=toon("#fbf6ea"), res=4), 0.2))
    return parts


def _frog():
    def veins(co, n):
        a = math.atan2(co.y, co.x)
        c = mix(hexc("#3f9a4a"), hexc("#74c75a"), min(1.0, math.hypot(co.x, co.y) * 1.1))
        return mix(c, hexc("#2c7a3c"), 0.7) if abs(math.sin(a * 6.0)) < 0.09 else c
    pad = sphere(loc=(0, 0, 0.0), scale=(1.02, 1.02, 0.09), seg=64, rings=20)

    def notch(co):
        d = abs((math.atan2(co.y, co.x) + math.radians(40) + math.pi) % math.tau - math.pi)
        k = d / math.radians(16)
        return Vector((co.x * k, co.y * k, co.z)) if k < 1.0 else co
    K.deform(pad, notch)
    _paint(pad, veins, "lily")
    body = sphere(loc=(0, 0, 0.44), scale=(0.48, 0.43, 0.35), seg=32, rings=16)
    _paint(body, lambda co, n: mix(hexc("#6cc24a"), hexc("#ecf5ae"), _s(-co.y * 0.9 - co.z * 0.9 - 0.2)), "frog")
    parts = [pad, body]
    dark = toon("#23331c", shade=1.0, rim=0.0)
    parts += _bare(tube([(-0.38, -0.27, 0.52), (-0.2, -0.4, 0.42), (0, -0.44, 0.4), (0.2, -0.4, 0.42), (0.38, -0.27, 0.52)], 0.016, mat=dark, res=8))
    for s in (1, -1):
        bump = sphere(loc=(s * 0.25, -0.06, 0.76), scale=0.18, mat=toon("#6cc24a"))
        white = sphere(loc=(s * 0.25, -0.13, 0.8), scale=0.13, mat=toon("#fffdf0"), seg=20, rings=10)
        pupil = sphere(loc=(s * 0.25, -0.22, 0.84), scale=(0.08, 0.05, 0.05), mat=toon("#141018", shade=1.0, rim=0.0), seg=14, rings=8)
        leg = sphere(loc=(s * 0.48, 0.04, 0.25), scale=(0.2, 0.3, 0.15), mat=toon("#5cb040"))
        arm = tube([(s * 0.3, -0.26, 0.4), (s * 0.36, -0.44, 0.13)], 0.05, mat=toon("#5cb040"))
        foot = sphere(loc=(s * 0.38, -0.5, 0.1), scale=(0.13, 0.09, 0.03), mat=toon("#5cb040"))
        parts += [bump, white, leg, arm, foot] + _bare(pupil)
    # he brought his own rod. He has caught more than you
    parts.append(_thin(tube([(0.36, -0.46, 0.14), (0.74, -0.6, 0.56), (1.14, -0.72, 0.9)], 0.018, mat=toon("#8a5a2e"), taper=(1.2, 0.6)), 0.6))
    parts.append(_thin(tube([(1.14, -0.72, 0.9), (1.18, -0.74, 0.45), (1.18, -0.74, 0.12)], 0.006, mat=toon("#f4f4f0"), res=4), 0.2))
    parts.append(sphere(loc=(1.18, -0.74, 0.1), scale=0.075, mat=toon("#e5533d"), seg=14, rings=8))
    for a in range(5):                                      # (and a flower, for the view)
        th = a / 5 * math.tau
        parts.append(_thin(sphere(loc=(-0.55 + math.cos(th) * 0.12, -0.42 + math.sin(th) * 0.12, 0.13), scale=(0.11, 0.07, 0.04), rot=(0, 0, math.degrees(th)), mat=toon("#ffb0cf")), 0.5))
    parts += _bare(sphere(loc=(-0.55, -0.42, 0.16), scale=0.055, mat=toon("#ffd83a")))
    return parts


def _old_boot():
    leather, dark, sole_m = toon("#8a5730"), toon("#61391f"), toon("#3b2a20")
    shaft = cyl(loc=(-0.32, 0, 0.72), r=0.38, depth=1.04, verts=32, mat=leather)
    foot = sphere(loc=(0.2, 0, 0.27), scale=(0.74, 0.41, 0.31), mat=leather)
    sole = sphere(loc=(0.12, 0, 0.05), scale=(0.94, 0.45, 0.085), mat=sole_m)
    rim = torus(loc=(-0.32, 0, 1.24), R=0.37, r=0.05, mat=dark)
    hole = cyl(loc=(-0.32, 0, 1.22), r=0.34, depth=0.02, verts=32, mat=toon("#20140d"))
    patch = sphere(loc=(0.62, -0.2, 0.34), scale=(0.2, 0.15, 0.13), mat=toon("#a7763f"))
    parts = [shaft, foot, sole, rim, hole, patch]
    # the tenant
    fish = sphere(loc=(-0.32, -0.08, 1.34), scale=(0.2, 0.17, 0.2), mat=toon("#ff9a2e"), seg=20, rings=10)
    fin = cone(loc=(-0.32, 0.02, 1.57), r1=0.08, r2=0.0, depth=0.15, verts=8, mat=toon("#e0641c"))
    parts += [fish, fin]
    for s in (1, -1):
        parts += _goggle((-0.32 + s * 0.095, -0.22, 1.39), 0.075, look=(s * 0.1, -0.8, 0.55), pupil=0.5)
    # his front window, with the light on
    frame = torus(loc=(-0.32, -0.385, 0.74), R=0.15, r=0.028, rot=(90, 0, 0), mat=toon("#5a3820"), seg=24, mseg=8)
    glass = cyl(loc=(-0.32, -0.37, 0.74), r=0.14, depth=0.02, rot=(90, 0, 0), verts=24, mat=toon("#ffdc6e", flat_glow=True))
    parts += [frame] + _bare(glass)
    for a, b in (((-0.47, -0.4, 0.74), (-0.17, -0.4, 0.74)), ((-0.32, -0.4, 0.59), (-0.32, -0.4, 0.89))):
        parts += _bare(tube([a, b], 0.012, mat=toon("#5a3820", shade=1.0), res=2))
    for i in range(3):                                      # the laces, what is left of them
        z = 0.42 + i * 0.13
        parts.append(_thin(tube([(0.0, -0.33 + i * 0.03, z), (0.09, -0.27 + i * 0.03, z + 0.03)], 0.02, mat=toon("#e8dcc0"), res=3), 0.4))
    return _turn(parts, (0, -7, -12))


# ---------------------------------------------------------------- Volcanic
def _capybara():
    parts = []
    for i in range(13):                                     # the spring
        a = i / 13 * math.tau
        r = 0.07 * ((i * 7) % 3) + 0.2
        parts.append(ico(loc=(math.cos(a) * 1.04, math.sin(a) * 0.92, 0.09), scale=(r, r * 0.86, r * 0.75), mat=toon("#7d746d" if i % 2 else "#938a80"), sub=2, smooth=True))
    water = sphere(loc=(0, 0, 0.1), scale=(1.03, 0.92, 0.08), seg=48, rings=12, mat=toon("#5fe0d0", flat_glow=True))
    water["no_outline"] = True
    parts.append(water)
    fur, dark = "#a97b4e", "#6a4a2c"
    body = sphere(loc=(-0.2, 0.06, 0.38), scale=(0.62, 0.44, 0.38), mat=toon(fur))
    head = sphere(loc=(0.34, -0.18, 0.66), scale=(0.34, 0.29, 0.27), mat=toon(fur))
    snout = sphere(loc=(0.56, -0.32, 0.6), scale=(0.2, 0.2, 0.17), mat=toon("#b98a5c"))
    nose = sphere(loc=(0.68, -0.42, 0.64), scale=(0.075, 0.07, 0.05), mat=toon("#3a2618"))
    parts += [body, head, snout, nose]
    for s in (1, -1):
        parts.append(sphere(loc=(0.16 + s * 0.2, -0.09 + s * 0.17, 0.92), scale=(0.075, 0.07, 0.05), mat=toon(dark)))
    parts += _happy((0.3, -0.42, 0.78), 0.06, along=(1, 0.3, 0)) + _happy((0.58, -0.13, 0.78), 0.06, along=(0.7, 0.7, 0))
    # the orange. Nobody knows why. It is very important
    orange = sphere(loc=(0.3, -0.16, 1.03), scale=0.15, mat=toon("#ff9a2e"), seg=20, rings=10)
    leaf = sphere(loc=(0.36, -0.14, 1.19), scale=(0.07, 0.035, 0.022), rot=(0, -20, 30), mat=toon("#4fa45a"))
    parts += [orange, _thin(leaf, 0.5)]
    for x, y, z, r in ((-0.74, 0.34, 0.5, 0.13), (-0.62, 0.42, 0.8, 0.18), (-0.76, 0.46, 1.14, 0.24), (0.84, 0.36, 0.54, 0.12), (0.76, 0.44, 0.86, 0.17)):
        parts += _bare(sphere(loc=(x, y, z), scale=r, mat=toon("#ffffff", flat_glow=True, alpha=0.26), seg=16, rings=8))
    return parts


def _lava_crab():
    import vf_life as LF
    groups = LF._build_crab(top="#4a3432", belly="#ff9a3a", claw="#ff5c2a", leg="#a2472a")

    def crust(co, n):
        c = mix(hexc("#ff9a3a"), hexc("#4a3432"), min(1.0, max(0.0, co.z * 2.6 + 0.8)))
        if abs(math.sin(co.x * 8.0 + co.z * 5.0) + math.sin(co.y * 7.0 - co.z * 6.0)) < 0.13 and co.z > -0.1:
            c = hexc("#ffc23a")
        return c
    _paint(groups["body"][0], crust, "lavacrab", emit=0.22)
    # (each claw is an arm, a palm, a finger and a thumb. Keep the arms)
    claws = groups["claws"]
    for o in claws[1:4] + claws[5:8]:
        bpy.data.objects.remove(o)
    groups["claws"] = [claws[0], claws[4]]
    parts = [p for g in groups.values() for p in g]
    red, cuff_m = toon("#e8483a"), toon("#f6ecd6")
    for s in (1, -1):                                       # oven gloves: he is not stupid
        glove = sphere(loc=(1.06, s * 0.76, 0.4), scale=(0.38, 0.28, 0.28), mat=red)
        cuff = sphere(loc=(0.76, s * 0.8, 0.28), scale=(0.1, 0.22, 0.22), mat=cuff_m)
        thumb = sphere(loc=(1.1, s * 0.5, 0.46), scale=(0.16, 0.13, 0.12), rot=(0, 0, s * -30), mat=red)
        parts += [glove, cuff, thumb]
    return _turn(parts, (0, 0, -90))


def _marshmallow():
    rock = ico(loc=(-0.12, 0.04, 0.04), scale=(0.68, 0.52, 0.42), mat=toon("#4f4240"), sub=2, smooth=False)
    glow = sphere(loc=(0.18, -0.12, 0.36), scale=(0.25, 0.2, 0.07), mat=toon("#ffb02e", flat_glow=True))
    stick = tube([(-0.5, 0.0, 0.3), (-0.2, -0.04, 0.72), (0.1, -0.08, 0.98), (0.26, -0.1, 1.12)], 0.034, mat=toon("#8a5a2e"), res=8)
    at = Vector((0.26, -0.12, 1.16))
    m = sphere(scale=1.0, seg=40, rings=24)

    def puff(co):
        rho = math.hypot(co.x, co.y)
        k = rho ** 0.5 / rho if rho > 1e-5 else 1.0                 # (a sphere, puffed out into a soft cylinder)
        z = math.copysign(abs(co.z) ** 0.55, co.z)
        return Vector((co.x * k * 0.46, co.y * k * 0.46, z * 0.33))

    def toast(co, n):
        c = mix(hexc("#fff6e4"), hexc("#a9652c"), _s((-co.z + 0.02 + 0.05 * math.sin(co.x * 16.0)) / 0.22))
        if math.hypot(co.x - 0.36, co.z + 0.02) < 0.15:             # (the side that has already had enough)
            c = mix(c, hexc("#6e3d1c"), 0.8)
        return c
    K.deform(m, puff)
    _paint(m, toast, "mallow", emit=0.45)
    m.location = at
    m.rotation_euler = (0, math.radians(-8), 0)
    parts = [rock, stick, m] + _bare(glow)
    parts += M._flames((0.2, -0.12, 0.3), 0.6)
    # it has seen what happened to the last one
    ink = toon("#231a22", shade=1.0, rim=0.0)
    for s in (1, -1):
        e = sphere(loc=(at.x + s * 0.15, at.y - 0.45, at.z + 0.1), scale=(0.062, 0.02, 0.09), mat=ink, seg=14, rings=8)
        g = sphere(loc=(at.x + s * 0.15 + 0.018, at.y - 0.47, at.z + 0.135), scale=0.022, mat=toon("#ffffff", flat_glow=True), seg=8, rings=5)
        brow = tube([(at.x + s * 0.25, at.y - 0.44, at.z + 0.2), (at.x + s * 0.09, at.y - 0.45, at.z + 0.25)], 0.014, mat=ink, res=2)
        parts += _bare(e, g, brow)
    parts += _bare(sphere(loc=(at.x, at.y - 0.46, at.z - 0.08), scale=(0.04, 0.012, 0.055), mat=ink, seg=12, rings=8))
    return parts


# ------------------------------------------------------------------- Ocean
def _turtle():
    shell = sphere(loc=(-0.12, 0, 0.2), scale=(0.84, 0.68, 0.44), seg=48, rings=24)

    def plates(co, n):
        hexa = math.sin(co.x * 7.5) + math.sin(co.y * 8.0 + co.x * 3.8) > 0.95
        return hexc("#2f7a44") if hexa else mix(hexc("#58ad62"), hexc("#3e9050"), 1.0 - co.z)
    _paint(shell, plates, "turtleshell")
    skin = "#8ccf7a"
    head = sphere(loc=(0.86, -0.1, 0.32), scale=(0.33, 0.3, 0.26), mat=toon(skin))
    neck = tube([(0.5, 0, 0.18), (0.8, -0.06, 0.28)], 0.17, mat=toon(skin))
    parts = [shell, head, neck]
    for sx, sy, ang, a, b in ((0.42, 1, 40, 0.5, 0.15), (0.42, -1, -40, 0.5, 0.15), (-0.72, 1, 140, 0.32, 0.12), (-0.72, -1, -140, 0.32, 0.12)):
        parts.append(sphere(loc=(sx, sy * 0.72, 0.1), scale=(a, b, 0.07), rot=(0, 0, ang), mat=toon(skin)))
    # the hat: thirty years of barnacles, all on the one head
    hat = cone(loc=(0.8, -0.04, 0.74), r1=0.24, r2=0.13, depth=0.26, verts=20, mat=toon("#cbd2cc"))
    brim = sphere(loc=(0.8, -0.04, 0.61), scale=(0.33, 0.31, 0.045), mat=toon("#b6bfb8"))
    parts += [hat, brim]
    for i in range(10):
        a = i * 2.4
        r = 0.08 + i * 0.019
        z = 0.86 - i * 0.022
        c = cone(loc=(0.8 + math.cos(a) * r, -0.04 + math.sin(a) * r, z), r1=0.055, r2=0.02, depth=0.08, verts=8, mat=toon("#eef0ea"))
        parts.append(_thin(c, 0.5))
    # and he has had enough of you
    parts += _eye((1.0, -0.3, 0.38), 0.07)
    lid = sphere(loc=(1.0, -0.31, 0.415), scale=(0.085, 0.07, 0.048), mat=toon("#79bd68"))
    parts += _bare(lid)
    parts += _bare(tube([(0.96, -0.33, 0.22), (1.1, -0.27, 0.2), (1.17, -0.14, 0.24)], 0.016, mat=toon("#3a4a2c", shade=1.0, rim=0.0), res=6))
    return parts


def _fake_fin():
    grey = "#7b8c9c"
    pts = [(-0.6, 0.0), (-0.46, 0.22), (-0.22, 0.58), (0.02, 0.92), (0.18, 1.06), (0.26, 1.0), (0.3, 0.62), (0.36, 0.28), (0.5, 0.0)]
    fin = extrude_poly(pts, 0.13, mat=None, bevel=0.03)
    fin.rotation_euler = (math.radians(90), 0, 0)
    fin.location = (0.05, 0.02, 0.42)
    _paint(fin, lambda co, n: mix(hexc(grey), hexc("#a5b3c0"), _s(co.y * 0.9)), "fakefin")
    # a shark. From a distance. If you squint
    stick = tube([(-0.22, -0.2, 0.1), (-0.08, -0.08, 0.3), (0.0, 0.0, 0.62)], 0.04, mat=toon("#b98a52"), res=6)
    tape = cyl(loc=(0.0, -0.05, 0.54), r=0.075, depth=0.1, rot=(90, 0, 0), verts=12, mat=toon("#d8d8cc"))
    parts = [fin, stick, tape]
    parts += _small_fish((-0.42, -0.34, 0.1), 0.3, col="#ffb02e", fin="#e0641c")
    parts += _goggle((-0.28, -0.52, 0.2), 0.085, look=(0.55, -0.5, 0.6), pupil=0.42)
    parts += _goggle((-0.41, -0.56, 0.22), 0.07, look=(0.55, -0.5, 0.6), pupil=0.42)
    paddle = sphere(loc=(-0.2, -0.46, 0.12), scale=(0.12, 0.05, 0.07), rot=(0, -30, 20), mat=toon("#e0641c"))
    parts.append(paddle)
    return parts


def _treasure():
    sand = sphere(loc=(0, 0, 0), scale=(1.12, 0.92, 0.26), seg=48, rings=16)
    _paint(sand, lambda co, n: mix(hexc("#d9c289"), hexc("#f6e6b4"), _s(co.z * 1.4)), "sand")
    wood, gold = toon("#8e5a2e"), toon("#f2c33d", spec=0.35)
    box = cube(loc=(0.05, -0.1, 0.42), scale=(0.98, 0.62, 0.46), mat=wood, bevel=0.03)
    lid = cyl(loc=(0.05, 0.3, 0.88), r=0.3, depth=0.98, rot=(0, 90, 0), verts=24, mat=wood)
    lid.scale = (1.0, 0.55, 1.0)
    in_lid = cube(loc=(0.05, 0.13, 0.88), scale=(0.86, 0.02, 0.5), mat=toon("#4a2c14"))
    inner = cube(loc=(0.05, -0.1, 0.66), scale=(0.84, 0.48, 0.02), mat=toon("#1f140c"))
    parts = [sand, box, lid, in_lid, inner]
    for x in (-0.36, 0.46):
        parts.append(cube(loc=(x, -0.1, 0.42), scale=(0.09, 0.64, 0.48), mat=gold))
    parts.append(cube(loc=(0.05, -0.42, 0.56), scale=(0.17, 0.05, 0.18), mat=gold))
    rnd = [(-0.28, -0.26), (-0.1, -0.18), (0.1, -0.26), (0.28, -0.16), (0.0, 0.0), (-0.22, 0.0), (0.22, 0.02), (0.1, -0.08), (-0.04, -0.26), (0.34, -0.3), (-0.34, -0.1)]
    for i, (x, y) in enumerate(rnd):                        # more gold than the chest will hold
        z = 0.7 + 0.075 * (2.0 - abs(x) * 3.0 - abs(y + 0.1) * 3.0) + (i % 3) * 0.02
        parts.append(_thin(cyl(loc=(0.05 + x, -0.1 + y, z), r=0.1, depth=0.03, rot=(14 * (i % 3 - 1), 18 * (i % 2 * 2 - 1), 0), verts=14, mat=gold), 0.5))
    # a palm tree, for the look of the thing
    parts.append(tube([(-0.78, 0.2, 0.1), (-0.86, 0.26, 0.6), (-0.74, 0.3, 1.12)], 0.05, mat=toon("#9a7a4a"), taper=(1.2, 0.7)))
    for i in range(6):
        a = i / 6 * math.tau + 0.4
        d = Vector((math.cos(a), math.sin(a), 0))
        tip = Vector((-0.74, 0.3, 1.12)) + d * 0.52 + Vector((0, 0, -0.24))
        leaf = tube([(-0.74, 0.3, 1.14), Vector((-0.74, 0.3, 1.2)) + d * 0.28, tip], 0.07, mat=toon("#4fa45a"), radii=[0.5, 1.0, 0.1])
        parts.append(_thin(leaf, 0.7))
    return parts


# --------------------------------------------------------------------- Sky
def _cloud_sheep():
    wool = toon("#ffffff", emit=0.5)
    parts = []
    puffs = [(0, 0, 0.72, 0.5), (-0.46, 0.04, 0.68, 0.38), (0.42, 0.1, 0.72, 0.36), (-0.2, -0.3, 0.6, 0.34), (0.2, -0.3, 0.6, 0.34), (0.0, 0.3, 0.76, 0.38),
             (-0.26, 0.1, 1.02, 0.3), (0.2, 0.08, 1.04, 0.3), (-0.72, 0.02, 0.56, 0.22), (0.66, 0.06, 0.46, 0.2), (-0.4, -0.2, 0.42, 0.26), (0.34, -0.14, 0.4, 0.26)]
    for x, y, z, r in puffs:
        parts.append(ico(loc=(x, y, z), scale=r, mat=wool, sub=3, smooth=True))
    for x in (-0.36, -0.12, 0.2, 0.42):                     # the legs, for show: it has never touched the ground
        parts.append(tube([(x, -0.1, 0.34), (x, -0.14, 0.0)], 0.05, mat=toon("#3a3640")))
    face = sphere(loc=(0.46, -0.44, 0.66), scale=(0.25, 0.2, 0.3), mat=toon("#3a3640"))
    parts.append(face)
    for s in (1, -1):
        parts.append(sphere(loc=(0.46 + s * 0.28, -0.36, 0.84), scale=(0.13, 0.06, 0.055), rot=(0, s * 20, 0), mat=toon("#3a3640")))
        parts += _goggle((0.46 + s * 0.1, -0.6, 0.74), 0.07, pupil=0.5)
    parts.append(ico(loc=(0.46, -0.36, 0.95), scale=0.15, mat=wool, sub=3, smooth=True))
    parts += _bare(tube([(0.4, -0.63, 0.53), (0.46, -0.645, 0.5), (0.52, -0.63, 0.53)], 0.012, mat=toon("#f4f0ec", shade=1.0, rim=0.0), res=4))
    return parts


def _kite():
    top, right, low, left = (0, 0, 1.28), (0.68, 0, 0.56), (0, 0, -0.34), (-0.68, 0, 0.56)
    c = (0, 0.14, 0.56)
    parts = []
    for a, b, col in ((top, right, "#e5533d"), (right, low, "#ffd23f"), (low, left, "#e5533d"), (left, top, "#ffd23f")):
        parts.append(_thin(_sheet([a, b, c], [(0, 1, 2)], 0.02, col), 0.6))
    frame = toon("#6a4a2e")
    parts.append(_thin(tube([top, low], 0.022, mat=frame, res=2), 0.6))
    parts.append(_thin(tube([left, right], 0.022, mat=frame, res=2), 0.6))
    # it does not know where it is
    parts += _goggle((-0.16, -0.05, 0.66), 0.11, look=(-0.4, -0.7, 0.5), pupil=0.48)
    parts += _goggle((0.16, -0.05, 0.66), 0.11, look=(-0.4, -0.7, 0.5), pupil=0.48)
    parts += _bare(tube([(-0.09, -0.03, 0.4), (0.0, -0.03, 0.45), (0.09, -0.03, 0.4)], 0.016, mat=toon("#3a1420", shade=1.0, rim=0.0), res=6))
    # the tail, and what is left of the string, going nowhere
    tail = [(0, 0, -0.34), (0.2, -0.1, -0.56), (-0.02, -0.16, -0.76), (0.18, -0.2, -0.98)]
    parts.append(_thin(tube(tail, 0.01, mat=toon("#f4f4f0"), res=8), 0.4))
    for at, col in ((tail[1], "#3e8fe0"), (tail[2], "#ffd23f"), (tail[3], "#e5533d")):
        for s in (1, -1):
            b = cone(loc=(at[0] + s * 0.09, at[1], at[2]), r1=0.075, r2=0.0, depth=0.18, rot=(0, -s * 90, 0), verts=4, mat=toon(col), smooth=False)
            parts.append(_thin(b, 0.6))
    return _turn(parts, (-34, 14, 0), (0, 0, 0.4))


def _paper_plane():
    nose, tail_l, tail_r = (1.24, 0.0, 0.5), (-1.02, -0.86, 0.74), (-1.02, 0.86, 0.74)
    fold_l, fold_r, keel = (-1.02, -0.06, 0.52), (-1.02, 0.06, 0.52), (-1.02, 0.0, 0.1)
    ob = _sheet([nose, tail_l, fold_l, tail_r, fold_r, keel], [(0, 1, 2), (0, 4, 3), (0, 2, 5), (0, 5, 4)], 0.024)
    _dice(ob, 3)
    _paint(ob, lambda co, n: hexc("#fdfcf4") if co.z > 0.46 else hexc("#d9dad2"), "paper")
    parts = [ob]
    n, l, f = Vector(nose), Vector(tail_l), Vector(fold_l)
    nrm = (l - n).cross(f - n).normalized()

    def on(x, y):
        """this point of a wing (they mirror each other), just above the paper"""
        return Vector((x, y, n.z - (nrm.x * (x - n.x) + nrm.y * (-abs(y) - n.y)) / nrm.z + 0.02))
    # (ruled paper: somebody's homework)
    blue = toon("#8db8ea", shade=1.0, rim=0.0)
    for x in (-0.82, -0.56, -0.3, -0.04, 0.22, 0.48):
        t = (1.24 - x) / 2.26
        for s in (-1, 1):
            parts += _bare(tube([on(x, s * (0.06 * t + 0.03)), on(x, s * (0.86 * t - 0.03))], 0.008, mat=blue, res=2))
    # it came back with a mark. A big one
    red = toon("#d9302c", shade=1.0, rim=0.0)
    for a, b in (((-0.48, -0.5), (-0.48, -0.16)), ((-0.48, -0.16), (-0.2, -0.16)), ((-0.48, -0.32), (-0.26, -0.32))):
        parts += _bare(tube([on(*a), on(*b)], 0.03, mat=red, res=2))
    return _turn(parts, (6, -4, -16), (0, 0, 0.5))


# ------------------------------------------------------------------- Space
def _helmet(at, r):
    glass = sphere(loc=at, scale=r, mat=toon("#cfefff", alpha=0.17, rim=0.65), seg=32, rings=16)
    glint = sphere(loc=(at[0] - r * 0.64, at[1] - r * 0.5, at[2] + r * 0.54), scale=(r * 0.1, r * 0.05, r * 0.17), rot=(40, 0, 32), mat=toon("#ffffff", flat_glow=True))
    return _bare(glass, glint)


def _astro_cat():
    suit, grey = toon("#eef2f5"), toon("#9aa6b0")
    body = sphere(loc=(0, 0.02, 0.46), scale=(0.42, 0.36, 0.46), mat=suit)
    pack = cube(loc=(0, 0.38, 0.52), scale=(0.5, 0.2, 0.56), mat=grey, bevel=0.04)
    collar = torus(loc=(0, 0, 0.84), R=0.34, r=0.065, mat=grey)
    patch = cyl(loc=(0.16, -0.35, 0.56), r=0.075, depth=0.02, rot=(90, 0, 0), verts=16, mat=toon("#e5533d"))
    head = sphere(loc=(0, -0.02, 1.14), scale=(0.4, 0.37, 0.34), mat=toon("#ff9a3a"))
    parts = [body, pack, collar, patch, head]
    for s in (1, -1):
        parts.append(cone(loc=(s * 0.27, 0.02, 1.46), r1=0.14, r2=0.0, depth=0.26, rot=(0, s * 14, 0), verts=4, mat=toon("#ff9a3a"), smooth=False))
        parts.append(tube([(s * 0.38, -0.02, 0.62), (s * 0.62, -0.14, 0.42), (s * 0.6, -0.26, 0.2)], 0.1, mat=suit))
        parts.append(sphere(loc=(s * 0.6, -0.28, 0.16), scale=0.12, mat=grey))
        parts.append(tube([(s * 0.2, -0.04, 0.12), (s * 0.28, -0.14, -0.14)], 0.12, mat=suit))
        parts.append(sphere(loc=(s * 0.29, -0.18, -0.24), scale=(0.15, 0.2, 0.1), mat=grey))
        parts += _goggle((s * 0.16, -0.32, 1.2), 0.105, pupil=0.62)
        parts.append(_thin(tube([(s * 0.25, -0.32, 1.06), (s * 0.5, -0.3, 1.11)], 0.007, mat=toon("#fbf6ea"), res=3), 0.2))
    for dx in (-0.14, 0.0, 0.14):                           # tabby stripes
        parts += _bare(tube([(dx, -0.2, 1.47 - abs(dx) * 0.3), (dx * 0.8, -0.32, 1.36 - abs(dx) * 0.3)], 0.016, mat=toon("#b9601c", shade=1.0, rim=0.0), res=3))
    parts += _bare(cone(loc=(0, -0.37, 1.07), r1=0.035, r2=0.0, depth=0.04, rot=(180, 0, 0), verts=3, mat=toon("#ff7a8a", shade=1.0, rim=0.0), smooth=False))
    # (a suit with a tail hole is a suit a cat might wear)
    parts.append(tube([(-0.3, 0.2, 0.24), (-0.66, 0.26, 0.2), (-0.84, 0.2, 0.52), (-0.72, 0.16, 0.74)], 0.075, mat=toon("#ff9a3a"), taper=(1.0, 0.6)))
    parts += _helmet((0, -0.02, 1.14), 0.56)
    return _turn(parts, (-20, 0, 10), (0, 0, 0.6))


def _satellite():
    def foil(co, n):
        k = math.sin(co.x * 41.0 + co.z * 37.0) * math.sin(co.y * 43.0 - co.z * 31.0)
        return mix(hexc("#ffd257"), hexc("#d29c2a"), 0.5 + 0.5 * k)
    body = cube(loc=(0, 0, 0.56), scale=(0.66, 0.66, 0.66), bevel=0.03)
    _dice(body, 6)
    _paint(body, foil, "foil", spec=0.3)
    parts = [body]

    def cells(co, n):
        line = int((co.x + 2.0) * 16.0) % 4 == 0 or int((co.y + 2.0) * 16.0) % 4 == 0
        return hexc("#9cc4ff") if line else hexc("#2f5cc4")
    for s in (1, -1):
        arm = tube([(s * 0.3, 0, 0.56), (s * 0.46, 0, 0.56)], 0.035, mat=toon("#9aa6b0"), res=2)
        panel = cube(loc=(s * 0.82, 0, 0.56), scale=(0.72, 0.84, 0.04))
        _dice(panel, 15)
        K.vcolor(panel, cells, per_face=True)
        panel.data.materials.append(toon(None, vcol="col", spec=0.25, emit=0.25, key=("find", "panel")))
        parts += [arm, _thin(panel, 0.7)]
    for a, b in (((-1.02, -0.2, 0.61), (-0.66, 0.2, 0.61)), ((-1.02, 0.2, 0.61), (-0.66, -0.2, 0.61))):     # it was mended, once, by someone
        parts += _bare(tube([a, b], 0.045, mat=toon("#e4e4dc", shade=1.0), res=2))
    dish = sphere(loc=(0, -0.08, 1.14), scale=(0.34, 0.34, 0.15), rot=(-30, 0, 0), mat=toon("#f2f4f6"))
    prong = tube([(0, -0.2, 1.2), (0, -0.28, 1.42)], 0.016, mat=toon("#9aa6b0"), res=2)
    tip = sphere(loc=(0, -0.28, 1.44), scale=0.045, mat=toon("#ff3b30", flat_glow=True))
    parts += [dish, _thin(prong, 0.5)] + _bare(tip)
    return _turn(parts, (-10, 12, 14), (0, 0, 0.6))


def _space_duck():
    import vf_life as LF
    parts = LF._build_duck()
    pack = cube(loc=(-0.24, 0.0, 0.8), scale=(0.46, 0.34, 0.24), mat=toon("#9aa6b0"), bevel=0.03)
    nozzle = cone(loc=(-0.54, 0.0, 0.8), r1=0.13, r2=0.07, depth=0.16, rot=(0, 90, 0), verts=12, mat=toon("#5a6470"))
    parts += [pack, nozzle]
    for r, ln, col in ((0.11, 0.5, "#ffb21f"), (0.06, 0.3, "#fff2a0")):      # (it did not need to go this fast)
        parts += _bare(cone(loc=(-0.62 - ln * 0.5, 0.0, 0.8), r1=r, r2=0.0, depth=ln, rot=(0, -90, 0), verts=10, mat=toon(col, flat_glow=True)))
    parts += _helmet((0.38, 0.0, 0.76), 0.47)
    parts.append(torus(loc=(0.38, 0.0, 0.42), R=0.27, r=0.05, mat=toon("#9aa6b0")))
    return _turn(parts, (-10, 0, -18), (0, 0, 0.4))


# ------------------------------------------------------------------- Alien
def _ufo():
    z = 1.86
    hull = sphere(loc=(0, 0, z), scale=(0.88, 0.88, 0.19), seg=48, rings=16)
    _paint(hull, lambda co, n: mix(hexc("#7f8d9a"), hexc("#d5dee4"), _s(co.z + 0.5)), "saucer", spec=0.2)
    band = torus(loc=(0, 0, z), R=0.84, r=0.045, mat=toon("#5a6470"), seg=48, mseg=8)
    parts = [hull, band]
    for i in range(10):                                     # lights, all of them the wrong colour
        a = i / 10 * math.tau
        parts += _bare(sphere(loc=(math.cos(a) * 0.79, math.sin(a) * 0.79, z + 0.03), scale=0.065, mat=toon("#ffe066" if i % 2 else "#b8ff6a", flat_glow=True), seg=10, rings=6))
    pilot = sphere(loc=(0, 0, z + 0.27), scale=(0.14, 0.13, 0.16), mat=toon("#8fe36a"))
    parts.append(pilot)
    for s in (1, -1):
        parts += _bare(sphere(loc=(s * 0.065, -0.11, z + 0.3), scale=(0.048, 0.03, 0.06), rot=(0, s * -20, 0), mat=toon("#141018", shade=1.0, rim=0.0), seg=10, rings=6))
    parts += _helmet((0, 0, z + 0.2), 0.33)
    beam_m = toon("#c6ff8a", flat_glow=True, alpha=0.22)
    beam_m.use_backface_culling = True
    parts += _bare(cone(loc=(0, 0, z * 0.5 - 0.06), r1=0.66, r2=0.3, depth=z - 0.12, verts=32, mat=beam_m))
    # today's fish, going up, tail first, against its will
    fish = _small_fish((0.02, -0.6, 0.78), 0.32, col="#ff9a2e", fin="#e0641c")
    eyes = _goggle((0.17, -0.8, 0.76), 0.1, look=(0.1, -0.6, 0.8), pupil=0.32)
    parts += _turn(fish + eyes, (0, 34, 0), (0.02, -0.6, 0.78))
    for x, zz, r in ((0.34, 0.44, 0.03), (-0.2, 0.36, 0.025), (0.08, 0.2, 0.02)):        # and what it was swimming in
        parts += _bare(sphere(loc=(x, -0.62, zz), scale=(r, r, r * 1.8), mat=toon("#e6f7ff", flat_glow=True), seg=10, rings=6))
    return parts


def _blob():
    body = sphere(loc=(0, 0, 0.04), scale=1.0, seg=64, rings=32)

    def goo(co):
        k = 1.0 + 0.09 * math.sin(math.atan2(co.y, co.x) * 7.0) * (0.5 - co.z * 0.5)    # a skirt that never quite stays up
        r = 0.86 if co.z < 0.1 else 0.86 - 0.16 * co.z ** 2
        return Vector((co.x * r * k, co.y * r * k * 0.88, co.z * 0.8 + 0.1 * co.z ** 2))
    K.deform(body, goo)
    _paint(body, lambda co, n: mix(hexc("#b03fd9"), hexc("#f08cff"), _s(co.z * 0.7 + 0.4)), "blob", spec=0.35)
    parts = [body]
    parts += _goggle((-0.32, -0.54, 0.54), 0.17, look=(-0.3, -0.7, 0.5), pupil=0.5)
    parts += _goggle((0.28, -0.56, 0.5), 0.2, look=(0.25, -0.7, 0.5), pupil=0.5)
    parts += _goggle((-0.02, -0.4, 0.9), 0.13, look=(0.0, -0.3, 0.9), pupil=0.5)
    mouth = sphere(loc=(0.0, -0.7, 0.26), scale=(0.22, 0.05, 0.08), mat=toon("#5a1430", shade=1.0, rim=0.0))
    tooth = cube(loc=(0.08, -0.74, 0.31), scale=(0.07, 0.015, 0.06), mat=toon("#fffdf0", shade=1.0))
    parts += _bare(mouth, tooth)
    for x, y, z, r in ((-0.54, -0.42, 0.2, 0.045), (0.5, -0.46, 0.14, 0.035), (0.34, -0.28, 0.84, 0.03)):    # things it ate
        parts += _bare(sphere(loc=(x, y, z), scale=r, mat=toon("#ffffff", flat_glow=True), seg=10, rings=6))
    return parts


def _glow_shroom():
    mound = sphere(loc=(0, 0, -0.02), scale=(0.98, 0.78, 0.26), seg=32, rings=12)
    _paint(mound, lambda co, n: mix(hexc("#2f3f4a"), hexc("#3fbf8a"), _s(co.z * 1.6)), "moss")
    parts = [mound]
    for x, y, h, r, col, spot in ((-0.14, 0.04, 0.92, 0.5, "#46f0e0", "#d9fffa"), (0.56, -0.2, 0.5, 0.29, "#b77dff", "#efe0ff"), (-0.62, -0.18, 0.36, 0.22, "#7dff9a", "#e8ffe8")):
        stem = tube([(x, y, 0.1), (x + 0.02, y, h * 0.55), (x, y, h)], 0.13 * r / 0.5 + 0.03, mat=toon("#e9e6d8"), taper=(1.2, 0.8))
        cap = sphere(loc=(x, y, h), scale=(r, r, r * 0.62), seg=32, rings=16)
        K.deform(cap, lambda co: Vector((co.x, co.y, max(co.z, -0.12))))

        def dots(co, n, col=col, spot=spot):
            c = hexc(col)
            h2 = math.sin(co.x * 8.0 + 1.0) * math.sin(co.y * 8.5 + 2.0)
            return hexc(spot) if h2 > 0.55 and co.z > 0.25 else mix(c, hexc("#ffffff"), 0.18 * max(co.z, 0.0))
        _paint(cap, dots, ("shroom", col), emit=0.72)
        parts += [stem, cap]
        parts += _bare(sphere(loc=(x, y, h + r * 0.1), scale=(r * 1.32, r * 1.32, r * 0.92), mat=toon(col, flat_glow=True, alpha=0.1), seg=24, rings=12))
    # the big one is asleep. Please be quiet
    dark = "#0d4a50"
    for s in (1, -1):
        parts += _bare(tube([(-0.14 + s * 0.27, -0.42, 0.98), (-0.14 + s * 0.18, -0.46, 0.93), (-0.14 + s * 0.09, -0.44, 0.98)], 0.02, mat=toon(dark, shade=1.0, rim=0.0), res=6))
    parts += _bare(sphere(loc=(-0.14, -0.47, 0.86), scale=(0.05, 0.015, 0.035), mat=toon(dark, shade=1.0, rim=0.0), seg=10, rings=6))
    return parts


# ------------------------------------------------------------------- Abyss
def _anglerfish():
    body = sphere(loc=(0, 0, 0.4), scale=(0.78, 0.62, 0.66), seg=48, rings=24)
    _paint(body, lambda co, n: mix(hexc("#3b4078"), hexc("#6a70b8"), _s(co.z * 0.8 + 0.5)), "angler")
    parts = [body]
    mouth = sphere(loc=(0.46, -0.32, 0.2), scale=(0.44, 0.34, 0.26), rot=(0, 12, -24), mat=toon("#190d26", shade=1.0, rim=0.0))
    lip = torus(loc=(0.5, -0.36, 0.2), R=0.36, r=0.05, rot=(90, 0, -24), scale=(1.1, 0.72, 1.0), mat=toon("#6a70b8"))
    parts += [mouth, _thin(lip, 0.5)]
    for x, h in ((0.2, 0.15), (0.34, 0.12), (0.48, 0.17), (0.62, 0.11), (0.76, 0.15)):
        parts.append(_thin(cone(loc=(x, -0.5 - (x - 0.2) * 0.18, 0.02), r1=0.05, r2=0.0, depth=h, verts=6, mat=toon("#fffdf0")), 0.4))
    for x, h in ((0.28, 0.1), (0.5, 0.12), (0.7, 0.09)):
        parts.append(_thin(cone(loc=(x, -0.46 - (x - 0.2) * 0.18, 0.36), r1=0.04, r2=0.0, depth=h, rot=(180, 0, 0), verts=6, mat=toon("#fffdf0")), 0.4))
    parts += _goggle((0.22, -0.52, 0.72), 0.1, look=(0.5, -0.8, 0.0), pupil=0.32)
    tail = cone(loc=(-0.92, 0, 0.46), r1=0.3, r2=0.0, depth=0.42, rot=(0, 90, 0), verts=4, mat=toon("#4f549a"), smooth=False)
    tail.scale = (1.0, 0.25, 1.0)
    fin = sphere(loc=(-0.1, -0.62, 0.32), scale=(0.26, 0.05, 0.14), rot=(0, 20, -8), mat=toon("#4f549a"))
    parts += [tail, fin]
    # the lure: he could not find a real one. It is from a kitchen
    parts.append(_thin(tube([(0.0, -0.1, 1.04), (0.12, -0.14, 1.4), (0.52, -0.2, 1.52), (0.74, -0.24, 1.3)], 0.024, mat=toon("#3b4078"), res=10), 0.6))
    base = cyl(loc=(0.75, -0.24, 1.26), r=0.06, depth=0.09, verts=12, mat=toon("#a9b2b8"))
    bulb = sphere(loc=(0.76, -0.25, 1.1), scale=(0.135, 0.135, 0.15), mat=toon("#fff2a0", flat_glow=True))
    halo = sphere(loc=(0.76, -0.25, 1.1), scale=0.27, mat=toon("#ffe066", flat_glow=True, alpha=0.2), seg=20, rings=10)
    parts += [_thin(base, 0.6), _thin(bulb, 0.5)] + _bare(halo)
    return parts


def _tiny_sub():
    hull = sphere(loc=(0, 0, 0.32), scale=(0.98, 0.44, 0.44), seg=48, rings=24)
    _paint(hull, lambda co, n: mix(hexc("#e0a810"), hexc("#ffdb3a"), _s(co.z + 0.6)), "sub", spec=0.2)
    tower = cyl(loc=(0.02, 0, 0.84), r=0.24, depth=0.34, verts=24, mat=toon("#ffcf2a"))
    cap = sphere(loc=(0.02, 0, 1.01), scale=(0.24, 0.24, 0.07), mat=toon("#e0a810"))
    scope = tube([(0.14, -0.05, 1.04), (0.14, -0.05, 1.3), (0.28, -0.14, 1.34)], 0.032, mat=toon("#7d8a96"), res=6)
    glass = sphere(loc=(0.3, -0.16, 1.34), scale=0.05, mat=toon("#9fe3ff", flat_glow=True))
    parts = [hull, tower, cap, _thin(scope, 0.6)] + _bare(glass)
    for x in (-0.46, 0.0, 0.46):
        y = -0.37 if x else -0.43
        z = 0.42
        parts.append(_thin(torus(loc=(x, y, z), R=0.13, r=0.03, rot=(90 - 30, 0, 0), mat=toon("#c2861a"), seg=20, mseg=8), 0.5))
        parts += _bare(sphere(loc=(x, y + 0.005, z), scale=(0.12, 0.02, 0.12), rot=(-30, 0, 0), mat=toon("#7fd8e8", flat_glow=True)))
    # the crew: one
    parts += _bare(sphere(loc=(0, -0.43, 0.43), scale=(0.06, 0.012, 0.07), rot=(-30, 0, 0), mat=toon("#1f3a52", flat_glow=True)))
    parts += _bare(sphere(loc=(0, -0.44, 0.5), scale=(0.075, 0.012, 0.022), rot=(-30, 0, 0), mat=toon("#e5533d", flat_glow=True)))
    fin_t = cone(loc=(-1.04, 0, 0.56), r1=0.2, r2=0.0, depth=0.3, rot=(0, -60, 0), verts=4, mat=toon("#e5533d"), smooth=False)
    fin_t.scale = (1.0, 0.25, 1.0)
    hub = sphere(loc=(-1.08, 0, 0.32), scale=(0.07, 0.07, 0.07), mat=toon("#7d8a96"))
    parts += [fin_t, hub]
    for a in (0, 120, 240):
        d = Vector((0, math.cos(math.radians(a)), math.sin(math.radians(a))))
        parts.append(_thin(sphere(loc=Vector((-1.12, 0, 0.32)) + d * 0.15, scale=(0.02, 0.07, 0.13), rot=(a, 0, 0), mat=toon("#e5533d")), 0.5))
    return _turn(parts, (0, -5, 0), (0, 0, 0.3))


def _sunken_tv():
    wood = toon("#7c5230")
    box = cube(loc=(0, 0, 0.6), scale=(1.5, 1.04, 1.14), mat=wood, bevel=0.08)
    frame = cube(loc=(-0.14, -0.53, 0.62), scale=(1.08, 0.04, 0.88), mat=toon("#2b2622"), bevel=0.015)
    parts = [box, frame]
    # the picture: colour bars, which is all that is on at this depth
    bars = ["#f4f4f4", "#ffd83a", "#3fd8d8", "#4fd65a", "#e84ad8", "#e8433f", "#3a5ae8"]
    for i, c in enumerate(bars):
        parts += _bare(cube(loc=(-0.14 - 0.44 + i * 0.88 / 6, -0.555, 0.7), scale=(0.88 / 6 + 0.002, 0.008, 0.52), mat=toon(c, flat_glow=True)))
    parts += _bare(cube(loc=(-0.14, -0.555, 0.34), scale=(0.88 + 0.147, 0.008, 0.2), mat=toon("#20242c", flat_glow=True)))
    for z in (0.9, 0.62):                                   # the knobs
        k = cyl(loc=(0.58, -0.54, z), r=0.085, depth=0.06, rot=(90, 0, 0), verts=12, mat=toon("#d6c090"))
        parts.append(_thin(k, 0.6))
    for s, lean in ((-1, -0.42), (1, 0.48)):
        parts.append(_thin(tube([(s * 0.06, 0, 1.14), (lean * 0.6, 0.02, 1.52), (lean, 0.04, 1.84)], 0.016, mat=toon("#a9b2b8"), res=3), 0.5))
        parts.append(sphere(loc=(lean, 0.04, 1.86), scale=0.04, mat=toon("#a9b2b8"), seg=10, rings=6))
    parts.append(cyl(loc=(0, 0, 1.2), r=0.14, depth=0.06, verts=16, mat=toon("#2b2622")))
    for x, w in ((-0.7, 0.0), (0.72, 0.14)):               # weed, from the time it spent on the bottom
        parts.append(_thin(tube([(x, -0.54, 0.12), (x - 0.04 + w, -0.58, 0.46), (x + 0.03 + w, -0.58, 0.76)], 0.035, mat=toon("#3fa86a"), taper=(1.0, 0.25)), 0.5))
    for a in range(5):                                      # a starfish moved in
        th = a / 5 * math.tau + 0.3
        parts.append(_thin(sphere(loc=(0.56 + math.cos(th) * 0.075, -0.56, 0.2 + math.sin(th) * 0.075), scale=(0.08, 0.02, 0.03), rot=(0, -math.degrees(th), 0), mat=toon("#ff8a4a")), 0.4))
    return _turn(parts, (-26, 10, 6), (0, 0, 0.0))


BUILD = {"otter": _otter, "frog": _frog, "old_boot": _old_boot,
         "capybara": _capybara, "lava_crab": _lava_crab, "marshmallow": _marshmallow,
         "turtle": _turtle, "fake_fin": _fake_fin, "treasure": _treasure,
         "cloud_sheep": _cloud_sheep, "kite": _kite, "paper_plane": _paper_plane,
         "astro_cat": _astro_cat, "satellite": _satellite, "space_duck": _space_duck,
         "ufo": _ufo, "blob": _blob, "glow_shroom": _glow_shroom,
         "anglerfish": _anglerfish, "tiny_sub": _tiny_sub, "sunken_tv": _sunken_tv}
RESIDENTS = tuple(BUILD)
# (these sit in the water or on something that does, so what is under the surface goes)
WET = {"otter", "frog", "old_boot", "marshmallow", "turtle", "fake_fin", "treasure", "glow_shroom", "blob", "anglerfish", "tiny_sub", "sunken_tv"}


def build(kind):
    parts = BUILD[kind]()
    return TD.clip_below(parts, 0.0) if kind in WET else parts

"""Gerald and his mum, built from scratch: fat, solid and cross. vf_life renders them: close up from the side for the
mini-game (which draws their eyes and mouths on top, so the eyes here only say where those go), and Gerald from the game's
camera as the big dark shape that swims past the boat. They dress for every stage of the chase (the outfits below).
Everything faces +X and the camera's side is y < 0. A part's "wob" says how it moves (pose()).
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Quaternion, Vector

import vf_kit as K
from vf_kit import cone, hexc, ico, mix, sphere, toon, tube, vcolor

RIVALS = {
    "Gerald": dict(rival=True, top="#8fa24e", belly="#f4ecc2", blotch="#566a32", fin="#c8743a", fin2="#8a4522",
                   hair="#4a2c18", hair2="#8a5c36", mouth=(1.04, -0.3, -0.41), eye=(0.6, 0.17), eye_r=0.15),
    "Geraldine": dict(rival=True, mum=True, top="#7fa27a", belly="#f6f0d4", blotch="#517458", fin="#d9708a", fin2="#a3425e",
                      hair="#2f2430", hair2="#dcd2ea", mouth=(1.1, -0.2, -0.13), eye=(0.6, 0.17), eye_r=0.15),
}
# a look for every stage of the chase (docs/MISSING_LIST.md part 3): who wears it, the outfit, and what else moves for it
LOOKS = {"gerald_lava": ("Gerald", "lava", {}), "gerald_pirate": ("Gerald", "pirate", {}), "gerald_pilot": ("Gerald", "pilot", {}),
         "geraldine_astro": ("Geraldine", "astro", {"bow_at": (0.25, -0.12, 1.17)}),
         "geraldine_alien": ("Geraldine", "alien", {"bow_at": (0.06, -0.2, 1.12)}),
         "geraldine_lamp": ("Geraldine", "lamp", {"bow_at": (0.0, -0.2, 1.1), "pearl_glow": 0.35})}
for _look, (_who, _outfit, _more) in LOOKS.items():
    RIVALS[_look] = dict(RIVALS[_who], outfit=_outfit, **_more)
TOP_H, BELLY_H, WIDE = 0.8, 0.86, 0.72
FOLDS = ((0.62, 0.07),)                 # (his chins: where along him, how deep)


def _shape(co):
    """a sphere -> a fat fish: a barrel that only narrows at the very end, a belly that hangs, a chin and a fold in it"""
    x = co.x
    k = 1.0 if x > -0.3 else max(0.14, 1.0 - 0.62 * ((-0.3 - x) / 0.55) ** 2)
    if co.z > 0:
        z = co.z * TOP_H
    else:
        low = min(1.0, -co.z / 0.6)
        z = -(-co.z) ** 0.86 * BELLY_H * (1.0 + 0.12 * math.exp(-((x + 0.1) / 0.7) ** 2))
        for at, deep in FOLDS:
            z *= 1.0 - deep * low * math.exp(-((x - at) / 0.05) ** 2)
    return Vector((x, co.y * WIDE * k, z * k))


def _smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def _body(spec):
    top, belly, blotch = hexc(spec["top"]), hexc(spec["belly"]), hexc(spec["blotch"])
    body = sphere(scale=1.0, seg=176, rings=88)
    K.deform(body, _shape)
    scale_s = 0.17

    def paint(co, n):
        x, z = co.x, co.z
        c = mix(belly, top, _smooth((z + 0.14 + 0.05 * math.sin(x * 9.0)) / 0.3))
        if x < 0.3 and z > -0.12:                                   # big old scales
            row = round(z / (scale_s * 0.8))
            ox = (row % 2) * scale_s * 0.5
            cx, cz = round((x - ox) / scale_s) * scale_s + ox, row * scale_s * 0.8
            d = math.hypot(x - cx, (z - cz) * 1.1)
            if d > scale_s * 0.4 and x < cx:
                c = mix(c, blotch, 0.42)
        for xs, w in ((-0.62, 0.11), (-0.2, 0.15), (0.24, 0.13)):   # dark saddles over the back
            if abs(x - xs) < w * (0.75 + 0.3 * math.sin(z * 13.0 + xs * 7.0)) and z > 0.14 + 0.06 * math.sin(x * 17.0):
                c = mix(c, blotch, 0.82)
        for at, _ in FOLDS:                                         # (they crease)
            if abs(x - at + (z + 0.8) * 0.08) < 0.016 and z < -0.5:
                c = mix(c, hexc("#a08c64"), 0.7)
        if spec.get("mum") and co.y < 0:                            # rouge
            c = mix(c, hexc("#ec7f8c"), 0.55 * _smooth(1.0 - math.hypot((x - 0.66) / 0.22, (z + 0.2) / 0.14)))
        return c
    vcolor(body, paint)
    body.data.materials.append(toon(None, vcol="col", spec=0.1, key=("rival", spec["top"])))
    body["wob"] = "body"
    return body


def _near(body, x, z):
    """y of the body's side that faces the camera, here"""
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    hit, loc, _, _ = ev.ray_cast(Vector((x, -5.0, z)), Vector((0, 1, 0)))
    return loc.y if hit else -0.05


def _over(x, y):
    """z of the top of the head, here"""
    return TOP_H * math.sqrt(max(1.0 - x * x - (y / WIDE) ** 2, 0.0))


def _fan(spec, root, a0, a1, reach, rays, thick=0.045, flare=0.0, notch=None, wob="fin"):
    """a real fin, not a sheet: a fan of rays from the root in the XZ plane (degrees from +X toward +Z), thick in the
    middle and thin at the rim, its edge scalloped between the rays. notch: the bit somebody bit out of it (0..1 across)"""
    bm = bmesh.new()
    nu, nv = rays * 8, 9
    a0, a1 = math.radians(a0), math.radians(a1)
    rx, ry, rz = root

    def point(i, j, s):
        u, v = i / nu, j / nv
        a = a0 + (a1 - a0) * u
        r = reach * (1.0 + 0.09 * math.cos(u * math.tau * rays))
        if notch is not None:
            r *= 1.0 - 0.42 * math.exp(-((u - notch) / 0.07) ** 2)
        t = thick * math.sin(math.pi * u) ** 0.5 * math.sin(math.pi * v) ** 0.5 * (1.0 + 0.3 * math.cos(u * math.tau * rays))
        return (rx + math.cos(a) * r * v, ry + flare * v + s * t, rz + math.sin(a) * r * v)
    grid = {}
    for s in (1, -1):
        for i in range(nu + 1):
            for j in range(nv + 1):
                grid[(s, i, j)] = bm.verts.new(point(i, j, s))
    for s in (1, -1):
        for i in range(nu):
            for j in range(nv):
                q = [grid[(s, i, j)], grid[(s, i + 1, j)], grid[(s, i + 1, j + 1)], grid[(s, i, j + 1)]]
                bm.faces.new(q if s > 0 else q[::-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("fin")
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new("fin", me)
    bpy.context.collection.objects.link(ob)
    fin, fin2 = hexc(spec["fin"]), hexc(spec["fin2"])

    def paint(co, n):
        dx, dz = co.x - rx, co.z - rz
        u = ((math.atan2(dz, dx) - a0) % math.tau) / (a1 - a0)
        c = mix(fin2, fin, min(1.0, math.hypot(dx, dz) / reach * 1.5))
        if math.cos(u * math.tau * rays) > 0.72:
            c = mix(c, fin2, 0.75)
        return c
    vcolor(ob, paint)
    ob.data.materials.append(toon(None, vcol="col", key=("rivalfin", spec["fin"])))
    ob["wob"] = wob
    ob["root"] = root
    ob["outline_even"] = False          # (the rim is so thin that an even outline would shoot out in spikes)
    return ob


def _strand(points, radii, mat, wob="tash", k=1.0):
    ob = tube(points, 1.0, mat=mat, radii=radii, res=12)
    ob["wob"] = wob
    ob["outline_k"] = k
    return ob


def _moustache(spec):
    """the pride of the family: from under his nose, back over both cheeks, the tips curled up and out so you can see
    them from above too"""
    dark, light = toon(spec["hair"]), toon(spec["hair2"])
    parts = []
    for s in (-1, 1):
        parts.append(_strand([(1.1, s * 0.02, -0.06), (0.96, s * 0.3, -0.19), (0.72, s * 0.6, -0.24), (0.46, s * 0.8, -0.17), (0.3, s * 1.0, 0.0), (0.2, s * 1.1, 0.17), (0.29, s * 1.12, 0.3), (0.37, s * 1.1, 0.22)],
                             [0.08, 0.125, 0.125, 0.09, 0.06, 0.035, 0.02, 0.012], dark))
        parts.append(_strand([(1.02, s * 0.22, -0.12), (0.86, s * 0.58, -0.19), (0.66, s * 0.8, -0.2), (0.5, s * 0.92, -0.15)],
                             [0.02, 0.04, 0.04, 0.01], light, k=0.35))
        parts.append(_strand([(0.9, s * 0.42, -0.3), (0.76, s * 0.64, -0.35), (0.62, s * 0.74, -0.33)],
                             [0.02, 0.05, 0.012], dark, k=0.6))
    return parts


def _eyebrows(spec):
    """thick, furious, and they have never met a comb"""
    hair = toon(spec["hair"])
    ex, ez = spec["eye"]
    parts = []
    for s in (-1, 1):
        pts = [(ex - 0.36, s * 0.36, ez + 0.5), (ex - 0.06, s * 0.38, ez + 0.42), (ex + 0.27, s * 0.26, ez + 0.28)]
        parts.append(_strand(pts, [0.06, 0.115, 0.07], hair, wob="brow"))
        for t, lean in ((0.08, -30), (0.25, 14), (0.42, -12), (0.6, 22), (0.76, -6), (0.92, 34)):
            x = pts[0][0] + (pts[2][0] - pts[0][0]) * t
            z = pts[0][2] + (pts[2][2] - pts[0][2]) * t + 0.08
            c = cone(loc=(x, s * (0.38 - abs(t - 0.5) * 0.14), z + 0.03), r1=0.035, r2=0.0, depth=0.12, verts=8, rot=(0, lean, 0), mat=hair)
            c["outline_k"] = 0.4
            c["wob"] = "brow"
            parts.append(c)
    return parts


def _face_eyes(spec, body):
    """(only says where the mini-game draws its eyes)"""
    ex, ez = spec["eye"]
    y = _near(body, ex, ez)
    parts = []
    for s in (1, -1):
        e = sphere(loc=(ex, s * y, ez), scale=spec["eye_r"], mat=toon("#ffffff"))
        e["no_outline"] = True
        e["wob"] = "still"
        parts.append(e)
    return parts


def _old_hooks():
    """the one that got away, many times: rusty hooks in his lip and the line he snapped"""
    steel, line = toon("#a9b2b8"), toon("#eef2f0")
    parts = []
    for x, y, z in ((1.08, -0.14, -0.5), (0.88, -0.3, -0.55)):
        h = tube([(x, y, z + 0.05), (x + 0.01, y, z - 0.08), (x - 0.03, y, z - 0.15), (x - 0.11, y, z - 0.11), (x - 0.12, y, z - 0.05)], 0.019, mat=steel, res=8)
        h["outline_k"] = 0.45
        h["wob"] = "lip"
        parts.append(h)
    a = tube([(1.08, -0.14, -0.46), (1.17, -0.2, -0.66), (1.03, -0.26, -0.84), (1.11, -0.28, -1.02)], 0.0095, mat=line, res=10)
    a["outline_k"] = 0.32
    a["wob"] = "line"
    parts.append(a)
    return parts


def _on_skin(ob, body, lift):
    """a flat thing in the XZ plane -> lying on the body's side, like ink"""
    bpy.context.view_layer.update()
    me = ob.data
    me.transform(ob.matrix_world)
    ob.location, ob.rotation_euler, ob.scale = (0, 0, 0), (0, 0, 0), (1, 1, 1)
    for v in me.vertices:
        v.co.y = _near(body, v.co.x, v.co.z) - lift
    me.update()
    ob["decal"] = ob["no_outline"] = True
    ob["wob"] = "body"


def _tattoo(body):
    """a heart on his flank, and whose name is in it"""
    at_x, at_z, size = -0.22, 0.12, 0.34
    outline = []
    for i in range(72):
        t = i / 72 * math.tau
        outline.append((at_x + size * math.sin(t) ** 3, at_z + size * (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 16))
    me = bpy.data.meshes.new("heart")
    bm = bmesh.new()
    rings = []
    for t in (0.14, 0.28, 0.42, 0.56, 0.7, 0.85, 1.0):          # (rings, so it can follow the curve of the belly)
        rings.append([bm.verts.new((at_x + (x - at_x) * t, 0, at_z + (z - at_z) * t)) for x, z in outline])
    bm.faces.new(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(len(a)):
            bm.faces.new((a[i], a[(i + 1) % len(a)], b[(i + 1) % len(a)], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    heart = bpy.data.objects.new("heart", me)
    bpy.context.collection.objects.link(heart)
    heart.data.materials.append(toon("#d8423f", shade=0.9))
    _on_skin(heart, body, 0.012)
    cu = bpy.data.curves.new("mum", "FONT")
    cu.body = "MUM"
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.offset = 0.012
    txt = bpy.data.objects.new("mum", cu)
    bpy.context.collection.objects.link(txt)
    txt.rotation_euler = (math.radians(90), 0, 0)
    txt.scale = (0.2, 0.26, 0.26)
    txt.location = (at_x, 0, at_z + 0.03)
    bpy.ops.object.select_all(action="DESELECT")
    txt.select_set(True)
    bpy.context.view_layer.objects.active = txt
    bpy.ops.object.convert(target="MESH")
    txt = bpy.context.active_object
    txt.data.materials.clear()
    txt.data.materials.append(toon("#fff4d8", flat_glow=True))
    _on_skin(txt, body, 0.024)
    return [heart, txt]


def _fins(spec, body, torn=True):
    parts = [
        _fan(spec, (-0.86, 0, 0.0), 140, 220, 0.62, 4, thick=0.05, notch=0.7 if torn else None, wob="tail"),
        _fan(spec, (-0.12, 0, 0.5), 66, 168, 0.6, 5, thick=0.05, notch=0.46 if torn else None, wob="dorsal"),
        _fan(spec, (-0.46, 0, -0.46), 205, 268, 0.34, 3, thick=0.035, wob="fin"),
    ]
    near = _near(body, 0.2, -0.36)
    for s in (-1, 1):                                           # paddles, far too small for all that fish
        paddle = _fan(spec, (0.2, s * -near, -0.36), 172, 262, 0.3, 3, thick=0.04, flare=s * 0.18, wob="paddle")
        paddle["part"] = "paddle"
        parts.append(paddle)
        parts.append(_fan(spec, (0.34, s * 0.3, -0.76), 200, 262, 0.2, 2, thick=0.03, flare=s * 0.06, wob="paddle"))
    return parts


def build_gerald(spec, details=True):
    body = _body(spec)
    bpy.context.view_layer.update()
    parts = [body] + _fins(spec, body)
    parts += _face_eyes(spec, body) + _eyebrows(spec) + _moustache(spec)
    nose = sphere(loc=(1.07, 0.0, 0.08), scale=(0.18, 0.2, 0.165), mat=toon("#d9685e", spec=0.25))
    nose["wob"] = "still"
    lip = sphere(loc=(0.99, 0.0, -0.43), scale=(0.23, 0.32, 0.125), mat=toon("#c8675a"))
    lip["wob"] = "lip"
    # his last hair, and he is very proud of it
    hair = tube([(0.24, 0, 0.76), (0.27, 0, 0.95), (0.39, 0, 1.03), (0.49, 0, 0.94)], 0.024, mat=toon(spec["hair"]), res=8)
    hair["outline_k"] = 0.5
    hair["wob"] = "brow"
    hair["part"] = "hair"
    parts += [nose, lip, hair]
    if details:
        parts += _old_hooks() + _tattoo(body)
    return parts


def _pearls(body, glow=0.0):
    """a good string of pearls, round her neck and resting on all that bosom, and a smaller one for Sundays"""
    pearl = toon("#fbf6ec", spec=0.5, rim=0.25, emit=glow)
    out = []
    for n, x0, reach, r, lift in ((13, -0.08, 0.32, 0.078, 0.04), (11, -0.16, 0.24, 0.052, 0.03)):
        for i in range(n):
            t = i / (n - 1)
            x, z = x0 + reach * math.sin(math.pi * t) ** 0.8, 0.5 - 1.14 * t
            p = ico(loc=(x, _near(body, x, z) - lift, z), scale=r, mat=pearl, sub=3, smooth=True)
            p["outline_k"] = 0.45
            p["wob"] = "pearl"
            out.append(p)
    return out


def _bow(at=(0.2, -0.2, 1.08)):
    """big. Bigger. It is held on by willpower"""
    silk, dark = toon("#ec3f78", spec=0.2), toon("#b42658")
    out = []
    at = Vector(at)
    for s in (-1, 1):
        lobe = sphere(scale=1.0, seg=32, rings=20, mat=silk)

        def fold(co, s=s):
            u = (co.x + 1.0) * 0.5                              # 0 at the knot .. 1 at the far end
            flare = 0.26 + 0.74 * u ** 0.8
            return Vector((s * u * 0.66, co.y * 0.13 + 0.06 * math.sin(u * 3.0), co.z * 0.38 * flare + 0.13 * u * u))
        K.deform(lobe, fold)
        lobe.location = at
        lobe["wob"] = "bow"
        lobe["root"] = tuple(at)
        crease = K.tube([at + Vector((s * 0.08, -0.13, 0.02)), at + Vector((s * 0.3, -0.16, 0.03)), at + Vector((s * 0.5, -0.14, 0.12))], 0.012, mat=dark, res=6)
        crease["decal"] = crease["no_outline"] = True
        crease["wob"] = "bow"
        crease["root"] = tuple(at)
        out += [lobe, crease]
    knot = sphere(loc=at + Vector((0, -0.08, 0.0)), scale=(0.13, 0.1, 0.13), mat=silk)
    knot["wob"] = "still"
    out.append(knot)
    return out


def _perm(spec):
    """a shampoo and set, every Friday since 1962"""
    curl = toon(spec["hair2"])
    out = []
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(52):
        t = (i + 0.5) / 52
        r = 0.56 * math.sqrt(t)
        a = golden * i
        x, y = 0.28 + r * math.cos(a), r * math.sin(a) * 1.05
        c = ico(loc=(x, y, _over(x, y) + 0.06), scale=0.125, mat=curl, sub=2, smooth=True)
        c["outline_k"] = 0.55
        c["wob"] = "still"
        out.append(c)
    return out


def build_geraldine(spec):
    """(the mini-game draws her one thin eyebrow, already raised at you)"""
    body = _body(spec)
    bpy.context.view_layer.update()
    parts = [body] + _fins(spec, body, torn=False)
    parts += _face_eyes(spec, body)
    ex, ez = spec["eye"]
    lash = toon(spec["hair"])
    y = _near(body, ex - 0.3, ez)
    for a in (150, 172, 194):                                   # lashes, out past the eye the mini-game draws
        d = Vector((math.cos(math.radians(a)), 0, math.sin(math.radians(a))))
        c = tube([Vector((ex, y - 0.02, ez)) + d * 0.3, Vector((ex, y - 0.06, ez + 0.03)) + d * 0.46], 0.02, mat=lash, taper=(1.0, 0.2), res=4)
        c["outline_k"] = 0.3
        c["wob"] = "still"
        parts.append(c)
    # a mouth like a closed purse
    upper = sphere(loc=(1.01, 0.0, -0.08), scale=(0.15, 0.24, 0.085), mat=toon("#d42c4f", spec=0.3))
    lower = sphere(loc=(0.99, 0.0, -0.21), scale=(0.17, 0.26, 0.105), mat=toon("#e83a5e", spec=0.3))
    for o in (upper, lower):
        o["wob"] = "still"
    parts += [upper, lower]
    parts += _perm(spec) + _pearls(body, spec.get("pearl_glow", 0.0)) + _bow(spec.get("bow_at", (0.2, -0.2, 1.08)))
    return parts


# ------------------------------------------------------------------- outfits
# Whatever they wear, his moustache, MUM and underbite stay in sight, and her perm, bow and pearls: it's obviously the
# same fish. Nothing goes where the mini-game draws the eye (round spec["eye"], about twice the marker, a brow above
# it) or the mouth, so caps stop above the brows and glasses are pushed up.
def _skin(x, a, lift=0.0):
    """a point on the top half of the fish: x along it, a degrees round from the top of the back (+ toward the camera)"""
    k = 1.0 if x > -0.3 else max(0.14, 1.0 - 0.62 * ((-0.3 - x) / 0.55) ** 2)
    r = math.sqrt(max(1.0 - x * x, 0.0)) * k
    t = math.radians(a)
    return Vector((x, -math.sin(t) * (WIDE * r + lift), math.cos(t) * (TOP_H * r + lift)))


def _round(body, x, a, lift=0.0, mid=-0.05):
    """the point on the fish at x, a degrees round from the top: all the way round, belly and all"""
    d = Vector((0.0, -math.sin(math.radians(a)), math.cos(math.radians(a))))
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    hit, loc, _n, _i = ev.ray_cast(Vector((x, 0.0, mid)) + d * 3.0, -d)
    return loc + d * lift if hit else Vector((x, 0.0, mid)) + d * 0.8


def _edge(x):
    """how far down the side a cap may come, here: above his brows in front, lower behind them"""
    return 18.0 + 37.0 * _smooth((0.3 - x) / 0.25)


def _shell(fn, nu, nv, thick, mat=None):
    """a curved piece with a real thickness, so it gets an outline: fn(u, v) -> point, u and v from 0 to 1"""
    verts = [tuple(fn(i / nu, j / nv)) for i in range(nu + 1) for j in range(nv + 1)]
    faces = [(i * (nv + 1) + j, (i + 1) * (nv + 1) + j, (i + 1) * (nv + 1) + j + 1, i * (nv + 1) + j + 1) for i in range(nu) for j in range(nv)]
    me = bpy.data.meshes.new("shell")
    me.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new("shell", me)
    bpy.context.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    mod = ob.modifiers.new("thick", "SOLIDIFY")
    mod.thickness = thick
    mod.offset = 0.0
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    if mat is not None:
        me.materials.append(mat)
    ob["outline_even"] = False
    return ob


def _curve(points, u):
    """a smooth way through the points (Catmull-Rom), u from 0 to 1"""
    n = len(points) - 1
    f = min(max(u, 0.0) * n, n - 1e-6)
    i = int(f)
    t = f - i
    p0, p1, p2, p3 = (Vector(points[max(i - 1, 0)]), Vector(points[i]), Vector(points[i + 1]), Vector(points[min(i + 2, n)]))
    return 0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t ** 3)


def _ribbon(points, width, mat=None, taper=1.0, thick=0.025, n=40, twist=0.0):
    """a strip of cloth along the points, its flat side to the camera. twist: how far it turns over as it goes"""
    def at(u, v):
        p = _curve(points, u)
        d = (_curve(points, min(u + 0.01, 1.0)) - _curve(points, max(u - 0.01, 0.0))).normalized()
        side = d.cross(Vector((0.0, -1.0, 0.0))).normalized()
        if twist:
            side = Quaternion(d, twist * math.sin(u * math.pi * 2.5)) @ side
        return p + side * (v - 0.5) * width * (1.0 - (1.0 - taper) * u)
    return _shell(at, n, 2, thick, mat)


def _coil(a, b, turns=6, r=0.03, n=8):
    """a spring from a to b"""
    a, b = Vector(a), Vector(b)
    d = (b - a).normalized()
    e1 = d.cross(Vector((0.0, 1.0, 0.0))).normalized()
    e2 = d.cross(e1)
    pts = []
    for i in range(turns * n + 1):
        t = i / (turns * n)
        w = t * turns * math.tau
        pts.append(a.lerp(b, t) + (e1 * math.cos(w) + e2 * math.sin(w)) * r * min(1.0, t * 8.0, (1.0 - t) * 8.0))
    return pts


def _dots(base, dot, every=0.13, r=0.032):
    """polka dots, laid round the fish"""
    b, d = hexc(base), hexc(dot)

    def paint(co, n):
        u = co.x / every
        w = math.atan2(-co.y, co.z) * 0.78 / every
        row = math.floor(w)
        u += (row % 2) * 0.5
        dx, dw = (u - math.floor(u) - 0.5) * every, (w - row - 0.5) * every
        return d if dx * dx + dw * dw < r * r else b
    return paint


def _dress(ob, paint, key):
    vcolor(ob, paint)
    ob.data.materials.clear()
    ob.data.materials.append(toon(None, vcol="col", key=("rivaldress", key)))
    return ob


def _bare(*obs):
    """no outline, and never taken for the eye marker (vf_life.render_mini)"""
    for o in obs:
        o["decal"] = o["no_outline"] = True
    return list(obs)


def _wob(obs, kind, root=None):
    """how they move (pose()). And no even outline: on a tube with a tight bend it shoots out a long spike"""
    for o in obs:
        o["wob"] = kind
        o["outline_even"] = False
        if root is not None:
            o["root"] = tuple(root)
    return list(obs)


def _take(parts, tag):
    """leave a part of the fish out (under a helmet, say)"""
    out = []
    for p in parts:
        if p.get("part") == tag:
            bpy.data.objects.remove(p)
        else:
            out.append(p)
    return out


def _turned(ob, face, at):
    """point the object's own +Z along face, and put it at"""
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(Vector(face).normalized())
    ob.location = at
    return ob


def _mitts(body):
    """oven gloves where his paddles were: quilted, cuffs turned back, a thumb each"""
    parts = []
    near = _near(body, 0.2, -0.36)

    def quilt(co, n):
        q = abs(math.sin((co.x + co.z) * 42.0)) < 0.18 or abs(math.sin((co.x - co.z) * 42.0)) < 0.18
        return hexc("#a8322a") if q else hexc("#e2513f")
    for y0 in (near, -near):
        out = 1.0 if y0 > 0 else -1.0
        root = Vector((0.2, y0, -0.36))
        d = Vector((math.cos(math.radians(225.0)), out * 0.45, math.sin(math.radians(225.0)))).normalized()
        q = Vector((1.0, 0.0, 0.0)).rotation_difference(d)
        mitt = sphere(seg=32, rings=16)
        K.deform(mitt, lambda co: Vector((co.x * 0.25, co.y * 0.125, co.z * 0.17)))
        _dress(mitt, quilt, "mitt")
        thumb = sphere(scale=(0.09, 0.065, 0.08), mat=toon("#e2513f"))
        cuff = K.cyl(r=0.13, depth=0.08, verts=24, mat=toon("#f2e8d2"))
        for o, local in ((mitt, Vector((0.27, 0.0, 0.0))), (thumb, Vector((0.17, 0.0, 0.15)))):
            o.rotation_mode = "QUATERNION"
            o.rotation_quaternion = q
            o.location = root + q @ local
        _turned(cuff, d, root + d * 0.035)
        parts += _wob([mitt, thumb, cuff], "paddle", root)
    return parts


def _lava(spec, parts):
    """Volcanic: a fireproof helmet, a size too small, with the visor pushed up; oven gloves where his paddles were"""
    body = parts[0]
    parts = _take(_take(parts, "hair"), "paddle")
    silver, rib, gold = toon("#d6dee5", spec=0.55, rim=0.25), toon("#8d99a5", spec=0.3), toon("#ef9f26", spec=0.8, rim=0.35)
    c = Vector((0.36, 0.0, 0.84))
    dome = sphere(seg=48, rings=24, mat=silver)
    K.deform(dome, lambda co: Vector((co.x * 0.48, co.y * 0.54, max(co.z, -0.2) * 0.42)))
    dome.location = c
    crest = tube([c + Vector((0.48 * math.cos(t), 0.0, 0.45 * math.sin(t))) for t in (1.75, 2.1, 2.45, 2.8)], 0.05, mat=rib, res=8)
    brim = sphere(seg=48, rings=12, mat=silver)
    K.deform(brim, lambda co: Vector((co.x * (0.6 if co.x > 0 else 0.84), co.y * 0.62, co.z * 0.035)))
    brim.location = c + Vector((-0.06, 0.0, -0.07))
    brim.rotation_euler = (0.0, math.radians(-8.0), 0.0)

    # the face shield, flipped up out of the way: tinted gold, on a hinge each side
    def visor(u, v, out=0.0):
        az, el = math.radians(-80.0 + 160.0 * u), math.radians(4.0 + 60.0 * v)
        return c + Vector((math.cos(el) * math.cos(az) * (0.53 + out), math.cos(el) * math.sin(az) * (0.59 + out), math.sin(el) * (0.47 + out)))
    shield = _shell(visor, 32, 12, 0.035, gold)
    hinges = [sphere(loc=visor(u, 0.08, 0.04), scale=0.045, mat=rib) for u in (0.03, 0.97)]
    glint = _bare(tube([visor(0.32, v, 0.03) for v in (0.25, 0.5, 0.75)], 0.02, mat=toon("#fff7d6", flat_glow=True), res=4))
    return parts + _wob([dome, crest, brim, shield] + hinges + glint, "still") + _mitts(body)


def _pirate(spec, parts):
    """Ocean: a spotted bandana, a patch on the eye you can't see (its strap shows), and a gold earring"""
    body = parts[0]
    ink, gold = toon("#17131a", shade=1.0, rim=0.0), toon("#f2c33d", spec=0.6, rim=0.3)

    def reach(x):
        return 22.0 + 40.0 * _smooth((0.36 - x) / 0.3)             # (down to his gills behind the eye, up off it in front)

    def cap(u, v):
        x = 0.1 + 0.78 * u
        w = 1.0 - abs(v - 0.5) * 2.0
        return _skin(x, (v - 0.5) * 2.0 * reach(x), 0.035 + 0.09 * math.sin(math.pi * u) ** 0.7 * w ** 0.6)
    spots = _dots("#d23a2c", "#fbf1df", every=0.17, r=0.046)
    band = _dress(_shell(cap, 32, 24, 0.03), spots, "bandana")
    knot_at = _skin(0.12, 30.0, 0.12)
    knot = sphere(loc=knot_at, scale=(0.13, 0.1, 0.12), mat=toon("#c23226"))
    tails = []
    for pts, w in (([knot_at, knot_at + Vector((-0.2, -0.06, 0.14)), knot_at + Vector((-0.46, -0.08, 0.24)), knot_at + Vector((-0.72, -0.06, 0.18))], 0.15),
                   ([knot_at, knot_at + Vector((-0.18, -0.1, -0.04)), knot_at + Vector((-0.4, -0.12, -0.1)), knot_at + Vector((-0.6, -0.12, -0.22))], 0.13)):
        tails.append(_dress(_ribbon(pts, w, taper=0.55, twist=0.5), spots, "bandana"))
    parts += _wob([band, knot], "body") + _wob(tails, "scarf", knot_at)
    # the patch is on his far eye; the strap comes round the front of his face, under his brow, and away under the bandana
    ex, ez = spec["eye"]
    patch = sphere(loc=(ex, -_near(body, ex, ez) + 0.03, ez), scale=(0.17, 0.05, 0.15), mat=ink)
    strap = tube([_skin(0.68, -60.0, 0.02), _skin(0.84, -28.0, 0.03), _skin(0.9, 0.0, 0.035), _skin(0.78, 34.0, 0.035), _skin(0.62, 44.0, 0.035),
                  _skin(0.46, 48.0, 0.035), _skin(0.32, 48.0, 0.03), _skin(0.18, 42.0, 0.025), _skin(0.06, 34.0, 0.02)], 0.03, mat=ink, res=12)
    strap["outline_k"] = 0.5
    parts += _wob([patch, strap], "still")
    # a gold earring, hanging from under his moustache
    ear = Vector((0.27, _near(body, 0.27, -0.14) - 0.03, -0.14))
    stud = sphere(loc=ear, scale=0.045, mat=gold)
    hoop = K.torus(loc=ear + Vector((0.0, -0.02, -0.14)), R=0.13, r=0.03, rot=(90, 0, 0), mat=gold)
    hoop["outline_k"] = 0.5
    return parts + _wob([stud, hoop], "pearl")


def _pilot(spec, parts):
    """Sky: a leather flying cap with the goggles pushed up, and a scarf far too long for him"""
    body = parts[0]
    leather, seam_m, brass, fleece = toon("#b0703e", spec=0.15), toon("#5a3418"), toon("#c9923f", spec=0.5, rim=0.25), toon("#f1e4c8")

    def cap(u, v):
        x = 0.12 + 0.72 * u
        return _skin(x, (v - 0.5) * 2.0 * _edge(x), 0.035 + 0.03 * math.sin(math.pi * u) * (1.0 - abs(v - 0.5) * 2.0) ** 0.5)
    leather_cap = _shell(cap, 28, 20, 0.035, leather)
    seam = tube([_skin(x, 0.0, 0.07) for x in (0.13, 0.34, 0.56, 0.8)], 0.016, mat=seam_m, res=6)
    seam["outline_k"] = 0.3
    # (a fleece rim all round the edge of it, so you can see where it stops)
    rim = [_skin(0.12 + 0.72 * i / 12, s * _edge(0.12 + 0.72 * i / 12), 0.05) for s in (1.0,) for i in range(13)]
    rim += [_skin(0.84, a, 0.05) for a in (9.0, 0.0, -9.0)] + [_skin(0.12 + 0.72 * i / 12, -_edge(0.12 + 0.72 * i / 12), 0.05) for i in range(12, -1, -1)]
    trim = tube(rim, 0.04, mat=fleece, res=8)
    trim["outline_k"] = 0.5
    parts += _wob([leather_cap, seam, trim], "body")
    # goggles on his forehead, the near lens turned a little toward you
    glass = toon("#a6e1f5", spec=0.7, emit=0.25)
    lenses = []
    for a, face in ((22.0, (0.45, -0.75, 0.5)), (-22.0, (0.45, 0.35, 0.82))):
        at = _skin(0.64, a, 0.12)
        ring = _turned(K.torus(R=0.12, r=0.034, mat=brass), face, at)
        lens = _turned(K.cyl(r=0.105, depth=0.02, verts=24, mat=glass), face, at)
        shine = _bare(sphere(loc=at + ring.rotation_quaternion @ Vector((-0.035, 0.03, 0.02)), scale=(0.025, 0.018, 0.01), mat=toon("#ffffff", flat_glow=True)))
        lenses.append(at)
        parts += _wob([ring, lens] + shine, "still")
    # (the strap round the back, and a bridge between the lenses: separate, so no curve overshoots a lens)
    straps = [tube([lenses[0], _skin(0.42, 24.0, 0.075), _skin(0.16, 30.0, 0.06)], 0.026, mat=seam_m, res=8),
              tube([lenses[0], _skin(0.7, 0.0, 0.14), lenses[1]], 0.022, mat=brass, res=8),
              tube([lenses[1], _skin(0.42, -24.0, 0.075), _skin(0.16, -30.0, 0.06)], 0.026, mat=seam_m, res=8)]
    for s in straps:
        s["outline_k"] = 0.5
    parts += _wob(straps, "still")
    # the scarf: round his neck (such as it is), knotted at the side, and the ends streaming out behind
    white = toon("#f6f2e8")
    band = _shell(lambda u, v: _round(body, 0.21 + (v - 0.5) * 0.15, u * 360.0, 0.045), 48, 2, 0.03, white)
    knot_at = _round(body, 0.21, 52.0, 0.09)
    knot = sphere(loc=knot_at, scale=(0.1, 0.07, 0.09), mat=white)
    parts += _wob([band, knot], "body")
    # (low along his back, under the cap and over the dorsal fin, clear of MUM)
    long = [(-0.2, -0.06, 0.12), (-0.48, -0.05, 0.22), (-0.78, -0.03, 0.18), (-1.06, -0.01, 0.3), (-1.34, 0.01, 0.24), (-1.56, 0.03, 0.34)]
    short = [(-0.18, -0.08, -0.02), (-0.42, -0.08, 0.04), (-0.66, -0.06, -0.02), (-0.9, -0.05, 0.06), (-1.08, -0.04, 0.0)]
    for path, w, tw in ((long, 0.12, 0.9), (short, 0.11, 0.8)):
        pts = [knot_at] + [knot_at + Vector(p) for p in path]
        tip_x = pts[-1].x

        def stripes(co, n, tip_x=tip_x):
            s = co.x - tip_x
            return hexc("#d23a2c") if (0.05 < s < 0.1 or 0.16 < s < 0.21) else hexc("#f6f2e8")
        parts += _wob([_dress(_ribbon(pts, w, taper=0.7, twist=tw), stripes, ("scarf", round(tip_x, 3)))], "scarf", knot_at)
    return parts


def _astro(spec, parts):
    """Space: a glass bubble for a helmet, over her head and the perm, with the bow still on top (outside); a collar"""
    c, R, back = Vector((0.25, 0.0, 0.0)), 1.1, -0.4
    glass_m = toon("#d8f3ff", alpha=0.2, rim=0.8, key="rivalglass")
    glass_m.use_backface_culling = True
    glass = sphere(loc=c, scale=R, seg=64, rings=32, mat=glass_m)
    bm = bmesh.new()
    bm.from_mesh(glass.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=((back - c.x) / R, 0.0, 0.0), plane_no=(1.0, 0.0, 0.0), clear_inner=True)
    bm.to_mesh(glass.data)
    bm.free()
    rr = math.sqrt(R * R - (back - c.x) ** 2)
    steel = toon("#c7d0d8", spec=0.5)
    collar = K.torus(loc=(back, 0.0, 0.0), R=rr, r=0.075, rot=(0, 90, 0), mat=steel, seg=64)
    rivets = [sphere(loc=(back + 0.06, -math.sin(math.radians(t)) * rr, math.cos(math.radians(t)) * rr), scale=0.028, mat=toon("#8d99a5")) for t in (35, 65, 95, 125)]
    for r in rivets:
        r["outline_k"] = 0.4

    def on_glass(*d):
        return c + Vector(d).normalized() * (R + 0.01)
    shine = toon("#ffffff", flat_glow=True)
    glints = _bare(glass, tube([on_glass(-0.5, -0.55, 0.66), on_glass(-0.28, -0.58, 0.76), on_glass(-0.04, -0.58, 0.82)], 0.022, mat=shine, res=8),
                   sphere(loc=on_glass(0.12, -0.6, 0.79), scale=0.026, mat=shine))
    return parts + _wob(glints + [collar] + rivets, "still")


def _alien(spec, parts):
    """Alien: a headband with antennae on springs, and sunglasses for three eyes pushed up on the perm"""
    green, glow = toon("#76d24a", spec=0.3), toon("#b6ff6a", emit=0.85)
    band = _shell(lambda u, v: _skin(0.44 + (v - 0.5) * 0.1, -44.0 + 88.0 * u, 0.235), 24, 2, 0.03, toon("#c6d0d8", spec=0.55))
    gem = sphere(loc=_skin(0.44, 0.0, 0.27), scale=0.05, mat=green)
    parts += _wob([band, gem], "still")
    for base, tip in ((_skin(0.5, 16.0, 0.25), (0.72, -0.44, 1.5)), (_skin(0.38, -16.0, 0.25), (0.16, 0.36, 1.58))):
        spring = tube(_coil(base, tip), 0.013, mat=toon("#cfd8e0", spec=0.5), res=4)
        spring["outline_k"] = 0.35
        ball = sphere(loc=tip, scale=0.085, mat=glow)
        shine = _bare(sphere(loc=Vector(tip) + Vector((0.025, -0.06, 0.035)), scale=0.022, mat=toon("#ffffff", flat_glow=True)))
        parts += _wob([spring, ball] + shine, "antenna", base)
    # three lenses, one for each eye she hasn't got, facing you from the top of her head
    frame_m, lens_m = toon("#ff4fa0", spec=0.4), toon("#241a33", spec=0.7, rim=0.3)
    face = (0.15, -0.9, 0.4)
    centres = [Vector((0.5, -0.38, 0.98)), Vector((0.71, -0.4, 0.93)), Vector((0.9, -0.36, 0.83))]
    shades = []
    for p in centres:
        shades += [_turned(K.torus(R=0.115, r=0.017, mat=frame_m), face, p), _turned(K.cyl(r=0.108, depth=0.025, verts=24, mat=lens_m), face, p)]
        shades += _bare(sphere(loc=p + Vector((-0.032, -0.05, 0.036)), scale=(0.028, 0.012, 0.02), mat=toon("#ffffff", flat_glow=True)))
    for a, b in zip(centres, centres[1:]):
        shades.append(tube([a + (b - a).normalized() * 0.105, b - (b - a).normalized() * 0.105], 0.018, mat=frame_m, res=4))
    shades.append(tube([centres[0] + Vector((-0.1, 0.0, 0.0)), centres[0] + Vector((-0.22, 0.22, 0.02)), Vector((0.2, 0.12, 0.94))], 0.018, mat=frame_m, res=6))
    return parts + _wob(shades, "still")


def _lamp(spec, parts):
    """Abyss: a miner's lamp strapped on top of the perm (it is very dark down there), and the good pearls, which glow"""
    brass, steel, dark = toon("#d9a43a", spec=0.45), toon("#b8c2cc", spec=0.5), toon("#3c3640")
    d = Vector((0.85, -0.42, -0.2)).normalized()            # (where it shines: ahead, and a little at you)
    at = Vector((0.7, -0.18, 0.97))
    housing = _turned(K.cyl(r=0.13, depth=0.24, verts=24, mat=brass), d, at)
    bezel = _turned(K.torus(R=0.13, r=0.032, mat=steel), d, at + d * 0.12)
    lens = _turned(K.cyl(r=0.11, depth=0.02, verts=24, mat=toon("#fff6c8", flat_glow=True)), d, at + d * 0.126)
    beam_m = toon("#fff2b0", flat_glow=True, alpha=0.24, key="rivalbeam")
    beam_m.use_backface_culling = True
    beam = _turned(K.cone(r1=0.11, r2=0.28, depth=0.36, verts=32, mat=beam_m), d, at + d * (0.13 + 0.18))
    halo = sphere(loc=at + d * 0.16, scale=0.21, mat=toon("#ffe98a", flat_glow=True, alpha=0.24))
    strap = tube([at - d * 0.08, _skin(0.5, 4.0, 0.24), _skin(0.26, 0.0, 0.26), _skin(0.0, 0.0, 0.22), _skin(-0.22, 6.0, 0.12)], 0.035, mat=dark, res=8)
    strap["outline_k"] = 0.5
    return parts + _wob([housing, bezel, strap] + _bare(lens, beam, halo), "still")


OUTFITS = {"lava": _lava, "pirate": _pirate, "pilot": _pilot, "astro": _astro, "alien": _alien, "lamp": _lamp}


def build(spec):
    parts = build_geraldine(spec) if spec.get("mum") else build_gerald(spec)
    if spec.get("outfit"):
        parts = OUTFITS[spec["outfit"]](spec, parts)
    return parts


def build_shape():
    """Gerald in the dark, from above: only the bulk of him, his moustache and two very cross eyes"""
    spec = dict(RIVALS["Gerald"], top="#22344a", belly="#101c2a", blotch="#182838", fin="#1b2b3c", fin2="#101c28", hair="#0a1119", hair2="#121d2a")
    body = _body(spec)
    bpy.context.view_layer.update()
    parts = [body] + _fins(spec, body) + _moustache(spec)
    pale, ink = toon("#e6efe0", flat_glow=True), toon("#0a1119", flat_glow=True)
    for s in (-1, 1):
        eye = sphere(loc=(0.66, s * 0.25, 0.62), scale=(0.13, 0.13, 0.1), mat=pale)
        pupil = sphere(loc=(0.72, s * 0.22, 0.7), scale=0.05, mat=ink)
        eye["no_outline"] = pupil["no_outline"] = True
        brow = _strand([(0.44, s * 0.46, 0.76), (0.66, s * 0.28, 0.82), (0.88, s * 0.08, 0.68)], [0.05, 0.09, 0.05], ink, wob="brow")
        eye["wob"] = pupil["wob"] = "still"
        parts += [eye, pupil, brow]
    return parts


def pose(baked, ph):
    """this moment of the swim. The head stays put, because the mini-game draws the face on it at a fixed place: the
    belly wobbles, the tail and the tiny paddles work far too hard, and the moustache bounces a beat late"""
    for p, a in baked:
        o = a.copy()
        kind = p.get("wob", "body")
        if kind == "body":
            back = np.clip((0.35 - a[:, 0]) / 1.35, 0.0, 1.0)
            low = np.clip(-a[:, 2] / 0.85, 0.0, 1.0) * np.clip((0.75 - a[:, 0]) / 0.5, 0.0, 1.0)
            o[:, 2] += low * np.sin(ph - a[:, 0] * 2.2) * 0.06                  # the wobble
            o[:, 2] += back ** 2 * np.sin(ph - 0.5) * 0.08
            o[:, 1] += back ** 2 * np.cos(ph) * 0.1
        elif kind == "tail":
            k = np.clip((-0.86 - a[:, 0]) / 0.62, 0.0, 1.0)
            o[:, 2] += (0.08 + k) * np.sin(ph - 0.5 - k * 1.1) * 0.2
            o[:, 1] += (0.08 + k) * np.cos(ph) * 0.26
            o[:, 0] += k * (np.abs(np.cos(ph)) * 0.12)                          # (it swings toward you, and looks shorter)
        elif kind == "dorsal":
            k = np.clip((a[:, 2] - 0.55) / 0.5, 0.0, 1.0)
            o[:, 0] -= k * (0.5 + 0.5 * np.sin(ph - 1.0)) * 0.1
            o[:, 2] -= k * (0.5 + 0.5 * np.sin(ph - 1.0)) * 0.05
        elif kind in ("paddle", "fin"):
            r = p["root"].to_list()
            k = np.clip(np.hypot(a[:, 0] - r[0], a[:, 2] - r[2]) / 0.3, 0.0, 1.0)
            n, sw = (2.0, 0.17) if kind == "paddle" else (1.0, 0.05)
            o[:, 2] += k * np.sin(ph * n) * sw
            o[:, 0] += k * np.cos(ph * n) * sw * 0.5
        elif kind == "tash":
            o[:, 2] += np.clip((0.9 - a[:, 0]) / 0.65, 0.0, 1.0) ** 1.6 * np.sin(ph - 1.2) * 0.09
        elif kind == "brow":
            o[:, 2] += (0.5 + 0.5 * np.sin(ph * 2.0)) * 0.012
        elif kind == "line":
            k = np.clip((-0.45 - a[:, 2]) / 0.55, 0.0, 1.0)
            o[:, 0] += k * np.sin(ph - a[:, 2] * 5.0) * 0.07
        elif kind == "lip":
            o[:, 2] += np.sin(ph * 2.0) * 0.008
        elif kind == "bow":
            k = np.clip(np.abs(a[:, 0] - p["root"].to_list()[0]) / 0.66, 0.0, 1.0)
            o[:, 2] += k * np.sin(ph - 0.8) * 0.09
        elif kind == "pearl":
            o[:, 0] += np.clip((0.3 - a[:, 2]) / 1.0, 0.0, 1.0) * np.sin(ph - 0.6) * 0.02
        elif kind == "scarf":                                                   # (it streams out behind, and flaps)
            r = p["root"].to_list()
            k = np.clip(np.hypot(a[:, 0] - r[0], a[:, 2] - r[2]) / 1.3, 0.0, 1.0)
            o[:, 2] += k * np.sin(ph - k * 6.0) * 0.09
            o[:, 1] += k * np.cos(ph - k * 6.0) * 0.04
        elif kind == "antenna":                                                 # (springs: they boing)
            r = p["root"].to_list()
            k = np.clip((a[:, 2] - r[2]) / 0.6, 0.0, 1.0) ** 2
            o[:, 0] += k * np.sin(ph + 0.6) * 0.07
        p.data.vertices.foreach_set("co", o.ravel())
        p.data.update()

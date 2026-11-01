"""Gerald and his mum, built from scratch: fat, solid and cross. vf_life renders them: close up from the side for the
mini-game (which draws their eyes and mouths on top, so the eyes here only say where those go), and Gerald from the game's
camera as the big dark shape that swims past the boat.
Everything faces +X and the camera's side is y < 0. A part's "wob" says how it moves (pose()).
"""
import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import vf_kit as K
from vf_kit import cone, hexc, ico, mix, sphere, toon, tube, vcolor

RIVALS = {
    "Gerald": dict(rival=True, top="#8fa24e", belly="#f4ecc2", blotch="#566a32", fin="#c8743a", fin2="#8a4522",
                   hair="#4a2c18", hair2="#8a5c36", mouth=(0.94, -0.3, -0.3), eye=(0.6, 0.17), eye_r=0.15),
    "Geraldine": dict(rival=True, mum=True, top="#7fa27a", belly="#f6f0d4", blotch="#517458", fin="#d9708a", fin2="#a3425e",
                      hair="#2f2430", hair2="#dcd2ea", mouth=(1.08, -0.2, -0.13), eye=(0.6, 0.17), eye_r=0.15),
}
TOP_H, BELLY_H, WIDE = 0.8, 0.86, 0.72
FOLDS = ((0.05, 0.1), (0.6, 0.08))      # (where along him, how deep)


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
    """thick, furious, and they've never met a comb"""
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
    for x, y, z in ((1.03, -0.14, -0.44), (0.86, -0.3, -0.5)):
        h = tube([(x, y, z + 0.05), (x + 0.01, y, z - 0.08), (x - 0.03, y, z - 0.15), (x - 0.11, y, z - 0.11), (x - 0.12, y, z - 0.05)], 0.019, mat=steel, res=8)
        h["outline_k"] = 0.45
        h["wob"] = "lip"
        parts.append(h)
    a = tube([(1.03, -0.14, -0.4), (1.12, -0.2, -0.6), (0.98, -0.26, -0.82), (1.06, -0.28, -1.0)], 0.0095, mat=line, res=10)
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
        parts.append(_fan(spec, (0.2, s * -near, -0.36), 172, 262, 0.3, 3, thick=0.04, flare=s * 0.18, wob="paddle"))
        parts.append(_fan(spec, (0.34, s * 0.3, -0.76), 200, 262, 0.2, 2, thick=0.03, flare=s * 0.06, wob="paddle"))
    return parts


def build_gerald(spec):
    body = _body(spec)
    bpy.context.view_layer.update()
    parts = [body] + _fins(spec, body)
    parts += _face_eyes(spec, body) + _eyebrows(spec) + _moustache(spec)
    nose = sphere(loc=(1.07, 0.0, 0.08), scale=(0.18, 0.2, 0.165), mat=toon("#d9685e", spec=0.25))
    nose["wob"] = "still"
    lip = sphere(loc=(0.93, 0.0, -0.41), scale=(0.2, 0.3, 0.105), mat=toon("#c8675a"))
    lip["wob"] = "lip"
    # his last hair, and he's very proud of it
    hair = tube([(0.24, 0, 0.76), (0.27, 0, 0.95), (0.39, 0, 1.03), (0.49, 0, 0.94)], 0.024, mat=toon(spec["hair"]), res=8)
    hair["outline_k"] = 0.5
    hair["wob"] = "brow"
    parts += [nose, lip, hair]
    parts += _old_hooks() + _tattoo(body)
    return parts


def _pearls(body):
    """a good string of pearls, round her neck and resting on all that bosom, and a smaller one for Sundays"""
    pearl = toon("#fbf6ec", spec=0.5, rim=0.25)
    out = []
    for n, x0, reach, r, lift in ((13, 0.1, 0.34, 0.078, 0.04), (11, 0.02, 0.26, 0.052, 0.03)):
        for i in range(n):
            t = i / (n - 1)
            x, z = x0 + reach * math.sin(math.pi * t) ** 0.8, 0.5 - 1.14 * t
            p = ico(loc=(x, _near(body, x, z) - lift, z), scale=r, mat=pearl, sub=3, smooth=True)
            p["outline_k"] = 0.45
            p["wob"] = "pearl"
            out.append(p)
    return out


def _bow():
    """big. Bigger. It's held on by willpower"""
    silk, dark = toon("#ec3f78", spec=0.2), toon("#b42658")
    out = []
    at = Vector((0.2, -0.2, 1.18))
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
    upper = sphere(loc=(1.0, 0.0, -0.09), scale=(0.12, 0.19, 0.065), mat=toon("#d42c4f", spec=0.3))
    lower = sphere(loc=(0.98, 0.0, -0.19), scale=(0.13, 0.21, 0.08), mat=toon("#e83a5e", spec=0.3))
    for o in (upper, lower):
        o["wob"] = "still"
    parts += [upper, lower]
    parts += _perm(spec) + _pearls(body) + _bow()
    return parts


def build(spec):
    return build_geraldine(spec) if spec.get("mum") else build_gerald(spec)


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
            o[:, 0] += k * (np.abs(np.cos(ph)) * 0.1)                           # (it swings toward you, and looks shorter)
        elif kind == "dorsal":
            k = np.clip((a[:, 2] - 0.55) / 0.5, 0.0, 1.0)
            o[:, 0] -= k * (0.5 + 0.5 * np.sin(ph - 1.0)) * 0.08
            o[:, 2] -= k * (0.5 + 0.5 * np.sin(ph - 1.0)) * 0.04
        elif kind in ("paddle", "fin"):
            r = p["root"].to_list()
            k = np.clip(np.hypot(a[:, 0] - r[0], a[:, 2] - r[2]) / 0.3, 0.0, 1.0)
            n, sw = (2.0, 0.16) if kind == "paddle" else (1.0, 0.04)
            o[:, 2] += k * np.sin(ph * n) * sw
            o[:, 0] += k * np.cos(ph * n) * sw * 0.5
        elif kind == "tash":
            o[:, 2] += np.clip((0.9 - a[:, 0]) / 0.65, 0.0, 1.0) ** 1.6 * np.sin(ph - 1.2) * 0.1
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
        p.data.vertices.foreach_set("co", o.ravel())
        p.data.update()

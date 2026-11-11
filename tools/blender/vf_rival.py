"""Gerald, built from scratch: fat, solid and cross (the other six outlaws of the Most Wanted board are vf_outlaws.py's). vf_life
renders him close up from the side for the mini-game (which draws his eyes and mouth on top, so the eyes here only say where
those go), and from the game's camera as the big dark shape that swims past the boat.
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
}
# the other six outlaws of the Most Wanted board: each a different fish (vf_outlaws.py builds them). eye = x, z of the near eye
# (the mini-game draws it there), mouth = where the mouth goes
OUTLAWS = {
    "sizzle": dict(top="#2d2926", belly="#6a4a3a", fin="#2b2724", fin2="#ff7a1f", accent="#ffd23f", eye=(0.62, 0.22), eye_r=0.2, mouth=(1.05, -0.2, -0.12)),
    "swordbeard": dict(top="#2c5f9a", belly="#e6eef4", fin="#1f4a7e", fin2="#9cc4e8", accent="#d9a02e", eye=(0.78, 0.18), eye_r=0.215, mouth=(1.1, -0.1, -0.12)),
    "baron": dict(top="#6fa8d8", belly="#f2f6fa", fin="#b8d8f0", fin2="#5a90c0", accent="#7a4a28", eye=(0.62, 0.16), eye_r=0.165, mouth=(1.0, -0.1, -0.1)),
    "chomp": dict(top="#5d7a96", belly="#f1f5f8", fin="#4b6680", fin2="#2f465c", accent="#e5533d", eye=(0.5, 0.12), eye_r=0.178, mouth=(0.98, -0.2, -0.16)),
    "zlorp": dict(top="#9a62c9", belly="#d9b8ee", fin="#7e4aa8", fin2="#c79be6", accent="#7dffb0", eye=(0.5, 0.2), eye_r=0.155, mouth=(0.98, -0.2, -0.3)),
    "duchess": dict(top="#2b2f6b", belly="#7c6fb8", fin="#3a3f85", fin2="#6f7ad0", accent="#ffcf4a", eye=(0.6, 0.25), eye_r=0.183, mouth=(1.12, -0.2, -0.3)),
}
for _look, _spec in OUTLAWS.items():
    RIVALS[_look] = dict(_spec, rival=True, outlaw=_look)
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


def build(spec):
    if spec.get("outlaw"):
        import vf_outlaws as OUT              # (the other six build on this file's helpers, so it's imported when needed)
        return OUT.build(spec)
    return build_gerald(spec)


def build_shape(name="Gerald"):
    """an outlaw in the dark, from above: only the bulk of them and two very cross eyes (Gerald: and his moustache)"""
    night = dict(top="#22344a", belly="#101c2a", blotch="#182838", fin="#1b2b3c", fin2="#101c28", hair="#0a1119", hair2="#121d2a", accent="#16222f")
    if name != "Gerald":
        import vf_outlaws as OUT
        return OUT.build(dict(RIVALS[name], dark=True, **night))
    spec = dict(RIVALS["Gerald"], **night)
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
        elif kind == "whisker":                                                 # (strands reaching forward: they waft)
            o[:, 2] += np.clip((a[:, 0] - 0.9) / 0.9, 0.0, 1.0) * np.sin(ph * 2.0 - a[:, 0] * 3.0) * 0.08
        elif kind == "sway":                                                    # (hangs from its root and swings)
            r = p["root"].to_list()
            k = np.clip(np.hypot(a[:, 0] - r[0], a[:, 2] - r[2]) / 0.9, 0.0, 1.0)
            o[:, 0] += k * np.sin(ph - k * 3.0) * 0.07
        elif kind == "wing":                                                    # (big side fins: they flap)
            r = p["root"].to_list()
            k = np.clip(np.hypot(a[:, 0] - r[0], a[:, 2] - r[2]) / 1.0, 0.0, 1.0)
            o[:, 2] += k * np.sin(ph * 2.0 - 0.4) * 0.14
        p.data.vertices.foreach_set("co", o.ravel())
        p.data.update()

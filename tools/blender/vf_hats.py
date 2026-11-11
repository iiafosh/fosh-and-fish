"""The captain's hats (docs/MISSING_LIST.md part 6), drawn by the stage on top of his sheets. Each is a real model on
his head, rendered from the game's camera for every way his head can face (vf_captain.HAT_ANGLES, then fishing and
cheering), with his head held out: where his head would hide a bit of the hat, the picture is empty. So a hat lands on
the hatless sheets just where the old one was baked.
    assets/vf/hats/<slug>.png   one row of pictures, one per view
The manifest's "hats" says how to place them; where his head is in every frame is in fisher.head (vf_captain.render)
and boats_top[boat].turn.head (vf_turn.render).
A hat is built in its own space: 1 is half his head's width, z = 0 where the old hat sat, and he looks toward -Y.
"""
import math
import os
import tempfile

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

import vf_captain as C
import vf_finds as FD
import vf_kit as K
import vf_life as L
import vf_topdown as TD
import vf_vendor as V
from vf_kit import cone, cube, cyl, hexc, ico, mix, sphere, toon, torus, tube

ORDER = ["straw", "pirate", "chef", "propeller", "viking", "traffic_cone", "top_hat", "sombrero", "duck", "crown", "tiara"]
UNIT_PX = round(C.CELL / C.SCALE, 3)       # (as sharp as the fishing sheets)
SUN_TURN, SUN_FISHER = (42, 0, 28), (35, 0, 30)


def _paint(ob, fn, key, **kw):
    K.vcolor(ob, fn)
    ob.data.materials.clear()
    ob.data.materials.append(toon(None, vcol="col", key=("hat", key), **kw))
    return ob


def _grid(fn, nu, nv, thick, col=None):
    """a curved piece with a real thickness: fn(u, v) -> point, u and v from 0 to 1"""
    verts = [fn(i / nu, j / nv) for i in range(nu + 1) for j in range(nv + 1)]
    faces = [(i * (nv + 1) + j, (i + 1) * (nv + 1) + j, (i + 1) * (nv + 1) + j + 1, i * (nv + 1) + j + 1) for i in range(nu) for j in range(nv)]
    ob = FD._sheet(verts, faces, thick, col)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def _ring(r, z, mat, radius=0.035, start=0.0, end=math.tau, n=48):
    return tube([(math.cos(start + (end - start) * i / n) * r, math.sin(start + (end - start) * i / n) * r, z(start + (end - start) * i / n) if callable(z) else z)
                 for i in range(n + 1)], radius, mat=mat, res=4)


# ------------------------------------------------------------------- the hats
def _pirate():
    black, gold, bone, ink = toon("#2b2733"), toon("#f0c048", spec=0.3), toon("#f8f4e8"), toon("#1a1720", shade=1.0, rim=0.0)
    crown = sphere(loc=(0, 0.1, 0.22), scale=(0.98, 0.95, 0.66), mat=black)
    back = sphere(loc=(0, 0.2, 0.08), scale=(1.3, 1.05, 0.1), mat=black)

    def wall(u, v):
        """the front of it, turned up high: a crescent across his brow"""
        x = (u - 0.5) * 2.5
        y = -0.98 + 0.32 * (2.0 * u - 1.0) ** 2
        return Vector((x, y - 0.12 * v, v * (0.42 + 0.62 * math.sin(math.pi * u))))
    front = _grid(wall, 28, 6, 0.09, "#2b2733")
    trim = tube([wall(i / 28, 1.0) + Vector((0, -0.05, 0.0)) for i in range(29)], 0.045, mat=gold, res=6)
    skull = sphere(loc=(0, -1.22, 0.62), scale=(0.2, 0.08, 0.19), mat=bone)
    jaw = sphere(loc=(0, -1.2, 0.47), scale=(0.12, 0.06, 0.07), mat=bone)
    parts = [crown, back, front, trim, skull, jaw]
    for s in (1, -1):
        parts.append(tube([(s * -0.3, -1.16, 0.36), (s * 0.3, -1.16, 0.84)], 0.03, mat=bone, res=4))
        for e in ((s * -0.3, -1.16, 0.36), (s * 0.3, -1.16, 0.84)):
            parts.append(sphere(loc=e, scale=0.055, mat=bone))
        eye = sphere(loc=(s * 0.075, -1.3, 0.64), scale=(0.05, 0.02, 0.05), mat=ink)
        eye["no_outline"] = True
        parts.append(eye)
    return parts


def _chef():
    white = toon("#f7f7f3")
    band = cyl(loc=(0, 0, 0.3), r=0.93, depth=0.6, verts=40)
    _paint(band, lambda co, n: hexc("#e3e3dc") if math.cos(math.atan2(co.y, co.x) * 16.0) > 0.86 else hexc("#f7f7f3"), "pleats")
    parts = [band]
    for x, y, z, r in ((0, 0.05, 1.08, 0.66), (0.5, 0.12, 0.9, 0.5), (-0.5, 0.12, 0.9, 0.5), (0.14, 0.56, 0.92, 0.5), (-0.12, -0.44, 0.94, 0.5),
                       (0.4, -0.34, 0.82, 0.42), (-0.4, 0.42, 0.82, 0.42), (0.06, 0.1, 1.46, 0.44)):
        parts.append(sphere(loc=(x, y, z), scale=r, mat=white, seg=24, rings=12))
    return _lean(parts, (-9, 6, 0))


def _propeller():
    cols = ["#e5533d", "#ffd23f", "#3e8fe0", "#4fc35a"]
    dome = sphere(loc=(0, 0, -0.08), scale=(1.02, 1.02, 0.9), seg=48, rings=24)
    K.deform(dome, lambda co: Vector((co.x, co.y, max(co.z, -0.12))))
    _paint(dome, lambda co, n: hexc(cols[int(((math.atan2(co.y, co.x) + math.pi) / math.tau * 4.0 + 0.5)) % 4]), "beanie")
    visor = sphere(loc=(0, -0.95, -0.06), scale=(0.66, 0.44, 0.07), rot=(-10, 0, 0), mat=toon("#e5533d"))
    button = sphere(loc=(0, 0, 0.84), scale=0.13, mat=toon("#ffd23f"))
    stalk = tube([(0, 0, 0.84), (0, 0, 1.2)], 0.045, mat=toon("#9aa6b0"), res=4)
    hub = sphere(loc=(0, 0, 1.22), scale=(0.1, 0.1, 0.07), mat=toon("#9aa6b0"))
    parts = [dome, visor, button, stalk, hub]
    for s, col in ((1, "#e5533d"), (-1, "#3e8fe0")):     # (it turns when he forgets to think)
        parts.append(sphere(loc=(s * 0.48, s * 0.12, 1.24), scale=(0.44, 0.13, 0.025), rot=(s * 14, 0, 15), mat=toon(col)))
    return parts


def _viking():
    steel, bronze, horn = toon("#aab5c0", spec=0.45), toon("#c9923f", spec=0.3), "#f2e6c8"
    dome = sphere(loc=(0, 0, -0.14), scale=(1.04, 1.04, 0.98), seg=48, rings=24, mat=steel)
    K.deform(dome, lambda co: Vector((co.x, co.y, max(co.z, -0.3))))
    band = torus(loc=(0, 0, -0.16), R=1.02, r=0.1, mat=bronze, seg=48, mseg=10)
    ridge = tube([(0, -1.02, -0.1), (0, -0.7, 0.62), (0, 0.0, 0.88), (0, 0.7, 0.62), (0, 1.02, -0.1)], 0.07, mat=bronze, res=8)
    nose = cube(loc=(0, -1.06, -0.42), scale=(0.16, 0.07, 0.56), mat=steel, bevel=0.02)
    parts = [dome, band, ridge, nose]
    for i in range(10):
        a = i / 10 * math.tau
        parts.append(sphere(loc=(math.cos(a) * 1.1, math.sin(a) * 1.1, -0.16), scale=0.05, mat=steel))
    for s in (1, -1):                                       # (for the buffet)
        h = tube([(s * 0.86, 0.04, 0.18), (s * 1.34, 0.02, 0.5), (s * 1.6, -0.04, 1.0), (s * 1.42, -0.12, 1.4)], 1.0, mat=None, radii=[0.24, 0.2, 0.13, 0.03], res=12)
        _paint(h, lambda co, n, s=s: mix(hexc(horn), hexc("#a58d62"), max(0.0, min(1.0, (co.z - 0.95) / 0.45))), ("horn", s))
        parts.append(h)
    return parts


def _traffic_cone():
    orange, white = toon("#ff7a1f", emit=0.1), toon("#fbfbf6", emit=0.25)
    base = cube(loc=(0, 0, 0.02), scale=(1.95, 1.95, 0.14), mat=orange, bevel=0.05)
    body = cone(loc=(0, 0, 1.06), r1=0.86, r2=0.12, depth=2.0, verts=40, mat=orange)
    parts = [base, body]
    radius = lambda z: 0.86 + (0.12 - 0.86) * (z - 0.06) / 2.0
    for z0, z1 in ((0.6, 0.92), (1.24, 1.46)):              # (the stripes that make it official)
        parts.append(cone(loc=(0, 0, (z0 + z1) * 0.5), r1=radius(z0) + 0.025, r2=radius(z1) + 0.025, depth=z1 - z0, verts=40, mat=white))
    parts.append(sphere(loc=(0, 0, 2.06), scale=(0.13, 0.13, 0.06), mat=orange))
    return _lean(parts, (7, -9, 0))


def _top_hat():
    black, band = toon("#211f27", spec=0.25), toon("#8c2240")
    brim = sphere(scale=1.0, seg=48, rings=12)
    K.deform(brim, lambda co: Vector((co.x * 1.42, co.y * 1.42, co.z * 0.07 + 0.04 + 0.16 * co.x * co.x)))
    brim.data.materials.append(black)
    tower = cyl(loc=(0, 0, 0.94), r=0.84, depth=1.8, verts=40, mat=black)
    K.deform(tower, lambda co: Vector((co.x * (1.0 + 0.07 * (co.z + 0.9)), co.y * (1.0 + 0.07 * (co.z + 0.9)), co.z)))
    stripe = cyl(loc=(0, 0, 0.26), r=0.875, depth=0.3, verts=40, mat=band)
    return _lean([brim, tower, stripe], (-6, 6, 0))


def _sombrero():
    brim = sphere(scale=1.0, seg=64, rings=20)

    def flare(co):
        rho = math.hypot(co.x, co.y)
        return Vector((co.x * 2.6, co.y * 2.6, co.z * 0.08 + 0.05 + 0.62 * rho ** 5))

    def zigzag(co, n):
        rho = math.hypot(co.x, co.y)
        a = math.atan2(co.y, co.x)
        z = 0.5 + 0.5 * math.sin(a * 18.0)
        if 2.05 + 0.1 * z < rho < 2.3 + 0.1 * z:
            return hexc("#e5533d")
        if 1.75 < rho < 1.9:
            return hexc("#2f9e55")
        return mix(hexc("#f3c95e"), hexc("#d9a43a"), min(1.0, rho / 2.6))
    K.deform(brim, flare)
    _paint(brim, zigzag, "sombrero")
    crown = cone(loc=(0, 0, 0.66), r1=0.96, r2=0.5, depth=1.3, verts=40)
    _paint(crown, lambda co, n: hexc("#e5533d") if -0.62 < co.z < -0.44 else (hexc("#2f9e55") if -0.44 < co.z < -0.36 else hexc("#f3c95e")), "sombrero_top")
    top = sphere(loc=(0, 0, 1.31), scale=(0.5, 0.5, 0.2), mat=toon("#f3c95e"))
    parts = [brim, crown, top]
    for i in range(16):                                     # (shade for the whole boat, with bobbles)
        a = i / 16 * math.tau
        parts.append(sphere(loc=(math.cos(a) * 2.64, math.sin(a) * 2.64, 0.6), scale=0.11, mat=toon("#e5533d" if i % 2 else "#2f9e55")))
    return parts


def _duck():
    """the rubber duck from the water (vf_life), sitting on him and looking where he looks. It squeaks when he thinks"""
    parts = L._build_duck()
    bpy.context.view_layer.update()
    m = Matrix.Translation((0, 0.08, 0.62)) @ Matrix.Rotation(math.radians(-90), 4, "Z") @ Matrix.Scale(1.65, 4)
    for p in parts:
        p.matrix_world = m @ p.matrix_world
    return parts


def _crown():
    gold, velvet = toon("#f2c33d", spec=0.45), toon("#b3263a")
    band = cyl(loc=(0, 0, 0.42), r=0.8, depth=0.44, verts=48, mat=gold)
    cushion = sphere(loc=(0, 0, 0.6), scale=(0.74, 0.74, 0.4), mat=velvet)
    parts = [band, cushion]
    for i in range(6):
        a = i / 6 * math.tau - math.pi / 2
        x, y = math.cos(a) * 0.78, math.sin(a) * 0.78
        parts.append(cone(loc=(x, y, 0.82), r1=0.2, r2=0.0, depth=0.44, verts=12, mat=gold))
        parts.append(sphere(loc=(x, y, 1.06), scale=0.07, mat=toon("#fbf6ec", spec=0.5)))
    for a, col, s in ((-90, "#e5332f", 0.13), (-50, "#2fbf6a", 0.08), (-130, "#3e8fe0", 0.08), (90, "#e5332f", 0.1)):
        t = math.radians(a)
        parts.append(sphere(loc=(math.cos(t) * 0.83, math.sin(t) * 0.83, 0.42), scale=(s, s * 0.6, s), rot=(0, 0, a + 90), mat=toon(col, spec=0.5)))
    tash = toon("#4a2c18")                                  # (the Baron's waxed moustache: he never takes it off)
    for s in (1, -1):
        parts.append(tube([(s * 0.03, -0.86, 0.29), (s * 0.16, -0.86, 0.26), (s * 0.3, -0.83, 0.25), (s * 0.4, -0.8, 0.31), (s * 0.37, -0.79, 0.37)], 1.0, mat=tash, radii=[0.05, 0.06, 0.045, 0.025, 0.01], res=8))
    feather, feather2 = toon("#f6f9fc", spec=0.35), toon("#bfdcf2", spec=0.3)
    for s in (1, -1):                                       # (he's a flying fish: a wing out of each side, three long feathers fanned back like a bird's)
        base = Vector((s * 0.86, 0.0, 0.56))
        for k, (sweep, length) in enumerate(((12, 0.95), (38, 0.85), (64, 0.7))):
            ang = math.radians(sweep if s > 0 else 180 - sweep)
            mid = base + Vector((math.cos(ang), math.sin(ang), 0.05 * k)) * (length * 0.5)
            parts.append(sphere(loc=tuple(mid), scale=(length * 0.5, 0.1, 0.035), rot=(0, 0, math.degrees(ang)), mat=feather if k != 1 else feather2))
    return parts


def _tiara():
    silver, pearl, pink = toon("#e9edf2", spec=0.55), toon("#fbf6ec", spec=0.5, rim=0.25), toon("#ff5fa2", spec=0.45)
    front = lambda a: 0.48 + 0.26 * max(0.0, math.cos(a + math.pi / 2)) ** 3
    parts = [_ring(0.84, front, silver, 0.05, math.radians(195), math.radians(345), 32)]
    for i in range(7):
        a = math.radians(200 + i * 140 / 6)
        x, y = math.cos(a) * 0.85, math.sin(a) * 0.85
        h = 0.22 + 0.4 * max(0.0, math.cos(a + math.pi / 2)) ** 2
        parts.append(cone(loc=(x, y, front(a) + h * 0.5), r1=0.08, r2=0.0, depth=h, verts=8, mat=silver))
        parts.append(sphere(loc=(x, y, front(a) + h + 0.03), scale=0.075, mat=pearl))
    gem = sphere(loc=(0, -0.88, 0.66), scale=(0.16, 0.09, 0.18), mat=pink)
    parts.append(gem)
    # (hers: she's an anglerfish, so a lure rides on the front of the tiara, and a little chandelier hangs from it)
    stalk, glow, crystal = toon("#c9d0da", spec=0.4), toon("#fff2a8", emit=0.9, rim=0.0, shade=1.0), toon("#e4f3ff", spec=0.6, emit=0.25)
    parts.append(tube([(0, -0.88, 0.7), (0, -0.95, 1.02), (0, -1.02, 1.34), (0, -1.15, 1.56), (0, -1.32, 1.52)], 1.0, mat=stalk, radii=[0.055, 0.05, 0.045, 0.04, 0.035], res=8))
    parts.append(sphere(loc=(0, -1.32, 1.36), scale=0.19, mat=glow))
    for dx, dz in ((-0.15, 1.12), (0.0, 1.05), (0.15, 1.12)):
        parts.append(sphere(loc=(dx, -1.32, dz), scale=(0.045, 0.045, 0.085), mat=crystal))
    return parts


def _points(objs):
    """every vertex as it is now, outlines and all, in the world -> N x 3"""
    dg = bpy.context.evaluated_depsgraph_get()
    out = []
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        a = np.empty(len(me.vertices) * 3)
        me.vertices.foreach_get("co", a)
        m = np.array(ev.matrix_world)
        out.append(a.reshape(-1, 3) @ m[:3, :3].T + m[:3, 3])
        ev.to_mesh_clear()
    return np.concatenate(out)


def _lean(parts, rot):
    bpy.context.view_layer.update()
    m = Euler([math.radians(r) for r in rot]).to_matrix().to_4x4()
    for p in parts:
        p.matrix_world = m @ p.matrix_world
    return parts


BUILD = {"pirate": _pirate, "chef": _chef, "propeller": _propeller, "viking": _viking, "traffic_cone": _traffic_cone,
         "top_hat": _top_hat, "sombrero": _sombrero, "duck": _duck, "crown": _crown, "tiara": _tiara}


def _wear(slug, arm, place):
    """build a hat in its own space and put it on his head"""
    parts = [p for p in BUILD[slug]() if p.type == "MESH"]
    bpy.context.view_layer.update()
    for p in parts:
        if p.data.users > 1:
            p.data = p.data.copy()
        p.data.transform(place @ p.matrix_world)
        p.matrix_world = Matrix.Identity(4)
        p["outline_even"] = False
    K.outline_all(parts, 0.014)
    C.on_head(arm, parts)
    return parts


def render(out_dir, only=None, holdout=True, views=None):
    """every hat in every view -> the manifest's "hats" entry. holdout=False shows his head (to look at the hats on him)"""
    os.makedirs(out_dir, exist_ok=True)
    K.clear_scene()
    V.clear_library()
    K.SOFT[0] = True
    K.setup_render(64, 64, samples=16)
    K.setup_world("#9aa6b0", 1.0)
    sun = K.sun(SUN_TURN, 1.0)
    sun.data.angle = math.radians(7)
    cam = K.make_camera(TD.CAM_ROT, ortho=True)
    acts = C.load_actions()
    arm, meshes, root = C.build()
    head = next(m for m in meshes if "Head" in m.name)
    anchor = C.hat_anchor(arm, head)
    seat, r = C.hat_seat(head)
    place = Matrix.Translation(seat) @ Matrix.Rotation(math.radians(C.FACE), 4, "Z") @ Matrix.Scale(r, 4)
    hats = {"straw": C.hat(arm, head)}                       # (it trims his hair, as it always did)
    for slug in ORDER[1:]:
        hats[slug] = _wear(slug, arm, place)
    for m in meshes:
        m.is_holdout = holdout
    Rc = cam.rotation_euler.to_matrix()
    right, up, fwd = Rc @ Vector((1, 0, 0)), Rc @ Vector((0, 1, 0)), Rc @ Vector((0, 0, -1))
    # one frame for all of them, around his head
    every = list(range(C.HAT_CHEER + 1))
    x0 = y0 = 1e9
    x1 = y1 = -1e9
    shown = [o for parts in hats.values() for o in parts] + ([] if holdout else meshes)
    for v in every:
        C.hat_pose(arm, acts, root, v)
        a = C.bone_world(arm, "head") @ anchor
        pts = _points(shown)
        x, y = pts @ np.array(right) - a.dot(right), pts @ np.array(up) - a.dot(up)
        x0, x1, y0, y1 = min(x0, float(x.min())), max(x1, float(x.max())), min(y0, float(y.min())), max(y1, float(y.max()))
    pad = 0.05
    sx, sy = x1 - x0 + pad * 2, y1 - y0 + pad * 2
    cell = int(math.ceil(max(sx, sy) * UNIT_PX / 8.0)) * 8
    span = cell / UNIT_PX
    px = (-x0 + pad + (span - sx) * 0.5) / span
    py = (y1 + pad + (span - sy) * 0.5) / span
    sc = bpy.context.scene
    sc.render.resolution_x = sc.render.resolution_y = cell
    cam.data.ortho_scale = span
    tmp = tempfile.mkdtemp()
    for slug in ORDER:
        if only and slug not in only:
            continue
        for s, parts in hats.items():
            for o in parts:
                o.hide_render = s != slug
        paths = []
        for v in (views or every):
            C.hat_pose(arm, acts, root, v)
            sun.rotation_euler = Euler([math.radians(q) for q in (SUN_FISHER if v >= C.HAT_FISH else SUN_TURN)])
            a = C.bone_world(arm, "head") @ anchor
            cx, cy = a.dot(right) - (px - 0.5) * span, a.dot(up) - (0.5 - py) * span
            cam.location = right * cx + up * cy - fwd * 60.0
            path = os.path.join(tmp, "%s_%02d.png" % (slug, v))
            K.render(path)
            paths.append(path)
        L._sheet([paths], os.path.join(out_dir, slug + ".png"), cell, clean=True)
    K.SOFT[0] = False
    return {"cell": cell, "unit_px": UNIT_PX, "pivot": [round(px, 4), round(py, 4)], "angles": C.HAT_ANGLES,
            "fish": C.HAT_FISH, "cheer": C.HAT_CHEER, "views": len(every), "order": ORDER}

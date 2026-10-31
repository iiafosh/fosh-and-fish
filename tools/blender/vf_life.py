"""Everything alive on the stage, rendered from the game's camera with real motion (assets/vf/life/):
- the fish: the same models as the catch art (vf_models), so what swims is what you catch. A swim cycle in 5 headings
  (rows: toward the camera .. right .. away from it; the stage mirrors them for the other side).
- the gull: built here, wings on hinges, a flap cycle in 5 headings. The crab: built here, walking and idling.
- whale and manta ray: Quaternius' Animated Fish (CC0, tools/fetch_assets.py), a cycle heading right.
"""
import math
import os
import tempfile

import bpy
import numpy as np
from mathutils import Matrix, Vector

import vf_kit as K
import vf_models as M
import vf_topdown as TD
import vf_vendor as V
from vf_kit import cone, extrude_poly, hexc, mix, sphere, toon, torus, tube, vcolor

HEADINGS = (-90.0, -45.0, 0.0, 45.0, 90.0)
FISH_CELL = 112
FISH_FRAMES = 6
BIOME_FISH = ["Raw Fish", "Raw Salmon", "Cod", "Tropical Fish", "Pufferfish", "Fiery Pufferfish", "Hot Cod", "Squid", "Turtle", "Dolphin",
              "Guardian", "Emerald Squid", "Rainbow Fish", "Space Fish", "Galactic Crab", "Shark", "Alien Fish", "Artifact Fish", "Dark Puffer", "Dark Tuna"]


def _setup(size, samples=10):
    K.clear_scene()
    V.clear_library()
    K.SOFT[0] = True
    K.setup_render(size, size, samples=samples)
    K.setup_world("#9aa6b0", 1.0)
    s = K.sun((35, 0, 30), 1.0)
    s.data.angle = math.radians(7)
    return K.make_camera(TD.CAM_ROT, ortho=True)


def _bake(parts):
    """every part's mesh into world coordinates, parented to one root -> (root, [(object, base coordinates)])"""
    bpy.context.view_layer.update()
    root = bpy.data.objects.new("life", None)
    bpy.context.collection.objects.link(root)
    out = []
    for p in parts:
        if p.type != "MESH":
            continue
        if p.data.users > 1:
            p.data = p.data.copy()
        p.data.transform(p.matrix_world)
        p.parent = None
        p.matrix_world = Matrix.Identity(4)
        p.rotation_mode = "XYZ"
        p.parent = root
        a = np.empty(len(p.data.vertices) * 3, dtype=np.float64)
        p.data.vertices.foreach_get("co", a)
        out.append((p, a.reshape(-1, 3)))
    return root, out


def _pose(baked, fn, phase):
    """move the vertices for this moment of the cycle"""
    for p, a in baked:
        p.data.vertices.foreach_set("co", fn(a, phase).ravel())
        p.data.update()


def _frame(cam, radius, centre_z=0.0):
    Rc = cam.rotation_euler.to_matrix()
    up, fwd = Rc @ Vector((0, 1, 0)), Rc @ Vector((0, 0, -1))
    cam.location = up * (centre_z * up.z) - fwd * 60.0
    cam.data.ortho_scale = radius * 2.0


def _sheet(rows, out_path, cell):
    """rows of frame files -> one sheet"""
    n = len(rows[0])
    img = np.zeros((cell * len(rows), cell * n, 4), dtype=np.float32)
    for r, row in enumerate(rows):
        for c, path in enumerate(row):
            im = bpy.data.images.load(path)
            px = np.array(im.pixels[:], dtype=np.float32).reshape(cell, cell, 4)
            bpy.data.images.remove(im)
            # (image rows run bottom-up)
            y0 = (len(rows) - 1 - r) * cell
            img[y0:y0 + cell, c * cell:(c + 1) * cell] = px
    out = bpy.data.images.new("sheet", n * cell, len(rows) * cell, alpha=True)
    out.pixels = img.ravel().tolist()
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


# ------------------------------------------------------------------- fish
def _build_puffer(spec):
    """swimming, a puffer is a plump fish that rows with its side fins (only the catch art is blown up into a ball)"""
    L, H, W = 0.92, 0.56, 0.54
    fin, top, belly = spec["fin"], hexc(spec["top"]), hexc(spec["belly"])

    def shape(co):
        k = 1.0 if co.x > 0.05 else max(0.22, 1.0 - 0.8 * ((0.05 - co.x) / 1.05) ** 1.15)
        return Vector((co.x * L, co.y * W * k, co.z * H * k))
    body = sphere(scale=1.0, seg=48, rings=24)
    K.deform(body, shape)

    def paint(co, n):
        c = mix(belly, top, min(1.0, max(0.0, (co.z / H + 0.22) / 0.62)))
        if co.z > 0.0 and math.sin(co.x * 8.0 + 0.5) > 0.5:     # dark saddles across the back
            c = mix(c, hexc(fin), 0.8)
        return c
    vcolor(body, paint)
    body.data.materials.append(toon(None, vcol="col", key=("puffswim", spec["top"], spec["belly"])))
    parts = [body]
    # a few short spines: the back and the flanks, not the belly or the face
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(34):
        z = 1 - (i / 33) * 2
        r = math.sqrt(1 - z * z)
        d = Vector((math.cos(golden * i) * r, math.sin(golden * i) * r, z))
        if d.z < -0.15 or d.x > 0.62 or d.x < -0.72:
            continue
        c = cone(r1=0.045, r2=0.0, depth=0.15, verts=6, mat=toon(spec["spike"], emit=0.6 if spec.get("glow_spikes") else 0.0), smooth=False)
        c.location = shape(d) + d * 0.05
        c.rotation_mode = "QUATERNION"
        c.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
        c["outline_k"] = 0.35
        parts.append(c)
    parts.append(M._tail(L * 1.02, 0.4, fin, forked=False, scale=0.8))
    parts.append(M._fin([(-0.26, 0), (0.1, 0), (-0.2, 0.27)], (-0.34, 0, H * 0.72), (90, 0, 0), fin))
    for side in (1, -1):                                        # the paddles it rows with
        parts.append(M._fin([(0.04, 0.0), (0.0, side * 0.3), (-0.14, side * 0.4), (-0.32, side * 0.36), (-0.34, side * 0.12), (-0.2, 0.0)],
                            (0.1, side * W * 0.84, -0.04), (0, 0, 0), fin, 0.03))
    parts += M._eyes(L, H, W, x=0.72, z=0.32, size=0.135, cute=spec.get("cute"))
    parts.append(torus(loc=(L * 0.99, 0, -0.06), R=0.085, r=0.032, rot=(0, 90, 0), mat=toon("#c0505a")))
    if spec.get("flames"):
        parts += M._flames((0.0, 0, H * 0.92), 0.6)
    return parts


def _swim(spec, xh, xt):
    """how a species moves: vertices (N x 3) at a phase of the cycle (radians)"""
    span = max(xh - xt, 1e-3)

    def back(a, p):
        return np.clip((xh - a[:, 0]) / span, 0.0, 1.0) ** p

    if spec.get("turtle"):
        def fn(a, ph):                     # the flippers row
            o = a.copy()
            y = np.abs(a[:, 1])
            k = np.clip((y - 0.55) / 0.5, 0.0, 1.0)
            o[:, 2] += k * np.sin(ph + np.where(a[:, 0] > 0, 0.0, 1.6)) * 0.26
            o[:, 0] += k * np.cos(ph) * 0.1
            return o
    elif spec.get("squid"):
        def fn(a, ph):                     # the tentacles trail and wave, the mantle pumps
            o = a.copy()
            k = np.clip((-0.5 - a[:, 0]) / 0.8, 0.0, 1.0)
            o[:, 1] += k * np.sin(ph * 1.0 + a[:, 0] * 4.0) * 0.16
            o[:, 2] += k * np.cos(ph * 1.0 + a[:, 0] * 4.0 + a[:, 1] * 5.0) * 0.12
            m = np.clip((a[:, 0] + 0.5) / 1.3, 0.0, 1.0)
            o[:, 1] *= 1.0 + m * np.sin(ph) * 0.07
            o[:, 2] *= 1.0 + m * np.sin(ph) * 0.07
            return o
    elif spec.get("crab"):
        def fn(a, ph):                     # the legs paddle
            o = a.copy()
            k = np.clip((np.abs(a[:, 1]) - 0.7) / 0.5, 0.0, 1.0)
            o[:, 2] += k * np.sin(ph + a[:, 0] * 5.0 + np.sign(a[:, 1]) * 1.6) * 0.14
            return o
    elif spec.get("puffer"):
        def fn(a, ph):                     # the paddles row, the tail steers, the body bobs along
            o = a.copy()
            k = np.clip((np.abs(a[:, 1]) - 0.5) / 0.38, 0.0, 1.0)
            o[:, 2] += k * np.sin(ph) * 0.24
            o[:, 0] += k * np.cos(ph) * 0.07
            o[:, 1] += back(a, 5.0) * np.sin(ph) * 0.26
            o[:, 2] += np.sin(ph) * 0.025
            return o
    elif spec.get("dolphin"):
        def fn(a, ph):                     # dolphins beat up and down
            o = a.copy()
            o[:, 2] += back(a, 2.2) * np.sin(ph - (xh - a[:, 0]) * 1.5) * 0.3
            return o
    else:
        amp = 0.3 if spec.get("guardian") else 0.24 * span * 0.5 + 0.06
        power = 2.6 if spec.get("guardian") else 2.0

        def fn(a, ph):                     # the tail swings, a wave down the body
            o = a.copy()
            o[:, 1] += amp * back(a, power) * np.sin(ph - (xh - a[:, 0]) * 1.6)
            return o
    return fn


def render_fish(name, out_path):
    """-> sheet px per model unit"""
    spec = M.FISH_SPECS[name]
    cam = _setup(FISH_CELL)
    parts = _build_puffer(spec) if spec.get("puffer") else M.build_fish(spec)
    root, baked = _bake(parts)
    allv = np.concatenate([a for _, a in baked])
    fn = _swim(spec, float(allv[:, 0].max()), float(allv[:, 0].min()))
    radius = float(np.sqrt((allv[:, :2] ** 2).sum(axis=1).max() + (allv[:, 2] ** 2).max() * 0.4)) * 1.14
    K.outline_all([p for p, _ in baked], 0.03)
    _frame(cam, radius)
    tmp = tempfile.mkdtemp()
    rows = [[] for _ in HEADINGS]
    for f in range(FISH_FRAMES):
        _pose(baked, fn, f / FISH_FRAMES * math.tau)
        for r, h in enumerate(HEADINGS):
            root.rotation_euler = (0, 0, math.radians(h))
            bpy.context.view_layer.update()
            path = os.path.join(tmp, "r%d_f%d.png" % (r, f))
            K.render(path)
            rows[r].append(path)
    _sheet(rows, out_path, FISH_CELL)
    K.SOFT[0] = False
    return round(FISH_CELL / (radius * 2.0), 3)


# ------------------------------------------------------------------- gull
GULL_CELL = 128
GULL_FRAMES = 8
GLIDE_FRAME = 6         # the frame with the wings out (the stage holds it to glide)


def _build_gull():
    white, grey, dark = toon("#fbfaf5"), toon("#a8b6c4"), toon("#2a2f38")
    body = sphere(scale=1.0, seg=32, rings=16)
    K.deform(body, lambda co: type(co)((co.x * 0.62, co.y * 0.23 * (0.55 + 0.45 * min(1.0, (co.x + 1.0))), co.z * 0.23 * (0.55 + 0.45 * min(1.0, (co.x + 1.0))))))
    body.data.materials.append(white)
    head = sphere(loc=(0.52, 0.0, 0.13), scale=(0.21, 0.19, 0.19), mat=white)
    beak = cone(loc=(0.8, 0.0, 0.1), r1=0.075, r2=0.015, depth=0.28, rot=(0, 90, 0), verts=12, mat=toon("#f7a823"))
    tip = sphere(loc=(0.75, 0.0, 0.065), scale=(0.05, 0.05, 0.022), mat=toon("#e0452f"))
    tail = extrude_poly([(-0.45, 0.1), (-0.98, 0.2), (-1.02, 0.0), (-0.98, -0.2), (-0.45, -0.1)], 0.03, mat=toon("#eef1f3"))
    tail.location = (0, 0, 0.03)
    parts = [body, head, beak, tip, tail]
    for side in (1, -1):
        eye = sphere(loc=(0.6, side * 0.145, 0.19), scale=0.052, mat=toon("#141018", shade=1.0, rim=0.0))
        shine = sphere(loc=(0.625, side * 0.177, 0.21), scale=0.016, mat=toon("#ffffff", flat_glow=True))
        eye["no_outline"] = shine["no_outline"] = True
        parts += [eye, shine]
    wings = []
    s = 1.0
    for side in (1, -1):
        inner = extrude_poly([(0.22, 0.0), (0.24, side * 0.56), (-0.14 * s, side * 0.62), (-0.25, side * 0.34), (-0.24, 0.0)], 0.03, mat=grey)
        inner.location = (0.06, side * 0.14, 0.12)
        outer = extrude_poly([(0.24, 0.0), (0.12, side * 0.5), (-0.02, side * 0.9), (-0.08, side * 0.62), (-0.16, side * 0.5), (-0.14, 0.0)], 0.028, mat=grey)
        outer.parent = inner
        outer.location = (0.0, side * 0.58, 0.0)
        blacktip = extrude_poly([(0.095, side * 0.56), (-0.02, side * 0.9), (-0.075, side * 0.62), (-0.1, side * 0.5)], 0.034, mat=dark)
        blacktip.parent = outer
        for o in (inner, outer):
            o.rotation_mode = "XYZ"
        wings.append((inner, outer, side))
        parts += [inner, outer, blacktip]
    return parts, wings


def render_gull(out_path):
    """-> the manifest entry"""
    cam = _setup(GULL_CELL, samples=12)
    parts, wings = _build_gull()
    root = bpy.data.objects.new("gull", None)
    bpy.context.collection.objects.link(root)
    for p in parts:
        if p.parent is None:
            p.parent = root
    K.outline_all(parts, 0.022)
    radius = 1.3
    _frame(cam, radius, 0.1)
    tmp = tempfile.mkdtemp()
    rows = [[] for _ in HEADINGS]
    for f in range(GULL_FRAMES):
        ph = f / GULL_FRAMES * math.tau
        a1 = 30.0 * math.cos(ph) + 6.0                 # the shoulder
        a2 = 24.0 * math.cos(ph - 1.1) - 8.0           # the wrist follows a little later
        for inner, outer, side in wings:
            inner.rotation_euler = (math.radians(side * a1), 0, 0)
            outer.rotation_euler = (math.radians(side * a2), 0, 0)
        root.location.z = -0.05 * math.cos(ph)         # (the body rises as the wings beat down)
        for r, h in enumerate(HEADINGS):
            root.rotation_euler = (0, 0, math.radians(h))
            bpy.context.view_layer.update()
            path = os.path.join(tmp, "r%d_f%d.png" % (r, f))
            K.render(path)
            rows[r].append(path)
    _sheet(rows, out_path, GULL_CELL)
    K.SOFT[0] = False
    return {"cell": GULL_CELL, "frames": GULL_FRAMES, "unit_px": round(GULL_CELL / (radius * 2.0), 3), "glide": GLIDE_FRAME}


# ------------------------------------------------------------------- crab
CRAB_CELL = 96
CRAB_FRAMES = 6


def _build_crab(top="#ee5a34", belly="#ffc29a", claw="#f0603a", leg="#d9472a"):
    shell = sphere(scale=(0.66, 0.84, 0.36), seg=28, rings=14)
    t, b = hexc(top), hexc(belly)
    K.vcolor(shell, lambda co, n: K.mix(b, t, min(1.0, max(0.0, co.z / 0.36 + 0.45))))
    shell.data.materials.append(toon(None, vcol="col", key=("crabshell", top)))
    groups = {"body": [shell], "legs": [], "claws": [], "eyes": []}
    for side in (1, -1):
        for i in range(3):
            x = -0.34 + i * 0.27
            o = tube([(x, side * 0.7, 0.02), (x - 0.12, side * 1.06, 0.2), (x - 0.2, side * 1.28, -0.32)], 0.055, mat=toon(leg), taper=(1.0, 0.45))
            o["leg"] = (i, side)
            groups["legs"].append(o)
        arm = tube([(0.38, side * 0.62, 0.06), (0.68, side * 0.92, 0.2), (0.86, side * 0.8, 0.3)], 0.08, mat=toon(leg))
        palm = sphere(loc=(1.0, side * 0.76, 0.36), scale=(0.3, 0.21, 0.19), mat=toon(claw))
        finger = cone(loc=(1.3, side * 0.68, 0.45), r1=0.1, r2=0.0, depth=0.3, rot=(0, 75, side * -16), mat=toon(claw))
        thumb = cone(loc=(1.26, side * 0.87, 0.3), r1=0.08, r2=0.0, depth=0.24, rot=(0, 100, side * 16), mat=toon(claw))
        for o in (arm, palm, finger, thumb):
            o["side"] = side
        groups["claws"] += [arm, palm, finger, thumb]
        stalk = tube([(0.46, side * 0.2, 0.22), (0.56, side * 0.24, 0.56)], 0.035, mat=toon(leg))
        eye = sphere(loc=(0.57, side * 0.25, 0.64), scale=0.125, mat=toon("#ffffff"))
        pupil = sphere(loc=(0.66, side * 0.27, 0.65), scale=0.07, mat=toon("#141018", shade=1.0, rim=0.0))
        shine = sphere(loc=(0.7, side * 0.3, 0.69), scale=0.022, mat=toon("#ffffff", flat_glow=True))
        for o in (eye, pupil, shine):
            o["no_outline"] = True
        groups["eyes"] += [stalk, eye, pupil, shine]
    smile = K.torus(loc=(0.62, 0.0, 0.03), R=0.1, r=0.016, rot=(0, 90, 0), mat=toon("#7a2415"))
    smile["no_outline"] = True
    groups["body"].append(smile)
    return groups


def render_crab(out_path):
    """rows: walking sideways, idling (the claws wave) -> the manifest entry"""
    cam = _setup(CRAB_CELL, samples=12)
    groups = _build_crab()
    parts = [p for g in groups.values() for p in g]
    root, baked = _bake(parts)
    info = {p: a for p, a in baked}
    K.outline_all(parts, 0.03)
    radius = 1.75
    _frame(cam, radius, 0.1)
    root.rotation_euler = (0, 0, math.radians(-90.0))       # it looks at you and walks sideways

    def pose(ph, walking):
        bob = 0.03 * math.sin(ph * 2.0) if walking else 0.015 * math.sin(ph)
        for p in groups["legs"]:
            a = info[p]
            i, side = p["leg"]
            k = np.clip((np.abs(a[:, 1]) - 0.7) / 0.58, 0.0, 1.0)
            step = ph + i * 2.1 + (0.0 if side > 0 else math.pi)
            o = a.copy()
            if walking:
                o[:, 2] += k * max(math.sin(step), 0.0) * 0.26
                o[:, 1] += k * math.cos(step) * 0.14
            o[:, 2] += bob
            p.data.vertices.foreach_set("co", o.ravel())
            p.data.update()
        for p in groups["claws"]:
            a = info[p]
            o = a.copy()
            lift = (0.05 * math.sin(ph + (0.0 if p["side"] > 0 else 1.2))) if walking else (0.11 * max(math.sin(ph + (0.0 if p["side"] > 0 else 2.2)), 0.0))
            o[:, 2] += lift * np.clip((a[:, 0] - 0.3) / 0.8, 0.0, 1.0) * 2.0 + bob
            p.data.vertices.foreach_set("co", o.ravel())
            p.data.update()
        for p in groups["body"] + groups["eyes"]:
            a = info[p]
            o = a.copy()
            o[:, 2] += bob
            p.data.vertices.foreach_set("co", o.ravel())
            p.data.update()

    tmp = tempfile.mkdtemp()
    rows = [[], []]
    for r, walking in enumerate((True, False)):
        for f in range(CRAB_FRAMES):
            pose(f / CRAB_FRAMES * math.tau, walking)
            bpy.context.view_layer.update()
            path = os.path.join(tmp, "r%d_f%d.png" % (r, f))
            K.render(path)
            rows[r].append(path)
    _sheet(rows, out_path, CRAB_CELL)
    K.SOFT[0] = False
    return {"cell": CRAB_CELL, "frames": CRAB_FRAMES, "unit_px": round(CRAB_CELL / (radius * 2.0), 3)}


# ------------------------------------------------------------ whale and manta
BIG_CELL = 192
BIG_FRAMES = 8


def render_big(model, out_path):
    cam = _setup(BIG_CELL)
    meshes, arm, roots = V.import_glb(os.path.join(V.GLB, model + ".glb"))
    root = V.group_root(roots)
    root.rotation_euler = (0, 0, math.radians(90))          # nose -Y -> +X
    for m in meshes:
        for i, mt in enumerate(m.data.materials):
            if mt is None:
                continue
            mt = mt.copy()
            m.data.materials[i] = mt
            V.toonify(mt)
    act = V.set_action(arm, "swim")
    sc = bpy.context.scene
    fr = act.frame_range if act else (1, 2)
    V.outline_skinned(meshes, 0.05)
    V.render_sheet(out_path, lambda i: sc.frame_set(int(fr[0] + (fr[1] - fr[0]) * i / BIG_FRAMES)), BIG_FRAMES, BIG_CELL, cam, meshes, 1.05)
    K.SOFT[0] = False


def render_all(out_dir, only=None):
    """-> the manifest's "life" entry"""
    os.makedirs(out_dir, exist_ok=True)
    slug = lambda n: n.lower().replace(" ", "_")
    want = lambda n: not only or n in only
    e = {"cell": FISH_CELL, "frames": FISH_FRAMES, "rows": len(HEADINGS), "headings": list(HEADINGS), "fish": {}, "big": {"cell": BIG_CELL, "frames": BIG_FRAMES}}
    for name in BIOME_FISH:
        if want(name):
            e["fish"][name] = render_fish(name, os.path.join(out_dir, slug(name) + ".png"))
    if want("gull"):
        e["gull"] = render_gull(os.path.join(out_dir, "gull.png"))
    if want("crab"):
        e["crab"] = render_crab(os.path.join(out_dir, "crab.png"))
    for m in ("whale", "manta"):
        if want(m):
            render_big(m, os.path.join(out_dir, m + ".png"))
    return e

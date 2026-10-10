"""Animated sprite sheets from vendor models:
- swimming fish (Quaternius Animated Fish, CC0), recoloured per VF species
- ambient whale / manta ray, seagull and crab (Poly by Google, CC-BY 3.0)
- the fisher: see vf_fisher.py (original puppet, sits on a cooler).
All sheets face +X and use the top-down camera pitch from vf_topdown.
"""
import math
import os

import bpy
from mathutils import Euler, Matrix, Vector

import vf_kit as K
import vf_vendor as V
import vf_topdown as TD
from vf_kit import cone, cyl, sphere, toon, torus

# species -> (model, {material: colour} or None)
SWIMMERS = {
    "Raw Fish":      ("fish2", {"Top": "#6f8fa8", "Bottom": "#dfe9ef", "Fins": "#57738a"}),
    "Raw Salmon":    ("fish2", {"Top": "#c86b5a", "Bottom": "#f6c4ae", "Fins": "#a8574a"}),
    "Cod":           ("fish3", {"Body": "#9a8a5c", "Front": "#efe6c8", "Fins": "#7e7049"}),
    "Tropical Fish": ("fish1", None),
    "Hot Cod":       ("fish3", {"Body": "#e2452b", "Front": "#ffc38a", "Fins": "#b52a1d"}),
    "Dolphin":       ("dolphin", None),
    "Shark":         ("shark", None),
    "Rainbow Fish":  ("fish2", {"Top": "#ff6bd6", "Bottom": "#7fe3ff", "Fins": "#ffd23f"}),
    "Space Fish":    ("fish2", {"Top": "#3a2a8a", "Bottom": "#8f7dff", "Fins": "#c56bff"}),
    "Alien Fish":    ("fish3", {"Body": "#23c48f", "Front": "#c4ffe8", "Fins": "#a24bff"}),
    "Artifact Fish": ("fish1", {"Body": "#c99a2e", "Stripes": "#3ff2e4", "Outline": "#5a3a10"}),
    "Dark Tuna":     ("fish3", {"Body": "#151b2e", "Front": "#3c4466", "Fins": "#5ff2ff"}),
    "whale":         ("whale", None),
    "manta":         ("manta", None),
}
FRAMES = 8
CELL = 128


def _setup(size, cam_rot):
    K.clear_scene()
    V.clear_library()
    K.SOFT[0] = True
    K.setup_render(size, size, samples=12)
    K.setup_world("#9aa6b0", 1.0)
    s = K.sun((35, 0, 30), 1.0)
    s.data.angle = math.radians(7)
    return K.make_camera(cam_rot, ortho=True)


def render_swimmer(key, out_path):
    model, tints = SWIMMERS[key]
    cam = _setup(CELL, (0, 0, 0))
    meshes, arm, roots = V.import_glb(os.path.join(V.GLB, model + ".glb"))
    root = V.group_root(roots)
    root.rotation_euler = (0, 0, math.radians(90))          # nose -Y -> +X
    for m in meshes:
        for i, mt in enumerate(m.data.materials):
            if mt is None:
                continue
            mt = mt.copy()
            m.data.materials[i] = mt
            V.toonify(mt, tint=(tints or {}).get(mt.name.split(".")[0]))
    act = V.set_action(arm, "swim")
    sc = bpy.context.scene
    fr = act.frame_range if act else (1, 2)
    V.outline_skinned(meshes, 0.05 if model in ("whale", "manta") else 0.035)
    step = lambda i: sc.frame_set(int(fr[0] + (fr[1] - fr[0]) * i / FRAMES))
    V.render_sheet(out_path, step, FRAMES, CELL, cam, meshes, 1.05)


def render_static(model, out_path, size=128, rot_z=90):
    cam = _setup(size, (0, 0, 0))
    meshes, arm, roots = V.import_glb(os.path.join(V.GLB, model + ".glb"))
    root = V.group_root(roots)
    root.rotation_euler = (0, 0, math.radians(rot_z))
    for m in meshes:
        for mt in m.data.materials:
            V.toonify(mt)
    V.outline_skinned(meshes, 0.03)
    bpy.context.view_layer.update()
    V.normalize(meshes, root, length=2.0)
    V.render_sheet(out_path, lambda i: None, 1, size, cam, meshes, 1.05)


# ------------------------------------------------------------------ fisher
def render_fisher(out_dir):
    """The fisher (vf_fisher.py): per-anim sheets + manifest info (frames, fps,
    rod_grip / rod_tip / head per frame, the anchor "feet", 0..1 in the cell)."""
    import vf_fisher
    info = vf_fisher.render(out_dir, lambda size: _setup(size, TD.CAM_ROT))
    K.SOFT[0] = False
    return info


# ------------------------------------------------------------ rod strips
STRIP = (512, 96)


def render_rod_strip(name, out_path):
    """Equipped-rod sprite: the rod laid horizontally (grip left, tip right)."""
    import vf_models as M
    K.clear_scene()
    K.SOFT[0] = True
    K.setup_render(*STRIP, samples=16)
    K.setup_world("#9aa6b0", 1.0)
    K.sun((30, 0, 20), 1.0)
    cam = K.make_camera((90, 0, 0), ortho=True)
    K.seed(1)
    parts, base, tip = M.build_rod(M.ROD_SPECS[name], strip=True)
    d = (tip - base).normalized()
    grip = base + d * 0.2
    root = K.parent_all(parts, "rod")
    root.rotation_euler = (0, math.radians(45), 0)
    bpy.context.view_layer.update()
    lo, hi = V.world_bbox([p for p in parts if p.type == "MESH"])
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    box = bpy.context.active_object
    box.location = (lo + hi) / 2
    box.scale = hi - lo
    bpy.context.view_layer.update()
    K.frame_ortho(cam, [box], 1.04)
    bpy.data.objects.remove(box)
    K.outline_all(parts, 0.02)
    K.render(out_path)
    R = root.matrix_world
    g = K.project(cam, R @ grip)
    t = K.project(cam, R @ tip)
    K.SOFT[0] = False
    return {"grip": [round(g[0] / STRIP[0], 4), round(g[1] / STRIP[1], 4)],
            "tip": [round(t[0] / STRIP[0], 4), round(t[1] / STRIP[1], 4)]}


# ------------------------------------------------------------------ gull
def render_gull(out_path, n=8, size=160):
    """Seagull flap cycle seen from above, facing +X (wings bend at the shoulder)."""
    cam = _setup(size, (0, 0, 0))
    meshes, arm, roots = V.import_glb(os.path.join(V.GLB, "gull.glb"))
    root = V.group_root(roots)
    for m in meshes:
        for mt in m.data.materials:
            V.toonify(mt)
    bpy.context.view_layer.update()
    V.normalize(meshes, root, length=2.0)
    gull = meshes[0]
    mw = gull.matrix_world.copy()
    gull.parent = None
    gull.matrix_world = mw
    bpy.ops.object.select_all(action="DESELECT")
    gull.select_set(True)
    bpy.context.view_layer.objects.active = gull
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    base = [v.co.copy() for v in gull.data.vertices]
    ymax = max(abs(c.y) for c in base)
    w0 = ymax * 0.16

    def flap(i):
        a = math.radians(40) * math.sin(math.tau * i / n)
        for v, c in zip(gull.data.vertices, base):
            r = abs(c.y) - w0
            if r <= 0:
                v.co = c
                continue
            sgn = 1.0 if c.y > 0 else -1.0
            v.co = (c.x, sgn * (w0 + r * math.cos(a)), c.z + r * math.sin(a))
        gull.data.update()
    flap(0)
    K.add_outline(gull, 0.03)
    V.render_sheet(out_path, flap, n, size, cam, [gull], 1.05)
    K.SOFT[0] = False


# --------------------------------------------------------------- merchant
MERCHANT_CELL = 384
MERCHANT_ANIMS = {"idle": ("Idle_Neutral", 8), "wave": ("Wave", 10)}


def _stall():
    """Market stall around the origin, counter facing -Y (toward the camera)."""
    from vf_kit import cube, cyl
    import vf_models as M
    t = lambda c: toon(c, soft=True)
    parts = [cube(loc=(0, -0.35, 0.45), scale=(2.6, 0.7, 0.9), mat=t("#a8723f"), bevel=0.04),
             cube(loc=(0, -0.35, 0.93), scale=(2.75, 0.85, 0.08), mat=t("#c48a52"), bevel=0.02)]
    for x in (-1.3, 1.3):
        for y in (-0.75, 0.75):
            parts.append(cyl(loc=(x, y, 1.15), r=0.06, depth=2.3, mat=t("#7a5232"), verts=10))
    for i in range(7):
        x = -1.5 + i * 0.5
        parts.append(cube(loc=(x, 0.45, 2.3), scale=(0.5, 1.0, 0.07), rot=(-22, 0, 0),
                          mat=t("#e0533e" if i % 2 == 0 else "#f6efe2")))
    for x, c in ((-0.8, "#6f8fa8"), (0.0, "#ffb02e"), (0.8, "#c86b5a")):
        crate = cube(loc=(x, -0.5, 1.1), scale=(0.62, 0.45, 0.22), mat=t("#c9a36a"), bevel=0.02)
        parts.append(crate)
        for k in range(3):
            f = M.build_fish(dict(top=c, belly="#eef3f6", fin=c, L=0.22, H=0.09, W=0.06))
            for o in f:
                o.location += Vector((x - 0.15 + k * 0.15, -0.5, 1.25))
            parts += f
    parts.append(cyl(loc=(1.75, 0.3, 0.45), r=0.38, depth=0.9, mat=t("#9a6a3c"), verts=16))
    parts.append(cube(loc=(-1.8, -0.4, 0.3), scale=(0.6, 0.6, 0.6), mat=t("#b07a4a"), bevel=0.03))
    parts.append(cube(loc=(-1.75, -1.2, 0.7), scale=(0.08, 0.08, 1.4), mat=t("#7a5232")))
    parts.append(cube(loc=(-1.75, -1.25, 1.3), scale=(0.9, 0.08, 0.5), mat=t("#f2e3c0"), bevel=0.03))
    parts.append(cube(loc=(-1.75, -1.3, 1.3), scale=(0.62, 0.02, 0.16), mat=t("#c0392b")))
    return parts


MARKET_MODEL = "village"       # Quaternius "Market Stalls" (CC0), see CREDITS.md


def _market(model, length=7.0):
    """Quaternius market stalls, cel-shaded, centred at the origin."""
    meshes, arm, roots = V.import_glb(os.path.join(V.GLB, "market", model + ".glb"))
    root = V.group_root(roots, "market")
    for m in meshes:
        for mt in m.data.materials:
            if mt:
                V.toonify(mt)
    bpy.context.view_layer.update()
    V.normalize(meshes, root, length=length, center=False)
    return meshes


def _bait_shack():
    """Fishing 'Bait & Tackle' shack: Quaternius Storage Hut (CC0) dressed
    with rods, a fish-drying rack, bait buckets and a sign."""
    from vf_kit import cube, cyl, torus
    import vf_models as M
    t = lambda c: toon(c, soft=True)
    parts = _market("storage", length=5.2)
    lo, hi = V.world_bbox(parts)
    front = lo.y - 0.05
    # sign over the door
    parts.append(cube(loc=(0, front - 0.05, hi.z * 0.62), scale=(2.4, 0.1, 0.55), mat=t("#f2e3c0"), bevel=0.04))
    parts.append(cube(loc=(0, front - 0.11, hi.z * 0.62), scale=(1.9, 0.02, 0.2), mat=t("#2f8f8a")))
    # rods leaning on the front wall
    for i, c in enumerate(["#4aa3ff", "#ffd23f", "#e0533e"]):
        x = 1.0 + i * 0.28
        parts.append(K.tube([(x, front - 0.1, 0.1), (x + 0.15, front - 0.05, 2.4)], 0.035, mat=t(c), taper=(1.0, 0.5)))
    # fish drying rack on the left with hanging fish
    rx = lo.x - 0.6
    for y in (front + 0.3, front + 1.6):
        parts.append(cyl(loc=(rx, y, 0.9), r=0.06, depth=1.8, mat=t("#7a5232"), verts=8))
    parts.append(cyl(loc=(rx, front + 0.95, 1.75), r=0.05, depth=1.4, rot=(90, 0, 0), mat=t("#7a5232"), verts=8))
    for k, col in enumerate(["#6f8fa8", "#c86b5a", "#9a8a5c", "#6f8fa8"]):
        f = M.build_fish(dict(top=col, belly="#eef3f6", fin=col, L=0.32, H=0.12, W=0.08))
        y = front + 0.45 + k * 0.32
        for o in f:
            o.rotation_euler = (0, math.radians(90), 0)
            o.location = Vector((rx, y, 1.35)) + o.location.copy() * 0
        parts += f
    # bait buckets and a barrel of fish by the door
    for x, c in ((-1.1, "#4f86c6"), (-0.6, "#e07a3a")):
        parts.append(cyl(loc=(x, front - 0.5, 0.25), r=0.22, depth=0.5, mat=t(c), verts=16))
        parts.append(cyl(loc=(x, front - 0.5, 0.48), r=0.18, depth=0.04, mat=t("#6b4a2e"), verts=16))
    parts.append(cyl(loc=(lo.x + 0.2, front - 0.6, 0.4), r=0.35, depth=0.8, mat=t("#9a6a3c"), verts=16))
    for k in range(3):
        f = M.build_fish(dict(top="#ffb02e", belly="#fff1c9", fin="#2b7de9", L=0.2, H=0.1, W=0.05))
        for o in f:
            o.location += Vector((lo.x + 0.05 + k * 0.15, front - 0.6, 0.85))
        parts += f
    parts.append(torus(loc=(hi.x + 0.3, front + 0.4, 0.06), R=0.35, r=0.07, mat=t("#d8c49a")))
    return parts


def _fish_shop():
    """'Bait & Tackle' fish shop designed for the top-down camera: bold teal
    roof with a big fish sign, striped awning over a counter of fish on ice."""
    from vf_kit import cube, cyl, torus, extrude_poly
    import vf_models as M
    t = lambda c, **k: toon(c, soft=True, **k)
    P = []
    # deck
    for i in range(9):
        P.append(cube(loc=(-2.4 + i * 0.6, 0.2, 0.08), scale=(0.56, 4.6, 0.16), mat=t("#b07a4a" if i % 2 else "#a8723f")))
    # building
    W, D, Hh = 3.8, 2.6, 2.0
    P.append(cube(loc=(0, 0.9, Hh / 2 + 0.16), scale=(W, D, Hh), mat=t("#e6cfa2"), bevel=0.04))
    for x in (-1.4, -0.7, 0.0, 0.7, 1.4):
        P.append(cube(loc=(x, 0.9 - D / 2 - 0.01, Hh / 2 + 0.16), scale=(0.05, 0.02, Hh), mat=t("#c9ad7e")))
    P.append(cube(loc=(-1.0, 0.9 - D / 2 - 0.03, 0.95), scale=(0.75, 0.04, 1.45), mat=t("#5a3a24")))       # door
    P.append(cube(loc=(1.0, 0.9 - D / 2 - 0.03, 1.3), scale=(0.9, 0.04, 0.65), mat=t("#8fd3ff", emit=0.15)))  # window
    for dx in (-0.55, 0.55):
        P.append(cube(loc=(1.0 + dx, 0.9 - D / 2 - 0.05, 1.3), scale=(0.18, 0.04, 0.72), mat=t("#2f8f9e")))
    # gable roof (two slabs) in bold teal, with ridge
    for sgn in (1, -1):
        slab = cube(loc=(0, 0.9 + sgn * 0.78, Hh + 0.75), scale=(W + 0.7, 1.85, 0.16), rot=(sgn * 32, 0, 0), mat=t("#2fa3a8"))
        P.append(slab)
        for k in range(5):
            P.append(cube(loc=(-1.9 + k * 0.95, 0.9 + sgn * 0.78, Hh + 0.85), scale=(0.08, 1.8, 0.04), rot=(sgn * 32, 0, 0),
                          mat=t("#1f7f86")))
    P.append(cyl(loc=(0, 0.9, Hh + 1.27), r=0.12, depth=W + 0.8, rot=(0, 90, 0), mat=t("#f2e3c0"), verts=10))
    # big golden fish sign on the ridge
    fish = M.build_fish(dict(top="#ffcf3f", belly="#fff1a8", fin="#e0a01f", L=1.25, H=0.55, W=0.2))
    for o in fish:
        o.location = o.location + Vector((0, 0.9, Hh + 2.0))
    P += fish
    P.append(cyl(loc=(0, 0.9, Hh + 1.55), r=0.05, depth=0.6, mat=t("#7a5232"), verts=8))
    # awning + counter of fish on ice in front
    for i in range(6):
        P.append(cube(loc=(-1.25 + i * 0.5, -0.75, Hh + 0.05), scale=(0.5, 1.1, 0.06), rot=(-20, 0, 0),
                      mat=t("#2fa3a8" if i % 2 == 0 else "#f6efe2")))
    P.append(cube(loc=(0, -0.9, 0.6), scale=(3.0, 0.8, 0.9), mat=t("#a8723f"), bevel=0.04))
    P.append(cube(loc=(0, -0.9, 1.08), scale=(2.8, 0.66, 0.06), mat=t("#eaf6ff")))                       # ice
    for k, col in enumerate(["#6f8fa8", "#c86b5a", "#ffb02e", "#9a8a5c", "#6f8fa8", "#c86b5a"]):
        f = M.build_fish(dict(top=col, belly="#eef3f6", fin=col, L=0.22, H=0.09, W=0.06))
        for o in f:
            o.location = o.location + Vector((-1.15 + k * 0.46, -0.9, 1.2))
        P += f
    # life ring, barrels, bait buckets, rod rack, lantern
    P.append(torus(loc=(2.05, 0.9 - D / 2 - 0.1, 1.4), R=0.32, r=0.09, rot=(90, 0, 0), mat=t("#e0533e")))
    for a in range(4):
        P.append(cube(loc=(2.05 + 0.32 * math.cos(a * math.pi / 2), 0.9 - D / 2 - 0.2, 1.4 + 0.32 * math.sin(a * math.pi / 2)),
                      scale=(0.1, 0.06, 0.1), mat=t("#ffffff")))
    for x, y in ((-2.3, -0.9), (-2.3, -0.2)):
        P.append(cyl(loc=(x, y, 0.55), r=0.32, depth=0.8, mat=t("#9a6a3c"), verts=16))
        P.append(cyl(loc=(x, y, 0.97), r=0.33, depth=0.05, mat=t("#6b4a2e"), verts=16))
    for x, c in ((1.9, "#4f86c6"), (2.35, "#e07a3a")):
        P.append(cyl(loc=(x, -1.6, 0.36), r=0.2, depth=0.45, mat=t(c), verts=16))
    for i, c in enumerate(["#4aa3ff", "#ffd23f", "#e0533e", "#3fbf6a"]):
        x = 2.25 + i * 0.12
        P.append(K.tube([(x, 0.9 + D / 2 - 0.2, 0.2), (x + 0.05, 0.9 + D / 2 + 0.2, 2.6)], 0.03, mat=t(c), taper=(1.0, 0.5)))
    P.append(cyl(loc=(-1.75, -1.32, 1.8), r=0.12, depth=0.3, mat=t("#ffd76a", emit=0.6), verts=10))
    return P


SHOP_MODEL = "fish_shop"


def render_merchant(out_dir, model=None):
    os.makedirs(out_dir, exist_ok=True)
    cam = _setup(MERCHANT_CELL, TD.CAM_ROT)
    model = model or SHOP_MODEL
    stall = _fish_shop() if model == "fish_shop" else _bait_shack() if model == "bait_shack" else _market(model)
    meshes, arm, roots = V.import_glb(os.path.join(V.GLB, "character.glb"))
    root = V.group_root(roots, "merchant")
    root.location = (1.3, -1.9, 0.16)                 # beside the counter on the deck, facing the camera (-Y)
    for m in meshes:
        for mt in m.data.materials:
            name = mt.name.split(".")[0]
            V.toonify(mt, tint={"Grey": "#2f8f8a", "White": "#f6efe2", "Orange": "#5a3a24"}.get(name))
    V.set_action(arm, MERCHANT_ANIMS["idle"][0])
    sc = bpy.context.scene
    sc.frame_set(1)
    bpy.context.view_layer.update()
    head = arm.matrix_world @ arm.pose.bones["Head"].tail
    cap = [cyl(loc=head + Vector((0, 0, -0.03)), r=0.2, depth=0.14, mat=toon("#c0392b", soft=True)),
           cyl(loc=head + Vector((0, -0.12, -0.08)), r=0.17, depth=0.03, scale=(1.0, 1.4, 1.0), mat=toon("#c0392b", soft=True))]
    for c in cap:
        mw = c.matrix_world.copy()
        c.parent = arm
        c.parent_type = "BONE"
        c.parent_bone = "Head"
        bpy.context.view_layer.update()
        c.matrix_world = mw
    everything = stall + meshes + cap
    lo, hi = V.world_bbox([o for o in everything if o.type == "MESH"])
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    box = bpy.context.active_object
    box.location = (lo + hi) / 2
    box.scale = (hi - lo) * 1.05
    bpy.context.view_layer.update()
    K.frame_ortho(cam, [box], 1.04)
    bpy.data.objects.remove(box)
    for o in everything:
        if o.type == "MESH":
            o["outline_even"] = False
            K.add_outline(o, 0.025 / max(o.matrix_world.to_scale()))
    info = {}
    import tempfile
    for key, (act_name, n) in MERCHANT_ANIMS.items():
        act = V.set_action(arm, act_name)
        fr = act.frame_range
        tmp = tempfile.mkdtemp()
        paths = []
        for i in range(n):
            sc.frame_set(int(fr[0] + (fr[1] - fr[0]) * i / n))
            pth = os.path.join(tmp, "f%02d.png" % i)
            K.render(pth)
            paths.append(pth)
        V._stitch(paths, os.path.join(out_dir, key + ".png"), MERCHANT_CELL)
        info[key] = {"frames": n}
    g = K.project(cam, (0, 0, 0))
    _, _, scale, _ = cam["frame"]
    info["anchor"] = [round(g[0] / MERCHANT_CELL, 4), round(g[1] / MERCHANT_CELL, 4)]
    info["unit_px"] = round(MERCHANT_CELL / scale, 3)
    info["cell"] = MERCHANT_CELL
    K.SOFT[0] = False
    return info

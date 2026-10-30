"""Animated sprite sheets from vendor models:
- swimming fish (Quaternius Animated Fish, CC0), recoloured per VF species
- ambient whale / manta ray, seagull and crab (Poly by Google, CC-BY 3.0)
- the captain and the shopkeeper: KayKit characters, see vf_captain.py.
All sheets face +X and use the top-down camera pitch from vf_topdown.
"""
import math
import os

import bpy
from mathutils import Vector

import vf_kit as K
import vf_vendor as V
import vf_topdown as TD

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
    """The captain (vf_captain.py): per-anim sheets + manifest info (frames, fps,
    rod_grip / rod_tip / head per frame, the anchor "feet", 0..1 in the cell)."""
    import vf_captain
    info = vf_captain.render(out_dir, lambda size: _setup(size, TD.CAM_ROT))
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


# ------------------------------------------------------------------ bobber
def render_bobber(out_path, size=96):
    """The float at the end of the line. A quarter of it sits under the waterline (the stage cuts it there)."""
    from vf_kit import cone, cyl, sphere, toon
    cam = _setup(size, TD.CAM_ROT)
    parts = [cone(loc=(0, 0, 0.3), r1=0.05, r2=0.44, depth=0.6, verts=20, mat=toon("#fbf6ea")),
             sphere(loc=(0, 0, 0.62), scale=(0.44, 0.44, 0.34), seg=24, rings=12, mat=toon("#ee3b2c")),
             cyl(loc=(0, 0, 0.6), r=0.455, depth=0.07, verts=24, mat=toon("#fbf6ea")),
             cyl(loc=(0, 0, 1.15), r=0.035, depth=0.55, verts=8, mat=toon("#ee3b2c")),
             sphere(loc=(0, 0, 1.44), scale=0.08, seg=12, rings=8, mat=toon("#ffd23f"))]
    K.outline_all(parts, 0.025)
    K.frame_ortho(cam, parts, 1.05)
    K.render(out_path)
    K.SOFT[0] = False


# --------------------------------------------------------------- merchant
MERCHANT_CELL = 192
MERCHANT_H = 1.6        # the shopkeeper's height, in game units (the shop's door is about that)
MERCHANT_SCALE = 3.0    # game units across a cell
MERCHANT_ANIMS = {"idle": ("Idle_A", 12), "wave": ("Waving", 12)}
# KayKit's Rogue, without the cape, in a shopkeeper's red tunic (swatches of the character's 8 x 4 atlas)
MERCHANT_SWATCHES = {(0, 1): ("#ff5a3c", "#c9321e"), (1, 1): ("#fff4dc", "#e8d4ae"), (1, 2): ("#fff4dc", "#e8d4ae")}


def render_merchant(out_dir):
    """The shopkeeper, who stands on the shop's deck (the shop itself is part of each backdrop: vf_shop.py)."""
    import vf_captain as C
    os.makedirs(out_dir, exist_ok=True)
    cam = _setup(MERCHANT_CELL, TD.CAM_ROT)
    acts = C.load_actions()
    arm, meshes, root = C.build("Rogue", MERCHANT_H, 30.0, MERCHANT_SWATCHES)
    C.hat(arm, next(m for m in meshes if "Head" in m.name), "#fff4dc", "#2f6fb0", 1.14)
    Rc = cam.rotation_euler.to_matrix()
    right, up, fwd = Rc @ Vector((1, 0, 0)), Rc @ Vector((0, 1, 0)), Rc @ Vector((0, 0, -1))
    cy = 0.75
    cam.location = up * cy - fwd * 50.0
    cam.data.ortho_scale = MERCHANT_SCALE
    cam["frame"] = (0.0, cy, MERCHANT_SCALE, 1.0)
    import tempfile
    info = {}
    for key, (act_name, n) in MERCHANT_ANIMS.items():
        tmp = tempfile.mkdtemp()
        paths = []
        for i in range(n):
            C.set_pose(arm, acts[act_name], C._span(acts[act_name], i / float(n)))
            pth = os.path.join(tmp, "f%02d.png" % i)
            K.render(pth)
            paths.append(pth)
        V._stitch(paths, os.path.join(out_dir, key + ".png"), MERCHANT_CELL)
        info[key] = {"frames": n}
    g = K.project(cam, (0, 0, 0))
    info["anchor"] = [round(g[0] / MERCHANT_CELL, 4), round(g[1] / MERCHANT_CELL, 4)]
    info["unit_px"] = round(MERCHANT_CELL / MERCHANT_SCALE, 3)
    info["cell"] = MERCHANT_CELL
    K.SOFT[0] = False
    return info

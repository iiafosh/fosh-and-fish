"""Animated sprite sheets from vendor models:
- swimming fish (Quaternius Animated Fish, CC0), recoloured per VF species
- ambient whale / manta ray, seagull and crab (Poly by Google, CC-BY 3.0)
- the fisher: Quaternius animated character (CC0) + Quaternius fishing rod
  (CC0) + the project's straw hat, rendered idle / cast / reel.
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
ANIMS = {"idle": ("Idle_Sword", 8), "cast": ("Sword_Slash", 10), "reel": ("Interact", 8)}
FISHER_CELL = 256
ROD_GRIP_AT_MIN_Y = True


def build_fisher():
    meshes, arm, roots = V.import_glb(os.path.join(V.GLB, "character.glb"))
    root = V.group_root(roots, "fisher")
    root.rotation_euler = (0, 0, math.radians(90))          # face +X (toward the bobber)
    for m in meshes:
        for mt in m.data.materials:
            name = mt.name.split(".")[0]
            V.toonify(mt, tint={"Grey": "#e8553b", "White": "#f2efe6", "Orange": "#2f4a7a"}.get(name))
    V.set_action(arm, ANIMS["idle"][0])
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    pb = arm.pose.bones

    def bone_world(b, tail=False):
        return arm.matrix_world @ (pb[b].tail if tail else pb[b].head)

    def attach(ob, bone):
        bpy.context.view_layer.update()
        mw = ob.matrix_world.copy()
        ob.parent = arm
        ob.parent_type = "BONE"
        ob.parent_bone = bone
        bpy.context.view_layer.update()
        ob.matrix_world = mw

    # straw hat on the head
    head_top = bone_world("Head", tail=True)
    hat = [cone(loc=head_top + Vector((0, 0, -0.02)), r1=0.36, r2=0.02, depth=0.2, mat=toon("#e3c27e", soft=True), verts=40),
           torus(loc=head_top + Vector((0, 0, 0.03)), R=0.15, r=0.016, mat=toon("#2f8f8a", soft=True), seg=32, mseg=8)]
    for h in hat:
        attach(h, "Head")
    # rod in the right hand, pointing forward/up (built here: grip at origin, tip at +Y)
    L = 2.3
    rod = K.tube([(0, 0, 0), (0, L * 0.5, 0), (0, L, 0)], 0.03, mat=toon("#3a2a22", soft=True), taper=(1.2, 0.35))
    grip = cyl(loc=(0, 0.18, 0), r=0.045, depth=0.36, rot=(90, 0, 0), mat=toon("#c48a52", soft=True))
    reel = cyl(loc=(0.06, 0.3, -0.05), r=0.07, depth=0.05, rot=(0, 90, 0), mat=toon("#c0c6cc", soft=True))
    rod = K.join([rod, grip, reel], "rod")
    rod.rotation_mode = "XYZ"
    rod.rotation_euler = Vector((1, 0, 0.6)).normalized().to_track_quat("Y", "Z").to_euler()
    rod.location = bone_world("Wrist.R", tail=True)
    tip = bpy.data.objects.new("rod_tip", None)
    bpy.context.collection.objects.link(tip)
    tip.parent = rod
    tip.location = (0, L, 0)
    grip = bpy.data.objects.new("rod_grip", None)
    bpy.context.collection.objects.link(grip)
    grip.parent = rod
    grip.location = (0, 0.18, 0)
    rod["grip"] = grip.name
    rod.hide_render = True          # the equipped rod is drawn in-game from rods_hand/ strips
    attach(rod, "Wrist.R")
    return meshes + [rod] + hat, arm, tip


def render_fisher(out_dir):
    """Returns manifest info: per-anim frames, rod tip and feet (0..1 in cell)."""
    os.makedirs(out_dir, exist_ok=True)
    info = {}
    cam = _setup(FISHER_CELL, TD.CAM_ROT)
    objs, arm, tip = build_fisher()
    sc = bpy.context.scene
    # one framing for every animation so the feet stay put between sheets
    allframes = []
    objs = [o for o in objs if not o.hide_render]
    for key, (act_name, n) in ANIMS.items():
        act = V.set_action(arm, act_name)
        fr = act.frame_range
        allframes += [(act, int(fr[0] + (fr[1] - fr[0]) * i / n)) for i in range(n)]
    los, his = [], []
    for act, f in allframes:
        arm.animation_data.action = act
        sc.frame_set(f)
        lo, hi = V.world_bbox([o for o in objs if o.type == "MESH"])
        los.append(lo)
        his.append(hi)
    lo = Vector(map(min, *los))
    hi = Vector(map(max, *his))
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    box = bpy.context.active_object
    box.location = (lo + hi) / 2
    box.scale = hi - lo
    bpy.context.view_layer.update()
    K.frame_ortho(cam, [box], 1.08)
    bpy.data.objects.remove(box)
    for o in objs:
        if o.type == "MESH" and not o.hide_render:
            K.add_outline(o, 0.022 / max(o.matrix_world.to_scale()))
    W = FISHER_CELL
    for key, (act_name, n) in ANIMS.items():
        act = V.set_action(arm, act_name)
        fr = act.frame_range
        tips = []
        grips = []
        grip = bpy.data.objects["rod_grip"]

        def step(i, act=act, fr=fr, n=n):
            arm.animation_data.action = act
            sc.frame_set(int(fr[0] + (fr[1] - fr[0]) * i / n))
        import tempfile
        tmp = tempfile.mkdtemp()
        paths = []
        for i in range(n):
            step(i)
            bpy.context.view_layer.update()
            t = K.project(cam, tip.matrix_world.translation)
            tips.append([round(t[0] / W, 4), round(t[1] / W, 4)])
            g = K.project(cam, grip.matrix_world.translation)
            grips.append([round(g[0] / W, 4), round(g[1] / W, 4)])
            p = os.path.join(tmp, "f%02d.png" % i)
            K.render(p)
            paths.append(p)
        V._stitch(paths, os.path.join(out_dir, key + ".png"), W)
        info[key] = {"frames": n, "rod_tip": tips, "rod_grip": grips}
    feet = K.project(cam, (0, 0, 0))
    _, _, scale, _ = cam["frame"]
    info["feet"] = [round(feet[0] / W, 4), round(feet[1] / W, 4)]
    info["unit_px"] = round(W / scale, 3)
    info["cell"] = W
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

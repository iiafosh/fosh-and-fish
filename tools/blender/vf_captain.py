"""The captain: KayKit's Ranger (Kay Lousberg, CC0) dressed as a fisherman, moved by the KayKit Character
Animations (CC0: Fishing_*, Sit_*, Waving, Cheering ...), rendered as sprite sheets for the stage.
Raw packs live in scratch/downloads (git-ignored): x_kaykit_adventurers, x_kaykit_animations; see CREDITS.md.
"""
import math
import os
import tempfile

import bmesh
import bpy
from mathutils import Quaternion, Vector

import vf_kit as K
import vf_vendor as V
from vf_kit import toon

ADV = os.path.join(V.DL, "x_kaykit_adventurers", "KayKit_Adventurers_2.0_FREE")
ANI = os.path.join(V.DL, "x_kaykit_animations", "KayKit_Character_Animations_1.1", "Animations", "gltf", "Rig_Medium")
ACTION_FILES = ["Rig_Medium_Tools.glb", "Rig_Medium_Simulation.glb", "Rig_Medium_General.glb"]
HEIGHT = 1.75           # his height standing, in game units (a bit big next to the boats, so he reads at game size)
FACE = 42.0             # degrees from facing the camera (-Y) toward +X (where he casts): his face shows from above
DROP = ("Cape", "Quiver")
# the swatches of the Ranger's 8 x 4 colour atlas -> new colours (top, bottom of the swatch's gradient)
SWATCHES = {(5, 0): ("#ffa95f", "#f27d2c"), (6, 0): ("#ffa95f", "#f27d2c"),        # the tunic: an orange vest
            (0, 1): ("#4aa0ea", "#2a62b8"),                                        # the scarf
            (3, 2): ("#58ad52", "#2f7038"),                                        # rubber boots
            (7, 1): ("#43547a", "#2e3a58")}                                        # trousers
UPPER = ("spine", "chest", "head", "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "handslot.l",
         "upperarm.r", "lowerarm.r", "wrist.r", "hand.r", "handslot.r")


def load_actions():
    """every animation of the Rig_Medium sets -> {name: action}; the mannequins they come with are removed"""
    out = {}
    for fn in ACTION_FILES:
        before = set(bpy.data.objects)
        known = set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=os.path.join(ANI, fn))
        for o in [o for o in bpy.data.objects if o not in before]:
            bpy.data.objects.remove(o)
        for a in bpy.data.actions:
            if a not in known:
                a.use_fake_user = True
                out[a.name.split("|")[-1].replace("_Rig_Medium", "")] = a
    return out


def recolor_atlas(meshes, swatches=None, cols=8, rows=4):
    """repaint swatches of the character's colour atlas (a copy of the image, on the material)"""
    swatches = SWATCHES if swatches is None else swatches
    mat = meshes[0].data.materials[0]
    node = next((n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image), None)
    if node is None: return
    src = node.image
    w, h = src.size
    px = list(src.pixels)
    for (c, r), (top, bot) in swatches.items():
        a, b = K.hexc(top), K.hexc(bot)
        x0, x1 = c * w // cols, (c + 1) * w // cols
        y_top, y_bot = h - r * h // rows, h - (r + 1) * h // rows        # (image rows run bottom-up)
        for y in range(y_bot, y_top):
            k = (y_top - 1 - y) / max(1, y_top - y_bot - 1)
            col = [a[i] * (1 - k) + b[i] * k for i in range(3)]
            for x in range(x0, x1):
                o = (y * w + x) * 4
                px[o], px[o + 1], px[o + 2] = col[0], col[1], col[2]
    img = bpy.data.images.new(src.name + "_captain", w, h, alpha=True)
    img.colorspace_settings.name = src.colorspace_settings.name
    img.pixels = px
    node.image = img


def trim_hair(head, above):
    """the hair that would stick through the hat goes: swatch (1, 0) of the atlas, above that height"""
    bm = bmesh.new()
    bm.from_mesh(head.data)
    uv = bm.loops.layers.uv.active
    m = head.matrix_world
    gone = []
    for f in bm.faces:
        u = sum(l[uv].uv[0] for l in f.loops) / len(f.loops)
        v = sum(l[uv].uv[1] for l in f.loops) / len(f.loops)
        z = sum((m @ l.vert.co).z for l in f.loops) / len(f.loops)
        if int(u * 8) == 1 and int((1.0 - v) * 4) == 0 and z > above:
            gone.append(f)
    bmesh.ops.delete(bm, geom=gone, context="FACES_ONLY")
    bm.to_mesh(head.data)
    bm.free()
    head.data.update()


def hat(arm, head, col="#ffc93a", band_col="#e39b1c", brim_r=1.42):
    """a yellow rain hat, low-poly, on the head bone (the hair under it is trimmed)"""
    yellow, band = toon(col), toon(band_col)
    lo, hi = V.world_bbox([head])
    r = (hi.x - lo.x) * 0.5 * 0.82
    z = hi.z - r * 0.46
    cx, cy = (lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5
    trim_hair(head, z - r * 0.1)
    brim = K.cone(loc=(cx, cy, z), r1=r * brim_r, r2=r * 0.84, depth=r * 0.18, verts=24, mat=yellow)
    crown = K.cyl(loc=(cx, cy, z + r * 0.3), r=r * 0.86, depth=r * 0.52, verts=24, mat=yellow)
    top = K.sphere(loc=(cx, cy, z + r * 0.56), scale=(r * 0.86, r * 0.86, r * 0.42), seg=24, rings=10, mat=yellow)
    rib = K.cyl(loc=(cx, cy, z + r * 0.13), r=r * 0.885, depth=r * 0.13, verts=24, mat=band)
    parts = [brim, crown, top, rib]
    K.outline_all(parts, 0.012)
    bpy.context.view_layer.update()
    for p in parts:
        w = p.matrix_world.copy()
        p.parent = arm
        p.parent_type = "BONE"
        p.parent_bone = "head"
        bpy.context.view_layer.update()
        p.matrix_world = w
    return parts


def build(name="Ranger", height=HEIGHT, face=FACE, swatches=None):
    """-> (armature, meshes, root): the fisherman at HEIGHT, feet at the origin, turned toward the camera"""
    meshes, arm, roots = V.import_glb(os.path.join(ADV, "Characters", "gltf", name + ".glb"))
    for m in list(meshes):
        if any(d in m.name for d in DROP):
            meshes.remove(m)
            bpy.data.objects.remove(m)
    root = V.group_root(roots, "captain")
    lo, hi = V.world_bbox(meshes)
    root.scale = (height / hi.z,) * 3
    root.rotation_euler = (0, 0, math.radians(face))
    bpy.context.view_layer.update()
    recolor_atlas(meshes, swatches)
    for m in meshes:
        for mt in m.data.materials:
            V.toonify(mt)
    V.outline_skinned(meshes, 0.018)
    return arm, meshes, root


def bone_world(arm, name):
    return arm.matrix_world @ arm.pose.bones[name].matrix


def _read(arm, action, frame):
    """the bones' local channels of an action at a frame -> {bone: (loc, rot, scale)}"""
    arm.animation_data_create()
    arm.animation_data.action = action
    bpy.context.scene.frame_set(int(math.floor(frame)), subframe=frame - math.floor(frame))
    bpy.context.view_layer.update()
    return {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in arm.pose.bones}


def set_pose(arm, body, body_frame, upper=None, upper_frame=0.0):
    """pose the armature: `body` for everything, `upper` (optional) for the spine, head and arms - e.g. sitting
    legs under fishing arms. The result is written as plain pose values (no action left on the armature)."""
    vals = _read(arm, body, body_frame)
    if upper is not None:
        up = _read(arm, upper, upper_frame)
        for b in UPPER:
            vals[b] = up[b]
    arm.animation_data.action = None
    for b in arm.pose.bones:
        loc, rot, sc = vals[b.name]
        b.location, b.rotation_quaternion, b.scale = loc, rot, sc
    bpy.context.view_layer.update()


# ------------------------------------------------------------------- sprites
CELL = 256
SCALE = 3.1             # game units across a cell
ROD_L = 2.3             # the rod in his hand (the stage draws the equipped rod from grip to tip)
ROD_IDLE = Vector((0.86, -0.12, 0.5)).normalized()    # the way it points while he waits: toward the bobber, up a bit
SEAT = "Sit_Floor_Idle"
UP_FROM = "Sit_Floor_StandUp"


def _nod(i, n, arm):
    """dozing off: the head sinks forward"""
    k = min(1.0, i / 3.0) if i < 7 else max(0.0, 1.0 - (i - 6) / 3.0)
    b = arm.pose.bones["head"]
    b.rotation_quaternion = b.rotation_quaternion @ Quaternion((1, 0, 0), math.radians(30.0 * k))
    s = arm.pose.bones["chest"]
    s.rotation_quaternion = s.rotation_quaternion @ Quaternion((1, 0, 0), math.radians(10.0 * k))


# every sprite animation: frames per second, and its parts: (body, upper body or None, from, to, frames).
# He sits on the deck to fish: sitting legs under the fishing arms. To cheer he gets up ("up"), then sits again.
# rod: "hand" follows his right hand; "park" stays where it is while he waits (the hand is busy with a gesture).
ANIMS = {
    "idle":    dict(fps=7, loop=True, parts=[(SEAT, "Fishing_Idle", 0.0, 1.0, 12)]),
    "cast":    dict(fps=22, parts=[(SEAT, "Fishing_Cast", 0.0, 1.0, 14)]),
    "reel":    dict(fps=18, parts=[(SEAT, "Fishing_Reeling", 0.0, 1.0, 10)]),
    "happy":   dict(fps=16, up=True, parts=[(UP_FROM, None, 0.0, 1.0, 6), ("Cheering", None, 0.0, 1.0, 10)]),
    "dance":   dict(fps=16, up=True, parts=[(UP_FROM, None, 0.0, 1.0, 6), ("Cheering", None, 0.0, 1.0, 10), ("Cheering", None, 0.0, 1.0, 10)]),
    "sit":     dict(fps=14, parts=[("Sit_Floor_Down", None, 0.0, 1.0, 6)]),
    "sad":     dict(fps=8, rod="park", parts=[(SEAT, "Hit_A", 0.0, 1.0, 8)]),
    "shrug":   dict(fps=9, rod="park", parts=[(SEAT, "Interact", 0.0, 1.0, 9)]),
    "yawn":    dict(fps=8, rod="park", parts=[(SEAT, "Idle_A", 0.0, 1.0, 10)]),
    "scratch": dict(fps=9, rod="park", parts=[(SEAT, "Use_Item", 0.0, 1.0, 10)]),
    "look":    dict(fps=8, rod="park", parts=[(SEAT, "Idle_B", 0.0, 1.0, 12)]),
    "wave":    dict(fps=10, rod="park", parts=[(SEAT, "Waving", 0.0, 1.0, 12)]),
    "doze":    dict(fps=7, rod="park", loop_range=[3, 6], hold=3.2, tweak=_nod, parts=[(SEAT, "Fishing_Idle", 0.0, 0.3, 10)]),
}
IDLES = ["yawn", "scratch", "look", "doze", "wave"]


def _span(action, k):
    return action.frame_range[0] + (action.frame_range[1] - action.frame_range[0]) * k


def render(out_dir, setup):
    """Render every animation to out_dir/<anim>.png; returns the manifest "fisher" entry (the stage's format:
    frames, fps, rod_grip / rod_tip / head per frame in 0..1 of the cell, the anchor "feet")."""
    os.makedirs(out_dir, exist_ok=True)
    cam = setup(CELL)
    acts = load_actions()
    arm, meshes, root = build()
    hat(arm, next(m for m in meshes if "Head" in m.name))
    Rc = cam.rotation_euler.to_matrix()
    right, up, fwd = Rc @ Vector((1, 0, 0)), Rc @ Vector((0, 1, 0)), Rc @ Vector((0, 0, -1))
    cx, cy = 0.1, 0.9
    cam.location = right * cx + up * cy - fwd * 50.0
    cam.data.ortho_scale = SCALE
    cam["frame"] = (cx, cy, SCALE, 1.0)
    pt = lambda p: [round(K.project(cam, p)[0] / CELL, 4), round(K.project(cam, p)[1] / CELL, 4)]
    # the rod's direction in the hand's frame, from how he holds it while waiting
    sit, fish = acts[SEAT], acts["Fishing_Idle"]
    set_pose(arm, sit, _span(sit, 0.5), fish, _span(fish, 0.0))
    m0 = bone_world(arm, "handslot.r")
    rod_local = m0.to_3x3().inverted() @ ROD_IDLE
    park = (m0.to_translation().copy(), m0.to_translation() + ROD_IDLE * ROD_L)
    info = {}
    only = os.environ.get("VF_FISHER_ONLY", "")
    for name, a in ANIMS.items():
        grips, tips, heads, paths = [], [], [], []
        tmp = tempfile.mkdtemp()
        i = 0
        total = sum(p[4] for p in a["parts"])
        for body, upper, t0, t1, n in a["parts"]:
            for j in range(n):
                k = t0 + (t1 - t0) * j / max(1, n - (0 if a.get("loop") else 1))
                if upper:
                    set_pose(arm, acts[body], _span(acts[body], 0.5), acts[upper], _span(acts[upper], k))
                else:
                    set_pose(arm, acts[body], _span(acts[body], k))
                if a.get("tweak"):
                    a["tweak"](i, total, arm)
                    bpy.context.view_layer.update()
                m = bone_world(arm, "handslot.r")
                if a.get("rod") == "park":
                    g, t = park
                else:
                    g = m.to_translation()
                    t = g + (m.to_3x3() @ rod_local).normalized() * ROD_L
                grips.append(pt(g))
                tips.append(pt(t))
                heads.append(pt(bone_world(arm, "head").to_translation() + Vector((0.05, 0, 0.62))))
                if not only or name in only.split(","):
                    p = os.path.join(tmp, "f%02d.png" % i)
                    K.render(p)
                    paths.append(p)
                i += 1
        if paths:
            V._stitch(paths, os.path.join(out_dir, name + ".png"), CELL)
        e = {"frames": total, "fps": a["fps"], "rod_grip": grips, "rod_tip": tips, "head": heads}
        if a.get("loop"):
            e["loop"] = True
        if "loop_range" in a:
            e["loop_range"] = a["loop_range"]
            e["hold"] = a["hold"]
        if name == "cast":                # when the bobber lets go: the tip's fastest swing forward
            jumps = [tips[q + 1][0] - tips[q][0] for q in range(total - 1)]
            e["release"] = round(jumps.index(max(jumps)) / float(a["fps"]), 3)
        info[name] = e
    info["feet"] = pt((0, 0, 0))          # the anchor: where he sits (goes on the boat's seat)
    info["unit_px"] = round(CELL / SCALE, 3)
    info["cell"] = CELL
    info["standing"] = ["cast", "reel", "happy", "dance", "sad", "shrug"]    # (reactions wait for these to end)
    info["up"] = [n for n, a in ANIMS.items() if a.get("up")]                # after these he sits back down
    info["idles"] = IDLES
    return info

"""A boat from every side: the stage swaps these while the boat swings round, so it really turns (it used to be one
picture mirrored, which looked like a sheet of paper). Half a circle, bow toward the camera .. stern toward it; the stage
mirrors the other half. The plain side view stays boats_top/<slug>.png, with the captain as a live sprite.
    boats_turn/<slug>.png          the boat, with the captain sitting on it
    boats_turn/<slug>_foam.png     its footprint, blurred, for vf_foam.gdshader
    boats_turn/<slug>_reflect.png  upside down below the water, for vf_reflect.gdshader
"""
import math
import os
import tempfile

import bpy
import numpy as np
from mathutils import Matrix, Vector

import vf_boats as B
import vf_captain as C
import vf_kit as K
import vf_life as L
import vf_topdown as TD
import vf_vendor as V
from vf_kit import toon

STEP = 15
ANGLES = [a for a in range(-90, 91, STEP) if a != 0]     # + = the bow turned away from the camera
COLS = 4
PX_PER_UNIT = 64.0      # (the stage shows about 56 px per unit at 1080p)
FOAM_CELL = 128
REFLECT_CELL = 176
_acts = {}


def _rows(paths):
    return [paths[i:i + COLS] for i in range(0, len(paths), COLS)]


def _size(n):
    sc = bpy.context.scene
    sc.render.resolution_x = sc.render.resolution_y = n


def _foam_sheet(cam, pivot, foot, span, path):
    """every angle's footprint, blurred like TD.render_foam's: 1 under the hull, about 0.5 at its edge, 0 a little way out"""
    foot.data.materials.append(toon("#ffffff", flat_glow=True))
    cam.data.ortho_scale = span * TD.FOAM_PAD
    n = FOAM_CELL * 2
    _size(n)
    rows = len(_rows(ANGLES))
    px = np.ones((FOAM_CELL * rows, FOAM_CELL * COLS, 4), dtype=np.float32)
    blur = max(1, int(round(0.32 * FOAM_CELL / (span * TD.FOAM_PAD))))
    tmp = os.path.join(tempfile.mkdtemp(), "foot.png")
    for i, ang in enumerate(ANGLES):
        pivot.rotation_euler = (0, 0, math.radians(ang))
        K.render(tmp)
        im = bpy.data.images.load(tmp)
        a = np.array(im.pixels[:], dtype=np.float32).reshape(n, n, 4)[..., 3]
        bpy.data.images.remove(im)
        a = (a[0::2, 0::2] + a[1::2, 0::2] + a[0::2, 1::2] + a[1::2, 1::2]) / 4.0
        a = np.clip(TD._soft(a, blur), 0.0, 1.0)
        y0 = (rows - 1 - i // COLS) * FOAM_CELL           # (image rows run bottom-up)
        x0 = (i % COLS) * FOAM_CELL
        px[y0:y0 + FOAM_CELL, x0:x0 + FOAM_CELL, :3] = a[..., None]
    out = bpy.data.images.new("foam", FOAM_CELL * COLS, FOAM_CELL * rows, alpha=False)
    out.pixels = px.ravel().tolist()
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


def _reflect_sheet(cam, hull, span, path):
    """the hull upside down below the water, with the sun mirrored too (like TD.render_boat_reflection)"""
    mirror = bpy.data.objects.new("mirror", None)
    bpy.context.collection.objects.link(mirror)
    for o in hull:
        me = o.data.copy()
        me.transform(o.matrix_world)
        me.transform(Matrix.Diagonal((1.0, 1.0, -1.0, 1.0)))
        me.flip_normals()
        r = bpy.data.objects.new(o.name + "_mirror", me)
        bpy.context.collection.objects.link(r)
        r.parent = mirror
    for o in bpy.data.objects:
        if o.type == "LIGHT":
            d = o.rotation_euler.to_matrix() @ Vector((0, 0, -1))
            o.rotation_euler = Vector((d.x, d.y, -d.z)).to_track_quat("-Z", "Y").to_euler()
    cam.data.ortho_scale = span * TD.REFLECT_PAD
    _size(REFLECT_CELL)
    tmp = tempfile.mkdtemp()
    paths = []
    for i, ang in enumerate(ANGLES):
        mirror.rotation_euler = (0, 0, math.radians(ang))
        p = os.path.join(tmp, "r%02d.png" % i)
        K.render(p)
        paths.append(p)
    L._sheet(_rows(paths), path, REFLECT_CELL)


def render(name, out_dir, slug):
    """-> the boat's manifest "turn" entry; the stage's numbers are 0..1 of a cell"""
    K.clear_scene()
    V.clear_library()
    K.SOFT[0] = True
    K.setup_render(256, 256, samples=16)
    K.setup_world("#9aa6b0", 1.0)
    s = K.sun((42, 0, 28), 1.0)
    s.data.angle = math.radians(7)
    cam = K.make_camera(TD.CAM_ROT, ortho=True)
    if not _acts:
        _acts.update(C.load_actions())
    parts, deck = B.build_boat(name)
    seat = B.find_seat(parts, deck)
    foot, floats = TD.footprint(parts)
    foot.hide_render = True
    hull = TD.clip_below(parts)
    K.outline_all(hull, 0.035)
    # the captain sits where the stage puts his sprite in the side view
    arm, meshes, root = C.build()
    C.hat(arm, next(m for m in meshes if "Head" in m.name))
    sit = _acts[C.SEAT]
    C.set_pose(arm, sit, C._span(sit, 0.5))
    root.location = seat
    bpy.context.view_layer.update()
    pivot = bpy.data.objects.new("turn", None)
    bpy.context.collection.objects.link(pivot)
    for o in hull + [foot, root]:
        w = o.matrix_world.copy()
        o.parent = pivot
        o.matrix_world = w
    bpy.context.view_layer.update()
    # one frame for every angle: the pivot stays at the same pixel, so the boat turns on the spot
    pts = np.array([tuple(p) for p in K._mesh_points(hull + meshes)], dtype=np.float64)
    Rc = cam.rotation_euler.to_matrix()
    right, up, fwd = Rc @ Vector((1, 0, 0)), Rc @ Vector((0, 1, 0)), Rc @ Vector((0, 0, -1))
    views = []
    for ang in ANGLES:
        c, n = math.cos(math.radians(ang)), math.sin(math.radians(ang))
        x, y, z = pts[:, 0] * c - pts[:, 1] * n, pts[:, 0] * n + pts[:, 1] * c, pts[:, 2]
        views.append((x * right.x + y * right.y + z * right.z, x * up.x + y * up.y + z * up.z))
    x0, x1 = min(v[0].min() for v in views), max(v[0].max() for v in views)
    y0, y1 = min(v[1].min() for v in views), max(v[1].max() for v in views)
    span = max(x1 - x0, y1 - y0) * 1.04
    cx, cy = (x0 + x1) * 0.5, (y0 + y1) * 0.5
    cam.location = right * cx + up * cy - fwd * 60.0
    cam.data.ortho_scale = span
    cam["frame"] = (cx, cy, span, 1.0)
    cell = int(min(512.0, max(240.0, span * PX_PER_UNIT)) / 8.0) * 8
    _size(cell)
    # the boat
    tmp = tempfile.mkdtemp()
    paths = []
    for i, ang in enumerate(ANGLES):
        pivot.rotation_euler = (0, 0, math.radians(ang))
        p = os.path.join(tmp, "h%02d.png" % i)
        K.render(p)
        paths.append(p)
    L._sheet(_rows(paths), os.path.join(out_dir, slug + ".png"), cell)
    # foam and reflection: only their own meshes show
    for o in bpy.data.objects:
        if o.type == "MESH" and o is not foot:
            o.hide_render = True
    foot.hide_render = False
    _foam_sheet(cam, pivot, foot, span, os.path.join(out_dir, slug + "_foam.png"))
    foot.hide_render = True
    pivot.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    _reflect_sheet(cam, hull, span, os.path.join(out_dir, slug + "_reflect.png"))
    K.SOFT[0] = False
    rects = []
    for sx, sy in views:
        rects.append([round((sx.min() - cx) / span + 0.5, 4), round(0.5 - (sy.max() - cy) / span, 4),
                      round((sx.max() - cx) / span + 0.5, 4), round(0.5 - (sy.min() - cy) / span, 4)])
    return {"step": STEP, "cols": COLS, "cell": cell, "unit_px": round(cell / span, 3), "origin": [round(-cx / span + 0.5, 4), round(0.5 + cy / span, 4)],
            "rects": rects, "foam_cell": FOAM_CELL, "reflect_cell": REFLECT_CELL, "foam_pad": TD.FOAM_PAD, "reflect_pad": TD.REFLECT_PAD}

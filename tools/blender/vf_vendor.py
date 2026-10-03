"""Third-party CC0 / CC-BY models (Quaternius, Kenney, Poly by Google),
converted to the project's soft cel shading and rendered as sprite sheets.

Raw downloads live in scratch/downloads (git-ignored); see CREDITS.md.
"""
import math
import os

import bpy
from mathutils import Euler, Matrix, Vector

import vf_kit as K

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DL = os.path.join(ROOT, "scratch", "downloads")
GLB = os.path.join(DL, "glb")
NATURE = os.path.join(DL, "x_kenney_nature", "Models", "GLTF format")
WATERCRAFT = os.path.join(DL, "x_kenney_watercraft", "Models", "GLB format")


def _ramp(nt, soft=True):
    g = lambda v: "#%02x%02x%02x" % ((int(v * 255),) * 3)
    dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    nt.links.new(dif.outputs[0], s2r.inputs[0])
    bw = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(s2r.outputs[0], bw.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    if soft:
        ramp.color_ramp.interpolation = "EASE"
        K._ramp_stops(ramp.color_ramp, [(0.15, g(0.6)), (0.45, g(0.87)), (0.8, g(1.0))])
    else:
        ramp.color_ramp.interpolation = "CONSTANT"
        K._ramp_stops(ramp.color_ramp, [(0.0, g(0.7)), (0.33, g(0.87)), (0.62, g(1.0))])
    nt.links.new(bw.outputs[0], ramp.inputs[0])
    return ramp.outputs[0]


def toonify(mat, tint=None, soft=True, emit=0.0):
    """Rewire a glTF Principled material into the project's cel shading,
    keeping its base colour or texture (or replacing it with `tint`)."""
    if mat is None or not mat.use_nodes:
        return mat
    nt = mat.node_tree
    pr = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
    if out is None:
        return mat
    base_sock = None
    col = (0.8, 0.8, 0.8, 1.0)
    if pr is not None:
        bc = pr.inputs["Base Color"]
        if bc.is_linked:
            base_sock = bc.links[0].from_socket
        col = tuple(bc.default_value)
    if tint is not None:
        base_sock = None
        col = K.hexc(tint) if isinstance(tint, str) else tint
    if base_sock is None:
        rgb = nt.nodes.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = col
        base_sock = rgb.outputs[0]
    shade = _ramp(nt, soft)
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    nt.links.new(base_sock, mul.inputs[6])
    nt.links.new(shade, mul.inputs[7])
    c = mul.outputs[2]
    if emit > 0:
        em2 = nt.nodes.new("ShaderNodeMix")
        em2.data_type = "RGBA"
        em2.inputs[0].default_value = emit
        nt.links.new(c, em2.inputs[6])
        nt.links.new(base_sock, em2.inputs[7])
        c = em2.outputs[2]
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(c, em.inputs[0])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return mat


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next((o for o in new if o.type == "ARMATURE"), None)
    meshes = [o for o in new if o.type == "MESH"]
    # Quaternius rigs ship a bone-widget icosphere; keep only skinned/visible meshes
    roots = [o for o in new if o.parent is None]
    for m in [m for m in meshes if len(m.data.materials) == 0]:
        if m in roots: roots.remove(m)
        meshes.remove(m)
        bpy.data.objects.remove(m)
    if arm:
        skinned = [m for m in meshes if any(md.type == "ARMATURE" for md in m.modifiers) or m.parent == arm and m.vertex_groups]
        drop = [m for m in meshes if m not in skinned]
        roots = [r for r in roots if r not in drop]
        for m in drop:
            bpy.data.objects.remove(m)
        meshes = skinned
    return meshes, arm, roots


def group_root(roots, name="vendor"):
    g = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(g)
    for r in roots:
        r.parent = g
    return g


def world_bbox(objs):
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in objs:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            p = ev.matrix_world @ v.co
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
        ev.to_mesh_clear()
    return lo, hi


def normalize(objs, root, length=None, height=None, center=True):
    """Scale `root` so the evaluated meshes have the given length (X) or
    height (Z), and move them to sit on/around the origin."""
    lo, hi = world_bbox(objs)
    size = hi - lo
    s = 1.0
    if length:
        s = length / max(size.x, 1e-6)
    elif height:
        s = height / max(size.z, 1e-6)
    root.scale = root.scale * s
    bpy.context.view_layer.update()
    lo, hi = world_bbox(objs)
    off = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z if not center else (lo.z + hi.z) / 2))
    root.location -= off
    bpy.context.view_layer.update()


def set_action(arm, contains):
    act = next((a for a in bpy.data.actions if contains.lower() in a.name.lower()), None)
    if arm and act:
        arm.animation_data_create()
        arm.animation_data.action = act
    return act


def outline_skinned(meshes, t):
    # solidify must run after the armature deform
    for m in meshes:
        K.add_outline(m, t / max(m.matrix_world.to_scale()))


# ----------------------------------------------------------- sprite sheets
def render_sheet(out_path, frames_fn, n, size, cam, objs, margin=1.1):
    """Render n frames (calling frames_fn(i) before each) into one
    horizontal strip PNG. Framing is fixed from the union of all frames."""
    import tempfile
    sc = bpy.context.scene
    tmp = tempfile.mkdtemp()
    # union framing
    los, his = [], []
    for i in range(n):
        frames_fn(i)
        lo, hi = world_bbox(objs)
        los.append(lo)
        his.append(hi)
    proxy_lo = Vector(map(min, *los)) if n > 1 else los[0]
    proxy_hi = Vector(map(max, *his)) if n > 1 else his[0]
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    box = bpy.context.active_object
    box.location = (proxy_lo + proxy_hi) / 2
    box.scale = proxy_hi - proxy_lo
    bpy.context.view_layer.update()
    K.frame_ortho(cam, [box], margin)
    bpy.data.objects.remove(box)
    paths = []
    for i in range(n):
        frames_fn(i)
        p = os.path.join(tmp, "f%02d.png" % i)
        K.render(p)
        paths.append(p)
    _stitch(paths, out_path, size)
    return cam


def _stitch(paths, out_path, size):
    imgs = [bpy.data.images.load(p) for p in paths]
    n = len(imgs)
    sheet = bpy.data.images.new("sheet", width=size * n, height=size, alpha=True)
    px = [0.0] * (size * n * size * 4)
    for k, im in enumerate(imgs):
        src = list(im.pixels)
        for y in range(size):
            row = y * size * 4
            dst = (y * size * n + k * size) * 4
            px[dst:dst + size * 4] = src[row:row + size * 4]
    sheet.pixels = px
    sheet.filepath_raw = out_path
    sheet.file_format = "PNG"
    sheet.save()
    for im in imgs:
        bpy.data.images.remove(im)
    bpy.data.images.remove(sheet)


# ---------------------------------------------------------- prop library
_lib = {}
# Kenney Nature Kit palette -> project palette (by material name)
MAT_TINTS = {"leafsGreen": "#5fae4f", "leafsDark": "#3f8a4a", "leafsFall": "#d98a3a", "grass": "#7cc06a",
             "woodBark": "#8a5a3a", "woodBarkDark": "#6b4430", "wood": "#b07a4a", "dirt": "#9a7450",
             "stone": "#a3a8ad", "stoneDark": "#7a8088", "mushroomRed": "#e0533e", "mushroomTan": "#e8d2a8"}


def prop(name, folder=NATURE, tint=None):
    """Return a fresh linked copy of a Kenney model (one joined mesh with
    cel-shaded materials). The first call imports and caches it."""
    key = (folder, name, tint)
    if key not in _lib or _lib[key].name not in bpy.data.objects:
        meshes, arm, roots = import_glb(os.path.join(folder, name + ".glb"))
        bpy.context.view_layer.update()
        for m in meshes:
            mw = m.matrix_world.copy()
            m.parent = None
            m.matrix_world = mw
        bpy.ops.object.select_all(action="DESELECT")
        for m in meshes:
            m.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        if len(meshes) > 1:
            bpy.ops.object.join()
        src = bpy.context.active_object
        for r in roots:
            try:
                if r != src and r.type == "EMPTY":
                    bpy.data.objects.remove(r)
            except ReferenceError:
                pass
        src.matrix_world = Matrix.Identity(4)
        for mt in src.data.materials:
            toonify(mt, tint=tint or MAT_TINTS.get(mt.name.split(".")[0]))
        src.hide_render = True
        src.hide_set(True)
        _lib[key] = src
    c = _lib[key].copy()
    c["outline_even"] = False
    c["outline_k"] = 0.6
    c.hide_render = False
    bpy.context.collection.objects.link(c)
    c.hide_set(False)
    return c


def place(name, loc, scale=1.0, rot_z=None, folder=NATURE, tint=None, rnd=None):
    o = prop(name, folder, tint)
    o.location = loc
    o.scale = (scale, scale, scale)
    o.rotation_euler = (0, 0, rot_z if rot_z is not None else (rnd.uniform(0, math.tau) if rnd else 0.0))
    return o


def clear_library():
    _lib.clear()

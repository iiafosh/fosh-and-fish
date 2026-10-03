"""Shared Blender helpers for the Virtual Fisher art pipeline.

Everything is procedural: primitives -> bmesh shaping -> cel-shaded
emission materials with an inverted-hull outline. Rendered with Eevee
using the Standard view transform so palette colours land exactly.
"""
import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

OUTLINE = (0.07, 0.06, 0.10)
FOG = {"color": None, "start": 30.0, "end": 140.0, "amount": 0.0}


# ----------------------------------------------------------------- colours
def hexc(h, a=1.0):
    h = h.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    # sRGB -> linear so the Standard view transform shows the hex as written
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin(r), lin(g), lin(b), a)


def mix(c1, c2, t):
    return tuple(c1[i] * (1 - t) + c2[i] * t for i in range(4))


# ------------------------------------------------------------------- scene
def clear_scene():
    _mat_cache.clear()
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for item in list(coll):
            if item.users == 0:
                coll.remove(item)


def setup_render(w, h, samples=16, transparent=True):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.eevee.taa_render_samples = samples
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = transparent
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    sc.render.image_settings.compression = 90
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.render.filter_size = 1.2


def setup_world(ambient="#5a5a66", strength=1.0, sky=None, stars=0.0):
    """Ambient light for shading; optional camera-only sky gradient.

    sky: list of (pos, hex) stops from horizon (0) to zenith (1).
    """
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    amb = nt.nodes.new("ShaderNodeBackground")
    amb.inputs[0].default_value = hexc(ambient)
    amb.inputs[1].default_value = strength
    if not sky:
        nt.links.new(amb.outputs[0], out.inputs[0])
        return
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -0.02
    mr.inputs["From Max"].default_value = 0.55
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    _ramp_stops(ramp.color_ramp, sky)
    ramp.color_ramp.interpolation = "EASE"
    nt.links.new(mr.outputs[0], ramp.inputs[0])
    col_out = ramp.outputs[0]
    if stars > 0:
        noise = nt.nodes.new("ShaderNodeTexVoronoi")
        noise.inputs["Scale"].default_value = 260.0
        nt.links.new(tc.outputs["Generated"], noise.inputs["Vector"])
        sr = nt.nodes.new("ShaderNodeMapRange")
        sr.inputs["From Min"].default_value = 0.0
        sr.inputs["From Max"].default_value = 0.035
        sr.inputs["To Min"].default_value = stars
        sr.inputs["To Max"].default_value = 0.0
        nt.links.new(noise.outputs["Distance"], sr.inputs["Value"])
        add = nt.nodes.new("ShaderNodeMix")
        add.data_type = "RGBA"
        add.blend_type = "ADD"
        add.inputs[0].default_value = 1.0
        nt.links.new(col_out, add.inputs[6])
        nt.links.new(sr.outputs[0], add.inputs[7])
        col_out = add.outputs[2]
    bg = nt.nodes.new("ShaderNodeBackground")
    nt.links.new(col_out, bg.inputs[0])
    lp = nt.nodes.new("ShaderNodeLightPath")
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0])
    nt.links.new(amb.outputs[0], mx.inputs[1])
    nt.links.new(bg.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs[0])


def _ramp_stops(cr, stops):
    els = cr.elements
    while len(els) > 1:
        els.remove(els[-1])
    els[0].position = stops[0][0]
    els[0].color = hexc(stops[0][1])
    for pos, col in stops[1:]:
        e = els.new(pos)
        e.color = hexc(col)


def sun(rot=(50, 0, 35), strength=1.0, color="#ffffff"):
    ld = bpy.data.lights.new("Sun", "SUN")
    ld.energy = strength
    ld.color = hexc(color)[:3]
    ld.angle = math.radians(2)
    ob = bpy.data.objects.new("Sun", ld)
    bpy.context.collection.objects.link(ob)
    ob.rotation_euler = Euler([math.radians(a) for a in rot])
    return ob


# ---------------------------------------------------------------- materials
_mat_cache = {}


def toon(color, shade=0.62, spec=0.0, emit=0.0, rim=0.10, vcol=None, flat_glow=False, alpha=1.0, key=None):
    """Cel material: (diffuse -> 3-step ramp) * colour, emitted.

    color: hex or linear tuple. vcol: name of a colour attribute to use
    instead of `color`. spec: strength of a hard white highlight.
    emit: extra self-illumination (0 = lit only, 1 = fully glowing).
    """
    c = hexc(color) if isinstance(color, str) else color
    k = key or (c, shade, spec, emit, rim, vcol, flat_glow, alpha, FOG["color"], FOG["amount"])
    if k in _mat_cache:
        return _mat_cache[k]
    m = bpy.data.materials.new("toon")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    if vcol:
        base = nt.nodes.new("ShaderNodeVertexColor")
        base.layer_name = vcol
        base_out = base.outputs["Color"]
    else:
        base = nt.nodes.new("ShaderNodeRGB")
        base.outputs[0].default_value = c
        base_out = base.outputs[0]

    if flat_glow:
        col_out = base_out
    else:
        dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
        s2r = nt.nodes.new("ShaderNodeShaderToRGB")
        nt.links.new(dif.outputs[0], s2r.inputs[0])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        g = lambda v: "#%02x%02x%02x" % ((int(v * 255),) * 3)
        _ramp_stops(ramp.color_ramp, [(0.0, g(shade ** 0.45 * 0.92)), (0.33, g(0.87)), (0.62, g(1.0))])
        bw = nt.nodes.new("ShaderNodeRGBToBW")
        nt.links.new(s2r.outputs[0], bw.inputs[0])
        nt.links.new(bw.outputs[0], ramp.inputs[0])
        mul = nt.nodes.new("ShaderNodeMix")
        mul.data_type = "RGBA"
        mul.blend_type = "MULTIPLY"
        mul.inputs[0].default_value = 1.0
        nt.links.new(base_out, mul.inputs[6])
        nt.links.new(ramp.outputs[0], mul.inputs[7])
        col_out = mul.outputs[2]
        if emit > 0:
            em = nt.nodes.new("ShaderNodeMix")
            em.data_type = "RGBA"
            em.inputs[0].default_value = emit
            nt.links.new(col_out, em.inputs[6])
            nt.links.new(base_out, em.inputs[7])
            col_out = em.outputs[2]
        if spec > 0:
            gl = nt.nodes.new("ShaderNodeBsdfAnisotropic") if False else nt.nodes.new("ShaderNodeBsdfGlossy")
            gl.inputs["Roughness"].default_value = 0.25
            s2 = nt.nodes.new("ShaderNodeShaderToRGB")
            nt.links.new(gl.outputs[0], s2.inputs[0])
            bw2 = nt.nodes.new("ShaderNodeRGBToBW")
            nt.links.new(s2.outputs[0], bw2.inputs[0])
            r2 = nt.nodes.new("ShaderNodeMapRange")
            r2.interpolation_type = "STEPPED"
            r2.inputs["From Min"].default_value = 0.0
            r2.inputs["From Max"].default_value = 1.0
            r2.inputs["Steps"].default_value = 2.0
            nt.links.new(bw2.outputs[0], r2.inputs["Value"])
            sm = nt.nodes.new("ShaderNodeMix")
            sm.data_type = "RGBA"
            sm.blend_type = "ADD"
            nt.links.new(r2.outputs[0], sm.inputs[0])
            sm.inputs[7].default_value = (spec, spec, spec, 1)
            nt.links.new(col_out, sm.inputs[6])
            col_out = sm.outputs[2]
        if rim > 0:
            lw = nt.nodes.new("ShaderNodeLayerWeight")
            lw.inputs[0].default_value = 0.2
            rr = nt.nodes.new("ShaderNodeMapRange")
            rr.interpolation_type = "STEPPED"
            rr.inputs["Steps"].default_value = 1.0
            rr.inputs["From Min"].default_value = 0.35
            rr.inputs["From Max"].default_value = 1.0
            rr.inputs["To Max"].default_value = rim
            nt.links.new(lw.outputs["Facing"], rr.inputs["Value"])
            ra = nt.nodes.new("ShaderNodeMix")
            ra.data_type = "RGBA"
            ra.blend_type = "SCREEN"
            nt.links.new(rr.outputs[0], ra.inputs[0])
            ra.inputs[7].default_value = (1, 1, 1, 1)
            nt.links.new(col_out, ra.inputs[6])
            col_out = ra.outputs[2]

    if FOG["color"] is not None and FOG["amount"] > 0:
        cd = nt.nodes.new("ShaderNodeCameraData")
        fr = nt.nodes.new("ShaderNodeMapRange")
        fr.inputs["From Min"].default_value = FOG["start"]
        fr.inputs["From Max"].default_value = FOG["end"]
        fr.inputs["To Max"].default_value = FOG["amount"]
        nt.links.new(cd.outputs["View Z Depth"], fr.inputs["Value"])
        fm = nt.nodes.new("ShaderNodeMix")
        fm.data_type = "RGBA"
        nt.links.new(fr.outputs[0], fm.inputs[0])
        nt.links.new(col_out, fm.inputs[6])
        fm.inputs[7].default_value = hexc(FOG["color"])
        col_out = fm.outputs[2]

    emn = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(col_out, emn.inputs[0])
    shader_out = emn.outputs[0]
    if alpha < 1.0:
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mx = nt.nodes.new("ShaderNodeMixShader")
        mx.inputs[0].default_value = alpha
        nt.links.new(tr.outputs[0], mx.inputs[1])
        nt.links.new(shader_out, mx.inputs[2])
        shader_out = mx.outputs[0]
        m.surface_render_method = "BLENDED"
    nt.links.new(shader_out, out.inputs[0])
    _mat_cache[k] = m
    return m


def outline_mat(color=OUTLINE):
    k = ("outline", color, FOG["color"], FOG["amount"])
    if k in _mat_cache:
        return _mat_cache[k]
    c = hexc(color) if isinstance(color, str) else (*color, 1.0)
    m = toon(c, flat_glow=True, key=("ol-inner",) + k)
    m = m.copy()
    m.use_backface_culling = True
    _mat_cache[k] = m
    return m


def add_outline(ob, thickness=0.03, color=OUTLINE):
    if ob.type != "MESH":
        return
    mats = ob.data.materials
    mats.append(outline_mat(color))
    mod = ob.modifiers.new("outline", "SOLIDIFY")
    mod.thickness = -thickness
    mod.offset = -1.0
    mod.use_flip_normals = True
    mod.use_even_offset = True
    mod.material_offset = len(mats) - 1
    mod.use_rim = False


# --------------------------------------------------------------- primitives
def _finish(ob, mat, smooth, name):
    if name:
        ob.name = name
    if mat is not None:
        ob.data.materials.clear()
        ob.data.materials.append(mat)
    if smooth:
        for p in ob.data.polygons:
            p.use_smooth = True
    return ob


def _place(ob, loc, rot, scale):
    ob.location = loc
    ob.rotation_euler = Euler([math.radians(a) for a in rot])
    ob.scale = scale if hasattr(scale, "__len__") else (scale, scale, scale)
    return ob


def cube(loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), mat=None, bevel=0.0, smooth=False, name=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    ob = bpy.context.active_object
    _place(ob, loc, rot, scale)
    if bevel > 0:
        apply_scale(ob)
        mod = ob.modifiers.new("bev", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return _finish(ob, mat, smooth, name)


def sphere(loc=(0, 0, 0), scale=1.0, rot=(0, 0, 0), mat=None, seg=24, rings=12, smooth=True, name=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1.0)
    ob = bpy.context.active_object
    _place(ob, loc, rot, scale)
    return _finish(ob, mat, smooth, name)


def ico(loc=(0, 0, 0), scale=1.0, rot=(0, 0, 0), mat=None, sub=1, smooth=False, name=None):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=1.0)
    ob = bpy.context.active_object
    _place(ob, loc, rot, scale)
    return _finish(ob, mat, smooth, name)


def cyl(loc=(0, 0, 0), r=1.0, depth=1.0, rot=(0, 0, 0), mat=None, verts=24, scale=None, smooth=True, name=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth)
    ob = bpy.context.active_object
    _place(ob, loc, rot, scale or (1, 1, 1))
    ob = _finish(ob, mat, smooth, name)
    if smooth:
        _flat_caps(ob)
    return ob


def cone(loc=(0, 0, 0), r1=1.0, r2=0.0, depth=1.0, rot=(0, 0, 0), mat=None, verts=24, scale=None, smooth=True, name=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth)
    ob = bpy.context.active_object
    _place(ob, loc, rot, scale or (1, 1, 1))
    ob = _finish(ob, mat, smooth, name)
    if smooth:
        _flat_caps(ob)
    return ob


def torus(loc=(0, 0, 0), R=1.0, r=0.25, rot=(0, 0, 0), mat=None, scale=None, seg=32, mseg=12, name=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=mseg)
    ob = bpy.context.active_object
    _place(ob, loc, rot, scale or (1, 1, 1))
    return _finish(ob, mat, True, name)


def _flat_caps(ob):
    for p in ob.data.polygons:
        if abs(p.normal.z) > 0.99:
            p.use_smooth = False


def extrude_poly(points, depth, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, scale=1.0, bevel=0.0, name=None):
    """Extrude a 2D outline (XY) along Z, centred on Z=0."""
    me = bpy.data.meshes.new("poly")
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, -depth / 2)) for x, y in points]
    face = bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=[face])
    if face.normal.z > 0:
        face.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    top = [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=top, vec=(0, 0, depth))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name or "poly", me)
    bpy.context.collection.objects.link(ob)
    _place(ob, loc, rot, scale)
    if bevel > 0:
        mod = ob.modifiers.new("bev", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    return _finish(ob, mat, False, None)


def tube(points, radius=0.05, mat=None, taper=None, res=8, name=None):
    """Bezier tube through points -> mesh. taper: (start_scale, end_scale)."""
    cu = bpy.data.curves.new("tube", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 3
    cu.resolution_u = res
    cu.use_fill_caps = True
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for i, p in enumerate(points):
        bp = sp.bezier_points[i]
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
        if taper:
            t = i / max(1, len(points) - 1)
            bp.radius = taper[0] * (1 - t) + taper[1] * t
    ob = bpy.data.objects.new(name or "tube", cu)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.active_object
    return _finish(ob, mat, True, None)


def apply_scale(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


def join(objs, name="model"):
    objs = [o for o in objs if o is not None and o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        if o.modifiers:
            bpy.context.view_layer.objects.active = o
            for m in list(o.modifiers):
                bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    return ob


def parent_all(objs, name="group"):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    for o in objs:
        if o is not None:
            o.parent = root
    return root


def vcolor(ob, fn, name="col", per_face=False):
    """Paint a colour attribute: fn(local_co, normal) -> linear rgba.

    per_face=True samples each face centre for crisp colour bands.
    """
    me = ob.data
    if per_face:
        attr = me.color_attributes.get(name) or me.color_attributes.new(name, "FLOAT_COLOR", "CORNER")
        for poly in me.polygons:
            c = fn(poly.center, poly.normal)
            for li in poly.loop_indices:
                attr.data[li].color = c
        return name
    attr = me.color_attributes.get(name) or me.color_attributes.new(name, "FLOAT_COLOR", "POINT")
    for i, v in enumerate(me.vertices):
        attr.data[i].color = fn(v.co, v.normal)
    return name


def deform(ob, fn):
    """fn(Vector) -> Vector applied to every vertex (object space)."""
    for v in ob.data.vertices:
        v.co = fn(v.co.copy())
    ob.data.update()


def outline_all(objs, thickness, color=OUTLINE):
    for o in objs:
        if o is not None and o.type == "MESH" and not o.get("no_outline"):
            add_outline(o, thickness * o.get("outline_k", 1.0), color)


# ------------------------------------------------------------------ camera
def make_camera(rot=(62, 0, 38), ortho=True, lens=50.0):
    cd = bpy.data.cameras.new("Cam")
    cd.type = "ORTHO" if ortho else "PERSP"
    cd.lens = lens
    cd.clip_end = 2000.0
    ob = bpy.data.objects.new("Cam", cd)
    bpy.context.collection.objects.link(ob)
    ob.rotation_euler = Euler([math.radians(a) for a in rot])
    bpy.context.scene.camera = ob
    return ob


def _mesh_points(objs):
    dg = bpy.context.evaluated_depsgraph_get()
    pts = []
    for o in objs:
        if o.type != "MESH":
            continue
        ev = o.evaluated_get(dg)
        mw = ev.matrix_world
        for c in ev.bound_box:
            pts.append(mw @ Vector(c))
    return pts


def frame_ortho(cam, objs, margin=1.12, shift=(0.0, 0.0)):
    bpy.context.view_layer.update()
    sc = bpy.context.scene
    aspect = sc.render.resolution_x / sc.render.resolution_y
    R = cam.rotation_euler.to_matrix()
    right, up, fwd = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0)), R @ Vector((0, 0, -1))
    pts = _mesh_points(objs)
    xs = [p.dot(right) for p in pts]
    ys = [p.dot(up) for p in pts]
    zs = [p.dot(fwd) for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    scale = max(w, h * aspect) * margin
    cx -= shift[0] * scale
    cy -= shift[1] * scale / aspect
    cam.location = right * cx + up * cy + fwd * (min(zs) - 50.0)
    cam.data.ortho_scale = scale
    cam["frame"] = (cx, cy, scale, aspect)
    return cam


def project(cam, p):
    """World point -> pixel (x, y) for an ortho camera framed by frame_ortho."""
    sc = bpy.context.scene
    W, H = sc.render.resolution_x, sc.render.resolution_y
    cx, cy, scale, aspect = cam["frame"]
    R = cam.rotation_euler.to_matrix()
    right, up = R @ Vector((1, 0, 0)), R @ Vector((0, 1, 0))
    p = Vector(p)
    x = (p.dot(right) - cx) / scale * W + W / 2
    y = H / 2 - (p.dot(up) - cy) / (scale / aspect) * H
    return round(x, 1), round(y, 1)


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def seed(s):
    random.seed(s)

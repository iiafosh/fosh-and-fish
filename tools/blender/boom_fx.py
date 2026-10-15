"""Effects for the fosh&fish KABOOM video (tools/blender/boom_video.py): cartoon splashes and
explosions, comic words, the 3D logo, sunbursts, gameplay screens, leaping fish and keyframe
helpers. Everything is keyframed from seeded maths (no simulations), cel-shaded with the art
pipeline's vf_kit materials and inverted-hull outlines, so every render is the same.
"""
import math
import os
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

import vf_kit as K
import vf_models as M
from vf_kit import hexc, toon

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WORK = os.path.join(ROOT, "build", "boom")
FONT_LOGO = os.path.join(WORK, "Fredoka-Logo.ttf")      # static instances of the variable font (boom_prep.py)
FONT_BOLD = os.path.join(WORK, "Fredoka-Bold.ttf")
FPS = 30.0
G = 30.0                                                  # cartoon gravity, units / s^2
UP = Vector((0, 0, 1))

WATER_LINE = "#2f86b5"                                    # outline of splashes
FIRE = ["#fffdf0", "#fff27a", "#ffd23f", "#ff9a1f", "#f2552c", "#b33a2e", "#5a4448", "#3e3440"]
SMOKE = ["#7a6a70", "#5a4c54", "#463c46"]


# ------------------------------------------------------------------ easing
def clamp01(t):
    return 0.0 if t < 0 else 1.0 if t > 1 else t


def ease_out(t, p=3):
    return 1 - (1 - clamp01(t)) ** p


def ease_in(t, p=3):
    return clamp01(t) ** p


def smooth(t):
    t = clamp01(t)
    return t * t * (3 - 2 * t)


def back_out(t, s=2.2):
    t = clamp01(t) - 1
    return t * t * ((s + 1) * t + s) + 1


def lerp(a, b, t):
    return a + (b - a) * t


def vlerp(a, b, t):
    return Vector(a).lerp(Vector(b), t)


# --------------------------------------------------------------- keyframes
def kf(ob, f, loc=None, rot=None, scale=None, color=None, quat=None):
    if loc is not None:
        ob.location = loc
        ob.keyframe_insert("location", frame=f)
    if rot is not None:
        ob.rotation_euler = rot
        ob.keyframe_insert("rotation_euler", frame=f)
    if quat is not None:
        ob.rotation_mode = "QUATERNION"
        ob.rotation_quaternion = quat
        ob.keyframe_insert("rotation_quaternion", frame=f)
    if scale is not None:
        ob.scale = (scale, scale, scale) if isinstance(scale, (int, float)) else scale
        ob.keyframe_insert("scale", frame=f)
    if color is not None:
        ob.color = color
        ob.keyframe_insert("color", frame=f)


def visible(ob, f_on, f_off=None):
    """render-visible from f_on until f_off (exclusive), hidden before"""
    for o in [ob] + list(ob.children_recursive):
        o.hide_render = True
        o.keyframe_insert("hide_render", frame=-1000)
        o.hide_render = False
        o.keyframe_insert("hide_render", frame=f_on)
        if f_off is not None:
            o.hide_render = True
            o.keyframe_insert("hide_render", frame=f_off)


def linear(ob):
    ad = ob.animation_data
    if ad and ad.action:
        for fc in ad.action.fcurves:
            if fc.data_path != "hide_render":
                for k in fc.keyframe_points:
                    k.interpolation = "LINEAR"


def keep_sign(q, prev):
    if prev is not None and q.dot(prev) < 0:
        q = -q
    return q


# --------------------------------------------------------------- materials
_mats = {}


def objtoon(shade=0.72, strength=1.0):
    """cel material whose colour is the object's colour (animated per object: fireballs that cool)"""
    k = ("objtoon", shade, strength)
    if k in _mats:
        return _mats[k]
    m = bpy.data.materials.new("objtoon")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    oi = nt.nodes.new("ShaderNodeObjectInfo")
    dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    nt.links.new(dif.outputs[0], s2r.inputs[0])
    bw = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(s2r.outputs[0], bw.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    g = lambda v: "#%02x%02x%02x" % ((int(v * 255),) * 3)
    K._ramp_stops(ramp.color_ramp, [(0.0, g(shade ** 0.45 * 0.92)), (0.33, g(0.9)), (0.62, g(1.0))])
    nt.links.new(bw.outputs[0], ramp.inputs[0])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    nt.links.new(oi.outputs["Color"], mul.inputs[6])
    nt.links.new(ramp.outputs[0], mul.inputs[7])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = strength
    nt.links.new(mul.outputs[2], em.inputs[0])
    nt.links.new(em.outputs[0], out.inputs[0])
    _mats[k] = m
    return m


def glow_mat(color, strength=2.5):
    k = ("glow", color, strength)
    if k in _mats:
        return _mats[k]
    m = bpy.data.materials.new("glow")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = hexc(color)
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs[0], out.inputs[0])
    _mats[k] = m
    return m


def fade_mat(color, strength=1.0, name="fade"):
    """flat colour with its own animatable alpha (mix node input 0): one per object"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.surface_render_method = "BLENDED"
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = hexc(color)
    em.inputs["Strength"].default_value = strength
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mx = nt.nodes.new("ShaderNodeMixShader")
    mx.name = "alpha"
    mx.inputs[0].default_value = 1.0
    nt.links.new(tr.outputs[0], mx.inputs[1])
    nt.links.new(em.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs[0])
    return m


def radial_mat(color, alpha=1.0, power=1.6):
    """a soft round glow: full colour in the middle fading out to the rim (a unit disc, scaled)"""
    m = bpy.data.materials.new("radial")
    m.use_nodes = True
    m.surface_render_method = "BLENDED"
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    ln = nt.nodes.new("ShaderNodeVectorMath")
    ln.operation = "LENGTH"
    nt.links.new(tc.outputs["Object"], ln.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.0
    mr.inputs["From Max"].default_value = 1.0
    mr.inputs["To Min"].default_value = alpha
    mr.inputs["To Max"].default_value = 0.0
    nt.links.new(ln.outputs["Value"], mr.inputs["Value"])
    pw = nt.nodes.new("ShaderNodeMath")
    pw.operation = "POWER"
    pw.inputs[1].default_value = power
    nt.links.new(mr.outputs[0], pw.inputs[0])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = hexc(color)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(pw.outputs[0], mx.inputs[0])
    nt.links.new(tr.outputs[0], mx.inputs[1])
    nt.links.new(em.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs[0])
    return m


def key_alpha(mat, f, a):
    s = mat.node_tree.nodes["alpha"].inputs[0]
    s.default_value = a
    s.keyframe_insert("default_value", frame=f)


# ------------------------------------------------------------------ meshes
def annulus(r_in=0.86, r_out=1.0, seg=64, mat=None, name="ring"):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    inner = [bm.verts.new((math.cos(a) * r_in, math.sin(a) * r_in, 0)) for a in
             (2 * math.pi * i / seg for i in range(seg))]
    outer = [bm.verts.new((math.cos(a) * r_out, math.sin(a) * r_out, 0)) for a in
             (2 * math.pi * i / seg for i in range(seg))]
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((inner[i], outer[i], outer[j], inner[j]))
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    if mat:
        me.materials.append(mat)
    ob["no_outline"] = True
    return ob


def blob(loc=(0, 0, 0), r=1.0, mat=None, sub=2, name="blob"):
    ob = K.ico(loc=loc, scale=r, mat=mat, sub=sub, smooth=True, name=name)
    return ob


def empty(name="empty", loc=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    e.location = loc
    bpy.context.collection.objects.link(e)
    return e


def outline(ob, t, color=None):
    if color is None:
        K.add_outline(ob, t)
    else:
        K.add_outline(ob, t, color)


# ------------------------------------------------------------------ splash
def splash(loc, f0, size=1.0, seed=0, crown=12, drops=20, column=0.0, rings=2, foam=True,
           color="#f2fcff", line=WATER_LINE, lava=False, life=40, gravity=G):
    """a cartoon splash breaking the surface at loc on frame f0. size ~ the fish's length / 2.
    column > 0 adds a tall jet (big explosions)."""
    rnd = random.Random(seed)
    loc = Vector(loc)
    if lava:
        mat = toon("#ffb21f", flat_glow=True)
        mat2 = toon("#ff6a1f", flat_glow=True)
        line = "#5a1a10"
    else:
        mat = toon(color, shade=0.8, rim=0.0)
        mat2 = toon("#c9f1ff", shade=0.8, rim=0.0)
    sq = math.sqrt(size)
    out = []

    def fly(ob, p0, v, f_start, r, stretch=1.6, shrink_to=0.35):
        t_land = (v.z + math.sqrt(max(0.0, v.z * v.z + 2 * gravity * max(0.0, p0.z + 0.15)))) / gravity
        n = min(life, int(t_land * FPS) + 1)
        prev = None
        for i in range(0, n + 1):
            t = i / FPS
            p = p0 + v * t + Vector((0, 0, -0.5 * gravity * t * t))
            vel = v + Vector((0, 0, -gravity * t))
            k = i / max(1, n)
            s = r * (ease_out(i / 3.0) if i < 3 else lerp(1.0, shrink_to, k ** 1.5))
            q = keep_sign(vel.normalized().to_track_quat("Z", "Y"), prev)
            prev = q
            kf(ob, f_start + i, loc=p, quat=q, scale=(s, s, s * lerp(stretch, 1.0, k)))
        kf(ob, f_start + n + 1, scale=0.0)
        visible(ob, f_start, f_start + n + 1)
        linear(ob)

    # the crown: petals thrown up and out in a ring
    for i in range(crown):
        a = 2 * math.pi * i / crown + rnd.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        p0 = loc + d * 0.3 * size
        v = d * rnd.uniform(1.8, 2.8) * sq + Vector((0, 0, rnd.uniform(6.5, 9.0) * sq))
        ob = blob(p0, 1.0, mat if i % 3 else mat2, sub=2, name="crown")
        outline(ob, 0.16, line)                          # (local units: scales with the blob)
        fly(ob, p0, v, f0, rnd.uniform(0.13, 0.2) * size, stretch=2.2)
        out.append(ob)
    # droplets
    for i in range(drops):
        a = rnd.uniform(0, 2 * math.pi)
        d = Vector((math.cos(a), math.sin(a), 0))
        p0 = loc + d * rnd.uniform(0.0, 0.25) * size
        v = d * rnd.uniform(0.8, 3.6) * sq + Vector((0, 0, rnd.uniform(7.0, 12.0) * sq))
        ob = blob(p0, 1.0, mat, sub=2, name="drop")
        outline(ob, 0.2, line)
        fly(ob, p0, v, f0 + rnd.randint(0, 3), rnd.uniform(0.05, 0.1) * size, stretch=1.4)
        out.append(ob)
    # the jet
    if column > 0:
        n = 7
        for i in range(n):
            p0 = loc + Vector((rnd.uniform(-0.1, 0.1), rnd.uniform(-0.1, 0.1), 0)) * size
            v = Vector((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.4, 0.4), 0)) * sq + \
                Vector((0, 0, math.sqrt(2 * gravity * column) * (1 - i * 0.09)))
            ob = blob(p0, 1.0, mat if i % 2 else mat2, sub=2, name="jet")
            outline(ob, 0.07, line)
            fly(ob, p0, v, f0 + i, (0.55 - i * 0.04) * size, stretch=1.9, shrink_to=0.25)
            out.append(ob)
    # foam where it broke the surface
    if foam:
        fm = blob((loc.x, loc.y, 0.0), 1.0, mat, sub=2, name="foam")
        outline(fm, 0.05, line)
        for i, (s, z) in enumerate([(0.0, 0.1), (0.75, 0.32), (0.95, 0.28), (0.7, 0.18), (0.0, 0.05)]):
            f = f0 + [0, 3, 8, 18, 30][i]
            kf(fm, f, scale=(s * size, s * size, z * size))
        visible(fm, f0, f0 + 31)
        out.append(fm)
    # rings spreading on the water
    for k in range(rings):
        rm = fade_mat("#ffffff" if not lava else "#ffb21f", 1.0, "ringmat")
        ring = annulus(0.8, 1.0, mat=rm, name="ripple")
        ring.location = (loc.x, loc.y, 0.03)
        fs = f0 + k * 6
        for i, (s, a) in enumerate([(0.5, 0.9), (1.6, 0.7), (2.6, 0.35), (3.3, 0.0)]):
            f = fs + [0, 8, 18, 28][i]
            kf(ring, f, scale=(s * size, s * size, 1))
            key_alpha(rm, f, a)
        visible(ring, fs, fs + 29)
        out.append(ring)
    return out


def ripple(loc, f0, size=1.0, n=1, gap=10, color="#ffffff"):
    out = []
    for k in range(n):
        rm = fade_mat(color, 1.0, "ringmat")
        ring = annulus(0.88, 1.0, mat=rm, name="ripple")
        ring.location = (loc[0], loc[1], 0.03)
        fs = f0 + k * gap
        for i, (s, a) in enumerate([(0.2, 0.8), (1.2, 0.5), (2.0, 0.0)]):
            f = fs + [0, 14, 30][i]
            kf(ring, f, scale=(s * size, s * size, 1))
            key_alpha(rm, f, a)
        visible(ring, fs, fs + 31)
        out.append(ring)
    return out


# --------------------------------------------------------------- explosion
def _palette_at(pal, t):
    """colour along a palette for 0..1 (linear rgba)"""
    t = clamp01(t) * (len(pal) - 1)
    i = min(len(pal) - 2, int(t))
    a, b = hexc(pal[i]), hexc(pal[i + 1])
    k = t - i
    return tuple(a[j] + (b[j] - a[j]) * k for j in range(4))


STEAM = ["#ffffff", "#f6fcff", "#e6f5fb", "#d6ecf4"]


def explosion(loc, f0, size=1.0, seed=0, puffs=18, life=40, ring=True, ring_axis="Z", debris=12, sparks=14,
              palette=FIRE, rise=0.6, flash=True, line="#3a1a12", steam=0.0):
    """a cartoon fireball: puffs that burst out, glow white -> yellow -> orange -> red, then cool to smoke and
    drift up; a flash, a shock ring, flying debris and sparks. steam: share of white steam puffs (outer
    ones: an explosion in water)"""
    rnd = random.Random(seed)
    loc = Vector(loc)
    out = []
    mat = objtoon(0.7, 1.0)
    n_steam = int(round(puffs * steam))
    for i in range(puffs):
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1) + 0.35)).normalized()
        is_steam = i >= puffs - n_steam
        dist = (rnd.uniform(0.7, 1.25) if is_steam else rnd.uniform(0.15, 0.85)) * size
        r = rnd.uniform(0.35, 0.7) * size * (1.15 - dist / size * 0.4)
        ob = blob(loc, 1.0, mat, sub=2, name="puff")
        outline(ob, 0.07, "#2f6f8a" if is_steam else line)
        delay = int(dist / size * 3)
        f_s = f0 + delay
        cool = rnd.uniform(0.8, 1.3)
        shift = rnd.uniform(-0.1, 0.3)                       # some puffs hotter, some already smoking
        pal = STEAM if is_steam else palette
        n = int(life * rnd.uniform(0.75, 1.0))
        for k in range(0, n + 1, 1):
            t = k / n
            burst = ease_out(k / 7.0, 3)
            p = loc + d * dist * (0.15 + 0.85 * burst) + d * dist * 0.35 * t + UP * rise * size * t * t * 1.5
            s = r * (back_out(k / 6.0, 1.6) if k < 6 else lerp(1.0, 0.0, ease_in((t - 0.45) / 0.55, 2)) if t > 0.45 else 1.0)
            s *= 1.0 + 0.06 * math.sin(k * 0.9 + i)
            c = _palette_at(pal, (k / (life * 0.75)) * cool * (0.8 + 0.4 * dist / size) + shift)
            kf(ob, f_s + k, loc=p, scale=max(0.0, s), color=c)
        visible(ob, f_s, f_s + n + 1)
        linear(ob)
        out.append(ob)
    if flash:
        fl = blob(loc, 1.0, glow_mat("#fffbe8", 3.0), sub=3, name="flash")
        fl["no_outline"] = True
        for k, s in [(0, 0.3), (1, 0.85), (2, 0.55), (3, 0.0)]:
            kf(fl, f0 + k, scale=s * size)
        visible(fl, f0, f0 + 4)
        linear(fl)
        out.append(fl)
    if ring:
        rm = fade_mat("#fff6d0", 2.0, "shock")
        rg = annulus(0.9, 1.0, mat=rm, name="shock")
        rg.location = loc
        if ring_axis == "Y":
            rg.rotation_euler = (math.radians(90), 0, 0)
        for k, s, a in [(0, 0.3, 1.0), (4, 2.2, 0.9), (9, 3.6, 0.4), (14, 4.4, 0.0)]:
            kf(rg, f0 + k, scale=(s * size, s * size, 1))
            key_alpha(rm, f0 + k, a)
        visible(rg, f0, f0 + 15)
        out.append(rg)
    dmat = toon("#3a2a2a", shade=0.7)
    for i in range(debris):
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), abs(rnd.gauss(0, 1)) + 0.6)).normalized()
        ob = K.ico(loc=loc, scale=1.0, mat=dmat, sub=1, smooth=False, name="debris")
        outline(ob, 0.25, line)
        v = d * rnd.uniform(9, 16) * math.sqrt(size)
        spin = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * 0.6
        r = rnd.uniform(0.06, 0.13) * size
        n = int(life * 0.8)
        for k in range(n + 1):
            t = k / FPS
            p = loc + v * t + Vector((0, 0, -0.5 * G * t * t))
            kf(ob, f0 + k, loc=p, rot=Euler(spin * k), scale=r * (1 - (k / n) ** 3))
        visible(ob, f0, f0 + n + 1)
        linear(ob)
        out.append(ob)
    smat = glow_mat("#fff27a", 3.0)
    for i in range(sparks):
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1) + 0.3)).normalized()
        ob = K.sphere(loc=loc, scale=1.0, mat=smat, seg=8, rings=4, name="spark")
        ob["no_outline"] = True
        v = d * rnd.uniform(14, 24) * math.sqrt(size)
        n = rnd.randint(8, 14)
        prev = None
        for k in range(n + 1):
            t = k / FPS
            vel = v * (1 - k / (n * 1.6))
            p = loc + v * t * (1 - k / (n * 3.2))
            q = keep_sign(vel.normalized().to_track_quat("Z", "Y"), prev)
            prev = q
            s = 0.05 * size * (1 - k / n)
            kf(ob, f0 + k, loc=p, quat=q, scale=(s, s, s * 6))
        visible(ob, f0, f0 + n + 1)
        linear(ob)
        out.append(ob)
    return out


# ---------------------------------------------------------------- 3D text
def text_mesh(body, font=FONT_BOLD, size=1.0, extrude=0.12, bevel=0.02, space=1.0, align="CENTER", name=None,
              shear=0.0, offset=0.0):
    """a text object converted to a mesh (+Z faces the reader); shear pushes the back down so the
    side shows under each letter like the 2D logo's 3D edge"""
    fnt = bpy.data.fonts.load(font, check_existing=True)
    cu = bpy.data.curves.new(name or "txt", "FONT")
    cu.font = fnt
    cu.body = body
    cu.size = size
    cu.align_x = align
    cu.align_y = "BOTTOM_BASELINE"
    cu.extrude = extrude
    cu.bevel_depth = bevel
    cu.bevel_resolution = 2
    cu.space_character = space
    cu.offset = offset                                   # > 0 fattens the letters (outline copies)
    cu.resolution_u = 8
    ob = bpy.data.objects.new(name or body, cu)
    bpy.context.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.active_object
    if shear:
        for v in ob.data.vertices:
            v.co.y += shear * v.co.z
        ob.data.update()
    return ob


def face_side_materials(ob, face_mat, side_mat, cos_min=0.7):
    me = ob.data
    me.materials.clear()
    me.materials.append(face_mat)
    me.materials.append(side_mat)
    for p in me.polygons:
        p.material_index = 0 if p.normal.z > cos_min else 1


def split_glyphs(ob):
    """one object per letter (an i's dot joins its stem), sorted left to right"""
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = list(bpy.context.selected_objects)

    def xr(o):
        xs = [(o.matrix_world @ v.co).x for v in o.data.vertices]
        return min(xs), max(xs)

    def area(o):
        a, b = xr(o)
        zs = [v.co.y for v in o.data.vertices]
        return (b - a) * (max(zs) - min(zs))

    parts.sort(key=area, reverse=True)
    groups = []
    for p in parts:
        a, b = xr(p)
        host = next((g for g in groups if xr(g[0])[0] - 0.02 <= a and b <= xr(g[0])[1] + 0.02), None)
        if host:
            host.append(p)
        else:
            groups.append([p])
    out = []
    for g in groups:
        if len(g) > 1:
            bpy.ops.object.select_all(action="DESELECT")
            for p in g:
                p.select_set(True)
            bpy.context.view_layer.objects.active = g[0]
            bpy.ops.object.join()
        out.append(g[0])
    for o in out:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    out.sort(key=lambda o: o.location.x)
    return out


# ---------------------------------------------------------------- the logo
LOGO_EDGE = "#78cdec"          # make_brand.py EDGE (120, 205, 236)
LOGO_ICE = "#d6f4ff"           # ICE (214, 244, 255)
LOGO_RIM = "#3c96be"


def logo_face_mat(root, top, bottom):
    """white -> ice gradient over the whole logo (make_brand.py styled()), lit with a soft cel ramp"""
    m = bpy.data.materials.new("logoface")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    tc.object = root
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = top
    mr.inputs["From Max"].default_value = bottom
    nt.links.new(sep.outputs["Y"], mr.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    K._ramp_stops(ramp.color_ramp, [(0.35, "#ffffff"), (1.0, LOGO_ICE)])
    nt.links.new(mr.outputs[0], ramp.inputs[0])
    dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    nt.links.new(dif.outputs[0], s2r.inputs[0])
    bw = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(s2r.outputs[0], bw.inputs[0])
    lr = nt.nodes.new("ShaderNodeValToRGB")
    lr.color_ramp.interpolation = "EASE"
    K._ramp_stops(lr.color_ramp, [(0.05, "#d8e6ee"), (0.4, "#ffffff")])
    nt.links.new(bw.outputs[0], lr.inputs[0])
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs[0].default_value = 1.0
    nt.links.new(ramp.outputs[0], mul.inputs[6])
    nt.links.new(lr.outputs[0], mul.inputs[7])
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(mul.outputs[2], em.inputs[0])
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


def _fish_logo_mesh(w, depth, bevel, shear):
    """make_brand.py fish_mask() in 3D: plump body, forked tail, top fin, an eye hole, smile and gill grooves
    (nose to +X, centred)"""
    h = w * 0.62

    def P(x, y):                          # mask px fractions -> local units, y up, centred
        return ((x - 0.5) * w, (0.5 - y) * h)

    body = [P(0.615 + 0.375 * math.cos(a), 0.52 + 0.38 * math.sin(a)) for a in
            (2 * math.pi * i / 48 for i in range(48))]
    tail = [P(0.36, 0.52), P(0.03, 0.12), P(0.15, 0.52), P(0.03, 0.94)]
    fin = [P(0.45, 0.24), P(0.58, 0.0), P(0.74, 0.22)]
    parts = [K.extrude_poly(pts, depth, bevel=0.0) for pts in (body, tail, fin)]
    base = parts[0]
    for o in parts[1:]:
        mod = base.modifiers.new("u", "BOOLEAN")
        mod.operation = "UNION"
        mod.solver = "EXACT"
        mod.object = o
        bpy.context.view_layer.objects.active = base
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(o)
    cutters = []
    er = h * 0.062
    ex, ey = P(0.81, 0.42)
    cutters.append(K.cyl(loc=(ex, ey, 0), r=er, depth=depth * 3, verts=20))

    def arc(cx, cy, rx, ry, a0, a1, th):
        pts_o, pts_i = [], []
        for i in range(17):
            a = math.radians(a0 + (a1 - a0) * i / 16)
            pts_o.append(P(cx + rx * math.cos(a), cy + ry * math.sin(a)))
            pts_i.append(P(cx + (rx - th) * math.cos(a), cy + (ry - th * 0.62 / 0.62) * math.sin(a)))
        return K.extrude_poly(pts_o + pts_i[::-1], depth * 3)

    cutters.append(arc(0.845, 0.61, 0.105, 0.13, 25, 105, 0.03))      # smile
    cutters.append(arc(0.57, 0.53, 0.07, 0.23, -60, 60, 0.025))        # gill
    for c in cutters:
        mod = base.modifiers.new("d", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "EXACT"
        mod.object = c
        bpy.context.view_layer.objects.active = base
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(c)
    if bevel:
        mod = base.modifiers.new("bev", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = base
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for v in base.data.vertices:
        v.co.y += shear * v.co.z
    base.data.update()
    base.name = "logo_fish"
    return base


def build_logo(extrude=0.11, bevel=0.022, shear=0.45, tilt=6.0, rim=0.018):
    """make_brand.py logo() in 3D: "fosh" over "& fish" with the leaping fish, one object per letter
    (each with its origin at its centre) under a root that carries the tilt. Units: "fosh" is 1.0 tall-ish.
    Returns (root, glyphs [f o s h & f i s h], fish)."""
    S = 1.0 / 300.0                   # make_brand.py px at scale 1 -> units
    root = empty("logo")
    l1 = split_glyphs(text_mesh("fosh", FONT_LOGO, 1.0, extrude, bevel, space=0.985, align="LEFT", shear=shear))
    amp = split_glyphs(text_mesh("&", FONT_LOGO, 170 / 300, extrude, bevel, align="LEFT", shear=shear))
    l2 = split_glyphs(text_mesh("fish", FONT_LOGO, 1.0, extrude, bevel, space=0.985, align="LEFT", shear=shear))
    if (len(l1), len(amp), len(l2)) != (4, 1, 4):
        raise RuntimeError("logo letters came out as %d+%d+%d pieces (font overlaps not removed? boom_prep.py)"
                           % (len(l1), len(amp), len(l2)))

    def bbox(objs):
        pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices if v.co.z > 0]
        return (min(p.x for p in pts), max(p.x for p in pts), min(p.y for p in pts), max(p.y for p in pts))

    def move(objs, dx, dy):
        for o in objs:
            o.location.x += dx
            o.location.y += dy
        bpy.context.view_layer.update()

    bpy.context.view_layer.update()
    x0, x1, y0, y1 = bbox(l1)
    move(l1, -x0, -y1)                                    # "fosh": top-left at the origin
    bx0, bx1, by0, by1 = bbox(l1)
    h1, w1 = by1 - by0, bx1 - bx0
    a0, a1, ay0, ay1 = bbox(l2)
    top2 = -(h1 + 26 * S)
    move(l2, 160 * S - a0, top2 - ay1)
    c0, c1, cy0, cy1 = bbox(amp)
    ampw = c1 - c0
    move(amp, 160 * S - ampw * 1.08 - c0, top2 - 30 * S - cy1)
    fish = _fish_logo_mesh(170 * S, extrude * 2, bevel * 0.8, shear)
    fish.rotation_euler = (0, 0, math.radians(18))
    # PIL pastes the rotated (expanded) fish with its top-left at (fosh width - 10, 20): centre of that box
    fw, fh, a18 = 170.0, 105.0, math.radians(18)
    rw, rh = fw * math.cos(a18) + fh * math.sin(a18), fw * math.sin(a18) + fh * math.cos(a18)
    fish.location = (w1 + (rw / 2 - 10) * S, -(20 + rh / 2) * S, 0)
    glyphs = l1 + amp + l2
    allo = glyphs + [fish]
    bpy.context.view_layer.update()
    X0, X1, Y0, Y1 = bbox(allo)
    cx, cy = (X0 + X1) / 2, (Y0 + Y1) / 2
    for o in allo:
        o.location.x -= cx
        o.location.y -= cy
    face = logo_face_mat(root, (Y1 - cy) + 0.05, (Y0 - cy))
    side = toon(LOGO_EDGE, shade=0.72, rim=0.0)
    for o in allo:
        face_side_materials(o, face, side, 0.55)
        o["outline_even"] = False
        K.add_outline(o, rim, LOGO_RIM)
        o.parent = root
    root.rotation_euler = (0, 0, math.radians(tilt))
    bpy.context.view_layer.update()
    return root, glyphs, fish


def slam(ob, f_hit, rest_loc, rest_rot=(0, 0, 0), rest_scale=1.0, frm=(0, 0, 3.0), frm_scale=2.2, travel=4,
         seed=0, squash=0.22):
    """a letter falls onto its spot (from toward the camera), squashes, overshoots and settles"""
    rnd = random.Random(seed)
    rest_loc = Vector(rest_loc)
    r0 = Euler((math.radians(rnd.uniform(-30, 30)), math.radians(rnd.uniform(-30, 30)), math.radians(rnd.uniform(-35, 35))))
    rr = Euler(rest_rot)
    for k in range(-travel, 0):
        t = (k + travel) / travel
        e = ease_in(t, 2)
        p = vlerp(rest_loc + Vector(frm), rest_loc, e)
        rot = Euler([lerp(a, b, e) for a, b in zip(r0, rr)])
        s = lerp(frm_scale, 1.0, e) * rest_scale
        kf(ob, f_hit + k, loc=p, rot=rot, scale=s)
    for k, sx, sy in [(0, 1 + squash, 1 - squash), (2, 1 - squash * 0.5, 1 + squash * 0.6), (4, 1 + squash * 0.2, 1 - squash * 0.2),
                      (7, 1.0, 1.0)]:
        kf(ob, f_hit + k, loc=rest_loc, rot=rr, scale=(sx * rest_scale, sy * rest_scale, rest_scale))
    visible(ob, f_hit - travel)


# -------------------------------------------------------------- comic word
def star(n, r1, r2, jitter=0.0, seed=0):
    rnd = random.Random(seed)
    pts = []
    for i in range(n * 2):
        r = (r1 if i % 2 == 0 else r2) * (1 + rnd.uniform(-jitter, jitter))
        a = math.pi / 2 + i * math.pi / n + rnd.uniform(-jitter, jitter) * 0.3
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


def comic_word(text, size=1.0, face="#ffe14a", side="#ff6a1f", line="#2a0f08", burst="#ff3d2e", burst2="#fff3b0",
               seed=1, burst_r=None):
    """a chunky comic sound effect on a jagged starburst, built facing -Y (toward a camera on -Y)"""
    root = empty("word_" + text)
    tm = text_mesh(text, FONT_BOLD, size, extrude=0.12 * size, bevel=0.025 * size, space=0.92, align="CENTER",
                   shear=0.4)
    face_side_materials(tm, toon(face, shade=0.8, rim=0.0), toon(side, shade=0.75, rim=0.0), 0.55)
    bpy.context.view_layer.update()
    xs = [v.co.x for v in tm.data.vertices]
    ys = [v.co.y for v in tm.data.vertices]
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    cy = (min(ys) + max(ys)) / 2
    for v in tm.data.vertices:                          # centre the word on the burst
        v.co.y -= cy
    tm.data.update()
    # the outline: a fattened copy of the word just behind it (a solidify hull spikes on letter corners)
    ol = text_mesh(text, FONT_BOLD, size, extrude=0.12 * size, bevel=0.025 * size, space=0.92, align="CENTER",
                   shear=0.4, offset=0.07 * size)
    for v in ol.data.vertices:
        v.co.y -= cy
        v.co.z -= 0.03 * size
    ol.data.update()
    ol.data.materials.clear()
    ol.data.materials.append(toon(line, flat_glow=True))
    ol["no_outline"] = True
    ol.parent = None
    R = burst_r or max(w * 0.58, h * 1.05)
    b1 = K.extrude_poly(star(14, R, R * 0.72, 0.12, seed), 0.08 * size, loc=(0, 0, -0.35 * size),
                        mat=toon(burst, shade=0.85, rim=0.0))
    K.add_outline(b1, 0.05 * size, line)
    b2 = K.extrude_poly(star(14, R * 0.8, R * 0.6, 0.1, seed + 7), 0.08 * size, loc=(0, 0, -0.25 * size),
                        mat=toon(burst2, shade=0.9, rim=0.0))
    b2["no_outline"] = True
    for o in (tm, ol, b1, b2):
        o.parent = root
    root.rotation_euler = (math.radians(90), 0, 0)
    return root, tm, (b1, b2), (w, h)


def pop_word(root, f0, life, tilt=-6.0, seed=0, out=True):
    """pop in with an elastic overshoot, jiggle, pop out (the word faces -Y: tilt turns it about Y, in the
    picture plane)"""
    rnd = random.Random(seed)
    rx = math.radians(90)
    keys = [(0, 0.0, -24), (3, 1.28, 8), (5, 0.9, -3), (7, 1.06, 2), (9, 1.0, 0)]
    for k, s, r in keys:
        kf(root, f0 + k, scale=s, rot=(rx, math.radians(tilt + r), 0))
    for k in range(10, life - 5, 2):
        s = 1.0 + 0.025 * math.sin(k * 1.3)
        kf(root, f0 + k, scale=s, rot=(rx, math.radians(tilt + 1.5 * math.sin(k * 0.8 + rnd.random())), 0))
    if out:
        kf(root, f0 + life - 4, scale=1.08)
        kf(root, f0 + life, scale=0.0)
    visible(root, f0, f0 + life + 1)


# ---------------------------------------------------------------- sunburst
def sunburst(loc, radius, n, col_a, col_b, f0, f1, spin=0.4, rot=(0, 0, 0), name="sunburst", center=None):
    """alternating wedges (a disc of col_a with n wedges of col_b), turning slowly; faces -Y"""
    root = empty(name, loc)
    root.rotation_euler = Euler([math.radians(a) for a in rot])
    disc = K.cyl(loc=(0, 0, -0.02), r=radius, depth=0.01, verts=64, mat=toon(col_a, flat_glow=True), smooth=False)
    disc["no_outline"] = True
    disc.rotation_euler = (math.radians(90), 0, 0)
    disc.parent = root
    me = bpy.data.meshes.new("wedges")
    bm = bmesh.new()
    c = bm.verts.new((0, 0, 0))
    for i in range(n):
        a0 = 2 * math.pi * i / n
        a1 = a0 + math.pi / n
        v0 = bm.verts.new((math.cos(a0) * radius, 0, math.sin(a0) * radius))
        v1 = bm.verts.new((math.cos(a1) * radius, 0, math.sin(a1) * radius))
        bm.faces.new((c, v0, v1))
    bm.to_mesh(me)
    bm.free()
    wd = bpy.data.objects.new("wedges", me)
    bpy.context.collection.objects.link(wd)
    me.materials.append(toon(col_b, flat_glow=True))
    wd["no_outline"] = True
    wd.location = (0, -0.01, 0)
    wd.parent = root
    if center:
        cg = K.cyl(loc=(0, -0.03, 0), r=1.0, depth=0.01, verts=64, mat=radial_mat(center, 0.85), smooth=False)
        cg.rotation_euler = (math.radians(90), 0, 0)
        cg.scale = (radius * 0.55, radius * 0.55, 1)
        cg["no_outline"] = True
        cg.parent = root
    for f in (f0, f1):
        wd.rotation_euler = (0, math.radians(spin * (f - f0)), 0)
        wd.keyframe_insert("rotation_euler", frame=f)
    linear(wd)
    return root


# ------------------------------------------------------------------ screens
def rounded_rect(w, h, r, n=8):
    pts = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180),
                       (w / 2 - r, -h / 2 + r, 270)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def clip_material(clip_dir, n, f_start, strength=1.0):
    files = sorted(f for f in os.listdir(clip_dir) if f.endswith(".jpg"))
    img = bpy.data.images.load(os.path.join(clip_dir, files[0]))
    img.source = "SEQUENCE"
    m = bpy.data.materials.new("clip")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tx = nt.nodes.new("ShaderNodeTexImage")
    tx.image = img
    tx.interpolation = "Cubic"
    iu = tx.image_user
    iu.frame_duration = n
    iu.frame_start = f_start
    iu.frame_offset = 0
    iu.use_auto_refresh = True
    iu.use_cyclic = False
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = strength
    nt.links.new(tx.outputs[0], em.inputs[0])
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


def screen(clip_dir, n, f_start, w=16.0, h=9.0, bezel=0.45, depth=0.5, radius=0.7, color="#fbfdff", line="#1b2a3a",
           name="screen", stand=False):
    """a rounded slab with the gameplay clip on its face, facing -Y; origin at the centre of the picture"""
    root = empty(name)
    slab = K.extrude_poly(rounded_rect(w + bezel * 2, h + bezel * 2, radius), depth, mat=toon(color, shade=0.8),
                          bevel=0.06)
    slab.rotation_euler = (math.radians(90), 0, 0)
    slab.location = (0, depth / 2 + 0.01, 0)
    slab["outline_even"] = False
    K.add_outline(slab, 0.08, line)
    slab.parent = root
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    pic = bpy.context.active_object
    pic.scale = (w, h, 1)
    pic.rotation_euler = (math.radians(90), 0, 0)
    pic.location = (0, -0.005, 0)
    pic.data.materials.append(clip_material(clip_dir, n, f_start))
    pic["no_outline"] = True
    pic.parent = root
    if stand:
        neck = K.cube(loc=(0, depth * 0.8, -h / 2 - bezel - 0.9), scale=(1.2, 0.5, 1.8), mat=toon(color, shade=0.8))
        foot = K.extrude_poly(rounded_rect(5.0, 2.4, 0.6), 0.25, loc=(0, depth * 0.8, -h / 2 - bezel - 1.9),
                              mat=toon(color, shade=0.8))
        for o in (neck, foot):
            K.add_outline(o, 0.08, line)
            o.parent = root
    return root


def phone(clip_dir, n, f_start, w=4.8, h=10.0, name="phone"):
    """a modern phone (dark bezel, rounded) with the clip on its screen, facing -Y"""
    root = empty(name)
    body = K.extrude_poly(rounded_rect(w + 0.36, h + 0.36, 0.75), 0.45, mat=toon("#1c2230", shade=0.7), bevel=0.05)
    body.rotation_euler = (math.radians(90), 0, 0)
    body.location = (0, 0.24, 0)
    body["outline_even"] = False
    K.add_outline(body, 0.06, "#0b0f18")
    body.parent = root
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    pic = bpy.context.active_object
    pic.scale = (w, h, 1)
    pic.rotation_euler = (math.radians(90), 0, 0)
    pic.location = (0, -0.005, 0)
    pic.data.materials.append(clip_material(clip_dir, n, f_start))
    pic["no_outline"] = True
    pic.parent = root
    notch = K.extrude_poly(rounded_rect(1.3, 0.34, 0.17), 0.02, loc=(0, -0.02, h / 2 - 0.42),
                           rot=(90, 0, 0), mat=toon("#0b0f18", flat_glow=True))
    notch["no_outline"] = True
    notch.parent = root
    return root


# --------------------------------------------------------------------- fish
def fish(name, scale=1.0, line=0.035, spec=None):
    """a game fish (vf_models), nose +X, under one root"""
    spec = spec or M.FISH_SPECS.get(name) or M.PET_SPECS.get(name)
    parts = M.build_fish(spec)
    K.outline_all(parts, line)
    root = K.parent_all(parts, "fish_" + name.replace(" ", "_"))
    root.scale = (scale, scale, scale)
    return root


def leap(root, f_out, f_in, p_out, p_in, height, wiggle=14.0, roll=0.0, spin=0.0, pre=8, post=8, scale=None):
    """a jump out of the water: breaks the surface at p_out on f_out, dives at p_in on f_in, nose along the
    arc, tail wagging; spin = full barrel rolls during the flight"""
    p_out, p_in = Vector(p_out), Vector(p_in)
    T = float(f_in - f_out)
    for f in range(f_out - pre, f_in + post + 1):
        u = (f - f_out) / T
        pos = p_out.lerp(p_in, u) + UP * 4 * height * u * (1 - u)
        vel = (p_in - p_out) + UP * 4 * height * (1 - 2 * u)
        yaw = math.atan2(vel.y, vel.x)
        hor = math.hypot(vel.x, vel.y)
        pitch = math.atan2(vel.z, hor)
        wag = math.radians(wiggle) * math.sin(f * 1.5)
        rl = math.radians(roll) + 2 * math.pi * spin * clamp01(u)
        kf(root, f, loc=pos, rot=Euler((rl, -pitch, yaw + wag), "XYZ"))
        if scale is not None:
            kf(root, f, scale=scale)
    linear(root)
    visible(root, f_out - pre, f_in + post + 1)


def rot_from(fwd, up=(0, 0, 1)):
    """euler that turns +X to fwd (keeping +Z up-ish)"""
    fwd = Vector(fwd).normalized()
    side = Vector(up).cross(fwd)
    if side.length < 1e-6:
        side = Vector((0, 1, 0))
    side.normalize()
    upv = fwd.cross(side)
    m = Matrix((fwd, side, upv)).transposed()
    return m.to_euler()

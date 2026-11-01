"""The game's face in the game's own look, rendered here (assets/brand/src); tools/art/make_brand.py then gives the
logo and icon their outline and shadow and cuts all the sizes.
    logo_3d.png    chunky golden letters; the "o" is a life ring, the dot on the "i" a bobber, a fish leaps off the top
    icon_3d.png    a fish leaping through a life ring
    (fonts: build/boom/Fredoka-*.ttf, tools/video/boom_prep.py)
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import boom_fx as FX
import vf_kit as K
import vf_life as L
import vf_models as M
from vf_kit import cone, hexc, sphere, toon, torus, tube, vcolor

GOLD = [(0.0, "#fff0b4"), (0.45, "#ffd144"), (1.0, "#ff9a28")]
MINT = [(0.0, "#a8f7e0"), (0.5, "#4fdfc0"), (1.0, "#16a893")]
SIDE = "#c2531c"
HERO = dict(top="#ff8a3d", belly="#fff3cf", fin="#ff5a48", L=1.0, H=0.54, W=0.3, cute=True)   # the leaping fish


def _face_mat(name, top, bottom, stops):
    """a gradient down the letters, softly lit (like boom_fx.logo_face_mat, in colour)"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = top
    mr.inputs["From Max"].default_value = bottom
    nt.links.new(sep.outputs["Y"], mr.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    K._ramp_stops(ramp.color_ramp, stops)
    ramp.color_ramp.interpolation = "EASE"
    nt.links.new(mr.outputs[0], ramp.inputs[0])
    dif = nt.nodes.new("ShaderNodeBsdfDiffuse")
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    nt.links.new(dif.outputs[0], s2r.inputs[0])
    bw = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(s2r.outputs[0], bw.inputs[0])
    lr = nt.nodes.new("ShaderNodeValToRGB")
    lr.color_ramp.interpolation = "EASE"
    K._ramp_stops(lr.color_ramp, [(0.05, "#e9d9c8"), (0.42, "#ffffff")])
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


def _bbox(objs):
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    return min(p.x for p in pts), max(p.x for p in pts), min(p.y for p in pts), max(p.y for p in pts)


def _move(objs, dx, dy):
    for o in objs:
        o.location.x += dx
        o.location.y += dy
    bpy.context.view_layer.update()


def life_ring(loc, R, r, bands=8):
    """red and white, like the ones on the shop's wall (lying flat, facing +Z)"""
    red, white = hexc("#d9281c"), hexc("#fdf9ef")
    ob = torus(loc=loc, R=R, r=r, seg=64, mseg=20)

    def paint(co, n):
        a = (math.atan2(co.y, co.x) + math.pi / bands) / math.tau
        return red if int(a * bands) % 2 == 0 else white
    vcolor(ob, paint, per_face=True)
    ob.data.materials.clear()
    ob.data.materials.append(toon(None, vcol="col", spec=0.08, rim=0.0, key=("ring",)))
    return ob


def bobber(loc, s):
    """the game's float: red on top, white below"""
    ob = sphere(loc=loc, scale=s, seg=32, rings=16)
    vcolor(ob, lambda co, n: hexc("#d9281c") if co.y > -0.1 * s else hexc("#fdf9ef"))
    ob.data.materials.clear()
    ob.data.materials.append(toon(None, vcol="col", spec=0.08, rim=0.0, key=("bobber",)))
    return ob


def leaping_fish(at, size, rot):
    """the fish, side on to you, with its tail swung -> (root, parts)"""
    parts = M.build_fish(HERO)
    smile = tube([(0.94, -0.085, -0.075), (0.88, -0.14, -0.16), (0.76, -0.2, -0.18)], 0.017, mat=toon("#7a2e1c"))
    smile["no_outline"] = True
    parts.append(smile)
    root, baked = L._bake(parts)
    allv = np.concatenate([a for _, a in baked])
    L._pose(baked, L._swim(HERO, float(allv[:, 0].max()), float(allv[:, 0].min())), 1.7)
    root.location = at
    root.scale = (size, size, size)
    root.rotation_euler = [math.radians(a) for a in rot]
    K.outline_all([p for p, _ in baked], 0.03)
    bpy.context.view_layer.update()
    return root, [p for p, _ in baked]


def render_logo(path):
    K.clear_scene()
    K.SOFT[0] = True
    K.setup_render(1800, 1300, samples=32)
    K.setup_world("#b9c2cc", 1.0)
    s = K.sun((32, -26, 0), 1.3)
    s.data.angle = math.radians(10)
    cam = K.make_camera((0, 0, 0), ortho=True)
    S = 1.0 / 300.0
    ex, bev, shear = 0.11, 0.022, 0.55
    l1 = FX.split_glyphs(FX.text_mesh("fosh", FX.FONT_LOGO, 1.0, ex, bev, space=0.97, align="LEFT", shear=shear))
    amp = FX.split_glyphs(FX.text_mesh("&", os.path.join(FX.WORK, "Fredoka-Semi.ttf"), 0.7, ex, bev, align="LEFT", shear=shear))
    l2 = FX.split_glyphs(FX.text_mesh("fish", FX.FONT_LOGO, 1.0, ex, bev, space=0.97, align="LEFT", shear=shear))
    x0, _, _, y1 = _bbox(l1)
    _move(l1, -x0, -y1)
    bx0, bx1, by0, by1 = _bbox(l1)
    h1 = by1 - by0
    a0, _, _, ay1 = _bbox(l2)
    top2 = -(h1 + 8 * S)
    _move(l2, 170 * S - a0, top2 - ay1)
    c0, c1, _, cy1 = _bbox(amp)
    _move(amp, 170 * S - (c1 - c0) * 1.04 - c0, top2 - 56 * S - cy1)
    # the "o" is a life ring
    o = l1[1]
    ox0, ox1, oy0, oy1 = _bbox([o])
    w = ox1 - ox0
    ring = life_ring(((ox0 + ox1) * 0.5, (oy0 + oy1 + 0.03) * 0.5, 0.03), w * 0.345, w * 0.155)
    bpy.data.objects.remove(o)
    l1.pop(1)
    # the dot on the "i" is a bobber
    i = l2[1]
    bm = bmesh.new()
    bm.from_mesh(i.data)
    # (it's two separate pieces of mesh, the stem and the dot)
    seen, pieces = set(), []
    for v0 in bm.verts:
        if v0.index in seen:
            continue
        piece, todo = [], [v0]
        seen.add(v0.index)
        while todo:
            v = todo.pop()
            piece.append(v)
            for e in v.link_edges:
                n = e.other_vert(v)
                if n.index not in seen:
                    seen.add(n.index)
                    todo.append(n)
        pieces.append(piece)
    dot = max(pieces, key=lambda p: sum(v.co.y for v in p) / len(p))
    dx, dy = sum(v.co.x for v in dot) / len(dot), sum(v.co.y for v in dot) / len(dot)
    bmesh.ops.delete(bm, geom=dot, context="VERTS")
    bm.to_mesh(i.data)
    bm.free()
    i.data.update()
    bpy.context.view_layer.update()
    at = i.matrix_world @ Vector((dx, dy, 0))
    bob = bobber((at.x, at.y + 0.012, 0.06), 0.112)
    # gold letters, with a gradient of their own on each line
    _, _, y0a, y1a = _bbox(l1)
    _, _, y0b, y1b = _bbox(l2)
    gold1 = _face_mat("gold1", y1a, y0a, GOLD)
    gold2 = _face_mat("gold2", y1b, y0b, GOLD)
    _, _, a_y0, a_y1 = _bbox(amp)
    mint = _face_mat("mint", a_y1, a_y0, MINT)
    side = toon(SIDE, shade=0.72, rim=0.0)
    for g, f in [(l1, gold1), (l2, gold2), (amp, mint)]:
        for ob in g:
            FX.face_side_materials(ob, f, side, 0.62)
    # the fish, leaping off the end of the first line
    froot, fparts = leaping_fish((bx1 + 0.36, by1 - 0.13, 0.25), 0.36, (-90, 0, 34))
    objs = l1 + l2 + amp + [ring, bob] + fparts
    root = FX.empty("logo")
    bpy.context.view_layer.update()
    for ob in l1 + l2 + amp + [ring, bob, froot]:
        w0 = ob.matrix_world.copy()
        ob.parent = root
        ob.matrix_world = w0
    root.rotation_euler = (0, 0, math.radians(5))
    bpy.context.view_layer.update()
    xs0, xs1, ys0, ys1 = 1e9, -1e9, 1e9, -1e9
    for p in K._mesh_points(objs):
        xs0, xs1, ys0, ys1 = min(xs0, p.x), max(xs1, p.x), min(ys0, p.y), max(ys1, p.y)
    sc = bpy.context.scene
    sc.render.resolution_y = int(sc.render.resolution_x * (ys1 - ys0) / (xs1 - xs0)) + 40
    K.frame_ortho(cam, objs, 1.03)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    K.render(path)
    K.SOFT[0] = False


def render_icon(path):
    K.clear_scene()
    K.SOFT[0] = True
    K.setup_render(1024, 1024, samples=32)
    K.setup_world("#b9c2cc", 1.0)
    s = K.sun((30, -28, 0), 1.25)
    s.data.angle = math.radians(10)
    cam = K.make_camera((0, 0, 0), ortho=True)
    rot = (-90, -28, 36)
    froot, fparts = leaping_fish((0.1, 0.05, 0.0), 0.9, rot)
    # the ring around its middle, square to the way it's going: the fish threads it
    going = froot.matrix_world.to_3x3() @ Vector((1, 0, 0))
    ring = life_ring((0, 0, 0), 0.92, 0.24)
    ring.location = Vector((0.1, 0.05, 0.0)) - going.normalized() * 0.2
    ring.rotation_mode = "QUATERNION"
    ring.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(going.normalized())
    K.outline_all([ring], 0.03)
    K.frame_ortho(cam, fparts + [ring], 1.04)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    K.render(path)
    K.SOFT[0] = False

"""fosh&fish 1.0 ad "STARFALL" (the shiny hunt, by night): the 3D shots, rendered VERTICAL (1080x1920) with
Blender (Eevee) in the game's cel-shaded style, with the KABOOM / Leviathan tools (boom_video.py, boom_fx.py,
boom10_video.py) and the 1.0 shiny palettes (render_v1.py). Timing: tools/video/starfall_timeline.py.

    blender -b --factory-startup --python tools/blender/starfall_video.py -- SHOT [SHOT ...]
            [--pct 50] [--samples 16] [--still F,F,...] [--force]

SHOT: a shot of starfall_timeline.SHOTS or "all". Frames go to build/starfall/frames/####.png,
stills to build/starfall/stills/. Needs the fonts in build/boom (tools/video/boom_prep.py).
Blender 4.2 (the one the other video scripts use: Eevee Next).
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "video"))

import boom_video as BV  # noqa: E402
import boom_fx as FX  # noqa: E402
import boom10_video as B10  # noqa: E402
import starfall_timeline as T  # noqa: E402
import vf_biomes as BI  # noqa: E402
import vf_kit as K  # noqa: E402
import vf_fisher as FI  # noqa: E402
from boom_fx import ease_out, kf, lerp, linear, smooth, visible, vlerp  # noqa: E402
from vf_kit import toon  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
WORK = os.path.join(ROOT, "build", "starfall")
FRAMES = os.path.join(WORK, "frames")
STILLS = os.path.join(WORK, "stills")
OPT = BV.OPT

NIGHT = dict(sky=[(0, "#4c3c9e"), (0.28, "#1c1652"), (1, "#05041a")], fog="#2c2468", stars=1.3,
             water=("#070c2a", "#22357e", "#7d8fd6"), ambient="#4e4e7a", sun=(64, 0, 120), sun_col="#c0c8ff")
GOLD = "#ffd75e"
HERO = "Hot Cod"            # the shiny the ad is about: purple and gold, it stands out against the gold glow
SPLASH = "#eef4ff"


def vscene(transparent=False):
    """boom_video's scene, but vertical"""
    sc = BV.scene(transparent=transparent)
    sc.render.resolution_x = T.W * OPT["pct"] // 100
    sc.render.resolution_y = T.H * OPT["pct"] // 100
    return sc


# ------------------------------------------------------------------ the night
def aurora_mat(c1, c2, strength=1.7, drift=0.0, f0=0, f1=100):
    """a curtain of light: a bright low edge (c1) fading up into c2, rays across it, soft at both ends"""
    m = bpy.data.materials.new("aurora")
    m.use_nodes = True
    m.surface_render_method = "BLENDED"
    nt = m.node_tree
    nt.nodes.clear()
    link = nt.links.new
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    link(tc.outputs["Generated"], sep.inputs[0])
    up = nt.nodes.new("ShaderNodeValToRGB")                   # colour + alpha up the curtain
    a, b = K.hexc(c1), K.hexc(c2)
    cr = up.color_ramp
    cr.elements[0].position, cr.elements[0].color = 0.0, (a[0], a[1], a[2], 0.0)
    cr.elements[1].position, cr.elements[1].color = 1.0, (b[0], b[1], b[2], 0.0)
    for pos, col, al in ((0.04, a, 1.0), (0.22, a, 0.75), (0.6, b, 0.35)):
        e = cr.elements.new(pos)
        e.color = (col[0], col[1], col[2], al)
    link(sep.outputs["Z"], up.inputs[0])
    ends = nt.nodes.new("ShaderNodeValToRGB")                 # fading out at both ends
    er = ends.color_ramp
    er.elements[0].color = (0, 0, 0, 1)
    er.elements[1].color = (0, 0, 0, 1)
    for pos in (0.22, 0.78):
        er.elements.new(pos).color = (1, 1, 1, 1)
    link(sep.outputs["X"], ends.inputs[0])
    shift = nt.nodes.new("ShaderNodeMath")                    # rays: 1D noise across it, sliding slowly
    shift.operation = "ADD"
    link(sep.outputs["X"], shift.inputs[0])
    for f, v in ((f0 - 2, 0.0), (f1 + 2, drift)):
        shift.inputs[1].default_value = v
        shift.inputs[1].keyframe_insert("default_value", frame=f)
    ray = nt.nodes.new("ShaderNodeTexNoise")
    ray.noise_dimensions = "1D"
    ray.inputs["Scale"].default_value = 34.0
    ray.inputs["Detail"].default_value = 3.0
    link(shift.outputs[0], ray.inputs["W"])
    rr = nt.nodes.new("ShaderNodeMapRange")
    rr.inputs["From Min"].default_value = 0.32
    rr.inputs["From Max"].default_value = 0.68
    rr.inputs["To Min"].default_value = 0.2
    rr.inputs["To Max"].default_value = 1.0
    link(ray.outputs["Fac"], rr.inputs["Value"])
    m1 = nt.nodes.new("ShaderNodeMath")
    m1.operation = "MULTIPLY"
    link(up.outputs["Alpha"], m1.inputs[0])
    link(ends.outputs["Color"], m1.inputs[1])
    m2 = nt.nodes.new("ShaderNodeMath")
    m2.operation = "MULTIPLY"
    link(m1.outputs[0], m2.inputs[0])
    link(rr.outputs[0], m2.inputs[1])
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = strength
    link(up.outputs["Color"], em.inputs[0])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mx = nt.nodes.new("ShaderNodeMixShader")
    link(m2.outputs[0], mx.inputs[0])
    link(tr.outputs[0], mx.inputs[1])
    link(em.outputs[0], mx.inputs[2])
    link(mx.outputs[0], out.inputs[0])
    if nt.animation_data and nt.animation_data.action:
        for fc in nt.animation_data.action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = "LINEAR"
    return m


def aurora(f0, f1, y=250.0):
    """three folded curtains of light high over the far sea, their rays drifting"""
    for i, (c1, c2, x0, z0, h, ph) in enumerate([("#45ffa8", "#3fc8ff", -30.0, 34.0, 130.0, 0.0),
                                                  ("#c06bff", "#ff6bd0", 40.0, 52.0, 120.0, 1.7),
                                                  ("#5affc0", "#8a6bff", 0.0, 70.0, 140.0, 3.1)]):
        me = bpy.data.meshes.new("aurora")
        bm = bmesh.new()
        n = 64
        cols = []
        for k in range(n + 1):
            x = -230 + 460 * k / n
            yy = y + 38 * math.sin(x * 0.014 + ph) + i * 24
            cols.append((bm.verts.new((x, yy, 0)), bm.verts.new((x, yy + 10 * math.sin(x * 0.04 + ph), h))))
        for k in range(n):
            bm.faces.new((cols[k][0], cols[k + 1][0], cols[k + 1][1], cols[k][1]))
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new("aurora", me)
        bpy.context.collection.objects.link(ob)
        me.materials.append(aurora_mat(c1, c2, drift=0.012 * (1 if i % 2 else -1), f0=f0, f1=f1))
        ob["no_outline"] = True
        for f, dx in ((f0 - 2, 0.0), (f1 + 2, 5.0 * (1 if i % 2 else -1))):
            kf(ob, f, loc=(x0 + dx, 0, z0))
        linear(ob)


def night_sea(f0, f1, stream=(0.0, -0.8)):
    """the Ocean diorama by night: no clouds or gulls (only grey blobs in the dark), the aurora over it"""
    cloud = BI.cloud
    BI.cloud = lambda *a, **k: []
    try:
        parts = B10.sea(NIGHT, f0, f1, stream=stream)
    finally:
        BI.cloud = cloud
    bpy.context.view_layer.update()
    for ob in list(parts):
        c = sum((ob.matrix_world @ Vector(b) for b in ob.bound_box), Vector()) / 8.0
        if abs(c.y - 60.0) < 1.5 and 12.0 < c.z < 32.0:          # the gulls
            bpy.data.objects.remove(ob)
    aurora(f0, f1)


def lantern(boat):
    """a little lamp on the boat, glowing"""
    pole = K.cyl(r=0.03, depth=1.0, verts=8, mat=toon("#5a3a22"))
    lamp = FX.blob((0, 0, 0), 0.16, FX.glow_mat("#ffd27a", 5.0), sub=2, name="lamp")
    lamp["no_outline"] = True
    halo = K.cyl(r=1.0, depth=0.01, verts=32, mat=FX.radial_mat("#ffcf6a", 0.5), smooth=False)
    halo["no_outline"] = True
    halo.rotation_euler = (math.radians(90), 0, 0)
    halo.scale = (0.9, 0.9, 1)
    for o, loc in ((pole, (-0.55, 0.0, 0.75)), (lamp, (-0.55, 0.0, 1.3)), (halo, (-0.55, -0.05, 1.3))):
        o.parent = boat
        o.location = loc
    return lamp


def glow_spot(loc, f0, size=3.0, f_off=None, color=GOLD):
    """the sea glowing gold where a star lands (a soft disc on the water that blooms, then breathes)"""
    d = K.cyl(r=1.0, depth=0.01, verts=48, mat=FX.radial_mat(color, 0.95), smooth=False)
    d["no_outline"] = True
    loc = Vector(loc)
    f_off = f_off or f0 + 80
    keys = [(f0, 0.0), (f0 + 4, size * 1.3), (f0 + 10, size)]
    keys += [(f, size * (1.0 + 0.08 * math.sin(f * 0.21 + loc.x))) for f in range(f0 + 16, f_off - 6, 8)]
    keys += [(f_off, 0.0)]
    for f, s in keys:
        kf(d, f, loc=(loc.x, loc.y, 0.03), scale=(s, s, 1))
    visible(d, f0, f_off + 1)
    return d


def flash(loc, f0, size=3.0, color="#fff3c0"):
    """a burst of light where a star hits (a glow facing the camera, sitting on the water, gone in a few frames)"""
    d = K.cyl(r=1.0, depth=0.01, verts=48, mat=FX.radial_mat(color, 1.0), smooth=False)
    d["no_outline"] = True
    d.rotation_euler = (math.radians(90), 0, 0)
    loc = Vector(loc)
    for k, s in [(0, 0.2), (2, size), (5, size * 0.7), (10, 0.0)]:
        kf(d, f0 + k, loc=loc + Vector((0, 0, 0.85 * s)), scale=(s, s, 1))   # (its faint rim just dips in)
    visible(d, f0, f0 + 11)


def falling_star(hit, f_hit, dur=16, size=1.0, seed=0, f_off=None, spot=3.0):
    """a golden star streaking down into the sea: a flash, a splash, and the water glows where it went in"""
    rnd = random.Random(seed)
    hit = Vector(hit)
    d = Vector((rnd.uniform(-0.45, 0.45), rnd.uniform(-0.2, 0.2), -1.0)).normalized()
    start = hit - d * 40.0
    head = FX.blob((0, 0, 0), 1.0, FX.glow_mat("#fff8dc", 9.0), sub=2, name="star")
    head["no_outline"] = True
    tail = K.cone(r1=0.55 * size, r2=0.0, depth=12.0 * size, verts=12, mat=FX.glow_mat("#ffcf4a", 3.5),
                  name="star_tail")
    tail["no_outline"] = True
    tail.rotation_mode = "QUATERNION"
    q = (-d).to_track_quat("Z", "Y")
    for k in range(-dur, 1):
        p = start.lerp(hit, (k + dur) / float(dur))
        kf(head, f_hit + k, loc=p, scale=0.55 * size)
        kf(tail, f_hit + k, loc=p - d * 6.0 * size, quat=q)
    linear(head)
    linear(tail)
    visible(head, f_hit - dur, f_hit + 1)
    visible(tail, f_hit - dur, f_hit + 1)
    flash(hit, f_hit, 2.6 * size)
    FX.splash(hit, f_hit, size=1.2 * size, seed=seed + 100, crown=12, drops=14, rings=0, color=SPLASH)
    glow_spot(hit, f_hit, size=spot, f_off=f_off)
    for k in range(6):
        a = 2 * math.pi * k / 6
        B10.glint(hit + Vector((math.cos(a) * 1.5, -0.4, 0.8 + math.sin(a) * 1.0)), f_hit + 2 + k % 3, life=14,
                  size=0.4)


def shooting_star(f, seed):
    """a thin streak across the high sky"""
    rnd = random.Random(seed)
    a = Vector((rnd.uniform(-50, 10), rnd.uniform(140, 220), rnd.uniform(70, 130)))
    b = a + Vector((rnd.uniform(35, 70), rnd.uniform(-10, 10), -rnd.uniform(18, 34)))
    head = FX.blob((0, 0, 0), 1.0, FX.glow_mat("#ffffff", 6.0), sub=1, name="shoot")
    head["no_outline"] = True
    d = (b - a).normalized()
    tail = K.cone(r1=0.4, r2=0.0, depth=16.0, verts=8, mat=FX.glow_mat("#bcd4ff", 2.5), name="shoot_tail")
    tail["no_outline"] = True
    tail.rotation_mode = "QUATERNION"
    q = (-d).to_track_quat("Z", "Y")
    for k in range(0, 13):
        p = a.lerp(b, k / 12.0)
        kf(head, f + k, loc=p, scale=0.6 * (1 - (k / 12.0) ** 2))
        kf(tail, f + k, loc=p - d * 8.0, quat=q, scale=(1, 1, 1 - (k / 12.0) ** 2))
    linear(head)
    linear(tail)
    visible(head, f, f + 13)
    visible(tail, f, f + 13)


def hero_shiny(hang, f_burst, f_hang, f1, out_loc, scale=2.6, tilt=62.0, yaw=-160.0, roll=-42.0):
    """the hero shiny bursting up out of the sea at out_loc (nose up, its back turned to us), then hanging at
    hang in a golden glow"""
    hero = B10.shiny_fish(HERO, scale)
    hang, out_loc = Vector(hang), Vector(out_loc)
    for f in range(f_burst - 2, f1 + 3):
        if f < f_hang:
            u = max(0.0, (f - f_burst) / float(f_hang - f_burst))
            p = out_loc.lerp(hang, ease_out(u, 2)) + Vector((0, 0, 1.4 * math.sin(math.pi * u)))
            rot = Euler((math.radians(lerp(roll - 30, roll, u)), math.radians(lerp(-82, -tilt, u)),
                         math.radians(lerp(yaw + 20, yaw, u))))
        else:
            p = hang + Vector((0.12 * math.sin(f * 0.15), 0.0, 0.1 * math.sin(f * 0.2)))
            rot = Euler((math.radians(roll + 5 * math.sin(f * 0.3)), math.radians(-tilt + 4 * math.sin(f * 0.11)),
                         math.radians(yaw + 4 * math.sin(f * 0.07))))
        kf(hero, f, loc=p, rot=rot)
    linear(hero)
    visible(hero, f_burst - 2)
    FX.splash((out_loc.x, out_loc.y, 0), f_burst, size=2.4, seed=7, crown=18, drops=30, rings=0, color=SPLASH)
    flash((out_loc.x, out_loc.y, 0), f_burst, 4.5)
    glow_spot((out_loc.x, out_loc.y, 0), f_burst - 10, size=4.5, f_off=f1 + 2)
    B10.trail(hero, f_burst, f_hang, every=1, size=0.55, seed=3, spread=0.8)
    halo = K.cyl(r=1.0, depth=0.01, verts=48, mat=FX.radial_mat(GOLD, 0.9), smooth=False)
    halo.rotation_euler = (math.radians(90), 0, 0)
    halo["no_outline"] = True
    for f, s in [(f_hang - 4, 0.0), (f_hang + 2, scale * 1.9), (f_hang + 6, scale * 1.6), (f1 + 2, scale * 1.75)]:
        kf(halo, f, loc=hang + Vector((0, 1.4, 0)), scale=(s, s, 1))
    visible(halo, f_hang - 4)
    rnd = random.Random(12)
    for f in range(f_hang, f1, 2):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(1.6, 2.9) * scale / 2.4
        B10.glint(hang + Vector((math.cos(a) * r * 0.8, -0.6, math.sin(a) * r)), f, life=12, size=rnd.uniform(0.25, 0.5))
    return hero


# ==================================================================== shots
def shot_hook(f0, f1):
    """HOOK: a golden-glowing shiny bursts out of the night sea right at you and hangs there"""
    vscene()
    night_sea(f0, f1)
    cam = BV.camera(28)
    hero_shiny((0.0, 7.0, 3.6), T.HOOK_BURST, T.HOOK_HANG, f1, (0.6, 12.0, -0.6), scale=2.5)
    for k in range(3):
        shooting_star(f0 + 8 + k * 14, seed=k)

    def cam_fn(f):
        k = smooth((f - f0) / float(f1 - f0))
        return vlerp((0.0, -3.4, 1.3), (0.0, -2.6, 1.8), k), \
            vlerp((0.4, 12.0, 2.0), (0.0, 7.0, 3.6), min(1.0, k * 1.8)), 0.0, 28.0

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_starfall(f0, f1):
    """from up high: the night sea, the aurora, the fisher's lantern ... stars rain down, the sea glows gold
    wherever they go in"""
    vscene()
    night_sea(f0, f1)
    cam = BV.camera(26)
    BOAT = Vector((0.8, 12.5, 0.0))
    rb, pup, tips, tops = B10.rowboat_with_fisher(
        BOAT, 205, f0, f1, lambda f: dict(FI.sample(FI.ANIMS["idle"], (f / 5.0) % 8), head=(-24.0, 0.0, 0.0)),
        rod="Starfall Rod", heading=240.0)
    lantern(rb)
    hits = [(-3.0, 20.0), (4.5, 26.0), (-6.0, 30.0), (3.5, 16.0), (-2.5, 9.0), (7.0, 22.0), (-8.0, 24.0),
            (3.2, 8.5), (0.5, 30.0), (-4.5, 14.0), (5.5, 33.0), (-1.5, 19.0), (-2.0, 10.5)]
    rnd = random.Random(31)
    for i, (fh, (x, y)) in enumerate(zip(T.FALLS, hits)):        # far ones and near ones, all over the sea
        near = y < 12
        falling_star((x, y, 0.0), fh, dur=16, size=1.3 if near else 1.0, seed=40 + i, f_off=f1 + 2,
                     spot=rnd.uniform(2.6, 3.4) * (1.2 if near else 1.0))
    for k in range(5):
        shooting_star(f0 + 4 + k * 22, seed=10 + k)

    def cam_fn(f):
        k = smooth((f - f0) / float(f1 - f0))
        return vlerp((-1.2, -3.0, 7.0), (0.6, -1.4, 6.2), k), vlerp((0.0, 24.0, 0.8), (0.4, 24.0, 1.4), k), \
            lerp(-2.0, 2.0, k), 26.0

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_shinies(f0, f1):
    """low over the water: shiny fish leap out of the glowing spots, sparkling, one after another"""
    vscene()
    night_sea(f0, f1, stream=(0.6, -0.8))
    cam = BV.camera(24)
    big = [("Tropical Fish", (-1.8, 6.0)), ("Pufferfish", (1.6, 7.0)), ("Space Fish", (-0.8, 5.0)),
           ("Cod", (1.9, 5.6)), ("Galactic Crab", (-1.6, 7.8)), ("Shark", (0.4, 6.4))]
    small = ["Raw Salmon", "Dolphin", "Squid", "Turtle", "Alien Fish", "Raw Fish"]
    rnd = random.Random(5)
    for i, ((name, (x, y)), fl) in enumerate(zip(big, T.LEAPS)):  # close: they arc up into the aurora
        glow_spot((x, y, 0), fl - 16, size=2.0, f_off=f1 + 2)
        fo = B10.shiny_fish(name, 1.7 if name != "Shark" else 2.0)
        p0 = Vector((x, y, -0.4))
        p1 = Vector((x + (2.2 if x < 0 else -2.2), y - 0.8, -0.4))
        FX.leap(fo, fl, fl + 24, p0, p1, 4.6, wiggle=12.0, spin=1.0 if i == 2 else 0.0)
        FX.splash((p0.x, p0.y, 0), fl - 1, size=0.85, seed=60 + i, crown=12, drops=12, rings=0, foam=False, color=SPLASH)
        FX.splash((p1.x, p1.y, 0), fl + 23, size=0.6, seed=80 + i, crown=8, drops=8, rings=0, foam=False, color=SPLASH)
        B10.trail(fo, fl, fl + 24, every=1, size=0.4, seed=i, spread=0.5)
    for i, name in enumerate(small):                              # more of them further out, in between
        fl = T.LEAPS[i] + 9
        y = rnd.uniform(12, 17)
        x = rnd.uniform(-0.3, 0.3) * (y + 1.6)
        glow_spot((x, y, 0), fl - 12, size=2.2, f_off=f1 + 2)
        fo = B10.shiny_fish(name, 1.5)
        p0, p1 = Vector((x, y, -0.4)), Vector((x + rnd.choice((-3.0, 3.0)), y + 1.0, -0.4))
        FX.leap(fo, fl, fl + 22, p0, p1, 4.4, wiggle=12.0)
        FX.splash((p0.x, p0.y, 0), fl - 1, size=1.0, seed=120 + i, crown=10, drops=10, rings=0, color=SPLASH)
        B10.trail(fo, fl, fl + 22, every=2, size=0.4, seed=20 + i, spread=0.5)
    for k in range(4):
        shooting_star(f0 + 10 + k * 26, seed=20 + k)

    def cam_fn(f):
        k = smooth((f - f0) / float(f1 - f0))
        return vlerp((-0.6, -1.6, 1.1), (0.6, -1.0, 1.3), k), vlerp((0.0, 12.0, 3.4), (0.0, 12.0, 3.8), k), \
            lerp(-1.5, 1.5, k), 24.0

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_catch(f0, f1):
    """he casts the Starfall Rod into a glow (TAP) ... a bite, he reels ... a shiny bursts out and hangs"""
    vscene()
    night_sea(f0, f1)
    cam = BV.camera(26)
    BOAT = Vector((0.0, 10.0, 0.0))
    BOB = Vector((1.6, 17.0, 0.0))

    def pose(f):
        if f < T.TAP:
            return B10.anim_pose("cast", 0, loop=False)
        if f < T.REEL:
            return B10.anim_pose("cast", f - T.TAP, loop=False)
        if f < T.BURST + 4:
            return B10.anim_pose("reel", f, fps_scale=1.8)
        return B10.anim_pose("happy", f - T.BURST, loop=True)

    rb, pup, tips, tops = B10.rowboat_with_fisher(BOAT, 200, f0, f1, pose, rod="Starfall Rod", heading=75.0)
    lantern(rb)
    glow_spot((BOB.x, BOB.y, 0), f0 - 10, size=3.4, f_off=f1 + 2)
    bob = B10.bobber()
    line = BV.fishing_line()
    pq = None
    for f in range(T.TAP + 4, f1 + 3):
        if f < T.LANDS:
            u = (f - T.TAP - 4) / float(T.LANDS - T.TAP - 4)
            bp = tips[f].lerp(BOB, u) + Vector((0, 0, 5.0 * u * (1 - u)))
        elif f < T.BITE:
            bp = BOB + Vector((0, 0, 0.05 * math.sin(f * 0.25)))
        elif f < T.BURST:
            bp = BOB + Vector((0.08 * math.sin(f * 2.3), 0.08 * math.cos(f * 2.0), -0.22 + 0.1 * math.sin(f * 1.9)))
        else:
            bp = BOB + Vector((0, 0, 2.0 * ease_out(min(1.0, (f - T.BURST) / 6.0))))
        kf(bob, f, loc=bp)
        pq = BV.key_line(line, f, tips[f], bp + Vector((0, 0, 0.18)), pq)
    linear(bob)
    linear(line)
    visible(bob, T.TAP + 4, T.BURST + 6)
    visible(line, T.TAP + 4, T.BURST + 6)
    FX.splash(BOB, T.LANDS, size=0.6, seed=5, crown=8, drops=6, rings=0, color=SPLASH)
    for f in range(T.REEL, T.BURST, 8):
        FX.splash((BOB.x + 0.4 * math.sin(f), BOB.y, 0), f, size=0.7, seed=f, crown=8, drops=8, rings=0, foam=False,
                  color=SPLASH)
    ex, _ = BV.text_pop("!", (0, 0, 0), T.BITE, T.REEL + 6, size=1.4)
    ep = tops[T.BITE] + Vector((0.1, -0.2, 0.55))
    for k, s in [(0, 0.0), (3, 1.35), (5, 0.9), (7, 1.05), (9, 1.0)]:
        kf(ex, T.BITE + k, loc=ep, scale=s)
    visible(ex, T.BITE, T.REEL + 6)
    hang = BOAT.lerp(BOB, 0.45) + Vector((0, 0, 5.4))
    hero_shiny(hang, T.BURST, T.HANG, f1, BOB + Vector((0, 0, -0.6)), scale=2.3)

    def cam_fn(f):
        if f < T.BURST:
            k = smooth((f - f0) / float(T.BURST - f0))
            return BOAT + vlerp((-3.2, -5.2, 2.5), (-2.8, -4.4, 2.2), k), BOAT + vlerp((0.8, 3.5, 1.2), (1.0, 4.0, 1.3), k), \
                0.0, 26.0
        u = smooth((f - T.BURST) / float(f1 - T.BURST))
        return BOAT + vlerp((-2.8, -4.4, 2.2), (-1.6, -5.4, 2.6), u), \
            vlerp(BOAT + Vector((1.0, 4.0, 1.3)), hang - Vector((0, 0, 1.2)), u), 0.0, lerp(26.0, 24.0, u)

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_sky(f0, f1):
    """the aurora and the stars, looking up (behind the collection grid)"""
    vscene()
    night_sea(f0, f1, stream=(0.0, -0.5))
    cam = BV.camera(22)
    for k in range(4):
        shooting_star(f0 + 4 + k * 14, seed=30 + k)

    def cam_fn(f):
        k = smooth((f - f0) / float(f1 - f0))
        return Vector((lerp(-1.0, 1.0, k), -6.0, 2.0)), Vector((lerp(-6.0, 6.0, k), 200.0, 80.0)), lerp(-3.0, 3.0, k), 22.0

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_logo(f0, f1):
    """the 3D logo slams in under the stars (top third: the end card goes under it); shinies circle it"""
    vscene()
    K.setup_world("#3a3270", 1.0, sky=[(0, "#2a2266"), (0.5, "#120e3a"), (1, "#05041a")], stars=1.2)
    K.sun((52, 8, 24), 1.0)
    cam = BV.camera(34)
    FX.sunburst((0, 9, 0), 40, 22, "#0d0a2e", "#141040", f0 - 2, f1 + 2, spin=0.3)
    glow = K.cyl(r=1.0, depth=0.01, verts=64, mat=FX.radial_mat("#5b4bd0", 0.85), smooth=False)
    glow.rotation_euler = (math.radians(90), 0, 0)
    glow.location = (0, 8.9, 0)
    glow.scale = (11, 11, 1)
    glow["no_outline"] = True
    stand = FX.empty("stand")
    stand.rotation_euler = (math.radians(90), 0, 0)
    root, glyphs, fish = FX.build_logo()
    root.parent = stand
    stand.scale = (3.0, 3.0, 3.0)
    stand.location = (0, 0, 0)
    for i, (g, hit) in enumerate(zip(glyphs, T.LOGO_HITS)):
        rest = g.location.copy()
        FX.slam(g, hit, rest, rest_rot=tuple(g.rotation_euler), frm=(0.25 * (i % 3 - 1), 1.4, 1.7), seed=i, frm_scale=1.7)
        BV.burst(g, hit, seed=i, color="#fff3b0")
    rest = fish.location.copy()
    rr = fish.rotation_euler.copy()
    fl = T.LOGO_FISH
    for k in range(-9, 1):
        u = (k + 9) / 9.0
        p = rest + Vector((1.6 * (1 - u), -2.6 * (1 - u) + 2.2 * 4 * u * (1 - u), 0.6 * (1 - u)))
        kf(fish, fl + k, loc=p, rot=(0, 0, rr.z + math.radians(-200 * (1 - u))), scale=0.85 + 0.15 * u)
    for k, sx, sy in [(2, 1.2, 0.82), (4, 0.92, 1.1), (7, 1.0, 1.0)]:
        kf(fish, fl + k, loc=rest, rot=rr, scale=(sx, sy, 1.0))
    visible(fish, fl - 9)
    BV.burst(fish, fl, seed=40, n=12, color=GOLD)
    for i, name in enumerate([HERO, "Tropical Fish", "Pufferfish", "Rainbow Fish"]):
        fo = B10.shiny_fish(name, 1.0)                            # a ring round the logo, just behind it,
        for f in range(T.LOGO_FISH - 4, f1 + 3, 2):               # flanks to the camera, backs facing out
            a = (f - T.LOGO_FISH) * 0.045 + i * math.pi / 2
            vel = (-math.sin(a) * 4.1, 0.0, math.cos(a) * 2.35)
            out = (math.cos(a) * 2.35, 0.0, math.sin(a) * 4.1)
            s = FX.back_out(min(1.0, (f - T.LOGO_FISH + 4) / 8.0))
            kf(fo, f, loc=(math.cos(a) * 4.1, 0.7, -0.05 + math.sin(a) * 2.35), rot=FX.rot_from(vel, out), scale=s)
        visible(fo, T.LOGO_FISH - 4)
        linear(fo)
    rnd = random.Random(4)
    for f in range(f0, f1, 2):                                    # twinkles all over the sky
        B10.glint((rnd.uniform(-6, 6), 4.0, rnd.uniform(-11, 6)), f, life=16, size=rnd.uniform(0.15, 0.35))
    for f in range(T.LOGO_FISH, f1, 3):                           # ... and round the logo
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(3.0, 4.6)
        B10.glint((math.cos(a) * r, -1.0, -0.3 + math.sin(a) * r * 0.7), f, life=14, size=rnd.uniform(0.25, 0.45))

    def cam_fn(f):
        k = smooth((f - f0) / float(f1 - f0))
        return Vector((lerp(-0.3, 0.3, k), lerp(-15.6, -14.6, k), -0.6)), Vector((0, 0, -2.8)), lerp(-1.5, 1.5, k), 34.0

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


SHOT_FN = {"hook": shot_hook, "starfall": shot_starfall, "shinies": shot_shinies, "catch": shot_catch,
           "sky": shot_sky, "logo": shot_logo}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    stills, force, names = None, False, []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--pct":
            OPT["pct"] = int(argv[i + 1])
            i += 1
        elif a == "--samples":
            OPT["samples"] = int(argv[i + 1])
            i += 1
        elif a == "--still":
            stills = [int(x) for x in argv[i + 1].split(",")]
            i += 1
        elif a == "--force":
            force = True
        else:
            names.append(a)
        i += 1
    if "all" in names:
        names = list(T.SHOTS)
    for name in names:
        print("== starfall shot", name, flush=True)
        f0, f1 = T.SHOTS[name]
        B10._glint_mesh.clear()
        SHOT_FN[name](f0, f1)
        sts = [f for f in stills if f0 <= f < f1] if stills else None
        if stills and not sts:
            sts = [f0 + (f1 - f0) // 2]
        render(f0, f1, sts, name, force)
    print("done", flush=True)


def render(f0, f1, stills, tag, force):
    sc = bpy.context.scene
    if stills:
        os.makedirs(STILLS, exist_ok=True)
        for f in stills:
            sc.frame_set(f)
            sc.render.filepath = os.path.join(STILLS, "%s_%04d.png" % (tag, f))
            bpy.ops.render.render(write_still=True)
            print("STILL", sc.render.filepath, flush=True)
        return
    os.makedirs(FRAMES, exist_ok=True)
    sc.frame_start, sc.frame_end = f0, f1 - 1
    sc.render.filepath = FRAMES + os.sep
    sc.render.use_overwrite = force
    sc.render.use_placeholder = not force
    bpy.ops.render.render(animation=True)


if __name__ == "__main__":
    main()

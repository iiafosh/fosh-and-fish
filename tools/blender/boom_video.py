"""fosh&fish "KABOOM" marketing video: the 3D shots, rendered with Blender (Eevee) in the game's
cel-shaded art style, from the game's own procedural models (fish, boats, the fisher, the biomes).
Timing comes from tools/video/boom_timeline.py; tools/video/edit_boom.py cuts the frames together
with the soundtrack, captions and camera shake.

    blender -b --factory-startup --python tools/blender/boom_video.py -- SHOT [SHOT ...]
            [--pct 50] [--samples 16] [--still F,F,...] [--force]

SHOT: a shot from boom_timeline.SHOTS, "all", or an overlay (word_kaboom, word_boom, word_whoosh,
word_splash, "words"). Shots render to build/boom/frames/####.png (global frame numbers, so they
line up into one sequence), overlays to build/boom/overlays/NAME/####.png (transparent). --still
renders single frames to build/boom/stills/ for a quick look. Existing frames are kept (re-run to
resume) unless --force. Needs build/boom from tools/video/boom_prep.py (fonts, gameplay clips).
"""
import math
import os
import random
import sys

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "video"))

import vf_kit as K  # noqa: E402
import vf_models as M  # noqa: E402
import vf_boats as B  # noqa: E402
import vf_biomes as BI  # noqa: E402
import vf_fisher as FI  # noqa: E402
import boom_fx as FX  # noqa: E402
import boom_timeline as T  # noqa: E402
from boom_fx import back_out, ease_in, ease_out, kf, lerp, linear, smooth, visible, vlerp  # noqa: E402
from vf_kit import toon  # noqa: E402

WORK = FX.WORK
FRAMES = os.path.join(WORK, "frames")
OVERLAYS = os.path.join(WORK, "overlays")
STILLS = os.path.join(WORK, "stills")
CLIPS = os.path.join(WORK, "clips")
OPT = {"pct": 100, "samples": 16}


# ------------------------------------------------------------------- scene
def scene(transparent=False, blur=True, glow=True, samples=None):
    K.clear_scene()
    for coll in (bpy.data.actions, bpy.data.images, bpy.data.curves, bpy.data.materials, bpy.data.meshes):
        for item in list(coll):
            if item.users == 0:
                coll.remove(item)
    FX._mats.clear()
    _prevq.clear()
    K.FOG.update({"color": None, "amount": 0.0})
    w, h = T.W * OPT["pct"] // 100, T.H * OPT["pct"] // 100
    K.setup_render(w, h, samples=samples or OPT["samples"], transparent=transparent)
    sc = bpy.context.scene
    sc.render.image_settings.compression = 15          # (90 took 6 s per 1080p frame to save)
    sc.render.fps = T.FPS
    sc.render.use_motion_blur = blur
    sc.render.motion_blur_shutter = 0.45
    if glow and not transparent:
        nt_comp(sc)
    else:
        sc.use_nodes = False
    return sc


def nt_comp(sc):
    """soft bloom on anything brighter than white (fire, sparks, lava, glows)"""
    sc.use_nodes = True
    nt = sc.node_tree
    nt.nodes.clear()
    rl = nt.nodes.new("CompositorNodeRLayers")
    gl = nt.nodes.new("CompositorNodeGlare")
    gl.glare_type = "FOG_GLOW"
    gl.quality = "HIGH"
    gl.threshold = 1.02
    gl.size = 8
    gl.mix = 0.0
    comp = nt.nodes.new("CompositorNodeComposite")
    nt.links.new(rl.outputs["Image"], gl.inputs["Image"])
    nt.links.new(gl.outputs["Image"], comp.inputs["Image"])


_prevq = {}


def camera(lens=35.0, name="Cam"):
    cd = bpy.data.cameras.new(name)
    cd.lens = lens
    cd.clip_start = 0.05
    cd.clip_end = 6000.0
    cam = bpy.data.objects.new(name, cd)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.rotation_mode = "QUATERNION"
    return cam


def cam_key(cam, f, pos, look, roll=0.0, lens=None):
    pos = Vector(pos)
    q = (Vector(look) - pos).to_track_quat("-Z", "Y")
    if roll:
        q = q @ Quaternion((0, 0, 1), math.radians(roll))
    q = FX.keep_sign(q, _prevq.get(cam.name))
    _prevq[cam.name] = q
    kf(cam, f, loc=pos, quat=q)
    if lens is not None:
        cam.data.lens = lens
        cam.data.keyframe_insert("lens", frame=f)


def cam_path(cam, f0, f1, fn):
    """fn(f) -> (pos, look, roll, lens), keyed every frame (a little past both ends for motion blur)"""
    for f in range(f0 - 2, f1 + 3):
        pos, look, roll, lens = fn(f)
        cam_key(cam, f, pos, look, roll, lens)
    linear(cam)
    ad = cam.data.animation_data
    if ad and ad.action:
        for fc in ad.action.fcurves:
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"


def biome(name, f0, f1, stream=(0.0, -2.5)):
    """a vf_biomes diorama (sky, sun, fog, water, islands...) with the water streaks drifting"""
    cfg = BI.BIOMES[name]
    K.setup_world(cfg["ambient"], 1.0, sky=cfg["sky"], stars=cfg.get("stars", 0.0))
    K.sun(cfg["sun"], 1.0, cfg["sun_col"])
    K.FOG.update({"color": cfg["fog"], "start": 40.0, "end": 420.0, "amount": 0.82})
    random.seed(42)
    parts = BI.build(name, cfg)
    K.outline_all(parts, 0.12)
    K.FOG.update({"color": None, "amount": 0.0})
    water = parts[0]
    mat = water.data.materials[0]
    mp = next(n for n in mat.node_tree.nodes if n.type == "MAPPING")
    for f, k in ((f0 - 2, 0.0), (f1 + 2, 1.0)):
        mp.inputs["Location"].default_value = (stream[0] * k, stream[1] * k, 0.0)
        mp.inputs["Location"].keyframe_insert("default_value", frame=f)
    ad = mat.node_tree.animation_data
    for fc in ad.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    return cfg, parts


def leaper(name, f_out, p_out, p_in, height=4.0, dur=24, scale=1.4, spin=0.0, roll=0.0, splash=1.0, lava=False,
           seed=0, wiggle=14.0, color="#f2fcff"):
    root = FX.fish(name, scale)
    FX.leap(root, f_out, f_out + dur, Vector(p_out), Vector(p_in), height, wiggle=wiggle, spin=spin, roll=roll)
    if splash:
        FX.splash((p_out[0], p_out[1], 0), f_out - 1, size=splash * scale * 0.8, seed=seed, lava=lava, color=color)
        FX.splash((p_in[0], p_in[1], 0), f_out + dur - 1, size=splash * scale * 0.65, seed=seed + 1, lava=lava,
                  crown=10, drops=12, color=color)
    return root


def boat(name, line=0.05):
    parts, deck = B.build_boat(name)
    K.outline_all(parts, line)
    return K.parent_all(parts, "boat_" + name.replace(" ", "_")), Vector(deck)


def text_pop(body, loc, f_on, f_off, size=1.0, color="#ff3b30", line="#2a0f08", rot=(90, 0, 0), seed=0):
    """a little 3D sign ("!", "z") that pops in and out (faces -Y)"""
    root = FX.empty("sign_" + body, loc)
    tm = FX.text_mesh(body, FX.FONT_BOLD, size, extrude=0.08 * size, bevel=0.02 * size, align="CENTER", shear=0.4)
    FX.face_side_materials(tm, toon(color, shade=0.85, rim=0.0), toon(line, flat_glow=True), 0.55)
    tm["outline_even"] = False
    K.add_outline(tm, 0.05 * size, "#ffffff")
    tm.parent = root
    root.rotation_euler = Euler([math.radians(a) for a in rot])
    return root, tm


# ------------------------------------------------------------- the fisher
def pose_mix(a, b, k):
    ra, rb = FI.resolve(a), FI.resolve(b)
    return {key: FI._lerp(ra[key], rb[key], k) if key not in ("hr", "hl") else
            ("r", *FI._lerp(ra[key][1:], rb[key][1:], k)) for key in ra}


class Puppet:
    """vf_fisher.Fisher posed and keyed per frame, with a 3D rod (vf_models) between grip and tip"""

    def __init__(self, scale=1.3, rod="Plastic Rod"):
        self.f = FI.Fisher()
        self.f.outline()
        self.scale = scale
        for o in self.f.parts.values():
            o.rotation_mode = "QUATERNION"
        parts, base, tip = M.build_rod(M.ROD_SPECS[rod], strip=True)
        K.outline_all(parts, 0.02)
        self.rod = K.parent_all(parts, "rod")
        self.rod.rotation_mode = "QUATERNION"
        self.rod_axis = (tip - base).normalized()
        self.rod_len = (tip - base).length
        self.rod_grip = base + self.rod_axis * 0.2
        self.q = {}

    def key(self, f, root, P, hat=None):
        """root: Matrix (world placement of the cooler, +X = where his rod points); returns (grip, tip, head)"""
        self.f.root = root @ Matrix.Rotation(math.radians(FI.YAW), 4, "Z") @ Matrix.Scale(self.scale, 4)
        grip, tip, top = self.f.pose(P)
        if hat is not None:
            self.f.parts["hat"].matrix_world = hat
        for name, o in self.f.parts.items():
            q = FX.keep_sign(o.matrix_world.to_quaternion(), self.q.get(name))
            self.q[name] = q
            o.location = o.matrix_world.to_translation()
            o.rotation_quaternion = q
            o.scale = o.matrix_world.to_scale()
            o.keyframe_insert("location", frame=f)
            o.keyframe_insert("rotation_quaternion", frame=f)
            o.keyframe_insert("scale", frame=f)
        d = (tip - grip).normalized()
        L = (tip - grip).length * 1.25
        s = L / self.rod_len
        rq = self.rod_axis.rotation_difference(d)
        rq = FX.keep_sign(rq, self.q.get("_rod"))
        self.q["_rod"] = rq
        m = Matrix.Translation(grip) @ rq.to_matrix().to_4x4() @ Matrix.Scale(s, 4) @ Matrix.Translation(-self.rod_grip)
        self.rod.location = m.to_translation()
        self.rod.rotation_quaternion = rq
        self.rod.scale = (s, s, s)
        kf(self.rod, f, loc=self.rod.location, quat=rq, scale=s)
        return grip, grip + d * L, top

    def done(self):
        for o in list(self.f.parts.values()) + [self.rod]:
            linear(o)


def fishing_line(name="line"):
    ob = K.cyl(r=0.012, depth=1.0, verts=6, mat=toon("#f4f4f4", flat_glow=True), name=name)
    for v in ob.data.vertices:
        v.co.z += 0.5
    ob.data.update()
    ob["no_outline"] = True
    ob.rotation_mode = "QUATERNION"
    return ob


def key_line(ob, f, a, b, prev):
    a, b = Vector(a), Vector(b)
    d = b - a
    q = FX.keep_sign(d.normalized().to_track_quat("Z", "Y"), prev)
    kf(ob, f, loc=a, quat=q, scale=(1, 1, max(0.001, d.length)))
    return q


# ==================================================================== shots
def shot_open(f0, f1):
    """the cozy river: the fisher dozes in his rowboat... the bobber dips, "!"... KABOOM: a giant fiery
    pufferfish blows the river up, launches him back, puffs up and rushes the camera"""
    scene()
    biome("River", f0, f1, stream=(0.0, -1.5))
    cam = camera(32)
    BOB = Vector((-0.45, 10.4, 0.0))
    BOAT = Vector((1.9, 16.6, 0.0))
    KB = T.KABOOM

    # the rowboat, bobbing; knocked back and rocking after the blast
    rb, deck = boat("Rowboat")
    byaw = math.radians(205)

    def boat_m(f):
        t = f - KB
        push = Vector((0, 0, 0))
        roll = 1.8 * math.sin(f * 0.13)
        pitch = 1.2 * math.sin(f * 0.09 + 1.0)
        z = 0.05 * math.sin(f * 0.11)
        if t >= 0:
            e = ease_out(t / 16.0)
            push = Vector((1.6, 2.2, 0)) * e
            roll += -26 * math.exp(-t / 14.0) * math.cos(t * 0.33)
            pitch += 9 * math.exp(-t / 12.0) * math.sin(t * 0.4)
            z += 0.5 * math.exp(-t / 6.0) * math.sin(t * 0.5)
        return (Matrix.Translation(BOAT + push + Vector((0, 0, z))) @ Matrix.Rotation(byaw, 4, "Z") @
                Euler((math.radians(roll), math.radians(pitch), 0)).to_matrix().to_4x4())

    rb.rotation_mode = "QUATERNION"
    bq = None
    for f in range(f0 - 2, f1 + 3):
        m = boat_m(f)
        bq = FX.keep_sign(m.to_quaternion(), bq)
        kf(rb, f, loc=m.to_translation(), quat=bq)
    linear(rb)

    pup = Puppet(scale=1.25)
    tops = {}
    line = fishing_line()
    bob_root = FX.empty("bobber")
    bob = K.sphere(scale=1.0, seg=24, rings=12, name="bob")
    K.vcolor(bob, lambda co, n: K.hexc("#ec3b2e") if co.z > 0.1 else K.hexc("#ffffff"), per_face=True)
    bob.data.materials.append(toon(None, vcol="col", key=("bobber",)))
    bob.scale = (0.2, 0.2, 0.2)
    K.add_outline(bob, 0.1)
    pin = K.cyl(loc=(0, 0, 0.27), r=0.025, depth=0.16, mat=toon("#ec3b2e"), verts=8)
    K.add_outline(pin, 0.012)
    for o in (bob, pin):
        o.parent = bob_root
    heading = math.radians(250) - byaw              # his rod points at the bobber (boat-relative)
    pq = None
    for f in range(f0 - 2, KB + 1):
        bm = boat_m(f)
        root = bm @ Matrix.Translation(deck) @ Matrix.Rotation(heading, 4, "Z")
        if f < 96:
            P = dict(FI.sample(FI.ANIMS["idle"], (f / 5.0) % 8), eyes=1.0, head=(10.0, 0.0, 0.0))
        elif f < 101:
            P = pose_mix(dict(FI.SIT, eyes=1.0), FI.S(lean=13.0, head=(4.0, 0.0, 0.0), brows=1.0, eyes=0.0,
                                                      mouth=0.4, rod=(0.0, 20.0)), smooth((f - 96) / 4.0))
        else:
            jit = 2.0 * math.sin(f * 2.1)
            P = FI.resolve(FI.S(lean=13.0 + jit, head=(4.0, 0.0, 0.0), brows=1.0, eyes=0.0, mouth=0.5,
                                rod=(0.0, 14.0 - (f - 101) * 0.6)))
        grip, tip, top = pup.key(f, root, P)
        tops[f] = top.copy()
        # the bobber
        z = 0.04 * math.sin(f * 0.21)
        off = Vector((0, 0, 0))
        if 96 <= f < 100:
            z = -0.1 * math.sin((f - 96) / 4 * math.pi)
        elif 100 <= f < 112:
            z = -0.22 + 0.1 * math.sin(f * 1.9)
            off = Vector((0.05 * math.sin(f * 2.7), 0.05 * math.cos(f * 2.3), 0))
        elif f >= 112:
            z = -0.22 - (f - 112) * 0.09
        bp = BOB + off + Vector((0, 0, z))
        kf(bob_root, f, loc=bp)
        pq = key_line(line, f, tip, bp + Vector((0, 0, 0.18)), pq)
    visible(bob_root, -1000, KB)
    linear(bob_root)
    # dozing "z"s, then "!"
    for i, fz in enumerate((6, 30, 54, 78)):
        sg, _ = text_pop("z", (0, 0, 0), fz, fz + 30, size=1.1 + 0.25 * (i % 3), color="#ffffff", line="#2f86b5")
        start = tops[fz] + Vector((0.25, -0.2, 0.25))
        for k in range(0, 31, 2):
            t = k / 30.0
            kf(sg, fz + k, loc=start + Vector((0.5 * math.sin(t * 3 + i) + 0.4 * t, 0, 1.5 * t)),
               scale=back_out(k / 6.0) * (1 - ease_in(t, 3)))
        visible(sg, fz, fz + 31)
    ex, _ = text_pop("!", (0, 0, 0), T.BITE, KB, size=1.5)
    ep = tops[T.BITE] + Vector((0.1, -0.2, 0.55))
    for k, s in [(0, 0.0), (3, 1.35), (5, 0.9), (7, 1.05), (9, 1.0)]:
        kf(ex, T.BITE + k, loc=ep, scale=s)
    for f in range(T.BITE + 10, KB, 2):
        kf(ex, f, loc=ep + Vector((0, 0, 0.06 * math.sin(f * 1.3))), scale=1.0 + 0.05 * math.sin(f * 2.0))
    visible(ex, T.BITE, KB)
    # gentle ripples, then the bite
    for fr in (6, 40, 74):
        FX.ripple(BOB, fr, 1.1)
    for fr in (96, 100, 104, 108, 112, 116):
        FX.ripple(BOB, fr, 1.5)
    # the water bulges just before
    dome = FX.blob((BOB.x, BOB.y, 0), 1.0, toon("#9fdcef", shade=0.85, rim=0.0), sub=3, name="dome")
    FX.outline(dome, 0.03, FX.WATER_LINE)
    for f, s, h in [(110, 0.4, 0.0), (114, 1.4, 0.25), (117, 1.9, 0.45), (119, 2.3, 0.7), (120, 0.0, 0.0)]:
        kf(dome, f, scale=(s, s, h))
    visible(dome, 110, KB + 1)

    # KABOOM: a fiery core inside a towering white water blast
    FX.explosion((BOB.x, BOB.y, 1.0), KB, size=2.4, seed=3, puffs=20, life=40, debris=0, sparks=18, steam=0.45,
                 palette=FX.FIRE[:5])
    FX.splash((BOB.x, BOB.y, 0), KB, size=3.4, seed=4, crown=20, drops=44, column=9.0, rings=3)
    FX.splash((BOB.x + 2.5, BOB.y + 1.0, 0), KB + 3, size=1.6, seed=5, crown=10, drops=14, rings=1)
    FX.splash((BOB.x - 2.6, BOB.y + 0.6, 0), KB + 4, size=1.4, seed=6, crown=10, drops=12, rings=1)
    # the giant fiery pufferfish
    puf = FX.fish("Fiery Pufferfish", 3.0)
    puf.rotation_mode = "XYZ"
    camp = {}

    def cam_fn(f):
        if f < 110:
            k = smooth(f / 110.0)
            return (vlerp((-1.5, 0.0, 2.9), (-0.9, 2.6, 2.4), k), vlerp((0.8, 13.8, 1.5), (0.4, 12.8, 1.2), k),
                    0.0, 40.0 + 2.0 * k)
        if f < KB:
            k = smooth((f - 110) / 10.0)
            return (vlerp((-0.9, 2.6, 2.4), (-0.8, 3.2, 2.3), k), vlerp((0.4, 12.8, 1.2), (-0.1, 10.8, 0.7), k),
                    0.0, 42.0 + 8.0 * k)
        t = f - KB
        k = ease_out(t / 10.0)
        pos = vlerp((-0.8, 3.2, 2.3), (0.0, -4.5, 3.0), k)
        look_z = lerp(0.9, 5.4, ease_out(t / 14.0))
        if f >= 154:
            look_z = lerp(5.4, 4.3, smooth((f - 154) / 20.0))
        return pos, Vector((-0.2, 10.6 - 1.0 * k, look_z)), 0.0, lerp(50.0, 30.0, k)

    for f in range(f0 - 2, f1 + 3):
        camp[f] = cam_fn(f)
    cam_path(cam, f0, f1, cam_fn)
    puf_at = {}
    for f in range(KB - 6, f1 + 3):
        t = f - KB
        if t < 0:
            pos = Vector((BOB.x, BOB.y, -3.5))
            s, yaw = 3.0, 0.0
        elif t <= 12:
            k = ease_out(t / 12.0, 2)
            pos = Vector((BOB.x, BOB.y - 0.8 * k, lerp(-1.5, 7.0, k)))
            s, yaw = 3.0, math.radians(-60 + 25 * k)
        elif f < 154:
            u = (f - KB - 12) / (154 - KB - 12)
            pos = Vector((BOB.x + 0.3 * math.sin(u * 3), BOB.y - 0.8 - 0.6 * u, 7.0 + 0.6 * smooth(u)))
            yaw = math.radians(-35 + 30 * u)
            p1 = back_out((f - 138) / 5.0) if f >= 138 else 0.0
            p2 = back_out((f - 146) / 5.0) if f >= 146 else 0.0
            s = 3.0 * (1 + 0.22 * p1 + 0.25 * p2)
        else:
            u = ease_in((f - 154) / 26.0, 2)
            cpos, look = Vector(camp[min(f, f1 + 2)][0]), Vector(camp[min(f, f1 + 2)][1])
            fwd = (look - cpos).normalized()
            start = Vector((BOB.x + 0.3 * math.sin(3), BOB.y - 1.4, 7.6))
            pos = start.lerp(cpos + fwd * 2.2, u)
            s = 3.0 * 1.47 * (1 + 0.15 * u)
            yaw = math.radians(-5 - 70 * u)
        wob = math.radians(8) * math.sin(f * 0.9)
        kf(puf, f, loc=pos, rot=Euler((wob, math.radians(-12), yaw - math.radians(90)), "XYZ"), scale=s)
        puf_at[f] = pos.copy()
    linear(puf)
    visible(puf, KB - 1)

    # after the blast: him (arms up, hat flying), the line pulled to the fish
    hat_v = Vector((1.2, 2.6, 9.5))
    hat_p0 = None
    hq = None
    for f in range(KB + 1, f1 + 3):
        t = f - KB
        bm = boat_m(f)
        root = bm @ Matrix.Translation(deck) @ Matrix.Rotation(heading, 4, "Z")
        k = smooth(t / 5.0)
        P = pose_mix(FI.S(lean=13.0, brows=1.0, mouth=0.5, rod=(0.0, 14.0)),
                     FI.S(lean=-24.0, head=(-18.0, 0.0, 0.0), hr=("t", 0.15, -0.36, 0.78), hl=("t", 0.12, 0.38, 0.8),
                          brows=1.0, eyes=0.0, mouth=1.0, rod=(0.0, 62.0)), k)
        if hat_p0 is None:
            pup.f.root = root @ Matrix.Rotation(math.radians(FI.YAW), 4, "Z") @ Matrix.Scale(pup.scale, 4)
            pup.f.pose(P)
            hat_p0 = pup.f.parts["hat"].matrix_world.copy()
        tt = t / T.FPS
        hp = hat_p0.to_translation() + hat_v * tt + Vector((0, 0, -0.5 * FX.G * 0.55 * tt * tt))
        hat_m = (Matrix.Translation(hp) @ Euler((tt * 9.0, tt * 4.0, tt * 6.0)).to_matrix().to_4x4() @
                 hat_p0.to_3x3().to_4x4())
        hat_m = hat_m @ Matrix.Scale(1.0, 4)
        grip, tip, top = pup.key(f, root, P, hat=hat_m if hp.z > -0.3 else Matrix.Translation((0, 0, -20)))
        hq = key_line(line, f, tip, puf_at.get(f, BOB), hq)
    linear(line)
    visible(line, -1000, 160)
    pup.done()
    # the hat lands
    FX.splash((BOAT.x + 3.0, BOAT.y + 4.2, 0), KB + 38, size=0.5, seed=9, crown=8, drops=6, rings=1)
    return cam


def shot_logo(f0, f1):
    """the 3D logo slams in letter by letter over a turning sunburst; the little fish leaps on last"""
    scene()
    K.setup_world("#2a6f78", 1.0, sky=[(0, "#0e3a44"), (1, "#0b2930")])
    K.sun((52, 8, 24), 1.0)
    cam = camera(40)
    FX.sunburst((0, 9, 0), 40, 22, "#0f3e48", "#13505c", f0 - 2, f1 + 2, spin=0.35, center="#2a8f96")
    stand = FX.empty("stand")
    stand.rotation_euler = (math.radians(90), 0, 0)
    root, glyphs, fish = FX.build_logo()
    root.parent = stand
    stand.scale = (2.25, 2.25, 2.25)
    stand.location = (0, 0, 0.35)
    for i, (g, hit) in enumerate(zip(glyphs, T.LOGO_HITS)):
        rest = g.location.copy()
        FX.slam(g, hit, rest, rest_rot=tuple(g.rotation_euler), frm=(0.25 * (i % 3 - 1), 1.4, 1.7), seed=i,
                frm_scale=1.7)
        burst(g, hit, seed=i)
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
    burst(fish, fl, seed=40, n=12, color="#5fe0bd")
    bubbles(f0, f1, area=(-14, 14, -8, 8), y=6.0, n=26, seed=2)

    def cam_fn(f):
        k = smooth((f - f0) / (f1 - f0))
        return Vector((lerp(-0.6, 0.4, k), lerp(-15.8, -13.2, k), lerp(0.2, 0.55, k))), Vector((0, 0, 0.35)), \
            lerp(-2.5, 1.5, k), 40.0

    cam_path(cam, f0, f1, cam_fn)
    return cam


def burst(target, f, seed=0, n=10, color="#ffffff"):
    """droplets flung out around a letter as it lands (in the picture plane)"""
    rnd = random.Random(seed)
    bpy.context.view_layer.update()
    c = target.matrix_world.to_translation()
    mat = toon(color, shade=0.85, rim=0.0)
    for i in range(n):
        a = 2 * math.pi * i / n + rnd.uniform(-0.3, 0.3)
        d = Vector((math.cos(a), -0.3, math.sin(a)))
        ob = FX.blob(c, 1.0, mat, sub=1, name="burst")
        FX.outline(ob, 0.2, "#2f86b5")
        r = rnd.uniform(0.07, 0.13)
        sp = rnd.uniform(4.0, 7.0)
        for k in range(0, 13):
            t = k / T.FPS
            p = c + d * (sp * t * (1 - k / 26.0)) + Vector((0, 0, -4.0 * t * t))
            kf(ob, f + k, loc=p, scale=r * (1 - (k / 12.0) ** 2))
        visible(ob, f, f + 13)
        linear(ob)


def bubbles(f0, f1, area=(-10, 10, -6, 6), y=5.0, n=20, seed=0, color="#bff3ff"):
    """rising bubbles (rings with a highlight) for the graphic shots"""
    rnd = random.Random(seed)
    mat = toon(color, flat_glow=True)
    for i in range(n):
        b = FX.annulus(0.78, 1.0, seg=24, mat=mat, name="bubble")
        b.rotation_euler = (math.radians(90), 0, 0)
        x0 = rnd.uniform(area[0], area[1])
        z0 = rnd.uniform(area[2] - 4, area[3])
        r = rnd.uniform(0.08, 0.22)
        sp = rnd.uniform(0.05, 0.11)
        yy = y + rnd.uniform(-2, 2)
        for f in range(f0 - 2, f1 + 3, 3):
            z = z0 + (f - f0) * sp
            kf(b, f, loc=(x0 + 0.3 * math.sin(f * 0.07 + i), yy, z), scale=(r, r, 1))
        linear(b)


def shot_river(f0, f1):
    scene()
    biome("River", f0, f1, stream=(0.0, -2.0))
    cam = camera(30)
    L = T.LEAPS["river"]
    leaper("Raw Salmon", L[0], (-6.5, 15.0, -0.4), (-1.5, 12.0, -0.4), height=4.6, dur=22, scale=1.5, seed=10, spin=0.0)
    leaper("Cod", L[1], (5.5, 17.0, -0.4), (0.8, 13.5, -0.4), height=4.2, dur=22, scale=1.5, seed=12)
    leaper("Tropical Fish", L[2], (-3.0, 11.0, -0.4), (2.6, 9.6, -0.4), height=3.6, dur=20, scale=1.5, seed=14,
           roll=0, spin=1.0)
    pf = leaper("Pufferfish", L[3], (3.4, 10.5, -0.4), (-1.0, 9.0, -0.4), height=3.8, dur=24, scale=1.4, seed=16)
    for k, s in [(8, 1.4), (11, 2.1), (14, 1.85), (24, 1.85)]:
        kf(pf, L[3] + k, scale=s)
    fb, _ = boat("Fishing Boat")
    for f, x in ((f0 - 2, -26.0), (f1 + 2, -16.0)):
        kf(fb, f, loc=(x, 46, 0.05 * math.sin(f)), rot=(0, 0, 0))
    linear(fb)

    def cam_fn(f):
        k = smooth((f - f0) / (f1 - f0))
        return vlerp((-0.6, -4.0, 2.3), (0.5, -1.6, 1.9), k), vlerp((0, 20, 2.4), (0, 20, 2.0), k), 0.0, 30.0

    cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_volcanic(f0, f1):
    scene()
    biome("Volcanic", f0, f1, stream=(0.0, -1.0))
    cam = camera(28)
    E = T.ERUPTION
    crater = Vector((10, 300, 57))
    FX.explosion(crater, E, size=22.0, seed=21, puffs=26, life=56, debris=0, sparks=0, ring=True, ring_axis="Y",
                 rise=1.2)
    rnd = random.Random(5)
    lmat = toon("#ffb21f", flat_glow=True)
    for i in range(22):
        ob = FX.blob(crater, 1.0, lmat, sub=1, name="bomb")
        FX.outline(ob, 0.15, "#5a1a10")
        tgt = Vector((rnd.uniform(-40, 50), rnd.uniform(40, 240), 0))
        if i < 5:
            tgt = Vector((rnd.uniform(-9, 9), rnd.uniform(16, 30), 0))
        dur = rnd.randint(28, 50) if i >= 5 else rnd.randint(34, 44)
        hgt = rnd.uniform(40, 90)
        r = rnd.uniform(1.5, 3.5) if i >= 5 else rnd.uniform(0.5, 0.9)
        for k in range(0, dur + 1, 2):
            u = k / dur
            p = crater.lerp(tgt, u) + Vector((0, 0, 4 * hgt * u * (1 - u)))
            kf(ob, E + 2 + k, loc=p, scale=r)
        visible(ob, E + 2, E + 3 + dur)
        linear(ob)
        if i < 5:
            FX.splash(tgt, E + 2 + dur, size=0.9, seed=60 + i, lava=True, crown=10, drops=10, rings=1)
    L = T.LEAPS["volcanic"]
    leaper("Fiery Pufferfish", L[0], (-5.5, 13.0, -0.4), (-0.5, 10.0, -0.4), height=4.8, dur=24, scale=1.5, seed=30,
           lava=True)
    leaper("Hot Cod", L[1], (5.8, 15.0, -0.4), (0.5, 11.5, -0.4), height=5.0, dur=22, scale=1.5, seed=32, lava=True,
           spin=1.0)
    leaper("Fiery Pufferfish", L[2], (2.2, 9.5, -0.4), (-3.0, 8.0, -0.4), height=3.6, dur=20, scale=1.3, seed=34,
           lava=True)

    def cam_fn(f):
        k = smooth((f - f0) / (f1 - f0))
        return vlerp((-1.0, -4.6, 2.5), (0.4, -1.8, 2.1), k), vlerp((3, 60, 9), (2, 40, 6), k), 0.0, 28.0

    cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_ocean(f0, f1):
    scene()
    biome("Ocean", f0, f1, stream=(1.5, -1.5))
    cam = camera(30)
    L = T.LEAPS["ocean"]
    leaper("Dolphin", L[0], (-10.0, 19.0, -0.5), (4.0, 14.0, -0.5), height=6.5, dur=28, scale=1.7, seed=40,
           wiggle=5.0)
    leaper("Turtle", L[1], (6.0, 12.0, -0.4), (1.0, 10.0, -0.4), height=3.6, dur=20, scale=1.3, seed=42, spin=1.0)
    leaper("Squid", L[2], (-3.5, 10.0, -0.4), (-1.0, 8.6, -0.4), height=4.6, dur=22, scale=1.3, seed=44, wiggle=6.0)
    y, _ = boat("Yacht")
    for f in range(f0 - 2, f1 + 3, 2):
        u = (f - f0) / (f1 - f0)
        kf(y, f, loc=(lerp(30, -12, u), 34, 0.08 * math.sin(f * 0.3)), rot=(math.radians(2 * math.sin(f * 0.2)), 0,
                                                                           math.radians(180)))
        if f % 6 == 0:
            FX.splash((lerp(30, -12, u) - 3.2, 33.0, 0), f, size=0.8, seed=f, crown=8, drops=6, rings=0, foam=False)
    linear(y)

    def cam_fn(f):
        k = smooth((f - f0) / (f1 - f0))
        return vlerp((-1.8, -3.8, 1.6), (1.2, -2.2, 1.9), k), vlerp((0, 24, 2.8), (0, 24, 3.2), k), 0.0, 30.0

    cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_sky(f0, f1):
    scene()
    biome("Sky", f0, f1, stream=(0.0, -1.0))
    cam = camera(30)
    sc_, _ = boat("Sky Cruiser")
    P = T.SKY_PASS
    for f in range(f0 - 2, f1 + 3):
        u = (f - f0) / float(f1 - f0)                  # right to left across the whole bar, closest mid-shot
        pos = Vector((lerp(24, -26, u), 14.0 - 4.0 * math.sin(math.pi * u), 5.2 + 0.8 * math.sin(f * 0.12)))
        kf(sc_, f, loc=pos, rot=(math.radians(-8 * math.sin(f * 0.1) - 6), math.radians(3), math.radians(192)))
    linear(sc_)
    L = T.LEAPS["sky"]
    leaper("Rainbow Fish", L[0], (-5.0, 13.0, -0.4), (0.0, 10.0, -0.4), height=5.0, dur=24, scale=1.5, seed=50,
           color="#ffffff")
    leaper("Guardian", L[1], (5.0, 15.0, -0.4), (0.5, 11.0, -0.4), height=4.4, dur=22, scale=1.4, seed=52,
           color="#ffffff")
    leaper("Emerald Squid", L[2], (-1.5, 9.5, -0.4), (2.5, 8.5, -0.4), height=3.8, dur=20, scale=1.3, seed=54,
           color="#ffffff", spin=1.0)

    def cam_fn(f):
        k = smooth((f - f0) / (f1 - f0))
        return vlerp((0.5, -4.5, 3.2), (-0.4, -2.0, 3.8), k), vlerp((0, 30, 5.0), (0, 30, 4.2), k), 0.0, 30.0

    cam_path(cam, f0, f1, cam_fn)
    return cam


def clamp(t):
    return 0.0 if t < 0 else 1.0 if t > 1 else t


def shot_space(f0, f1):
    scene()
    biome("Space", f0, f1, stream=(0.0, -1.0))
    cam = camera(28)
    sh, _ = boat("Space Shuttle")
    S0 = T.SHUTTLE
    for f in range(f0 - 2, f1 + 3):
        u = (f - S0) / 36.0
        e = ease_in(clamp(u), 2)
        pos = Vector((lerp(-16, 30, e), lerp(16, 60, e), lerp(1.2, 30, e)))
        kf(sh, f, loc=pos, rot=(0, math.radians(-lerp(8, 34, e)), math.radians(lerp(30, 40, e))))
        if S0 <= f < S0 + 30 and f % 2 == 0:
            back = pos - Vector((math.cos(math.radians(35)), math.sin(math.radians(35)), math.tan(math.radians(20)))) * 3.2
            FX.explosion(back, f, size=0.9, seed=f, puffs=4, life=14, ring=False, debris=0, sparks=2, flash=False,
                         rise=0.0)
    linear(sh)
    L = T.LEAPS["space"]
    for name, p0, p1, h, sp, sd in [("Space Fish", (-6, 14, -0.4), (-1, 11, -0.4), 5.5, 1.0, 70),
                                    ("Galactic Crab", (5, 13, -0.4), (1, 10, -0.4), 4.5, 1.5, 72),
                                    ("Space Fish", (1, 9, -0.4), (-3, 8, -0.4), 4.0, 0.5, 74)]:
        i = [70, 72, 74].index(sd)
        leaper(name, L[i], p0, p1, height=h, dur=26, scale=1.4, seed=sd, spin=sp, color="#d8c8ff")

    def cam_fn(f):
        k = smooth((f - f0) / (f1 - f0))
        return vlerp((0.0, -5.5, 2.5), (0.6, -2.5, 2.9), k), vlerp((0, 40, 8.0), (2, 40, 10.0), k), 0.0, 28.0

    cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_alien(f0, f1):
    scene()
    biome("Alien", f0, f1, stream=(0.0, -1.0))
    cam = camera(30)
    L = T.LEAPS["alien"]
    leaper("Alien Fish", L[0], (-4.0, 11.0, -0.4), (0.5, 9.0, -0.4), height=4.0, dur=20, scale=1.4, seed=80,
           color="#c8ffe6")
    leaper("Shark", L[1], (5.0, 14.0, -0.6), (-1.0, 11.0, -0.6), height=4.5, dur=22, scale=1.8, seed=82,
           color="#c8ffe6", wiggle=6.0)
    ufo, _ = boat("Alien Raft")
    for f in range(f0 - 2, f1 + 3):
        kf(ufo, f, loc=(lerp(-14, -6, (f - f0) / 30.0), 30, 3.0 + 0.4 * math.sin(f * 0.2)), rot=(0, 0, math.radians(f * 4)))
    linear(ufo)

    def cam_fn(f):
        k = smooth((f - f0) / (f1 - f0))
        return vlerp((0.0, -3.6, 2.1), (0.8, -2.0, 1.9), k), Vector((0, 24, 3.0)), lerp(0, 3, k), 30.0

    cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_abyss(f0, f1):
    scene()
    biome("Abyss", f0, f1, stream=(0.0, -0.6))
    cam = camera(30)
    L = T.LEAPS["abyss"]
    leaper("Dark Tuna", L[0], (4.0, 13.0, -0.6), (-1.5, 9.0, -0.6), height=4.4, dur=22, scale=1.7, seed=90,
           color="#bfefff", wiggle=6.0)
    leaper("Dark Puffer", L[1], (-4.0, 10.0, -0.4), (0.5, 8.4, -0.4), height=3.4, dur=18, scale=1.4, seed=92,
           color="#bfefff")

    def cam_fn(f):
        k = smooth((f - f0) / (f1 - f0))
        return vlerp((0.0, -3.2, 2.3), (-0.6, -1.6, 2.1), k), Vector((0, 24, 3.4)), lerp(0, -3, k), 30.0

    cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_screens(f0, f1):
    """the real game on floating screens, one per bar: Reel it in!, the boat parade, FishTok, online"""
    scene()
    K.setup_world("#2a6f78", 1.0, sky=[(0, "#0f4450"), (1, "#0b2930")])
    K.sun((52, 8, 24), 1.0)
    cam = camera(38)
    FX.sunburst((0, 12, 0), 48, 26, "#0e3a44", "#114955", f0 - 2, f1 + 2, spin=0.25, center="#1d7480")
    bubbles(f0, f1, area=(-18, 18, -10, 10), y=8.0, n=40, seed=5)
    swimmers(f0, f1)
    S = T.SCREENS
    scr = []

    def slam_in(ob, f_in, f_out, frm, rest=(0, 0, 0), rest_rot=(0, 0, 0), exit_to=(-40, 6, 0), spin=35.0, s=1.0):
        frm, rest, exit_to = Vector(frm), Vector(rest), Vector(exit_to)
        rr = Vector([math.radians(a) for a in rest_rot])
        for k in range(-6, 1):
            u = ease_in((k + 6) / 6.0, 2)
            kf(ob, f_in + k, loc=frm.lerp(rest, u), rot=Euler(rr + Vector((0, 0, math.radians(spin * (1 - u))))),
               scale=s * lerp(0.6, 1.0, u))
        for k, sc in [(2, 1.06), (4, 0.98), (7, 1.0)]:
            kf(ob, f_in + k, loc=rest, rot=Euler(rr), scale=s * sc)
        for f in range(f_in + 9, f_out - 5, 3):
            kf(ob, f, loc=rest + Vector((0, 0, 0.12 * math.sin(f * 0.12))), rot=Euler(rr + Vector((math.radians(1.2 * math.sin(f * 0.09)), 0, math.radians(1.5 * math.sin(f * 0.07))))),
               scale=s)
        for k in range(-5, 1):
            u = ease_in((k + 5) / 5.0, 2)
            kf(ob, f_out + k, loc=rest.lerp(exit_to, u), rot=Euler(rr + Vector((0, 0, math.radians(-spin * u)))),
               scale=s)
        visible(ob, f_in - 6, f_out + 1)
        linear(ob)

    reel = FX.screen(os.path.join(CLIPS, "reel"), 60, S[0], 16.0, 9.0, name="reel")
    slam_in(reel, S[0], S[1], (34, 4, 2), rest=(0, 0, 0.6), s=0.88)
    boats = FX.screen(os.path.join(CLIPS, "boats"), 60, S[1], 16.0, 9.0, name="boats")
    slam_in(boats, S[1], S[2], (0, 4, 22), rest=(0, 0, 0.6), exit_to=(0, 4, -26), spin=-25, s=0.88)
    for k in (15, 30, 45):
        f = S[1] + k
        kf(boats, f, scale=1.045)
        kf(boats, f + 3, scale=1.0)
    ph = FX.phone(os.path.join(CLIPS, "fishtok"), 60, S[2], name="fishtok")
    slam_in(ph, S[2], S[3], (2, 2, -24), rest=(0, 0, 0.7), rest_rot=(0, 0, 0), exit_to=(40, 4, 0), spin=-40, s=0.95)
    board = FX.screen(os.path.join(CLIPS, "board"), 60, S[3], 16.0, 9.0, name="board")
    slam_in(board, S[3], f1 + 8, (-36, 6, 3), rest=(-1.4, 1.0, 0.9), s=0.86)
    hero = FX.phone(os.path.join(CLIPS, "hero"), 45, S[3] + 15, w=8.6, h=4.0, name="phone_land")
    slam_in(hero, S[3] + 15, f1 + 8, (30, -6, -14), rest=(5.4, -3.0, -2.6), rest_rot=(0, 0, -8), spin=40, s=0.82)

    def cam_fn(f):
        k = smooth((f - f0) / (f1 - f0))
        return Vector((lerp(-0.4, 0.4, k), -21.0 + 0.6 * math.sin(f * 0.02), 0.6)), Vector((0, 0, 0.5)), 0.0, 38.0

    cam_path(cam, f0, f1, cam_fn)
    return cam


def swimmers(f0, f1, n=7, y=7.0, seed=11):
    """game fish swimming across behind the graphic shots (each crosses once, no wrap-around)"""
    rnd = random.Random(seed)
    names = ["Raw Salmon", "Tropical Fish", "Pufferfish", "Squid", "Rainbow Fish", "Space Fish", "Cod", "Turtle"]
    for i in range(n):
        fo = FX.fish(names[i % len(names)], rnd.uniform(0.7, 1.1))
        z = rnd.uniform(-7, 7)
        yy = y + rnd.uniform(0, 4)
        d = 1 if i % 2 else -1
        sp = rnd.uniform(0.09, 0.16)
        x0 = -d * rnd.uniform(4, 24)
        for f in range(f0 - 2, f1 + 3, 2):
            x = x0 + d * sp * (f - f0)
            kf(fo, f, loc=(x, yy, z + 0.3 * math.sin(f * 0.1 + i)),
               rot=(0, 0, math.radians(0 if d > 0 else 180) + math.radians(6) * math.sin(f * 0.4)))
        linear(fo)


def shot_boats(f0, f1):
    """all 17 boats race past on the eighth notes, then the abyssal surveyor rises"""
    scene()
    biome("Ocean", f0, f1, stream=(2.0, -1.0))
    cam = camera(30)
    lift = {"Sky Cruiser": 2.5, "Satellite": 4.0, "Space Shuttle": 3.0, "Alien Raft": 2.0}
    for i, (name, fp) in enumerate(zip(B.BOAT_ORDER[:16], T.BOAT_PASSES)):
        b, _ = boat(name)
        y = 9.0 + (i % 3) * 2.6
        hw = 14 if i < 8 else 9                    # the second bar's boats are faster
        for f in range(fp - hw, fp + hw + 1):
            u = (f - fp) / float(hw)
            x = -u * 22.0
            z = lift.get(name, 0.0) + 0.15 * math.sin(f * 0.5 + i)
            kf(b, f, loc=(x, y, z), rot=(math.radians(3 * math.sin(f * 0.7)), math.radians(-2), math.radians(180)))
        visible(b, fp - hw, fp + hw + 1)
        linear(b)
        if name not in lift:
            FX.splash((0.0, y - 0.8, 0), fp, size=1.0, seed=100 + i, crown=8, drops=10, rings=0, foam=False)
    last, _ = boat(B.BOAT_ORDER[16])
    fl = T.SURVEYOR
    for f in range(fl - 2, f1 + 3):
        u = ease_out((f - fl) / float(f1 - fl), 2)
        kf(last, f, loc=(0.0, 12.0, lerp(-6.0, 0.2, u)), rot=(0, 0, math.radians(lerp(140, 200, u))))
    visible(last, fl)
    linear(last)
    FX.splash((0, 12, 0), fl + 6, size=3.0, seed=150, crown=16, drops=30, column=4.0, rings=2)

    def cam_fn(f):
        k = smooth((f - f0) / (f1 - f0))
        return vlerp((0.0, -8.0, 1.5), (0.0, -5.5, 2.4), k), vlerp((0, 20, 1.8), (0, 20, 2.6), k), \
            lerp(-2.0, 2.0, k), lerp(30.0, 26.0, k)

    cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_finale(f0, f1):
    """the big KABOOM: every fish bursts out at the camera, the logo slams in again, the end card"""
    scene()
    K.setup_world("#2a6f78", 1.0, sky=[(0, "#0e3a44"), (1, "#0b2930")])
    K.sun((52, 8, 24), 1.0)
    cam = camera(40)
    FX.sunburst((0, 10, 0), 44, 22, "#0f3e48", "#13505c", f0 - 2, f1 + 2, spin=0.35, center="#2a8f96")
    BK = T.BIG_KABOOM
    FX.explosion((0, 4, 0.4), BK, size=2.1, seed=7, puffs=24, life=36, ring=True, ring_axis="Y", debris=10, sparks=26)
    rnd = random.Random(12)
    for i, name in enumerate(T_FISH):
        s0 = rnd.uniform(1.0, 1.5)
        fo = FX.fish(name, s0)
        a = 2 * math.pi * i / len(T_FISH) + rnd.uniform(-0.2, 0.2)
        d = Vector((math.cos(a) * 1.7, -rnd.uniform(0.5, 1.3), math.sin(a) * 1.05))
        spin = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * 0.25
        dur = rnd.randint(30, 44)
        for k in range(0, dur + 1):
            e = ease_out(k / 12.0, 2) * 0.6 + 0.4 * (k / dur)
            p = Vector((0, 4, 0.4)) + d * 7.5 * e
            kf(fo, BK + k, loc=p, rot=Euler(spin * (k + 10)), scale=s0 * (0.4 + 0.6 * ease_out(k / 4.0)))
        visible(fo, BK, BK + dur + 1)
        linear(fo)
    stand = FX.empty("stand")
    stand.rotation_euler = (math.radians(90), 0, 0)
    root, glyphs, fish = FX.build_logo()
    root.parent = stand
    stand.scale = (2.1, 2.1, 2.1)
    stand.location = (0, 0, 1.1)
    for i, (g, hit) in enumerate(zip(glyphs, T.FINALE_HITS)):
        rest = g.location.copy()
        FX.slam(g, hit, rest, rest_rot=tuple(g.rotation_euler), frm=(0.25 * (i % 3 - 1), 1.4, 1.7), seed=i + 50,
                frm_scale=1.7, travel=3)
        burst(g, hit, seed=i + 50, n=8)
    rest = fish.location.copy()
    rr = fish.rotation_euler.copy()
    fl = T.FINALE_FISH
    for k in range(-9, 1):
        u = (k + 9) / 9.0
        p = rest + Vector((1.6 * (1 - u), -2.6 * (1 - u) + 2.2 * 4 * u * (1 - u), 0.6 * (1 - u)))
        kf(fish, fl + k, loc=p, rot=(0, 0, rr.z + math.radians(-200 * (1 - u))), scale=0.85 + 0.15 * u)
    for k, sx, sy in [(2, 1.2, 0.82), (4, 0.92, 1.1), (7, 1.0, 1.0)]:
        kf(fish, fl + k, loc=rest, rot=rr, scale=(sx, sy, 1.0))
    visible(fish, fl - 9)
    burst(fish, fl, seed=90, n=12, color="#5fe0bd")
    # the logo breathes on the beat once it's there; fish circle it
    for f in range(1020, f1 + 3, 15):
        kf(stand, f, scale=2.1 * 1.03)
        kf(stand, f + 4, scale=2.1)
    kf(stand, 1019, scale=2.1)
    for i, name in enumerate(["Tropical Fish", "Pufferfish", "Rainbow Fish"]):
        fo = FX.fish(name, 0.8)
        for f in range(1012, f1 + 3, 2):
            a = (f - 1012) * 0.045 + i * 2.1
            vel = (-math.sin(a) * 8.4, math.cos(a) * 2.0, math.cos(a) * 2.4)
            kf(fo, f, loc=(math.cos(a) * 8.4, 3.0 + math.sin(a) * 2.0, 1.7 + math.sin(a) * 2.4), rot=FX.rot_from(vel))
        visible(fo, 1012)
        linear(fo)
    bubbles(f0, f1, area=(-16, 16, -9, 9), y=6.0, n=36, seed=8)

    def cam_fn(f):
        if f < BK + 24:
            k = ease_out((f - BK) / 24.0)
            return vlerp((0, -14.0, 0.6), (0, -15.5, 0.9), k), Vector((0, 0, 0.6)), lerp(4.0, -1.0, k), 40.0
        k = smooth((f - BK - 24) / (f1 - BK - 24))
        return vlerp((0, -15.5, 0.9), (0.3, -14.2, 0.7), k), Vector((0, 0, 0.4)), lerp(-1.0, 1.0, k), 40.0

    cam_path(cam, f0, f1, cam_fn)
    return cam


T_FISH = list(M.FISH_SPECS.keys())


# ------------------------------------------------------------- overlays
WORDS = {
    "word_kaboom": dict(text="KABOOM!", face="#ffe14a", side="#d62f1f", burst="#e8302a", burst2="#ff8a1f"),
    "word_boom": dict(text="BOOM!", face="#ffffff", side="#d62f1f", burst="#ff6a1f", burst2="#ffb21f"),
    "word_whoosh": dict(text="WHOOSH!", face="#ffffff", side="#2f6fd6", burst="#2f6fd6", burst2="#6fc3ff"),
    "word_splash": dict(text="SPLASH!", face="#ffffff", side="#1f8fbf", burst="#1f8fbf", burst2="#6fdcf5"),
}
WORD_LIFE = 34


def overlay_word(name):
    scene(transparent=True, blur=True, glow=False)
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = 1600 * OPT["pct"] // 100, 1100 * OPT["pct"] // 100
    K.setup_world("#9a9aa6", 1.0)
    K.sun((40, 10, 20), 1.0)
    cam = camera(50)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 16.0
    cam_key(cam, 0, (0, -20, 0), (0, 0, 0))
    w = WORDS[name]
    root, tm, bursts, (tw, th) = FX.comic_word(w["text"], 1.0, w["face"], w["side"], "#2a0f08", w["burst"],
                                               w["burst2"], seed=len(name))
    fit = 9.0 / max(tw * 1.35, 1.0)
    holder = FX.empty("holder")
    root.parent = holder
    holder.scale = (fit, fit, fit)
    FX.pop_word(root, 1, WORD_LIFE - 2, tilt=-7.0, seed=3)
    for b in bursts:
        for f, a in ((0, 0.0), (WORD_LIFE, 25.0)):
            b.rotation_euler = (0, 0, math.radians(a))
            b.keyframe_insert("rotation_euler", frame=f)
        linear(b)
    return cam


# ---------------------------------------------------------------- render
SHOT_FN = {"open": shot_open, "logo": shot_logo, "river": shot_river, "volcanic": shot_volcanic, "ocean": shot_ocean,
           "sky": shot_sky, "space": shot_space, "alien": shot_alien, "abyss": shot_abyss, "screens": shot_screens,
           "boats": shot_boats, "finale": shot_finale}


def render_frames(out_dir, f0, f1, stills=None, tag="", force=False):
    sc = bpy.context.scene
    os.makedirs(out_dir, exist_ok=True)
    if stills:
        os.makedirs(STILLS, exist_ok=True)
        for f in stills:
            sc.frame_set(f)
            sc.render.filepath = os.path.join(STILLS, "%s_%04d.png" % (tag, f))
            bpy.ops.render.render(write_still=True)
            print("STILL", sc.render.filepath, flush=True)
        return
    sc.frame_start, sc.frame_end = f0, f1 - 1
    sc.render.filepath = out_dir.rstrip("/\\") + os.sep
    sc.render.use_overwrite = force
    sc.render.use_placeholder = not force
    bpy.ops.render.render(animation=True)


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
    if "words" in names:
        names = [n for n in names if n != "words"] + list(WORDS)
    for name in names:
        print("== boom shot", name, flush=True)
        if name in WORDS:
            overlay_word(name)
            sts = ([f for f in stills if 0 <= f <= WORD_LIFE] or [10]) if stills else None
            render_frames(os.path.join(OVERLAYS, name), 0, WORD_LIFE + 1, sts, name, force)
            continue
        f0, f1 = T.SHOTS[name]
        SHOT_FN[name](f0, f1)
        sts = [f for f in stills if f0 <= f < f1] if stills else None
        if stills and not sts:
            sts = [f0 + (f1 - f0) // 2]
        render_frames(FRAMES, f0, f1, sts, name, force)
    print("done", flush=True)


if __name__ == "__main__":
    main()

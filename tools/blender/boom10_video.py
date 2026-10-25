"""fosh&fish 1.0 trailer, "THE LEVIATHAN": the 3D shots, rendered with Blender (Eevee) in the game's
cel-shaded style, with the KABOOM video's tools (boom_video.py, boom_fx.py) and the 1.0 art (render_v1.py:
the shiny palettes, the event fish). The Leviathan is Quaternius' whale (CC0), recoloured like in the game.
Timing: tools/video/boom10_timeline.py. The logo and finale shots are KABOOM's own (same frames): their
frames are copied from build/boom/frames when they're there, or rendered with boom_video.

    blender -b --factory-startup --python tools/blender/boom10_video.py -- SHOT [SHOT ...]
            [--pct 50] [--samples 16] [--still F,F,...] [--force]

SHOT: a shot of boom10_timeline.SHOTS, "all", "new" (all but the reused ones) or an overlay word
(word_sploosh, word_shiny, word_kaching, word_caught; "words" = all of them). Frames go to
build/boom10/frames/####.png, words to build/boom10/overlays/NAME/####.png, stills to build/boom10/stills/.
Needs the fonts in build/boom (tools/video/boom_prep.py).
"""
import math
import os
import random
import shutil
import sys

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "video"))

import boom_video as BV  # noqa: E402
import boom_fx as FX  # noqa: E402
import boom10_timeline as T  # noqa: E402
import render_v1 as R1  # noqa: E402
import vf_kit as K  # noqa: E402
import vf_models as M  # noqa: E402
import vf_props as P  # noqa: E402
import vf_biomes as BI  # noqa: E402
import vf_fisher as FI  # noqa: E402
import vf_vendor as V  # noqa: E402
from boom_fx import back_out, ease_in, ease_out, kf, lerp, linear, smooth, visible, vlerp  # noqa: E402
from vf_kit import toon  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
WORK = os.path.join(ROOT, "build", "boom10")
FRAMES = os.path.join(WORK, "frames")
OVERLAYS = os.path.join(WORK, "overlays")
STILLS = os.path.join(WORK, "stills")
KABOOM_FRAMES = os.path.join(ROOT, "build", "boom", "frames")
OPT = BV.OPT

# skies for the Ocean diorama (vf_biomes "Ocean" with other colours)
SUNSET = dict(sky=[(0, "#ffe2b0"), (0.22, "#ffb48a"), (0.55, "#e98ab8"), (1, "#4f63d8")], fog="#ffd6b4",
              water=("#1d4f9a", "#4aa6e0", "#fff2dc"), ambient="#8d8090", sun=(74, 0, 30), sun_col="#ffd8a8")
SHINY = dict(sky=[(0, "#fff0c4"), (0.28, "#a8d8ff"), (1, "#2440a8")], fog="#dceeff",
             water=("#123e8a", "#3d9be0", "#ffffff"), ambient="#7c84a0", sun=(60, 0, 30), sun_col="#fff4d0")
GOLDEN = dict(sky=[(0, "#fff6c8"), (0.3, "#ffd36a"), (1, "#ff9a3a")], fog="#ffe6a8",
              water=("#b86e12", "#ffcf4d", "#fff8d8"), ambient="#a08a6a", sun=(66, 0, 30), sun_col="#fff0b0")
DAY = dict(BI.BIOMES["Ocean"])
TWILIGHT = dict(sky=[(0, "#f6d0ff"), (0.3, "#b383e8"), (1, "#352680")], fog="#dcbcf2",
                water=("#24166a", "#7656d6", "#f2e4ff"), ambient="#82709a", sun=(64, 0, 60), sun_col="#f4e0ff")
NIGHT = dict(sky=[(0, "#3c3c8c"), (0.3, "#1a1a4e"), (1, "#05051c")], fog="#2a2a62", stars=1.0,
             water=("#08102e", "#283a8c", "#c4d2ff"), ambient="#4c4c74", sun=(64, 0, 120), sun_col="#b8c0ff")
STORM = dict(sky=[(0, "#ffa080"), (0.3, "#b8343e"), (1, "#280814")], fog="#7a3a52",
             water=("#0c0a24", "#2e2a5e", "#e8d8ff"), ambient="#7c5a6a", sun=(62, 0, 50), sun_col="#ffd0c0")

WHALE_TINT = {"Top": "#9b1d3a", "Bottom": "#f6d2b0"}
GOLD_LINE = "#8a5a00"


# ------------------------------------------------------------------ helpers
def sea(cfg, f0, f1, stream=(0.0, -1.5)):
    """the Ocean diorama (islands, lighthouse, clouds) in other colours, its water drifting"""
    base = dict(BI.BIOMES["Ocean"])
    base.update(cfg)
    K.setup_world(base["ambient"], 1.0, sky=base["sky"], stars=base.get("stars", 0.0))
    K.sun(base["sun"], 1.0, base["sun_col"])
    K.FOG.update({"color": base["fog"], "start": 40.0, "end": 420.0, "amount": 0.82})
    random.seed(42)
    parts = BI.build("Ocean", base)
    K.outline_all(parts, 0.12)
    K.FOG.update({"color": None, "amount": 0.0})
    mat = parts[0].data.materials[0]
    mp = next(n for n in mat.node_tree.nodes if n.type == "MAPPING")
    for f, k in ((f0 - 2, 0.0), (f1 + 2, 1.0)):
        mp.inputs["Location"].default_value = (stream[0] * k, stream[1] * k, 0.0)
        mp.inputs["Location"].keyframe_insert("default_value", frame=f)
    for fc in mat.node_tree.animation_data.action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    return parts


def leviathan(length=16.0, f0=0, f1=200, speed=1.6):
    """Quaternius' whale in the game's boss colours, swimming (looped), under a holder that faces +X:
    returns (holder, meshes)"""
    meshes, arm, roots = V.import_glb(os.path.join(V.GLB, "whale.glb"))
    root = V.group_root(roots)
    for m in meshes:
        for i, mt in enumerate(m.data.materials):
            if mt is None:
                continue
            mt = mt.copy()
            m.data.materials[i] = mt
            V.toonify(mt, tint=WHALE_TINT.get(mt.name.split(".")[0]))
    root.rotation_euler = (0, 0, math.radians(90))          # nose -Y -> +X
    act = V.set_action(arm, "swim")
    bpy.context.scene.frame_set(int(act.frame_range[0]) if act else 1)
    bpy.context.view_layer.update()
    V.normalize(meshes, root, length=length)
    holder = FX.empty("leviathan")
    root.parent = holder
    holder.rotation_mode = "QUATERNION"
    V.outline_skinned(meshes, 0.07)
    if act and arm:
        ad = arm.animation_data
        ad.action = None
        tr = ad.nla_tracks.new()
        st = tr.strips.new("swim", int(f0) - 20, act)
        span = act.frame_range[1] - act.frame_range[0]
        st.scale = speed
        st.repeat = max(1.0, (f1 - f0 + 60) / max(1.0, span * speed))
    return holder, meshes


def key_whale(holder, f, center, fwd, roll=0.0, prev=None):
    """place the whale: its centre, the way its nose points, a roll about that axis"""
    q = Vector(fwd).normalized().to_track_quat("X", "Z")
    if roll:
        q = q @ Quaternion((1, 0, 0), math.radians(roll))
    q = FX.keep_sign(q, prev)
    kf(holder, f, loc=Vector(center), quat=q)
    return q


def shiny_fish(name, scale=1.0):
    """a shiny (render_v1's palettes, gold outline), nose +X under one root"""
    parts = M.build_fish(R1.shiny_spec(name, M.FISH_SPECS[name]))
    K.outline_all(parts, 0.04, GOLD_LINE)
    root = K.parent_all(parts, "shiny_" + name.replace(" ", "_"))
    root.scale = (scale, scale, scale)
    return root


def event_fish(name, scale=1.0):
    spec = R1.EVENT_SPECS[name]
    parts = M.build_fish(spec)
    if name == "Frenzy Piranha":
        parts += R1.piranha_jaw(spec)
    K.outline_all(parts, 0.035)
    root = K.parent_all(parts, "event_" + name.replace(" ", "_"))
    root.scale = (scale, scale, scale)
    return root


_glint_mesh = {}


def glint(loc, f, life=14, size=0.35, color="#fff3b0", strength=3.0, facing=(90, 0, 0)):
    """a 4-point sparkle that pops and fades (faces -Y unless told otherwise)"""
    key = (round(size, 3), color)
    if key not in _glint_mesh:
        ob = K.extrude_poly(M.star_pts(1.0, 0.22, 4), 0.02, mat=FX.glow_mat(color, strength))
        ob["no_outline"] = True
        _glint_mesh[key] = ob.data
        bpy.data.objects.remove(ob)
    ob = bpy.data.objects.new("glint", _glint_mesh[key])
    bpy.context.collection.objects.link(ob)
    ob["no_outline"] = True
    ob.rotation_euler = Euler([math.radians(a) for a in facing])
    for k, s in [(0, 0.0), (2, size * 1.25), (4, size), (life, 0.0)]:
        kf(ob, f + k, loc=Vector(loc), scale=s)
    visible(ob, f, f + life + 1)
    return ob


def trail(root, f0, f1, every=2, size=0.3, color="#fff3b0", spread=0.4, seed=0):
    """glints left behind along an animated object's path"""
    rnd = random.Random(seed)
    sc = bpy.context.scene
    for f in range(f0, f1, every):
        sc.frame_set(f)
        p = root.matrix_world.to_translation()
        p += Vector((rnd.uniform(-spread, spread), rnd.uniform(-spread, spread) * 0.3, rnd.uniform(-spread, spread)))
        glint(p, f, life=rnd.randint(10, 16), size=size * rnd.uniform(0.6, 1.2), color=color)


def coin(loc=(0, 0, 0), r=0.32):
    ob = K.cyl(loc=loc, r=r, depth=0.07, verts=20, mat=toon("#ffcf3a", spec=0.4, rim=0.25))
    K.add_outline(ob, 0.03, "#7a4a00")
    return ob


def throw(ob, f0, p0, v, life, spin=(0, 0, 0), g=FX.G, scale=1.0, shrink=False):
    """ballistic flight from p0 with velocity v (units/s), spinning; hidden outside its flight"""
    p0, v, spin = Vector(p0), Vector(v), Vector(spin)
    for k in range(0, life + 1):
        t = k / T.FPS
        p = p0 + v * t + Vector((0, 0, -0.5 * g * t * t))
        s = scale * (1 - (k / life) ** 3) if shrink else scale
        kf(ob, f0 + k, loc=p, rot=Euler(spin * t), scale=s)
    linear(ob)
    visible(ob, f0, f0 + life + 1)


def rowboat_with_fisher(pos, yaw, f0, f1, pose_fn, rod="Plastic Rod", heading=250.0, rock=1.0, push=None):
    """the rowboat bobbing at pos, the fisher posed every frame by pose_fn(f) -> P;
    push(f) -> (offset Vector, extra roll, extra pitch) shoves the boat; returns (boat, puppet, tips, tops)"""
    rb, deck = BV.boat("Rowboat")
    byaw = math.radians(yaw)
    base = Vector(pos)

    def boat_m(f):
        roll = 1.8 * rock * math.sin(f * 0.13)
        pitch = 1.2 * rock * math.sin(f * 0.09 + 1.0)
        z = 0.05 * math.sin(f * 0.11)
        off = Vector((0, 0, 0))
        if push:
            off, r2, p2 = push(f)
            roll += r2
            pitch += p2
        return (Matrix.Translation(base + off + Vector((0, 0, z))) @ Matrix.Rotation(byaw, 4, "Z") @
                Euler((math.radians(roll), math.radians(pitch), 0)).to_matrix().to_4x4())

    rb.rotation_mode = "QUATERNION"
    bq = None
    for f in range(f0 - 2, f1 + 3):
        m = boat_m(f)
        bq = FX.keep_sign(m.to_quaternion(), bq)
        kf(rb, f, loc=m.to_translation(), quat=bq)
    linear(rb)
    pup = BV.Puppet(scale=1.25, rod=rod)
    head = math.radians(heading) - byaw
    tips, tops = {}, {}
    for f in range(f0 - 2, f1 + 3):
        root = boat_m(f) @ Matrix.Translation(deck) @ Matrix.Rotation(head, 4, "Z")
        grip, tip, top = pup.key(f, root, pose_fn(f))
        tips[f], tops[f] = tip.copy(), top.copy()
    pup.done()
    return rb, pup, tips, tops


def anim_pose(name, f, fps_scale=1.0, loop=True):
    a = FI.ANIMS[name]
    i = f * a["fps"] / T.FPS * fps_scale
    i = i % a["n"] if loop else min(i, a["n"] - 1)
    return FI.sample(a, i)


def bobber(name="bobber"):
    root = FX.empty(name)
    bob = K.sphere(scale=1.0, seg=24, rings=12, name="bob")
    K.vcolor(bob, lambda co, n: K.hexc("#ec3b2e") if co.z > 0.1 else K.hexc("#ffffff"), per_face=True)
    bob.data.materials.append(toon(None, vcol="col", key=("bobber",)))
    bob.scale = (0.2, 0.2, 0.2)
    K.add_outline(bob, 0.1)
    pin = K.cyl(loc=(0, 0, 0.27), r=0.025, depth=0.16, mat=toon("#ec3b2e"), verts=8)
    K.add_outline(pin, 0.012)
    for o in (bob, pin):
        o.parent = root
    return root


def whale_shadow():
    """the giant dark shape under the water (a flat silhouette just over the surface, see-through)"""
    pts = []
    for i in range(24):
        a = 2 * math.pi * i / 24
        pts.append((math.cos(a) * 8.0, math.sin(a) * 3.0 * (0.55 + 0.45 * math.cos(a / 2) ** 2)))
    body = K.extrude_poly(pts, 0.01, mat=None)
    fl = K.extrude_poly([(-7.2, 0), (-11.0, 3.6), (-9.8, 0.2), (-11.0, -3.6)], 0.01, mat=None)
    mat = FX.fade_mat("#0a1838", 1.0, "shadow")
    for o in (body, fl):
        o.data.materials.clear()
        o.data.materials.append(mat)
        o["no_outline"] = True
    root = K.parent_all([body, fl], "shadow")
    return root, mat


# ==================================================================== shots
def shot_open(f0, f1):
    """a calm sea at sunset, the fisher dozing ... a giant shadow slides under the boat, "!" ... the
    Leviathan bursts out of the sea behind him: the boat is thrown back, his hat flies"""
    BV.scene()
    sea(SUNSET, f0, f1, stream=(0.0, -1.2))
    cam = BV.camera(32)
    BOAT = Vector((1.9, 16.6, 0.0))
    BOB = Vector((-0.45, 10.4, 0.0))
    BR = Vector((3.0, 27.0, 0.0))                 # where it breaks the surface
    B = T.BREACH

    def push(f):
        t = f - B
        if t < 0:
            if T.SHADOW[0] + 40 <= f < B:          # the wake of the shadow rocks the boat a little
                u = (f - T.SHADOW[0] - 40) / 40.0
                return Vector((0, 0, 0)), 4.0 * math.sin(u * 7) * u, 2.0 * math.sin(u * 5)
            return Vector((0, 0, 0)), 0.0, 0.0
        e = ease_out(t / 18.0)
        return (Vector((-1.4, -2.8, 0)) * e + Vector((0, 0, 0.6 * math.exp(-t / 7.0) * math.sin(t * 0.5))),
                -24 * math.exp(-t / 14.0) * math.cos(t * 0.33), 10 * math.exp(-t / 12.0) * math.sin(t * 0.4))

    def pose(f):
        if f < T.BITE - 4:
            return dict(FI.sample(FI.ANIMS["idle"], (f / 5.0) % 8), eyes=1.0, head=(10.0, 0.0, 0.0))
        if f < B:
            k = smooth((f - T.BITE + 4) / 6.0)
            return BV.pose_mix(dict(FI.SIT, eyes=1.0), FI.S(lean=13.0, head=(4.0, 0.0, 0.0), brows=1.0, eyes=0.0,
                                                            mouth=0.4, rod=(0.0, 20.0)), k)
        k = smooth((f - B) / 5.0)
        return BV.pose_mix(FI.S(lean=13.0, brows=1.0, mouth=0.5, rod=(0.0, 14.0)),
                           FI.S(lean=-24.0, head=(-22.0, 0.0, 0.0), hr=("t", 0.15, -0.36, 0.78),
                                hl=("t", 0.12, 0.38, 0.8), brows=1.0, eyes=0.0, mouth=1.0, rod=(0.0, 62.0)), k)

    rb, pup, tips, tops = rowboat_with_fisher(BOAT, 205, f0, f1, pose, push=push)
    # the bobber and the line, until the breach
    line = BV.fishing_line()
    bob = bobber()
    pq = None
    for f in range(f0 - 2, B + 1):
        z = 0.04 * math.sin(f * 0.21)
        off = Vector((0, 0, 0))
        if T.BITE - 4 <= f < T.BITE:
            z = -0.1 * math.sin((f - T.BITE + 4) / 4 * math.pi)
        elif T.BITE <= f < B:
            z = -0.25 + 0.12 * math.sin(f * 1.9)
            off = Vector((0.06 * math.sin(f * 2.7), 0.06 * math.cos(f * 2.3), 0))
        bp = BOB + off + Vector((0, 0, z))
        kf(bob, f, loc=bp)
        pq = BV.key_line(line, f, tips[f], bp + Vector((0, 0, 0.18)), pq)
    linear(bob)
    linear(line)
    visible(bob, -1000, B)
    visible(line, -1000, B)
    for fr in (6, 40, 74):
        FX.ripple(BOB, fr, 1.1)
    # dozing "z"s, then "!"
    for i, fz in enumerate((6, 30, 54)):
        sg, _ = BV.text_pop("z", (0, 0, 0), fz, fz + 30, size=1.1 + 0.25 * (i % 3), color="#ffffff", line="#2f86b5")
        start = tops[fz] + Vector((0.25, -0.2, 0.25))
        for k in range(0, 31, 2):
            t = k / 30.0
            kf(sg, fz + k, loc=start + Vector((0.5 * math.sin(t * 3 + i) + 0.4 * t, 0, 1.5 * t)),
               scale=back_out(k / 6.0) * (1 - ease_in(t, 3)))
        visible(sg, fz, fz + 31)
    ex, _ = BV.text_pop("!", (0, 0, 0), T.BITE, B, size=1.5)
    ep = tops[T.BITE] + Vector((0.1, -0.2, 0.55))
    for k, s in [(0, 0.0), (3, 1.35), (5, 0.9), (7, 1.05), (9, 1.0)]:
        kf(ex, T.BITE + k, loc=ep, scale=s)
    for f in range(T.BITE + 10, B, 2):
        kf(ex, f, loc=ep + Vector((0, 0, 0.06 * math.sin(f * 1.3))), scale=1.0 + 0.05 * math.sin(f * 2.0))
    visible(ex, T.BITE, B)
    # the shadow glides in under the boat, then sinks toward where it will come up
    sh, smat = whale_shadow()
    s0, s1 = T.SHADOW
    for f in range(s0 - 2, B + 3):
        u = (f - s0) / float(s1 - s0)
        p = Vector((lerp(-24.0, BR.x - 3.0, smooth(min(1.0, u))), lerp(19.0, BR.y - 5.0, smooth(min(1.0, u))), 0.03))
        d = Vector((1.0, 0.25, 0))
        kf(sh, f, loc=p, rot=(0, 0, math.atan2(d.y, d.x)), scale=1.0 + 0.25 * max(0.0, u - 0.6))
    linear(sh)
    for f, a in [(s0, 0.0), (s0 + 14, 0.5), (s1, 0.62), (B - 4, 0.75), (B + 1, 0.0)]:
        FX.key_alpha(smat, f, a)
    visible(sh, s0, B + 1)
    # the water bulges ... and it breaks
    dome = FX.blob((BR.x, BR.y, 0), 1.0, toon("#9fdcef", shade=0.85, rim=0.0), sub=3, name="dome")
    FX.outline(dome, 0.03, FX.WATER_LINE)
    for f, s, h in [(108, 1.0, 0.0), (113, 3.0, 0.5), (117, 4.4, 1.1), (119, 5.0, 1.6), (B, 0.0, 0.0)]:
        kf(dome, f, scale=(s, s, h))
    visible(dome, 108, B + 1)
    FX.splash(BR, B, size=5.6, seed=4, crown=26, drops=60, column=15.0, rings=3)
    FX.splash(BR + Vector((4.0, -2.0, 0)), B + 3, size=2.4, seed=5, crown=12, drops=18, rings=1)
    FX.splash(BR + Vector((-4.2, -1.5, 0)), B + 4, size=2.2, seed=6, crown=12, drops=16, rings=1)
    FX.explosion(BR + Vector((0, 0, 1.5)), B, size=4.0, seed=8, puffs=22, life=36, ring=True, ring_axis="Z", debris=0,
                 sparks=0, palette=["#ffffff", "#f2fbff", "#ddf4ff", "#c4eaff", "#a8dcff"], rise=0.4, flash=False,
                 line=FX.WATER_LINE)
    # the Leviathan
    wh, _ = leviathan(17.0, f0, f1)
    q = None
    for f in range(104, f1 + 3):
        t = (f - B) / float(f1 - B)
        if f < B:
            z = lerp(-14.0, -8.0, (f - 104) / float(B - 104))
            pitch = 70.0
        else:
            z = lerp(-8.0, 6.8, ease_out(min(1.0, t * 1.08), 2.2))
            pitch = lerp(70.0, 18.0, smooth(t))
        c = Vector((lerp(BR.x - 3.0, BR.x + 3.5, smooth(max(0.0, t))), BR.y, z))
        fwd = Vector((math.cos(math.radians(pitch)), -0.18, math.sin(math.radians(pitch))))      # side-on to the camera
        q = key_whale(wh, f, c, fwd, roll=lerp(-10.0, 55.0, smooth(max(0.0, t))), prev=q)
    linear(wh)
    visible(wh, 104)
    # water streaming off it as it rises
    rnd = random.Random(3)
    for i in range(46):
        fs = B + rnd.randint(4, 46)
        d = FX.blob((0, 0, 0), 1.0, toon("#f2fcff", shade=0.9, rim=0.0), sub=1, name="drop")
        FX.outline(d, 0.12, FX.WATER_LINE)
        p0 = BR + Vector((rnd.uniform(-3, 3), rnd.uniform(-2, 2), rnd.uniform(3, 11)))
        throw(d, fs, p0, (rnd.uniform(-3, 3), rnd.uniform(-3, 1), rnd.uniform(-2, 4)), 24, scale=rnd.uniform(0.18, 0.4),
              shrink=True)
    # his hat flies off
    hat_p = tops[B] + Vector((0, 0, 0.3))
    hat = FX.empty("hat_fly")
    hp_ob = pup.f.parts["hat"]
    # (the puppet keeps its own hat: a second one flies, the puppet's is hidden from the breach on)
    hat2 = hp_ob.copy()
    hat2.data = hp_ob.data
    hat2.animation_data_clear()
    bpy.context.collection.objects.link(hat2)
    hat2.parent = hat
    hat2.location = (0, 0, 0)
    hat2.rotation_mode = "XYZ"
    hat2.rotation_euler = (0, 0, 0)
    hat2.scale = hp_ob.scale
    throw(hat, B + 1, hat_p, (1.2, -3.4, 12.0), 58, spin=(9, 4, 6), g=FX.G * 0.55)
    visible(hp_ob, -1000, B + 1)

    def cam_fn(f):
        if f < 30:
            k = smooth(f / 30.0)
            return vlerp((-1.6, 0.4, 2.8), (-1.5, 0.8, 3.2), k), vlerp((0.9, 14.0, 1.6), (1.0, 14.6, 1.4), k), 0.0, 40.0
        if f < B - 8:
            k = smooth((f - 30) / float(B - 38))
            return vlerp((-1.5, 0.8, 3.2), (-1.8, 2.4, 6.2), k), vlerp((1.0, 14.6, 1.4), (1.2, 18.0, 0.2), k), 0.0,                 lerp(40.0, 34.0, k)
        if f < B:
            k = smooth((f - B + 8) / 8.0)
            return vlerp((-1.8, 2.4, 6.2), (-1.6, 1.6, 3.0), k), vlerp((1.2, 18.0, 0.2), (2.6, 24.0, 2.6), k), 0.0,                 lerp(34.0, 32.0, k)
        t = f - B
        k = ease_out(t / 16.0)
        look_z = lerp(2.6, 8.0, ease_out(t / 30.0, 2))
        return vlerp((-1.6, 1.6, 3.0), (-3.0, -3.6, 1.6), k), Vector((lerp(2.6, 4.0, k), lerp(24.0, 25.0, k), look_z)),             lerp(0.0, -4.0, k), lerp(32.0, 26.0, k)

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_shiny(f0, f1):
    """golden-outlined shiny fish leap across, sparkling; the big one leaps at the camera and hangs there"""
    BV.scene()
    sea(SHINY, f0, f1, stream=(0.8, -1.2))
    cam = BV.camera(30)
    L = T.SHINY_LEAPS
    specs = [("Tropical Fish", (-5.5, 11.0, -0.4), (-1.0, 8.5, -0.4), 4.0),
             ("Pufferfish", (5.0, 11.5, -0.4), (0.8, 9.0, -0.4), 3.8),
             ("Space Fish", (-3.4, 8.0, -0.4), (2.4, 7.4, -0.4), 3.4),
             ("Shark", (6.0, 13.0, -0.6), (-1.8, 10.0, -0.6), 4.2)]
    for i, (name, p0, p1, h) in enumerate(specs):
        fo = shiny_fish(name, 1.9 if name != "Shark" else 2.3)
        FX.leap(fo, L[i], L[i] + 22, Vector(p0), Vector(p1), h, wiggle=12.0, spin=1.0 if i == 2 else 0.0)
        FX.splash((p0[0], p0[1], 0), L[i] - 1, size=1.2, seed=20 + i, crown=10, drops=12)
        FX.splash((p1[0], p1[1], 0), L[i] + 21, size=0.9, seed=30 + i, crown=8, drops=8)
        trail(fo, L[i], L[i] + 24, every=1, size=0.5, seed=i, spread=0.7)
    # the hero: Shiny Rainbow Fish, leaping right at the camera, then hanging in a golden glow
    hero = shiny_fish("Rainbow Fish", 2.2)
    HJ, HF = T.SHINY_HERO, T.SHINY_FREEZE
    p_out = Vector((1.6, 13.0, -0.4))
    hang = Vector((0.4, 7.6, 2.6))
    for f in range(HJ - 4, f1 + 3):
        if f < HF:
            u = (f - HJ) / float(HF - HJ)
            p = p_out.lerp(hang, ease_out(max(0.0, u), 2)) + Vector((0, 0, 2.6 * math.sin(math.pi * min(1.0, max(0.0, u)) * 0.5)))
            rot = Euler((0.0, math.radians(lerp(-40, -8, max(0.0, u))), math.radians(lerp(-120, -150, max(0.0, u)))))
        else:
            u = (f - HF) / float(f1 - HF)
            p = hang + Vector((0.15 * math.sin(f * 0.15), 0.0, 0.1 * math.sin(f * 0.2)))
            rot = Euler((math.radians(4 * math.sin(f * 0.3)), math.radians(-8), math.radians(-150 + 8 * u)))
        kf(hero, f, loc=p, rot=rot)
    linear(hero)
    visible(hero, HJ - 4)
    FX.splash((p_out.x, p_out.y, 0), HJ - 1, size=1.6, seed=40, crown=14, drops=18, rings=2)
    trail(hero, HJ, HF, every=1, size=0.55, seed=9, spread=0.8)
    halo = K.cyl(r=1.0, depth=0.01, verts=48, mat=FX.radial_mat("#ffd75e", 0.85), smooth=False)
    halo.rotation_euler = (math.radians(90), 0, 0)
    halo["no_outline"] = True
    for f, s in [(HF - 4, 0.0), (HF + 2, 3.6), (HF + 6, 3.0), (f1 + 2, 3.3)]:
        kf(halo, f, loc=hang + Vector((0, 1.2, 0)), scale=(s, s, 1))
    visible(halo, HF - 4)
    rnd = random.Random(12)
    for f in range(HF, f1, 3):                                # sparkles round the hero while it hangs
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(1.8, 3.2)
        glint(hang + Vector((math.cos(a) * r, -0.6, math.sin(a) * r * 0.75)), f, life=12, size=rnd.uniform(0.25, 0.5))

    def cam_fn(f):
        k = smooth((f - f0) / float(f1 - f0))
        if f < HF:
            return vlerp((-0.6, -3.6, 1.5), (0.0, -1.6, 1.9), k), vlerp((0, 20, 2.4), (0.3, 18, 2.6), k), 0.0, 30.0
        u = smooth((f - HF) / float(f1 - HF))
        return vlerp((0.0, -1.6, 1.9), (0.2, -0.8, 2.3), u), vlerp((0.3, 18, 2.6), (0.4, 7.6, 2.6), min(1.0, u * 1.6)), \
            lerp(0.0, -3.0, u), lerp(30.0, 34.0, u)

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_golden(f0, f1):
    """Golden Hour: the sea turns to gold, coins fountain out of it, a Golden Koi leaps, he cheers"""
    BV.scene()
    sea(GOLDEN, f0, f1, stream=(0.0, -1.0))
    cam = BV.camera(30)
    BOAT = Vector((0.0, 14.0, 0.0))
    rowboat_with_fisher(BOAT, 200, f0, f1, lambda f: anim_pose("happy", f - f0, loop=True), heading=230.0)
    rnd = random.Random(21)
    for i in range(40):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(2.6, 7.0)
        p0 = BOAT + Vector((math.cos(a) * r, math.sin(a) * r * 0.7, -0.1))
        fs = f0 + 2 + int(i * 1.0) + rnd.randint(0, 3)
        c = coin()
        v = Vector((math.cos(a) * rnd.uniform(0.5, 2.0), math.sin(a) * rnd.uniform(0.5, 1.5), rnd.uniform(10, 15)))
        throw(c, fs, p0, v, 32, spin=(rnd.uniform(6, 14), rnd.uniform(-4, 4), 0), scale=rnd.uniform(0.8, 1.3))
        if i % 3 == 0:
            FX.ripple(p0, fs, 0.8)
    koi = event_fish("Golden Koi", 1.6)
    KJ = f0 + 22
    FX.leap(koi, KJ, KJ + 24, Vector((-6.0, 18.0, -0.4)), Vector((-1.0, 12.0, -0.4)), 5.0, wiggle=12.0)
    FX.splash((-6.0, 18.0, 0), KJ - 1, size=1.3, seed=60, crown=10, drops=12)
    FX.splash((-1.0, 12.0, 0), KJ + 23, size=1.0, seed=61, crown=8, drops=8)
    trail(koi, KJ, KJ + 24, every=2, size=0.32, seed=3)

    def cam_fn(f):
        k = smooth((f - f0) / float(f1 - f0))
        a = math.radians(lerp(-112, -64, k))
        r = 9.5
        return BOAT + Vector((math.cos(a) * r, math.sin(a) * r, lerp(3.4, 2.6, k))), BOAT + Vector((0, 1.0, 1.6)), 0.0, 32.0

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_frenzy(f0, f1):
    """Fish Frenzy: fish leap everywhere around the boat, one after another"""
    BV.scene()
    sea(DAY, f0, f1, stream=(1.2, -1.6))
    cam = BV.camera(30)
    BOAT = Vector((0.0, 14.0, 0.0))
    rowboat_with_fisher(BOAT, 200, f0, f1, lambda f: anim_pose("cast", (f - f0) % 30, loop=False), heading=245.0)
    names = ["Raw Salmon", "Tropical Fish", "Cod", "Pufferfish", "Squid", "Hot Cod", "Rainbow Fish", "Turtle",
             "Space Fish", "Dolphin", "Alien Fish", "Raw Fish"]
    rnd = random.Random(31)
    for i, (fl, name) in enumerate(zip(T.FRENZY_LEAPS, names)):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(4.5, 9.0)
        p0 = BOAT + Vector((math.cos(a) * r, math.sin(a) * r * 0.8, -0.4))
        b = a + rnd.choice((-1, 1)) * rnd.uniform(0.6, 1.1)
        p1 = BOAT + Vector((math.cos(b) * r * 0.75, math.sin(b) * r * 0.6, -0.4))
        if i == 6:                                              # the frenzy piranha, front and centre
            fo = event_fish("Frenzy Piranha", 1.5)
        else:
            fo = FX.fish(name, 1.3 if name != "Dolphin" else 1.6)
        FX.leap(fo, fl, fl + 20, p0, p1, rnd.uniform(3.4, 5.2), wiggle=14.0, spin=rnd.choice((0.0, 0.0, 1.0)))
        FX.splash((p0.x, p0.y, 0), fl - 1, size=1.0, seed=70 + i, crown=10, drops=10)
        FX.splash((p1.x, p1.y, 0), fl + 19, size=0.8, seed=90 + i, crown=8, drops=8, rings=1)

    def cam_fn(f):
        k = smooth((f - f0) / float(f1 - f0))
        return vlerp((-3.0, 2.0, 4.6), (-1.6, 5.6, 3.4), k), BOAT + Vector((0, 0.5, 1.4)), lerp(-3.0, 3.0, k), \
            lerp(28.0, 32.0, k)

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_treasure(f0, f1):
    """Treasure Tide: chests bob up out of a twilight sea one after another, sparkling, spilling coins"""
    BV.scene()
    sea(TWILIGHT, f0, f1, stream=(0.0, -1.0))
    cam = BV.camera(30)
    tiers = ["rare", "epic", "legendary", "artifact", "super"]
    spots = [(-6.0, 17.0), (-2.6, 13.6), (0.6, 16.6), (3.6, 13.0), (6.6, 17.6)]
    rnd = random.Random(41)
    for i, (tier, (x, y), fc) in enumerate(zip(tiers, spots, T.CHESTS)):
        parts = P.chest(tier)
        K.outline_all(parts, 0.04)
        ch = K.parent_all(parts, "chest_" + tier)
        yaw = math.radians(rnd.uniform(-25, 25))
        for f in range(fc - 6, f1 + 3):
            t = f - fc
            if t < 0:
                z = -2.6
            else:
                z = lerp(-2.6, -0.25, back_out(min(1.0, t / 8.0), 2.6)) + 0.12 * math.sin(f * 0.25 + i)
            kf(ch, f, loc=(x, y, z), rot=(math.radians(4 * math.sin(f * 0.2 + i)), math.radians(3 * math.sin(f * 0.17)), yaw),
               scale=1.25)
        linear(ch)
        visible(ch, fc - 6)
        FX.splash((x, y, 0), fc, size=1.4, seed=100 + i, crown=12, drops=14, rings=2)
        for k in range(8):                                     # a burst of glints
            a = 2 * math.pi * k / 8
            glint((x + math.cos(a) * 1.6, y - 1.0, 1.4 + math.sin(a) * 1.2), fc + 6 + k % 3, life=14, size=0.4)
        for k in range(4):                                     # coins jump out
            c = coin(r=0.26)
            throw(c, fc + 8 + k * 2, (x, y, 1.0), (rnd.uniform(-2.5, 2.5), rnd.uniform(-2.5, -0.5), rnd.uniform(8, 11)), 26,
                  spin=(rnd.uniform(8, 14), 0, 0))

    def cam_fn(f):
        k = smooth((f - f0) / float(f1 - f0))
        return vlerp((0.0, -2.0, 3.2), (0.4, 1.2, 2.9), k), vlerp((0.3, 18.0, 1.4), (0.3, 18.0, 1.0), k), 0.0, \
            lerp(30.0, 33.0, k)

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_meteor(f0, f1):
    """Meteor Shower: a night sky, meteors streak down and crash into the sea, a Meteor Fish leaps"""
    BV.scene()
    sea(NIGHT, f0, f1, stream=(0.0, -1.0))
    cam = BV.camera(28)
    rnd = random.Random(51)
    head_mat = FX.glow_mat("#fff0c8", 6.0)
    tail_mat = FX.glow_mat("#ff9a3d", 3.0)
    for i, fi in enumerate(T.METEORS):
        hit = Vector((rnd.uniform(-9, 10), rnd.uniform(16, 34), 0))
        d = Vector((-0.55 + rnd.uniform(-0.15, 0.15), -0.25, -1.0)).normalized()
        start = hit - d * 46.0
        dur = 18
        head = FX.blob((0, 0, 0), 1.0, head_mat, sub=2, name="meteor")
        head["no_outline"] = True
        tail = K.cone(r1=0.7, r2=0.0, depth=9.0, verts=12, mat=tail_mat, name="meteor_tail")
        tail["no_outline"] = True
        tail.rotation_mode = "QUATERNION"
        q = (-d).to_track_quat("Z", "Y")
        for k in range(-dur, 1):
            u = (k + dur) / float(dur)
            p = start.lerp(hit, u)
            kf(head, fi + k, loc=p, scale=0.75)
            kf(tail, fi + k, loc=p - d * 4.6, quat=q)
        linear(head)
        linear(tail)
        visible(head, fi - dur, fi + 1)
        visible(tail, fi - dur, fi + 1)
        FX.splash(hit, fi, size=2.2, seed=200 + i, crown=16, drops=22, column=5.0, rings=2)
        FX.explosion(hit + Vector((0, 0, 0.6)), fi, size=1.3, seed=210 + i, puffs=12, life=26, ring=False, debris=0,
                     sparks=10, steam=0.5, palette=FX.FIRE[:5])
    mf = event_fish("Meteor Fish", 1.6)
    MF = T.METEOR_FISH
    FX.leap(mf, MF, MF + 22, Vector((5.0, 13.0, -0.4)), Vector((0.0, 10.0, -0.4)), 4.6, wiggle=12.0)
    FX.splash((5.0, 13.0, 0), MF - 1, size=1.3, seed=230, crown=10, drops=12)
    trail(mf, MF, f1, every=2, size=0.3, color="#ffd27a", seed=5)

    def cam_fn(f):
        k = smooth((f - f0) / float(f1 - f0))
        return vlerp((-0.6, -4.0, 1.6), (0.4, -2.2, 1.9), k), vlerp((0.0, 30.0, 8.0), (1.0, 30.0, 6.5), k), \
            lerp(2.0, -1.0, k), 28.0

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_rods(f0, f1):
    """the three exclusive rods slam in over a sunburst, turn, and spin together"""
    BV.scene()
    K.setup_world("#2a6f78", 1.0, sky=[(0, "#0e3a44"), (1, "#0b2930")])
    K.sun((52, 8, 24), 1.0)
    cam = BV.camera(40)
    FX.sunburst((0, 9, 0), 40, 22, "#0f3e48", "#13505c", f0 - 2, f1 + 2, spin=0.35, center="#2a8f96")
    BV.bubbles(f0, f1, area=(-14, 14, -8, 8), y=6.0, n=26, seed=4)
    names = ["Starfall Rod", "Pearl Rod", "Legend Rod"]
    xs = [-3.9, 0.0, 3.9]
    froms = [(-26, 4, 6), (0, 4, 22), (26, 4, 6)]
    for i, (name, x, frm, fr) in enumerate(zip(names, xs, froms, T.RODS)):
        parts = M.build_rod(M.ROD_SPECS[name], strip=True)[0]
        K.outline_all(parts, 0.025)
        inner = K.parent_all(parts, "rod_" + name.replace(" ", "_"))
        inner.rotation_euler = (0, math.radians(-45), 0)        # the rod stands up
        inner.location = (0, 0, 0.05)                          # (centred on the holder)
        holder = FX.empty("rodholder_%d" % i)
        inner.parent = holder
        rest = Vector((x, 0, -0.1))
        frm = Vector(frm)
        s = 1.85
        for k in range(-7, 1):
            u = ease_in((k + 7) / 7.0, 2)
            kf(holder, fr + k, loc=frm.lerp(rest, u), rot=(0, math.radians(30 * (1 - u) * (1 if i != 1 else 0)),
                                                           math.radians(180 * (1 - u))), scale=s * lerp(0.6, 1.0, u))
        for k, sc in [(2, 1.08), (4, 0.97), (7, 1.0)]:
            kf(holder, fr + k, loc=rest, rot=(0, 0, 0), scale=s * sc)
        for f in range(fr + 9, f1 + 3, 2):
            spin = 0.0
            if f >= T.ROD_SPIN:
                spin = 360.0 * ease_out(min(1.0, (f - T.ROD_SPIN) / 14.0), 2)
            kf(holder, f, loc=rest + Vector((0, 0, 0.12 * math.sin(f * 0.12 + i))),
               rot=(0, math.radians(2 * math.sin(f * 0.09 + i)), math.radians(25 * math.sin((f - fr) * 0.035) + spin)),
               scale=s)
        linear(holder)
        visible(holder, fr - 7)
        BV.burst(inner, fr, seed=i * 3, n=12, color="#fff3b0")
        for k in range(10):
            a = 2 * math.pi * k / 10
            glint((x + math.cos(a) * 1.6, -1.2, 0.2 + math.sin(a) * 2.6), fr + 2 + k % 4, life=14, size=0.35)

    def cam_fn(f):
        k = smooth((f - f0) / float(f1 - f0))
        return Vector((lerp(-0.5, 0.5, k), lerp(-15.0, -13.2, k), 0.25)), Vector((0, 0, 0.15)), lerp(-1.5, 1.5, k), 38.0

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


def shot_boss(f0, f1):
    """the boss: the Leviathan surfaces and circles the boat under a red sky; the line goes tight and it
    drags the boat; tail slaps; REEL IT IN; it leaps out of the sea right beside him"""
    BV.scene()
    sea(STORM, f0, f1, stream=(0.0, -2.0))
    cam = BV.camera(30)
    BOAT = Vector((0.0, 16.0, 0.0))
    HK, RL, BJ = T.HOOKED, T.REEL, T.BOSS_JUMP
    LEN = 18.0
    path = {}

    def whale_at(f):
        """(centre, forward, roll) of the Leviathan"""
        if f < HK:                                              # circling behind the boat, its back breaking the water
            u = (f - T.BOSS_SURFACE) / float(HK - T.BOSS_SURFACE)
            a = math.radians(lerp(205, 20, u))
            c = BOAT + Vector((math.cos(a) * 12.0, 6.0 + math.sin(a) * 9.0, -1.1 + 0.5 * math.sin(f * 0.18)))
            fwd = Vector((-math.sin(a) * 12.0, math.cos(a) * 9.0, 0.6 * math.cos(f * 0.18)))
            return c, fwd, 0.0
        if f < RL:                                              # hooked: it swims off, dragging the line tight
            u = (f - HK) / float(RL - HK)
            a = math.radians(20)
            c0 = BOAT + Vector((math.cos(a) * 12.0, 6.0 + math.sin(a) * 9.0, -2.2))
            c = c0 + Vector((6.0, 9.0, 0.0)) * smooth(u) + Vector((0, 0, 0.6 * math.sin(f * 0.3)))
            return c, Vector((0.6, 1.0, 0.1 * math.cos(f * 0.3))), 8.0 * math.sin(f * 0.25)
        if f < BJ:                                              # reeled back in, thrashing
            u = (f - RL) / float(BJ - RL)
            c0 = BOAT + Vector((math.cos(math.radians(20)) * 12.0 + 6.0, 6.0 + math.sin(math.radians(20)) * 9.0 + 9.0, -2.2))
            c1 = BOAT + Vector((7.0, 10.0, -3.0))
            c = c0.lerp(c1, smooth(u)) + Vector((0, 0, 0.8 * math.sin(f * 0.45)))
            return c, Vector((-0.8, -1.0, 0.15 * math.sin(f * 0.5))), 18.0 * math.sin(f * 0.4)
        u = (f - BJ) / float(f1 - BJ)                             # the leap, right beside him, side-on
        c0 = BOAT + Vector((1.0, 11.0, -9.0))
        c = c0 + Vector((7.0 * smooth(u), 0.0, 0)) + Vector((0, 0, 17.0 * ease_out(min(1.0, u * 1.2), 2.0)))
        pitch = lerp(66.0, 4.0, smooth(u))
        fwd = Vector((math.cos(math.radians(pitch)), -0.2, math.sin(math.radians(pitch))))
        return c, fwd, lerp(-10.0, 70.0, smooth(u))

    wh, _ = leviathan(LEN, f0, f1, speed=1.2)
    q = None
    for f in range(f0 - 2, f1 + 3):
        c, fwd, roll = whale_at(f)
        path[f] = (c, fwd.normalized())
        q = key_whale(wh, f, c, fwd, roll=roll, prev=q)
    linear(wh)
    # wake while it circles, spray while it drags, slaps, the big splash of the leap
    for f in range(T.BOSS_SURFACE, HK, 6):
        c, fwd = path[f]
        FX.splash((c.x, c.y, 0), f, size=1.4, seed=f, crown=10, drops=8, rings=1, foam=False)
    for f in range(HK, BJ, 8):
        c, fwd = path[f]
        FX.splash((c.x - fwd.x * LEN * 0.45, c.y - fwd.y * LEN * 0.45, 0), f, size=1.2, seed=f + 3, crown=8, drops=8,
                  rings=0, foam=False)
    for i, fs in enumerate(T.SLAPS):
        c, fwd = path[fs]
        tailp = c - fwd * LEN * 0.48
        FX.splash((tailp.x, tailp.y, 0), fs, size=3.0, seed=300 + i, crown=16, drops=26, column=4.0, rings=2)
    c, _ = path[BJ + 3]
    FX.splash((c.x, c.y, 0), BJ + 3, size=6.0, seed=320, crown=26, drops=60, column=14.0, rings=3)

    # the boat: shoved by the wake, dragged when hooked, rocked hard while he reels
    def push(f):
        if f < HK:
            return Vector((0, 0, 0)), 3.0 * math.sin(f * 0.21), 1.5 * math.sin(f * 0.17)
        if f < BJ:
            u = min(1.0, (f - HK) / float(RL - HK))
            return Vector((1.6, 2.4, 0)) * smooth(u), 7.0 * math.sin(f * 0.6), 4.0 + 3.0 * math.sin(f * 0.5)
        t = f - BJ
        return Vector((1.6, 2.4, 0)) + Vector((0, -1.5, 0)) * ease_out(min(1.0, t / 14.0)), \
            -18 * math.exp(-t / 12.0) * math.cos(t * 0.4), 8 * math.exp(-t / 10.0) * math.sin(t * 0.5)

    def pose(f):
        if f < HK - 6:
            return anim_pose("cast", 999, loop=False)          # standing, rod up (the cast's last pose)
        return anim_pose("reel", f, fps_scale=1.0 if f < RL else 1.8)

    rb, pup, tips, tops = rowboat_with_fisher(BOAT, 200, f0, f1, pose, rod="Legend Rod", heading=60.0, push=push)
    line = BV.fishing_line()
    lq = None
    for f in range(HK - 2, f1 + 3):
        c, fwd = path[f]
        mouth = c + fwd * LEN * 0.46
        lq = BV.key_line(line, f, tips[f], mouth, lq)
    linear(line)
    visible(line, HK)

    def cam_fn(f):
        if f < HK:
            u = smooth((f - f0) / float(HK - f0))
            a = math.radians(lerp(-120, -70, u))
            return BOAT + Vector((math.cos(a) * 15.0, math.sin(a) * 15.0, lerp(7.0, 5.0, u))), BOAT + Vector((1.0, 5.0, 0.5)), \
                0.0, 30.0
        if f < RL:
            u = smooth((f - HK) / float(RL - HK))
            return BOAT + vlerp((-3.0, -6.5, 3.6), (-2.4, -5.0, 3.0), u), BOAT + vlerp((3.0, 8.0, 1.0), (5.0, 12.0, 1.0), u), \
                lerp(0.0, 3.0, u), 30.0
        if f < BJ:
            u = smooth((f - RL) / float(BJ - RL))
            return BOAT + vlerp((-2.4, -5.0, 3.0), (-3.0, -4.0, 2.2), u), BOAT + vlerp((5.0, 12.0, 1.0), (5.5, 10.0, 0.8), u), \
                lerp(3.0, -3.0, u), lerp(30.0, 26.0, u)
        u = (f - BJ) / float(f1 - BJ)
        c, _ = path[f]
        look = BOAT.lerp(c, 0.7) + Vector((0, 0, 1.0))
        return BOAT + vlerp((-3.0, -4.0, 2.2), (-5.0, -9.0, 1.6), ease_out(min(1.0, u * 2.0))), look, lerp(-3.0, 4.0, u), \
            lerp(26.0, 24.0, u)

    BV.cam_path(cam, f0, f1, cam_fn)
    return cam


# ------------------------------------------------------------- overlays
WORDS = {
    "word_sploosh": dict(text="SPLOOSH!", face="#ffffff", side="#1f8fbf", burst="#1f6fd6", burst2="#6fdcf5"),
    "word_shiny": dict(text="SHINY!", face="#ffe14a", side="#d98a00", burst="#8b3fe0", burst2="#e4c8ff"),
    "word_kaching": dict(text="KA-CHING!", face="#ffe14a", side="#c77a00", burst="#ff8a1f", burst2="#fff3b0"),
    "word_caught": dict(text="CAUGHT!", face="#ffe14a", side="#d62f1f", burst="#e8302a", burst2="#ff8a1f"),
}
for _k, _v in WORDS.items():
    BV.WORDS[_k] = _v
WORD_LIFE = BV.WORD_LIFE

SHOT_FN = {"open": shot_open, "shiny": shot_shiny, "golden": shot_golden, "frenzy": shot_frenzy,
           "treasure": shot_treasure, "meteor": shot_meteor, "rods": shot_rods, "boss": shot_boss,
           "logo": BV.shot_logo, "finale": BV.shot_finale}


def copy_reused(name, force=False):
    """KABOOM's logo / finale frames, when they're already rendered: same frames, same pictures"""
    f0, f1 = T.SHOTS[name]
    src = [os.path.join(KABOOM_FRAMES, "%04d.png" % f) for f in range(f0, f1)]
    if not all(os.path.exists(p) for p in src):
        return False
    os.makedirs(FRAMES, exist_ok=True)
    for f, p in zip(range(f0, f1), src):
        dst = os.path.join(FRAMES, "%04d.png" % f)
        if force or not os.path.exists(dst):
            shutil.copyfile(p, dst)
    print("copied KABOOM's", name, "frames", flush=True)
    return True


def render_frames(out_dir, f0, f1, stills=None, tag="", force=False):
    BV.STILLS = STILLS
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
    if "new" in names:
        names = [n for n in T.SHOTS if n not in T.REUSED]
    if "words" in names:
        names = [n for n in names if n != "words"] + list(WORDS)
    for name in names:
        print("== boom10 shot", name, flush=True)
        if name in WORDS:
            BV.overlay_word(name)
            sts = ([f for f in stills if 0 <= f <= WORD_LIFE] or [10]) if stills else None
            render_frames(os.path.join(OVERLAYS, name), 0, WORD_LIFE + 1, sts, name, force)
            continue
        if name in T.REUSED and not stills and copy_reused(name, force):
            continue
        f0, f1 = T.SHOTS[name]
        _glint_mesh.clear()                                     # (each shot starts from an empty scene)
        SHOT_FN[name](f0, f1)
        sts = [f for f in stills if f0 <= f < f1] if stills else None
        if stills and not sts:
            sts = [f0 + (f1 - f0) // 2]
        render_frames(FRAMES, f0, f1, sts, name, force)
    print("done", flush=True)


if __name__ == "__main__":
    main()

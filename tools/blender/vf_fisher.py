"""The fosh&fish fisher: an original chunky cartoon sea dog built from primitives
(project's own art): yellow sou'wester, bushy walrus moustache, big red nose,
orange life vest, green rubber boots, sitting on a cooler with his mug on the lid.

A tiny puppet rig poses him per frame: rigid parts on "bones", 2-bone IK for the
arms and legs, and animations written as keyed poses (frame index -> pose).
He sits while waiting, stands up to cast / reel / react, and sits back down.
The rod is not rendered: rod_grip / rod_tip are recorded per frame and the game
draws the equipped rod between them (as before). "head" (hat top) is recorded so
the game can draw "Zzz" over him while he dozes.
Faces +X like every top-down sprite; the anchor (cooler base) is the origin.
"""
import math
import os
import tempfile

import bpy
from mathutils import Matrix, Vector

import vf_kit as K
import vf_vendor as V
from vf_kit import cone, cube, cyl, sphere, toon, torus

CELL = 256
YAW = -40.0        # whole puppet turned toward the camera so his face reads from above
ROD_L = 1.35       # in-hand rod length (drawn in-game from the equipped rod strip)
ARM = (0.22, 0.20)
LEG = (0.25, 0.24)
OUTLINE = 0.026
SIZE = 1.5         # cartoon scale: drawn 1.5x his "real" size next to the boats so he reads at game size

COL = dict(skin="#f6bf96", nose="#ea7766", cheek="#f3958a", tache="#f3eee4", hat="#ffc93a", hat_band="#e39b1c",
           vest="#ff7a2e", band="#f6f6f2", shirt="#3d6fb6", pants="#34466b", boot="#4fa14b", sole="#2b3b2b",
           cooler="#2f93c4", lid="#7fd0ea", mug="#d9473a", eye="#1b1717", mouth="#6e2324", buckle="#2a2a30")


# ------------------------------------------------------------------ poses
SIT = dict(hips=(0.0, 0.0, 0.50), lean=6.0, roll=0.0, twist=0.0, head=(-10.0, 0.0, 0.0), shrug=0.0, hat=(-18.0, 0.0),
           hr=("t", 0.30, -0.17, 0.20), hl=("t", 0.22, 0.24, 0.04), rod=(0.0, 30.0),
           fl=(0.26, 0.17, 0.12), fr=(0.27, -0.17, 0.12), eyes=0.0, mouth=0.1, brows=0.0, mug=0.0)
STAND = dict(SIT, hips=(0.24, 0.0, 0.60), lean=3.0, fl=(0.25, 0.18, 0.12), fr=(0.30, -0.17, 0.12),
             hr=("t", 0.30, -0.17, 0.24), hl=("t", 0.20, 0.25, 0.08), rod=(0.0, 28.0))
MUG_LID = (-0.04, 0.29, 0.39)          # mug on the cooler lid (root-local, base)


def S(**kw):
    return dict(SIT, **kw)


def ST(**kw):
    return dict(STAND, **kw)


def _wave_keys(base, a, b, frames, extra):
    return [(f, base(hl=(a if k % 2 == 0 else b), **extra)) for k, f in enumerate(frames)]


# name -> n frames, fps, keys [(frame, pose)], loop, optional per-frame overrides / hold loop
ANIMS = {
    "idle": dict(n=8, fps=6, loop=True, keys=[
        (0, SIT), (4, S(lean=9.0, hips=(0.0, 0.0, 0.51), head=(4.0, 0.0, 0.0), rod=(0.0, 27.0),
                        hr=("t", 0.30, -0.17, 0.22))), (8, SIT)],
        over={6: dict(eyes=1.0)}),
    "yawn": dict(n=10, fps=8, keys=[
        (0, SIT),
        (3, S(hl=("t", 0.02, 0.30, 0.98), lean=-10.0, head=(-24.0, 0.0, 6.0), mouth=1.0, eyes=1.0, brows=0.7, hat=(-26.0, 0.0),
              rod=(0.0, 36.0), hr=("t", 0.28, -0.20, 0.28))),
        (6, S(hl=("t", -0.04, 0.33, 1.0), lean=-12.0, head=(-26.0, 0.0, 8.0), mouth=1.0, eyes=1.0, brows=0.8,
              rod=(0.0, 38.0), hr=("t", 0.28, -0.20, 0.30))),
        (8, S(hl=("t", 0.18, 0.28, 0.25), lean=2.0, mouth=0.2, eyes=0.6)),
        (9, SIT)]),
    "scratch": dict(n=10, fps=9, keys=[(0, SIT)] + _wave_keys(
        S, ("h", -0.08, 0.2, 0.12), ("h", -0.13, 0.17, 0.05), [2, 3, 4, 5, 6, 7],
        dict(head=(-2.0, -12.0, -12.0), brows=0.9, eyes=0.35, mouth=0.25, roll=6.0, hat=(4.0, 0.03))) + [
        (8, S(hl=("t", 0.2, 0.3, 0.3), brows=0.4)), (9, SIT)]),
    "sip": dict(n=10, fps=8, keys=[
        (0, SIT),
        (2, S(hl=("r", MUG_LID[0] + 0.02, MUG_LID[1] + 0.03, 0.47), roll=18.0, mug=1.0, head=(10.0, 20.0, 0.0))),
        (4, S(hl=("h", 0.27, 0.03, -0.15), head=(-16.0, 0.0, 0.0), lean=-2.0, mug=1.0, eyes=1.0, brows=0.4)),
        (6, S(hl=("h", 0.27, 0.03, -0.15), head=(-20.0, 0.0, 4.0), lean=-4.0, mug=1.0, eyes=1.0, brows=0.6)),
        (8, S(hl=("r", MUG_LID[0] + 0.02, MUG_LID[1] + 0.03, 0.47), roll=18.0, mug=1.0, mouth=0.4)),
        (9, SIT)]),
    "doze": dict(n=12, fps=7, loop_range=[5, 8], hold=3.2, keys=[
        (0, SIT),
        (2, S(head=(16.0, 0.0, 0.0), eyes=0.7, lean=10.0, rod=(0.0, 24.0))),
        (5, S(head=(40.0, 0.0, 6.0), eyes=1.0, hat=(10.0, 0.0), lean=18.0, rod=(0.0, 8.0), mouth=0.35, hips=(0.0, 0.0, 0.49),
              hr=("t", 0.27, -0.17, 0.12))),
        (6, S(head=(43.0, 0.0, 7.0), eyes=1.0, hat=(10.0, 0.0), lean=19.0, rod=(0.0, 6.0), mouth=0.45, hips=(0.0, 0.0, 0.485),
              hr=("t", 0.27, -0.17, 0.11))),
        (7, S(head=(46.0, 0.0, 8.0), eyes=1.0, hat=(12.0, 0.0), lean=20.0, rod=(0.0, 4.0), mouth=0.55, hips=(0.0, 0.0, 0.48),
              hr=("t", 0.27, -0.17, 0.10))),
        (8, S(head=(43.0, 0.0, 7.0), eyes=1.0, hat=(10.0, 0.0), lean=19.0, rod=(0.0, 6.0), mouth=0.45, hips=(0.0, 0.0, 0.485),
              hr=("t", 0.27, -0.17, 0.11))),
        (9, S(head=(-22.0, 0.0, 0.0), eyes=0.0, brows=1.0, mouth=0.6, hat=(-30.0, 0.12), lean=-6.0, rod=(0.0, 48.0),
              hips=(0.0, 0.0, 0.55), hl=("t", 0.25, 0.38, 0.3))),
        (10, S(head=(-4.0, 28.0, 0.0), brows=0.6, mouth=0.2)),
        (11, SIT)]),
    "look": dict(n=10, fps=8, keys=[
        (0, SIT),
        (2, S(hl=("h", 0.21, 0.07, 0.13), head=(-6.0, 42.0, 0.0), brows=0.5, roll=-4.0)),
        (4, S(hl=("h", 0.21, 0.07, 0.13), head=(-8.0, 46.0, 0.0), brows=0.5, roll=-4.0)),
        (6, S(hl=("h", 0.21, 0.07, 0.13), head=(-6.0, -40.0, 0.0), brows=0.5, roll=4.0, twist=-10.0)),
        (7, S(hl=("h", 0.21, 0.07, 0.13), head=(-8.0, -44.0, 0.0), brows=0.5, roll=4.0, twist=-10.0)),
        (9, SIT)]),
    "wave": dict(n=10, fps=10, keys=[(0, SIT)] + _wave_keys(
        S, ("t", 0.10, 0.30, 1.0), ("t", -0.02, 0.50, 0.86), [1, 2, 3, 4, 5, 6, 7],
        dict(head=(-18.0, 32.0, 0.0), mouth=0.6, brows=0.8, roll=-8.0)) + [
        (8, S(hl=("t", 0.2, 0.32, 0.4), mouth=0.4)), (9, SIT)]),
    # ---- standing: cast / reel / reactions end on STAND, then "sit" takes him back down
    "cast": dict(n=10, fps=18, keys=[
        (0, SIT),
        (1, S(hips=(0.13, 0.0, 0.57), lean=24.0, rod=(0.0, 55.0), hr=("t", 0.28, -0.15, 0.32), hl=("rod", 0.24))),
        (2, ST(lean=-8.0, rod=(0.0, 110.0), hr=("t", 0.14, -0.20, 0.62), hl=("rod", 0.24), head=(-8.0, 0.0, 0.0),
               brows=-0.6, mouth=0.3)),
        (3, ST(lean=-14.0, rod=(0.0, 138.0), hr=("t", 0.06, -0.20, 0.66), hl=("rod", 0.24), head=(-10.0, 0.0, 0.0),
               brows=-0.8, mouth=0.4, fr=(0.36, -0.17, 0.12))),
        (4, ST(lean=8.0, rod=(0.0, 72.0), hr=("t", 0.30, -0.18, 0.58), hl=("rod", 0.24), brows=-0.8, mouth=0.6,
               fr=(0.38, -0.17, 0.12))),
        (5, ST(lean=22.0, rod=(0.0, 24.0), hr=("t", 0.42, -0.15, 0.32), hl=("rod", 0.24), mouth=0.8,
               fr=(0.40, -0.17, 0.12), hips=(0.28, 0.0, 0.58))),
        (6, ST(lean=18.0, rod=(0.0, 12.0), hr=("t", 0.40, -0.15, 0.24), hl=("rod", 0.24), mouth=0.4,
               fr=(0.38, -0.17, 0.12), hips=(0.27, 0.0, 0.59))),
        (9, ST(hl=("rod", 0.24)))]),
    "reel": dict(n=8, fps=16, keys=[(0, ST(hl=("rod", 0.24)))] + [
        (i, ST(lean=-12.0 - 3.0 * (i % 2), rod=(0.0, 50.0 + 6.0 * (i % 2)), hr=("t", 0.30, -0.15, 0.30),
               hl=("t", 0.27 + 0.07 * math.cos(i * 1.6), -0.03, 0.26 + 0.07 * math.sin(i * 1.6)),
               brows=-0.7, mouth=0.25, fr=(0.40, -0.17, 0.12), fl=(0.16, 0.18, 0.12), hips=(0.22, 0.0, 0.59)))
        for i in range(1, 7)] + [(7, ST(hl=("rod", 0.24)))]),
    "happy": dict(n=10, fps=12, keys=[
        (0, STAND),
        (2, ST(hips=(0.24, 0.0, 0.53), lean=16.0, hl=("t", 0.26, 0.32, 0.12), brows=0.5, mouth=0.5)),
        (3, ST(hips=(0.24, 0.0, 0.74), fl=(0.25, 0.18, 0.27), fr=(0.30, -0.17, 0.25), hl=("t", 0.06, 0.30, 1.05),
               rod=(0.0, 72.0), hr=("t", 0.25, -0.24, 0.55), mouth=1.0, eyes=0.85, brows=1.0, lean=-6.0, hat=(-24.0, 0.14))),
        (5, ST(hips=(0.24, 0.0, 0.57), hl=("t", 0.26, 0.33, 0.42), rod=(0.0, 60.0), hr=("t", 0.27, -0.22, 0.45),
               mouth=1.0, eyes=0.85, brows=1.0, lean=8.0)),
        (6, ST(hips=(0.24, 0.0, 0.66), fl=(0.25, 0.18, 0.18), hl=("t", 0.08, 0.31, 1.0), rod=(0.0, 74.0),
               hr=("t", 0.25, -0.24, 0.55), mouth=1.0, eyes=0.85, brows=1.0, lean=-4.0)),
        (7, ST(hips=(0.24, 0.0, 0.58), hl=("t", 0.26, 0.33, 0.40), rod=(0.0, 58.0), hr=("t", 0.27, -0.22, 0.42),
               mouth=1.0, eyes=0.85, brows=1.0, lean=8.0)),
        (9, ST(mouth=0.5))]),
    "dance": dict(n=12, fps=12, keys=[(0, STAND)] + [
        (f, ST(hips=(0.24, 0.07 * s, 0.6 + 0.02 * (k % 2)), roll=14.0 * s, head=(0.0, 0.0, -12.0 * s),
               hl=("t", 0.10, 0.36, 0.95) if s > 0 else ("t", 0.26, 0.34, 0.20),
               rod=(18.0 * s, 74.0), hr=("t", 0.22, -0.24, 0.62) if s < 0 else ("t", 0.30, -0.20, 0.40),
               fl=(0.25, 0.18, 0.12 + (0.12 if s < 0 else 0.0)), fr=(0.30, -0.17, 0.12 + (0.12 if s > 0 else 0.0)),
               mouth=1.0, eyes=0.85, brows=1.0))
        for k, (f, s) in enumerate([(1, 1), (3, -1), (5, 1), (7, -1), (9, 1)])] + [(11, ST(mouth=0.5))]),
    "sad": dict(n=10, fps=10, keys=[
        (0, STAND),
        (2, ST(hl=("h", 0.25, 0.02, 0.03), head=(-14.0, 0.0, 0.0), lean=6.0, rod=(0.0, 4.0), brows=-1.0,
               hr=("t", 0.28, -0.18, 0.10), mouth=0.0)),
        (4, ST(hl=("h", 0.25, 0.02, 0.03), head=(-18.0, 0.0, 0.0), lean=8.0, rod=(0.0, 0.0), brows=-1.0,
               hr=("t", 0.28, -0.18, 0.06), mouth=0.0)),
        (5, ST(hl=("h", 0.25, 0.02, 0.03), head=(-18.0, 14.0, 0.0), lean=8.0, rod=(0.0, 0.0), brows=-1.0,
               hr=("t", 0.28, -0.18, 0.06), mouth=0.0)),
        (6, ST(hl=("h", 0.25, 0.02, 0.03), head=(-18.0, -14.0, 0.0), lean=8.0, rod=(0.0, 0.0), brows=-1.0,
               hr=("t", 0.28, -0.18, 0.06), mouth=0.0)),
        (7, ST(hl=("h", 0.25, 0.02, 0.03), head=(-18.0, 10.0, 0.0), lean=8.0, rod=(0.0, 0.0), brows=-1.0,
               hr=("t", 0.28, -0.18, 0.06), mouth=0.0)),
        (9, STAND)]),
    "shrug": dict(n=8, fps=9, keys=[
        (0, STAND),
        (2, ST(shrug=1.0, hl=("t", 0.20, 0.46, 0.30), hr=("t", 0.28, -0.40, 0.32), rod=(-22.0, 40.0),
               head=(0.0, 0.0, 16.0), brows=1.0, mouth=0.15)),
        (5, ST(shrug=1.0, hl=("t", 0.22, 0.48, 0.34), hr=("t", 0.29, -0.42, 0.34), rod=(-24.0, 42.0),
               head=(0.0, 0.0, 18.0), brows=1.0, mouth=0.15, eyes=0.5)),
        (7, STAND)]),
    "sit": dict(n=5, fps=14, keys=[
        (0, STAND),
        (2, S(hips=(0.12, 0.0, 0.61), lean=18.0, rod=(0.0, 30.0))),
        (3, S(hips=(0.01, 0.0, 0.47), lean=10.0, brows=0.4)),
        (4, SIT)]),
}


def _lerp(a, b, k):
    if isinstance(a, (int, float)):
        return a + (b - a) * k
    return tuple(x + (y - x) * k for x, y in zip(a, b))


def _ease(k):
    return k * k * (3 - 2 * k)


# ---------------------------------------------------------------- matrices
def _rx(d):
    return Matrix.Rotation(math.radians(d), 4, "X")


def _ry(d):
    return Matrix.Rotation(math.radians(d), 4, "Y")


def _rz(d):
    return Matrix.Rotation(math.radians(d), 4, "Z")


def _T(*v):
    return Matrix.Translation(Vector(v))


def _seg(a, b):
    d = (b - a).normalized()
    return Matrix.Translation(a) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()


def _ik(s, t, a, b, pole):
    """2-bone IK: shoulder s, target t, lengths a/b, pole direction -> (elbow, wrist)."""
    dv = t - s
    d = max(abs(a - b) + 1e-3, min(dv.length, a + b - 1e-4))
    u = dv.normalized()
    v = pole - u * pole.dot(u)
    if v.length < 1e-5:
        v = Vector((0, 0, -1)) - u * (-u.z)
    v.normalize()
    ca = max(-1.0, min(1.0, (a * a + d * d - b * b) / (2 * a * d)))
    A = math.acos(ca)
    e = s + a * (math.cos(A) * u + math.sin(A) * v)
    return e, s + u * d


def _frames_of(P):
    """Pose dict -> bone matrices (root space) + resolved points."""
    hips = Vector(P["hips"])
    pelvis = _T(*hips)
    torso = pelvis @ _rz(P["twist"]) @ _ry(P["lean"]) @ _rx(-P["roll"])
    hp, hy, hr_ = P["head"]
    head = torso @ _T(0.02, 0.0, 0.56) @ _rz(hy) @ _ry(hp) @ _rx(-hr_) @ _T(0.0, 0.0, 0.18)
    ry, rp = P["rod"]
    yaw = math.radians(ry - YAW)
    pr = math.radians(rp)
    rod_dir = Vector((math.cos(pr) * math.cos(yaw), math.cos(pr) * math.sin(yaw), math.sin(pr)))
    return pelvis, torso, head, rod_dir


def _hand(spec, torso, head, grip=None, rod_dir=None):
    tag = spec[0]
    if tag == "t":
        return torso @ Vector(spec[1:])
    if tag == "h":
        return head @ Vector(spec[1:])
    if tag == "r":
        return Vector(spec[1:])
    if tag == "rod":
        return grip - rod_dir * spec[1] + Vector((0, 0, -0.02))
    raise ValueError(spec)


def resolve(P):
    """Hands to root-space points so poses with different hand specs blend smoothly."""
    pelvis, torso, head, rod_dir = _frames_of(P)
    hr = _hand(P["hr"], torso, head)
    hl = _hand(P["hl"], torso, head, hr, rod_dir)
    return dict(P, hr=("r", *hr), hl=("r", *hl))


def sample(anim, i):
    keys = anim["keys"]
    P = None
    for (f0, a), (f1, b) in zip(keys, keys[1:]):
        if f0 <= i <= f1:
            k = _ease((i - f0) / (f1 - f0)) if f1 > f0 else 0.0
            ra, rb = resolve(a), resolve(b)
            P = {key: _lerp(ra[key], rb[key], k) if key not in ("hr", "hl") else
                 ("r", *_lerp(ra[key][1:], rb[key][1:], k)) for key in ra}
            break
    if P is None:
        P = resolve(keys[-1][1])
    over = anim.get("over", {}).get(i)
    if over:
        P = dict(P, **over)
    return P


# ------------------------------------------------------------------ build
def _bake(objs, name):
    """Join parts into one object whose mesh lives in bone-local space."""
    objs = [o for o in objs if o is not None]
    for o in objs:
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob = K.join(objs, name) if len(objs) > 1 else objs[0]
    ob.name = name
    return ob


def _limb(length, r0, r1, color, end_ball=True):
    m = toon(color, soft=True)
    parts = [cone(loc=(0, 0, length / 2), r1=r0, r2=r1, depth=length, mat=m, verts=16),
             sphere(loc=(0, 0, 0), scale=r0, mat=m, seg=16, rings=8)]
    if end_ball:
        parts.append(sphere(loc=(0, 0, length), scale=r1, mat=m, seg=16, rings=8))
    return parts


class Fisher:
    def __init__(self):
        t = lambda c: toon(COL[c], soft=True)
        self.parts = {}
        P = self.parts
        # cooler (the seat): body along Y under him, white lid, side handles
        P["cooler"] = _bake([
            cube(loc=(-0.02, 0, 0.17), scale=(0.40, 0.70, 0.34), mat=t("cooler"), bevel=0.03),
            cube(loc=(-0.02, 0, 0.365), scale=(0.43, 0.73, 0.05), mat=t("lid"), bevel=0.015),
            cube(loc=(-0.02, 0.37, 0.24), scale=(0.12, 0.04, 0.05), mat=t("band"), bevel=0.01),
            cube(loc=(-0.02, -0.37, 0.24), scale=(0.12, 0.04, 0.05), mat=t("band"), bevel=0.01),
            cube(loc=(0.185, 0, 0.17), scale=(0.02, 0.5, 0.06), mat=t("band"))], "cooler")
        P["pelvis"] = _bake([sphere(scale=(0.19, 0.22, 0.13), mat=t("pants"))], "pelvis")
        P["torso"] = _bake([
            sphere(loc=(0.03, 0, 0.27), scale=(0.25, 0.28, 0.30), mat=t("vest")),
            sphere(loc=(0.245, 0, 0.33), scale=(0.06, 0.085, 0.20), mat=t("shirt")),
            cyl(loc=(0.03, 0, 0.19), r=1.0, depth=0.055, scale=(0.252, 0.282, 1.0), mat=t("band"), verts=32),
            cube(loc=(0.29, 0, 0.19), scale=(0.03, 0.09, 0.06), mat=t("buckle")),
            cyl(loc=(0.02, 0, 0.55), r=0.105, depth=0.07, mat=t("shirt"), verts=20)], "torso")
        P["head"] = _bake([
            sphere(scale=0.21, mat=t("skin")),
            sphere(loc=(0.205, 0, -0.03), scale=(0.085, 0.08, 0.075), mat=t("nose")),
            sphere(loc=(0.15, 0.125, -0.06), scale=0.05, mat=t("cheek"), seg=12, rings=6),
            sphere(loc=(0.15, -0.125, -0.06), scale=0.05, mat=t("cheek"), seg=12, rings=6),
            sphere(loc=(0.195, 0.09, -0.095), scale=(0.055, 0.12, 0.05), rot=(-28, 0, 22), mat=t("tache")),
            sphere(loc=(0.195, -0.09, -0.095), scale=(0.055, 0.12, 0.05), rot=(28, 0, -22), mat=t("tache")),
            sphere(loc=(0.0, 0.2, -0.02), scale=(0.035, 0.03, 0.05), mat=t("skin"), seg=12, rings=6),
            sphere(loc=(0.0, -0.2, -0.02), scale=(0.035, 0.03, 0.05), mat=t("skin"), seg=12, rings=6),
            ], "head")
        # sou'wester (pushed back on his head): round crown, short front brim, long back brim, band
        P["hat"] = _bake([
            sphere(loc=(-0.02, 0, 0.12), scale=(0.2, 0.2, 0.15), mat=t("hat")),
            torus(loc=(-0.02, 0, 0.11), R=0.195, r=0.025, mat=t("hat_band"), seg=32, mseg=8),
            cone(loc=(-0.11, 0, 0.09), r1=0.34, r2=0.19, depth=0.05, rot=(0, -6, 0), scale=(1.0, 0.95, 1.0),
                 mat=t("hat"), verts=40)], "hat")
        for s in ("l", "r"):
            P["eye_" + s] = _bake([sphere(scale=0.03, mat=t("eye"), seg=12, rings=6)], "eye_" + s)
            P["brow_" + s] = _bake([sphere(scale=(0.028, 0.06, 0.02), mat=t("tache"), seg=12, rings=6)], "brow_" + s)
        P["mouth"] = sphere(scale=1.0, mat=t("mouth"), seg=12, rings=6, name="mouth")
        for k in ("eye_l", "eye_r", "brow_l", "brow_r", "mouth"):
            P[k]["no_outline"] = True
        for side in ("l", "r"):
            P["uarm_" + side] = _bake(_limb(ARM[0], 0.07, 0.064, COL["shirt"]), "uarm_" + side)
            P["farm_" + side] = _bake(_limb(ARM[1], 0.058, 0.05, COL["skin"], end_ball=False), "farm_" + side)
            P["hand_" + side] = _bake([sphere(scale=(0.075, 0.07, 0.07), mat=t("skin"), seg=16, rings=8)], "hand_" + side)
            P["thigh_" + side] = _bake(_limb(LEG[0], 0.088, 0.08, COL["pants"]), "thigh_" + side)
            P["shin_" + side] = _bake(_limb(LEG[1], 0.078, 0.07, COL["pants"], end_ball=False), "shin_" + side)
            P["boot_" + side] = _bake([
                cyl(loc=(0, 0, 0.0), r=0.088, depth=0.15, mat=t("boot"), verts=16),
                torus(loc=(0, 0, 0.075), R=0.085, r=0.018, mat=t("boot"), seg=16, mseg=6),
                sphere(loc=(0.06, 0, -0.07), scale=(0.13, 0.085, 0.06), mat=t("boot")),
                cube(loc=(0.05, 0, -0.115), scale=(0.25, 0.15, 0.03), mat=t("sole"), bevel=0.012)], "boot_" + side)
        P["mug"] = _bake([
            cyl(loc=(0, 0, 0.06), r=0.055, depth=0.12, mat=t("mug"), verts=16),
            cyl(loc=(0, 0, 0.085), r=0.057, depth=0.025, mat=t("lid"), verts=16),
            torus(loc=(0, -0.065, 0.06), R=0.03, r=0.011, rot=(90, 0, 0), mat=t("mug"), seg=12, mseg=6)], "mug")
        self.root = Matrix.Rotation(math.radians(YAW), 4, "Z")
        for o in P.values():
            o.matrix_world = Matrix.Identity(4)

    def meshes(self):
        return list(self.parts.values())

    def outline(self):
        for o in self.parts.values():
            if not o.get("no_outline"):
                o["outline_even"] = False
                K.add_outline(o, OUTLINE)

    def pose(self, P):
        """Place every part for pose P; returns world points (grip, tip, head top)."""
        R = self.root
        W = self.parts
        pelvis, torso, head, rod_dir = _frames_of(P)
        W["cooler"].matrix_world = R
        W["pelvis"].matrix_world = R @ pelvis
        W["torso"].matrix_world = R @ torso
        W["head"].matrix_world = R @ head
        W["hat"].matrix_world = R @ head @ _ry(P["hat"][0]) @ _T(0, 0, P["hat"][1])
        e, mo, br = P["eyes"], P["mouth"], P["brows"]
        for s, sy in (("l", 1), ("r", -1)):
            W["eye_" + s].matrix_world = R @ head @ _T(0.182, 0.078 * sy, 0.035) @ Matrix.Diagonal((1, 1, max(0.15, 1 - e), 1))
            W["brow_" + s].matrix_world = R @ head @ _T(0.18, 0.085 * sy, 0.088 + 0.03 * br) @ _rx(-sy * 12 * br)
        W["mouth"].matrix_world = R @ head @ _T(0.185, 0, -0.135) @ Matrix.Diagonal(
            (0.035, 0.055 - 0.015 * mo, 0.012 + 0.055 * mo, 1))
        hr = Vector(P["hr"][1:])
        hl = Vector(P["hl"][1:])
        for s, sy, tgt in (("l", 1, hl), ("r", -1, hr)):
            sh = torso @ Vector((0.0, 0.25 * sy, 0.42 + 0.06 * P["shrug"]))
            pole = torso.to_3x3() @ Vector((-0.35, 0.8 * sy, -1.0))
            el, wr = _ik(sh, tgt, ARM[0], ARM[1], pole)
            W["uarm_" + s].matrix_world = R @ _seg(sh, el)
            W["farm_" + s].matrix_world = R @ _seg(el, wr)
            W["hand_" + s].matrix_world = R @ _T(*wr) @ torso.to_quaternion().to_matrix().to_4x4()
            hip = pelvis @ Vector((0.0, 0.115 * sy, -0.03))
            foot = Vector(P["fl"] if s == "l" else P["fr"])
            kn, an = _ik(hip, foot, LEG[0], LEG[1], Vector((1.0, 0.25 * sy, 0.4)))
            W["thigh_" + s].matrix_world = R @ _seg(hip, kn)
            W["shin_" + s].matrix_world = R @ _seg(kn, an)
            W["boot_" + s].matrix_world = R @ _T(*an) @ _rz(-8 * sy)
            if s == "r":
                grip = wr
        if P["mug"] >= 0.5:
            W["mug"].matrix_world = R @ _T(*hl) @ torso.to_quaternion().to_matrix().to_4x4() @ _T(0.035, 0.05, -0.06)
        else:
            W["mug"].matrix_world = R @ _T(*MUG_LID)
        tip = grip + rod_dir * ROD_L
        top = head @ Vector((-0.02, 0, 0.27))
        bpy.context.view_layer.update()
        return R @ grip, R @ tip, R @ top


def render(out_dir, setup):
    """Render every animation to out_dir/<anim>.png; returns the manifest "fisher" entry."""
    os.makedirs(out_dir, exist_ok=True)
    cam = setup(CELL)
    f = Fisher()
    objs = f.meshes()
    # one framing for every animation so the anchor stays put between sheets
    Rc = cam.rotation_euler.to_matrix()
    right, up, fwd = Rc @ Vector((1, 0, 0)), Rc @ Vector((0, 1, 0)), Rc @ Vector((0, 0, -1))
    xs, ys, zs = [], [], []
    for name, anim in ANIMS.items():
        for i in range(anim["n"]):
            f.pose(sample(anim, i))
            for p in K._mesh_points(objs):
                xs.append(p.dot(right))
                ys.append(p.dot(up))
                zs.append(p.dot(fwd))
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    scale = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.06
    cam.location = right * cx + up * cy + fwd * (min(zs) - 50.0)
    cam.data.ortho_scale = scale
    cam["frame"] = (cx, cy, scale, 1.0)
    f.outline()
    W = CELL
    pt = lambda p: [round(K.project(cam, p)[0] / W, 4), round(K.project(cam, p)[1] / W, 4)]
    info = {}
    only = os.environ.get("VF_FISHER_ONLY", "")
    for name, anim in ANIMS.items():
        grips, tips, heads, paths = [], [], [], []
        tmp = tempfile.mkdtemp()
        for i in range(anim["n"]):
            g, t, h = f.pose(sample(anim, i))
            grips.append(pt(g))
            tips.append(pt(t))
            heads.append(pt(h))
            if not only or name in only.split(","):
                p = os.path.join(tmp, "f%02d.png" % i)
                K.render(p)
                paths.append(p)
        if paths:
            V._stitch(paths, os.path.join(out_dir, name + ".png"), W)
        e = {"frames": anim["n"], "fps": anim["fps"], "rod_grip": grips, "rod_tip": tips, "head": heads}
        if anim.get("loop"):
            e["loop"] = True
        if "loop_range" in anim:
            e["loop_range"] = anim["loop_range"]
            e["hold"] = anim["hold"]
        info[name] = e
    _, _, scale, _ = cam["frame"]
    info["feet"] = pt((0, 0, 0))        # the anchor: cooler base centre (goes on the boat's seat)
    info["unit_px"] = round(W / scale / SIZE, 3)
    info["cell"] = W
    info["standing"] = ["cast", "reel", "happy", "dance", "sad", "shrug"]
    info["idles"] = ["yawn", "scratch", "sip", "doze", "look", "wave"]
    return info

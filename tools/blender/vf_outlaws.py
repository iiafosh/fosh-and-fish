"""The other six outlaws of the Most Wanted board (Gerald is vf_rival.py's). Each is a different fish, with its own body, fins and
face furniture: Sizzle the catfish, Captain Swordbeard the swordfish, Baron von Flap the flying fish, Commander Chomp the shark,
Zlorp the blobfish and the Duchess the anglerfish. Built the same way as Gerald: facing +X, the camera's side is y < 0, a
part's "wob" says how it moves (vf_rival.pose). The mini-game draws their eyes and mouths over the model, so the eye markers
(RV._face_eyes) only say where. spec["dark"]: the big shape that swims past the boat (one night colour, no little details).
"""
import math

import bmesh
import bpy
from mathutils import Vector

import vf_kit as K
import vf_rival as RV
from vf_kit import cone, hexc, ico, mix, sphere, toon, tube, vcolor

_sm = RV._smooth


def _mat(fish, color, **kw):
    return toon("#1b2b3c", key="outlaw_dark") if fish.get("dark") else toon(color, **kw)       # (toon's own "spec" is its shininess)


def _blob(spec, shape, paint):
    """a unit sphere pulled into this fish's body"""
    body = sphere(scale=1.0, seg=120, rings=60)
    K.deform(body, shape)
    vcolor(body, paint)
    body.data.materials.append(toon(None, vcol="col", spec=0.1, key=("outlaw", spec["top"])))
    body["wob"] = "body"
    return body


def _still(ob, wob="still", root=None, k=None):
    ob["wob"] = wob
    if root is not None:
        ob["root"] = tuple(root)
    if k is not None:
        ob["outline_k"] = k
    return ob


def _strand(spec, points, radii, color, wob="sway", k=0.8):
    ob = RV._strand(points, radii, _mat(spec, color), wob=wob, k=k)
    ob["root"] = tuple(points[0])
    return ob


def _tail(spec, reach, a0=140, a1=220, rays=5, at=(-1.0, 0.0, 0.0)):
    return RV._fan(spec, at, a0, a1, reach, rays, wob="tail")


def _dorsal(spec, at, a0, a1, reach, rays):
    return RV._fan(spec, at, a0, a1, reach, rays, wob="dorsal")


def _side(spec, at, a0, a1, reach, rays, flare=-0.2):
    return RV._fan(spec, at, a0, a1, reach, rays, flare=flare, wob="fin")


def _start(spec, body):
    bpy.context.view_layer.update()
    return [body] + RV._face_eyes(spec, body)


# ------------------------------------------------------------------------------------------------ Sizzle: a hot-headed catfish
def sizzle(spec):
    def shape(co):
        x = co.x
        head = _sm((x + 0.1) / 0.8)
        tap = 1.0 if x > -0.2 else max(0.12, 1.0 - 0.8 * ((-0.2 - x) / 0.95) ** 1.5)
        return Vector((x * 1.05, co.y * (0.5 + 0.36 * head) * tap, co.z * (0.7 if co.z > 0 else 0.6) * (0.85 + 0.2 * head) * tap))
    top, belly, hot, white = hexc(spec["top"]), hexc(spec["belly"]), hexc(spec["fin2"]), hexc(spec["accent"])

    def paint(co, n):
        x, z = co.x, co.z
        c = mix(belly, top, _sm((z + 0.12) / 0.3))
        w = math.sin(x * 7.0 + z * 4.5 + math.sin(z * 9.0) * 0.6) * math.sin(z * 8.0 - x * 3.0 + 1.3)
        if abs(w) < 0.08 and z > -0.3 and not spec.get("dark"):                              # the lava cracks, hottest in the middle
            c = mix(white, hot, min(1.0, abs(w) / 0.08))
        return c
    parts = _start(spec, _blob(spec, shape, paint))
    parts += [_tail(spec, 0.7), _dorsal(spec, (-0.05, 0.0, 0.52), 64, 116, 0.42, 3), _side(spec, (0.3, -0.36, -0.2), 205, 250, 0.45, 3)]
    for s, z0, reach in ((-1, -0.04, 1.0), (1, -0.04, 0.8), (-1, -0.2, 0.85), (1, -0.2, 0.7)):      # four long whiskers
        pts = [(0.92, s * 0.3, z0), (1.25, s * 0.5, z0 + 0.04), (1.25 + 0.28 * reach, s * 0.62, z0 - 0.16 * reach), (1.25 + 0.45 * reach, s * 0.62, z0 - 0.42 * reach)]
        parts.append(_strand(spec, pts, [0.045, 0.036, 0.028, 0.016], "#3a3430", wob="whisker", k=0.7))
    flame = _mat(spec, "#ff7a1f", flat_glow=True)
    for x, h, tilt in ((0.34, 0.42, -14), (0.52, 0.6, 0), (0.7, 0.4, 14)):                      # his head's on fire
        parts.append(_still(cone(loc=(x, 0.0, 0.54 + h * 0.5), r1=0.1, r2=0.0, depth=h, rot=(0, tilt, 0), mat=flame, verts=12), "brow"))
    return parts


# ------------------------------------------------------------------------------------------------ Captain Swordbeard: a swordfish pirate
def swordbeard(spec):
    def shape(co):
        x = co.x
        tap = 1.0 if x > -0.25 else max(0.1, 1.0 - 0.9 * ((-0.25 - x) / 0.8) ** 1.4)
        return Vector((x * 1.15, co.y * 0.5 * tap, co.z * (0.62 if co.z > 0 else 0.56) * tap))
    top, belly, red = hexc(spec["top"]), hexc(spec["belly"]), hexc("#c5483a")

    def paint(co, n):
        x, z = co.x, co.z
        c = mix(belly, top, _sm((z + 0.1) / 0.28))
        if z < -0.02 and -0.7 < x < 0.75 and math.sin(x * 17.0) > 0.25 and not spec.get("dark"):                       # a stripy sailor's belly
            c = mix(c, red, 0.9)
        return c
    parts = _start(spec, _blob(spec, shape, paint))
    parts += [_tail(spec, 0.8, 135, 225, 4, at=(-1.05, 0.0, 0.0)), _dorsal(spec, (0.05, 0.0, 0.6), 70, 120, 0.7, 4), _side(spec, (0.35, -0.3, -0.25), 205, 250, 0.5, 3)]
    parts.append(_still(cone(loc=(1.58, 0.0, -0.02), r1=0.1, r2=0.012, depth=0.85, rot=(0, 90, 0), mat=_mat(spec, "#cfd8de", spec=0.5), verts=16)))     # the sword
    black, gold, white = _mat(spec, "#1c1c22"), _mat(spec, "#d9a02e", spec=0.5), _mat(spec, "#f4f1e8")
    parts.append(_still(K.cyl(loc=(0.5, 0.0, 0.64), r=0.52, depth=0.07, rot=(0, 8, 0), mat=black, verts=32, scale=(1.0, 0.85, 1.0))))      # the captain's hat
    parts.append(_still(K.cyl(loc=(0.5, 0.0, 0.8), r=0.3, depth=0.3, mat=black, verts=24)))
    parts.append(_still(K.torus(loc=(0.5, 0.0, 0.7), R=0.31, r=0.025, mat=gold, seg=32, mseg=8)))
    parts.append(_still(sphere(loc=(0.5, -0.29, 0.82), scale=(0.1, 0.03, 0.11), mat=white), k=0.4))                   # skull and
    for dx in (-0.045, 0.045):
        parts.append(_still(sphere(loc=(0.5 + dx, -0.32, 0.84), scale=0.022, mat=black), k=0.3))
    parts.append(_still(sphere(loc=(1.05, -0.16, -0.2), scale=0.05, mat=gold), k=0.4))                                # the gold tooth
    for i, (x0, dz) in enumerate(((0.85, 0.0), (0.68, -0.06), (0.5, -0.1))):                                           # the beard
        pts = [(x0, 0.0, -0.46 + dz), (x0 - 0.06, 0.0, -0.78 + dz), (x0 - 0.26, 0.0, -0.98 + dz), (x0 - 0.42, 0.0, -0.86 + dz)]
        parts.append(_strand(spec, pts, [0.07, 0.065, 0.05, 0.03], "#7a3a1a", k=0.8))
    return parts


# ------------------------------------------------------------------------------------------------ Baron von Flap: a flying fish
def baron(spec):
    def shape(co):
        x = co.x
        tap = 1.0 if x > -0.1 else max(0.12, 1.0 - 0.88 * ((-0.1 - x) / 0.95) ** 1.3)
        return Vector((x * 1.1, co.y * 0.4 * tap, co.z * (0.48 if co.z > 0 else 0.42) * tap))
    top, belly, white = hexc(spec["top"]), hexc(spec["belly"]), hexc("#ffffff")

    def paint(co, n):
        c = mix(belly, top, _sm((co.z + 0.08) / 0.22))
        return mix(c, white, 0.45) if abs(co.z - 0.04) < 0.03 else c                          # a silver stripe
    parts = _start(spec, _blob(spec, shape, paint))
    parts += [_tail(spec, 0.7, 130, 225, 4), _dorsal(spec, (-0.2, 0.0, 0.4), 70, 115, 0.3, 2)]
    parts.append(RV._fan(spec, (0.2, -0.22, 0.12), 100, 165, 1.15, 6, flare=-0.3, wob="wing"))             # the wings: a flying fish
    parts.append(RV._fan(spec, (0.2, 0.22, 0.12), 100, 165, 1.15, 6, flare=0.3, wob="wing"))
    leather, dark, gold, glass = _mat(spec, "#7a4a28"), _mat(spec, "#4a2c18"), _mat(spec, "#d9a02e", spec=0.5), _mat(spec, "#bfe6f5", spec=0.6)
    parts.append(_still(sphere(loc=(0.5, 0.0, 0.34), scale=(0.34, 0.33, 0.26), mat=leather)))                  # the flying cap
    parts.append(_still(sphere(loc=(0.42, -0.29, 0.14), scale=(0.15, 0.05, 0.17), mat=leather), k=0.6))            # an ear flap
    parts.append(_still(K.torus(loc=(0.5, 0.0, 0.5), R=0.3, r=0.025, rot=(0, 18, 0), mat=dark, seg=32, mseg=8)))
    for x in (0.56, 0.74):                                                                                       # goggles pushed up
        parts.append(_still(K.torus(loc=(x, -0.26, 0.52), R=0.085, r=0.028, rot=(90, 0, 0), mat=gold, seg=24, mseg=8), k=0.5))
        parts.append(_still(sphere(loc=(x, -0.27, 0.52), scale=(0.08, 0.012, 0.08), mat=glass), k=0.3))
    parts.append(_strand(spec, [(0.12, -0.12, 0.18), (-0.3, -0.2, 0.08), (-0.75, -0.26, 0.26), (-1.15, -0.28, 0.12)], [0.09, 0.08, 0.06, 0.045], "#f6f6f2", wob="scarf", k=0.7))
    for s in (-1, 1):                                                                                            # a waxed moustache
        parts.append(_strand(spec, [(1.0, s * 0.06, 0.0), (1.14, s * 0.2, -0.04), (1.22, s * 0.3, 0.07)], [0.04, 0.035, 0.02], "#3a2a20", wob="still", k=0.6))
    return parts


# ------------------------------------------------------------------------------------------------ Commander Chomp: a small shark, in space
def chomp(spec):
    def shape(co):
        x = co.x
        nose = 1.0 - 0.55 * max(0.0, (x - 0.35) / 0.65) ** 1.5
        tap = 1.0 if x > -0.15 else max(0.15, 1.0 - 0.85 * ((-0.15 - x) / 0.9) ** 1.4)
        return Vector((x * 1.1, co.y * 0.52 * nose * tap, co.z * (0.55 if co.z > 0 else 0.5) * nose * tap))
    top, belly, dark = hexc(spec["top"]), hexc(spec["belly"]), hexc("#27394a")

    def paint(co, n):
        c = mix(belly, top, _sm((co.z + 0.05) / 0.22))
        return c
    parts = _start(spec, _blob(spec, shape, paint))
    parts += [_tail(spec, 0.8, 120, 215, 4), _dorsal(spec, (0.0, 0.0, 0.5), 60, 112, 0.75, 2), _side(spec, (0.3, -0.3, -0.2), 215, 262, 0.7, 2, flare=-0.3)]
    steel, tank, fire = _mat(spec, "#c7d0d8", spec=0.5), _mat(spec, "#e5533d", spec=0.3), _mat(spec, "#ffb52e", flat_glow=True)
    for y in (-0.16, 0.16):                                                                                      # the jetpack
        parts.append(_still(K.cyl(loc=(-0.42, y, 0.62), r=0.09, depth=0.5, rot=(0, 78, 0), mat=tank, verts=16)))
        parts.append(_still(cone(loc=(-0.78, y, 0.55), r1=0.07, r2=0.0, depth=0.32, rot=(0, -90, 0), mat=fire, verts=12)))
    if not spec.get("dark"):
        glass_m = toon("#d8f3ff", alpha=0.22, rim=0.8, key="outlawglass")
        glass_m.use_backface_culling = True
        c, R, back = Vector((0.58, 0.0, 0.1)), 0.62, 0.22
        glass = sphere(loc=c, scale=R, seg=48, rings=24, mat=glass_m)
        bm = bmesh.new()
        bm.from_mesh(glass.data)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=((back - c.x) / R, 0.0, 0.0), plane_no=(1.0, 0.0, 0.0), clear_inner=True)
        bm.to_mesh(glass.data)
        bm.free()
        glass["no_outline"] = True                                                      # (the mini-game's eye-finder ignores glass: it's no eye)
        glass["decal"] = True
        parts.append(_still(glass))
        parts.append(_still(K.torus(loc=(back, 0.0, c.z), R=math.sqrt(R * R - (back - c.x) ** 2), r=0.06, rot=(0, 90, 0), mat=steel, seg=48), k=0.8))
        parts.append(_strand(spec, [(0.58, 0.0, 0.66), (0.58, 0.0, 1.0)], [0.025, 0.02], "#c7d0d8", wob="still", k=0.6))      # an antenna with a flag
        parts.append(_still(K.cube(loc=(0.68, 0.0, 0.96), scale=(0.2, 0.02, 0.13), mat=_mat(spec, "#e5533d")), k=0.5))
    return parts


# ------------------------------------------------------------------------------------------------ Zlorp: an alien blobfish
def zlorp(spec):
    def shape(co):
        x, z = co.x, co.z
        tap = 1.0 if x > -0.3 else max(0.2, 1.0 - 0.75 * ((-0.3 - x) / 0.65) ** 1.4)
        return Vector((x * 0.98, co.y * 0.82 * tap, (z * 0.74 if z > 0 else z * 0.66 * (1.0 + 0.15 * math.sin(x * 4.0))) * tap))
    top, belly, green = hexc(spec["top"]), hexc(spec["belly"]), hexc(spec["accent"])

    def paint(co, n):
        c = mix(belly, top, _sm((co.z + 0.1) / 0.4))
        if math.sin(co.x * 13.0) * math.sin(co.z * 13.0 + 1.0) > 0.82 and co.z > -0.2 and not spec.get("dark"):                # glowing spots
            c = mix(c, green, 0.9)
        return c
    parts = _start(spec, _blob(spec, shape, paint))
    parts += [_tail(spec, 0.5, 145, 215, 3, at=(-0.9, 0.0, -0.1)), _side(spec, (0.3, -0.45, -0.25), 205, 250, 0.35, 2, flare=-0.15)]
    parts.append(_still(sphere(loc=(0.98, 0.0, -0.12), scale=(0.3, 0.26, 0.22), mat=_mat(spec, "#e0a0d8"))))               # that blobfish nose
    white, ink = _mat(spec, "#ffffff"), _mat(spec, "#18121f")
    for x, y, tip in ((0.2, -0.16, (0.08, -0.2, 1.1)), (0.42, 0.14, (0.5, 0.18, 1.0))):                                  # two more eyes, on stalks
        parts.append(_still(RV._strand([(x, y, 0.5), ((x + tip[0]) / 2, y * 1.2, 0.8), tip], [0.05, 0.045, 0.04], _mat(spec, spec["fin"]), wob="still", k=0.7)))
        parts.append(_still(sphere(loc=tip, scale=0.14, mat=white), k=0.7))
        parts.append(_still(sphere(loc=(tip[0] + 0.07, tip[1] - 0.09, tip[2] - 0.02), scale=0.06, mat=ink), k=0.3))
    for x, h in ((0.55, 1.0), (0.3, 1.3), (0.05, 1.1), (-0.2, 0.8)):                                                     # and tentacles
        pts = [(x, -0.1, -0.5), (x - 0.05, -0.12, -0.5 - 0.35 * h), (x + 0.1, -0.1, -0.5 - 0.6 * h), (x, -0.08, -0.5 - 0.8 * h)]
        parts.append(_strand(spec, pts, [0.06, 0.055, 0.045, 0.03], spec["fin2"], k=0.8))
    return parts


# ------------------------------------------------------------------------------------------------ The Duchess: an anglerfish lady
def duchess(spec):
    def shape(co):
        x, z = co.x, co.z
        jaw = _sm((-z - 0.1) / 0.5) * _sm((x - 0.1) / 0.6)
        tap = 1.0 if x > -0.25 else max(0.18, 1.0 - 0.8 * ((-0.25 - x) / 0.8) ** 1.3)
        return Vector((x * 1.02 + 0.22 * jaw, co.y * 0.78 * tap, (z * 0.8 if z > 0 else z * 0.72) * tap))
    top, belly, glow = hexc(spec["top"]), hexc(spec["belly"]), hexc("#9fe8ff")

    def paint(co, n):
        c = mix(belly, top, _sm((co.z + 0.05) / 0.5))
        if math.sin(co.x * 17.0 + co.z * 3.0) * math.sin(co.z * 15.0) > 0.85 and co.z > 0 and not spec.get("dark"):            # bioluminescent freckles
            c = mix(c, glow, 0.9)
        return c
    body = _blob(spec, shape, paint)
    parts = _start(spec, body)
    parts += [_tail(spec, 0.8, 140, 220, 6, at=(-0.95, 0.0, 0.0)), _side(spec, (0.2, -0.6, -0.1), 200, 250, 0.7, 5, flare=-0.3), _dorsal(spec, (-0.3, 0.0, 0.68), 70, 120, 0.5, 4)]
    parts.append(_strand(spec, [(0.35, 0.0, 0.72), (0.5, 0.0, 1.12), (0.95, 0.0, 1.32), (1.3, 0.0, 1.1)], [0.05, 0.04, 0.035, 0.03], spec["fin"], wob="still", k=0.7))   # the lure
    gold, bulb = _mat(spec, "#d9a02e", spec=0.6), _mat(spec, "#fff2a8", flat_glow=True)
    parts.append(_still(cone(loc=(1.3, 0.0, 1.04), r1=0.04, r2=0.17, depth=0.14, mat=gold, verts=20)))               # a little chandelier
    for i in range(6):
        a = i / 6.0 * math.tau
        parts.append(_still(sphere(loc=(1.3 + 0.17 * math.cos(a), 0.17 * math.sin(a), 1.13), scale=0.045, mat=bulb), k=0.3))
    pearl = _mat(spec, "#fbf6ec", spec=0.5, rim=0.25)
    for i in range(11):                                                                                           # her pearls
        t = i / 10.0
        x, z = 0.0 + 0.3 * math.sin(math.pi * t) ** 0.8, 0.35 - 0.95 * t
        parts.append(_still(ico(loc=(x, RV._near(body, x, z) - 0.03, z), scale=0.062, mat=pearl, sub=3, smooth=True), k=0.45))
    tooth = _mat(spec, "#f6f1e6", spec=0.3)
    for x in (0.72, 0.86, 1.0, 1.14):                                                                             # a few fangs
        parts.append(_still(cone(loc=(x, -0.18, -0.33), r1=0.04, r2=0.0, depth=0.15, mat=tooth, verts=10), k=0.4))
    lips = _mat(spec, "#d93a63", spec=0.4)
    parts.append(_still(sphere(loc=(1.1, -0.04, -0.18), scale=(0.16, 0.22, 0.06), mat=lips), k=0.5))                    # lipstick
    parts.append(_still(sphere(loc=(1.2, -0.04, -0.42), scale=(0.16, 0.22, 0.07), mat=lips), k=0.5))
    return parts


BUILD = {"sizzle": sizzle, "swordbeard": swordbeard, "baron": baron, "chomp": chomp, "zlorp": zlorp, "duchess": duchess}


def build(spec):
    return BUILD[spec["outlaw"]](spec)

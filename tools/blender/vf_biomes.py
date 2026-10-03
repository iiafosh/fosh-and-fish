"""Biome backdrops (1600x900). The boat is composited in Godot, so each
scene leaves the centre-lower area as open water.
"""
import math
import random

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

import vf_kit as K
from vf_kit import cone, cube, cyl, deform, hexc, ico, sphere, toon, torus, tube

W, H = 1600, 900

BIOMES = {
    "River": dict(sky=[(0, "#d9f1ff"), (0.35, "#9fd4f5"), (1, "#4f9fe0")], fog="#cfeaf7",
                  water=("#1f7f9e", "#7fc6dc", "#e6fbff"), ambient="#7a8290", sun=(55, 0, 30), sun_col="#fff6e0"),
    "Volcanic": dict(sky=[(0, "#ffb36b"), (0.3, "#d4573a"), (1, "#3a1230")], fog="#e98a5a",
                     water=("#3a0d0a", "#a2301a", "#ffb84d"), ambient="#7a5a5a", sun=(70, 0, 160), sun_col="#ffd0a0"),
    "Ocean": dict(sky=[(0, "#eaf8ff"), (0.3, "#a9dcff"), (1, "#2f7fe0")], fog="#d6efff",
                  water=("#0b4f9e", "#3aa0e0", "#ffffff"), ambient="#7a8494", sun=(50, 0, 40), sun_col="#ffffff"),
    "Sky": dict(sky=[(0, "#ffe6f2"), (0.4, "#d6c8ff"), (1, "#8ab0ff")], fog="#fbe8f6",
                water=("#cfc6ff", "#f2eaff", "#ffffff"), ambient="#8a86a0", sun=(45, 0, 20), sun_col="#fff0f6"),
    "Space": dict(sky=[(0, "#4a2a8a"), (0.25, "#1a1040"), (1, "#05030f")], fog="#3a2470", stars=1.0,
                  water=("#1a0f4a", "#5a3ad0", "#d8c8ff"), ambient="#5a5080", sun=(60, 0, 120), sun_col="#d8d0ff"),
    "Alien": dict(sky=[(0, "#9affd8"), (0.3, "#3aa08a"), (1, "#2a0f4a")], fog="#7ae6c4", stars=0.4,
                  water=("#06402e", "#14a070", "#b8ffd8"), ambient="#5a7a70", sun=(55, 0, 200), sun_col="#e0ffe8"),
    "Abyss": dict(sky=[(0, "#1a3060"), (0.3, "#0a1230"), (1, "#020208")], fog="#14244a", stars=0.25,
                  water=("#020812", "#0c2a52", "#5ff2ff"), ambient="#3a4660", sun=(65, 0, 90), sun_col="#9fb8ff"),
}


def water_material(near, far, streak, glow=0.0):
    m = bpy.data.materials.new("water")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    cd = nt.nodes.new("ShaderNodeCameraData")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 10.0
    mr.inputs["From Max"].default_value = 260.0
    nt.links.new(cd.outputs["View Z Depth"], mr.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    K._ramp_stops(ramp.color_ramp, [(0.0, near), (1.0, far)])
    ramp.color_ramp.interpolation = "EASE"
    pw = nt.nodes.new("ShaderNodeMath")
    pw.operation = "POWER"
    pw.inputs[1].default_value = 0.55
    nt.links.new(mr.outputs[0], pw.inputs[0])
    nt.links.new(pw.outputs[0], ramp.inputs[0])
    # stylised wave streaks: stretched noise, hard threshold
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (0.09, 0.5, 1.0)
    nt.links.new(geo.outputs["Position"], mp.inputs["Vector"])
    nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = 1.6
    nz.inputs["Detail"].default_value = 3.0
    nt.links.new(mp.outputs[0], nz.inputs["Vector"])
    th = nt.nodes.new("ShaderNodeMapRange")
    th.interpolation_type = "STEPPED"
    th.inputs["Steps"].default_value = 1.0
    th.inputs["From Min"].default_value = 0.66
    th.inputs["From Max"].default_value = 0.70
    nt.links.new(nz.outputs["Fac"], th.inputs["Value"])
    fade = nt.nodes.new("ShaderNodeMath")
    fade.operation = "MULTIPLY"
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 0.9
    nt.links.new(mr.outputs[0], inv.inputs[1])
    nt.links.new(th.outputs[0], fade.inputs[0])
    nt.links.new(inv.outputs[0], fade.inputs[1])
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    nt.links.new(fade.outputs[0], mx.inputs[0])
    nt.links.new(ramp.outputs[0], mx.inputs[6])
    mx.inputs[7].default_value = hexc(streak)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[1].default_value = 1.0 + glow
    nt.links.new(mx.outputs[2], em.inputs[0])
    nt.links.new(em.outputs[0], out.inputs[0])
    return m


def water_plane(cfg, glow=0.0):
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    p = bpy.context.active_object
    p.scale = (1600, 900, 1)
    p.location = (0, 430, 0)
    near, far, streak = cfg["water"]
    p.data.materials.append(water_material(near, far, streak, glow))
    p["no_outline"] = True
    return p


# ------------------------------------------------------------------ props
def cloud(loc, s=1.0, color="#ffffff", shade=0.8):
    parts = []
    rnd = random.Random(int(loc[0] * 7 + loc[1] * 3))
    for i in range(7):
        parts.append(ico(loc=(loc[0] + rnd.uniform(-2.2, 2.2) * s, loc[1] + rnd.uniform(-0.6, 0.6) * s,
                              loc[2] + rnd.uniform(0, 0.9) * s), scale=rnd.uniform(1.0, 1.8) * s, sub=2,
                         mat=toon(color, shade=shade, rim=0.0)))
    for p in parts:
        p["no_outline"] = True
    return parts


def pine(loc, s=1.0, col="#2f7a4a"):
    out = [cyl(loc=(loc[0], loc[1], loc[2] + 0.6 * s), r=0.18 * s, depth=1.2 * s, mat=toon("#6b4a2e"), verts=6, smooth=False)]
    for i, (r, z) in enumerate([(1.1, 1.4), (0.85, 2.3), (0.6, 3.1)]):
        out.append(cone(loc=(loc[0], loc[1], loc[2] + z * s), r1=r * s, r2=0.0, depth=1.3 * s, verts=7,
                        mat=toon(col), smooth=False))
    return out


def palm(loc, s=1.0):
    base = Vector(loc)
    top = base + Vector((0.8 * s, 0, 4.2 * s))
    out = [tube([base, base + Vector((0.1 * s, 0, 2.0 * s)), top], 0.18 * s, mat=toon("#9a6a3c"), taper=(1.0, 0.7))]
    for i in range(6):
        a = i / 6 * math.tau
        tip = top + Vector((math.cos(a) * 2.0 * s, math.sin(a) * 2.0 * s, -0.9 * s))
        mid = top + Vector((math.cos(a) * 1.1 * s, math.sin(a) * 1.1 * s, 0.35 * s))
        out.append(tube([top, mid, tip], 0.22 * s, mat=toon("#3fa34a"), taper=(1.0, 0.1), res=6))
    return out


def hill(loc, sx, sy, sz, col):
    h = ico(loc=loc, scale=(sx, sy, sz), sub=2, mat=toon(col, shade=0.75, rim=0.0))
    return h


def mountain(loc, r, h, col, snow=None):
    out = [cone(loc=(loc[0], loc[1], loc[2] + h / 2), r1=r, r2=0.0, depth=h, verts=7, mat=toon(col, rim=0.0), smooth=False)]
    if snow:
        out.append(cone(loc=(loc[0], loc[1], loc[2] + h * 0.82), r1=r * 0.37, r2=0.0, depth=h * 0.37, verts=7,
                        mat=toon(snow, rim=0.0), smooth=False))
    return out


def island(loc, r, col_top="#4fae55", col_side="#e8d29a"):
    out = [cyl(loc=(loc[0], loc[1], loc[2] + 0.3), r=r, depth=0.9, verts=9, mat=toon(col_side), smooth=False)]
    out.append(ico(loc=(loc[0], loc[1], loc[2] + 0.7), scale=(r * 0.85, r * 0.85, r * 0.35), sub=1, mat=toon(col_top)))
    return out


def floating_island(loc, r):
    out = [cone(loc=(loc[0], loc[1], loc[2] - r * 0.9), r1=r, r2=0.0, depth=r * 1.8, rot=(0, 0, 0), verts=8,
                mat=toon("#8a6a5a"), smooth=False)]
    out[0].rotation_euler = (math.pi, 0, 0)
    out.append(cyl(loc=(loc[0], loc[1], loc[2]), r=r * 1.02, depth=r * 0.35, verts=8, mat=toon("#6fd16a"), smooth=False))
    for i in range(3):
        out += pine((loc[0] + (i - 1) * r * 0.45, loc[1] + (i % 2) * r * 0.3, loc[2] + r * 0.15), s=r * 0.18,
                    col="#2f9a5a")
    fall = cube(loc=(loc[0] + r * 0.7, loc[1] - r * 0.4, loc[2] - r * 1.4), scale=(r * 0.18, 0.05, r * 2.6),
                mat=toon("#cfefff", flat_glow=True, alpha=0.8))
    fall["no_outline"] = True
    out.append(fall)
    return out


def planet(loc, r, col, ring=None):
    out = [sphere(loc=loc, scale=r, mat=toon(col, rim=0.25), seg=48, rings=24)]
    if ring:
        t = torus(loc=loc, R=r * 1.7, r=r * 0.08, rot=(72, 0, 18), mat=toon(ring, emit=0.3), scale=(1, 1, 0.15), seg=64)
        out.append(t)
    return out


def crystal(loc, h, col):
    c = cone(loc=(loc[0], loc[1], loc[2] + h / 2), r1=h * 0.16, r2=0.0, depth=h, verts=5, mat=toon(col, emit=0.45, spec=0.4),
             smooth=False)
    c.rotation_euler = (random.uniform(-0.15, 0.15), random.uniform(-0.15, 0.15), random.uniform(0, 3))
    return c


def mushroom(loc, s, stem="#e6d6ff", cap="#c77dff"):
    return [cyl(loc=(loc[0], loc[1], loc[2] + 1.0 * s), r=0.22 * s, depth=2.0 * s, mat=toon(stem)),
            sphere(loc=(loc[0], loc[1], loc[2] + 2.0 * s), scale=(1.1 * s, 1.1 * s, 0.5 * s), mat=toon(cap, emit=0.3))]


def godray(x, y, w, col):
    c = cone(loc=(x, y, 30), r1=w, r2=w * 0.25, depth=70, mat=toon(col, flat_glow=True, alpha=0.05), verts=12)
    c.rotation_euler = (0, math.radians(8), 0)
    c["no_outline"] = True
    return c


def sun_disc(loc, r, col, alpha=1.0):
    s = sphere(loc=loc, scale=r, mat=toon(col, flat_glow=True, alpha=alpha))
    s["no_outline"] = True
    return s


# ------------------------------------------------------------------ biomes
def build(name, cfg):
    rnd = random.Random(42)
    random.seed(42)
    P = []
    if name == "River":
        P.append(water_plane(cfg))
        for side in (-1, 1):
            for i in range(14):
                y = 18 + i * 14
                x = side * (16 + i * 1.6 + rnd.uniform(0, 3))
                P.append(hill((x + side * 10, y, -1.5), 14, 9, 3.5 + rnd.uniform(0, 2), "#5fae4f" if i % 2 else "#6dbb5a"))
                for k in range(2):
                    P += pine((x + side * rnd.uniform(1, 7), y + rnd.uniform(-4, 4), 1.2), s=rnd.uniform(1.0, 1.6))
            P.append(cube(loc=(side * 13.5, 60, 0.05), scale=(1.2, 200, 0.4), mat=toon("#d8c08a", rim=0.0)))
        for i, x in enumerate([-120, -60, 0, 70, 140]):
            P += mountain((x, 380, -2), 55 + rnd.uniform(0, 20), 70 + rnd.uniform(0, 25), "#7a9cb8", "#f2f6fa")
        for x, y, z, s in [(-40, 160, 34, 4), (30, 200, 46, 5), (90, 240, 52, 6), (-110, 260, 60, 6)]:
            P += cloud((x, y, z), s)
        for i in range(6):
            P.append(ico(loc=(rnd.uniform(-10, 10), rnd.uniform(14, 40), 0.1), scale=(0.6, 0.6, 0.25), sub=1,
                         mat=toon("#3f8f4a")))
    elif name == "Volcanic":
        P.append(water_plane(cfg, glow=0.1))
        R0, RT, VH, VY = 62.0, 11.0, 58.0, 300.0
        P.append(cone(loc=(10, VY, VH / 2 - 3), r1=R0, r2=RT, depth=VH, verts=9, mat=toon("#3a2626", rim=0.0), smooth=False))
        crater = cyl(loc=(10, VY, VH - 2.6), r=RT * 0.85, depth=1.2, verts=9, mat=toon("#ffb21f", flat_glow=True), smooth=False)
        crater["no_outline"] = True
        P.append(crater)
        for k in range(5):
            a = math.radians(-50 + k * 25)
            pts = []
            for j in range(4):
                z = (VH - 4) * (1 - j / 3.0)
                rad = R0 - (R0 - RT) * (z + 3) / VH + 0.6
                wob = math.sin(j * 1.7 + k) * 0.08
                pts.append((10 + math.sin(a + wob) * rad, VY - math.cos(a + wob) * rad, z - 2))
            lava = tube(pts, 1.4 - k * 0.1, mat=toon("#ff8a1f", flat_glow=True), taper=(1.0, 0.7))
            lava["no_outline"] = True
            P.append(lava)
        for x, y, z, s in [(8, 305, 66, 6), (22, 312, 74, 8), (-6, 318, 80, 9)]:
            P += cloud((x, y, z), s, color="#4a3a42", shade=0.6)
        for x in (-150, -95, 120, 175):
            P += mountain((x, 380, -3), 45, 48 + abs(x) * 0.05, "#2e1f22")
        for side in (-1, 1):
            for i in range(8):
                P.append(ico(loc=(side * (30 + i * 9 + rnd.uniform(0, 6)), 40 + i * 20, 0), scale=(6, 5, 3 + rnd.uniform(0, 4)),
                             sub=1, mat=toon("#2a1c1c")))
        for i in range(80):
            e = ico(loc=(rnd.uniform(-70, 70), rnd.uniform(25, 160), rnd.uniform(1, 35)), scale=0.2, sub=1,
                    mat=toon("#ffb84d", flat_glow=True))
            e["no_outline"] = True
            P.append(e)
        P.append(sun_disc((-110, 650, 70), 26, "#ffcf8a", 0.55))
    elif name == "Ocean":
        P.append(water_plane(cfg))
        P += island((-70, 220, -0.3), 14)
        P += palm((-72, 220, 0.8), 2.2) + palm((-64, 222, 0.8), 1.7)
        P += island((85, 300, -0.3), 20)
        P += palm((84, 300, 0.8), 2.6)
        P.append(cyl(loc=(95, 298, 9), r=2.2, depth=18, verts=10, mat=toon("#ffffff")))
        for k in range(3):
            band = cyl(loc=(95, 298, 3 + k * 6), r=2.25, depth=1.8, verts=10, mat=toon("#e0322b"))
            P.append(band)
        P.append(cyl(loc=(95, 298, 19.5), r=2.6, depth=3, verts=10, mat=toon("#fff2a0", flat_glow=True)))
        for x, y, z, s in [(-60, 180, 30, 6), (20, 230, 48, 8), (110, 260, 40, 7), (-130, 300, 70, 9), (60, 330, 90, 10)]:
            P += cloud((x, y, z), s)
        for i in range(5):
            gx, gz = rnd.uniform(-40, 40), rnd.uniform(14, 30)
            g = tube([(gx - 1.2, 60, gz + 0.6), (gx, 60, gz), (gx + 1.2, 60, gz + 0.6)], 0.15, mat=toon("#ffffff"))
            P.append(g)
        P.append(sun_disc((-160, 700, 160), 40, "#fffbe0"))
    elif name == "Sky":
        P.append(water_plane(cfg))
        for i in range(40):
            x = rnd.uniform(-160, 160)
            y = rnd.uniform(20, 360)
            P += cloud((x, y, -1.5), rnd.uniform(3, 7) * (0.6 + y / 300), color="#ffffff", shade=0.86)
        P += floating_island((-55, 140, 30), 10)
        P += floating_island((70, 200, 48), 13)
        P += floating_island((-15, 300, 70), 9)
        P.append(sun_disc((60, 700, 150), 55, "#fff0b0"))
        for i in range(3):
            rb = torus(loc=(-120, 500, 0), R=140 + i * 8, r=3, rot=(90, 0, 0), mat=toon(["#ff8a8a", "#ffe68a", "#8ad0ff"][i],
                                                                                         flat_glow=True, alpha=0.35), seg=64)
            rb["no_outline"] = True
            P.append(rb)
    elif name == "Space":
        P.append(water_plane(cfg, glow=0.2))
        P += planet((-95, 430, 80), 52, "#d47a4a", ring="#f2c48a")
        P += planet((110, 300, 70), 22, "#4f7dff")
        P += planet((40, 240, 110), 8, "#c9c9d6")
        for i in range(40):
            a = ico(loc=(rnd.uniform(-120, 120), rnd.uniform(60, 300), rnd.uniform(8, 80)), scale=rnd.uniform(0.6, 3.5), sub=1,
                    mat=toon("#6a5a7a"))
            P.append(a)
        for x, y, z, s, c in [(-40, 500, 200, 40, "#ff4fb0"), (80, 520, 160, 50, "#4fb3ff")]:
            n = sphere(loc=(x, y, z), scale=(s, s * 0.3, s * 0.6), mat=toon(c, flat_glow=True, alpha=0.18))
            n["no_outline"] = True
            P.append(n)
    elif name == "Alien":
        P.append(water_plane(cfg, glow=0.15))
        P += planet((-80, 500, 105), 34, "#f2e6ff")
        P += planet((70, 520, 120), 18, "#ffcf8a")
        for side in (-1, 1):
            for i in range(10):
                x = side * (22 + i * 7 + rnd.uniform(0, 8))
                y = 30 + i * 20
                P.append(ico(loc=(x, y, -1), scale=(10, 8, 3), sub=1, mat=toon("#3d2a66")))
                for k in range(3):
                    P.append(crystal((x + rnd.uniform(-4, 4), y + rnd.uniform(-3, 3), 0.5), rnd.uniform(5, 16),
                                     ["#c77dff", "#7dffcf", "#5ff2ff"][k]))
                if i % 2 == 0:
                    P += mushroom((x - side * 3, y, 0.5), rnd.uniform(2.0, 3.5),
                                  cap=["#c77dff", "#7dff9a"][i % 4 // 2])
        for i in range(30):
            o = ico(loc=(rnd.uniform(-60, 60), rnd.uniform(30, 150), rnd.uniform(4, 50)), scale=0.3, sub=1,
                    mat=toon("#b8ff6a", flat_glow=True))
            o["no_outline"] = True
            P.append(o)
    elif name == "Abyss":
        P.append(water_plane(cfg, glow=0.2))
        for i in range(6):
            P.append(godray(rnd.uniform(-90, 90), rnd.uniform(160, 320), rnd.uniform(2.5, 5), "#5ff2ff"))
        for side in (-1, 1):
            for i in range(7):
                x = side * (26 + i * 10)
                y = 50 + i * 30
                h = rnd.uniform(14, 30)
                P.append(cyl(loc=(x, y, h / 2 - 2), r=2.4, depth=h, verts=8, mat=toon("#26304a"), smooth=False))
                P.append(cube(loc=(x, y, h - 1.5), scale=(7, 7, 1.5), mat=toon("#2e3a58")))
                for k in range(3):
                    kelp = tube([(x + k * 2 - 2, y - 4, -1), (x + k * 2 - 1, y - 4, 4), (x + k * 2 - 3, y - 4, 9)], 0.4,
                                mat=toon("#5ff2ff", emit=0.6), taper=(1.0, 0.2))
                    P.append(kelp)
        for i in range(90):
            o = ico(loc=(rnd.uniform(-80, 80), rnd.uniform(20, 200), rnd.uniform(1, 60)), scale=rnd.uniform(0.12, 0.35), sub=1,
                    mat=toon(["#5ff2ff", "#c77dff", "#9fffd0"][i % 3], flat_glow=True))
            o["no_outline"] = True
            P.append(o)
        # ribcage of something enormous
        for i in range(6):
            rib = tube([(-30 + i * 9, 260, -2), (-34 + i * 9, 262, 30), (-20 + i * 9, 266, 44)], 1.6,
                       mat=toon("#cfc6b0", rim=0.0), taper=(1.0, 0.4))
            P.append(rib)
    return P


def render_biome(name, path):
    cfg = BIOMES[name]
    K.clear_scene()
    K.setup_render(W, H, samples=32, transparent=False)
    K.setup_world(cfg["ambient"], 1.0, sky=cfg["sky"], stars=cfg.get("stars", 0.0))
    K.sun(cfg["sun"], 1.0, cfg["sun_col"])
    K.FOG.update({"color": cfg["fog"], "start": 40.0, "end": 420.0, "amount": 0.82})
    cam = K.make_camera((86.2, 0, 0), ortho=False, lens=30)
    cam.location = (0, -6, 4.2)
    parts = build(name, cfg)
    K.outline_all([p for p in parts], 0.12)
    bpy.context.view_layer.update()
    sc = bpy.context.scene
    hz = world_to_camera_view(sc, cam, Vector((0, 5000, 0)))
    K.render(path)
    K.FOG.update({"color": None, "amount": 0.0})
    return {"horizon": round(1.0 - hz.y, 4), "accent": cfg["water"][2], "water_near": cfg["water"][0],
            "water_far": cfg["water"][1], "fog": cfg["fog"]}

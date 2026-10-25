"""1.0 art, rendered like the rest (Eevee, cel-shaded, inverted-hull outlines):
shiny fish, event fish, the Pearl, the Event Star and the Supporter Pack icons. The exclusive rods
(Starfall, Pearl, Legend) are vf_models.ROD_SPECS entries, rendered by render_assets.py (rods, rods_hand).

Built from the game's own models (vf_models fish and rods, vf_props chests and crown) so it matches
the other icons, plus an already-made pack where one fits: the Leviathan is Quaternius' Animated Fish
whale (CC0, scratch/downloads/glb, see CREDITS.md), recoloured.

  blender -b --factory-startup --python tools/blender/render_v1.py -- [shiny event ui packs] [--only NAME,...]

Output (256 px, transparent): assets/vf/shiny/<fish>.png, assets/vf/event/<fish>.png,
assets/vf/ui/pearl.png + star.png, assets/vf/packs/<pack id>.png
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import vf_kit as K  # noqa: E402
import vf_models as M  # noqa: E402
import vf_props as P  # noqa: E402
import vf_vendor as V  # noqa: E402
from vf_kit import cone, cube, cyl, extrude_poly, sphere, toon, torus, tube  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "vf")
SIZE = 256
CAM = (76, 0, 20)               # the fish icons' view
GOLD_LINE = "#8a5a00"           # shinies get a gold outline


def slug(name):
    return name.lower().replace(" ", "_").replace(".", "")


def scene(rot=CAM, light=(48, 8, 40)):
    K.clear_scene()
    V.clear_library()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    K.FOG["color"] = None
    K.setup_render(SIZE, SIZE, samples=24)
    K.setup_world("#6a6a78", 1.0)
    K.sun(light, 1.0)
    return K.make_camera(rot)


def shoot(parts, path, outline=0.035, color=K.OUTLINE, margin=1.15):
    K.outline_all(parts, outline, color)
    K.frame_ortho(bpy.context.scene.camera, parts, margin)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    K.render(path)
    print("rendered", os.path.relpath(path, ROOT), flush=True)


def vendor(path, tints=None):
    """import a glTF model, cel-shaded (tints: material name -> colour)"""
    meshes, arm, roots = V.import_glb(path)
    root = V.group_root(roots)
    for m in meshes:
        for i, mt in enumerate(m.data.materials):
            if mt is None:
                continue
            mt = mt.copy()
            m.data.materials[i] = mt
            V.toonify(mt, tint=(tints or {}).get(mt.name.split(".")[0]))
    return meshes, arm, root


def vendor_outline(meshes, t, color=K.OUTLINE):
    """imported models come scaled, so their outline is set in world units (and shoot() leaves them be)"""
    for m in meshes:
        m["outline_even"] = False
        K.add_outline(m, t / max(m.matrix_world.to_scale()), color)
        m["no_outline"] = True


def twinkles(parts, color="#fff3b0", spots=((0.9, 0.98, 0.2), (0.06, 0.82, 0.13), (0.58, 0.0, 0.1))):
    """big 4-point glints around a model, facing the camera: (x, z) in its bounding box (0..1), size"""
    cam = bpy.context.scene.camera
    back = cam.rotation_euler.to_matrix() @ Vector((0, 0, 1))
    lo, hi = V.world_bbox([p for p in parts if p.type == "MESH"])
    out = []
    for fx, fz, s in spots:
        p = Vector((lo.x + (hi.x - lo.x) * fx, (lo.y + hi.y) / 2, lo.z + (hi.z - lo.z) * fz)) + back * 2.0
        t = extrude_poly(M.star_pts(s, s * 0.24, 4), 0.01, mat=toon(color, flat_glow=True))
        t.location = p
        t.rotation_euler = cam.rotation_euler.copy()
        t["no_outline"] = True
        out.append(t)
    return out


# ------------------------------------------------------------------ shinies
# hand-picked alternate colours, like shinies elsewhere; fins turn gold unless given
SHINY = {
    "Raw Fish":         dict(top="#e8b923", belly="#fff4c9", fin="#ff8a3d"),
    "Raw Salmon":       dict(top="#3fa7d6", belly="#dff4ff", spots="#1f5f8a"),
    "Cod":              dict(top="#d94f8a", belly="#ffe0ee", spots="#8a1f52"),
    "Tropical Fish":    dict(top="#2e86de", belly="#e3f2ff"),
    "Pufferfish":       dict(top="#2ecc71", belly="#dcffe9", spike="#fff7c2"),
    "Fiery Pufferfish": dict(top="#3b82f6", belly="#d6e7ff", spike="#c7f9ff"),
    "Hot Cod":          dict(top="#7c3aed", belly="#eadcff", glow_line="#5ff2ff"),
    "Squid":            dict(top="#34d399", belly="#d7fbe9"),
    "Turtle":           dict(top="#3b82f6", belly="#fde68a"),
    "Dolphin":          dict(top="#f472b6", belly="#ffe4f2"),
    "Guardian":         dict(top="#7c3aed", belly="#ffd23f"),
    "Emerald Squid":    dict(top="#ef4444", belly="#ffd5d5"),
    "Rainbow Fish":     dict(top="#f2b705", belly="#fff3c4", spots="#ff8a1f", fin="#ff7a2f", rainbow=False, metal=True),
    "Space Fish":       dict(top="#0f766e", belly="#5eead4"),
    "Galactic Crab":    dict(top="#dc2626", belly="#ffb3b3"),
    "Shark":            dict(top="#1e40af", belly="#e0ebff"),
    "Alien Fish":       dict(top="#f43f5e", belly="#ffe4e8"),
    "Artifact Fish":    dict(top="#94a3b8", belly="#f1f5f9", runes="#ff5ad1"),
    "Dark Puffer":      dict(top="#e8edf5", belly="#ffffff", spike="#ffd23f"),
    "Dark Tuna":        dict(top="#7f1d1d", belly="#ffb4b4", glow_line="#ffd23f"),
}


def shiny_spec(name, spec):
    sp = dict(spec, fin="#ffcf3a")
    sp.update(SHINY[name])
    return sp


def do_shiny(only):
    for name, spec in M.FISH_SPECS.items():
        if only and slug(name) not in only:
            continue
        scene()
        random.seed(7)
        parts = M.build_fish(shiny_spec(name, spec))
        parts += twinkles(parts)
        shoot(parts, os.path.join(OUT, "shiny", slug(name) + ".png"), 0.04, GOLD_LINE)


# --------------------------------------------------------------- event fish
EVENT_SPECS = {
    "Golden Koi":     dict(top="#f0a000", belly="#ffd95e", fin="#ff7a2f", L=1.15, H=0.5, W=0.26, spots="#ff4a1a",
                           metal=True, sail=True, barbel=True),
    "Frenzy Piranha": dict(top="#3b4a6b", belly="#ff3b3b", fin="#2b3754", L=0.95, H=0.7, W=0.3, spots="#7d8bb0"),
    "Meteor Fish":    dict(top="#2b1d5c", belly="#ff9f45", fin="#ffd23f", L=1.0, H=0.48, W=0.24, stars=True, flames=True,
                           glow_line="#ffd23f", glow_fin=True),
}


def piranha_jaw(spec):
    """an underbite full of teeth"""
    L, H, W = spec["L"], spec["H"], spec["W"]
    jaw = cube(loc=(L * 0.84, 0, -H * 0.24), scale=(0.42, W * 1.1, 0.12), mat=toon(spec["belly"]), bevel=0.02)
    out = [jaw]
    white = toon("#ffffff", rim=0.0)
    for k in range(4):
        y = W * 0.42 * (k / 1.5 - 1.0)
        t = cone(loc=(L * 0.84 + 0.17, y, -H * 0.24 + 0.1), r1=0.045, r2=0.0, depth=0.12, mat=white, verts=6, smooth=False)
        t["outline_k"] = 0.5
        out.append(t)
    return out


def leviathan():
    """Quaternius' whale in boss colours, breaching"""
    meshes, arm, root = vendor(os.path.join(V.GLB, "whale.glb"), {"Top": "#c0283f", "Bottom": "#ffe0c2"})
    root.rotation_euler = (math.radians(-35), 0, math.radians(72))     # nose -Y -> up and to the right
    act = V.set_action(arm, "swim")
    if act:
        f0, f1 = act.frame_range
        bpy.context.scene.frame_set(int(f0 + (f1 - f0) * 0.3))
    bpy.context.view_layer.update()
    V.normalize(meshes, root, length=2.6)
    vendor_outline(meshes, 0.05)
    lo, hi = V.world_bbox(meshes)
    return meshes + splash(Vector((lo.x + (hi.x - lo.x) * 0.3, (lo.y + hi.y) / 2, lo.z + 0.1)), 0.9)


def splash(at, s=1.0):
    """the sea bursting where it comes out: a foam ring and flying drops"""
    rnd = random.Random(4)
    foam = [toon("#ffffff", shade=0.9), toon("#d8f3ff", shade=0.85)]
    out = []
    for k in range(9):
        a = math.tau * k / 9
        r = rnd.uniform(0.75, 1.0) * s
        out.append(sphere(loc=at + Vector((math.cos(a) * r * 0.7, math.sin(a) * r * 0.45, rnd.uniform(0.0, 0.18) * s)),
                          scale=rnd.uniform(0.16, 0.26) * s, mat=foam[k % 2], seg=12, rings=8))
    for k in range(7):
        a = math.tau * k / 7 + 0.3
        out.append(sphere(loc=at + Vector((math.cos(a) * s * 0.95, math.sin(a) * s * 0.5, rnd.uniform(0.45, 0.85) * s)),
                          scale=rnd.uniform(0.05, 0.09) * s, mat=foam[1], seg=10, rings=6))
    return out


def small_chest(loc, scale=0.4, tier="legendary", rot_z=0.0):
    """vf_props' chest (the game's chest icons), shrunk"""
    parts = P.chest(tier)
    root = K.parent_all(parts, "chest")
    root.scale = (scale, scale, scale)
    root.location = loc
    root.rotation_euler = (0, 0, math.radians(rot_z))
    for o in parts:
        o["outline_k"] = 1.0 / scale
    bpy.context.view_layer.update()
    return parts


def treasure_crab():
    """the game's crab, gilded, with a treasure chest on its back"""
    parts = M.build_fish(dict(crab=True, top="#f2a900", belly="#ffe7a0", fin="#e07b00"))
    return parts + small_chest((-0.12, 0.0, 0.26), 0.42)


def do_event(only):
    for name in ["Golden Koi", "Frenzy Piranha", "Treasure Crab", "Meteor Fish", "Leviathan"]:
        if only and slug(name) not in only:
            continue
        scene()
        random.seed(11)
        if name in EVENT_SPECS:
            spec = EVENT_SPECS[name]
            parts = M.build_fish(spec)
            if name == "Frenzy Piranha":
                parts += piranha_jaw(spec)
        elif name == "Treasure Crab":
            parts = treasure_crab()
        else:
            parts = leviathan()
        shoot(parts, os.path.join(OUT, "event", slug(name) + ".png"))


# ---------------------------------------------------------------------- UI
def pearl(loc=(0, 0, 0), r=0.32):
    p = sphere(loc=loc, scale=r, mat=toon("#fbf4ff", spec=0.35, rim=0.25), seg=32, rings=16)
    gl = sphere(loc=(loc[0] - r * 0.3, loc[1] - r * 0.55, loc[2] + r * 0.5), scale=r * 0.2, mat=toon("#ffffff", flat_glow=True))
    gl["no_outline"] = True
    return [p, gl]


def big_pearl():
    """the Pearls currency: one glossy pearl (it has to read at HUD size)"""
    p = sphere(scale=1.0, seg=48, rings=24)
    top, low = K.hexc("#ffffff"), K.hexc("#e7c6ff")
    K.vcolor(p, lambda co, n: K.mix(low, top, min(1.0, max(0.0, co.z * 0.7 + 0.55))))     # lilac below, white on top
    p.data.materials.append(toon(None, vcol="col", shade=0.8, spec=0.5, rim=0.35, key=("pearl",)))
    gl = sphere(loc=(-0.3, -0.62, 0.48), scale=(0.26, 0.2, 0.2), mat=toon("#ffffff", flat_glow=True))
    gl["no_outline"] = True
    parts = [p, gl]
    return parts + twinkles(parts, "#ffffff", ((0.95, 0.95, 0.32),))


def event_star():
    st = extrude_poly(M.star_pts(1.0, 0.5, 5), 0.32, mat=toon("#ffcc1f", spec=0.3, rim=0.2, emit=0.15), bevel=0.05)
    st.rotation_euler = (math.radians(90), 0, 0)
    face = extrude_poly(M.star_pts(0.6, 0.3, 5), 0.05, loc=(0, -0.18, 0), mat=toon("#ffe680", flat_glow=True))
    face.rotation_euler = (math.radians(90), 0, 0)
    face["no_outline"] = True
    return [st, face]


def do_ui(only):
    for name, build, rot in [("pearl", big_pearl, (70, 0, 16)), ("star", event_star, (84, 0, 12))]:
        if only and name not in only:
            continue
        scene(rot=rot, light=(40, 10, 30))
        shoot(build(), os.path.join(OUT, "ui", name + ".png"), 0.04, margin=1.1)


# -------------------------------------------------------------------- packs
def gift_box(color, ribbon="#ffffff"):
    body = toon(color)
    rb = toon(ribbon)
    out = [cube(loc=(0, 0, 0.42), scale=(1.0, 1.0, 0.84), mat=body, bevel=0.04),
           cube(loc=(0, 0, 0.92), scale=(1.12, 1.12, 0.22), mat=body, bevel=0.04),
           cube(loc=(0, 0, 0.53), scale=(0.2, 1.04, 1.1), mat=rb),
           cube(loc=(0, 0, 0.53), scale=(1.04, 0.2, 1.1), mat=rb),
           sphere(loc=(0, 0, 1.08), scale=(0.13, 0.13, 0.1), mat=rb)]
    for side in (1, -1):                                 # the bow: two loops, tilted up and out
        out.append(torus(loc=(side * 0.27, 0, 1.13), R=0.17, r=0.06, rot=(90, -side * 28, 0), mat=rb,
                         scale=(1.5, 0.85, 1.0)))
    return out


def open_chest(wood, metal):
    """vf_props' chest (the game's chest icons) with its lid swung open on the back hinge"""
    w, m = toon(wood), toon(metal, spec=0.5)
    out = [cube(loc=(0, 0, 0.4), scale=(1.6, 1.0, 0.8), mat=w, bevel=0.04)]
    for x in (-0.55, 0.55):
        out.append(cube(loc=(x, 0, 0.4), scale=(0.16, 1.04, 0.84), mat=m))
    out.append(cube(loc=(0, -0.52, 0.6), scale=(0.3, 0.08, 0.32), mat=toon(metal, spec=0.6), bevel=0.03))
    out.append(cyl(loc=(0, -0.57, 0.58), r=0.05, depth=0.04, rot=(90, 0, 0), mat=toon("#1a1420")))
    arc = [math.pi * i / 16 for i in range(17)]
    lid = [extrude_poly([(0.5 * math.cos(a), 0.375 * math.sin(a)) for a in arc], 1.6, loc=(0, -0.5, 0), rot=(90, 0, 90), mat=w)]
    for x in (-0.55, 0.55):
        lid.append(tube([(x, -0.5 + 0.52 * math.cos(a), 0.39 * math.sin(a)) for a in arc[::2]], 0.06, mat=m))
    hinge = K.parent_all(lid, "lid")                     # built around the hinge, then swung open
    hinge.location = (0, 0.5, 0.8)
    hinge.rotation_euler = (math.radians(-105), 0, 0)
    bpy.context.view_layer.update()
    return out + lid


def treasure(gem, crown=False):
    """a heap of coins in the open chest, pearls and gems on it, a few coins spilled"""
    rnd = random.Random(5)
    gold = toon("#ffcf3a", spec=0.3, rim=0.2)
    out = [sphere(loc=(0, -0.02, 0.8), scale=(0.7, 0.42, 0.22), mat=gold)]
    for k in range(7):                                   # coins on the heap
        a = math.tau * k / 7 + 0.4
        out.append(cyl(loc=(math.cos(a) * 0.42, -0.02 + math.sin(a) * 0.22, 0.94), r=0.12, depth=0.04, verts=16, mat=gold,
                       rot=(rnd.uniform(-35, 35), rnd.uniform(-35, 35), 0)))
    for k, x in enumerate((-0.42, -0.14, 0.14, 0.42)):   # pearls and gems on top
        if k % 2 == 0:
            out += pearl((x, -0.12, 1.02), 0.13)
        else:
            out.append(K.ico(loc=(x, -0.05, 1.04), scale=0.12, sub=1, mat=toon(gem, emit=0.3, spec=0.4)))
    for x, y in ((-0.95, -0.75), (-0.62, -0.85), (0.75, -0.8), (1.0, -0.55), (0.3, -0.95)):   # spilled
        out.append(cyl(loc=(x, y, 0.02), r=0.12, depth=0.04, verts=16, mat=gold))
    if crown:
        parts = P.crown()
        root = K.parent_all(parts, "crown")
        root.scale = (0.34, 0.34, 0.34)
        root.location = (0.05, -0.1, 1.12)
        root.rotation_euler = (math.radians(-14), math.radians(8), 0)
        for o in parts:
            o["outline_k"] = 1.0 / 0.34
        bpy.context.view_layer.update()
        out += parts
    return out


def chest_pack(wood, metal, gem, crown=False):
    parts = open_chest(wood, metal) + treasure(gem, crown)
    return parts + twinkles(parts, "#fff6c8", ((0.92, 0.8, 0.16), (0.08, 0.62, 0.12)))


def rod_by_box(name):
    """an exclusive rod leaning on the gift box"""
    parts = M.build_rod(M.ROD_SPECS[name], strip=True)[0]
    root = K.parent_all(parts, "rod")
    root.scale = (0.75, 0.75, 0.75)
    root.rotation_euler = (0, math.radians(-25), math.radians(180))
    root.location = (0.75, -0.7, 1.1)
    bpy.context.view_layer.update()
    return parts


PACK_ART = {
    "pack_starter": lambda: gift_box("#22c55e", "#fff6c2") + pearl((0.0, 0.0, 1.42), 0.24),
    "pack_fisher": lambda: gift_box("#0ea5e9") + rod_by_box("Pearl Rod"),
    "pack_captain": lambda: chest_pack("#5a2d8a", "#d0d6e0", "#c77dff"),
    "pack_legend": lambda: chest_pack("#b5541c", "#ffd23f", "#ef4444", crown=True),
}


def do_packs(only):
    for pid, build in PACK_ART.items():
        if only and pid not in only:
            continue
        scene(rot=(68, 0, 30), light=(45, 10, 40))
        random.seed(3)
        K.seed(1)
        shoot(build(), os.path.join(OUT, "packs", pid + ".png"), 0.035, margin=1.1)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = []
    if "--only" in argv:
        i = argv.index("--only")
        only = [x.strip() for x in argv[i + 1].split(",")]
        argv = argv[:i] + argv[i + 2:]
    for c in argv or ["shiny", "event", "ui", "packs"]:
        print("== rendering", c, flush=True)
        {"shiny": do_shiny, "event": do_event, "ui": do_ui, "packs": do_packs}[c](only)
    print("done")


if __name__ == "__main__":
    main()

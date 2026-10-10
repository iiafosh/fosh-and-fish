"""The 17 fosh&fish boats, built from CC0 / CC-BY model packs (see CREDITS.md)
and converted to the project's cel shading. Bow faces +X, waterline at z=0.

build_boat(name) -> (parts, deck_anchor): deck_anchor is where the fisher's
feet go (found by casting a ray down onto the model at the boat's deck spot).

Sources (fetched into scratch/downloads by tools/fetch_assets.py):
  Kenney Watercraft Kit, Pirate Kit, Space Kit (CC0) - most hulls
  Quaternius (CC0, poly.pizza)                     - luxury yacht, space cruiser
  Poly by Google / Zoe XR (CC-BY 3.0, poly.pizza)  - satellite, shuttle, UFO, submarine
Kenney colormap textures are palette-swapped per boat (recolor) so the
upgrades read as a progression instead of a row of stock models.
"""
import math
import os

import bpy
import numpy as np
from mathutils import Vector

import vf_kit as K
import vf_vendor as V
from vf_kit import cone, cube, cyl, extrude_poly, hexc, ico, sphere, toon, torus, tube

BOAT_ORDER = ["Rowboat", "Fishing Boat", "Speedboat", "Pontoon", "Sailboat", "Yacht", "Luxury Yacht",
              "Cruise Ship", "Gold Boat", "Sky Cruiser", "Satellite", "Space Shuttle", "Cruiser",
              "Alien Raft", "Alien Submarine", "Dark Explorer", "Abyssal Surveyor"]

FISHER_SCALE = {"Yacht": 1.05, "Luxury Yacht": 1.1, "Cruise Ship": 1.25, "Gold Boat": 1.15, "Sky Cruiser": 1.15,
                "Satellite": 1.1, "Space Shuttle": 1.15, "Cruiser": 1.2, "Alien Raft": 1.1, "Alien Submarine": 1.15,
                "Dark Explorer": 1.2, "Abyssal Surveyor": 1.25}

WC, PI, SP, BO = "wc", "pi", "sp", "bo"


def _folder(key):
    return {WC: V.WATERCRAFT, PI: V.PIRATE, SP: V.SPACE, BO: V.BOATS}[key]


# ------------------------------------------------------------- recolouring
def _lum(c):
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]


def _rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def recolor_image(img, swaps, name):
    """Palette swap for a Kenney colormap (512 px, swatch pairs of 64x128 px:
    a flat column + a gradient column). swaps: {src_hex: dst_hex}; every
    swatch whose flat colour matches src is repainted with dst, keeping the
    gradient's relative brightness."""
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)   # rows bottom-up
    out = px.copy()
    bw, bh = w // 8, h // 4
    for by in range(4):
        for bx in range(8):
            y0, x0 = by * bh, bx * bw
            base = px[y0 + bh // 2, x0 + bw // 4, :3]
            for src, dst in swaps.items():
                if np.abs(base - _rgb(src)).max() < 0.03:
                    blk = px[y0:y0 + bh, x0:x0 + bw, :3]
                    k = (_lum(blk) / max(_lum(base), 1e-3))[..., None]
                    out[y0:y0 + bh, x0:x0 + bw, :3] = np.clip(_rgb(dst)[None, None, :] * k, 0, 1)
    new = bpy.data.images.new(name, w, h, alpha=True)
    new.pixels = out.ravel().tolist()
    new.pack()
    return new


def _recolor_material(mat, swaps, tag):
    if not swaps or not mat.use_nodes:
        return
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image is not None:
            n.image = recolor_image(n.image, swaps, "%s_%s" % (n.image.name, tag))


def _hsv(mat, h=0.5, s=1.0, v=1.0):
    """Hue/saturation/value shift on a material's base colour (textured models)."""
    nt = mat.node_tree
    pr = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if pr is None:
        return
    bc = pr.inputs["Base Color"]
    hs = nt.nodes.new("ShaderNodeHueSaturation")
    hs.inputs["Hue"].default_value = h
    hs.inputs["Saturation"].default_value = s
    hs.inputs["Value"].default_value = v
    if bc.is_linked:
        nt.links.new(bc.links[0].from_socket, hs.inputs["Color"])
    else:
        hs.inputs["Color"].default_value = bc.default_value
    nt.links.new(hs.outputs[0], bc)


def squash(ob, z0, k):
    """Compress everything above z0 by k: masts and sails seen from the
    high top-down camera otherwise tower over the hull like a side view."""
    for v in ob.data.vertices:
        if v.co.z > z0:
            v.co.z = z0 + (v.co.z - z0) * k
    ob.data.update()


# ---------------------------------------------------------------- loading
def load(src, name, length, rot=0.0, draft=0.2, swaps=None, tints=None, emit=None, tag="boat", axis="x",
         drop=(), hsv=None, parts=None):
    """Import a vendor GLB as ONE cel-shaded mesh: bow turned to +X (`rot`
    degrees about Z), scaled so its X extent (or `axis` "max") is `length`,
    centred on the origin, with `draft` world units below the waterline.
    drop: mesh-name prefixes to leave out (sails, flags...).
    tints / emit / hsv: per material base name (tint colour, glow 0..1,
    (hue, sat, val) shift).
    parts: {mesh-name prefix: {"swaps": {...}, "emit": k}} gives those
    meshes (e.g. sails) their own palette before everything is joined."""
    meshes, arm, roots = V.import_glb(os.path.join(_folder(src), name + ".glb"))
    bpy.context.view_layer.update()
    for m in [m for m in meshes if any(m.name.startswith(d) for d in drop)]:
        meshes.remove(m)
        bpy.data.objects.remove(m)
    parts = parts or {}
    for m in meshes:
        pre = next((p for p in parts if m.name.startswith(p)), None)
        if pre:
            if m.data.users > 1:
                m.data = m.data.copy()
            for i, mt in enumerate(m.data.materials):
                c = mt.copy()
                c.name = "%s__%s" % (mt.name.split(".")[0], pre)
                m.data.materials[i] = c
    for m in meshes:
        mw = m.matrix_world.copy()
        m.parent = None
        m.matrix_world = mw
        if m.data.users > 1:
            m.data = m.data.copy()
    for r in roots:
        try:
            if r.type == "EMPTY":
                bpy.data.objects.remove(r)
        except ReferenceError:
            pass
    bpy.ops.object.select_all(action="DESELECT")
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = "%s_%s" % (tag, name)
    ob.rotation_mode = "XYZ"
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    # weld the per-face vertices glTF ships (flat shading stays) so the
    # inverted-hull outline is one closed shell instead of floating faces
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bm.to_mesh(ob.data)
    bm.free()
    if ob.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for p in ob.data.polygons:
        p.use_smooth = False
    for i, mt in enumerate(ob.data.materials):
        if mt is None:
            continue
        mt = mt.copy()
        ob.data.materials[i] = mt
        mt.surface_render_method = "DITHERED"        # glTF "BLEND" materials sort badly
        base = mt.name.split(".")[0]
        part = parts.get(base.split("__")[1]) if "__" in base else None
        _recolor_material(mt, part.get("swaps", swaps) if part else swaps, tag)
        if hsv and (base in hsv or "*" in hsv):
            _hsv(mt, *hsv.get(base, hsv.get("*")))
        tint = (tints or {}).get(base)
        k = part.get("emit", 0.0) if part else (emit or {}).get(base, 0.0)
        V.toonify(mt, tint=tint, emit=k)
    ob.rotation_euler = (0, 0, math.radians(rot))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    lo, hi = V.world_bbox([ob])
    size = hi - lo
    s = length / (size.x if axis == "x" else max(size.x, size.y))
    ob.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    lo, hi = V.world_bbox([ob])
    ob.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z - draft)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    ob["outline_even"] = False
    return ob


def surfaces(x, y=0.0, top=50.0):
    """Every surface height under (x, y), top first (debug + deck finding)."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    out, z = [], top
    for _ in range(12):
        hit, loc, nrm, *_ = bpy.context.scene.ray_cast(dg, Vector((x, y, z)), Vector((0, 0, -1)))
        if not hit:
            break
        out.append(round(loc.z, 3))
        z = loc.z - 1e-3
    return out


def deck_at(parts, x, y=0.0, below=None):
    """Top surface under (x, y): where the fisher's feet go. `below` skips
    hits above that height (cabin roofs, sails, a balloon)."""
    hs = surfaces(x, y, below if below is not None else 50.0)
    z = hs[0] if hs else 0.3
    print("DECK", [p.name for p in parts[:1]], (round(x, 2), round(y, 2)), "surfaces", hs, "->", z)
    return (x, y, z)


def glow(color, k=0.85):
    return toon(color, emit=k)


def noline(o):
    o["no_outline"] = True
    return o


# --------------------------------------------------------------- details
def lamp(loc, color, r=0.12):
    """Small glowing bulb (no outline, so it reads as light)."""
    return noline(sphere(loc=loc, scale=r, mat=glow(color, 1.0), seg=12, rings=6))


def flare(x, y, z, r, length, color="#5ff2ff"):
    """Engine exhaust cone pointing -X (backwards)."""
    c = cone(loc=(x - length / 2, y, z), r1=r, r2=0.0, depth=length, rot=(0, -90, 0), mat=glow(color, 1.0), verts=16)
    return noline(c)


def propeller(x, y, z, r=0.5, color="#7a5a3a"):
    out = [cyl(loc=(x, y, z), r=r * 0.22, depth=r * 0.5, rot=(0, 90, 0), mat=toon("#3a3f44"))]
    for k in range(3):
        a = k * 120 + 15
        out.append(cube(loc=(x - r * 0.1, y + math.cos(math.radians(a)) * r * 0.5, z + math.sin(math.radians(a)) * r * 0.5),
                        scale=(0.05, r * 0.95, r * 0.26), rot=(a, 0, 0), mat=toon(color)))
    return out


def wing(side, root, z, pts, color, dihedral=12.0, thick=0.08):
    """Flat wing outline (x, y>0) mirrored to `side`, tilted up by dihedral."""
    w = extrude_poly([(x, y * side) for x, y in pts], thick, mat=toon(color))
    w.location = (root[0], root[1] * side, z)
    w.rotation_euler = (math.radians(-dihedral * side), 0, 0)
    return w


def apply_scale(ob, sx, sy, sz):
    ob.scale = (sx, sy, sz)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)


# Kenney colormap swatches (flat colour of each pair)
BROWN, SALMON, TAN, CREAM, WHITE = "#b06041", "#f1976c", "#f2bf99", "#fde4c7", "#ffffff"
GREEN, YELLOW, ORANGE, RED, BLUE, LBLUE = "#61cb8b", "#ffc044", "#ff7e44", "#cf534f", "#6794d9", "#d0e8ff"
DARK, GREY, SLATE, LAVENDER, PURPLE, PINK = "#38383d", "#868ba1", "#4f5260", "#a0a8c9", "#a878e8", "#f378f0"
FEATHER = [(1.0, 0.0), (0.3, 1.2), (-0.9, 2.5), (-1.1, 2.0), (-1.5, 2.1), (-1.6, 1.5), (-2.0, 1.4), (-1.9, 0.8), (-1.4, 0.0)]


# ------------------------------------------------------------------ boats
def rowboat():
    ob = load(WC, "boat-row-small", 3.4, rot=90, draft=0.22)
    return [ob], deck_at([ob], 0.35)


def fishing_boat():
    ob = load(WC, "boat-fishing-small", 4.3, rot=90, draft=0.3)
    return [ob], deck_at([ob], 1.5, below=1.0)


def speedboat():
    ob = load(WC, "boat-speed-c", 4.7, rot=90, draft=0.28)
    return [ob], deck_at([ob], -1.2)


def pontoon():
    ob = load(WC, "boat-house-a", 5.0, rot=90, draft=0.3, swaps={LAVENDER: "#3fbf9f"})
    return [ob], deck_at([ob], 1.95)


def sailboat():
    ob = load(WC, "boat-sail-a", 5.3, rot=90, draft=0.3)
    return [ob], deck_at([ob], 1.75, below=2.0)


def yacht():
    ob = load(BO, "q_cruise", 6.0, rot=90, draft=0.3, tints={"Red": "#1f3a6a", "F2F2F2": "#ffffff"},
              emit={"F2F2F2": 0.3})
    return [ob], deck_at([ob], 2.25)


def luxury_yacht():
    ob = load(BO, "p_cruise", 7.0, rot=90, draft=0.3)
    return [ob], deck_at([ob], 2.85)


def cruise_ship():
    ob = load(WC, "ship-ocean-liner", 8.0, rot=90, draft=0.38)
    return [ob], deck_at([ob], 3.3)


def gold_boat():
    gold = {BROWN: "#b8860b", SALMON: "#e9b23a", TAN: "#ffd75e", CREAM: "#fff0b3", RED: "#b3263a"}
    ob = load(PI, "ship-large", 7.6, rot=90, draft=0.45, swaps=gold, emit={"colormap": 0.12})
    squash(ob, 1.6, 0.55)
    p = [ob]
    for x, y in ((3.4, 0.0), (-3.45, 0.55), (-3.45, -0.55)):
        p.append(lamp((x, y, 1.78), "#fff2a0", 0.1))
    return p, deck_at([ob], 2.35, below=1.5)


def sky_cruiser():
    """A flying galleon: Kenney pirate hull with furled sails, feathered
    wings and stern propellers, held up by a blimp envelope (Poly by Google)."""
    ob = load(PI, "ship-medium", 7.4, rot=90, draft=-0.45, drop=("sail",),
              swaps={RED: "#4f9bea", BROWN: "#a2663f"})
    squash(ob, 1.5, 0.5)
    p = [ob]
    env = load(BO, "p_blimp2", 5.4, rot=90, draft=0.0, tints={"lambert6SG": "#9ad6ff"}, tag="env")
    lo, hi = V.world_bbox([env])
    env.location = (-0.9, 0.0, 4.3)
    p.append(env)
    zb = 4.3 + 0.12
    for s in (1, -1):
        p.append(wing(s, (0.4, 0.75), 1.45, FEATHER, "#eef6ff"))
        p.append(wing(s, (0.6, 0.8), 1.52, [(x * 0.62, y * 0.62) for x, y in FEATHER], "#7cc4ff", thick=0.06))
        p += propeller(-3.95, s * 0.55, 1.45, 0.6)
        for x in (-2.6, 0.6):
            p.append(tube([(x, s * 0.7, 1.5), (x + 0.1, s * 0.45, zb)], 0.03, mat=toon("#5a4632")))
    for x in (-2.6, 0.2, 2.6):
        p.append(lamp((x, 0.0, 0.3), "#7dfcff", 0.16))
    return p, deck_at([ob], 2.4, below=1.9)


def satellite():
    ob = load(BO, "p_sat1", 7.8, rot=0, draft=0.1)
    p = [ob, lamp((0.0, 1.9, 1.3), "#ff4b3e", 0.1)]
    return p, deck_at([ob], 0.0)


def space_shuttle():
    ob = load(BO, "p_orbiter_zoe", 7.8, rot=180, draft=0.15)
    lo, hi = V.world_bbox([ob])
    p = [ob]
    for y, z, r in ((0.0, 1.1, 0.28), (0.34, 0.74, 0.21), (-0.34, 0.74, 0.21)):
        p.append(flare(lo.x + 0.05, y, z, r, 0.95))
    return p, deck_at([ob], 0.6)


def cruiser():
    ob = load(BO, "q_space411", 8.2, rot=90, draft=0.15)
    lo, hi = V.world_bbox([ob])
    p = [ob]
    for y in (-0.56, 0.56):
        p.append(flare(lo.x + 0.15, y, 0.77, 0.25, 1.15, "#ff9a3c"))
    return p, deck_at([ob], 0.6)


def alien_raft():
    ob = load(BO, "p_saucer1", 7.6, rot=0, draft=0.3, hsv={"*": (0.62, 1.4, 1.25)}, emit={"MAIN": 0.15})
    p = [ob]
    for i in range(12):
        a = i / 12 * math.tau
        p.append(lamp((math.cos(a) * 3.65, math.sin(a) * 3.65, 0.26), "#7dffcf" if i % 2 else "#c77dff", 0.15))
    return p, deck_at([ob], 2.3)


def alien_submarine():
    """Poly by Google submarine, hue-shifted alien purple and fattened, with
    a glowing canopy, glowing portholes, fins and tentacles."""
    ob = load(BO, "p_sub1", 7.4, rot=90, draft=0.5, hsv={"*": (0.62, 1.3, 1.15)})
    apply_scale(ob, 1.0, 1.8, 1.4)
    lo, hi = V.world_bbox([ob])
    p = [ob]
    p.append(noline(sphere(loc=(1.3, 0.0, hi.z - 0.12), scale=(0.75, 0.5, 0.38), mat=glow("#7dffcf", 0.4))))
    for i in range(5):
        x = -2.3 + i * 0.95
        for s in (1, -1):
            p.append(lamp((x, s * (hi.y - 0.14), 0.3), "#7dffcf", 0.16))
    for s in (1, -1):
        p.append(wing(s, (lo.x + 1.1, 0.45), 0.35, [(0.6, 0), (-0.6, 0), (-1.1, 1.0), (-0.4, 0.9)], "#c77dff", dihedral=0))
    for i, y in enumerate((-0.5, -0.25, 0.0, 0.25, 0.5)):
        tip = (lo.x - 1.5 + abs(y) * 0.8, y * 2.0, 0.25 + 0.15 * (i % 2))
        p.append(tube([(lo.x + 0.3, y * 0.8, 0.35), (lo.x - 0.6, y * 1.4, 0.2 + 0.1 * (i % 2)), tip], 0.11,
                      mat=toon("#9b4fd6"), taper=(1.0, 0.35)))
        p.append(lamp(tip, "#7dffcf", 0.09))
    return p, deck_at([ob], 2.7)


def dark_explorer():
    """Kenney ghost ship repainted midnight purple with glowing spectral sails."""
    spectral = {"swaps": {GREEN: "#b59cff"}, "emit": 0.55}
    ob = load(PI, "ship-ghost", 9.0, rot=90, draft=0.5, swaps={GREEN: "#433573"}, emit={"colormap": 0.08},
              parts={"sail": spectral, "flag": spectral})
    squash(ob, 2.4, 0.55)
    p = [ob]
    k = 9.0 / 8.6
    for x, y, z in ((3.7, 0.0, 1.85), (-3.75, 0.62, 2.7), (-3.75, -0.62, 2.7), (0.6, 0.9, 1.45), (-1.4, 0.9, 1.45),
                    (0.6, -0.9, 1.45), (-1.4, -0.9, 1.45)):
        p.append(lamp((x * k, y * k, z * k), "#c77dff", 0.14))
    return p, deck_at([ob], 2.2, below=1.8)


def abyssal_surveyor():
    """Deep-sea survey ship: Kenney supply-ship hull repainted abyss teal,
    with an A-frame crane, a yellow submersible, radar and floodlights."""
    sw = {RED: "#1f7a8c", ORANGE: "#f2f5f7", GREY: "#3b5566", LAVENDER: "#56788a", SLATE: "#1c2b36"}
    ob = load(WC, "ship-cargo-c", 9.2, rot=90, draft=0.35, swaps=sw)
    p = [ob]
    hs = surfaces(-2.9)
    zd = hs[0] if hs else 0.8
    # white bridge + lab block on the forward hatch, radar dome and mast
    zt = surfaces(1.8)[0]
    p.append(cube(loc=(1.75, 0.0, zt + 0.32), scale=(2.3, 1.5, 0.64), mat=toon("#f2f5f7"), bevel=0.06))
    p.append(cube(loc=(2.1, 0.0, zt + 0.86), scale=(1.2, 1.2, 0.46), mat=toon("#f2f5f7"), bevel=0.05))
    p.append(noline(cube(loc=(2.71, 0.0, zt + 0.9), scale=(0.04, 1.0, 0.2), mat=glow("#5ff2ff", 0.55))))
    for s in (1, -1):
        p.append(noline(cube(loc=(1.75, s * 0.76, zt + 0.38), scale=(1.9, 0.04, 0.14), mat=glow("#5ff2ff", 0.4))))
    p.append(sphere(loc=(1.45, 0.0, zt + 1.25), scale=0.34, mat=toon("#f2f5f7"), seg=20, rings=10))
    p.append(cyl(loc=(2.35, 0.0, zt + 1.55), r=0.05, depth=0.9, mat=toon("#d9dde2")))
    p.append(cube(loc=(2.35, 0.0, zt + 1.75), scale=(0.08, 0.8, 0.06), mat=toon("#d9dde2")))
    p.append(lamp((2.35, 0.0, zt + 2.05), "#ff4b3e", 0.1))
    # submersible on the aft deck
    p.append(sphere(loc=(-2.6, 0.0, zd + 0.58), scale=(1.0, 0.66, 0.58), mat=toon("#ffd23f"), seg=24, rings=12))
    p.append(noline(sphere(loc=(-1.75, 0.0, zd + 0.62), scale=(0.33, 0.38, 0.36), mat=glow("#5ff2ff", 0.9))))
    p.append(cyl(loc=(-2.7, 0.0, zd + 1.18), r=0.17, depth=0.26, mat=toon("#e0a82e")))
    for s in (1, -1):
        p.append(cyl(loc=(-3.3, s * 0.66, zd + 0.32), r=0.13, depth=0.75, rot=(0, 90, 0), mat=toon("#3a414c")))
    # A-frame crane over the stern
    for s in (1, -1):
        p.append(tube([(-4.3, s * 0.85, zd), (-3.6, s * 0.7, zd + 2.2)], 0.09, mat=toon("#ffd23f")))
    p.append(tube([(-3.6, 0.75, zd + 2.2), (-3.6, -0.75, zd + 2.2)], 0.09, mat=toon("#ffd23f")))
    p.append(tube([(-3.6, 0.0, zd + 2.2), (-2.7, 0.0, zd + 1.3)], 0.018, mat=toon("#d9dde2")))
    # floodlights + mast lights
    for x, y in ((1.3, 0.9), (1.3, -0.9), (-0.6, 0.9), (-0.6, -0.9), (-4.0, 0.9), (-4.0, -0.9)):
        p.append(lamp((x, y, zd + 0.35), "#fff2a0", 0.15))
    p.append(lamp((4.45, 0.0, 1.25), "#5ff2ff", 0.17))
    return p, deck_at([ob], 3.9)


BUILDERS = {
    "Rowboat": rowboat, "Fishing Boat": fishing_boat, "Speedboat": speedboat, "Pontoon": pontoon,
    "Sailboat": sailboat, "Yacht": yacht, "Luxury Yacht": luxury_yacht, "Cruise Ship": cruise_ship,
    "Gold Boat": gold_boat, "Sky Cruiser": sky_cruiser, "Satellite": satellite, "Space Shuttle": space_shuttle,
    "Cruiser": cruiser, "Alien Raft": alien_raft, "Alien Submarine": alien_submarine,
    "Dark Explorer": dark_explorer, "Abyssal Surveyor": abyssal_surveyor,
}


def build_boat(name):
    parts, deck = BUILDERS[name]()
    if os.environ.get("VF_BOAT_PROFILE"):
        lo, hi = V.world_bbox([p for p in parts if p.type == "MESH"])
        for i in range(13):
            x = lo.x + (hi.x - lo.x) * (i + 0.5) / 13
            print("PROFILE", name, round(x, 2), surfaces(x, 0.0))
    return parts, deck

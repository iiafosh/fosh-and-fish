"""The fish shop: a timbered house on a wooden deck, put together from Kenney's Fantasy Town and Pirate kits (CC0),
built right into each biome's backdrop so it stands on the ground and takes the scene's light and shadows.
Raw packs live in scratch/downloads (git-ignored): x_kenney_fantasy_town, x_kenney_pirate; see CREDITS.md.

Local coordinates: the door looks along -Y, the origin is the middle of the front wall, at deck level.
"""
import math
import os

import bpy
from mathutils import Vector

import vf_kit as K
import vf_models as M
import vf_vendor as V
from vf_kit import cube, cyl, toon, torus

TOWN = os.path.join(V.DL, "x_kenney_fantasy_town", "Models", "GLB format")
PIRATE = os.path.join(V.DL, "x_kenney_pirate", "Models", "GLB format")
T = 1.7                 # one kit tile, in game units
TURN = 38.0             # degrees: the front looks down and to the right, toward the boat, so two sides of the house show
UPPER = 0.66            # the timbered upper floor, squat, in tiles (the land between the HUD and the shore is not tall)
ROOF_Z = 0.9            # the roof's height, of what the kit has
DECK_Z = 0.06 * T
X0, X1, Y0, Y1 = -1.72 * T, 2.72 * T, -0.72 * T, 2.0 * T    # the deck
WALLS = DECK_Z + (1.0 + UPPER) * T
ROOF_TOP = WALLS + 0.63 * T * ROOF_Z
SIGN_TOP = ROOF_TOP + 1.15
MERCHANT_AT = (1.25, -0.72)     # where the shopkeeper stands

# the kit's 8 x 4 colour atlas: swatch -> (top, bottom of its gradient)
ROOF, INFILL, TIMBER, STONE, PLANK = (1, 3), (5, 3), (3, 2), (1, 2), (4, 2)
THEMES = {
    "River":    {ROOF: ("#3fb8ad", "#1f8a86"), INFILL: ("#f4e6c6", "#e2cda0"), TIMBER: ("#a9693c", "#8a5230"), STONE: ("#c9c2b4", "#9c958a"), PLANK: ("#cf9f6b", "#ad8150")},
    "Ocean":    {ROOF: ("#4f9fe0", "#2a6fb8"), INFILL: ("#fbf4e2", "#ecdfc2"), TIMBER: ("#b98248", "#946536"), STONE: ("#e2d6bc", "#b8ab90"), PLANK: ("#dcb483", "#b89263")},
    "Volcanic": {ROOF: ("#e0562e", "#a8341c"), INFILL: ("#6a5a56", "#4e4240"), TIMBER: ("#4a3430", "#352624"), STONE: ("#57504e", "#3c3634"), PLANK: ("#5c4640", "#47352f")},
    "Sky":      {ROOF: ("#f58cc0", "#c763a6"), INFILL: ("#fff8f0", "#f0e4ee"), TIMBER: ("#c9a0d8", "#a27fc0"), STONE: ("#e8e2f4", "#bcb4d8"), PLANK: ("#e8d0ea", "#c8acd2")},
    "Space":    {ROOF: ("#8f6bff", "#5a3fd0"), INFILL: ("#3e3a5e", "#2c2946"), TIMBER: ("#8a8fb0", "#5e6284"), STONE: ("#5a5a78", "#3e3e58"), PLANK: ("#6e6e90", "#50506e")},
    "Alien":    {ROOF: ("#7dff9a", "#35c47a"), INFILL: ("#6e4ea8", "#523a88"), TIMBER: ("#2fd6b0", "#1f9c8a"), STONE: ("#4a3a78", "#352a5c"), PLANK: ("#4e7a78", "#3a5c5c")},
    "Abyss":    {ROOF: ("#2fb8d8", "#1a6f9a"), INFILL: ("#27344e", "#1b2438"), TIMBER: ("#3e5a7a", "#2a4058"), STONE: ("#2a3450", "#1c2438"), PLANK: ("#34465e", "#263448")},
}
NO_SMOKE = ("Space", "Abyss")


def _repaint(src, swatches, suffix, cols=8, rows=4):
    w, h = src.size
    px = list(src.pixels)
    srgb = lambda h: [int(h[i:i + 2], 16) / 255.0 for i in (1, 3, 5)]     # (the atlas stores sRGB values)
    for (c, r), (top, bot) in swatches.items():
        a, b = srgb(top), srgb(bot)
        x0, x1 = c * w // cols, (c + 1) * w // cols
        y_top, y_bot = h - r * h // rows, h - (r + 1) * h // rows        # (image rows run bottom-up)
        for y in range(y_bot, y_top):
            k = (y_top - 1 - y) / max(1, y_top - y_bot - 1)
            col = [a[i] * (1 - k) + b[i] * k for i in range(3)]
            for x in range(x0, x1):
                o = (y * w + x) * 4
                px[o], px[o + 1], px[o + 2] = col[0], col[1], col[2]
    img = bpy.data.images.new(src.name + suffix, w, h, alpha=True)
    img.colorspace_settings.name = src.colorspace_settings.name
    img.pixels = px
    return img


def _apply_theme(parts, swatches, name):
    """the kit's pieces share one atlas: repaint a copy per theme, on every material of the town kit"""
    done = {}
    seen = set()
    for o in parts:
        if o.type != "MESH" or not o.get("town"):
            continue
        for mt in o.data.materials:
            if mt is None or mt in seen or not mt.use_nodes:
                continue
            seen.add(mt)
            for n in mt.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    key = n.image.name.split(".")[0]
                    if key not in done:
                        done[key] = _repaint(n.image, swatches, "_" + name)
                    n.image = done[key]


class Build:
    def __init__(self, loc, turn):
        self.root = bpy.data.objects.new("shop", None)
        bpy.context.collection.objects.link(self.root)
        self.root.location = loc
        self.root.rotation_euler = (0, 0, math.radians(turn))
        self.parts = []

    def add(self, o):
        o.parent = self.root
        self.parts.append(o)
        return o

    def town(self, name, x, y, z, rot=0.0, s=1.0):
        o = V.place(name, (x, y, z), T * s, rot_z=math.radians(rot), folder=TOWN)
        o["town"] = True
        return self.add(o)

    def pirate(self, name, x, y, z=DECK_Z, rot=0.0, s=0.55):
        return self.add(V.place(name, (x, y, z), s, rot_z=math.radians(rot), folder=PIRATE))

    def wall(self, name, i, j, side, upper=False):
        """a wall on one side of house tile (i, j); side: the way the piece's +X looks"""
        rot = {"front": -90.0, "back": 90.0, "left": 180.0, "right": 0.0}[side]
        o = self.town(name, i * T, (j + 0.5) * T, DECK_Z + (T if upper else 0.0), rot)
        if upper:
            o.scale = (T, T, T * UPPER)
        return o


def _deck(b):
    """planks from the house's back to the steps, on posts that reach the ground"""
    dark = toon("#6f4a2c")
    nx, ny = 5, 3
    w, d = (X1 - X0) / nx, (Y1 - Y0) / ny
    for i in range(nx):
        for j in range(ny):
            p = b.town("planks", X0 + (i + 0.5) * w, Y0 + (j + 0.5) * d, 0.0, 90.0)
            p.scale = (d, w, T)
    b.add(cube(loc=((X0 + X1) / 2, Y0 - 0.03, -0.1), scale=(X1 - X0 + 0.12, 0.14, 0.36), mat=dark))
    b.add(cube(loc=(X0 - 0.03, (Y0 + Y1) / 2, -0.1), scale=(0.14, Y1 - Y0 + 0.12, 0.36), mat=dark))
    b.add(cube(loc=(X1 + 0.03, (Y0 + Y1) / 2, -0.1), scale=(0.14, Y1 - Y0 + 0.12, 0.36), mat=dark))
    for k in range(5):
        x = X0 + 0.12 + (X1 - X0 - 0.24) * k / 4.0
        b.add(cyl(loc=(x, Y0 + 0.08, -1.7), r=0.12, depth=3.3, mat=dark, verts=8))
    for y in (0.4 * T, Y1 - 0.12):
        for x in (X0 + 0.12, X1 - 0.12):
            b.add(cyl(loc=(x, y, -1.7), r=0.12, depth=3.3, mat=dark, verts=8))
    # steps down to the beach, in front of the door
    for k in range(3):
        b.add(cube(loc=(0.0, Y0 - 0.3 - k * 0.38, -0.14 - k * 0.26), scale=(1.9, 0.42, 0.09), mat=toon("#a9744a")))


def _house(b):
    # ground floor: stone, with the door in the middle
    for i, n in zip((-1, 0, 1), ("wall-window-shutters", "wall-door", "wall-window-shutters")):
        b.wall(n, i, 0, "front")
    for j in (0, 1):
        b.wall("wall-window-shutters" if j == 0 else "wall", -1, j, "left")
        b.wall("wall-window-shutters" if j == 1 else "wall", 1, j, "right")
    for i in (-1, 0, 1):
        b.wall("wall", i, 1, "back")
    # upper floor: timber
    for i, n in zip((-1, 0, 1), ("wall-wood-window-glass", "wall-wood-detail-cross", "wall-wood-window-glass")):
        b.wall(n, i, 0, "front", True)
    for j in (0, 1):
        b.wall("wall-wood-window-small" if j == 0 else "wall-wood-detail-cross", -1, j, "left", True)
        b.wall("wall-wood-detail-cross" if j == 0 else "wall-wood-window-small", 1, j, "right", True)
    for i in (-1, 0, 1):
        b.wall("wall-wood", i, 1, "back", True)
    # the roof: the ridge runs left to right over the house's middle
    for i, n, y, rot in [(-1, "roof-left", 0.5, 90.0), (0, "roof-window", 0.5, 90.0), (1, "roof-right", 0.5, 90.0),
                         (-1, "roof-right", 1.5, -90.0), (0, "roof", 1.5, -90.0), (1, "roof-left", 1.5, -90.0)]:
        o = b.town(n, i * T, y * T, WALLS, rot)
        o.scale = (T, T, T * ROOF_Z)
    b.town("chimney", 1.15 * T, 0.8 * T, WALLS - 0.1, 90.0, s=0.8)


def _sign(b):
    """a golden fish on the ridge: the shop's sign, seen from across the bay"""
    t = toon("#6f4a2c")
    b.add(cyl(loc=(-0.8, T, ROOF_TOP + 0.16), r=0.06, depth=0.5, mat=t, verts=8))
    fish = M.build_fish(dict(top="#ffcf3f", belly="#fff1a8", fin="#e0a01f", L=1.05, H=0.45, W=0.17))
    for o in fish:
        o.location = o.location + Vector((-0.8, T, ROOF_TOP + 0.6))
        b.add(o)


def _props(b):
    d = DECK_Z
    # a market stall to the right of the house, its table along the front
    sx, sy = 2.12 * T, -0.14 * T
    b.town("stall-red", sx, sy, d, 90.0, s=1.0)
    top = d + 0.37 * T + 0.03
    b.add(cube(loc=(sx, sy, top), scale=(0.95, 0.42, 0.05), mat=toon("#eaf6ff")))        # ice
    for k, col in enumerate(["#6f8fa8", "#ffb02e", "#c86b5a", "#6f8fa8"]):
        f = M.build_fish(dict(top=col, belly="#eef3f6", fin=col, L=0.15, H=0.065, W=0.045))
        for o in f:
            o.location = o.location + Vector((sx - 0.34 + k * 0.23, sy - 0.02 + (k % 2) * 0.1, top + 0.07))
            b.add(o)
    # barrels and crates by the left corner
    b.pirate("barrel", X0 + 0.42, -0.12, rot=20.0, s=0.44)
    b.pirate("barrel", X0 + 0.36, -0.78, rot=70.0, s=0.38)
    b.pirate("crate", X0 + 1.02, -0.45, rot=12.0, s=0.42)
    # rods leaning on the wall by the door
    for i, c in enumerate(["#4aa3ff", "#ffd23f", "#e0533e"]):
        x = 1.0 + i * 0.13
        b.add(K.tube([(x, -0.32, d + 0.05), (x + 0.07, -0.04, d + 1.6)], 0.026, mat=toon(c, soft=True), taper=(1.0, 0.5)))
    # a life ring on the wall
    b.add(torus(loc=(-1.38, -0.1, d + 0.88), R=0.22, r=0.065, rot=(90, 0, 0), mat=toon("#e0533e", soft=True)))
    # lanterns on the deck's front corners, a banner over the door
    for x in (X0 + 0.14, X1 - 0.14):
        b.town("lantern", x, Y0 + 0.14, d, 0.0, s=0.72)
    o = b.town("banner-green", 0.0, -0.05, d + 0.98 * T, -90.0, s=0.7)
    o.scale = (T * 0.7, T * 0.7, T * 0.5)


def key_points():
    """local points that bound the shop (for the search of its spot): the deck's corners first, then the roof and the sign"""
    return [(X0, Y0, 0.0), (X1, Y0, 0.0), (X0, Y1, 0.0), (X1, Y1, 0.0), (-1.55 * T, T, ROOF_TOP), (1.55 * T, T, ROOF_TOP), (-0.8, T, SIGN_TOP)]


def light_points():
    """(local position, kind) of what lights up after dark"""
    d = DECK_Z
    lamp = d + 1.05 * T
    out = [((X0 + 0.14, Y0 + 0.14, lamp), "lamp"), ((X1 - 0.14, Y0 + 0.14, lamp), "lamp"), ((0.0, -0.04, d + 0.42 * T), "door"),
           ((-1.5 * T - 0.04, 0.5 * T, d + 0.52 * T), "window"), ((0.0, 0.32 * T, WALLS + 0.3 * T), "window")]
    for i in (-1, 1):
        out.append(((i * T, -0.04, d + 0.52 * T), "window"))
        out.append(((i * T, -0.04, d + (1.0 + 0.5 * UPPER) * T), "window"))
    return out


def to_world(p, loc, turn=TURN):
    c, s = math.cos(math.radians(turn)), math.sin(math.radians(turn))
    return (loc[0] + p[0] * c - p[1] * s, loc[1] + p[0] * s + p[1] * c, loc[2] + p[2])


def build(loc, biome="River", turn=TURN):
    """-> (parts, the shopkeeper's world position, the chimney's top)"""
    b = Build(loc, turn)
    _deck(b)
    _house(b)
    _sign(b)
    _props(b)
    _apply_theme(b.parts, THEMES.get(biome, THEMES["River"]), biome)
    bpy.context.view_layer.update()
    m = b.root.matrix_world
    return b.parts, m @ Vector((MERCHANT_AT[0], MERCHANT_AT[1], DECK_Z)), m @ Vector((1.33 * T, 0.8 * T, WALLS + 0.72 * T))

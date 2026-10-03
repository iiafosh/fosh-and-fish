"""Render every Virtual Fisher sprite with Blender (Eevee, cel-shaded).

Usage (from repo root):
  D:/Blender/blender-4.2.3-windows-x64/blender.exe -b --factory-startup \
      --python tools/blender/render_assets.py -- [category ...] [--only NAME]

Categories: fish exotics pets rods boats baits chests charms ui biomes
Output: assets/vf/<category>/<slug>.png and assets/vf/manifest.json
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import vf_kit as K  # noqa: E402
import vf_models as M  # noqa: E402
import vf_boats as B  # noqa: E402
import vf_props as P  # noqa: E402
import vf_biomes as BI  # noqa: E402
import vf_topdown as TD  # noqa: E402
import vf_critters as CR  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "vf")
MANIFEST = os.path.join(OUT, "manifest.json")


def slug(name):
    return name.lower().replace(" ", "_").replace(".", "")


def load_manifest():
    if os.path.exists(MANIFEST):
        with open(MANIFEST) as f:
            return json.load(f)
    return {}


def save_manifest(m):
    os.makedirs(OUT, exist_ok=True)
    with open(MANIFEST, "w") as f:
        json.dump(m, f, indent=1, sort_keys=True)


def icon_scene(size=256, rot=(76, 0, 20), light=(48, 8, 40)):
    K.clear_scene()
    K.FOG["color"] = None
    K.setup_render(size, size, samples=24)
    K.setup_world("#6a6a78", 1.0)
    K.sun(light, 1.0)
    return K.make_camera(rot)


def render_icon(parts, path, outline=0.035, rot=(76, 0, 20), size=256, margin=1.15, light=(48, 8, 40)):
    cam = bpy.context.scene.camera
    K.outline_all(parts, outline)
    K.frame_ortho(cam, parts, margin)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    K.render(path)


def want(name, only):
    return not only or slug(name) in only or name in only


def do_fish(only):
    for name, spec in M.FISH_SPECS.items():
        if not want(name, only):
            continue
        icon_scene()
        parts = M.build_fish(spec)
        render_icon(parts, os.path.join(OUT, "fish", slug(name) + ".png"))


def do_exotics(only):
    for key, spec in M.EXOTIC_SPECS.items():
        if not want(key, only):
            continue
        icon_scene()
        parts = M.build_fish(spec)
        render_icon(parts, os.path.join(OUT, "exotics", key + ".png"))


def do_pets(only):
    for name, spec in M.PET_SPECS.items():
        if not want(name, only):
            continue
        icon_scene(rot=(78, 0, 28))
        parts = M.build_fish(spec)
        render_icon(parts, os.path.join(OUT, "pets", slug(name) + ".png"), rot=(78, 0, 28))


def do_rods(only):
    for name, spec in M.ROD_SPECS.items():
        if not want(name, only):
            continue
        icon_scene(rot=(90, 0, 0), light=(40, 20, 30))
        K.seed(1)
        parts = M.build_rod(spec)
        render_icon(parts, os.path.join(OUT, "rods", slug(name) + ".png"), outline=0.025)


def do_boats(only, man):
    for name in B.BOAT_ORDER:
        if not want(name, only):
            continue
        # shop icon (3/4 view, no fisher)
        icon_scene(size=320, rot=(72, 0, 32), light=(50, 10, 60))
        parts, _deck = B.build_boat(name)
        render_icon(parts, os.path.join(OUT, "boats", slug(name) + ".png"), outline=0.05, size=320)


def do_props(cat, only):
    for name, builder in P.PROPS[cat].items():
        if not want(name, only):
            continue
        cfg = P.PROP_VIEW.get(cat, {})
        icon_scene(rot=cfg.get("rot", (72, 0, 28)))
        K.seed(3)
        parts = builder()
        render_icon(parts, os.path.join(OUT, cat, slug(name) + ".png"), outline=cfg.get("outline", 0.035),
                    rot=cfg.get("rot", (72, 0, 28)))


def do_biomes(only, man):
    bm = man.setdefault("biomes", {})
    for name in BI.BIOMES:
        if not want(name, only):
            continue
        info = BI.render_biome(name, os.path.join(OUT, "biomes", slug(name) + ".png"))
        bm[name] = info


def do_scenes(only, man):
    sm = man.setdefault("scenes", {})
    for name in TD.BIOMES:
        if not want(name, only):
            continue
        d = os.path.join(OUT, "scenes")
        os.makedirs(d, exist_ok=True)
        sm[name] = TD.render_scene(name, os.path.join(d, slug(name) + ".png"), os.path.join(d, slug(name) + "_mask.png"))


def do_boats_top(only, man):
    bt = man.setdefault("boats_top", {})
    for name in B.BOAT_ORDER:
        if not want(name, only):
            continue
        d = os.path.join(OUT, "boats_top")
        os.makedirs(d, exist_ok=True)
        bt[name] = TD.render_boat_top(name, os.path.join(d, slug(name) + ".png"))


def do_fish_top(only):
    d = os.path.join(OUT, "fish_top")
    os.makedirs(d, exist_ok=True)
    for name, spec in M.FISH_SPECS.items():
        if want(name, only):
            TD.render_fish_top(name, spec, os.path.join(d, slug(name) + ".png"))


def do_critters(only, man):
    d = os.path.join(OUT, "swim")
    os.makedirs(d, exist_ok=True)
    for key in CR.SWIMMERS:
        if want(key, only):
            CR.render_swimmer(key, os.path.join(d, slug(key) + ".png"))
    man["swim"] = {"frames": CR.FRAMES, "cell": CR.CELL, "species": [k for k in CR.SWIMMERS]}
    d = os.path.join(OUT, "critters")
    os.makedirs(d, exist_ok=True)
    if want("gull", only):
        CR.render_gull(os.path.join(d, "gull.png"))
        man["gull"] = {"frames": 8, "cell": 160}
    if want("crab", only):
        CR.render_static("crab", os.path.join(d, "crab.png"), 96, rot_z=0)


def do_fisher(man):
    man["fisher"] = CR.render_fisher(os.path.join(OUT, "fisher"))


def do_merchant(man):
    man["merchant"] = CR.render_merchant(os.path.join(OUT, "merchant"))


def do_rods_hand(only, man):
    d = os.path.join(OUT, "rods_hand")
    os.makedirs(d, exist_ok=True)
    rh = man.setdefault("rods_hand", {})
    for name in M.ROD_SPECS:
        if want(name, only):
            rh[name] = CR.render_rod_strip(name, os.path.join(d, slug(name) + ".png"))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = []
    if "--only" in argv:
        i = argv.index("--only")
        only = [s.strip() for s in argv[i + 1].split(",")]
        argv = argv[:i] + argv[i + 2:]
    cats = argv or ["fish", "exotics", "pets", "rods", "baits", "chests", "charms", "ui", "boats", "scenes", "boats_top", "fish_top", "critters", "fisher", "rods_hand", "merchant"]
    man = load_manifest()
    for c in cats:
        print("== rendering", c)
        if c == "fish":
            do_fish(only)
        elif c == "exotics":
            do_exotics(only)
        elif c == "pets":
            do_pets(only)
        elif c == "rods":
            do_rods(only)
        elif c == "boats":
            do_boats(only, man)
        elif c == "biomes":
            do_biomes(only, man)
        elif c == "scenes":
            do_scenes(only, man)
        elif c == "boats_top":
            do_boats_top(only, man)
        elif c == "fish_top":
            do_fish_top(only)
        elif c == "critters":
            do_critters(only, man)
        elif c == "fisher":
            do_fisher(man)
        elif c == "rods_hand":
            do_rods_hand(only, man)
        elif c == "merchant":
            do_merchant(man)
        elif c in P.PROPS:
            do_props(c, only)
        save_manifest(man)
    print("done")


if __name__ == "__main__":
    main()

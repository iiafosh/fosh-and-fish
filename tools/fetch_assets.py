#!/usr/bin/env python3
"""Download the third-party source packs listed in CREDITS.md into
scratch/downloads/ (git-ignored). Needed only to re-run the Blender
pipeline (tools/blender/render_assets.py)."""
import os
import urllib.request
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DL = os.path.join(ROOT, "scratch", "downloads")

ZIPS = {
    "kenney_particle": "https://kenney.nl/media/pages/assets/particle-pack/f8fe0f8cb8-1677578741/kenney_particle-pack.zip",
    "kenney_watercraft": "https://kenney.nl/media/pages/assets/watercraft-kit/a335cfed49-1713519620/kenney_watercraft-pack.zip",
    "kenney_interface": "https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
    "kenney_ui_adventure": "https://kenney.nl/media/pages/assets/ui-pack-adventure/9a877376bc-1723597274/kenney_ui-pack-adventure.zip",
    "kenney_nature": "https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip",
    "splash_sfx": "https://opengameart.org/sites/default/files/water-splash-slime-sfx.zip",
}
GLBS = {
    "dolphin": "fcea284f-cafc-4be1-a701-2a0fd811ad5c", "shark": "d2d374ea-eb1d-4659-8cc7-816a83b82470",
    "fish1": "6805b99c-5fd7-4aab-bf57-3bb645e1108a", "whale": "7300e697-2543-4a9a-a77d-dedf29251fd7",
    "fish2": "311a79f6-ba3e-47aa-80ce-04185fc76b2a", "fish3": "8410757e-6594-4011-817a-633730fbcaf8",
    "manta": "32b4e08e-4605-4356-8bd3-e0cf32335a0f", "gull": "882c4ff3-c97b-4ae2-aedf-953c8d692898",
    "crab": "1acf95b5-2e6b-4c9d-bd37-8384b88bdbea", "character": "ba7a1955-ea51-4cb9-a561-188bdef0a6c7",
    "chest": "803af4ae-433f-4b05-b1f1-c6a2da02d768",
}


def get(url, path):
    if os.path.exists(path):
        return
    print("fetch", url)
    req = urllib.request.Request(url, headers={"User-Agent": "vfish-asset-fetch"})
    with urllib.request.urlopen(req) as r, open(path, "wb") as f:
        f.write(r.read())


def main():
    os.makedirs(os.path.join(DL, "glb"), exist_ok=True)
    for name, url in ZIPS.items():
        z = os.path.join(DL, name + ".zip")
        get(url, z)
        with zipfile.ZipFile(z) as zf:
            zf.extractall(os.path.join(DL, "x_" + name))
    for name, uid in GLBS.items():
        get("https://static.poly.pizza/%s.glb" % uid, os.path.join(DL, "glb", name + ".glb"))
    print("done ->", DL)


if __name__ == "__main__":
    main()

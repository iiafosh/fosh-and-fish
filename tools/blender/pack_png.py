"""Re-save PNGs as small as lossless gets: Blender writes them about twice as big as they need to be.
    python tools/blender/pack_png.py <png or folder> ...
Run it with the system Python (it needs Pillow), not Blender's. A picture is only replaced when the new file has exactly
the same pixels, so this never changes how anything looks.
"""
import os
import sys

from PIL import Image


def pack(path):
    """-> (bytes before, bytes after)"""
    before = os.path.getsize(path)
    im = Image.open(path)
    im.load()
    tmp = path + ".packing.png"
    im.save(tmp, optimize=True, compress_level=9)
    same = Image.open(tmp).convert("RGBA").tobytes() == im.convert("RGBA").tobytes()
    if same and os.path.getsize(tmp) < before:
        os.replace(tmp, path)
    else:
        os.remove(tmp)
    return before, os.path.getsize(path)


def main(args):
    files = []
    for a in args:
        if os.path.isdir(a):
            files += [os.path.join(a, f) for f in sorted(os.listdir(a)) if f.lower().endswith(".png")]
        else:
            files.append(a)
    total0 = total1 = 0
    for f in files:
        b0, b1 = pack(f)
        total0, total1 = total0 + b0, total1 + b1
        print("%-60s %9d -> %9d" % (f, b0, b1))
    print("%d files: %.1f MB -> %.1f MB" % (len(files), total0 / 1e6, total1 / 1e6))


if __name__ == "__main__":
    main(sys.argv[1:])

#!/usr/bin/env python3
"""The game's cartoon sounds, synthesized here (no samples, nothing to credit) -> assets/audio/fun/*.ogg.
Short and soft on purpose: they come up often, in the mini-game and when you poke things.
   python tools/video/make_sfx.py"""
import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio", "fun")
SR = 44100
rng = np.random.default_rng(7)


def times(sec):
    return np.arange(int(sec * SR)) / SR


def osc(freq, shape="sine"):
    """an oscillator following a frequency curve (Hz per sample)"""
    ph = np.cumsum(freq) / SR
    if shape == "sine":
        return np.sin(2 * np.pi * ph)
    if shape == "tri":
        return 2 * np.abs(2 * (ph % 1.0) - 1) - 1
    return 2 * (ph % 1.0) - 1          # saw


def fade(x, a=0.006, r=0.03):
    n = len(x)
    e = np.ones(n)
    na, nr = max(1, int(a * SR)), max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr)
    return x * e


def band(x, lo, hi):
    sos = signal.butter(2, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def low(x, hi):
    return signal.sosfilt(signal.butter(2, hi, btype="low", fs=SR, output="sos"), x)


def boing():
    t = times(0.5)
    f = 170 * (1 + 0.55 * np.sin(2 * np.pi * 11 * t) * np.exp(-5 * t)) * (1 + 0.5 * t)
    return fade(osc(f) * np.exp(-5.5 * t), 0.002, 0.05)


def squeak():
    t = times(0.2)
    f = np.interp(t, [0, 0.05, 0.12, 0.2], [900, 1650, 1500, 1050])
    return fade(band(osc(f, "saw"), 700, 3800) * 1.4, 0.008, 0.04)


def quack():
    t = times(0.17)
    f = np.interp(t, [0, 0.04, 0.17], [300, 330, 210])
    return fade(band(osc(f, "saw"), 500, 2200) * 1.6, 0.004, 0.04)


def slide(a, b, sec):
    t = times(sec)
    f = np.geomspace(a, b, len(t)) * (1 + 0.012 * np.sin(2 * np.pi * 6 * t))
    return fade(osc(f, "tri") * 0.8, 0.02, 0.06)


def pop():
    t = times(0.08)
    return fade(osc(np.geomspace(900, 180, len(t))) * np.exp(-30 * t), 0.001, 0.01)


def horn():
    """a ship's horn, a bit silly: a low chord that sags at the end"""
    t = times(1.0)
    sag = 1 - 0.07 * np.clip((t - 0.65) / 0.35, 0, 1) ** 2
    x = osc(98 * sag, "saw") + 0.8 * osc(147 * sag, "saw") + 0.5 * osc(196 * sag, "saw")
    return fade(low(x, 900) * 0.5, 0.05, 0.14)


def shutter():
    x = np.zeros(int(0.12 * SR))
    for at, a in ((0, 1.0), (int(0.055 * SR), 0.8)):
        n = int(0.022 * SR)
        x[at:at + n] += rng.normal(0, 1, n) * np.exp(-np.arange(n) / (0.006 * SR)) * a
    return band(x, 1800, 9000) * 1.2


def dundun():
    """something big is coming"""
    out = np.zeros(int(1.0 * SR))
    for at, f in ((0.0, 82.4), (0.48, 87.3)):
        t = times(0.42)
        x = low(osc(np.full(len(t), f), "saw"), 500) * np.exp(-3.2 * t)
        out[int(at * SR):int(at * SR) + len(x)] += fade(x, 0.008, 0.05)
    return out


def whoosh():
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    x = rng.normal(0, 1, n)
    out = np.zeros(n)
    # a band of noise sweeping up, and fading
    for i in range(0, n, 512):
        k = i / n
        lo = 300 + 2200 * k
        seg = band(x[i:i + 1024], lo, lo * 2.2) if i + 1024 < n else x[i:i + 512] * 0
        out[i:i + len(seg)] += seg * np.hanning(len(seg))
    return fade(out * np.sin(np.pi * t / t[-1]) * 1.6, 0.02, 0.05)


def clunk():
    t = times(0.2)
    return fade(osc(np.geomspace(190, 70, len(t))) * np.exp(-20 * t) + band(rng.normal(0, 1, len(t)), 300, 1600) * np.exp(-45 * t) * 0.5, 0.001, 0.03)


def squawk():
    t = times(0.3)
    f = np.interp(t, [0, 0.08, 0.3], [800, 1020, 640])
    am = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 42 * t))
    return fade(band(osc(f, "saw") * am, 800, 4200) * 1.5, 0.008, 0.06)


def pfff():
    """a balloon let go"""
    t = times(0.95)
    f = np.geomspace(620, 170, len(t)) * (1 + 0.13 * np.sin(2 * np.pi * 31 * t))
    x = band(osc(f, "saw"), 200, 2600) + band(rng.normal(0, 1, len(t)), 1200, 5000) * 0.25
    return fade(x * 0.9, 0.01, 0.08)


def ding():
    t = times(0.6)
    return fade((np.sin(2 * np.pi * 1320 * t) + 0.45 * np.sin(2 * np.pi * 2640 * t) + 0.2 * np.sin(2 * np.pi * 3960 * t)) * np.exp(-6.5 * t) * 0.6, 0.001, 0.05)


def snip():
    out = np.zeros(int(0.26 * SR))
    for at in (0, int(0.13 * SR)):
        n = int(0.05 * SR)
        out[at:at + n] += band(rng.normal(0, 1, n), 2500, 9000) * np.exp(-np.arange(n) / (0.01 * SR)) * 1.5
    return out


SOUNDS = {"boing": boing, "squeak": squeak, "quack": quack, "slide_up": lambda: slide(320, 1300, 0.42), "slide_down": lambda: slide(1300, 260, 0.5),
          "pop": pop, "horn": horn, "shutter": shutter, "dundun": dundun, "whoosh": whoosh, "clunk": clunk, "squawk": squawk, "pfff": pfff,
          "ding": ding, "snip": snip}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        x = np.asarray(fn(), dtype=np.float64)
        x = x / max(1e-6, np.abs(x).max()) * 0.5                  # all at one level, with plenty of room
        path = os.path.join(tempfile.gettempdir(), "vf_%s.wav" % name)
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((x * 32767).astype(np.int16).tobytes())
        out = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", path, "-c:a", "libvorbis", "-q:a", "3", out], check=True)
        os.remove(path)
        print(name, round(len(x) / SR, 2), "s", os.path.getsize(out) // 1024, "KB")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Small images for the stage's shaders and lights (assets/vf/fx/):
noise.png: 256 x 256, seamless. Red: cloud-like (1/f). Green: small blobs (band-limited). Histograms evened out, so every
           level is equally common and a threshold in a shader means "this share of the area".
glow.png:  a soft round light, for the lights after dark.
   python tools/art/make_fx.py"""
import os

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "vf", "fx")
n = 256
fx, fy = np.meshgrid(np.fft.fftfreq(n) * n, np.fft.fftfreq(n) * n)
k = np.sqrt(fx ** 2 + fy ** 2)
k[0, 0] = 1.0


def even(a):
    order = a.ravel().argsort()
    rank = np.empty(n * n, dtype=np.float64)
    rank[order] = np.arange(n * n) / (n * n - 1.0)
    return (rank.reshape(n, n) * 255.0 + 0.5).astype(np.uint8)


os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)
f = np.fft.fft2(rng.normal(size=(n, n))) / k ** 1.35
f[0, 0] = 0.0
red = even(np.real(np.fft.ifft2(f)))
f = np.fft.fft2(rng.normal(size=(n, n))) * np.exp(-((k - 42.0) / 16.0) ** 2)
green = even(np.real(np.fft.ifft2(f)))
Image.fromarray(np.dstack([red, green, np.zeros_like(red)]), "RGB").save(os.path.join(OUT, "noise.png"), optimize=True)

g = 128
y, x = np.mgrid[0:g, 0:g]
r = np.hypot(x - (g - 1) / 2.0, y - (g - 1) / 2.0) / (g / 2.0)
glow = np.clip(1.0 - r, 0.0, 1.0) ** 2.2
a = (glow * 255.0 + 0.5).astype(np.uint8)
Image.fromarray(np.dstack([np.full_like(a, 255), np.full_like(a, 255), np.full_like(a, 255), a]), "RGBA").save(os.path.join(OUT, "glow.png"), optimize=True)
print("saved", OUT)

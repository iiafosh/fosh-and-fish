#!/usr/bin/env python3
"""The game's cartoon sounds, synthesized here (no samples, nothing to credit) -> assets/audio/fun/*.ogg.
Short and soft on purpose: they come up often, in the mini-game and when you poke things.
   python tools/video/make_sfx.py [name ...]          (no names: all of them)"""
import os
import subprocess
import sys
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


def put(out, at, x):
    """mix x into out, at seconds"""
    i = int(at * SR)
    out[i:i + len(x)] += x[:len(out) - i]


def vowel(x, formants):
    """a saw into a mouth: one resonance per (Hz, level)"""
    return sum(signal.lfilter(*signal.iirpeak(f, f / 140, fs=SR), x) * a for f, a in formants)


def huh(f0, sec, oh):
    """one 'huh' of a chuckle: a breath, then a low voice that sags. oh: how far the vowel rounds into 'oh'"""
    t = times(sec)
    k = t / sec
    v = osc(f0 * (1.05 - 0.12 * k - 0.22 * k ** 3) * (1 + 0.006 * np.sin(2 * np.pi * 7 * t)), "saw")
    voice = vowel(v, ((540, 2.0), (1010, 1.2), (2030, 0.2))) * (1 - oh * k) + vowel(v, ((430, 2.0), (730, 1.2), (2050, 0.15))) * oh * k + low(v, 280) * 0.3
    breath = vowel(rng.normal(0, 1, len(t)), ((540, 1.0), (1010, 0.6))) * 0.9
    return fade((voice * np.minimum(t / 0.022, 1) + breath * np.exp(-t / 0.02)) * np.exp(-t / (sec * 0.6)), 0.006, 0.03)


def laugh():
    """Gerald, very pleased with himself: a fat 'huh-huh-huh-hoh' and one bubble. Low and round, because it plays often"""
    out = np.zeros(int(0.92 * SR))
    for at, f, sec, oh, level in ((0, 120, 0.15, 0.3, 0.85), (0.19, 113, 0.15, 0.3, 1.0), (0.38, 106, 0.15, 0.3, 0.85), (0.57, 96, 0.32, 1.0, 0.95)):
        put(out, at, huh(f, sec, oh) * level)
    t = times(0.05)
    put(out, 0.85, fade(osc(np.geomspace(420, 980, len(t))) * 0.1, 0.004, 0.012))
    return low(out, 2400)


def brass(f, sec):
    """a fat, slightly sour horn that opens up right after the attack. f: Hz, or a curve"""
    t = times(sec)
    x = osc(f * np.ones(len(t)), "saw") + osc(f * 1.007 * np.ones(len(t)), "saw")
    return fade(low(x, 350) * 0.6 + band(x, 350, 1500) * 1.5 + band(x, 1500, 3200) * (0.15 + 0.85 * np.exp(-t / 0.06)), 0.01, 0.03)


def sting():
    """Gerald shows up: bwa-bwa-BWAAA, a villain's chord, and the last note gives up"""
    out = np.zeros(int(0.95 * SR))
    for at in (0, 0.15):
        put(out, at, (brass(146.8, 0.11) + brass(73.4, 0.11) * 0.3) * 0.75)
    t = times(0.62)
    bend = (1 + 0.02 * np.sin(2 * np.pi * 7 * t) * np.clip(t / 0.2, 0, 1)) * (1 - 0.26 * np.clip((t - 0.34) / 0.28, 0, 1) ** 2)
    put(out, 0.3, brass(207.7 * bend, 0.62) + brass(146.8 * bend, 0.62) * 0.7 + brass(73.4 * bend, 0.62) * 0.3)
    return out


def kazoo(f, sec):
    """a kazoo-ish buzz: nasal and not quite in tune. f: Hz, or a curve"""
    t = times(sec)
    f = f * np.ones(len(t))
    x = (osc(f, "saw") + osc(f * 1.009, "saw") * 0.7) * (0.8 + 0.2 * np.sin(2 * np.pi * 61 * t))
    return fade(band(x, 420, 3000) + band(x, 1000, 1700) * 0.6, 0.012, 0.03)


def fanfare():
    """you finally got him: da-da-da-DAAA on a bad kazoo band, and one late toot"""
    out = np.zeros(int(0.97 * SR))
    for at in (0, 0.1, 0.2):
        put(out, at, kazoo(392, 0.085) * 0.7)
    t = times(0.47)
    bend = np.interp(t, [0, 0.05], [0.93, 1]) * (1 + 0.022 * np.sin(2 * np.pi * 7.5 * t) * np.clip(t / 0.22, 0, 1))
    put(out, 0.3, kazoo(523.3 * bend, 0.47) + kazoo(659.3 * bend, 0.47) * 0.7 + brass(130.8, 0.47) * 0.2)
    put(out, 0.83, kazoo(784, 0.13) * 0.7)
    return band(np.tanh(out), 120, 9000)


def mallet(f, sec):
    """a soft wooden note, with a tock at the start"""
    t = times(sec)
    return fade((np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 4 * f * t) * np.exp(-40 * t)) * np.exp(-7 * t), 0.002, 0.03)


def find_new():
    """a small happy discovery: three notes up, and a glint on the last"""
    out = np.zeros(int(0.62 * SR))
    for at, f, level in ((0, 587.3, 0.7), (0.09, 784, 0.8), (0.18, 987.8, 1.0)):
        put(out, at, mallet(f, 0.44) * level)
    put(out, 0.18, mallet(1975.5, 0.3) * 0.18)
    return out


def bell(f, sec):
    t = times(sec)
    return fade((np.sin(2 * np.pi * f * t) + 0.45 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-3 * t) + 0.15 * np.sin(2 * np.pi * 4.2 * f * t) * np.exp(-12 * t)) * np.exp(-5 * t), 0.001, 0.05)


def ach():
    """claiming an achievement: ta-DING, a rolled chord of bells with a soft thump under it"""
    out = np.zeros(int(0.82 * SR))
    put(out, 0, bell(784, 0.07) * 0.6)
    for at, f in ((0.07, 1046.5), (0.095, 1318.5), (0.12, 1568)):
        put(out, at, bell(f, 0.7) * 0.6)
    t = times(0.14)
    put(out, 0.07, fade(np.sin(2 * np.pi * 261.6 * t) * np.exp(-24 * t), 0.002, 0.02))
    return out


def hat_on():
    """a soft comic pop: a round 'bwop' going up, and a puff of felt"""
    t = times(0.17)
    f = 220 + 480 * (1 - np.exp(-t / 0.03))
    x = (osc(f) + 0.25 * osc(f * 2)) * np.exp(-26 * t)
    return fade(x + low(rng.normal(0, 1, len(t)), 1400) * np.exp(-t / 0.012) * 0.6, 0.003, 0.02)


SOUNDS = {"boing": boing, "squeak": squeak, "quack": quack, "slide_up": lambda: slide(320, 1300, 0.42), "slide_down": lambda: slide(1300, 260, 0.5),
          "pop": pop, "horn": horn, "shutter": shutter, "dundun": dundun, "whoosh": whoosh, "clunk": clunk, "squawk": squawk, "pfff": pfff,
          "ding": ding, "snip": snip, "laugh": laugh, "sting": sting, "fanfare": fanfare, "find_new": find_new, "ach": ach, "hat_on": hat_on}


def main():
    only = sys.argv[1:]
    if set(only) - set(SOUNDS):
        sys.exit("no such sound: %s" % ", ".join(sorted(set(only) - set(SOUNDS))))
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        x = np.asarray(fn(), dtype=np.float64)                    # every sound runs, so each still gets the same noise from rng
        if only and name not in only:
            continue
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

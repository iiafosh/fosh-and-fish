"""Soundtrack for the fosh&fish KABOOM video (tools/video/edit_boom.py), on boom_timeline's frames.

Original music, synthesized (music.py's ukulele / marimba / drums, plus a saw lead, sub booms, snare
rolls and cartoon boings), and CC0 sound effects placed on the frames where things happen:
Kenney Impact Sounds + Interface Sounds and rubberduck's water SFX (scratch/downloads, see CREDITS.md).

    0:00 cozy ukulele, water, birds ... the bobber goes "bloop", the music holds its breath
    0:04 KABOOM and the drop       0:06 a rising pluck on every logo letter, a boing for the fish
    0:08 a hit + whoosh on every world, splashes on every leap, the volcano, the shuttle, the abyss (muffled)
    0:20 screen slams and UI pops  0:28 build: snare roll, riser, boat whooshes, a breath of silence
    0:32 the big KABOOM, the drop, the logo run    0:36 the last chord rings out

    python tools/video/music_boom.py OUT.wav [--sfx-only]

--sfx-only: no music at all, just the sound design (every scene gets its own bed: water and birds, lava,
waves, wind, a space hum, a UFO, the abyss; engines for the boats).
"""
import os
import subprocess
import sys

import imageio_ffmpeg
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import boom_timeline as T  # noqa: E402
from music import (BEAT, CHORDS, MOTIF_A, MOTIF_B, PROG, ROOT, SR, STRUM, bass, clap, hat, impact, kick,  # noqa: E402
                   marimba, midi, noise_hit, pluck, riser, save, shaker, whoosh)

HERE = os.path.dirname(os.path.abspath(__file__))
DL = os.path.join(HERE, "..", "..", "scratch", "downloads")
FF = imageio_ffmpeg.get_ffmpeg_exe()
rng = np.random.default_rng(11)
DUR = T.TOTAL / T.FPS + 0.5


def sec(f):
    return f / float(T.FPS)


def bar_t(b, beat=0.0):
    return (b * 4 + beat) * BEAT


# ------------------------------------------------------------- instruments
def adsr(n, a=0.01, d=0.15, s=0.6, r=0.08):
    t = np.arange(n) / SR
    dur = n / SR
    e = np.where(t < a, t / a, s + (1 - s) * np.exp(-(t - a) / d))
    rel = np.clip((dur - t) / r, 0, 1)
    return e * rel


def saw(freq, dur, detune=0.006, gain=0.3):
    """two detuned band-limited saws: the bright lead of the drops"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    vib = 1 + 0.003 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.2, 0, 1)
    for d in (1 - detune, 1 + detune):
        f = freq * d
        ph = 2 * np.pi * np.cumsum(f * vib) / SR
        kmax = int(min(36, 9000 / f))
        for k in range(1, kmax + 1):
            out += np.sin(k * ph) / k * (1 - 0.5 * k / kmax)
    return out * 0.5 * adsr(n) * gain


def sub_boom(dur=2.2, f0=95.0, f1=30.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t / 0.12)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.85)
    return np.tanh(2.2 * s) * 0.9


def lowpass(x, a):
    """one-pole low-pass; a: coefficient per sample (array or float, 0..1)"""
    a = np.broadcast_to(np.asarray(a, dtype=float), x.shape)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def explosion(dur=2.8):
    """a cartoon blast: a noise burst whose filter closes, crackle, and a sub boom"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    body = lowpass(rng.uniform(-1, 1, n), 0.02 + 0.55 * np.exp(-t / 0.18)) * np.exp(-t / 0.75) * 2.2
    crk = np.zeros(n)
    for i in rng.integers(0, int(n * 0.7), 140):
        k = min(n - i, 600)
        crk[i:i + k] += rng.uniform(-1, 1, k) * np.exp(-np.arange(k) / 90.0) * rng.uniform(0.2, 1.0)
    crk *= np.exp(-t / 0.9) * 0.35
    attack = np.clip(t / 0.004, 0, 1)
    return (body + crk + sub_boom(dur) * 0.9) * attack


def snare(gain=1.0):
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.045) * 0.55
    return (tone + noise_hit(0.22, 0.06, hp=0.5) * 0.75) * gain


def crash(dur=1.8):
    return noise_hit(dur, 0.5, hp=0.9) * 0.45


def boing(dur=0.5, f0=260.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (1 + 0.9 * t / dur) * (1 + 0.25 * np.sin(2 * np.pi * 14 * t) * np.exp(-t / 0.18))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.22) * np.clip(t / 0.005, 0, 1) * 0.8


def puff(dur=0.35):
    """a balloon-ish inflate: a rising, wobbling tone"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 160 + 420 * (t / dur) ** 1.5
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    return s * np.sin(np.pi * t / dur) ** 0.6 * 0.45


def zap(dur=0.35):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 220 + 2200 * np.exp(-t / 0.05)
    return np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * np.exp(-t / 0.09) * 0.25


def chirp(base=2600.0):
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    f = base + 1500 * np.sin(np.pi * t / 0.09)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / 0.09) * 0.5


def rumble(dur=1.4):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = lowpass(rng.uniform(-1, 1, n), 0.012) * 6.0
    return x * np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.5


def swell(dur=0.6):
    """a reversed-cymbal swell into a hit"""
    return crash(dur)[::-1] * 0.8


def fades(n, a=0.3, b=0.3):
    t = np.arange(n) / SR
    return np.clip(t / a, 0, 1) * np.clip((n / SR - t) / b, 0, 1)


def engine(dur=1.0, f0=95.0):
    """a motor zooming past: higher and louder coming in, lower going away (doppler)"""
    n = int(dur * SR)
    u = np.arange(n) / n
    f = f0 * (1.22 - 0.44 * (0.5 + 0.5 * np.tanh((u - 0.5) * 8)))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.tanh(2.5 * (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph + 0.7)))
    rum = lowpass(rng.uniform(-1, 1, n), 0.08) * 3
    return (tone * 0.5 + rum * 0.5) * np.exp(-((u - 0.5) / 0.2) ** 2)


def wind(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = lowpass(rng.uniform(-1, 1, n), 0.03) * 5
    return x * (0.55 + 0.45 * np.sin(2 * np.pi * 0.35 * t + 1.3)) * fades(n, 0.4, 0.4)


def crackle(dur, density=90):
    """fire: sparse crackles"""
    n = int(dur * SR)
    out = np.zeros(n)
    for i in rng.integers(0, n, int(density * dur)):
        k = min(n - i, 500)
        out[i:i + k] += rng.uniform(-1, 1, k) * np.exp(-np.arange(k) / 60.0) * rng.uniform(0.2, 1.0)
    return out * np.exp(-np.arange(n) / SR / (dur * 0.6))


def blorp():
    """a lava bubble"""
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    f = 70 + 180 * np.exp(-t / 0.03)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.05) * np.clip(t / 0.003, 0, 1)


def pop():
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    f = 260 + 900 * np.exp(-t / 0.012)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.028)


def ufo(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 620 + 180 * np.sin(2 * np.pi * 6.5 * t) + 120 * np.sin(2 * np.pi * 0.7 * t)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.3 * fades(n, 0.2, 0.2)


def hum(dur, f0=55.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f0 * t) + 0.5 * np.sin(2 * np.pi * f0 * 2.01 * t) + 0.25 * np.sin(2 * np.pi * f0 * 3.02 * t)
    return s * (0.7 + 0.3 * np.sin(2 * np.pi * 0.5 * t)) * fades(n)


def moan(dur=1.0):
    """something huge, far down in the abyss"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    u = t / dur
    ph = 2 * np.pi * np.cumsum(140 - 50 * u + 5 * np.sin(2 * np.pi * 5 * t)) / SR
    return (np.sin(ph) + 0.4 * np.sin(2 * ph)) * np.sin(np.pi * u) ** 1.5 * 0.6


def rocket(dur=1.6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    roar = lowpass(rng.uniform(-1, 1, n), 0.05 + 0.25 * (t / dur)) * 4
    return (roar + crackle(dur, 160) * 0.5) * np.clip(t / 0.08, 0, 1) * np.clip((dur - t) / 0.4, 0, 1)


def squeak():
    """a dolphin's chirp"""
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    f = 2400 + 1600 * np.sin(np.pi * t / 0.22) + 300 * np.sin(2 * np.pi * 40 * t)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / 0.22) * 0.5


def buzz(dur=0.35):
    """a phone vibrating"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sign(np.sin(2 * np.pi * 170 * t)) * (np.sin(2 * np.pi * 9 * t) > -0.2)
    return lowpass(s, 0.15) * fades(n, 0.01, 0.03)


def ratchet(dur, r0=10.0, r1=34.0):
    """a fishing reel clicking, faster and faster"""
    n = int(dur * SR)
    out = np.zeros(n)
    t = 0.0
    k = int(0.004 * SR)
    tick = np.sin(2 * np.pi * 3200 * np.arange(k) / SR) * np.exp(-np.arange(k) / (0.0012 * SR))
    while t < dur:
        i = int(t * SR)
        j = min(n, i + k)
        out[i:j] += tick[:j - i] * (0.6 + 0.4 * rng.uniform())
        t += 1.0 / (r0 + (r1 - r0) * t / dur)
    return out


def pan_sweep(sig, p0, p1):
    p = np.linspace(p0, p1, len(sig))
    return sig * (1 - np.maximum(0, p)), sig * (1 + np.minimum(0, p))


# ----------------------------------------------------------------- samples
_cache = {}


def sample(rel, gain_to=1.0):
    """a CC0 sample (mono float, peak-normalised) and its attack time"""
    if rel not in _cache:
        raw = subprocess.run([FF, "-v", "error", "-i", os.path.join(DL, rel), "-f", "f32le", "-ac", "1", "-ar",
                              str(SR), "-"], capture_output=True, check=True).stdout
        a = np.frombuffer(raw, np.float32).astype(float)
        a /= max(1e-6, np.abs(a).max())
        env = np.sqrt(np.convolve(a * a, np.ones(480) / 480, "same"))
        _cache[rel] = (a, np.argmax(env > env.max() * 0.5) / SR)
    a, att = _cache[rel]
    return a * gain_to, att


def splash_sfx(i):
    return sample("x_splash_sfx/splash_%02d.ogg" % i)


SMALL = [2, 3, 9, 10, 14, 15, 6, 8]
BIG = [4, 7, 1]


def kenney(name, i=0):
    if name.startswith(("impact", "footstep")):
        return sample("x_kenney_impact/Audio/%s_%03d.ogg" % (name, i % 5))            # numbered from 000
    return sample("x_kenney_interface/Audio/%s_%03d.ogg" % (name, i % 4 + 1))         # numbered from 001


# ------------------------------------------------------------------- mixer
class Bus:
    def __init__(self, dur):
        self.L = np.zeros(int(dur * SR) + SR)
        self.R = np.zeros_like(self.L)

    def add(self, sig, t, gain=1.0, pan=0.0):
        i = int(round(t * SR))
        if i < 0:
            sig = sig[-i:]
            i = 0
        j = min(len(self.L), i + len(sig))
        if j <= i:
            return
        self.L[i:j] += sig[:j - i] * gain * (1 - max(0.0, pan))
        self.R[i:j] += sig[:j - i] * gain * (1 + min(0.0, pan))

    def hit(self, smp, t, gain=1.0, pan=0.0):
        """a sample lined up so its attack lands on t"""
        a, att = smp
        self.add(a, t - att, gain, pan)

    def add2(self, lr, t, gain=1.0):
        """a stereo pair (e.g. from pan_sweep)"""
        L, R = lr
        i = int(round(t * SR))
        j = min(len(self.L), i + len(L))
        self.L[i:j] += L[:j - i] * gain
        self.R[i:j] += R[:j - i] * gain

    def loop(self, rel, t0, t1, gain, fade=0.3, pan=0.0):
        """a looping ambience sample from t0 to t1"""
        a, _ = sample(rel)
        n = int((t1 - t0) * SR)
        x = np.tile(a, int(np.ceil(n / len(a))) + 1)[:n]
        self.add(x * fades(n, fade, fade), t0, gain, pan)


class Silent(Bus):
    """the music bus of the sound-effects-only mix: ignores every note"""

    def add(self, *a, **k):
        pass


def strum(bus, ch, t0, gain=0.2, beats=STRUM, bright=0.6):
    for sb in beats:
        for k, n in enumerate(CHORDS[ch]):
            bus.add(pluck(midi(n), 0.9, bright if sb % 1 == 0 else bright * 0.7), t0 + sb * BEAT + k * 0.012,
                    gain if sb % 1 == 0 else gain * 0.65, -0.25 + k * 0.17)


SECTIONS = [2, 4, 8, 10, 14, 16]          # every section starts its C - G - Am - F cycle on C (the drops land home)


def chord(b):
    start = max(s for s in SECTIONS if s <= b)
    return PROG[(b - start) % 4]


def groove(bus, b, kicks=(0, 1, 2, 3), claps=True, shakers=False, bass_gain=0.36, strum_gain=0.18, octave=False):
    t0 = bar_t(b)
    ch = chord(b)
    strum(bus, ch, t0, strum_gain)
    r = ROOT[ch]
    for bt, n in [(0, r), (1.5, r + 12), (2, r), (3.5, r + 7)]:
        bus.add(bass(midi(n), 0.5), t0 + bt * BEAT, bass_gain)
    if octave:
        for bt in (0.5, 1.0, 2.5, 3.0):
            bus.add(bass(midi(r + 12), 0.3), t0 + bt * BEAT, bass_gain * 0.55)
    for bt in range(4):
        if bt in kicks:
            bus.add(kick(), t0 + bt * BEAT, 0.95 if bt % 2 == 0 else 0.8)
        if claps and bt in (1, 3):
            bus.add(clap(), t0 + bt * BEAT, 0.6)
            bus.add(snare(0.35), t0 + bt * BEAT, 1.0)
        for e in (0, 0.5):
            bus.add(hat(), t0 + (bt + e) * BEAT, 1.1 if e else 0.7, 0.35)
        if shakers:
            for s16 in (0.25, 0.75):
                bus.add(shaker(), t0 + (bt + s16) * BEAT, 1.2, -0.4)


def lead(bus, b, motif, half, gain=0.22, octave=-12, marimba_gain=0.16):
    """two-bar motif (half 0/1) on the saw lead, doubled an octave up on marimba"""
    t0 = bar_t(b)
    for bt, n, ln in motif:
        if half * 4 <= bt < half * 4 + 4:
            t = t0 + (bt - half * 4) * BEAT
            bus.add(saw(midi(n + octave), ln * BEAT * 0.95, gain=gain), t, 1.0, 0.1)
            if marimba_gain:
                bus.add(marimba(midi(n), ln * BEAT + 0.3), t, marimba_gain, -0.15)


# ------------------------------------------------------------------- score
def render(with_music=True):
    music = Bus(DUR) if with_music else Silent(DUR)
    fx = Bus(DUR)
    KB = sec(T.KABOOM)

    # 0:00 cozy: soft ukulele, marimba, water, birds
    wat, _ = sample("x_splash_sfx/loop_water_01.ogg")
    loop = np.tile(wat, int(np.ceil(5.0 * SR / len(wat))))[:int(4.2 * SR)]
    tt = np.arange(len(loop)) / SR
    fx.add(loop * np.clip(tt / 0.8, 0, 1) * np.clip((4.0 - tt) / 0.3, 0, 1), 0.0, 0.22)
    strum(music, "C", 0.0, 0.11, beats=[0, 2, 3], bright=0.4)
    strum(music, "G", bar_t(1), 0.1, beats=[0, 1.5], bright=0.4)
    for bt, n, ln in MOTIF_A[:6]:
        if bt < 6.5:
            music.add(marimba(midi(n), ln * BEAT + 0.4), bt * BEAT, 0.14, 0.2)
    for t, base in ((0.55, 2700), (0.68, 3000), (1.9, 2500), (2.05, 2900), (2.85, 3100)):
        fx.add(chirp(base), t, 0.06, 0.5)
    bite = sec(T.BITE)
    fx.hit(sample("x_splash_sfx/bubble_01.ogg"), bite, 0.65, -0.1)
    music.add(pluck(midi(84), 0.6, 0.8), bite, 0.18)
    fx.hit(sample("x_splash_sfx/bubble_02.ogg"), sec(112), 0.5, -0.1)
    fx.add(riser(KB - sec(T.HUSH) + 0.05), sec(T.HUSH), 0.55)
    fx.add(swell(0.5), KB - 0.5, 0.6)

    # 0:04 KABOOM
    fx.add(explosion(), KB, 0.95)
    fx.add(impact(2.6), KB, 0.75)
    fx.hit(splash_sfx(4), KB + 0.03, 0.8, -0.2)
    fx.hit(splash_sfx(7), KB + 0.08, 0.7, 0.25)
    fx.add(crash(2.4), KB, 0.5)
    for f in (138, 146):
        fx.add(puff(), sec(f) - 0.2, 0.5)
    fx.add(whoosh(0.9), sec(171), 0.8)
    groove(music, 2, octave=True)
    lead(music, 2, MOTIF_B, 0, gain=0.18)

    # 0:06 the logo: one rising pluck + thump per letter, a boing for the fish
    notes = [72, 76, 79, 84, 86, 88, 91, 93, 96]
    for i, (f, n) in enumerate(zip(T.LOGO_HITS, notes)):
        t = sec(f)
        music.add(pluck(midi(n), 0.7, 0.9), t, 0.3, -0.3 + i * 0.07)
        fx.hit(kenney("impactPunch_medium", i % 5), t, 0.45)
        music.add(kick(0.2), t, 0.35)
    fx.add(boing(), sec(T.LOGO_FISH), 0.55, 0.3)
    fx.hit(splash_sfx(10), sec(T.LOGO_FISH) + 0.05, 0.3, 0.3)
    groove(music, 3, kicks=(0, 2), octave=False)

    # 0:08 seven worlds: a hit + whoosh on every cut, splashes on every leap
    for name, f in T.WORLDS:
        t = sec(f)
        fx.add(whoosh(0.35), t - 0.33, 0.55)
        fx.add(crash(1.2), t, 0.32)
        fx.hit(kenney("impactPunch_heavy", f % 5), t, 0.4)
    leap_pan = {"river": [-0.6, 0.5, -0.3, 0.3], "volcanic": [-0.5, 0.5, 0.2], "ocean": [-0.7, 0.5, -0.3],
                "sky": [-0.5, 0.5, -0.1], "space": [-0.5, 0.5, 0.1], "alien": [-0.4, 0.5], "abyss": [0.4, -0.4]}
    dur = {"river": [22, 22, 20, 24], "volcanic": [24, 22, 20], "ocean": [28, 20, 22], "sky": [24, 22, 20],
           "space": [26, 26, 26], "alien": [20, 22], "abyss": [22, 18]}
    k = 0
    for world, frames in T.LEAPS.items():
        for i, f in enumerate(frames):
            pan = leap_pan[world][i]
            fx.hit(splash_sfx(SMALL[k % len(SMALL)]), sec(f), 0.55, pan)
            fx.hit(splash_sfx(SMALL[(k + 3) % len(SMALL)]), sec(f + dur[world][i]), 0.38, -pan * 0.5)
            if world in ("space", "alien"):
                fx.add(zap(), sec(f), 0.35, pan)
            k += 1
    fx.add(explosion(3.2), sec(T.ERUPTION), 0.9, 0.2)
    fx.hit(kenney("impactMining", 0), sec(T.ERUPTION) + 0.05, 0.4, 0.2)
    for i in range(5):
        fx.add(noise_hit(0.5, 0.15, hp=0.3) * 0.5, sec(T.ERUPTION + 36 + i * 2), 0.35, -0.4 + i * 0.2)
    fx.add(whoosh(0.8), sec(T.SKY_PASS) + 0.05, 0.85, 0.0)
    fx.add(rumble(1.5), sec(T.SHUTTLE), 0.8, 0.3)
    fx.add(whoosh(0.7), sec(T.SHUTTLE) + 0.4, 0.6, 0.4)
    fx.add(sub_boom(1.6, 70, 26), sec(570), 0.8 if with_music else 0.45)
    for b in range(4, 10):
        groove(music, b, shakers=b >= 6, octave=b >= 8)
        lead(music, b, MOTIF_B if b in (4, 5, 8, 9) else MOTIF_A, (b - 4) % 2, gain=0.2 if b >= 8 else 0.16)

    # 0:20 the real game on screens: slams, whooshes, UI pops
    for i, f in enumerate(T.SCREENS):
        t = sec(f)
        fx.add(whoosh(0.3), t - 0.25, 0.6, 0.5 if i % 2 == 0 else -0.5)
        fx.hit(kenney("impactPunch_heavy", i), t, 0.5)
        fx.hit(kenney("maximize", i), t + 0.02, 0.35)
        fx.add(whoosh(0.25), sec(f + 55), 0.45, -0.5)
    for f in (675, 690, 705):
        fx.hit(kenney("click", f % 5), sec(f), 0.35)
    fx.hit(kenney("confirmation", 0), sec(735), 0.35)
    fx.hit(kenney("select", 1), sec(750), 0.3)
    fx.hit(kenney("drop", 1), sec(795), 0.45, 0.4)
    for b in range(10, 14):
        groove(music, b, shakers=b >= 12, octave=b == 13)
        lead(music, b, MOTIF_A if b < 12 else MOTIF_B, (b - 10) % 2, gain=0.16, marimba_gain=0.18)

    # 0:28 build-up: snare roll, riser, rising bass, boat whooshes, then a breath
    t28 = bar_t(14)
    fx.add(riser(4.0 - 0.5), t28, 0.75)
    for i in range(16):
        music.add(kick(0.25), t28 + i * BEAT * 0.5, 0.6 + 0.02 * i)
    rolls = [x * 0.5 for x in range(8)] + [4 + x * 0.25 for x in range(8)] + [6 + x * 0.125 for x in range(12)]
    for i, bt in enumerate(rolls):
        music.add(snare(0.4 + 0.6 * i / len(rolls)), t28 + bt * BEAT, 0.8)
    n = int(3.5 * SR)
    tt = np.arange(n) / SR
    f = midi(36) * 2 ** (tt / 3.5)
    music.add(np.tanh(1.5 * np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.4 * np.clip(tt / 0.5, 0, 1), t28, 0.8)
    for i in range(14):
        strum(music, "C" if i < 8 else "F", t28 + i * BEAT * 0.5, 0.1, beats=[0], bright=0.5)
    for i, f in enumerate(T.BOAT_PASSES):
        fx.add(whoosh(0.28 if i < 8 else 0.18), sec(f) - 0.12, 0.38, 0.6 if i % 2 else -0.6)
    fx.add(rumble(1.0), sec(T.SURVEYOR), 0.6)
    fx.hit(splash_sfx(1), sec(T.SURVEYOR + 6), 0.6)

    # 0:32 the BIG KABOOM, the drop, the logo run, the end card
    BK = sec(T.BIG_KABOOM)
    fx.add(explosion(3.0), BK, 1.0)
    fx.add(impact(3.0), BK, 0.85)
    fx.add(crash(2.6), BK, 0.55)
    fx.hit(splash_sfx(4), BK + 0.05, 0.5)
    for b in (16, 17):
        groove(music, b, shakers=True, octave=True)
        lead(music, b, MOTIF_B, b - 16, gain=0.22, marimba_gain=0.18)
    for i, (f, n) in enumerate(zip(T.FINALE_HITS, notes)):
        music.add(pluck(midi(n), 0.6, 0.9), sec(f), 0.26, -0.3 + i * 0.07)
        fx.hit(kenney("impactPunch_medium", i % 5), sec(f), 0.3)
    fx.add(boing(), sec(T.FINALE_FISH), 0.5, 0.3)
    te = sec(T.END_HIT)
    for k, n in enumerate(CHORDS["C"]):
        music.add(pluck(midi(n), 3.2, 0.7, 0.998), te + k * 0.025, 0.34, -0.2 + k * 0.13)
    music.add(marimba(midi(84), 2.6), te, 0.35)
    music.add(saw(midi(60), 1.6, gain=0.2), te, 1.0)
    music.add(bass(midi(36), 2.4), te, 0.6)
    music.add(kick(), te, 1.0)
    fx.add(impact(2.8), te, 0.55)
    fx.hit(kenney("confirmation", 1), te + 0.02, 0.3)

    if not with_music:
        sound_design(fx)

    # the abyss half-bar sounds deep underwater: a low-pass sweeps closed then open again
    a, b = int(sec(570) * SR), int(sec(600) * SR)
    cut = np.concatenate([np.linspace(0.5, 0.03, (b - a) // 3), np.full((b - a) - 2 * ((b - a) // 3), 0.03),
                          np.linspace(0.03, 0.5, (b - a) // 3)])
    for ch in (music.L, music.R, fx.L, fx.R):
        ch[a:b] = lowpass(ch[a:b], cut)

    mix = np.stack([music.L + fx.L, music.R + fx.R], 1)
    # a breath of near-silence on the last eighth before the big KABOOM
    a, b = int((BK - 0.27) * SR), int((BK - 0.012) * SR)
    dip = np.ones(b - a)
    r = int(0.04 * SR)
    dip[:r] = np.linspace(1, 0.06, r)
    dip[r:] = 0.06
    mix[a:b] *= dip[:, None]
    drive = 1.3 if with_music else 2.0                 # effects alone: squeeze the peaks so the beds carry
    mix = np.tanh(mix * drive) / np.tanh(drive)
    mix /= np.max(np.abs(mix)) / 0.89
    mix = mix[:int(T.TOTAL / T.FPS * SR)]
    fade = int(0.6 * SR)
    mix[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
    return mix


def sound_design(fx):
    """the effects-only mix: no music, so every scene gets its own bed and more detail"""
    KB, BK = sec(T.KABOOM), sec(T.BIG_KABOOM)
    W = dict(T.WORLDS)
    # the cozy river: more water, birds, plips where the bobber ripples, then the water bulges with a rumble
    fx.loop("x_splash_sfx/loop_water_03.ogg", 0.0, KB, 0.3, 0.6)
    for t, base in ((0.3, 2600), (0.42, 2900), (1.2, 3200), (1.33, 2800), (2.4, 2700), (2.52, 3050), (3.05, 2950)):
        fx.add(chirp(base), t, 0.12, float(rng.uniform(-0.6, 0.6)))
    for f in (6, 40, 74):
        fx.hit(sample("x_splash_sfx/bubble_03.ogg"), sec(f), 0.2, -0.1)
    r = rumble(0.6)
    fx.add(r * np.linspace(0.2, 1.0, len(r)), sec(110) - 0.05, 0.5)
    # KABOOM: fire crackling, the river raining back down, the water settling
    fx.add(crackle(1.8), KB, 0.45)
    fx.add(sub_boom(2.2), KB, 0.5)
    for _ in range(16):
        fx.hit(splash_sfx(int(rng.choice(SMALL))), KB + 0.35 + float(rng.uniform(0, 1.7)),
               float(rng.uniform(0.15, 0.35)), float(rng.uniform(-0.7, 0.7)))
    fx.loop("x_splash_sfx/loop_water_02.ogg", KB + 0.3, 6.0, 0.2)
    # the logo: a pop and a few droplets on every letter, bubbles behind
    fx.loop("x_splash_sfx/loop_bubbles_1.ogg", 6.0, 8.0, 0.2)
    for i, f in enumerate(T.LOGO_HITS + T.FINALE_HITS):
        fx.add(pop(), sec(f), 0.32, -0.3 + (i % 9) * 0.07)
        fx.hit(splash_sfx(9 if i % 2 else 10), sec(f) + 0.01, 0.16, -0.3 + (i % 9) * 0.07)
    # the worlds
    fx.loop("x_splash_sfx/loop_water_01.ogg", sec(W["river"]), sec(W["volcanic"]), 0.24, 0.05)
    for t in (8.3, 8.45, 9.2, 9.6):
        fx.add(chirp(float(rng.uniform(2500, 3200))), t, 0.07, float(rng.uniform(-0.6, 0.6)))
    v0, v1 = sec(W["volcanic"]), sec(W["ocean"])
    fx.add(rumble(v1 - v0), v0, 0.45)
    fx.add(crackle(v1 - v0, 50), v0, 0.25)
    for _ in range(14):
        fx.add(blorp(), v0 + float(rng.uniform(0.1, 1.9)), float(rng.uniform(0.2, 0.4)), float(rng.uniform(-0.6, 0.6)))
    o0, o1 = sec(W["ocean"]), sec(W["sky"])
    fx.loop("x_splash_sfx/loop_water_03.ogg", o0, o1, 0.32, 0.05)
    fx.add(squeak(), sec(T.LEAPS["ocean"][0]) + 0.25, 0.25, -0.5)
    fx.add2(pan_sweep(engine(2.0, 70.0), 0.8, -0.5), o0, 0.18)
    for t in (12.4, 12.55, 13.4):
        fx.add(chirp(float(rng.uniform(1900, 2300))), t, 0.06, 0.4)
    s0, s1 = sec(W["sky"]), sec(W["space"])
    fx.add(wind(s1 - s0), s0, 0.4)
    fx.add2(pan_sweep(engine(2.0, 48.0), 0.85, -0.85), s0, 0.4)           # the galleon's propellers
    p0, p1 = sec(W["space"]), sec(W["alien"])
    fx.add(hum(p1 - p0, 48.0), p0, 0.16)
    fx.add2(pan_sweep(rocket(1.7), -0.6, 0.7), sec(T.SHUTTLE), 0.55)
    a0, a1 = sec(W["alien"]), sec(W["abyss"])
    fx.add(ufo(a1 - a0), a0, 0.3, -0.5)
    fx.add(hum(a1 - a0, 62.0), a0, 0.1)
    b0, b1 = sec(W["abyss"]), sec(T.SCREENS[0])
    fx.add(moan(b1 - b0), b0, 0.28)
    fx.loop("x_splash_sfx/loop_bubbles_02.ogg", b0, b1, 0.2, 0.05)
    # the screens: an underwater bed, and the sounds of what's on each screen
    S = T.SCREENS
    fx.loop("x_splash_sfx/loop_bubbles_1.ogg", sec(S[0]), sec(840), 0.3, 0.2)
    fx.loop("x_splash_sfx/loop_water_01.ogg", sec(S[0]), sec(840), 0.1, 0.3)
    #   Reel it in!: the reel clicks faster and faster, the fish splashes, PERFECT!, the catch
    fx.add(ratchet(sec(640) - sec(S[0]) - 0.3), sec(S[0]) + 0.3, 0.35, 0.1)
    for f in (612, 627):
        fx.hit(splash_sfx(10), sec(f), 0.25, -0.2)
    fx.hit(kenney("confirmation", 2), sec(640), 0.5)
    fx.hit(splash_sfx(3), sec(644), 0.35)
    fx.hit(kenney("select", 3), sec(648), 0.3)
    #   the boat parade: an engine on every clip
    for i, f in enumerate((S[1], S[1] + 15, S[1] + 30, S[1] + 45)):
        fx.add2(pan_sweep(engine(0.7, 70.0 + 15.0 * i), 0.5, -0.5), sec(f) + 0.05, 0.22)
    #   FishTok: the phone buzzes, likes pop, a swipe
    fx.add(buzz(), sec(S[2]) + 0.2, 0.3, -0.2)
    fx.add(buzz(), sec(S[2]) + 0.65, 0.25, -0.2)
    for i in range(7):
        fx.add(pop() * (1.0 + 0.1 * i), sec(S[2] + 22) + i * 0.11, 0.3, 0.3)
    fx.hit(kenney("maximize", 3), sec(S[2] + 44), 0.3)
    #   online: the leaderboard ticks, your row lights up, a sparkle
    for i in range(5):
        fx.hit(kenney("click", i), sec(S[3] + 6) + i * 0.09, 0.25)
    fx.hit(kenney("select", 4), sec(S[3] + 20), 0.35)
    fx.hit(kenney("glass", 1), sec(S[3] + 30), 0.3)
    fx.hit(kenney("glass", 2), sec(S[3] + 34), 0.25)
    # the boats: water, and every boat's engine zooming past right to left
    fx.loop("x_splash_sfx/loop_water_02.ogg", sec(840), BK - 0.3, 0.22)
    flyers = {"Sky Cruiser": "prop", "Satellite": "zap", "Space Shuttle": "rocket", "Alien Raft": "ufo"}
    names = ["Rowboat", "Fishing Boat", "Speedboat", "Pontoon", "Sailboat", "Yacht", "Luxury Yacht", "Cruise Ship",
             "Gold Boat", "Sky Cruiser", "Satellite", "Space Shuttle", "Cruiser", "Alien Raft", "Alien Submarine",
             "Dark Explorer"]
    for i, (name, f) in enumerate(zip(names, T.BOAT_PASSES)):
        d = 0.9 if i < 8 else 0.6
        kind = flyers.get(name)
        if kind == "rocket":
            fx.add2(pan_sweep(rocket(d), 0.9, -0.9), sec(f) - d / 2, 0.35)
        elif kind == "ufo":
            fx.add2(pan_sweep(ufo(d), 0.9, -0.9), sec(f) - d / 2, 0.5)
        elif kind == "zap":
            fx.add(zap(), sec(f), 0.4)
        else:
            f0 = 55.0 if kind == "prop" else 80.0 + 12.0 * (i % 5)
            fx.add2(pan_sweep(engine(d, f0), 0.9, -0.9), sec(f) - d / 2, 0.3)
    # the BIG KABOOM: crackle, falling water, and every fish whizzing past
    fx.add(crackle(1.8), BK, 0.45)
    fx.add(sub_boom(2.2), BK, 0.5)
    for _ in range(12):
        fx.add(whoosh(0.25), BK + 0.05 + float(rng.uniform(0, 0.6)), 0.25, float(rng.uniform(-0.8, 0.8)))
    for _ in range(10):
        fx.hit(splash_sfx(int(rng.choice(SMALL))), BK + 0.4 + float(rng.uniform(0, 1.2)),
               float(rng.uniform(0.12, 0.3)), float(rng.uniform(-0.7, 0.7)))
    # the end card: bubbles, a pop for each line, the last splash
    fx.loop("x_splash_sfx/loop_bubbles_1.ogg", BK + 1.5, sec(T.TOTAL), 0.32, 0.5)
    fx.loop("x_splash_sfx/loop_water_01.ogg", BK + 1.5, sec(T.TOTAL), 0.14, 0.5)
    for t in (34.6, 35.9, 37.0):                                     # the fish circling the logo
        fx.add(whoosh(0.5), t, 0.18, float(rng.uniform(-0.6, 0.6)))
    fx.hit(kenney("select", 2), sec(1024), 0.35)
    fx.add(pop(), sec(1032), 0.35)
    fx.add(pop(), sec(1040), 0.3)
    fx.hit(splash_sfx(4), sec(T.END_HIT) + 0.03, 0.45)


if __name__ == "__main__":
    out = sys.argv[1]
    sfx_only = "--sfx-only" in sys.argv
    m = render(with_music=not sfx_only)
    save(out, m)
    print("music_boom", out, "%.1f s" % (len(m) / SR), "(sound effects only)" if sfx_only else "")

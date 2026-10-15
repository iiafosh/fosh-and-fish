"""Soundtrack for the fosh&fish KABOOM video (tools/video/edit_boom.py), on boom_timeline's frames.

Original music, synthesized (music.py's ukulele / marimba / drums, plus a saw lead, sub booms, snare
rolls and cartoon boings), and CC0 sound effects placed on the frames where things happen:
Kenney Impact Sounds + Interface Sounds and rubberduck's water SFX (scratch/downloads, see CREDITS.md).

    0:00 cozy ukulele, water, birds ... the bobber goes "bloop", the music holds its breath
    0:04 KABOOM and the drop       0:06 a rising pluck on every logo letter, a boing for the fish
    0:08 a hit + whoosh on every world, splashes on every leap, the volcano, the shuttle, the abyss (muffled)
    0:20 screen slams and UI pops  0:28 build: snare roll, riser, boat whooshes, a breath of silence
    0:32 the big KABOOM, the drop, the logo run    0:36 the last chord rings out

    python tools/video/music_boom.py OUT.wav
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
def render():
    music = Bus(DUR)
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
    music.add(riser(KB - sec(T.HUSH) + 0.05), sec(T.HUSH), 0.55)
    music.add(swell(0.5), KB - 0.5, 0.6)

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
    fx.add(sub_boom(1.6, 70, 26), sec(570), 0.8)
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
    music.add(riser(4.0 - 0.5), t28, 0.75)
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

    # the abyss half-bar sounds deep underwater: a low-pass sweeps closed then open again
    a, b = int(sec(570) * SR), int(sec(600) * SR)
    cut = np.concatenate([np.linspace(0.5, 0.03, (b - a) // 3), np.full((b - a) - 2 * ((b - a) // 3), 0.03),
                          np.linspace(0.03, 0.5, (b - a) // 3)])
    for ch in (music.L, music.R):
        ch[a:b] = lowpass(ch[a:b], cut)

    mix = np.stack([music.L + fx.L, music.R + fx.R], 1)
    # a breath of near-silence on the last eighth before the big KABOOM
    a, b = int((BK - 0.27) * SR), int((BK - 0.012) * SR)
    dip = np.ones(b - a)
    r = int(0.04 * SR)
    dip[:r] = np.linspace(1, 0.06, r)
    dip[r:] = 0.06
    mix[a:b] *= dip[:, None]
    mix = np.tanh(mix * 1.3) / np.tanh(1.3)
    mix /= np.max(np.abs(mix)) / 0.89
    mix = mix[:int(T.TOTAL / T.FPS * SR)]
    fade = int(0.6 * SR)
    mix[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
    return mix


if __name__ == "__main__":
    out = sys.argv[1]
    m = render()
    save(out, m)
    print("music_boom", out, "%.1f s" % (len(m) / SR))

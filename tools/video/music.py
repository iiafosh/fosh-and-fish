"""Original trailer music for fosh&fish, synthesized from scratch (no samples, no licenses).

Cozy island-pop at 120 BPM: Karplus-Strong ukulele strums, marimba lead, plucked bass,
kick / clap / hats / shaker, plus a riser and an impact for the title hit.
Bars are 2 s long, so the edit can cut on bar and beat lines.

    python tools/video/music.py OUT.wav [bars]
"""
import sys
import wave
import numpy as np

SR = 48000
BPM = 120
BEAT = 60 / BPM
BAR = 4 * BEAT
rng = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def env(n, a=0.005, d=0.3):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / a) * np.exp(-t / d)
    return e


def pluck(freq, dur, bright=0.5, decay=0.996):
    """Karplus-Strong string: ukulele / guitar-like pluck."""
    n = int(dur * SR)
    p = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, p) * (0.6 + 0.4 * bright)
    out = np.zeros(n)
    for i in range(n):
        v = buf[i % p]
        out[i] = v
        buf[i % p] = decay * 0.5 * (v + buf[(i + 1) % p])
    return out * env(n, 0.002, dur * 0.6)


def marimba(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t / 0.05)
    return s * env(n, 0.002, 0.35)


def bass(freq, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t) + 0.12 * np.sin(2 * np.pi * freq * 3 * t)
    return np.tanh(1.4 * s) * env(n, 0.004, 0.28)


def kick(dur=0.35):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 50 + 110 * np.exp(-t / 0.04)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t / 0.12) * 1.1


def noise_hit(dur, decay, hp=0.0, lp=1.0):
    n = int(dur * SR)
    x = rng.uniform(-1, 1, n)
    if hp > 0:
        x = np.append(x[0], np.diff(x)) * hp + x * (1 - hp)
    if lp < 1:
        y = np.zeros(n)
        acc = 0.0
        for i in range(n):
            acc += lp * (x[i] - acc)
            y[i] = acc
        x = y
    return x * np.exp(-np.arange(n) / SR / decay)


def clap():
    return noise_hit(0.25, 0.07, hp=0.6) * 0.6


def hat():
    return noise_hit(0.06, 0.015, hp=0.7) * 0.12


def shaker():
    return noise_hit(0.05, 0.02, hp=0.7) * 0.05


def riser(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = rng.uniform(-1, 1, n)
    y = np.zeros(n)
    acc = 0.0
    for i in range(n):
        a = 0.02 + 0.5 * (i / n) ** 2
        acc += a * (x[i] - acc)
        y[i] = acc
    return y * (t / dur) ** 2 * 0.9


def impact(dur=2.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * (38 + 40 * np.exp(-t / 0.08)) * t) * np.exp(-t / 0.6)
    crash = noise_hit(dur, 0.7, hp=0.85) * 0.35
    return boom * 0.9 + crash


def whoosh(dur=0.45):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = rng.uniform(-1, 1, n)
    y = np.zeros(n)
    acc = 0.0
    for i in range(n):
        a = 0.03 + 0.25 * np.sin(np.pi * i / n)
        acc += a * (x[i] - acc)
        y[i] = acc
    return y * np.sin(np.pi * t / dur) ** 2 * 0.6


# I - V - vi - IV in C, voiced for a ukulele-ish strum (MIDI notes)
CHORDS = {
    "C": [60, 64, 67, 72], "G": [59, 62, 67, 71], "Am": [57, 60, 64, 69], "F": [57, 60, 65, 69],
    "Dm": [57, 62, 65, 69], "Em": [59, 64, 67, 71],
}
ROOT = {"C": 36, "G": 43, "Am": 45, "F": 41, "Dm": 38, "Em": 40}
PROG = ["C", "G", "Am", "F"]
STRUM = [0, 1.5, 2, 2.5, 3.5]                    # beats of a D . D U . U D U pattern
# lead motif in C major pentatonic: (beat, midi, length beats); two bars, then a variation
MOTIF_A = [(0, 76, .5), (.5, 79, .5), (1, 81, 1), (2.5, 79, .5), (3, 76, 1),
           (4, 74, .5), (4.5, 76, .5), (5, 79, 1.5), (6.5, 76, .5), (7, 74, 1)]
MOTIF_B = [(0, 81, .5), (.5, 84, .5), (1, 81, .5), (1.5, 79, .5), (2, 76, 1), (3, 79, 1),
           (4, 81, .5), (4.5, 79, .5), (5, 76, .5), (5.5, 74, .5), (6, 72, 2)]


def render(bars=16):
    total = bars * BAR + 3.0
    L = np.zeros(int(total * SR) + SR)
    R = np.zeros_like(L)

    def add(sig, t, gain=1.0, pan=0.0):
        i = int(t * SR)
        j = min(len(L), i + len(sig))
        L[i:j] += sig[:j - i] * gain * (1 - max(0, pan))
        R[i:j] += sig[:j - i] * gain * (1 + min(0, pan))

    # sections: 0 intro (riser), 1 title hit, 2-5 groove A, 6-9 groove B (biomes), 10-13 A', 14-15 outro
    add(riser(BAR), 0.0, 0.5)
    for k in range(4):
        add(pluck(midi(CHORDS["C"][k % 4] + 12), 1.0, 0.8), k * BEAT * 0.5 + BEAT * 2, 0.25, 0.3 * (k % 2 * 2 - 1))
    add(impact(), BAR, 0.85)
    for b in range(1, bars):
        t0 = b * BAR
        ch = PROG[(b - 1) % 4]
        last = b == bars - 1
        if last:
            # final chord: one big strum that rings out
            for k, n in enumerate(CHORDS["C"]):
                add(pluck(midi(n), 3.0, 0.7, 0.998), t0 + k * 0.025, 0.32, -0.2 + k * 0.13)
            add(marimba(midi(84), 2.5), t0, 0.35)
            add(bass(midi(36), 2.0), t0, 0.5)
            add(kick(), t0, 0.9)
            add(impact(2.5) * 0.4, t0, 0.5)
            break
        busy = 6 <= b <= 9
        # strums
        for sb in STRUM:
            for k, n in enumerate(CHORDS[ch]):
                add(pluck(midi(n), 0.9, 0.6 if sb % 1 == 0 else 0.4), t0 + sb * BEAT + k * 0.012,
                    0.2 if sb % 1 == 0 else 0.13, -0.25 + k * 0.17)
        # bass: root on 1 and 3, octave bounce on the "and" of 2 and 4
        r = ROOT[ch]
        for bt, n in [(0, r), (1.5, r + 12), (2, r), (3.5, r + 7)]:
            add(bass(midi(n), 0.5), t0 + bt * BEAT, 0.33)
        # drums
        for bt in range(4):
            if bt in (0, 2) or (busy and bt == 3):
                add(kick(), t0 + bt * BEAT, 0.8)
            if bt in (1, 3):
                add(clap(), t0 + bt * BEAT, 0.55 if b >= 2 else 0.3)
            for e in (0, 0.5):
                add(hat(), t0 + (bt + e) * BEAT, 1.0 if e else 0.6, 0.35)
            if busy:
                for s16 in (0.25, 0.75):
                    add(shaker(), t0 + (bt + s16) * BEAT, 1.0, -0.4)
        # lead: two-bar motifs; groove B uses the higher variation
        if b >= 2:
            motif = MOTIF_B if busy else MOTIF_A
            bar_in = (b - 2) % 2
            for bt, n, ln in motif:
                if bar_in * 4 <= bt < bar_in * 4 + 4:
                    add(marimba(midi(n), ln * BEAT + 0.3), t0 + (bt - bar_in * 4) * BEAT, 0.3, 0.15)
        if b == 5:
            add(riser(BAR), t0, 0.35)                 # lift into the biome section
    mix = np.stack([L, R], 1)
    # gentle bus glue: soft clip + normalise to -1 dBFS
    mix = np.tanh(mix * 1.2) / np.tanh(1.2)
    mix /= np.max(np.abs(mix)) / 0.89
    return mix


def save(path, mix):
    pcm = (np.clip(mix, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


if __name__ == "__main__":
    out = sys.argv[1]
    bars = int(sys.argv[2]) if len(sys.argv) > 2 else 16
    save(out, render(bars))
    print("music", out, bars * BAR, "s")

"""Soundtrack for the fosh&fish 1.0 trailer, "THE LEVIATHAN" (tools/video/edit_boom10.py), on
boom10_timeline's frames: music (the KABOOM video's synthesized ukulele / marimba / drums / saw lead,
tools/video/music_boom.py) with the sound effects on top (CC0: Kenney Impact + Interface Sounds and
rubberduck's water SFX in scratch/downloads, see CREDITS.md).

    0:00 a cozy sunset strum ... a low hum as the shadow passes, a whale moan, the music holds its breath
    0:04 the BREACH: a huge splash and the drop          0:06 the logo, a pluck per letter
    0:08 shiny: shakers, marimba, sparkly chimes on every leap, a shimmer when the big one hangs
    0:12 the four events: a hit and a whoosh on every cut; coins, splashes, chests, meteors
    0:20 the rods: half-time, a punch per rod            0:24 the boss: A minor, the reel ratchets, tail slaps
    0:28 the build: snare roll, riser ... a breath        0:32 CAUGHT!: the drop, the logo run, the last chord

    python tools/video/music10.py OUT.wav
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import boom10_timeline as T  # noqa: E402
import music  # noqa: E402
import music_boom as MB  # noqa: E402
from music import (BEAT, CHORDS, MOTIF_A, MOTIF_B, ROOT, SR, bass, clap, hat, impact, kick, marimba, midi,  # noqa: E402
                   noise_hit, pluck, riser, save, shaker, whoosh)
from music_boom import (Bus, boing, chirp, crash, explosion, hum, kenney, lowpass, moan, puff, rumble, sample,  # noqa: E402
                        saw, snare, splash_sfx, strum, sub_boom, swell, zap, ratchet, SMALL)

DUR = T.TOTAL / T.FPS + 0.5
rng = np.random.default_rng(21)
CHORDS.setdefault("E", [56, 59, 64, 68])           # E major (the boss's turnaround)
ROOT.setdefault("E", 40)
BOSS = ["Am", "F", "Dm", "E"]
BOSS_MOTIF = [(0, 69, .5), (.5, 72, .5), (1, 76, 1), (2, 74, .5), (2.5, 72, .5), (3, 71, 1),
              (4, 69, .5), (4.5, 72, .5), (5, 77, 1), (6, 76, .5), (6.5, 74, .5), (7, 76, 1)]


def sec(f):
    return f / float(T.FPS)


def bar_t(b, beat=0.0):
    return (b * 4 + beat) * BEAT


def groove(bus, b, ch, kicks=(0, 1, 2, 3), claps=True, shakers=False, bass_gain=0.36, strum_gain=0.18, octave=False):
    """music_boom.groove with the chord given (for the boss's minor turn)"""
    t0 = bar_t(b)
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


def lead(bus, b, motif, half, gain=0.2, octave=-12, marimba_gain=0.16):
    MB.lead(bus, b, motif, half, gain=gain, octave=octave, marimba_gain=marimba_gain)


def shimmer(bus, t0, dur, gain=0.11):
    """a sparkly run of high plucks (C major pentatonic, sixteenths)"""
    notes = [84, 86, 88, 91, 93, 96, 98, 100]
    n = int(dur / (BEAT / 4))
    for i in range(n):
        bus.add(pluck(midi(notes[(i * 3) % len(notes)]), 0.5, 0.95), t0 + i * BEAT / 4, gain * (0.7 + 0.3 * (i % 2)),
                -0.5 + (i % 5) * 0.25)


def sparkle(fx, t, gain=0.3, pan=0.0):
    fx.hit(kenney("glass", int(t * 10)), t, gain, pan)
    fx.add(chirp(3200), t + 0.03, gain * 0.35, pan)


def render():
    music = Bus(DUR)
    fx = Bus(DUR)
    B = sec(T.BREACH)

    # 0:00 a cozy sunset: soft strums, marimba, water, gulls
    wat, _ = sample("x_splash_sfx/loop_water_01.ogg")
    loop = np.tile(wat, int(np.ceil(5.0 * SR / len(wat))))[:int(4.2 * SR)]
    tt = np.arange(len(loop)) / SR
    fx.add(loop * np.clip(tt / 0.8, 0, 1) * np.clip((4.0 - tt) / 0.3, 0, 1), 0.0, 0.22)
    strum(music, "C", 0.0, 0.11, beats=[0, 2, 3], bright=0.4)
    strum(music, "G", bar_t(1), 0.09, beats=[0, 1.5], bright=0.35)
    for bt, n, ln in MOTIF_A[:5]:
        if bt < 5.0:
            music.add(marimba(midi(n), ln * BEAT + 0.4), bt * BEAT, 0.13, 0.2)
    for t, base in ((0.55, 2700), (0.68, 3000), (1.9, 2500), (2.05, 2900)):
        fx.add(chirp(base), t, 0.06, 0.5)
    # ... the shadow: a low hum swells, a whale moans far off
    s0, s1 = sec(T.SHADOW[0]), sec(T.SHADOW[1])
    h = hum(s1 - s0 + 0.6, 44.0)
    fx.add(h * np.linspace(0.0, 1.0, len(h)) ** 1.5, s0, 0.5)
    fx.add(moan(1.8), sec(64), 0.4, -0.3)
    fx.add(rumble(1.2), sec(84), 0.35)
    fx.hit(sample("x_splash_sfx/bubble_01.ogg"), sec(T.BITE), 0.6, -0.1)
    music.add(pluck(midi(84), 0.6, 0.8), sec(T.BITE), 0.18)
    fx.add(riser(B - sec(T.HUSH) + 0.05), sec(T.HUSH), 0.6)
    fx.add(swell(0.5), B - 0.5, 0.6)

    # 0:04 the BREACH: the sea bursts, the drop
    fx.add(impact(2.8), B, 0.85)
    fx.add(sub_boom(2.4, 80, 24), B, 0.7)
    fx.add(crash(2.4), B, 0.45)
    fx.hit(splash_sfx(4), B + 0.02, 0.9, -0.2)
    fx.hit(splash_sfx(7), B + 0.06, 0.8, 0.25)
    fx.hit(splash_sfx(1), B + 0.12, 0.6, 0.0)
    fx.add(moan(1.4) * 1.6, B + 0.25, 0.35, 0.2)
    fx.add(whoosh(1.2), B + 0.2, 0.6, 0.1)
    for _ in range(14):                                        # the sea raining back down
        fx.hit(splash_sfx(int(rng.choice(SMALL))), B + 0.6 + float(rng.uniform(0, 1.3)), float(rng.uniform(0.12, 0.3)),
               float(rng.uniform(-0.7, 0.7)))
    groove(music, 2, "C", octave=True)
    lead(music, 2, MOTIF_B, 0, gain=0.18)

    # 0:06 the logo (as KABOOM): one rising pluck + thump per letter, a boing for the fish
    notes = [72, 76, 79, 84, 86, 88, 91, 93, 96]
    for i, (f, n) in enumerate(zip(T.LOGO_HITS, notes)):
        music.add(pluck(midi(n), 0.7, 0.9), sec(f), 0.3, -0.3 + i * 0.07)
        fx.hit(kenney("impactPunch_medium", i % 5), sec(f), 0.45)
        music.add(kick(0.2), sec(f), 0.35)
    fx.add(boing(), sec(T.LOGO_FISH), 0.55, 0.3)
    fx.hit(splash_sfx(10), sec(T.LOGO_FISH) + 0.05, 0.3, 0.3)
    groove(music, 3, "G", kicks=(0, 2))

    # 0:08 shiny: lighter, sparkly
    for b, ch in ((4, "C"), (5, "G")):
        groove(music, b, ch, kicks=(0, 2), claps=True, shakers=True, bass_gain=0.3, strum_gain=0.15)
        lead(music, b, MOTIF_A, b - 4, gain=0.12, marimba_gain=0.2)
    for i, f in enumerate(T.SHINY_LEAPS):
        pan = -0.5 if i % 2 == 0 else 0.5
        fx.hit(splash_sfx(SMALL[i % len(SMALL)]), sec(f), 0.5, pan)
        sparkle(fx, sec(f + 6), 0.3, pan)
        sparkle(fx, sec(f + 14), 0.2, -pan)
        fx.hit(splash_sfx(SMALL[(i + 3) % len(SMALL)]), sec(f + 22), 0.35, -pan * 0.5)
    fx.hit(splash_sfx(4), sec(T.SHINY_HERO), 0.55)
    fx.add(whoosh(0.6), sec(T.SHINY_HERO) + 0.1, 0.5)
    fx.hit(kenney("impactBell_heavy", 0), sec(T.SHINY_FREEZE), 0.4)
    shimmer(music, sec(T.SHINY_FREEZE), sec(360) - sec(T.SHINY_FREEZE))

    # 0:12 the events: a hit + whoosh on every cut
    for b, ch in ((6, "Am"), (7, "F"), (8, "C"), (9, "G")):
        groove(music, b, ch, shakers=True, octave=b >= 8)
        lead(music, b, MOTIF_B if b in (6, 7) else MOTIF_A, (b - 6) % 2, gain=0.18 if b >= 8 else 0.16)
    for name, f in T.EVENTS:
        t = sec(f)
        fx.add(whoosh(0.35), t - 0.33, 0.55)
        fx.add(crash(1.2), t, 0.32)
        fx.hit(kenney("impactPunch_heavy", f % 5), t, 0.42)
    #   Golden Hour: coins
    for i in range(18):
        fx.hit(kenney("impactMetal_light", i), sec(362 + i * 2.2) + float(rng.uniform(0, 0.05)), 0.22,
               float(rng.uniform(-0.7, 0.7)))
    fx.hit(kenney("confirmation", 1), sec(372), 0.3)
    #   Fish Frenzy: a splash on every leap
    for i, f in enumerate(T.FRENZY_LEAPS):
        fx.hit(splash_sfx(SMALL[i % len(SMALL)]), sec(f), 0.32, -0.6 + (i % 5) * 0.3)
    #   Treasure Tide: chests thump up and sparkle
    for i, f in enumerate(T.CHESTS):
        fx.hit(kenney("impactWood_heavy", i), sec(f), 0.45, -0.6 + i * 0.3)
        fx.hit(splash_sfx(SMALL[(i + 2) % len(SMALL)]), sec(f) + 0.02, 0.3, -0.6 + i * 0.3)
        sparkle(fx, sec(f + 6), 0.22, -0.6 + i * 0.3)
    #   Meteor Shower: falling whooshes, booms
    for i, f in enumerate(T.METEORS):
        fx.add(whoosh(0.5), sec(f) - 0.5, 0.45, 0.6 - i * 0.25)
        fx.add(explosion(1.4), sec(f), 0.35, 0.6 - i * 0.25)
        fx.hit(splash_sfx(SMALL[i % len(SMALL)]), sec(f) + 0.04, 0.3, 0.6 - i * 0.25)
    fx.hit(splash_sfx(3), sec(T.METEOR_FISH), 0.4)

    # 0:20 the exclusive rods: half-time, a punch per rod
    for b, ch in ((10, "C"), (11, "F")):
        groove(music, b, ch, kicks=(0, 2), claps=False, shakers=True, bass_gain=0.32)
        lead(music, b, MOTIF_A, b - 10, gain=0.14, marimba_gain=0.18)
    for i, f in enumerate(T.RODS):
        fx.add(whoosh(0.3), sec(f) - 0.28, 0.6, -0.5 + i * 0.5)
        fx.hit(kenney("impactPunch_heavy", i + 1), sec(f), 0.5, -0.5 + i * 0.5)
        fx.hit(kenney("maximize", i), sec(f) + 0.02, 0.3)
        sparkle(fx, sec(f + 3), 0.25, -0.5 + i * 0.5)
    fx.add(whoosh(0.7), sec(T.ROD_SPIN), 0.5)
    shimmer(music, sec(T.ROD_SPIN), 1.0, 0.09)

    # 0:24 the boss: A minor, heavier
    for b in (12, 13):
        for half in (0, 1):
            ch = BOSS[(b - 12) * 2 + half]
            t0 = bar_t(b, half * 2)
            strum(music, ch, t0, 0.17, beats=[0, 0.75, 1.5])
            r = ROOT[ch]
            for bt, n in [(0, r), (0.75, r), (1.5, r + 12)]:
                music.add(bass(midi(n), 0.4), t0 + bt * BEAT, 0.42)
            for bt in (0, 0.75, 1.5):
                music.add(kick(), t0 + bt * BEAT, 0.95)
            music.add(snare(0.8), t0 + 1.0 * BEAT, 0.9)
            for e in range(4):
                music.add(hat(), t0 + e * 0.5 * BEAT, 0.9, 0.35)
        lead(music, b, BOSS_MOTIF, b - 12, gain=0.2, marimba_gain=0.1)
    fx.add(rumble(1.6), sec(T.BOSS_SURFACE), 0.6)
    fx.add(moan(1.6), sec(T.BOSS_SURFACE + 12), 0.45, -0.3)
    for f in range(T.BOSS_SURFACE, T.HOOKED, 6):
        fx.hit(splash_sfx(SMALL[(f // 6) % len(SMALL)]), sec(f), 0.14, -0.5 + ((f // 6) % 5) * 0.25)
    fx.hit(kenney("impactPunch_heavy", 2), sec(T.HOOKED), 0.5)
    fx.add(ratchet(sec(T.REEL) - sec(T.HOOKED), 8.0, 20.0), sec(T.HOOKED), 0.35, 0.1)
    for i, f in enumerate(T.SLAPS):
        fx.hit(splash_sfx(4 if i % 2 == 0 else 7), sec(f), 0.7, 0.3)
        fx.add(sub_boom(1.0, 70, 30), sec(f), 0.35)

    # 0:28 REEL IT IN: the build (as KABOOM's), the reel screaming, the leap, a breath
    t28 = bar_t(14)
    fx.add(riser(4.0 - 0.5), t28, 0.75)
    for i in range(16):
        music.add(kick(0.25), t28 + i * BEAT * 0.5, 0.6 + 0.02 * i)
    rolls = [x * 0.5 for x in range(8)] + [4 + x * 0.25 for x in range(8)] + [6 + x * 0.125 for x in range(12)]
    for i, bt in enumerate(rolls):
        music.add(snare(0.4 + 0.6 * i / len(rolls)), t28 + bt * BEAT, 0.8)
    n = int(3.5 * SR)
    tt = np.arange(n) / SR
    fr = midi(33) * 2 ** (tt / 3.5)
    music.add(np.tanh(1.5 * np.sin(2 * np.pi * np.cumsum(fr) / SR)) * 0.4 * np.clip(tt / 0.5, 0, 1), t28, 0.8)
    for i in range(14):
        strum(music, "Am" if i < 8 else "E", t28 + i * BEAT * 0.5, 0.1, beats=[0], bright=0.5)
    fx.add(ratchet(sec(T.BOSS_JUMP) - t28, 18.0, 40.0), t28, 0.4, 0.1)
    BJ = sec(T.BOSS_JUMP)
    fx.hit(splash_sfx(1), BJ + 0.1, 0.8)
    fx.add(sub_boom(2.0, 80, 26), BJ + 0.1, 0.6)
    fx.add(moan(1.2) * 1.5, BJ + 0.4, 0.4, -0.2)
    fx.add(whoosh(1.0), BJ + 0.3, 0.55)

    # 0:32 CAUGHT!: the blast, the drop, the logo run, the end card (as KABOOM)
    BK = sec(T.BIG_KABOOM)
    fx.add(explosion(3.0), BK, 1.0)
    fx.add(impact(3.0), BK, 0.85)
    fx.add(crash(2.6), BK, 0.55)
    fx.hit(splash_sfx(4), BK + 0.05, 0.5)
    fx.hit(kenney("impactBell_heavy", 1), BK + 0.05, 0.45)
    for b in (16, 17):
        groove(music, b, ["C", "G"][b - 16], shakers=True, octave=True)
        lead(music, b, MOTIF_B, b - 16, gain=0.22, marimba_gain=0.18)
    for i, (f, n_) in enumerate(zip(T.FINALE_HITS, notes)):
        music.add(pluck(midi(n_), 0.6, 0.9), sec(f), 0.26, -0.3 + i * 0.07)
        fx.hit(kenney("impactPunch_medium", i % 5), sec(f), 0.3)
    fx.add(boing(), sec(T.FINALE_FISH), 0.5, 0.3)
    te = sec(T.END_HIT)
    for k, n_ in enumerate(CHORDS["C"]):
        music.add(pluck(midi(n_), 3.2, 0.7, 0.998), te + k * 0.025, 0.34, -0.2 + k * 0.13)
    music.add(marimba(midi(84), 2.6), te, 0.35)
    music.add(saw(midi(60), 1.6, gain=0.2), te, 1.0)
    music.add(bass(midi(36), 2.4), te, 0.6)
    music.add(kick(), te, 1.0)
    fx.add(impact(2.8), te, 0.55)
    fx.hit(kenney("confirmation", 1), te + 0.02, 0.3)
    fx.loop("x_splash_sfx/loop_bubbles_1.ogg", BK + 1.5, sec(T.TOTAL), 0.22, 0.5)

    mix = np.stack([music.L + fx.L, music.R + fx.R], 1)
    # a breath of near-silence on the last eighth before CAUGHT!
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
    print("music10", out, "%.1f s" % (len(m) / SR))

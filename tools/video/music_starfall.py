"""Soundtrack for the fosh&fish 1.0 ad "STARFALL" (tools/video/edit_starfall.py), on starfall_timeline's frames:
a night-time synth-pop loop in A minor (Am - F - C - G) on the KABOOM / Leviathan instruments
(tools/video/music.py, music_boom.py) with a soft saw pad and a starry arp, the sound effects on top
(CC0: Kenney Impact + Interface Sounds and rubberduck's water SFX in scratch/downloads, see CREDITS.md).

    0:00 the HOOK: the shiny bursts out (a hit, a splash, a high shimmer) ... a riser
    0:02 the stars fall: the pad, the arp, a "pew", a chime and a splash for every star
    0:06 the shinies leap: the beat comes in
    0:10 TAP: the beat drops out, the cast, the plop ... the bite: ding-ding ... REEL: the ratchet, a snare roll
    0:14 the shiny bursts out: a breath, the drop, the card       0:16 the collection: a note for every icon
    0:18 the events: a whoosh and a punch per band                0:20 the logo, the last chord, the taps on PLAY

    python tools/video/music_starfall.py OUT.wav
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import starfall_timeline as T  # noqa: E402
import music_boom as MB  # noqa: E402
from music import (BEAT, CHORDS, ROOT, SR, bass, clap, hat, impact, kick, marimba, midi, pluck, riser, save,  # noqa: E402
                   shaker, whoosh)
from music_boom import (Bus, boing, crash, kenney, lowpass, sample, saw, snare, splash_sfx, sub_boom, swell,  # noqa: E402
                        ratchet, SMALL)

DUR = T.TOTAL / T.FPS + 0.5
rng = np.random.default_rng(7)
PROG = ["Am", "F", "C", "G", "Am", "F", "G", "Am", "F", "C", "G", "C"]    # a chord a bar; the end card lands home
PENTA = [57, 60, 62, 64, 67, 69, 72, 74, 76, 79, 81, 84, 86, 88, 91, 93, 96, 98, 100, 103]   # A minor pentatonic
MOTIF = [(0, 76, .5), (.5, 79, .5), (1, 81, 1.5), (2.5, 79, .5), (3, 76, 1),
         (4, 74, .5), (4.5, 76, .5), (5, 72, 1.5), (6.5, 74, .5), (7, 76, 1)]


def sec(f):
    return f / float(T.FPS)


def bar_t(b, beat=0.0):
    return (b * 4 + beat) * BEAT


def pad(ch, dur, bright=0.06, gain=0.05):
    """a soft, wide saw pad (detuned pairs, low-passed), swelling in and out"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for note in CHORDS[ch] + [CHORDS[ch][0] + 12]:
        for det in (0.995, 1.005):
            ph = 2 * np.pi * midi(note) * det * t + rng.uniform(0, 2 * np.pi)
            x += sum(np.sin(h * ph) / h for h in range(1, 10))
    x = lowpass(x, bright)
    return x * np.clip(t / 0.3, 0, 1) * np.clip((dur - t) / 0.35, 0, 1) * gain


def arp(bus, b, step=0.5, gain=0.1, beats=4, start=0.0):
    """chord tones up and down an octave up, plucked (the stars twinkling)"""
    ch = PROG[b]
    notes = [n + 12 for n in CHORDS[ch]]
    order = [0, 1, 2, 3, 2, 1, 3, 2]
    k = 0
    bt = start
    while bt < beats - 1e-6:
        bus.add(pluck(midi(notes[order[k % len(order)]]), 0.45, 0.9), bar_t(b, bt), gain * (1.0 if k % 2 == 0 else 0.7),
                -0.4 + 0.8 * ((k * 3) % 5) / 4)
        k += 1
        bt += step


def drums(bus, b, kicks=(0, 1, 2, 3), claps=True, shakers=True, hats=True, bass_gain=0.34, octave=False):
    t0 = bar_t(b)
    r = ROOT[PROG[b]]
    for bt, n in [(0, r), (1.5, r + 12), (2, r), (3.5, r + 7)]:
        bus.add(bass(midi(n), 0.5), t0 + bt * BEAT, bass_gain)
    if octave:
        for bt in (0.5, 1.0, 2.5, 3.0):
            bus.add(bass(midi(r + 12), 0.3), t0 + bt * BEAT, bass_gain * 0.55)
    for bt in range(4):
        if bt in kicks:
            bus.add(kick(), t0 + bt * BEAT, 0.95 if bt % 2 == 0 else 0.85)
        if claps and bt in (1, 3):
            bus.add(clap(), t0 + bt * BEAT, 0.6)
            bus.add(snare(0.3), t0 + bt * BEAT, 1.0)
        if hats:
            for e in (0, 0.5):
                bus.add(hat(), t0 + (bt + e) * BEAT, 1.1 if e else 0.7, 0.35)
        if shakers:
            for s16 in (0.25, 0.75):
                bus.add(shaker(), t0 + (bt + s16) * BEAT, 1.2, -0.4)


def pew(dur=0.32):
    """a star falling: a quick descending whistle"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 600 + 2200 * (1 - t / dur) ** 2
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / dur) ** 1.5 * 0.35


def shimmer(bus, t0, dur, gain=0.1):
    """a sparkly run of high plucks (A minor pentatonic, sixteenths)"""
    notes = PENTA[9:]
    for i in range(int(dur / (BEAT / 4))):
        bus.add(pluck(midi(notes[(i * 3) % len(notes)]), 0.5, 0.95), t0 + i * BEAT / 4, gain * (0.7 + 0.3 * (i % 2)),
                -0.5 + (i % 5) * 0.25)


def tick(i):
    return sample("x_kenney_interface/Audio/tick_%03d.ogg" % (1, 2, 4)[i % 3])     # (there's no tick_003)


def sparkle(fx, t, gain=0.3, pan=0.0):
    fx.hit(kenney("glass", int(t * 10)), t, gain, pan)
    fx.add(MB.chirp(3200), t + 0.03, gain * 0.35, pan)


def burst(fx, music, t, ch="Am", big=1.0):
    """a shiny breaking the surface: the hit, the splash, a high chord ringing"""
    fx.add(impact(2.6), t, 0.8 * big)
    fx.add(sub_boom(2.2, 85, 26), t, 0.55 * big)
    fx.add(crash(2.2), t, 0.4 * big)
    fx.hit(splash_sfx(4), t + 0.02, 0.85, -0.2)
    fx.hit(splash_sfx(7), t + 0.06, 0.7, 0.25)
    fx.add(whoosh(0.9), t + 0.08, 0.45)
    for k, n in enumerate(CHORDS[ch]):
        music.add(pluck(midi(n + 12), 1.8, 0.85, 0.998), t + k * 0.02, 0.2, -0.3 + k * 0.2)
    sparkle(fx, t + 0.1, 0.35, 0.3)
    for _ in range(8):                                             # the sea raining back down
        fx.hit(splash_sfx(int(rng.choice(SMALL))), t + 0.5 + float(rng.uniform(0, 0.9)), float(rng.uniform(0.1, 0.22)),
               float(rng.uniform(-0.7, 0.7)))


def render():
    music = Bus(DUR)
    fx = Bus(DUR)

    # the night sea under it all, quietly
    fx.loop("x_splash_sfx/loop_water_02.ogg", 0.0, sec(T.BURST) + 1.0, 0.16, 0.6)

    # 0:00 HOOK: the shiny bursts out of the sea ... hangs in a shimmer ... a riser into the stars
    burst(fx, music, sec(T.HOOK_BURST), "Am", 1.0)
    music.add(pad("Am", bar_t(1) + 0.3), 0.0, 1.0)
    fx.hit(kenney("impactBell_heavy", 0), sec(T.HOOK_HANG), 0.35)
    shimmer(music, sec(T.HOOK_HANG), 0.9, 0.09)
    fx.add(riser(bar_t(1) - 1.1), 1.1, 0.45)

    # 0:02 the stars fall: pad + arp, a kick on 1 and 3; a pew, a chime and a splash per star
    for b in (1, 2):
        music.add(pad(PROG[b], 4 * BEAT + 0.35, 0.07), bar_t(b), 1.0)
        arp(music, b, 0.5, 0.09)
        drums(music, b, kicks=(0, 2), claps=False, shakers=False, hats=b == 2, bass_gain=0.26)
    for i, f in enumerate(T.FALLS):
        t = sec(f)
        pan = float(rng.uniform(-0.6, 0.6))
        fx.add(pew(0.3), t - 0.3, 0.32, pan)
        music.add(marimba(midi(PENTA[8 + (i * 3) % 10]), 0.9), t, 0.2, pan)
        fx.hit(splash_sfx(SMALL[i % len(SMALL)]), t + 0.01, 0.3, pan)
        if i % 3 == 0:
            sparkle(fx, t + 0.08, 0.16, -pan)

    # 0:06 the shinies leap: the beat comes in
    for b in (3, 4):
        music.add(pad(PROG[b], 4 * BEAT + 0.35, 0.09, 0.045), bar_t(b), 1.0)
        arp(music, b, 0.25, 0.07)
        drums(music, b, octave=b == 4)
    fx.add(swell(0.5), bar_t(3) - 0.5, 0.4)
    for i, f in enumerate(T.LEAPS):
        pan = -0.5 if i % 2 == 0 else 0.5
        fx.hit(splash_sfx(SMALL[i % len(SMALL)]), sec(f), 0.45, pan)
        sparkle(fx, sec(f + 6), 0.25, pan)
        music.add(marimba(midi(PENTA[10 + i % 6]), 0.7), sec(f + 6), 0.16, pan)
        fx.hit(splash_sfx(SMALL[(i + 3) % len(SMALL)]), sec(f + 23), 0.28, -pan * 0.5)

    # 0:10 TAP: the beat drops out; the cast, the plop ... the bite ... REEL IT IN
    music.add(pad("F", 4 * BEAT + 0.35, 0.05, 0.055), bar_t(5), 1.0)
    arp(music, 5, 1.0, 0.07)
    music.add(bass(midi(ROOT["F"]), 1.6), bar_t(5), 0.3)
    fx.hit(kenney("select", 0), sec(T.TAP), 0.5)                  # the finger on the screen
    fx.add(whoosh(0.55), sec(T.TAP) + 0.05, 0.55, 0.2)
    fx.hit(sample("x_splash_sfx/bubble_02.ogg"), sec(T.LANDS), 0.6, 0.2)
    fx.hit(splash_sfx(10), sec(T.LANDS) + 0.02, 0.35, 0.2)
    tb = sec(T.BITE)
    for k, n in enumerate((88, 93)):                               # ding-ding!
        music.add(marimba(midi(n), 0.6), tb + k * 0.09, 0.32)
        music.add(pluck(midi(n), 0.5, 0.95), tb + k * 0.09, 0.15)
    fx.hit(kenney("impactGlass_light", 1), tb, 0.3)
    fx.hit(splash_sfx(3), tb + 0.02, 0.3, 0.2)
    tr = sec(T.REEL)
    music.add(pad("G", sec(T.BURST) - tr + 0.2, 0.04, 0.06), tr, 1.0)
    fx.add(ratchet(sec(T.BURST) - tr - 0.05, 12.0, 34.0), tr, 0.38, 0.1)
    fx.add(riser(sec(T.BURST) - tr - 0.1), tr, 0.7)
    for i in range(8):
        music.add(kick(0.25), bar_t(6, i * 0.5), 0.55 + 0.04 * i)
    rolls = [x * 0.5 for x in range(4)] + [2 + x * 0.25 for x in range(4)] + [3 + x * 0.125 for x in range(8)]
    for i, bt in enumerate(rolls):
        music.add(snare(0.35 + 0.65 * i / len(rolls)), bar_t(6, bt), 0.75)
    n = int((sec(T.BURST) - tr) * SR)
    tt = np.arange(n) / SR
    fr = midi(43) * 2 ** (tt / (n / SR))                           # a rising saw, an octave
    music.add(np.tanh(1.3 * np.sin(2 * np.pi * np.cumsum(fr) / SR)) * 0.25 * np.clip(tt / 0.4, 0, 1), tr, 0.8)
    for f in range(T.REEL, T.BURST, 8):
        fx.hit(splash_sfx(SMALL[(f // 8) % len(SMALL)]), sec(f), 0.14, 0.2)

    # 0:14 the shiny bursts out: the drop ... it hangs, the card
    tbst = sec(T.BURST)
    burst(fx, music, tbst, "Am", 1.15)
    for b in (7, 8, 9):
        music.add(pad(PROG[b], 4 * BEAT + 0.35, 0.1, 0.04), bar_t(b), 1.0)
        arp(music, b, 0.25, 0.06)
        drums(music, b, octave=True)
        MB.lead(music, b, MOTIF, (b - 7) % 2, gain=0.17, marimba_gain=0.17)
    fx.hit(kenney("impactBell_heavy", 1), sec(T.HANG), 0.4)
    shimmer(music, sec(T.HANG), 0.8, 0.08)
    fx.hit(kenney("maximize", 0), sec(T.HANG + 6), 0.4)            # the shiny card pops up
    fx.hit(kenney("confirmation", 1), sec(T.HANG + 8), 0.3)
    for k in range(10):                                            # the number rolls to No. 0042
        fx.hit(tick(k), sec(T.HANG + 7 + k * 1.8), 0.18)

    # 0:16 the collection: a note for every icon popping in
    for i in range(20):
        t = sec(T.GRID + 2 * i)
        music.add(marimba(midi(PENTA[i]), 0.5), t, 0.15, -0.6 + 1.2 * (i % 5) / 4)
        fx.hit(tick(i), t, 0.1)
    sparkle(fx, sec(T.GRID + 40), 0.3)

    # 0:18 the events: a band slides in, a whoosh and a punch each
    for i, f in enumerate(T.EXTRA_IN):
        fx.add(whoosh(0.35), sec(f) - 0.2, 0.55, -0.5 + 0.5 * i)
        fx.hit(kenney("impactPunch_heavy", i), sec(f) + 0.12, 0.45, -0.5 + 0.5 * i)
        fx.add(crash(1.0), sec(f) + 0.12, 0.2)

    # 0:20 the logo: a rising pluck + thump per letter, a boing for the fish
    drums(music, 10, kicks=(0, 2), claps=False, shakers=True, bass_gain=0.3)
    music.add(pad("G", 4 * BEAT + 0.3, 0.08, 0.045), bar_t(10), 1.0)
    notes = [69, 72, 76, 79, 81, 84, 88, 91, 93]
    for i, (f, n_) in enumerate(zip(T.LOGO_HITS, notes)):
        music.add(pluck(midi(n_), 0.7, 0.9), sec(f), 0.28, -0.3 + i * 0.07)
        fx.hit(kenney("impactPunch_medium", i % 5), sec(f), 0.4)
        music.add(kick(0.2), sec(f), 0.3)
    fx.add(boing(), sec(T.LOGO_FISH), 0.5, 0.3)
    fx.hit(splash_sfx(10), sec(T.LOGO_FISH) + 0.05, 0.3, 0.3)
    fx.add(whoosh(0.5), sec(T.END) - 0.25, 0.45)

    # 0:22 the end card lands: the last chord (C), then the beat carries on softly under the taps on PLAY
    te = sec(T.END_HIT)
    for k, n_ in enumerate(CHORDS["C"]):
        music.add(pluck(midi(n_ + 12), 2.4, 0.75, 0.998), te + k * 0.025, 0.3, -0.2 + k * 0.13)
    music.add(marimba(midi(84), 2.2), te, 0.3)
    music.add(saw(midi(60), 1.4, gain=0.18), te, 1.0)
    music.add(bass(midi(36), 2.0), te, 0.55)
    music.add(kick(), te, 1.0)
    fx.add(impact(2.4), te, 0.5)
    fx.add(crash(1.8), te, 0.3)
    music.add(pad("C", sec(T.TOTAL) - te + 0.5, 0.07, 0.05), te, 1.0)
    arp(music, 11, 0.5, 0.06, start=1.0)
    drums(music, 11, kicks=(1, 2, 3), claps=True, shakers=True, bass_gain=0.25)
    for f in T.END_TAPS:
        fx.hit(kenney("select", f), sec(f), 0.5)
        fx.hit(kenney("confirmation", 0), sec(f) + 0.05, 0.2)

    mix = np.stack([music.L + fx.L, music.R + fx.R], 1)
    a, b = int((tbst - 0.24) * SR), int((tbst - 0.012) * SR)      # a breath of near-silence before the drop
    dip = np.ones(b - a)
    r = int(0.04 * SR)
    dip[:r] = np.linspace(1, 0.08, r)
    dip[r:] = 0.08
    mix[a:b] *= dip[:, None]
    mix = np.tanh(mix * 1.3) / np.tanh(1.3)
    mix /= np.max(np.abs(mix)) / 0.89
    mix = mix[:int(T.TOTAL / T.FPS * SR)]
    fade = int(0.5 * SR)
    mix[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
    return mix


if __name__ == "__main__":
    out = sys.argv[1]
    m = render()
    save(out, m)
    print("music_starfall", out, "%.1f s" % (len(m) / SR))

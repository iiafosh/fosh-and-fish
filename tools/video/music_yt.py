"""Soundtrack for the YouTube cut (tools/video/edit_yt.py): the fosh&fish trailer theme (music.py)
re-arranged with a break and a drop. 120 BPM, 2 s bars, original and synthesized (no samples).

    bar 0      intro riser + plucks          (hook montage)
    bar 1      IMPACT, groove starts          (title slam)
    bars 2-13  groove, busier in 4-5 / 7-8 / 11-13
    bars 14-15 BREAK: no drums, long strums, riser, a beat of silence
    bar 16     IMPACT + DROP 16-19            (boat parade)
    bars 20-21 groove                         (free to play)
    bar 22     final chord + impact, bar 23 tail (end card)

    python tools/video/music_yt.py OUT.wav
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from music import (BAR, BEAT, CHORDS, MOTIF_A, MOTIF_B, PROG, ROOT, SR, STRUM, bass, clap, hat, impact, kick,
                   marimba, midi, pluck, riser, save, shaker)

BARS = 24
BUSY = set(range(4, 6)) | set(range(7, 9)) | set(range(11, 14)) | set(range(16, 20))
BREAK = {14, 15}
DROP = set(range(16, 20))


def render():
    total = BARS * BAR + 3.0
    L = np.zeros(int(total * SR) + SR)
    R = np.zeros_like(L)

    def add(sig, t, gain=1.0, pan=0.0):
        i = int(t * SR)
        j = min(len(L), i + len(sig))
        if j <= i:
            return
        L[i:j] += sig[:j - i] * gain * (1 - max(0, pan))
        R[i:j] += sig[:j - i] * gain * (1 + min(0, pan))

    # bar 0: riser under quick plucks (the hook montage cuts on each beat)
    add(riser(BAR), 0.0, 0.55)
    for k in range(8):
        add(pluck(midi(CHORDS["C"][k % 4] + 12), 0.6, 0.9), k * BEAT * 0.5, 0.22, 0.4 * (k % 2 * 2 - 1))
    add(impact(), BAR, 0.95)
    for b in range(1, BARS):
        t0 = b * BAR
        ch = PROG[(b - 1) % 4]
        if b == BARS - 2:
            for k, n in enumerate(CHORDS["C"]):
                add(pluck(midi(n), 3.2, 0.7, 0.998), t0 + k * 0.025, 0.34, -0.2 + k * 0.13)
            add(marimba(midi(84), 2.6), t0, 0.35)
            add(bass(midi(36), 2.2), t0, 0.55)
            add(kick(), t0, 0.95)
            add(impact(2.8) * 0.5, t0, 0.6)
            continue
        if b == BARS - 1:
            continue                                  # tail: the final chord rings out
        if b in BREAK:
            # long, soft strums and the lead alone; riser into the drop; silence on the last beat
            for k, n in enumerate(CHORDS[ch]):
                add(pluck(midi(n), 2.2, 0.35, 0.998), t0 + k * 0.03, 0.2, -0.25 + k * 0.17)
            for bt, n, ln in (MOTIF_B[:4] if b == 14 else MOTIF_B[4:8]):
                add(marimba(midi(n), ln * BEAT + 0.4), t0 + (bt % 4) * BEAT, 0.28, 0.1)
            if b == 15:
                add(riser(BAR - BEAT * 0.5), t0, 0.6)
            continue
        busy = b in BUSY
        drop = b in DROP
        if b == 16:
            add(impact(), t0, 0.9)
        for sb in STRUM:
            for k, n in enumerate(CHORDS[ch]):
                add(pluck(midi(n), 0.9, 0.6 if sb % 1 == 0 else 0.4), t0 + sb * BEAT + k * 0.012,
                    0.2 if sb % 1 == 0 else 0.13, -0.25 + k * 0.17)
        r = ROOT[ch]
        for bt, n in [(0, r), (1.5, r + 12), (2, r), (3.5, r + 7)]:
            add(bass(midi(n), 0.5), t0 + bt * BEAT, 0.33)
        if drop:                                       # the drop: octave bass on the off-beats
            for bt in (0.5, 1.0, 2.5, 3.0):
                add(bass(midi(r + 12), 0.3), t0 + bt * BEAT, 0.2)
        for bt in range(4):
            if bt in (0, 2) or (busy and bt in (1, 3)) or (drop and True):
                add(kick(), t0 + bt * BEAT, 0.8 if bt in (0, 2) else 0.55)
            if bt in (1, 3):
                add(clap(), t0 + bt * BEAT, 0.6 if drop else 0.5)
            for e in (0, 0.5):
                add(hat(), t0 + (bt + e) * BEAT, 1.0 if e else 0.6, 0.35)
            if busy:
                for s16 in (0.25, 0.75):
                    add(shaker(), t0 + (bt + s16) * BEAT, 1.0, -0.4)
        motif = MOTIF_B if (busy or drop) else MOTIF_A
        bar_in = (b - 2) % 2
        for bt, n, ln in motif:
            if bar_in * 4 <= bt < bar_in * 4 + 4:
                add(marimba(midi(n), ln * BEAT + 0.3), t0 + (bt - bar_in * 4) * BEAT, 0.3, 0.15)
        if b == 15 - 2:
            pass
    mix = np.stack([L, R], 1)
    mix = np.tanh(mix * 1.2) / np.tanh(1.2)
    mix /= np.max(np.abs(mix)) / 0.89
    return mix


if __name__ == "__main__":
    save(sys.argv[1], render())
    print("music_yt", sys.argv[1], BARS * BAR, "s")

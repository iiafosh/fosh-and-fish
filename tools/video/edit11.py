"""fosh&fish marketing videos for today's game, edited from the --reel11 recording, cut to the soundtrack.

  trailer   ~32 s  16x9 + 9x16   the bay, a catch, friends' boats, Reel it in!, the Derby, a shiny, three worlds,
                                 the Derby Cup (YouTube, the Google Play promo video, Loadout's game media)
  friends   ~15 s  9x16 + 1x1    ad: "Fish with your friends"
  derby     ~15 s  9x16 + 1x1    ad: "3 minutes. One board."

    (record at 1920x1080: the movie writer uses the project's base size, so a 1920x1080 base with the same UI scale)
    printf '[display]\\nwindow/size/viewport_width=1920\\nwindow/size/viewport_height=1080\\nwindow/stretch/scale=1.5\\n' > override.cfg
    godot --path . --resolution 1920x1080 --write-movie WORK/reel.avi --fixed-fps 30 -- --reel11 > WORK/reel_log.txt
    (then move override.cfg out of the project again)
    python tools/video/edit11.py WORK OUT [trailer,friends,derby] [--track felicity]

Built on edit10.py (its shots, camera, captions, end card), with music instead of sound effects: one of the game's
own Scott Buckley tracks (CC BY 4.0: the credit is on the end card, and must go in every video's description too),
its liveliest stretch, the cuts on its beat, the game's own sounds under it.
"""
import os
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
TRACK = "felicity"
if "--track" in sys.argv:
    TRACK = sys.argv[sys.argv.index("--track") + 1]
import edit10 as E  # noqa: E402  (reads WORK/reel_log.txt; WORK and OUT are argv 1 and 2)
from PIL import ImageDraw  # noqa: E402

ROOT = E.ROOT
W, H = E.W, E.H

# the marks of a --reel11 recording are already in the 1920x1080 canvas (edit10 scales 1280x720 ones by 1.5)
for _name, _ms in E.marks.items():
    for _m in _ms:
        _m["bob"] = (_m["bob"][0] / E.SRC_SCALE, _m["bob"][1] / E.SRC_SCALE)
        _m["boat"] = (_m["boat"][0] / E.SRC_SCALE, _m["boat"][1] / E.SRC_SCALE)

# the end card's sticker says what's new now (edit10's said NEW 1.0)
_pill = E.pill


def _pill_now(text, *a, **k):
    text = {"NEW 1.0": "NEW: FISH WITH FRIENDS", "THE 1.0 UPDATE": "NOW WITH FRIENDS"}.get(text, text)
    return _pill(text, *a, **k)


E.pill = _pill_now


# ------------------------------------------------------------------ the music
def decode(path):
    raw = subprocess.run([E.FF, "-loglevel", "error", "-i", path, "-f", "s16le", "-ac", "2", "-ar", str(E.SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.int16).reshape(-1, 2).astype(np.float32) / 32768


MUSIC = decode(os.path.join(ROOT, "assets", "audio", "music", TRACK + ".ogg"))
_mono = MUSIC.mean(1)
_hop = E.SR // 100                                    # 100 frames a second
_rms = np.sqrt((_mono[: len(_mono) // _hop * _hop].reshape(-1, _hop) ** 2).mean(1) + 1e-9)
_ONSETS = np.maximum(np.diff(np.log(_rms + 1e-4), prepend=0.0), 0.0)


def _onsets():
    """how sharply the music gets louder, 100 times a second (for the tempo and the downbeats)"""
    return _ONSETS


def tempo():
    """the beat in seconds: the strongest repeat of the onsets between 0.4 and 1.0 s"""
    o = _onsets() - _onsets().mean()
    ac = np.correlate(o, o, "full")[len(o) - 1:]
    lags = np.arange(40, 101)
    return float(lags[np.argmax(ac[40:101])]) / 100.0


def best_start(seconds):
    """where the liveliest stretch of `seconds` starts, moved onto its nearest strong onset"""
    n = int(seconds * 100)
    c = np.convolve(_rms, np.ones(n) / n, "valid")
    i = int(np.argmax(c[: max(1, len(c) - 1)]))
    o = _onsets()
    w = o[max(0, i - 50): i + 50]
    return (max(0, i - 50) + int(np.argmax(w))) / 100.0 if len(w) else i / 100.0


BEAT_S = tempo()
while BEAT_S < 0.45:
    BEAT_S *= 2.0
E.BEAT = max(12, int(round(BEAT_S * E.FPS)))         # the cuts land on the music's beat
print("music: %s, beat %.2f s (%d frames)" % (TRACK, BEAT_S, E.BEAT), flush=True)


def build_audio(cut):
    """the soundtrack (its liveliest part, faded in and out), the game's own sounds under it, a soft whoosh on whips"""
    game = E.game_audio()
    total = cut.total / E.FPS
    n = int((total + 1.0) * E.SR)
    out = np.zeros((n, 2), np.float32)
    s0 = int(best_start(total + 1.0) * E.SR)
    mus = MUSIC[s0:s0 + n]
    if len(mus) < n:
        mus = np.concatenate([mus, np.zeros((n - len(mus), 2), np.float32)])
    t = np.arange(n) / E.SR
    env = np.minimum(1.0, t / 0.6) * np.clip((total + 0.4 - t) / 2.2, 0.0, 1.0)
    out += mus * env[:, None] * 0.85
    wsh = E.music.whoosh(0.4)
    pos = 0
    for s in cut.shots:
        a = int(pos / E.FPS * E.SR)
        dur = s["n"] / E.FPS
        if s.get("src") is not None:
            g0 = int(s["src"] / E.FPS * E.SR)
            seg = game[g0:g0 + int(dur * E.SR)]
            ramp = np.minimum(1, np.minimum(np.arange(len(seg)), np.arange(len(seg))[::-1]) / 480.0)[:, None]
            seg = seg[: max(0, min(len(seg), n - a))]
            out[a:a + len(seg)] += seg * ramp[: len(seg)] * s["fx"].get("game", 0.3)
        if s.get("whoosh"):
            w = E.stereo(wsh)
            b = max(0, a - int(0.2 * E.SR))
            w = w[: max(0, min(len(w), n - b))]
            out[b:b + len(w)] += w * 0.16
        pos += s["n"]
    out = np.tanh(out * 1.05) / np.tanh(1.05)
    path = os.path.join(E.WORK, "mix_%s.wav" % cut.name)
    import wave
    with wave.open(path, "wb") as wv:
        wv.setnchannels(2)
        wv.setsampwidth(2)
        wv.setframerate(E.SR)
        wv.writeframes((np.clip(out, -1, 1) * 32767).astype(np.int16).tobytes())
    return path


E.build_audio = build_audio

# the music's credit on the end card (CC BY 4.0)
CREDIT = "Music: “%s” by Scott Buckley, scottbuckley.com.au (CC BY 4.0)" % TRACK.replace("_", " ").title()
_draw = E.draw_frame


def _draw_now(cut, fmt, s, i, img):
    c = _draw(cut, fmt, s, i, img)
    if s.get("tag") == "end" and i > 6:
        ow, oh = E.FORMATS[fmt]
        d = ImageDraw.Draw(c)
        f = E.font(int(22 if fmt == "16x9" else 26), 600)
        d.text((ow / 2, oh - 34), CREDIT, font=f, fill=(255, 255, 255, 200), anchor="mm")
    return c


E.draw_frame = _draw_now


# ------------------------------------------------------------------ the cuts
mk, mid, Cut = E.mk, E.mid, E.Cut
SOFT = dict(whip=True, whoosh=True)                   # (a cozy game: gentle cuts, no flashes or shakes)
FRIENDS = (W * 0.66, H * 0.52)
CARD = (W * 0.5, H * 0.48)
CATCH = (W * 0.55, H * 0.34)


CUP = lambda m: (m["boat"][0] + 40, m["boat"][1] - 120)     # (the captain's head, the cup on it)


def cut_trailer():
    """~31 s at the track's beat (0.73 s for Felicity)"""
    c = Cut("trailer", ["16x9", "9x16"])
    b = mk("bay")
    c.shot(b["f"] + 4, 3, 1.04, 1.12, mid(b), caption=[("A", False), ("cozy", True), ("fishing", False), ("game", False)], game=0.25)
    c.shot(b["f"] + 70, 3, 1.1, 1.16, mid(b), tag="title", game=0.25)
    k = mk("catch")
    c.shot(k["f"] + 6, 3, 1.3, 1.4, CATCH, caption=[("Catch", False), ("them", False), ("all", True)], **SOFT)
    f = mk("friends")
    c.shot(f["f"] + 10, 4, 1.12, 1.2, FRIENDS, caption=[("Fish", False), ("with", False), ("friends", True)], **SOFT)
    fw = mk("friends_wave")
    c.shot(fw["f"] + 2, 3, 1.22, 1.28, FRIENDS, caption=[("Live,", True), ("in", False), ("your", False), ("bay", False)])
    r = mk("reel")
    c.shot(r["f"] + 8, 3, 1.22, 1.32, CARD, caption=[("Reel", True), ("it", False), ("in!", True)], **SOFT)
    d = mk("derby")
    c.shot(d["f"] + 6, 3, 1.08, 1.14, (W * 0.5, H * 0.42), caption=[("The", False), ("weekly", False), ("Derby", True)], **SOFT)
    dr = mk("derby_result")
    c.shot(dr["f"] + 10, 2, 1.25, 1.3, (W * 0.5, H * 0.45), caption=[("Beat", False), ("my", False), ("score", True)])
    s = mk("shiny")
    c.shot(s["f"] + 10, 3, 1.3, 1.42, E.SHINY, caption=[("Only", False), ("3,000", True), ("of", False), ("each", False)],
           sparkle=True, **SOFT)
    sk = mk("sky")
    c.shot(sk["f"] + 4, 2, 1.05, 1.1, mid(sk), caption=[("7", True), ("worlds", False)], label="Sky", **SOFT)
    v = mk("volcanic")
    c.shot(v["f"] + 4, 2, 1.05, 1.1, mid(v), label="Volcanic", **SOFT)
    sp = mk("space")
    c.shot(sp["f"] + 4, 2, 1.05, 1.1, mid(sp), label="Space", **SOFT)
    cu = mk("cup")
    c.shot(cu["f"] + 6, 3, 1.7, 1.82, CUP(cu), caption=[("Win", False), ("the", False), ("Derby", True), ("Cup", True)], **SOFT)
    c.end(6)
    return c


def cut_friends():
    c = Cut("friends", ["9x16", "1x1"])
    f = mk("friends")
    c.shot(f["f"] + 4, 4, 1.2, 1.3, FRIENDS, big=[("FISH", 0), ("WITH", 1), ("FRIENDS", 2)])
    c.shot(f["f"] + 60, 3, 1.3, 1.38, FRIENDS, caption=[("Send", False), ("a", False), ("code", True)], **SOFT)
    fw = mk("friends_wave")
    c.shot(fw["f"] + 2, 3, 1.3, 1.36, FRIENDS, caption=[("Their", False), ("boats,", False), ("live", True)])
    k = mk("catch")
    c.shot(k["f"] + 6, 3, 1.35, 1.43, CATCH, caption=[("Catch", False), ("together", True)], **SOFT)
    r = mk("reel")
    c.shot(r["f"] + 8, 3, 1.3, 1.38, CARD, caption=[("Reel", True), ("it", False), ("in!", True)], **SOFT)
    c.end(5)
    return c


def cut_derby():
    c = Cut("derby", ["9x16", "1x1"])
    d = mk("derby")
    c.shot(d["f"] + 2, 4, 1.15, 1.23, (W * 0.5, H * 0.42), big=[("3", 0), ("MINUTES", 1)])
    c.shot(d["f"] + 40, 3, 1.25, 1.33, CARD, caption=[("Same", False), ("fish", False), ("for", False), ("everyone", True)], **SOFT)
    dr = mk("derby_result")
    c.shot(dr["f"] + 10, 3, 1.3, 1.36, (W * 0.5, H * 0.45), caption=[("One", False), ("board", True)], **SOFT)
    cu = mk("cup")
    c.shot(cu["f"] + 6, 3, 1.8, 1.92, CUP(cu), caption=[("Win", False), ("the", False), ("Cup", True)], **SOFT)
    c.end(5)
    return c


CUTS = {"trailer": cut_trailer, "friends": cut_friends, "derby": cut_derby}

if __name__ == "__main__":
    args = [a for a in sys.argv[3:] if not a.startswith("--") and a != TRACK]
    want = args[0].split(",") if args else list(CUTS)
    os.makedirs(E.OUT, exist_ok=True)
    for name in want:
        cut = CUTS[name]()
        print("== %s: %.1f s" % (name, cut.total / E.FPS), flush=True)
        E.render(cut)
        for fmt in cut.formats:                       # (edit10 names them 1.0)
            old = os.path.join(E.OUT, "fosh-and-fish-1.0-%s-%s.mp4" % (name, fmt))
            new = os.path.join(E.OUT, "fosh-and-fish-%s-%s.mp4" % (name, fmt))
            if os.path.exists(old):
                os.replace(old, new)
                print("wrote", new, flush=True)

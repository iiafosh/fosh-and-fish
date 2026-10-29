"""The fosh&fish 1.0 ad "STARFALL" (the shiny hunt, by night): a vertical (9:16) mobile-game ad, payoff first.
One timeline shared by the Blender shots (tools/blender/starfall_video.py), the music
(tools/video/music_starfall.py) and the edit (tools/video/edit_starfall.py).
30 fps, 120 BPM: one beat = 15 frames, one bar = 60 frames.

    0:00 HOOK: a golden shiny bursts out of the night sea right at you: ONLY 3,000 EXIST
    0:02 every night, stars fall into the sea ... where they land, the water glows gold
    0:06 shiny fish leap out of the glow
    0:10 TAP to cast the Starfall Rod ... a bite ... REEL IT IN ... it bursts out: SHINY! No. 0042 of 3,000
    0:16 collect all 20
    0:18 + an event every 10 minutes, a boss to catch (the Leviathan trailer's shots)
    0:20 the logo under the stars, PLAY FREE
"""
FPS = 30
BEAT = 15
BAR = 60
W, H = 1080, 1920             # vertical


def at(bar, beat=0.0):
    return int(round(bar * BAR + beat * BEAT))


SHOTS = {
    "hook": (0, 60),          # bar 0
    "starfall": (60, 180),    # bars 1-2
    "shinies": (180, 300),    # bars 3-4
    "catch": (300, 480),      # bars 5-7
    "sky": (480, 600),        # bars 8-9: the night sky behind the collection grid and the event bands
    "logo": (600, 720),       # bars 10-11
}
EXTRAS = (540, 600)           # bar 9: three bands of the Leviathan trailer (build/boom10/frames) slide in, playing
EXTRA_SHOTS = [(360, "GOLDEN HOUR", "x2 MONEY"), (424, "FISH FRENZY", "2x FASTER CASTS"),
               (905, "BOSS FISH", "THE LEVIATHAN")]   # (the band's first Leviathan-trailer frame, label, what it does)
EXTRA_IN = [540, 552, 564]    # each band slides in
TOTAL = 720                   # 24 s

HOOK_BURST = 4                # the shiny breaks the surface
HOOK_HANG = 22                # ... and hangs in front of you
FALLS = [66, 74, 82, 90, 98, 106, 114, 122, 130, 138, 148, 158, 168]    # stars hitting the sea
LEAPS = [184, 202, 220, 238, 256, 274]                                    # shiny fish leap out of the glow
TAP = 306                     # the hand taps: cast
LANDS = 326                   # the bobber lands in a glow
BITE = 350
REEL = 362                    # REEL IT IN (the meter fills)
BURST = 420                   # the shiny bursts out of the sea
HANG = 436                    # ... and hangs
GRID = 484                    # the 20 shinies pop into the book, one every 2 frames
LOGO_HITS = [602, 606, 610, 613, 617, 621, 625, 628, 632]   # f o s h & f i s h
LOGO_FISH = 636
END = 650                     # the end card: PLAY FREE under the logo
END_HIT = 660                 # ... lands (the last chord)
END_TAPS = [676, 700]         # the hand taps PLAY FREE

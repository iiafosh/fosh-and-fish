"""The fosh&fish 1.0 trailer ("THE LEVIATHAN"): one timeline shared by the Blender shots
(tools/blender/boom10_video.py), the music (tools/video/music10.py) and the edit (tools/video/edit_boom10.py).
30 fps, 120 BPM: one beat = 15 frames, one bar = 60 frames. Same grid as the KABOOM video, and the logo
(bar 3) and the finale (bars 16-18) sit on the same frames, so those two shots are KABOOM's own.

    0:00 a calm sea at sunset ... a giant shadow slides under the boat ... the Leviathan breaches
    0:06 the 3D logo: THE 1.0 UPDATE
    0:08 shiny fish leap, sparkling: only 3,000 of each
    0:12 an event every 10 minutes: Golden Hour, Fish Frenzy, Treasure Tide, Meteor Shower
    0:20 the exclusive rods slam in
    0:24 the boss: the Leviathan circles, the line goes tight, reel it in, it leaps
    0:32 CAUGHT! the finale, the logo, play free
"""
FPS = 30
BEAT = 15
BAR = 60
W, H = 1920, 1080


def at(bar, beat=0.0):
    """frame of a bar / beat position"""
    return int(round(bar * BAR + beat * BEAT))


SHOTS = {
    "open": (0, 180),          # bars 0-2: calm -> the shadow -> the breach
    "logo": (180, 240),        # bar 3 (boom_video.shot_logo)
    "shiny": (240, 360),       # bars 4-5
    "golden": (360, 420),      # bar 6
    "frenzy": (420, 480),      # bar 7
    "treasure": (480, 540),    # bar 8
    "meteor": (540, 600),      # bar 9
    "rods": (600, 720),        # bars 10-11
    "boss": (720, 960),        # bars 12-15
    "finale": (960, 1140),     # bars 16-18 (boom_video.shot_finale)
}
TOTAL = 1140                   # 38 s
REUSED = ("logo", "finale")    # KABOOM's own shots (frames copied from build/boom/frames when there)

SHADOW = (36, 108)             # the giant shadow glides under the boat
BITE = 100                     # "!"
HUSH = 105                     # the music holds its breath
BREACH = 120                   # the Leviathan bursts out of the sea
LOGO_HITS = [180, 184, 188, 191, 195, 199, 203, 206, 210]      # f o s h & f i s h (as KABOOM)
LOGO_FISH = 214
SHINY_LEAPS = [244, 266, 288, 306]          # shiny fish break the surface
SHINY_HERO = 322               # the big one leaps at the camera ...
SHINY_FREEZE = 336             # ... and hangs there
EVENTS = [("golden", 360), ("frenzy", 420), ("treasure", 480), ("meteor", 540)]
FRENZY_LEAPS = [424 + i * 4 for i in range(12)]
CHESTS = [486, 494, 502, 510, 518]
METEORS = [543, 551, 559, 567, 575]          # impact frames
METEOR_FISH = 578
RODS = [604, 626, 648]          # each exclusive rod slams in
ROD_SPIN = 690
BOSS_SURFACE = 724              # the Leviathan surfaces and circles the boat
HOOKED = 782                    # the line goes tight
SLAPS = [800, 818, 836]         # tail slaps
REEL = 840                      # REEL IT IN! (the build)
BOSS_JUMP = 900                 # it leaps out of the sea
BIG_KABOOM = 960                # CAUGHT! (KABOOM's finale blast)
FINALE_HITS = [990, 992, 994, 996, 998, 1000, 1002, 1004, 1006]  # the logo again, faster (as KABOOM)
FINALE_FISH = 1010
END_HIT = 1080                  # the last chord

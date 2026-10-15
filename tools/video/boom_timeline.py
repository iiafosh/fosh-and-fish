"""The fosh&fish "KABOOM" marketing video: one timeline shared by the Blender shots
(tools/blender/boom_video.py), the soundtrack (tools/video/music_boom.py) and the edit
(tools/video/edit_boom.py). 30 fps, 120 BPM: one beat = 15 frames, one bar = 60 frames.

    0:00 cozy river, the fisher dozes on his rowboat ... the bobber dips
    0:04 KABOOM: a fiery pufferfish blows the river up
    0:06 the 3D logo slams in, letter by letter
    0:08 seven worlds, one bar each: river, volcano, ocean, sky, space, alien seas, the abyss
    0:20 the real game on floating screens: Reel it in!, 17 boats, FishTok, play online
    0:28 the 17 boats race past, everything builds up
    0:32 the big KABOOM, the logo, "play free" end card
"""
FPS = 30
BEAT = 15
BAR = 60
W, H = 1920, 1080


def at(bar, beat=0.0):
    """frame of a bar / beat position"""
    return int(round(bar * BAR + beat * BEAT))


# shot name -> (first frame, end frame (exclusive)); each shot is its own Blender scene
SHOTS = {
    "open": (0, 180),          # bars 0-2: cozy -> KABOOM
    "logo": (180, 240),        # bar 3
    "river": (240, 300),       # bar 4
    "volcanic": (300, 360),    # bar 5
    "ocean": (360, 420),       # bar 6
    "sky": (420, 480),         # bar 7
    "space": (480, 540),       # bar 8
    "alien": (540, 570),       # bar 9, first half
    "abyss": (570, 600),       # bar 9, second half
    "screens": (600, 840),     # bars 10-13
    "boats": (840, 960),       # bars 14-15
    "finale": (960, 1140),     # bars 16-18
}
TOTAL = 1140                   # 38 s

# the moments everything syncs to (frame numbers)
BITE = 100                     # the bobber dips
HUSH = 105                     # the music drops out
KABOOM = 120                   # the river explodes
LOGO_HITS = [180, 184, 188, 191, 195, 199, 203, 206, 210]      # f o s h & f i s h
LOGO_FISH = 214                # the little fish leaps onto the logo
WORLDS = [("river", 240), ("volcanic", 300), ("ocean", 360), ("sky", 420), ("space", 480),
          ("alien", 540), ("abyss", 570)]
LEAPS = {                      # fish leaping out of the water (frame they break the surface)
    "river": [240, 255, 270, 285],
    "volcanic": [307, 322, 337],
    "ocean": [362, 382, 397],
    "sky": [437, 452, 467],
    "space": [492, 507, 522],
    "alien": [544, 555],
    "abyss": [576, 587],
}
ERUPTION = 300                 # the volcano blows
SKY_PASS = 440                 # the flying galleon whooshes past (closest mid-bar)
SHUTTLE = 484                  # the space shuttle blasts past
SCREENS = [600, 660, 720, 780]  # a gameplay screen slams in on each bar
# 16 boats race past: on the eighth notes in bar 14, the sixteenths in bar 15; then the 17th rises
BOAT_PASSES = [840 + int(i * 7.5) for i in range(8)] + [900 + int(i * 3.75) for i in range(8)]
SURVEYOR = 930
BIG_KABOOM = 960
FINALE_HITS = [990, 992, 994, 996, 998, 1000, 1002, 1004, 1006]  # the logo again, faster
FINALE_FISH = 1010
END_HIT = 1080                 # the last chord

"""fosh&fish short vertical clips for TikTok, YouTube Shorts and Instagram Reels: the real game, one idea a clip.

    python tools/video/shorts.py record WORK [name,name]     # films the clips (vf_fun.shorts) into WORK/*.avi + *.log
    python tools/video/shorts.py cut WORK OUT [name,name]    # OUT/NN-name.mp4 (1080x1920, a caption on top), OUT/posts.md
                                                             # (the text for every post) and OUT/sheet-*.jpg (a look at each)

`record` films at 2560x1440: for that it puts an override.cfg (a bigger base size) in the project and takes it away again
when it's done. The game plays on the throwaway save in build/appdata_tmp and, being a --capture run, never talks to the
server. Without names it films everything, in a few passes (PASSES); with names, just those, into WORK/pick_<first>.avi.
`cut` reads every WORK/*.log ("SHORT name first_frame last_frame what | music track"); a newer recording of a clip wins.

The music in the clips is the game's own, by Scott Buckley (CC BY 4.0): the text of each post carries the credit for the
track that plays in it. Needs `pip install pillow imageio-ffmpeg` (or an ffmpeg on the PATH) and GODOT (the console exe).
"""
import glob
import os
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = os.environ.get("GODOT", r"C:\Program Files\Godot\Godot_console.exe")
try:
    import imageio_ffmpeg
    FF = imageio_ffmpeg.get_ffmpeg_exe()
except ImportError:
    FF = "ffmpeg"

FPS = 30
FRAME_OFFSET = -2                 # frames_drawn runs a little ahead of the movie writer (as in edit10.py)
REC_W, REC_H = 2560, 1440         # the recording: the game's 1280x720 layout with twice the pixels
W, H = 1080, 1920
INK, MINT = "#0b2930", "#5fe0bd"

# what to show of the game's 1280x720 screen (x, y, w, h), and where it goes in the 1080x1920 picture (x, y, w, h, corner)
PANEL = ((320, 60, 640, 640), (0, 450, 1080, 1080, 0))        # Reel it in!, with a little water round it
STAGE = ((267, 14, 691, 691), (0, 450, 1080, 1080, 0))        # the middle of the screen (its edges fall between the HUD's pills)
PHONE = ((471, 23, 338, 674), (209, 420, 662, 1320, 88))      # FishTok's phone, edge to edge
ZOOM = {"bigcatch": (335, 62, 500, 500)}                      # closer in (and under the HUD): on the whole screen the fish that leaps is small

GAG_TAGS = "#cozygames #indiegame #fishinggame #gamedev #funnygames"
TOK_TAGS = "#fishtok #cozygames #indiegame #fishinggame #gamedev"
CALM_TAGS = "#cozygames #cozygaming #indiegame #fishinggame #gamedev"

# name: (the line on the picture, the post's text, hashtags)
CLIPS = {
    "gag_disguise": ("This cod thinks I can't see it", "A cod in a fake moustache. \"Never seen that fish.\"", GAG_TAGS),
    "gag_selfie": ("It stopped mid-fight for a selfie", "On the hook, fighting for its life, and it still stops for a selfie. For its FishTok, it says.", GAG_TAGS),
    "gag_dead": ("This fish is playing dead. Badly.", "Playing dead is a classic. It helps if you stop talking.", GAG_TAGS),
    "gag_nap": ("The fish fell asleep on my hook", "Five more minutes, it says.", GAG_TAGS),
    "gag_shark": ("Suddenly it WANTS to be caught", "It fought me the whole way. Then it saw what was behind it.", GAG_TAGS),
    "gag_banana": ("It left a banana peel on my hook", "Nobody knows where a fish gets a banana.", GAG_TAGS),
    "gag_rocket": ("This fish has a rocket", "You can't catch a rocket. I tried anyway.", GAG_TAGS),
    "gag_boot": ("It hung a boot on my line", "Size 12. Not mine.", GAG_TAGS),
    "gag_dance": ("Too fabulous to be caught", "It stopped the fight to dance. Honestly, good fins.", GAG_TAGS),
    "gag_bribe": ("This fish tried to bribe me", "Three dollars and we never met. Tempting.", GAG_TAGS),
    "gag_puff": ("Oops. It puffed.", "The pufferfish says it's a medical condition.", GAG_TAGS),
    "gag_ink": ("Squid ink. Now I see nothing.", "The squid says that wasn't it. That was ink.", GAG_TAGS),
    "gag_closed": ("The turtle is not home", "I knocked. Nobody's home, apparently.", GAG_TAGS),
    "gag_flip": ("The dolphin is just showing off", "Ten out of ten, it says. It scored itself.", GAG_TAGS),
    "gag_chomp": ("The shark is eating my line", "It says it's a vegetarian. The line says otherwise.", GAG_TAGS),
    "gag_snip": ("This crab cut my line", "\"Oops, was that yours?\" Yes. Yes it was.", GAG_TAGS),
    "shiny": ("Only 3,000 of this fish exist", "Every shiny fish is numbered, and there are only 3,000 of each in the whole world. This one is No. 42.", CALM_TAGS),
    "bigcatch": ("When a new fish finally bites", "The first time you catch a new kind of fish, the whole bay hears about it.", CALM_TAGS),
    "sunset": ("No rush. Just fishing.", "The sun goes down, the music plays, and the fish keep biting. That's the whole plan.", CALM_TAGS),
    "tok_grwm": ("The fish in my game have their own TikTok", "It's called FishTok. This pufferfish does a get ready with me. It's two steps.", TOK_TAGS),
    "tok_bait": ("A day in the life of bait", "On FishTok, the feed inside the game, even the worm has a vlog. It's a short day.", TOK_TAGS),
    "tok_unbox": ("A crab unboxing a treasure chest", "FishTok is the feed inside the game. The fish post there, and so does this crab.", TOK_TAGS),
    "tok_story": ("Kevin the shark has something to say", "Storytime on FishTok, the feed inside the game: everyone thinks Kevin is scary.", TOK_TAGS),
    "tok_pov": ("POV: you are the fish", "Free food, just hanging there. What could go wrong? (FishTok, the feed inside the game.)", TOK_TAGS),
    "tok_reacts": ("A cod reacts to my catches", "It's emotional. FishTok is the feed inside the game, and the fish have opinions.", TOK_TAGS),
    "tok_dance": ("The shoal has a dance trend", "The shoal shuffle. Learn it, pass it on. (FishTok, the feed inside the game.)", TOK_TAGS),
    "tok_slow": ("A turtle's world record attempt", "Crossing the screen, with epic sports music. (FishTok, the feed inside the game.)", TOK_TAGS),
    "tok_deep": ("This cod is going through something", "Something it has never told anyone. Only on FishTok, the feed inside the game.", TOK_TAGS),
}
# the order to post them in: a trick, then something else, the strongest first
ORDER = ["gag_disguise", "tok_pov", "gag_puff", "shiny", "gag_bribe", "tok_story", "gag_selfie", "gag_shark", "tok_grwm", "gag_dead",
         "bigcatch", "gag_banana", "tok_bait", "gag_rocket", "gag_nap", "tok_unbox", "gag_boot", "sunset", "gag_dance", "tok_reacts",
         "gag_ink", "gag_closed", "tok_dance", "gag_flip", "gag_chomp", "tok_slow", "gag_snip", "tok_deep"]
PASSES = {
    "tricks1": ["gag_disguise", "gag_selfie", "gag_dead", "gag_nap", "gag_shark", "gag_banana", "gag_rocket", "gag_boot"],
    "tricks2": ["gag_dance", "gag_bribe", "gag_puff", "gag_ink", "gag_closed", "gag_flip", "gag_chomp", "gag_snip"],
    "moments": ["shiny", "bigcatch", "sunset"],
    "fishtok": [n for n in CLIPS if n.startswith("tok_")],
}
ACCOUNTS = """## The accounts (you make them: about 10 minutes)

One account on each: TikTok, YouTube (Shorts), Instagram (Reels). Use the same name everywhere.

- Name: fosh&fish
- Handle: foshfish (if taken: foshfishgame, then playfoshfish)
- Picture: assets/brand/icon_1024.png
- Bio: A cozy, funny fishing game. The fish fight back. Free in your browser.
- Link: https://foshfish.xyz

One clip a day, the same clip on all three, in the order below. One account per app: several accounts posting the
same clips get removed as spam.
"""


# ------------------------------------------------------------------ record
def record(work, names):
    os.makedirs(work, exist_ok=True)
    open(os.path.join(work, ".gdignore"), "a").close()            # (Godot must not import what lands here)
    over = os.path.join(ROOT, "override.cfg")
    if os.path.exists(over):
        sys.exit("override.cfg is already there: move it away first")
    passes = {"pick_" + names[0]: names} if names else PASSES
    env = dict(os.environ, APPDATA=os.path.join(ROOT, "build", "appdata_tmp"))
    os.makedirs(env["APPDATA"], exist_ok=True)
    try:
        with open(over, "w") as f:
            f.write("[display]\nwindow/size/viewport_width=%d\nwindow/size/viewport_height=%d\n" % (REC_W, REC_H))
        for tag, clips in passes.items():
            avi = os.path.join(work, tag + ".avi").replace("\\", "/")
            print("recording %s: %s" % (tag, ", ".join(clips)), flush=True)
            with open(os.path.join(work, tag + ".log"), "w") as log:
                subprocess.run([GODOT, "--path", ROOT, "--resolution", "%dx%d" % (REC_W, REC_H), "--write-movie", avi, "--fixed-fps", str(FPS),
                                "--", "--capture=" + os.path.abspath(work).replace("\\", "/"), "--shorts=" + ",".join(clips)],
                               stdout=log, stderr=subprocess.STDOUT, env=env, check=False)
            got = [ln.split()[1] for ln in open(os.path.join(work, tag + ".log"), errors="replace") if ln.startswith("SHORT ")]
            print("  got %d of %d%s" % (len(got), len(clips), "" if len(got) == len(clips) else "  MISSING: " + ", ".join(set(clips) - set(got))), flush=True)
    finally:
        if os.path.exists(over):
            os.remove(over)


# ------------------------------------------------------------------ cut
def marks(work):
    """{name: (avi, first_frame, last_frame, what, track)}, the newest recording of each"""
    out = {}
    for log in sorted(glob.glob(os.path.join(work, "*.log")), key=os.path.getmtime):
        avi = log[:-4] + ".avi"
        if not os.path.exists(avi):
            continue
        for ln in open(log, errors="replace"):
            mt = re.match(r"SHORT (\S+) (\d+) (\d+) (.*) \| (\S*)", ln)
            if mt:
                out[mt.group(1)] = (avi, int(mt.group(2)), int(mt.group(3)), mt.group(4), mt.group(5))
    return out


def titles():
    """the soundtrack's titles, by track id (assets/audio/music/<id>.ogg), from CREDITS.md"""
    out = {}
    for t, slug in re.findall(r"\[([^\]]+)\]\(https://www\.scottbuckley\.com\.au/library/([^/)]+)/\)", open(os.path.join(ROOT, "CREDITS.md"), encoding="utf-8").read()):
        out[slug.replace("-", "_")] = t
    return out


def font(size):
    f = ImageFont.truetype(os.path.join(ROOT, "assets", "third_party", "fonts", "Fredoka.ttf"), size)
    try:                                                          # (a variable font: its boldest)
        f.set_variation_by_axes([a["maximum"] if "eight" in str(a["name"]) else a["default"] for a in f.get_variation_axes()])
    except Exception:
        bold = os.path.join(ROOT, "build", "boom", "Fredoka-Bold.ttf")
        if os.path.exists(bold):
            f = ImageFont.truetype(bold, size)
    return f


def wrap(d, text, f, maxw):
    """one line if it fits, or the most even two"""
    if d.textlength(text, font=f) <= maxw:
        return [text]
    words, best = text.split(), None
    for i in range(1, len(words)):
        a, b = " ".join(words[:i]), " ".join(words[i:])
        m = max(d.textlength(a, font=f), d.textlength(b, font=f))
        if m <= maxw and (best is None or m < best[0]):
            best = (m, [a, b])
    return best[1] if best else None


def overlay(path, hook, box):
    """the caption over the picture: the line, the game's name under it, and the logo below the game"""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    size, lines = 92, None
    while lines is None:
        size -= 4
        f = font(size)
        lines = wrap(d, hook, f, W - 110)
    sub = font(40)
    step = int(size * 1.12)
    total = step * len(lines) + 62
    y = max(150, box[1] - 26 - total)
    for ln in lines:
        d.text((W // 2, y), ln, font=f, fill="white", anchor="ma", stroke_width=9, stroke_fill=INK)
        y += step
    d.text((W // 2, y + 12), "fosh&fish  ·  free fishing game", font=sub, fill=MINT, anchor="ma", stroke_width=6, stroke_fill=INK)
    below = box[1] + box[3]
    if below + 190 <= H - 170:                                    # room under the game: the logo
        logo = Image.open(os.path.join(ROOT, "assets", "brand", "logo.png")).convert("RGBA")
        lh = 150
        logo = logo.resize((int(logo.width * lh / logo.height), lh), Image.LANCZOS)
        im.alpha_composite(logo, ((W - logo.width) // 2, below + 34))
    im.save(path)


def mask(path, box):
    m = Image.new("L", (box[2], box[3]), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, box[2] - 1, box[3] - 1), radius=box[4], fill=255)
    m.save(path)


def peak_db(avi, t0, dur):
    r = subprocess.run([FF, "-hide_banner", "-ss", "%.3f" % t0, "-t", "%.3f" % dur, "-i", avi, "-vn", "-af", "volumedetect", "-f", "null", "-"],
                       capture_output=True, text=True)
    mt = re.search(r"max_volume: (-?[\d.]+) dB", r.stderr)
    return float(mt.group(1)) if mt else 0.0


def frame(mp4, at):
    """one frame of a finished clip, small"""
    raw = subprocess.run([FF, "-loglevel", "error", "-ss", "%.2f" % at, "-i", mp4, "-frames:v", "1", "-vf", "scale=270:480",
                          "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
    return Image.frombytes("RGB", (270, 480), raw) if len(raw) == 270 * 480 * 3 else None


def cut(work, out, names):
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, ".gdignore"), "a").close()
    got, music = marks(work), titles()
    posts = []
    for n, name in enumerate(ORDER, 1):
        if name not in got:
            continue
        avi, f0, f1, _what, track = got[name]
        src, box = PHONE if name.startswith("tok_") else (PANEL if name.startswith("gag_") else STAGE)
        src = ZOOM.get(name, src)
        # frames before the mark: a breath before a cast; a trick starts a few frames in (the toasts have just been cleared);
        # a skit starts on its first frame
        lead = 0 if name.startswith("tok_") else (-4 if name.startswith("gag_") else 3)
        t0 = max(0.0, (f0 + FRAME_OFFSET - lead) / FPS)
        dur = (f1 - f0 + lead) / FPS
        mp4 = os.path.join(out, "%02d-%s.mp4" % (n, name.replace("_", "-")))
        posts.append((n, name, mp4, dur, track))
        if names and name not in names:
            continue
        k = REC_H / 720.0
        cap = os.path.join(work, "_cap.png")
        overlay(cap, CLIPS[name][0], box)
        ins = ["-ss", "%.3f" % t0, "-t", "%.3f" % dur, "-i", avi, "-loop", "1", "-i", cap]
        fg = "[a]crop=%d:%d:%d:%d,scale=%d:%d:flags=lanczos[fg];" % (src[2] * k, src[3] * k, src[0] * k, src[1] * k, box[2], box[3])
        if box[4]:
            mk = os.path.join(work, "_mask.png")
            mask(mk, box)
            ins += ["-loop", "1", "-i", mk]
            fg += "[2:v]format=gray[m];[fg][m]alphamerge[fgm];"
        gain = min(12.0, max(0.0, -1.5 - peak_db(avi, t0, dur)))
        graph = ("[0:v]split=2[a][b];"
                 "[b]scale=-2:480,crop=270:480,gblur=sigma=9,eq=brightness=-0.16:saturation=0.9,scale=%d:%d:flags=bicubic[bg];" % (W, H)
                 + fg + "[bg][%s]overlay=%d:%d[v0];[v0][1:v]overlay=0:0,"
                 "scale=in_color_matrix=bt601:in_range=pc:out_color_matrix=bt709:out_range=tv,format=yuv420p[v]" % ("fgm" if box[4] else "fg", box[0], box[1]))
        audio = "volume=%.1fdB,afade=t=in:d=0.1,afade=t=out:st=%.3f:d=0.35" % (gain, max(0.0, dur - 0.35))
        subprocess.run([FF, "-y", "-loglevel", "error"] + ins + ["-filter_complex", graph, "-map", "[v]", "-map", "0:a", "-af", audio,
                        "-t", "%.3f" % dur, "-r", str(FPS), "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-c:a", "aac", "-b:a", "160k",
                        "-ar", "48000", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv",
                        "-movflags", "+faststart", mp4], check=True)
        print("%s  %.1f s  (+%.1f dB)" % (os.path.basename(mp4), dur, gain), flush=True)
    # the text for every post
    with open(os.path.join(out, "posts.md"), "w", encoding="utf-8") as f:
        f.write("# fosh&fish: short videos to post\n\n" + ACCOUNTS + "\n## The posts, in order\n")
        for n, name, mp4, dur, track in posts:
            hook, text, tags = CLIPS[name]
            credit = "Music: \"%s\" by Scott Buckley, CC BY 4.0, scottbuckley.com.au" % music.get(track, track.replace("_", " ").title())
            f.write("\n### %d. %s (%.0f s)\n\nTitle (YouTube): %s | fosh&fish\n\nText (all three):\n\n```\n%s\n\nfosh&fish is a free, cozy fishing game. Play in your browser: foshfish.xyz\n\n%s\n\n%s\n```\n"
                    % (n, os.path.basename(mp4), dur, hook, text, tags, credit))
    # a look at each: a frame from its middle, 7 to a sheet
    for s in range(0, len(posts), 7):
        tiles = [t for t in (frame(p[2], p[3] * 0.45) for p in posts[s:s + 7] if os.path.exists(p[2])) if t]
        if tiles:
            sheet = Image.new("RGB", (270 * len(tiles), 480), "black")
            for i, t in enumerate(tiles):
                sheet.paste(t, (270 * i, 0))
            sheet.save(os.path.join(out, "sheet-%d.jpg" % (s // 7 + 1)), quality=86)


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) >= 2 and a[0] == "record":
        record(a[1], a[2].split(",") if len(a) > 2 else [])
    elif len(a) >= 3 and a[0] == "cut":
        cut(a[1], a[2], a[3].split(",") if len(a) > 3 else [])
    else:
        sys.exit(__doc__)

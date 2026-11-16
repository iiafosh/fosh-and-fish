"""fosh&fish story videos for TikTok, YouTube Shorts and Instagram Reels: the fisherman's story, one short for each page.

    python tools/video/story.py OUT [1,3]     # OUT/story-<n>-<biome>.mp4 (1080x1920), OUT/story-posts.md, OUT/story-sheet.jpg

A page's painting (tools/art/story_source_<n>.*) fills the square in the middle and drifts slowly across; the page's
sentences (CHAPTERS in scripts/vf/vf_story.gd) come one at a time above it, in the look of the other clips (shorts.py);
the biome's own music plays under it (STATIONS in scripts/audio_manager.gd) and the text of each post carries its credit.
Without numbers it makes all seven (about a minute each). Needs what shorts.py needs, and numpy.
"""
import glob
import json
import os
import re
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shorts import FF, FPS, H, INK, MINT, ROOT, W, font, frame, titles  # noqa: E402

BOX = (0, 450, 1080, 1080)             # the painting's square: where the other clips have the game
SUB_Y = BOX[1] - 76                    # the small line just above it
SITE = "foshfish.xyz"
TAGS = "#cozygames #indiegame #fishinggame #storytime #gamedev"
# how far the square drifts across the painting (0 = at its left edge, 1 = at its right: what matters stays in sight),
# and the line that goes with the post
PAGES = {
    "River": ((0.0, 0.45), "He sold umbrellas in a town where it never rained. Then he took one day off."),
    "Volcanic": ((0.0, 0.7), "\"One more cast,\" he said. That was four thousand casts ago."),
    "Ocean": ((0.0, 1.0), "Every sailor had a story about it. Not one of them had a photo."),
    "Sky": ((0.0, 0.72),"Nobody told the boat it couldn't sail on clouds. So it did."),
    "Space": ((0.0, 1.0), "Still fishing. Send socks."),
    "Alien": ((0.0, 0.6), "The locals have a word for him. It means \"the one who won't go home\"."),
    "Abyss": ((0.0, 1.0), "He found what ate his lunch. It was asleep on a thousand rubber ducks."),
}


def chapters():
    """the story's pages, read from the game's own script (its CHAPTERS is written the way JSON is)"""
    src = open(os.path.join(ROOT, "scripts", "vf", "vf_story.gd"), encoding="utf-8").read()
    body = src[src.index("const CHAPTERS := ") + len("const CHAPTERS := "):]
    return json.loads(re.sub(r",\s*\]", "]", body[:body.index("\n]\n") + 2]))


def track_of(biome):
    """the track the game starts that biome with"""
    src = open(os.path.join(ROOT, "scripts", "audio_manager.gd"), encoding="utf-8").read()
    return re.search(r'"%s": \["([a-z_]+)"' % biome, src[src.index("const STATIONS"):]).group(1)


def source(n):
    found = [p for ext in ("png", "webp", "jpg", "jpeg") for p in glob.glob(os.path.join(ROOT, "tools", "art", "story_source_%d.%s" % (n, ext)))]
    return found[0] if found else None


def sentences(line):
    """a line's sentences, one to a card; what somebody says stays whole"""
    out, start, said = [], 0, False
    for i, c in enumerate(line):
        if c == '"':
            said = not said
        end = (c in ".?!" or (c == '"' and line[i - 1] in ".?!")) and not said
        if end and (i + 1 == len(line) or line[i + 1] == " "):
            out.append(line[start:i + 1].strip())
            start = i + 1
    if line[start:].strip():
        out.append(line[start:].strip())
    return out


def timeline(ch, n, total):
    """(words, big, seconds) for every card: the title, each sentence, the way out"""
    cards = [(ch["title"], True, 2.4)]
    for ln in ch["lines"]:
        cards += [(s, False, max(1.7, 0.95 + 0.048 * len(s))) for s in sentences(ln)]
    cards[-1] = (cards[-1][0], False, cards[-1][2] + 0.7)
    cards.append(("To be continued..." if n < total else "The end. He is still out there.", True, 2.6))
    return cards


def wrap(d, text, f, maxw):
    """as few lines as it takes, of about the same length"""
    def lines_at(width):
        out, cur = [], ""
        for w in text.split():
            t = (cur + " " + w).strip()
            if cur and d.textlength(t, font=f) > width:
                out.append(cur)
                cur = w
            else:
                cur = t
        return out + [cur]
    best = lines_at(maxw)
    for width in range(int(maxw) - 20, 200, -20):
        got = lines_at(width)
        if len(got) > len(best) or max(d.textlength(g, font=f) for g in got) > maxw:
            break
        best = got
    return best


def words(text, big):
    """a card: the words that stand above the painting, as large as fits there"""
    im = Image.new("RGBA", (W, BOX[1]), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    size = 96 if big else 64
    while True:
        size -= 4
        f = font(size)
        lines = wrap(d, text, f, W - 110)
        step = int(size * 1.12)
        y = SUB_Y - 14 - step * len(lines)
        if y >= 140 or size <= 36:
            break
    for ln in lines:
        d.text((W // 2, y), ln, font=f, fill="white", anchor="ma", stroke_width=max(6, size // 9), stroke_fill=INK)
        y += step
    return im


def small(text):
    im = Image.new("RGBA", (W, BOX[1]), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((W // 2, SUB_Y), text, font=font(40), fill=MINT, anchor="ma", stroke_width=6, stroke_fill=INK)
    return im


def faded(im, a):
    if a >= 0.999:
        return im
    out = im.copy()
    out.putalpha(im.getchannel("A").point(lambda v: int(v * max(0.0, a))))
    return out


def scene(n, ch, cards, total):
    """the video as a function: at(i) is its frame number i. Returns (at, frames)"""
    src = Image.open(source(n)).convert("RGB")
    sw, sh = src.size
    # what stands still: the painting again, soft and dark, behind everything, and the logo under the square
    bg = src.resize((int(sw * H / sh), H), Image.BICUBIC)
    bg = bg.crop(((bg.width - W) // 2, 0, (bg.width - W) // 2 + W, H)).filter(ImageFilter.GaussianBlur(28))
    bg = bg.point(lambda v: int(v * 0.5))
    logo = Image.open(os.path.join(ROOT, "assets", "brand", "logo.png")).convert("RGBA")
    logo = logo.resize((int(logo.width * 150 / logo.height), 150), Image.LANCZOS)
    bg.paste(logo, ((W - logo.width) // 2, BOX[1] + BOX[3] + 34), logo)
    top = bg.crop((0, 0, W, BOX[1])).convert("RGBA")
    cardims = [words(c[0], c[1]) for c in cards]
    subs = [small("The fisherman's story  ·  part %d of %d" % (n, total)), small("Play it free  ·  " + SITE)]
    starts = np.cumsum([0.0] + [c[2] for c in cards])
    dur = float(starts[-1])
    x0, x1 = PAGES[ch["biome"]][0]
    still = {}

    def at(i):
        t = i / FPS
        k = min(len(cards) - 1, int(np.searchsorted(starts, t, side="right")) - 1)
        u, d = t - starts[k], cards[k][2]
        a = min(1.0, (d - u) / 0.16) if k + 1 < len(cards) else 1.0       # (the last card stays to the end)
        if k > 0:
            a = min(a, u / 0.2)                                           # (the first is there from the first frame)
        last = k + 1 == len(cards)
        sa = a if last or (k + 2 == len(cards) and d - u < 0.16) else 1.0  # the small line changes with the last card
        p = t / dur
        p = p * p * (3.0 - 2.0 * p)                                       # slow away, slow to a stop
        s = sh / (1.0 + 0.07 * p)
        x, y = (sw - s) * (x0 + (x1 - x0) * p), (sh - s) * 0.5
        fr = bg.copy()
        fr.paste(src.resize((BOX[2], BOX[3]), Image.LANCZOS, box=(x, y, x + s, y + s)), (BOX[0], BOX[1]))
        if a >= 0.999 and sa >= 0.999 and k in still:
            band = still[k]
        else:
            band = top.copy()
            band.alpha_composite(faded(subs[1 if last else 0], sa))
            band.alpha_composite(faded(cardims[k], a))
            band = band.convert("RGB")
            if a >= 0.999 and sa >= 0.999:
                still[k] = band
        fr.paste(band, (0, 0))
        return fr

    return at, int(round(dur * FPS))


def music(ogg, dur):
    """where in the track to start (its first stretch that is not nearly silent) and how much louder to make it, so
    that every video is about as loud as the next"""
    raw = subprocess.run([FF, "-loglevel", "error", "-t", "150", "-i", ogg, "-ac", "1", "-ar", "8000", "-f", "s16le", "-"], capture_output=True).stdout
    a = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    sec = np.sqrt(np.add.reduceat(a * a, np.arange(0, len(a), 8000)) / 8000.0)       # how loud, a second at a time
    n = int(np.ceil(dur))
    means = np.array([sec[s:s + n].mean() for s in range(0, max(1, len(sec) - n))])
    start = int(np.argmax(means >= 0.8 * means.max()))
    part = a[start * 8000:(start + n) * 8000]
    return start, min(14.0, max(-6.0, -18.0 - 20.0 * np.log10(max(float(np.sqrt((part * part).mean())), 1e-4))))


def render(n, ch, cards, total, track, mp4):
    at, frames = scene(n, ch, cards, total)
    dur = frames / FPS
    ogg = os.path.join(ROOT, "assets", "audio", "music", track + ".ogg")
    a0, gain = music(ogg, dur)
    p = subprocess.Popen([FF, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H), "-r", str(FPS), "-i", "-",
                          "-ss", str(a0), "-t", "%.3f" % dur, "-i", ogg, "-map", "0:v", "-map", "1:a",
                          "-vf", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p,setparams=color_primaries=bt709:color_trc=bt709",
                          "-af", "volume=%.1fdB,alimiter=limit=0.84:level=false,afade=t=in:d=0.5,afade=t=out:st=%.3f:d=1.5" % (gain, max(0.0, dur - 1.5)),
                          "-t", "%.3f" % dur, "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-c:a", "aac", "-b:a", "160k", "-ar", "48000",
                          "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv",
                          "-movflags", "+faststart", mp4], stdin=subprocess.PIPE)
    for i in range(frames):
        p.stdin.write(at(i).tobytes())
    p.stdin.close()
    if p.wait() != 0:
        sys.exit("ffmpeg failed on " + mp4)
    print("%s  %.1f s  %d cards  music from %d s (%+.1f dB)" % (os.path.basename(mp4), dur, len(cards), a0, gain), flush=True)


def make(out, only):
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, ".gdignore"), "a").close()
    chs, names = chapters(), titles()
    posts = []
    for n, ch in enumerate(chs, 1):
        cards, track = timeline(ch, n, len(chs)), track_of(ch["biome"])
        mp4 = os.path.join(out, "story-%d-%s.mp4" % (n, ch["biome"].lower()))
        posts.append((n, ch, mp4, sum(c[2] for c in cards), track))
        if only and n not in only:
            continue
        if source(n) is None:
            print("%d %s: no painting (tools/art/story_source_%d.png)" % (n, ch["biome"], n))
            continue
        render(n, ch, cards, len(chs), track, mp4)
    with open(os.path.join(out, "story-posts.md"), "w", encoding="utf-8") as f:
        f.write("# fosh&fish: the fisherman's story, seven short videos\n\nPost them in order, one part a post, between the "
                "other clips (posts.md has the accounts). The same video and text on TikTok, YouTube Shorts and Instagram Reels.\n")
        for n, ch, mp4, dur, track in posts:
            credit = "Music: \"%s\" by Scott Buckley, CC BY 4.0, scottbuckley.com.au" % names.get(track, track.replace("_", " ").title())
            f.write("\n### Part %d. %s (%.0f s)\n\nTitle (YouTube): The fisherman's story, part %d: %s | fosh&fish\n\nText (all three):\n\n"
                    "```\n%s (Part %d of %d)\n\nfosh&fish is a free, cozy fishing game. Play in your browser: %s\n\n%s\n\n%s\n```\n"
                    % (n, os.path.basename(mp4), dur, n, ch["title"], PAGES[ch["biome"]][1], n, len(posts), SITE, TAGS, credit))
    # a look at each: its first frame, its middle and its end
    done = [p for p in posts if os.path.exists(p[2])]
    if done:
        sheet = Image.new("RGB", (270 * len(done), 480 * 3), "black")
        for i, p in enumerate(done):
            for j, k in enumerate((0.0, 0.5, 0.97)):
                t = frame(p[2], p[3] * k)
                if t:
                    sheet.paste(t, (270 * i, 480 * j))
        sheet.save(os.path.join(out, "story-sheet.jpg"), quality=86)


if __name__ == "__main__":
    arg = sys.argv[1:]
    if not arg:
        sys.exit(__doc__)
    make(arg[0], [int(x) for x in arg[1].split(",")] if len(arg) > 1 else [])

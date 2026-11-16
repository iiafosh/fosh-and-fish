"""fosh&fish story videos for TikTok, YouTube Shorts and Instagram Reels: the fisherman's story, one short for each page.

    python tools/video/story.py OUT [1,3] [--voice=af_heart]
                                    # OUT/story-<n>-<biome>.mp4 (1080x1920), OUT/story-posts.md, OUT/story-sheet.jpg

With --voice a narrator reads the page (tools/video/voice.py makes the spoken sentences first): each card stays as long
as its sentence takes to say, and the music dips under the voice.

A page's painting (tools/art/story_source_<n>.*) fills the square in the middle and drifts slowly across; the page's
sentences (CHAPTERS in scripts/vf/vf_story.gd) come one at a time above it, in the look of the other clips (shorts.py);
the biome's own music plays under it (STATIONS in scripts/audio_manager.gd) and the text of each post carries its credit.
Where build/social/anim/story-<n>.mp4 exists (animate.py makes it, on a Colab GPU), the painting is alive: that clip plays
in the square, forwards and then backwards, for as long as the page lasts.
Without numbers it makes all seven (about a minute each). Needs what shorts.py needs, and numpy.
"""
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shorts import FF, FPS, H, INK, MINT, ROOT, W, font, frame, titles  # noqa: E402

BOX = (0, 450, 1080, 1080)             # the painting's square: where the other clips have the game
SUB_Y = BOX[1] - 76                    # the small line just above it
CLIP_FPS = 16.0 * 0.85                 # an animated painting is made at 16 pictures a second; played a little slower, it is calmer
VOICE_DIR = os.path.join(ROOT, "build", "social", "voice")
VOICE_SPEED = 0.95                     # the narrator, a little slower than Kokoro's own pace: a story, told
VOICE_AT = 0.15                        # seconds into its card that a sentence starts
SR = 48000
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


def moving(n):
    """the page's painting brought to life (tools/video/animate.py makes build/social/anim/story-<n>.mp4), as frames, or
    None when there is none: then the painting itself is shown"""
    mp4 = os.path.join(ROOT, "build", "social", "anim", "story-%d.mp4" % n)
    if not os.path.exists(mp4):
        return None
    size = re.search(r", (\d{3,4})x(\d{3,4})", subprocess.run([FF, "-hide_banner", "-i", mp4], capture_output=True, text=True, errors="replace").stderr)
    w, h = int(size.group(1)), int(size.group(2))
    raw = subprocess.run([FF, "-loglevel", "error", "-i", mp4, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.uint8).reshape(-1, h, w, 3)


def there_and_back(u, a=0.12):
    """0..1 -> 0..1 at a steady pace, easing away from the start and into the end: the clip is played forwards and then
    backwards for as long as the page lasts, and the turn must not jerk"""
    if u < a:
        return u * u / (2.0 * a * (1.0 - a))
    if u > 1.0 - a:
        return 1.0 - (1.0 - u) * (1.0 - u) / (2.0 * a * (1.0 - a))
    return (u - a / 2.0) / (1.0 - a)


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


def cards_of(ch, n, total):
    """(words, big) for every card: the title, each sentence, the way out"""
    cards = [(ch["title"], True)]
    for ln in ch["lines"]:
        cards += [(s, False) for s in sentences(ln)]
    return cards + [("To be continued..." if n < total else "The end. He is still out there.", True)]


def said(text):
    """what the narrator says for a card"""
    return text.replace("...", ".")


def voice_file(voice, text):
    """where a card's spoken sentence is (tools/video/voice.py makes them): the same words in the same voice, the same file"""
    key = hashlib.sha1(("%s|%.2f" % (said(text), VOICE_SPEED)).encode("utf-8")).hexdigest()[:12]
    return os.path.join(VOICE_DIR, voice, key + ".wav")


def wav_seconds(path):
    with wave.open(path, "rb") as w:
        return w.getnframes() / float(w.getframerate())


def timeline(ch, n, total, voice=None):
    """(words, big, seconds, spoken) for every card. Read: a card stays as long as reading it takes. Spoken (a voice): as long
    as the narrator takes to say it, and a breath"""
    cards = cards_of(ch, n, total)
    out = []
    for k, (text, big) in enumerate(cards):
        first, last, end = k == 0, k == len(cards) - 1, k == len(cards) - 2
        if voice:
            wav = voice_file(voice, text)
            sec = VOICE_AT + wav_seconds(wav)
            d = max(2.2, sec + 0.85) if first else (max(2.8, sec + 1.7) if last else max(1.4, sec + (1.0 if end else 0.4)))
            out.append((text, big, d, wav))
        else:
            d = 2.4 if first else (2.6 if last else max(1.7, 0.95 + 0.048 * len(text)) + (0.7 if end else 0.0))
            out.append((text, big, d, None))
    return out


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
    clip = moving(n)

    def picture(t):
        """the painting at that second: itself, or its animation (16 pictures a second, each melting into the next)"""
        if clip is None:
            return src, 1.0
        half = (len(clip) - 1) / CLIP_FPS                                 # seconds, one way
        u = (t / half) % 2.0
        pos = there_and_back(u if u <= 1.0 else 2.0 - u) * (len(clip) - 1)
        i0 = min(len(clip) - 2, int(pos))
        f = pos - i0
        mix = clip[i0].astype(np.float32) * (1.0 - f) + clip[i0 + 1].astype(np.float32) * f
        return Image.fromarray(mix.astype(np.uint8)), clip.shape[2] / sw

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
        pic, z = picture(t)
        fr.paste(pic.resize((BOX[2], BOX[3]), Image.LANCZOS, box=(x * z, y * z, (x + s) * z, (y + s) * z)), (BOX[0], BOX[1]))
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


def pcm(path, start=None, dur=None):
    """a sound file as 48 kHz stereo floats"""
    cut = ["-ss", "%.3f" % start, "-t", "%.3f" % dur] if start is not None else []
    raw = subprocess.run([FF, "-loglevel", "error"] + cut + ["-i", path, "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2)


def narrated(cards, ogg, a0, dur, out):
    """the page's sound with a narrator: each sentence as its card comes, and the music under it, a good deal quieter while
    somebody speaks. Written to out (a WAV)"""
    n = int(round(dur * SR))
    voice, talk = np.zeros((n, 2), np.float32), np.zeros(n, np.float32)
    t = 0.0
    for c in cards:
        v = pcm(c[3])
        i = int((t + VOICE_AT) * SR)
        j = min(n, i + len(v))
        voice[i:j] += v[:j - i]
        talk[max(0, i - int(0.3 * SR)):min(n, j + int(0.4 * SR))] = 1.0
        t += c[2]

    def level(x):
        return float(np.sqrt(np.mean(x * x))) + 1e-9
    voice *= 10.0 ** (-17.0 / 20.0) / level(voice[talk > 0])
    got = pcm(ogg, a0, dur)
    tune = np.zeros((n, 2), np.float32)
    tune[:min(n, len(got))] = got[:n]
    tune *= 10.0 ** (-23.0 / 20.0) / level(tune)
    k = int(0.35 * SR)                                              # the music dips and comes back over about a third of a second
    cs = np.cumsum(np.concatenate([[0.0], np.pad(talk, (k // 2, k - k // 2 - 1), mode="edge")]))
    duck = (cs[k:] - cs[:-k]) / k
    fade = np.ones(n, np.float32)
    fade[:int(0.5 * SR)] = np.linspace(0.0, 1.0, int(0.5 * SR))
    fade[-int(1.5 * SR):] = np.linspace(1.0, 0.0, int(1.5 * SR))
    mix = (voice + tune * ((1.0 - duck * (1.0 - 10.0 ** (-10.0 / 20.0))) * fade)[:, None]) * 0.5   # (6 dB of room: render's limiter
    with wave.open(out, "wb") as w:                                                                 #  gives them back without clipping)
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(mix, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())


def render(n, ch, cards, total, track, mp4):
    at, frames = scene(n, ch, cards, total)
    dur = frames / FPS
    ogg = os.path.join(ROOT, "assets", "audio", "music", track + ".ogg")
    a0, gain = music(ogg, dur)
    mixed = mp4 + ".wav" if cards[0][3] else None
    if mixed:                                                       # a narrator: the sound is mixed here
        narrated(cards, ogg, a0, dur, mixed)
        # (in floats: the volume filter on 16-bit sound clips before the limiter gets to it)
        sound, af = ["-i", mixed], ["-af", "aformat=sample_fmts=fltp,volume=6dB,alimiter=limit=0.84:attack=5:release=60:level=false"]
    else:
        sound = ["-ss", str(a0), "-t", "%.3f" % dur, "-i", ogg]
        af = ["-af", "volume=%.1fdB,alimiter=limit=0.84:level=false,afade=t=in:d=0.5,afade=t=out:st=%.3f:d=1.5" % (gain, max(0.0, dur - 1.5))]
    p = subprocess.Popen([FF, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H), "-r", str(FPS), "-i", "-"]
                         + sound + ["-map", "0:v", "-map", "1:a",
                                    "-vf", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p,setparams=color_primaries=bt709:color_trc=bt709"]
                         + af + ["-t", "%.3f" % dur, "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
                                 "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv",
                                 "-movflags", "+faststart", mp4], stdin=subprocess.PIPE)
    for i in range(frames):
        p.stdin.write(at(i).tobytes())
    p.stdin.close()
    if p.wait() != 0:
        sys.exit("ffmpeg failed on " + mp4)
    if mixed:
        os.remove(mixed)
    print("%s  %.1f s  %d cards  music from %d s%s" % (os.path.basename(mp4), dur, len(cards), a0,
                                                        ", narrated" if mixed else " (%+.1f dB)" % gain), flush=True)


def make(out, only, voice=None):
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, ".gdignore"), "a").close()
    chs, names = chapters(), titles()
    if voice:
        missing = [t for n, ch in enumerate(chs, 1) for t, _big in cards_of(ch, n, len(chs)) if not os.path.exists(voice_file(voice, t))]
        if missing:
            sys.exit("%d sentences have no %s narration yet: python tools/video/voice.py %s" % (len(missing), voice, voice))
    posts = []
    for n, ch in enumerate(chs, 1):
        cards, track = timeline(ch, n, len(chs), voice), track_of(ch["biome"])
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
    told = next((x.split("=", 1)[1] for x in arg if x.startswith("--voice=")), None)
    arg = [x for x in arg if not x.startswith("--voice=")]
    if not arg:
        sys.exit(__doc__)
    make(arg[0], [int(x) for x in arg[1].split(",")] if len(arg) > 1 else [], told)

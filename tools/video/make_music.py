#!/usr/bin/env python3
"""The game's soundtrack: Scott Buckley's library tracks (CC-BY 4.0, see CREDITS.md) -> assets/audio/music/*.ogg.
Takes the mp3s in scratch/downloads/music_buckley (https://www.scottbuckley.com.au/library/), brings them all to one
loudness (no limiter, no compression: only a gain, so the dynamics stay) and encodes them small.
   python tools/video/make_music.py"""
import os
import re
import subprocess

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "scratch", "downloads", "music_buckley")
OUT = os.path.join(ROOT, "assets", "audio", "music")
LOUDNESS = -18.0          # LUFS, under the sound effects
LONG_AMBIENT = 330.0      # seconds: long, slow pieces get the smaller quality (they hide it well)


def measure(path):
    log = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                         capture_output=True, text=True, errors="replace").stderr
    summary = log[log.rindex("Summary:"):]
    return float(re.search(r"I:\s+(-?[\d.]+) LUFS", summary).group(1))


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                         capture_output=True, text=True).stdout
    return float(out.strip())


def main():
    os.makedirs(OUT, exist_ok=True)
    total = 0
    for f in sorted(os.listdir(SRC)):
        if not f.endswith(".mp3"):
            continue
        src = os.path.join(SRC, f)
        dst = os.path.join(OUT, f[:-4] + ".ogg")
        gain = LOUDNESS - measure(src)
        q = "0" if duration(src) > LONG_AMBIENT else "1"
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-map_metadata", "-1", "-af", "volume=%.2fdB" % gain,
                        "-ar", "44100", "-c:a", "libvorbis", "-q:a", q, dst], check=True)
        total += os.path.getsize(dst)
        print("%-30s %+.1f dB  q%s  %.1f MB" % (f[:-4], gain, q, os.path.getsize(dst) / 1e6))
    print("total %.1f MB" % (total / 1e6))


if __name__ == "__main__":
    main()

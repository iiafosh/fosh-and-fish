"""Rehearse the in-game update before a release, on this PC, without touching the internet or GitHub.

    python tools/updater_rehearsal.py

It signs a dummy patch with the real update key, serves five manifests from a local port and runs the game's real
Updater (tests/updater_local_check.gd) against each one:
    good.json     a newer build with a patch for this install     -> "ready" (downloaded, sha256 and signature checked)
    badsig.json   the signature was tampered with                  -> "error" (not installed, nothing left behind)
    badsha.json   the file doesn't match its sha256                -> "error"
    old.json      nothing newer than this install                  -> "up_to_date"
    nopatch.json  newer, but no patch for this install             -> "full_needed" (download the full game)
If the key on this PC is not the one the game trusts (Updater.PUBLIC_KEY), the first line fails. Every run uses a
throwaway user folder, so your own save and patches are never touched.
"""
import functools
import http.server
import json
import os
import shutil
import subprocess
import sys
import tempfile
import threading

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GODOT = os.environ.get("GODOT", r"C:\Program Files\Godot\Godot_console.exe")
work = tempfile.mkdtemp(prefix="updater_site_")

pck = os.path.join(work, "p.pck")
with open(pck, "wb") as f:
    f.write(os.urandom(400_000))
out = subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "res://tools/update_sign.gd", "--", "--sign=" + pck],
                     capture_output=True, text=True, cwd=ROOT).stdout
lines = [l for l in out.splitlines() if l.startswith("SIGNED ")]
if not lines:
    sys.exit("signing failed - is the private key there? (tools/update_sign.gd --keygen)\n" + out[-300:])
_, sha, sig = lines[0].split(" ", 2)
sig = sig.strip()

class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args, **kwargs):
        pass


handler = functools.partial(Quiet, directory=work)
srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
port = srv.server_address[1]
threading.Thread(target=srv.serve_forever, daemon=True).start()
base = "http://127.0.0.1:%d" % port


def entry(sha_=sha, sig_=sig):
    e = {"url": base + "/p.pck", "size": os.path.getsize(pck), "sha256": sha_, "sig": sig_}
    return {"desktop": e, "android": e}


cur_build = str(json.load(open(os.path.join(ROOT, "data", "build.json")))["build"])


def manifest(name, **kw):
    m = {"version": "9.9", "build": 99, "base": int(cur_build), "notes": ["rehearsal"], "date": "2026-01-01",
         "full_url": "https://example.invalid/", "patches": {cur_build: entry()}}
    m.update(kw)
    with open(os.path.join(work, name), "w") as f:
        json.dump(m, f)


manifest("good.json")
manifest("badsig.json", patches={cur_build: entry(sig_=sig[:-8] + ("AAAAAAAA" if not sig.endswith("AAAAAAAA") else "BBBBBBBB"))})
manifest("badsha.json", patches={cur_build: entry(sha_="0" * 64)})
manifest("old.json", build=int(cur_build), version="old")
manifest("nopatch.json", patches={})

cases = [("good.json", "ready"), ("badsig.json", "error"), ("badsha.json", "error"),
         ("old.json", "up_to_date"), ("nopatch.json", "full_needed")]
ok_all = True
for name, want in cases:
    appdata = tempfile.mkdtemp(prefix="updater_user_")
    env = dict(os.environ, APPDATA=appdata)
    r = subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "res://tests/updater_local_check.gd", "--",
                        "--update-url=%s/%s" % (base, name)], capture_output=True, text=True, cwd=ROOT, env=env, timeout=180)
    line = next((l for l in r.stdout.splitlines() if l.startswith("UPDATER ")), "NO OUTPUT: " + r.stdout[-300:] + r.stderr[-300:])
    good = ("state=%s " % want) in line
    if name == "good.json":
        good = good and "patch_file=true" in line and "installed_json=true" in line
    elif want == "error":
        good = good and "patch_file=false" in line and "leftover_part=false" in line
    ok_all = ok_all and good
    print(("ok   " if good else "FAIL ") + name.ljust(13) + line)
    shutil.rmtree(appdata, ignore_errors=True)
srv.shutdown()
shutil.rmtree(work, ignore_errors=True)
print("ALL OK" if ok_all else "SOMETHING FAILED")
sys.exit(0 if ok_all else 1)

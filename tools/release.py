"""Publish fosh&fish releases.

FULL release (players download new files once; becomes the new base for patches):
    python tools/release.py full 0.5 -n "Sailing between biomes" -n "FishTok" --publish
Installs of the previous full release also get it as an in-game update (a patch against the old
base), unless --no-old-patch (needed when the release adds autoloads, class_name scripts or project
settings). Releasing a version that already has a release (e.g. rolling 0.5.1-0.5.14 into a fresh
"0.5") replaces its downloads, keeps its other files (trailers) and moves its tag here.

PATCH (an in-game update: players press "Update now"; only changed files are sent):
    python tools/release.py patch 0.5.1 -n "Faster early levels" --publish

Without --publish everything is built and signed locally (build/release, build/patches) and
nothing is uploaded. --local URL writes a test manifest whose download links point at URL.

GOOGLE PLAY (the .aab you upload in Play Console; set up once with docs/PLAY_STORE.md):
    python tools/release.py play
builds build/play/fosh_fish-<version>-b<build>.aab from the "Android Play" preset (Gradle build with the
billing and AdMob plugins, export feature "play"), signed with your upload key from the environment.

Needs: Godot 4.7 (env GODOT), gh CLI, the update signing key (tools/update_sign.gd --keygen).
Patches can't add autoloads, class_name scripts or project settings: use a full release.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import time
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GODOT = os.environ.get("GODOT", r"C:\Program Files\Godot\Godot_console.exe")
REPO = "iiafosh/fosh-and-fish"
PAGES_BRANCH = "gh-pages"
BUILD_JSON = os.path.join(ROOT, "data", "build.json")
STATE = os.path.join(ROOT, "tools", "update.json")          # the published manifest, kept in git
B = os.path.join(ROOT, "build")
SITE = os.path.join(ROOT, "site")         # the website (foshfish.xyz)
DOCS = ["GUIDE.md", "CHANGELOG.md", "CREDITS.md"]
PLATFORMS = {"desktop": "Windows Desktop", "android": "Android"}
PLAY_PRESET = "Android Play"
PLAY_NEEDS = ["android/build/build.gradle", "addons/GodotGooglePlayBilling", "addons/admob"]
KEY_VARS = ["GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"]


def run(cmd, **kw):
    print("  $", " ".join(cmd) if isinstance(cmd, list) else cmd, flush=True)
    return subprocess.run(cmd, check=True, cwd=ROOT, **kw)


def godot(*args):
    run([GODOT, "--headless", "--path", ROOT, *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def load(path, default):
    return json.load(open(path, encoding="utf-8")) if os.path.exists(path) else default


def save(path, data):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def sign(path):
    out = subprocess.run([GODOT, "--headless", "--path", ROOT, "-s", "res://tools/update_sign.gd", "--", f"--sign={path}"],
                         capture_output=True, text=True, cwd=ROOT).stdout
    for line in out.splitlines():
        if line.startswith("SIGNED "):
            _, sha, sig = line.split(" ", 2)
            return sha, sig.strip()
    sys.exit("signing failed - is the private key there? (tools/update_sign.gd --keygen)")


def stamp_presets(version, build):
    """Write the version into export_presets.cfg (Android versionCode/Name, Windows file version)."""
    p = os.path.join(ROOT, "export_presets.cfg")
    t = open(p, encoding="utf-8").read()
    nums = [int(x) for x in version.split("-")[0].split(".")[:3]] + [0, 0, 0]
    win = "%d.%d.%d.%d" % (nums[0], nums[1], nums[2], build)
    import re
    t = re.sub(r'(?m)^version/code=\d+', "version/code=%d" % build, t)
    t = re.sub(r'(?m)^version/name=".*"', 'version/name="%s"' % version, t)
    t = re.sub(r'(?m)^application/file_version=".*"', 'application/file_version="%s"' % win, t)
    t = re.sub(r'(?m)^application/product_version=".*"', 'application/product_version="%s"' % win, t)
    open(p, "w", encoding="utf-8", newline="\n").write(t)


def export_games(version):
    for d in ["web", "windows", "linux", "android"]:
        shutil.rmtree(os.path.join(B, d), ignore_errors=True)
        os.makedirs(os.path.join(B, d), exist_ok=True)
    godot("--export-release", "Web", "build/web/index.html")
    godot("--export-release", "Windows Desktop", "build/windows/fosh_fish.exe")
    godot("--export-release", "Linux", "build/linux/fosh_fish.x86_64")
    godot("--export-debug", "Android", "build/android/fosh_fish.apk")
    out = os.path.join(B, "release")
    os.makedirs(out, exist_ok=True)
    lic = os.path.join(ROOT, "assets", "third_party", "fonts", "OFL.txt")
    name = f"fosh_fish-{version}"
    files = []
    p = os.path.join(out, f"{name}-windows.zip")
    with zipfile.ZipFile(p, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(os.path.join(B, "windows", "fosh_fish.exe"), "fosh_fish/fosh_fish.exe")
        for d in DOCS: z.write(os.path.join(ROOT, d), "fosh_fish/" + d)
        z.write(lic, "fosh_fish/licenses/Fredoka-OFL.txt")
    files.append(p)
    p = os.path.join(out, f"{name}-linux.tar.gz")
    with tarfile.open(p, "w:gz") as t:
        ti = t.gettarinfo(os.path.join(B, "linux", "fosh_fish.x86_64"), "fosh_fish/fosh_fish.x86_64")
        ti.mode = 0o755
        with open(os.path.join(B, "linux", "fosh_fish.x86_64"), "rb") as fh:
            t.addfile(ti, fh)
        for d in DOCS: t.add(os.path.join(ROOT, d), "fosh_fish/" + d)
        t.add(lic, "fosh_fish/licenses/Fredoka-OFL.txt")
    files.append(p)
    p = os.path.join(out, f"{name}-web.zip")
    with zipfile.ZipFile(p, "w", zipfile.ZIP_DEFLATED) as z:
        for f in os.listdir(os.path.join(B, "web")):
            z.write(os.path.join(B, "web", f), f)
    files.append(p)
    p = os.path.join(out, f"{name}-android.apk")
    shutil.copy(os.path.join(B, "android", "fosh_fish.apk"), p)
    files.append(p)
    return files


def play_bundle():
    """The Google Play .aab for the version in data/build.json (a full release stamps it first)."""
    missing = [p for p in PLAY_NEEDS if not os.path.exists(os.path.join(ROOT, p))]
    if missing:
        sys.exit("not set up for Google Play yet (missing %s): see docs/PLAY_STORE.md" % ", ".join(missing))
    unset = [k for k in KEY_VARS if not os.environ.get(k)]
    if unset:
        sys.exit("set your upload key first (%s): see docs/PLAY_STORE.md" % ", ".join(unset))
    bj = load(BUILD_JSON, {})
    stamp_presets(bj["version"], int(bj["build"]))
    godot("--import")
    os.makedirs(os.path.join(B, "play"), exist_ok=True)
    out = os.path.join(B, "play", f"fosh_fish-{bj['version']}-b{bj['build']}.aab")
    # (output shown: the first Gradle build downloads its tools, and its errors are worth reading)
    run([GODOT, "--headless", "--path", ROOT, "--export-release", PLAY_PRESET, os.path.relpath(out, ROOT)])
    if not os.path.exists(out):
        sys.exit("no .aab was made: read the Gradle output above")
    print(f"Google Play bundle: {out} ({os.path.getsize(out) / 1048576:.1f} MB) - upload it in Play Console "
          f"(Testing -> Internal testing first). versionCode {bj['build']}, versionName {bj['version']}.")


def build_patches(version, base, build, url_base):
    """Signed patch .pcks (desktop, android) that turn an install of full release `base` into this build."""
    base_dir = os.path.join(B, "base", f"b{base}")
    if not all(os.path.exists(os.path.join(base_dir, f"{p}.pck")) for p in PLATFORMS):
        os.makedirs(base_dir, exist_ok=True)
        run(["gh", "release", "download", f"dev-base-b{base}", "-R", REPO, "-D", base_dir, "--clobber"])
    out = os.path.join(B, "patches", f"b{build}")
    os.makedirs(out, exist_ok=True)
    entry, files = {}, []
    for plat, preset in PLATFORMS.items():
        name = f"fosh_fish-{version}-patch-{plat}.pck"
        path = os.path.join(out, name)
        godot("--export-patch", preset, os.path.relpath(path, ROOT), "--patches", os.path.join(base_dir, f"{plat}.pck"))
        sha, sig = sign(path)
        entry[plat] = {"url": url_base.rstrip("/") + "/" + name, "size": os.path.getsize(path), "sha256": sha, "sig": sig}
        files.append(path)
        print(f"  {plat} (from b{base}): {os.path.getsize(path) / 1048576:.2f} MB")
    return entry, files


def release_exists(tag):
    return subprocess.run(["gh", "release", "view", tag, "-R", REPO], cwd=ROOT, capture_output=True).returncode == 0


SITE_DOMAIN = "foshfish.xyz"
GAME_FILE = re.compile(r"^index\.")     # the web export's files: index.html, .js, .wasm, .pck, icons, worker, ...


def deploy_pages(manifest_path=None, web=True, live=None):
    """The gh-pages branch. Two layouts:
      preview (no CNAME yet): the web game at the root, the website (site/) at /site/
      live (CNAME = foshfish.xyz): the website at the root, the web game at /play/
    update.json always stays at the root: installed games look for it there (the old github.io URL
    redirects to the domain once it is live). live=True switches to the live layout, None keeps the
    current one."""
    wt = os.path.join(B, "_pages")
    shutil.rmtree(wt, ignore_errors=True)
    run(["git", "worktree", "prune"])
    run(["git", "fetch", "-q", "origin", PAGES_BRANCH])
    run(["git", "worktree", "add", "-q", wt, f"origin/{PAGES_BRANCH}"])
    try:
        was_live = os.path.exists(os.path.join(wt, "CNAME"))
        live = was_live if live is None else live
        game_dir = os.path.join(wt, "play") if live else wt
        os.makedirs(game_dir, exist_ok=True)
        if live and not was_live:
            # moving to the domain: the game's files go from the root to /play/
            for f in os.listdir(wt):
                if GAME_FILE.match(f):
                    shutil.move(os.path.join(wt, f), os.path.join(game_dir, f))
            shutil.rmtree(os.path.join(wt, "site"), ignore_errors=True)
            with open(os.path.join(wt, "CNAME"), "w") as fh:
                fh.write(SITE_DOMAIN + "\n")
        if web and os.path.isdir(os.path.join(B, "web")):
            for f in os.listdir(os.path.join(B, "web")):
                shutil.copy(os.path.join(B, "web", f), os.path.join(game_dir, f))
        site_dst = wt if live else os.path.join(wt, "site")
        for base, _, files in os.walk(SITE):
            rel = os.path.relpath(base, SITE)
            os.makedirs(os.path.join(site_dst, rel), exist_ok=True)
            for f in files:
                if f != ".gdignore":
                    shutil.copy(os.path.join(base, f), os.path.join(site_dst, rel, f))
        if manifest_path:
            shutil.copy(manifest_path, os.path.join(wt, "update.json"))
        open(os.path.join(wt, ".nojekyll"), "w").close()
        subprocess.run(["git", "add", "-A"], cwd=wt, check=True)
        if subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=wt).returncode != 0:
            what = ("publish " + json.load(open(manifest_path))["version"]) if manifest_path else "website"
            subprocess.run(["git", "commit", "-qm", what + (" (live: %s)" % SITE_DOMAIN if live else "")], cwd=wt, check=True)
            subprocess.run(["git", "push", "-q", "origin", f"HEAD:{PAGES_BRANCH}"], cwd=wt, check=True)
        print("pages:", ("live at https://%s/ (game at /play/)" % SITE_DOMAIN) if live else "preview at https://%s.github.io/%s/site/" % tuple(REPO.split("/")))
    finally:
        run(["git", "worktree", "remove", "--force", wt])


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "site":
        # python tools/release.py site [--live]: only the website (site/); --live moves to foshfish.xyz
        deploy_pages(None, web=False, live=True if "--live" in sys.argv else None)
        return
    if len(sys.argv) > 1 and sys.argv[1] == "play":
        play_bundle()
        return
    ap = argparse.ArgumentParser()
    ap.add_argument("kind", choices=["full", "patch"])
    ap.add_argument("version")
    ap.add_argument("-n", "--note", action="append", default=[], help="a line for 'What's new' (repeat)")
    ap.add_argument("--publish", action="store_true")
    ap.add_argument("--local", help="test manifest: download links point at this base URL")
    ap.add_argument("--no-old-patch", action="store_true", help="full: no in-game update for installs of the previous full release")
    a = ap.parse_args()

    manifest = load(STATE, {"build": 1, "version": "0.1.0", "base": 1, "patches": {}})
    prev_build_json = load(BUILD_JSON, {})
    build = int(manifest["build"]) + 1
    tag = f"v{a.version}"
    save(BUILD_JSON, {"version": a.version, "build": build})
    print(f"== {a.kind} release {a.version} (build {build})")
    godot("--import")

    assets = []           # files for the player-facing release
    dev_assets = []       # files for the "dev base" pre-release (full releases)
    if a.kind == "full":
        old_base = int(manifest["base"])
        stamp_presets(a.version, build)
        assets = export_games(a.version)
        base_dir = os.path.join(B, "base", f"b{build}")
        os.makedirs(base_dir, exist_ok=True)
        for plat, preset in PLATFORMS.items():
            godot("--export-pack", preset, os.path.relpath(os.path.join(base_dir, f"{plat}.pck"), ROOT))
        dev_assets = [os.path.join(base_dir, f"{p}.pck") for p in PLATFORMS]
        patches = {}
        if not a.no_old_patch and old_base != build:
            # players on the previous full release update in-game; the patch files sit with the dev base files
            entry, files = build_patches(a.version, old_base, build,
                                         a.local or f"https://github.com/{REPO}/releases/download/dev-base-b{build}")
            patches[str(old_base)] = entry
            dev_assets += files
        manifest = {"version": a.version, "build": build, "base": build, "notes": a.note,
                    "date": time.strftime("%Y-%m-%d"), "full_url": f"https://github.com/{REPO}/releases/latest",
                    "patches": patches}
    else:
        base = int(manifest["base"])
        entry, assets = build_patches(a.version, base, build, a.local or f"https://github.com/{REPO}/releases/download/{tag}")
        shutil.rmtree(os.path.join(B, "web"), ignore_errors=True)
        os.makedirs(os.path.join(B, "web"))
        godot("--export-release", "Web", "build/web/index.html")
        manifest.update({"version": a.version, "build": build, "notes": a.note, "date": time.strftime("%Y-%m-%d"),
                         "patches": {str(base): entry}})

    if a.local:
        test = os.path.join(B, "patches", "update.json")
        save(test, manifest)
        print("test manifest:", test)
        return
    if not a.publish:
        # a dry run must not move the published build number forward
        preview = os.path.join(B, "update.preview.json")
        save(preview, manifest)
        save(BUILD_JSON, prev_build_json)
        print("built only (nothing published, version files untouched) - preview manifest:", preview)
        return
    save(STATE, manifest)
    print("manifest saved:", STATE)
    notes = "\n".join("- " + n for n in a.note) or "See CHANGELOG.md"
    relaunch = False
    if a.kind == "full":
        relaunch = release_exists(tag)
        if relaunch:
            # this version already has a release: new downloads (same file names), its other files stay
            run(["gh", "release", "upload", tag, *assets, "-R", REPO, "--clobber"])
            run(["gh", "release", "edit", tag, "-R", REPO, "--title", f"fosh&fish {a.version}", "--notes", notes,
                 "--prerelease=false", "--latest"])
        else:
            run(["gh", "release", "create", tag, *assets, "-R", REPO, "--title", f"fosh&fish {a.version}", "--notes", notes])
    else:
        # an in-game update: players get it from Menu -> Updates. Keep "latest" pointing at the full download.
        notes += ("\n\n**How to get it:** open the game and press *Update now* (Menu -> Updates). "
                  "New players: download the latest full release.")
        run(["gh", "release", "create", tag, *assets, "-R", REPO, "--title", f"fosh&fish {a.version} (in-game update)",
             "--notes", notes, "--latest=false"])
    if a.kind == "full":
        run(["gh", "release", "create", f"dev-base-b{build}", *dev_assets,
             "-R", REPO, "--prerelease", "--latest=false", "--title", f"dev base b{build} (not for players)",
             "--notes", "Developer files: the base .pck files in-game update patches are built against, and the "
                        "in-game update for installs of the previous full release. Players: download the latest fosh&fish release instead."])
    deploy_pages(STATE)
    run(["git", "add", BUILD_JSON, STATE, os.path.join(ROOT, "export_presets.cfg")])
    run(["git", "commit", "-qm", f"release {a.version} (build {build})"])
    run(["git", "push", "-q", "origin", "HEAD"])
    if relaunch:
        # the release's tag (and its "Source code" downloads) now point at this release commit
        run(["git", "tag", "-f", tag])
        run(["git", "push", "-q", "-f", "origin", f"refs/tags/{tag}"])
    print("published", tag)


if __name__ == "__main__":
    main()

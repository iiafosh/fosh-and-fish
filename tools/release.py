"""Publish fosh&fish releases.

FULL release (players download new files once; becomes the new base for patches):
    python tools/release.py full 0.5 -n "Sailing between biomes" -n "FishTok" --publish

PATCH (an in-game update: players press "Update now"; only changed files are sent):
    python tools/release.py patch 0.5.1 -n "Faster early levels" --publish

Without --publish everything is built and signed locally (build/release, build/patches) and
nothing is uploaded. --local URL writes a test manifest whose download links point at URL.

Needs: Godot 4.7 (env GODOT), gh CLI, the update signing key (tools/update_sign.gd --keygen).
Patches can't add autoloads, class_name scripts or project settings: use a full release.
"""
import argparse
import json
import os
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
DOCS = ["GUIDE.md", "CHANGELOG.md", "CREDITS.md"]
PLATFORMS = {"desktop": "Windows Desktop", "android": "Android"}


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


def deploy_pages(manifest_path):
    """Put the web build and update.json on the gh-pages branch."""
    wt = os.path.join(B, "_pages")
    shutil.rmtree(wt, ignore_errors=True)
    run(["git", "worktree", "prune"])
    run(["git", "fetch", "-q", "origin", PAGES_BRANCH])
    run(["git", "worktree", "add", "-q", wt, f"origin/{PAGES_BRANCH}"])
    try:
        for f in os.listdir(os.path.join(B, "web")):
            shutil.copy(os.path.join(B, "web", f), os.path.join(wt, f))
        shutil.copy(manifest_path, os.path.join(wt, "update.json"))
        open(os.path.join(wt, ".nojekyll"), "w").close()
        subprocess.run(["git", "add", "-A"], cwd=wt, check=True)
        if subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=wt).returncode != 0:
            subprocess.run(["git", "commit", "-qm", "publish " + json.load(open(manifest_path))["version"]], cwd=wt, check=True)
            subprocess.run(["git", "push", "-q", "origin", f"HEAD:{PAGES_BRANCH}"], cwd=wt, check=True)
    finally:
        run(["git", "worktree", "remove", "--force", wt])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("kind", choices=["full", "patch"])
    ap.add_argument("version")
    ap.add_argument("-n", "--note", action="append", default=[], help="a line for 'What's new' (repeat)")
    ap.add_argument("--publish", action="store_true")
    ap.add_argument("--local", help="test manifest: download links point at this base URL")
    a = ap.parse_args()

    manifest = load(STATE, {"build": 1, "version": "0.1.0", "base": 1, "patches": {}})
    prev_build_json = load(BUILD_JSON, {})
    build = int(manifest["build"]) + 1
    tag = f"v{a.version}"
    save(BUILD_JSON, {"version": a.version, "build": build})
    print(f"== {a.kind} release {a.version} (build {build})")
    godot("--import")

    assets = []
    if a.kind == "full":
        stamp_presets(a.version, build)
        assets = export_games(a.version)
        base_dir = os.path.join(B, "base", f"b{build}")
        os.makedirs(base_dir, exist_ok=True)
        for plat, preset in PLATFORMS.items():
            godot("--export-pack", preset, os.path.relpath(os.path.join(base_dir, f"{plat}.pck"), ROOT))
        manifest = {"version": a.version, "build": build, "base": build, "notes": a.note,
                    "date": time.strftime("%Y-%m-%d"), "full_url": f"https://github.com/{REPO}/releases/latest",
                    "patches": {}}
    else:
        base = int(manifest["base"])
        base_dir = os.path.join(B, "base", f"b{base}")
        if not all(os.path.exists(os.path.join(base_dir, f"{p}.pck")) for p in PLATFORMS):
            os.makedirs(base_dir, exist_ok=True)
            run(["gh", "release", "download", f"dev-base-b{base}", "-R", REPO, "-D", base_dir, "--clobber"])
        out = os.path.join(B, "patches", f"b{build}")
        os.makedirs(out, exist_ok=True)
        entry = {}
        for plat, preset in PLATFORMS.items():
            name = f"fosh_fish-{a.version}-patch-{plat}.pck"
            path = os.path.join(out, name)
            godot("--export-patch", preset, os.path.relpath(path, ROOT), "--patches", os.path.join(base_dir, f"{plat}.pck"))
            sha, sig = sign(path)
            url = (a.local.rstrip("/") + "/" + name) if a.local else f"https://github.com/{REPO}/releases/download/{tag}/{name}"
            entry[plat] = {"url": url, "size": os.path.getsize(path), "sha256": sha, "sig": sig}
            assets.append(path)
            print(f"  {plat}: {os.path.getsize(path) / 1048576:.2f} MB")
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
    run(["gh", "release", "create", tag, *assets, "-R", REPO, "--title", f"fosh&fish {a.version}", "--notes", notes])
    if a.kind == "full":
        run(["gh", "release", "create", f"dev-base-b{build}", *[os.path.join(base_dir, f"{p}.pck") for p in PLATFORMS],
             "-R", REPO, "--prerelease", "--title", f"dev base b{build} (not for players)",
             "--notes", "Developer files used to build in-game update patches. Players: download the latest fosh&fish release instead."])
    deploy_pages(STATE)
    run(["git", "add", BUILD_JSON, STATE, os.path.join(ROOT, "export_presets.cfg")])
    run(["git", "commit", "-qm", f"release {a.version} (build {build})"])
    run(["git", "push", "-q", "origin", "HEAD"])
    print("published", tag)


if __name__ == "__main__":
    main()

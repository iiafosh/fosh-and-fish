extends Node
## In-game updates (autoload "Updater", listed FIRST so it runs before anything else loads).
##
## A release is either FULL (players download new files once) or a PATCH: a .pck with only
## the files that changed since the full release ("base") the player installed. Patches are
## listed in update.json on the website, downloaded from GitHub Releases, checked against a
## SHA-256 and an RSA signature made with the private key that only the developer has, then
## loaded at the next start. If a patched start never reaches the main menu, the next start
## runs the base game instead. The web build always serves the newest version: just reload.
##
## Limits of patches: no new autoloads, no new class_name scripts, no project setting or
## engine changes. Those need a full release. Tooling: tools/release.py.

signal status_changed

const MANIFEST_URL := "https://iiafosh.github.io/fosh-and-fish/update.json"
const RELEASES_URL := "https://github.com/iiafosh/fosh-and-fish/releases/latest"
const BUILD_FILE := "res://data/build.json"
const DIR := "user://patches/"
const STATE := DIR + "installed.json"
const BOOT_FLAG := DIR + "booting"
const PUBLIC_KEY := """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5OJtGC+i6sxm9eTMvGAn
CZ9H5nTW68/idlrKpslJy43k9NCxPAxDqz9E5Xy93FxkoMsHPjuw94fVMzj/uBqL
ZGsUd6V4LcNPX8y/0/FsfxGG/q2VSjoxfmUOu4NnMZ82iA7WlF5kcd3+8R31FNEB
AiCbfMQ8RqD8XxdsM0sFrrnzG2c9Q8IDWY/wVFPQnK616lW93SuUxnyHKPsqlzkr
/KeQWjJKppwYQoKd3H3vEcQ3Q6AChURYQHt8wCxLCrapVUsZCG9kZXztXOCNWEJM
+2hlkqWdPDNZUnFzIS/cEkKOac3XxA5sTAYMUHkpAkoU/jy1QjoS6q8mu6Up5UwJ
gwIDAQAB
-----END PUBLIC KEY-----"""

var base_build := 0            # the full release this install came from
var version := "?"             # what's running now (base or patched)
var build := 0
var patch_loaded := false
var skipped_patch := ""        # a patch that failed to start last time (we ran the base game)

## idle | checking | up_to_date | available | full_needed | downloading | ready | error
var state := "idle"
var latest := {}               # parsed update.json
var progress := 0.0            # 0..1 while downloading
var error := ""
var _http: HTTPRequest
var _part := ""
var _size := 0

func _init() -> void:
	var b := _read_json(BUILD_FILE)
	base_build = int(b.get("build", 0))
	version = String(b.get("version", "?"))
	build = base_build
	if OS.has_feature("web") or OS.has_feature("editor"):
		return
	var st := _read_json(STATE)
	if st.is_empty():
		return
	if int(st.get("base", -1)) != base_build:
		_wipe()                                    # a newer full install replaced the old base
		return
	var file := DIR + String(st.get("file", ""))
	if st.get("bad", false) or not FileAccess.file_exists(file):
		return
	if FileAccess.file_exists(BOOT_FLAG):
		# the last start with this patch never reached the game: run the base game this time
		skipped_patch = String(st.get("version", "?"))
		st["bad"] = true
		_write_json(STATE, st)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BOOT_FLAG))
		return
	_write_text(BOOT_FLAG, "1")
	if ProjectSettings.load_resource_pack(file, true):
		patch_loaded = true
		var pb := _read_json(BUILD_FILE)           # the patch carries its own build.json
		version = String(pb.get("version", version))
		build = int(pb.get("build", build))

## The main scene calls this once it's up: the patch works, keep it.
func boot_ok() -> void:
	if FileAccess.file_exists(BOOT_FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BOOT_FLAG))
	_cleanup_old_patches()

func platform() -> String:
	if OS.has_feature("web"): return "web"
	if OS.has_feature("android"): return "android"
	return "desktop"

func manifest_url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--update-url="): return a.substr(13)
	return MANIFEST_URL

# ------------------------------------------------------------------ check
func check() -> void:
	if state in ["checking", "downloading", "ready"]: return
	_set_state("checking")
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_manifest, CONNECT_ONE_SHOT)
	var url := manifest_url()
	url += ("&" if "?" in url else "?") + "t=%d" % int(Time.get_unix_time_from_system())
	if _http.request(url) != OK:
		_fail("Can't reach the update server.")

func _on_manifest(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("Can't reach the update server (check your internet).")
		return
	var m = JSON.parse_string(body.get_string_from_utf8())
	if typeof(m) != TYPE_DICTIONARY:
		_fail("The update info looks broken. Try again later.")
		return
	latest = m
	if int(m.get("build", 0)) <= build:
		_set_state("up_to_date")
	elif platform() == "web":
		_set_state("available")
	elif patch_info().is_empty():
		_set_state("full_needed")
	else:
		_set_state("available")

## the patch for this install (made against our base), or {} if there isn't one
func patch_info() -> Dictionary:
	return latest.get("patches", {}).get(str(base_build), {}).get(platform(), {})

func notes() -> Array:
	var n = latest.get("notes", [])
	return n if n is Array else [str(n)]

# --------------------------------------------------------------- download
func download() -> void:
	if state != "available": return
	if platform() == "web":
		JavaScriptBridge.eval("location.reload()")
		return
	var p := patch_info()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_part = DIR + "patch_b%d.pck.part" % int(latest.build)
	_size = int(p.get("size", 0))
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.download_file = _part
	add_child(_http)
	_http.request_completed.connect(_on_download, CONNECT_ONE_SHOT)
	progress = 0.0
	_set_state("downloading")
	if _http.request(String(p.url)) != OK:
		_fail("Couldn't start the download.")

func _process(_delta: float) -> void:
	if state == "downloading" and is_instance_valid(_http) and _size > 0:
		var p := clampf(float(_http.get_downloaded_bytes()) / _size, 0.0, 1.0)
		if absf(p - progress) > 0.01:
			progress = p
			status_changed.emit()

func _on_download(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_remove(_part)
		_fail("The download stopped. Check your internet and try again.")
		return
	var p := patch_info()
	var sha := FileAccess.get_sha256(_part)
	if sha != String(p.get("sha256", "")):
		_remove(_part)
		_fail("The download was damaged. Please try again.")
		return
	if not signature_ok(sha, String(p.get("sig", ""))):
		_remove(_part)
		_fail("This update isn't signed by afosh, so it was not installed.")
		return
	var fname := "patch_b%d.pck" % int(latest.build)
	_remove(DIR + fname)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(_part), ProjectSettings.globalize_path(DIR + fname))
	_write_json(STATE, {"base": base_build, "build": int(latest.build), "version": String(latest.get("version", "")),
		"file": fname, "installed": Time.get_datetime_string_from_system()})
	progress = 1.0
	_set_state("ready")

func signature_ok(sha_hex: String, sig_b64: String) -> bool:
	if sha_hex.length() != 64 or sig_b64 == "": return false
	var key := CryptoKey.new()
	if key.load_from_string(PUBLIC_KEY, true) != OK: return false
	return Crypto.new().verify(HashingContext.HASH_SHA256, sha_hex.hex_decode(), Marshalls.base64_to_raw(sig_b64), key)

## Restart into the new version (desktop restarts itself; on phones the player reopens the app).
func restart() -> void:
	var vf := get_node_or_null("/root/VF")
	if vf and vf.autosave: vf.save_game()
	if platform() == "desktop":
		var args := OS.get_cmdline_args()
		if not OS.get_cmdline_user_args().is_empty():
			args.append("--")
			args.append_array(OS.get_cmdline_user_args())
		OS.set_restart_on_exit(true, args)
	get_tree().quit()

func open_downloads() -> void:
	OS.shell_open(RELEASES_URL)

# ---------------------------------------------------------------- helpers
func _set_state(s: String) -> void:
	state = s
	if s != "error": error = ""
	status_changed.emit()

func _fail(msg: String) -> void:
	error = msg
	_set_state("error")
	error = msg

func _cleanup_old_patches() -> void:
	var keep := String(_read_json(STATE).get("file", ""))
	var d := DirAccess.open(DIR)
	if d == null: return
	for f in d.get_files():
		if f.ends_with(".pck") and f != keep:
			d.remove(f)

func _wipe() -> void:
	var d := DirAccess.open(DIR)
	if d == null: return
	for f in d.get_files():
		d.remove(f)

func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Dictionary else {}

func _write_json(path: String, d: Dictionary) -> void:
	_write_text(path, JSON.stringify(d, "  "))

func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f: f.store_string(text)

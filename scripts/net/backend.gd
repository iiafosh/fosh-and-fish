extends Node
## Online accounts, cloud saves and the leaderboard (autoload "Backend", listed after Updater and VF).
##
## Talks to a Supabase project with plain HTTPRequest calls, so it works in the web build too:
##   auth  (GoTrue)    <url>/auth/v1/...   sign up, sign in, refresh, sign out, password-reset codes
##   data  (PostgREST) <url>/rest/v1/...   saves (one row per player), profiles, leaderboard (view)
## Database + security rules: supabase/schema.sql. Owner setup: docs/BACKEND.md.
## Not configured (data/backend.json has no url/key) = offline mode: the game never goes online.
## Local testing: python tools/mock_supabase.py, then run the game with
##   -- --backend-url=http://127.0.0.1:54321 --backend-key=test
##
## The game stays client-authoritative: the save is VF.to_dict() and the cloud keeps a copy.
## The password is never stored; the refresh token lives in user://account.cfg. Tokens are never printed.

signal status_changed           # anything the account panel shows changed
signal leaderboard_changed
signal conflict_found           # this device and the cloud have different progress: the player picks one
signal _refresh_done(ok: bool)

const CONFIG_FILE := "res://data/backend.json"
const ACCOUNT_FILE := "user://account.cfg"
const TEST_ACCOUNT_FILE := "user://account_test.cfg"   # capture/test runs never touch the real session
const RECORDING_FLAGS := ["--trailer", "--reel", "--reel05", "--reelyt"]   # video recordings count as captures
const SYNC_EVERY := 60.0        # seconds between automatic uploads (only when progress changed)
const RETRY_EVERY := 60.0       # offline with a saved session: try to reconnect this often
const TIMEOUT := 15.0
const NAME_MIN := 3
const NAME_MAX := 20
const PASSWORD_MIN := 6
const LEADERBOARD_SIZE := 50
const SAVE_VERSION := 1         # must match VF.SAVE_VERSION
const GET := HTTPClient.METHOD_GET
const POST := HTTPClient.METHOD_POST
const PATCH := HTTPClient.METHOD_PATCH
const PUT := HTTPClient.METHOD_PUT

var url := ""
var anon_key := ""
var account_file := ACCOUNT_FILE

## disabled | signed_out | busy | signed_in | offline
var state := "disabled"
var op := ""                    # what "busy" is doing: sign_in, sign_up, restore, sign_out, recover, reset, delete
var message := ""               # the last friendly status line for the panel
var message_kind := ""          # error | info | good
var reset_sent_to := ""         # after "forgot password": where the code went
var need_new_password := false  # web: arrived from a password-reset email link
var renaming := false

var user_id := ""
var email := ""
var display_name := ""

## cloud save
var sync_state := ""            # "" | syncing | ok | error | conflict
var sync_error := ""
var last_sync := 0.0            # unix time of the last successful upload / download
var conflict := {}              # {"cloud": summary, "local": summary, "data": cloud save}
var dirty := false              # progress changed since the last upload

var leaderboard: Array = []
var lb_state := ""              # "" | loading | ok | error
var lb_error := ""
var lb_time := 0.0

var _access := ""
var _refresh_token := ""
var _expires := 0.0
var _refreshing := false
var _since_sync := 0.0
var _since_retry := 0.0
var _quitting := false
var _applying := false
var _uploading := false
var _synced_fp := ""            # fingerprint of the save this device last uploaded / downloaded
var _synced_at := ""            # the cloud row's updated_at at that moment

# ------------------------------------------------------------------ setup
func _ready() -> void:
	_load_config()
	if not configured():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vf = _vf()
	if vf: vf.changed.connect(_on_vf_changed)
	_load_account()
	_set_state("signed_out")
	if _web_link():
		return
	if _refresh_token != "":
		restore_session.call_deferred()

func configured() -> bool:
	return url != "" and anon_key != ""

func _load_config() -> void:
	var cfg := parse_config(_read_json(CONFIG_FILE))
	url = cfg.url
	anon_key = cfg.anon_key
	var capturing := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--backend-url="): url = clean_url(a.substr(14))
		elif a.begins_with("--backend-key="): anon_key = a.substr(14).strip_edges()
		elif a.begins_with("--account-file="): account_file = a.substr(15)
		elif a.begins_with("--capture=") or a in RECORDING_FLAGS: capturing = true
	if capturing and account_file == ACCOUNT_FILE:
		account_file = TEST_ACCOUNT_FILE

func _vf():                     # untyped: VF's own methods (to_dict, _apply, ...)
	return get_node_or_null("/root/VF")

# --------------------------------------------------------------- accounts
func sign_up(mail: String, password: String, name: String) -> void:
	mail = mail.strip_edges().to_lower()
	name = name.strip_edges()
	var bad := validate_name(name)
	if bad == "": bad = validate_email(mail)
	if bad == "": bad = validate_password(password)
	if bad != "":
		_say(bad, "error")
		return
	if not _begin("sign_up"): return
	var r := await _http(POST, "/auth/v1/signup", {"email": mail, "password": password, "data": {"display_name": name}})
	var d: Variant = r.data
	if r.ok and d is Dictionary and d.has("access_token"):
		display_name = name
		await _signed_in(d, "Welcome aboard, %s! Your progress is now backed up." % name)
		return
	_end("signed_out")
	if r.ok:
		# email confirmations are on: no session until the link in the email is opened
		email = mail
		_say("Almost there! Open the link we emailed to %s, then sign in here." % mail, "info")
	else:
		_say(friendly_error(r), "error")

func sign_in(mail: String, password: String) -> void:
	mail = mail.strip_edges().to_lower()
	var bad := validate_email(mail)
	if bad == "" and password == "": bad = "Enter your password."
	if bad != "":
		_say(bad, "error")
		return
	if not _begin("sign_in"): return
	var r := await _http(POST, "/auth/v1/token?grant_type=password", {"email": mail, "password": password})
	var d: Variant = r.data
	if r.ok and d is Dictionary and d.has("access_token"):
		await _signed_in(d, "Signed in. Welcome back!")
		return
	_end("signed_out")
	_say(friendly_error(r), "error")

## Startup: sign in again with the saved refresh token (no password needed).
func restore_session() -> void:
	if _refresh_token == "" or not configured(): return
	if not _begin("restore"): return
	var r := await _http(POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh_token})
	var d: Variant = r.data
	if r.ok and d is Dictionary and d.has("access_token"):
		await _signed_in(d, "")
	elif r.net or int(r.code) >= 500:
		_end("offline")
		_say("You're offline. Your progress is saved on this device and will sync when you're back.", "info")
	else:
		_forget()
		_end("signed_out")
		_say("Your session ended. Please sign in again.", "info")

func sign_out() -> void:
	if state != "signed_in" and state != "offline": return
	var was := state
	if not _begin("sign_out"): return
	if was == "signed_in" and dirty and conflict.is_empty():
		await _upload(false)
	if _access != "":
		await _http(POST, "/auth/v1/logout?scope=local", {}, PackedStringArray(), _access)   # this device only
	_forget()
	_end("signed_out")
	_say("Signed out. Your progress stays on this device.", "info")

## "Forgot password?": Supabase emails a 6-digit code (see docs/BACKEND.md, email template).
func request_reset(mail: String) -> void:
	mail = mail.strip_edges().to_lower()
	var bad := validate_email(mail)
	if bad != "":
		_say(bad, "error")
		return
	if not _begin("recover"): return
	var r := await _http(POST, "/auth/v1/recover", {"email": mail})
	_end("signed_out")
	if r.ok:
		reset_sent_to = mail
		_say("If %s has an account, a code is on its way. Enter it below with a new password." % mail, "info")
	else:
		_say(friendly_error(r), "error")

func reset_password(mail: String, code: String, new_password: String) -> void:
	mail = mail.strip_edges().to_lower()
	code = code.strip_edges().replace(" ", "")
	var bad := validate_email(mail)
	if bad == "" and not code.is_valid_int(): bad = "Enter the code from the email (numbers only)."
	if bad == "": bad = validate_password(new_password)
	if bad != "":
		_say(bad, "error")
		return
	if not _begin("reset"): return
	var r := await _http(POST, "/auth/v1/verify", {"type": "recovery", "email": mail, "token": code})
	var d: Variant = r.data
	if not (r.ok and d is Dictionary and d.has("access_token")):
		_end("signed_out")
		_say(friendly_error(r), "error")
		return
	_take_session(d)
	var u := await _http(PUT, "/auth/v1/user", {"password": new_password}, PackedStringArray(), _access)
	reset_sent_to = ""
	await _signed_in(d, "Password changed. Welcome back!" if u.ok else "Signed in, but the new password wasn't saved: " + friendly_error(u))

## Web: arrived from a password-reset link (already signed in) and chose a new password.
func change_password(new_password: String) -> void:
	var bad := validate_password(new_password)
	if bad != "":
		_say(bad, "error")
		return
	var r := await _authed(PUT, "/auth/v1/user", {"password": new_password})
	if r.ok:
		need_new_password = false
		_say("Password changed.", "good")
	else:
		_say(friendly_error(r), "error")

func rename(name: String) -> void:
	name = name.strip_edges()
	var bad := validate_name(name)
	if bad != "":
		_say(bad, "error")
		return
	if state != "signed_in" or renaming: return
	renaming = true
	status_changed.emit()
	var r := await _authed(PATCH, "/rest/v1/profiles?id=eq." + user_id.uri_encode(), {"display_name": name},
		PackedStringArray(["Prefer: return=minimal"]))
	renaming = false
	if r.ok:
		display_name = name
		_save_account()
		_say("You're now %s on the leaderboard." % name, "good")
		lb_time = 0.0
	else:
		_say(friendly_error(r), "error")

## Deletes the account, its profile and its cloud save for good (the save on this device stays).
## App stores require an in-app way to do this.
func delete_account() -> void:
	if state != "signed_in": return
	if not _begin("delete"): return
	var r := await _authed(POST, "/rest/v1/rpc/delete_my_account", {})
	if r.ok:
		_forget()
		_end("signed_out")
		_say("Your account and cloud save were deleted. Your progress stays on this device.", "info")
	else:
		_end("signed_in")
		_say(friendly_error(r), "error")

func _signed_in(session: Dictionary, greet: String) -> void:
	_take_session(session)
	await _load_profile()
	_load_sync_marks()
	_end("signed_in")
	if greet != "": _say(greet, "good")
	elif message_kind == "error": _say("", "")
	await _reconcile()

func _load_profile() -> void:
	var r := await _authed(GET, "/rest/v1/profiles?select=display_name&id=eq." + user_id.uri_encode())
	var d: Variant = r.data
	if r.ok and d is Array and not d.is_empty() and d[0] is Dictionary:
		display_name = str(d[0].get("display_name", display_name))
		_save_account()

# ------------------------------------------------------------- cloud save
## Sign-in / startup: line this device's save up with the cloud save. Progress that isn't
## safe somewhere else is never replaced silently: if in doubt, the player picks.
func _reconcile() -> void:
	sync_state = "syncing"
	status_changed.emit()
	var r := await _fetch_cloud()
	if not r.ok:
		_sync_failed(r)
		return
	var rows: Variant = r.data
	var vf = _vf()
	var local := summarize(vf.to_dict())
	if not (rows is Array) or rows.is_empty() or not (rows[0] is Dictionary):
		await _upload(false)                     # first sign-in anywhere: the cloud gets this save
		return
	var row: Dictionary = rows[0]
	var data: Variant = row.get("data")
	if not save_valid(data):
		sync_error = "The cloud save was damaged, so this device's save replaced it."
		await _upload(true)
		return
	var cloud := summarize(data)
	cloud["updated_at"] = str(row.get("updated_at", ""))
	match decide(local, cloud, _synced_fp, _synced_at):
		"same":
			_mark_synced(local.fp, cloud.updated_at)
			_sync_ok()
		"upload":
			await _upload(false)
		"download":
			_apply_cloud(data, cloud.updated_at, "Loaded your cloud save (Lv %s, P%d)." % [_commas(cloud.level), cloud.prestige])
		_:
			_ask(cloud, local, data)

## Upload this device's save now (if signed in and nothing is waiting for the player).
func sync_now() -> void:
	if state != "signed_in" or not conflict.is_empty(): return
	await _upload(false)

## The player answered "Use your cloud save or this device?"
func resolve_conflict(use_cloud: bool) -> void:
	if conflict.is_empty(): return
	var c := conflict
	conflict = {}
	if use_cloud:
		var cloud: Dictionary = c.cloud
		_apply_cloud(c.data, str(cloud.get("updated_at", "")), "Cloud save loaded (Lv %s, P%d)." % [_commas(cloud.level), cloud.prestige])
	else:
		sync_state = "syncing"
		status_changed.emit()
		await _upload(true)
		if sync_state == "ok": _say("This device's save is now your cloud save.", "good")

func _fetch_cloud() -> Dictionary:
	return await _authed(GET, "/rest/v1/saves?select=data,updated_at,level,prestige,money_earned&user_id=eq." + user_id.uri_encode())

func _upload(overwrite: bool) -> void:
	if _uploading: return
	var vf = _vf()
	if vf == null or user_id == "": return
	_uploading = true
	var d: Dictionary = vf.to_dict()
	var s := summarize(d)
	dirty = false
	_since_sync = 0.0
	sync_state = "syncing"
	status_changed.emit()
	# level / prestige / money_earned are re-derived from data by the server (saves_guard). "overwrite" is
	# always sent: true only when the player chose to replace a cloud save that has more progress.
	var body := {"user_id": user_id, "data": d, "level": s.level, "prestige": s.prestige, "money_earned": s.money_earned,
		"overwrite": overwrite}
	var r := await _authed(POST, "/rest/v1/saves?select=updated_at", body,
		PackedStringArray(["Prefer: resolution=merge-duplicates,return=representation"]))
	_uploading = false
	if r.ok:
		var at := ""
		var rows: Variant = r.data
		if rows is Array and not rows.is_empty() and rows[0] is Dictionary: at = str(rows[0].get("updated_at", ""))
		_mark_synced(s.fp, at)
		_sync_ok()
		return
	dirty = true
	if is_downgrade(r):
		# the server refused to replace a save with more progress: let the player choose
		var f := await _fetch_cloud()
		var rows: Variant = f.data
		if f.ok and rows is Array and not rows.is_empty() and rows[0] is Dictionary and save_valid(rows[0].get("data")):
			var cloud := summarize(rows[0].data)
			cloud["updated_at"] = str(rows[0].get("updated_at", ""))
			_ask(cloud, summarize(vf.to_dict()), rows[0].data)
			return
	_sync_failed(r)

func _apply_cloud(data: Dictionary, updated_at: String, msg: String) -> void:
	var vf = _vf()
	_applying = true
	vf._apply(data)
	if vf.has_method("_roll_quest_day"): vf._roll_quest_day()
	vf.save_game()
	vf.changed.emit()
	_applying = false
	dirty = false
	_mark_synced(summarize(vf.to_dict()).fp, updated_at)
	_say(msg, "good")
	_sync_ok()

func _ask(cloud: Dictionary, local: Dictionary, data: Dictionary) -> void:
	conflict = {"cloud": cloud, "local": local, "data": data}
	sync_state = "conflict"
	status_changed.emit()
	conflict_found.emit()

func _sync_ok() -> void:
	sync_state = "ok"
	sync_error = ""
	last_sync = Time.get_unix_time_from_system()
	lb_time = 0.0                                   # our row changed: a cached leaderboard is stale
	status_changed.emit()

func _sync_failed(r: Dictionary) -> void:
	sync_state = "error"
	sync_error = friendly_error(r)
	status_changed.emit()

func _on_vf_changed() -> void:
	if not _applying: dirty = true

func _process(delta: float) -> void:
	if state == "signed_in":
		_since_sync += delta
		if dirty and _since_sync >= SYNC_EVERY and conflict.is_empty() and not _uploading:
			_upload(false)
	elif state == "offline":
		_since_retry += delta
		if _since_retry >= RETRY_EVERY:
			_since_retry = 0.0
			restore_session()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			on_quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			# phones kill paused apps and browsers close tabs without warning: upload when we lose focus
			if state == "signed_in" and dirty and conflict.is_empty() and not _uploading and _since_sync > 10.0:
				_upload(false)

## The window is closing (vf_main calls this right after saving locally; the autoload hears it too).
## Signed in with unsynced progress: upload first (at most ~4 s), then quit. On desktop the window
## waits (auto_accept_quit is off while signed in); elsewhere this is best effort.
## and_quit = false: just the upload (tests).
func on_quit(and_quit := true) -> void:
	if _quitting: return
	_quitting = true
	if and_quit:
		get_tree().create_timer(4.0, true, false, true).timeout.connect(_finish_quit)   # never hang the close
	while _uploading:                               # an autosync is on its way: let it land first
		await get_tree().process_frame
	if state == "signed_in" and dirty and conflict.is_empty():
		await _upload(false)
	if and_quit:
		_finish_quit()
	else:
		_quitting = false

func _finish_quit() -> void:
	if not get_tree().auto_accept_quit:
		get_tree().quit()

# ------------------------------------------------------------ leaderboard
func load_leaderboard() -> void:
	if not configured() or lb_state == "loading": return
	lb_state = "loading"
	leaderboard_changed.emit()
	var r := await _http(GET, "/rest/v1/leaderboard?select=display_name,level,prestige,money_earned"
		+ "&order=prestige.desc,level.desc,money_earned.desc&limit=%d" % LEADERBOARD_SIZE)
	var d: Variant = r.data
	if r.ok and d is Array:
		leaderboard = d
		lb_state = "ok"
		lb_time = Time.get_unix_time_from_system()
	else:
		lb_state = "error"
		lb_error = friendly_error(r)
		lb_time = Time.get_unix_time_from_system()  # retried once it's stale, like a good result
	leaderboard_changed.emit()

## index of the player's row in the leaderboard, or -1
func my_rank() -> int:
	if display_name == "": return -1
	for i in leaderboard.size():
		var row: Variant = leaderboard[i]
		if row is Dictionary and str(row.get("display_name", "")).to_lower() == display_name.to_lower():
			return i
	return -1

# ------------------------------------------------------------------- HTTP
## One call to Supabase. Returns {ok, code, data, net}; net = the server couldn't be reached.
func _http(method: int, path: String, body: Variant = null, extra := PackedStringArray(), token := "") -> Dictionary:
	var h := HTTPRequest.new()
	h.timeout = TIMEOUT
	add_child(h)
	var headers := PackedStringArray(["apikey: " + anon_key, "Content-Type: application/json", "Accept: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	elif anon_key.begins_with("eyJ"):
		headers.append("Authorization: Bearer " + anon_key)   # legacy anon keys are JWTs; new publishable keys aren't
	headers.append_array(extra)
	var payload := "" if body == null else JSON.stringify(body)
	if h.request(url + path, headers, method, payload) != OK:
		h.queue_free()
		return {"ok": false, "code": 0, "data": null, "net": true}
	var res: Array = await h.request_completed
	h.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var raw: PackedByteArray = res[3]
	var data: Variant = null
	var text := raw.get_string_from_utf8()
	if text.strip_edges() != "":
		var j := JSON.new()
		if j.parse(text) == OK: data = j.data
	var net := result != HTTPRequest.RESULT_SUCCESS or code == 0
	return {"ok": not net and code >= 200 and code < 300, "code": 0 if net else code, "data": data, "net": net}

## A call as the signed-in player: refreshes the access token when it is about to expire
## (or the server says it did) and retries once.
func _authed(method: int, path: String, body: Variant = null, extra := PackedStringArray()) -> Dictionary:
	if not await _ensure_token():
		return {"ok": false, "code": 0 if state == "offline" else 401, "data": null, "net": state == "offline"}
	var r := await _http(method, path, body, extra, _access)
	if int(r.code) == 401 or (int(r.code) == 403 and "jwt" in str(r.data).to_lower()):
		_expires = 0.0
		if await _ensure_token():
			r = await _http(method, path, body, extra, _access)
	return r

func _ensure_token() -> bool:
	if _access != "" and Time.get_unix_time_from_system() < _expires - 30.0: return true
	if _refresh_token == "": return false
	return await _do_refresh()

func _do_refresh() -> bool:
	if _refreshing:
		return await _refresh_done
	_refreshing = true
	var r := await _http(POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": _refresh_token})
	var d: Variant = r.data
	var ok := false
	if r.ok and d is Dictionary and d.has("access_token"):
		_take_session(d)
		ok = true
	elif r.net or int(r.code) >= 500:
		pass                                        # offline for now: keep the session
	else:
		_forget()                                   # revoked (signed out elsewhere, password changed, ...)
		_set_state("signed_out")
		_say("Your session ended. Please sign in again.", "info")
	_refreshing = false
	_refresh_done.emit(ok)
	return ok

func _take_session(d: Dictionary) -> void:
	_access = str(d.get("access_token", ""))
	_refresh_token = str(d.get("refresh_token", _refresh_token))
	_expires = Time.get_unix_time_from_system() + float(d.get("expires_in", 3600))
	var u: Variant = d.get("user")
	if u is Dictionary:
		var new_id := str(u.get("id", user_id))
		if new_id != user_id:
			display_name = ""
		user_id = new_id
		email = str(u.get("email", email))
		var meta: Variant = u.get("user_metadata")
		if display_name == "" and meta is Dictionary:
			display_name = str(meta.get("display_name", ""))
	_save_account()

func _forget() -> void:
	_access = ""
	_refresh_token = ""
	_expires = 0.0
	user_id = ""
	email = ""
	display_name = ""
	conflict = {}
	sync_state = ""
	sync_error = ""
	dirty = false
	need_new_password = false
	_save_account()

# ------------------------------------------------------------------ state
func _begin(what: String) -> bool:
	if state == "busy": return false
	op = what
	message = ""
	message_kind = ""
	_set_state("busy")
	return true

func _end(s: String) -> void:
	op = ""
	_set_state(s)

func _set_state(s: String) -> void:
	state = s
	# desktop: keep the window open for a moment on close so the last progress can upload
	if OS.get_name() in ["Windows", "Linux", "macOS", "FreeBSD"] and is_inside_tree():
		get_tree().set_auto_accept_quit(s != "signed_in")
	status_changed.emit()

func _say(text: String, kind: String) -> void:
	message = text
	message_kind = kind
	status_changed.emit()

# ---------------------------------------------------------- account file
func _load_account() -> void:
	var c := ConfigFile.new()
	if c.load(account_file) != OK: return
	_refresh_token = str(c.get_value("session", "refresh_token", ""))
	user_id = str(c.get_value("session", "user_id", ""))
	email = str(c.get_value("session", "email", ""))
	display_name = str(c.get_value("session", "display_name", ""))

func _save_account() -> void:
	var c := ConfigFile.new()
	c.load(account_file)
	if c.has_section("session"): c.erase_section("session")
	if _refresh_token != "":
		c.set_value("session", "refresh_token", _refresh_token)
		c.set_value("session", "user_id", user_id)
		c.set_value("session", "email", email)
		c.set_value("session", "display_name", display_name)
	c.save(account_file)

func _load_sync_marks() -> void:
	var c := ConfigFile.new()
	c.load(account_file)
	var same := str(c.get_value("sync", "user_id", "")) == user_id
	_synced_fp = str(c.get_value("sync", "fp", "")) if same else ""
	_synced_at = str(c.get_value("sync", "cloud_at", "")) if same else ""

func _mark_synced(fp: String, at: String) -> void:
	_synced_fp = fp
	if at != "": _synced_at = at
	var c := ConfigFile.new()
	c.load(account_file)
	c.set_value("sync", "user_id", user_id)
	c.set_value("sync", "fp", _synced_fp)
	c.set_value("sync", "cloud_at", _synced_at)
	c.save(account_file)

## Web: Supabase email links (confirm email / reset password) open the game with the
## session in the URL fragment (#access_token=...&refresh_token=...&type=...).
func _web_link() -> bool:
	if not OS.has_feature("web"): return false
	var h: Variant = JavaScriptBridge.eval("window.location.hash", true)
	var frag := str(h) if h != null else ""
	if frag.length() < 2: return false
	var q := parse_fragment(frag.substr(1))
	if not (q.has("refresh_token") or q.has("error_code") or q.has("error")): return false
	JavaScriptBridge.eval("history.replaceState(null, '', location.pathname + location.search)", true)
	if not q.has("refresh_token"):
		_say("That email link didn't work (%s). Sign in, or ask for a new one." % str(q.get("error_description", "it expired")), "error")
		if _refresh_token != "": restore_session.call_deferred()
		return true
	_refresh_token = str(q.refresh_token)
	need_new_password = str(q.get("type", "")) == "recovery"
	restore_session.call_deferred()
	return true

# ============================================================ pure helpers
## (static: tests/vf_sim_test.gd checks these without a network)

static func clean_url(u: String) -> String:
	u = u.strip_edges()
	while u.ends_with("/"): u = u.trim_suffix("/")
	for suffix in ["/rest/v1", "/auth/v1"]:
		u = u.trim_suffix(suffix)
	return u

static func parse_config(d: Dictionary) -> Dictionary:
	return {"url": clean_url(str(d.get("url", ""))), "anon_key": str(d.get("anon_key", "")).strip_edges()}

static func parse_fragment(s: String) -> Dictionary:
	var out := {}
	for part in s.split("&", false):
		var kv := part.split("=", true, 1)
		out[kv[0].uri_decode()] = kv[1].replace("+", " ").uri_decode() if kv.size() > 1 else ""
	return out

static func validate_email(mail: String) -> String:
	var re := RegEx.create_from_string("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$")
	return "" if re.search(mail.strip_edges()) else "Enter a valid email address."

static func validate_password(p: String) -> String:
	if p.length() < PASSWORD_MIN: return "Passwords need at least %d characters." % PASSWORD_MIN
	if p.length() > 72: return "That password is too long (72 characters max)."
	return ""

static func validate_name(n: String) -> String:
	n = n.strip_edges()
	if n.length() < NAME_MIN or n.length() > NAME_MAX:
		return "Your fisher name needs %d to %d characters." % [NAME_MIN, NAME_MAX]
	var re := RegEx.create_from_string("^[\\p{L}\\p{N} _.\\-]+$")
	if not re.search(n): return "Names can use letters, numbers, spaces and _ - ."
	return ""

## the numbers that matter for "which save is better?" + a fingerprint to spot changes
static func summarize(d: Dictionary) -> Dictionary:
	var st: Variant = d.get("stats", {})
	var stats: Dictionary = st if st is Dictionary else {}
	var s := {"level": _num(d.get("level", 1)), "prestige": _num(d.get("prestige", 0)), "xp": _num(d.get("xp", 0)),
		"money": _num(d.get("money", 0)), "money_earned": _num(stats.get("money_earned", 0)), "trips": _num(stats.get("trips", 0))}
	s["fp"] = "%d/%d/%d/%d/%d/%d" % [s.prestige, s.level, s.xp, s.money, s.money_earned, s.trips]
	s["fresh"] = s.prestige == 0 and s.level <= 1 and s.trips == 0 and s.money_earned == 0
	return s

## ints, rounded the way JSON floats are, so a save and its cloud copy fingerprint the same
static func _num(v: Variant) -> int:
	return int(float(v)) if (v is int or v is float or (v is String and v.is_valid_float())) else 0

## a has less progress than b (prestige first, then level)
static func worse(a: Dictionary, b: Dictionary) -> bool:
	return int(a.prestige) < int(b.prestige) or (int(a.prestige) == int(b.prestige) and int(a.level) < int(b.level))

## same | upload | download | ask. synced_fp / synced_at describe the save this device last
## exchanged with the cloud; when one side hasn't moved since then, the other side wins
## (unless it has less progress: then the player is asked).
static func decide(local: Dictionary, cloud: Dictionary, synced_fp: String, synced_at: String) -> String:
	if local.fp == cloud.fp: return "same"
	if local.fresh: return "download"
	if synced_fp != "":
		var cloud_moved: bool = not (cloud.fp == synced_fp or (synced_at != "" and str(cloud.get("updated_at", "")) == synced_at))
		var local_moved: bool = local.fp != synced_fp
		if local_moved and not cloud_moved:
			return "ask" if worse(local, cloud) else "upload"
		if cloud_moved and not local_moved:
			return "ask" if worse(cloud, local) else "download"
	return "ask"

## a cloud save we can load (VF._apply reads these keys directly)
static func save_valid(d: Variant) -> bool:
	if not (d is Dictionary): return false
	if int(float(d.get("v", 0))) != SAVE_VERSION: return false
	for k in ["name", "prestige", "level", "xp", "money", "biome", "rod", "bait", "pet", "owned_rods", "boats_owned",
			"bait_stock", "inventory", "exotics", "hooks", "upgrades", "specials", "league", "perks", "charms", "pets",
			"trips_without_pet", "boosts", "personal_boosters", "personal_until", "stats", "quest_day", "quest_progress",
			"quest_claimed", "week_key", "week_trips", "week_hooks", "daily_last", "daily_streak"]:
		if not d.has(k): return false
	return d.stats is Dictionary and d.pets is Dictionary and d.owned_rods is Array

static func is_downgrade(r: Dictionary) -> bool:
	var d: Variant = r.get("data")
	return d is Dictionary and "save_downgrade" in str(d.get("message", ""))

## Supabase error -> a sentence a player understands
static func friendly_error(r: Dictionary) -> String:
	if r.get("net", false) or int(r.get("code", 0)) == 0:
		return "Can't reach the server. Check your internet and try again."
	var code := int(r.get("code", 0))
	var d: Variant = r.get("data")
	var key := ""
	var msg := ""
	if d is Dictionary:
		key = str(d.get("error_code", d.get("code", d.get("error", ""))))
		msg = str(d.get("msg", d.get("error_description", d.get("message", ""))))
	var t := (key + " " + msg).to_lower()
	if "email_not_confirmed" in t or "not confirmed" in t:
		return "Please confirm your email first: open the link we sent you, then sign in."
	if "user_already_exists" in t or "email_exists" in t or "already registered" in t:
		return "That email already has an account. Sign in instead, or use \"Forgot password?\"."
	if "invalid_credentials" in t or "invalid login" in t:
		return "Wrong email or password."
	if "weak_password" in t or "password should" in t:
		return "Please pick a stronger password. " + msg
	if "otp_expired" in t or "token has expired" in t or "otp" in t:
		return "That code is wrong or has expired. Ask for a new one."
	if "rate_limit" in t or "rate limit" in t or code == 429:
		return "Too many tries. Please wait a minute and try again."
	if "email_address_invalid" in t or "validate email" in t or "invalid email" in t:
		return "That email address doesn't look right."
	if "email_address_not_authorized" in t:
		return "We can't send email to that address yet. Please try again later."
	if "signup_disabled" in t or "signups not allowed" in t:
		return "New accounts are paused right now. Please try again later."
	if "refresh_token" in t or "session_not_found" in t:
		return "Your session ended. Please sign in again."
	if "23505" in t or "duplicate key" in t or code == 409:
		return "That name is taken. Try another one."
	if "save_downgrade" in t:
		return "Your cloud save has more progress than this device."
	if "implausible" in t:
		return "The server didn't accept this save: " + msg.get_slice(":", 1).strip_edges()
	if "database error saving new user" in t:
		return "Couldn't create the account. Please try a different name."
	if code == 401 or code == 403:
		return "Please sign in again."
	if code >= 500:
		return "The server is having trouble. Please try again in a moment."
	return "Something went wrong (error %d). Please try again." % code

static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK: return {}
	return j.data if j.data is Dictionary else {}

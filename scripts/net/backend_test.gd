extends RefCounted
## End-to-end test of accounts + cloud saves + leaderboard against tools/mock_supabase.py:
##   python tools/mock_supabase.py --port 54321 --seed 14
##   godot --path . -- --capture=DIR --backend-test --backend-url=http://127.0.0.1:54321 --backend-key=test
## Drives the real Account panel, prints PASS/FAIL lines and saves screenshots to DIR.
## Never touches the real save (VF.autosave is off in capture mode) or the real session
## (capture mode uses user://account_test.cfg, deleted at the end).

var m                    # vf_main
var ui                   # vf_main.account_ui
var dir := ""
var fails := 0
var checks := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		print("PASS ", what)
	else:
		fails += 1
		print("FAIL ", what)

func wait(t: float) -> void:
	await m.get_tree().create_timer(t).timeout

func until(cond: Callable, timeout := 10.0) -> bool:
	var t := 0.0
	while not cond.call():
		if t >= timeout: return false
		await m.get_tree().create_timer(0.05).timeout
		t += 0.05
	return true

func shot(name: String) -> void:
	await wait(0.35)
	await m._shot(dir + "/%s.png" % name)
	print("SHOT ", dir + "/%s.png" % name)

## a mock-only helper endpoint (outbox, expire tokens)
func mock(method: int, path: String) -> Dictionary:
	var h := HTTPRequest.new()
	m.add_child(h)
	h.request(Backend.url + path, PackedStringArray(), method, "")
	var res: Array = await h.request_completed
	h.queue_free()
	var j := JSON.new()
	if j.parse((res[3] as PackedByteArray).get_string_from_utf8()) == OK and j.data is Dictionary:
		return j.data
	return {}

func fill(values: Dictionary) -> void:
	for k in values:
		var e: LineEdit = ui._fields.get(k)
		if e == null:
			check(false, "form has a '%s' field" % k)
			continue
		e.text = values[k]

func press(key: String) -> void:
	var b: Button = ui._buttons.get(key)
	if b == null or b.disabled:
		check(false, "button '%s' is there and enabled" % key)
		return
	b.pressed.emit()

func fresh_device() -> void:
	VF._apply(VF._defaults.duplicate(true))
	VF.tutorial = 99
	VF.goals_done = VFData.STARTER_GOALS.size()
	VF.changed.emit()

func cloud() -> Dictionary:
	var r: Dictionary = await Backend._fetch_cloud()
	if r.ok and r.data is Array and not r.data.is_empty(): return r.data[0]
	return {}

func session_in_file() -> bool:
	var c := ConfigFile.new()
	return c.load(Backend.account_file) == OK and str(c.get_value("session", "refresh_token", "")) != ""

func run(main, out_dir: String) -> void:
	m = main
	ui = m.account_ui
	dir = out_dir
	var B = Backend
	VF.autosave = false
	print("== accounts / cloud save / leaderboard against ", B.url)
	check(B.account_file != "user://account.cfg", "test session lives in its own file (%s)" % B.account_file)
	if B.account_file == "user://account.cfg":
		return                                   # never touch the player's real session
	DirAccess.remove_absolute(ProjectSettings.globalize_path(B.account_file))
	check(B.configured() and B.state == "signed_out", "configured from --backend-url/--backend-key, signed out")

	# ---- a device with progress, the sign-in form
	fresh_device()
	m._veteran("Ocean")
	VF.level = 120
	VF.stats.trips = 5200
	VF.stats.money_earned = 2_750_000_000
	VF.changed.emit()
	m._open_panel("account", "Account")
	await shot("account_1_signed_out")
	var mail := "tester%d@example.com" % (int(Time.get_unix_time_from_system()) % 100000)
	fill({"email": mail, "password": "wrongpass1"})
	press("submit")
	await until(func(): return B.state == "signed_out" and B.message != "")
	check(B.message == "Wrong email or password.", "unknown account -> \"%s\"" % B.message)
	await shot("account_2_error")

	# ---- create an account: the cloud gets this device's save
	ui._set_mode("sign_up")
	await shot("account_3_sign_up_form")
	fill({"name": "Tester", "email": mail, "password": "short"})
	press("submit")
	check(B.message_kind == "error" and "6" in B.message, "short password refused before any request (\"%s\")" % B.message)
	fill({"password": "hunter22"})
	press("submit")
	var ok := await until(func(): return B.state == "signed_in" and B.sync_state == "ok")
	check(ok and B.display_name == "Tester", "sign up -> signed in as %s, sync %s" % [B.display_name, B.sync_state])
	var c := await cloud()
	check(int(c.get("level", 0)) == 120 and int(c.get("prestige", -1)) == 1, "first sign-in uploaded this device's save (cloud Lv %s P%s)" % [c.get("level"), c.get("prestige")])
	check(session_in_file() and not FileAccess.get_file_as_string(B.account_file).contains("hunter22"), "refresh token saved, password never stored")
	await shot("account_4_signed_in")
	m._open_panel("menu")
	await shot("account_0_menu_tile")
	m._open_panel("account", "Account")

	# ---- a second sign-up with the same email
	var dup: Dictionary = await B._http(HTTPClient.METHOD_POST, "/auth/v1/signup", {"email": mail, "password": "hunter22", "data": {"display_name": "Copy"}})
	check(B.friendly_error(dup).begins_with("That email already has an account"), "email taken -> \"%s\"" % B.friendly_error(dup))

	# ---- progress uploads; an expired access token is refreshed on the fly
	VF.level = 131
	VF.changed.emit()
	check(B.dirty, "progress marks the save dirty")
	await B.sync_now()
	c = await cloud()
	check(int(c.get("level", 0)) == 131 and not B.dirty, "sync uploads new progress (cloud Lv %s)" % c.get("level"))
	await mock(HTTPClient.METHOD_POST, "/__mock/expire_tokens")
	VF.xp += 10
	VF.changed.emit()
	await B.sync_now()
	check(B.sync_state == "ok" and B.state == "signed_in", "expired access token refreshed transparently")

	# ---- leaderboard
	m._open_panel("account", "Leaderboard")
	await wait(0.1)                              # the stale board reloads on the next frame
	ok = await until(func(): return B.lb_state == "ok")
	await wait(0.2)
	check(ok and B.leaderboard.size() > 1 and B.my_rank() >= 0, "leaderboard: %d rows, you are #%d" % [B.leaderboard.size(), B.my_rank() + 1])
	var sorted := true
	for i in range(1, B.leaderboard.size()):
		var a: Dictionary = B.leaderboard[i - 1]
		var b: Dictionary = B.leaderboard[i]
		if int(a.prestige) < int(b.prestige) or (int(a.prestige) == int(b.prestige) and int(a.level) < int(b.level)): sorted = false
	check(sorted and not B.leaderboard[0].has("data") and not B.leaderboard[0].has("user_id"), "sorted by prestige, level; no save data or ids exposed")
	await shot("account_5_leaderboard")

	# ---- restart: the session comes back from the refresh token alone
	B._access = ""
	B._expires = 0.0
	B._refresh_token = ""
	B.user_id = ""
	B.state = "signed_out"
	B._load_account()
	B.restore_session()
	ok = await until(func(): return B.state == "signed_in" and B.sync_state == "ok")
	check(ok and B.display_name == "Tester" and B.conflict.is_empty(), "session restored at startup, nothing to ask (same save)")

	# ---- a second device: fresh install, sign in -> cloud save restored
	await B.sign_out()
	check(B.state == "signed_out" and not session_in_file(), "sign out clears the session")
	check(VF.level == 131, "sign out keeps the progress on this device")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(B.account_file))
	fresh_device()
	m._open_panel("account", "Account")
	ui._set_mode("sign_in")
	fill({"email": mail, "password": "hunter22"})
	press("submit")
	ok = await until(func(): return B.state == "signed_in" and B.sync_state == "ok")
	check(ok and VF.level == 131 and VF.prestige == 1 and int(VF.stats.trips) == 5200, "second device: cloud save restored (Lv %d P%d)" % [VF.level, VF.prestige])

	# ---- different progress on this device -> the player chooses
	await B.sign_out()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(B.account_file))
	fresh_device()
	VF.level = 7
	VF.stats.trips = 64
	VF.stats.money_earned = 41_000
	VF.changed.emit()
	m._close_panel()
	B.sign_in(mail, "hunter22")
	ok = await until(func(): return not B.conflict.is_empty())
	check(ok and m.overlay.visible and m._panel_kind == "account", "different saves -> the account panel asks which one to keep")
	c = await cloud()
	check(int(c.get("level", 0)) == 131, "nothing uploaded while the player decides")
	await shot("account_6_conflict")
	press("use_cloud")
	ok = await until(func(): return B.sync_state == "ok" and B.conflict.is_empty())
	check(ok and VF.level == 131, "\"Use cloud save\" loads it (Lv %d)" % VF.level)

	# ---- the server refuses to replace more progress unless the player says so
	fresh_device()
	VF.level = 3
	VF.stats.trips = 9
	VF.changed.emit()
	await B.sync_now()
	check(not B.conflict.is_empty(), "server refused a downgrade (save_downgrade) -> player is asked")
	c = await cloud()
	check(int(c.get("level", 0)) == 131, "cloud save untouched by the refused upload")
	await wait(0.2)
	press("keep_device")
	ok = await until(func(): return B.sync_state == "ok" and B.conflict.is_empty())
	c = await cloud()
	check(ok and int(c.get("level", 0)) == 3, "\"Keep this device\" replaces the cloud save on purpose")
	m._veteran("Ocean")
	VF.level = 140
	VF.stats.money_earned = 3_100_000_000
	VF.changed.emit()
	await B.sync_now()

	# ---- forgot password: code by email -> new password
	await B.sign_out()
	m._open_panel("account", "Account")
	ui._set_mode("forgot")
	fill({"email": mail})
	press("submit")
	ok = await until(func(): return B.reset_sent_to != "" and B.state == "signed_out")
	var code := str((await mock(HTTPClient.METHOD_GET, "/__mock/outbox?email=" + mail.uri_encode())).get("code", ""))
	check(ok and code.length() == 6, "forgot password -> code emailed")
	await wait(0.2)
	await shot("account_7_reset_code")
	fill({"code": "000000" if code != "000000" else "111111", "new_password": "newpass77"})
	press("submit")
	await until(func(): return B.state == "signed_out" and B.message != "")
	check(B.message.begins_with("That code is wrong"), "wrong code -> \"%s\"" % B.message)
	fill({"code": code, "new_password": "newpass77"})
	press("submit")
	ok = await until(func(): return B.state == "signed_in" and B.sync_state == "ok")
	check(ok, "right code + new password -> signed in")
	await B.sign_out()
	await B.sign_in(mail, "hunter22")
	check(B.state == "signed_out" and B.message == "Wrong email or password.", "old password no longer works")
	await B.sign_in(mail, "newpass77")
	await until(func(): return B.sync_state == "ok")
	check(B.state == "signed_in", "new password works")

	# ---- rename (names are unique, case-insensitive)
	var other := "Marlin Mae"
	for row in B.leaderboard:
		if str(row.get("display_name", "")).to_lower() != B.display_name.to_lower():
			other = str(row.get("display_name", ""))
			break
	await B.rename(other.to_upper())
	check(B.message == "That name is taken. Try another one.", "rename to a taken name -> \"%s\"" % B.message)
	await B.rename("Tester Two")
	check(B.display_name == "Tester Two", "rename -> %s" % B.display_name)

	# ---- offline
	var good_url: String = B.url
	B.url = "http://127.0.0.1:9"
	VF.xp += 1
	VF.changed.emit()
	await B.sync_now()
	check(B.sync_state == "error" and B.sync_error.begins_with("Can't reach the server"), "offline -> \"%s\"" % B.sync_error)
	B.url = good_url
	await B.sync_now()
	check(B.sync_state == "ok", "back online -> synced")

	# ---- closing the game uploads the last progress
	check(not (OS.get_name() in ["Windows", "Linux", "macOS"]) or not m.get_tree().auto_accept_quit,
		"desktop: closing the window waits for the last upload while signed in")
	VF.level = 141
	VF.changed.emit()
	await B.on_quit(false)
	c = await cloud()
	check(int(c.get("level", 0)) == 141 and not B.dirty, "quit hook uploads unsynced progress (cloud Lv %s)" % c.get("level"))
	await until(func(): return B.lb_state != "loading", 20.0)   # a request sent while "offline" times out
	B.load_leaderboard()
	await until(func(): return B.lb_state == "ok" and B.my_rank() >= 0)
	m._open_panel("account", "Account")
	await shot("account_8_signed_in_final")

	# ---- delete account
	await B.delete_account()
	check(B.state == "signed_out" and not session_in_file(), "delete account -> signed out")
	await B.sign_in(mail, "newpass77")
	check(B.state == "signed_out" and B.message == "Wrong email or password.", "deleted account can't sign in")

	# ---- not configured: offline mode
	B.url = ""
	m._open_panel("account", "Account")
	await shot("account_9_coming_soon")
	check(not B.configured(), "no url -> \"coming soon\" (offline mode)")
	B.url = good_url
	m._close_panel()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(B.account_file))
	check(not FileAccess.file_exists(B.account_file), "test session file cleaned up")
	print("\nBACKEND TEST %s (%d checks, %d failures)" % ["PASS" if fails == 0 else "FAILED", checks, fails])

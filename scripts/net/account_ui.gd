extends RefCounted
## The Account panel (Menu -> Account): sign in / create account / forgot password, the cloud
## save status, the "which save do you want to keep?" prompt and the leaderboard.
## Builds into vf_main's panel_body with vf_main's UI kit (sbox, lbl, btn, icon, ph, money_str).
## All online work happens in the Backend autoload (scripts/net/backend.gd).

const C_TEXT := Color("#1f2d35")
const C_MUTED := Color("#6b7d86")
const C_GOOD := Color("#22a06b")
const C_GOLD := Color("#d4920f")
const C_BAD := Color("#e04f45")
const C_TEAL := Color("#1d9bb0")
const C_PANEL2 := Color("#eef4f6")
const C_NEUTRAL := Color("#eef3f5")
const C_LINE := Color("#dbe6ea")
const MEDALS := [Color("#f2b632"), Color("#a3b4bc"), Color("#cd8b57")]

var m                           # vf_main
var mode := "sign_in"           # sign_in | sign_up | forgot | reset
var f_email := ""               # form values survive re-renders (the password only until signed in)
var f_name := ""
var f_password := ""
var f_code := ""
var _renaming := false
var _confirm_delete := false
var _fields := {}               # key -> LineEdit (this render)
var _buttons := {}              # key -> Button (this render)
var _form: VBoxContainer
var _sync_label: Label
var _key := ""

func _init(main) -> void:
	m = main
	Backend.status_changed.connect(_on_status)
	Backend.leaderboard_changed.connect(_on_status)
	Backend.conflict_found.connect(_on_conflict)

func _open() -> bool:
	return m.overlay.visible and m._panel_kind == "account"

func _on_status() -> void:
	if Backend.state == "signed_in":
		f_password = ""
	if not _open(): return
	if _render_key() != _key:
		m._render_panel()
	else:
		_update_sync_label()
		if m._panel_tab == "Account" and Backend.state == "signed_in" and Backend.sync_state != "syncing" and _lb_stale(60.0):
			Backend.load_leaderboard()             # a new upload: refresh "You're #N"

func _lb_stale(max_age: float) -> bool:
	return Backend.lb_state == "" or (Backend.lb_state in ["ok", "error"] and Time.get_unix_time_from_system() - Backend.lb_time > max_age)

func _on_conflict() -> void:
	m._open_panel("account", "Account")

## re-render only when something the layout depends on changed (keeps typing focus otherwise)
func _render_key() -> String:
	var B = Backend
	return str([B.state, B.op, B.message, B.conflict.is_empty(), B.display_name, B.lb_state, B.need_new_password,
		B.reset_sent_to, B.renaming, m._panel_tab])

## the Account tile's subtitle in the Menu grid
func tile_subtitle() -> String:
	if not Backend.configured(): return "Cloud save & leaderboard"
	if not Backend.conflict.is_empty(): return "Choose which save to keep"
	match Backend.state:
		"signed_in": return "Signed in as " + Backend.display_name
		"offline": return "Offline · syncs when back"
	return "Cloud save & leaderboard"

# ================================================================= build
func build(tab: String) -> void:
	_fields = {}
	_buttons = {}
	_sync_label = null
	_key = _render_key()
	if not Backend.configured():
		_coming_soon()
		return
	if tab == "Leaderboard":
		_leaderboard()
		return
	if not Backend.conflict.is_empty():
		_conflict()
		return
	var st: String = Backend.state
	var op: String = Backend.op
	if st == "signed_in" or (st == "busy" and op in ["sign_out", "delete"]):
		_signed_in()
	elif st == "offline" or (st == "busy" and op == "restore"):
		_reconnecting()
	else:
		_signed_out()

# ------------------------------------------------------------ not set up
func _coming_soon() -> void:
	var c := _center_card()
	var bub := _bubble("cloud-arrow-up", C_TEAL, 40, 16)
	bub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(bub)
	var t: Label = m.lbl("Online accounts are coming soon", 26)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var s := _wrap("Cloud saves and a worldwide leaderboard are on the way. Until then, your progress is saved on this device.", 15, C_MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.custom_minimum_size.x = 460
	c.add_child(s)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	for f in [["cloud-arrow-up", "Cloud save"], ["device-mobile", "Play on any device"], ["trophy", "Leaderboard"]]:
		var it := HBoxContainer.new()
		it.add_theme_constant_override("separation", 7)
		var ic: TextureRect = m.icon(m.ph(f[0]), 18)
		ic.modulate = C_TEAL
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		it.add_child(ic)
		it.add_child(m.lbl(f[1], 14, C_MUTED))
		row.add_child(it)
	c.add_child(row)

# ------------------------------------------------------------ signed out
func _signed_out() -> void:
	if mode == "forgot" and Backend.reset_sent_to != "":
		mode = "reset"
	var busy: bool = Backend.state == "busy"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	m.panel_body.add_child(h)
	# left: why
	var info := _box(C_PANEL2, 20)
	info.custom_minimum_size.x = 330
	h.add_child(info)
	var iv := _vbox(10)
	info.add_child(iv)
	iv.add_child(_bubble("cloud-arrow-up", C_TEAL, 28, 10))
	iv.add_child(m.lbl("Your fish, everywhere", 22))
	iv.add_child(_wrap("A free account backs up your progress and lets you keep playing on any device.", 14, C_MUTED))
	var gap := Control.new()
	gap.custom_minimum_size.y = 2
	iv.add_child(gap)
	for f in ["Cloud save every minute", "Same progress on PC, phone and web", "A spot on the worldwide leaderboard"]:
		iv.add_child(_check_row(f, C_TEXT))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	iv.add_child(sp)
	iv.add_child(_wrap("We only keep your email, your fisher name and your save. Your password never leaves the sign-in form.", 12, C_MUTED))
	# right: the form
	var card := _box(Color.WHITE, 20, 1, C_LINE)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(card)
	_form = _vbox(10)
	card.add_child(_form)
	if mode == "sign_in" or mode == "sign_up":
		_form.add_child(_segment([["sign_in", "Sign in"], ["sign_up", "Create account"]], mode))
	match mode:
		"sign_up":
			_field("name", "Fisher name (shown on the leaderboard)", "e.g. Marlin Mae", f_name)
			_field("email", "Email", "you@example.com", f_email, false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
			_field("password", "Password", "6 or more characters", f_password, true, LineEdit.KEYBOARD_TYPE_PASSWORD)
			_primary("Creating your account…" if busy else "Create account", C_GOOD)
		"forgot":
			_form.add_child(m.lbl("Reset your password", 20))
			_form.add_child(_wrap("Enter your account's email. We'll send you a code to set a new password.", 14, C_MUTED))
			_field("email", "Email", "you@example.com", f_email, false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
			_primary("Sending…" if busy else "Send me a code", C_TEAL)
		"reset":
			_form.add_child(m.lbl("Choose a new password", 20))
			_form.add_child(_wrap("Enter the code we emailed to %s." % Backend.reset_sent_to, 14, C_MUTED))
			_field("code", "Code from the email", "123456", f_code, false, LineEdit.KEYBOARD_TYPE_NUMBER)
			_field("new_password", "New password", "6 or more characters", "", true, LineEdit.KEYBOARD_TYPE_PASSWORD)
			_primary("Saving…" if busy else "Set new password", C_TEAL)
		_:
			_field("email", "Email", "you@example.com", f_email, false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS)
			_field("password", "Password", "Your password", f_password, true, LineEdit.KEYBOARD_TYPE_PASSWORD)
			_primary("Signing in…" if busy else "Sign in", C_TEAL)
	var links := HBoxContainer.new()
	match mode:
		"sign_in":
			links.add_child(_link("Forgot password?", _set_mode.bind("forgot")))
		"forgot", "reset":
			links.add_child(_link("Back to sign in", _set_mode.bind("sign_in")))
			if mode == "reset":
				var s2 := Control.new()
				s2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				links.add_child(s2)
				links.add_child(_link("Send a new code", _resend))
	if links.get_child_count() > 0:
		_form.add_child(links)
	else:
		links.free()                               # never added to the tree: don't leak it
	_status(_form)

func _set_mode(md: String) -> void:
	_keep_fields()
	mode = md
	if md != "reset": Backend.reset_sent_to = ""
	Backend.message = ""
	m._render_panel()

func _resend() -> void:
	f_email = Backend.reset_sent_to
	Backend.reset_sent_to = ""
	mode = "forgot"
	Backend.request_reset(f_email)

func _submit() -> void:
	if Backend.state == "busy": return
	_keep_fields()
	match mode:
		"sign_up": Backend.sign_up(f_email, f_password, f_name)
		"forgot": Backend.request_reset(f_email)
		"reset": Backend.reset_password(Backend.reset_sent_to, f_code, _val("new_password"))
		_: Backend.sign_in(f_email, f_password)

func _keep_fields() -> void:
	if _fields.has("email"): f_email = _val("email")
	if _fields.has("name"): f_name = _val("name")
	if _fields.has("password"): f_password = _val("password")
	if _fields.has("code"): f_code = _val("code")

func _val(key: String) -> String:
	return (_fields[key] as LineEdit).text if _fields.has(key) and is_instance_valid(_fields[key]) else ""

# ------------------------------------------------------------- signed in
func _signed_in() -> void:
	var busy: bool = Backend.state == "busy"
	# who
	var prof := _box(C_PANEL2, 16)
	m.panel_body.add_child(prof)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 14)
	prof.add_child(ph)
	ph.add_child(_bubble("user-circle", C_TEAL, 34, 9))
	var who := _vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	ph.add_child(who)
	if _renaming:
		var e := _line_edit("rename", "New fisher name", Backend.display_name)
		e.custom_minimum_size.x = 260
		e.text_submitted.connect(func(_t): _do_rename())
		var rr := HBoxContainer.new()
		rr.add_theme_constant_override("separation", 8)
		rr.add_child(e)
		var ok: Button = m.btn("Saving…" if Backend.renaming else "Save", C_TEAL, 14, 90)
		ok.disabled = Backend.renaming
		ok.pressed.connect(_do_rename)
		rr.add_child(ok)
		var cancel: Button = m.btn("Cancel", C_NEUTRAL, 14, 90)
		cancel.pressed.connect(func(): _renaming = false; Backend.message = ""; m._render_panel())
		rr.add_child(cancel)
		who.add_child(rr)
	else:
		who.add_child(m.lbl(Backend.display_name if Backend.display_name != "" else "Fisher", 24))
		who.add_child(m.lbl("%s  ·  signed in" % Backend.email, 13, C_MUTED))
	if not _renaming:
		var rn: Button = m.btn("Change name", C_NEUTRAL, 14, 0)
		rn.disabled = busy
		rn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rn.pressed.connect(func(): _renaming = true; m._render_panel())
		ph.add_child(rn)
	var so: Button = m.btn("Signing out…" if Backend.op == "sign_out" else "Sign out", C_NEUTRAL, 14, 112)
	so.disabled = busy
	so.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	so.pressed.connect(func(): Backend.sign_out())
	_buttons["sign_out"] = so
	ph.add_child(so)
	# cloud save + leaderboard
	var g: GridContainer = m._grid(2)
	g.add_theme_constant_override("h_separation", 12)
	var cs := _box(C_PANEL2, 18)
	cs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(cs)
	var cv := _vbox(8)
	cs.add_child(cv)
	cv.add_child(_title_row("cloud-arrow-up", C_GOOD, "Cloud save"))
	_sync_label = m.lbl("", 15)
	_sync_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(_sync_label)
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_update_sync_label)
	_sync_label.add_child(tick)
	cv.add_child(_wrap("Uploads every minute while you play, and when you close the game.", 13, C_MUTED))
	var sv: Button = m.btn("Save now", C_TEAL, 15, 140)
	sv.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sv.disabled = busy
	sv.pressed.connect(func(): Backend.sync_now())
	_buttons["save_now"] = sv
	cv.add_child(sv)
	_update_sync_label()
	var lb := _box(C_PANEL2, 18)
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(lb)
	var lv := _vbox(8)
	lb.add_child(lv)
	lv.add_child(_title_row("trophy", C_GOLD, "Leaderboard"))
	if Backend.sync_state != "syncing" and _lb_stale(60.0):
		Backend.load_leaderboard.call_deferred()
	var rank: int = Backend.my_rank()
	var rt := "Checking your rank…"
	if Backend.lb_state == "ok":
		rt = ("You're #%d on the leaderboard" % (rank + 1)) if rank >= 0 else "Not in the top %d yet. Keep fishing!" % Backend.LEADERBOARD_SIZE
	elif Backend.lb_state == "error":
		rt = "Ranked by prestige, then level"
	lv.add_child(m.lbl(rt, 15))
	lv.add_child(m.lbl("This save: Lv %s  ·  P%d  ·  %s earned" % [VF.commas(VF.level), VF.prestige,
		m.money_str(int(VF.stats.get("money_earned", 0)))], 13, C_MUTED))
	var ob: Button = m.btn("View leaderboard", C_GOLD, 15, 160)
	ob.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ob.pressed.connect(func(): m._open_panel("account", "Leaderboard"))
	lv.add_child(ob)
	_status(m.panel_body)
	# rarely needed: delete
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var del: Button = m.btn("Click again to delete your account and cloud save" if _confirm_delete else "Delete account…", C_NEUTRAL, 12, 120)
	if _confirm_delete: del.add_theme_color_override("font_color", C_BAD)
	del.disabled = busy
	del.tooltip_text = "Deletes your account and cloud save for good. The save on this device stays."
	del.pressed.connect(_delete_pressed)
	row.add_child(del)
	m.panel_body.add_child(row)

func _do_rename() -> void:
	var n := _val("rename")
	if n.strip_edges() == Backend.display_name:
		_renaming = false
		m._render_panel()
		return
	await Backend.rename(n)
	if Backend.message_kind == "good":
		_renaming = false
		m._render_panel()

func _delete_pressed() -> void:
	if not _confirm_delete:
		_confirm_delete = true
		m._render_panel()
		m.get_tree().create_timer(4.0).timeout.connect(func():
			if _confirm_delete:
				_confirm_delete = false
				if _open(): m._render_panel())
		return
	_confirm_delete = false
	Backend.delete_account()

func _update_sync_label() -> void:
	if _sync_label == null or not is_instance_valid(_sync_label): return
	var B = Backend
	var t := "Not saved to the cloud yet."
	var c := C_MUTED
	match B.sync_state:
		"syncing":
			t = "Saving to the cloud…"
		"error":
			t = "Couldn't save: " + B.sync_error
			c = C_BAD
		"conflict":
			t = "Waiting for you to choose a save."
			c = C_GOLD
		"ok":
			var ago := int(Time.get_unix_time_from_system() - B.last_sync)
			var when := "just now" if ago < 10 else ("%d s ago" % ago if ago < 60 else ("%d min ago" % (ago / 60) if ago < 3600 else "%d h ago" % (ago / 3600)))
			t = "Saved " + when + (" · new progress uploads soon" if B.dirty else "")
			c = C_GOOD
	_sync_label.text = t
	_sync_label.add_theme_color_override("font_color", c)

# --------------------------------------------------------- reconnecting
func _reconnecting() -> void:
	var restoring: bool = Backend.op == "restore"
	var c := _center_card()
	var bub := _bubble("cloud-arrow-up", C_MUTED if not restoring else C_TEAL, 36, 14)
	bub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(bub)
	var t: Label = m.lbl("Connecting to your account…" if restoring else "You're offline", 24)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var who := "Signed in as %s (%s)." % [Backend.display_name, Backend.email] if Backend.display_name != "" else ""
	var s := _wrap(who + ("" if restoring else "  Your progress is saved on this device and uploads when you're back online."), 15, C_MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.custom_minimum_size.x = 480
	c.add_child(s)
	if not restoring:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		var again: Button = m.btn("Try again", C_TEAL, 15, 140)
		again.pressed.connect(func(): Backend.restore_session())
		row.add_child(again)
		var so: Button = m.btn("Sign out", C_NEUTRAL, 15, 120)
		so.pressed.connect(func(): Backend.sign_out())
		row.add_child(so)
		c.add_child(row)

# -------------------------------------------------------------- conflict
func _conflict() -> void:
	var cf: Dictionary = Backend.conflict
	var cloud: Dictionary = cf.cloud
	var local: Dictionary = cf.local
	var cloud_better: bool = not Backend.worse(cloud, local)
	m.panel_body.add_child(m.lbl("Which save do you want to keep?", 24))
	m.panel_body.add_child(_wrap("This device and your cloud save have different progress. Pick one: the other one is replaced. Nothing is uploaded until you choose.", 15, C_MUTED))
	var g: GridContainer = m._grid(2)
	g.add_theme_constant_override("h_separation", 14)
	g.add_child(_choice("cloud-arrow-up", "Cloud save", cloud, cloud_better, "Use cloud save", "use_cloud", true,
		_ago(str(cloud.get("updated_at", "")))))
	g.add_child(_choice("device-mobile", "This device", local, not cloud_better, "Keep this device", "keep_device", false, "the save you're playing now"))

func _choice(icon_name: String, title: String, s: Dictionary, best: bool, action: String, key: String, use_cloud: bool, sub: String) -> PanelContainer:
	var p := _box(Color.WHITE if best else C_PANEL2, 20, 2 if best else 0, C_GOOD if best else Color.TRANSPARENT)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _vbox(8)
	p.add_child(v)
	var top := _title_row(icon_name, C_TEAL if use_cloud else Color("#5b6d75"), title)
	if best:
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(sp)
		top.add_child(_chip("More progress", C_GOOD))
	v.add_child(top)
	var big := HBoxContainer.new()
	big.add_theme_constant_override("separation", 14)
	big.add_child(m.lbl("Lv %s" % VF.commas(int(s.level)), 30))
	var pl: Label = m.lbl("P%d" % int(s.prestige), 30, C_GOLD)
	big.add_child(pl)
	v.add_child(big)
	v.add_child(m.lbl("%s earned  ·  %s casts" % [m.money_str(int(s.money_earned)), VF.commas(int(s.trips))], 14, C_MUTED))
	v.add_child(m.lbl(sub, 13, C_MUTED))
	var b: Button = m.btn(action, C_GOOD if best else C_NEUTRAL, 16, 0)
	b.custom_minimum_size.y = 44
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func(): Backend.resolve_conflict(use_cloud))
	_buttons[key] = b
	v.add_child(b)
	return p

func _ago(iso: String) -> String:
	if iso.length() < 19: return "from your account"
	var t := Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	var ago := int(Time.get_unix_time_from_system() - t)
	if ago < 120: return "saved just now"
	if ago < 7200: return "saved %d min ago" % (ago / 60)
	if ago < 172800: return "saved %d h ago" % (ago / 3600)
	return "saved %d days ago" % (ago / 86400)

# ------------------------------------------------------------ leaderboard
func _leaderboard() -> void:
	var B = Backend
	if _lb_stale(30.0):
		B.load_leaderboard.call_deferred()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var tv := _vbox(0)
	tv.add_child(m.lbl("Top fishers", 22))
	tv.add_child(m.lbl("Ranked by prestige, then level", 13, C_MUTED))
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	var rf: Button = m.btn("Refreshing…" if B.lb_state == "loading" else "Refresh", C_NEUTRAL, 14, 110)
	rf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rf.disabled = B.lb_state == "loading"
	rf.pressed.connect(func(): B.load_leaderboard())
	head.add_child(rf)
	m.panel_body.add_child(head)
	if B.lb_state == "error":
		var e := _wrap(B.lb_error, 15, C_BAD)
		m.panel_body.add_child(e)
	elif B.leaderboard.is_empty():
		m.panel_body.add_child(m.lbl("Loading the leaderboard…" if B.lb_state in ["", "loading"] else "Nobody is on the board yet. Be the first!", 15, C_MUTED))
	else:
		m.panel_body.add_child(_lb_row(["#", "Fisher", "Prestige", "Level", "Total earned"], -1, false, true))
		var mine: int = B.my_rank() if B.state == "signed_in" else -1
		for i in B.leaderboard.size():
			var r: Variant = B.leaderboard[i]
			if not (r is Dictionary): continue
			m.panel_body.add_child(_lb_row([str(i + 1), str(r.get("display_name", "?")), "P%d" % int(r.get("prestige", 0)),
				"Lv " + VF.commas(int(r.get("level", 0))), m.money_str(float(r.get("money_earned", 0)))], i, i == mine, false))
		if B.state == "signed_in" and mine < 0:
			m.panel_body.add_child(_lb_row(["–", B.display_name, "P%d" % VF.prestige, "Lv " + VF.commas(VF.level),
				m.money_str(int(VF.stats.get("money_earned", 0)))], 99, true, false))
	if B.state != "signed_in":
		var cta := _box(Color("#e3f5f8"), 14)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		cta.add_child(h)
		h.add_child(_bubble("sign-in", C_TEAL, 20, 7))
		var l := _wrap("Sign in or create a free account to put your name on the board.", 15, C_TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		var b: Button = m.btn("Sign in", C_TEAL, 15, 120)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): m._open_panel("account", "Account"))
		h.add_child(b)
		m.panel_body.add_child(cta)

func _lb_row(cells: Array, idx: int, mine: bool, header: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var bg := Color(1, 1, 1, 0) if header else (Color("#e3f5f8") if mine else (C_PANEL2 if idx % 2 == 0 else Color(C_PANEL2, 0.45)))
	var sb: StyleBoxFlat = m.sbox(bg, 12, 2 if mine else 0, C_TEAL, 0)
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	sb.content_margin_top = 2 if header else 6
	sb.content_margin_bottom = 2 if header else 6
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var size := 12 if header else 16
	var col := C_MUTED if header else C_TEXT
	# rank: medal for the top three
	var rank := CenterContainer.new()
	rank.custom_minimum_size = Vector2(36, 0 if header else 28)
	if not header and idx >= 0 and idx < 3:
		var medal := PanelContainer.new()
		medal.add_theme_stylebox_override("panel", m.sbox(MEDALS[idx], 999, 0, Color.TRANSPARENT, 0))
		medal.custom_minimum_size = Vector2(26, 26)
		var n: Label = m.lbl(cells[0], 14, Color.WHITE)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		medal.add_child(n)
		rank.add_child(medal)
	else:
		rank.add_child(m.lbl(cells[0], size if header else 15, C_MUTED))
	h.add_child(rank)
	var name := HBoxContainer.new()
	name.add_theme_constant_override("separation", 8)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_child(m.lbl(cells[1], size, col))
	if mine:
		name.add_child(_chip("You", C_TEAL))
	h.add_child(name)
	var widths := [90, 100, 130]
	for i in 3:
		var c: Label = m.lbl(cells[i + 2], size if header else 15, col if i != 0 or header else (C_GOLD if cells[2] != "P0" else C_MUTED))
		c.custom_minimum_size.x = widths[i]
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(c)
	return p

# ================================================================ widgets
func _box(bg: Color, pad := 18, border := 0, border_col := Color.TRANSPARENT) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", m.sbox(bg, 18, border, border_col, pad))
	return p

func _vbox(sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

func _center_card() -> VBoxContainer:
	var outer := CenterContainer.new()
	outer.custom_minimum_size.y = 400
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.panel_body.add_child(outer)
	var v := _vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(v)
	return v

func _bubble(icon_name: String, color: Color, size := 22, pad := 8) -> CenterContainer:
	var c := CenterContainer.new()
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := PanelContainer.new()
	b.add_theme_stylebox_override("panel", m.sbox(color, int(size * 0.45 + pad), 0, Color.TRANSPARENT, pad))
	b.add_child(m.icon(m.ph(icon_name), size))
	c.add_child(b)
	return c

func _title_row(icon_name: String, color: Color, title: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(_bubble(icon_name, color, 20, 7))
	var l: Label = m.lbl(title, 19)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h

func _chip(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb: StyleBoxFlat = m.sbox(Color(color, 0.14), 999, 0, Color.TRANSPARENT, 0)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(m.lbl(text, 12, color.darkened(0.15)))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

func _check_row(text: String, color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var ic: TextureRect = m.icon(m.ph("check"), 16)
	ic.modulate = C_GOOD
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(m.lbl(text, 14, color))
	return h

func _wrap(text: String, size: int, color: Color) -> Label:
	var l: Label = m.lbl(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	return l

## a two-option pill switch (like the panel tabs)
func _segment(options: Array, current: String) -> PanelContainer:
	var track := PanelContainer.new()
	track.add_theme_stylebox_override("panel", m.sbox(Color("#e6eef1"), 999, 0, Color.TRANSPARENT, 4))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	track.add_child(h)
	for o in options:
		var on: bool = o[0] == current
		var b := Button.new()
		b.text = o[1]
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size.y = 34
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_stylebox_override("normal", m.sbox(Color.WHITE if on else Color(1, 1, 1, 0), 999, 0, Color.TRANSPARENT, 6, 4 if on else 0))
		b.add_theme_stylebox_override("hover", m.sbox(Color.WHITE if on else Color(1, 1, 1, 0.5), 999, 0, Color.TRANSPARENT, 6))
		b.add_theme_stylebox_override("pressed", m.sbox(Color.WHITE, 999, 0, Color.TRANSPARENT, 6))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, C_TEXT if on else C_MUTED)
		b.disabled = Backend.state == "busy"
		b.add_theme_stylebox_override("disabled", m.sbox(Color.WHITE if on else Color(1, 1, 1, 0), 999, 0, Color.TRANSPARENT, 6))
		if not on:
			b.pressed.connect(func(): AudioManager.play_click(); _set_mode(o[0]))
		h.add_child(b)
	return track

func _line_edit(key: String, placeholder: String, value: String, secret := false, kb := LineEdit.KEYBOARD_TYPE_DEFAULT) -> LineEdit:
	var e := LineEdit.new()
	e.name = key
	e.text = value
	e.placeholder_text = placeholder
	e.secret = secret
	e.secret_character = "●"
	e.virtual_keyboard_type = kb
	e.custom_minimum_size.y = 42
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.add_theme_font_size_override("font_size", 16)
	var n: StyleBoxFlat = m.sbox(Color("#f5f9fa"), 12, 1, Color("#d3dfe4"), 12)
	n.content_margin_top = 6
	n.content_margin_bottom = 6
	e.add_theme_stylebox_override("normal", n)
	var f: StyleBoxFlat = m.sbox(Color.TRANSPARENT, 12, 2, C_TEAL, 12)
	f.draw_center = false
	e.add_theme_stylebox_override("focus", f)
	var ro: StyleBoxFlat = n.duplicate()
	ro.bg_color = Color("#eef3f5")
	e.add_theme_stylebox_override("read_only", ro)
	e.add_theme_color_override("font_color", C_TEXT)
	e.add_theme_color_override("font_uneditable_color", C_MUTED)
	e.add_theme_color_override("font_placeholder_color", Color(C_MUTED, 0.55))
	e.add_theme_color_override("caret_color", C_TEAL)
	e.add_theme_color_override("selection_color", Color(C_TEAL, 0.25))
	e.editable = Backend.state != "busy"
	_fields[key] = e
	return e

## label + input in the form; Enter submits
func _field(key: String, label: String, placeholder: String, value: String, secret := false, kb := LineEdit.KEYBOARD_TYPE_DEFAULT) -> LineEdit:
	var v := _vbox(4)
	v.add_child(m.lbl(label, 13, C_MUTED))
	var e := _line_edit(key, placeholder, value, secret, kb)
	e.text_submitted.connect(func(_t): _submit())
	v.add_child(e)
	_form.add_child(v)
	return e

func _primary(text: String, color: Color) -> Button:
	var b: Button = m.btn(text, color, 17, 0)
	b.custom_minimum_size.y = 46
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = Backend.state == "busy"
	b.pressed.connect(_submit)
	_buttons["submit"] = b
	_form.add_child(b)
	return b

func _link(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", C_TEAL)
	b.add_theme_color_override("font_hover_color", C_TEAL.darkened(0.25))
	b.add_theme_color_override("font_pressed_color", C_TEAL.darkened(0.35))
	b.add_theme_color_override("font_disabled_color", Color(C_MUTED, 0.5))
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		var e := StyleBoxEmpty.new()
		e.content_margin_left = 2
		e.content_margin_right = 2
		b.add_theme_stylebox_override(s, e)
	b.disabled = Backend.state == "busy"
	b.pressed.connect(func(): AudioManager.play_click(); cb.call())
	return b

## the last message from Backend (errors in red), or what it is doing right now
func _status(parent: Control) -> void:
	var text: String = Backend.message
	var kind: String = Backend.message_kind
	if text == "": return
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var col: Color = C_BAD if kind == "error" else (C_GOOD if kind == "good" else C_TEAL.darkened(0.15))
	var ic: TextureRect = m.icon(m.ph("x" if kind == "error" else ("check" if kind == "good" else "chat-circle")), 16)
	ic.modulate = col
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var l := _wrap(text, 14, col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	parent.add_child(h)

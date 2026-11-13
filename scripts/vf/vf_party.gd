extends RefCounted
## Fish with friends, live (1.1). Make a party, send its 6-letter code to friends; everyone in it sees the others' boats
## sail in their bay, live, with purple name tags, and hears about their best catches ("Sam caught a Pufferfish!") and
## waves. No account needed. It's a Supabase Realtime broadcast channel per code (realtime:party-<code>, public, nothing
## stored on the server): messages hi (who you are), pos (where your boat is), catch, wave, bye. Everything that
## comes in is cleaned up first: names cut and stripped, fish checked against the game's own list, positions kept in
## the bay, at most MAX_FRIENDS friends and a few messages a second each.
## Test (two at once, tools/mock_supabase.py running):
##   godot --path . -- --capture=DIR --party-test --party-role=host --party-code=TEST42 --backend-url=... --backend-key=test
##   godot --path . -- --capture=DIR --party-test --party-role=guest --party-code=TEST42 --backend-url=... --backend-key=test

signal changed

const ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"     # (no 0/O, 1/I/L: codes get read out loud)
const CODE_LEN := 6
const MAX_FRIENDS := 7
const HELLO_EVERY := 15.0
const POS_EVERY := 0.5
const GONE_AFTER := 45.0
const BEAT_EVERY := 25.0
const RETRY := [3.0, 6.0, 12.0, 30.0]
const C_PARTY := Color("#7c5cd6")
const SAVE := "user://party.cfg"

var m                                   # vf_main
var code := ""                          # the party you're in, "" when none
var state := ""                         # "" | connecting | live | offline
var me_id := ""
var friends := {}                       # id -> {name, level, prestige, boats, hat, biome, pos, shown, seen, node, tag, label, top, said, msgs}
var _ws: WebSocketPeer
var _ref := 0
var _join_ref := ""
var _joined := false
var _beat := 0.0
var _hello := 0.0
var _pos_t := 0.0
var _sent_pos := Vector2.INF
var _sent_biome := ""
var _retry_in := -1.0
var _tries := 0
var _last := 0.0
var _catch_t := 0.0
var _known_fish := {}
var _rejoin := true
var got := {}                           # (tests: what came in)

func _init(main) -> void:
	m = main
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	me_id = "%08x" % rng.randi()
	for b in VFData.BIOMES:
		for f in VFData.BIOMES[b].get("fish", []): _known_fish[str(f)] = true
	VF.trip_done.connect(_on_trip)
	m.get_tree().process_frame.connect(_tick)
	_last = Time.get_ticks_msec() / 1000.0

# ------------------------------------------------------------------ joining
static func clean_code(s: String) -> String:
	var out := ""
	for ch in s.to_upper():
		if ALPHABET.contains(ch): out += ch
	return out.left(CODE_LEN)

func make() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var c := ""
	for i in CODE_LEN: c += ALPHABET[rng.randi_range(0, ALPHABET.length() - 1)]
	join(c)

## join a party by its code (true if the code looks right)
func join(c: String) -> bool:
	c = clean_code(c)
	if c.length() != CODE_LEN or not Backend.configured(): return false
	if code != "": leave(false)
	code = c
	var cfg := ConfigFile.new()
	cfg.set_value("party", "code", code)
	cfg.save(SAVE)
	_tries = 0
	_connect()
	changed.emit()
	return true

## the link that joins this party in a browser
func invite_link() -> String:
	return "https://foshfish.xyz/play?party=" + code

## web: the code of an invite link the page was opened with (and the link is tidied away, so a reload after leaving
## doesn't join again), else ""
func _link_code() -> String:
	if not OS.has_feature("web"): return ""
	var c: Variant = JavaScriptBridge.eval("""(function () {
	var p = new URLSearchParams(window.location.search); var c = p.get('party') || '';
	if (c) { p.delete('party'); var q = p.toString();
		window.history.replaceState(null, '', window.location.pathname + (q ? '?' + q : '') + window.location.hash); }
	return c; })()""", true)
	return clean_code(str(c)) if c != null else ""

func leave(forget := true) -> void:
	if state == "live":
		_cast("bye", {})
		_send("phx_leave", {})
		_ws.poll()
	if _ws: _ws.close()
	_ws = null
	state = ""
	_joined = false
	_retry_in = -1.0
	for id in friends.keys(): _drop(id, false)
	code = ""
	if forget: DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	changed.emit()

func _topic() -> String:
	return "realtime:party-" + code.to_lower()

func _connect() -> void:
	var base: String = Backend.url.replace("https://", "wss://").replace("http://", "ws://")
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 18
	var err := _ws.connect_to_url(base + "/realtime/v1/websocket?apikey=%s&vsn=1.0.0" % Backend.anon_key.uri_encode())
	state = "connecting" if err == OK else "offline"
	_joined = false
	if err != OK: _retry_in = RETRY[mini(_tries, RETRY.size() - 1)]
	changed.emit()

# ------------------------------------------------------------------ the wire
func _send(event: String, payload: Dictionary, topic := "") -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	_ref += 1
	_ws.send_text(JSON.stringify({"topic": topic if topic != "" else _topic(), "event": event, "payload": payload,
		"ref": str(_ref), "join_ref": _join_ref}))

## a message to everyone else in the party
func _cast(kind: String, data: Dictionary) -> void:
	if state != "live": return
	data["id"] = me_id
	_send("broadcast", {"type": "broadcast", "event": kind, "payload": data})

func _tick() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var dt := clampf(now - _last, 0.0, 0.1)
	_last = now
	if _rejoin:                                       # (back in the party you were in last time)
		_rejoin = false
		var link := _link_code()
		var cfg := ConfigFile.new()
		if link != "":                                # (an invite link: foshfish.xyz/play?party=ABC123)
			if join(link): m._toast("You joined the party %s! Your friends' boats sail in when you're in the same biome." % link, "quest")
		elif cfg.load(SAVE) == OK and str(cfg.get_value("party", "code", "")) != "" and not "--party-test" in OS.get_cmdline_user_args():
			join(str(cfg.get_value("party", "code", "")))
	if code == "": return
	_net(dt)
	_draw(dt)

func _net(dt: float) -> void:
	if _retry_in >= 0.0:
		_retry_in -= dt
		if _retry_in < 0.0: _connect()
		return
	if _ws == null: return
	_ws.poll()
	var rs := _ws.get_ready_state()
	if rs == WebSocketPeer.STATE_OPEN:
		if not _joined:
			_joined = true
			_ref += 1
			_join_ref = str(_ref)
			_ws.send_text(JSON.stringify({"topic": _topic(), "event": "phx_join", "ref": _join_ref, "join_ref": _join_ref,
				"payload": {"config": {"broadcast": {"self": false, "ack": false}, "presence": {"key": ""}, "private": false}}}))
		while _ws.get_available_packet_count() > 0:
			_on_text(_ws.get_packet().get_string_from_utf8())
		_beat -= dt
		if _beat <= 0.0:
			_beat = BEAT_EVERY
			_send("heartbeat", {}, "phoenix")
		if state == "live": _live(dt)
	elif rs == WebSocketPeer.STATE_CLOSED:
		_ws = null
		state = "offline"
		_retry_in = RETRY[mini(_tries, RETRY.size() - 1)]
		_tries += 1
		changed.emit()

func _on_text(s: String) -> void:
	var msg: Variant = JSON.parse_string(s)
	if not (msg is Dictionary): return
	var ev := str(msg.get("event", ""))
	var pl: Variant = msg.get("payload", {})
	if ev == "phx_reply" and str(msg.get("ref", "")) == _join_ref and str(msg.get("topic", "")) == _topic():
		if pl is Dictionary and str(pl.get("status", "")) == "ok":
			state = "live"
			_tries = 0
			_hello = 0.0
			_sent_pos = Vector2.INF
		else:
			state = "offline"
			if _ws: _ws.close()
		changed.emit()
	elif ev == "broadcast" and pl is Dictionary:
		_on_cast(str(pl.get("event", "")), pl.get("payload", {}))
	elif ev in ["phx_error", "phx_close"] and str(msg.get("topic", "")) == _topic():
		if _ws: _ws.close()

## what you are, where you are, what you caught
func _live(dt: float) -> void:
	_hello -= dt
	if _hello <= 0.0:
		_hello = HELLO_EVERY
		_cast("hi", {"name": VF.player_name, "level": VF.level, "prestige": VF.prestige, "boats": VF.boats_owned,
			"hat": VF.hat, "biome": VF.biome, "x": roundi(m.stage.boat_pos.x), "y": roundi(m.stage.boat_pos.y)})
	_pos_t -= dt
	if _pos_t <= 0.0:
		_pos_t = POS_EVERY
		var p: Vector2 = m.stage.boat_pos
		if p.distance_to(_sent_pos) > 4.0 or VF.biome != _sent_biome:
			_sent_pos = p
			_sent_biome = VF.biome
			_cast("pos", {"x": roundi(p.x), "y": roundi(p.y), "biome": VF.biome})
	_catch_t -= dt
	for id in friends.keys():
		if Time.get_ticks_msec() / 1000.0 - float(friends[id].seen) > GONE_AFTER: _drop(id, true)

func _on_trip(res: Dictionary) -> void:
	if state != "live" or _catch_t > 0.0: return
	var new: Array = res.get("new_species", [])
	if not new.is_empty():
		_catch_t = 4.0
		_cast("catch", {"fish": str(new[0]), "new": true})

func wave() -> void:
	_cast("wave", {})
	m._toast("You waved at the party!", "quest")

# ------------------------------------------------------------------ what comes in
static func clean_name(s: String) -> String:
	var out := ""
	for ch in s.strip_edges():
		if ch.unicode_at(0) >= 32 and ch.unicode_at(0) != 127: out += ch
	out = out.strip_edges().left(20)
	return out if out != "" else "Fisher"

func _on_cast(kind: String, d: Variant) -> void:
	if not (d is Dictionary): return
	var id := str(d.get("id", "")).left(16)
	if id == "" or id == me_id: return
	var now := Time.get_ticks_msec() / 1000.0
	if friends.has(id):                               # (a few messages a second, no more)
		var f: Dictionary = friends[id]
		f.msgs = (f.msgs as Array).filter(func(t): return now - t < 1.0)
		if f.msgs.size() >= 8: return
		f.msgs.append(now)
	match kind:
		"hi":
			if not friends.has(id):
				if friends.size() >= MAX_FRIENDS: return
				friends[id] = {"msgs": [now], "pos": Vector2.INF, "shown": Vector2.INF, "said": 0.0}
				m._toast("%s joined the party!" % clean_name(str(d.get("name", ""))), "quest")
			var f: Dictionary = friends[id]
			var was_boats := int(f.get("boats", 0))
			f.name = clean_name(str(d.get("name", "")))
			f.level = clampi(int(d.get("level", 1)), 1, 100000)
			f.prestige = clampi(int(d.get("prestige", 0)), 0, 1000)
			f.boats = clampi(int(d.get("boats", 1)), 1, VFData.BOAT_ORDER.size())
			f.hat = str(d.get("hat", "straw")).left(24)
			f.biome = str(d.get("biome", "")) if VFData.BIOMES.has(str(d.get("biome", ""))) else "River"
			f.seen = now
			_set_pos(f, d)
			if was_boats != 0 and was_boats != f.boats: _unshow(f)     # (a new boat: draw it again)
			got["hi"] = true
			changed.emit()
		"pos":
			if not friends.has(id): return
			var f: Dictionary = friends[id]
			f.seen = now
			if VFData.BIOMES.has(str(d.get("biome", ""))): f.biome = str(d.biome)
			_set_pos(f, d)
		"catch":
			if not friends.has(id): return
			var fish := str(d.get("fish", ""))
			var f: Dictionary = friends[id]
			f.seen = now
			m._toast(("%s caught a %s!" % [f.name, fish]) if _known_fish.has(fish) else ("%s caught something good!" % f.name), "quest")
			got["catch"] = true
		"wave":
			if not friends.has(id): return
			var f: Dictionary = friends[id]
			f.seen = now
			f.said = 3.0
			m._toast("%s waves at you!" % f.name, "quest")
			got["wave"] = true
		"bye":
			if friends.has(id): _drop(id, true)

func _set_pos(f: Dictionary, d: Dictionary) -> void:
	if d.has("x") and d.has("y"):
		f.pos = Vector2(clampf(float(d.x), 0.0, 1920.0), clampf(float(d.y), 0.0, 1080.0))

func _drop(id: String, say: bool) -> void:
	var f: Dictionary = friends[id]
	_unshow(f)
	friends.erase(id)
	if say: m._toast("%s left the party." % f.get("name", "A friend"), "quest")
	changed.emit()

# ------------------------------------------------------------------ their boats in your bay
func _unshow(f: Dictionary) -> void:
	if f.get("node") != null and is_instance_valid(f.node): f.node.queue_free()
	if f.get("tag") != null and is_instance_valid(f.tag): f.tag.queue_free()
	f.node = null
	f.tag = null

func _tag_text(f: Dictionary) -> String:
	return "%s  ·  Lv %s" % [f.name, VF.commas(int(f.level))] if float(f.get("said", 0.0)) <= 0.0 else "%s waves!" % f.name

## where to draw a friend: where they are, unless that's on top of your boat (everyone starts at the same spot):
## then a spot beside yours that stays theirs
func _where(id: String, f: Dictionary) -> Vector2:
	var p: Vector2 = f.pos
	var st = m.stage
	if p == Vector2.INF: p = st.boat_pos
	if p.distance_to(st.boat_pos) > 260.0 and st._in_water(p, 0.05): return p
	if f.has("beside") and (f.beside as Vector2).distance_to(st.boat_pos) > 260.0: return f.beside
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id + st._biome)
	for _i in 300:
		var q: Vector2 = st.boat_pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(300.0, 460.0)
		if q.x > 200 and q.x < 1720 and q.y > 160 and q.y < 920 and st._in_water(q, 0.1):
			f.beside = q
			return q
	return st.boat_pos + Vector2(320, 60)

func _draw(dt: float) -> void:
	var st = m.stage
	if st == null or m.visitors == null: return
	for id in friends:
		var f: Dictionary = friends[id]
		if not f.has("name"): continue
		if f.biome != VF.biome:
			_unshow(f)
			continue
		var to := _where(id, f)
		if f.get("node") == null or not is_instance_valid(f.node):
			var bb: Dictionary = m.visitors.build_boat(VFData.BOAT_ORDER[int(f.boats) - 1], _tag_text(f), Color(C_PARTY, 0.85), false, randf() * 50.0)
			if bb.is_empty(): continue
			f.node = bb.node
			f.tag = bb.tag
			f.label = bb.label
			f.top = bb.top
			f.shown = to
		var cur: Vector2 = f.shown
		var step := to - cur
		var go := minf(step.length(), 240.0 * dt)
		if go > 0.5:
			var flip := step.x < -2.0
			var r: TextureRect = f.node
			if abs(step.x) > 2.0 and flip != r.flip_h:
				r.flip_h = flip
				for c in r.get_children():
					if c is TextureRect: c.flip_h = flip
				f.top = Vector2(r.size.x - (f.top as Vector2).x, (f.top as Vector2).y)
			cur += step.normalized() * go
		f.shown = cur
		var node: TextureRect = f.node
		var bob := Vector2(sin(st._t * 0.9 + hash(id) % 7) * 4.0, sin(st._t * 1.4 + hash(id) % 5) * 2.5)
		node.position = cur + bob - node.pivot_offset
		node.rotation = sin(st._t * 0.8 + hash(id) % 3) * 0.03
		if f.said > 0.0: f.said = float(f.said) - dt
		var label: Label = f.label
		label.text = _tag_text(f)
		var tag: PanelContainer = f.tag
		tag.reset_size()
		tag.position = node.position + (f.top as Vector2) - Vector2(tag.size.x * 0.5, tag.size.y + 4.0)

# ------------------------------------------------------------------ the panel (Menu -> Friends)
func panel() -> void:
	var body: VBoxContainer = m.panel_body
	if not changed.is_connected(_rerender): changed.connect(_rerender)
	if code == "":
		var intro: Label = m.lbl("Make a party and send its code to your friends. When they join, their boats sail in your bay, live, and you see what they catch. No account needed.", 15, m.C_TEXT)
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(intro)
		var mk: Button = m._act("Make a party", C_PARTY, func(): make(); return "")
		mk.custom_minimum_size = Vector2(240, 52)
		body.add_child(mk)
		body.add_child(m.lbl("Got a code from a friend?", 15, m.C_TEXT))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var edit := LineEdit.new()
		edit.placeholder_text = "ABC123"
		edit.max_length = CODE_LEN
		edit.custom_minimum_size = Vector2(170, 48)
		edit.add_theme_font_size_override("font_size", 22)
		row.add_child(edit)
		var jb: Button = m._act("Join", C_PARTY, func(): return "" if join(edit.text) else "That code doesn't look right: 6 letters and numbers.")
		jb.custom_minimum_size = Vector2(120, 48)
		row.add_child(jb)
		edit.text_submitted.connect(func(t):
			if not join(t): m._toast("That code doesn't look right: 6 letters and numbers.", "warn"))
		body.add_child(row)
		var note: Label = m.lbl("Anyone with a code can join its party, so share it with friends only.", 13, m.C_MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(note)
		return
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.add_child(m.lbl("Your party:", 18, m.C_TEXT))
	head.add_child(m.lbl(code, 34, C_PARTY))
	var cp: Button = m._act("Copy code", m.C_NEUTRAL, func():
		DisplayServer.clipboard_set("Fish with me in fosh&fish! Party code: %s  %s" % [code, invite_link()])
		return "")
	cp.pressed.connect(func(): m._toast("Copied: send it to your friends.", "quest"))
	head.add_child(cp)
	body.add_child(head)
	var here := 0
	for id in friends:
		if friends[id].get("biome", "") == VF.biome: here += 1
	var line: String = {"connecting": "Connecting...", "offline": "Offline: trying again in a moment.",
		"live": ("Live. %d friend%s in the party%s." % [friends.size(), "" if friends.size() == 1 else "s",
			(", %d here in the %s" % [here, VF.biome]) if friends.size() > 0 else ": send them the code!"])}.get(state, "")
	body.add_child(m.lbl(line, 15, m.C_GOOD if state == "live" else m.C_MUTED))
	for id in friends:
		var f: Dictionary = friends[id]
		if not f.has("name"): continue
		var where := "here" if f.biome == VF.biome else "in the %s" % f.biome
		body.add_child(m.lbl("%s  ·  Lv %s%s  ·  %s" % [f.name, VF.commas(int(f.level)), ("  ·  P%d" % int(f.prestige)) if int(f.prestige) > 0 else "", where], 16, m.C_TEXT))
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	var wv: Button = m._act("Wave", C_PARTY, func(): wave(); return "", state == "live" and not friends.is_empty())
	row2.add_child(wv)
	row2.add_child(m._act("Leave the party", m.C_NEUTRAL, func(): leave(); return ""))
	body.add_child(row2)
	var tip: Label = m.lbl("Sail to the same biome to see each other's boats. Your party is still here the next time you play, until you leave it.", 13, m.C_MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(tip)

func _rerender() -> void:
	if m._panel_kind == "party" and m.overlay.visible: m._render_panel()

# ------------------------------------------------------------------ test
func test(dir: String) -> void:
	VF.autosave = false
	var role := "host"
	var c := "TEST42"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--party-role="): role = a.substr(13)
		if a.begins_with("--party-code="): c = a.substr(13)
	m._veteran("River")
	VF.tutorial = 99
	VF.player_name = "Host Hal" if role == "host" else "Guest Gail"
	m._close_panel()
	m._apply_biome()
	await m.get_tree().create_timer(1.0).timeout
	join(c)
	var t := 0.0
	while state != "live" and t < 10.0:
		await m.get_tree().process_frame
		t += m.get_process_delta_time()
	print("PARTY %s %s is live (%s)" % ["PASS" if state == "live" else "FAIL", role, state])
	if role == "guest":
		await m.get_tree().create_timer(4.0).timeout
		_cast("catch", {"fish": VFData.BIOMES["River"].fish.back()})
		await m.get_tree().create_timer(1.0).timeout
		wave()
		await m.get_tree().create_timer(8.0).timeout
		leave()
		await m.get_tree().create_timer(0.5).timeout
		return
	t = 0.0
	while (not got.has("catch") or friends.is_empty()) and t < 30.0:
		await m.get_tree().process_frame
		t += m.get_process_delta_time()
	await m.get_tree().create_timer(2.0).timeout
	await m._shot(dir + "/party_0_bay.png")
	var shown := false
	for id in friends:
		if friends[id].get("node") != null and is_instance_valid(friends[id].node): shown = true
	print("PARTY %s a friend joined and their boat sails in your bay" % ("PASS" if shown else "FAIL"))
	print("PARTY %s their catch came through" % ("PASS" if got.has("catch") else "FAIL"))
	m._open_panel("party")
	await m.get_tree().create_timer(0.6).timeout
	await m._shot(dir + "/party_1_panel.png")
	t = 0.0
	while not friends.is_empty() and t < 20.0:
		await m.get_tree().process_frame
		t += m.get_process_delta_time()
	print("PARTY %s they waved and left" % ("PASS" if got.has("wave") and friends.is_empty() else "FAIL"))
	leave()

extends RefCounted
## Collecting, on screen (vf_main): the WANTED pill and board (Gerald), the Fish Book's Finds tab and its stamps, the
## Achievements and the Aquarium (Menu), the Shop's Hats tab, the aquarium's line on the welcome-back card.
## Built with vf_main's UI kit (sbox, lbl, btn, icon, ph, tex, _card, _act, _grid, money_str).
## The rules live in VF (vf_game.gd: Gerald, Finds, Collecting, Hats), the data in VFData. docs/MISSING_LIST.md parts 3 to 6.

const C_TEXT := Color("#2b3a40")
const C_MUTED := Color("#6d7c7d")
const C_GOOD := Color("#2c9a73")
const C_GOLD := Color("#c98b1c")
const C_TEAL := Color("#238b9c")
const C_PANEL2 := Color("#efe9dc")          # (vf_main.C_PANEL2: cards inside panels)
const PAPER := Color("#e6cf9c")             # the WANTED posters, like the mini-game's (vf_minigame.gd _draw_poster)
const PAPER_EDGE := Color("#a8854d")
const BROWN := Color("#5a3d1a")
const STAMP := Color("#c0392b")
const INK := Color("#22313a")
## The Most Wanted: a different outlaw for every stage (docs/MISSING_LIST.md part 3). What their poster says they were up to,
## and what they're like in the aquarium once they're caught.
const UP_TO := {"River": "sulking", "Volcanic": "setting things on fire", "Ocean": "stealing other people's treasure",
	"Sky": "doing loop-the-loops", "Space": "eating a satellite", "Alien": "waving all its tentacles", "Abyss": "by the light of her chandelier"}
const IN_THE_TANK := {"River": "Still sulking.", "Volcanic": "The water's warmer now.", "Ocean": "Says this tank is his ship now.",
	"Sky": "Keeps trying to fly.", "Space": "Has eaten two of the plants.", "Alien": "Waves. With everything.", "Abyss": "Has asked to see the manager."}

var m                                 # vf_main
var wanted_pill: PanelContainer
var _wanted_lbl: Label
var _wanted_face: Control
var _tank: Control
var _swim := []                       # the aquarium's fish: {f, x, y, v, ph, k, flee}
var _say := {}                        # what the tapped one's card says: {f, text, t}
var _tank_ms := 0


func _init(main) -> void:
	m = main
	VF.changed.connect(refresh_pill)


func _rerender(kinds: Array) -> void:
	if m.overlay.visible and m._panel_kind in kinds:
		m._render_panel()


# ===================================================================== HUD
## WANTED: Gerald · Volcanic, in the left column once you've met him (tap: the board). It fades with the rest of it.
func build_hud() -> void:
	wanted_pill = PanelContainer.new()
	wanted_pill.add_theme_stylebox_override("panel", m.pill_box(false, 10, 4))
	wanted_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	wanted_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	wanted_pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	wanted_pill.tooltip_text = "The WANTED board"
	wanted_pill.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			AudioManager.play_click()
			m._open_panel("wanted"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	_wanted_face = Control.new()
	_wanted_face.custom_minimum_size = Vector2(26, 22)
	_wanted_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wanted_face.draw.connect(func(): _draw_portrait(_wanted_face, _look(int(VF.gerald.stage)), Vector2(13, 11), 30.0))
	h.add_child(_wanted_face)
	_wanted_lbl = m.lbl("", 13, Color.WHITE)
	h.add_child(_wanted_lbl)
	wanted_pill.add_child(h)
	m.hud_col.add_child(wanted_pill)
	refresh_pill()


func refresh_pill() -> void:
	if wanted_pill == null: return
	var g: Dictionary = VF.gerald_info()
	wanted_pill.visible = g.met and not g.done
	if wanted_pill.visible:
		_wanted_lbl.text = "WANTED: %s · %s" % [g.who, g.biome]
		_wanted_face.queue_redraw()


## which picture a stage's outlaw has: its look once that's drawn, else plain Gerald
func _look(i: int) -> String:
	var row: Dictionary = VFData.GERALD[clampi(i, 0, VFData.GERALD.size() - 1)]
	var look := String(VF.gerald_info(i).get("look", row.get("look", "")))
	if look != "" and m.stage.manifest.get("mini", {}).get("fish", {}).has(look) and m.tex("mini/%s.png" % VFData.slug(look)) != null:
		return look
	return "Gerald"


## run 2's outlaws are a surprise until the end of run 1 is caught (the Baron): a "?" on the board
func _secret(i: int) -> bool:
	var at := int(VF.gerald.stage)
	for f in i:
		if VFData.GERALD[f].get("final", false) and at <= f: return true
	return false


## who's portrait from their mini-game sheet, with the eyes the mini-game gives them (the art has none). dim: a silhouette
func _draw_portrait(c: CanvasItem, who: String, at: Vector2, px: float, dim := false) -> void:
	var t: Texture2D = m.tex("mini/%s.png" % VFData.slug(who))
	if t == null: return
	var cell := float(t.get_height())                    # (one row of square frames)
	c.draw_texture_rect_region(t, Rect2(at - Vector2(px, px) * 0.5, Vector2(px, px)), Rect2(0, 0, cell, cell),
		Color(0.16, 0.11, 0.05, 0.55) if dim else Color.WHITE)
	if dim: return
	var info: Dictionary = m.stage.manifest.get("mini", {}).get("fish", {}).get(who, {})
	if info.is_empty(): return
	var e := at + (Vector2(info.eye[0], info.eye[1]) - Vector2(0.5, 0.5)) * px
	var er := maxf(float(info.er) * px * 1.9, 2.2)
	var w := maxf(1.0, er * 0.22)
	# unimpressed: half-closed, looking at you (vf_minigame.gd _draw_fish, "smug")
	c.draw_circle(e, er, Color.WHITE)
	var pr := er * 0.48
	c.draw_circle(e + Vector2(0.9, 0.2).normalized() * (er - pr - w * 0.6), pr, INK)
	c.draw_arc(e, er, 0, TAU, 24, INK, w, true)
	var lid := PackedVector2Array()
	for i in 11:
		lid.append(e + Vector2.from_angle(PI + PI * i / 10.0) * (er + w * 0.2))
	c.draw_colored_polygon(lid, Color(0.12, 0.16, 0.2, 0.5))
	c.draw_line(e + Vector2(-er - w * 0.4, -w * 0.4), e + Vector2(er + w * 0.4, -w * 0.4), INK, w, true)


# =============================================================== the board
## Menu (or the pill) -> Wanted: one poster per stage of Gerald's run, then his mum's. Stamped once it's behind you.
func panel_wanted() -> void:
	var g: Dictionary = VF.gerald_info()
	var line := ""
	if g.done:
		line = "You caught every one of them. The board's yours now. Frame it."
	elif not g.met:
		line = "Someone's been asking about you. A fish. A grumpy one, with a moustache."
	else:
		line = "%s is wanted in %s, from level %s. Win the round and that's them caught for good, and the bounty's yours. Then the next one turns up." % [g.who,
			VFData.GERALD_PLACES.get(g.biome, g.biome), VF.commas(g.level)]
	var l: Label = m.lbl(line, 15, C_MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.panel_body.add_child(l)
	var grid: GridContainer = m._grid(4)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for i in VFData.GERALD.size():
		var p := Control.new()
		p.custom_minimum_size = Vector2(196, 284)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		p.draw.connect(_draw_poster.bind(p, i))
		grid.add_child(p)


func _draw_poster(c: Control, i: int) -> void:
	var row: Dictionary = VFData.GERALD[i]
	var g: Dictionary = VF.gerald_info(i)
	var at := int(VF.gerald.stage)
	var now: bool = i == at
	var secret := _secret(i)
	var later: bool = i > at and not secret
	var font: Font = c.get_theme_default_font()
	var w := minf(c.size.x, 208.0)
	var h := c.size.y
	var tilt := 0.03 if i % 2 == 0 else -0.025
	c.draw_set_transform(c.size * 0.5, tilt, Vector2.ONE)
	var r := Rect2(-w * 0.5 + 4.0, -h * 0.5 + 4.0, w - 8.0, h - 8.0)
	c.draw_style_box(m.sbox(Color(0, 0, 0, 0.16), 8, 0, Color.TRANSPARENT, 0), Rect2(r.position + Vector2(5, 7), r.size))
	c.draw_style_box(m.sbox(PAPER.lerp(Color("#f3e6c5"), 0.35) if later or secret else PAPER, 6, 2, PAPER_EDGE, 0), r)
	if now and not g.done:                              # the one you're after: pinned up
		c.draw_circle(Vector2(0, r.position.y + 10.0), 7.0, Color("#d6453a"))
		c.draw_circle(Vector2(-2, r.position.y + 8.0), 2.2, Color(1, 1, 1, 0.6))
	var x := r.position.x
	var cw := r.size.x
	c.draw_string(font, Vector2(x, r.position.y + 46.0), "WANTED", HORIZONTAL_ALIGNMENT_CENTER, cw, 30, BROWN)
	var face_at := Vector2(0, r.position.y + 112.0)
	if secret:
		c.draw_string(font, Vector2(x, face_at.y + 18.0), "?", HORIZONTAL_ALIGNMENT_CENTER, cw, 64, Color(BROWN, 0.45))
	else:
		_draw_portrait(c, _look(i), face_at, 132.0, later)
	var ink := BROWN if not later else Color(BROWN, 0.6)
	c.draw_string(font, Vector2(x, r.position.y + 196.0), "???" if secret else String(row.who), HORIZONTAL_ALIGNMENT_CENTER, cw, 22, ink)
	# where, and what they were up to (two lines at most)
	var where := "Somewhere out there" if secret else "Last seen: %s, %s" % [VFData.GERALD_PLACES.get(row.biome, row.biome), UP_TO.get(row.biome, "up to no good")]
	c.draw_multiline_string(font, Vector2(x + 8.0, r.position.y + 216.0), where, HORIZONTAL_ALIGNMENT_CENTER, cw - 16.0, 13, 2, Color(ink, 0.85))
	var foot := "From level %s" % VF.commas(int(row.level)) if later or secret else "Reward %s" % m.money_str(int(g.bounty))
	c.draw_string(font, Vector2(x, r.position.y + 260.0), foot, HORIZONTAL_ALIGNMENT_CENTER, cw, 15, C_GOLD.darkened(0.25) if not later else Color(ink, 0.7))
	if g.done:                                         # a rubber stamp over the picture's lower edge: the name and the caption stay readable
		var word := "CAUGHT!"
		c.draw_set_transform(c.size * 0.5 + Vector2(0, r.position.y + 150.0).rotated(tilt), tilt - 0.2, Vector2.ONE)
		var sr := Rect2(-66, -20, 132, 40)
		c.draw_style_box(m.sbox(Color(PAPER, 0.8), 7, 3, Color(STAMP, 0.9), 0), sr)
		c.draw_string(font, Vector2(sr.position.x, 9), word, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 25, STAMP)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# =============================================================== Fish Book
## Fish Book -> Finds: the 21 residents to find while sailing, three a biome. Silhouettes for the ones you haven't found.
func tab_finds() -> void:
	var head: Label = m.lbl("Residents found: %d of %d" % [VF.finds.size(), VFData.finds_total()], 18)
	m.panel_body.add_child(head)
	var tip: Label = m.lbl("Every biome has three, away from the shop. Sail close and tap one. The third one's rarer.", 13, C_MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.panel_body.add_child(tip)
	for b in VFData.BIOME_ORDER:
		if not VFData.FINDS.has(b): continue
		var here: Dictionary = VFData.FINDS[b]
		var got := 0
		for id in here:
			if VF.finds.has(id): got += 1
		m.panel_body.add_child(m.lbl("%s   %d / %d" % [b, got, here.size()], 16, C_TEXT if got > 0 else C_MUTED))
		var g: GridContainer = m._grid(3)
		for id in here:
			var d: Dictionary = here[id]
			var n := int(VF.finds.get(id, 0))
			var t: Texture2D = m.tex("life/find_%s.png" % id)
			var right: Control = null
			if n > 1: right = m.lbl("×%s" % VF.commas(n), 14, C_MUTED)
			elif n == 0 and d.rare: right = _chip("Rare", C_GOLD)
			var desc: String = d.line if n > 0 else "Somewhere in %s." % VFData.GERALD_PLACES.get(b, b)
			var card: PanelContainer = m._card(t if t else m.ph("question"), d.name if n > 0 else "???", desc, right, false, 56)
			if n == 0:
				var ic: Control = card.get_child(0).get_child(0)
				ic.modulate = Color(0.1, 0.12, 0.18, 0.5)          # a silhouette, like the fish you haven't caught
			m._add_to(g, card)


func _chip(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", m.sbox(Color(color, 0.16), 999, 0, Color.TRANSPARENT, 4))
	p.add_child(m.lbl(text, 12, color.darkened(0.2)))
	return p


## Fish Book -> Fish: a stamp for every biome whose fish you've all caught (+5% money there, for good)
func book_stamps() -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	var pct := int(round(VFData.BOOK_BONUS * 100.0))
	for b in VFData.BIOME_ORDER:
		var fish: Array = VFData.BIOMES[b].fish
		var got := 0
		for f in fish:
			if VF.discovered.has(f): got += 1
		var done: bool = VF.book_done(b)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", m.sbox(Color(C_GOLD, 0.2) if done else C_PANEL2, 999, 2 if done else 0, Color(C_GOLD, 0.7), 6))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		if done:
			var ic: TextureRect = m.icon(m.ph("check"), 16)
			ic.modulate = C_GOLD.darkened(0.2)
			h.add_child(ic)
		h.add_child(m.lbl("%s  +%d%% money" % [b, pct] if done else "%s  %d / %d" % [b, got, fish.size()], 13, C_GOLD.darkened(0.3) if done else C_MUTED))
		p.add_child(h)
		p.tooltip_text = ("Every %s fish is in your Fish Book: +%d%% money there, for good." if done else "Catch every %s fish for its stamp: +%d%% money there, for good.") % [b, pct]
		flow.add_child(p)
	m.panel_body.add_child(flow)


# ============================================================ achievements
## Menu -> Achievements: goals and jokes, a few Pearls each. Ready ones first, then the closest, claimed ones last.
func panel_achievements() -> void:
	var ready: Array = VF.ach_ready()
	var head := HBoxContainer.new()
	var l: Label = m.lbl("%d of %d done" % [VF.ach_claimed.size(), VFData.ACHIEVEMENTS.size()] + ("   ·   %d ready to claim!" % ready.size() if ready.size() > 0 else ""), 17,
		C_GOOD if ready.size() > 0 else C_TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	head.add_child(m.icon(m.icon_for("ui", "pearl"), 24))
	head.add_child(m.lbl("%s Pearls" % VF.commas(VF.pearls), 15, C_TEXT))
	m.panel_body.add_child(head)
	var list: Array = VFData.ACHIEVEMENTS.duplicate()
	list.sort_custom(func(a, b): return _ach_rank(a, ready) < _ach_rank(b, ready))
	var g: GridContainer = m._grid(2)
	for a in list:
		m._add_to(g, _ach_card(a, a.id in ready))


func _ach_rank(a: Dictionary, ready: Array) -> float:
	if a.id in ready: return 0.0
	if VF.ach_claimed.has(a.id): return 3.0
	return 2.0 - clampf(float(VF.stat_value(a.stat)) / float(a.goal), 0.0, 0.999)


func _ach_card(a: Dictionary, ready: bool) -> PanelContainer:
	var done: bool = VF.ach_claimed.has(a.id)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", m.sbox(Color(C_GOOD, 0.12) if ready else C_PANEL2, 12, 2 if ready else 0, Color(C_GOOD, 0.6), 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var joke: bool = a.get("joke", false)
	var ic: TextureRect = m.icon(m.ph("chat-circle") if joke else m.icon_for("ui", "star"), 40)
	if joke: ic.modulate = C_TEAL
	if not ready and not done: ic.modulate = Color(ic.modulate, 0.45)
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.add_child(m.lbl(a.name, 16))
	var d: Label = m.lbl(a.desc, 12, C_MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	var have := mini(VF.stat_value(a.stat), int(a.goal))
	if not done:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 6
		bar.max_value = float(a.goal)
		bar.value = float(have)
		bar.add_theme_stylebox_override("background", m.sbox(Color(0, 0, 0, 0.08), 999, 0, Color.TRANSPARENT, 0))
		bar.add_theme_stylebox_override("fill", m.sbox(C_GOOD if ready else C_TEAL, 999, 0, Color.TRANSPARENT, 0))
		v.add_child(bar)
	h.add_child(v)
	var right: Control
	if ready:
		var b: Button = m.btn("Claim +%d" % int(a.pearls), C_GOOD, 14, 104)
		b.pressed.connect(func(): claim(a.id))
		right = b
	elif done:
		var ok := HBoxContainer.new()
		var ck: TextureRect = m.icon(m.ph("check"), 16)
		ck.modulate = C_GOOD
		ok.add_child(ck)
		ok.add_child(m.lbl("+%d" % int(a.pearls), 13, C_GOOD))
		right = ok
	else:
		right = m.lbl("%s / %s" % [VF.fmt(have), VF.fmt(int(a.goal))], 13, C_MUTED)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(right)
	return p


func claim(id: String) -> void:
	var pay: int = VF.ach_claim(id)
	if pay <= 0: return
	AudioManager.play_fun("ach")
	m._toast("%s: +%d Pearls" % [VFData.ach_def(id).name, pay], "unlock")
	refresh_badges()
	_rerender(["achievements", "menu"])


## the Menu's badge: achievements waiting to be claimed (FishTok's goes on the Phone)
func refresh_badges() -> void:
	if m.menu_btn: m.pill_badge(m.menu_btn, VF.ach_ready().size())


# ================================================================ aquarium
## Menu -> Aquarium: every species you've caught swims here. Tap one: who it is, how many you've caught, something about it.
## Visitors pay: a bit more on what the crews catch while you're away.
func panel_aquarium() -> void:
	var n: int = VF.discovered.size()
	var pct := int(round(VF.aquarium_income() * 100.0))
	var top := "%d of %d species swim here. Visitors add +%d%% to what your crews catch while you're away (+%d%% with every one)." % [n,
		VFData.FISH_ORDER.size(), pct, int(round(VFData.AQUARIUM_MAX * 100.0))]
	var l: Label = m.lbl(top, 14, C_MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.panel_body.add_child(l)
	_tank = Control.new()
	_tank.custom_minimum_size = Vector2(0, clampf(m.get_viewport_rect().size.y * 0.58, 250.0, 430.0))
	_tank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tank.clip_contents = true
	_tank.mouse_filter = Control.MOUSE_FILTER_STOP
	_tank.draw.connect(_draw_tank)
	_tank.gui_input.connect(_tank_input)
	m.panel_body.add_child(_tank)
	var tick := Timer.new()                            # (it goes when the panel does)
	tick.wait_time = 1.0 / 30.0
	tick.autostart = true
	tick.timeout.connect(_tick_tank)
	_tank.add_child(tick)
	_tank_ms = Time.get_ticks_msec()
	_say = {}
	_swim = []
	var who := []                                      # [picture, name, the outlaw's row or -1]
	for f in VFData.FISH_ORDER:
		if VF.discovered.has(f): who.append([f, f, -1])
	for i in VFData.GERALD.size():                    # every outlaw you've caught, in a tank at last
		if VF.gerald_info(i).done: who.append([_look(i), String(VFData.GERALD[i].who), i])
	for w in who:
		var v := randf_range(0.02, 0.045) * (1.0 if randf() < 0.5 else -1.0)
		_swim.append({"f": w[0], "name": w[1], "row": w[2], "x": randf_range(0.08, 0.92), "y": randf_range(0.2, 0.78), "v": v, "face": signf(v),
			"ph": randf() * TAU, "k": randf_range(0.85, 1.15), "flee": 0.0})
	if _swim.is_empty():
		var e: Label = m.lbl("Nobody's here yet. Catch a fish and it'll swim here.", 15, Color.WHITE)
		e.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		e.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_tank.add_child(e)


func _tick_tank() -> void:
	if not is_instance_valid(_tank): return
	var now := Time.get_ticks_msec()
	var dt := minf((now - _tank_ms) / 1000.0, 0.1)
	_tank_ms = now
	for s in _swim:
		s.flee = maxf(0.0, s.flee - dt)
		s.x += s.v * dt * (1.0 + 5.0 * s.flee)
		if (s.x > 0.93 and s.v > 0.0) or (s.x < 0.07 and s.v < 0.0) or randf() < dt * 0.03: s.v = -s.v     # (the glass, or a change of mind)
		s.face = move_toward(s.face, signf(s.v), dt * 3.0)     # (it turns round: thin for a moment, then the other way)
		s.ph += dt
	if not _say.is_empty():
		_say.t += dt
		if _say.t > 4.0: _say = {}
	_tank.queue_redraw()


## A fish side on, the way the mini-game draws it: its sheet (mini/, made without eyes) and a face (vf_minigame.gd _draw_fish).
## face: which way it looks, -1..1 (through 0 while it turns round).
func _draw_side(f: String, at: Vector2, px: float, face: float, ph: float) -> bool:
	var mini: Dictionary = m.stage.manifest.get("mini", {})
	var info: Dictionary = mini.get("fish", {}).get(f, {})
	var t: Texture2D = m.tex("mini/%s.png" % VFData.slug(f))
	if t == null or info.is_empty(): return false
	var cell := float(mini.cell)
	var fr := int(ph * 7.0) % int(mini.frames)
	_tank.draw_set_transform(at, sin(ph * 1.1) * 0.05, Vector2(face, 1.0))
	_tank.draw_texture_rect_region(t, Rect2(-px * 0.5, -px * 0.5, px, px), Rect2(fr * cell, 0, cell, cell))
	var k := px / 176.0                                # (the mini-game draws them 176 px across)
	var e := (Vector2(info.eye[0], info.eye[1]) - Vector2(0.5, 0.5)) * px
	var mo := (Vector2(info.mouth[0], info.mouth[1]) - Vector2(0.5, 0.5)) * px
	var er := maxf(float(info.er) * px * 1.9, 11.0 * k)
	var w := maxf(1.2, 2.5 * k)
	if fmod(ph + float(f.length()), 4.3) < 0.14:      # a blink now and then
		_tank.draw_arc(e + Vector2(0, er * 0.2), er * 0.8, PI * 0.15, PI * 0.85, 10, INK, w, true)
	else:
		var pr := er * 0.48
		var look := e + Vector2(er - pr - w * 0.6, er * 0.1)      # ahead, where it's going
		_tank.draw_circle(e, er, Color.WHITE)
		_tank.draw_circle(look, pr, INK)
		_tank.draw_circle(look - Vector2(pr, pr) * 0.35, maxf(1.0, pr * 0.3), Color.WHITE)
		_tank.draw_arc(e, er, 0, TAU, 24, INK, w, true)
	_tank.draw_arc(mo + Vector2(-3, -5) * k, 6.0 * k, PI * 0.2, PI * 0.8, 8, INK, w, true)      # quite content, really
	return true


func _sheet(f: String) -> Dictionary:
	var sw: Dictionary = m.stage.manifest.get("swim", {})
	if f in sw.get("species", []):
		var t: Texture2D = m.tex("swim/%s.png" % VFData.slug(f))
		if t: return {"tex": t, "cell": float(sw.cell), "frames": int(sw.frames), "row": 0}
	var life: Dictionary = m.stage.manifest.get("life", {})
	var t2: Texture2D = m.tex("life/%s.png" % VFData.slug(f))
	if t2 and not life.is_empty(): return {"tex": t2, "cell": float(life.cell), "frames": int(life.frames), "row": 2}
	return {}


func _fish_at(s: Dictionary) -> Vector2:
	var sz := _tank.size
	return Vector2(s.x * sz.x, s.y * sz.y + sin(s.ph * 1.3) * 6.0)


func _draw_tank() -> void:
	var sz := _tank.size
	var top := Color("#5fc7d6")
	var bot := Color("#0f4f63")
	var n := 24
	for i in n:                                        # the water, lighter at the top
		_tank.draw_rect(Rect2(0, sz.y * i / n, sz.x, sz.y / n + 1.0), top.lerp(bot, float(i) / n))
	var t := Time.get_ticks_msec() / 1000.0
	for i in 5:                                        # slow light from above
		var x := sz.x * (0.12 + 0.2 * i) + sin(t * 0.3 + i) * 30.0
		_tank.draw_colored_polygon(PackedVector2Array([Vector2(x - 26, 0), Vector2(x + 26, 0), Vector2(x + 90, sz.y), Vector2(x + 10, sz.y)]),
			Color(1, 1, 1, 0.05))
	_tank.draw_rect(Rect2(0, sz.y - 26, sz.x, 26), Color("#d9c08a"))     # sand
	for i in 9:                                        # weed
		var bx := sz.x * (0.06 + 0.115 * i)
		var pts := PackedVector2Array()
		for k in 7:
			pts.append(Vector2(bx + sin(t * 0.9 + i + k * 0.6) * 4.0 * k / 6.0, sz.y - 20 - k * (14 + (i % 3) * 5)))
		_tank.draw_polyline(pts, Color("#3e8f62", 0.8), 5.0, true)
	for i in 12:                                       # bubbles
		var bx := sz.x * fmod(i * 0.137 + 0.05, 1.0)
		var by := sz.y - fmod(t * (22.0 + i * 3.0) + i * 57.0, sz.y + 20.0)
		_tank.draw_arc(Vector2(bx + sin(t + i) * 5.0, by), 2.0 + (i % 3), 0, TAU, 12, Color(1, 1, 1, 0.35), 1.2, true)
	for s in _swim:
		var px: float = clampf(_tank.size.y * 0.25, 72.0, 112.0) * s.k      # (a phone's shorter tank: smaller fish, less of a crowd)
		if _draw_side(s.f, _fish_at(s), px, s.face, s.ph * (1.8 if s.flee > 0.0 else 1.0)): continue
		var sh := _sheet(s.f)                          # (no side view for it: its picture from the stage)
		if sh.is_empty(): continue
		var cell: float = sh.cell
		var fr := int(s.ph * 8.0) % int(sh.frames)
		_tank.draw_set_transform(_fish_at(s), 0.0, Vector2(s.face * px / cell, px / cell))
		_tank.draw_texture_rect_region(sh.tex, Rect2(-cell * 0.5, -cell * 0.5, cell, cell), Rect2(fr * cell, sh.row * cell, cell, cell))
	_tank.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_tank.draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, 0.35), false, 3.0)      # the glass
	if not _say.is_empty():
		for s in _swim:
			if s.name == _say.name: _draw_say(_fish_at(s))


func _draw_say(at: Vector2) -> void:
	var font: Font = _tank.get_theme_default_font()
	var lines: PackedStringArray = String(_say.text).split("\n")
	var w := 0.0
	for li in lines: w = maxf(w, font.get_string_size(li, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var bw := w + 24.0
	var bh := 22.0 * lines.size() + 14.0
	var p := Vector2(clampf(at.x - bw * 0.5, 6.0, _tank.size.x - bw - 6.0), clampf(at.y - bh - 46.0, 6.0, _tank.size.y - bh - 6.0))
	var a := clampf(minf(_say.t / 0.15, (4.0 - _say.t) / 0.4), 0.0, 1.0)
	_tank.draw_style_box(m.sbox(Color(1, 1, 1, 0.95 * a), 12, 2, Color(INK, 0.5 * a), 0), Rect2(p, Vector2(bw, bh)))
	for i in lines.size():
		_tank.draw_string(font, p + Vector2(12, 24 + 22 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16 if i == 0 else 14,
			Color(C_TEXT if i == 0 else C_MUTED, a))


func _tank_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT): return
	VF.stat_add("glass_taps")                         # "Please Don't Tap the Glass"
	var best := {}
	var d := 70.0
	for s in _swim:
		var dd := _fish_at(s).distance_to(e.position)
		if dd < d:
			d = dd
			best = s
	for s in _swim:                                   # everyone nearby jumps a bit
		if _fish_at(s).distance_to(e.position) < 200.0: s.flee = 0.6
	if not best.is_empty():
		best.flee = 0.0
		var fact: String = load("res://scripts/vf/vf_minigame.gd").FACTS.pick_random()
		var text := "%s\nCaught %s  ·  %s" % [best.name, VF.commas(int(VF.discovered.get(best.f, 0))), fact]
		if int(best.row) >= 0:
			text = "%s\nWanted no more  ·  %s" % [best.name, IN_THE_TANK.get(String(VFData.GERALD[int(best.row)].biome), "Behaving. For now.")]
		_say = {"f": best.f, "name": best.name, "text": text, "t": 0.0}
		AudioManager.play_fun("boing", -14.0, randf_range(0.9, 1.15))
	else:
		AudioManager.play_fun("clunk", -16.0)
	refresh_badges()


# =============================================================== the Shop
## Shop -> Hats: for the captain. They buy nothing but laughs. A preview once the art's in (assets/vf/hats/<slug>.png).
func tab_hats() -> void:
	var l: Label = m.lbl("For the captain. They do nothing at all, and that's the point.", 14, C_MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.panel_body.add_child(l)
	var g: GridContainer = m._grid(2)
	for id in VFData.HAT_ORDER:
		var d: Dictionary = VFData.HATS[id]
		var owned: bool = id in VF.hats_owned
		var right: Control
		if VF.hat == id:
			right = _chip("Wearing", C_GOOD)
		elif owned:
			right = m._act("Wear", C_TEAL, func():
				VF.wear_hat(id)
				AudioManager.play_fun("hat_on")
				_rerender(["shop"])
				return "")
		else:
			var why: String = VF.hat_lock(id)
			if why != "":
				var wl: Label = m.lbl(why, 12, C_MUTED)
				wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				wl.custom_minimum_size.x = 150
				wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				right = wl
			else:
				var price: int = VF.hat_price(id)
				right = m._act("Buy " + m.money_str(price) if price > 0 else "Take it", C_GOOD, func():
					var r: String = VF.buy_hat(id)
					if r == "":
						AudioManager.play_fun("hat_on")
						m._toast("%s: on!" % d.name, "buy")
						_rerender(["shop"])
					return r, VF.money >= price)
		m._add_to(g, m._card(hat_preview(id), d.name, d.desc, right, false, 64))


## the hat's picture, once the art's in: the first view in its sheet
func hat_preview(id: String) -> Texture2D:
	var t: Texture2D = m.tex("hats/%s.png" % id)
	if t == null: return null
	var info: Dictionary = m.stage.manifest.get("hats", {})
	var cell := float(info.get("cell", t.get_height()))
	var a := AtlasTexture.new()
	a.atlas = t
	a.region = Rect2(0, 0, cell, cell)
	return a


# ===================================================================== test
## godot --path . --resolution 1560x720 -- --capture=DIR --collect-test [--touch --ui-dp=390] : every collecting screen. Never saves.
func capture_test(dir: String) -> void:
	var tree: SceneTree = m.get_tree()
	var wait := func(s: float): await tree.create_timer(s).timeout
	VF._apply(VF._defaults.duplicate(true))
	m._veteran("Ocean")
	VF.gerald = {"stage": 2, "casts": 0, "tries": 1, "wins": 2, "losses": 3}       # beaten twice, after him in the Ocean
	VF.finds = {"otter": 3, "frog": 1, "capybara": 2, "turtle": 1, "treasure": 1}
	VF.stats["honks"] = 120
	VF.stats["glass_taps"] = 48
	VF.stats["reel_wins"] = 61
	VF.ach_claimed = {"first_fish": true, "level_25": true}
	for b in ["River", "Volcanic"]:
		for f in VFData.BIOMES[b].fish: VF.discovered[f] = int(VF.discovered.get(f, 0)) + 40
	VF.hats_owned = ["straw", "pirate"]
	VF.hat = "pirate"
	VF.changed.emit()
	refresh_badges()
	await wait.call(1.2)
	print("COLLECT pill=%s '%s' menu badge=%d" % [wanted_pill.visible, _wanted_lbl.text, VF.ach_ready().size()])
	await m._shot(dir + "/collect0_hud.png")
	m._open_panel("wanted")
	await wait.call(0.5)
	var looks := []
	for i in VFData.GERALD.size(): looks.append("%s=%s" % [VFData.GERALD[i].biome, _look(i)])
	print("COLLECT poster looks: %s" % ", ".join(looks))
	await m._shot(dir + "/collect1_wanted.png")
	m.panel_scroll.scroll_vertical = 100000
	await wait.call(0.2)
	await m._shot(dir + "/collect1_wanted_lower.png")
	m._open_panel("inventory", "Finds")
	await wait.call(0.4)
	await m._shot(dir + "/collect2_finds.png")
	m._open_panel("inventory", "Fish")
	await wait.call(0.4)
	m.panel_scroll.scroll_vertical = 100000
	await wait.call(0.1)
	await m._shot(dir + "/collect3_book_stamps.png")
	m._open_panel("menu")
	await wait.call(0.4)
	m.panel_scroll.scroll_vertical = 100000
	await wait.call(0.1)
	await m._shot(dir + "/collect4_menu.png")
	m._open_panel("achievements")
	m.panel_scroll.scroll_vertical = 0                    # (the ready ones are at the top)
	await wait.call(0.4)
	print("COLLECT achievements open at scroll %d" % m.panel_scroll.scroll_vertical)
	await m._shot(dir + "/collect5_achievements.png")
	var before: int = VF.pearls
	var ready: Array = VF.ach_ready()
	if not ready.is_empty(): claim(ready[0])
	await wait.call(0.5)
	print("COLLECT claimed %s: pearls %d -> %d, ready %d -> %d" % [ready[0] if not ready.is_empty() else "-", before, VF.pearls, ready.size(), VF.ach_ready().size()])
	await m._shot(dir + "/collect6_claimed.png")
	VF.gerald = {"stage": 4, "casts": 0, "tries": 0, "wins": 4, "losses": 3}       # (run 1's four outlaws are caught: in the tank too)
	m._open_panel("aquarium")
	await wait.call(1.0)
	var taps0 := int(VF.stats.get("glass_taps", 0))
	if not _swim.is_empty():
		var at: Vector2 = _tank.get_global_transform() * _fish_at(_swim[0])
		m._tap(m.get_viewport().get_final_transform() * at)
	await wait.call(0.6)
	print("COLLECT glass taps %d -> %d, card '%s'" % [taps0, int(VF.stats.get("glass_taps", 0)), String(_say.get("text", "")).replace("\n", " / ")])
	await m._shot(dir + "/collect7_aquarium.png")
	m._open_panel("shop", "Hats")
	await wait.call(0.4)
	await m._shot(dir + "/collect8_hats.png")
	print("COLLECT buy chef: '%s' hat=%s owned=%s" % [VF.buy_hat("chef"), VF.hat, VF.hats_owned])
	m._render_panel()
	await wait.call(0.3)
	await m._shot(dir + "/collect9_hat_bought.png")
	m._close_panel()
	VF.gerald = {"stage": VFData.GERALD.size(), "casts": 0, "tries": 0, "wins": 7, "losses": 4}
	VF.changed.emit()
	m._open_panel("wanted")
	await wait.call(0.4)
	print("COLLECT all caught: pill=%s" % wanted_pill.visible)
	await m._shot(dir + "/collect10_wanted_done.png")

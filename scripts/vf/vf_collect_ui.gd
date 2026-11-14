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
var _swim := []                       # the aquarium's fish: {f, name, row, x, y, home, v, face, ph, k, flee, act, act_t, munch}
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
## Menu (or the pill) -> Wanted: one poster per outlaw, seven in all. Stamped once they're behind you.
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
	var who := "???" if secret else String(row.who)
	c.draw_string(font, Vector2(x, r.position.y + 196.0), who, HORIZONTAL_ALIGNMENT_CENTER, cw, 22 if who.length() <= 12 else (19 if who.length() <= 15 else 16), ink)       # (long names get smaller, not trimmed)
	# where, and what they were up to (two lines at most)
	var where := "Somewhere out there" if secret else "Last seen: %s, %s" % [VFData.GERALD_PLACES.get(row.biome, row.biome), UP_TO.get(row.biome, "up to no good")]
	c.draw_multiline_string(font, Vector2(x + 8.0, r.position.y + 216.0), where, HORIZONTAL_ALIGNMENT_CENTER, cw - 16.0, 13, 2, Color(ink, 0.85))
	var foot := "From level %s" % VF.commas(int(row.level)) if later or secret else "Reward %s" % m.money_str(int(g.bounty))
	c.draw_string(font, Vector2(x, r.position.y + 260.0), foot, HORIZONTAL_ALIGNMENT_CENTER, cw, 15, C_GOLD.darkened(0.25) if not later else Color(ink, 0.7))
	if g.done:                                         # a rubber stamp over the picture's lower edge: the name and the caption stay readable
		var word := "CAUGHT!"
		c.draw_set_transform(c.size * 0.5 + Vector2(12, r.position.y + 150.0).rotated(tilt), tilt - 0.2, Vector2(0.75, 0.75))
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
## Menu -> Aquarium: every species you've caught swims here, and they're a lively lot. Tap a fish: who it is, how many you've caught,
## and its party trick (TRICK). Tap the water: a pinch of food, and they race for it. Tap the chest: bubbles. Left alone they chat
## (about you, mostly), the shark has a go at the small ones, and visitors walk past the glass, take photos and tap on it.
## Visitors pay: a bit more on what the crews catch while you're away.
const TRICK := {"Pufferfish": "puff", "Fiery Pufferfish": "puff", "Dark Puffer": "puff", "Squid": "ink", "Emerald Squid": "ink",
	"Turtle": "nap", "Dolphin": "flip", "Rainbow Fish": "flip", "Shark": "grin", "Galactic Crab": "snip", "Guardian": "stare"}
const TRICK_SAYS := {"puff": ["PFFF.", "Do NOT poke me.", "I'm big now. Fear me."], "ink": ["You saw nothing.", "Ink! Everybody run!"],
	"nap": ["Five more minutes.", "Wake me for lunch."], "flip": ["Ta-da!", "And the crowd goes wild."],
	"grin": ["Hello, snacks.", "Who's hungry? I am."], "snip": ["Snip snip.", "Shake my claw."],
	"stare": ["...", "I'm guarding. Go away."], "": ["Hi!", "Oh! Hello.", "That tickles.", "Again, again!"]}
const CHAT := [["Is it feeding time? It feels like feeding time."], ["Do you ever feel watched?", "Constantly."],
	["I was promised a castle.", "We were ALL promised a castle."], ["Psst. The captain is looking at us again.", "Act natural."],
	["Who keeps tapping the glass?", "The big face. Up there."], ["I miss the sea.", "The sea had hooks in it."],
	["Nice bubbles today.", "Thanks. I made them myself."], ["What day is it?", "Tank day. It's always tank day."],
	["I'm the captain's favourite.", "You were bait size, mate."], ["Left. Right. Left. Right. What a life."],
	["If I swim really fast, do I get out?", "You hit the glass. Again."], ["What's in the chest?", "Nothing. We checked."]]
const CHAT_BY := {"Shark": "I'm on a diet. Mostly.", "Turtle": "I was here before the tank.", "Cod": "I'm just a cod. No pressure.",
	"Dolphin": "I'm not even a fish. Nobody checks.", "Pufferfish": "One more joke about my size. Go on.",
	"Squid": "So many arms and nothing to hold.", "Guardian": "I guard this tank. From what? Don't ask.",
	"Raw Fish": "Why am I called RAW? Who's cooking?", "Hot Cod": "Is it warm in here, or is it me?",
	"Space Fish": "I've seen the stars. This is fine too.", "Alien Fish": "Take me to your feeder.",
	"Galactic Crab": "Sideways is the only way.", "Rainbow Fish": "Yes, it's natural.", "Dark Tuna": "It's always night for me.",
	"Tropical Fish": "I'm on holiday. Forever.", "Raw Salmon": "I swam upstream for THIS?"}
const POSES := ["My good side, please.", "No flash!", "Is my fin straight?", "Put it on FishTok."]
const GLASS := Color("#124656")                        # the visitors: dark shapes in front of the glass

var _food := []                       # flakes sinking: {x, y, t}
var _fx := []                         # {k: heart|ink|flash|ring|pop|z, x, y, t, life}
var _talks := []                      # what they're saying: {s, text, t (below 0: not yet), life}
var _vis := []                        # the visitors: {x, v, h (of the tank's height), kid, stop}
var _hunt := {}                       # the shark's little joke: {shark, prey, t}
var _chat_t := 4.0
var _vis_t := 6.0
var _hunt_t := 16.0
var _hint := 7.0                      # "tap the water" shows this long, or until you do


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
	_food = []
	_fx = []
	_talks = []
	_vis = []
	_hunt = {}
	_chat_t = 4.0
	_vis_t = 6.0
	_hunt_t = 16.0
	_hint = 7.0
	var who := []                                      # [picture, name, the outlaw's row or -1]
	for f in VFData.FISH_ORDER:
		if VF.discovered.has(f): who.append([f, f, -1])
	for i in VFData.GERALD.size():                    # every outlaw you've caught, in a tank at last
		if VF.gerald_info(i).done: who.append([_look(i), String(VFData.GERALD[i].who), i])
	for w in who:
		var v := randf_range(0.02, 0.045) * (1.0 if randf() < 0.5 else -1.0)
		var y := randf_range(0.2, 0.74)
		if String(w[1]) == "Galactic Crab": y = 0.86  # (it walks the sand)
		_swim.append({"f": w[0], "name": w[1], "row": w[2], "x": randf_range(0.08, 0.92), "y": y, "home": y, "v": v, "face": signf(v),
			"ph": randf() * TAU, "k": randf_range(0.85, 1.15), "flee": 0.0, "act": "", "act_t": 0.0, "munch": 0.0})
	var crowd := clampi(1 + who.size() / 6, 1, 4)   # the more there is to see, the more come to see it
	for i in crowd:
		_vis.append(_visitor((i + randf_range(0.2, 0.8)) / crowd))
	if _swim.is_empty():
		var e: Label = m.lbl("Nobody's here yet. Catch a fish and it'll swim here.", 15, Color.WHITE)
		e.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		e.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_tank.add_child(e)


func _visitor(at: float) -> Dictionary:
	var kid := randf() < 0.3
	return {"x": at, "v": randf_range(0.012, 0.03) * (1.0 if randf() < 0.5 else -1.0), "h": randf_range(0.15, 0.18) if kid else randf_range(0.23, 0.29),
		"kid": kid, "stop": 0.0}


func _talk(s: Dictionary, text: String, wait := 0.0) -> void:
	_talks = _talks.filter(func(t): return t.s != s)
	_talks.append({"s": s, "text": text, "t": -wait, "life": 2.2 + text.length() * 0.045})


func _puff(k: String, at: Vector2, life: float) -> void:
	_fx.append({"k": k, "x": at.x, "y": at.y, "t": 0.0, "life": life})


func _free(s: Dictionary) -> bool:                    # nothing on: it can chat, or be picked on
	return String(s.act) == "" and float(s.flee) <= 0.0 and (_hunt.is_empty() or (_hunt.shark != s and _hunt.prey != s))


func _tick_tank() -> void:
	if not is_instance_valid(_tank): return
	var now := Time.get_ticks_msec()
	var dt := minf((now - _tank_ms) / 1000.0, 0.1)
	_tank_ms = now
	var sz := _tank.size
	_hint = maxf(0.0, _hint - dt)
	for fd in _food:
		fd.t += dt
		fd.y = minf(fd.y + 26.0 * dt, sz.y - 30.0)
	_food = _food.filter(func(fd): return fd.t < 16.0)
	for p in _fx: p.t += dt
	_fx = _fx.filter(func(p): return p.t < p.life)
	for t in _talks: t.t += dt
	_talks = _talks.filter(func(t): return t.t < t.life)
	_tick_hunt(dt)
	for s in _swim:
		s.flee = maxf(0.0, s.flee - dt)
		s.munch = maxf(0.0, s.munch - dt)
		if s.act != "":
			s.act_t -= dt
			if s.act_t <= 0.0: s.act = ""
		s.ph += dt
		var speed: float = 1.0 + 5.0 * s.flee
		var ty: float = s.home
		var busy: bool = not _hunt.is_empty() and (_hunt.shark == s or _hunt.prey == s)
		if s.act == "nap" or s.act == "stare":
			speed = 0.0
			if s.act == "nap":
				ty = 0.84
				if fmod(s.ph, 1.1) < dt: _puff("z", _fish_at(s) + Vector2(18, -22), 1.6)
		elif busy:
			speed = 3.4 if _hunt.shark == s else 4.2
			if _hunt.shark == s: ty = _hunt.prey.y
		elif s.flee <= 0.0 and not _food.is_empty():
			var at := _fish_at(s)
			var best := {}
			var d := sz.x * 0.42
			for fd in _food:
				var dd := at.distance_to(Vector2(fd.x, fd.y))
				if dd < d:
					d = dd
					best = fd
			if not best.is_empty():
				if d < 26.0:
					_food.erase(best)
					s.munch = 0.35
					_puff("heart", at + Vector2(0, -26), 1.1)
					AudioManager.play_fun("pop", -24.0, randf_range(1.3, 1.7))
					if randf() < 0.22: _talk(s, ["Mine.", "Yum.", "More, please.", "I saw it first."].pick_random())
				else:
					if absf(best.x - at.x) > 8.0: s.v = absf(s.v) * signf(best.x - at.x)
					speed = 3.2
					if float(s.home) < 0.8: ty = best.y / sz.y
		s.x += s.v * dt * speed
		s.y = move_toward(s.y, ty, dt * 0.22 * maxf(speed, 0.7))
		var mind: bool = speed <= 1.0 and randf() < dt * 0.03          # (a change of mind, when there's nothing better to do)
		if (s.x > 0.93 and s.v > 0.0) or (s.x < 0.07 and s.v < 0.0) or mind: s.v = -s.v     # (or the glass)
		s.face = move_toward(s.face, signf(s.v), dt * 3.0)     # (it turns round: thin for a moment, then the other way)
	if not _say.is_empty():
		_say.t += dt
		if _say.t > 4.0: _say = {}
	_chat_t -= dt
	if _chat_t <= 0.0 and _talks.is_empty() and _say.is_empty():
		_chat_t = randf_range(5.0, 9.0)
		_chat()
	_tick_visitors(dt)
	_tank.queue_redraw()


## Somebody says something; now and then somebody else answers.
func _chat() -> void:
	var idle: Array = _swim.filter(func(s): return _free(s))
	if idle.is_empty(): return
	var a: Dictionary = idle.pick_random()
	var r := randf()
	var hour := int(Time.get_time_dict_from_system().hour)
	if int(a.row) >= 0:
		_talk(a, IN_THE_TANK.get(String(VFData.GERALD[int(a.row)].biome), "Behaving. For now."))
	elif r < 0.28 and CHAT_BY.has(a.name):
		_talk(a, CHAT_BY[a.name])
	elif r < 0.4:
		_talk(a, "%s of my family caught. I counted." % VF.commas(int(VF.discovered.get(a.f, 0))))
	elif r < 0.48 and (hour >= 23 or hour < 5):
		_talk(a, "It's late, captain. Go to bed.")
	elif r < 0.56 and int(VF.stats.get("glass_taps", 0)) >= 50:
		_talk(a, "%s taps on the glass. We felt every one." % VF.commas(int(VF.stats.glass_taps)))
	else:
		var lines: Array = CHAT.pick_random()
		_talk(a, lines[0])
		idle.erase(a)
		if lines.size() > 1 and not idle.is_empty(): _talk(idle.pick_random(), lines[1], 1.7)


## The shark goes for one of the small ones. It never means it.
func _tick_hunt(dt: float) -> void:
	if _hunt.is_empty():
		_hunt_t -= dt
		if _hunt_t > 0.0: return
		_hunt_t = randf_range(24.0, 40.0)
		var sharks: Array = _swim.filter(func(s): return s.name == "Shark" and _free(s))
		var prey: Array = _swim.filter(func(s): return s.name != "Shark" and int(s.row) < 0 and _free(s) and float(s.home) < 0.8)
		if sharks.is_empty() or prey.is_empty(): return
		_hunt = {"shark": sharks[0], "prey": prey.pick_random(), "t": 0.0}
		_talk(_hunt.prey, ["Not again!", "Help! Shark!", "Why is it always me?"].pick_random())
		AudioManager.play_fun("dundun", -20.0)
		return
	_hunt.t += dt
	var a: Vector2 = _fish_at(_hunt.shark)
	var b: Vector2 = _fish_at(_hunt.prey)
	if absf(b.x - a.x) > 8.0: _hunt.shark.v = absf(_hunt.shark.v) * signf(b.x - a.x)
	if _hunt.t > 4.5 or a.distance_to(b) < 64.0:
		_talk(_hunt.shark, ["Just kidding.", "Relax. I had lunch.", "Got you. Again."].pick_random())
		_talk(_hunt.prey, ["NOT funny.", "Every. Single. Day.", "I'm telling the captain."].pick_random(), 1.2)
		_hunt.prey.flee = 0.5
		_hunt = {}


## The people at the glass: they wander past; one stops now and then, for a photo, or (the small ones) to tap on it.
func _tick_visitors(dt: float) -> void:
	var sz := _tank.size
	for p in _vis:
		if p.stop > 0.0:
			p.stop -= dt
			continue
		p.x += p.v * dt
		if p.x > 1.08 or p.x < -0.08:
			var q := _visitor(-0.07 if p.v > 0.0 else 1.07)
			q.v = absf(q.v) * signf(p.v)
			for key in q: p[key] = q[key]
	_vis_t -= dt
	if _vis_t > 0.0 or _vis.is_empty() or _swim.is_empty(): return
	_vis_t = randf_range(9.0, 16.0)
	var who: Dictionary = _vis.pick_random()
	if who.x < 0.1 or who.x > 0.9 or who.stop > 0.0: return
	who.stop = 2.4
	var head := Vector2(who.x * sz.x, sz.y - float(who.h) * sz.y * 0.8)
	var near := {}
	var d := 1e9
	for s in _swim:
		var dd := _fish_at(s).distance_to(head)
		if dd < d and _free(s):
			d = dd
			near = s
	if who.kid:
		_puff("ring", head + Vector2(who.h * sz.y * 0.44, 0), 0.7)
		AudioManager.play_fun("clunk", -24.0, 1.3)
		for s in _swim:
			if _fish_at(s).distance_to(head) < 190.0 and String(s.act) == "": s.flee = 0.6
		if not near.is_empty(): _talk(near, ["Kids.", "Read the sign!", "Every school trip. Every time."].pick_random(), 0.5)
	else:
		_puff("flash", head + Vector2(who.h * sz.y * 0.33, -who.h * sz.y * 0.08), 0.35)
		AudioManager.play_fun("shutter", -24.0)
		if not near.is_empty(): _talk(near, POSES.pick_random(), 0.3)


## A fish side on, the way the mini-game draws it: its sheet (mini/, made without eyes) and a face (vf_minigame.gd _draw_fish).
## face: which way it looks, -1..1 (through 0 while it turns round). rot: its trick, if it's doing one. asleep: eyes shut.
func _draw_side(f: String, at: Vector2, px: float, face: float, ph: float, rot := 0.0, asleep := false) -> bool:
	var mini: Dictionary = m.stage.manifest.get("mini", {})
	var info: Dictionary = mini.get("fish", {}).get(f, {})
	var t: Texture2D = m.tex("mini/%s.png" % VFData.slug(f))
	if t == null or info.is_empty(): return false
	var cell := float(mini.cell)
	var fr := int(ph * 7.0) % int(mini.frames)
	_tank.draw_set_transform(at, rot + sin(ph * 1.1) * 0.05, Vector2(face, 1.0))
	_tank.draw_texture_rect_region(t, Rect2(-px * 0.5, -px * 0.5, px, px), Rect2(fr * cell, 0, cell, cell))
	var k := px / 176.0                                # (the mini-game draws them 176 px across)
	var e := (Vector2(info.eye[0], info.eye[1]) - Vector2(0.5, 0.5)) * px
	var mo := (Vector2(info.mouth[0], info.mouth[1]) - Vector2(0.5, 0.5)) * px
	var er := maxf(float(info.er) * px * 1.9, 11.0 * k)
	var w := maxf(1.2, 2.5 * k)
	if asleep or fmod(ph + float(f.length()), 4.3) < 0.14:      # a blink now and then
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
	var act := String(s.get("act", ""))
	var bob: float = 0.0 if act == "nap" else sin(s.ph * 1.3) * 6.0
	var hop := 0.0                                     # (the flip is a jump too)
	if act == "flip": hop = -sin(clampf(1.0 - float(s.act_t) / 0.8, 0.0, 1.0) * PI) * 34.0
	return Vector2(s.x * sz.x, s.y * sz.y + bob + hop)


func _chest_rect() -> Rect2:
	var sz := _tank.size
	var w := clampf(sz.y * 0.2, 54.0, 84.0)
	return Rect2(sz.x * 0.78 - w * 0.5, sz.y - w - 8.0, w, w)


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
	var chest: Texture2D = m.tex("chests/common.png")  # the chest on the sand: it bubbles, and more when you tap it
	var cr := _chest_rect()
	if chest: _tank.draw_texture_rect(chest, cr, false)
	for i in 3:
		var cy := fmod(t * 34.0 + i * 61.0, sz.y * 0.6)
		_tank.draw_arc(Vector2(cr.get_center().x + sin(t * 1.4 + i * 2.0) * 7.0, cr.position.y + 6.0 - cy), 2.5 + i, 0, TAU, 12,
			Color(1, 1, 1, 0.4 * (1.0 - cy / (sz.y * 0.6))), 1.2, true)
	for i in 12:                                       # bubbles
		var bx := sz.x * fmod(i * 0.137 + 0.05, 1.0)
		var by := sz.y - fmod(t * (22.0 + i * 3.0) + i * 57.0, sz.y + 20.0)
		_tank.draw_arc(Vector2(bx + sin(t + i) * 5.0, by), 2.0 + (i % 3), 0, TAU, 12, Color(1, 1, 1, 0.35), 1.2, true)
	for p in _fx:                                      # ink goes behind the fish
		if p.k != "ink": continue
		var ia: float = 1.0 - p.t / p.life
		for i in 5:
			_tank.draw_circle(Vector2(p.x, p.y) + Vector2.from_angle(i * 1.3 + p.t) * (10.0 + p.t * 16.0), 16.0 + p.t * 12.0 + i * 2.0,
				Color(0.05, 0.05, 0.12, 0.42 * ia))
	for fd in _food:
		var fp := Vector2(fd.x + sin(fd.t * 3.0 + fd.x) * 3.0, fd.y)
		_tank.draw_circle(fp, 3.2, Color("#e8a23a"))
		_tank.draw_circle(fp - Vector2(1, 1), 1.2, Color("#ffe0a0"))
	for s in _swim:
		var px: float = clampf(_tank.size.y * 0.25, 72.0, 112.0) * s.k      # (a phone's shorter tank: smaller fish, less of a crowd)
		var rot := 0.0
		var sc: float = 1.0 + sin(s.munch / 0.35 * PI) * 0.14
		var left: float = s.act_t
		match String(s.act):
			"puff": sc *= 1.0 + 0.55 * clampf(minf((1.8 - left) / 0.15, left / 0.5), 0.0, 1.0) + sin(s.ph * 22.0) * 0.02
			"flip": rot = -TAU * clampf(1.0 - left / 0.8, 0.0, 1.0) * signf(s.face)
			"snip": rot = sin(s.ph * 26.0) * 0.16
			"grin": sc *= 1.0 + 0.18 * sin(clampf(1.0 - left, 0.0, 1.0) * PI)
			"hi": rot = sin(s.ph * 24.0) * 0.14 * clampf(left / 0.6, 0.0, 1.0)
		var fast: float = 1.8 if s.flee > 0.0 else (0.25 if s.act == "nap" else 1.0)
		if _draw_side(s.f, _fish_at(s), px * sc, s.face, s.ph * fast, rot, s.act == "nap"): continue
		var sh := _sheet(s.f)                          # (no side view for it: its picture from the stage)
		if sh.is_empty(): continue
		var cell: float = sh.cell
		var fr := int(s.ph * 8.0) % int(sh.frames)
		_tank.draw_set_transform(_fish_at(s), rot, Vector2(s.face * px * sc / cell, px * sc / cell))
		_tank.draw_texture_rect_region(sh.tex, Rect2(-cell * 0.5, -cell * 0.5, cell, cell), Rect2(fr * cell, sh.row * cell, cell, cell))
	_tank.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var font: Font = _tank.get_theme_default_font()
	for p in _fx:
		var a: float = clampf(1.0 - p.t / p.life, 0.0, 1.0)
		var at := Vector2(p.x, p.y)
		match String(p.k):
			"heart":
				at.y -= p.t * 30.0
				_tank.draw_circle(at + Vector2(-4, 0), 5.0, Color("#ff5e7e", a))
				_tank.draw_circle(at + Vector2(4, 0), 5.0, Color("#ff5e7e", a))
				_tank.draw_colored_polygon(PackedVector2Array([at + Vector2(-8.6, 2), at + Vector2(8.6, 2), at + Vector2(0, 12)]), Color("#ff5e7e", a))
			"z":
				_tank.draw_string(font, at + Vector2(p.t * 8.0, -p.t * 22.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 15 + int(p.t * 5.0), Color(1, 1, 1, a))
			"pop":
				for i in 7:
					var o := Vector2(sin(i * 2.4) * (6.0 + i * 3.0), -p.t * (60.0 + i * 16.0) - i * 5.0)
					_tank.draw_arc(at + o, 3.0 + (i % 3) * 2.0, 0, TAU, 12, Color(1, 1, 1, 0.75 * a), 1.5, true)
	_tank.draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, 0.35), false, 3.0)      # the glass
	for i in _vis.size():                              # ... and the people on our side of it
		var p: Dictionary = _vis[i]
		var h: float = p.h * sz.y
		var x: float = p.x * sz.x
		var step: float = 0.0 if p.stop > 0.0 else sin(t * 7.0 + i * 1.7) * 1.5
		var r := h * 0.2
		var head := Vector2(x, sz.y - h + r + step)
		var w := h * (0.7 if p.kid else 0.62)
		var sy := head.y + r * 0.8                      # the shoulders: a rounded block down to the sill
		var body := PackedVector2Array([Vector2(x - w * 0.5, sz.y)])
		for k in 7: body.append(Vector2(x - w * 0.5 + w * 0.3, sy + w * 0.3) + Vector2.from_angle(PI + k * PI / 12.0) * w * 0.3)
		for k in 7: body.append(Vector2(x + w * 0.5 - w * 0.3, sy + w * 0.3) + Vector2.from_angle(-PI * 0.5 + k * PI / 12.0) * w * 0.3)
		body.append(Vector2(x + w * 0.5, sz.y))
		_tank.draw_colored_polygon(body, GLASS)
		_tank.draw_circle(head, r, GLASS)
		if p.stop > 0.0 and not p.kid:                 # the phone, held up
			_tank.draw_line(Vector2(x + w * 0.4, sy + w * 0.2), Vector2(x + w * 0.52, head.y), GLASS, h * 0.09)
			_tank.draw_rect(Rect2(x + w * 0.42, head.y - h * 0.13, h * 0.13, h * 0.2), GLASS)
		elif p.stop > 0.0:                             # a small hand on the glass
			_tank.draw_line(Vector2(x + w * 0.4, sy + w * 0.25), Vector2(x + w * 0.62, head.y + r * 0.4), GLASS, h * 0.1)
	for p in _fx:
		var a: float = clampf(1.0 - p.t / p.life, 0.0, 1.0)
		if p.k == "flash":
			_tank.draw_circle(Vector2(p.x, p.y), 14.0 + p.t * 120.0, Color(1, 1, 1, 0.75 * a))
		elif p.k == "ring":
			_tank.draw_arc(Vector2(p.x, p.y), 6.0 + p.t * 46.0, 0, TAU, 24, Color(1, 1, 1, 0.8 * a), 2.0, true)
	if _hint > 0.0 and not _swim.is_empty():
		_tank.draw_string(font, Vector2(14, 26), "Tap the water to feed them. Tap a fish to say hello.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(1, 1, 1, 0.85 * clampf(_hint / 0.6, 0.0, 1.0)))
	for tk in _talks:
		if tk.t >= 0.0: _draw_bubble(_fish_at(tk.s), tk.text, tk.t, tk.life)
	if not _say.is_empty():
		for s in _swim:
			if s.name == _say.name: _draw_bubble(_fish_at(s), _say.text, _say.t, 4.0)


## What a fish says, above it. One line: a speech bubble. More: its card (the first line is its name).
func _draw_bubble(at: Vector2, text: String, t: float, life: float) -> void:
	var font: Font = _tank.get_theme_default_font()
	var lines: PackedStringArray = text.split("\n")
	var one := lines.size() == 1
	var w := 0.0
	for li in lines: w = maxf(w, font.get_string_size(li, HORIZONTAL_ALIGNMENT_LEFT, -1, 14 if one else 16).x)
	var bw := w + 24.0
	var bh := 22.0 * lines.size() + (10.0 if one else 14.0)
	var p := Vector2(clampf(at.x - bw * 0.5, 6.0, _tank.size.x - bw - 6.0), clampf(at.y - bh - 46.0, 6.0, _tank.size.y - bh - 6.0))
	var a := clampf(minf(t / 0.15, (life - t) / 0.4), 0.0, 1.0)
	_tank.draw_style_box(m.sbox(Color(1, 1, 1, 0.95 * a), 12, 2, Color(INK, 0.5 * a), 0), Rect2(p, Vector2(bw, bh)))
	if one:
		var tx := clampf(at.x, p.x + 14.0, p.x + bw - 14.0)
		_tank.draw_colored_polygon(PackedVector2Array([Vector2(tx - 6, p.y + bh - 2), Vector2(tx + 6, p.y + bh - 2), Vector2(tx, p.y + bh + 8)]),
			Color(1, 1, 1, 0.95 * a))
		_tank.draw_string(font, p + Vector2(12, 21), lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(C_TEXT, a))
		return
	for i in lines.size():
		_tank.draw_string(font, p + Vector2(12, 24 + 22 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16 if i == 0 else 14,
			Color(C_TEXT if i == 0 else C_MUTED, a))


func _tank_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT): return
	VF.stat_add("glass_taps")                         # "Please Don't Tap the Glass"
	_hint = minf(_hint, 0.6)
	var best := {}
	var d := 70.0
	for s in _swim:
		var dd := _fish_at(s).distance_to(e.position)
		if dd < d:
			d = dd
			best = s
	if not best.is_empty():
		for s in _swim:                               # everyone nearby jumps a bit
			if s != best and _fish_at(s).distance_to(e.position) < 200.0 and String(s.act) == "": s.flee = 0.6
		best.flee = 0.0
		var trick := ""
		if int(best.row) < 0: trick = String(TRICK.get(String(best.name), ""))
		var fact: String = load("res://scripts/vf/vf_minigame.gd").FACTS.pick_random()
		var text := "%s\nCaught %s  ·  %s" % [best.name, VF.commas(int(VF.discovered.get(best.f, 0))), fact]
		if int(best.row) >= 0:
			text = "%s\nWanted no more  ·  %s" % [best.name, IN_THE_TANK.get(String(VFData.GERALD[int(best.row)].biome), "Behaving. For now.")]
		text += "\n\"%s\"" % String(TRICK_SAYS[trick].pick_random())
		_say = {"f": best.f, "name": best.name, "text": text, "t": 0.0}
		_talks = _talks.filter(func(tk): return tk.s != best)
		_do_trick(best, trick)
	elif _chest_rect().grow(8.0).has_point(e.position):
		_puff("pop", _chest_rect().get_center() + Vector2(0, -20), 1.4)
		AudioManager.play_fun("pop", -14.0, randf_range(0.8, 1.0))
	elif _swim.is_empty():
		AudioManager.play_fun("clunk", -16.0)
	else:                                              # the water: a pinch of food
		if _food.size() < 40:
			for i in 5:
				_food.append({"x": clampf(e.position.x + randf_range(-26.0, 26.0), 10.0, _tank.size.x - 10.0),
					"y": e.position.y + randf_range(-10.0, 10.0), "t": randf_range(0.0, 0.6)})
		AudioManager.play_fun("pop", -18.0, randf_range(1.5, 1.8))
	refresh_badges()


## What the tapped one does about it (TRICK). Everyone else gets a wiggle.
func _do_trick(s: Dictionary, trick: String) -> void:
	match trick:
		"puff":
			s.act_t = 1.8
			AudioManager.play_fun("pfff", -14.0, randf_range(0.9, 1.1))
		"ink":
			s.act_t = 0.1
			s.flee = 1.1
			_puff("ink", _fish_at(s), 2.6)
			AudioManager.play_fun("pfff", -16.0, 1.4)
		"nap":
			s.act_t = 6.0
			AudioManager.play_fun("slide_down", -18.0)
		"flip":
			s.act_t = 0.8
			AudioManager.play_fun("whoosh", -14.0, 1.2)
		"grin":
			s.act_t = 1.0
			for o in _swim:
				if o != s and String(o.act) == "": o.flee = 1.0
			AudioManager.play_fun("dundun", -14.0)
		"snip":
			s.act_t = 0.7
			AudioManager.play_fun("snip", -12.0)
		"stare":
			s.act_t = 2.2
			AudioManager.play_fun("clunk", -16.0, 0.8)
		_:
			trick = "hi"
			s.act_t = 0.6
			AudioManager.play_fun("boing", -14.0, randf_range(0.9, 1.15))
	s.act = trick


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
	for f in VFData.FISH_ORDER: VF.discovered[f] = maxi(int(VF.discovered.get(f, 0)), 12)      # a full tank: feeding, tricks, the shark, the visitors
	m._open_panel("aquarium")
	await wait.call(0.6)
	var spot := Vector2(_tank.size.x * 0.5, _tank.size.y * 0.3)
	var room := 0.0
	for i in 24:                                           # (clear water: a tap on a fish is a hello, not lunch)
		var c := Vector2(_tank.size.x * randf_range(0.15, 0.7), _tank.size.y * randf_range(0.15, 0.6))
		var near := 1e9
		for s in _swim: near = minf(near, _fish_at(s).distance_to(c))
		if near > room:
			room = near
			spot = c
	m._tap(m.get_viewport().get_final_transform() * (_tank.get_global_transform() * spot))
	await wait.call(0.1)
	var dropped := _food.size()
	await wait.call(1.6)
	print("COLLECT feed: %d flakes dropped, %d left, %d hearts" % [dropped, _food.size(), _fx.filter(func(p): return p.k == "heart").size()])
	await m._shot(dir + "/collect7b_feed.png")
	for s in _swim:
		if s.name == "Pufferfish":
			m._tap(m.get_viewport().get_final_transform() * (_tank.get_global_transform() * _fish_at(s)))
			await wait.call(0.5)
			print("COLLECT trick: %s does '%s', card '%s'" % [s.name, s.act, String(_say.get("text", "")).replace("
", " / ")])
	await m._shot(dir + "/collect7c_trick.png")
	_say = {}
	_talks = []
	_hunt_t = 0.0
	_chat_t = 0.0
	_vis_t = 0.0
	for p in _vis: p.x = clampf(p.x, 0.15, 0.85)
	await wait.call(1.4)
	print("COLLECT life: hunt=%s talks=%d visitors=%d stopped=%d" % [not _hunt.is_empty(), _talks.size(), _vis.size(), _vis.filter(func(p): return p.stop > 0.0).size()])
	await m._shot(dir + "/collect7d_life.png")
	await wait.call(3.0)
	await m._shot(dir + "/collect7e_life.png")
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
	m.panel_scroll.scroll_vertical = 100000
	await wait.call(0.2)
	await m._shot(dir + "/collect10_wanted_done_lower.png")

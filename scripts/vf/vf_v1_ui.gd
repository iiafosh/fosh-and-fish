extends RefCounted
## 1.0 on the main screen (vf_main): the Pearls pill, the event pill (time left, the boss's health) and the
## event glow, event banners, event fish and the shiny celebration; the Store (Packs, Pearls, Pearl Shop,
## Free) and Events (what's on, the Event Shop) panels and the Fish Book's Shiny / Event fish tabs.
## Built with vf_main's UI kit (sbox, lbl, btn, icon, ph, tex, _card, _act, _grid, money_str).
## Game rules live in VF (vf_game.gd "1.0"), purchases in Store, ads in Ads, shiny rolls in Backend.

const C_TEXT := Color("#1f2d35")
const C_MUTED := Color("#6b7d86")
const C_GOOD := Color("#22a06b")
const C_GOLD := Color("#d4920f")
const C_TEAL := Color("#1d9bb0")
const C_PEARL := Color("#a78bfa")
const C_STAR := Color("#f59e0b")
const HINT_EVERY := 900.0             # seconds between "sign in to catch shiny fish" hints

var m                                 # vf_main
var pearls_btn: Button
var event_pill: PanelContainer
var event_icon: TextureRect
var event_title: Label
var event_sub: Label
var boss_bar: ProgressBar
var glow: ColorRect
var _glow_k := 0.0
var _hint_at := -1.0e9
var _sold_out_told := {}


func _init(main) -> void:
	m = main
	VF.event_started.connect(_on_event_started)
	VF.event_ended.connect(_on_event_ended)
	VF.shiny_ticket.connect(_on_shiny_ticket)
	VF.trip_done.connect(_on_trip)
	Store.changed.connect(func(): _rerender(["store"]))
	Ads.changed.connect(func(): _rerender(["store"]))
	Backend.shiny_changed.connect(func(): _rerender(["inventory"]))


func _rerender(kinds: Array) -> void:
	if m.overlay.visible and m._panel_kind in kinds:
		m._render_panel()


# ===================================================================== art
func pearl_tex() -> Texture2D:
	var t: Texture2D = m.tex("ui/pearl.png")
	return t if t else m.ph("drop")

func star_tex() -> Texture2D:
	var t: Texture2D = m.tex("ui/star.png")
	return t if t else m.ph("star")

func shiny_tex(species: String) -> Texture2D:
	var t: Texture2D = m.tex("shiny/%s.png" % VFData.slug(species))
	return t if t else m.icon_for("fish", species)

func event_fish_tex(f: String) -> Texture2D:
	var t: Texture2D = m.tex("event/%s.png" % VFData.slug(f))
	return t if t else m.ph("fish")

func pack_tex(id: String) -> Texture2D:
	var t: Texture2D = m.tex("packs/%s.png" % id)
	return t if t else m.ph("gift")

func rod_tex(r: String) -> Texture2D:
	var t: Texture2D = m.icon_for("rod", r)
	return t if t else m.ph("crown")


# ===================================================================== HUD
## the Pearls pill next to your money, the event pill under your buffs, the event glow over the water
func build_hud() -> void:
	pearls_btn = m.pill_button("drop", "0", "", false)
	pearls_btn.icon = pearl_tex()
	pearls_btn.add_theme_constant_override("icon_max_width", 18)
	pearls_btn.tooltip_text = "Pearls: spend them in the Pearl Shop (Menu -> Store)"
	pearls_btn.pressed.connect(func(): AudioManager.play_click(); m._open_panel("store", "Pearl Shop" if VF.pearls > 0 else "Packs"))
	m.hud_row.add_child(pearls_btn)
	m.hud_row.move_child(pearls_btn, 2)                         # after the level and the money
	event_pill = PanelContainer.new()
	event_pill.add_theme_stylebox_override("panel", m.pill_box(false, 10, 5))
	event_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	event_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	event_pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	event_pill.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: m._open_panel("events"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	event_icon = m.icon(m.ph("confetti"), 18)
	h.add_child(event_icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	event_title = m.lbl("", 13, Color.WHITE)
	event_sub = m.lbl("", 10, Color(1, 1, 1, 0.75))
	v.add_child(event_title)
	v.add_child(event_sub)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(150, 6)
	boss_bar.add_theme_stylebox_override("background", m.sbox(Color(1, 1, 1, 0.18), 3, 0, Color.TRANSPARENT, 0))
	boss_bar.add_theme_stylebox_override("fill", m.sbox(Color("#ef4444"), 3, 0, Color.TRANSPARENT, 0))
	v.add_child(boss_bar)
	h.add_child(v)
	event_pill.add_child(h)
	m.hud_col.add_child(event_pill)
	# a soft glow round the screen edges in the event's colour (under the HUD, over the water)
	glow = ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.2, 1.0);
uniform float strength = 0.0;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.5, 1.0));
	float edge = smoothstep(0.42, 0.95, d);
	float pulse = 0.82 + 0.18 * sin(TIME * 2.6);
	COLOR = vec4(tint.rgb, edge * strength * pulse * 0.55);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	glow.material = mat
	m.add_child(glow)
	m.move_child(glow, m.fx_layer.get_index())
	tick(0.0)


func tick(delta: float) -> void:
	if pearls_btn == null: return
	m.pill_text(pearls_btn, VF.commas(VF.pearls))
	var on: bool = VF.event_active()
	if on:
		var e: Dictionary = VFData.EVENTS[VF.ev_id]
		event_icon.texture = m.ph(e.icon)
		event_icon.modulate = e.color.lightened(0.25)
		event_title.text = "%s  %s" % [e.name, m._clock(VF.event_left())]
		event_sub.text = e.desc
		boss_bar.visible = VF.ev_id == "boss"
		if boss_bar.visible:
			boss_bar.max_value = float(e.boss_hp)
			boss_bar.value = float(VF.ev_boss_hp)
		var sb: StyleBoxFlat = m.pill_box(false, 10, 5)
		sb.bg_color = Color(e.color.darkened(0.45), 0.86)
		sb.border_color = e.color
		sb.set_border_width_all(2)
		event_pill.add_theme_stylebox_override("panel", sb)
		(glow.material as ShaderMaterial).set_shader_parameter("tint", e.color)
	else:
		event_icon.texture = m.ph("confetti")
		event_icon.modulate = Color(1, 1, 1, 0.6)
		event_title.text = "Next event in %s" % m._clock(VF.event_next_in())
		event_sub.text = "Keep fishing: events come every 10 minutes of play"
		boss_bar.visible = false
		event_pill.add_theme_stylebox_override("panel", m.pill_box(false, 10, 5))
	event_sub.visible = on or m.overlay.visible == false and not m.compact()
	event_pill.visible = VF.level >= 3 or on                     # not in the very first minutes
	_glow_k = move_toward(_glow_k, 1.0 if on else 0.0, delta * 1.5)
	(glow.material as ShaderMaterial).set_shader_parameter("strength", _glow_k)
	glow.visible = _glow_k > 0.001


# ================================================================== events
func _on_event_started(id: String) -> void:
	var e: Dictionary = VFData.EVENTS[id]
	m._banner(e.name, "%s  ·  %s" % [e.desc, m._clock(float(e.secs))], m.ph(e.icon) if not m.tex("event/%s.png" % id) else m.tex("event/%s.png" % id), e.color)
	AudioManager.play_levelup()
	var c: Vector2 = m.get_viewport_rect().size * 0.5
	m.stage.burst("confetti", c)
	if id == "boss":
		m._toast("Catch fish to wear the Leviathan down before it swims off!", "warn")


func _on_event_ended(id: String, boss_caught: bool) -> void:
	if id == "boss" and boss_caught:
		var f := "Leviathan"
		m._banner("You caught the Leviathan!", "+%s  ·  +%d Event Stars  ·  a legendary chest" % [m.money_str(VF.event_fish_money(f)), VFData.EVENT_FISH[f].stars],
			event_fish_tex(f), Color("#ef4444"))
		m.stage.burst("confetti", m.get_viewport_rect().size * 0.5)
		AudioManager.play_levelup()
	else:
		m._toast("%s is over. Next event in %s of play" % [VFData.EVENTS[id].name, m._clock(VFData.EVENT_EVERY)], "quest")


func _on_trip(res: Dictionary) -> void:
	if int(res.get("stars", 0)) > 0:
		m._float_text("+%d ★" % int(res.stars), m.stage.bobber_screen() + Vector2(40, -30), C_STAR)
	var f := String(res.get("event_fish", ""))
	if f != "" and f != "Leviathan":
		m._banner("%s!" % f, "Event fish  ·  +%s  ·  +%d Event Stars" % [m.money_str(int(res.event_money)), VFData.EVENT_FISH[f].stars],
			event_fish_tex(f), VFData.EVENTS[VFData.EVENT_FISH[f].event].color)
		m.stage.burst("sparkle", m.stage._bobber)
	if int(res.get("boss_hp", -1)) > 0:
		m._float_text("Leviathan  %d / %d" % [int(res.boss_hp), VFData.EVENTS.boss.boss_hp], m.stage.bobber_screen() + Vector2(-60, -90), Color("#ef4444"))


# ================================================================= shinies
func _on_shiny_ticket(species: String) -> void:
	if Backend.state != "signed_in":
		var now := Time.get_unix_time_from_system()
		if now - _hint_at > HINT_EVERY and Backend.configured():
			_hint_at = now
			m.stage.burst("sparkle", m.stage._bobber)
			m._toast("A shiny %s glimmered! Sign in (Menu -> Account) to catch shiny fish: only %s of each exist" % [species, VF.commas(VFData.SHINY_SUPPLY)], "unlock")
		return
	var r: Dictionary = await Backend.try_shiny(species)
	if bool(r.get("ok", false)):
		celebrate(species, int(r.serial), int(r.get("left", 0)))
	elif r.get("reason") == "sold_out" and not _sold_out_told.has(species):
		_sold_out_told[species] = true
		m._toast("Every shiny %s has been found: all %s are taken!" % [species, VF.commas(VFData.SHINY_SUPPLY)], "warn")
	elif r.get("reason") == "no_luck":
		m.stage.burst("sparkle", m.stage._bobber)                 # a glint... not this time


## the big moment: a white flash, sparkles, and the numbered shiny
func celebrate(species: String, serial: int, left: int) -> void:
	AudioManager.play_levelup()
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.fx_layer.add_child(flash)
	var ft := flash.create_tween()
	ft.tween_property(flash, "color:a", 0.75, 0.08)
	ft.tween_property(flash, "color:a", 0.0, 0.6)
	ft.tween_callback(flash.queue_free)
	for k in 3:
		m.stage.burst("sparkle" if k != 1 else "magic", m.stage._bobber)
	m.stage.burst("confetti", m.get_viewport_rect().size * 0.5)
	var p := PanelContainer.new()
	var sb: StyleBoxFlat = m.sbox(Color("#1b1036", 0.94), 22, 3, Color("#ffd75e"), 18, 22)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.add_child(m.icon(shiny_tex(species), 96))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.add_child(m.lbl("SHINY!", 15, Color("#ffd75e")))
	v.add_child(m.lbl("Shiny %s" % species, 30, Color.WHITE))
	v.add_child(m.lbl("No. %04d of %s  ·  %s left in the world" % [serial, VF.commas(VFData.SHINY_SUPPLY), VF.commas(left)], 15, Color(1, 1, 1, 0.85)))
	v.add_child(m.lbl("+%d%% sell price for every shiny species you own" % int(VFData.SHINY_SELL_BONUS * 100), 12, Color("#c4b5fd")))
	h.add_child(v)
	p.add_child(h)
	m.fx_layer.add_child(p)
	await m.get_tree().process_frame
	if not is_instance_valid(p): return
	var vs: Vector2 = m.get_viewport_rect().size
	p.pivot_offset = p.size * 0.5
	p.position = (vs - p.size) * 0.5 - Vector2(0, vs.y * 0.08)
	p.scale = Vector2(0.4, 0.4)
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


# ================================================================== panels
## vf_main._card, with a white Phosphor icon tinted so it shows on the light card
func _card(t: Texture2D, title: String, desc: String, right: Control = null, dim := false, size := 64, tint := C_TEAL) -> PanelContainer:
	var c: PanelContainer = m._card(t, title, desc, right, dim, size)
	if t and String(t.resource_path).find("/phosphor/") >= 0:
		for n in c.find_children("*", "TextureRect", true, false):
			n.modulate = tint
			break
	return c


## 900 -> "15 min", 3600 -> "1h", 5400 -> "1h 30 min"
static func dur(secs: float) -> String:
	var mins := int(round(secs / 60.0))
	if mins < 60: return "%d min" % mins
	return ("%dh" % (mins / 60)) + ((" %d min" % (mins % 60)) if mins % 60 else "")


func _note(text: String, color := C_MUTED, size := 13) -> Label:
	var l: Label = m.lbl(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.panel_body.add_child(l)
	return l


func _balance_row() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	for item in [[pearl_tex(), "%s Pearls" % VF.commas(VF.pearls), C_PEARL], [star_tex(), "%s Event Stars" % VF.commas(VF.stars), C_STAR]]:
		var c := HBoxContainer.new()
		c.add_theme_constant_override("separation", 6)
		var ic: TextureRect = m.icon(item[0], 24)
		if item[0] is Texture2D and String(item[0].resource_path).begins_with("res://assets/third_party/phosphor"): ic.modulate = item[2]
		c.add_child(ic)
		c.add_child(m.lbl(item[1], 16, item[2].darkened(0.2)))
		h.add_child(c)
	m.panel_body.add_child(h)


## Menu -> Store
func panel_store(tab: String) -> void:
	_balance_row()
	match Store.mode:
		"test": _note("Test store: purchases are free and nothing is charged (debug build).", Color("#b45309"))
		"none": _note("Packs and Pearls are bought in the Android app (Google Play). Sign in there and here with the same account: what you buy comes with your cloud save.")
	if Store.message != "": _note(Store.message, Color("#b45309"))
	match tab:
		"Packs": _store_packs()
		"Pearls": _store_pearls()
		"Pearl Shop": _store_shop()
		"Free": _store_free()


func _buy_button(id: String) -> Control:
	if Store.owns(id):
		return m.lbl("Owned", 16, C_GOOD)
	var can: bool = Store.mode != "none" and Store.busy == ""
	var b: Button = m._act(Store.price(id) if Store.busy != id else "...", Color("#22a06b"), func(): Store.buy(id); return "", can)
	return b


func _store_packs() -> void:
	_note("One-time packs, yours forever. Every pack unlocks the Supporter Rod; their bonuses add up.")
	var g: GridContainer = m._grid(2)
	var tags := {"pack_captain": "Most popular", "pack_legend": "Best value"}
	for id in VFData.PACK_ORDER:
		var d: Dictionary = VFData.PACKS[id]
		var bits := ["Supporter Rod"]
		for r in d.get("rods", []): bits.append(r)
		bits.append("%s Pearls" % VF.commas(int(d.pearls)))
		var pk: Dictionary = d.perks
		if pk.has("money"): bits.append("+%d%% money forever" % int(round(pk.money * 100)))
		if pk.has("xp"): bits.append("+%d%% XP forever" % int(round(pk.xp * 100)))
		if pk.has("worker"): bits.append("Workers last %d%% longer" % int(round(pk.worker * 100)))
		if pk.has("shiny"): bits.append("+%d%% shiny chance" % int(round(pk.shiny * 100)))
		var bmins := 0
		for b in d.get("boost", []): bmins = maxi(bmins, int(b[1]) / 60)
		if bmins > 0: bits.append(("%s of every boost" % dur(bmins * 60.0)) if d.get("boost", []).size() > 1 else ("%s Fish Boost" % dur(bmins * 60.0)))
		var card: PanelContainer = _card(pack_tex(id), d.name + ("   ·  " + tags[id] if tags.has(id) else ""), "\n".join(bits.map(func(x): return "•  " + x)),
			_buy_button(id), false, 72, d.color)
		var sb: StyleBoxFlat = m.sbox(Color("#f6fbfc"), 14, 2, d.color.lightened(0.2), 12)
		card.add_theme_stylebox_override("panel", sb)
		m._add_to(g, card)


func _store_pearls() -> void:
	_note("Pearls buy boosts, chests, events, the Shiny Lure and the Pearl Rod in the Pearl Shop.")
	var g: GridContainer = m._grid(2)
	var base := float(VFData.PEARL_PACKS.pearls_100.pearls)
	for id in VFData.PEARL_PACK_ORDER:
		var d: Dictionary = VFData.PEARL_PACKS[id]
		var bonus := ""
		var dollars := float(String(d.price).trim_prefix("$"))
		var per := float(d.pearls) / maxf(0.01, dollars)
		var base_per := base / 0.99
		if per > base_per * 1.04: bonus = "  +%d%% bonus" % int(round((per / base_per - 1.0) * 100.0))
		m._add_to(g, _card(pearl_tex(), "%s Pearls%s" % [VF.commas(int(d.pearls)), bonus], "", _buy_button(id), false, 56, C_PEARL))


func _store_shop() -> void:
	var g: GridContainer = m._grid(2)
	for id in VFData.PEARL_SHOP_ORDER:
		var d: Dictionary = VFData.PEARL_SHOP[id]
		var owned: bool = d.has("rod") and d.rod in VF.owned_rods
		var right: Control
		if owned:
			right = m.lbl("Owned", 15, C_GOOD)
		else:
			var buy := func():
				var r: Dictionary = VF.buy_pearl_item(id)
				if r.has("error"): return r.error
				AudioManager.play_success()
				m._toast("%s!  %s" % [d.name, VF.got_text(r)], "buy")
				m._render_panel()
				return ""
			right = m._act("%s Pearls" % VF.commas(int(d.cost)), C_PEARL.darkened(0.25), buy, VF.pearls >= int(d.cost))
		var ic: Texture2D = rod_tex(d.rod) if d.has("rod") else m.ph(String(d.get("icon", "sparkle")))
		m._add_to(g, _card(ic, d.name, _item_desc(d), right, false, 48, C_PEARL.darkened(0.2)))


## what a Pearl Shop / Event Shop / ad item does, in words
func _item_desc(d: Dictionary) -> String:
	var bits := []
	var kinds := []
	var secs := 0.0
	for b in d.get("boost", []):
		kinds.append(String(b[0]).capitalize())
		secs = float(b[1])
	if not kinds.is_empty():
		bits.append("%s boost%s for %s" % [" + ".join(kinds), "s" if kinds.size() > 1 else "", dur(secs)])
	if d.has("money_levels"): bits.append("%s right now" % m.money_str(int(maxf(1000.0, VF.levelup_money(VF.level)) * float(d.money_levels))))
	if d.has("xp_frac"): bits.append("+%s XP (half a level)" % VF.fmt(VF.xp_to_next() * float(d.xp_frac)))
	if d.has("chest"): bits.append("A %s chest" % String(d.chest))
	if d.has("event"): bits.append("A random event starts now")
	if d.has("lure"): bits.append("Your next %d catches: shiny fish 3x as often" % int(d.lure))
	if d.has("rod"): bits.append(VFData.RODS[d.rod].desc)
	if d.has("money2x"): bits.append("x2 money from selling for %d minutes" % int(float(d.money2x) / 60.0))
	if d.has("pearls"): bits.append("+%d Pearls" % int(d.pearls))
	if d.has("desc") and bits.is_empty(): bits.append(String(d.desc))
	return "  ·  ".join(bits)


func _store_free() -> void:
	if not Ads.available():
		_note("Free rewards for watching a short ad are in the Android app.")
		return
	_note("Watch a short ad, get a reward. %d ads a day." % VFData.AD_DAILY_MAX)
	if Ads.mode == "test": _note("Test ads: a pretend 2-second ad (debug build).", Color("#b45309"))
	if Ads.message != "": _note(Ads.message, Color("#b45309"))
	var g: GridContainer = m._grid(2)
	for id in VFData.AD_ORDER:
		var d: Dictionary = VFData.AD_REWARDS[id]
		var left: int = VF.ad_left(id)
		var label := "Watching..." if Ads.watching == id else ("Watch ad" if left > 0 else "Done today")
		var right: Button = m._act(label, Color("#2563eb"), func(): Ads.watch(id); return "", Ads.can_watch(id))
		m._add_to(g, _card(m.ph(String(d.icon)), d.name, "%s\n%d left today" % [d.desc, left], right, left <= 0, 44, Color("#2563eb")))


## Menu -> Events
func panel_events(tab: String) -> void:
	_balance_row()
	if tab == "Event Shop":
		_note("Event Stars come from every catch during an event and from event fish. The shop's things are exclusive.")
		var g: GridContainer = m._grid(2)
		for id in VFData.EVENT_SHOP_ORDER:
			var d: Dictionary = VFData.EVENT_SHOP[id]
			var owned: bool = d.has("rod") and d.rod in VF.owned_rods
			var buy := func():
				var r: Dictionary = VF.buy_event_item(id)
				if r.has("error"): return r.error
				AudioManager.play_success()
				m._toast("%s!  %s" % [d.name, VF.got_text(r)], "buy")
				m._render_panel()
				return ""
			var right: Control = m.lbl("Owned", 15, C_GOOD) if owned else m._act("%s ★" % VF.commas(int(d.cost)), C_STAR.darkened(0.2), buy, VF.stars >= int(d.cost))
			var ic: Texture2D = rod_tex(d.rod) if d.has("rod") else m.ph("gift")
			m._add_to(g, _card(ic, d.name, d.desc, right, false, 48, C_STAR))
		return
	if VF.event_active():
		var e: Dictionary = VFData.EVENTS[VF.ev_id]
		var card: PanelContainer = _card(m.ph(e.icon), "Now: %s  (%s left)" % [e.name, m._clock(VF.event_left())], e.desc, null, false, 48, e.color)
		card.add_theme_stylebox_override("panel", m.sbox(e.color.lightened(0.75), 14, 2, e.color, 12))
		m.panel_body.add_child(card)
	else:
		_note("Next event in %s of fishing. Events come every 10 minutes of play (idle time doesn't count)." % m._clock(VF.event_next_in()), C_TEXT, 15)
	var g2: GridContainer = m._grid(2)
	for id in VFData.EVENT_ORDER:
		var e: Dictionary = VFData.EVENTS[id]
		var f: String = e.fish_id
		var fd: Dictionary = VFData.EVENT_FISH[f]
		var how := "%s (%d%% of catches)" % [f, int(round(fd.chance * 100))] if id != "boss" else "Wear it down with %d catches to land the %s" % [e.boss_hp, f]
		m._add_to(g2, _card(event_fish_tex(f), e.name, "%s\nEvent fish: %s" % [e.desc, how], null, false, 56, e.color))


## Fish Book -> Shiny
func tab_shiny() -> void:
	if Backend.configured() and Backend.shiny_state == "" or (Backend.shiny_state == "ok" and Backend.shiny_board.is_empty()):
		Backend.load_shinies()
	var owned: int = VF.shiny_species_owned()
	_note("Shiny fish are rare sparkling versions. Only %s of each exist in the whole world, numbered. You can own up to %d of each, and every shiny species you own adds +%d%% to your sell price (now +%d%%)."
		% [VF.commas(VFData.SHINY_SUPPLY), VFData.SHINY_MAX_EACH, int(VFData.SHINY_SELL_BONUS * 100), int(VF.shiny_bonus() * 100)], C_TEXT, 14)
	if Backend.state != "signed_in":
		var row := HBoxContainer.new()
		var l: Label = m.lbl("Shiny fish need an account: the server keeps the count fair for everyone.", 14, Color("#7c3aed"))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		row.add_child(m._act("Sign in", Color("#6366f1"), func(): m._open_panel("account", "Account"); return ""))
		m.panel_body.add_child(row)
	m.panel_body.add_child(m.lbl("Your shinies  %d / %d species" % [owned, VFData.FISH_ORDER.size()], 18))
	var g: GridContainer = m._grid(5)
	for f in VFData.FISH_ORDER:
		var mine: Array = VF.shinies.get(f, [])
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic: TextureRect = m.icon(shiny_tex(f) if not mine.is_empty() else m.icon_for("fish", f), 56)
		if mine.is_empty(): ic.modulate = Color(0.1, 0.12, 0.18, 0.5)
		box.add_child(ic)
		var name: Label = m.lbl(f, 12, C_TEXT if not mine.is_empty() else C_MUTED)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name)
		var serials := ", ".join(mine.map(func(n): return "No. %04d" % int(n)))
		var left := ""
		if Backend.shiny_board.has(f):
			left = "%s left" % VF.commas(int(Backend.shiny_board[f].left))
		var sub: Label = m.lbl(serials if serials != "" else left, 10, Color("#7c3aed") if serials != "" else C_MUTED)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(sub)
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", m.sbox(Color("#f3efff") if not mine.is_empty() else Color("#eef4f6"), 12, 1 if not mine.is_empty() else 0, Color("#c4b5fd"), 8))
		cell.add_child(box)
		cell.tooltip_text = "Shiny %s\n%s%s" % [f, ("You own " + serials + "\n") if serials != "" else "", left]
		m._add_to(g, cell)
	if not Backend.shiny_feed.is_empty():
		m.panel_body.add_child(m.lbl("Latest finds", 18))
		for row in Backend.shiny_feed.slice(0, 8):
			_note("%s found Shiny %s No. %04d" % [row.get("display_name", "?"), row.get("species", "?"), int(row.get("serial", 0))], C_MUTED, 13)


## Fish Book -> Event fish
func tab_event_fish() -> void:
	_note("Event fish only bite during their event. Each one pays well and gives Event Stars.", C_TEXT, 14)
	var g: GridContainer = m._grid(5)
	for f in VFData.EVENT_FISH_ORDER:
		var n := int(VF.event_fish.get(f, 0))
		var box := VBoxContainer.new()
		var ic: TextureRect = m.icon(event_fish_tex(f), 64)
		if n == 0: ic.modulate = Color(0.1, 0.12, 0.18, 0.5)
		box.add_child(ic)
		var t: Label = m.lbl(f, 13, C_TEXT if n > 0 else C_MUTED)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(t)
		var e: Dictionary = VFData.EVENTS[VFData.EVENT_FISH[f].event]
		var s: Label = m.lbl(("Caught %s" % VF.commas(n)) if n > 0 else e.name, 11, e.color.darkened(0.2) if n > 0 else C_MUTED)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(s)
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", m.sbox(Color("#eef4f6"), 12, 0, Color.TRANSPARENT, 8))
		cell.add_child(box)
		m._add_to(g, cell)


# ============================================================== capture test
## godot --path . -- --capture=DIR --v1-test : events, an event fish, the boss, a shiny celebration, a test
## purchase, the Pearl Shop, an ad reward, and every 1.0 panel, as screenshots in DIR (never saves).
func capture_test(dir: String) -> void:
	VF._apply(VF._defaults.duplicate(true))
	m._veteran("Ocean")
	VF.tutorial = 99
	VF.changed.emit()
	m._coach_show()
	await m._wait(0.8)
	VF.start_event("golden_hour")
	await m._wait(1.6)
	await m._shot(dir + "/v1_event_start.png")
	VF.rng.seed = 4
	for i in 6:
		VF._last_cast_ms = -100000
		m._do_cast()
		await m._wait(1.0)
		if VF.event_fish.size() > 0: break
	await m._wait(0.8)
	await m._shot(dir + "/v1_event_catch.png")
	VF._ev_end(false)
	VF.start_event("boss")
	VF.ev_boss_hp = 3
	for i in 3:
		VF._last_cast_ms = -100000
		m._do_cast()
		await m._wait(1.0)
	await m._wait(0.8)
	await m._shot(dir + "/v1_boss.png")
	celebrate("Rainbow Fish", 42, 2958)
	await m._wait(0.7)
	await m._shot(dir + "/v1_shiny.png")
	await m._wait(4.0)
	Store.buy("pack_captain")
	VF.add_shiny("Rainbow Fish", 42)
	VF.add_shiny("Cod", 1207)
	VF.stars = 260
	VF.event_fish = {"Golden Koi": 3, "Meteor Fish": 1, "Leviathan": 1}
	for t in ["Packs", "Pearls", "Pearl Shop", "Free"]:
		m._open_panel("store", t)
		await m._wait(0.4)
		await m._shot(dir + "/v1_store_%s.png" % t.to_lower().replace(" ", "_"))
	if Ads.available():
		Ads.watch("ad_money2x")
		await m._wait(0.3)
		await m._shot(dir + "/v1_ad_watching.png")
		await m._wait(2.8)
	for t in ["Events", "Event Shop"]:
		m._open_panel("events", t)
		await m._wait(0.4)
		await m._shot(dir + "/v1_events_%s.png" % t.to_lower().replace(" ", "_"))
	for t in ["Shiny", "Event fish"]:
		m._open_panel("inventory", t)
		await m._wait(0.4)
		await m._shot(dir + "/v1_book_%s.png" % t.to_lower().replace(" ", "_"))
	m._open_panel("shop", "Rods")
	await m._wait(0.3)
	m.panel_scroll.scroll_vertical = 100000
	await m._wait(0.3)
	await m._shot(dir + "/v1_shop_rods.png")
	m._open_panel("menu")
	await m._wait(0.3)
	await m._shot(dir + "/v1_menu.png")
	m._close_panel()
	await m._wait(0.3)
	await m._shot(dir + "/v1_hud.png")
	print("V1 pearls=%d packs=%s stars=%d money2x=%.0f rods=%s" % [VF.pearls, VF.packs, VF.stars, VF.money2x_left(), VF.owned_rods])

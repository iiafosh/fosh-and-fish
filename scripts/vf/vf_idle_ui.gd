extends RefCounted
## Idle play on the main screen (vf_main): the Auto switch (your boat fishes by itself), the Fleet pill and the
## crew boats' splashes, the welcome-back card (what the crews caught while you were away), the Daily pill;
## the Fleet (Crews, Upgrades) and Daily (Calendar, Spin) panels and the wheel.
## Built with vf_main's UI kit (sbox, lbl, btn, icon, ph, tex, _card, _act, _grid, money_str).
## Game rules live in VF (vf_game.gd "Idle"), data in VFData ("idle").

const C_TEXT := Color("#1f2d35")
const C_MUTED := Color("#6b7d86")
const C_GOOD := Color("#22a06b")
const C_GOLD := Color("#d4920f")
const C_TEAL := Color("#1d9bb0")
const C_AD := Color("#2563eb")
const C_SUN := Color("#ffd75e")
const C_PANEL2 := Color("#eef4f6")          # (vf_main.C_PANEL2: cards inside panels)
const SPIN_SECS := 3.6

var m                                 # vf_main
var auto_pill: Button
var fleet_pill: PanelContainer
var fleet_title: Label
var fleet_sub: Label
var gift_btn: Button
var back_card: Control                # the welcome-back card, while it's up
var _back_panel: PanelContainer
var _shown_crews := -1
var _on_screen := false               # the game is showing (the title screen has closed)
var _wheel: Control
var _spin_from := 0.0                 # the wheel's turn, in degrees clockwise
var _spin_to := 0.0
var _spin_rot := 0.0
var _spin_t0 := -1                    # ticks ms the spin started (-1: not spinning)
var _spin_prize := {}
var _spin_tick := -1


func _init(main) -> void:
	m = main
	VF.crew_trip.connect(_on_crew_trip)
	VF.offline_ready.connect(func(_o): _offer_back())
	VF.leveled_up.connect(_on_level)
	Ads.changed.connect(func():
		if back_card: _fill_back()
		_rerender(["daily"]))


func _rerender(kinds: Array) -> void:
	if m.overlay.visible and m._panel_kind in kinds:
		m._render_panel()


# ===================================================================== HUD
func build_hud() -> void:
	# Auto: above the catch-mode pill, left of the cast button
	auto_pill = m.pill_button("robot", "Auto")
	auto_pill.anchor_left = 1.0
	auto_pill.anchor_right = 1.0
	auto_pill.anchor_top = 1.0
	auto_pill.anchor_bottom = 1.0
	auto_pill.offset_right = -112
	auto_pill.offset_top = -125
	auto_pill.offset_bottom = -85
	auto_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	auto_pill.pressed.connect(func():
		VF.set_auto(not VF.auto_on)
		_style_auto()
		m._toast("Auto-fish on: your boat casts by itself. Tap or hold to fish faster" if VF.auto_on else "Auto-fish off", "quest"))
	m.add_child(auto_pill)
	m.move_child(auto_pill, m.mode_pill.get_index() + 1)          # (under the menus)
	# the Fleet: a dark pill in the left column (click: the Fleet)
	fleet_pill = PanelContainer.new()
	fleet_pill.add_theme_stylebox_override("panel", m.pill_box(false, 10, 5))
	fleet_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fleet_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	fleet_pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fleet_pill.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: m._open_panel("fleet"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var ic: TextureRect = m.icon(m.ph("sailboat"), 18)
	ic.modulate = Color("#7ef0c6")
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	fleet_title = m.lbl("", 13, Color.WHITE)
	fleet_sub = m.lbl("", 10, Color(1, 1, 1, 0.75))
	v.add_child(fleet_title)
	v.add_child(fleet_sub)
	h.add_child(v)
	fleet_pill.add_child(h)
	m.hud_col.add_child(fleet_pill)
	# Daily: a gift first in the top-right row, with a badge when something waits
	gift_btn = m.pill_button("gift", "Daily", "")
	gift_btn.tooltip_text = "Daily rewards: the 7-day calendar and the daily spin"
	gift_btn.pressed.connect(func(): m._open_panel("daily", "Calendar" if VF.daily_ready_in() <= 0.0 or not VF.spin_free() else "Spin"))
	m.top_right.add_child(gift_btn)
	m.top_right.move_child(gift_btn, 0)
	_style_auto()
	_refresh_hud()


func _style_auto() -> void:
	var on: bool = VF.auto_on
	var fc := Color.WHITE if on else C_TEXT
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		auto_pill.add_theme_color_override(k, fc)
	for st in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = m.pill_box(true, 13, 6)
		if on: sb.bg_color = C_GOOD.lightened(0.08 if st == "hover" else 0.0).darkened(0.12 if st == "pressed" else 0.0)
		elif st == "hover": sb.bg_color = Color.WHITE
		auto_pill.add_theme_stylebox_override(st, sb)
	auto_pill.text = "Auto: on" if on else "Auto"
	auto_pill.tooltip_text = ("Auto-fish is on: your boat casts by itself (a bit slower than holding the button). Click to stop." if on
		else "Auto-fish: let your boat cast by itself while you do other things.")


func _refresh_hud() -> void:
	auto_pill.visible = VF.auto_unlocked() and not m.launcher_open()
	gift_btn.visible = VF.level >= VFData.DAILY_LEVEL
	m.pill_badge(gift_btn, (1 if VF.daily_ready_in() <= 0.0 else 0) + (1 if VF.spin_free() else 0))
	fleet_pill.visible = VF.fleet_unlocked()
	if VF.crews <= 0:
		var c: int = VF.next_crew_cost()
		fleet_title.text = "Hire a crew  %s" % m.money_str(c)
		fleet_sub.text = "They fish for you, even while you're away"
		var sb: StyleBoxFlat = m.pill_box(false, 10, 5)
		if VF.money >= c:
			sb.border_color = C_SUN
			sb.set_border_width_all(2)
		fleet_pill.add_theme_stylebox_override("panel", sb)
	else:
		fleet_title.text = "%d crew%s  ·  %s fish/min" % [VF.crews, "" if VF.crews == 1 else "s", VF.fmt(VF.fleet_fish_per_min())]
		fleet_sub.text = "Fishing for you, even while you're away"
		fleet_pill.add_theme_stylebox_override("panel", m.pill_box(false, 10, 5))
	fleet_sub.visible = not m.compact()


func tick(_delta: float) -> void:
	if auto_pill == null: return
	_auto_step()
	if VF.crews != _shown_crews:
		_shown_crews = VF.crews
		m.stage.set_fleet(VF.crews)
	if Engine.get_process_frames() % 15 == 0:
		_refresh_hud()
		if auto_pill.text != ("Auto: on" if VF.auto_on else "Auto"): _style_auto()    # (a cloud save may switch it)
	if back_card and VF.offline.is_empty():
		_close_back()                                      # collected, or doubled by an ad
	if _spin_t0 >= 0:
		var seg := 360.0 / VFData.SPIN.size()
		var k := int(floor(_spin_angle() / seg))
		if k != _spin_tick:
			_spin_tick = k
			AudioManager.play_sfx("click", -14.0, 1.25)        # the wheel ticks past each slice
		if is_instance_valid(_wheel): _wheel.queue_redraw()
		if Time.get_ticks_msec() - _spin_t0 >= int(SPIN_SECS * 1000.0): _spin_done()


## your own boat casts by itself: Relax casts, VFData.AUTO_SLOW times the cooldown apart
func _auto_step() -> void:
	if not VF.auto_on or not VF.auto_unlocked() or back_card != null: return
	if m.launcher_open() or m.minigame != null or m.sail.busy() or Time.get_ticks_msec() < m._reel_wait_until: return
	if (Time.get_ticks_msec() - VF._last_cast_ms) / 1000.0 < VF.cooldown() * VFData.AUTO_SLOW: return
	if VF.can_cast() == "": m._do_cast(true)


## new things to try, the first time through
func _on_level(lvl: int, _money: int) -> void:
	if VF.prestige > 0: return
	if lvl == VFData.DAILY_LEVEL:
		m._banner("Daily rewards!", "A 7-day calendar and a free spin every day: tap Daily, top right", m.ph("gift"), Color("#f97316"))
	if lvl == VFData.AUTO_LEVEL:
		m._banner("Auto-fish & your fleet!", "Your boat can fish by itself (Auto), and crews you hire fish for you, even while you're away",
			m.ph("sailboat"), Color("#0e7490"))


# ================================================================== crews
func _on_crew_trip(n: int) -> void:
	m._refresh_hold()
	if m.launcher_open() or not m.stage.visible: return
	var at: Vector2 = m.stage.crew_splash()
	if at == Vector2.INF: return
	var l: Label = m.lbl("+%s" % VF.fmt(n), 15, Color("#e6fffb"), 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = at + Vector2(-16, -46)
	m.fx_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 34.0, 1.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.3).set_delay(0.4)
	tw.tween_callback(l.queue_free)


# ========================================================= welcome back
## the game is on screen (the title screen has closed): the welcome-back card can show
func on_shown() -> void:
	_on_screen = true
	_offer_back()


func _offer_back() -> void:
	if not _on_screen or VF.offline.is_empty() or m.launcher_open(): return
	if back_card == null: _open_back()
	else: _fill_back()


func _open_back() -> void:
	back_card = Control.new()
	back_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.1, 0.14, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_card.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	back_card.add_child(center)
	_back_panel = PanelContainer.new()
	_back_panel.add_theme_stylebox_override("panel", m.sbox(Color("#0b3a44", 0.97), 26, 3, C_SUN, 26, 24))
	_back_panel.custom_minimum_size.x = 600
	center.add_child(_back_panel)
	m.add_child(back_card)                                  # over everything: it's the first thing you see
	_fill_back()
	AudioManager.play_levelup()
	await m.get_tree().process_frame
	if not is_instance_valid(_back_panel): return
	_back_panel.pivot_offset = _back_panel.size * 0.5
	_back_panel.scale = Vector2(0.6, 0.6)
	_back_panel.create_tween().tween_property(_back_panel, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fill_back() -> void:
	if _back_panel == null or VF.offline.is_empty(): return
	for c in _back_panel.get_children(): c.queue_free()
	var o: Dictionary = VF.offline
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_back_panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	var boat: String = VFData.BOAT_ORDER[maxi(0, VF.crews - 1)]
	top.add_child(m.icon(m.icon_for("boat", boat), 84))
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", -2)
	tv.add_child(m.lbl("Welcome back!", 32, Color.WHITE))
	var away := float(o.away)
	var fished := float(o.secs)
	var sub := "You were away %s" % dur(away)
	if fished < away - 60.0: sub += "  ·  your crews filled the cooler in %s" % dur(fished)
	tv.add_child(m.lbl(sub, 15, Color(1, 1, 1, 0.75)))
	top.add_child(tv)
	v.add_child(top)
	v.add_child(m.lbl("Your %d crew%s caught" % [VF.crews, "" if VF.crews == 1 else "s"], 16, Color(1, 1, 1, 0.85)))
	v.add_child(m.lbl("%s fish" % VF.commas(int(o.n)), 44, C_SUN, 6))
	var xp := int(o.xp)
	v.add_child(m.lbl("worth about %s  ·  +%s XP" % [m.money_str(VF.offline_value()), VF.commas(xp) if xp < 1000000 else VF.fmt(xp)], 17, Color("#7ef0c6")))
	var names: Array = (o.fish as Dictionary).keys()
	names.sort_custom(func(a, b): return int(o.fish[a]) * VFData.FISH[a].price > int(o.fish[b]) * VFData.FISH[b].price)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for f in names.slice(0, 5):
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.add_child(m.icon(m.icon_for("fish", f), 40))
		cell.add_child(m.lbl("×%s" % VF.fmt(int(o.fish[f])), 14, Color.WHITE))
		cell.tooltip_text = f
		row.add_child(cell)
	v.add_child(row)
	var note: Label = m.lbl("Crews fish at %d%% while you're away, for up to %s. More: Fleet - Upgrades" % [int(round(VF.offline_rate() * 100.0)), dur(VF.offline_cap_secs())], 12, Color(1, 1, 1, 0.55))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(note)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	var collect: Button = m.btn("Collect", C_GOOD, 18, 200)
	collect.pressed.connect(func(): _collect())
	btns.add_child(collect)
	if Ads.available():
		var watching: bool = Ads.watching == "ad_offline2x"
		var x2: Button = m.btn("Watching..." if watching else "x2  ·  Watch an ad", C_AD, 18, 230)
		x2.disabled = not Ads.can_watch("ad_offline2x")
		x2.pressed.connect(func(): Ads.watch("ad_offline2x"))
		btns.add_child(x2)
	v.add_child(btns)
	if Ads.message != "" and Ads.watching == "":
		v.add_child(m.lbl(Ads.message, 12, Color("#fcd34d")))


func _collect() -> void:
	var r: Dictionary = VF.collect_offline(1.0)
	if r.has("error"): return
	AudioManager.play_success()
	_close_back()
	m._float_text("+%s fish in your hold" % VF.commas(int(r.n)), m.sell_btn.get_global_rect().get_center() + Vector2(-70, -64), C_SUN)


func _close_back() -> void:
	if back_card == null: return
	var c := back_card
	back_card = null
	_back_panel = null
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 0.0, 0.25)
	tw.tween_callback(c.queue_free)


## 120 -> "2 min", 5400 -> "1h 30m", 14400 -> "4h"
static func dur(secs: float) -> String:
	var mins := int(round(secs / 60.0))
	if mins < 60: return "%d min" % maxi(1, mins)
	return ("%dh" % (mins / 60)) + ((" %dm" % (mins % 60)) if mins % 60 else "")


## 3725 -> "1:02:05"
static func hms(secs: float) -> String:
	var s := int(ceil(secs))
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


# ================================================================== panels
func _note(text: String, color := C_MUTED, size := 13) -> Label:
	var l: Label = m.lbl(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.panel_body.add_child(l)
	return l


## vf_main._card, with a white Phosphor icon tinted so it shows on the light card
func _card(t: Texture2D, title: String, desc: String, right: Control = null, dim := false, size := 64, tint := C_TEAL) -> PanelContainer:
	var c: PanelContainer = m._card(t, title, desc, right, dim, size)
	if t and String(t.resource_path).find("/phosphor/") >= 0:
		for n in c.find_children("*", "TextureRect", true, false):
			n.modulate = tint
			break
	return c


## Menu -> Fleet
func panel_fleet(tab: String) -> void:
	if not VF.fleet_unlocked():
		_note("The fleet unlocks at level %d: crews you hire fish for you all the time, even while the game is closed." % VFData.FLEET_LEVEL, C_TEXT, 15)
		return
	var title := ("%d crew%s  ·  %s trips a minute" % [VF.crews, "" if VF.crews == 1 else "s", _num(VF.crew_trips_per_min())]
		if VF.crews > 0 else "No crews yet")
	var desc := ("About %s fish a minute with your %s in the %s.  While you're away: %d%% of that, for up to %s." % [
		VF.fmt(VF.fleet_fish_per_min()), VF.rod, VF.biome, int(round(VF.offline_rate() * 100.0)), dur(VF.offline_cap_secs())]
		if VF.crews > 0 else "Crews fish with your rod, in your biome, all the time - and keep fishing while the game is closed.")
	var total: Label = m.lbl("%s fish\ncaught so far" % VF.fmt(VF.fleet_fish_total), 14, C_GOLD)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	m.panel_body.add_child(_card(m.ph("sailboat"), title, desc, total, false, 52))
	if tab == "Upgrades":
		_fleet_upgrades()
	else:
		_fleet_crews()
	_note("Your fleet starts over when you prestige, like your boats.", C_MUTED, 12)


func _fleet_crews() -> void:
	var g: GridContainer = m._grid(2)
	var n := VFData.BOAT_ORDER.size()
	var last := mini(n, VF.crews + 2)                       # yours, the next one, and one to look forward to
	var per_crew: float = 60.0 / VF.crew_trip_secs()
	for k in last:
		var boat: String = VFData.BOAT_ORDER[k]
		var t: Texture2D = m.icon_for("boat", boat)
		if k < VF.crews:
			m._add_to(g, m._card(t, "%s crew" % boat, "Fishing for you: a trip every %ss" % _num(VF.crew_trip_secs()), m._tick(), false, 56))
		elif k == VF.crews:
			var c: int = VF.next_crew_cost()
			var b: Button = m._act("Hire  %s" % m.money_str(c), C_GOOD, func(): return VF.hire_crew(), VF.money >= c)
			m._add_to(g, m._card(t, "%s crew" % boat, "+%s trips a minute (about %s fish a minute)" % [_num(per_crew), VF.fmt(per_crew * VF.crew_trip_fish())], b, false, 56))
		else:
			m._add_to(g, m._card(t, "%s crew" % boat, "After the %s crew  ·  %s" % [VFData.BOAT_ORDER[k - 1], m.money_str(VF.crew_cost(k + 1))], null, true, 56))
	if last < n:
		_note("%d more boats to crew after that, all the way to the %s." % [n - last, VFData.BOAT_ORDER[n - 1]])


func _fleet_upgrades() -> void:
	var g: GridContainer = m._grid(2)
	for id in VFData.FLEET_UPGRADE_ORDER:
		var d: Dictionary = VFData.FLEET_UPGRADES[id]
		var lv: int = VF.fleet_lv(id)
		var c: int = VF.fleet_up_cost(id)
		var right: Control
		if c < 0:
			right = m.lbl("Maxed", 15, C_GOOD)
		else:
			right = m._act(m.money_str(c), C_GOOD, func(): return VF.buy_fleet_up(id), VF.money >= c and VF.crews > 0)
		m._add_to(g, _card(m.ph(d.icon), "%s  ·  Lv %d / %d" % [d.name, lv, d.max], "%s\n%s" % [d.desc, _up_now(id)], right, false, 44))


func _up_now(id: String) -> String:
	match id:
		"nets": return "Now: +%d%% fish per trip" % int(round((VF.crew_fish_mult() - 1.0) * 100.0))
		"speed": return "Now: a trip every %ss" % _num(VF.crew_trip_secs())
		"cooler": return "Now: up to %s while you're away" % dur(VF.offline_cap_secs())
		"sealegs": return "Now: %d%% while you're away" % int(round(VF.offline_rate() * 100.0))
	return ""


static func _num(x: float) -> String:
	return str(int(round(x))) if absf(x - round(x)) < 0.05 else "%.1f" % x


## Menu -> Daily
func panel_daily(tab: String) -> void:
	if VF.level < VFData.DAILY_LEVEL:
		_note("Daily rewards unlock at level %d." % VFData.DAILY_LEVEL, C_TEXT, 15)
		return
	if tab == "Spin":
		_daily_spin()
	else:
		_daily_calendar()


func _item_tex(d: Dictionary) -> Texture2D:
	if d.has("chest"): return m.icon_for("chest", String(d.chest))
	if d.has("money_levels"): return m.icon_for("ui", "money")
	if d.has("xp_frac"): return m.icon_for("ui", "xp")
	if d.has("pearls"): return m.v1.pearl_tex()
	if d.has("spin"): return m.v1.star_tex()
	if d.has("bait_best"): return m.icon_for("bait", VF.best_bait())
	if d.has("boost"): return m.icon_for("ui", "boosts")
	return m.ph(String(d.get("icon", "gift")))


func _daily_calendar() -> void:
	var done: int = VF.calendar_done()
	var ready: bool = VF.daily_ready_in() <= 0.0
	var next: int = VF.calendar_next()
	var row := GridContainer.new()
	row.columns = 7
	row.add_theme_constant_override("h_separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in 7:
		var state := "done" if i < done else ("today" if i == next - 1 and ready else "later")
		row.add_child(_day_tile(i + 1, VFData.CALENDAR[i], state))
	m.panel_body.add_child(row)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	if ready:
		var b: Button = m.btn("Claim day %d" % next, C_GOOD, 20, 280)
		b.custom_minimum_size.y = 52
		b.pressed.connect(_claim)
		h.add_child(b)
	else:
		h.add_child(m.lbl("Next reward in %s" % hms(VF.daily_ready_in()), 18, C_MUTED))
	m.panel_body.add_child(h)
	_note("Every day also pays money, XP and exotic fish, +2%% for every day of your streak (%d now). Claim within 48 hours, or the calendar starts over at day 1." % VF.daily_streak)


func _day_tile(n: int, d: Dictionary, state: String) -> Control:
	var p := PanelContainer.new()
	var today := state == "today"
	var bg: Color = Color("#fff4d6") if today else (Color("#e3f5ec") if state == "done" else C_PANEL2)
	var border := 3 if today or n == 7 else 0
	p.add_theme_stylebox_override("panel", m.sbox(bg, 14, border, Color("#f5b301") if today else Color("#e9c46a"), 8, 6 if today else 0))
	p.custom_minimum_size = Vector2(112, 150)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	var day: Label = m.lbl("Day %d" % n, 14, C_GOLD if today else C_MUTED)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(day)
	var t := _item_tex(d)
	var ic: TextureRect = m.icon(t, 54 if n < 7 else 60)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if t and String(t.resource_path).find("/phosphor/") >= 0: ic.modulate = C_TEAL
	v.add_child(ic)
	var nm: Label = m.lbl(d.name, 12, C_TEXT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	if state == "done":
		var tk: TextureRect = m._tick()
		tk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(tk)
		p.modulate = Color(1, 1, 1, 0.8)
	elif today:
		var c: Label = m.lbl("Today!", 13, C_GOOD)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(c)
	p.add_child(v)
	p.tooltip_text = "Day %d: %s" % [n, d.name]
	return p


func _claim() -> void:
	var r: Dictionary = VF.claim_daily()
	if r.has("error"):
		m._toast(r.error, "warn")
		return
	AudioManager.play_levelup()
	m.stage.burst("confetti", m.stage.boat.position + m.stage.boat.pivot_offset)
	var bits := [VF.got_text(r.bonus), "+" + m.money_str(int(r.money))]
	m._banner("Day %d claimed!" % int(r.day), "  ·  ".join(bits.filter(func(x): return x != "")) + "  ·  streak %d" % int(r.streak),
		_item_tex(VFData.CALENDAR[int(r.day) - 1]), Color("#f59e0b"))


func _daily_spin() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	_wheel = Control.new()
	_wheel.custom_minimum_size = Vector2(340, 340)
	_wheel.draw.connect(_draw_wheel.bind(_wheel))
	h.add_child(_wheel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(m.lbl("Daily Spin", 28))
	var spinning := _spin_t0 >= 0
	var state := "Free spin ready!" if VF.spin_free() else (
		"%d extra spin%s" % [VF.spins, "" if VF.spins == 1 else "s"] if VF.spins > 0 else "Next free spin in %s" % hms(_to_utc_midnight()))
	v.add_child(m.lbl(state, 16, C_GOOD if VF.spins_left() > 0 else C_MUTED))
	var sb: Button = m.btn("Spinning..." if spinning else "SPIN!", Color("#f5b301"), 22, 240)
	sb.custom_minimum_size.y = 56
	sb.disabled = spinning or VF.spins_left() <= 0
	sb.pressed.connect(_spin)
	v.add_child(sb)
	if Ads.available():
		var left: int = VF.ad_left("ad_spin")
		var ab: Button = m.btn("Watching..." if Ads.watching == "ad_spin" else ("+1 spin  ·  Watch an ad" if left > 0 else "No more ad spins today"), C_AD, 15, 240)
		ab.disabled = not Ads.can_watch("ad_spin") or spinning
		ab.pressed.connect(func(): Ads.watch("ad_spin"))
		v.add_child(ab)
	var odds := GridContainer.new()
	odds.columns = 2
	odds.add_theme_constant_override("h_separation", 14)
	odds.add_theme_constant_override("v_separation", 2)
	for d in VFData.SPIN:
		var c := HBoxContainer.new()
		c.add_theme_constant_override("separation", 6)
		var sw := ColorRect.new()
		sw.color = d.color
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c.add_child(sw)
		c.add_child(m.lbl("%s  %d%%" % [d.name, int(d.w)], 13, C_TEXT))
		odds.add_child(c)
	v.add_child(m.lbl("The odds", 13, C_MUTED))
	v.add_child(odds)
	h.add_child(v)
	m.panel_body.add_child(h)


func _to_utc_midnight() -> float:
	var now := Time.get_unix_time_from_system()
	return 86400.0 - fmod(now, 86400.0)


func _spin() -> void:
	if _spin_t0 >= 0: return
	var r: Dictionary = VF.spin()
	if r.has("error"):
		m._toast(r.error, "warn")
		return
	var seg := 360.0 / VFData.SPIN.size()
	var target := -(float(r.index) + 0.5) * seg + randf_range(-seg * 0.3, seg * 0.3)
	_spin_from = _spin_rot
	_spin_to = _spin_rot + 360.0 * 5.0 + fposmod(target - _spin_rot, 360.0)
	_spin_t0 = Time.get_ticks_msec()
	_spin_prize = r
	_rerender(["daily"])


func _spin_angle() -> float:
	if _spin_t0 < 0: return _spin_rot
	var u := clampf((Time.get_ticks_msec() - _spin_t0) / 1000.0 / SPIN_SECS, 0.0, 1.0)
	return lerpf(_spin_from, _spin_to, 1.0 - pow(1.0 - u, 3.0))


func _spin_done() -> void:
	_spin_rot = fposmod(_spin_to, 360.0)
	_spin_t0 = -1
	var d: Dictionary = VFData.SPIN[int(_spin_prize.index)]
	if d.name == "JACKPOT": AudioManager.play_bell()
	AudioManager.play_levelup()
	m._banner("%s!" % d.name, VF.got_text(_spin_prize.got), _item_tex(d), d.color)
	_rerender(["daily"])


## the wheel: VFData.SPIN in equal slices (the odds are listed next to it), turning under a fixed pointer
func _draw_wheel(w: Control) -> void:
	var c := w.size * 0.5
	var r := minf(c.x, c.y) - 14.0
	var n := VFData.SPIN.size()
	var seg := TAU / n
	var rot := deg_to_rad(_spin_angle())
	var font := w.get_theme_default_font()
	w.draw_circle(c + Vector2(0, 7), r + 10.0, Color(0, 0, 0, 0.16))
	w.draw_circle(c, r + 10.0, Color("#1f2d35"))
	for i in n:
		var a0 := -PI / 2.0 + rot + i * seg
		var pts := PackedVector2Array([c])
		for k in 17: pts.append(c + Vector2.from_angle(a0 + seg * k / 16.0) * r)
		w.draw_colored_polygon(pts, VFData.SPIN[i].color)
		w.draw_set_transform(c, a0 + seg * 0.5, Vector2.ONE)
		w.draw_string_outline(font, Vector2(r * 0.27, 6), VFData.SPIN[i].name, HORIZONTAL_ALIGNMENT_LEFT, r * 0.7, 15, 4, Color(0, 0, 0, 0.35))
		w.draw_string(font, Vector2(r * 0.27, 6), VFData.SPIN[i].name, HORIZONTAL_ALIGNMENT_LEFT, r * 0.7, 15, Color.WHITE)
		w.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in n:
		w.draw_line(c, c + Vector2.from_angle(-PI / 2.0 + rot + i * seg) * r, Color(1, 1, 1, 0.55), 2.0, true)
	for i in n * 2:
		w.draw_circle(c + Vector2.from_angle(-PI / 2.0 + rot + i * seg * 0.5) * (r + 5.0), 3.2, C_SUN)
	w.draw_circle(c, r * 0.18, Color.WHITE)
	w.draw_circle(c, r * 0.13, C_SUN)
	var top := c + Vector2(0, -r)
	w.draw_colored_polygon(PackedVector2Array([top + Vector2(0, 22), top + Vector2(-17, -16), top + Vector2(17, -16)]), Color("#ef4444"))
	w.draw_polyline(PackedVector2Array([top + Vector2(0, 22), top + Vector2(-17, -16), top + Vector2(17, -16), top + Vector2(0, 22)]), Color.WHITE, 2.0, true)


# ============================================================== capture test
## godot --path . -- --capture=DIR --idle-test : auto-fish, crews and their boats, the welcome-back card, the
## Fleet and Daily panels, a claim and a spin, as screenshots in DIR (never saves).
func capture_test(dir: String) -> void:
	VF._apply(VF._defaults.duplicate(true))
	m._veteran("River")                                   # then scaled back to a level-25 fisher on P0
	VF.tutorial = 99
	VF.prestige = 0
	VF.perks = {}
	VF.level = 25
	VF.owned_rods = ["Plastic Rod", "Improved Rod", "Steel Rod", "Fiberglass Rod"]
	VF.rod = "Fiberglass Rod"
	VF.boats_owned = 2
	VF.upgrades = {"better_fish": 2, "salesman": 2}
	VF.charms = {}
	VF.pets = {}
	VF.pet = ""
	VF.bait_stock = {"Worms": 140}
	VF.bait = "Worms"
	VF.exotics = {"gold": 24, "emerald": 9, "lava": 0, "diamond": 0, "azure": 0}
	VF.money = 60000
	VF.changed.emit()
	await m._wait(0.6)
	VF.set_auto(true)
	_style_auto()
	await m._wait(3.5)
	await m._shot(dir + "/idle_auto.png")
	m._open_panel("fleet", "Crews")
	await m._wait(0.4)
	await m._shot(dir + "/idle_fleet_empty.png")
	for i in 3: VF.hire_crew()
	await m._wait(0.4)
	await m._shot(dir + "/idle_fleet_crews.png")
	m._open_panel("fleet", "Upgrades")
	await m._wait(0.4)
	await m._shot(dir + "/idle_fleet_upgrades.png")
	m._close_panel()
	VF._crew_tick = 1.9
	VF._crew_accum = 3.0
	await m._wait(0.5)
	await m._shot(dir + "/idle_crews_water.png")
	VF.set_auto(false)
	_style_auto()
	VF.idle_seen = Time.get_unix_time_from_system() - 3.0 * 3600.0 - 1234.0      # back after 3h 20m
	VF.offline_check()
	await m._wait(0.8)
	await m._shot(dir + "/idle_welcome_back.png")
	var before: int = VF.inventory_value()
	_collect()
	await m._wait(0.8)
	await m._shot(dir + "/idle_collected.png")
	print("IDLE crews=%d fleet/min=%.0f hold %s -> %s" % [VF.crews, VF.fleet_fish_per_min(), VF.commas(before), VF.commas(VF.inventory_value())])
	VF.daily_last = Time.get_unix_time_from_system() - 26.0 * 3600.0
	VF.daily_streak = 3
	m._open_panel("daily", "Calendar")
	await m._wait(0.4)
	await m._shot(dir + "/idle_calendar.png")
	_claim()
	await m._wait(0.6)
	await m._shot(dir + "/idle_calendar_claimed.png")
	m._open_panel("daily", "Spin")
	await m._wait(0.4)
	await m._shot(dir + "/idle_spin.png")
	_spin()
	await m._wait(1.2)
	await m._shot(dir + "/idle_spin_turning.png")
	await m._wait(2.8)
	await m._shot(dir + "/idle_spin_prize.png")
	m._open_panel("menu")
	await m._wait(0.4)
	await m._shot(dir + "/idle_menu.png")
	m._close_panel()
	await m._wait(0.4)
	await m._shot(dir + "/idle_hud.png")
	print("IDLE day=%d streak=%d spins=%d pearls=%d" % [VF.calendar_done(), VF.daily_streak, VF.spins_left(), VF.pearls])

extends Control
## Main screen: Blender-rendered biome + boat, Virtual Fisher style catch
## card, and panels for every system (shop, biomes, charms, pets, boosts,
## quests, prestige, buffs). All art comes from assets/vf (see
## tools/blender/render_assets.py).

const ART := "res://assets/vf/"
const VERSION := "0.1 beta"
const FEEDBACK_URL := "https://github.com/iiafosh/vfish.fosh/issues/new"
const C_BG := Color("#e9dcc4")
const C_PANEL := Color("#fbf5e8")
const C_PANEL2 := Color("#f1e6d0")
const C_TEXT := Color("#3b2c20")
const C_MUTED := Color("#8c7660")
const C_GOOD := Color("#2f9e6a")
const C_GOLD := Color("#c9861a")
const C_BAD := Color("#d0473a")
const C_NEUTRAL := Color("#ecdfc5")
const C_SHADOW := Color(0.24, 0.16, 0.08, 0.22)

var manifest := {}
var _tex_cache := {}

# stage
var stage
var fx_layer: Control

# hud
var lvl_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var money_label: Label
var exotic_labels := {}
var hooks_label: Label
var prestige_label: Label
var wallet_btn: Button
var wallet: PanelContainer
var goal_box: PanelContainer
var goal_label: Label
var goal_bar: ProgressBar
var _goal := {}
var card: PanelContainer
var _card_tw: Tween

# catch card
var card_accent: ColorRect
var card_title: Label
var card_body: VBoxContainer
var toast_box: VBoxContainer

# dock
var fish_btn: Button
var fish_fill: ColorRect
var sell_btn: Button
var chips := {}
var boost_label: Label

# panel
var overlay: Control
var panel_title: Label
var panel_tabs: HBoxContainer
var panel_body: VBoxContainer
var _panel_kind := ""
var _panel_tab := ""

var _save_timer := 0.0

func _ready() -> void:
	_load_manifest()
	_build()
	VF.changed.connect(_refresh)
	VF.trip_done.connect(_on_trip)
	VF.leveled_up.connect(_on_level_up)
	VF.toast.connect(_toast)
	stage.merchant_clicked.connect(func(): _open_panel("shop", "Rods"))
	_refresh()
	_apply_biome()
	_card_intro()
	_build_version_label()
	if VF.stats.trips == 0 and VF.level == 1 and VF.prestige == 0 and not _capturing():
		_open_panel("guide", "Basics")
	_check_capture()

func _process(delta: float) -> void:
	_save_timer += delta
	if _save_timer > 20.0:
		_save_timer = 0.0
		VF.save_game()
	var cd: float = VF.cooldown()
	var left: float = VF.cooldown_left()
	fish_fill.anchor_right = 1.0 - (left / cd if cd > 0.0 else 0.0)
	fish_btn.text = "FISH" if left <= 0.0 else "%.1fs" % left
	if Engine.get_process_frames() % 30 == 0:
		_refresh_boosts()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		VF.save_game()

func _unhandled_input(event: InputEvent) -> void:
	# tap / click anywhere on the scene to cast (mobile friendly)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not overlay.visible:
		_do_cast()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_F:
				if overlay.visible: return
				_do_cast()
			KEY_S:
				if not overlay.visible: _do_sell()
			KEY_ESCAPE:
				_close_panel()
			KEY_G:
				if overlay.visible and _panel_kind == "guide": _close_panel()
				else: _open_panel("guide")
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var kinds := ["inventory", "shop", "biomes", "charms", "pets", "boosts", "quests", "prestige", "stats"]
				var k: String = kinds[event.keycode - KEY_1]
				if overlay.visible and _panel_kind == k: _close_panel()
				else: _open_panel(k)

# ================================================================ helpers
func _load_manifest() -> void:
	var f := FileAccess.open(ART + "manifest.json", FileAccess.READ)
	if f:
		manifest = JSON.parse_string(f.get_as_text())

func tex(path: String) -> Texture2D:
	if _tex_cache.has(path): return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(ART + path):
		t = load(ART + path)
	elif FileAccess.file_exists(ART + path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(ART + path))
		if img: t = ImageTexture.create_from_image(img)
	_tex_cache[path] = t
	return t

func icon_for(kind: String, name: String) -> Texture2D:
	match kind:
		"fish": return tex("fish/%s.png" % VFData.slug(name))
		"rod": return tex("rods/%s.png" % VFData.slug(name))
		"boat": return tex("boats/%s.png" % VFData.slug(name))
		"bait": return tex("baits/%s.png" % VFData.slug(name))
		"exotic": return tex("exotics/%s.png" % name)
		"pet": return tex("pets/%s.png" % VFData.slug(name))
		"charm": return tex("charms/%s.png" % name)
		"chest": return tex("chests/%s.png" % name)
		"ui": return tex("ui/%s.png" % name)
		"biome": return tex("scenes/%s.png" % VFData.slug(name))
	return null

func sbox(bg: Color, radius := 12, border := 0, border_col := Color.TRANSPARENT, pad := 10, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = C_SHADOW
		s.shadow_offset = Vector2(0, shadow * 0.5)
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_col
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s

const UI := "res://assets/third_party/kenney_ui/"

func tbox(name: String, margin := 20.0, pad := 14.0) -> StyleBoxTexture:
	var t := StyleBoxTexture.new()
	t.texture = load(UI + name + ".png")
	t.set_texture_margin_all(margin)
	t.set_content_margin_all(pad)
	return t

func lbl(text: String, size := 15, color := C_TEXT, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	return l

func icon(t: Texture2D, size := 40) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func btn(text: String, color := Color("#2f8f9e"), size := 15, min_w := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	var fc := C_TEXT if color.get_luminance() > 0.55 else Color.WHITE
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_disabled_color", Color(C_TEXT, 0.4))
	if color == C_NEUTRAL:
		b.add_theme_stylebox_override("normal", sbox(Color("#f6ecda"), 12, 1, Color("#dccaa8"), 6))
		b.add_theme_stylebox_override("hover", sbox(Color("#fff6e6"), 12, 2, Color("#c9a86a"), 6))
		b.add_theme_stylebox_override("pressed", sbox(Color("#ead9b8"), 12, 1, Color("#c9a86a"), 6))
	else:
		b.add_theme_stylebox_override("normal", sbox(color, 10, 2, color.darkened(0.3), 8, 2))
		b.add_theme_stylebox_override("hover", sbox(color.lightened(0.15), 10, 2, color.darkened(0.3), 8))
		b.add_theme_stylebox_override("pressed", sbox(color.darkened(0.2), 10, 2, color.darkened(0.3), 8))
	b.add_theme_stylebox_override("disabled", sbox(Color("#ddd0b6"), 10, 0, Color.TRANSPARENT, 8))
	if min_w > 0: b.custom_minimum_size.x = min_w
	b.pressed.connect(func(): AudioManager.play_click())
	return b

func accent() -> Color:
	return VFData.BIOMES[VF.biome].accent

func money_str(n: float) -> String:
	return "$" + VF.fmt(n)

# ================================================================== build
func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	var font: Font = load("res://assets/third_party/fonts/Fredoka.ttf")
	var fv := FontVariation.new()
	fv.base_font = font
	fv.variation_opentype = {"wght": 560}
	th.default_font = fv
	th.set_color("font_color", "Label", C_TEXT)
	theme = th
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_stage()
	_build_hud()
	_build_card()
	_build_dock()
	_build_overlay()

func _build_stage() -> void:
	stage = load("res://scripts/vf/vf_stage.gd").new()
	add_child(stage)
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)

func _flat(pad := 10, radius := 16) -> StyleBoxFlat:
	return sbox(Color(C_PANEL, 0.94), radius, 1, Color("#e3d3b4"), pad, 8)

func _build_hud() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(14, 12)
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _flat(10))
	col.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", sbox(Color("#2f8f9e"), 12, 0, Color.TRANSPARENT, 7))
	lvl_label = lbl("Lv 1", 17, Color.WHITE)
	badge.add_child(lvl_label)
	badge.tooltip_text = "Your level. Fish to earn XP."
	row.add_child(badge)
	var xpbox := VBoxContainer.new()
	xpbox.add_theme_constant_override("separation", 2)
	xpbox.alignment = BoxContainer.ALIGNMENT_CENTER
	xp_label = lbl("0 / 100 XP", 11, C_MUTED)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(150, 9)
	xp_bar.add_theme_stylebox_override("background", sbox(C_NEUTRAL, 5, 0, Color.TRANSPARENT, 0))
	xp_bar.add_theme_stylebox_override("fill", sbox(C_GOOD, 5, 0, Color.TRANSPARENT, 0))
	xpbox.add_child(xp_label)
	xpbox.add_child(xp_bar)
	row.add_child(xpbox)
	var m := HBoxContainer.new()
	m.add_child(icon(icon_for("ui", "money"), 28))
	money_label = lbl("$0", 18)
	m.add_child(money_label)
	m.tooltip_text = "Money"
	row.add_child(m)
	wallet_btn = btn("", C_NEUTRAL, 14)
	wallet_btn.icon = icon_for("exotic", "gold")
	wallet_btn.add_theme_constant_override("icon_max_width", 24)
	wallet_btn.tooltip_text = "Wallet: exotic fish, hooks and azure fish"
	wallet_btn.pressed.connect(_toggle_wallet)
	row.add_child(wallet_btn)
	prestige_label = lbl("P0", 15, C_GOLD)
	prestige_label.tooltip_text = "Prestige"
	prestige_label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(prestige_label)
	# wallet popup (hidden until clicked)
	wallet = PanelContainer.new()
	wallet.add_theme_stylebox_override("panel", _flat(10, 12))
	wallet.visible = false
	var wg := GridContainer.new()
	wg.columns = 2
	wg.add_theme_constant_override("h_separation", 18)
	wallet.add_child(wg)
	for k in ["gold", "emerald", "lava", "diamond", "azure"]:
		var h := HBoxContainer.new()
		h.add_child(icon(icon_for("exotic", k), 26))
		var l := lbl("0", 15)
		h.add_child(l)
		h.tooltip_text = VFData.EXOTICS[k].name
		exotic_labels[k] = l
		wg.add_child(h)
	var hk := HBoxContainer.new()
	hk.add_child(icon(icon_for("ui", "hooks"), 26))
	hooks_label = lbl("0", 15)
	hk.add_child(hooks_label)
	hk.tooltip_text = "Hooks (league currency)"
	wg.add_child(hk)
	col.add_child(wallet)
	# next goal hint
	goal_box = PanelContainer.new()
	goal_box.add_theme_stylebox_override("panel", _flat(8, 12))
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 3)
	goal_label = lbl("", 13)
	goal_bar = ProgressBar.new()
	goal_bar.show_percentage = false
	goal_bar.custom_minimum_size = Vector2(220, 7)
	goal_bar.add_theme_stylebox_override("background", sbox(C_NEUTRAL, 4, 0, Color.TRANSPARENT, 0))
	goal_bar.add_theme_stylebox_override("fill", sbox(C_GOLD, 4, 0, Color.TRANSPARENT, 0))
	gv.add_child(goal_label)
	gv.add_child(goal_bar)
	goal_box.add_child(gv)
	goal_box.mouse_filter = Control.MOUSE_FILTER_STOP
	goal_box.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _open_goal())
	goal_box.tooltip_text = "Your next upgrade. Click to open it."
	col.add_child(goal_box)

func _toggle_wallet() -> void:
	wallet.visible = not wallet.visible

func _build_card() -> void:
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(0, 14))
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -330
	card.offset_right = -14
	card.offset_top = 12
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	card.add_child(h)
	card_accent = ColorRect.new()
	card_accent.custom_minimum_size = Vector2(5, 0)
	h.add_child(card_accent)
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 10)
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	mc.add_child(v)
	card_title = lbl("", 16)
	v.add_child(card_title)
	card_body = VBoxContainer.new()
	card_body.add_theme_constant_override("separation", 2)
	v.add_child(card_body)
	toast_box = VBoxContainer.new()
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.offset_left = -230
	toast_box.offset_right = 230
	toast_box.offset_top = 84
	toast_box.add_theme_constant_override("separation", 4)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)

func _show_card() -> void:
	card.modulate.a = 1.0
	card.visible = true
	if _card_tw: _card_tw.kill()
	_card_tw = card.create_tween()
	_card_tw.tween_interval(6.0)
	_card_tw.tween_property(card, "modulate:a", 0.0, 0.8)

var _bottom: HBoxContainer

func _group(anchor_x: float, grow: int) -> HBoxContainer:
	if _bottom == null:
		_bottom = HBoxContainer.new()
		_bottom.anchor_left = 0.0
		_bottom.anchor_right = 1.0
		_bottom.anchor_top = 1.0
		_bottom.anchor_bottom = 1.0
		_bottom.offset_left = 12
		_bottom.offset_right = -12
		_bottom.offset_bottom = -10
		_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
		_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bottom)
	if _bottom.get_child_count() > 0:
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bottom.add_child(sp)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat(7, 16))
	p.size_flags_vertical = Control.SIZE_SHRINK_END
	_bottom.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	return h

func _build_dock() -> void:
	# left: current setup (rod, bait, biome, pet)
	var left := _group(0.0, Control.GROW_DIRECTION_END)
	for key in ["rod", "bait", "biome", "pet"]:
		left.add_child(_chip(key))
	# centre: fish + sell
	var mid := _group(0.5, Control.GROW_DIRECTION_BOTH)
	var midv := VBoxContainer.new()
	midv.add_theme_constant_override("separation", 4)
	mid.add_child(midv)
	boost_label = lbl("", 12, C_MUTED)
	boost_label.clip_text = true
	boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	midv.add_child(boost_label)
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 6)
	midv.add_child(mh)
	fish_btn = btn("FISH", Color("#3fae6a"), 22, 140)
	fish_btn.custom_minimum_size.y = 54
	fish_btn.clip_contents = true
	fish_fill = ColorRect.new()
	fish_fill.color = Color(1, 1, 1, 0.22)
	fish_fill.anchor_bottom = 1.0
	fish_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fish_btn.add_child(fish_fill)
	fish_btn.pressed.connect(_do_cast)
	fish_btn.tooltip_text = "Cast your line  [Space / F]"
	mh.add_child(fish_btn)
	sell_btn = btn("SELL", Color("#e07a3a"), 15, 112)
	sell_btn.pressed.connect(_do_sell)
	sell_btn.tooltip_text = "Sell every fish in your hold  [S]"
	mh.add_child(sell_btn)
	# right: navigation
	var right := _group(1.0, Control.GROW_DIRECTION_BEGIN)
	var i := 1
	for nav in [["inventory", "Hold"], ["shop", "Shop"], ["biomes", "Map"], ["charms", "Charms"], ["pets", "Pets"],
			["boosts", "Boosts"], ["quests", "Quests"], ["prestige", "Prestige"], ["stats", "Buffs"], ["guide", "Guide"]]:
		var b := _nav_button(nav[0], nav[1])
		b.tooltip_text = ("%s  [%d]" % [nav[1], i]) if i <= 9 else "%s  [G]" % nav[1]
		right.add_child(b)
		i += 1

func _chip(key: String) -> Button:
	var b := btn("", C_NEUTRAL, 11)
	b.custom_minimum_size = Vector2(58, 56)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", 34)
	b.clip_text = true
	b.pressed.connect(_on_chip.bind(key))
	chips[key] = b
	return b

func _on_chip(key: String) -> void:
	match key:
		"rod": _open_panel("shop", "Rods")
		"bait": _open_panel("shop", "Bait")
		"biome": _open_panel("biomes")
		"pet": _open_panel("pets")

func _nav_button(kind: String, text: String) -> Button:
	var b := btn(text, C_NEUTRAL, 11, 0)
	match kind:
		"charms": b.icon = icon_for("charm", "quality")
		"pets": b.icon = icon_for("pet", "Puffer")
		"quests": b.icon = icon_for("ui", "daily")
		"guide": b.icon = icon_for("ui", "quests")
		_: b.icon = icon_for("ui", kind)
	b.add_theme_constant_override("icon_max_width", 30)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(52, 56)
	b.pressed.connect(func(): _open_panel(kind))
	return b

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.1, 0.05, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_panel())
	overlay.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", tbox("panel_brown_corners_a", 36, 26))
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -480
	p.offset_right = 480
	p.offset_top = -300
	p.offset_bottom = 290
	overlay.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	var ban := PanelContainer.new()
	ban.add_theme_stylebox_override("panel", tbox("banner_hanging", 40, 0))
	ban.custom_minimum_size = Vector2(320, 56)
	panel_title = lbl("", 24, Color.WHITE, 6)
	panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ban.add_child(panel_title)
	head.add_child(ban)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := btn("✕", Color("#e2d4b8"), 16, 40)
	close.pressed.connect(_close_panel)
	head.add_child(close)
	v.add_child(head)
	panel_tabs = HBoxContainer.new()
	panel_tabs.add_theme_constant_override("separation", 6)
	v.add_child(panel_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	panel_body = VBoxContainer.new()
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation", 8)
	scroll.add_child(panel_body)

# ================================================================== stage
func _apply_biome() -> void:
	stage.set_biome(VF.biome)
	stage.set_boat(VF.current_boat() if VF.current_boat() != "" else "Rowboat")
	card_accent.color = accent()

# ================================================================ actions
func _do_cast() -> void:
	var why: String = VF.can_cast()
	if why == "cooldown":
		return
	if why != "":
		_toast(why, "warn")
		return
	AudioManager.play_cast()
	VF._last_cast_ms = Time.get_ticks_msec()   # lock the cooldown during the throw
	stage.cast(func():
		AudioManager.play_splash()
		VF._last_cast_ms = -100000
		VF.cast())

func _do_sell() -> void:
	var earned: int = VF.sell_all()
	if earned > 0:
		AudioManager.play_success()
		_float_text("+%s" % money_str(earned), sell_btn.get_global_rect().get_center() + Vector2(0, -40), C_GOLD)

func _on_trip(res: Dictionary) -> void:
	_show_catch(res)
	var best := ""
	for f in res.fish:
		if best == "" or VFData.FISH[f].price > VFData.FISH[best].price: best = f
	if best != "": stage.show_bite(best)
	var i := 0
	var from: Vector2 = stage.bobber_screen()
	for f in res.fish:
		var ic := icon(icon_for("fish", f), 54)
		ic.position = from - Vector2(27, 27)
		fx_layer.add_child(ic)
		var target := Vector2(get_viewport_rect().size.x - 300, 140 + i * 30)
		var tw := ic.create_tween()
		ic.modulate.a = 0.0
		tw.tween_interval(0.35 + i * 0.06)
		tw.tween_property(ic, "modulate:a", 1.0, 0.05)
		tw.tween_property(ic, "position", ic.position + Vector2(randf_range(-20, 20), -70), 0.25).set_ease(Tween.EASE_OUT)
		tw.tween_property(ic, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(ic, "modulate:a", 0.0, 0.45)
		tw.tween_callback(ic.queue_free)
		i += 1
	if not res.chest.is_empty():
		AudioManager.play_strike()
		stage.burst("sparkle", stage._bobber)
	if res.pet != "":
		AudioManager.play_success()
		stage.burst("magic", stage._bobber)

func _on_level_up(new_level: int, reward: int) -> void:
	AudioManager.play_levelup()
	stage.burst("confetti", stage.boat.position + stage.boat.pivot_offset)
	var banner := lbl("LEVEL UP!  %d" % new_level, 40, C_GOLD, 8)
	banner.position = Vector2(get_viewport_rect().size.x * 0.36 - 160, get_viewport_rect().size.y * 0.22)
	fx_layer.add_child(banner)
	var sub := lbl("+%s" % money_str(reward), 22, C_GOOD, 6) if reward > 0 else null
	if sub:
		sub.position = banner.position + Vector2(60, 50)
		fx_layer.add_child(sub)
	for n in [banner, sub]:
		if n == null: continue
		var tw: Tween = n.create_tween()
		tw.tween_property(n, "position:y", n.position.y - 40, 1.6)
		tw.parallel().tween_property(n, "modulate:a", 0.0, 1.6).set_delay(0.6)
		tw.tween_callback(n.queue_free)

func _float_text(text: String, at: Vector2, color: Color) -> void:
	var l := lbl(text, 22, color, 6)
	l.position = at - Vector2(40, 0)
	fx_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", at.y - 50, 1.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)

func _toast(text: String, kind: String) -> void:
	var colors := {"warn": Color("#b45309"), "pet": Color("#be185d"), "unlock": Color("#7c3aed"), "quest": Color("#0f766e"),
		"prestige": Color("#1d4ed8"), "buy": Color("#15803d")}
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(colors.get(kind, Color("#334155")), 10, 0, Color.TRANSPARENT, 8))
	p.add_child(lbl(text, 15, Color.WHITE))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).free()
	var tw := p.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)

# ============================================================ catch card
func _clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

func _card_intro() -> void:
	_show_card()
	card_title.text = "Welcome, %s!" % VF.player_name
	_clear(card_body)
	for t in ["Tap the water, press FISH or Space to cast.", "Sell your catch, then visit the merchant on the island for rods, bait and boats.",
			"Reach level 250 with 440/440 charms and $5B to prestige."]:
		var l := lbl("• " + t, 14, C_MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 320
		card_body.add_child(l)

func _show_catch(res: Dictionary) -> void:
	_show_card()
	card_accent.color = accent()
	card_title.text = "🎣 You caught %d fish!" % res.count if res.count > 0 else "🎣 Nothing bit this time..."
	_clear(card_body)
	var names: Array = res.fish.keys()
	names.sort_custom(func(a, b): return VFData.FISH[a].price > VFData.FISH[b].price)
	for f in names:
		var row := HBoxContainer.new()
		row.add_child(icon(icon_for("fish", f), 34))
		row.add_child(lbl("%s × %s" % [f, VF.commas(res.fish[f])], 15))
		var val := lbl(money_str(res.fish[f] * VFData.FISH[f].price * VF.sell_mult()), 13, C_MUTED)
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val)
		card_body.add_child(row)
	card_body.add_child(lbl("+%s XP" % VF.commas(res.xp), 14, C_GOOD))
	if not res.chest.is_empty():
		var c: Dictionary = res.chest
		var row := HBoxContainer.new()
		row.add_child(icon(icon_for("chest", c.tier), 40))
		var txt := "%s chest!" % String(c.tier).capitalize()
		var bits := []
		for k in c.items:
			if k == "charms":
				for ch in c.items.charms:
					bits.append("%d %s" % [c.items.charms[ch], VFData.CHARMS[ch].name])
			elif k == "money": bits.append(money_str(c.items[k]))
			elif k == "xp": bits.append("%s XP" % VF.fmt(c.items[k]))
			else: bits.append("%d %s" % [c.items[k], VFData.EXOTICS[k].name])
		var l := lbl(txt + "  " + ", ".join(bits), 14, C_GOLD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 270
		row.add_child(l)
		card_body.add_child(row)
	if res.pet != "":
		var row := HBoxContainer.new()
		row.add_child(icon(icon_for("pet", res.pet), 40))
		row.add_child(lbl("You found a %s!" % res.pet, 15, Color("#c0367a")))
		card_body.add_child(row)
	if res.bait_used != "":
		card_body.add_child(lbl("%s left: %s" % [res.bait_used, VF.commas(int(VF.bait_stock.get(res.bait_used, 0)))], 12, C_MUTED))

# ================================================================ refresh
func _refresh() -> void:
	lvl_label.text = "Lv %s" % VF.commas(VF.level)
	var need: int = VF.xp_to_next()
	xp_bar.max_value = maxf(1.0, need)
	xp_bar.value = VF.xp
	xp_label.text = "%s / %s XP" % [VF.fmt(VF.xp), VF.fmt(need)]
	money_label.text = money_str(VF.money)
	for k in exotic_labels:
		exotic_labels[k].text = VF.fmt(VF.exotics.get(k, 0))
	hooks_label.text = str(VF.hooks)
	wallet_btn.text = VF.fmt(VF.exotics.gold + VF.exotics.emerald + VF.exotics.lava + VF.exotics.diamond)
	prestige_label.text = "P%d" % VF.prestige
	prestige_label.visible = VF.prestige > 0
	var inv: int = VF.inventory_value()
	sell_btn.text = ("SELL\n%s" % money_str(inv)) if inv > 0 else "SELL"
	sell_btn.disabled = inv <= 0
	var rod_chip: Button = chips.rod
	rod_chip.icon = icon_for("rod", VF.rod)
	rod_chip.text = "Rod" if VF.rod_usable() else "⚠ Rod"
	rod_chip.tooltip_text = "%s — %s\nClick to change rods" % [VF.rod, "ready" if VF.rod_usable() else "can't be used in %s!" % VF.biome]
	var bait_chip: Button = chips.bait
	bait_chip.icon = icon_for("bait", VF.bait) if VF.has_bait() else icon_for("bait", "Worms")
	bait_chip.modulate = Color.WHITE if VF.has_bait() else Color(1, 1, 1, 0.6)
	bait_chip.text = ("×%s" % VF.fmt(VF.bait_stock[VF.bait])) if VF.has_bait() else "No bait"
	bait_chip.tooltip_text = ("%s: %s left" % [VF.bait, VF.commas(int(VF.bait_stock[VF.bait]))] if VF.has_bait() else "No bait equipped") + "\nClick to buy or change bait"
	var biome_chip: Button = chips.biome
	biome_chip.icon = icon_for("ui", "biomes")
	biome_chip.text = VF.biome
	biome_chip.tooltip_text = "%s biome • %.2fs cooldown\nClick to travel" % [VF.biome, VF.cooldown()]
	var pet_chip: Button = chips.pet
	pet_chip.icon = icon_for("pet", VF.pet if VF.pet != "" else "Puffer")
	pet_chip.modulate = Color.WHITE if VF.pet != "" else Color(1, 1, 1, 0.5)
	pet_chip.text = ("Lv %d" % VF.pets[VF.pet].level) if VF.pet != "" else "None"
	pet_chip.tooltip_text = ("%s (level %d)" % [VF.pet, VF.pets[VF.pet].level]) if VF.pet != "" else "No pet yet — 1 in 10,000 casts"
	_refresh_goal()
	_apply_biome()
	stage.set_rod(VF.rod)
	_refresh_boosts()
	if overlay.visible:
		_render_panel()

## The cheapest useful purchase you can't afford yet (next rod or boat),
## mirroring the Prestige 0 Guide's buying order.
func _refresh_goal() -> void:
	var best := {}
	for r in VFData.ROD_ORDER:
		var d: Dictionary = VFData.RODS[r]
		if r in VF.owned_rods or r == "Supporter Rod" or VF.level < d.level: continue
		if d.cost > VF.money:
			best = {"name": r, "cost": d.cost, "panel": ["shop", "Rods"]}
			break
	var nb: String = VF.next_boat()
	if nb != "" and VF.level >= VFData.BOATS[nb].level and VFData.BOATS[nb].cost > VF.money:
		if best.is_empty() or VFData.BOATS[nb].cost < best.cost:
			best = {"name": nb, "cost": VFData.BOATS[nb].cost, "panel": ["shop", "Boats"]}
	if best.is_empty():
		goal_box.visible = false
		return
	goal_box.visible = true
	_goal = best
	var have: float = VF.money + VF.inventory_value()
	goal_label.text = "Next: %s   %s / %s" % [best.name, money_str(have), money_str(best.cost)]
	goal_bar.max_value = best.cost
	goal_bar.value = minf(have, best.cost)

func _open_goal() -> void:
	if not _goal.is_empty():
		_open_panel(_goal.panel[0], _goal.panel[1])

func _refresh_boosts() -> void:
	var names := []
	var tips := []
	for k in ["fish", "treasure", "worker"]:
		if VF.is_boost_active(k):
			names.append(k.capitalize())
			tips.append("%s boost: %s left" % [k.capitalize(), _clock(VF.boost_left(k))])
	if Time.get_unix_time_from_system() < VF.personal_until:
		names.append("Personal")
		tips.append("Personal booster: %s left" % _clock(VF.personal_until - Time.get_unix_time_from_system()))
	boost_label.text = ("⚡ " + " · ".join(names)) if names else "~%.1f fish per cast" % _avg_fish()
	boost_label.tooltip_text = "
".join(tips) if tips else "Average fish per cast with your current setup"
	boost_label.mouse_filter = Control.MOUSE_FILTER_STOP

func _clock(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]

func _avg_fish() -> float:
	var r: Dictionary = VFData.RODS[VF.rod]
	var v: float = (r.min + r.max) / 2.0 * VF.fish_catch_mult() + VF.boats_owned
	if VF.has_bait(): v += round(float(VFData.BAITS[VF.bait].get("fish", 0)) * VF.bait_eff())
	return v * VFData.BIOMES[VF.biome].catch_rate * float(r.get("biome_mult", {}).get(VF.biome, 1.0)) * VF.booster_buff()

# ================================================================= panels
const PANEL_TABS := {
	"shop": ["Rods", "Bait", "Boats", "Upgrades", "Special", "League"],
	"prestige": ["Prestige", "Shop", "Guide"],
	"quests": ["Quests", "Daily"],
	"guide": VFGuide.TAB_ORDER,
}

func _open_panel(kind: String, tab: String = "") -> void:
	_panel_kind = kind
	_panel_tab = tab if tab != "" else (PANEL_TABS[kind][0] if PANEL_TABS.has(kind) else "")
	overlay.visible = true
	_render_panel()

func _close_panel() -> void:
	overlay.visible = false
	_panel_kind = ""

func _render_panel() -> void:
	_clear(panel_tabs)
	_clear(panel_body)
	var titles := {"inventory": "Fish Inventory", "shop": "Shop", "biomes": "Biomes", "charms": "Charms", "pets": "Pets",
		"boosts": "Boosts", "quests": "Quests & Daily", "prestige": "Prestige", "stats": "Buffs & Odds", "guide": "Guide"}
	panel_title.text = titles.get(_panel_kind, "")
	if PANEL_TABS.has(_panel_kind):
		for t in PANEL_TABS[_panel_kind]:
			var b := btn(t, accent().darkened(0.2) if t == _panel_tab else C_NEUTRAL, 14, 96)
			b.pressed.connect(func(): _panel_tab = t; _render_panel())
			panel_tabs.add_child(b)
	panel_tabs.visible = PANEL_TABS.has(_panel_kind)
	match _panel_kind:
		"inventory": _panel_inventory()
		"shop": _panel_shop()
		"biomes": _panel_biomes()
		"charms": _panel_charms()
		"pets": _panel_pets()
		"boosts": _panel_boosts()
		"quests": _panel_quests()
		"prestige": _panel_prestige()
		"stats": _panel_stats()
		"guide": _panel_guide()

func _card(t: Texture2D, title: String, desc: String, right: Control = null, dim := false, icon_size := 64) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(C_PANEL2, 12, 0, Color.TRANSPARENT, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	if t: h.add_child(icon(t, icon_size))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(lbl(title, 17))
	if desc != "":
		var d := lbl(desc, 13, C_MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
	h.add_child(v)
	if right:
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(right)
	if dim: p.modulate = Color(1, 1, 1, 0.55)
	return p

func _act(text: String, color: Color, cb: Callable, enabled := true) -> Button:
	var b := btn(text, color, 14, 130)
	b.disabled = not enabled
	b.pressed.connect(func():
		var r = cb.call()
		if r is String and r != "": _toast(r, "warn"))
	return b

func _grid(cols := 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_child(g)
	return g

func _add_to(g: Node, c: Control) -> void:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(c)

func _panel_inventory() -> void:
	var total: int = VF.inventory_value()
	var head := HBoxContainer.new()
	var l := lbl("Hold value: %s   (sell multiplier ×%.2f)" % [money_str(total), VF.sell_mult()], 16)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	head.add_child(_act("Sell all", Color("#e07a3a"), func(): _do_sell(); return "", total > 0))
	panel_body.add_child(head)
	var g := _grid(3)
	for f in VFData.FISH_ORDER:
		var n := int(VF.inventory.get(f, 0))
		if n <= 0: continue
		_add_to(g, _card(icon_for("fish", f), "%s × %s" % [f, VF.commas(n)],
			"%s each • %s total" % [money_str(VFData.FISH[f].price * VF.sell_mult()), money_str(n * VFData.FISH[f].price * VF.sell_mult())], null, false, 56))
	if g.get_child_count() == 0:
		panel_body.add_child(lbl("Your hold is empty. Go fish!", 16, C_MUTED))

func _panel_shop() -> void:
	match _panel_tab:
		"Rods":
			var g := _grid(2)
			for r in VFData.ROD_ORDER:
				var d: Dictionary = VFData.RODS[r]
				var desc := "%d-%d fish • %s%% treasure%s\n%s" % [d.min, d.max, str(snappedf(d.tc * 100.0, 0.1)),
					(" • +%d%% TQ" % int(d.tq * 100)) if d.tq > 0 else "", ", ".join(d.biomes) if d.biomes.size() < 7 else "All biomes"]
				var right: Control
				if r in VF.owned_rods:
					right = _act("Equipped" if VF.rod == r else "Equip", C_GOOD if VF.rod == r else Color("#2f8f9e"),
						func(): VF.select_rod(r); return "", VF.rod != r)
				elif r == "Supporter Rod":
					right = lbl("Prestige 5", 14, C_MUTED)
				elif VF.level < d.level:
					right = lbl("Level %d" % d.level, 14, C_MUTED)
				else:
					right = _act("Buy %s" % money_str(d.cost), Color("#3fae6a"), func(): return VF.buy_rod(r), VF.money >= d.cost)
				_add_to(g, _card(icon_for("rod", r), r, desc, right, VF.level < d.level and not (r in VF.owned_rods)))
		"Bait":
			var g := _grid(2)
			for b in VFData.BAIT_ORDER:
				var d: Dictionary = VFData.BAITS[b]
				var box := VBoxContainer.new()
				var locked: bool = VF.level < d.level
				if locked:
					box.add_child(lbl("Level %d" % d.level, 14, C_MUTED))
				else:
					var hb := HBoxContainer.new()
					for amt in [10, 100]:
						var a := _act("+%d  %s" % [amt, money_str(d.cost * amt)], Color("#3fae6a"), func(): return VF.buy_bait(b, amt), VF.money >= d.cost * amt)
						a.custom_minimum_size.x = 0
						hb.add_child(a)
					box.add_child(hb)
					var eq := _act("Using" if VF.bait == b else "Use", C_GOOD if VF.bait == b else Color("#2f8f9e"),
						func(): VF.select_bait(b); return "", VF.bait != b and int(VF.bait_stock.get(b, 0)) > 0)
					box.add_child(eq)
				_add_to(g, _card(icon_for("bait", b), "%s  (×%s)" % [b, VF.fmt(VF.bait_stock.get(b, 0))], "%s\n%s" % [d.desc, _bait_fx(d)], box, locked))
		"Boats":
			panel_body.add_child(lbl("Every boat: -0.25s cooldown and +1 fish per cast. Bought in order. Owned: %d/17" % VF.boats_owned, 14, C_MUTED))
			var g := _grid(2)
			for i in VFData.BOAT_ORDER.size():
				var b: String = VFData.BOAT_ORDER[i]
				var d: Dictionary = VFData.BOATS[b]
				var right: Control
				if i < VF.boats_owned: right = lbl("✓ Owned", 15, C_GOOD)
				elif i == VF.boats_owned:
					right = lbl("Level %d" % d.level, 14, C_MUTED) if VF.level < d.level else \
						_act("Buy %s" % money_str(d.cost), Color("#3fae6a"), func(): return VF.buy_boat(), VF.money >= d.cost)
				else: right = lbl(money_str(d.cost), 14, C_MUTED)
				_add_to(g, _card(icon_for("boat", b), b, "Tier %d • Level %d" % [i + 1, d.level], right, i > VF.boats_owned, 80))
		"Upgrades":
			var g := _grid(2)
			for id in VFData.UPGRADE_ORDER:
				var d: Dictionary = VFData.UPGRADES[id]
				var c: int = VF.upgrade_cost(id)
				var right: Control = lbl("MAX", 15, C_GOLD) if c < 0 else _act(money_str(c), Color("#3fae6a"), func(): return VF.buy_upgrade(id), VF.money >= c)
				_add_to(g, _card(null, "%s  %d/%d" % [d.name, VF.up(id), d.max], d.desc, right))
		"Special":
			if VF.level < 50:
				panel_body.add_child(lbl("The Special Shop opens at level 50 (Volcanic biome).", 15, C_MUTED))
			var g := _grid(2)
			for id in VFData.SPECIAL_ORDER:
				var d: Dictionary = VFData.SPECIALS[id]
				var c: int = VF.special_cost(id)
				var right: Control
				if VF.level < d.level: right = lbl("Level %d" % d.level, 14, C_MUTED)
				elif c < 0: right = lbl("MAX", 15, C_GOLD)
				else:
					right = _act("%d %s" % [c, VFData.EXOTICS[d.cur].name.split(" ")[0]], Color("#3fae6a"), func(): return VF.buy_special(id), VF.exotics[d.cur] >= c)
				_add_to(g, _card(icon_for("exotic", d.cur), "%s  %d/%d" % [d.name, VF.sp(id), d.max], d.desc, right, VF.level < d.level, 48))
		"League":
			panel_body.add_child(lbl("Hooks come from the daily league quest (+10) and weekly trip milestones (+10 per 500 trips, max 100/week). League upgrades never reset.", 13, C_MUTED))
			var g := _grid(2)
			for id in VFData.LEAGUE_ORDER:
				var d: Dictionary = VFData.LEAGUE[id]
				var c: int = VF.league_cost(id)
				var right: Control = lbl("MAX", 15, C_GOLD) if c < 0 else _act("%d Hooks" % c, Color("#3fae6a"), func(): return VF.buy_league(id), VF.hooks >= c)
				_add_to(g, _card(icon_for("ui", "hooks"), "%s  %d/%d" % [d.name, VF.lg(id), d.costs.size()], d.desc, right, false, 44))

func _bait_fx(d: Dictionary) -> String:
	var bits := []
	var names := {"fish": "Fish", "catch": "Fish Catch", "quality": "Quality", "tc": "Treasure", "tq": "Treasure Quality",
		"xp": "XP", "pet_chance": "Pet chance", "pet_eff": "Pet effect", "pet_xp": "Pet XP"}
	for k in names:
		if d.has(k):
			if k == "fish": bits.append("+%d fish" % d[k])
			else: bits.append("%+d%% %s" % [int(round(d[k] * 100)), names[k]])
	return " • ".join(bits)

func _panel_biomes() -> void:
	var g := _grid(1)
	for b in VFData.BIOME_ORDER:
		var d: Dictionary = VFData.BIOMES[b]
		var locked: bool = VF.level < d.level
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", sbox(C_PANEL2, 12, 3 if VF.biome == b else 0, d.accent, 8))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		p.add_child(h)
		var thumb := icon(icon_for("biome", b), 0)
		thumb.custom_minimum_size = Vector2(200, 112)
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		h.add_child(thumb)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(lbl("%s  •  Level %d" % [b, d.level], 18, d.accent.darkened(0.3)))
		v.add_child(lbl("+%.1fs cooldown • %s%% fish catch rate" % [d.cd_add, str(d.catch_rate * 100.0)], 13, C_MUTED))
		var fr := HBoxContainer.new()
		for f in d.fish:
			var fi := icon(icon_for("fish", f), 36)
			fi.tooltip_text = f
			fi.mouse_filter = Control.MOUSE_FILTER_STOP
			fr.add_child(fi)
		v.add_child(fr)
		h.add_child(v)
		var right: Control
		if VF.biome == b: right = lbl("You are here", 14, C_GOOD)
		elif locked: right = lbl("Level %d" % d.level, 14, C_MUTED)
		else: right = _act("Travel", Color("#2f8f9e"), func(): return VF.select_biome(b))
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(right)
		if locked: p.modulate = Color(1, 1, 1, 0.5)
		_add_to(g, p)

func _panel_charms() -> void:
	var cap: int = VFData.charm_tier_cap(VF.prestige)
	panel_body.add_child(lbl("Charms come from Rare+ chests (level 20+). Tier n costs n charms. Total %d / %d (prestige needs all of them)." %
		[VF.charms_total(), VFData.charm_total_cap(VF.prestige)], 14, C_MUTED))
	var g := _grid(2)
	for id in VFData.CHARM_ORDER:
		var n := int(VF.charms.get(id, 0))
		var t: int = VF.charm_tier(id)
		var into := n - t * (t + 1) / 2
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(120, 10)
		bar.max_value = t + 1 if t < cap else 1
		bar.value = into if t < cap else 1
		bar.add_theme_stylebox_override("background", sbox(Color("#e4d6bb"), 5, 0, Color.TRANSPARENT, 0))
		bar.add_theme_stylebox_override("fill", sbox(C_GOLD, 5, 0, Color.TRANSPARENT, 0))
		var box := VBoxContainer.new()
		box.add_child(lbl("Tier %d / %d" % [t, cap], 14, C_GOLD))
		box.add_child(bar)
		_add_to(g, _card(icon_for("charm", id), VFData.CHARMS[id].name, VFData.CHARMS[id].desc + " per tier", box))

func _panel_pets() -> void:
	panel_body.add_child(lbl("Pets can't be bought: each cast has a 1 in 10,000 chance (more with Support Bait and prestige). Max level %d." % VF.pet_level_cap(), 14, C_MUTED))
	var g := _grid(1)
	for p in VFData.PET_ORDER:
		if not VF.pets.has(p):
			var c := _card(icon_for("pet", p), "???", "Not found yet", null, true)
			(c.get_child(0).get_child(0) as TextureRect).modulate = Color(0, 0, 0, 0.8)
			_add_to(g, c)
			continue
		var d: Dictionary = VF.pets[p]
		var buffs := []
		for k in VFData.PETS[p].buffs:
			buffs.append("+%.1f%% %s" % [VF.pet_stat(k, p) * 100.0, {"catch": "Fish Catch", "quality": "Fish Quality", "xp": "XP", "tc": "Treasure Chance", "tq": "Treasure Quality"}[k]])
		var right := _act("Equipped" if VF.pet == p else "Equip", C_GOOD if VF.pet == p else Color("#2f8f9e"), func(): VF.select_pet(p); return "", VF.pet != p)
		_add_to(g, _card(icon_for("pet", p), "%s  •  Lv %d   (%s / %s XP)" % [p, d.level, VF.fmt(d.xp), VF.fmt(VF._pet_xp_needed(d.level))],
			VFData.PETS[p].desc + "\n" + "  ".join(buffs), right))

func _panel_boosts() -> void:
	if VF.level < 10:
		panel_body.add_child(lbl("Boosts unlock at level 10. Gold & Emerald Fish come from chests.", 15, C_MUTED))
	var info := {"fish": "×%.2f catch + bonus fish" % (1.05 + 0.01 * VF.lg("fishing_frenzy") + 0.01 * VF.sp("boost_booster")),
		"treasure": "×%.2f treasure chance" % (1.5 + 0.05 * VF.sp("boost_booster") + 0.05 * VF.lg("fishing_frenzy")),
		"worker": "fishes every %.1fs for you" % VF.worker_cooldown()}
	var g := _grid(2)
	for id in VFData.BOOST_ORDER:
		var d: Dictionary = VFData.BOOSTS[id]
		var right := _act("%d %s" % [d.cost, VFData.EXOTICS[d.cur].name.split(" ")[0]], Color("#3fae6a"), func(): return VF.buy_boost(id),
			VF.level >= 10 and VF.exotics[d.cur] >= d.cost)
		var active := "  (active %s)" % _clock(VF.boost_left(d.kind)) if VF.is_boost_active(d.kind) else ""
		_add_to(g, _card(icon_for("exotic", d.cur), "%s %dm%s" % [d.name, d.secs / 60, active], info[d.kind], right, false, 48))
	var pb := _act("Use (%d)" % VF.personal_boosters, Color("#7c3aed"), func(): return VF.use_personal_booster(), VF.personal_boosters > 0)
	panel_body.add_child(_card(icon_for("ui", "boosts"), "Personal Booster", "+75% fish for 10 minutes. 10% chance from /daily.", pb, false, 48))

func _panel_quests() -> void:
	if _panel_tab == "Daily":
		var ready: float = VF.daily_ready_in()
		var right := _act("Claim" if ready <= 0 else _clock(ready / 60.0) + "h", Color("#3fae6a"), func():
			var r: Dictionary = VF.claim_daily()
			if r.has("error"): return r.error
			_toast("Daily claimed! Streak %d" % r.streak, "quest")
			return "", VF.level >= 10 and ready <= 0)
		panel_body.add_child(_card(icon_for("ui", "daily"), "Daily Reward  •  streak %d" % VF.daily_streak,
			"Unlocks at level 10. Money, XP, exotic fish and a chance of a Personal Booster. Claim within 48h to keep your streak.", right))
		return
	for q in VFData.QUESTS:
		var claimed := int(VF.quest_claimed.get(q.id, 0))
		var prog := int(VF.quest_progress.get(q.stat, 0))
		var goal: int = q.goals[mini(claimed, q.goals.size() - 1)]
		var done: bool = claimed >= q.goals.size()
		panel_body.add_child(_card(icon_for("ui", "quests"), "%s  (%d/%d)" % [q.name, claimed, q.goals.size()],
			"Done for today!" if done else "%s / %s" % [VF.commas(prog), VF.commas(goal)], lbl("✓" if done else "", 20, C_GOOD), done, 48))
	var sq: Dictionary = VF.special_quest()
	var sp := int(VF.quest_progress.get(sq.stat, 0))
	panel_body.add_child(_card(icon_for("ui", "hooks"), "League quest: %s" % sq.name, "%s / %s  →  +10 Hooks" % [VF.commas(mini(sp, sq.goal)), VF.commas(sq.goal)],
		lbl("✓" if VF.quest_claimed.get("special", false) else "", 20, C_GOOD), false, 48))
	panel_body.add_child(_card(icon_for("ui", "hooks"), "Weekly trips: %s" % VF.commas(VF.week_trips), "+10 Hooks every 500 trips (max 100/week). Earned this week: %d" % VF.week_hooks, null, false, 48))

func _req_row(name: String, have: float, need: float, money := false) -> Control:
	var ok := have >= need
	var h := HBoxContainer.new()
	var l := lbl(("✓ " if ok else "✗ ") + name, 16, C_GOOD if ok else C_BAD)
	l.custom_minimum_size.x = 160
	h.add_child(l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 14
	bar.max_value = 1.0
	bar.value = clampf(have / need, 0.0, 1.0) if need > 0 else 1.0
	bar.add_theme_stylebox_override("background", sbox(Color("#e4d6bb"), 6, 0, Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", sbox(C_GOOD if ok else Color("#2f8f9e"), 6, 0, Color.TRANSPARENT, 0))
	h.add_child(bar)
	var f := money_str(have) + " / " + money_str(need) if money else VF.commas(int(have)) + " / " + VF.commas(int(need))
	var r := lbl(f, 14, C_MUTED)
	r.custom_minimum_size.x = 200
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(r)
	return h

func _panel_prestige() -> void:
	match _panel_tab:
		"Prestige":
			var c: Dictionary = VF.prestige_check()
			panel_body.add_child(lbl("Prestige %d → %d" % [VF.prestige, VF.prestige + 1], 20, C_GOLD))
			panel_body.add_child(_req_row("Level", c.level[0], c.level[1]))
			panel_body.add_child(_req_row("Money", c.money[0], c.money[1], true))
			panel_body.add_child(_req_row("Charms", c.charms[0], c.charms[1]))
			var note := lbl("Prestiging resets level, money, fish, rods, boats, bait, shop & special upgrades, exotic fish and charms. You keep pets, hooks, league upgrades and prestige perks, and gain 1 Azure Fish. P0 requirements are from the Prestige 0 Guide; later requirements are estimated.", 13, C_MUTED)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			panel_body.add_child(note)
			var b := _act("PRESTIGE", Color("#1d4ed8"), func(): return VF.do_prestige(), c.ok)
			b.custom_minimum_size = Vector2(220, 52)
			panel_body.add_child(b)
		"Shop":
			var tip: Dictionary = VFData.prestige_guide(VF.prestige)
			panel_body.add_child(lbl("Azure Fish: %d   •   perk cap %d (1 + P/5)   •   Guide pick for P%d: %s%s" % [VF.exotics.azure, VF.perk_cap(), VF.prestige, tip.main,
				("  (Max: %s)" % tip.max) if tip.max != "" else ""], 15, C_GOLD))
			var g := _grid(1)
			for id in VFData.PERK_ORDER:
				var d: Dictionary = VFData.PRESTIGE_PERKS[id]
				var locked: bool = VF.prestige < d.unlock
				var right: Control = lbl("Prestige %d" % d.unlock, 14, C_MUTED) if locked else \
					_act("1 Azure", Color("#1d4ed8"), func(): return VF.buy_perk(id), VF.exotics.azure >= 1 and VF.pk(id) < VF.perk_cap())
				_add_to(g, _card(icon_for("exotic", "azure"), "%s [%s]  %d/%d" % [d.name, d.short, VF.pk(id), VF.perk_cap()], d.desc, right, locked, 48))
		"Guide":
			var intro := lbl("Community Prestige Shop buy order (IT International Ties, FW Fish Whisperer, AO Ancient One, BE Business Education, VF Virtual Fisher). \"Max\" only if you want to reach P160 level 25k.", 13, C_MUTED)
			intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			panel_body.add_child(intro)
			var g := _grid(4)
			var rows := []
			for p in range(1, 17): rows.append([str(p), p])
			rows += [["17-85 (x1/x6)", 21], ["17-85 (x0/x5)", 20], ["86-100 (x1,2,6,7)", 91], ["86-100 (x0/x5)", 90], ["101", 101],
				["102-140 (x1/x6)", 106], ["102-140 (x0/x5)", 110], ["141", 141], ["142", 142], ["145", 145],
				["146-155 (x1,2,6,7)", 146], ["146-155 (x0/x5)", 150], ["156", 156], ["157", 157], ["160", 160]]
			for r in rows:
				var gd: Dictionary = VFData.prestige_guide(r[1])
				var hl: bool = r[1] == VF.prestige
				var p := PanelContainer.new()
				p.add_theme_stylebox_override("panel", sbox(Color("#1d4ed8") if hl else C_PANEL2, 8, 0, Color.TRANSPARENT, 6))
				p.add_child(lbl("P%s: %s%s" % [r[0], gd.main, (" / Max: " + gd.max) if gd.max != "" else ""], 13))
				_add_to(g, p)
			panel_body.add_child(lbl("Other prestiges in each range ending in 2,3,4,7,8,9 (or 3,4,8,9): SKIP and save Azure Fish.", 13, C_MUTED))

func _panel_stats() -> void:
	var rows := [
		["Fish Catch", "×%.2f" % VF.fish_catch_mult()], ["Fish Quality", "×%.2f" % VF.fish_quality_mult()],
		["Sell Price", "×%.2f" % VF.sell_mult()], ["XP", "×%.2f" % VF.xp_mult()],
		["Treasure Chance", "%.2f%%" % (VF.treasure_chance() * 100.0)], ["Treasure Quality", "×%.2f" % VF.treasure_quality()],
		["Cooldown", "%.2fs" % VF.cooldown()], ["Avg fish / cast", "%.1f" % _avg_fish()],
		["Bait effectiveness", "×%.2f" % VF.bait_eff()], ["Duplicate chance", "%.0f%%" % (VF.duplicate_chance() * 100.0)],
		["Trips", VF.commas(VF.stats.trips)], ["Fish caught", VF.commas(VF.stats.fish)], ["Chests", VF.commas(VF.stats.chests)],
		["Money earned", money_str(VF.stats.money_earned)]]
	var g := _grid(4)
	for r in rows:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", sbox(C_PANEL2, 10, 0, Color.TRANSPARENT, 8))
		var v := VBoxContainer.new()
		v.add_child(lbl(r[0], 12, C_MUTED))
		v.add_child(lbl(r[1], 18))
		p.add_child(v)
		_add_to(g, p)
	panel_body.add_child(lbl("Catch odds: %s in %s" % [VF.rod, VF.biome], 17))
	if not VF.rod_usable():
		panel_body.add_child(lbl("This rod can't be used here.", 14, C_BAD))
		return
	var odds: Array = VF.species_odds()
	var fish: Array = VFData.BIOMES[VF.biome].fish
	var og := _grid(5)
	for i in 5:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", sbox(C_PANEL2, 10, 0, Color.TRANSPARENT, 6))
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(icon(icon_for("fish", fish[i]), 56))
		var n := lbl(fish[i], 13)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		var pc := lbl("%.2f%%" % (odds[i] * 100.0), 16, C_GOLD)
		pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(pc)
		p.add_child(v)
		_add_to(og, p)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var reset := btn("Reset save…", C_NEUTRAL, 12, 120)
	reset.tooltip_text = "Erase all progress (asks to confirm)"
	reset.pressed.connect(func():
		if reset.text == "Click again to erase everything":
			VF.reset_save()
			get_tree().reload_current_scene()
		else:
			reset.text = "Click again to erase everything"
			reset.add_theme_color_override("font_color", C_BAD)
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(reset): reset.text = "Reset save…"))
	row.add_child(reset)
	panel_body.add_child(row)

# ============================================================ capture mode
## godot --path . -- --capture=DIR [--demo=BIOME] : plays a few casts, saves
## screenshots of the main screen and key panels, then quits. Never saves.
func _check_capture() -> void:
	var dir := ""
	var demo := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="): dir = a.substr(10)
		if a.begins_with("--demo="): demo = a.substr(7)
	if dir == "": return
	VF.autosave = false
	if demo != "":
		var lv: int = VFData.BIOMES[demo].level
		VF.level = maxi(lv, 120)
		VF.money = 3_400_000_000
		VF.biome = demo
		VF.boats_owned = 0
		for b in VFData.BOAT_ORDER:
			if VFData.BOATS[b].level <= VF.level: VF.boats_owned += 1
		for r in VFData.ROD_ORDER:
			if VFData.RODS[r].level <= VF.level and r != "Supporter Rod": VF.owned_rods.append(r)
		for r in VFData.ROD_ORDER:
			if r in VF.owned_rods and VF.rod_usable(r, demo): VF.rod = r
		VF.bait_stock = {"Magic Bait": 850, "Wise Bait": 120, "Leeches": 40}
		VF.bait = "Magic Bait"
		VF.exotics = {"gold": 412, "emerald": 268, "lava": 91, "diamond": 37, "azure": 1}
		VF.prestige = 1
		VF.perks = {"international_ties": 1}
		VF.pets = {"Puffer": {"level": 34, "xp": 1200}, "Axolotl": {"level": 12, "xp": 300}}
		VF.pet = "Puffer"
		VF.upgrades = {"better_fish": 14, "salesman": 14, "more_chests": 7, "artifact_specialist": 7, "experienced": 2}
		for id in VFData.CHARM_ORDER: VF.charms[id] = 20
		VF.changed.emit()
	await get_tree().create_timer(0.6).timeout
	for i in 3:
		VF._last_cast_ms = -100000
		_do_cast()
		await get_tree().create_timer(0.9).timeout
	await get_tree().create_timer(0.3).timeout
	await _shot(dir + "/main.png")
	var shots := [["shop", "Rods"], ["biomes", ""], ["prestige", "Guide"], ["stats", ""], ["charms", ""], ["guide", "Basics"], ["guide", "Feedback"]]
	if "--all-panels" in OS.get_cmdline_user_args():
		shots = []
		for k in ["inventory", "shop", "biomes", "charms", "pets", "boosts", "quests", "prestige", "stats", "guide"]:
			for t in PANEL_TABS.get(k, [""]):
				shots.append([k, t])
	for p in shots:
		_open_panel(p[0], p[1])
		await get_tree().create_timer(0.4).timeout
		await _shot(dir + "/panel_%s%s.png" % [p[0], ("_" + p[1].to_lower().replace(" / ", "_")) if p[1] != "" else ""])
	get_tree().quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


# ================================================================== guide
func _capturing() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="): return true
	return false

func _build_version_label() -> void:
	var v := lbl("Virtual Fisher %s" % VERSION, 11, Color(1, 1, 1, 0.75), 4)
	v.anchor_left = 1.0
	v.anchor_right = 1.0
	v.anchor_top = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = -200
	v.offset_right = -16
	v.offset_top = -102
	v.offset_bottom = -86
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	move_child(v, overlay.get_index())

func _panel_guide() -> void:
	if _panel_tab == "Feedback":
		_panel_feedback()
		return
	for entry in VFGuide.TABS.get(_panel_tab, []):
		var ic: Array = entry[1]
		var c := _card(icon_for(ic[0], ic[1]), entry[0], entry[2], null, false, 52)
		_add_to(panel_body, c)
	if _panel_tab == "Basics":
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		var go := btn("Start fishing!", Color("#3fae6a"), 16, 180)
		go.pressed.connect(_close_panel)
		row.add_child(go)
		panel_body.add_child(row)

var _fb_kind := "Idea"
var _fb_text: TextEdit

func _panel_feedback() -> void:
	var intro := lbl("Thanks for playing the %s! Tell us what you liked, what broke, or what you want next. Your message opens as a GitHub issue (free account needed) with your game version and platform filled in — no personal data." % VERSION, 14, C_MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_body.add_child(intro)
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 6)
	for k in ["Bug", "Idea", "Balance", "Art / UI", "Other"]:
		var b := btn(k, accent().darkened(0.2) if k == _fb_kind else C_NEUTRAL, 14, 90)
		b.pressed.connect(func():
			_fb_kind = k
			var keep := _fb_text.text if _fb_text else ""
			_render_panel()
			_fb_text.text = keep)
		kinds.add_child(b)
	panel_body.add_child(kinds)
	_fb_text = TextEdit.new()
	_fb_text.placeholder_text = "What happened / what would you like? (For bugs: what did you do, what did you expect?)"
	_fb_text.custom_minimum_size = Vector2(0, 180)
	_fb_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_fb_text.add_theme_stylebox_override("normal", sbox(Color("#fffaf0"), 10, 1, Color("#dccaa8"), 10))
	_fb_text.add_theme_stylebox_override("focus", sbox(Color("#fffaf0"), 10, 2, Color("#c9a86a"), 10))
	_fb_text.add_theme_color_override("font_color", C_TEXT)
	_fb_text.add_theme_color_override("font_placeholder_color", C_MUTED)
	panel_body.add_child(_fb_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	var copy := btn("Copy report", C_NEUTRAL, 14, 140)
	copy.tooltip_text = "Copy the report to paste it anywhere (Discord, itch.io comments…)"
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(_feedback_body())
		_toast("Report copied to clipboard", "quest"))
	row.add_child(copy)
	var send := btn("Send feedback", Color("#3fae6a"), 15, 170)
	send.pressed.connect(_send_feedback)
	row.add_child(send)
	panel_body.add_child(row)

func _feedback_body() -> String:
	var lines := [
		(_fb_text.text.strip_edges() if _fb_text else ""),
		"",
		"---",
		"Version: %s" % VERSION,
		"Platform: %s" % OS.get_name(),
		"Progress: level %d, prestige %d, biome %s, rod %s, boats %d, trips %d" % [VF.level, VF.prestige, VF.biome, VF.rod, VF.boats_owned, VF.stats.trips],
	]
	return "\n".join(lines)

func _send_feedback() -> void:
	var text := _fb_text.text.strip_edges() if _fb_text else ""
	if text.length() < 5:
		_toast("Write a few words first", "warn")
		return
	var title := "[%s] %s" % [_fb_kind, text.split("\n")[0].left(60)]
	var url := "%s?labels=%s&title=%s&body=%s" % [FEEDBACK_URL, ("feedback," + _fb_kind.to_lower().replace(" / ", "-")).uri_encode(),
		title.uri_encode(), _feedback_body().uri_encode()]
	OS.shell_open(url)
	_toast("Opening GitHub to send your feedback…", "quest")

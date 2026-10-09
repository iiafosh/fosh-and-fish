extends Control
## Main screen: Blender-rendered biome + boat, Virtual Fisher (bot) style catch
## card, and panels for every system (shop, biomes, charms, pets, boosts,
## quests, prestige, buffs). All art comes from assets/vf (see
## tools/blender/render_assets.py).

const ART := "res://assets/vf/"
var VERSION: String = Updater.version + " beta"
const FEEDBACK_URL := "https://github.com/iiafosh/fosh-and-fish/issues/new"
const C_BG := Color("#cfe8ec")
const C_PANEL := Color("#fbfdfe")          # frosted white
const C_PANEL2 := Color("#eef4f6")         # cards inside panels
const C_TEXT := Color("#1f2d35")
const C_MUTED := Color("#6b7d86")
const C_GOOD := Color("#22a06b")
const C_GOLD := Color("#d4920f")
const C_BAD := Color("#e04f45")
const C_NEUTRAL := Color("#eef3f5")
const C_TEAL := Color("#1d9bb0")
const C_DARK := Color(0.055, 0.16, 0.2, 0.74)  # dark glass pills (numbers)
const C_LIGHT := Color(1, 1, 1, 0.9)          # light glass pills (actions)
const C_SHADOW := Color(0.02, 0.1, 0.14, 0.22)

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
var _hold_btn := false       # FISH button held down
var _hold_water := false     # finger / mouse held on the water
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
var update_pill: Button
var xp_ring: Control
var boost_pill: PanelContainer
var boost_icon: TextureRect
var cast_ring: Control
var top_right: HBoxContainer
var book_btn: Button
var phone_btn: Button
var menu_btn: Button
var panel_back: Button
var tabs_track: PanelContainer
var _update_announced := false
var account_ui                 # scripts/net/account_ui.gd (Menu -> Account)

func _ready() -> void:
	_load_manifest()
	_build()
	account_ui = load("res://scripts/net/account_ui.gd").new(self)
	VF.changed.connect(_refresh)
	VF.trip_done.connect(_on_trip)
	VF.leveled_up.connect(_on_level_up)
	VF.toast.connect(_toast)
	VF.goal_done.connect(_on_goal_done)
	stage.merchant_clicked.connect(func(): _open_panel("shop", "Rods"))
	_refresh()
	_apply_biome()
	_card_intro()
	_build_version_label()
	_build_coach()
	_check_capture()
	Updater.boot_ok()
	Updater.status_changed.connect(_on_update_status)
	if Updater.skipped_patch != "":
		_toast("Update %s didn't start, so you're on the previous version. A fix is coming!" % Updater.skipped_patch, "warn")
	if not _capturing() and not OS.get_cmdline_user_args().has("--trailer") and not OS.get_cmdline_user_args().has("--reel"):
		get_tree().create_timer(4.0).timeout.connect(Updater.check)

func _process(delta: float) -> void:
	_save_timer += delta
	if _save_timer > 20.0:
		_save_timer = 0.0
		VF.save_game()
	var cd: float = VF.cooldown()
	var left: float = VF.cooldown_left()
	cast_ring.queue_redraw()
	_process_hold()
	if Engine.get_process_frames() % 30 == 0:
		_refresh_boosts()
	_process_coach(delta)

## hold the FISH button, Space/F, or a finger on the water to keep casting
func _process_hold() -> void:
	if _hold_water and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_hold_water = false
	var held := _hold_btn or _hold_water or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_F)
	if held and not overlay.visible and VF.cooldown_left() <= 0.0 and VF.can_cast() == "":
		_do_cast()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		VF.save_game()
		Backend.on_quit()          # signed in: upload the last progress before the window closes

func _unhandled_input(event: InputEvent) -> void:
	# tap / click anywhere on the scene to cast (mobile friendly)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not overlay.visible:
		_hold_water = true
		stage.set_aim(event.position)          # the line lands where you tap
		_do_cast()
		return
	if event is InputEventMouseMotion and _hold_water and not overlay.visible:
		stage.set_aim(event.position)          # drag while holding to move the spot
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_F:
				if overlay.visible: return
				_do_cast()
			KEY_S:
				if not overlay.visible: _do_sell()
			KEY_ESCAPE:
				if overlay.visible: _close_panel()
				else: _open_panel("menu")
			KEY_TAB:
				if overlay.visible and _panel_kind == "inventory": _close_panel()
				else: _open_panel("inventory")
			KEY_P:
				_open_phone()
			KEY_O:
				if overlay.visible and _panel_kind == "settings": _close_panel()
				else: _open_panel("settings")
			KEY_G:
				if overlay.visible and _panel_kind == "guide": _close_panel()
				else: _open_panel("guide")
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var kinds := ["shop", "biomes", "inventory", "charms", "pets", "boosts", "quests", "prestige", "stats"]   # same order as the Menu tiles
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
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", Color(C_TEXT, 0.35))
	if color == C_NEUTRAL:
		b.add_theme_stylebox_override("normal", sbox(Color.WHITE, 14, 1, Color("#d5e1e5"), 8))
		b.add_theme_stylebox_override("hover", sbox(Color("#f6fbfc"), 14, 2, C_TEAL.lightened(0.3), 8))
		b.add_theme_stylebox_override("pressed", sbox(Color("#e3eef1"), 14, 1, C_TEAL, 8))
	else:
		var n := sbox(color, 14, 0, Color.TRANSPARENT, 9)
		n.border_width_bottom = 3
		n.border_color = color.darkened(0.25)
		b.add_theme_stylebox_override("normal", n)
		var h := n.duplicate()
		h.bg_color = color.lightened(0.12)
		b.add_theme_stylebox_override("hover", h)
		var pr := n.duplicate()
		pr.bg_color = color.darkened(0.12)
		pr.border_width_bottom = 1
		b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("disabled", sbox(Color("#e4ecef"), 14, 0, Color.TRANSPARENT, 9))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if min_w > 0: b.custom_minimum_size.x = min_w
	b.pressed.connect(func(): AudioManager.play_click())
	return b

# ------------------------------------------------------- pill UI kit (0.2)
const PH := "res://assets/third_party/phosphor/"

## a Phosphor icon (white, tint it with modulate / icon colors)
func ph(name: String) -> Texture2D:
	var path := PH + name + ".svg"
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]

func is_touch() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")

func pill_box(light: bool, pad_h := 12, pad_v := 6) -> StyleBoxFlat:
	var sb := sbox(C_LIGHT if light else C_DARK, 999, 1, Color(1, 1, 1, 0.7) if light else Color(1, 1, 1, 0.08), 0, 6)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

## small keyboard hint chip ("Tab", "Esc"); hidden on phones
func keycap(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := sbox(Color("#e6eef1"), 6, 1, Color("#c9d6db"), 0)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(lbl(text, 11, Color("#5b6d75")))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visible = not is_touch()
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p

## a clickable pill: [icon] text [keycap] (+ optional red badge)
func pill_button(icon_name: String, text: String, key := "", light := true) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 40
	b.text = text
	b.add_theme_font_size_override("font_size", 14)
	var fc := C_TEXT if light else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, fc)
	if icon_name != "":
		b.icon = ph(icon_name)
		b.add_theme_constant_override("icon_max_width", 18)
		b.add_theme_constant_override("h_separation", 7)
	var show_key := key != "" and not is_touch()
	var sb := pill_box(light, 13, 6)
	if show_key: sb.content_margin_right = 13 + 8 + 9 * key.length() + 10
	b.add_theme_stylebox_override("normal", sb)
	var hv := sb.duplicate()
	hv.bg_color = Color.WHITE if light else C_DARK.lightened(0.1)
	hv.border_color = C_TEAL.lightened(0.35) if light else Color(1, 1, 1, 0.25)
	b.add_theme_stylebox_override("hover", hv)
	var pr := sb.duplicate()
	pr.bg_color = Color("#e3eef1") if light else C_DARK.darkened(0.2)
	b.add_theme_stylebox_override("pressed", pr)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if show_key:
		var kc := keycap(key)
		kc.anchor_left = 1.0
		kc.anchor_right = 1.0
		kc.anchor_top = 0.5
		kc.anchor_bottom = 0.5
		kc.offset_right = -11
		kc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		kc.grow_vertical = Control.GROW_DIRECTION_BOTH
		b.add_child(kc)
	var badge := PanelContainer.new()
	badge.name = "Badge"
	var bsb := sbox(Color("#ff4d4f"), 999, 2, Color.WHITE, 0)
	bsb.content_margin_left = 5
	bsb.content_margin_right = 5
	badge.add_theme_stylebox_override("panel", bsb)
	badge.add_child(lbl("", 11, Color.WHITE))
	badge.position = Vector2(-6, -7)
	badge.visible = false
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(badge)
	b.pressed.connect(func(): AudioManager.play_click())
	return b

func pill_text(b: Button, text: String) -> void:
	b.text = text

func pill_badge(b: Button, n: int) -> void:
	var bd: PanelContainer = b.get_node("Badge")
	bd.visible = n > 0
	(bd.get_child(0) as Label).text = str(n) if n < 100 else "99+"

func accent() -> Color:
	return VFData.BIOMES[VF.biome].accent

func money_str(n: float) -> String:
	return "$" + VF.fmt(n)

# ================================================================== build
func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE      # clicks must reach the water (tap to cast)
	add_child(bg)
	_build_stage()
	_build_hud()
	_build_card()
	_build_dock()
	_build_overlay()

func _build_stage() -> void:
	stage = load("res://scripts/vf/vf_stage.gd").new()
	add_child(stage)
	_click_through.call_deferred(stage)
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)

# every stage layer lets clicks fall through to _unhandled_input (tap the water to cast),
# except the merchant's hitbox
func _click_through(n: Node) -> void:
	if n is Control and n != stage.merchant_hit:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_click_through(c)

func _flat(pad := 10, radius := 16) -> StyleBoxFlat:
	return sbox(Color(C_PANEL, 0.94), radius, 1, Color("#e3d3b4"), pad, 8)

func _build_hud() -> void:
	# ---- top-left: who you are + what you have (dark glass = numbers)
	var col := VBoxContainer.new()
	col.position = Vector2(14, 12)
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	# level: XP ring around the number
	var lv := PanelContainer.new()
	lv.add_theme_stylebox_override("panel", pill_box(false, 6, 4))
	lv.tooltip_text = "Your level. Fish to earn XP."
	var lvh := HBoxContainer.new()
	lvh.add_theme_constant_override("separation", 8)
	lv.add_child(lvh)
	xp_ring = Control.new()
	xp_ring.custom_minimum_size = Vector2(32, 32)
	xp_ring.draw.connect(_draw_xp_ring)
	xp_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lvh.add_child(xp_ring)
	var lvv := VBoxContainer.new()
	lvv.add_theme_constant_override("separation", -4)
	lvv.alignment = BoxContainer.ALIGNMENT_CENTER
	lvl_label = lbl("Lv 1", 16, Color.WHITE)
	xp_label = lbl("0 / 100 XP", 10, Color(1, 1, 1, 0.7))
	lvv.add_child(lvl_label)
	lvv.add_child(xp_label)
	lvh.add_child(lvv)
	var pad := Control.new()
	pad.custom_minimum_size.x = 4
	lvh.add_child(pad)
	row.add_child(lv)
	xp_bar = ProgressBar.new()            # kept for the ring's value; never shown
	xp_bar.visible = false
	add_child(xp_bar)
	# money
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", pill_box(false, 12, 6))
	mp.tooltip_text = "Money"
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 6)
	var coin := icon(ph("coins"), 18)
	coin.modulate = Color("#ffcf4a")
	mh.add_child(coin)
	money_label = lbl("$0", 16, Color.WHITE)
	mh.add_child(money_label)
	mp.add_child(mh)
	row.add_child(mp)
	# exotic fish wallet (click to open)
	wallet_btn = pill_button("diamond", "0", "", false)
	wallet_btn.tooltip_text = "Wallet: exotic fish, hooks and azure fish"
	wallet_btn.pressed.connect(_toggle_wallet)
	row.add_child(wallet_btn)
	prestige_label = lbl("P0", 15, Color("#ffcf4a"), 4)
	prestige_label.tooltip_text = "Prestige"
	prestige_label.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(prestige_label)
	# wallet popover
	wallet = PanelContainer.new()
	wallet.add_theme_stylebox_override("panel", sbox(C_LIGHT, 16, 1, Color.WHITE, 12, 8))
	wallet.visible = false
	var wg := GridContainer.new()
	wg.columns = 3
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
	# goal: one quiet line + thin progress, click to jump to it
	goal_box = PanelContainer.new()
	goal_box.add_theme_stylebox_override("panel", sbox(C_LIGHT, 14, 1, Color(1, 1, 1, 0.7), 10, 6))
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 4)
	goal_label = lbl("", 13)
	goal_bar = ProgressBar.new()
	goal_bar.show_percentage = false
	goal_bar.custom_minimum_size = Vector2(230, 5)
	goal_bar.add_theme_stylebox_override("background", sbox(Color("#dfe9ec"), 3, 0, Color.TRANSPARENT, 0))
	goal_bar.add_theme_stylebox_override("fill", sbox(C_GOLD, 3, 0, Color.TRANSPARENT, 0))
	gv.add_child(goal_label)
	gv.add_child(goal_bar)
	goal_box.add_child(gv)
	goal_box.mouse_filter = Control.MOUSE_FILTER_STOP
	goal_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	goal_box.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _open_goal())
	goal_box.tooltip_text = "Your next goal. Click to go there."
	col.add_child(goal_box)
	# active buffs: one small dark pill under the goal (hidden when nothing is active)
	boost_pill = PanelContainer.new()
	boost_pill.add_theme_stylebox_override("panel", pill_box(false, 10, 4))
	boost_pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	boost_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 6)
	boost_icon = icon(ph("clover"), 14)
	boost_icon.modulate = Color("#7ef0c6")
	bh.add_child(boost_icon)
	boost_label = lbl("", 12, Color.WHITE)
	bh.add_child(boost_label)
	boost_pill.add_child(bh)
	col.add_child(boost_pill)

	# ---- top-right: where you can go (light glass = actions)
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 8)
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_right = -14
	tr.offset_top = 12
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.alignment = BoxContainer.ALIGNMENT_END
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	top_right = tr
	book_btn = pill_button("book-open-text", "Fish Book", "Tab")
	book_btn.pressed.connect(func(): _open_panel("inventory"))
	tr.add_child(book_btn)
	phone_btn = pill_button("device-mobile", "Phone", "P")
	phone_btn.pressed.connect(_open_phone)
	tr.add_child(phone_btn)
	menu_btn = pill_button("dots-nine", "Menu", "Esc")
	menu_btn.pressed.connect(func(): _open_panel("menu"))
	tr.add_child(menu_btn)

func _draw_xp_ring() -> void:
	var c := xp_ring.size * 0.5
	var r := minf(c.x, c.y) - 3.0
	var k := clampf(xp_bar.value / maxf(1.0, xp_bar.max_value), 0.0, 1.0)
	xp_ring.draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.18), 4.0, true)
	if k > 0.0:
		xp_ring.draw_arc(c, r, -PI / 2, -PI / 2 + TAU * k, 40, Color("#7ef0c6"), 4.0, true)
	xp_ring.draw_circle(c, r - 4.5, Color(1, 1, 1, 0.12))

func _toggle_wallet() -> void:
	wallet.visible = not wallet.visible

func _build_card() -> void:
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", sbox(C_LIGHT, 18, 1, Color(1, 1, 1, 0.8), 0, 10))
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -314
	card.offset_right = -14
	card.offset_top = 62
	card.custom_minimum_size.x = 300
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
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
	toast_box.offset_top = 64
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

func _build_dock() -> void:
	# ---- bottom-left: your gear (rod, bait, biome, pet) in one light pill
	var gear := PanelContainer.new()
	gear.add_theme_stylebox_override("panel", sbox(C_LIGHT, 20, 1, Color(1, 1, 1, 0.7), 6, 6))
	gear.anchor_top = 1.0
	gear.anchor_bottom = 1.0
	gear.offset_left = 14
	gear.offset_bottom = -12
	gear.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(gear)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 4)
	gear.add_child(gh)
	for key in ["rod", "bait", "biome", "pet"]:
		gh.add_child(_chip(key))
	# ---- bottom-centre: sell (only when the hold has fish) + buffs
	sell_btn = btn("", C_GOLD.lightened(0.1), 16, 0)
	sell_btn.icon = ph("hand-coins")
	sell_btn.add_theme_constant_override("icon_max_width", 22)
	sell_btn.add_theme_color_override("icon_normal_color", Color.WHITE)
	sell_btn.add_theme_color_override("icon_hover_color", Color.WHITE)
	sell_btn.add_theme_color_override("icon_pressed_color", Color.WHITE)
	for st in ["normal", "hover", "pressed"]:
		var sb: StyleBoxFlat = sell_btn.get_theme_stylebox(st).duplicate()
		sb.set_corner_radius_all(999)
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.shadow_size = 8
		sb.shadow_color = C_SHADOW
		sell_btn.add_theme_stylebox_override(st, sb)
	sell_btn.custom_minimum_size.y = 48
	sell_btn.anchor_left = 0.5
	sell_btn.anchor_right = 0.5
	sell_btn.anchor_top = 1.0
	sell_btn.anchor_bottom = 1.0
	sell_btn.offset_bottom = -16
	sell_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sell_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sell_btn.pressed.connect(_do_sell)
	sell_btn.tooltip_text = "Sell every fish in your hold  [S]"
	add_child(sell_btn)
	# ---- bottom-right: the cast button with a cooldown ring
	fish_btn = Button.new()
	fish_btn.focus_mode = Control.FOCUS_NONE
	fish_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fb := sbox(C_TEAL, 999, 3, Color.WHITE, 0, 10)
	fish_btn.add_theme_stylebox_override("normal", fb)
	var fbh := fb.duplicate()
	fbh.bg_color = C_TEAL.lightened(0.12)
	fish_btn.add_theme_stylebox_override("hover", fbh)
	var fbp := fb.duplicate()
	fbp.bg_color = C_TEAL.darkened(0.15)
	fish_btn.add_theme_stylebox_override("pressed", fbp)
	fish_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	fish_btn.icon = ph("fish")
	fish_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fish_btn.expand_icon = false
	fish_btn.add_theme_constant_override("icon_max_width", 34)
	fish_btn.custom_minimum_size = Vector2(82, 82)
	fish_btn.anchor_left = 1.0
	fish_btn.anchor_right = 1.0
	fish_btn.anchor_top = 1.0
	fish_btn.anchor_bottom = 1.0
	fish_btn.offset_left = -100
	fish_btn.offset_right = -18
	fish_btn.offset_top = -100
	fish_btn.offset_bottom = -18
	fish_btn.pressed.connect(_do_cast)
	fish_btn.button_down.connect(func(): _hold_btn = true)
	fish_btn.button_up.connect(func(): _hold_btn = false)
	fish_btn.tooltip_text = "Cast — or just tap the water. Hold to keep fishing  [Space]"
	add_child(fish_btn)
	fish_fill = ColorRect.new()          # kept for compatibility (unused visually)
	fish_fill.visible = false
	fish_btn.add_child(fish_fill)
	cast_ring = Control.new()
	cast_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cast_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cast_ring.draw.connect(_draw_cast_ring)
	fish_btn.add_child(cast_ring)
	var kc := keycap("Space")
	kc.anchor_left = 0.5
	kc.anchor_right = 0.5
	kc.anchor_top = 1.0
	kc.anchor_bottom = 1.0
	kc.offset_top = -4
	kc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fish_btn.add_child(kc)

func _draw_cast_ring() -> void:
	var c := cast_ring.size * 0.5
	var r := minf(c.x, c.y) + 5.0
	var cd: float = VF.cooldown()
	var left: float = VF.cooldown_left()
	if left > 0.0 and cd > 0.0:
		cast_ring.draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.35), 5.0, true)
		cast_ring.draw_arc(c, r, -PI / 2, -PI / 2 + TAU * (1.0 - left / cd), 48, Color.WHITE, 5.0, true)
	else:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
		cast_ring.draw_arc(c, r + pulse * 3.0, 0, TAU, 48, Color(1, 1, 1, 0.35 + 0.35 * pulse), 3.0, true)

func _chip(key: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", sbox(Color(1, 1, 1, 0), 14, 0, Color.TRANSPARENT, 4))
	b.add_theme_stylebox_override("hover", sbox(Color("#e8f2f4"), 14, 0, Color.TRANSPARENT, 4))
	b.add_theme_stylebox_override("pressed", sbox(Color("#d9e9ed"), 14, 0, Color.TRANSPARENT, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 11)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, C_MUTED)
	b.custom_minimum_size = Vector2(56, 58)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", 32)
	b.clip_text = true
	b.pressed.connect(_on_chip.bind(key))
	b.pressed.connect(func(): AudioManager.play_click())
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
	dim.color = Color(0.02, 0.1, 0.14, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_panel())
	overlay.add_child(dim)
	var p := PanelContainer.new()
	var psb := sbox(Color(C_PANEL, 0.97), 26, 1, Color.WHITE, 22, 28)
	psb.shadow_offset = Vector2(0, 10)
	p.add_theme_stylebox_override("panel", psb)
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
	head.add_theme_constant_override("separation", 10)
	panel_back = pill_button("caret-left", "Menu", "", true)
	panel_back.pressed.connect(func(): _open_panel("menu"))
	head.add_child(panel_back)
	panel_title = lbl("", 26, C_TEXT)
	panel_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(panel_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := pill_button("x", "Close", "Esc", true)
	close.pressed.connect(_close_panel)
	head.add_child(close)
	v.add_child(head)
	tabs_track = PanelContainer.new()
	tabs_track.add_theme_stylebox_override("panel", sbox(Color("#e6eef1"), 999, 0, Color.TRANSPARENT, 4))
	tabs_track.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel_tabs = HBoxContainer.new()
	panel_tabs.add_theme_constant_override("separation", 2)
	tabs_track.add_child(panel_tabs)
	v.add_child(tabs_track)
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
	var cast_start := Time.get_ticks_msec()
	VF._last_cast_ms = cast_start              # cooldown starts the moment you cast
	stage.cast(func():
		AudioManager.play_splash()
		VF._last_cast_ms = -100000
		VF.cast()
		VF._last_cast_ms = cast_start)         # keep counting from the cast, not the catch

func _do_sell() -> void:
	var earned: int = VF.sell_all()
	if earned > 0 and VF.tutorial == 1:
		_coach_next(2)
	if earned > 0:
		AudioManager.play_success()
		_float_text("+%s" % money_str(earned), sell_btn.get_global_rect().get_center() + Vector2(0, -40), C_GOLD)

func _on_trip(res: Dictionary) -> void:
	_show_catch(res)
	for f in res.get("new_species", []):
		_banner("New fish discovered!", "%s  ·  %d / %d in your collection" % [f, VF.discovered.size(), VFData.FISH_ORDER.size()],
			icon_for("fish", f), Color("#2f8f9e"))
		stage.burst("sparkle", stage._bobber)
	if int(res.get("lucky", 0)) > 0:
		_float_text("Lucky splash!  +%s" % money_str(res.lucky), stage.bobber_screen() + Vector2(0, -70), C_GOLD)
		stage.burst("sparkle", stage._bobber)
		AudioManager.play_strike()
	if VF.tutorial == 0:
		_coach_next(1)
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
	# a pill that pops in at the top-centre, then floats away
	var p := PanelContainer.new()
	var sb := sbox(Color(C_TEAL, 0.95), 999, 3, Color.WHITE, 0, 14)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var star := icon(ph("star"), 26)
	star.modulate = Color("#ffcf4a")
	h.add_child(star)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	v.add_child(lbl("LEVEL UP", 13, Color(1, 1, 1, 0.8)))
	v.add_child(lbl("Level %s" % VF.commas(new_level), 28, Color.WHITE))
	h.add_child(v)
	if reward > 0:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", pill_box(true, 10, 3))
		chip.add_child(lbl("+" + money_str(reward), 15, C_GOOD))
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(chip)
	p.add_child(h)
	fx_layer.add_child(p)
	await get_tree().process_frame
	if not is_instance_valid(p): return
	var vs := get_viewport_rect().size
	p.pivot_offset = p.size * 0.5
	p.position = Vector2((vs.x - p.size.x) * 0.5, vs.y * 0.2)
	p.scale = Vector2(0.6, 0.6)
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(p, "position:y", p.position.y - 30, 0.6)
	tw.parallel().tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)

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
	var sb := pill_box(false, 16, 7)
	sb.bg_color = Color(colors.get(kind, Color("#334155")), 0.9)
	p.add_theme_stylebox_override("panel", sb)
	var tl := lbl(text, 14, Color.WHITE)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(tl)
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
	for t in ["Follow the arrow — or press G for the guide.", "Finish the goals under your level for rewards.", "Made by afosh."]:
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
		l.custom_minimum_size.x = 220
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
	xp_ring.queue_redraw()
	money_label.text = money_str(VF.money)
	for k in exotic_labels:
		exotic_labels[k].text = VF.fmt(VF.exotics.get(k, 0))
	hooks_label.text = str(VF.hooks)
	pill_text(wallet_btn, VF.fmt(VF.exotics.gold + VF.exotics.emerald + VF.exotics.lava + VF.exotics.diamond))
	wallet_btn.visible = VF.level >= 10 or VF.exotics.gold + VF.exotics.emerald + VF.exotics.lava + VF.exotics.diamond > 0
	prestige_label.text = "P%d" % VF.prestige
	prestige_label.visible = VF.prestige > 0
	var inv: int = VF.inventory_value()
	var nfish := 0
	for f in VF.inventory: nfish += int(VF.inventory[f])
	sell_btn.text = "Sell %s fish  ·  %s" % [VF.commas(nfish), money_str(inv)]
	sell_btn.visible = inv > 0
	sell_btn.reset_size()
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
	if overlay.visible and _panel_kind != "account":   # the account forms keep their typing focus
		_render_panel()

## The cheapest useful purchase you can't afford yet (next rod or boat),
## mirroring the Prestige 0 Guide's buying order.
func _refresh_goal() -> void:
	var sg: Dictionary = VF.current_goal()
	if not sg.is_empty():
		goal_box.visible = true
		_goal = {"starter": true, "goal": sg}
		var prog: int = mini(VF.goal_progress(sg), int(sg.goal))
		goal_label.text = "★ %s   %s/%s\n    Reward: %s" % [sg.text, VF.commas(prog), VF.commas(sg.goal), VF.goal_reward_text(sg.reward)]
		goal_bar.max_value = sg.goal
		goal_bar.value = prog
		return
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
	if _goal.is_empty(): return
	if _goal.get("starter", false):
		match String(_goal.goal.stat):
			"rods": _open_panel("shop", "Rods")
			"boats": _open_panel("shop", "Boats")
			"bait_casts": _open_panel("shop", "Bait")
			"species": _open_panel("inventory")
			"sells": _do_sell()
			_: _open_panel("guide", "Basics")
		return
	_open_panel(_goal.panel[0], _goal.panel[1])

func _refresh_boosts() -> void:
	var names := []
	var tips := []
	for k in ["fish", "treasure", "worker"]:
		if VF.is_boost_active(k):
			names.append(k.capitalize())
			tips.append("%s boost: %s left" % [k.capitalize(), _clock(VF.boost_left(k))])
	if VF.beginner_mult() > 1.0:
		names.append("Beginner's Luck ×%.1f XP" % VF.beginner_mult())
		tips.append("Beginner's Luck: extra XP for new fishers, fades out by level %d" % VFData.BEGINNER_END)
	if Time.get_unix_time_from_system() < VF.personal_until:
		names.append("Personal")
		tips.append("Personal booster: %s left" % _clock(VF.personal_until - Time.get_unix_time_from_system()))
	boost_label.text = "  ·  ".join(names)
	boost_pill.visible = not names.is_empty()
	boost_icon.texture = ph("clover") if names.size() == 1 and VF.beginner_mult() > 1.0 else ph("lightning")
	boost_icon.modulate = Color("#7ef0c6") if boost_icon.texture == ph("clover") else Color("#ffcf4a")
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
	"account": ["Account", "Leaderboard"],
}

func _open_panel(kind: String, tab: String = "") -> void:
	if VF.tutorial == 2 and kind == "shop":
		_coach_next(3)
	_panel_kind = kind
	_panel_tab = tab if tab != "" else (PANEL_TABS[kind][0] if PANEL_TABS.has(kind) else "")
	overlay.visible = true
	_render_panel()

func _close_panel() -> void:
	if VF.tutorial == 3 and _panel_kind == "shop":
		_coach_next(4)
	overlay.visible = false
	_panel_kind = ""

func _render_panel() -> void:
	_clear(panel_tabs)
	_clear(panel_body)
	var titles := {"inventory": "Fish Book", "shop": "Shop", "biomes": "Biomes", "charms": "Charms", "pets": "Pets",
		"boosts": "Boosts", "quests": "Quests & Daily", "prestige": "Prestige", "stats": "Buffs & Odds", "guide": "Guide", "settings": "Settings", "update": "Updates", "menu": "Menu", "account": "Account"}
	panel_title.text = titles.get(_panel_kind, "")
	if PANEL_TABS.has(_panel_kind):
		for t in PANEL_TABS[_panel_kind]:
			var b := Button.new()
			b.text = t
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(86, 34)
			b.add_theme_font_size_override("font_size", 14)
			var on: bool = t == _panel_tab
			b.add_theme_stylebox_override("normal", sbox(Color.WHITE if on else Color(1, 1, 1, 0), 999, 0, Color.TRANSPARENT, 6, 4 if on else 0))
			b.add_theme_stylebox_override("hover", sbox(Color.WHITE if on else Color(1, 1, 1, 0.5), 999, 0, Color.TRANSPARENT, 6))
			b.add_theme_stylebox_override("pressed", sbox(Color.WHITE, 999, 0, Color.TRANSPARENT, 6))
			b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			for k in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.add_theme_color_override(k, C_TEXT if on else C_MUTED)
			b.pressed.connect(func(): AudioManager.play_click(); _panel_tab = t; _render_panel())
			panel_tabs.add_child(b)
	tabs_track.visible = PANEL_TABS.has(_panel_kind)
	panel_back.visible = _panel_kind != "menu"
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
		"settings": _panel_settings()
		"update": _panel_update()
		"menu": _panel_menu()
		"account": _panel_account()

## Menu -> Account: sign in, cloud save, leaderboard (built by scripts/net/account_ui.gd)
func _panel_account() -> void:
	account_ui.build(_panel_tab)

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
	panel_body.add_child(lbl("Fish collection  %d / %d" % [VF.discovered.size(), VFData.FISH_ORDER.size()], 18))
	var dex := _grid(10)
	for f in VFData.FISH_ORDER:
		var known: bool = VF.discovered.has(f)
		var ic := icon(icon_for("fish", f), 52)
		ic.modulate = Color.WHITE if known else Color(0.1, 0.12, 0.18, 0.55)
		ic.tooltip_text = ("%s — caught %s" % [f, VF.commas(int(VF.discovered[f]))]) if known else "??? (not discovered yet)"
		ic.mouse_filter = Control.MOUSE_FILTER_STOP
		dex.add_child(ic)

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
	if VF.beginner_mult() > 1.0:
		panel_body.add_child(lbl("🍀 Beginner's Luck: ×%.1f XP (included above) — fades out by level %d" % [VF.beginner_mult(), VFData.BEGINNER_END], 14, C_GOOD))
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

# ============================================================ capture mode
## godot --path . -- --capture=DIR [--demo=BIOME] : plays a few casts, saves
## screenshots of the main screen and key panels, then quits. Never saves.
func _check_capture() -> void:
	if "--trailer" in OS.get_cmdline_user_args():
		_trailer()
		return
	if "--reel" in OS.get_cmdline_user_args():
		_reel()
		return
	var dir := ""
	var demo := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="): dir = a.substr(10)
		if a.begins_with("--demo="): demo = a.substr(7)
	if dir == "": return
	VF.autosave = false
	if "--update-test" in OS.get_cmdline_user_args():
		# exported-build test of in-game updates (tools/release.py --local + a local web server):
		# download -> verify -> restart, then report what is running. Writes user://update_test.txt
		VF.autosave = false
		Updater.status_changed.connect(_update_test_step)
		Updater.check()
		return
	if "--backend-test" in OS.get_cmdline_user_args():
		# accounts + cloud save end to end against tools/mock_supabase.py (see scripts/net/backend_test.gd)
		var bt = load("res://scripts/net/backend_test.gd").new()
		await bt.run(self, dir)
		get_tree().quit(1 if bt.fails > 0 else 0)
		return
	if "--aim-test" in OS.get_cmdline_user_args():
		# tap three different spots; the bobber must land on each (within a few px)
		VF._apply(VF._defaults.duplicate(true))
		VF.tutorial = 99
		VF.changed.emit()
		_coach_show()
		await get_tree().create_timer(1.0).timeout
		var vs := get_viewport_rect().size
		var spots := [vs * Vector2(0.75, 0.62), vs * Vector2(0.45, 0.78), vs * Vector2(0.79, 0.32), vs * Vector2(0.72, 0.21), vs * Vector2(0.3, 0.2)]
		for i in spots.size():
			VF._last_cast_ms = -100000
			_tap(spots[i])
			await get_tree().create_timer(1.2).timeout
			print("AIM tap=%s bobber=%s" % [spots[i].round(), stage.bobber_screen().round()])
			await _shot(dir + "/aim%d.png" % i)
		get_tree().quit()
		return
	if "--onboarding" in OS.get_cmdline_user_args():
		VF._apply(VF._defaults.duplicate(true))
		VF.tutorial = 0
		VF.changed.emit()
		_coach_show()
		await get_tree().create_timer(1.0).timeout
		await _shot(dir + "/on0_cast.png")
		var trips_before: int = VF.stats.trips
		for i in 6:
			VF._last_cast_ms = -100000
			var at: Vector2 = stage.bobber_screen() + Vector2(40, 30)
			for pressed in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = pressed
				ev.position = at
				ev.global_position = at
				Input.parse_input_event(ev)
			await get_tree().create_timer(0.7).timeout
		print("TAP_CASTS ", VF.stats.trips - trips_before)
		await get_tree().create_timer(0.6).timeout
		await _shot(dir + "/on1_sell.png")
		_do_sell()
		await get_tree().create_timer(2.6).timeout
		await _shot(dir + "/on2_merchant.png")
		stage.merchant_clicked.emit()
		await get_tree().create_timer(0.6).timeout
		await _shot(dir + "/on3_shop.png")
		_close_panel()
		await get_tree().create_timer(0.8).timeout
		await _shot(dir + "/on4_goals.png")
		_open_panel("inventory")
		await get_tree().create_timer(0.5).timeout
		await _shot(dir + "/on5_collection.png")
		get_tree().quit()
		return
	if demo != "":
		_veteran(demo)
	await get_tree().create_timer(0.6).timeout
	for i in 3:
		VF._last_cast_ms = -100000
		_do_cast()
		await get_tree().create_timer(0.9).timeout
	await get_tree().create_timer(0.3).timeout
	if "--clean" in OS.get_cmdline_user_args():
		for c in get_children():
			if c is CanvasItem and c != stage and c != fx_layer and not (c is ColorRect):
				c.visible = false
		await get_tree().create_timer(1.2).timeout
		await _shot(dir + "/clean.png")
		get_tree().quit()
		return
	await _shot(dir + "/main.png")
	var shots := [["menu", ""], ["shop", "Rods"], ["biomes", ""], ["prestige", "Guide"], ["stats", ""], ["charms", ""], ["guide", "Basics"], ["guide", "Credits"], ["guide", "Feedback"], ["settings", ""]]
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
	var v := lbl("fosh&fish %s · by afosh" % VERSION, 11, Color(1, 1, 1, 0.75), 4)
	v.anchor_left = 1.0
	v.anchor_right = 1.0
	v.anchor_top = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = -480
	v.offset_right = -118
	v.offset_top = -24
	v.offset_bottom = -8
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	update_pill = btn("⬆  Update available", Color("#2f8f9e"), 14, 0)
	update_pill.custom_minimum_size = Vector2(0, 34)
	update_pill.anchor_left = 1.0
	update_pill.anchor_right = 1.0
	update_pill.anchor_top = 1.0
	update_pill.anchor_bottom = 1.0
	update_pill.offset_left = -230
	update_pill.offset_right = -16
	update_pill.offset_top = -142
	update_pill.offset_bottom = -108
	update_pill.visible = false
	update_pill.pressed.connect(func(): _open_panel("update"))
	add_child(update_pill)
	add_child(v)
	move_child(v, overlay.get_index())

func _panel_guide() -> void:
	if _panel_tab == "Feedback":
		_panel_feedback()
		return
	if _panel_tab == "Credits":
		_panel_credits()
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

func _panel_credits() -> void:
	var head := VBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	var t := lbl("fosh&fish", 34, C_TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(t)
	var by := lbl("Made by %s" % VFGuide.AUTHOR, 24, Color("#2f8f9e"))
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(by)
	var ver := lbl("Version %s" % VERSION, 13, C_MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(ver)
	panel_body.add_child(head)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for s in VFGuide.SOCIALS:
		var url: String = s[1]
		var b := btn("%s  ↗" % s[0], Color("#0a66c2") if s[0] == "LinkedIn" else Color("#24292f"), 16, 170)
		b.tooltip_text = url
		b.pressed.connect(func(): OS.shell_open(url))
		row.add_child(b)
	panel_body.add_child(row)
	var thanks := lbl("Thanks for testing! Follow afosh for updates, and send ideas or bugs from the Feedback tab.", 14, C_TEXT)
	thanks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_body.add_child(thanks)
	var assets := lbl(VFGuide.ASSET_CREDITS, 12, C_MUTED)
	assets.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	assets.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_body.add_child(assets)

# =============================================================== settings
func _setting_row(title: String, sub: String, on: bool, on_key: String, vol: float = -1.0, vol_key: String = "") -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(C_PANEL2, 12, 0, Color.TRANSPARENT, 12))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(lbl(title, 18))
	v.add_child(lbl(sub, 13, C_MUTED))
	h.add_child(v)
	if vol >= 0.0:
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = vol
		sl.custom_minimum_size = Vector2(220, 28)
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sl.editable = on
		sl.add_theme_stylebox_override("slider", sbox(Color("#e4d6bb"), 6, 0, Color.TRANSPARENT, 4))
		sl.add_theme_stylebox_override("grabber_area", sbox(Color("#2f8f9e"), 6, 0, Color.TRANSPARENT, 4))
		sl.add_theme_stylebox_override("grabber_area_highlight", sbox(Color("#3aa5b5"), 6, 0, Color.TRANSPARENT, 4))
		sl.value_changed.connect(func(x): AudioManager.set_option(vol_key, x))
		sl.drag_ended.connect(func(_c): AudioManager.play_click())
		h.add_child(sl)
	var t := btn("ON" if on else "OFF", C_GOOD if on else Color("#9a8a74"), 15, 86)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.pressed.connect(func():
		AudioManager.set_option(on_key, not on)
		_render_panel())
	h.add_child(t)
	panel_body.add_child(p)

func _panel_settings() -> void:
	var A = AudioManager
	_setting_row("Music & ambience", "Calm water sounds in the background", A.music_on, "music_on", A.music_volume, "music_volume")
	_setting_row("Sound effects", "Casting, splashes, clicks, level-ups", A.sfx_on, "sfx_on", A.sfx_volume, "sfx_volume")
	if OS.get_name() in ["Windows", "Linux", "macOS", "Web"]:
		_setting_row("Fullscreen", "Play in fullscreen (Esc closes menus)", A.fullscreen, "fullscreen")
	var keys := lbl("Shortcuts: Space/F cast · S sell · 1-9 menus · G guide · O settings · Esc close", 13, C_MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_body.add_child(keys)
	var urow := HBoxContainer.new()
	urow.add_theme_constant_override("separation", 12)
	urow.add_child(lbl("Version %s (build %d)%s" % [VERSION, Updater.build, "  ·  update installed" if Updater.patch_loaded else ""], 14))
	var ub := btn("Check for updates", Color("#2f8f9e"), 13, 170)
	ub.pressed.connect(func(): _open_panel("update"); Updater.check())
	urow.add_child(ub)
	panel_body.add_child(urow)
	var info := lbl("fosh&fish %s · made by afosh · your progress saves automatically" % VERSION, 12, C_MUTED)
	panel_body.add_child(info)
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


# ============================================================== onboarding
var _banner_queue: Array = []
var _banner_busy := false

func _banner(title: String, sub: String, tex: Texture2D, color: Color) -> void:
	_banner_queue.append([title, sub, tex, color])
	if not _banner_busy: _next_banner()

func _next_banner() -> void:
	if _banner_queue.is_empty():
		_banner_busy = false
		return
	_banner_busy = true
	var b: Array = _banner_queue.pop_front()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(Color(C_PANEL, 0.97), 18, 3, b[3], 14, 10))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	if b[2]: h.add_child(icon(b[2], 72))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(lbl(b[0], 24, b[3].darkened(0.15)))
	v.add_child(lbl(b[1], 15, C_TEXT))
	h.add_child(v)
	p.add_child(h)
	fx_layer.add_child(p)
	await get_tree().process_frame
	var vw := get_viewport_rect().size.x
	p.position = Vector2((vw - p.size.x) * 0.5, -p.size.y - 10)
	AudioManager.play_success()
	var tw := p.create_tween()
	tw.tween_property(p, "position:y", 112.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	tw.tween_callback(_next_banner)

func _on_goal_done(text: String, reward: String, chest: Dictionary) -> void:
	_banner("Goal complete!", "%s  →  %s" % [text, reward], icon_for("ui", "xp"), Color("#c9861a"))
	stage.burst("confetti", stage.boat.position + stage.boat.pivot_offset)
	if not chest.is_empty():
		_show_catch({"count": 0, "fish": {}, "xp": 0, "chest": chest, "pet": "", "bait_used": "", "new_species": []})
		card_title.text = "🎁 Goal reward!"

# ---- tutorial coach: a bouncing pointer + speech bubble that waits for you
var _coach: Control
var _coach_bubble: PanelContainer
var _coach_label: Label
var _coach_t := 0.0

const COACH_TEXT := {
	0: "Tap the water to cast your line!
(hold it down to keep fishing)",
	1: "Nice catch! Your fish are in the hold.\nTap SELL to turn them into money.",
	2: "Now visit the fish shop to spend it —\ntap the merchant on the island.",
	3: "Better rods catch more and rarer fish.\nSave $500 for the Improved Rod, then come back!",
	4: "Your goals live here — finish them for rewards.\nPress G any time for the full guide. Happy fishing!",
}

func _build_coach() -> void:
	_coach = Control.new()
	_coach.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach.draw.connect(_draw_coach)
	add_child(_coach)
	_coach_bubble = PanelContainer.new()
	_coach_bubble.add_theme_stylebox_override("panel", sbox(Color.WHITE, 18, 3, C_TEAL, 14, 12))
	_coach_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach_label = lbl("", 17)
	_coach_bubble.add_child(_coach_label)
	_coach.add_child(_coach_bubble)
	_coach.visible = false
	if _capturing() and not ("--onboarding" in OS.get_cmdline_user_args()): VF.tutorial = maxi(VF.tutorial, 99)
	_coach_show()

func _coach_next(step: int) -> void:
	VF.tutorial = step
	VF.save_game()
	_coach_show()
	if step == 4:
		get_tree().create_timer(7.0).timeout.connect(func():
			if VF.tutorial == 4: _coach_next(99))

func _coach_show() -> void:
	if _coach == null: return
	_coach.visible = COACH_TEXT.has(VF.tutorial)
	if _coach.visible:
		_coach_label.text = COACH_TEXT[VF.tutorial]
		move_child(_coach, get_child_count() - 1)

func _coach_target() -> Vector2:
	match VF.tutorial:
		0: return stage.bobber_screen()
		1: return sell_btn.get_global_rect().get_center() + Vector2(0, -sell_btn.size.y * 0.5)
		2:
			if stage.merchant: return stage.to_screen(stage.merchant.position + stage.merchant.size * Vector2(0.5, 0.15))
		3: return overlay.get_global_rect().get_center() + Vector2(0, -240)
		4: return goal_box.get_global_rect().get_center() + Vector2(0, goal_box.size.y * 0.5)
	return get_viewport_rect().size * 0.5

func _process_coach(delta: float) -> void:
	if _coach == null or not COACH_TEXT.has(VF.tutorial): return
	_coach.visible = not overlay.visible or VF.tutorial == 3
	if not _coach.visible: return
	_coach_t += delta
	var tgt := _coach_target()
	var vs := get_viewport_rect().size
	var bs := _coach_bubble.size
	var below := VF.tutorial in [2, 4]
	var bp := tgt + (Vector2(-bs.x * 0.5, 46) if below else Vector2(-bs.x * 0.5, -bs.y - 58))
	if VF.tutorial == 3: bp = tgt + Vector2(-bs.x * 0.5, -bs.y * 0.5)
	bp.x = clampf(bp.x, 12, vs.x - bs.x - 12)
	bp.y = clampf(bp.y, 12, vs.y - bs.y - 12)
	_coach_bubble.position = bp
	_coach.queue_redraw()

func _draw_coach() -> void:
	if VF.tutorial == 3: return
	var tgt := _coach_target()
	var bob := sin(_coach_t * 5.0) * 7.0
	var below := VF.tutorial in [2, 4]
	var dir := -1.0 if below else 1.0          # arrow points down at the target unless the bubble is below
	var tip := tgt + Vector2(0, -12 * dir + bob * dir)
	var base := tip + Vector2(0, -34 * dir)
	var pts := PackedVector2Array([tip, base + Vector2(-20, 0), base + Vector2(20, 0)])
	_coach.draw_colored_polygon(PackedVector2Array([tip + Vector2(2, 3), base + Vector2(-18, 3), base + Vector2(22, 3)]), Color(0, 0, 0, 0.25))
	_coach.draw_colored_polygon(pts, Color("#ffcf3f"))
	_coach.draw_polyline(PackedVector2Array([tip, base + Vector2(-20, 0), base + Vector2(20, 0), tip]), Color("#3b2c20"), 3.0, true)
	if VF.tutorial == 0:
		var r := 26.0 + fmod(_coach_t * 30.0, 30.0)
		_coach.draw_arc(tgt, r, 0, TAU, 40, Color(1, 1, 1, 1.0 - (r - 26.0) / 30.0), 3.0, true)

# a well-progressed save for screenshots and the demo video (never saved)
func _veteran(demo: String) -> void:
	VF.owned_rods = []
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
	for f in VFData.FISH_ORDER: VF.discovered[f] = 1      # a veteran: no discovery banners
	VF.goals_done = VFData.STARTER_GOALS.size()
	VF.changed.emit()


# ============================================================ demo video
## godot --path . --write-movie OUT.avi --fixed-fps 30 -- --trailer
## plays a scripted tour with real taps on the water, then quits. Never saves.
var _cap_box: PanelContainer
var _cap_label: Label

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)

func _caption(text: String) -> void:
	if _cap_box == null:
		_cap_box = PanelContainer.new()
		_cap_box.add_theme_stylebox_override("panel", sbox(Color("#3b2c20", 0.88), 22, 0, Color.TRANSPARENT, 26, 12))
		_cap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cap_label = lbl("", 30, Color("#fff4dc"))
		_cap_box.add_child(_cap_label)
		add_child(_cap_box)
	move_child(_cap_box, get_child_count() - 1)
	_cap_label.text = text
	_cap_box.reset_size()
	await get_tree().process_frame
	var vs := get_viewport_rect().size
	_cap_box.position = Vector2((vs.x - _cap_box.size.x) * 0.5, vs.y - 168)
	_cap_box.modulate.a = 0.0
	_cap_box.create_tween().tween_property(_cap_box, "modulate:a", 1.0, 0.25)

func _cast_tap() -> void:
	VF._last_cast_ms = -100000
	_tap(stage.bobber_screen() + Vector2(40, 30))

func _trailer() -> void:
	VF.autosave = false
	AudioManager.music_on = true          # record with sound, without touching saved settings
	AudioManager.sfx_on = true
	AudioManager.apply_settings()
	VF._apply(VF._defaults.duplicate(true))
	VF.tutorial = 99          # captions explain instead of the tutorial pointer
	VF.changed.emit()
	_coach_show()
	await _wait(1.2)
	_caption("Tap the water to fish")
	for i in 3:
		await _wait(0.5)
		_cast_tap()
		await _wait(1.8)
	_caption("Sell your catch")
	await _wait(1.0)
	_do_sell()
	await _wait(2.4)
	_caption("Shop at the fish market on the island")
	await _wait(1.0)
	stage.merchant_clicked.emit()
	await _wait(2.6)
	_close_panel()
	_caption("Better rods and boats bring bigger catches")
	_veteran("Ocean")
	for i in 3:
		await _wait(0.4)
		_cast_tap()
		await _wait(1.6)
	_caption("Explore 7 biomes, from the River to the Abyss")
	for b in ["Volcanic", "Sky", "Abyss"]:
		_veteran(b)
		for i in 2:
			await _wait(0.5)
			_cast_tap()
			await _wait(1.5)
	_veteran("Ocean")
	_caption("Pets, charms, quests & prestige")
	for p in [["pets", ""], ["charms", ""], ["prestige", "Guide"]]:
		_open_panel(p[0], p[1])
		await _wait(1.9)
	_close_panel()
	_caption("Free to play on browser, Windows, Android & Linux")
	for i in 2:
		await _wait(0.5)
		_cast_tap()
		await _wait(1.3)
	await _wait(0.6)
	get_tree().quit()


## godot --path . --write-movie OUT.avi --fixed-fps 30 -- --reel
## clean footage for the edited trailer (tools/video): no captions, and every key
## moment is printed as "MARK frame name bobber_x bobber_y boat_x boat_y".
func _mark(name: String) -> void:
	var b: Vector2 = stage.bobber_screen()
	var o: Vector2 = stage.boat_screen()
	print("MARK %d %s %.0f %.0f %.0f %.0f" % [Engine.get_frames_drawn(), name, b.x, b.y, o.x, o.y])

func _reel() -> void:
	VF.autosave = false
	AudioManager.music_on = true
	AudioManager.sfx_on = true
	AudioManager.apply_settings()
	VF._apply(VF._defaults.duplicate(true))
	VF.tutorial = 99
	VF.changed.emit()
	_coach_show()
	await _wait(1.0)
	_mark("river")
	for i in 3:
		await _wait(0.4)
		_mark("tap")
		_cast_tap()
		await _wait(1.6)
	_mark("sell")
	_do_sell()
	await _wait(2.0)
	_mark("shop")
	stage.merchant_clicked.emit()
	await _wait(2.4)
	_close_panel()
	for b in VFData.BIOME_ORDER:
		_veteran(b)
		await _wait(0.6)
		_mark("biome_" + b)
		for i in 2:
			await _wait(0.3)
			_mark("tap_" + b)
			_cast_tap()
			await _wait(1.5)
	_veteran("Ocean")
	VF.xp = maxi(0, VF.xp_to_next() - 1)
	VF.changed.emit()
	await _wait(0.5)
	_mark("levelup")
	_cast_tap()
	await _wait(2.2)
	for p in [["pets", ""], ["charms", ""], ["prestige", "Guide"], ["shop", "Rods"], ["biomes", ""]]:
		_open_panel(p[0], p[1])
		await _wait(0.3)
		_mark("panel_" + p[0])
		await _wait(1.6)
	_close_panel()
	await _wait(0.5)
	_veteran("Ocean")
	for i in 3:
		await _wait(0.3)
		_mark("hero")
		_cast_tap()
		await _wait(1.7)
	get_tree().quit()


# ================================================================ updates
func _on_update_status() -> void:
	var st: String = Updater.state
	update_pill.visible = st in ["available", "full_needed", "downloading", "ready"]
	match st:
		"downloading": update_pill.text = "⬇  Updating %d%%" % int(Updater.progress * 100.0)
		"ready": update_pill.text = "↻  Restart to update"
		_: update_pill.text = "⬆  Update available"
	if st in ["available", "full_needed"] and not _update_announced:
		_update_announced = true
		_banner("Update available!", "fosh&fish %s is out — tap the Update button" % String(Updater.latest.get("version", "")),
			icon_for("ui", "xp"), Color("#2f8f9e"))
	if overlay.visible and _panel_kind == "update":
		_render_panel()

func _panel_update() -> void:
	var U = Updater
	panel_body.add_child(lbl("You have fosh&fish %s (build %d)%s" % [VERSION, U.build, " with an update installed" if U.patch_loaded else ""], 17))
	var newest: String = String(U.latest.get("version", ""))
	var status := ""
	var action: Button = null
	match U.state:
		"idle", "checking":
			status = "Checking for updates…"
		"up_to_date":
			status = "✓ You're on the newest version."
			action = btn("Check again", C_NEUTRAL, 15, 180)
			action.pressed.connect(U.check)
		"available":
			if U.platform() == "web":
				status = "fosh&fish %s is out! Reload the page to play it." % newest
				action = btn("Reload now", Color("#3fae6a"), 17, 220)
			else:
				var mb := float(U.patch_info().get("size", 0)) / 1048576.0
				status = "fosh&fish %s is ready to download (%.1f MB). Your progress is kept." % [newest, mb]
				action = btn("Update now", Color("#3fae6a"), 17, 220)
			action.pressed.connect(U.download)
		"full_needed":
			status = "fosh&fish %s is a big update and needs a new download (one time). Your progress is kept." % newest
			action = btn("Open downloads", Color("#2f8f9e"), 17, 220)
			action.pressed.connect(U.open_downloads)
		"downloading":
			status = "Downloading the update…"
		"ready":
			status = "Update downloaded and checked. Restart to play %s." % newest
			if U.platform() == "android":
				status += "
Close the game and open it again."
			action = btn("Restart now" if U.platform() == "desktop" else "Close game", Color("#3fae6a"), 17, 220)
			action.pressed.connect(U.restart)
		"error":
			status = U.error
			action = btn("Try again", C_NEUTRAL, 15, 180)
			action.pressed.connect(func():
				U.state = "idle"
				U.check())
	var st := lbl(status, 16, C_BAD if U.state == "error" else C_TEXT)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_body.add_child(st)
	if U.state == "downloading":
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 22)
		bar.value = U.progress * 100.0
		panel_body.add_child(bar)
	if action:
		var row := HBoxContainer.new()
		row.add_child(action)
		panel_body.add_child(row)
	var notes: Array = U.notes()
	if not notes.is_empty() and U.state in ["available", "full_needed", "downloading", "ready"]:
		panel_body.add_child(lbl("What's new", 18))
		for n in notes:
			var l := lbl("•  " + str(n), 15)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			panel_body.add_child(l)


func _update_test_step() -> void:
	match Updater.state:
		"available": Updater.download()
		"ready":
			_update_test_report("downloaded build %d" % int(Updater.latest.build))
			Updater.restart()
		"up_to_date", "full_needed", "error":
			_update_test_report("running %s build %d patched=%s state=%s %s" % [Updater.version, Updater.build, Updater.patch_loaded, Updater.state, Updater.error])
			get_tree().quit()

func _update_test_report(msg: String) -> void:
	var path := "user://update_test.txt"
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	f.seek_end()
	f.store_line(msg)


# =================================================================== menu
const MENU_TILES := [
	["shop", "Shop", "storefront", "1", "Rods, bait, boats & upgrades"],
	["biomes", "Map", "map-trifold", "2", "Travel to other waters"],
	["inventory", "Fish Book", "book-open-text", "Tab", "Your hold & collection"],
	["charms", "Charms", "sparkle", "4", "Permanent boosts"],
	["pets", "Pets", "paw-print", "5", "Companions with buffs"],
	["boosts", "Boosts", "lightning", "6", "Timed boosts & workers"],
	["quests", "Quests", "target", "7", "Daily & league quests"],
	["prestige", "Prestige", "crown", "8", "Start over, stronger"],
	["stats", "Buffs", "chart-bar", "9", "Your multipliers & odds"],
	["guide", "Guide", "question", "G", "How everything works"],
	["settings", "Settings", "gear-six", "O", "Sound, screen, save"],
	["update", "Updates", "arrow-circle-up", "", "Get the newest version"],
	["account", "Account", "user-circle", "", "Cloud save & leaderboard"],
]

const MENU_COLORS := {
	"shop": Color("#1d9bb0"), "biomes": Color("#f08a24"), "inventory": Color("#3b82f6"), "charms": Color("#8b5cf6"),
	"pets": Color("#ec4899"), "boosts": Color("#f5b301"), "quests": Color("#22a06b"), "prestige": Color("#d4920f"),
	"stats": Color("#0ea5e9"), "guide": Color("#64748b"), "settings": Color("#475569"), "update": Color("#14b8a6"),
	"account": Color("#6366f1"),
}

func _panel_menu() -> void:
	var g := _grid(4)
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	for t in MENU_TILES:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = Vector2(196, 104)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", sbox(C_PANEL2, 18, 0, Color.TRANSPARENT, 12))
		b.add_theme_stylebox_override("hover", sbox(Color.WHITE, 18, 2, C_TEAL.lightened(0.3), 12, 8))
		b.add_theme_stylebox_override("pressed", sbox(Color("#dcebef"), 18, 2, C_TEAL, 12))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 14
		v.offset_top = 12
		v.offset_right = -12
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 4)
		var top := HBoxContainer.new()
		var bubble := PanelContainer.new()
		bubble.add_theme_stylebox_override("panel", sbox(MENU_COLORS.get(t[0], C_TEAL), 12, 0, Color.TRANSPARENT, 7))
		var ic := icon(ph(t[2]), 22)
		bubble.add_child(ic)
		top.add_child(bubble)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(sp)
		if t[3] != "": top.add_child(keycap(t[3]))
		v.add_child(top)
		v.add_child(lbl(t[1], 17))
		var sub := lbl(t[4], 12, C_MUTED)
		sub.clip_text = true
		v.add_child(sub)
		b.add_child(v)
		if t[0] == "update" and Updater.state in ["available", "full_needed", "ready"]:
			bubble.add_theme_stylebox_override("panel", sbox(C_GOOD, 12, 0, Color.TRANSPARENT, 7))
			sub.text = "Update available!"
			sub.add_theme_color_override("font_color", C_GOOD)
		if t[0] == "account": sub.text = account_ui.tile_subtitle()
		var kind: String = t[0]
		b.pressed.connect(func(): AudioManager.play_click(); _open_panel(kind))
		g.add_child(b)

# ================================================================== phone
func _open_phone() -> void:
	_toast("FishTok is coming in this update!", "quest")

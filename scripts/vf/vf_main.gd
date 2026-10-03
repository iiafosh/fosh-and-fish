extends Control
## Main screen: Blender-rendered biome + boat, Virtual Fisher style catch
## card, and panels for every system (shop, biomes, charms, pets, boosts,
## quests, prestige, buffs). All art comes from assets/vf (see
## tools/blender/render_assets.py).

const ART := "res://assets/vf/"
const C_BG := Color("#151925")
const C_PANEL := Color("#1e2433")
const C_PANEL2 := Color("#262d40")
const C_TEXT := Color("#eef1f8")
const C_MUTED := Color("#97a0b8")
const C_GOOD := Color("#4ade80")
const C_GOLD := Color("#f5c542")
const C_BAD := Color("#f87171")

var manifest := {}
var _tex_cache := {}

# stage
var stage: Control
var backdrop: TextureRect
var boat_rect: TextureRect
var water: ColorRect
var line: Line2D
var bobber: Control
var fx_layer: Control
var _boat_name := ""
var _bobber_target := Vector2.ZERO
var _casting := false

# hud
var lvl_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var money_label: Label
var exotic_labels := {}
var hooks_label: Label
var prestige_label: Label
var biome_label: Label

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
	get_viewport().size_changed.connect(_layout_stage)
	_refresh()
	_apply_biome()
	_card_intro()
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
	_animate_stage(delta)
	if Engine.get_process_frames() % 30 == 0:
		_refresh_boosts()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		VF.save_game()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_F:
				if overlay.visible: return
				_do_cast()
			KEY_S:
				if not overlay.visible: _do_sell()
			KEY_ESCAPE:
				_close_panel()

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
		"biome": return tex("biomes/%s.png" % VFData.slug(name))
	return null

func sbox(bg: Color, radius := 12, border := 0, border_col := Color.TRANSPARENT, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_col
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s

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

func btn(text: String, color := Color("#3b82f6"), size := 15, min_w := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	b.add_theme_stylebox_override("normal", sbox(color, 10, 0, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("hover", sbox(color.lightened(0.15), 10, 0, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("pressed", sbox(color.darkened(0.2), 10, 0, Color.TRANSPARENT, 8))
	b.add_theme_stylebox_override("disabled", sbox(Color("#3a4152"), 10, 0, Color.TRANSPARENT, 8))
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
	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	backdrop = TextureRect.new()
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(backdrop)
	line = Line2D.new()
	line.width = 2.0
	line.default_color = Color(1, 1, 1, 0.85)
	line.antialiased = true
	boat_rect = TextureRect.new()
	boat_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boat_rect.stretch_mode = TextureRect.STRETCH_SCALE
	stage.add_child(boat_rect)
	stage.add_child(line)
	bobber = Control.new()
	var bob_img := ColorRect.new()
	bob_img.color = Color("#ff4b3e")
	bob_img.size = Vector2(12, 12)
	bob_img.position = Vector2(-6, -6)
	var bob_top := ColorRect.new()
	bob_top.color = Color.WHITE
	bob_top.size = Vector2(12, 5)
	bob_top.position = Vector2(-6, -6)
	bobber.add_child(bob_img)
	bobber.add_child(bob_top)
	stage.add_child(bobber)
	water = ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vf_foreground_water.gdshader")
	water.material = mat
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(water)
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)

func _build_hud() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", sbox(Color(0.08, 0.09, 0.14, 0.82), 14, 0, Color.TRANSPARENT, 8))
	bar.position = Vector2(12, 10)
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	# level badge
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", sbox(Color("#3b82f6"), 10, 0, Color.TRANSPARENT, 6))
	lvl_label = lbl("Lv 1", 17)
	badge.add_child(lvl_label)
	row.add_child(badge)
	var xpbox := VBoxContainer.new()
	xpbox.add_theme_constant_override("separation", 2)
	xp_label = lbl("0 / 100 XP", 12, C_MUTED)
	xp_bar = ProgressBar.new()
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(170, 10)
	xp_bar.add_theme_stylebox_override("background", sbox(Color("#2a3145"), 5, 0, Color.TRANSPARENT, 0))
	xp_bar.add_theme_stylebox_override("fill", sbox(C_GOOD, 5, 0, Color.TRANSPARENT, 0))
	xpbox.add_child(xp_label)
	xpbox.add_child(xp_bar)
	row.add_child(xpbox)
	row.add_child(_hud_stat(icon_for("ui", "money"), "money"))
	for k in ["gold", "emerald", "lava", "diamond", "azure"]:
		row.add_child(_hud_stat(icon_for("exotic", k), k))
	row.add_child(_hud_stat(icon_for("ui", "hooks"), "hooks"))
	prestige_label = lbl("P0", 15, C_GOLD)
	row.add_child(prestige_label)
	biome_label = lbl("River", 15, Color.WHITE)
	var bp := PanelContainer.new()
	bp.add_theme_stylebox_override("panel", sbox(Color(0, 0, 0, 0.35), 8, 0, Color.TRANSPARENT, 5))
	bp.add_child(biome_label)
	row.add_child(bp)

func _hud_stat(t: Texture2D, key: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.add_child(icon(t, 28))
	var l := lbl("0", 15)
	h.add_child(l)
	if key == "money": money_label = l
	elif key == "hooks": hooks_label = l
	else: exotic_labels[key] = l
	h.tooltip_text = VFData.EXOTICS[key].name if VFData.EXOTICS.has(key) else key.capitalize()
	return h

func _build_card() -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", sbox(Color("#2b2d31", 0.95), 8, 0, Color.TRANSPARENT, 0))
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -372
	card.offset_right = -14
	card.offset_top = 70
	add_child(card)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	card.add_child(h)
	card_accent = ColorRect.new()
	card_accent.custom_minimum_size = Vector2(5, 0)
	h.add_child(card_accent)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 12)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	card_title = lbl("", 17)
	v.add_child(card_title)
	card_body = VBoxContainer.new()
	card_body.add_theme_constant_override("separation", 4)
	v.add_child(card_body)
	toast_box = VBoxContainer.new()
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.offset_left = -260
	toast_box.offset_right = 260
	toast_box.offset_top = 70
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)

func _build_dock() -> void:
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", sbox(Color(0.08, 0.09, 0.14, 0.88), 16, 0, Color.TRANSPARENT, 10))
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.anchor_left = 0.5
	dock.anchor_right = 0.5
	dock.offset_top = -160
	dock.offset_bottom = -10
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dock.offset_left = -620
	dock.offset_right = 620
	add_child(dock)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	dock.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	for key in ["rod", "bait", "biome", "pet"]:
		var chip := _chip(key)
		top.add_child(chip)
	boost_label = lbl("", 13, C_MUTED)
	boost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(boost_label)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	v.add_child(bottom)
	# fish button with cooldown fill
	fish_btn = btn("FISH", Color("#16a34a"), 22, 170)
	fish_btn.custom_minimum_size.y = 58
	fish_btn.clip_contents = true
	fish_fill = ColorRect.new()
	fish_fill.color = Color(1, 1, 1, 0.16)
	fish_fill.anchor_bottom = 1.0
	fish_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fish_btn.add_child(fish_fill)
	fish_btn.pressed.connect(_do_cast)
	fish_btn.tooltip_text = "Space / F"
	bottom.add_child(fish_btn)
	sell_btn = btn("SELL $0", Color("#d97706"), 17, 150)
	sell_btn.pressed.connect(_do_sell)
	sell_btn.tooltip_text = "S"
	bottom.add_child(sell_btn)
	var sep := Control.new()
	sep.custom_minimum_size.x = 6
	bottom.add_child(sep)
	for nav in [["inventory", "Fish"], ["shop", "Shop"], ["biomes", "Biomes"], ["charms", "Charms"], ["pets", "Pets"],
			["boosts", "Boosts"], ["quests", "Quests"], ["prestige", "Prestige"], ["stats", "Buffs"]]:
		bottom.add_child(_nav_button(nav[0], nav[1]))

func _chip(key: String) -> Button:
	var b := btn("", Color("#2a3145"), 14)
	b.custom_minimum_size = Vector2(190, 44)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 34)
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
	var b := btn(text, Color("#2a3145"), 12, 0)
	b.icon = icon_for("ui", "charms" if kind == "charms" else kind) if kind != "charms" and kind != "pets" and kind != "inventory" else null
	match kind:
		"charms": b.icon = icon_for("charm", "quality")
		"pets": b.icon = icon_for("pet", "Puffer")
		"inventory": b.icon = icon_for("ui", "inventory")
	b.add_theme_constant_override("icon_max_width", 30)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(86, 58)
	b.pressed.connect(func(): _open_panel(kind))
	return b

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_panel())
	overlay.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbox(C_PANEL, 18, 2, Color("#39415a"), 16))
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
	panel_title = lbl("", 24)
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(panel_title)
	var close := btn("✕", Color("#3a4152"), 16, 40)
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
	backdrop.texture = icon_for("biome", VF.biome)
	var info: Dictionary = manifest.get("biomes", {}).get(VF.biome, {})
	var mat: ShaderMaterial = water.material
	mat.set_shader_parameter("near_col", Color(info.get("water_near", "#1f7f9e")))
	mat.set_shader_parameter("far_col", Color(info.get("water_far", "#7fc6dc")))
	mat.set_shader_parameter("foam_col", Color(info.get("accent", "#e6fbff")).lerp(Color.WHITE, 0.3))
	card_accent.color = accent()
	_layout_stage()

func _layout_stage() -> void:
	if not is_inside_tree(): return
	var sz := get_viewport_rect().size
	var boat: String = VF.current_boat()
	var key := boat if boat != "" else "Rowboat"
	if key != _boat_name:
		_boat_name = key
		boat_rect.texture = tex("boats_hero/%s.png" % VFData.slug(key))
		boat_rect.modulate = Color(1, 1, 1, 1) if boat != "" else Color(1, 1, 1, 1)
	var info: Dictionary = manifest.get("boats", {}).get(key, {"rod_tip": [0.9, 0.1], "waterline": 0.8, "center_x": 0.5})
	var water_y := sz.y * 0.70
	var h := sz.y * 0.42
	var w := h * 1.5
	var cx := sz.x * 0.34
	boat_rect.size = Vector2(w, h)
	boat_rect.position = Vector2(cx - w * float(info.center_x), water_y - h * float(info.waterline))
	boat_rect.pivot_offset = Vector2(w * float(info.center_x), h * float(info.waterline))
	water.position = Vector2(0, water_y - sz.y * 0.035)
	water.size = Vector2(sz.x, sz.y - water_y + sz.y * 0.035)
	(water.material as ShaderMaterial).set_shader_parameter("edge", 0.035 * sz.y / water.size.y * 1.6)
	_bobber_target = Vector2(boat_rect.position.x + w * float(info.rod_tip[0]) + 70, water_y + 14)
	if not _casting:
		bobber.position = _bobber_target

var _t := 0.0
func _animate_stage(delta: float) -> void:
	_t += delta
	var bob := sin(_t * 1.6) * 4.0
	var tilt := sin(_t * 1.1) * 0.012
	var info: Dictionary = manifest.get("boats", {}).get(_boat_name, {"rod_tip": [0.9, 0.1], "waterline": 0.8, "center_x": 0.5})
	boat_rect.rotation = tilt
	var base_y := get_viewport_rect().size.y * 0.70 - boat_rect.size.y * float(info.waterline)
	boat_rect.position.y = base_y + bob
	# rod tip in screen space (respecting the boat's tilt)
	var local := Vector2(boat_rect.size.x * float(info.rod_tip[0]), boat_rect.size.y * float(info.rod_tip[1]))
	var tip := boat_rect.position + boat_rect.pivot_offset + (local - boat_rect.pivot_offset).rotated(tilt)
	if not _casting:
		bobber.position = _bobber_target + Vector2(0, sin(_t * 2.3) * 2.5)
	var mid := (tip + bobber.position) * 0.5 + Vector2(0, 26)
	line.points = PackedVector2Array([tip, tip.lerp(mid, 0.5) + Vector2(0, 6), mid, mid.lerp(bobber.position, 0.5) + Vector2(0, 4), bobber.position])

# ================================================================ actions
func _do_cast() -> void:
	var why: String = VF.can_cast()
	if why == "cooldown":
		return
	if why != "":
		_toast(why, "warn")
		return
	AudioManager.play_cast()
	_casting = true
	var from := bobber.position
	var to := _bobber_target + Vector2(randf_range(-30, 50), randf_range(-4, 10))
	var tw := create_tween()
	tw.tween_method(func(t: float):
		bobber.position = from.lerp(to, t) + Vector2(0, -sin(t * PI) * 90.0), 0.0, 1.0, 0.32)
	tw.tween_callback(func():
		_casting = false
		_bobber_target = to
		_splash(to)
		VF.cast())

func _do_sell() -> void:
	var earned: int = VF.sell_all()
	if earned > 0:
		AudioManager.play_success()
		_float_text("+%s" % money_str(earned), sell_btn.get_global_rect().get_center() + Vector2(0, -40), C_GOLD)

func _splash(at: Vector2) -> void:
	AudioManager.play_splash()
	for i in 8:
		var d := ColorRect.new()
		d.color = Color(1, 1, 1, 0.9)
		d.size = Vector2(5, 5)
		d.position = at
		fx_layer.add_child(d)
		var dir := Vector2(randf_range(-1, 1), randf_range(-1.6, -0.6)).normalized() * randf_range(25, 55)
		var tw := d.create_tween()
		tw.set_parallel(true)
		tw.tween_property(d, "position", at + dir, 0.4).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "modulate:a", 0.0, 0.45)
		tw.chain().tween_callback(d.queue_free)

func _on_trip(res: Dictionary) -> void:
	_show_catch(res)
	var i := 0
	for f in res.fish:
		var ic := icon(icon_for("fish", f), 54)
		ic.position = bobber.position - Vector2(27, 27)
		fx_layer.add_child(ic)
		var target := Vector2(get_viewport_rect().size.x - 300, 140 + i * 30)
		var tw := ic.create_tween()
		tw.tween_interval(i * 0.06)
		tw.tween_property(ic, "position", ic.position + Vector2(randf_range(-20, 20), -70), 0.25).set_ease(Tween.EASE_OUT)
		tw.tween_property(ic, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(ic, "modulate:a", 0.0, 0.45)
		tw.tween_callback(ic.queue_free)
		i += 1
	if not res.chest.is_empty():
		AudioManager.play_strike()
	if res.pet != "":
		AudioManager.play_success()

func _on_level_up(new_level: int, reward: int) -> void:
	AudioManager.play_success()
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
	p.add_child(lbl(text, 15))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)

# ============================================================ catch card
func _clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

func _card_intro() -> void:
	card_title.text = "Welcome, %s!" % VF.player_name
	_clear(card_body)
	for t in ["Press FISH (or Space) to cast.", "Sell your catch, buy rods, boats and upgrades.",
			"Reach level 250 with 440/440 charms and $5B to prestige."]:
		var l := lbl("• " + t, 14, C_MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 320
		card_body.add_child(l)

func _show_catch(res: Dictionary) -> void:
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
		row.add_child(lbl("You found a %s!" % res.pet, 15, Color("#f472b6")))
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
		exotic_labels[k].get_parent().visible = k == "azure" and (VF.prestige > 0 or VF.exotics.azure > 0) \
			or k != "azure" and VF.level >= VFData.EXOTICS[k].level or VF.exotics.get(k, 0) > 0
	hooks_label.text = str(VF.hooks)
	prestige_label.text = "P%d" % VF.prestige
	biome_label.text = VF.biome
	biome_label.add_theme_color_override("font_color", accent().lightened(0.3))
	sell_btn.text = "SELL %s" % money_str(VF.inventory_value())
	var rod_chip: Button = chips.rod
	rod_chip.icon = icon_for("rod", VF.rod)
	rod_chip.text = VF.rod + ("" if VF.rod_usable() else "  ⚠")
	var bait_chip: Button = chips.bait
	if VF.has_bait():
		bait_chip.icon = icon_for("bait", VF.bait)
		bait_chip.text = "%s ×%s" % [VF.bait, VF.fmt(VF.bait_stock[VF.bait])]
	else:
		bait_chip.icon = null
		bait_chip.text = "No bait"
	var biome_chip: Button = chips.biome
	biome_chip.icon = icon_for("ui", "biomes")
	biome_chip.text = "%s  •  %.2fs" % [VF.biome, VF.cooldown()]
	var pet_chip: Button = chips.pet
	if VF.pet != "":
		pet_chip.icon = icon_for("pet", VF.pet)
		pet_chip.text = "%s Lv %d" % [VF.pet, VF.pets[VF.pet].level]
	else:
		pet_chip.icon = null
		pet_chip.text = "No pet yet"
	if backdrop.texture != icon_for("biome", VF.biome) or _boat_name != (VF.current_boat() if VF.current_boat() != "" else "Rowboat"):
		_apply_biome()
	_refresh_boosts()
	if overlay.visible:
		_render_panel()

func _refresh_boosts() -> void:
	var bits := []
	for k in ["fish", "treasure", "worker"]:
		if VF.is_boost_active(k):
			bits.append("%s %s" % [k.capitalize(), _clock(VF.boost_left(k))])
	if Time.get_unix_time_from_system() < VF.personal_until:
		bits.append("Personal %s" % _clock(VF.personal_until - Time.get_unix_time_from_system()))
	boost_label.text = "⚡ " + "   ".join(bits) if bits else "Avg %.1f fish/cast • TC %.1f%%" % [_avg_fish(), VF.treasure_chance() * 100.0]

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
		"boosts": "Boosts", "quests": "Quests & Daily", "prestige": "Prestige", "stats": "Buffs & Odds"}
	panel_title.text = titles.get(_panel_kind, "")
	if PANEL_TABS.has(_panel_kind):
		for t in PANEL_TABS[_panel_kind]:
			var b := btn(t, accent().darkened(0.2) if t == _panel_tab else Color("#2a3145"), 14, 96)
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
	head.add_child(_act("Sell all", Color("#d97706"), func(): _do_sell(); return "", total > 0))
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
					right = _act("Equipped" if VF.rod == r else "Equip", C_GOOD if VF.rod == r else Color("#3b82f6"),
						func(): VF.select_rod(r); return "", VF.rod != r)
				elif r == "Supporter Rod":
					right = lbl("Prestige 5", 14, C_MUTED)
				elif VF.level < d.level:
					right = lbl("Level %d" % d.level, 14, C_MUTED)
				else:
					right = _act("Buy %s" % money_str(d.cost), Color("#16a34a"), func(): return VF.buy_rod(r), VF.money >= d.cost)
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
						var a := _act("+%d  %s" % [amt, money_str(d.cost * amt)], Color("#16a34a"), func(): return VF.buy_bait(b, amt), VF.money >= d.cost * amt)
						a.custom_minimum_size.x = 0
						hb.add_child(a)
					box.add_child(hb)
					var eq := _act("Using" if VF.bait == b else "Use", C_GOOD if VF.bait == b else Color("#3b82f6"),
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
						_act("Buy %s" % money_str(d.cost), Color("#16a34a"), func(): return VF.buy_boat(), VF.money >= d.cost)
				else: right = lbl(money_str(d.cost), 14, C_MUTED)
				_add_to(g, _card(icon_for("boat", b), b, "Tier %d • Level %d" % [i + 1, d.level], right, i > VF.boats_owned, 80))
		"Upgrades":
			var g := _grid(2)
			for id in VFData.UPGRADE_ORDER:
				var d: Dictionary = VFData.UPGRADES[id]
				var c: int = VF.upgrade_cost(id)
				var right: Control = lbl("MAX", 15, C_GOLD) if c < 0 else _act(money_str(c), Color("#16a34a"), func(): return VF.buy_upgrade(id), VF.money >= c)
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
					right = _act("%d %s" % [c, VFData.EXOTICS[d.cur].name.split(" ")[0]], Color("#16a34a"), func(): return VF.buy_special(id), VF.exotics[d.cur] >= c)
				_add_to(g, _card(icon_for("exotic", d.cur), "%s  %d/%d" % [d.name, VF.sp(id), d.max], d.desc, right, VF.level < d.level, 48))
		"League":
			panel_body.add_child(lbl("Hooks come from the daily league quest (+10) and weekly trip milestones (+10 per 500 trips, max 100/week). League upgrades never reset.", 13, C_MUTED))
			var g := _grid(2)
			for id in VFData.LEAGUE_ORDER:
				var d: Dictionary = VFData.LEAGUE[id]
				var c: int = VF.league_cost(id)
				var right: Control = lbl("MAX", 15, C_GOLD) if c < 0 else _act("%d Hooks" % c, Color("#16a34a"), func(): return VF.buy_league(id), VF.hooks >= c)
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
		v.add_child(lbl("%s  •  Level %d" % [b, d.level], 18, d.accent.lightened(0.3)))
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
		else: right = _act("Travel", Color("#3b82f6"), func(): return VF.select_biome(b))
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
		bar.add_theme_stylebox_override("background", sbox(Color("#1a1f2c"), 5, 0, Color.TRANSPARENT, 0))
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
		var right := _act("Equipped" if VF.pet == p else "Equip", C_GOOD if VF.pet == p else Color("#3b82f6"), func(): VF.select_pet(p); return "", VF.pet != p)
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
		var right := _act("%d %s" % [d.cost, VFData.EXOTICS[d.cur].name.split(" ")[0]], Color("#16a34a"), func(): return VF.buy_boost(id),
			VF.level >= 10 and VF.exotics[d.cur] >= d.cost)
		var active := "  (active %s)" % _clock(VF.boost_left(d.kind)) if VF.is_boost_active(d.kind) else ""
		_add_to(g, _card(icon_for("exotic", d.cur), "%s %dm%s" % [d.name, d.secs / 60, active], info[d.kind], right, false, 48))
	var pb := _act("Use (%d)" % VF.personal_boosters, Color("#7c3aed"), func(): return VF.use_personal_booster(), VF.personal_boosters > 0)
	panel_body.add_child(_card(icon_for("ui", "boosts"), "Personal Booster", "+75% fish for 10 minutes. 10% chance from /daily.", pb, false, 48))

func _panel_quests() -> void:
	if _panel_tab == "Daily":
		var ready: float = VF.daily_ready_in()
		var right := _act("Claim" if ready <= 0 else _clock(ready / 60.0) + "h", Color("#16a34a"), func():
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
	bar.add_theme_stylebox_override("background", sbox(Color("#1a1f2c"), 6, 0, Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", sbox(C_GOOD if ok else Color("#3b82f6"), 6, 0, Color.TRANSPARENT, 0))
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
	var reset := _act("Reset save", Color("#7f1d1d"), func():
		VF.reset_save()
		get_tree().reload_current_scene()
		return "")
	panel_body.add_child(reset)

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
	for p in [["shop", "Rods"], ["biomes", ""], ["prestige", "Guide"], ["stats", ""], ["charms", ""]]:
		_open_panel(p[0], p[1])
		await get_tree().create_timer(0.4).timeout
		await _shot(dir + "/panel_%s.png" % p[0])
	get_tree().quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

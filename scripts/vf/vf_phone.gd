extends Control
## The in-game phone (P / the Phone pill). A portrait device slides up over the
## game: status bar with the real time, a tiny home screen (shortcuts into the
## game's panels) and FishTok, a vertical feed of posts: tips, today's trending
## fish (+50% sell price), your own catches, the daily challenge and parody
## "sponsored" posts. Profile = followers, likes, your posts and follower
## rewards. Everything is built in code; state lives in VF (vf_game.gd, FishTok
## section), content in vf_fishtok.gd. Closes with Esc / P, a swipe up on the
## home bar, or a click outside.

const Tok := preload("res://scripts/vf/vf_fishtok.gd")
const Feed := preload("res://scripts/vf/vf_tok_feed.gd")
const FX := "res://assets/third_party/kenney_particles/"

const DEV := Vector2(340, 676)       # device body
const BZ := 10.0                     # bezel
const SCR := Vector2(320, 656)       # screen
const R_DEV := 52
const R_SCR := 43
const STATUS_H := 36.0
const NAV_H := 64.0
const FEED_H := 592.0                # SCR.y - NAV_H

const C_INK := Color("#121a1f")
const C_SUB := Color("#6b7a83")
const C_LINE := Color("#e8edf0")
const C_CARD := Color("#f2f5f7")
const C_TEAL := Color("#1d9bb0")
const C_HEART := Color("#fe2c55")
const C_GOLD := Color("#f5b82e")
const C_GOOD := Color("#22c55e")
const C_CORAL := Color("#ff5e7e")

var main                             # vf_main.gd (UI kit + panels)
var font_light: FontVariation
var font_reg: FontVariation
var font_bold: FontVariation
var font_black: FontVariation

var dim: ColorRect
var hints: VBoxContainer
var device: Control
var screen: Panel
var home: Control
var tok: Control
var pages: Control
var feed_page: Control
var feed                             # the For You feed (vf_tok_feed.gd)
var viewer                           # your posts, opened from the profile grid
var nav: Control
var nav_items := {}
var status: Control
var homebar: Control
var notif_layer: Control
var sheet_layer: Control
var home_badge: Label

var app := "tok"                     # "home" | "tok"
var page := "feed"                   # feed | discover | inbox | profile | viewer
var _status_dark := false
var _nav_dark := true
var _feed_key := ""
var _salt := 0
var _closing := false
var _tw: Tween
var _notif_queue: Array = []
var _notif_busy := false
var _home_drag := false
var _home_y := 0.0
var _rest_y := 0.0
var _tick := 0.0
var _following := {}
var _island_sb: StyleBoxFlat
var _batt_sb: StyleBoxFlat
var _prof_followers: Label
var _prof_likes: Label
var _prof_rewards: VBoxContainer
var _prof_sig := ""

# ==================================================================== setup
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_fonts()
	_build()
	VF.changed.connect(_on_vf_changed)
	get_viewport().size_changed.connect(_layout)

func _fonts() -> void:
	var base: Font = load("res://assets/third_party/fonts/Fredoka.ttf")
	var mk := func(w: int) -> FontVariation:
		var f := FontVariation.new()
		f.base_font = base
		f.variation_opentype = {"wght": w}
		return f
	font_light = mk.call(400)
	font_reg = mk.call(500)
	font_bold = mk.call(600)
	font_black = mk.call(700)

func _build() -> void:
	dim = ColorRect.new()
	dim.color = Color(0.01, 0.05, 0.07, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: close())
	add_child(dim)
	_build_hints()
	device = Control.new()
	device.size = DEV
	device.pivot_offset = DEV * 0.5
	device.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(device)
	# side buttons peek out behind the body
	for b in [[-3.0, 112.0, 30.0], [-3.0, 160.0, 52.0], [-3.0, 222.0, 52.0], [DEV.x - 1.0, 184.0, 82.0]]:
		var sb := Panel.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color("#2b363c")
		s.set_corner_radius_all(2)
		sb.add_theme_stylebox_override("panel", s)
		sb.position = Vector2(b[0], b[1])
		sb.size = Vector2(4, b[2])
		sb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		device.add_child(sb)
	var body := Panel.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("#0c1215")
	bsb.set_corner_radius_all(R_DEV)
	bsb.corner_detail = 20
	bsb.set_border_width_all(2)
	bsb.border_color = Color("#4a5a62")
	bsb.shadow_color = Color(0, 0, 0, 0.5)
	bsb.shadow_size = 36
	bsb.shadow_offset = Vector2(0, 18)
	bsb.anti_aliasing = true
	body.add_theme_stylebox_override("panel", bsb)
	body.size = DEV
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	device.add_child(body)
	screen = Panel.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color.BLACK
	ssb.set_corner_radius_all(R_SCR)
	ssb.corner_detail = 20
	ssb.anti_aliasing = true
	screen.add_theme_stylebox_override("panel", ssb)
	screen.position = Vector2(BZ, BZ)
	screen.size = SCR
	screen.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	device.add_child(screen)
	_island_sb = StyleBoxFlat.new()
	_island_sb.bg_color = Color.BLACK
	_island_sb.set_corner_radius_all(14)
	_island_sb.anti_aliasing = true
	_batt_sb = StyleBoxFlat.new()
	_batt_sb.draw_center = false
	_batt_sb.set_border_width_all(1)
	_batt_sb.set_corner_radius_all(4)
	_batt_sb.anti_aliasing = true
	_build_home()
	_build_tok()
	status = _ctl(screen, Vector2.ZERO, Vector2(SCR.x, STATUS_H))
	status.draw.connect(_draw_status)
	notif_layer = _ctl(screen, Vector2.ZERO, SCR)
	sheet_layer = _ctl(screen, Vector2.ZERO, SCR)
	sheet_layer.visible = false
	homebar = _ctl(screen, Vector2(SCR.x * 0.5 - 80, SCR.y - 24), Vector2(160, 24))
	homebar.mouse_filter = Control.MOUSE_FILTER_STOP
	homebar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	homebar.tooltip_text = "Tap: home screen  ·  Swipe up: put the phone away"
	homebar.draw.connect(_draw_homebar)
	homebar.gui_input.connect(_homebar_input)
	_show_app("tok", false)
	_layout()

func _ctl(parent: Node, pos: Vector2, sz: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

func _build_hints() -> void:
	hints = VBoxContainer.new()
	hints.add_theme_constant_override("separation", 10)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints.visible = not main.is_touch()
	for h in [["Wheel / ↑ ↓", "next post"], ["Double-click", "like"], ["Space", "pause"], ["C", "comments"],
			["H", "home screen"], ["Esc", "put the phone away"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(main.keycap(h[0]))
		row.add_child(lbl(h[1], 13, Color(1, 1, 1, 0.78), "bold"))
		hints.add_child(row)
	add_child(hints)

func _layout() -> void:
	var vp := get_viewport_rect().size
	var s := minf(1.0, (vp.y - 24.0) / DEV.y)
	device.scale = Vector2(s, s)
	device.position = Vector2((vp.x - DEV.x) * 0.5, (vp.y - DEV.y) * 0.5)
	_rest_y = device.position.y
	hints.reset_size()
	hints.position = Vector2(vp.x * 0.5 + DEV.x * s * 0.5 + 34, vp.y * 0.5 - hints.size.y * 0.5)
	hints.visible = not main.is_touch() and hints.position.x + hints.size.x < vp.x - 10

# ============================================================ open / close
func open() -> void:
	if visible and not _closing: return
	_closing = false
	visible = true
	_layout()
	_show_app("tok", false)
	_ensure_feed()
	if page in ["discover", "inbox", "profile"]: show_page(page)
	VF.tok_mark_seen()
	_refresh_badges()
	if _tw: _tw.kill()
	device.position.y = get_viewport_rect().size.y + 30
	device.rotation = 0.04
	dim.modulate.a = 0.0
	hints.modulate.a = 0.0
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(dim, "modulate:a", 1.0, 0.25)
	_tw.tween_property(device, "position:y", _rest_y, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tw.tween_property(device, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tw.tween_property(hints, "modulate:a", 1.0, 0.3).set_delay(0.25)
	AudioManager.play_click()

func close(animated := true) -> void:
	if not visible or _closing: return
	_set_feeds_live(false)
	_close_sheet()
	if _tw: _tw.kill()
	if not animated:
		visible = false
		_after_close()
		return
	_closing = true
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(dim, "modulate:a", 0.0, 0.25)
	_tw.tween_property(hints, "modulate:a", 0.0, 0.15)
	_tw.tween_property(device, "position:y", get_viewport_rect().size.y + 30, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_property(device, "rotation", -0.03, 0.32)
	_tw.chain().tween_callback(func():
		visible = false
		_closing = false
		_after_close())

func _after_close() -> void:
	main.pill_badge(main.phone_btn, VF.tok_badge())

## open a game panel from the phone (shortcut apps, ads)
func open_panel(kind: String, tab := "") -> void:
	close(false)
	main._open_panel(kind, tab)

func _input(e: InputEvent) -> void:
	if not visible or _closing: return
	if not (e is InputEventKey): return
	var k := e as InputEventKey
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit and k.keycode != KEY_ESCAPE: return      # typing a comment
	if k.pressed and not k.echo:
		match k.keycode:
			KEY_ESCAPE:
				if sheet_layer.visible: _close_sheet()
				else: close()
			KEY_P: close()
			KEY_UP, KEY_W, KEY_PAGEUP:
				if _active_feed(): _active_feed().prev()
			KEY_DOWN, KEY_S, KEY_PAGEDOWN:
				if _active_feed(): _active_feed().next()
			KEY_SPACE:
				if _active_feed() and _active_feed().current(): _active_feed().current().toggle_pause()
			KEY_L, KEY_ENTER:
				if _active_feed() and _active_feed().current():
					var cur = _active_feed().current()
					cur.set_liked(not cur.liked)
			KEY_C:
				if _active_feed() and _active_feed().current(): open_comments(_active_feed().current().item)
			KEY_H: go_home()
			KEY_BACKSPACE:
				if page == "viewer": show_page("profile")
				elif app == "tok" and page != "feed": show_page("feed")
				else: go_home()
	get_viewport().set_input_as_handled()

func _active_feed():
	if app != "tok": return null
	if page == "feed": return feed
	if page == "viewer": return viewer
	return null

func _set_feeds_live(on: bool) -> void:
	if feed: feed.set_live(on and app == "tok" and page == "feed")
	if viewer and is_instance_valid(viewer): viewer.set_live(on and app == "tok" and page == "viewer")

func _process(delta: float) -> void:
	if not visible: return
	_tick += delta
	if _tick < 0.5: return
	_tick = 0.0
	status.queue_redraw()
	_refresh_badges()
	if page == "profile" and app == "tok": _profile_live()

# ============================================================== UI helpers
func ph(name: String) -> Texture2D:
	return main.ph(name)

func item_tex(ic: Array) -> Texture2D:
	if ic.size() < 2: return null
	if ic[0] == "ph": return ph(ic[1])
	return main.icon_for(ic[0], ic[1])

func biome_tex(b: String) -> Texture2D:
	return main.icon_for("biome", b)

func boat_top(b: String) -> Texture2D:
	return main.tex("boats_top/%s.png" % VFData.slug(b))

func swim_entry(f: String) -> Dictionary:
	var swim: Dictionary = main.manifest.get("swim", {})
	if f in swim.get("species", []):
		var t: Texture2D = main.tex("swim/%s.png" % VFData.slug(f))
		if t: return {"tex": t, "frames": int(swim.frames), "cell": float(swim.cell)}
	return {"tex": main.tex("fish_top/%s.png" % VFData.slug(f)), "frames": 1, "cell": 160.0}

func tier_color(t: String) -> Color:
	return {"common": Color("#94a3b8"), "uncommon": Color("#22c55e"), "rare": Color("#3b82f6"), "epic": Color("#a855f7"),
		"legendary": Color("#f59e0b"), "artifact": Color("#ef4444"), "super": Color("#06b6d4")}.get(t, C_TEAL)

func lbl(text: String, sz := 14, col := C_INK, weight := "reg") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", {"light": font_light, "reg": font_reg, "bold": font_bold, "black": font_black}.get(weight, font_reg))
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## soft drop shadow so white text reads on any scene
func shadow(l: Control, a := 0.4) -> void:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, a))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 3)

func rich(bb: String, sz := 14, col := Color.WHITE) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_font_override("normal_font", font_reg)
	r.add_theme_font_override("bold_font", font_black)
	r.add_theme_font_size_override("normal_font_size", sz)
	r.add_theme_font_size_override("bold_font_size", sz)
	r.add_theme_color_override("default_color", col)
	r.add_theme_constant_override("line_separation", 1)
	shadow(r, 0.45)
	r.text = bb
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func chip(text: String, bg: Color, fg: Color, icon_name := "", sz := 12) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(999)
	sb.content_margin_left = 10
	sb.content_margin_right = 11
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_name != "":
		var ic := TextureRect.new()
		ic.texture = ph(icon_name)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.custom_minimum_size = Vector2(sz + 2, sz + 2)
		ic.modulate = fg
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
	h.add_child(lbl(text, sz, fg, "black"))
	p.add_child(h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func pill(text: String, bg: Color, fg: Color, h := 38, min_w := 0, radius := 10) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(min_w, h)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.add_theme_font_override("font", font_black)
	b.add_theme_font_size_override("font_size", 14)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.75))
	var mk := func(c: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.set_corner_radius_all(radius)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.anti_aliasing = true
		return s
	b.add_theme_stylebox_override("normal", mk.call(bg))
	b.add_theme_stylebox_override("hover", mk.call(bg.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", mk.call(bg.darkened(0.12)))
	b.add_theme_stylebox_override("disabled", mk.call(Color(bg, bg.a * 0.55)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): AudioManager.play_click())
	return b

func avatar(who: Dictionary, d: float, ring := Color.WHITE) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(d, d)
	c.size = Vector2(d, d)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = who.get("color", C_TEAL)
	var ic: Array = who.get("icon", ["ph", "user-circle"])
	c.draw.connect(func():
		var ctr := Vector2(d, d) * 0.5
		c.draw_circle(ctr, d * 0.5, ring)
		c.draw_circle(ctr, d * 0.5 - maxf(1.5, d * 0.045), col)
		c.draw_circle(ctr + Vector2(-d * 0.12, -d * 0.14), d * 0.26, Color(1, 1, 1, 0.12))
		var tex := item_tex(ic)
		if tex:
			var px := d * (0.52 if ic[0] == "ph" else 0.78)
			var s := px / maxf(1.0, tex.get_width())
			c.draw_set_transform(ctr, -0.12 if ic[0] == "fish" else 0.0, Vector2(s, s))
			c.draw_texture(tex, -tex.get_size() * 0.5)
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	return c

func verified_badge(d := 15.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(d, d)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var ctr := Vector2(d, d) * 0.5
		c.draw_circle(ctr, d * 0.5, Color("#20d5ec"))
		c.draw_polyline(PackedVector2Array([ctr + Vector2(-d * 0.24, 0), ctr + Vector2(-d * 0.06, d * 0.2), ctr + Vector2(d * 0.26, -d * 0.18)]),
			Color.WHITE, maxf(1.6, d * 0.13), true))
	return c

func icon_rect(name: String, d: float, col := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = ph(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(d, d)
	t.modulate = col
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func on_click(c: Control, cb: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS          # wheel events still reach scroll views
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.play_click()
			cb.call()
			c.accept_event())

# -------------------------------------------------------------- drawing kit
func grad(ci: CanvasItem, r: Rect2, a: Color, b: Color, diag := false) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var m := a.lerp(b, 0.5)
	var cols := PackedColorArray([a, m, b, m]) if diag else PackedColorArray([a, a, b, b])
	ci.draw_polygon(pts, cols)

func glow(ci: CanvasItem, c: Vector2, r: float, col: Color, steps := 14) -> void:
	for i in steps:
		var k := 1.0 - float(i) / steps
		ci.draw_circle(c, r * k * k, Color(col.r, col.g, col.b, col.a / steps * 1.6))

func rays(ci: CanvasItem, c: Vector2, length: float, n: int, a0: float, col: Color) -> void:
	var w := PI / n * 0.42
	for i in n:
		var a := a0 + TAU * i / n
		ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - w) * length, c + Vector2.from_angle(a + w) * length]), col)

func rrect_points(r: Rect2, rad: float, seg := 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs := [[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
		[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5]]
	for c in cs:
		for i in seg + 1:
			pts.append(c[0] + Vector2.from_angle(float(c[1]) + PI * 0.5 * i / seg) * rad)
	return pts

## rounded rect with a vertical gradient (app icons, cards)
func rrect_grad(ci: CanvasItem, r: Rect2, rad: float, a: Color, b: Color) -> void:
	var pts := rrect_points(r, rad)
	var cols := PackedColorArray()
	for p in pts: cols.append(a.lerp(b, (p.y - r.position.y) / r.size.y))
	ci.draw_polygon(pts, cols)
	var ring := pts.duplicate()
	ring.append(pts[0])
	var rc := cols.duplicate()
	rc.append(cols[0])
	ci.draw_polyline_colors(ring, rc, 1.0, true)

func particles(kind: String, rect: Rect2, parent: Control) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect.size * 0.5
	p.position = rect.get_center()
	p.spread = 180.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 1))
	g.add_point(0.7, Color(1, 1, 1, 0.8))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = g
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	match kind:
		"sparkle":
			p.texture = load(FX + "star_06.png")
			p.amount = 16
			p.lifetime = 2.4
			p.color = Color(1, 0.93, 0.65)
			p.scale_amount_min = 0.025
			p.scale_amount_max = 0.07
			p.gravity = Vector2(0, -14)
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 18.0
			p.angular_velocity_min = -90.0
			p.angular_velocity_max = 90.0
			p.material = add
		"bubbles":
			p.texture = load(FX + "circle_05.png")
			p.amount = 14
			p.lifetime = 5.0
			p.color = Color(1, 1, 1, 0.4)
			p.scale_amount_min = 0.014
			p.scale_amount_max = 0.035
			p.gravity = Vector2(0, -24)
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 14.0
		"flames":
			p.texture = load(FX + "flame_03.png")
			p.amount = 26
			p.lifetime = 1.8
			p.color = Color(1, 0.5, 0.18, 0.55)
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.26
			p.gravity = Vector2(0, -80)
			p.initial_velocity_min = 5.0
			p.initial_velocity_max = 25.0
			p.material = add
		"confetti":
			p.texture = load(FX + "star_04.png")
			p.amount = 36
			p.lifetime = 4.5
			p.scale_amount_min = 0.03
			p.scale_amount_max = 0.06
			p.gravity = Vector2(0, 60)
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 40.0
			p.angular_velocity_min = -200.0
			p.angular_velocity_max = 200.0
			var rb := Gradient.new()
			rb.set_color(0, Color("#ff5a5a"))
			rb.add_point(0.33, Color("#ffd23f"))
			rb.add_point(0.66, Color("#4fd1ff"))
			rb.set_color(rb.get_point_count() - 1, Color("#7dff9a"))
			p.color_initial_ramp = rb
	p.preprocess = p.lifetime
	p.emitting = false
	parent.add_child(p)
	return p

func until_midnight() -> String:
	var s := 86400 - int(Time.get_unix_time_from_system()) % 86400
	return "%dh %02dm" % [s / 3600, (s % 3600) / 60]

func _battery() -> int:
	return clampi(91 - int(Time.get_ticks_msec() / 1000.0 / 60.0 / 3.0), 9, 100)

# ============================================================ status / bar
func _draw_status() -> void:
	var col := C_INK if (_status_dark and app == "tok") else Color.WHITE
	var t := Time.get_time_dict_from_system()
	status.draw_string(font_black, Vector2(32, 25), "%d:%02d" % [t.hour, t.minute], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
	status.draw_style_box(_island_sb, Rect2(SCR.x * 0.5 - 50, 10, 100, 28))
	status.draw_circle(Vector2(SCR.x * 0.5 + 34, 24), 4.5, Color("#101820"))
	var x := SCR.x - 96.0
	for i in 4:
		var h := 4.0 + i * 2.3
		status.draw_rect(Rect2(x + i * 4.4, 25.0 - h, 3.0, h), col)
	var wc := Vector2(SCR.x - 66, 25)
	for i in 3:
		status.draw_arc(wc, 3.2 + i * 3.3, -PI * 0.76, -PI * 0.24, 12, col, 1.8, true)
	status.draw_circle(wc + Vector2(0, -0.6), 1.5, col)
	var pct := _battery()
	var bx := SCR.x - 54.0
	_batt_sb.border_color = Color(col, 0.45)
	status.draw_style_box(_batt_sb, Rect2(bx, 15, 25, 12))
	status.draw_rect(Rect2(bx + 2, 17, 21.0 * pct / 100.0, 8), C_HEART if pct < 20 else col)
	status.draw_rect(Rect2(bx + 26, 19, 1.6, 4), Color(col, 0.45))

func _draw_homebar() -> void:
	var dark := app == "tok" and not _nav_dark
	homebar.draw_style_box(_pill_sb(Color(C_INK, 0.9) if dark else Color(1, 1, 1, 0.92)), Rect2(homebar.size.x * 0.5 - 62, 14, 124, 5))

var _pill_cache := {}
func _pill_sb(c: Color) -> StyleBoxFlat:
	if not _pill_cache.has(c):
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.set_corner_radius_all(3)
		s.anti_aliasing = true
		_pill_cache[c] = s
	return _pill_cache[c]

func _homebar_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_home_drag = true
			_home_y = e.global_position.y
		elif _home_drag:
			_home_drag = false
			var dy: float = e.global_position.y - _home_y
			if dy < -40.0: close()
			else:
				if absf(dy) < 8.0: go_home()
				create_tween().tween_property(device, "position:y", _rest_y, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		homebar.accept_event()
	elif e is InputEventMouseMotion and _home_drag:
		var dy: float = e.global_position.y - _home_y
		device.position.y = _rest_y + minf(0.0, dy) * 0.45
		homebar.accept_event()

# ================================================================ home app
const HOME_APPS := [
	["quests", "Quests", "target", "#fbbf24", "#d97706"],
	["pets", "Pets", "paw-print", "#c084fc", "#7c3aed"],
	["boosts", "Boosts", "lightning", "#fde047", "#ca8a04"],
	["charms", "Charms", "sparkle", "#f9a8d4", "#db2777"],
	["prestige", "Prestige", "crown", "#93c5fd", "#1d4ed8"],
	["stats", "Buffs", "chart-bar", "#5eead4", "#0f766e"],
	["guide", "Guide", "question", "#cbd5e1", "#64748b"],
	["settings", "Settings", "gear-six", "#d1d5db", "#4b5563"],
]
const DOCK_APPS := [
	["fishtok", "FishTok", "fish", "#16323a", "#0b161a"],
	["biomes", "Map", "map-trifold", "#4ade80", "#15803d"],
	["shop", "Shop", "storefront", "#fb7185", "#e11d48"],
	["inventory", "Fish Book", "book-open-text", "#38bdf8", "#0369a1"],
]

func _build_home() -> void:
	home = _ctl(screen, Vector2.ZERO, SCR)
	var wall := _ctl(home, Vector2.ZERO, SCR)
	wall.draw.connect(func():
		var t := biome_tex(VF.biome)
		if t:
			var th := float(t.get_height())
			var cw := th * SCR.x / SCR.y
			wall.draw_texture_rect_region(t, Rect2(Vector2.ZERO, SCR), Rect2(float(t.get_width()) * 0.62 - cw * 0.5, 0, cw, th))
		grad(wall, Rect2(Vector2.ZERO, SCR), Color(0.02, 0.06, 0.1, 0.35), Color(0.02, 0.06, 0.1, 0.55)))
	var date := lbl("", 15, Color(1, 1, 1, 0.9), "bold")
	date.name = "Date"
	shadow(date, 0.3)
	home.add_child(date)
	var clock := lbl("", 70, Color.WHITE, "reg")
	clock.name = "Clock"
	shadow(clock, 0.25)
	home.add_child(clock)
	# glanceable widget: today's trend + challenge
	var w := PanelContainer.new()
	w.name = "Widget"
	w.add_theme_stylebox_override("panel", _glass(22, 12))
	w.position = Vector2(18, 178)
	w.custom_minimum_size = Vector2(SCR.x - 36, 0)
	home.add_child(w)
	on_click(w, func(): _open_tok_from_home())
	# app grid
	var cell := (SCR.x - 28.0) / 4.0
	for i in HOME_APPS.size():
		var a: Array = HOME_APPS[i]
		var ic := _app_icon(a, cell)
		ic.position = Vector2(14 + (i % 4) * cell, 314 + int(i / 4) * 92)
		home.add_child(ic)
	var dock := Panel.new()
	dock.add_theme_stylebox_override("panel", _glass(30, 0))
	dock.position = Vector2(12, SCR.y - 30 - 88)
	dock.size = Vector2(SCR.x - 24, 88)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	home.add_child(dock)
	for i in DOCK_APPS.size():
		var ic := _app_icon(DOCK_APPS[i], cell, false)
		ic.position = Vector2(14 + i * cell, SCR.y - 30 - 88 + 13)
		home.add_child(ic)
	var dots := _ctl(home, Vector2(SCR.x * 0.5 - 20, SCR.y - 134), Vector2(40, 8))
	dots.draw.connect(func():
		dots.draw_circle(Vector2(14, 4), 3.2, Color.WHITE)
		dots.draw_circle(Vector2(26, 4), 3.2, Color(1, 1, 1, 0.45)))

func _glass(radius: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.2)
	s.set_corner_radius_all(radius)
	s.set_border_width_all(1)
	s.border_color = Color(1, 1, 1, 0.28)
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	return s

func _refresh_home() -> void:
	var t := Time.get_time_dict_from_system()
	var d := Time.get_date_dict_from_system()
	var days := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	var date: Label = home.get_node("Date")
	date.text = "%s, %s %d" % [days[int(d.weekday)], months[int(d.month) - 1], int(d.day)]
	date.reset_size()
	date.position = Vector2((SCR.x - date.size.x) * 0.5, 54)
	var clock: Label = home.get_node("Clock")
	clock.text = "%d:%02d" % [t.hour, t.minute]
	clock.reset_size()
	clock.position = Vector2((SCR.x - clock.size.x) * 0.5, 70)
	var w: PanelContainer = home.get_node("Widget")
	for c in w.get_children(): c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 10)
	r1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f: String = VF.trending_fish()
	var fi := TextureRect.new()
	fi.texture = item_tex(["fish", f])
	fi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fi.custom_minimum_size = Vector2(46, 46)
	fi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r1.add_child(fi)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -2)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(chip("TRENDING ON FISHTOK", Color(1, 0.45, 0.2, 0.9), Color.WHITE, "fire", 10))
	var fl := lbl("%s  +50%%" % f, 18, Color.WHITE, "black")
	shadow(fl, 0.25)
	tv.add_child(fl)
	r1.add_child(tv)
	v.add_child(r1)
	var c: Dictionary = VF.tok_challenge()
	var cl := lbl("%s  ·  %s / %s" % [VF.tok_challenge_text(c), VF.commas(mini(VF.tok_ch_prog, int(c.goal))), VF.commas(int(c.goal))], 13, Color(1, 1, 1, 0.92), "bold")
	shadow(cl, 0.25)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	r2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r2.add_child(icon_rect("target", 15, Color.WHITE))
	r2.add_child(cl)
	v.add_child(r2)
	w.add_child(v)

func _app_icon(a: Array, cell: float, label := true) -> Control:
	var id: String = a[0]
	var box := Control.new()
	box.size = Vector2(cell, 84)
	var sq := Control.new()
	sq.size = Vector2(58, 58)
	sq.position = Vector2((cell - 58) * 0.5, 0)
	sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sq.draw.connect(func(): _draw_app(sq, a))
	box.add_child(sq)
	if label:
		var l := lbl(a[1], 11, Color.WHITE, "bold")
		shadow(l, 0.45)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(0, 62)
		l.size = Vector2(cell, 16)
		box.add_child(l)
	if id == "fishtok":
		var bd := PanelContainer.new()
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color("#ff3b30")
		bsb.set_corner_radius_all(999)
		bsb.content_margin_left = 6
		bsb.content_margin_right = 6
		bd.add_theme_stylebox_override("panel", bsb)
		home_badge = lbl("", 12, Color.WHITE, "black")
		bd.add_child(home_badge)
		bd.position = Vector2(sq.position.x + 46, -6)
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bd)
	on_click(box, func(): _launch(id))
	return box

func _draw_app(sq: Control, a: Array) -> void:
	var r := Rect2(Vector2.ZERO, sq.size)
	rrect_grad(sq, r, 15.0, Color(a[3]), Color(a[4]))
	var t := ph(a[2])
	if t == null: return
	var px := 30.0
	if a[0] == "fishtok":
		# our own mark: a fish riding a sound wave
		for i in 3:
			sq.draw_arc(Vector2(29, 29), 15.0 + i * 5.0, PI * 0.15, PI * 0.85, 16, Color(C_CORAL, 0.55 - i * 0.15), 2.0, true)
		var s := 30.0 / t.get_width()
		sq.draw_set_transform(Vector2(29, 26), -0.2, Vector2(s, s))
		sq.draw_texture(t, -t.get_size() * 0.5, Color.WHITE)
		sq.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var n := ph("music-notes")
		var s2 := 15.0 / n.get_width()
		sq.draw_set_transform(Vector2(43, 14), 0.0, Vector2(s2, s2))
		sq.draw_texture(n, -n.get_size() * 0.5, Color("#5eead4"))
		sq.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var sc := px / t.get_width()
	sq.draw_set_transform(r.get_center(), 0.0, Vector2(sc, sc))
	sq.draw_texture(t, -t.get_size() * 0.5, Color.WHITE)
	sq.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _launch(id: String) -> void:
	if id == "fishtok":
		_open_tok_from_home()
		return
	var tab := ""
	if id == "quests": tab = "Quests"
	open_panel(id, tab)

func go_home() -> void:
	if app == "home": return
	_show_app("home", true)

func _open_tok_from_home() -> void:
	_show_app("tok", true)
	VF.tok_mark_seen()

func _show_app(which: String, animate: bool) -> void:
	app = which
	home.visible = which == "home"
	tok.visible = which == "tok"
	if which == "home": _refresh_home()
	_set_feeds_live(visible and not _closing)
	if animate:
		var n: Control = tok if which == "tok" else home
		n.pivot_offset = SCR * 0.5
		n.scale = Vector2(0.86, 0.86) if which == "tok" else Vector2(1.08, 1.08)
		n.modulate.a = 0.0
		var tw := n.create_tween().set_parallel(true)
		tw.tween_property(n, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "modulate:a", 1.0, 0.18)
	status.queue_redraw()
	homebar.queue_redraw()
	_refresh_badges()

# ============================================================ FishTok shell
func _build_tok() -> void:
	tok = _ctl(screen, Vector2.ZERO, SCR)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.size = SCR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tok.add_child(bg)
	pages = _ctl(tok, Vector2.ZERO, Vector2(SCR.x, FEED_H))
	pages.clip_contents = true
	feed_page = _ctl(pages, Vector2.ZERO, Vector2(SCR.x, FEED_H))
	nav = _ctl(tok, Vector2(0, FEED_H), Vector2(SCR.x, NAV_H))
	nav.draw.connect(_draw_nav_bg)
	var w := SCR.x / 5.0
	var defs := [["feed", "Home", "house"], ["discover", "Discover", "magnifying-glass"], ["post", "", "plus"],
		["inbox", "Inbox", "chat-circle"], ["profile", "Profile", "user-circle"]]
	for i in defs.size():
		var d: Array = defs[i]
		var it := _ctl(nav, Vector2(i * w, 0), Vector2(w, 46))
		it.set_meta("def", d)
		it.draw.connect(_draw_nav_item.bind(it))
		var key: String = d[0]
		on_click(it, func(): _nav_tap(key))
		nav_items[key] = it

func _draw_nav_bg() -> void:
	nav.draw_rect(Rect2(Vector2.ZERO, nav.size), Color.BLACK if _nav_dark else Color.WHITE)
	if not _nav_dark: nav.draw_rect(Rect2(0, 0, nav.size.x, 1), C_LINE)

func _draw_nav_item(it: Control) -> void:
	var d: Array = it.get_meta("def")
	var key: String = d[0]
	var fg := Color.WHITE if _nav_dark else C_INK
	var on := key == page or (key == "profile" and page == "viewer")
	var col := fg if on else Color(fg, 0.55)
	var c := Vector2(it.size.x * 0.5, 17)
	match d[2]:
		"house":
			var s := 10.5
			var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, -1.5), c + Vector2(s * 0.78, -1.5), c + Vector2(s * 0.78, s * 0.85),
				c + Vector2(s * 0.24, s * 0.85), c + Vector2(s * 0.24, s * 0.25), c + Vector2(-s * 0.24, s * 0.25), c + Vector2(-s * 0.24, s * 0.85),
				c + Vector2(-s * 0.78, s * 0.85), c + Vector2(-s * 0.78, -1.5), c + Vector2(-s, -1.5)])
			if on: it.draw_colored_polygon(pts, col)
			var ring := pts.duplicate()
			ring.append(pts[0])
			it.draw_polyline(ring, col, 1.8, true)
		"plus":
			var r := Rect2(c - Vector2(21, 14), Vector2(42, 28))
			it.draw_style_box(_pill_sb_r(C_TEAL, 10), r)
			var pc := Color.WHITE
			it.draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), pc, 3.0, true)
			it.draw_line(c + Vector2(0, -7), c + Vector2(0, 7), pc, 3.0, true)
		_:
			var t := ph(d[2])
			if t:
				var s := 23.0 / t.get_width()
				it.draw_set_transform(c, 0.0, Vector2(s, s))
				it.draw_texture(t, -t.get_size() * 0.5, col)
				it.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if d[1] != "":
		it.draw_string(font_black if on else font_bold, Vector2(0, 42), d[1], HORIZONTAL_ALIGNMENT_CENTER, it.size.x, 10, col)
	var n := int(it.get_meta("badge", 0))
	if n > 0:
		var bc := c + Vector2(13, -9)
		it.draw_circle(bc, 8.0, C_HEART)
		it.draw_string(font_black, bc + Vector2(-8, 4), str(mini(n, 9)), HORIZONTAL_ALIGNMENT_CENTER, 16, 11, Color.WHITE)

var _sb_r := {}
func _pill_sb_r(c: Color, r: int) -> StyleBoxFlat:
	var k := "%s/%d" % [c.to_html(), r]
	if not _sb_r.has(k):
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.set_corner_radius_all(r)
		s.anti_aliasing = true
		_sb_r[k] = s
	return _sb_r[k]

func _nav_tap(key: String) -> void:
	if key == "post":
		var why: String = VF.tok_post_flex()
		if why != "":
			notify("Not yet", why)
			return
		notify("Posted!", "Your catch is live. Watch the likes roll in.")
		show_page("profile")
		return
	if key == "feed" and page == "feed" and feed:
		feed.go(0)
		return
	show_page(key)

func _refresh_badges() -> void:
	var ready := 0
	for m in VF.TOK_MILESTONES:
		if VF.tok_milestone_state(m) == "ready": ready += 1
	var ch := 1 if (VF.tok_challenge_done() and not VF.tok_ch_claimed) else 0
	for k in nav_items:
		var n := 0
		if k == "profile": n = ready
		if k == "inbox": n = ready + ch
		if k == "discover": n = ch
		if int(nav_items[k].get_meta("badge", -1)) != n:
			nav_items[k].set_meta("badge", n)
			nav_items[k].queue_redraw()
	if home_badge:
		var b: int = VF.tok_badge()
		home_badge.text = str(b)
		home_badge.get_parent().visible = b > 0
	if main: main.pill_badge(main.phone_btn, VF.tok_badge())

func show_page(name: String) -> void:
	page = name
	for c in pages.get_children():
		if c != feed_page: c.queue_free()
	if name != "viewer": viewer = null
	feed_page.visible = name == "feed"
	_status_dark = name in ["discover", "inbox", "profile"]
	_nav_dark = not _status_dark
	match name:
		"feed": _ensure_feed()
		"discover": pages.add_child(_page_discover())
		"inbox": pages.add_child(_page_inbox())
		"profile": pages.add_child(_page_profile())
	_set_feeds_live(visible and not _closing)
	nav.queue_redraw()
	for k in nav_items: nav_items[k].queue_redraw()
	status.queue_redraw()
	homebar.queue_redraw()

# ---------------------------------------------------------------- the feed
func _ensure_feed() -> void:
	var key := "%s/%d/%d" % [VF._today(), VF.tok_next_id, _salt]
	if feed and key == _feed_key: return
	_feed_key = key
	if feed: feed.queue_free()
	for c in feed_page.get_children(): c.queue_free()
	feed = Feed.new()
	feed.setup(self, Tok.feed(VF, _salt), Vector2(SCR.x, FEED_H))
	feed_page.add_child(feed)
	_feed_header(feed_page, false)
	feed.set_live(visible and app == "tok" and page == "feed")

func _feed_header(parent: Control, back: bool) -> void:
	var head := _ctl(parent, Vector2(0, STATUS_H + 6), Vector2(SCR.x, 32))
	if back:
		var b := _ctl(head, Vector2(10, -2), Vector2(36, 36))
		b.draw.connect(func():
			b.draw_circle(Vector2(18, 18), 17.0, Color(0, 0, 0, 0.3))
			var t := ph("caret-left")
			var s := 18.0 / t.get_width()
			b.draw_set_transform(Vector2(17, 18), 0.0, Vector2(s, s))
			b.draw_texture(t, -t.get_size() * 0.5)
			b.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
		on_click(b, func(): show_page("profile"))
		var t := lbl("Your posts", 17, Color.WHITE, "black")
		shadow(t, 0.4)
		t.position = Vector2((SCR.x - 96) * 0.5, 4)
		head.add_child(t)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fo := lbl("Following", 16, Color(1, 1, 1, 0.62), "bold")
	shadow(fo, 0.4)
	row.add_child(fo)
	var fy := VBoxContainer.new()
	fy.add_theme_constant_override("separation", 3)
	fy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fyl := lbl("For You", 16, Color.WHITE, "black")
	shadow(fyl, 0.4)
	fy.add_child(fyl)
	var bar := ColorRect.new()
	bar.color = Color.WHITE
	bar.custom_minimum_size = Vector2(26, 3)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fy.add_child(bar)
	row.add_child(fy)
	head.add_child(row)
	row.reset_size()
	row.position = Vector2((SCR.x - row.size.x) * 0.5, 2)
	var s := icon_rect("magnifying-glass", 22, Color.WHITE)
	s.position = Vector2(SCR.x - 42, 2)
	s.size = Vector2(22, 22)
	head.add_child(s)
	on_click(s, func(): show_page("discover"))

## jump to the first post of a kind (capture / debugging)
func debug_goto(kind: String) -> bool:
	if feed == null: return false
	for i in feed.items.size():
		if String(feed.items[i].get("kind", "")) == kind:
			feed.go(i, false)
			return true
	return false

# ------------------------------------------------------------ feed actions
func on_like(item: Dictionary, liked: bool) -> void:
	var id := String(item.get("id", ""))
	if id != "" and (id in VF.tok_liked) != liked:
		VF.tok_toggle_like(id)

func is_following(who: Dictionary) -> bool:
	return _following.has(String(who.get("handle", "")))

func on_follow(who: Dictionary) -> void:
	var h := String(who.get("handle", ""))
	if _following.has(h): _following.erase(h)
	else:
		_following[h] = true
		AudioManager.play_click()

func on_share(_item: Dictionary) -> void:
	notify("Shared!", "Sent to your fishing crew's group chat.")

func on_cta(item: Dictionary) -> void:
	var p: Array = item.get("panel", ["shop", "Bait"])
	open_panel(p[0], p[1] if p.size() > 1 else "")

func on_end(action: String) -> void:
	if action == "fish":
		close()
		return
	_salt += 1
	_feed_key = ""
	_ensure_feed()

func on_claim_challenge(post) -> void:
	var r: Dictionary = VF.tok_claim_challenge()
	if r.has("error"):
		notify("Challenge", r.error)
		return
	AudioManager.play_success()
	notify("Challenge complete!", "You got %s%s" % [r.text, _chest_text(r.get("chest", {}))], ph("trophy"))
	if post: post.refresh_live()
	_confetti()

func _chest_text(c: Dictionary) -> String:
	if c.is_empty(): return ""
	var bits := []
	for k in c.get("items", {}):
		var val = c.items[k]
		if k == "money": bits.append("$" + VF.fmt(val))
		elif k == "xp": bits.append("%s XP" % VF.fmt(val))
		elif k == "charms": bits.append("%d charms" % val.size())
		elif VFData.EXOTICS.has(k): bits.append("%d %s" % [val, VFData.EXOTICS[k].name])
	return "  (chest: %s)" % ", ".join(bits) if bits else ""

func _confetti() -> void:
	var p := particles("confetti", Rect2(0, -10, SCR.x, 20), notif_layer)
	p.preprocess = 0.0
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = 60
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.emitting = true
	p.finished.connect(p.queue_free)

# -------------------------------------------------------------- comments
func open_comments(item: Dictionary) -> void:
	_close_sheet()
	sheet_layer.visible = true
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.size = SCR
	shade.modulate.a = 0.0
	shade.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_sheet())
	sheet_layer.add_child(shade)
	var h := SCR.y * 0.64
	var sheet := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.anti_aliasing = true
	sheet.add_theme_stylebox_override("panel", sb)
	sheet.size = Vector2(SCR.x, h)
	sheet.position = Vector2(0, SCR.y)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet_layer.add_child(sheet)
	var n := int(item.get("comments", 0))
	if item.has("post"): n = int(VF.tok_post_likes(item.post) * 0.04)
	var title := lbl("%s comments" % Tok.count(n), 13, C_INK, "black")
	title.position = Vector2(0, 14)
	title.size = Vector2(SCR.x, 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet.add_child(title)
	var x := icon_rect("x", 16, C_INK)
	x.position = Vector2(SCR.x - 34, 14)
	x.size = Vector2(16, 16)
	sheet.add_child(x)
	on_click(x, _close_sheet)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 42)
	scroll.size = Vector2(SCR.x, h - 42 - 92)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sheet.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	list.custom_minimum_size.x = SCR.x
	scroll.add_child(list)
	for c in Tok.comments_for(item, mini(8, maxi(1, n))):
		list.add_child(_comment_row(c.who, c.text, c.ago, c.likes))
	var bar := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = C_CARD
	bsb.set_corner_radius_all(999)
	bsb.content_margin_left = 14
	bsb.content_margin_right = 14
	bsb.content_margin_top = 6
	bsb.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", bsb)
	bar.position = Vector2(12, h - 88)
	bar.size = Vector2(SCR.x - 24, 40)
	var le := LineEdit.new()
	le.placeholder_text = "Add a comment..."
	le.flat = true
	le.add_theme_font_override("font", font_reg)
	le.add_theme_font_size_override("font_size", 13)
	le.add_theme_color_override("font_color", C_INK)
	le.add_theme_color_override("font_placeholder_color", C_SUB)
	le.add_theme_color_override("caret_color", C_TEAL)
	le.max_length = 120
	le.text_submitted.connect(func(t: String):
		if t.strip_edges() == "": return
		var row := _comment_row(Tok.me(VF), t.strip_edges(), "now", 0)
		list.add_child(row)
		list.move_child(row, 0)
		le.text = ""
		AudioManager.play_click())
	bar.add_child(le)
	sheet.add_child(bar)
	var tw := sheet.create_tween().set_parallel(true)
	tw.tween_property(sheet, "position:y", SCR.y - h, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(shade, "modulate:a", 1.0, 0.2)

func _comment_row(who: Dictionary, text: String, when: String, likes: int) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var av := avatar(who, 32, Color.WHITE)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(av)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lbl(String(who.get("handle", "")), 12, C_SUB, "bold"))
	var t := lbl(text, 14, C_INK, "reg")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = SCR.x - 120
	v.add_child(t)
	v.add_child(lbl("%s   Reply" % when, 11, C_SUB, "bold"))
	h.add_child(v)
	var lk := VBoxContainer.new()
	lk.add_theme_constant_override("separation", 0)
	lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lk.add_child(icon_rect("heart", 15, Color("#b8c2c8")))
	var ll := lbl(Tok.count(likes) if likes > 0 else "", 11, C_SUB, "bold")
	ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lk.add_child(ll)
	h.add_child(lk)
	m.add_child(h)
	return m

func _close_sheet() -> void:
	if not sheet_layer.visible: return
	for c in sheet_layer.get_children(): c.queue_free()
	sheet_layer.visible = false
	var f := get_viewport().gui_get_focus_owner()
	if f: f.release_focus()

# ---------------------------------------------------------- notifications
func notify(title: String, body: String, icon_tex: Texture2D = null) -> void:
	_notif_queue.append([title, body, icon_tex])
	if not _notif_busy: _next_notif()

func _next_notif() -> void:
	if _notif_queue.is_empty():
		_notif_busy = false
		return
	_notif_busy = true
	var n: Array = _notif_queue.pop_front()
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.97, 0.98, 0.99, 0.96)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 4)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size.x = SCR.x - 20
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(36, 36)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = n[2]
	ic.draw.connect(func():
		rrect_grad(ic, Rect2(0, 0, 36, 36), 9.0, Color(DOCK_APPS[0][3]), Color(DOCK_APPS[0][4]))
		var t := tex if tex else ph("fish")
		var s := 20.0 / t.get_width()
		ic.draw_set_transform(Vector2(18, 18), 0.0, Vector2(s, s))
		ic.draw_texture(t, -t.get_size() * 0.5, Color.WHITE)
		ic.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := lbl(n[0], 13, C_INK, "black")
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	top.add_child(lbl("now", 11, C_SUB, "bold"))
	v.add_child(top)
	var bl := lbl(n[1], 12, Color("#3b4950"), "reg")
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size.x = SCR.x - 86
	v.add_child(bl)
	h.add_child(v)
	p.add_child(h)
	notif_layer.add_child(p)
	p.reset_size()
	p.position = Vector2(10, -p.size.y - 10)
	var tw := p.create_tween()
	tw.tween_property(p, "position:y", 44.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(p, "position:y", -p.size.y - 10, 0.28).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.queue_free)
	tw.tween_callback(_next_notif)

# ============================================================ light pages
func _light_page() -> Array:
	var root := Control.new()
	root.size = Vector2(SCR.x, FEED_H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.size = root.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.size = root.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root.add_child(scroll)
	var m := MarginContainer.new()
	m.custom_minimum_size.x = SCR.x
	for s in ["left", "right"]: m.add_theme_constant_override("margin_" + s, 16)
	m.add_theme_constant_override("margin_top", int(STATUS_H) + 8)
	m.add_theme_constant_override("margin_bottom", 18)
	scroll.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	return [root, v]

func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 60
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _card_box(bg: Color, border: Color, pad := 14) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	return p

func _section(v: VBoxContainer, text: String) -> void:
	var l := lbl(text, 15, C_INK, "black")
	v.add_child(l)

func _tex_rect(t: Texture2D, d: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(d, d)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _bar(k: float, col: Color, w := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, 8)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		c.draw_style_box(_pill_sb_r(Color(0, 0, 0, 0.08), 4), Rect2(Vector2.ZERO, c.size))
		if k > 0.0: c.draw_style_box(_pill_sb_r(col, 4), Rect2(0, 0, maxf(8.0, c.size.x * clampf(k, 0.0, 1.0)), c.size.y)))
	return c

# ------------------------------------------------------------- discover
func _page_discover() -> Control:
	var pr := _light_page()
	var v: VBoxContainer = pr[1]
	v.add_child(lbl("Discover", 24, C_INK, "black"))
	var search := _card_box(C_CARD, C_CARD, 10)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 8)
	sh.add_child(icon_rect("magnifying-glass", 16, C_SUB))
	sh.add_child(lbl("Search fishers, fish, #tags", 13, C_SUB, "bold"))
	search.add_child(sh)
	v.add_child(search)
	# trending fish
	var f: String = VF.trending_fish()
	var tc := _card_box(Color("#fff3ea"), Color("#ffd6b8"))
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 12)
	th.add_child(_tex_rect(item_tex(["fish", f]), 70))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(chip("TRENDING TODAY", Color("#ff6a2b"), Color.WHITE, "fire", 10))
	tv.add_child(lbl("#%sTok" % f.replace(" ", ""), 18, C_INK, "black"))
	tv.add_child(_wrap(lbl("%s sells for +50%% until midnight UTC" % f, 12, Color("#9a3412"), "bold")))
	var where := []
	for b in VFData.BIOME_ORDER:
		if f in VFData.BIOMES[b].fish: where.append(b)
	tv.add_child(_wrap(lbl("Found in: " + ", ".join(where), 12, C_SUB, "bold")))
	th.add_child(tv)
	var tcv := VBoxContainer.new()
	tcv.add_theme_constant_override("separation", 10)
	tcv.add_child(th)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	var map := pill("Open map", Color("#ff6a2b"), Color.WHITE, 34, 0)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.pressed.connect(func(): open_panel("biomes"))
	trow.add_child(map)
	var held := int(VF.inventory.get(f, 0))
	if VF.inventory_value() > 0:
		var sell := pill("Sell  $%s" % VF.fmt(VF.inventory_value()), C_INK, Color.WHITE, 34, 0)
		sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sell.tooltip_text = "Sell everything in your hold (%d %s at +50%%)" % [held, f]
		sell.pressed.connect(func():
			var got: int = VF.sell_all()
			notify("Sold!", "+$%s%s" % [VF.fmt(got), (" with %d trending %s" % [held, f]) if held > 0 else ""], ph("coins"))
			show_page("discover"))
		trow.add_child(sell)
	tcv.add_child(trow)
	tc.add_child(tcv)
	v.add_child(tc)
	# daily challenge
	v.add_child(_challenge_card())
	# hashtags (flavour)
	_section(v, "Popular hashtags")
	var tags := [["fishtok", 9.8], ["%stok" % Tok.tag(f), 4.1], ["%stok" % Tok.tag(VF.biome), 2.7], ["1in10000", 1.9], ["treasure", 1.2], ["protip", 0.6]]
	for t in tags:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		var hc := Control.new()
		hc.custom_minimum_size = Vector2(34, 34)
		hc.draw.connect(func():
			hc.draw_circle(Vector2(17, 17), 17.0, C_CARD)
			hc.draw_string(font_black, Vector2(0, 23), "#", HORIZONTAL_ALIGNMENT_CENTER, 34, 17, C_INK))
		r.add_child(hc)
		var tl := VBoxContainer.new()
		tl.add_theme_constant_override("separation", -2)
		tl.add_child(lbl("#" + String(t[0]), 14, C_INK, "black"))
		tl.add_child(lbl("%sM views" % str(t[1]), 11, C_SUB, "bold"))
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(tl)
		r.add_child(icon_rect("caret-right", 14, C_SUB))
		v.add_child(r)
	return pr[0]

func _challenge_card() -> Control:
	var c: Dictionary = VF.tok_challenge()
	var goal := maxi(1, int(c.goal))
	var prog := mini(VF.tok_ch_prog, goal)
	var card := _card_box(Color("#eaf7f9"), Color("#c3e8ee"))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var t: Texture2D = item_tex(["fish", String(c.fish)]) if c.kind == "species" else (item_tex(["chest", "epic"]) if c.kind == "chests" else item_tex(["ui", "inventory"]))
	h.add_child(_tex_rect(t, 52))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 1)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(chip("#CHALLENGE", C_TEAL, Color.WHITE, "target", 10))
	tv.add_child(_wrap(lbl(VF.tok_challenge_text(c), 16, C_INK, "black")))
	tv.add_child(_wrap(lbl("Reward: %s" % VF.goal_reward_text(c.reward), 12, C_SUB, "bold")))
	h.add_child(tv)
	v.add_child(h)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 8)
	pr.add_child(_bar(float(prog) / goal, C_GOOD if prog >= goal else C_TEAL))
	pr.add_child(lbl("%s / %s" % [VF.commas(prog), VF.commas(goal)], 12, C_INK, "black"))
	v.add_child(pr)
	var b: Button
	if VF.tok_ch_claimed:
		b = pill("Claimed  ✓", Color("#cfe9ee"), C_TEAL, 34, 0)
		b.disabled = true
	elif prog >= goal:
		b = pill("Claim reward", C_GOLD, C_INK, 36, 0)
		b.pressed.connect(func():
			on_claim_challenge(null)
			show_page(page))
	else:
		b = pill("Ends in %s" % until_midnight(), Color("#cfe9ee"), C_TEAL, 34, 0)
		b.disabled = true
	v.add_child(b)
	card.add_child(v)
	return card

# ---------------------------------------------------------------- inbox
func _page_inbox() -> Control:
	var pr := _light_page()
	var v: VBoxContainer = pr[1]
	v.add_child(lbl("Inbox", 24, C_INK, "black"))
	_section(v, "Activity")
	var me := Tok.me(VF)
	for m in VF.TOK_MILESTONES:
		if VF.tok_milestone_state(m) == "ready":
			v.add_child(_inbox_row("gift", C_GOLD, "You hit %s followers!" % Tok.count(m), "Tap to claim: %s" % VF.goal_reward_text(VF.tok_milestone_reward(m)),
				func(): show_page("profile")))
	if VF.tok_challenge_done() and not VF.tok_ch_claimed:
		v.add_child(_inbox_row("target", C_TEAL, "Challenge complete", "Claim your reward: %s" % VF.goal_reward_text(VF.tok_challenge().reward),
			func(): show_page("discover")))
	var fans: int = VF.tok_followers()
	if fans > 0:
		var c: Dictionary = Tok.CREATORS[fans % Tok.CREATORS.size()]
		v.add_child(_inbox_row("user-circle", Color("#8b5cf6"), "New followers",
			"%s%s followed you" % [c.handle, (" and %s others" % Tok.count(fans - 1)) if fans > 1 else ""], func(): show_page("profile")))
	var posts: Array = VF.tok_posts.duplicate()
	posts.reverse()
	for i in mini(12, posts.size()):
		var p: Dictionary = posts[i]
		var likes: int = VF.tok_post_likes(p)
		var idx := i
		v.add_child(_inbox_row("heart", C_HEART, "%s likes" % Tok.count(likes), "on \"%s\" · %s" % [VF.tok_post_title(p),
			Tok.ago(Time.get_unix_time_from_system() - float(p.t))], func(): _open_viewer(idx)))
	v.add_child(_inbox_row("fish", Color(DOCK_APPS[0][3]), "Welcome to FishTok, %s!" % me.handle,
		"Your catches post themselves: new fish, records, rare chests and big levels.", func(): show_page("feed")))
	return pr[0]

func _inbox_row(icon_name: String, col: Color, title: String, sub: String, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var c := Control.new()
	c.custom_minimum_size = Vector2(44, 44)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		c.draw_circle(Vector2(22, 22), 22.0, col)
		var t := ph(icon_name)
		var s := 22.0 / t.get_width()
		c.draw_set_transform(Vector2(22, 22), 0.0, Vector2(s, s))
		c.draw_texture(t, -t.get_size() * 0.5, Color.WHITE)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	h.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lbl(title, 14, C_INK, "black"))
	var s := lbl(sub, 12, C_SUB, "bold")
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = SCR.x - 32 - 56 - 20
	v.add_child(s)
	h.add_child(v)
	h.add_child(icon_rect("caret-right", 14, Color("#b8c2c8")))
	on_click(h, cb)
	return h

# -------------------------------------------------------------- profile
func _page_profile() -> Control:
	var pr := _light_page()
	var v: VBoxContainer = pr[1]
	v.add_theme_constant_override("separation", 10)
	var me := Tok.me(VF)
	var top := lbl(VF.player_name, 17, C_INK, "black")
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(top)
	var avc := CenterContainer.new()
	avc.add_child(avatar(me, 92, Color("#e9eef1")))
	v.add_child(avc)
	var hl := lbl("@" + String(me.handle), 15, C_INK, "black")
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hl)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 0)
	var nums := []
	for s in [[str(_following.size() + 12), "Following"], ["", "Followers"], ["", "Likes"]]:
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 92
		col.add_theme_constant_override("separation", -2)
		var n := lbl(s[0], 18, C_INK, "black")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		var l := lbl(s[1], 12, C_SUB, "bold")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		stats.add_child(col)
		nums.append(n)
	_prof_followers = nums[1]
	_prof_likes = nums[2]
	v.add_child(stats)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 8)
	var post := pill("Post your catch", C_HEART, Color.WHITE, 38, 170, 8)
	var left: float = VF.tok_flex_ready_in()
	if left > 0.0:
		post.text = "Next post in %d:%02d" % [int(left) / 60, int(left) % 60]
		post.disabled = true
	post.pressed.connect(func(): _nav_tap("post"))
	btns.add_child(post)
	var share := pill("", C_CARD, C_INK, 38, 44, 8)
	share.icon = ph("share-fat")
	share.add_theme_color_override("icon_normal_color", C_INK)
	share.add_theme_color_override("icon_hover_color", C_INK)
	share.add_theme_constant_override("icon_max_width", 18)
	share.pressed.connect(func(): notify("Profile link copied", "Share it with your crew!"))
	btns.add_child(share)
	v.add_child(btns)
	var bio := lbl("fishing the %s · Lv %s · %d/%d species" % [VF.biome, VF.commas(VF.level), VF.discovered.size(), VFData.FISH_ORDER.size()], 12, C_SUB, "bold")
	bio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(bio)
	_prof_rewards = VBoxContainer.new()
	v.add_child(_prof_rewards)
	_prof_sig = ""
	_profile_live()
	# posts grid
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 6)
	tabs.add_child(icon_rect("squares-four", 18, C_INK))
	tabs.add_child(lbl("Posts  %d" % VF.tok_posts.size(), 13, C_INK, "black"))
	v.add_child(tabs)
	var posts: Array = VF.tok_posts.duplicate()
	posts.reverse()
	if posts.is_empty():
		var e := lbl("Your catches post themselves here:\ndiscover a new fish, set a record or open a rare chest.", 13, C_SUB, "bold")
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(e)
	else:
		var g := GridContainer.new()
		g.columns = 3
		g.add_theme_constant_override("h_separation", 3)
		g.add_theme_constant_override("v_separation", 3)
		for i in posts.size():
			g.add_child(_thumb(posts[i], i))
		v.add_child(g)
	return pr[0]

## live numbers + milestone rewards (rebuilt only when something changed)
func _profile_live() -> void:
	if _prof_followers == null or not is_instance_valid(_prof_followers): return
	var fans: int = VF.tok_followers()
	_prof_followers.text = Tok.count(fans)
	_prof_likes.text = Tok.count(VF.tok_likes())
	var sig := ""
	for m in VF.TOK_MILESTONES: sig += VF.tok_milestone_state(m)
	var nxt := 0
	for m in VF.TOK_MILESTONES:
		if fans < m:
			nxt = m
			break
	sig += "/%d" % (int(fans * 40.0 / maxf(1.0, nxt)) if nxt > 0 else -1)
	if sig == _prof_sig: return
	_prof_sig = sig
	for c in _prof_rewards.get_children(): c.queue_free()
	var card := _card_box(Color("#fbf7ee"), Color("#f1e3c2"), 12)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_child(icon_rect("trophy", 16, C_GOLD.darkened(0.2)))
	var ht := lbl("Creator rewards", 14, C_INK, "black")
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ht)
	if nxt > 0: head.add_child(lbl("%s / %s" % [Tok.count(fans), Tok.count(nxt)], 12, C_SUB, "bold"))
	v.add_child(head)
	if nxt > 0:
		var prev := 0
		for m in VF.TOK_MILESTONES:
			if m < nxt: prev = m
		v.add_child(_bar(float(fans - prev) / float(nxt - prev), C_GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for m in VF.TOK_MILESTONES:
		row.add_child(_milestone_chip(m))
	v.add_child(row)
	if nxt > 0:
		var nr := lbl("Next: %s followers → %s" % [Tok.count(nxt), VF.goal_reward_text(VF.tok_milestone_reward(nxt))], 11, C_SUB, "bold")
		nr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nr.custom_minimum_size.x = SCR.x - 60
		v.add_child(nr)
	card.add_child(v)
	_prof_rewards.add_child(card)

func _milestone_chip(m: int) -> Control:
	var st: String = VF.tok_milestone_state(m)
	var c := Control.new()
	c.custom_minimum_size = Vector2(51, 62)
	c.draw.connect(func():
		var r := Rect2(Vector2.ZERO, c.size)
		var bg: Color = {"ready": C_GOLD, "claimed": Color("#dcfce7"), "locked": Color("#eef1f3")}[st]
		c.draw_style_box(_pill_sb_r(bg, 12), r)
		var ic: String = {"ready": "gift", "claimed": "check", "locked": "lock"}[st]
		var col: Color = {"ready": C_INK, "claimed": Color("#15803d"), "locked": Color("#9aa7ae")}[st]
		var t := ph(ic)
		var s := 20.0 / t.get_width()
		c.draw_set_transform(Vector2(c.size.x * 0.5, 21), 0.0, Vector2(s, s))
		c.draw_texture(t, -t.get_size() * 0.5, col)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		c.draw_string(font_black, Vector2(0, 50), Tok.count(m), HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 13, col))
	c.tooltip_text = "%s followers: %s" % [Tok.count(m), VF.goal_reward_text(VF.tok_milestone_reward(m))]
	if st == "ready":
		c.pivot_offset = c.custom_minimum_size * 0.5
		var tw := c.create_tween().set_loops()
		tw.tween_property(c, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(c, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	on_click(c, func(): claim_milestone(m))
	return c

func claim_milestone(m: int) -> void:
	var st: String = VF.tok_milestone_state(m)
	if st != "ready":
		notify("%s followers" % Tok.count(m), "Already claimed." if st == "claimed" else "Reward: %s" % VF.goal_reward_text(VF.tok_milestone_reward(m)), ph("trophy"))
		return
	var r: Dictionary = VF.tok_claim_milestone(m)
	if r.has("error"):
		notify("FishTok", r.error)
		return
	AudioManager.play_success()
	notify("%s followers!" % Tok.count(m), "Reward claimed: %s%s" % [r.text, _chest_text(r.get("chest", {}))], ph("gift"))
	_confetti()
	_prof_sig = ""
	_profile_live()
	_refresh_badges()

func _thumb(p: Dictionary, idx: int) -> Control:
	var w := (SCR.x - 32.0 - 6.0) / 3.0
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, w * 1.33)
	c.clip_contents = true
	var item := Tok.mine_post(VF, p)
	var vv: Dictionary = item.v
	c.draw.connect(func(): _draw_thumb(c, vv))
	var likes := lbl("", 12, Color.WHITE, "black")
	shadow(likes, 0.5)
	likes.text = Tok.count(int(item.likes))
	likes.position = Vector2(20, w * 1.33 - 20)
	c.add_child(likes)
	on_click(c, func(): _open_viewer(idx))
	return c

func _draw_thumb(c: Control, vv: Dictionary) -> void:
	var r := Rect2(Vector2.ZERO, c.size)
	var t := String(vv.get("type", ""))
	var tex: Texture2D
	var col := C_TEAL
	match t:
		"fish":
			col = vv.get("accent", C_TEAL)
			tex = item_tex(["fish", String(vv.fish)])
		"chest":
			col = tier_color(String(vv.tier))
			tex = item_tex(["chest", String(vv.tier)])
		"haul":
			var b := biome_tex(String(vv.biome))
			if b:
				var th := float(b.get_height()) * 0.6
				var cw := th * r.size.x / r.size.y
				c.draw_texture_rect_region(b, r, Rect2(b.get_width() * 0.5 - cw * 0.5, b.get_height() * 0.35, cw, th))
			tex = item_tex(["fish", String(vv.fish)])
		"level":
			col = Color("#4338ca")
	if t != "haul": grad(c, r, col.darkened(0.55), col.darkened(0.15))
	if t == "level":
		c.draw_string(font_black, Vector2(0, r.size.y * 0.5 + 4), "Lv " + VF.commas(int(vv.level)), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Color.WHITE)
	elif tex:
		var s := r.size.x * 0.78 / tex.get_width()
		c.draw_set_transform(r.get_center() - Vector2(0, 6), -0.1, Vector2(s, s))
		c.draw_texture(tex, -tex.get_size() * 0.5)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	grad(c, Rect2(0, r.size.y - 34, r.size.x, 34), Color(0, 0, 0, 0), Color(0, 0, 0, 0.45))
	var y := r.size.y - 12.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(7, y - 5), Vector2(15, y), Vector2(7, y + 5)]), Color.WHITE)

func _open_viewer(idx: int) -> void:
	show_page("feed")            # clears other pages
	page = "viewer"
	feed_page.visible = false
	var posts: Array = VF.tok_posts.duplicate()
	posts.reverse()
	var items := []
	for p in posts:
		var it := Tok.mine_post(VF, p)
		it["seed"] = int(p.id) * 37
		items.append(it)
	if items.is_empty():
		show_page("profile")
		return
	var holder := _ctl(pages, Vector2.ZERO, Vector2(SCR.x, FEED_H))
	viewer = Feed.new()
	viewer.setup(self, items, Vector2(SCR.x, FEED_H), idx)
	holder.add_child(viewer)
	_feed_header(holder, true)
	_status_dark = false
	_nav_dark = true
	_set_feeds_live(true)
	nav.queue_redraw()
	for k in nav_items: nav_items[k].queue_redraw()
	status.queue_redraw()
	homebar.queue_redraw()

func _on_vf_changed() -> void:
	if not visible or _closing: return
	if app == "home": _refresh_home()
	elif page == "discover" or page == "inbox": show_page(page)

extends Control
## Title screen ("launcher"): the first thing players see. The owner's title illustration, brought to life
## (water shimmer and glints, swaying leaves, bobber ripples, lantern glow, a passing gull, a slow camera
## drift), with a deep-sea side panel on the right (a softly moving wave edge, drifting bubbles and fish
## shadows): a greeting, Play, signing in / creating an account right there, and the update status.
## Art: tools/art/make_launcher.py. vf_main shows it at start (not in captures / recordings unless
## --launcher) and hides it on Play.

const BG := "res://assets/launcher/launcher_bg.jpg"
const MASKS := "res://assets/launcher/launcher_masks.png"
const LOGO := "res://assets/brand/logo.png"          # tools/art/make_brand.py
const ICON := "res://assets/brand/icon_256.png"
const BOBBER := Vector2(0.3772, 0.6885)                     # points in the picture (fractions)
const LANTERNS := [Vector2(0.1356, 0.2862), Vector2(0.2663, 0.4296)]

const MINT := Color("#5fe0bd")
const SEA := Color("#12454f")
const DEEP := Color("#0a2930")
const INK := Color("#0b3138")
const SOFT := Color("#a9d6d8")
const FAINT := Color("#7fb0b5")

const SHADER := """
shader_type canvas_item;
uniform sampler2D masks : filter_linear, repeat_disable;
uniform sampler2D noise : filter_linear, repeat_enable;
void fragment() {
	vec2 uv = UV;
	vec3 m = texture(masks, uv).rgb;
	float t = TIME;
	vec2 n = texture(noise, uv * vec2(2.5, 4.5) + vec2(t * 0.010, t * 0.017)).rg - 0.5;
	vec2 wobble = n * 0.0016 * m.r;
	vec2 sway = vec2(sin(t * 1.25 + uv.y * 5.0) * 0.0045, cos(t * 1.05 + uv.x * 4.0) * 0.0018) * m.g;
	vec4 c = texture(TEXTURE, uv + wobble + sway);
	float a = texture(noise, uv * vec2(16.0, 30.0) + vec2(-t * 0.03, t * 0.05)).r;
	float b = texture(noise, uv * vec2(23.0, 41.0) + vec2(t * 0.04, -t * 0.02)).r;
	float patch = smoothstep(0.55, 0.75, texture(noise, uv * 1.3 + vec2(t * 0.006, 0.0)).r);
	float glint = smoothstep(0.86, 0.93, a * b * 2.0) * m.r * patch;
	c.rgb += vec3(1.0, 0.98, 0.9) * glint * 0.45;
	COLOR = c;
}
"""

var main
var art: Control
var fx: Control
var wave: Control
var tex: Texture2D
var glow: Texture2D
var bold: FontVariation
var logo: TextureRect
var tagline: Control
var col: VBoxContainer                  # the panel's content column
var foot: HBoxContainer
var play_btn: Button
var form := ""                          # "" | sign_in | sign_up: the account form open in the panel
var _fields := {}
var _typed := {}                        # what was typed in the form (kept across rebuilds)
var _t := 0.0
var _gull_t := -4.0
var _slide := 1.0                       # 1 = the panel is off to the right (entrance / exit)
var _leaving := false
var _leave_t := 0.0
var _key := ""
var _retried := false                   # one quiet automatic retry if the first update check fails
var _bubbles := []
var _fish := []

func setup(m) -> void:
	main = m

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP                  # nothing reaches the game underneath
	theme = main.theme
	bold = FontVariation.new()
	bold.base_font = load("res://assets/third_party/fonts/Fredoka.ttf")
	bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 680}
	tex = load(BG)
	art = _layer(_draw_art)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SHADER
	mat.set_shader_parameter("masks", load(MASKS))
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	nt.noise = fn
	mat.set_shader_parameter("noise", nt)
	art.material = mat
	fx = _layer(_draw_fx)
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(1, 0.86, 0.5, 0.85))
	g.gradient.set_color(1, Color(1, 0.7, 0.3, 0.0))
	glow = g
	_build_logo()
	wave = _layer(_draw_wave)
	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	foot = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	add_child(foot)
	for i in 14:
		_bubbles.append({"x": randf(), "y": randf() * 1200.0, "r": randf_range(1.5, 4.5), "s": randf_range(10.0, 26.0)})
	for i in 4:
		_fish.append({"x": randf(), "y": randf_range(0.1, 0.95), "s": randf_range(0.006, 0.014) * (1 if randf() < 0.5 else -1), "k": randf_range(0.7, 1.3)})
	Backend.status_changed.connect(_refresh)
	Updater.status_changed.connect(_refresh)
	resized.connect(_layout)
	_refresh()
	# entrance: the panel glides in, the logo fades up
	logo.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_slide", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(logo, "modulate:a", 1.0, 0.8).set_delay(0.25)

func _layer(cb: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(cb)
	add_child(c)
	return c

# ------------------------------------------------------------------ picture
func _cover_rect() -> Rect2:
	var sz := size
	var ts := Vector2(tex.get_size())
	var zoom := 1.0 + 0.035 * (0.5 - 0.5 * cos(_t * TAU / 46.0))         # a slow breath of a camera move
	if _leaving: zoom += 0.12 * clampf((_t - _leave_t) / 0.5, 0.0, 1.0)
	var s := maxf(sz.x / ts.x, sz.y / ts.y) * zoom
	var rs := ts * s
	var drift := Vector2(0.5 + 0.03 * sin(_t * TAU / 61.0), 0.5)
	return Rect2((sz - rs) * drift, rs)

func to_screen(p: Vector2) -> Vector2:
	var r := _cover_rect()
	return r.position + p * r.size

func _draw_art() -> void:
	art.draw_texture_rect(tex, _cover_rect(), false)

func _draw_fx() -> void:
	var r := _cover_rect()
	var k := r.size.x / 1920.0
	var bp := to_screen(BOBBER)                               # bobber ripples (flattened: we look at an angle)
	fx.draw_set_transform(bp, 0.0, Vector2(1.0, 0.42))
	for i in 3:
		var ph := fmod(_t * 0.45 + i / 3.0, 1.0)
		fx.draw_arc(Vector2.ZERO, (10.0 + 70.0 * ph) * k, 0.0, TAU, 48, Color(1, 1, 1, 0.55 * (1.0 - ph)), 2.0 * k, true)
	fx.draw_set_transform(Vector2.ZERO)
	for i in LANTERNS.size():
		var lp := to_screen(LANTERNS[i])
		var fl := 0.75 + 0.15 * sin(_t * 7.3 + i * 2.1) + 0.1 * sin(_t * 13.7 + i)
		var gs := 120.0 * k * (0.95 + 0.08 * fl)
		fx.draw_texture_rect(glow, Rect2(lp - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false, Color(1, 1, 1, 0.55 * fl))
	if _gull_t >= 0.0:                                        # a gull crossing the sky now and then
		var f := _gull_t / 11.0
		var gp := Vector2(r.position.x + r.size.x * (0.75 - 0.9 * f), r.position.y + r.size.y * (0.12 + 0.04 * sin(f * 5.0)))
		var flap := sin(_t * 9.0)
		var w := 15.0 * k
		var pts := PackedVector2Array([gp + Vector2(-w, -w * 0.35 * flap - 2 * k), gp + Vector2(-w * 0.45, -w * 0.2 * flap - 5 * k * flap),
			gp, gp + Vector2(w * 0.45, -w * 0.2 * flap - 5 * k * flap), gp + Vector2(w, -w * 0.35 * flap - 2 * k)])
		fx.draw_polyline(pts, Color(0.2, 0.25, 0.3, 0.35), 4.0 * k, true)
		fx.draw_polyline(pts, Color(1, 1, 1, 0.95), 2.4 * k, true)

# ------------------------------------------------------------------ the deep-sea panel
func _short() -> bool:
	return size.y < 600.0

func _panel_w() -> float:
	return clampf(size.x * 0.42, 340.0, 440.0) if _short() else clampf(size.x * 0.36, 390.0, 500.0)

func _panel_x() -> float:
	return size.x - _panel_w() * (1.0 - _slide) + 40.0 * _slide

func _edge(y: float) -> float:
	var a := 13.0
	return _panel_x() - a + a * sin(y * 0.0105 + _t * 0.6) + a * 0.45 * sin(y * 0.027 - _t * 0.95)

func _draw_wave() -> void:
	var n := 56
	var edge := PackedVector2Array()
	for i in n + 1:
		var y := size.y * float(i) / n
		edge.append(Vector2(_edge(y), y))
	for s in 3:                                               # a soft shadow on the picture
		var sh := PackedVector2Array()
		for p in edge: sh.append(p - Vector2(5.0 + s * 6.0, 0.0))
		wave.draw_polyline(sh, Color(0.02, 0.1, 0.14, 0.09 - s * 0.025), 10.0, true)
	var right := maxf(size.x, _panel_x() + 40.0) + 4.0       # (strips: always convex, even while sliding off-screen)
	for i in n:
		var c0 := SEA.lerp(DEEP, float(i) / n)
		var c1 := SEA.lerp(DEEP, float(i + 1) / n)
		wave.draw_polygon(PackedVector2Array([edge[i], edge[i + 1], Vector2(right, edge[i + 1].y), Vector2(right, edge[i].y)]),
			PackedColorArray([c0, c1, c1, c0]))
	wave.draw_polyline(edge, Color(0.6, 0.97, 0.88, 0.32), 2.0, true)       # rim light
	var x0 := _panel_x()
	var pw := _panel_w()
	for f in _fish:                                           # fish shadows drifting by
		var fp := Vector2(x0 + 30.0 + fmod(f.x, 1.0) * (pw - 60.0), size.y * f.y)
		var d: float = signf(f.s)
		var sz: float = 14.0 * f.k
		var body := PackedVector2Array()
		for a in 12:
			var ang := TAU * a / 12.0
			body.append(fp + Vector2(cos(ang) * sz, sin(ang) * sz * 0.42))
		wave.draw_colored_polygon(body, Color(0.62, 0.95, 0.9, 0.07))
		var tail := fp - Vector2(d * sz * 0.95, 0)
		wave.draw_colored_polygon(PackedVector2Array([tail, tail - Vector2(d * sz * 0.6, sz * 0.4), tail - Vector2(d * sz * 0.6, -sz * 0.4)]),
			Color(0.62, 0.95, 0.9, 0.07))
	for b in _bubbles:                                        # bubbles rising
		var bp := Vector2(x0 + 20.0 + b.x * (pw - 40.0) + sin(_t * 1.3 + b.r * 3.0) * 4.0, size.y - fmod(b.y, size.y + 40.0) + 20.0)
		wave.draw_arc(bp, b.r, 0.0, TAU, 14, Color(0.75, 1.0, 0.95, 0.11), 1.2, true)

func _process(delta: float) -> void:
	_t += delta
	_gull_t += delta
	if _gull_t > 11.0: _gull_t = -randf_range(6.0, 12.0)
	for b in _bubbles: b.y += b.s * delta
	for f in _fish: f.x += f.s * delta
	art.queue_redraw()
	fx.queue_redraw()
	wave.queue_redraw()
	_place()
	if Engine.get_process_frames() % 20 == 0:
		_refresh()                                            # (cheap: only rebuilds when something changed)

# ------------------------------------------------------------------ layout
func _build_logo() -> void:
	logo = TextureRect.new()
	logo.texture = load(LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	var tg := PanelContainer.new()                           # (hidden: the stacked logo stands alone, like the brand art)
	tg.visible = false
	tg.add_theme_stylebox_override("panel", _box(Color(0.06, 0.2, 0.26, 0.5), 999, Color.TRANSPARENT, 14, 5))
	tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := _text("a cozy fishing game  ·  by afosh", 15, Color(1, 1, 1, 0.95))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tg.add_child(tl)
	tagline = tg
	logo.add_child(tg)

func _layout() -> void:
	_place()

## positions follow the moving panel every frame (it slides in and out)
func _place() -> void:
	if size.x < 10: return
	var pw := _panel_w()
	var x0 := _panel_x()
	var pad := 34.0 if not _short() else 26.0
	var cw := pw - pad * 2.0
	col.custom_minimum_size.x = cw
	col.add_theme_constant_override("separation", 12 if not _short() else 8)
	col.size = Vector2(cw, 0)
	col.reset_size()
	foot.reset_size()
	foot.position = Vector2(x0 + pad, size.y - foot.size.y - (16.0 if not _short() else 8.0))
	var room := foot.position.y - 8.0                         # centred in the space above the footer
	col.position = Vector2(x0 + pad, maxf(10.0, (room - col.size.y) * 0.5))
	# the logo over the sky, centred on the picture's visible part
	var ts := Vector2(logo.texture.get_size())
	var lw := minf(size.x * 0.2, 380.0) if not _short() else minf(size.x * 0.2, 270.0)
	var lh := lw * ts.y / ts.x
	logo.size = Vector2(lw, lh)
	logo.position = Vector2((size.x - pw) * 0.42 - lw * 0.5, size.y * (0.05 if not _short() else 0.035))
	tagline.reset_size()
	tagline.position = Vector2(lw * 0.5 - tagline.size.x * 0.5, lh + 6.0)

# ------------------------------------------------------------------ widgets
func _box(bg: Color, radius: int, border: Color, pad_h := 12, pad_v := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0:
		s.set_border_width_all(2)
		s.border_color = border
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	s.anti_aliasing = true
	return s

func _text(t: String, size_ := 15, color := SOFT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size_)
	l.add_theme_color_override("font_color", color)
	return l

func _wrap(t: String, size_ := 15, color := SOFT) -> Label:
	var l := _text(t, size_, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _button(t: String, primary: bool, cb: Callable, icon_name := "", height := 44) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = height
	b.add_theme_font_size_override("font_size", 17 if primary else 15)
	if primary: b.add_theme_font_override("font", bold)
	var fg := INK if primary else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.5))
	var n := _box(MINT if primary else Color(1, 1, 1, 0.05), 999, Color.TRANSPARENT if primary else Color(MINT, 0.5), 16, 6)
	var h := _box(MINT.lightened(0.15) if primary else Color(1, 1, 1, 0.1), 999, Color.TRANSPARENT if primary else MINT, 16, 6)
	var p := _box(MINT.darkened(0.12) if primary else Color(1, 1, 1, 0.02), 999, Color.TRANSPARENT if primary else MINT, 16, 6)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if icon_name != "":
		b.icon = main.ph(icon_name)
		b.add_theme_constant_override("icon_max_width", 20 if primary else 16)
		b.add_theme_constant_override("h_separation", 9)
	b.pressed.connect(func(): AudioManager.play_click())
	b.pressed.connect(cb)
	return b

func _link(t: String, cb: Callable, color := MINT) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 14)
	for k in ["font_color", "font_focus_color"]: b.add_theme_color_override(k, color)
	b.add_theme_color_override("font_hover_color", color.lightened(0.25))
	b.add_theme_color_override("font_pressed_color", color.darkened(0.15))
	b.pressed.connect(cb)
	return b

func _field(key: String, placeholder: String, secret := false, kb := LineEdit.KEYBOARD_TYPE_DEFAULT) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.secret_character = "•"
	e.virtual_keyboard_type = kb
	e.custom_minimum_size.y = 44
	e.add_theme_font_size_override("font_size", 16)
	e.add_theme_color_override("font_color", Color.WHITE)
	e.add_theme_color_override("font_placeholder_color", Color(FAINT, 0.85))
	e.add_theme_color_override("caret_color", MINT)
	e.add_theme_stylebox_override("normal", _box(Color(0.02, 0.13, 0.16, 0.6), 999, Color("#2d6d76"), 18, 6))
	e.add_theme_stylebox_override("focus", _box(Color(0.02, 0.13, 0.16, 0.75), 999, MINT, 18, 6))
	e.text = str(_typed.get(key, ""))
	e.text_changed.connect(func(t): _typed[key] = t)
	e.text_submitted.connect(func(_t): _submit())
	_fields[key] = e
	return e

func _row(items: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	for it in items:
		it.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(it)
	return h

# ------------------------------------------------------------------ state
func _refresh() -> void:
	var B = Backend
	var U = Updater
	var key := str([B.state, B.op, B.display_name, B.sync_state, B.sync_error, B.conflict.is_empty(), B.message, U.state,
		int(U.progress * 50.0), U.error, VF.level, VF.biome, form, _short()])
	if key == _key: return
	_key = key
	if B.state == "signed_in" and form != "": form = ""         # signed in from the form: back to Play
	if U.state == "error" and not _retried:
		_retried = true
		get_tree().create_timer(2.5).timeout.connect(func():
			if Updater.state == "error":
				Updater.state = "idle"
				Updater.check())
	_rebuild()

func _rebuild() -> void:
	for k in _fields:
		if is_instance_valid(_fields[k]): _typed[k] = _fields[k].text      # (typed text survives a rebuild)
	for c in col.get_children(): c.queue_free()
	for c in foot.get_children(): c.queue_free()
	_fields.clear()
	var B = Backend
	var short := _short()
	var open := form != ""
	# greeting
	var hello := "Welcome, fisher!"
	var sub := "Your fish are saved on this device. Sign in to keep them safe in the cloud too."
	var sub_col := SOFT
	if not B.configured():
		sub = "Your progress is saved on this device."
	match B.state:
		"signed_in":
			hello = "Welcome back, %s!" % (B.display_name if B.display_name != "" else "fisher")
			match B.sync_state:
				"syncing": sub = "Saving your fish to the cloud…"
				"error":
					sub = B.sync_error
					sub_col = Color("#ff9d8f")
				"conflict":
					sub = "This device and your cloud save differ. Pick the one to keep."
					sub_col = Color("#ffd27a")
				_: sub = "Your cloud save is synced."
		"busy":
			sub = "Signing in…"
		"offline":
			hello = "Welcome back!"
			sub = "You're offline. Your progress is kept here and syncs when you're back."
	if open:
		hello = "Sign in" if form == "sign_in" else "Create your account"
		sub = "Your progress comes with you to any device." if form == "sign_in" else "Free. Keeps your fish safe and puts you on the leaderboard."
	if not (short and open):
		var tile := CenterContainer.new()
		var tp := PanelContainer.new()
		tp.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.08), 22, Color(MINT, 0.35), 8, 8))
		var ic: TextureRect = main.icon(load(ICON), 64 if not short else 42)
		tp.add_child(ic)
		tile.add_child(tp)
		col.add_child(tile)
	var title := _text(hello, 30 if not short else 25, Color.WHITE)
	title.add_theme_font_override("font", bold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	var sl := _wrap(sub, 15, sub_col)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sl)
	col.add_child(_gap(4))
	if open:
		_form_rows()
	else:
		play_btn = _button("Play", true, play, "play", 58 if not short else 52)
		play_btn.add_theme_font_size_override("font_size", 24)
		col.add_child(play_btn)
		var fresh: bool = VF.level <= 1 and VF.stats.trips == 0
		var ps := _text("New game: welcome aboard!" if fresh else "Continue  ·  Lv %s  ·  %s  ·  %s" % [VF.commas(VF.level), VF.biome, main.money_str(VF.money)], 13, FAINT)
		ps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(ps)
		if B.configured():
			col.add_child(_gap(2))
			match B.state:
				"signed_in":
					if not B.conflict.is_empty():
						col.add_child(_row([_button("Choose my save", false, func(): main._open_panel("account", "Account"), "cloud-arrow-up", 40)]))
					else:
						col.add_child(_row([_button("Account", false, func(): main._open_panel("account", "Account"), "user-circle", 40),
							_button("Leaderboard", false, func(): main._open_panel("account", "Leaderboard"), "trophy", 40)]))
				"signed_out":
					col.add_child(_row([_button("Sign in", false, func(): _open_form("sign_in"), "sign-in", 40),
						_button("Create account", false, func(): _open_form("sign_up"), "user-circle", 40)]))
	col.add_child(_gap(4))
	col.add_child(_update_strip())
	# footer: settings (and quit on desktop) + version
	foot.add_child(_link("Settings", func(): main._open_panel("settings"), FAINT))
	if OS.get_name() in ["Windows", "Linux", "macOS"]:
		foot.add_child(_link("Quit", func(): get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST), FAINT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var v := _text("fosh&fish %s" % main.VERSION, 13, Color(FAINT, 0.8))
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(v)
	foot.custom_minimum_size.x = _panel_w() - (68.0 if not short else 52.0)

func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size.y = h
	return g

func _form_rows() -> void:
	var B = Backend
	if form == "sign_up":
		col.add_child(_field("name", "Fisher name (on the leaderboard)"))
	col.add_child(_field("email", "Email", false, LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS))
	col.add_child(_field("password", "Password" if form == "sign_in" else "Password (6+ characters)", true, LineEdit.KEYBOARD_TYPE_PASSWORD))
	var busy: bool = B.state == "busy"
	var go := _button(("Signing in…" if form == "sign_in" else "Creating…") if busy else ("Sign in" if form == "sign_in" else "Create account"),
		true, _submit, "sign-in" if form == "sign_in" else "user-circle", 48)
	go.disabled = busy
	col.add_child(go)
	if B.message != "":
		var m := _wrap(B.message, 14, Color("#ff9d8f") if B.message_kind == "error" else (MINT if B.message_kind == "good" else SOFT))
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(m)
	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 18)
	links.add_child(_link("Back", func(): _open_form("")))
	if form == "sign_in":
		links.add_child(_link("Forgot password?", func():
			main._open_panel("account", "Account")
			if main.account_ui: main.account_ui._set_mode("forgot")))
		links.add_child(_link("Create account", func(): _open_form("sign_up")))
	else:
		links.add_child(_link("I have an account", func(): _open_form("sign_in")))
	col.add_child(links)
	var first: LineEdit = _fields.get("name" if form == "sign_up" else "email")
	if first and first.text == "" and not main.is_touch():
		first.call_deferred("grab_focus")

func _open_form(f: String) -> void:
	form = f
	_typed.erase("password")
	Backend.message = ""
	_key = ""
	_refresh()

func _submit() -> void:
	var B = Backend
	if B.state == "busy": return
	var mail := str(_typed.get("email", ""))
	var pw := str(_typed.get("password", ""))
	if form == "sign_in":
		B.sign_in(mail, pw)
	elif form == "sign_up":
		B.sign_up(mail, pw, str(_typed.get("name", "")))
	_key = ""
	_refresh()

func _update_strip() -> Control:
	var U = Updater
	var newest: String = String(U.latest.get("version", ""))
	var box := PanelContainer.new()
	var hot: bool = U.state in ["available", "full_needed", "ready"]
	box.add_theme_stylebox_override("panel", _box(Color(MINT, 0.12) if hot else Color(1, 1, 1, 0.04), 16,
		Color(MINT, 0.45) if hot else Color.TRANSPARENT, 14, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var icon_name := "arrow-circle-up"
	var line := "Checking for updates…"
	var action: Button = null
	match U.state:
		"up_to_date":
			icon_name = "check"
			line = "Up to date  ·  version %s" % main.VERSION
		"available":
			var web: bool = U.platform() == "web"
			var mb := float(U.patch_info().get("size", 0)) / 1048576.0
			line = "Version %s is out!" % newest + ("" if web else "  (%.1f MB)" % mb)
			action = _button("Reload" if web else "Update", true, U.download, "", 34)
		"full_needed":
			line = "Version %s needs a new download" % newest
			action = _button("Get it", true, U.open_downloads, "", 34)
		"downloading":
			line = "Updating to %s…  %d%%" % [newest, int(U.progress * 100.0)]
		"ready":
			icon_name = "check"
			var android: bool = U.platform() == "android"
			line = "Update %s is ready" % newest
			action = _button("Close game" if android else "Restart", true, U.restart, "", 34)
		"error":
			line = "Couldn't check for updates"
			action = _button("Retry", false, func():
				U.state = "idle"
				U.check(), "", 34)
	var ic: TextureRect = main.icon(main.ph(icon_name), 18)
	ic.modulate = MINT if U.state in ["up_to_date", "available", "ready"] else FAINT
	h.add_child(ic)
	var l := _wrap(line, 14, Color.WHITE if hot else SOFT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	if action:
		action.add_theme_font_size_override("font_size", 14)
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(action)
	if U.state == "downloading":
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 6
		bar.value = U.progress * 100.0
		bar.add_theme_stylebox_override("background", _box(Color(1, 1, 1, 0.1), 999, Color.TRANSPARENT, 0, 0))
		bar.add_theme_stylebox_override("fill", _box(MINT, 999, Color.TRANSPARENT, 0, 0))
		v.add_child(bar)
	return box

# ------------------------------------------------------------------ play
func play() -> void:
	if _leaving: return
	_leaving = true
	_leave_t = _t
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	main._launcher_closing()
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_slide", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_delay(0.15)
	tw.chain().tween_callback(queue_free)

func _unhandled_key_input(e: InputEvent) -> void:
	if _leaving or main.overlay.visible or form != "": return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		play()

extends Control
## Title screen ("launcher"): the first thing players see. The game's own River at golden hour, seen from the water
## (tools/blender/vf_brand.py, tools/art/make_brand.py), brought to life: the water shimmers, the trees sway, the boat
## bobs, a gull goes by, now and then a fish jumps. On the left the logo and what you came for: Play, signing in /
## creating an account right there, and the update status when there's something to do about it. And a daft tip.
## vf_main shows it at start (not in captures / recordings unless --launcher) and hides it on Play.

const BG := "res://assets/launcher/title_bg.jpg"
const MASKS := "res://assets/launcher/title_masks.png"
const BOAT := "res://assets/launcher/title_boat.png"
const LOGO := "res://assets/brand/logo.png"                 # tools/art/make_brand.py
const BOAT_BOX := Rect2(0.5391, 0.6481, 0.339, 0.2926)      # where the boat's picture goes, in the big picture (fractions)
const BOBBER := Vector2(0.5486, 0.93)
const LANTERNS := [Vector2(0.582, 0.558), Vector2(0.76, 0.528)]

const GOLD := Color("#ffcf4a")
const MINT := Color("#7ff0cf")
const INK := Color("#2b2110")
const SOFT := Color("#e4f1ee")
const FAINT := Color("#b9d3d0")
const SHADE := Color("#06262e")

const TIPS := ["Tip: fish can't read this.", "Tip: hold to reel. Let go to regret.", "Tip: the crabs know what you did.",
	"Tip: gulls don't pay rent.", "Tip: poke things. They love it. Mostly.", "Tip: a bigger boat won't fill the void. Buy it anyway.",
	"Tip: that's not a rock. Or is it?", "Tip: the fish have been warned about you.", "Tip: never trust a fish in a moustache.",
	"Tip: the shopkeeper remembers everything.", "Tip: honk your boat. It helps nobody.", "Tip: the sea is big. You'll be fine. Probably."]
const JUMPERS := ["Raw Salmon", "Cod", "Tropical Fish", "Pufferfish", "Raw Fish"]

const SHADER := """
shader_type canvas_item;
uniform sampler2D masks : filter_linear, repeat_disable;
uniform sampler2D noise : filter_linear, repeat_enable;
void fragment() {
	vec2 uv = UV;
	vec3 m = texture(masks, uv).rgb;
	float t = TIME;
	vec2 n = texture(noise, uv * vec2(2.5, 4.5) + vec2(t * 0.010, t * 0.017)).rg - 0.5;
	vec2 wobble = n * 0.0022 * m.r;
	vec2 sway = vec2(sin(t * 1.25 + uv.y * 5.0 + uv.x * 9.0) * 0.0016, cos(t * 1.05 + uv.x * 4.0) * 0.0006) * m.g;
	vec4 c = texture(TEXTURE, uv + wobble + sway);
	float a = texture(noise, uv * vec2(16.0, 30.0) + vec2(-t * 0.03, t * 0.05)).r;
	float b = texture(noise, uv * vec2(23.0, 41.0) + vec2(t * 0.04, -t * 0.02)).r;
	float patch = smoothstep(0.55, 0.75, texture(noise, uv * 1.3 + vec2(t * 0.006, 0.0)).r);
	float glint = smoothstep(0.86, 0.93, a * b * 2.0) * m.r * patch;
	c.rgb += vec3(1.0, 0.96, 0.84) * glint * 0.3;
	COLOR = c;
}
"""

var main
var art: Control
var under: Control                      # ripples and a jumping fish, under the boat
var boat_layer: Control
var over: Control                       # a gull, the lamps' glow
var shade: Control                      # the side the words are on gets darker, so they read
var tex: Texture2D
var boat_tex: Texture2D
var glow: Texture2D
var bold: FontVariation
var logo: TextureRect
var col: VBoxContainer                  # the logo's column
var foot: HBoxContainer
var tip_box: PanelContainer
var tip_lbl: Label
var play_btn: Button
var form := ""                          # "" | sign_in | sign_up: the account form open in the column
var _fields := {}
var _typed := {}                        # what was typed in the form (kept across rebuilds)
var _t := 0.0
var _gull_t := -3.0
var _slide := 1.0                       # 1 = the column is off to the left (entrance / exit)
var _leaving := false
var _leave_t := 0.0
var _key := ""
var _retried := false                   # one quiet automatic retry if the first update check fails
var _jump := {}
var _jump_wait := 2.5
var _rings := []
var _tip_i := 0
var _tip_t := 0.0
var _life := {}

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
	boat_tex = load(BOAT)
	_life = main.stage.manifest.get("life", {})
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
	under = _layer(_draw_under)
	boat_layer = _layer(_draw_boat)
	over = _layer(_draw_over)
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(1, 0.86, 0.5, 0.7))
	g.gradient.set_color(1, Color(1, 0.7, 0.3, 0.0))
	glow = g
	shade = _layer(_draw_shade)
	_build_logo()
	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	foot = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	add_child(foot)
	tip_box = PanelContainer.new()
	tip_box.add_theme_stylebox_override("panel", _box(Color(0.03, 0.14, 0.17, 0.55), 999, Color.TRANSPARENT, 16, 7))
	tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_lbl = _text("", 14, SOFT)
	tip_box.add_child(tip_lbl)
	add_child(tip_box)
	_tip_i = randi() % TIPS.size()
	tip_lbl.text = TIPS[_tip_i]
	Backend.status_changed.connect(_refresh)
	Updater.status_changed.connect(_refresh)
	resized.connect(_layout)
	_refresh()
	# entrance: the column glides in, the logo pops up
	logo.modulate.a = 0.0
	logo.scale = Vector2(0.82, 0.82)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_slide", 0.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(logo, "modulate:a", 1.0, 0.4).set_delay(0.2)
	tw.tween_property(logo, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)

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
	var zoom := 1.0 + 0.03 * (0.5 - 0.5 * cos(_t * TAU / 46.0))          # a slow breath of a camera move
	if _leaving: zoom += 0.12 * clampf((_t - _leave_t) / 0.5, 0.0, 1.0)
	var s := maxf(sz.x / ts.x, sz.y / ts.y) * zoom
	var rs := ts * s
	var drift := Vector2(0.5 + 0.03 * sin(_t * TAU / 61.0), 0.62)        # (keeps the water in view on wide phones)
	return Rect2((sz - rs) * drift, rs)

func to_screen(p: Vector2) -> Vector2:
	var r := _cover_rect()
	return r.position + p * r.size

func _draw_art() -> void:
	art.draw_texture_rect(tex, _cover_rect(), false)

func _draw_under() -> void:
	var r := _cover_rect()
	var k := r.size.x / 1920.0
	var bp := to_screen(BOBBER)                               # the float's ripples (flattened: we look at an angle)
	under.draw_set_transform(bp, 0.0, Vector2(1.0, 0.34))
	for i in 3:
		var ph := fmod(_t * 0.45 + i / 3.0, 1.0)
		under.draw_arc(Vector2.ZERO, (14.0 + 90.0 * ph) * k, 0.0, TAU, 48, Color(1, 1, 1, 0.45 * (1.0 - ph)), 2.4 * k, true)
	for q in _rings:
		var ph: float = q.t
		under.draw_set_transform(to_screen(q.at), 0.0, Vector2(1.0, 0.34))
		under.draw_arc(Vector2.ZERO, (16.0 + 110.0 * ph) * k, 0.0, TAU, 48, Color(1, 1, 1, 0.6 * (1.0 - ph)), 3.0 * k, true)
	under.draw_set_transform(Vector2.ZERO)
	if not _jump.is_empty() and not _life.is_empty():         # a fish jumps
		var t: Texture2D = _jump.tex
		var f: float = _jump.t
		var at: Vector2 = _jump.at
		var cell: float = _life.cell
		var y: float = at.y - 4.0 * _jump.h * f * (1.0 - f)
		var p := to_screen(Vector2(at.x + _jump.dir * 0.05 * (f - 0.5), y))
		var rot: float = (1.0 - 2.0 * f) * -1.05 * _jump.dir              # nose up, then nose down
		var s := 1.5 * k
		under.draw_set_transform(p, rot, Vector2(_jump.dir * s, s))
		var fr := int(_t * 12.0) % int(_life.frames)
		under.draw_texture_rect_region(t, Rect2(-cell * 0.5, -cell * 0.5, cell, cell), Rect2(fr * cell, 2.0 * cell, cell, cell))
		under.draw_set_transform(Vector2.ZERO)

func _draw_boat() -> void:
	var r := _cover_rect()
	var box := Rect2(r.position + BOAT_BOX.position * r.size, BOAT_BOX.size * r.size)
	var k := r.size.x / 1920.0
	var pivot := box.position + box.size * Vector2(0.66, 0.85)
	boat_layer.draw_set_transform(pivot + Vector2(0.0, sin(_t * 1.3) * 3.5 * k), sin(_t * 0.9) * 0.008, Vector2.ONE)
	boat_layer.draw_texture_rect(boat_tex, Rect2(box.position - pivot, box.size), false)
	boat_layer.draw_set_transform(Vector2.ZERO)

func _draw_over() -> void:
	var r := _cover_rect()
	var k := r.size.x / 1920.0
	for i in LANTERNS.size():
		var lp := to_screen(LANTERNS[i])
		var fl := 0.75 + 0.15 * sin(_t * 7.3 + i * 2.1) + 0.1 * sin(_t * 13.7 + i)
		var gs := 86.0 * k * (0.95 + 0.08 * fl)
		over.draw_texture_rect(glow, Rect2(lp - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false, Color(1, 1, 1, 0.42 * fl))
	var gull: Dictionary = _life.get("gull", {})
	if _gull_t >= 0.0 and not gull.is_empty():                # a gull crossing the sky now and then
		var t: Texture2D = main.stage._tex("life/gull.png")
		if t == null: return
		var f := _gull_t / 13.0
		var gp := r.position + r.size * Vector2(1.02 - 0.75 * f, 0.16 + 0.05 * sin(f * 5.0))
		var cell: float = gull.cell
		var fr: int = int(gull.glide) if fmod(_t, 3.2) < 1.1 else int(_t * 11.0) % int(gull.frames)
		var s := 0.92 * k
		over.draw_set_transform(gp, 0.0, Vector2(-s, s))
		over.draw_texture_rect_region(t, Rect2(-cell * 0.5, -cell * 0.5, cell, cell), Rect2(fr * cell, 2.0 * cell, cell, cell))
		over.draw_set_transform(Vector2.ZERO)

func _draw_shade() -> void:
	var w := size.x
	var h := size.y
	var c1 := Color(SHADE, 0.0)
	var edge := _col_w() + _pad() * 2.0 + 150.0
	var x := -edge * _slide * 0.6
	shade.draw_polygon(PackedVector2Array([Vector2(minf(x, 0.0), 0), Vector2(x + edge, 0), Vector2(x + edge, h), Vector2(minf(x, 0.0), h)]),
		PackedColorArray([Color(SHADE, 0.12), c1, c1, Color(SHADE, 0.68)]))       # (the sky stays clear: only the words need it)
	if form != "":                                            # an account form is open: the world steps back
		shade.draw_rect(Rect2(0, 0, w, h), Color(SHADE, 0.34))

func _tick_jump(delta: float) -> void:
	for q in _rings: q.t += delta / 1.3
	_rings = _rings.filter(func(q): return q.t < 1.0)
	if _jump.is_empty():
		_jump_wait -= delta
		if _jump_wait <= 0.0:
			var at := Vector2(randf_range(0.43, 0.53), randf_range(0.8, 0.92))    # (out on the open water, between the words and the boat)
			var who: String = JUMPERS.pick_random()
			_jump = {"at": at, "t": 0.0, "dir": 1.0 if randf() < 0.5 else -1.0, "h": randf_range(0.1, 0.17), "tex": main.stage._tex("life/%s.png" % VFData.slug(who))}
			_rings.append({"at": at, "t": 0.0})
	else:
		_jump.t += delta / 1.05
		if _jump.t >= 1.0:
			_rings.append({"at": _jump.at + Vector2(_jump.dir * 0.025, 0.0), "t": 0.0})
			_jump = {}
			_jump_wait = randf_range(4.0, 10.0)

func _process(delta: float) -> void:
	_t += delta
	_gull_t += delta
	if _gull_t > 13.0: _gull_t = -randf_range(6.0, 14.0)
	_tick_jump(delta)
	_tip_t += delta
	if _tip_t > 6.0:
		_tip_t = 0.0
		_tip_i = (_tip_i + 1) % TIPS.size()
		var tw := create_tween()
		tw.tween_property(tip_box, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func(): tip_lbl.text = TIPS[_tip_i])
		tw.tween_property(tip_box, "modulate:a", 1.0, 0.25)
	art.queue_redraw()
	under.queue_redraw()
	boat_layer.queue_redraw()
	over.queue_redraw()
	shade.queue_redraw()
	_place()
	if Engine.get_process_frames() % 20 == 0:
		_refresh()                                            # (cheap: only rebuilds when something changed)

# ------------------------------------------------------------------ layout
func _short() -> bool:
	return size.y < 600.0

func _pad() -> float:
	return 26.0 if _short() else 54.0

func _col_w() -> float:
	return clampf(size.x * 0.36, 280.0, 400.0) if _short() else clampf(size.x * 0.3, 340.0, 560.0)

func _build_logo() -> void:
	logo = TextureRect.new()
	logo.texture = load(LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

func _layout() -> void:
	_place()

## positions follow the moving column every frame (it slides in and out)
func _place() -> void:
	if size.x < 10: return
	var cw := _col_w()
	var pad := _pad()
	var x0 := pad - (cw + pad + 70.0) * _slide
	col.custom_minimum_size.x = cw
	col.add_theme_constant_override("separation", 10 if not _short() else 6)
	col.size = Vector2(cw, 0)
	col.reset_size()
	foot.custom_minimum_size.x = cw
	foot.reset_size()
	foot.position = Vector2(x0, size.y - foot.size.y - (14.0 if not _short() else 6.0))
	tip_box.visible = form == ""
	tip_box.reset_size()
	tip_box.position = Vector2(size.x - tip_box.size.x - pad * 0.6, 16.0 if not _short() else 8.0).round()
	# the logo gets the height the column leaves; together they're centred above the footer
	var room := foot.position.y - 8.0
	var ts := Vector2(logo.texture.get_size())
	var lh := minf(cw * ts.y / ts.x, room - col.size.y - 18.0)
	if form != "" and _short(): lh = 0.0
	logo.visible = lh > 70.0
	var total := col.size.y + (lh + 10.0 if logo.visible else 0.0)
	var y := maxf(8.0, (room - total) * 0.5)
	if logo.visible:
		var lw := lh * ts.x / ts.y
		logo.size = Vector2(lw, lh)
		logo.pivot_offset = logo.size * 0.5
		logo.position = Vector2(x0 + (cw - lw) * 0.5, y + sin(_t * 0.9) * 3.0)
		logo.rotation = sin(_t * 0.6) * 0.006
		y += lh + 10.0
	col.position = Vector2(x0, y)
	if is_instance_valid(play_btn):
		play_btn.pivot_offset = play_btn.size * 0.5
		var br := 1.0 + 0.012 * sin(_t * 2.1)
		play_btn.scale = Vector2(br, br)

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
	var n := _box(GOLD if primary else Color(0.03, 0.14, 0.17, 0.5), 999, Color.TRANSPARENT if primary else Color(1, 1, 1, 0.28), 16, 6)
	var h := _box(GOLD.lightened(0.14) if primary else Color(0.05, 0.2, 0.24, 0.65), 999, Color.TRANSPARENT if primary else Color(1, 1, 1, 0.6), 16, 6)
	var p := _box(GOLD.darkened(0.1) if primary else Color(0.02, 0.1, 0.13, 0.6), 999, Color.TRANSPARENT if primary else Color(1, 1, 1, 0.5), 16, 6)
	if primary:
		for s in [n, h]:
			s.shadow_color = Color(0.02, 0.08, 0.1, 0.32)
			s.shadow_size = 10
			s.shadow_offset = Vector2(0, 4)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if icon_name != "":
		b.icon = main.ph(icon_name)
		b.add_theme_constant_override("icon_max_width", 22 if primary else 16)
		b.add_theme_constant_override("h_separation", 9)
	b.pressed.connect(func(): AudioManager.play_click())
	b.pressed.connect(cb)
	return b

func _link(t: String, cb: Callable, color := SOFT) -> Button:
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
	e.add_theme_stylebox_override("normal", _box(Color(0.02, 0.13, 0.16, 0.72), 999, Color(1, 1, 1, 0.25), 18, 6))
	e.add_theme_stylebox_override("focus", _box(Color(0.02, 0.13, 0.16, 0.85), 999, MINT, 18, 6))
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
	var U = Updater
	var short := _short()
	var open := form != ""
	# greeting
	var hello := "Welcome, fisher!"
	var sub := "Your fish are saved on this device."
	var sub_col := SOFT
	match B.state:
		"signed_in":
			hello = "Welcome back, %s!" % (B.display_name if B.display_name != "" else "fisher")
			match B.sync_state:
				"syncing": sub = "Saving your fish to the cloud…"
				"error":
					sub = B.sync_error
					sub_col = Color("#ffb4a6")
				"conflict":
					sub = "This device and your cloud save differ. Pick the one to keep."
					sub_col = Color("#ffd27a")
				_: sub = ""
		"busy":
			sub = "Signing in…"
		"offline":
			hello = "Welcome back!"
			sub = "You're offline. Your progress syncs when you're back."
	if open:
		hello = "Sign in" if form == "sign_in" else "Create your account"
		sub = "Your progress comes with you to any device." if form == "sign_in" else "Free. Keeps your fish safe and puts you on the leaderboard."
	var title := _text(hello, 24 if not short else 19, Color.WHITE)
	title.add_theme_font_override("font", bold)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title)
	if sub != "" and (open or not short or sub_col != SOFT):
		var sl := _wrap(sub, 14, sub_col)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(sl)
	if open:
		_form_rows()
	else:
		play_btn = _button("Play", true, play, "", 64 if not short else 50)
		play_btn.add_theme_font_size_override("font_size", 28 if not short else 22)
		col.add_child(play_btn)
		var fresh: bool = VF.level <= 1 and VF.stats.trips == 0
		var ps := _text("New game: welcome aboard!" if fresh else "Lv %s  ·  %s  ·  %s" % [VF.commas(VF.level), VF.biome, main.money_str(VF.money)], 14, SOFT)
		ps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(ps)
		if B.configured():
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
	if U.state in ["available", "full_needed", "downloading", "ready", "error"]:         # only when there's something to do
		col.add_child(_update_strip())
	# footer: settings (and quit on desktop) + version
	foot.add_child(_link("Settings", func(): main._open_panel("settings"), SOFT))
	if OS.get_name() in ["Windows", "Linux", "macOS"]:
		foot.add_child(_link("Quit", func(): get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST), SOFT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var v := _text("fosh&fish %s" % main.VERSION, 13, FAINT)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(v)

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
		var m := _wrap(B.message, 14, Color("#ffb4a6") if B.message_kind == "error" else (MINT if B.message_kind == "good" else SOFT))
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(m)
	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 18)
	links.add_child(_link("Back", func(): _open_form(""), MINT))
	if form == "sign_in":
		links.add_child(_link("Forgot password?", func():
			main._open_panel("account", "Account")
			if main.account_ui: main.account_ui._set_mode("forgot"), MINT))
		links.add_child(_link("Create account", func(): _open_form("sign_up"), MINT))
	else:
		links.add_child(_link("I have an account", func(): _open_form("sign_in"), MINT))
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
	box.add_theme_stylebox_override("panel", _box(Color(0.03, 0.14, 0.17, 0.6), 16,
		Color(MINT, 0.5) if hot else Color.TRANSPARENT, 14, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var icon_name := "arrow-circle-up"
	var line := ""
	var action: Button = null
	match U.state:
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
	ic.modulate = MINT if U.state in ["available", "ready"] else FAINT
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

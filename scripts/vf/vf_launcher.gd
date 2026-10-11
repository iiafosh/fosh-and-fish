extends Control
## Title screen ("launcher"): the first thing players see. Account + cloud save, game updates and
## Play, over the owner's title illustration brought to life (water shimmer and glints, swaying leaves,
## bobber ripples, lantern glow, a passing gull, a slow camera drift). Art: tools/art/make_launcher.py.
## vf_main shows it at start (not in captures / recordings, unless --launcher) and hides it on Play.

const BG := "res://assets/launcher/launcher_bg.jpg"
const MASKS := "res://assets/launcher/launcher_masks.png"
const WORDMARK := "res://assets/brand/wordmark.png"
const BOBBER := Vector2(0.3772, 0.6885)                     # points in the picture (fractions)
const LANTERNS := [Vector2(0.1356, 0.2862), Vector2(0.2663, 0.4296)]

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
var tex: Texture2D
var glow: Texture2D
var _t := 0.0
var _gull_t := -4.0                                          # seconds into the current gull flight (<0: waiting)
var logo: TextureRect
var tagline: Control
var card: PanelContainer
var acct_box: VBoxContainer
var upd_box: VBoxContainer
var play_btn: Button
var play_sub: Label
var corner: HBoxContainer
var _leaving := false
var _key := ""
var _retried := false            # one quiet automatic retry if the first update check fails

func setup(m) -> void:
	main = m

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP                  # nothing reaches the game underneath
	theme = main.theme
	tex = load(BG)
	art = Control.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	art.draw.connect(_draw_art)
	add_child(art)
	var fx := Control.new()                                   # ripples, glows and the gull (no shader)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(_draw_fx.bind(fx))
	add_child(fx)
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(1, 0.86, 0.5, 0.85))
	g.gradient.set_color(1, Color(1, 0.7, 0.3, 0.0))
	glow = g
	var vig := TextureRect.new()                              # soft edges + a darker right side for the card
	var vg := GradientTexture2D.new()
	vg.fill_from = Vector2(0.45, 0.5)
	vg.fill_to = Vector2(1.0, 0.5)
	vg.gradient = Gradient.new()
	vg.gradient.set_color(0, Color(0.02, 0.1, 0.16, 0.0))
	vg.gradient.set_color(1, Color(0.02, 0.1, 0.16, 0.38))
	vig.texture = vg
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	_build_logo()
	_build_card()
	_build_corner()
	Backend.status_changed.connect(_refresh)
	Updater.status_changed.connect(_refresh)
	resized.connect(_layout)
	_layout()
	_refresh()
	# entrance
	logo.modulate.a = 0.0
	card.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(logo, "modulate:a", 1.0, 0.6).set_delay(0.15)
	tw.tween_property(card, "modulate:a", 1.0, 0.5).set_delay(0.35)
	var sp := create_tween().set_loops()                      # Play breathes a little
	sp.tween_property(play_btn, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE)
	sp.tween_property(play_btn, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)

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

func _draw_fx(c: Control) -> void:
	var r := _cover_rect()
	var k := r.size.x / 1920.0
	# bobber ripples (flattened rings: we look at the water at an angle)
	var bp := to_screen(BOBBER)
	c.draw_set_transform(bp, 0.0, Vector2(1.0, 0.42))
	for i in 3:
		var ph := fmod(_t * 0.45 + i / 3.0, 1.0)
		c.draw_arc(Vector2.ZERO, (10.0 + 70.0 * ph) * k, 0.0, TAU, 48, Color(1, 1, 1, 0.55 * (1.0 - ph)), 2.0 * k, true)
	c.draw_set_transform(Vector2.ZERO)
	# lanterns
	for i in LANTERNS.size():
		var lp := to_screen(LANTERNS[i])
		var fl := 0.75 + 0.15 * sin(_t * 7.3 + i * 2.1) + 0.1 * sin(_t * 13.7 + i)
		var gs := 120.0 * k * (0.95 + 0.08 * fl)
		c.draw_texture_rect(glow, Rect2(lp - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false, Color(1, 1, 1, 0.55 * fl))
	# a gull crossing the sky now and then
	if _gull_t >= 0.0:
		var f := _gull_t / 11.0
		var gp := Vector2(r.position.x + r.size.x * (1.08 - 1.25 * f), r.position.y + r.size.y * (0.16 + 0.05 * sin(f * 5.0)))
		var flap := sin(_t * 9.0)
		var w := 15.0 * k
		var pts := PackedVector2Array([gp + Vector2(-w, -w * 0.35 * flap - 2 * k), gp + Vector2(-w * 0.45, -w * 0.2 * flap - 5 * k * flap),
			gp, gp + Vector2(w * 0.45, -w * 0.2 * flap - 5 * k * flap), gp + Vector2(w, -w * 0.35 * flap - 2 * k)])
		c.draw_polyline(pts, Color(0.2, 0.25, 0.3, 0.35), 4.0 * k, true)
		c.draw_polyline(pts, Color(1, 1, 1, 0.95), 2.4 * k, true)

var _leave_t := 0.0

func _process(delta: float) -> void:
	_t += delta
	_gull_t += delta
	if _gull_t > 11.0: _gull_t = -randf_range(6.0, 12.0)
	art.queue_redraw()
	get_child(1).queue_redraw()
	if Engine.get_process_frames() % 20 == 0:
		_refresh()                                            # (cheap: only rebuilds when something changed)

# ------------------------------------------------------------------ layout
func _build_logo() -> void:
	logo = TextureRect.new()
	logo.texture = load(WORDMARK)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	var tg := PanelContainer.new()
	tg.add_theme_stylebox_override("panel", main.sbox(Color(0.06, 0.2, 0.26, 0.55), 999, 0, Color.TRANSPARENT, 14, 0))
	tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl: Label = main.lbl("a cozy fishing game  ·  by afosh", 15, Color(1, 1, 1, 0.95))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tg.add_child(tl)
	tagline = tg
	logo.add_child(tg)

func _build_card() -> void:
	card = PanelContainer.new()
	var sb: StyleBoxFlat = main.sbox(Color(main.C_PANEL, 0.94), 26, 1, Color.WHITE, 20, 24)
	sb.shadow_offset = Vector2(0, 10)
	sb.shadow_color = Color(0.02, 0.1, 0.16, 0.35)
	card.add_theme_stylebox_override("panel", sb)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	acct_box = VBoxContainer.new()
	acct_box.add_theme_constant_override("separation", 8)
	v.add_child(acct_box)
	v.add_child(_line())
	upd_box = VBoxContainer.new()
	upd_box.add_theme_constant_override("separation", 8)
	v.add_child(upd_box)
	var gap := Control.new()
	gap.custom_minimum_size.y = 2
	v.add_child(gap)
	play_btn = main.btn("Play", main.C_GOLD, 26, 0)
	play_btn.custom_minimum_size.y = 60
	play_btn.icon = main.ph("play")
	play_btn.add_theme_constant_override("icon_max_width", 22)
	play_btn.add_theme_constant_override("h_separation", 10)
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color",
			"font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		play_btn.add_theme_color_override(k, Color.WHITE)
	var bold := FontVariation.new()
	bold.base_font = load("res://assets/third_party/fonts/Fredoka.ttf")
	bold.variation_opentype = {"wght": 700}
	play_btn.add_theme_font_override("font", bold)
	play_btn.add_theme_constant_override("outline_size", 4)
	play_btn.add_theme_color_override("font_outline_color", Color(0.45, 0.27, 0.0, 0.45))
	play_btn.pressed.connect(play)
	play_btn.resized.connect(func(): play_btn.pivot_offset = play_btn.size * 0.5)
	v.add_child(play_btn)
	play_sub = main.lbl("", 13, main.C_MUTED)
	play_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(play_sub)

func _build_corner() -> void:
	corner = HBoxContainer.new()
	corner.add_theme_constant_override("separation", 10)
	add_child(corner)
	var st: Button = main.pill_button("gear-six", "Settings", "", true)
	st.pressed.connect(func(): main._open_panel("settings"))
	corner.add_child(st)
	if OS.get_name() in ["Windows", "Linux", "macOS"]:
		var q: Button = main.pill_button("x", "Quit", "", true)
		q.pressed.connect(func(): get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST))
		corner.add_child(q)

func _line() -> Control:
	var l := ColorRect.new()
	l.color = Color(0.12, 0.2, 0.25, 0.1)
	l.custom_minimum_size.y = 1
	return l

func _layout() -> void:
	var sz := size
	if sz.x < 10: return
	var short := sz.y < 600.0                                 # phones
	var lw := minf(560.0 if not short else 420.0, sz.x * 0.42)
	var lh := lw * 167.0 / 779.0
	var card_w := 370.0 if not short else 350.0
	var margin := 32.0 if not short else 18.0
	# the logo sits over the sky, centred between the left edge and the card
	var free_w := sz.x - card_w - margin * 2.0
	logo.size = Vector2(lw, lh)
	logo.position = Vector2(clampf(free_w * 0.5 - lw * 0.5 + margin * 0.5, margin, sz.x - lw - margin), (26.0 if not short else 14.0))
	tagline.position = Vector2(lw * 0.5 - tagline.size.x * 0.5, lh + 6.0)
	tagline.reset_size()
	tagline.position = Vector2(lw * 0.5 - tagline.size.x * 0.5, lh + 6.0)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_right = -margin
	card.offset_bottom = -margin
	card.offset_left = -margin - card_w
	card.offset_top = -margin
	corner.reset_size()
	corner.position = Vector2(margin, sz.y - corner.size.y - margin * 0.8)

# ------------------------------------------------------------------ state
func _refresh() -> void:
	var B = Backend
	var U = Updater
	var key := str([B.state, B.op, B.display_name, B.sync_state, B.sync_error, B.conflict.is_empty(), U.state,
		int(U.progress * 50.0), U.error, VF.level, VF.biome])
	if key == _key: return
	_key = key
	if U.state == "error" and not _retried:
		_retried = true
		get_tree().create_timer(2.5).timeout.connect(func():
			if Updater.state == "error":
				Updater.state = "idle"
				Updater.check())
	_fill_account()
	_fill_update()
	var fresh: bool = VF.level <= 1 and VF.stats.trips == 0
	play_sub.text = "New game: welcome aboard!" if fresh else "Continue  ·  Lv %s  ·  %s  ·  %s" % [VF.commas(VF.level), VF.biome, main.money_str(VF.money)]
	_layout.call_deferred()

func _row(icon_name: String, color: Color, title: String, sub: String, sub_color := Color(0, 0, 0, 0)) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var b := PanelContainer.new()
	b.add_theme_stylebox_override("panel", main.sbox(color, 999, 0, Color.TRANSPARENT, 9, 0))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic: TextureRect = main.icon(main.ph(icon_name), 22)
	b.add_child(ic)
	h.add_child(b)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(main.lbl(title, 18))
	var sl: Label = main.lbl(sub, 13, sub_color if sub_color.a > 0 else main.C_MUTED)
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size.x = 220
	tv.add_child(sl)
	h.add_child(tv)
	return h

func _buttons(items: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for it in items:                                          # [text, color, callable, expand]
		var b: Button = main.btn(it[0], it[1], 14, 0)
		b.custom_minimum_size.y = 36
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(it[2])
		h.add_child(b)
	return h

func _fill_account() -> void:
	for c in acct_box.get_children(): c.queue_free()
	var B = Backend
	if not B.configured():
		acct_box.add_child(_row("user-circle", main.C_MUTED, "Playing on this device", "Your progress is saved here."))
		return
	match B.state:
		"busy":
			acct_box.add_child(_row("cloud-arrow-up", main.C_TEAL, "Signing in…", "Getting your cloud save ready."))
		"signed_in":
			var name: String = B.display_name if B.display_name != "" else B.email
			var sub := "Cloud save on  ·  synced"
			var col := Color(0, 0, 0, 0)
			match B.sync_state:
				"syncing": sub = "Saving to the cloud…"
				"error":
					sub = B.sync_error
					col = main.C_BAD
				"conflict":
					sub = "This device and your cloud save differ: pick one."
					col = main.C_GOLD
			acct_box.add_child(_row("user-circle", main.C_GOOD, name, sub, col))
			if not B.conflict.is_empty():
				acct_box.add_child(_buttons([["Choose my save", main.C_GOLD, func(): main._open_panel("account", "Account"), true]]))
			else:
				acct_box.add_child(_buttons([["Account", main.C_NEUTRAL, func(): main._open_panel("account", "Account"), true],
					["Leaderboard", main.C_NEUTRAL, func(): main._open_panel("account", "Leaderboard"), true]]))
		"offline":
			acct_box.add_child(_row("cloud-arrow-up", main.C_MUTED, B.display_name if B.display_name != "" else "Offline",
				"Offline: your progress is kept here and syncs when you're back."))
		_:
			acct_box.add_child(_row("user-circle", main.C_TEAL, "Not signed in", "Sign in to back up your fish and play on any device."))
			acct_box.add_child(_buttons([["Sign in", main.C_TEAL, func(): _account("sign_in"), true],
				["Create account", main.C_NEUTRAL, func(): _account("sign_up"), true]]))

func _account(mode: String) -> void:
	main._open_panel("account", "Account")
	if main.account_ui and main.account_ui.mode != mode:
		main.account_ui._set_mode(mode)

func _fill_update() -> void:
	for c in upd_box.get_children(): c.queue_free()
	var U = Updater
	var newest: String = String(U.latest.get("version", ""))
	var ver := "Version %s" % main.VERSION
	match U.state:
		"idle", "checking":
			upd_box.add_child(_row("arrow-circle-up", main.C_MUTED, ver, "Checking for updates…"))
		"up_to_date":
			upd_box.add_child(_row("check", main.C_GOOD, ver, "You have the newest version."))
		"available":
			var web: bool = U.platform() == "web"
			var mb := float(U.patch_info().get("size", 0)) / 1048576.0
			upd_box.add_child(_row("arrow-circle-up", Color("#3fae6a"), "Update %s is out!" % newest,
				"Reload to play it." if web else "%.1f MB · your progress is kept." % mb))
			upd_box.add_child(_buttons([["Reload now" if web else "Update now", Color("#3fae6a"), U.download, true]]))
		"full_needed":
			upd_box.add_child(_row("arrow-circle-up", main.C_TEAL, "Version %s is out" % newest, "It needs a new download (one time). Your progress is kept."))
			upd_box.add_child(_buttons([["Open downloads", main.C_TEAL, U.open_downloads, true]]))
		"downloading":
			upd_box.add_child(_row("arrow-circle-up", Color("#3fae6a"), "Updating to %s" % newest, "Downloading… %d%%" % int(U.progress * 100.0)))
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size.y = 10
			bar.value = U.progress * 100.0
			upd_box.add_child(bar)
		"ready":
			var android: bool = U.platform() == "android"
			upd_box.add_child(_row("check", main.C_GOOD, "Update %s is ready" % newest,
				"Close the game and open it again." if android else "Restart to play it."))
			upd_box.add_child(_buttons([["Close game" if android else "Restart now", Color("#3fae6a"), U.restart, true]]))
		"error":
			upd_box.add_child(_row("arrow-circle-up", main.C_BAD, ver, U.error, main.C_BAD))
			upd_box.add_child(_buttons([["Try again", main.C_NEUTRAL, func():
				U.state = "idle"
				U.check(), true]]))

# ------------------------------------------------------------------ play
func play() -> void:
	if _leaving: return
	_leaving = true
	_leave_t = _t
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	main._launcher_closing()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_delay(0.12)
	tw.tween_callback(queue_free)

func _unhandled_key_input(e: InputEvent) -> void:
	if _leaving or main.overlay.visible: return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		play()

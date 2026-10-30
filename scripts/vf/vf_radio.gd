extends RefCounted
## The soundtrack on the main screen (vf_main): the pill that says what's playing, the Radio panel (Menu -> Radio) and
## "Just listen", where the interface fades away and the game plays by itself to the music.
## The music itself is in AudioManager. Built with vf_main's UI kit (sbox, lbl, btn, icon, ph, _grid, _add_to).

const C_TEAL := Color("#1d9bb0")
const C_MUTED := Color("#6b7d86")
const C_PINK := Color("#db2777")

var m                                 # vf_main
var pill: PanelContainer
var _pill_title: Label
var _pill_tw: Tween
var listening := false                # "Just listen" is on
var _catcher: Control
var _now: Label
var _hint: Label
var _auto_before := false


func _init(main) -> void:
	m = main
	AudioManager.track_changed.connect(_on_track)


# ===================================================================== HUD
## what's playing: shows for a moment when a track starts, above the Auto button (click: the Radio)
func build_hud() -> void:
	pill = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", m.pill_box(false, 12, 5))
	pill.anchor_left = 1.0
	pill.anchor_right = 1.0
	pill.anchor_top = 1.0
	pill.anchor_bottom = 1.0
	pill.offset_right = -112
	pill.offset_top = -170
	pill.offset_bottom = -135
	pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pill.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			m._open_panel("radio")
			pill.accept_event())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	var ic: TextureRect = m.icon(m.ph("music-notes"), 17)
	ic.modulate = Color("#7ef0c6")
	h.add_child(ic)
	_pill_title = m.lbl("", 13, Color.WHITE)
	h.add_child(_pill_title)
	pill.add_child(h)
	pill.visible = false
	m.add_child(pill)
	m.move_child(pill, m.mode_pill.get_index() + 1)          # (under the menus)


func _on_track(slug: String) -> void:
	if _now != null: _now.text = _title_line(slug)
	if pill == null or m.launcher_open() or listening: return
	_pill_title.text = _title_line(slug)
	pill.visible = true
	pill.modulate.a = 1.0
	if _pill_tw: _pill_tw.kill()
	_pill_tw = pill.create_tween()
	_pill_tw.tween_interval(6.0)
	_pill_tw.tween_property(pill, "modulate:a", 0.0, 0.8)
	_pill_tw.tween_callback(func(): pill.visible = false)
	if m.overlay.visible and m._panel_kind == "radio": m._render_panel()


func _title_line(slug: String) -> String:
	return "%s  ·  %s" % [AudioManager.TRACKS.get(slug, [slug])[0], AudioManager.COMPOSER]


# =================================================================== panel
func panel_radio() -> void:
	var A = AudioManager
	var now: Array = A.TRACKS.get(A.track, ["-", "", ""])
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", m.sbox(Color("#0b3a44"), 16, 0, Color.TRANSPARENT, 16))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	box.add_child(h)
	var ic: TextureRect = m.icon(m.ph("music-notes"), 46)
	ic.modulate = Color("#7ef0c6")
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.add_child(m.lbl(now[0], 22, Color.WHITE))
	v.add_child(m.lbl("%s  ·  %s" % [A.COMPOSER, now[1]], 13, Color(1, 1, 1, 0.72)))
	h.add_child(v)
	for b in [["caret-left", A.music_prev], ["pause" if A.music_is_playing() else "play", A.music_toggle_pause], ["caret-right", A.music_next]]:
		var cb: Callable = b[1]
		var t: Button = m.btn("", C_TEAL, 15, 46)
		t.icon = m.ph(b[0])
		t.expand_icon = true
		t.custom_minimum_size = Vector2(52, 46)
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.pressed.connect(func():
			cb.call()
			m._render_panel())
		h.add_child(t)
	m.panel_body.add_child(box)
	# what the radio does
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var listen: Button = m.btn("Just listen", C_PINK, 16, 170)
	listen.tooltip_text = "The menus fade away and the game plays by itself to the music. Tap to come back."
	listen.pressed.connect(start_listening)
	row.add_child(listen)
	var follow: Button = m.btn("Music follows where I fish" if not A.music_pick else "Back to the music of where I fish", C_TEAL if not A.music_pick else m.C_NEUTRAL, 14)
	follow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	follow.disabled = not A.music_pick
	follow.pressed.connect(func():
		A.music_follow_place()
		m._render_panel())
	row.add_child(follow)
	m.panel_body.add_child(row)
	# every track
	var g: GridContainer = m._grid(2)
	for slug in A.TRACKS:
		var d: Array = A.TRACKS[slug]
		var here: bool = slug == A.track
		var play: Button = m.btn("Playing" if here else "Play", C_PINK if here else C_TEAL, 13, 78)
		play.disabled = here
		play.pressed.connect(func():
			A.music_choose(slug)
			m._render_panel())
		var c: PanelContainer = m.idle._card(m.ph("music-notes"), d[0], "%s\n%s  ·  %s" % [d[1], _where(slug), d[2]], play, false, 34, C_PINK if here else C_TEAL)
		m._add_to(g, c)
	m.idle._note(A.MUSIC_CREDIT, C_MUTED, 12)


## where a track plays by itself
func _where(slug: String) -> String:
	var out := []
	for st in AudioManager.STATIONS:
		if slug in AudioManager.STATIONS[st]: out.append("At night" if st == "night" else st)
	return ", ".join(out)


# ============================================================= just listening
func start_listening() -> void:
	m._close_panel()
	listening = true
	_auto_before = VF.auto_on
	if VF.auto_unlocked() and not VF.auto_on: VF.set_auto(true)
	_catcher = Control.new()
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_catcher.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed: stop_listening())
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -26
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_now = m.lbl(_title_line(AudioManager.track), 17, Color(1, 1, 1, 0.92), 5)
	_now.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint = m.lbl("Tap anywhere to come back", 13, Color(1, 1, 1, 0.8), 4)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_now)
	box.add_child(_hint)
	_catcher.add_child(box)
	m.add_child(_catcher)
	_hint.create_tween().tween_interval(5.0).finished.connect(func():
		if is_instance_valid(_hint): _hint.create_tween().tween_property(_hint, "modulate:a", 0.0, 1.0))
	_fade_interface(0.0)
	m.child_entered_tree.connect(_hide_new)


func stop_listening() -> void:
	if not listening: return
	listening = false
	if VF.auto_unlocked() and VF.auto_on != _auto_before: VF.set_auto(_auto_before)
	m.child_entered_tree.disconnect(_hide_new)
	if is_instance_valid(_catcher): _catcher.queue_free()
	_catcher = null
	_now = null
	_hint = null
	_fade_interface(1.0)


func _interface() -> Array:
	return m.get_children().filter(func(c): return c is Control and c != m.stage and c != _catcher and c != m.overlay)


func _fade_interface(a: float) -> void:
	for c in _interface():
		var tw: Tween = c.create_tween()
		tw.tween_property(c, "modulate:a", a if a < 1.0 or c != pill else 0.0, 0.7)
	if a >= 1.0: pill.visible = false


## things that pop up while listening (a banner, a toast) stay out of the picture
func _hide_new(n: Node) -> void:
	if n is Control and n != _catcher and n != m.overlay: n.modulate.a = 0.0

extends RefCounted
## The look of the game's interface (1.1), after the mockup the owner picked on 2026-11-14 (tools/art/ui_mockup_source.png):
## a deep teal panel with a golden rim, a wooden plank for the title, a round red close button, glossy tabs and
## buttons, cream cards with big pictures, and the Menu's big icons (assets/vf/ui/menu, tools/art/make_menu_icons.py).
## Every panel has it, and so do the main screen's pills, cards and buttons. vf_main asks on() wherever it builds a
## frame, a tab, a card, a button, a pill or a Menu tile; finish() then turns the dark text that sits straight on the
## teal light, gives hand-made cards and text boxes the cream look, and puts a faint picture in a roomy panel's corner.
## --old-look turns it all off (the paper look of 1.0).
## Look at it: godot --path . --resolution 1280x720 -- --capture=DIR --all-panels [--old-look]

const TEAL := Color("#1e6f7c")           # the panel
const TEAL_HI := Color("#2f93a2")        # tiles, tabs
const RIM := Color("#f3c453")            # the golden rim
const CREAM := Color("#fff3d9")          # cards
const CARD_RIM := Color("#e9bf73")
const INK := Color("#3b2a1a")            # text on cream
const INK_SOFT := Color("#7b6a55")
const WOOD := Color("#a9652f")
const WOOD_DARK := Color("#5c3214")
const GOLD := Color("#ffc93c")
const GREEN := Color("#58b92f")
const RED := Color("#e8483b")
const ICONS := {"shop": "shop", "biomes": "map", "inventory": "fish_book", "charms": "charms", "quests": "quests",
	"leaderboard": "leaderboard", "derby": "derby", "party": "friends", "events": "events", "prestige": "prestige",
	"pets": "pets", "stats": "buffs", "achievements": "achievements"}

var m                                   # vf_main
var plank: PanelContainer
var sign_lbl: Label
var sign_at: Control                    # (a zero-size spot in the head row the plank hangs from)
var close: Button
var deco: TextureRect                   # the panel's own picture, big and faint in the corner of a panel with room to spare
var _old_frame: StyleBox
var _gloss := {}
var _bold: Font
var _off := false

func _init(main) -> void:
	m = main
	_off = "--old-look" in OS.get_cmdline_user_args()       # (for before-and-after pictures)

func on() -> bool:
	return not _off

func bold() -> Font:
	if _bold == null:
		var fv := FontVariation.new()
		var base: Font = m.theme.default_font
		fv.base_font = (base as FontVariation).base_font if base is FontVariation else base
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}     # (the axis by its tag: a plain "wght" key does nothing)
		_bold = fv
	return _bold

# ------------------------------------------------------------------ glossy boxes
static func _cover(px: float, py: float, x0: float, y0: float, x1: float, y1: float, r: float) -> float:
	var cx := clampf(px, x0 + r, x1 - r)
	var cy := clampf(py, y0 + r, y1 - r)
	return clampf(0.5 - (Vector2(px - cx, py - cy).length() - r), 0.0, 1.0)

## a rounded, glossy box in one colour: lighter at the top, a soft shine, a darker lip along the bottom
func gloss(col: Color, radius := 13, lip := 4, shine := 0.3) -> StyleBoxTexture:
	var key := "%s/%d/%d/%.2f" % [col.to_html(), radius, lip, shine]
	if not _gloss.has(key):
		var n := radius * 2 + 8
		var h := n + lip
		var img := Image.create(n, h, false, Image.FORMAT_RGBA8)
		var edge := Color("#c79a52") if col.get_luminance() > 0.8 else col.darkened(0.4)       # (cream and white get the cards' golden edge)
		var top := col.lightened(0.2)
		var low := col.darkened(0.07)
		for y in h:
			for x in n:
				var px := x + 0.5
				var py := y + 0.5
				var a := _cover(px, py, 0.0, 0.0, n, h, radius)
				if a <= 0.0: continue
				var face := _cover(px, py, 1.5, 1.5, n - 1.5, n - 1.0, radius - 1.5)
				var t := clampf((py - 1.5) / (n - 2.5), 0.0, 1.0)
				var c := top.lerp(col, t / 0.55) if t < 0.55 else col.lerp(low, (t - 0.55) / 0.45)
				var fade := 1.0 - clampf((py - 3.5) / (n * 0.5 - 3.5), 0.0, 1.0) * 0.75
				var glow := _cover(px, py, 4.0, 3.5, n - 4.0, n * 0.5, maxf(2.0, radius - 4.5)) * shine * fade
				c = c.lerp(Color.WHITE, glow)
				var out := edge.lerp(c, face)
				out.a = a * col.a
				img.set_pixel(x, y, out)
		var sb := StyleBoxTexture.new()
		sb.texture = ImageTexture.create_from_image(img)
		sb.texture_margin_left = radius + 3
		sb.texture_margin_right = radius + 3
		sb.texture_margin_top = radius + 3
		sb.texture_margin_bottom = radius + 3 + lip
		_gloss[key] = sb
	return (_gloss[key] as StyleBoxTexture).duplicate()

func _pad(sb: StyleBox, l: float, t: float, r: float, b: float) -> StyleBox:
	sb.content_margin_left = l
	sb.content_margin_right = r
	sb.content_margin_top = t
	sb.content_margin_bottom = b
	return sb

## vf_main.btn in the new look: the game's teal becomes the mockup's green, "buy" green becomes gold
func style_btn(b: Button, color: Color) -> void:
	if color.is_equal_approx(m.C_NEUTRAL):               # (a quiet button: cream, with dark words)
		b.add_theme_stylebox_override("normal", _pad(gloss(CREAM, 13, 3, 0.0), 12, 7, 12, 10))
		b.add_theme_stylebox_override("hover", _pad(gloss(Color.WHITE, 13, 3, 0.0), 12, 7, 12, 10))
		b.add_theme_stylebox_override("pressed", _pad(gloss(CREAM.darkened(0.1), 13, 3, 0.0), 12, 9, 12, 8))
		b.add_theme_stylebox_override("disabled", _pad(gloss(Color("#d9d5c8"), 13, 3, 0.0), 12, 7, 12, 10))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, INK)
		b.add_theme_color_override("font_disabled_color", Color(INK, 0.45))
		return
	var col := color
	if color.is_equal_approx(Color("#2f8f9e")): col = GREEN
	elif color.is_equal_approx(Color("#3fae6a")): col = Color("#f5a623")
	elif color.is_equal_approx(m.C_GOOD): col = Color("#3aa57c")
	b.add_theme_stylebox_override("normal", _pad(gloss(col), 12, 7, 12, 11))
	b.add_theme_stylebox_override("hover", _pad(gloss(col.lightened(0.1)), 12, 7, 12, 11))
	b.add_theme_stylebox_override("pressed", _pad(gloss(col.darkened(0.12)), 12, 9, 12, 9))
	b.add_theme_stylebox_override("disabled", _pad(gloss(Color("#93a7a8"), 13, 4, 0.12), 12, 7, 12, 11))
	b.add_theme_font_override("font", bold())
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.92))
	b.add_theme_color_override("font_outline_color", Color(0.08, 0.14, 0.14, 0.5))      # (one soft shade: it sits on green, gold and grey)
	b.add_theme_constant_override("outline_size", 3)
	b.custom_minimum_size.y = 40

## the pills of the main screen: cream ones to press, deep teal ones that show numbers, both with a golden rim
func pill_box(light: bool, pad_h: int, pad_v: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = m.sbox(Color(CREAM, 0.96) if light else Color(0.07, 0.3, 0.35, 0.86), 999, 2, CARD_RIM if light else Color(RIM, 0.75), 0, 5)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

func hud_box(radius: int, pad: int, shadow: int) -> StyleBoxFlat:
	return m.sbox(Color(CREAM, 0.96), radius, 2, CARD_RIM, pad, shadow)

func card_box() -> StyleBoxFlat:
	var s: StyleBoxFlat = m.sbox(CREAM, 18, 2, CARD_RIM, 12, 3)
	s.shadow_color = Color(0.03, 0.2, 0.24, 0.35)
	return s

func style_tab(b: Button, is_on: bool) -> void:
	var col := GOLD if is_on else TEAL_HI
	var shine := 0.3 if is_on else 0.14
	b.custom_minimum_size = Vector2(92, 38)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_font_override("font", bold())
	b.add_theme_stylebox_override("normal", _pad(gloss(col, 14, 3, shine), 14, 5, 14, 8))
	b.add_theme_stylebox_override("hover", _pad(gloss(col.lightened(0.1), 14, 3, shine), 14, 5, 14, 8))
	b.add_theme_stylebox_override("pressed", _pad(gloss(GOLD, 14, 3, 0.3), 14, 5, 14, 8))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, INK if is_on else Color.WHITE)

# ------------------------------------------------------------------ the frame
## made once, with the panel: the wooden plank and the round close button (hidden while a panel has the old look)
func build(head: HBoxContainer) -> void:
	sign_at = Control.new()
	sign_at.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sign_at)
	head.move_child(sign_at, 0)
	plank = PanelContainer.new()
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plank.add_theme_stylebox_override("panel", _pad(gloss(WOOD, 16, 5, 0.16), 30, 6, 30, 12))
	sign_lbl = m.lbl("", 28, Color("#fff1c9"))
	sign_lbl.add_theme_font_override("font", bold())
	sign_lbl.add_theme_constant_override("outline_size", 7)
	sign_lbl.add_theme_color_override("font_outline_color", WOOD_DARK)
	sign_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plank.add_child(sign_lbl)
	sign_at.add_child(plank)
	close = Button.new()
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.custom_minimum_size = Vector2(46, 46)
	var cross := Control.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(func():
		var c := cross.size * 0.5
		var r := 8.5
		cross.draw_line(c + Vector2(-r, -r), c + Vector2(r, r), Color.WHITE, 5.0, true)
		cross.draw_line(c + Vector2(-r, r), c + Vector2(r, -r), Color.WHITE, 5.0, true))
	close.add_child(cross)
	close.tooltip_text = "Close  [Esc]"
	var n: StyleBoxFlat = m.sbox(RED, 999, 3, Color("#ffe9b8"), 8, 5)
	close.add_theme_stylebox_override("normal", n)
	var hv: StyleBoxFlat = n.duplicate()
	hv.bg_color = RED.lightened(0.14)
	close.add_theme_stylebox_override("hover", hv)
	var pr: StyleBoxFlat = n.duplicate()
	pr.bg_color = RED.darkened(0.15)
	close.add_theme_stylebox_override("pressed", pr)
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func(): AudioManager.play_click())
	close.pressed.connect(m._close_panel)
	head.add_child(close)
	var holder := Control.new()            # (behind everything in the panel)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.panel_box.add_child(holder)
	m.panel_box.move_child(holder, 0)
	deco = TextureRect.new()
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	deco.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	deco.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	deco.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	deco.offset_left = -236
	deco.offset_top = -236
	deco.offset_right = -6
	deco.offset_bottom = -6
	deco.modulate = Color(1, 1, 1, 0.3)
	deco.visible = false
	holder.add_child(deco)
	m.panel_box.resized.connect(place_sign)
	head.sort_children.connect(place_sign)

## the plank hangs over the middle of the panel's top edge (inside it on a phone, where the panel fills the screen)
func place_sign() -> void:
	if plank == null or not plank.visible: return
	plank.reset_size()
	var box: Control = m.panel_box
	var at: Vector2 = box.get_global_transform().affine_inverse() * sign_at.get_global_transform().origin
	plank.position = Vector2(box.size.x * 0.5 - plank.size.x * 0.5, 2.0 if m.compact() else -26.0) - at

## called for every panel before it's filled: the frame of the new look, or the old one back
func frame() -> void:
	var box: PanelContainer = m.panel_box
	if _old_frame == null: _old_frame = box.get_theme_stylebox("panel")
	var is_new := on()
	if is_new:
		var sb: StyleBoxFlat = m.sbox(TEAL, 30, 4, RIM, 22, 28)
		sb.shadow_offset = Vector2(0, 10)
		sb.shadow_color = Color(0.01, 0.1, 0.13, 0.4)
		box.add_theme_stylebox_override("panel", sb)
	else:
		box.add_theme_stylebox_override("panel", _old_frame)
	m._layout_panel()
	plank.visible = is_new
	close.visible = is_new
	m.panel_title.visible = not is_new
	m.panel_close.visible = not is_new
	sign_lbl.text = m.panel_title.text
	var bar: VScrollBar = m.panel_scroll.get_v_scroll_bar()
	if is_new:
		bar.add_theme_stylebox_override("scroll", m.sbox(Color(0, 0, 0, 0.2), 999, 0, Color.TRANSPARENT, 0))
		for k in ["grabber", "grabber_highlight", "grabber_pressed"]:
			bar.add_theme_stylebox_override(k, m.sbox(RIM if k == "grabber" else RIM.lightened(0.2), 999, 0, Color.TRANSPARENT, 0))
		m.tabs_track.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		for k in ["scroll", "grabber", "grabber_highlight", "grabber_pressed"]:
			bar.remove_theme_stylebox_override(k)
	place_sign.call_deferred()

# ------------------------------------------------------------------ the Menu's tiles
func tile(kind: String, title: String, icon_name: String, key: String, what: String) -> Button:
	var b := Button.new()
	b.name = "Tile_" + kind
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(130, 142)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = what + ("   [%s]" % key if key != "" and not m.is_touch() else "")
	b.add_theme_stylebox_override("normal", gloss(TEAL_HI, 20, 5, 0.16))
	b.add_theme_stylebox_override("hover", gloss(TEAL_HI.lightened(0.12), 20, 5, 0.22))
	b.add_theme_stylebox_override("pressed", gloss(TEAL_HI.darkened(0.12), 20, 5, 0.1))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_top = 6
	v.offset_bottom = -9
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	var note: Array = m._menu_note(kind)
	var t: Texture2D = m.icon_for("ui", "menu/" + ICONS[kind]) if ICONS.has(kind) else null
	if t != null:
		var pic: TextureRect = m.icon(t, 84 if note.is_empty() else 70)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		v.add_child(pic)
	else:                                  # (no picture yet: the old round icon)
		var bubble := PanelContainer.new()
		bubble.add_theme_stylebox_override("panel", m.sbox(m.MENU_COLORS.get(kind, m.C_TEAL), 999, 2, Color(1, 1, 1, 0.5), 14))
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.add_child(m.icon(m.ph(icon_name), 36))
		v.add_child(bubble)
	var n: Label = m.lbl(title, 17, Color.WHITE)
	n.add_theme_font_override("font", bold())
	n.add_theme_constant_override("outline_size", 5)
	n.add_theme_color_override("font_outline_color", Color("#0f4650"))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	if not note.is_empty():
		var s: Label = m.lbl(String(note[0]), 13, Color("#c8ff6a") if note[1] == m.C_GOOD else Color("#ffe08a"))
		s.add_theme_font_override("font", bold())
		s.add_theme_constant_override("outline_size", 4)
		s.add_theme_color_override("font_outline_color", Color("#0f4650"))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
	b.add_child(v)
	b.pressed.connect(func(): AudioManager.play_click())
	b.pressed.connect(func(): m._open_panel(kind))
	return b

# ------------------------------------------------------------------ text on teal
## the same colour, made for the dark teal: the game's inks become light, anything else dark gets brighter
func light(c: Color) -> Color:
	if c.a < 0.05 or c.get_luminance() > 0.6: return c
	var known := [[m.C_TEXT, Color("#fff8e6")], [m.C_MUTED, Color("#c2e6e9")], [m.C_GOOD, Color("#a4f5be")],
		[m.C_GOLD, Color("#ffd866")], [m.C_BAD, Color("#ffb3a3")], [m.C_TEAL, Color("#a8eef5")]]
	for k in known:
		if c.is_equal_approx(Color(k[0], c.a)): return Color(k[1], c.a)
	return Color.from_hsv(c.h, c.s * 0.45, 1.0, c.a)

## 1 = a light box (a card: its text stays dark), 0 = a dark box, -1 = not a box
static func _box_kind(n: Node) -> int:
	if not (n is PanelContainer): return -1
	var sb: StyleBox = (n as PanelContainer).get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var bg: Color = (sb as StyleBoxFlat).bg_color
		if bg.a < 0.4: return -1
		return 1 if bg.get_luminance() > 0.6 else 0
	return -1

## after a panel is filled: old paper cards get the cream look, and text straight on the teal turns light
func finish() -> void:
	deco.visible = false
	if not on(): return
	_walk(m.panel_body, false)
	_deco.call_deferred(m._panel_kind)

const DECO := {"guide": "guide", "settings": "settings", "daily": "daily", "aquarium": "fish_book", "store": "shop",
	"fleet": "shop", "boosts": "buffs", "wanted": "fish_book", "account": "friends", "update": "guide", "radio": "events"}

## a panel with a lot of room left (the Derby, the Leaderboard, Friends) gets its picture in the corner
func _deco(kind: String) -> void:
	for i in 2: await m.get_tree().process_frame            # (wrapped text knows its height now)
	if kind != m._panel_kind or kind == "menu" or m.compact(): return
	var pic: String = ICONS.get(kind, DECO.get(kind, ""))
	if pic == "" or m.panel_body.get_combined_minimum_size().y > m.panel_scroll.size.y - 215.0: return
	deco.texture = m.icon_for("ui", "menu/" + pic)
	deco.visible = deco.texture != null

## a box to type in, on the teal: cream, with dark words
func field(e: Control) -> void:
	e.add_theme_stylebox_override("normal", m.sbox(CREAM, 12, 2, CARD_RIM, 10))
	var f: StyleBoxFlat = m.sbox(Color.TRANSPARENT, 12, 3, RIM, 10)
	f.draw_center = false                                  # (drawn over the box: only its rim)
	e.add_theme_stylebox_override("focus", f)
	e.add_theme_stylebox_override("read_only", m.sbox(CREAM.darkened(0.08), 12, 2, CARD_RIM, 10))
	for k in ["font_color", "caret_color", "font_selected_color"]:
		e.add_theme_color_override(k, INK)
	e.add_theme_color_override("font_placeholder_color", Color(INK_SOFT, 0.75))

func _walk(n: Node, on_light: bool) -> void:
	for c in n.get_children():
		if c is Button: continue                           # (buttons bring their own colours)
		if c is LineEdit or c is TextEdit:
			field(c)
			continue
		var here := on_light
		var kind := _box_kind(c)
		if kind == 1:
			here = true
			var sb: StyleBoxFlat = (c as PanelContainer).get_theme_stylebox("panel")
			if sb.bg_color.is_equal_approx(m.C_PANEL2):      # (cards other files make by hand)
				var nb := card_box()
				nb.content_margin_left = sb.content_margin_left
				nb.content_margin_right = sb.content_margin_right
				nb.content_margin_top = sb.content_margin_top
				nb.content_margin_bottom = sb.content_margin_bottom
				nb.set_corner_radius_all(maxi(sb.corner_radius_top_left, 14))
				(c as PanelContainer).add_theme_stylebox_override("panel", nb)
		elif kind == 0:
			here = false
		if here and c is Label:                             # (on cream: the old grey-blue inks become the warm ones)
			var fc: Color = (c as Label).get_theme_color("font_color")
			if fc.is_equal_approx(m.C_TEXT): (c as Label).add_theme_color_override("font_color", INK)
			elif fc.is_equal_approx(m.C_MUTED): (c as Label).add_theme_color_override("font_color", INK_SOFT)
		if not here:
			if c is Label:
				var l: Label = c
				l.add_theme_color_override("font_color", light(l.get_theme_color("font_color")))
			elif c is RichTextLabel:
				var r: RichTextLabel = c
				r.add_theme_color_override("default_color", light(r.get_theme_color("default_color")))
		_walk(c, here)

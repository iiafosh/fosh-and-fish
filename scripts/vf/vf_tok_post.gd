extends Control
## One FishTok post: an animated full-screen visual (biome "drone shot" with
## swimming fish, a spotlighted fish or chest, tips, the trending fish, the
## daily challenge, parody ads...) plus the overlay UI: creator, caption with
## #hashtags, like / comment / share column, spinning sound disc and a looping
## progress line. Built by vf_tok_feed.gd; actions call back into vf_phone.gd.

const Tok := preload("res://scripts/vf/vf_fishtok.gd")

var phone                       # vf_phone.gd
var item: Dictionary
var v: Dictionary
var active := false
var paused := false
var liked := false
var _t := 0.0
var _seed := 0
var _live_t := 0.0
var _swimmers: Array = []
var _parts: Array = []
var _loop := 9.0                # "video" length for the progress line

var vis: Control
var shade: Control
var fx: Control
var heart_icon: TextureRect
var like_label: Label
var comment_label: Label
var share_label: Label
var disc: Control
var marquee: Label
var progress: Control
var pause_icon: TextureRect
var follow_badge: Control
var caption: RichTextLabel
var _cap_full := ""
var _cap_short := ""
var _cap_open := false
# challenge widgets
var ch_text: Label
var ch_prog: Label
var ch_btn: Button

func setup(p, it: Dictionary, sz: Vector2) -> void:
	phone = p
	item = it
	v = it.get("v", {})
	size = sz
	custom_minimum_size = sz
	_seed = int(it.get("seed", 0))
	_t = float(_seed % 97) * 0.37
	_loop = 7.0 + float(_seed % 6)
	liked = String(it.get("id", "")) in VF.tok_liked
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build()
	set_active(false)

func vtype() -> String:
	return String(v.get("type", ""))

# =================================================================== build
func _build() -> void:
	vis = _layer(_draw_vis)
	_init_visual()
	shade = _layer(_draw_shade)
	_build_extras()
	if vtype() != "end":
		_build_column()
		_build_text()
		progress = _layer(_draw_progress)
	fx = Control.new()
	fx.size = size
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx)
	pause_icon = TextureRect.new()
	pause_icon.texture = phone.ph("play")
	pause_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pause_icon.size = Vector2(72, 72)
	pause_icon.position = size * 0.5 - Vector2(36, 36)
	pause_icon.pivot_offset = Vector2(36, 36)
	pause_icon.modulate = Color(1, 1, 1, 0.0)
	pause_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pause_icon)

func _layer(cb: Callable) -> Control:
	var c := Control.new()
	c.size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(cb)
	add_child(c)
	return c

func _init_visual() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed * 31 + 7
	var W := size.x
	var H := size.y
	match vtype():
		"scene", "haul", "boat":
			var biome := String(v.get("biome", "River"))
			var names: Array = VFData.BIOMES[biome].fish
			var n := 5 if vtype() == "scene" else (3 if vtype() == "boat" else int(v.get("fish_n", 7)))
			var school_dir := -1.0 if rng.randf() < 0.5 else 1.0
			for i in n:
				var f: String = names[rng.randi() % names.size()]
				var y := rng.randf_range(0.5, 0.9) * H
				var dir := school_dir if vtype() == "haul" else (-1.0 if rng.randf() < 0.5 else 1.0)
				if vtype() == "haul":
					f = String(v.get("fish", f)) if rng.randf() < 0.75 else f
					y = H * 0.66 + rng.randf_range(-0.16, 0.16) * H
				_swimmers.append({"sp": phone.swim_entry(f), "x0": rng.randf() * (W + 200.0), "y": y,
					"speed": rng.randf_range(22.0, 48.0), "dir": dir, "size": rng.randf_range(0.85, 1.2), "ph": rng.randf() * TAU})
			_parts.append(phone.particles("bubbles", Rect2(0, H * 0.45, W, H * 0.55), vis))
		"fish", "chest":
			_parts.append(phone.particles("sparkle", Rect2(W * 0.15, H * 0.16, W * 0.7, H * 0.42), vis))
		"trend":
			_parts.append(phone.particles("flames", Rect2(0, H * 0.62, W, H * 0.3), vis))
			_parts.append(phone.particles("sparkle", Rect2(W * 0.15, H * 0.16, W * 0.7, H * 0.4), vis))
		"tip":
			_parts.append(phone.particles("bubbles", Rect2(0, H * 0.3, W, H * 0.7), vis))
		"level":
			_parts.append(phone.particles("confetti", Rect2(0, -20, W, 30), vis))
		"challenge":
			_parts.append(phone.particles("bubbles", Rect2(0, H * 0.4, W, H * 0.6), vis))
		"ad":
			_parts.append(phone.particles("sparkle", Rect2(W * 0.2, H * 0.12, W * 0.6, H * 0.36), vis))

# --------------------------------------------------- per-type child widgets
func _build_extras() -> void:
	var W := size.x
	var H := size.y
	var sticker := String(v.get("sticker", ""))
	match vtype():
		"trend":
			_center(phone.chip("TRENDING TODAY", Color(1, 1, 1, 0.16), Color.WHITE, "fire"), 76)
			var tag := PanelContainer.new()
			var tsb := StyleBoxFlat.new()
			tsb.bg_color = phone.C_GOLD
			tsb.set_corner_radius_all(14)
			tsb.content_margin_left = 16
			tsb.content_margin_right = 16
			tsb.content_margin_top = 2
			tsb.content_margin_bottom = 8
			tsb.shadow_color = Color(0, 0, 0, 0.25)
			tsb.shadow_size = 8
			tag.add_theme_stylebox_override("panel", tsb)
			var tv := VBoxContainer.new()
			tv.add_theme_constant_override("separation", -8)
			var big: Label = phone.lbl("+50%", 44, phone.C_INK, "black")
			big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tv.add_child(big)
			var sub: Label = phone.lbl("sell price today", 12, phone.C_INK, "black")
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tv.add_child(sub)
			tag.add_child(tv)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tag)
			tag.reset_size()
			tag.position = Vector2((W - 66.0 - tag.size.x) * 0.5, H * 0.53)
			tag.pivot_offset = tag.size * 0.5
			tag.rotation = deg_to_rad(-4.0)
			sticker = ""
		"challenge":
			_center(phone.chip("DAILY CHALLENGE", Color(1, 1, 1, 0.16), Color.WHITE, "target"), 76)
			ch_text = phone.lbl("", 21, Color.WHITE, "bold")
			ch_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ch_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ch_text.custom_minimum_size.x = 196
			phone.shadow(ch_text, 0.3)
			ch_prog = phone.lbl("", 14, Color(1, 1, 1, 0.85), "bold")
			_center(ch_text, H * 0.565)
			_center(ch_prog, H * 0.565 + 30)
			ch_btn = phone.pill("", phone.C_GOLD, phone.C_INK, 40, 180)
			ch_btn.pressed.connect(func(): phone.on_claim_challenge(self))
			add_child(ch_btn)
			refresh_live()
		"tip":
			_center(phone.chip("PRO TIP", Color(1, 1, 1, 0.18), Color.WHITE, "sparkle"), 76)
			var t: Label = phone.lbl(String(v.text), 24, Color.WHITE, "black")
			t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			t.custom_minimum_size.x = 206
			phone.shadow(t, 0.3)
			_center(t, H * 0.47)
		"ad":
			var head: Label = phone.lbl(String(v.head), 25, phone.C_INK, "black")
			_center(head, H * 0.5)
			var price: PanelContainer = phone.chip(String(v.price), phone.C_INK, Color.WHITE, "")
			_center(price, H * 0.5 + 40)
		"level":
			_center(phone.chip("LEVEL UP", Color(1, 1, 1, 0.16), Color.WHITE, "star"), 76)
			var n: Label = phone.lbl(VF.commas(int(v.level)), 92 if int(v.level) < 1000 else 70, Color.WHITE, "black")
			phone.shadow(n, 0.35)
			_center(n, H * 0.3)
			var sub: Label = phone.lbl("level reached", 16, Color(1, 1, 1, 0.85), "bold")
			_center(sub, H * 0.3 + 118)
		"end":
			var ic := TextureRect.new()
			ic.texture = phone.ph("check")
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.size = Vector2(46, 46)
			ic.position = Vector2(W * 0.5 - 23, H * 0.3 - 23)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(ic)
			var t: Label = phone.lbl("You're all caught up", 21, Color.WHITE, "black")
			_center(t, H * 0.3 + 62)
			var s: Label = phone.lbl("New trending fish and a new challenge\nevery day at midnight (UTC).", 13, Color(1, 1, 1, 0.7))
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_center(s, H * 0.3 + 96)
			var go: Button = phone.pill("Go fish!", phone.C_TEAL, Color.WHITE, 42, 190)
			go.pressed.connect(func(): phone.on_end("fish"))
			go.position = Vector2(W * 0.5 - 95, H * 0.3 + 160)
			add_child(go)
			var again: Button = phone.pill("Watch again", Color(1, 1, 1, 0.14), Color.WHITE, 38, 190)
			again.pressed.connect(func(): phone.on_end("top"))
			again.position = Vector2(W * 0.5 - 95, H * 0.3 + 212)
			add_child(again)
	if sticker != "":
		var st := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.set_corner_radius_all(9)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 5
		sb.content_margin_bottom = 7
		sb.shadow_color = Color(0, 0, 0, 0.18)
		sb.shadow_size = 6
		st.add_theme_stylebox_override("panel", sb)
		var l: Label = phone.lbl(sticker, 17, phone.C_INK, "black")
		st.add_child(l)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(st)
		st.reset_size()
		var y := H * (0.6 if vtype() in ["fish", "chest"] else 0.2)
		st.position = Vector2((W - st.size.x) * 0.5, y)
		st.pivot_offset = st.size * 0.5
		st.rotation = deg_to_rad(-3.0 if _seed % 2 == 0 else 2.5)

## place a control horizontally centred with its top at y
func _center(c: Control, y: float) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.reset_size()
	c.position = Vector2((size.x - c.size.x) * 0.5, y)

# ------------------------------------------------------------ action column
func _build_column() -> void:
	var who: Dictionary = item.get("who", {})
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 12)
	col.position = Vector2(size.x - 60, 0)
	col.size = Vector2(56, size.y - 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	# creator avatar + follow badge
	var av_box := Control.new()
	av_box.custom_minimum_size = Vector2(56, 60)
	av_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var av: Control = phone.avatar(who, 46)
	av.position = Vector2(5, 0)
	av_box.add_child(av)
	if not who.get("me", false) and not who.get("sponsored", false):
		follow_badge = Control.new()
		follow_badge.size = Vector2(20, 20)
		follow_badge.position = Vector2(18, 37)
		follow_badge.mouse_filter = Control.MOUSE_FILTER_PASS
		follow_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		follow_badge.draw.connect(_draw_follow)
		follow_badge.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				phone.on_follow(who)
				follow_badge.queue_redraw()
				accept_event())
		av_box.add_child(follow_badge)
	col.add_child(av_box)
	var hb := _action("heart", item.get("likes", 0), _on_heart)
	heart_icon = hb[0]
	like_label = hb[1]
	_paint_heart()
	var cb := _action("chat-circle", item.get("comments", 0), func(): phone.open_comments(item))
	comment_label = cb[1]
	var sh := _action("share-fat", item.get("shares", 0), func():
		item["shares"] = int(item.get("shares", 0)) + 1
		share_label.text = Tok.count(int(item.shares))
		phone.on_share(item))
	share_label = sh[1]
	for a in [hb, cb, sh]: col.add_child(a[2])
	disc = Control.new()
	disc.custom_minimum_size = Vector2(56, 50)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.draw.connect(_draw_disc)
	col.add_child(disc)

## [icon, count label, box]
func _action(icon_name: String, n: int, cb: Callable) -> Array:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.custom_minimum_size = Vector2(56, 0)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var ic := TextureRect.new()
	ic.texture = phone.ph(icon_name)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(56, 33)
	ic.pivot_offset = Vector2(28, 16)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(_icon_shadow(icon_name))
	box.add_child(ic)
	var l: Label = phone.lbl(Tok.count(n), 12, Color.WHITE, "bold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phone.shadow(l, 0.45)
	box.add_child(l)
	box.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			cb.call()
			accept_event())
	return [ic, l, box]

## a soft dark copy under white icons so they read on bright scenes
func _icon_shadow(icon_name: String) -> TextureRect:
	var s := TextureRect.new()
	s.texture = phone.ph(icon_name)
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s.size = Vector2(56, 33)
	s.position = Vector2(0, 1.5)
	s.modulate = Color(0, 0, 0, 0.28)
	s.show_behind_parent = true
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s

func _paint_heart() -> void:
	if heart_icon: heart_icon.modulate = phone.C_HEART if liked else Color.WHITE

func _like_count() -> int:
	var n := int(item.get("likes", 0))
	if item.has("post"): n = VF.tok_post_likes(item.post)
	return n + (1 if liked else 0)

func _on_heart() -> void:
	set_liked(not liked)

func set_liked(on: bool, pop := true) -> void:
	if on == liked:
		if on and pop: _pop_heart()
		return
	liked = on
	phone.on_like(item, liked)
	_paint_heart()
	like_label.text = Tok.count(_like_count())
	if on and pop: _pop_heart()

func _pop_heart() -> void:
	if heart_icon == null: return
	var tw := heart_icon.create_tween()
	heart_icon.scale = Vector2(0.7, 0.7)
	tw.tween_property(heart_icon, "scale", Vector2(1.3, 1.3), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(heart_icon, "scale", Vector2.ONE, 0.14)

## double tap: a big heart pops where you tapped, and the post is liked
func double_tap(at: Vector2) -> void:
	if vtype() == "end": return
	set_liked(true)
	var h := TextureRect.new()
	h.texture = phone.ph("heart")
	h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h.size = Vector2(104, 104)
	h.pivot_offset = Vector2(52, 52)
	h.position = at - Vector2(52, 62)
	h.modulate = phone.C_HEART
	h.rotation = randf_range(-0.35, 0.35)
	h.scale = Vector2(0.2, 0.2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(h)
	var tw := h.create_tween()
	tw.tween_property(h, "scale", Vector2(1.25, 1.25), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(h, "scale", Vector2(1.0, 1.0), 0.1)
	tw.tween_interval(0.28)
	tw.tween_property(h, "position:y", h.position.y - 60, 0.4).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(h, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(h, "scale", Vector2(1.4, 1.4), 0.4)
	tw.tween_callback(h.queue_free)
	AudioManager.play_click()

func toggle_pause() -> void:
	if vtype() == "end": return
	paused = not paused
	for p in _parts: (p as CPUParticles2D).speed_scale = 0.0 if paused else 1.0
	var tw := pause_icon.create_tween()
	if paused:
		pause_icon.scale = Vector2(1.4, 1.4)
		tw.tween_property(pause_icon, "modulate:a", 0.75, 0.12)
		tw.parallel().tween_property(pause_icon, "scale", Vector2.ONE, 0.16)
	else:
		tw.tween_property(pause_icon, "modulate:a", 0.0, 0.15)

# ----------------------------------------------------------- caption block
func _build_text() -> void:
	var who: Dictionary = item.get("who", {})
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 6)
	box.position = Vector2(12, 0)
	box.size = Vector2(size.x - 80, size.y - 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl: Label = phone.lbl(String(who.get("handle", "")), 16, Color.WHITE, "black")
	phone.shadow(nl, 0.4)
	name_row.add_child(nl)
	if who.get("verified", false):
		name_row.add_child(phone.verified_badge(15))
	var meta := ""
	if who.get("sponsored", false): meta = "Sponsored"
	elif item.has("post"): meta = "· " + Tok.ago(Time.get_unix_time_from_system() - float(item.post.t))
	elif item.get("kind", "") == "npc": meta = "· %dh" % (1 + _seed % 20)
	if meta != "":
		var ml: Label = phone.lbl(meta, 13, Color(1, 1, 1, 0.75), "bold")
		phone.shadow(ml, 0.4)
		name_row.add_child(ml)
	box.add_child(name_row)
	_cap_full = _bb(String(item.get("caption", "")))
	var raw := String(item.get("caption", ""))
	_cap_short = _cap_full
	if raw.length() > 96:
		var cut := raw.left(88)
		cut = cut.left(cut.rfind(" ")) if cut.rfind(" ") > 40 else cut
		_cap_short = _bb(cut) + "... [b]more[/b]"
	caption = phone.rich(_cap_short, 14, Color.WHITE)
	caption.custom_minimum_size.x = size.x - 84
	caption.mouse_filter = Control.MOUSE_FILTER_PASS if _cap_short != _cap_full else Control.MOUSE_FILTER_IGNORE
	caption.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_cap_open = not _cap_open
			caption.text = _cap_full if _cap_open else _cap_short
			accept_event())
	box.add_child(caption)
	if item.get("kind", "") == "ad":
		var cta: Button = phone.pill("%s  ›" % String(item.get("cta", "Shop now")), phone.C_TEAL, Color.WHITE, 36, 0)
		cta.pressed.connect(func(): phone.on_cta(item))
		box.add_child(cta)
	if item.get("kind", "") == "trend":
		var go: Button = phone.pill("Where to catch it  ›", Color(1, 1, 1, 0.2), Color.WHITE, 36, 0)
		go.pressed.connect(func(): phone.on_cta({"panel": ["biomes", ""]}))
		box.add_child(go)
	# sound row with a scrolling title
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	srow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var note := TextureRect.new()
	note.texture = phone.ph("music-notes")
	note.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	note.custom_minimum_size = Vector2(15, 15)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	srow.add_child(note)
	var clip := Control.new()
	clip.clip_contents = true
	clip.custom_minimum_size = Vector2(170, 18)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var snd := String(item.get("sound", ""))
	marquee = phone.lbl(snd + "        " + snd + "        ", 13, Color.WHITE, "bold")
	phone.shadow(marquee, 0.4)
	clip.add_child(marquee)
	srow.add_child(clip)
	box.add_child(srow)

## hashtags in bold; brackets escaped
func _bb(text: String) -> String:
	var out := []
	for w in text.replace("[", "[lb]").split(" "):
		out.append("[b]%s[/b]" % w if w.begins_with("#") or w.begins_with("@") else w)
	return " ".join(out)

# ------------------------------------------------------------------ runtime
func set_active(on: bool) -> void:
	active = on
	set_process(on)
	for p in _parts:
		(p as CPUParticles2D).emitting = on
	if not on and paused: toggle_pause()

func _process(delta: float) -> void:
	if not paused:
		_t += delta
		vis.queue_redraw()
		if progress: progress.queue_redraw()
		if disc: disc.queue_redraw()
		if marquee and marquee.size.x > 0.0:
			marquee.position.x -= delta * 26.0
			if marquee.position.x < -marquee.size.x * 0.5: marquee.position.x += marquee.size.x * 0.5
	_live_t += delta
	if _live_t > 0.5:
		_live_t = 0.0
		refresh_live()

## counts that change while you watch (your posts' likes, challenge progress)
func refresh_live() -> void:
	if like_label and item.has("post"):
		like_label.text = Tok.count(_like_count())
		var l := _like_count()
		comment_label.text = Tok.count(int(l * 0.04))
	if vtype() == "challenge" and ch_text:
		var c: Dictionary = VF.tok_challenge()
		var goal := int(c.get("goal", 1))
		var prog := mini(VF.tok_ch_prog, goal)
		ch_text.text = VF.tok_challenge_text(c)
		ch_prog.text = "%s / %s  ·  ends in %s" % [VF.commas(prog), VF.commas(goal), phone.until_midnight()]
		for c2 in [ch_text, ch_prog]:
			c2.reset_size()
			c2.position.x = (size.x - c2.size.x) * 0.5
		var done := prog >= goal
		if VF.tok_ch_claimed:
			ch_btn.text = "Claimed  ✓"
			ch_btn.disabled = true
		elif done:
			ch_btn.text = "Claim  %s" % VF.goal_reward_text(c.reward)
			ch_btn.disabled = false
		else:
			ch_btn.text = "Reward: %s" % VF.goal_reward_text(c.reward)
			ch_btn.disabled = true
		ch_prog.position.y = ch_text.position.y + ch_text.size.y + 2
		ch_btn.reset_size()
		ch_btn.position = Vector2((size.x - ch_btn.size.x) * 0.5, ch_prog.position.y + 30)
		vis.queue_redraw()

# ===================================================================== draw
func _draw_vis() -> void:
	match vtype():
		"scene", "haul", "boat": _draw_scene()
		"fish": _draw_spot(phone.item_tex(["fish", String(v.fish)]), v.get("accent", Color("#1d9bb0")), 230.0)
		"chest": _draw_spot(phone.item_tex(["chest", String(v.tier)]), phone.tier_color(String(v.tier)), 220.0)
		"trend": _draw_trend()
		"challenge": _draw_challenge()
		"tip": _draw_tip()
		"ad": _draw_ad()
		"level": _draw_level()
		"end": phone.grad(vis, Rect2(Vector2.ZERO, size), Color("#0b1418"), Color("#12343b"))

func _draw_scene() -> void:
	var W := size.x
	var H := size.y
	var bg: Texture2D = phone.biome_tex(String(v.get("biome", "River")))
	if bg:
		var tw := float(bg.get_width())
		var th := float(bg.get_height())
		var z := 1.45 + 0.07 * sin(_t * 0.17 + _seed)
		var ch := th / z
		var cw := ch * W / H
		var cx := tw * 0.5 + (tw - cw) * 0.5 * 0.9 * sin(_t * 0.06 + _seed * 0.37)
		var cy := clampf(th * 0.6, ch * 0.5, th - ch * 0.5)
		vis.draw_texture_rect_region(bg, Rect2(0, 0, W, H), Rect2(cx - cw * 0.5, cy - ch * 0.5, cw, ch))
	else:
		phone.grad(vis, Rect2(0, 0, W, H), Color("#0e4f5c"), Color("#062a33"))
	for s in _swimmers:
		var x: float = fposmod(float(s.x0) + float(s.dir) * float(s.speed) * _t, W + 200.0) - 100.0
		var p := Vector2(x, float(s.y) + sin(_t * 0.9 + float(s.ph)) * 7.0)
		var ang := 0.0 if float(s.dir) > 0.0 else PI
		var len_px: float = 74.0 * float(s.size)
		_sheet(s.sp, p + Vector2(9, 13), ang, len_px, Color(0, 0.05, 0.1, 0.24), float(s.ph))
		_sheet(s.sp, p, ang, len_px, Color(1, 1, 1, 0.93), float(s.ph))
	if vtype() == "boat":
		var bt: Texture2D = phone.boat_top(String(v.get("boat", "Rowboat")))
		if bt:
			var c := Vector2(W * 0.5, H * 0.47 + sin(_t * 1.2) * 4.0)
			var sc := 250.0 / bt.get_width()
			for k in 3:          # wake rings
				var r := fmod(_t * 22.0 + k * 26.0, 78.0)
				vis.draw_arc(c + Vector2(0, 30), 60.0 + r, 0, TAU, 40, Color(1, 1, 1, 0.22 * (1.0 - r / 78.0)), 2.0, true)
			vis.draw_set_transform(c + Vector2(10, 16), -0.5 + sin(_t * 0.8) * 0.05, Vector2(sc, sc))
			vis.draw_texture(bt, -bt.get_size() * 0.5, Color(0, 0.05, 0.1, 0.25))
			vis.draw_set_transform(c, -0.5 + sin(_t * 0.8) * 0.05, Vector2(sc, sc))
			vis.draw_texture(bt, -bt.get_size() * 0.5)
			vis.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _sheet(sp: Dictionary, p: Vector2, ang: float, length_px: float, col: Color, phase: float) -> void:
	var t: Texture2D = sp.get("tex")
	if t == null: return
	var cell: float = sp.cell
	var n: int = sp.frames
	var fi := int(_t * 10.0 + phase * 3.0) % n if n > 1 else 0
	var sc := length_px / cell
	vis.draw_set_transform(p, ang + (0.0 if n > 1 else sin(_t * 6.0 + phase) * 0.08), Vector2(sc, sc))
	vis.draw_texture_rect_region(t, Rect2(-cell * 0.5, -cell * 0.5, cell, cell), Rect2(fi * cell, 0, cell, t.get_height()), col)
	vis.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## a hero item on a glowing backdrop (fish / chest / trending)
func _draw_spot(tex: Texture2D, acc: Color, px: float, center_y := 0.36) -> void:
	var W := size.x
	var H := size.y
	phone.grad(vis, Rect2(0, 0, W, H), acc.darkened(0.62), acc.darkened(0.25))
	var c := Vector2(W * 0.5, H * center_y)
	phone.rays(vis, c, 520.0, 14, _t * 0.12, Color(1, 1, 1, 0.055))
	phone.glow(vis, c, 210.0, Color(acc.lightened(0.45), 0.6), 16)
	_hero(tex, c, px)

func _hero(tex: Texture2D, c: Vector2, px: float) -> void:
	if tex == null: return
	var bob := sin(_t * 2.0) * 9.0
	var shake := 0.0
	if vtype() == "chest":
		var k := fmod(_t, 2.6)
		if k < 0.45: shake = sin(k * 60.0) * 0.07 * (1.0 - k / 0.45)
	vis.draw_set_transform(c + Vector2(0, px * 0.47), 0.0, Vector2(1.0, 0.2))
	vis.draw_circle(Vector2.ZERO, px * 0.36 - bob * 0.6, Color(0, 0, 0, 0.22))
	var sc := px / maxf(1.0, tex.get_width())
	vis.draw_set_transform(c + Vector2(0, bob), sin(_t * 1.3) * 0.07 + shake, Vector2(sc, sc))
	vis.draw_texture(tex, -tex.get_size() * 0.5)
	vis.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_trend() -> void:
	var W := size.x
	var H := size.y
	phone.grad(vis, Rect2(0, 0, W, H), Color("#2a0a06"), Color("#b4380d"))
	var c := Vector2(W * 0.5, H * 0.34)
	phone.rays(vis, c, 520.0, 16, _t * 0.18, Color(1, 0.8, 0.4, 0.07))
	phone.glow(vis, c, 200.0, Color(1.0, 0.62, 0.2, 0.65), 16)
	_hero(phone.item_tex(["fish", String(v.fish)]), c, 210.0)

func _draw_challenge() -> void:
	var W := size.x
	var H := size.y
	phone.grad(vis, Rect2(0, 0, W, H), Color("#08262c"), Color("#0f5e6b"))
	var c := Vector2(W * 0.5, H * 0.34)
	phone.glow(vis, c, 150.0, Color(0.4, 0.9, 1.0, 0.35), 12)
	var ch: Dictionary = VF.tok_challenge()
	var goal := maxi(1, int(ch.get("goal", 1)))
	var k := clampf(float(VF.tok_ch_prog) / goal, 0.0, 1.0)
	var r := 86.0
	vis.draw_arc(c, r, 0, TAU, 90, Color(1, 1, 1, 0.14), 12.0, true)
	if k > 0.0:
		var col: Color = phone.C_GOOD if k >= 1.0 else phone.C_GOLD
		vis.draw_arc(c, r, -PI / 2, -PI / 2 + TAU * k, 90, col, 12.0, true)
		var e := c + Vector2.from_angle(-PI / 2 + TAU * k) * r
		vis.draw_circle(e, 6.0, col)
		vis.draw_circle(c + Vector2(0, -r), 6.0, col)
	var tex: Texture2D
	match String(ch.get("kind", "")):
		"species": tex = phone.item_tex(["fish", String(ch.fish)])
		"chests": tex = phone.item_tex(["chest", "epic"])
		_: tex = phone.item_tex(["ui", "inventory"])
	_hero(tex, c, 120.0)

func _draw_tip() -> void:
	var W := size.x
	var H := size.y
	var c1: Color = v.get("c1", Color("#0f766e"))
	var c2: Color = v.get("c2", Color("#22d3ee"))
	phone.grad(vis, Rect2(0, 0, W, H), c1.darkened(0.35), c2.darkened(0.2), true)
	var c := Vector2(W * 0.5, H * 0.29)
	vis.draw_circle(c, 74.0 + sin(_t * 1.6) * 3.0, Color(1, 1, 1, 0.14))
	vis.draw_circle(c, 58.0, Color(1, 1, 1, 0.12))
	var ic: Array = v.get("icon", ["ph", "sparkle"])
	var tex: Texture2D = phone.item_tex(ic)
	if tex:
		var px := 74.0 if ic[0] == "ph" else 108.0
		var sc := px / maxf(1.0, tex.get_width())
		vis.draw_set_transform(c + Vector2(0, sin(_t * 2.0) * 6.0), sin(_t * 1.2) * 0.06, Vector2(sc, sc))
		vis.draw_texture(tex, -tex.get_size() * 0.5)
		vis.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_ad() -> void:
	var W := size.x
	var H := size.y
	phone.grad(vis, Rect2(0, 0, W, H), Color("#fff4e2"), Color("#d8eef2"))
	var c := Vector2(W * 0.5, H * 0.3)
	phone.rays(vis, c, 460.0, 18, _t * 0.1, Color(1.0, 0.85, 0.45, 0.16))
	vis.draw_set_transform(c + Vector2(0, 96), 0.0, Vector2(1.0, 0.18))
	vis.draw_circle(Vector2.ZERO, 92.0, Color(0, 0, 0, 0.12))
	vis.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	vis.draw_circle(c, 96.0, Color.WHITE)
	vis.draw_arc(c, 96.0, 0, TAU, 80, Color(1, 0.8, 0.4, 0.6), 3.0, true)
	var tex: Texture2D = phone.item_tex(v.get("icon", ["bait", "Worms"]))
	if tex:
		var sc := 150.0 / maxf(1.0, tex.get_width())
		vis.draw_set_transform(c + Vector2(0, sin(_t * 2.0) * 5.0), sin(_t * 1.1) * 0.08, Vector2(sc, sc))
		vis.draw_texture(tex, -tex.get_size() * 0.5)
		vis.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_level() -> void:
	var W := size.x
	var H := size.y
	phone.grad(vis, Rect2(0, 0, W, H), Color("#1e1b4b"), Color("#0e7490"), true)
	var c := Vector2(W * 0.5, H * 0.38)
	phone.rays(vis, c, 520.0, 12, _t * 0.15, Color(1, 1, 1, 0.06))
	phone.glow(vis, c, 190.0, Color(0.55, 0.75, 1.0, 0.5), 14)

func _draw_shade() -> void:
	var W := size.x
	var H := size.y
	var dark := vtype() not in ["end"]
	if not dark: return
	var k := 1.35 if vtype() == "ad" else 1.0
	phone.grad(shade, Rect2(0, 0, W, 130), Color(0, 0, 0, 0.42 * k), Color(0, 0, 0, 0.0))
	phone.grad(shade, Rect2(0, H - 300, W, 300), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.62 * k))

func _draw_progress() -> void:
	var W := size.x
	var y := size.y - 2.0
	progress.draw_rect(Rect2(0, y, W, 2), Color(1, 1, 1, 0.22))
	progress.draw_rect(Rect2(0, y, W * fmod(_t, _loop) / _loop, 2), Color(1, 1, 1, 0.85))

func _draw_disc() -> void:
	var c := Vector2(28, 25)
	var a := _t * 1.6
	disc.draw_circle(c, 21.0, Color("#1b1f22"))
	for r in [17.0, 14.0]:
		disc.draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.08), 1.0, true)
	disc.draw_arc(c, 21.0, 0, TAU, 48, Color("#3a4248"), 2.0, true)
	var who: Dictionary = item.get("who", {})
	disc.draw_circle(c, 10.5, who.get("color", Color("#1d9bb0")))
	var ic: Array = who.get("icon", ["ph", "music-notes"])
	var tex: Texture2D = phone.item_tex(ic)
	if tex:
		var sc := 15.0 / maxf(1.0, tex.get_width())
		disc.draw_set_transform(c, a, Vector2(sc, sc))
		disc.draw_texture(tex, -tex.get_size() * 0.5)
		disc.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# a little note drifting out of the disc
	var k := fmod(_t * 0.5, 1.0)
	var nt: Texture2D = phone.ph("music-notes")
	if nt:
		var p := c + Vector2(-10.0 - 16.0 * k, -14.0 - 22.0 * k)
		var s := 11.0 / nt.get_width()
		disc.draw_set_transform(p, -0.3 * k, Vector2(s, s))
		disc.draw_texture(nt, -nt.get_size() * 0.5, Color(1, 1, 1, 0.8 * (1.0 - k)))
		disc.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_follow() -> void:
	var on: bool = phone.is_following(item.get("who", {}))
	var c := Vector2(10, 10)
	follow_badge.draw_circle(c, 10.0, Color.WHITE if on else phone.C_HEART)
	if on:
		follow_badge.draw_polyline(PackedVector2Array([c + Vector2(-4.5, 0), c + Vector2(-1, 3.5), c + Vector2(5, -3)]), phone.C_HEART, 2.2, true)
	else:
		follow_badge.draw_line(c + Vector2(-4.5, 0), c + Vector2(4.5, 0), Color.WHITE, 2.2, true)
		follow_badge.draw_line(c + Vector2(0, -4.5), c + Vector2(0, 4.5), Color.WHITE, 2.2, true)

extends Control
## "Reel it in!" - the skill catch (VF.catch_mode == "reel", numbers in VFData.MINIGAME_*).
## After the bite a cheeky cartoon fish wiggles in a water column: hold (mouse / touch
## anywhere / Space) to lift the catch zone and keep the fish inside it until the reel
## ring is full. Rarer fish wiggle harder. resolved(won) fires the moment it is decided
## (vf_main gives the catch right away), then a short win / fail gag plays (tap to skip).
## Art: Kenney Fish Pack + Emotes Pack (CC0) in the game's frosted-pill style.

signal resolved(won: bool)

const FISHP := "res://assets/third_party/kenney_fish/"
const EMO := "res://assets/third_party/kenney_emotes/"
const SPARK := "res://assets/third_party/kenney_particles/"
const CW := 440.0
const CH := 470.0
const COL := Rect2(26, 72, 140, 356)           # the water column inside the card
const RING := Vector2(303, 236)                # centre of the reel ring
const RING_R := 62.0
# one cartoon fish per tier (biome fish lists run low -> high tier); eye / mouth / lid in sprite px (128x128)
const LOOKS := [
	{"tex": "fish_orange", "eye": Vector2(101, 61), "mouth": Vector2(114, 71), "lid": Color("#e57d0a")},
	{"tex": "fish_green", "eye": Vector2(96, 63), "mouth": Vector2(112, 76), "lid": Color("#1f8a4a")},
	{"tex": "fish_blue", "eye": Vector2(100, 61), "mouth": Vector2(115, 71), "lid": Color("#2468b5")},
	{"tex": "fish_red", "eye": Vector2(99, 57), "mouth": Vector2(114, 73), "lid": Color("#b8332a")},
	{"tex": "fish_brown", "eye": Vector2(96, 45), "mouth": Vector2(110, 63), "lid": Color("#a86a33")},
]
const TIER_COL := [Color("#6b7d86"), Color("#1d9bb0"), Color("#2f6fd6"), Color("#8b3fd1"), Color("#d4920f")]
const SAY_START := ["You'll never catch me!", "blub blub ;P", "Is that hook made of spaghetti?", "Come at me, bro.",
	"I've escaped better fishers!", "Catch me if you can!", "My mom swims faster than you reel."]
const SAY_ESCAPE := ["Too slow!", "Nyeh nyeh!", "Missed me!", "Over here, genius!", "Wheee!", "Nope!", "Butterfingers!"]
const SAY_CAUGHT := ["Hey! Let go!", "This is fine.", "Okay, that tickles!", "Unhand me!", "No no no no"]
const SAY_ALMOST := ["Wait wait, let's talk!", "I have a family! (I don't)", "MOMMYYY!", "I'll pay you 3 shrimp!", "Not the frying pan!"]
const SAY_WIN := ["Fine. You win. THIS time.", "Tell my story...", "Ugh. GG.", "I'm too pretty for a bucket!"]
const SAY_LOSE := ["PFFFT! Bye, loser!", "Later, sucker!", "blub blub, see ya!", "Git gud, fisher!"]

var main                     # vf_main.gd (UI kit: lbl, sbox, keycap, is_touch, stage)
var fish_name := ""
var tier := 0
var auto := ""               # capture tests: "win" / "lose" plays by itself

var phase := "intro"         # intro -> play -> end
var t := 0.0                 # time in the current phase
var play_t := 0.0
var won := false
var perfect := true          # never slipped out once caught
# column units: 0 = bottom, 1 = top
var zone_y := 0.0
var zone_v := 0.0
var zone_h := 0.32
var fish_y := 0.6
var fish_target := 0.6
var fish_speed := 0.35
var dart := 1.0
var retarget := 0.5
var progress := 0.15
var fill_rate := 0.42
var drain_rate := 0.24        # how fast the ring empties while the fish is out of the zone
var reel_power := 0.0         # the rod's reel power (0..1), VFData.rod_reel_power
var lift := 3.4               # zone acceleration while holding / sinking (gentler on keyboard + mouse)
var sink := 2.8
var max_v := 1.7
var time_limit := 7.0
var in_zone := false
var _was_in := false
var _in_time := 0.0
var _out_time := 0.0
var _entered := false

var card: Control
var board: Control           # card bg, ring, timer
var column: Control          # water, zone (clipped)
var top: Control             # fish, emote, bubble tail (not clipped: the fish can fly out)
var bubble: PanelContainer
var bubble_lbl: Label
var status: Label
var hint: Control
var skip_lbl: Label
var _tex := {}
var _bubbles: Array = []
var _bub_t := 0.0
var _emote := ""
var _emote_t := 0.0
var _talk_t := 0.0
var _taunt_cd := 0.0
var _shake := 0.0
var _card_base := Vector2.ZERO
var _fit := 1.0                  # card scale: < 1 on short (phone) screens
var _stage_base := Vector2.ZERO
var _tick_t := 0.0
var _spin := 0.0
var _face := "smug"          # smug / worried / dizzy / raspberry
var _fish_x := 0.0
var _fish_rot := 0.0
var _fish_squash := Vector2.ONE
var _fish_out := 0.0         # end gag: px the fish has left the column (+ up, - down)
var _zone_a := 1.0
var _end_len := 1.5
var _done := false
var _sb_zone: StyleBoxFlat
var _sb_zone_in: StyleBoxFlat

## which fish bit: rolled with the real species odds, so rare fish are rare here too
static func pick_biter() -> Array:
	var odds: Array = VF.species_odds()
	var names: Array = VFData.BIOMES[VF.biome].fish
	var roll := randf()
	var acc := 0.0
	for k in range(4, -1, -1):
		acc += float(odds[k])
		if roll < acc: return [names[k], k]
	return [names[0], 0]

func setup(m, fname: String, ftier: int) -> void:
	main = m
	fish_name = fname
	tier = clampi(ftier, 0, 4)
	reel_power = VFData.rod_reel_power(VF.rod)
	var p := VFData.minigame_params(tier, reel_power, not main.is_touch())
	zone_h = p.zone_h
	fish_speed = p.fish_speed
	fill_rate = p.fill_rate
	drain_rate = p.drain_rate
	time_limit = p.time_limit
	lift = p.lift
	sink = p.sink
	max_v = p.max_v
	fish_y = randf_range(0.45, 0.8)
	fish_target = fish_y

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.08, 0.12, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)
	card = Control.new()
	card.size = Vector2(CW, CH)
	card.pivot_offset = card.size * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var vs := get_viewport_rect().size
	# the card plus its banner above and the result pill below is ~CH + 100 tall: shrink it on short (phone) screens
	_fit = minf(1.0, (vs.y - 12.0) / (CH + 100.0))
	_card_base = ((vs - card.size) * 0.5 + Vector2(0, 12) * _fit).round()
	card.position = _card_base
	if main and main.stage: _stage_base = main.stage.position
	board = _layer(card, Rect2(Vector2.ZERO, card.size), _draw_board)
	column = _layer(card, COL, _draw_column)
	column.clip_contents = true
	top = _layer(card, Rect2(Vector2.ZERO, card.size), _draw_top)
	_sb_zone = main.sbox(Color(1, 1, 1, 0.24), 16, 3, Color(1, 1, 1, 0.92), 0)
	_sb_zone_in = main.sbox(Color(0.45, 1.0, 0.7, 0.34), 16, 3, Color("#d9ffe9"), 0)
	_sb_zone_in.shadow_color = Color(0.5, 1, 0.75, 0.55)
	_sb_zone_in.shadow_size = 10
	_build_labels()
	# pop in
	card.scale = Vector2(0.55, 0.55) * _fit
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "scale", Vector2.ONE * _fit, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.14)
	_fish_out = -220.0
	create_tween().tween_property(self, "_fish_out", 0.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_emote("exclamation")
	_say(SAY_START.pick_random())
	AudioManager.play_strike()
	AudioManager.play_sfx("splash", -4.0, 1.15)

func _layer(parent: Control, r: Rect2, cb: Callable) -> Control:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(cb)
	parent.add_child(c)
	return c

func _build_labels() -> void:
	# header pill sitting on the card's top edge
	var head := PanelContainer.new()
	var hsb: StyleBoxFlat = main.sbox(Color("#1d9bb0"), 999, 3, Color.WHITE, 0, 10)
	hsb.content_margin_left = 22
	hsb.content_margin_right = 26
	hsb.content_margin_top = 4
	hsb.content_margin_bottom = 6
	head.add_theme_stylebox_override("panel", hsb)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 8)
	var bolt: TextureRect = main.icon(main.ph("lightning"), 26)
	bolt.modulate = Color("#ffd75e")
	hh.add_child(bolt)
	hh.add_child(main.lbl("REEL IT IN!", 26, Color.WHITE, 0))
	head.add_child(hh)
	head.anchor_left = 0.5
	head.anchor_right = 0.5
	head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	head.offset_top = -24
	card.add_child(head)
	head.rotation = -0.03
	var who: Label = main.lbl("%s is on the line!%s" % [fish_name, "  (rare!)" if tier >= 3 else ""], 15, TIER_COL[tier])
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.position = Vector2(0, 34)
	who.size = Vector2(CW, 24)
	card.add_child(who)
	# the fish's speech bubble
	bubble = PanelContainer.new()
	var bsb: StyleBoxFlat = main.sbox(Color.WHITE, 18, 3, Color("#1f2d35"), 0, 4)
	bsb.content_margin_left = 14
	bsb.content_margin_right = 14
	bsb.content_margin_top = 8
	bsb.content_margin_bottom = 10
	bubble.add_theme_stylebox_override("panel", bsb)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_lbl = main.lbl("", 17, Color("#1f2d35"))
	bubble_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_lbl.custom_minimum_size.x = 196
	bubble_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_child(bubble_lbl)
	bubble.position = Vector2(196, 68)
	card.add_child(bubble)
	status = main.lbl("FISH ON!", 20, Color("#1f2d35"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.position = Vector2(RING.x - 125, RING.y + RING_R + 14)
	status.size = Vector2(250, 28)
	card.add_child(status)
	# your rod's reel power (better rods make this easier)
	var rp := HBoxContainer.new()
	rp.alignment = BoxContainer.ALIGNMENT_CENTER
	rp.add_theme_constant_override("separation", 6)
	rp.add_child(main.icon(main.icon_for("rod", VF.rod), 22))
	var pips := ""
	var lvl := int(round(reel_power * 10.0))
	for i in 10: pips += "●" if i < lvl else "○"
	rp.add_child(main.lbl("%s  reel power %d/10" % [VF.rod, lvl], 13, Color("#1d9bb0")))
	rp.position = Vector2(RING.x - 130, RING.y + RING_R + 74)   # under the timer bar, above the hint
	rp.size = Vector2(260, 24)
	rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rp.tooltip_text = "Better rods reel faster and give you a bigger catch zone. " + pips
	card.add_child(rp)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	if not main.is_touch():
		hb.add_child(main.keycap("Space"))
		hb.add_child(main.lbl("or hold the mouse to reel", 14, Color("#6b7d86")))
	else:
		hb.add_child(main.lbl("Hold anywhere to reel", 15, Color("#6b7d86")))
	hb.position = Vector2(RING.x - 130, CH - 50)
	hb.size = Vector2(260, 26)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hb)
	hint = hb
	skip_lbl = main.lbl("tap to skip", 13, Color(1, 1, 1, 0.85), 4)
	skip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_lbl.position = Vector2(0, CH + 12)
	skip_lbl.size = Vector2(CW, 22)
	skip_lbl.visible = false
	card.add_child(skip_lbl)

func _t(path: String) -> Texture2D:
	if not _tex.has(path): _tex[path] = load(path)
	return _tex[path]

# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	t += delta
	_emote_t += delta
	_talk_t -= delta
	_taunt_cd -= delta
	_spin += delta * (11.0 if (in_zone and phase == "play") else 1.2)
	_shake = maxf(0.0, _shake - delta * 2.2)
	var j := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 16.0 * _shake * _shake
	card.position = _card_base + j
	if main and main.stage and not _done: main.stage.position = _stage_base + j * 0.7
	_tick_bubbles(delta)
	if phase == "intro":
		_fish_squash = Vector2(1.0 + 0.1 * sin(t * 18.0), 1.0 - 0.1 * sin(t * 18.0))
		if t >= 0.55:
			phase = "play"
			t = 0.0
	elif phase == "play":
		_play(delta)
	elif phase == "end":
		_end_tick(delta)
		if t >= _end_len: _close()
	board.queue_redraw()
	column.queue_redraw()
	top.queue_redraw()

func _holding() -> bool:
	if auto == "win":
		return zone_y + zone_h * 0.5 + zone_v * 0.22 < fish_y
	if auto == "lose":
		return sin(play_t * 2.3) > 0.55
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_F)

func _play(delta: float) -> void:
	play_t += delta
	# the catch zone: hold to lift, let go to sink (with a little bounce on the floor)
	zone_v = clampf(zone_v + (lift if _holding() else -sink) * delta, -max_v, max_v)
	zone_y += zone_v * delta
	if zone_y < 0.0:
		zone_y = 0.0
		zone_v = -zone_v * 0.35 if zone_v < -0.4 else 0.0
	if zone_y > 1.0 - zone_h:
		zone_y = 1.0 - zone_h
		zone_v = minf(zone_v, 0.0)
	# the fish: picks a new spot every so often, sometimes darts (rarer fish dart more)
	retarget -= delta
	if retarget <= 0.0:
		fish_target = randf_range(0.1, 0.9)
		dart = 2.2 if randf() < 0.12 + 0.07 * tier else 1.0
		retarget = randf_range(0.55, 1.35) - 0.08 * tier
	var before := fish_y
	fish_y = move_toward(fish_y, fish_target, fish_speed * dart * delta)
	fish_y = clampf(fish_y + sin(play_t * (5.0 + tier)) * 0.002 * (1 + tier), 0.08, 0.92)
	var vy := (fish_y - before) / maxf(delta, 0.001)
	_fish_rot = lerpf(_fish_rot, clampf(-vy * 0.45, -0.6, 0.6) + sin(play_t * 7.0) * 0.06, minf(1.0, delta * 10.0))
	var st := 1.0 + minf(absf(vy) * 0.25, 0.2)                     # stretch when darting
	_fish_squash = Vector2(st + 0.07 * sin(play_t * 16.0), (1.0 / st) - 0.07 * sin(play_t * 16.0))
	_fish_x = sin(play_t * 3.1) * 7.0
	# reel progress
	in_zone = fish_y >= zone_y and fish_y <= zone_y + zone_h
	if in_zone:
		progress += fill_rate * delta
		_in_time += delta
		_out_time = 0.0
		_entered = true
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = 0.15
			AudioManager.play_sfx("bubble", -17.0, 0.8 + progress * 0.9)
	else:
		progress -= drain_rate * delta
		_out_time += delta
		if _entered and _out_time > 0.25: perfect = false
	progress = clampf(progress, 0.0, 1.0)
	# reactions
	if _was_in and not in_zone and _in_time > 0.3:
		_show_emote("laugh")
		AudioManager.play_sfx("bubble", -8.0, 0.55)
		if _taunt_cd <= 0.0: _say(SAY_ESCAPE.pick_random())
	if not _was_in and in_zone:
		_in_time = 0.0
	if in_zone and progress > 0.72:
		_face = "worried"
		if _taunt_cd <= 0.0:
			_say(SAY_ALMOST.pick_random())
			_show_emote("drops")
	elif in_zone and _in_time > 0.7:
		_face = "worried"
		if _taunt_cd <= 0.0:
			_say(SAY_CAUGHT.pick_random())
			_show_emote("anger")
	elif not in_zone:
		_face = "smug"
		if _taunt_cd <= -1.4: _say(SAY_START.pick_random())
	_was_in = in_zone
	var left := time_limit - play_t
	if in_zone:
		status.text = "REELING!  %d%%" % int(progress * 100.0)
		status.add_theme_color_override("font_color", Color("#16865a"))
	elif left < 2.0:
		status.text = "HURRY!  %d%%" % int(progress * 100.0)
		status.add_theme_color_override("font_color", Color("#e04f45"))
	else:
		status.text = "SLIPPING...  %d%%" % int(progress * 100.0)
		status.add_theme_color_override("font_color", Color("#b26a00"))
	if progress >= 1.0: _finish(true)
	elif play_t >= time_limit: _finish(false)

func _end_tick(_delta: float) -> void:
	if won:
		_fish_squash = Vector2(0.85, 1.2)
	else:
		_fish_x = sin(t * 30.0) * 7.0 if t < 0.7 else 0.0         # mocking wiggle
		var s := 0.1 * sin(t * 24.0)
		_fish_squash = Vector2(1.0 + s, 1.0 - s)

func _finish(w: bool) -> void:
	if phase == "end": return
	phase = "end"
	t = 0.0
	won = w
	in_zone = false
	hint.visible = false
	skip_lbl.visible = true
	resolved.emit(w)
	var tw := create_tween()
	if w:
		_face = "dizzy"
		_show_emote("swirl")
		_say(SAY_WIN.pick_random())
		status.text = "CAUGHT!"
		status.add_theme_color_override("font_color", Color("#16865a"))
		_pop("PERFECT!" if perfect else ["GOTCHA!", "SPLOOSH!", "YOINK!"].pick_random(), Color("#ffcf4a"))
		_sub("+%d%% fish  ·  next cast in %ss" % [int(round(VFData.MINIGAME_FISH_BONUS * 100.0)), str(VFData.MINIGAME_COOLDOWN)], Color("#16a36a"))
		_shake = 1.0
		_confetti(RING + Vector2(0, 30))
		AudioManager.play_sfx("splash_big", -2.0)
		AudioManager.play_success()
		if perfect: AudioManager.play_levelup()
		if main and main.stage:
			main.stage.burst("splash", main.stage._bobber)
			main.stage.burst("sparkle", main.stage._bobber)
		# yanked out of the water, spinning
		tw.tween_property(self, "_fish_out", 330.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(self, "_fish_rot", -TAU - 0.4, 0.55)
		_end_len = 1.2
	else:
		_face = "raspberry"
		_show_emote("laugh")
		_say(SAY_LOSE.pick_random())
		status.text = "IT GOT AWAY!"
		status.add_theme_color_override("font_color", Color("#e04f45"))
		_pop(["PFFFT!", "BLEHHH!", "NOPE!"].pick_random(), Color("#ff7aa2"))
		_sub("Slippery! Normal catch, no bonus", Color("#5d6f78"))
		_shake = 0.4
		for i in 6:      # a wet raspberry: pbbbbt
			get_tree().create_timer(0.05 + i * 0.055).timeout.connect(func(): AudioManager.play_sfx("bubble", -5.0, randf_range(0.4, 0.52)))
		tw.tween_property(self, "_zone_a", 0.2, 0.25)
		tw.tween_interval(0.45)
		tw.tween_property(self, "_fish_rot", 0.9, 0.12)
		tw.tween_property(self, "_fish_out", -340.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_callback(func(): AudioManager.play_sfx("splash", -6.0, 1.3)).set_delay(0.1)
		_end_len = 1.35

func _close() -> void:
	if _done: return
	_done = true
	if main and main.stage: main.stage.position = _stage_base
	set_process_input(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(queue_free)

## presses are eaten here (no casting / menus while reeling); releases pass through so held
## buttons elsewhere still let go. During the end gag any press skips it.
func _input(e: InputEvent) -> void:
	var press := false
	if e is InputEventKey:
		press = e.pressed and not e.echo
		if e.pressed: get_viewport().set_input_as_handled()
	elif e is InputEventMouseButton or e is InputEventScreenTouch:
		press = e.pressed
		if e.pressed: get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion or e is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
	if press and phase == "end" and t > 0.2:
		_close()

# ------------------------------------------------------------ reactions
func _say(text: String) -> void:
	bubble_lbl.text = text
	bubble.reset_size()
	bubble.pivot_offset = Vector2(0, bubble.size.y)
	bubble.scale = Vector2(0.7, 0.7)
	bubble.create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_talk_t = 0.65
	_taunt_cd = 1.5

func _show_emote(e: String) -> void:
	if _emote == e and _emote_t < 1.0: return
	_emote = e
	_emote_t = 0.0

func _pop(word: String, fill: Color) -> void:
	var pop := Control.new()
	pop.position = RING + Vector2(8, 34)       # over the reel, so the fish and its face stay in view
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.draw.connect(func():
		var pts := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			var r := 1.0 if i % 2 == 0 else 0.74
			pts.append(Vector2(cos(a) * 140.0 * r, sin(a) * 80.0 * r))
		var sh := PackedVector2Array()
		for p in pts: sh.append(p + Vector2(6, 8))
		pop.draw_colored_polygon(sh, Color(0.02, 0.1, 0.14, 0.35))
		pop.draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		pop.draw_polyline(pts, Color("#1f2d35"), 5.0, true))
	var l: Label = main.lbl(word, 54, Color.WHITE)
	l.add_theme_constant_override("outline_size", 16)
	l.add_theme_color_override("font_outline_color", Color("#1f2d35"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(420, 90)
	l.position = Vector2(-210, -48)
	pop.add_child(l)
	pop.rotation = -0.14
	pop.scale = Vector2(0.15, 0.15)
	card.add_child(pop)
	var tw := pop.create_tween()
	tw.tween_property(pop, "scale", Vector2(1.18, 1.18), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "scale", Vector2.ONE, 0.1)
	tw.parallel().tween_property(pop, "rotation", -0.08, 0.1)

func _sub(text: String, col: Color) -> void:
	var p := PanelContainer.new()
	var sb: StyleBoxFlat = main.sbox(col, 999, 2, Color.WHITE, 0, 6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 5
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(main.lbl(text, 16, Color.WHITE))
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.offset_top = CH - 54
	card.add_child(p)
	p.modulate.a = 0.0
	p.create_tween().tween_property(p, "modulate:a", 1.0, 0.15)

func _confetti(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = _t(SPARK + "star_04.png")
	p.amount = 48
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 460.0
	p.gravity = Vector2(0, 620)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	var g := Gradient.new()
	g.set_color(0, Color("#ff5d7a"))
	g.set_color(1, Color("#5dd6ff"))
	g.add_point(0.33, Color("#ffd23f"))
	g.add_point(0.66, Color("#58e08a"))
	p.color_initial_ramp = g
	p.position = at
	card.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

# ---------------------------------------------------------------- drawing
func _col_y(v: float) -> float:
	return COL.size.y * (1.0 - v)

func fish_pos() -> Vector2:
	return COL.position + Vector2(COL.size.x * 0.5 + _fish_x, _col_y(fish_y) - _fish_out)

func _tick_bubbles(delta: float) -> void:
	_bub_t -= delta
	if _bub_t <= 0.0:
		_bub_t = randf_range(0.12, 0.3) * (0.4 if in_zone else 1.0)
		var from_fish := in_zone and randf() < 0.6
		var x := fish_pos().x - COL.position.x + randf_range(-20, 20) if from_fish else randf_range(8, COL.size.x - 8)
		var y := _col_y(fish_y) if from_fish else COL.size.y + 6.0
		_bubbles.append([x, y, randf_range(45, 95), randf_range(5, 13), randf() * TAU])
	for b in _bubbles:
		b[1] -= b[2] * delta
		b[4] += delta * 3.0
	_bubbles = _bubbles.filter(func(b): return b[1] > -16.0)

func _draw_board() -> void:
	var c := board
	c.draw_style_box(main.sbox(Color(0.985, 0.995, 1.0, 0.96), 30, 3, Color.WHITE, 0, 18), Rect2(Vector2.ZERO, card.size))
	# reel ring
	var col := Color("#f0a020").lerp(Color("#22c07b"), progress)
	if in_zone and phase == "play":
		var pulse := 0.5 + 0.5 * sin(t * 12.0)
		c.draw_arc(RING, RING_R + 13.0, 0, TAU, 64, Color(0.3, 0.9, 0.6, 0.18 + 0.2 * pulse), 6.0, true)
	c.draw_arc(RING, RING_R, 0, TAU, 72, Color(0.12, 0.3, 0.36, 0.12), 17.0, true)
	if progress > 0.005:
		var a0 := -PI / 2.0
		var a1 := a0 + TAU * progress
		c.draw_arc(RING, RING_R, a0, a1, 72, col, 17.0, true)
		c.draw_circle(RING + Vector2.from_angle(a0) * RING_R, 8.5, col)
		c.draw_circle(RING + Vector2.from_angle(a1) * RING_R, 8.5, col)
	# the reel: spins while you reel the fish in
	c.draw_circle(RING + Vector2(0, 3), 43.0, Color(0.02, 0.1, 0.14, 0.12))
	c.draw_circle(RING, 42.0, Color.WHITE)
	c.draw_arc(RING, 42.0, 0, TAU, 48, Color("#cfdde2"), 3.0, true)
	for i in 3:
		var a := _spin + TAU * i / 3.0
		c.draw_line(RING + Vector2.from_angle(a) * 10.0, RING + Vector2.from_angle(a) * 36.0, Color("#d7e4e8"), 6.0, true)
	var knob := RING + Vector2.from_angle(_spin * 1.0) * 30.0
	c.draw_line(RING, knob, Color("#1d9bb0"), 7.0, true)
	c.draw_circle(knob, 8.0, Color("#ffcf4a"))
	c.draw_arc(knob, 8.0, 0, TAU, 20, Color("#1f2d35"), 2.0, true)
	c.draw_circle(RING, 9.0, Color("#1d9bb0"))
	# time left
	var bar := Rect2(RING.x - 100, RING.y + RING_R + 52, 200, 10)
	c.draw_style_box(main.sbox(Color(0.12, 0.3, 0.36, 0.12), 999, 0, Color.TRANSPARENT, 0), bar)
	var left := 1.0 - clampf(play_t / time_limit, 0.0, 1.0)
	if left > 0.0:
		var tc := Color("#1d9bb0")
		if time_limit - play_t < 2.0 and phase == "play":
			tc = Color("#e04f45") if fmod(t, 0.3) < 0.18 else Color("#ff8a7a")
		c.draw_style_box(main.sbox(tc, 999, 0, Color.TRANSPARENT, 0), Rect2(bar.position, Vector2(maxf(10.0, bar.size.x * left), bar.size.y)))
	var hg: Texture2D = main.ph("hourglass-medium")
	if hg: c.draw_texture_rect(hg, Rect2(bar.position + Vector2(-24, -6), Vector2(20, 20)), false, Color("#6b7d86"))

func _draw_column() -> void:
	var c := column
	var r := Rect2(Vector2.ZERO, COL.size)
	# water: light at the top, deep at the bottom
	var top_c := Color("#4cc3d6")
	var bot_c := Color("#0e4a6e")
	c.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([top_c, top_c, bot_c, bot_c]))
	for i in 3:      # sun rays
		var x0 := 20.0 + i * 46.0 + sin(t * 0.7 + i) * 8.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 22, 0), Vector2(x0 - 20, r.end.y), Vector2(x0 - 52, r.end.y)]),
			Color(1, 1, 1, 0.07))
	# sea floor (Kenney Fish Pack)
	_sway(c, FISHP + "seaweed_green_a.png", Vector2(18, r.end.y + 4), 0.62, 0.0)
	_sway(c, FISHP + "seaweed_pink_b.png", Vector2(r.end.x - 20, r.end.y + 4), 0.7, 1.7)
	c.draw_texture_rect(_t(FISHP + "rock_a.png"), Rect2(Vector2(r.size.x * 0.5 - 34, r.end.y - 62), Vector2(68, 68)), false)
	_sway(c, FISHP + "seaweed_orange_a.png", Vector2(r.size.x * 0.5 + 22, r.end.y + 4), 0.55, 3.1)
	# rising bubbles
	var btx := _t(FISHP + "bubble_c.png")
	for b in _bubbles:
		var s: float = b[3]
		var p := Vector2(b[0] + sin(b[4]) * 3.0, b[1])
		c.draw_texture_rect_region(btx, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Rect2(40, 40, 48, 48), Color(1, 1, 1, 0.75))
	# catch zone + the line it hangs on
	var zt := _col_y(zone_y + zone_h)
	var zb := _col_y(zone_y)
	var cx := r.size.x * 0.5
	c.draw_line(Vector2(cx, 0), Vector2(cx, zt), Color(1, 1, 1, 0.55 * _zone_a), 2.0, true)
	var zr := Rect2(6, zt, r.size.x - 12, zb - zt)
	var sb := _sb_zone_in if in_zone else _sb_zone
	if _zone_a > 0.99:
		c.draw_style_box(sb, zr)
	else:
		c.draw_rect(zr, Color(1, 1, 1, 0.1 * _zone_a))
	for i in 3:          # grip lines
		var gy := zr.get_center().y + (i - 1) * 7.0
		c.draw_line(Vector2(cx - 16, gy), Vector2(cx + 16, gy), Color(1, 1, 1, 0.75 * _zone_a), 3.0, true)
	# little hook at the top of the zone
	c.draw_arc(Vector2(cx + 5, zt - 1), 6.0, 0.0, PI, 10, Color(1, 1, 1, 0.9 * _zone_a), 2.5, true)
	# frame
	var fr := StyleBoxFlat.new()
	fr.draw_center = false
	fr.set_border_width_all(4)
	fr.border_color = Color.WHITE
	fr.set_corner_radius_all(20)
	fr.anti_aliasing = true
	c.draw_style_box(fr, r.grow(2))

func _sway(c: Control, path: String, base: Vector2, sc: float, ph: float) -> void:
	var tx := _t(path)
	c.draw_set_transform(base, sin(t * 1.6 + ph) * 0.08, Vector2(sc, sc))
	c.draw_texture(tx, Vector2(-64, -128))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _ellipse(c: CanvasItem, at: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(at + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(pts, col)

func _draw_top() -> void:
	var c := top
	var fp := fish_pos()
	var look: Dictionary = LOOKS[tier]
	var ink := Color("#1f2d35")
	# speech bubble tail, pointing at the fish's mouth
	if bubble.visible:
		var bp := bubble.position + Vector2(4, bubble.size.y * 0.5)
		var mouth: Vector2 = fp + (Vector2(look.mouth) - Vector2(64, 64)) * 0.95
		var tip := bp + (mouth - bp).limit_length(58.0)
		var tri := PackedVector2Array([bp + Vector2(0, -13), bp + Vector2(0, 13), tip])
		c.draw_colored_polygon(tri, Color.WHITE)
		c.draw_polyline(PackedVector2Array([bp + Vector2(0, -13), tip, bp + Vector2(0, 13)]), ink, 3.0, true)
	# the fish (squash & stretch, wiggle) + a cartoon face on top of the Kenney sprite
	c.draw_set_transform(fp, _fish_rot, _fish_squash * 0.95)
	c.draw_texture(_t(FISHP + String(look.tex) + ".png"), Vector2(-64, -64))
	var e: Vector2 = Vector2(look.eye) - Vector2(64, 64)
	var m: Vector2 = Vector2(look.mouth) - Vector2(64, 64)
	var talking := _talk_t > 0.0
	match _face:
		"raspberry":
			c.draw_arc(e + Vector2(0, 4), 8.0, PI * 1.12, PI * 1.88, 10, ink, 4.0, true)     # ^ squeezed shut
			_ellipse(c, m + Vector2(1, 0), 6.0, 6.0, Color("#3a1420"))
			_ellipse(c, m + Vector2(10, 5), 11.0, 7.0, Color("#ff6f91"))                      # tongue out
			c.draw_line(m + Vector2(4, 5), m + Vector2(15, 6), Color("#d94a6e"), 2.0, true)
		"dizzy":
			c.draw_circle(e, 11.0, Color.WHITE)
			c.draw_arc(e, 11.0, 0, TAU, 20, ink, 2.5, true)
			c.draw_line(e + Vector2(-6, -6), e + Vector2(6, 6), ink, 3.0, true)
			c.draw_line(e + Vector2(-6, 6), e + Vector2(6, -6), ink, 3.0, true)
			_ellipse(c, m, 5.0, 3.0 + 2.0 * absf(sin(t * 9.0)), Color("#3a1420"))
		_:
			var worried := _face == "worried"
			var er := 13.0 if worried else 11.0
			c.draw_circle(e, er, Color.WHITE)
			# pupil: watches the catch zone, or you while talking
			var zc := COL.position + Vector2(COL.size.x * 0.5, _col_y(zone_y + zone_h * 0.5))
			var dir := (zc - fp).rotated(-_fish_rot).normalized() if not talking else Vector2(0.9, 0.2)
			c.draw_circle(e + dir * (er - 6.0), 4.0 if worried else 5.0, ink)
			c.draw_circle(e + dir * (er - 6.0) + Vector2(-1.5, -1.5), 1.4, Color.WHITE)
			c.draw_arc(e, er, 0, TAU, 24, ink, 2.5, true)
			if worried:
				c.draw_line(e + Vector2(-12, -17), e + Vector2(9, -23), ink, 4.5, true)      # brows up
			else:
				# smug half-closed lid + cocky brow
				var lid := PackedVector2Array()
				for i in 11:
					lid.append(e + Vector2.from_angle(PI + PI * i / 10.0) * (er + 0.5))
				lid.append(e + Vector2(er, -1.0))
				lid.append(e + Vector2(-er, -1.0))
				c.draw_colored_polygon(lid, look.lid)
				c.draw_line(e + Vector2(-er - 1, -1), e + Vector2(er + 1, -1), ink, 2.5, true)
				c.draw_line(e + Vector2(-13, -20), e + Vector2(10, -15), ink, 4.5, true)
			if talking:
				_ellipse(c, m, 6.0, 2.0 + 5.0 * absf(sin(t * 22.0)), Color("#3a1420"))
			elif worried:
				_ellipse(c, m, 4.0, 4.0, Color("#3a1420"))
			else:
				c.draw_arc(m + Vector2(-3, -5), 6.0, PI * 0.2, PI * 0.8, 8, ink, 2.5, true)  # smirk
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# reaction emote (Kenney Emotes Pack) popping above its head
	if _emote != "" and _emote_t < 1.6:
		var k := clampf(_emote_t / 0.18, 0.0, 1.0)
		var s := 2.0 * (1.0 + 0.35 * sin(k * PI)) * k
		var a := clampf((1.6 - _emote_t) / 0.25, 0.0, 1.0)
		var et := _t(EMO + "emote_%s.png" % _emote)
		var sz := Vector2(32, 38) * s
		var at := fp + Vector2(34, -60 - 6.0 * sin(_emote_t * 5.0))
		c.draw_texture_rect(et, Rect2(at - Vector2(sz.x * 0.5, sz.y), sz), false, Color(1, 1, 1, a))

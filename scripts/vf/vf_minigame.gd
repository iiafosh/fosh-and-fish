extends Control
## "Reel it in!" - the skill catch (VF.catch_mode == "reel", numbers in VFData.MINIGAME_*).
## After the bite the very fish that bit (vf_life.render_mini, with a cartoon face drawn on it) wiggles in a
## window of water: hold (mouse / touch anywhere / Space) to lift the net and keep the fish inside it until the
## reel ring is full. The fish doesn't make it easy: every couple of seconds it pulls a gag (a disguise, a selfie,
## playing dead, a banana peel, a shark passing by...), and some species have their own. Rarer fish wiggle harder.
## resolved(won) fires the moment it is decided (vf_main gives the catch right away), then a short win / fail gag
## plays (tap to skip): a mugshot, or a WANTED poster.
## Art: Kenney Fish Pack (seaweed, bubbles) + Emotes Pack (CC0). Props are drawn here.

signal resolved(won: bool)

const FISHP := "res://assets/third_party/kenney_fish/"
const EMO := "res://assets/third_party/kenney_emotes/"
const SPARK := "res://assets/third_party/kenney_particles/"
const CW := 600.0
const CH := 480.0
const COL := Rect2(24, 70, 276, 382)           # the window of water inside the card
const RING := Vector2(452, 240)                # centre of the reel ring
const RING_R := 60.0
const FISH_PX := 176.0                         # a cell of the fish's sheet, on screen
const INK := Color("#23343c")
const CARD := Color("#f8f4ea")
const TIER_COL := [Color("#5f7079"), Color("#1a8a9d"), Color("#2f6fd6"), Color("#8b3fd1"), Color("#c58a12")]
const NAMES := ["Gerald", "Kevin", "Big Steve", "Susan", "Mr. Wiggles", "Dave", "Karen", "Lil' Finn", "Bubbles", "Sir Flops", "Tiny",
	"Brenda", "Old Gary", "Noodle", "Captain Soggy", "Doug", "Pickles", "Wanda", "Gill", "Phil"]
const FACTS := ["Owes a crab money.", "Never read the terms.", "Thought it was Tuesday.", "One day from retiring.", "Had a great personality.",
	"Left the stove on.", "Collected bottle caps.", "Survived 3 hooks. Not 4.", "Could've been a contender.", "Allergic to buckets."]
const WANTED := ["Reward: 3 shrimp", "Last seen laughing", "Armed and slippery", "Do not feed", "Extremely smug"]
const SAY_START := ["You'll never catch me!", "blub blub ;P", "Is that hook made of spaghetti?", "Come at me, bro.",
	"I've escaped better fishers!", "Catch me if you can!", "My mom swims faster than you reel."]
const SAY_SPECIES := {"Raw Fish": "I'm called Raw Fish. Have some pity.", "Raw Salmon": "I was just going upstream!", "Cod": "Oh my cod.",
	"Tropical Fish": "I'm on vacation!", "Pufferfish": "Don't make me puff.", "Fiery Pufferfish": "Hot stuff coming through!",
	"Hot Cod": "I'm too hot to handle.", "Squid": "Eight arms and zero patience.", "Turtle": "I'll outlive you.", "Dolphin": "I'm smarter than you, you know.",
	"Guardian": "I guard things. Mostly this.", "Emerald Squid": "Do you know what I'm worth?", "Rainbow Fish": "Fabulous, darling.",
	"Space Fish": "In space, no one hears you reel.", "Galactic Crab": "Snip. From orbit.", "Shark": "You're gonna need a bigger boat.",
	"Alien Fish": "Take me to your bait.", "Artifact Fish": "I belong in a museum!", "Dark Puffer": "I'm a puffer. But edgy.", "Dark Tuna": "Nobody asked for dark tuna."}
const SAY_FAMOUS := ["Wait. You're the one from the posters!", "They warned me about you.", "The fish talk about you, you know.", "Oh no. It's YOU."]
const SAY_ESCAPE := ["Too slow!", "Nyeh nyeh!", "Missed me!", "Over here, genius!", "Wheee!", "Nope!", "Butterfingers!"]
const SAY_CAUGHT := ["Hey! Let go!", "This is fine.", "Okay, that tickles!", "Unhand me!", "No no no no"]
const SAY_ALMOST := ["Wait wait, let's talk!", "I have a family! (I don't)", "MOMMYYY!", "I'll pay you 3 shrimp!", "Not the frying pan!", "I know a guy!"]
const SAY_WIN := ["Fine. You win. THIS time.", "Tell my story...", "Ugh. GG.", "I'm too pretty for a bucket!"]
const SAY_LOSE := ["PFFFT! Bye, loser!", "Later, sucker!", "blub blub, see ya!", "Git gud, fisher!"]
const PUNS := ["GOTCHA!", "YOINK!", "REEL GOOD!", "FIN-TASTIC!", "HOLY MACKEREL!", "O-FISH-AL!", "SHELL YEAH!", "SPLOOSH!"]
# what the fish can pull: how long it takes, what it says
const GAGS := {
	"disguise": {"len": 1.5, "say": ["Who, me? I'm a rock.", "Nothing to see here.", "Sir, this is a reef.", "Never seen that fish."]},
	"selfie": {"len": 1.3, "say": ["For my FishTok!", "Caption: hook, line, stinker.", "Say cheese! Not you."]},
	"dead": {"len": 1.5, "say": ["I'm dead. Totally dead.", "Oh no. I died. Go away.", "Rest in fish."]},
	"nap": {"len": 1.5, "say": ["Wake me when you're good.", "Five more minutes...", "You're boring me."]},
	"shark": {"len": 2.0, "say": ["TAKE ME! TAKE ME!", "I LOVE BUCKETS NOW!", "YOU WIN! JUST HURRY!"]},
	"banana": {"len": 1.0, "say": ["Oopsie!", "Mind the peel!", "Slippery, isn't it?"]},
	"rocket": {"len": 0.9, "say": ["BYE!", "TO THE MOON!", "Can't catch a rocket!"]},
	"boot": {"len": 1.4, "say": ["Nice catch, genius!", "Size 12. Yours?", "That's your catch today."]},
	"dance": {"len": 1.4, "say": ["Too fabulous to catch!", "Look at these fins!", "Five stars. No notes."]},
	"bribe": {"len": 1.3, "say": ["Psst. $3 and we never met.", "How about a shrimp?", "Everyone has a price."]},
	"puff": {"len": 1.9, "say": ["OOPS. I PUFFED.", "Not again...", "It's a medical condition!"]},
	"ink": {"len": 1.5, "say": ["Can't see me!", "That wasn't me. That was ink.", "Excuse me. Pardon."]},
	"closed": {"len": 1.5, "say": ["Nobody's home.", "Leave a message.", "We gave at the office."]},
	"flip": {"len": 0.9, "say": ["Eee-hee-hee!", "Ten out of ten!", "Did you see that?!"]},
	"chomp": {"len": 1.0, "say": ["I'm a vegetarian. Honest.", "Nice line. Looks tasty.", "Just a nibble."]},
	"snip": {"len": 0.9, "say": ["Snip snip!", "Oops, was that yours?", "Nice line you had."]},
}
const STAYS_PUT := ["disguise", "selfie", "dead", "nap", "dance", "bribe", "closed", "flip"]

static var streak := 0        # wins in a row (this session): the fish start to hear about you

var main                     # vf_main.gd (UI kit: lbl, sbox, keycap, is_touch, stage)
var fish_name := ""
var tier := 0
var auto := ""               # capture tests: "win" / "lose" plays by itself
var nick := "Gerald"

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
var column: Control          # water, shark, net (clipped)
var top: Control             # fish, props, emote, bubble tail (not clipped: the fish can fly out)
var over_col: Control        # ink, camera flash (clipped to the window)
var bubble: PanelContainer
var bubble_lbl: Label
var status: Label
var hint: Control
var skip_lbl: Label
var _tex := {}
var _sp := {}                # the fish's sheet: tex, frames, cell, and its face in px around the picture's centre
var _top_c := Color("#4cc3d6")
var _bot_c := Color("#0e4a6e")
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
var _face := "smug"          # smug / worried / dizzy / raspberry / panic / shut
var _fish_x := 0.0
var _fish_rot := 0.0
var _fish_squash := Vector2.ONE
var _fish_out := 0.0         # end gag: px the fish has left the column (+ up, - down)
var _zone_a := 1.0
var _end_len := 1.5
var _done := false
var _sb_zone: StyleBoxFlat
var _sb_zone_in: StyleBoxFlat
# the gag it's pulling
var _gag := ""
var _gag_t := 0.0
var _gag_len := 0.0
var _gag_wait := 1.0
var _gag_step := 0           # what has already happened in it (a thrown peel landed, the flash went off ...)
var _used: Array = []
var _heavy := 0.0            # a boot on the line
var _slip := 0.0             # the net on a banana peel
var _small := 0.0            # the net got snipped
var _ink: Array = []
var _flash := 0.0
var _puff := 0.0
var _poster_k := 0.0         # the mugshot / WANTED poster sliding in
var _fact := ""
var _shades_k := 0.0
var _hit_word := ""
var _hit_t := 9.0

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
	nick = NAMES.pick_random()
	if tier >= 3: nick = ["Lord ", "Lady ", "Sir ", "The Great "].pick_random() + nick.trim_prefix("Sir ")
	_fact = FACTS.pick_random()
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
	_gag_wait = randf_range(0.7, 1.4)
	_load_fish()

## the fish's picture and where its face goes
func _load_fish() -> void:
	var mini: Dictionary = main.stage.manifest.get("mini", {})
	var info: Dictionary = mini.get("fish", {}).get(fish_name, {})
	if info.is_empty():
		_sp = {}
		return
	var cell: float = mini.cell
	var k := FISH_PX / cell
	_sp = {"tex": main.stage._tex("mini/%s.png" % VFData.slug(fish_name)), "frames": int(mini.frames), "cell": cell,
		"eye": (Vector2(info.eye[0], info.eye[1]) - Vector2(0.5, 0.5)) * FISH_PX,
		"mouth": (Vector2(info.mouth[0], info.mouth[1]) - Vector2(0.5, 0.5)) * FISH_PX,
		"er": maxf(float(info.er) * cell * k * 1.9, 11.0)}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.08, 0.12, 0.38)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)
	if main and main.stage and not main.stage._scene.is_empty():    # the water of the biome you're in
		var w: Array = main.stage._scene.water
		_top_c = Color(w[0]).lerp(Color(w[1]), 0.35)
		_bot_c = Color(w[1]).darkened(0.42)
	card = Control.new()
	card.size = Vector2(CW, CH)
	card.pivot_offset = card.size * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var vs := get_viewport_rect().size
	# the card plus its banner above and the result pill below is ~CH + 90 tall: shrink it on short (phone) screens
	_fit = minf(1.0, minf((vs.y - 12.0) / (CH + 90.0), (vs.x - 16.0) / CW))
	_card_base = ((vs - card.size) * 0.5 + Vector2(0, 12) * _fit).round()
	card.position = _card_base
	if main and main.stage: _stage_base = main.stage.position
	board = _layer(card, Rect2(Vector2.ZERO, card.size), _draw_board)
	column = _layer(card, COL, _draw_column)
	column.clip_contents = true
	top = _layer(card, Rect2(Vector2.ZERO, card.size), _draw_top)
	over_col = _layer(card, COL, _draw_over_col)
	over_col.clip_contents = true
	_sb_zone = main.sbox(Color(1, 1, 1, 0.2), 16, 3, Color(1, 1, 1, 0.85), 0)
	_sb_zone_in = main.sbox(Color(0.5, 1.0, 0.75, 0.28), 16, 3, Color("#d9ffe9"), 0)
	_sb_zone_in.shadow_color = Color(0.5, 1, 0.75, 0.4)
	_sb_zone_in.shadow_size = 8
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
	var line: String = SAY_START.pick_random()
	if streak >= 3: line = SAY_FAMOUS.pick_random()
	elif randf() < 0.55 and SAY_SPECIES.has(fish_name): line = SAY_SPECIES[fish_name]
	_say(line)
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
	var hsb: StyleBoxFlat = main.sbox(Color("#1a8a9d"), 999, 3, Color("#f8f4ea"), 0, 8)
	hsb.content_margin_left = 22
	hsb.content_margin_right = 26
	hsb.content_margin_top = 4
	hsb.content_margin_bottom = 6
	head.add_theme_stylebox_override("panel", hsb)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 8)
	var bolt: TextureRect = main.icon(main.ph("lightning"), 24)
	bolt.modulate = Color("#ffd75e")
	hh.add_child(bolt)
	hh.add_child(main.lbl("REEL IT IN!", 24, Color.WHITE, 0))
	head.add_child(hh)
	head.anchor_left = 0.5
	head.anchor_right = 0.5
	head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	head.offset_top = -24
	card.add_child(head)
	head.rotation = -0.03
	var who: Label = main.lbl("%s the %s is on the line!" % [nick, fish_name], 15, TIER_COL[tier])
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.position = Vector2(0, 34)
	who.size = Vector2(CW, 24)
	card.add_child(who)
	if streak >= 2:
		var st := HBoxContainer.new()
		st.add_theme_constant_override("separation", 4)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fi: TextureRect = main.icon(main.ph("fire"), 18)
		fi.modulate = Color("#e8843a")
		st.add_child(fi)
		st.add_child(main.lbl("x%d" % streak, 15, Color("#c9692a")))
		st.position = Vector2(CW - 62, 34)
		card.add_child(st)
	# the fish's speech bubble
	bubble = PanelContainer.new()
	var bsb: StyleBoxFlat = main.sbox(Color.WHITE, 18, 2, INK, 0, 3)
	bsb.content_margin_left = 12
	bsb.content_margin_right = 12
	bsb.content_margin_top = 7
	bsb.content_margin_bottom = 9
	bubble.add_theme_stylebox_override("panel", bsb)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_lbl = main.lbl("", 16, INK)
	bubble_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_lbl.custom_minimum_size.x = 226
	bubble_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.add_child(bubble_lbl)
	bubble.position = Vector2(326, 66)
	card.add_child(bubble)
	status = main.lbl("FISH ON!", 19, INK)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.position = Vector2(RING.x - 125, RING.y + RING_R + 12)
	status.size = Vector2(250, 28)
	card.add_child(status)
	# your rod's reel power (better rods make this easier)
	var rp := HBoxContainer.new()
	rp.alignment = BoxContainer.ALIGNMENT_CENTER
	rp.add_theme_constant_override("separation", 6)
	rp.add_child(main.icon(main.icon_for("rod", VF.rod), 20))
	var pips := ""
	var lvl := int(round(reel_power * 10.0))
	for i in 10: pips += "•" if i < lvl else "·"
	rp.add_child(main.lbl("%s  reel power %d/10" % [VF.rod, lvl], 13, Color("#1a8a9d")))
	rp.position = Vector2(RING.x - 130, RING.y + RING_R + 70)   # under the timer bar, above the hint
	rp.size = Vector2(260, 24)
	rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rp.tooltip_text = "Better rods reel faster and give you a bigger net. " + pips
	card.add_child(rp)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	if not main.is_touch():
		hb.add_child(main.keycap("Space"))
		hb.add_child(main.lbl("or hold the mouse to reel", 14, Color("#6b7d86")))
	else:
		hb.add_child(main.lbl("Hold anywhere to reel", 15, Color("#6b7d86")))
	hb.position = Vector2(RING.x - 130, CH - 46)
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
	_hit_t += delta
	_flash = maxf(0.0, _flash - delta * 2.6)
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
	over_col.queue_redraw()

func _holding() -> bool:
	if auto == "win":
		return zone_y + _net_h() * 0.5 + zone_v * 0.22 < fish_y
	if auto == "lose":
		return sin(play_t * 2.3) > 0.55
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_F)

func _net_h() -> float:
	return zone_h * (0.72 if _small > 0.0 else 1.0)

func _play(delta: float) -> void:
	play_t += delta
	_heavy = maxf(0.0, _heavy - delta)
	_slip = maxf(0.0, _slip - delta)
	_small = maxf(0.0, _small - delta)
	# the net: hold to lift, let go to sink (with a little bounce on the floor). A boot on the line weighs it
	# down, and on a banana peel it slides about.
	var nh := _net_h()
	var up := lift * (0.7 if _heavy > 0.0 else 1.0)
	var down := sink * (1.5 if _heavy > 0.0 else 1.0)
	zone_v = clampf(zone_v + (up if _holding() else -down) * delta, -max_v, max_v)
	if _slip > 0.0: zone_v += sin(play_t * 19.0) * 7.0 * delta
	zone_y += zone_v * delta
	if zone_y < 0.0:
		zone_y = 0.0
		zone_v = -zone_v * 0.35 if zone_v < -0.4 else 0.0
	if zone_y > 1.0 - nh:
		zone_y = 1.0 - nh
		zone_v = minf(zone_v, 0.0)
	_gag_tick(delta)
	# the fish: picks a new spot every so often, sometimes darts (rarer fish dart more), unless it's busy being funny
	retarget -= delta
	if retarget <= 0.0 and _gag == "":
		fish_target = randf_range(0.1, 0.9)
		dart = 2.2 if randf() < 0.12 + 0.07 * tier else 1.0
		retarget = randf_range(0.55, 1.35) - 0.08 * tier
	var speed := fish_speed * dart
	match _gag:
		"shark":
			fish_target = clampf(zone_y + nh * 0.5, 0.08, 0.92)      # hide in the net!
			speed = fish_speed * 3.0
		"chomp":
			fish_target = clampf(zone_y + nh * 0.5, 0.08, 0.92)
			speed = fish_speed * 1.5
		"nap", "dead":
			fish_target = 0.12
			speed = 0.05
		"rocket": speed = 2.8
		"puff":
			if _gag_t < 0.95:
				fish_target = 0.9
				speed = 0.8
			else:                                  # let go like a balloon
				if int(_gag_t * 9.0) != int((_gag_t - delta) * 9.0): fish_target = randf_range(0.1, 0.92)
				speed = 2.6
		_:
			if _gag in STAYS_PUT: speed = 0.05
	var before := fish_y
	fish_y = move_toward(fish_y, fish_target, speed * delta)
	fish_y = clampf(fish_y + sin(play_t * (5.0 + tier)) * 0.002 * (1 + tier), 0.08, 0.92)
	var vy := (fish_y - before) / maxf(delta, 0.001)
	_fish_rot = lerpf(_fish_rot, clampf(-vy * 0.45, -0.6, 0.6) + sin(play_t * 7.0) * 0.06, minf(1.0, delta * 10.0))
	var st := 1.0 + minf(absf(vy) * 0.25, 0.2)                     # stretch when darting
	_fish_squash = Vector2(st + 0.07 * sin(play_t * 16.0), (1.0 / st) - 0.07 * sin(play_t * 16.0))
	_fish_x = sin(play_t * 1.3) * 34.0 + sin(play_t * 3.1) * 7.0
	_gag_pose()
	# reel progress
	in_zone = fish_y >= zone_y and fish_y <= zone_y + nh
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
	# reactions (the gags have their own)
	if _gag == "":
		if _was_in and not in_zone and _in_time > 0.3:
			_show_emote("laugh")
			AudioManager.play_sfx("bubble", -8.0, 0.55)
			if _taunt_cd <= 0.0: _say(SAY_ESCAPE.pick_random())
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
	if not _was_in and in_zone:
		_in_time = 0.0
	_was_in = in_zone
	var left := time_limit - play_t
	if in_zone:
		status.text = "REELING!  %d%%" % int(progress * 100.0)
		status.add_theme_color_override("font_color", Color("#16865a"))
	elif left < 2.0:
		status.text = "HURRY!  %d%%" % int(progress * 100.0)
		status.add_theme_color_override("font_color", Color("#d9594e"))
	else:
		status.text = "SLIPPING...  %d%%" % int(progress * 100.0)
		status.add_theme_color_override("font_color", Color("#b0732a"))
	if progress >= 1.0: _finish(true)
	elif play_t >= time_limit: _finish(false)

# ---------------------------------------------------------------- the gags
func _pick_gag() -> String:
	var own := ""
	if "Puffer" in fish_name: own = "puff"
	elif "Squid" in fish_name: own = "ink"
	elif fish_name == "Turtle": own = "closed"
	elif fish_name == "Dolphin": own = "flip"
	elif fish_name == "Shark": own = "chomp"
	elif "Crab" in fish_name: own = "snip"
	if own != "" and not own in _used and randf() < 0.7: return own
	var pool := ["disguise", "selfie", "dead", "nap", "shark", "dance", "bribe", "banana"]
	if tier >= 1: pool += ["boot", "rocket"]
	if own == "chomp": pool.erase("shark")
	var fresh := pool.filter(func(g): return not g in _used)
	return (fresh if not fresh.is_empty() else pool).pick_random()

func _gag_tick(delta: float) -> void:
	if _gag == "":
		_gag_wait -= delta
		if _gag_wait <= 0.0 and progress < 0.93 and play_t < time_limit - 1.2:
			_start_gag(_pick_gag())
		return
	_gag_t += delta
	match _gag:
		"selfie":
			if _gag_step == 0 and _gag_t > 0.65:
				_gag_step = 1
				_flash = 1.0
				AudioManager.play_fun("shutter", -8.0)
		"banana":
			if _gag_step == 0 and _gag_t > 0.45:            # the peel lands on the net
				_gag_step = 1
				_slip = 0.8
				zone_v -= 0.7
				_hit("WHOOPS!")
				AudioManager.play_fun("slide_down", -10.0, 1.2)
		"boot":
			if _gag_step == 0 and _gag_t > 0.45:
				_gag_step = 1
				_heavy = 1.1
				_shake = 0.3
				AudioManager.play_fun("clunk", -6.0)
		"chomp":
			if _gag_step == 0 and _gag_t > 0.4:
				_gag_step = 1
				_shake = 0.5
				zone_v -= 0.5
				_hit("CHOMP!")
				AudioManager.play_fun("clunk", -8.0, 1.4)
		"snip":
			if _gag_step == 0 and _gag_t > 0.3:
				_gag_step = 1
				_small = 1.8
				_hit("SNIP!")
				AudioManager.play_fun("snip", -6.0)
		"puff":
			_puff = clampf(_gag_t / 0.3, 0.0, 1.0) if _gag_t < 0.95 else clampf(1.0 - (_gag_t - 0.95) / 0.9, 0.0, 1.0)
			if _gag_step == 0 and _gag_t > 0.95:
				_gag_step = 1
				AudioManager.play_fun("pfff", -7.0)
	if _gag_t >= _gag_len: _end_gag()

func _start_gag(g: String) -> void:
	_gag = g
	_gag_t = 0.0
	_gag_len = float(GAGS[g].len)
	_gag_step = 0
	_used.append(g)
	_say(GAGS[g].say.pick_random())
	match g:
		"disguise", "selfie", "bribe", "dance": _face = "smug"
		"nap", "closed": _face = "shut"
		"dead":
			_face = "dizzy"
			AudioManager.play_fun("slide_down", -11.0)
		"shark":
			_face = "panic"
			_show_emote("exclamation")
			AudioManager.play_fun("dundun", -5.0)
		"rocket":
			fish_target = 0.9 if fish_y < 0.5 else 0.1
			_face = "smug"
			AudioManager.play_fun("whoosh", -7.0)
		"puff":
			_face = "panic"
			fish_target = 0.9
			AudioManager.play_fun("slide_up", -10.0)
		"ink":
			_face = "smug"
			_ink.clear()
			for i in 11:
				_ink.append([Vector2(randf_range(10.0, COL.size.x - 10.0), COL.size.y * (1.0 - fish_y) + randf_range(-110.0, 110.0)), randf_range(30.0, 62.0), randf() * TAU])
			AudioManager.play_fun("pfff", -14.0, 1.5)
		"flip": AudioManager.play_fun("boing", -9.0, 1.3)
		"banana": AudioManager.play_fun("pop", -8.0)
		"chomp": _face = "smug"

func _end_gag() -> void:
	_gag = ""
	_puff = 0.0
	_face = "smug"
	_gag_wait = randf_range(1.8, 2.6)
	retarget = 0.0

## what the gag does to how it looks, after the swimming
func _gag_pose() -> void:
	match _gag:
		"flip": _fish_rot = -TAU * clampf(_gag_t / _gag_len, 0.0, 1.0)
		"dead":
			_fish_squash.y *= -1.0                         # belly up
			_fish_rot = 0.1
		"nap": _fish_rot = lerpf(_fish_rot, 0.4, 0.2)
		"dance":
			_fish_rot = sin(_gag_t * 16.0) * 0.32
			_fish_x += sin(_gag_t * 8.0) * 22.0
			_fish_squash = Vector2(1.0 + 0.12 * sin(_gag_t * 16.0), 1.0 - 0.12 * sin(_gag_t * 16.0))
		"rocket":
			_fish_rot = -0.5 if fish_target > fish_y else 0.5
			_fish_squash = Vector2(1.25, 0.84)
		"puff":
			if _gag_t > 0.95: _fish_rot += 0.5
			_fish_squash *= 1.0 + _puff * 0.32

func _hit(word: String) -> void:
	_hit_word = word
	_hit_t = 0.0

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
	_gag = ""
	_puff = 0.0
	hint.visible = false
	skip_lbl.visible = true
	streak = streak + 1 if w else 0
	resolved.emit(w)
	var tw := create_tween()
	if w:
		_face = "dizzy"
		_show_emote("swirl")
		_say(SAY_WIN.pick_random())
		status.text = "CAUGHT!"
		status.add_theme_color_override("font_color", Color("#16865a"))
		_pop("PERFECT!" if perfect else PUNS.pick_random(), Color("#ffcf4a"))
		var extra := "  ·  x%d in a row!" % streak if streak >= 2 else ""
		_sub("+%d%% fish!%s" % [int(round(VFData.MINIGAME_FISH_BONUS * 100.0)), extra], Color("#159a64"))
		_shake = 1.0
		_confetti(COL.position + Vector2(COL.size.x * 0.5, 40.0))
		AudioManager.play_sfx("splash_big", -2.0)
		AudioManager.play_success()
		if perfect: AudioManager.play_levelup()
		if main and main.stage:
			main.stage.burst("splash", main.stage._bobber)
			main.stage.burst("sparkle", main.stage._bobber)
		# yanked out of the water, spinning, and then its mugshot
		tw.tween_property(self, "_fish_out", 430.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(self, "_fish_rot", -TAU - 0.4, 0.55)
		tw.tween_property(self, "_poster_k", 1.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_end_len = 2.1
	else:
		_face = "raspberry"
		_show_emote("laugh")
		_say(SAY_LOSE.pick_random())
		status.text = "IT GOT AWAY!"
		status.add_theme_color_override("font_color", Color("#d9594e"))
		_pop(["PFFFT!", "BLEHHH!", "NOPE!"].pick_random(), Color("#ff9db5"))
		_sub("Slippery! Normal catch, no bonus", Color("#5d6f78"))
		_shake = 0.4
		for i in 6:      # a wet raspberry: pbbbbt
			get_tree().create_timer(0.05 + i * 0.055).timeout.connect(func(): AudioManager.play_sfx("bubble", -5.0, randf_range(0.4, 0.52)))
		tw.tween_property(self, "_zone_a", 0.2, 0.25)
		tw.tween_property(self, "_shades_k", 1.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)   # deal with it
		tw.tween_interval(0.35)
		tw.tween_property(self, "_fish_rot", 0.9, 0.12)
		tw.tween_property(self, "_fish_out", -440.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_callback(func(): AudioManager.play_sfx("splash", -6.0, 1.3)).set_delay(0.1)
		tw.tween_property(self, "_poster_k", 1.0, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_end_len = 2.5

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

## capture tests: this fish pulls this gag right now
func test_gag(fname: String, g: String) -> void:
	fish_name = fname
	_load_fish()
	_end_gag()
	progress = 0.35
	play_t = 0.0
	time_limit = 999.0
	_start_gag(g)

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
	pop.position = RING + Vector2(0, -12)      # over the reel, so the window stays in view
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.draw.connect(func():
		var pts := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			var r := 1.0 if i % 2 == 0 else 0.76
			pts.append(Vector2(cos(a) * 138.0 * r, sin(a) * 78.0 * r))
		var sh := PackedVector2Array()
		for p in pts: sh.append(p + Vector2(5, 7))
		pop.draw_colored_polygon(sh, Color(0.02, 0.1, 0.14, 0.3))
		pop.draw_colored_polygon(pts, fill)
		pts.append(pts[0])
		pop.draw_polyline(pts, INK, 4.0, true))
	var l: Label = main.lbl(word, 44 if word.length() <= 9 else 32, Color.WHITE)
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(320, 90)
	l.position = Vector2(-160, -46)
	pop.add_child(l)
	pop.rotation = -0.14
	pop.scale = Vector2(0.15, 0.15)
	card.add_child(pop)
	var tw := pop.create_tween()
	tw.tween_property(pop, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pop, "scale", Vector2.ONE, 0.1)
	tw.parallel().tween_property(pop, "rotation", -0.08, 0.1)

func _sub(text: String, col: Color) -> void:
	var p := PanelContainer.new()
	var sb: StyleBoxFlat = main.sbox(col, 999, 2, Color.WHITE, 0, 6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 5
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = main.lbl(text, 18, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.position = Vector2(RING.x - 134, CH - 58)
	p.size = Vector2(268, 34)
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
	c.draw_style_box(main.sbox(CARD, 30, 3, Color("#fffdf6"), 0, 14), Rect2(Vector2.ZERO, card.size))
	# reel ring
	var col := Color("#e9a23b").lerp(Color("#2fb97c"), progress)
	if in_zone and phase == "play":
		var pulse := 0.5 + 0.5 * sin(t * 12.0)
		c.draw_arc(RING, RING_R + 13.0, 0, TAU, 64, Color(0.3, 0.9, 0.6, 0.14 + 0.16 * pulse), 6.0, true)
	c.draw_arc(RING, RING_R, 0, TAU, 72, Color(0.12, 0.3, 0.36, 0.1), 17.0, true)
	if progress > 0.005:
		var a0 := -PI / 2.0
		var a1 := a0 + TAU * progress
		c.draw_arc(RING, RING_R, a0, a1, 72, col, 17.0, true)
		c.draw_circle(RING + Vector2.from_angle(a0) * RING_R, 8.5, col)
		c.draw_circle(RING + Vector2.from_angle(a1) * RING_R, 8.5, col)
	# the reel: spins while you reel the fish in
	c.draw_circle(RING + Vector2(0, 3), 43.0, Color(0.02, 0.1, 0.14, 0.1))
	c.draw_circle(RING, 42.0, Color("#fffdf8"))
	c.draw_arc(RING, 42.0, 0, TAU, 48, Color("#d8dfdc"), 3.0, true)
	for i in 3:
		var a := _spin + TAU * i / 3.0
		c.draw_line(RING + Vector2.from_angle(a) * 10.0, RING + Vector2.from_angle(a) * 36.0, Color("#dde5e3"), 6.0, true)
	var knob := RING + Vector2.from_angle(_spin * 1.0) * 30.0
	c.draw_line(RING, knob, Color("#1a8a9d"), 7.0, true)
	c.draw_circle(knob, 8.0, Color("#ffcf4a"))
	c.draw_arc(knob, 8.0, 0, TAU, 20, INK, 2.0, true)
	c.draw_circle(RING, 9.0, Color("#1a8a9d"))
	# time left
	var bar := Rect2(RING.x - 100, RING.y + RING_R + 48, 200, 10)
	c.draw_style_box(main.sbox(Color(0.12, 0.3, 0.36, 0.1), 999, 0, Color.TRANSPARENT, 0), bar)
	var left := 1.0 - clampf(play_t / time_limit, 0.0, 1.0)
	if left > 0.0:
		var tc := Color("#1a8a9d")
		if time_limit - play_t < 2.0 and phase == "play":
			tc = Color("#d9594e") if fmod(t, 0.3) < 0.18 else Color("#ee8a7b")
		c.draw_style_box(main.sbox(tc, 999, 0, Color.TRANSPARENT, 0), Rect2(bar.position, Vector2(maxf(10.0, bar.size.x * left), bar.size.y)))
	var hg: Texture2D = main.ph("hourglass-medium")
	if hg: c.draw_texture_rect(hg, Rect2(bar.position + Vector2(-24, -6), Vector2(20, 20)), false, Color("#6b7d86"))

func _draw_column() -> void:
	var c := column
	var r := Rect2(Vector2.ZERO, COL.size)
	# water: light at the top, deep at the bottom, in the colours of this biome
	c.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([_top_c, _top_c, _bot_c, _bot_c]))
	for i in 4:      # sun rays
		var x0 := 26.0 + i * 70.0 + sin(t * 0.7 + i) * 9.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 26, 0), Vector2(x0 - 22, r.end.y), Vector2(x0 - 62, r.end.y)]),
			Color(1, 1, 1, 0.06))
	# sea floor (Kenney Fish Pack)
	_sway(c, FISHP + "seaweed_green_a.png", Vector2(26, r.end.y + 4), 0.66, 0.0)
	_sway(c, FISHP + "seaweed_pink_b.png", Vector2(r.end.x - 28, r.end.y + 4), 0.74, 1.7)
	c.draw_texture_rect(_t(FISHP + "rock_a.png"), Rect2(Vector2(r.size.x * 0.5 - 40, r.end.y - 70), Vector2(80, 80)), false)
	_sway(c, FISHP + "seaweed_orange_a.png", Vector2(r.size.x * 0.5 + 34, r.end.y + 4), 0.6, 3.1)
	# rising bubbles
	var btx := _t(FISHP + "bubble_c.png")
	for b in _bubbles:
		var s: float = b[3]
		var p := Vector2(b[0] + sin(b[4]) * 3.0, b[1])
		c.draw_texture_rect_region(btx, Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Rect2(40, 40, 48, 48), Color(1, 1, 1, 0.7))
	# something big goes by behind the fish
	if _gag == "shark":
		var k := clampf(_gag_t / _gag_len, 0.0, 1.0)
		var at := Vector2(lerpf(r.end.x + 130.0, -130.0, k), _col_y(fish_y) + sin(k * 6.0) * 14.0 - 60.0)
		var shark := main.stage._tex("mini/shark.png") as Texture2D
		if shark:
			var cell: float = main.stage.manifest.mini.cell
			var fr := int(t * 8.0) % int(main.stage.manifest.mini.frames)
			c.draw_set_transform(at, 0.0, Vector2(-1, 1))
			c.draw_texture_rect_region(shark, Rect2(-125, -125, 250, 250), Rect2(fr * cell, 0, cell, cell), Color(0.04, 0.1, 0.17, 0.78))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the net, on its line
	var nh := _net_h()
	var zt := _col_y(zone_y + nh)
	var zb := _col_y(zone_y)
	var cx := r.size.x * 0.5
	c.draw_line(Vector2(cx, 0), Vector2(cx, zt), Color(1, 1, 1, 0.55 * _zone_a), 2.0, true)
	var wob := sin(t * 24.0) * 8.0 if _slip > 0.0 else 0.0
	var zr := Rect2(8 + wob, zt, r.size.x - 16, zb - zt)
	var sb := _sb_zone_in if in_zone else _sb_zone
	if _zone_a > 0.99:
		c.draw_style_box(sb, zr)
	else:
		c.draw_rect(zr, Color(1, 1, 1, 0.1 * _zone_a))
	var net := Color(1, 1, 1, 0.16 * _zone_a)                   # its mesh
	var step := 26.0
	var x := zr.position.x + 10.0
	while x < zr.end.x - 6.0:
		c.draw_line(Vector2(x, zr.position.y + 3), Vector2(x, zr.end.y - 3), net, 1.5, true)
		x += step
	var y := zr.position.y + 12.0
	while y < zr.end.y - 4.0:
		c.draw_line(Vector2(zr.position.x + 3, y), Vector2(zr.end.x - 3, y), net, 1.5, true)
		y += step
	# little hook at the top of the net
	c.draw_arc(Vector2(cx + 5, zt - 1), 6.0, 0.0, PI, 10, Color(1, 1, 1, 0.9 * _zone_a), 2.5, true)
	# frame
	var fr2 := StyleBoxFlat.new()
	fr2.draw_center = false
	fr2.set_border_width_all(4)
	fr2.border_color = Color("#fffdf6")
	fr2.set_corner_radius_all(20)
	fr2.anti_aliasing = true
	c.draw_style_box(fr2, r.grow(2))

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

func _draw_over_col() -> void:
	var c := over_col
	if _gag == "ink":
		var k := clampf(minf(_gag_t / 0.18, (_gag_len - _gag_t) / 0.4), 0.0, 1.0)
		for b in _ink:
			var at: Vector2 = b[0] + Vector2.from_angle(b[2] + t) * 5.0
			c.draw_circle(at, float(b[1]) * k, Color(0.05, 0.03, 0.11, 0.93))
	if _flash > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, COL.size), Color(1, 1, 1, _flash * 0.9))

func _draw_top() -> void:
	var c := top
	var fp := fish_pos()
	var ink := INK
	# speech bubble tail, pointing at the fish's mouth
	if bubble.visible and not _sp.is_empty():
		var bp := bubble.position + Vector2(4, bubble.size.y * 0.5)
		var mouth: Vector2 = fp + (_sp.mouth as Vector2).rotated(_fish_rot)
		var tip := bp + (mouth - bp).limit_length(58.0)
		var tri := PackedVector2Array([bp + Vector2(0, -11), bp + Vector2(0, 11), tip])
		c.draw_colored_polygon(tri, Color.WHITE)
		c.draw_polyline(PackedVector2Array([bp + Vector2(0, -11), tip, bp + Vector2(0, 11)]), ink, 2.0, true)
	if _poster_k < 0.3:                  # (then it's long gone, up in the air or under the card)
		_draw_fish(c, fp, _fish_rot, _fish_squash, _face, _talk_t > 0.0)
		_draw_props(c, fp)
	# reaction emote (Kenney Emotes Pack) popping above its head
	if _emote != "" and _emote_t < 1.6 and _poster_k < 0.3:
		var k := clampf(_emote_t / 0.18, 0.0, 1.0)
		var s := 1.7 * (1.0 + 0.35 * sin(k * PI)) * k
		var a := clampf((1.6 - _emote_t) / 0.25, 0.0, 1.0)
		var et := _t(EMO + "emote_%s.png" % _emote)
		var sz := Vector2(32, 38) * s
		var at := fp + Vector2(44, -70 - 6.0 * sin(_emote_t * 5.0))
		c.draw_texture_rect(et, Rect2(at - Vector2(sz.x * 0.5, sz.y), sz), false, Color(1, 1, 1, a))
	if _hit_t < 0.8:
		var a := clampf((0.8 - _hit_t) / 0.25, 0.0, 1.0)
		var f: Font = top.get_theme_default_font()
		var at := COL.position + Vector2(COL.size.x * 0.5 - 60.0, _col_y(zone_y + _net_h()) - 8.0 - _hit_t * 30.0)
		c.draw_string_outline(f, at, _hit_word, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Color(ink, a))
		c.draw_string(f, at, _hit_word, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.93, 0.55, a))
	if _poster_k > 0.01: _draw_poster(c)

## the fish and its cartoon face, with the transform left on it (the props are drawn around it)
func _draw_fish(c: CanvasItem, at: Vector2, rot: float, sq: Vector2, face: String, talking: bool, shades := false) -> void:
	if _sp.is_empty(): return
	c.draw_set_transform(at, rot, sq)
	var cell: float = _sp.cell
	var fast := 16.0 if in_zone else 10.0
	var fi := int(t * fast) % int(_sp.frames)
	if _gag in ["dead", "nap", "closed", "disguise"] or _poster_k > 0.3: fi = 0
	c.draw_texture_rect_region(_sp.tex, Rect2(-FISH_PX * 0.5, -FISH_PX * 0.5, FISH_PX, FISH_PX), Rect2(fi * cell, 0, cell, cell))
	var e: Vector2 = _sp.eye
	var m: Vector2 = _sp.mouth
	var er: float = _sp.er
	var ink := INK
	match face:
		"raspberry":
			c.draw_arc(e + Vector2(0, er * 0.35), er * 0.75, PI * 1.12, PI * 1.88, 10, ink, 3.5, true)       # ^ squeezed shut
			_ellipse(c, m + Vector2(1, 0), 6.0, 6.0, Color("#3a1420"))
			_ellipse(c, m + Vector2(10, 5), 11.0, 7.0, Color("#ff6f91"))                                     # tongue out
			c.draw_line(m + Vector2(4, 5), m + Vector2(15, 6), Color("#d94a6e"), 2.0, true)
		"dizzy":
			c.draw_circle(e, er, Color.WHITE)
			c.draw_arc(e, er, 0, TAU, 20, ink, 2.5, true)
			c.draw_line(e + Vector2(-er, -er) * 0.55, e + Vector2(er, er) * 0.55, ink, 3.0, true)
			c.draw_line(e + Vector2(-er, er) * 0.55, e + Vector2(er, -er) * 0.55, ink, 3.0, true)
			_ellipse(c, m, 5.0, 3.0 + 2.0 * absf(sin(t * 9.0)), Color("#3a1420"))
			if _gag == "dead": _ellipse(c, m + Vector2(6, 6), 7.0, 5.0, Color("#ff6f91"))                    # tongue lolling
		"shut":
			c.draw_circle(e, er, Color(0.05, 0.1, 0.13, 0.22))
			c.draw_arc(e + Vector2(0, -er * 0.25), er * 0.82, PI * 0.12, PI * 0.88, 10, ink, 3.5, true)      # eyes shut
			c.draw_arc(m + Vector2(-3, -5), 6.0, PI * 0.2, PI * 0.8, 8, ink, 2.5, true)
		_:
			var worried: bool = face in ["worried", "panic"]
			var r2 := er * (1.25 if worried else 1.0)
			if face == "panic": r2 = er * 1.5
			c.draw_circle(e, r2, Color.WHITE)
			# pupil: watches the net, or you while talking
			var zc := COL.position + Vector2(COL.size.x * 0.5, _col_y(zone_y + _net_h() * 0.5))
			var dir := (zc - at).rotated(-rot).normalized() if not talking else Vector2(0.9, 0.2)
			var pr := r2 * (0.26 if face == "panic" else (0.34 if worried else 0.48))
			c.draw_circle(e + dir * (r2 - pr - 1.5), pr, ink)
			c.draw_circle(e + dir * (r2 - pr - 1.5) + Vector2(-1.5, -1.5), maxf(1.2, pr * 0.3), Color.WHITE)
			c.draw_arc(e, r2, 0, TAU, 24, ink, 2.5, true)
			if worried:
				c.draw_line(e + Vector2(-r2 * 0.95, -r2 * 1.35), e + Vector2(r2 * 0.75, -r2 * 1.75), ink, 4.0, true)    # brows up
			else:
				# smug half-closed lid + cocky brow
				var lid := PackedVector2Array()
				for i in 11:
					lid.append(e + Vector2.from_angle(PI + PI * i / 10.0) * (r2 + 0.5))
				c.draw_colored_polygon(lid, Color(0.12, 0.16, 0.2, 0.45))
				c.draw_line(e + Vector2(-r2 - 1, -1), e + Vector2(r2 + 1, -1), ink, 2.5, true)
				c.draw_line(e + Vector2(-r2 * 1.1, -r2 * 1.75), e + Vector2(r2 * 0.9, -r2 * 1.35), ink, 4.0, true)
			if talking or face == "panic":
				_ellipse(c, m, 6.0, 2.0 + 5.0 * absf(sin(t * 22.0)), Color("#3a1420"))
			elif worried:
				_ellipse(c, m, 4.0, 4.0, Color("#3a1420"))
			else:
				c.draw_arc(m + Vector2(-3, -5), 6.0, PI * 0.2, PI * 0.8, 8, ink, 2.5, true)  # smirk
	if shades:
		_shades(c, e, er)
	elif _shades_k > 0.01 and phase == "end" and not won:
		_shades(c, e + Vector2(0, -130.0 * (1.0 - _shades_k)), er)

func _shades(c: CanvasItem, e: Vector2, er: float) -> void:
	var s := er * 1.25
	c.draw_rect(Rect2(e + Vector2(-s * 1.2, -s * 0.55), Vector2(s * 2.4, s * 0.8)), Color.BLACK)
	c.draw_rect(Rect2(e + Vector2(-s * 0.95, s * 0.25), Vector2(s * 1.9, s * 0.28)), Color.BLACK)
	c.draw_rect(Rect2(e + Vector2(-s * 0.7, s * 0.53), Vector2(s * 1.4, s * 0.2)), Color.BLACK)
	c.draw_line(e + Vector2(-s * 1.2, -s * 0.4), e + Vector2(-s * 3.2, -s * 0.8), Color.BLACK, 4.0)
	c.draw_rect(Rect2(e + Vector2(-s * 0.75, -s * 0.35), Vector2(s * 0.42, s * 0.2)), Color(1, 1, 1, 0.9))
	c.draw_rect(Rect2(e + Vector2(s * 0.1, -s * 0.35), Vector2(s * 0.42, s * 0.2)), Color(1, 1, 1, 0.9))

## what the fish is holding or wearing for the gag. On entry the transform is still the fish's.
func _draw_props(c: CanvasItem, fp: Vector2) -> void:
	if _sp.is_empty(): return
	var e: Vector2 = _sp.eye
	var m: Vector2 = _sp.mouth
	var er: float = _sp.er
	var font: Font = top.get_theme_default_font()
	match _gag:
		"disguise":
			c.draw_arc(e, er + 4.0, 0, TAU, 24, INK, 3.5, true)                  # glasses
			c.draw_line(e + Vector2(er + 4.0, 0), e + Vector2(er + 15.0, 2), INK, 3.0, true)
			var nose := m + Vector2(4.0, -er * 0.75)
			var tash := m + Vector2(4.0, -er * 0.1)
			for s in [-1.0, 1.0]:                                                # the moustache
				c.draw_colored_polygon(PackedVector2Array([tash, tash + Vector2(s * 12.0, -4.0), tash + Vector2(s * 24.0, -9.0), tash + Vector2(s * 17.0, 5.0), tash + Vector2(s * 5.0, 7.0)]), Color("#3a2a20"))
			_ellipse(c, nose, er * 0.8, er * 0.62, Color("#f2a98f"))             # the nose it's attached to
		"selfie":
			var at := m + Vector2(30.0, -24.0)
			c.draw_line(m + Vector2(4, 6), at, INK, 4.0, true)
			c.draw_style_box(main.sbox(INK, 5, 0, Color.TRANSPARENT, 0), Rect2(at - Vector2(9, 17), Vector2(18, 34)))
			c.draw_rect(Rect2(at - Vector2(6, 13), Vector2(12, 24)), Color("#7fd8e8"))
			if _flash > 0.2:
				c.draw_circle(at, 26.0 * _flash, Color(1, 1, 0.8, 0.8 * _flash))
		"bribe":
			var at := m + Vector2(28.0, 6.0 + sin(t * 9.0) * 3.0)
			c.draw_circle(at, 14.0, Color("#f2c33d"))
			c.draw_arc(at, 14.0, 0, TAU, 24, Color("#a9781a"), 2.5, true)
			c.draw_string(font, at + Vector2(-5, 7), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#8a5f10"))
		"closed":
			var at := e + Vector2(0, er + 26.0)
			c.draw_line(at + Vector2(-20, -12), e + Vector2(-6, -er), INK, 2.0, true)
			c.draw_line(at + Vector2(20, -12), e + Vector2(6, -er), INK, 2.0, true)
			c.draw_style_box(main.sbox(Color("#c79a5f"), 4, 2, Color("#6f4d24"), 0), Rect2(at - Vector2(36, 12), Vector2(72, 24)))
			c.draw_string(font, at + Vector2(-30, 6), "CLOSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#3f2a10"))
		"rocket":
			var at := Vector2(-20.0, -er - 34.0)
			var fl := 22.0 + randf() * 12.0
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-24, -7), at + Vector2(-24 - fl, 0), at + Vector2(-24, 7)]), Color("#ffb52e"))
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-24, -4), at + Vector2(-24 - fl * 0.55, 0), at + Vector2(-24, 4)]), Color("#fff2a8"))
			_ellipse(c, at, 28.0, 12.0, Color("#e5533d"))
			_ellipse(c, at + Vector2(16, 0), 11.0, 8.0, Color("#f7f4ea"))
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-14, -9), at + Vector2(-26, -20), at + Vector2(-4, -9)]), Color("#b83a28"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var zt := COL.position.y + _col_y(zone_y + _net_h())
	var hook := Vector2(COL.position.x + COL.size.x * 0.5, zt)
	match _gag:
		"nap":
			for k in 3:
				var ph := fmod(_gag_t * 0.9 + k / 3.0, 1.0)
				var sz := int(16.0 + 14.0 * ph)
				var at := fp + Vector2(40.0 + 26.0 * ph, -50.0 - 60.0 * ph)
				c.draw_string_outline(font, at, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 5, Color(INK, 1.0 - ph))
				c.draw_string(font, at, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(1, 1, 1, 1.0 - ph))
		"dance":
			var notes: Texture2D = main.ph("music-notes")
			for k in 3:
				var ph := fmod(_gag_t * 1.1 + k / 3.0, 1.0)
				var at := fp + Vector2(-56.0 + k * 56.0 + sin(ph * 7.0) * 8.0, -50.0 - 50.0 * ph)
				if notes: c.draw_texture_rect(notes, Rect2(at, Vector2(24, 24)), false, Color(1, 0.95, 0.6, 1.0 - ph))
		"banana":
			var k := clampf(_gag_t / 0.45, 0.0, 1.0)
			var at := fp.lerp(hook + Vector2(30, 6), k) + Vector2(0, -sin(k * PI) * 70.0)
			if _slip > 0.0: at = hook + Vector2(30, 6)
			_peel(c, at, _gag_t * 9.0 if k < 1.0 else 0.2)
		"boot":
			var k := clampf(_gag_t / 0.45, 0.0, 1.0)
			_boot(c, hook + Vector2(0, 26.0 - (1.0 - k * k) * 300.0), sin(t * 7.0) * 0.1)
	if _slip > 0.0 and _gag != "banana": _peel(c, hook + Vector2(30, 6), 0.2)
	if _heavy > 0.0 and _gag != "boot": _boot(c, hook + Vector2(0, 26), sin(t * 7.0) * 0.1)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _peel(c: CanvasItem, at: Vector2, rot: float) -> void:
	c.draw_set_transform(at, rot, Vector2.ONE)
	for a in [-2.5, -1.1, 0.4, 1.9]:
		var d := Vector2.from_angle(a)
		var n := d.orthogonal()
		c.draw_colored_polygon(PackedVector2Array([n * 7.0, d * 12.0 + n * 8.0, d * 26.0 + n * 2.0, d * 28.0, d * 26.0 - n * 2.0, d * 12.0 - n * 8.0, -n * 7.0]), Color("#f4d24a"))
	c.draw_circle(Vector2.ZERO, 8.0, Color("#e0b631"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _boot(c: CanvasItem, at: Vector2, rot: float) -> void:
	c.draw_set_transform(at, rot, Vector2.ONE)
	c.draw_colored_polygon(PackedVector2Array([Vector2(-15, -30), Vector2(10, -30), Vector2(10, 2), Vector2(30, 8), Vector2(33, 20), Vector2(-15, 20)]), Color("#7a5230"))
	c.draw_rect(Rect2(-16, 18, 50, 8), Color("#3f2a19"))
	for i in 3:
		c.draw_line(Vector2(-8, -24 + i * 9), Vector2(8, -24 + i * 9), Color("#d9c7a5"), 2.0, true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## where the fish was: its mugshot (you got it), or the WANTED poster (it got away)
func _draw_poster(c: CanvasItem) -> void:
	var at := COL.position + COL.size * Vector2(0.5, 0.46)
	var font: Font = top.get_theme_default_font()
	var tilt := -0.05 if won else 0.04
	var sc := Vector2.ONE * _poster_k
	c.draw_set_transform(at, tilt, sc)
	var r := Rect2(-104, -140, 208, 270)
	c.draw_style_box(main.sbox(Color(0, 0, 0, 0.2), 8, 0, Color.TRANSPARENT, 0), Rect2(r.position + Vector2(6, 8), r.size))
	if won:
		c.draw_style_box(main.sbox(Color("#fffef9"), 6, 0, Color.TRANSPARENT, 0), r)
		c.draw_rect(Rect2(-92, -128, 184, 170), _top_c.lerp(_bot_c, 0.4))
	else:
		c.draw_style_box(main.sbox(Color("#e6cf9c"), 6, 2, Color("#a8854d"), 0), r)
		c.draw_string(font, Vector2(-104, -108), "WANTED", HORIZONTAL_ALIGNMENT_CENTER, 208, 34, Color("#5a3d1a"))
	# the picture of it
	_draw_fish(c, at + (Vector2(0, -44) if won else Vector2(0, -22)).rotated(tilt) * _poster_k, tilt, sc, "dizzy" if won else "smug", false, not won)
	c.draw_set_transform(at, tilt, sc)
	if won:
		c.draw_string(font, Vector2(-100, 70), nick, HORIZONTAL_ALIGNMENT_CENTER, 200, 19, INK)
		c.draw_string(font, Vector2(-100, 94), _fact, HORIZONTAL_ALIGNMENT_CENTER, 200, 13, Color("#5f7079"))
	else:
		c.draw_string(font, Vector2(-100, 72), nick, HORIZONTAL_ALIGNMENT_CENTER, 200, 21, Color("#5a3d1a"))
		c.draw_string(font, Vector2(-100, 98), WANTED[nick.length() % WANTED.size()], HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color("#7a5a2e"))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

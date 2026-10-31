extends RefCounted
## The things in the world that are there for no reason but fun. Everything can be poked: crabs jump, gulls squawk, tap
## your boat and it honks (H on a keyboard). The captain mutters to himself. Bottles float by with a note in them, rubber
## ducks too (nobody knows why you're collecting them), and now and then a gull flies off with a fish: tap it before
## it's gone. Finds pay about what a few casts would bring in. The stage (vf_stage.gd) draws them; this decides when,
## what they're worth and what gets said.

const QUIPS := ["I was told there'd be more fish.", "One day, the big one. Today, lunch.", "The sea is calling. It wants its fish back.",
	"This hat has seen things.", "Is that fish looking at me?", "I should've been an accountant.", "The crabs are planning something.",
	"That gull owes me a sandwich.", "Nice weather for being ignored by fish.", "I named the bobber. Don't ask.",
	"My boat, my rules. Mostly the fish's rules.", "Still better than my old job."]
const HONKS := ["Excuse me, coming through!", "That's the horn. It's my favourite part.", "The gulls hate that. That's why.", "Honk honk, fish!", "Sorry. Reflex."]
const NOTES := ["Help! Stranded on an island. No rush, the fishing's great.", "To whoever finds this: the crabs are lying to you.",
	"Dear diary, today a fish winked at me.", "IOU: 3 shrimp. Signed, Gerald.", "If found, please return to the sea. It's recycling.",
	"Roses are red, the ocean is blue. I lost my boat. Have you seen it too?", "This is not a bottle. It's a cry for help. Also a bottle.",
	"The treasure is buried where the X is. That's all I remember.", "Your hat looks great from down here. Signed, a fish.",
	"Whoever you are: stop feeding the gulls. They've formed a union."]
const DUCK_LINES := ["It's watching you now.", "You collect these now. That's who you are.", "Quack.", "Nobody knows where they come from.", "It squeaks with disapproval."]
const DUCK_MILESTONES := {10: "Ten ducks. The fish are concerned.", 25: "Twenty-five ducks. Your family is concerned.", 50: "Fifty ducks. The ducks are concerned."}
const CAUGHT_LINES := ["One of them looked at you funny.", "They seemed disappointed.", "A crab saw the whole thing.", "They'll tell their friends.",
	"Nobody clapped. But they could have.", "Smells like success. And fish.", "One of them owes you money."]
const EMPTY_LINES := ["The fish are on a break.", "Not even a boot.", "The bobber is judging you."]

var m                            # vf_main
var _find_wait := 25.0
var _thief_wait := 90.0
var _quip_wait := 30.0
var _pay_cd := 0.0               # poking pays a little, not all the time
var _honk_cd := 0.0
var _note_box: PanelContainer

func _init(main) -> void:
	m = main
	m.stage.poked.connect(_on_poked)

func tick(delta: float) -> void:
	_pay_cd -= delta
	_honk_cd -= delta
	if VF.tutorial < 99 or m.launcher_open() or m.overlay.visible or m.minigame != null or m._phone_open() or m.sail.state != "idle": return
	_find_wait -= delta
	if _find_wait <= 0.0:
		_find_wait = randf_range(40.0, 100.0)
		m.stage.spawn_find("duck" if randf() < 0.3 else "bottle")
	_thief_wait -= delta
	if _thief_wait <= 0.0:
		_thief_wait = randf_range(150.0, 300.0)
		if VF.inventory_value() > 0.0 and m.stage.night_amount < 0.5: m.stage.spawn_thief()
	_quip_wait -= delta
	if _quip_wait <= 0.0:
		_quip_wait = randf_range(45.0, 110.0)
		m.stage.say(QUIPS.pick_random())

## tap the boat, or H
func honk() -> void:
	if _honk_cd > 0.0: return
	_honk_cd = 1.2
	AudioManager.play_fun("horn", -9.0, randf_range(0.97, 1.03))
	m.stage.on_honk()
	m.stage.say(HONKS.pick_random(), 2.4)

## a little line on the catch card now and then ("" most of the time)
func catch_line(res: Dictionary) -> String:
	if res.count <= 0: return EMPTY_LINES.pick_random()
	return CAUGHT_LINES.pick_random() if randf() < 0.22 else ""

func _pay(casts: float, at: Vector2) -> void:
	var n: int = VF.pay_find(casts)
	var sp: Vector2 = m.stage.to_screen(at)
	m._float_text("+%s" % m.money_str(n), sp + Vector2(0, -36), m.C_GOLD)
	m.v1.coins_to_wallet(sp, n)
	AudioManager.play_coin()

func _on_poked(kind: String, at: Vector2) -> void:
	match kind:
		"crab":
			AudioManager.play_fun("squeak", -9.0, randf_range(0.9, 1.25))
			if randf() < 0.25: m.stage.say("Leave the crabs alone. They know things.", 2.8)
			if _pay_cd <= 0.0:
				_pay_cd = 20.0
				_pay(0.15, at)
		"gull":
			AudioManager.play_fun("squawk", -10.0, randf_range(0.9, 1.15))
			if _pay_cd <= 0.0:
				_pay_cd = 20.0
				_pay(0.15, at)
		"bottle":
			AudioManager.play_fun("pop", -6.0)
			_pay(3.0, at)
			note(NOTES.pick_random())
		"duck":
			AudioManager.play_fun("quack", -6.0)
			VF.ducks += 1
			VF.save_game()
			_pay(1.0 + minf(VF.ducks, 20.0) * 0.1, at)
			m._toast("Rubber duck #%d! %s" % [VF.ducks, DUCK_MILESTONES.get(VF.ducks, DUCK_LINES.pick_random())], "quest")
		"thief":
			AudioManager.play_fun("squawk", -7.0, 0.85)
			AudioManager.play_fun("ding", -9.0)
			_pay(5.0, at)
			m.stage.say("And stay out!", 2.4)

## the note out of a bottle, on a scrap of paper for a few seconds
func note(text: String) -> void:
	if is_instance_valid(_note_box): _note_box.queue_free()
	var p := PanelContainer.new()
	var sb: StyleBoxFlat = m.sbox(Color("#fbf3dc"), 10, 1, Color("#d9c9a0"), 0, 10)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(m.lbl("A message in a bottle:", 13, Color("#8a7a55")))
	var l: Label = m.lbl(text, 18, Color("#3f3522"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 380
	v.add_child(l)
	m.add_child(p)
	p.reset_size()
	var vs: Vector2 = m.get_viewport_rect().size
	p.position = Vector2((vs.x - p.size.x) * 0.5, vs.y * 0.2).round()
	p.pivot_offset = p.size * 0.5
	p.rotation = -0.02
	p.scale = Vector2(0.6, 0.6)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(4.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	_note_box = p

## godot --path . --resolution 1280x720 -- --capture=DIR --fun-test : every toy, one after the other
func capture_test(dir: String) -> void:
	await m.get_tree().create_timer(2.0).timeout
	var s = m.stage
	s.spawn_find("duck")
	s.spawn_find("bottle")
	s.say("Is that fish looking at me?")
	await m.get_tree().create_timer(1.2).timeout
	await m._shot(dir + "/fun_floating.png")
	print("FUN floaters=%d crabs=%d gulls=%d ducks=%d money=%d" % [s._floaters.size(), s._crabs.size(), s._gulls.size(), VF.ducks, VF.money])
	var before: float = VF.money
	for f in s._floaters.duplicate():
		print("FUN poke %s -> %s" % [f.kind, s.poke(s.to_screen(f.pos))])
	await m.get_tree().create_timer(0.5).timeout
	await m._shot(dir + "/fun_note.png")
	print("FUN after finds: ducks=%d money +%d" % [VF.ducks, VF.money - before])
	if not s._crabs.is_empty():
		print("FUN poke crab -> %s" % s.poke(s.to_screen(s._crabs[0].pos)))
		await m.get_tree().create_timer(0.25).timeout
		await m._shot(dir + "/fun_crab.png")
	if not s._gulls.is_empty():
		print("FUN poke gull -> %s" % s.poke(s.to_screen(s._gulls[0].pos)))
	s.spawn_thief()
	await m.get_tree().create_timer(2.2).timeout
	await m._shot(dir + "/fun_thief.png")
	before = VF.money
	print("FUN poke thief -> %s (money +%d)" % [s.poke(s.to_screen(s._thief.pos)), VF.money - before])
	await m.get_tree().create_timer(0.3).timeout
	await m._shot(dir + "/fun_thief_caught.png")
	honk()
	await m.get_tree().create_timer(0.6).timeout
	await m._shot(dir + "/fun_honk.png")
	print("FUN honk done, say='%s'" % s._say_text)

## godot --path . --resolution 1600x900 --write-movie OUT.avi --fixed-fps 30 -- --capture=DIR --tour : a look round for a
## recording: the title screen, the boat turning, the mini-game's gags, the toys. Never saves.
func tour() -> void:
	var tree: SceneTree = m.get_tree()
	var wait := func(t: float): await tree.create_timer(t).timeout
	VF._apply(VF._defaults.duplicate(true))
	m._veteran("River")
	VF.tutorial = 99
	VF.sail_hint = true
	VF.changed.emit()
	await wait.call(6.5)
	m.launcher.play()
	await wait.call(1.4)
	m.card.visible = false
	for t in m.toast_box.get_children(): t.free()
	# the boat turns
	for leg in [[[KEY_D], 1.5], [[KEY_A], 2.6], [[KEY_S], 1.2], [[KEY_D], 1.8], [[KEY_W], 1.3], [[], 2.0]]:
		for k in leg[0]: m.sail._key(k, true)
		await wait.call(leg[1])
		for k in leg[0]: m.sail._key(k, false)
	# the mini-game's gags
	m._set_catch_mode("reel")
	for step in [["Cod", "disguise", "win"], ["Pufferfish", "puff", "win"], ["Raw Salmon", "selfie", "win"], ["Rainbow Fish", "shark", "lose"]]:
		VF._last_cast_ms = -100000
		m._do_cast()
		while m.minigame == null:
			await tree.process_frame
		var mg = m.minigame
		mg.auto = "win"
		await wait.call(0.9)
		mg.test_gag(step[0], step[1])
		await wait.call(float(mg.GAGS[step[1]].len) + 0.4)
		if step[2] == "lose":
			mg.auto = "lose"
			mg.progress = 0.2
			mg.time_limit = mg.play_t + 1.2
		else:
			mg.progress = 0.9
		while m.minigame != null:
			await tree.process_frame
		await wait.call(1.2)
	m._set_catch_mode("relax")
	m.card.visible = false
	# the toys
	var s = m.stage
	s.spawn_find("duck")
	s.spawn_find("bottle")
	await wait.call(2.2)
	for f in s._floaters.duplicate():
		s.poke(s.to_screen(f.pos))
		await wait.call(0.8)
	await wait.call(3.0)
	if not s._crabs.is_empty():
		s.poke(s.to_screen(s._crabs[0].pos))
	await wait.call(1.4)
	s.spawn_thief()
	await wait.call(3.0)
	if not s._thief.is_empty(): s.poke(s.to_screen(s._thief.pos))
	await wait.call(2.2)
	honk()
	await wait.call(3.0)

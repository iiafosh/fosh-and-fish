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
const TEASE_MAX := 2             # their shape passes this often before each meeting: a tease, not a nag

var m                            # vf_main
var _find_wait := 25.0
var _thief_wait := 90.0
var _quip_wait := 30.0
var _pay_cd := 0.0               # poking pays a little, not all the time
var _honk_cd := 0.0
var _resident_wait := 40.0       # until the next find turns up
var _resident_left := 0.0        # the one out there now: how long it stays
var _tease_wait := 0.0
var _teases := 0
var _note_box: PanelContainer

func _init(main) -> void:
	m = main
	m.stage.poked.connect(_on_poked)

func tick(delta: float) -> void:
	_pay_cd -= delta
	_honk_cd -= delta
	_resident_left -= delta
	if VF.tutorial < 99 or m.launcher_open() or m.overlay.visible or m.minigame != null or m._phone_open() or m.sail.state != "idle": return
	_find_wait -= delta
	if _find_wait <= 0.0:
		_find_wait = randf_range(40.0, 100.0)
		m.stage.spawn_find("duck" if randf() < 0.3 else "bottle")
	if _resident_left <= 0.0:
		_resident_wait -= delta
		if _resident_wait <= 0.0: _send_resident()
	_tick_tease(delta)
	_thief_wait -= delta
	if _thief_wait <= 0.0:
		_thief_wait = randf_range(150.0, 300.0)
		if VF.inventory_value() > 0.0 and m.stage.night_amount < 0.5: m.stage.spawn_thief()
	_quip_wait -= delta
	if _quip_wait <= 0.0:
		_quip_wait = randf_range(45.0, 110.0)
		if not (m.stage.has_method("talking") and m.stage.talking()): m.stage.say(QUIPS.pick_random())     # (never over a line that's showing)

## one find at a time, the stage puts it somewhere worth sailing to and takes it away after VFData.FIND_SECS
func _send_resident() -> void:
	_resident_wait = randf_range(VFData.FIND_WAIT[0], VFData.FIND_WAIT[1])
	if not m.stage.has_method("spawn_resident"): return
	var id: String = VF.find_pick()
	if id == "": return
	m.stage.spawn_resident(id)
	_resident_left = VFData.FIND_SECS

## the rival's close: now and then his shape swims past the boat (no more than TEASE_MAX times until you've met)
func _tick_tease(delta: float) -> void:
	if not VF.gerald_soon():
		_teases = 0
		_tease_wait = 3.0
		return
	_tease_wait -= delta
	if _tease_wait > 0.0 or _teases >= TEASE_MAX or not m.stage.has_method("spawn_gerald"): return
	_tease_wait = randf_range(50.0, 90.0)
	_teases += 1
	var row: Dictionary = VFData.GERALD[int(VF.gerald.stage)]
	m.stage.spawn_gerald(tease_lines(row).pick_random(), String(row.look), float(row.get("size", 1.0)))

## what the passing shape says: the outlaw's own lines
func tease_lines(row: Dictionary) -> Array:
	return row.get("tease", ["Something big just laughed at you."])

## tap the boat, or H
func honk() -> void:
	if _honk_cd > 0.0: return
	_honk_cd = 1.2
	VF.stat_add("honks")
	VFHaptics.buzz("honk")
	AudioManager.play_fun("horn", -9.0, randf_range(0.97, 1.03))
	m.stage.on_honk()
	m.stage.say(HONKS.pick_random(), 2.4)

## a little line on the catch card now and then ("" most of the time)
func catch_line(res: Dictionary) -> String:
	if res.count <= 0: return "" if not res.get("chest", {}).is_empty() else EMPTY_LINES.pick_random()    # (a goal's chest isn't a bad catch)
	return CAUGHT_LINES.pick_random() if randf() < 0.22 else ""

func _pay(casts: float, at: Vector2) -> void:
	_show_pay(VF.pay_find(casts), at)

func _show_pay(n: int, at: Vector2) -> void:
	var sp: Vector2 = m.stage.to_screen(at)
	m._float_text("+%s" % m.money_str(n), sp + Vector2(0, -36), m.C_GOLD)
	m.v1.coins_to_wallet(sp, n)
	AudioManager.play_coin()

func _on_poked(kind: String, at: Vector2) -> void:
	if kind == "thief_away":             # (nobody touched anything: it just got away with it)
		VF.stat_add("robbed")
		return
	VFHaptics.buzz("poke")
	if kind.begins_with("find:"):
		_found(kind.substr(5), at)
		return
	match kind:
		"crab":
			VF.stat_add("crab_pokes")
			AudioManager.play_fun("squeak", -9.0, randf_range(0.9, 1.25))
			if randf() < 0.25: m.stage.say("Leave the crabs alone. They know things.", 2.8)
			if _pay_cd <= 0.0:
				_pay_cd = 20.0
				_pay(0.15, at)
		"gull":
			VF.stat_add("gull_pokes")
			AudioManager.play_fun("squawk", -10.0, randf_range(0.9, 1.15))
			if _pay_cd <= 0.0:
				_pay_cd = 20.0
				_pay(0.15, at)
		"bottle":
			VF.stat_add("bottles")
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
			VF.stat_add("thieves")
			AudioManager.play_fun("squawk", -7.0, 0.85)
			AudioManager.play_fun("ding", -9.0)
			_pay(5.0, at)
			m.stage.say("And stay out!", 2.4)

## you tapped a find, from close enough
func _found(id: String, at: Vector2) -> void:
	_resident_left = 0.0
	var d: Dictionary = VFData.find_def(id)
	if d.is_empty(): return
	var r: Dictionary = VF.find_tapped(id)
	m.stage.say(r.line, 4.0)
	if r.first:
		VFHaptics.buzz("rare")
		AudioManager.play_fun("find_new", -5.0)
		m._banner("New find: %s!" % d.name, "%d of %d found (Fish Book)" % [VF.finds.size(), VFData.finds_total()], m.ph("sparkle"), Color("#2f8f9e"))
	else:
		AudioManager.play_fun("ding", -11.0)
	if int(r.pay) > 0: _show_pay(int(r.pay), at)

## the round against an outlaw is decided: pay up. At the end of a run: the hat. Some bring a note in a bottle: the next one's.
func rival_result(mg, won: bool) -> void:
	var r: Dictionary = VF.gerald_result(won)
	mg.rival_result = r
	if int(r.pay) > 0:
		m.v1.coins_to_wallet(m.size * 0.5, int(r.pay))
		AudioManager.play_coin()
	if r.caught: mg.tree_exited.connect(_rival_caught.bind(r), CONNECT_DEFERRED)

func _rival_caught(r: Dictionary) -> void:
	if r.hat != "": m._toast("New hat: %s! (Shop - Hats)" % VFData.HATS[r.hat].name, "unlock")
	var row: Dictionary = VFData.GERALD[clampi(int(r.stage), 0, VFData.GERALD.size() - 1)]
	if row.has("note"):
		AudioManager.play_fun("pop", -6.0)
		note(row.note)

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
	var vs: Vector2 = m.size
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
	await s.tap_areas_test()

## godot --path . --resolution 1280x720 -- --capture=DIR --gerald-test : the whole chase, from the first meeting to the end of
## The whole Most Wanted act: all seven outlaws, every gag of theirs, caught, the notes, the crown and the tiara. Never saves.
func gerald_test(dir: String) -> void:
	var tree: SceneTree = m.get_tree()
	var wait := func(secs: float): await tree.create_timer(secs).timeout
	VF._apply(VF._defaults.duplicate(true))
	VF.catch_mode = "relax"                # (he bites in Relax mode too)
	VF.reel_rounds = VFData.ROOKIE_ROUNDS
	VF.tutorial = 99
	VF.sail_hint = true
	VF.level = 10
	VF.rod = "Improved Rod"
	VF.owned_rods = ["Plastic Rod", "Improved Rod"]
	VF.changed.emit()
	m._coach_show()
	await wait.call(1.2)
	VF.gerald.casts = VFData.gerald_need(0, 0) - 10
	print("GERALD soon=%s due=%s info=%s" % [VF.gerald_soon(), VF.gerald_due(), VF.gerald_info()])
	for i in TEASE_MAX + 2:                # (however long it takes you to meet him)
		_tease_wait = 0.0
		await tree.process_frame
		await tree.process_frame
	print("GERALD teases while he's close: %d, at most %d" % [_teases, TEASE_MAX])
	VF.gerald.casts = 0
	await tree.process_frame
	await tree.process_frame
	print("GERALD teases once he's far off again: %d" % _teases)
	VF.gerald.casts = VFData.gerald_need(0, 0)
	print("GERALD soon=%s due=%s" % [VF.gerald_soon(), VF.gerald_due()])
	var trips: int = VF.stats.trips
	VF._last_cast_ms = -100000
	m._do_cast(true)
	await wait.call(1.2)
	print("GERALD auto-fish cast: minigame=%s trips +%d" % [m.minigame != null, VF.stats.trips - trips])
	VF.gerald.casts = VFData.gerald_need(0, 0)
	await _rival_round(dir, "1_first_meeting", "lose")
	VF.gerald.casts = VFData.gerald_need(0, 1)
	await _rival_round(dir, "2_beat_him", "win")
	print("GERALD after a win: %s money=%d" % [VF.gerald, VF.money])
	# every gag of his
	VF.gerald = {"stage": 1, "casts": 999, "tries": 0, "wins": 1, "losses": 1}
	VF.level = 60
	VF.biome = "Volcanic"
	VF.rod = "Lava Rod"
	VF.owned_rods.append("Lava Rod")
	VF.changed.emit()
	await wait.call(2.0)
	await _rival_gags(dir)
	# Baron von Flap: caught, the crown, the Duchess's note in a bottle
	VF.gerald = {"stage": 3, "casts": 999, "tries": 0, "wins": 3, "losses": 1}
	VF.level = 250
	VF.biome = "Sky"
	VF.rod = "Infinity Rod"
	VF.owned_rods.append("Infinity Rod")
	VF.changed.emit()
	await wait.call(2.0)
	await _rival_round(dir, "3_caught_baron", "win")
	await wait.call(0.8)
	await m._shot(dir + "/gerald_3_note_from_duchess.png")
	print("GERALD caught: %s hats=%s note=%s" % [VF.gerald, VF.hats_owned, is_instance_valid(_note_box)])
	await wait.call(5.0)
	# Commander Chomp, then the Duchess
	VF.gerald = {"stage": 4, "casts": 999, "tries": 0, "wins": 4, "losses": 1}
	VF.level = 500
	VF.biome = "Space"
	VF.rod = "Space Rod"
	VF.owned_rods.append("Space Rod")
	VF.changed.emit()
	await wait.call(2.0)
	await _rival_round(dir, "4_chomp_laughs", "lose")
	VF.gerald.casts = 999
	await _rival_gags(dir)
	VF.gerald = {"stage": 6, "casts": 999, "tries": 0, "wins": 6, "losses": 2}
	VF.level = 2500
	VF.biome = "Abyss"
	VF.rod = "Dark Rod"
	VF.owned_rods.append("Dark Rod")
	VF.changed.emit()
	await wait.call(2.0)
	await _rival_round(dir, "5_caught_duchess", "win")
	print("GERALD all done: %s hats=%s info=%s due=%s" % [VF.gerald, VF.hats_owned, VF.gerald_info(), VF.gerald_due()])
	for i in VFData.GERALD.size():         # every outlaw's whole act
		var act: Dictionary = VFData.GERALD[i]
		VF.gerald = {"stage": i, "casts": 999, "tries": 0, "wins": i, "losses": 0}
		VF.biome = act.biome
		VF.level = int(act.level)
		VF.rod = "Dark Rod"
		if not "Dark Rod" in VF.owned_rods: VF.owned_rods.append("Dark Rod")
		VF.changed.emit()
		await wait.call(2.0)
		await _rival_gags(dir)
	for row in VFData.GERALD:              # their shape going past the boat, wherever they turn up
		VF.biome = row.biome
		VF.changed.emit()
		await wait.call(1.0)
		m.stage.spawn_gerald(tease_lines(row)[0], String(row.look), float(row.get("size", 1.0)))
		var shape: Dictionary = m.stage._big.back()
		shape.pos.x = m.stage.boat_pos.x - signf(shape.vel.x) * 240.0
		await wait.call(1.9)
		await m._shot(dir + "/gerald_shape_%s_%s.png" % [VFData.slug(row.who), VFData.slug(row.biome)])
		print("GERALD shape %s %s (%s, %s, %.1f units long): says '%s'" % [row.who, row.biome, row.get("look", ""), shape.tex.resource_path.get_file(), shape.len, m.stage._say_text])

## one round against the rival, played by the capture's bot, with a picture of each part
func _rival_round(dir: String, name: String, outcome: String) -> void:
	var tree: SceneTree = m.get_tree()
	VF._last_cast_ms = -100000
	m._do_cast()
	while m.minigame == null:
		await tree.process_frame
	var mg = m.minigame
	mg.auto = outcome
	await tree.create_timer(1.5).timeout
	await m._shot(dir + "/gerald_%s_play.png" % name)
	if outcome == "win": mg.progress = 0.97
	else:
		mg.progress = minf(mg.progress, 0.3)
		mg.time_limit = mg.play_t + 0.6
	while is_instance_valid(mg) and mg.phase != "end":
		await tree.process_frame
	await tree.create_timer(0.3).timeout
	await m._shot(dir + "/gerald_%s_end.png" % name)
	await tree.create_timer(1.4).timeout
	if is_instance_valid(mg): await m._shot(dir + "/gerald_%s_poster.png" % name)
	while m.minigame != null:
		await tree.process_frame
	print("GERALD round %s: %s -> %s" % [name, outcome, VF.gerald])

## the rival right now pulling each of their own gags
func _rival_gags(dir: String) -> void:
	var tree: SceneTree = m.get_tree()
	VF._last_cast_ms = -100000
	m._do_cast()
	while m.minigame == null:
		await tree.process_frame
	var mg = m.minigame
	mg.auto = "win"
	await tree.create_timer(0.9).timeout
	var fill: float = mg.fill_rate
	mg.fill_rate = 0.0                     # (the round doesn't end while they go through their act)
	for g in mg._row.gags:
		mg.test_gag(mg.fish_name, g)
		await tree.create_timer(0.7).timeout
		await m._shot(dir + "/gerald_gag_%s_%s.png" % [VFData.slug(mg.rival), g])
		await tree.create_timer(float(mg.GAGS[g].len)).timeout
	mg.fill_rate = fill
	mg.progress = 0.97
	while m.minigame != null:
		await tree.process_frame

## godot --path . --resolution 1280x720 -- --capture=DIR --finds-test : every find of every biome, tapped twice. It shows them on
## the water once the stage has stage.spawn_resident. Never saves.
func finds_test(dir: String) -> void:
	var tree: SceneTree = m.get_tree()
	VF._apply(VF._defaults.duplicate(true))
	VF.catch_mode = "relax"
	VF.tutorial = 99
	VF.sail_hint = true
	VF.level = 2500
	VF.rod = "Dark Rod"
	VF.owned_rods = ["Plastic Rod", "Dark Rod"]
	print("FINDS stage has spawn_resident: %s" % m.stage.has_method("spawn_resident"))
	for b in VFData.BIOME_ORDER:
		VF.biome = b
		VF.changed.emit()
		await tree.create_timer(2.2).timeout
		for id in VFData.FINDS[b]:
			if m.stage.has_method("spawn_resident"):
				m.stage.spawn_resident(id)
				await tree.create_timer(0.8).timeout
				await m._shot(dir + "/finds_%s_%s.png" % [VFData.slug(b), id])
			var money0: int = VF.money
			_on_poked("find:" + id, m.stage.boat_pos + Vector2(220, -60))
			print("FINDS %s %s first tap: +$%d, found %d of %d: %s" % [b, id, VF.money - money0, VF.finds.size(), VFData.finds_total(), m.stage._say_text])
			await tree.create_timer(1.3).timeout
			await m._shot(dir + "/finds_%s_%s_tapped.png" % [VFData.slug(b), id])
			money0 = VF.money
			_on_poked("find:" + id, m.stage.boat_pos + Vector2(220, -60))
			print("FINDS %s %s tapped again: +$%d" % [b, id, VF.money - money0])
			await tree.create_timer(0.4).timeout
	var total := 0
	for id in VF.finds: total += int(VF.finds[id])
	print("FINDS done: %d of %d found, %d taps" % [VF.finds.size(), VFData.finds_total(), total])
	await m.stage.residents_test(dir)

## godot --path . --resolution 1280x720 -- --capture=DIR --rebirth-test : the first rebirth from the goal on the HUD to Prestige 1
func rebirth_test(dir: String) -> void:
	var tree: SceneTree = m.get_tree()
	VF._apply(VF._defaults.duplicate(true))
	VF.catch_mode = "relax"
	VF.tutorial = 99
	VF.level = VFData.prestige_level_req(0) - 1
	VF.money = 1_200_000
	VF.goals_done = VFData.STARTER_GOALS.size() - 2
	VF.changed.emit()
	m._coach_show()
	await tree.create_timer(1.2).timeout
	await m._shot(dir + "/rebirth0_goal_level.png")
	m._open_panel("prestige", "Prestige")
	await tree.create_timer(0.5).timeout
	await m._shot(dir + "/rebirth1_panel_not_yet.png")
	m._close_panel()
	VF.level = VFData.prestige_level_req(0)
	VF.check_goals()
	VF.changed.emit()
	await tree.create_timer(1.2).timeout
	await m._shot(dir + "/rebirth2_goal_money.png")
	VF.money = VFData.prestige_money_req(0)
	VF.check_goals()
	VF.changed.emit()
	await tree.create_timer(0.8).timeout
	await m._shot(dir + "/rebirth3_ready_toast.png")
	print("REBIRTH ready=%s check=%s goal=%s" % [VF.prestige_check().ok, VF.prestige_check(), VF.current_goal().get("id", "")])
	m._open_panel("prestige", "Prestige")
	await tree.create_timer(0.5).timeout
	await m._shot(dir + "/rebirth4_panel_ready.png")
	print("REBIRTH do_prestige='%s' prestige=%d level=%d azure=%d goals=%d/%d" % [VF.do_prestige(), VF.prestige, VF.level, VF.exotics.azure, VF.goals_done, VFData.STARTER_GOALS.size()])
	m._close_panel()
	await tree.create_timer(1.2).timeout
	await m._shot(dir + "/rebirth5_reborn.png")
	m._open_panel("prestige", "Prestige")
	await tree.create_timer(0.5).timeout
	await m._shot(dir + "/rebirth6_next_prestige.png")

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
	VF.reel_rounds = VFData.ROOKIE_ROUNDS
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

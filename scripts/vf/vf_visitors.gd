extends RefCounted
## Real players in your bay (1.1): people who played lately (Backend.players, schema.sql players_public) sail in one at
## a time, each in their best boat with a name tag, fish for a while on open water and sail off again. Tap one: they
## call something friendly and you see who it is. Only what the public list says (name, level, prestige, boats, hat,
## biome); nothing is sent anywhere. Players in your biome come first. Never more than shown_max() at once.
## Test: godot --path . --resolution 1280x720 -- --capture=DIR --visitors-test [--touch --ui-dp=390]

const STAY := [40.0, 80.0]          # seconds one stays
const GAP := [6.0, 20.0]            # seconds before the next one comes
const FADE := 1.4
const LINES := ["Nice boat!", "Seen Gerald anywhere?", "Race you in the Derby!", "The fish are biting here!",
	"Ahoy!", "Got any worms?", "Beautiful day for it.", "My cooler's full!", "Watch out for the gulls.",
	"Just passing through!", "Is that a shiny?", "Wave back!"]
const C_TAG := Color("#10303a")

var m                               # vf_main
var st                              # vf_stage
var layer: Control
var boats: Array = []               # [{who, node, tag, label, a, b, t, stay, ph, splash, said}]
var _queue: Array = []              # whom to show next
var _next := 4.0
var _poll := 0.0
var _last := 0.0
var _biome := ""
var _used := {}                     # boat name -> where the boat is in its picture
var enabled := true

func _init(main) -> void:
	m = main
	Backend.players_changed.connect(func(): _queue.clear())
	m.get_tree().process_frame.connect(_tick)
	_last = Time.get_ticks_msec() / 1000.0

func shown_max() -> int:
	return 2 if m.compact() else 3

func _tick() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var dt := clampf(now - _last, 0.0, 0.1)
	_last = now
	if st == null or not is_instance_valid(st):
		st = m.stage                                   # (vf_main makes the stage after this)
		if st == null or not is_instance_valid(st): return
	if st.root == null or st._scene.is_empty(): return
	if st._biome != _biome:                            # they belong to the bay they were in
		_biome = st._biome
		clear()
		_next = randf_range(3.0, 8.0)
	_poll -= dt
	if _poll <= 0.0:
		_poll = 60.0
		Backend.load_players()                         # (it loads at most every 10 minutes)
	if not enabled: return
	_next -= dt
	if _next <= 0.0 and boats.size() < shown_max():
		_next = randf_range(GAP[0], GAP[1])
		var who := _pick()
		if not who.is_empty(): _arrive(who)
	for v in boats.duplicate():
		_move(v, dt)

## the next player to visit: same biome first, nobody twice until everyone has been
func _pick() -> Dictionary:
	if _queue.is_empty():
		var here: Array = []
		var rest: Array = []
		for p in Backend.players:
			if not (p is Dictionary): continue
			(here if str(p.get("biome", "")) == _biome else rest).append(p)
		here.shuffle()
		rest.shuffle()
		_queue = here + rest
	while not _queue.is_empty():
		var p: Dictionary = _queue.pop_front()
		var busy := false
		for v in boats:
			if v.who.get("display_name", "") == p.get("display_name", ""): busy = true
		if not busy: return p
	return {}

func _boat_name(who: Dictionary) -> String:
	var n := clampi(int(who.get("boats", 1)), 1, VFData.BOAT_ORDER.size())
	return VFData.BOAT_ORDER[n - 1]

## somewhere on open water, clear of your boat, your float, the fleet and the other visitors
func _spot(rng: RandomNumberGenerator) -> Vector2:
	# (inside what the screen shows, clear of the buttons round the edges: phones see less of the bay)
	var vs: Vector2 = m.get_viewport().get_visible_rect().size
	var lo: Vector2 = st.to_scene(vs * Vector2(0.14, 0.2))
	var hi: Vector2 = st.to_scene(vs * Vector2(0.84, 0.7))
	var x0 := maxf(260.0, lo.x)
	var x1 := maxf(x0 + 1.0, minf(st.SCENE.x - 320.0, hi.x))
	var y0 := maxf(170.0, lo.y)
	var y1 := maxf(y0 + 1.0, minf(st.SCENE.y - 190.0, hi.y))
	for _i in 600:
		var p := Vector2(rng.randf_range(x0, x1), rng.randf_range(y0, y1))
		if p.distance_to(st.boat_pos) < 440.0 or p.distance_to(st._bobber_home) < 260.0 or not st._in_water(p, 0.1): continue
		var ok := true
		for i in 8:
			if not st._in_water(p + Vector2.from_angle(TAU * i / 8.0) * 100.0, 0.05): ok = false
		for f in st._fleet:
			if p.distance_to(f.home) < 230.0: ok = false
		for v in boats:
			if p.distance_to(v.a) < 280.0 or p.distance_to(v.b) < 280.0: ok = false
		if ok: return p
	return Vector2.INF

func _arrive(who: Dictionary) -> void:
	if layer == null or not is_instance_valid(layer):
		layer = Control.new()
		layer.size = st.SCENE
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		st.root.add_child(layer)
		st.root.move_child(layer, st.boat.get_index())      # over the water and the fleet, under your boat
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var a := _spot(rng)
	if a == Vector2.INF: return
	var b := a
	for _i in 30:                                          # a short drift that stays on open water
		var c := a + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(150.0, 260.0)
		var ok := true
		for k in 9:
			if not st._in_water(a.lerp(c, k / 8.0), 0.1): ok = false
		if ok and c.distance_to(st.boat_pos) > 420.0:
			b = c
			break
	var bname := _boat_name(who)
	var t: Texture2D = st._tex("boats_top/%s.png" % VFData.slug(bname))
	if t == null: return
	var info: Dictionary = st.manifest.get("boats_top", {}).get(bname, {"origin": [0.5, 0.6], "unit_px": 100.0})
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = t.get_size() * float(st._scene.unit_px) / float(info.unit_px) * 0.7     # (a bit smaller than yours: you're the star)
	r.pivot_offset = Vector2(info.origin[0], info.origin[1]) * r.size
	r.flip_h = b.x < a.x
	# where the boat really is in its picture (the sheets have empty margins): the tag sits just over its top
	if not _used.has(bname):
		var img := t.get_image()
		_used[bname] = Rect2(img.get_used_rect()) if img != null else Rect2(Vector2.ZERO, t.get_size())
	var u: Rect2 = _used[bname]
	var k := r.size / t.get_size()
	var cx := (u.position.x + u.size.x * 0.5) * k.x
	var top := Vector2(r.size.x - cx if r.flip_h else cx, u.position.y * k.y)
	r.modulate.a = 0.0
	layer.add_child(r)
	var mirror: TextureRect = st._reflect_rect()
	r.add_child(mirror)
	st._fit_reflect(mirror, bname, info, r.size)
	mirror.flip_h = r.flip_h
	(mirror.material as ShaderMaterial).set_shader_parameter("seed", rng.randf() * 50.0)
	var foam: TextureRect = st._foam_rect()
	r.add_child(foam)
	st._fit_foam(foam, bname, info, r.size)
	foam.flip_h = r.flip_h
	(foam.material as ShaderMaterial).set_shader_parameter("seed", rng.randf() * 50.0)
	# the name tag: a dark pill over the boat
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_stylebox_override("panel", m.sbox(Color(C_TAG, 0.72), 999, 0, Color.TRANSPARENT, 12, 0))
	var label: Label = m.lbl(_tag_text(who), 22, Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(label)
	tag.modulate.a = 0.0
	layer.add_child(tag)
	boats.append({"who": who, "node": r, "tag": tag, "label": label, "a": a, "b": b, "t": 0.0, "top": top,
		"stay": rng.randf_range(STAY[0], STAY[1]), "ph": rng.randf() * TAU, "splash": rng.randf_range(4.0, 9.0), "said": 0.0})
	st._add_ripple(a, 60.0, 2.4)

func _tag_text(who: Dictionary) -> String:
	var s := "%s  ·  Lv %s" % [str(who.get("display_name", "?")).left(18), VF.commas(int(who.get("level", 1)))]
	if int(who.get("prestige", 0)) > 0: s += "  ·  P%d" % int(who.get("prestige", 0))
	return s

func _move(v: Dictionary, dt: float) -> void:
	var r: TextureRect = v.node
	if not is_instance_valid(r):
		boats.erase(v)
		return
	v.t += dt
	var k: float = clampf(v.t / v.stay, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)                      # (eases in and out of the drift)
	var at: Vector2 = (v.a as Vector2).lerp(v.b, e) + Vector2(sin(st._t * 0.45 + v.ph) * 6.0, sin(st._t * 1.2 + v.ph) * 3.0)
	var a := clampf(minf(v.t, v.stay - v.t) / FADE, 0.0, 1.0)
	r.position = at - r.pivot_offset
	r.rotation = sin(st._t * 0.8 + v.ph) * 0.03
	r.modulate.a = a
	var tag: PanelContainer = v.tag
	tag.reset_size()
	tag.position = r.position + (v.top as Vector2) - Vector2(tag.size.x * 0.5, tag.size.y + 4.0)
	tag.modulate.a = a
	if v.said > 0.0:
		v.said -= dt
		if v.said <= 0.0: (v.label as Label).text = _tag_text(v.who)
	v.splash -= dt
	if v.splash <= 0.0 and a >= 1.0:                       # they're fishing too
		v.splash = randf_range(6.0, 12.0)
		var s := at + Vector2(randf_range(-80.0, 80.0), randf_range(50.0, 90.0))
		if st._in_water(s, 0.05):
			st._add_ripple(s, 30.0, 2.0)
			st.burst("splash", s)
	if v.t >= v.stay:
		_free(v)

func _free(v: Dictionary) -> void:
	if is_instance_valid(v.node): v.node.queue_free()
	if is_instance_valid(v.tag): v.tag.queue_free()
	boats.erase(v)

func clear() -> void:
	for v in boats.duplicate(): _free(v)

## a tap on the scene (scene px): a visitor's boat or tag -> they call something and you see who it is
func tap(p: Vector2) -> bool:
	for v in boats:
		var r: TextureRect = v.node
		if not is_instance_valid(r) or r.modulate.a < 0.5: continue
		var box := Rect2(r.position, r.size).grow(16.0)
		var tbox := Rect2((v.tag as Control).position, (v.tag as Control).size).grow(8.0)
		if box.has_point(p) or tbox.has_point(p):
			var who: Dictionary = v.who
			(v.label as Label).text = "%s: %s" % [str(who.get("display_name", "?")).left(18), LINES.pick_random()]
			v.said = 3.0
			st._add_ripple(r.position + r.pivot_offset, 46.0, 2.0)
			var hat: String = VFData.HATS.get(str(who.get("hat", "")), {}).get("name", "")
			m._toast("%s  ·  Level %s%s  ·  %s%s" % [str(who.get("display_name", "?")), VF.commas(int(who.get("level", 1))),
				("  ·  Prestige %d" % int(who.get("prestige", 0))) if int(who.get("prestige", 0)) > 0 else "",
				_boat_name(who), ("  ·  " + hat) if hat != "" else ""], "quest")
			return true
	return false

## --visitors-test: three made-up players sail in; one is tapped. Never saves, never loads the real list.
func test(dir: String) -> void:
	VF.autosave = false
	_poll = 1e9
	m._veteran("River")
	VF.tutorial = 99
	m._close_panel()
	m._apply_biome()
	await m.get_tree().create_timer(1.2).timeout
	_biome = st._biome
	clear()
	Backend.players = [
		{"display_name": "Captain Kipper", "level": 412, "prestige": 3, "boats": 12, "hat": "pirate", "biome": _biome},
		{"display_name": "salmonella", "level": 88, "prestige": 0, "boats": 6, "hat": "duck", "biome": _biome},
		{"display_name": "Reel Deal", "level": 1250, "prestige": 7, "boats": 15, "hat": "crown", "biome": "Sky"}]
	_queue.clear()
	for i in 3:
		var who := _pick()
		if not who.is_empty(): _arrive(who)
	_next = 1e9
	for v in boats: v.t = FADE + 0.5
	await m.get_tree().create_timer(1.0).timeout
	await m._shot(dir + "/visitors_0.png")
	print("VISITORS %s %d boats in the bay" % ["PASS" if boats.size() >= mini(3, shown_max()) else "FAIL", boats.size()])
	if not boats.is_empty():
		var v: Dictionary = boats[0]
		var r: TextureRect = v.node
		var hit := tap(r.position + r.pivot_offset)
		await m.get_tree().create_timer(0.6).timeout
		await m._shot(dir + "/visitors_1_tap.png")
		print("VISITORS %s a tap on a boat shows who it is" % ("PASS" if hit and v.said > 0.0 else "FAIL"))
	clear()
	print("VISITORS %s cleared" % ("PASS" if boats.is_empty() else "FAIL"))

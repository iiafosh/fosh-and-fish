extends Control

signal merchant_clicked
## Top-down fishing stage. Everything lives in "scene space": the 1920x1080
## Blender render, scaled to cover the window. Fish (animated Quaternius
## sheets) swim under the water, seagulls fly over it, crabs walk the beach,
## and the animated fisher stands on the boat's deck holding the line.

const SCENE := Vector2(1920, 1080)
const ART := "res://assets/vf/"
const FX := "res://assets/third_party/kenney_particles/"

var manifest := {}
var root: Control
var backdrop: TextureRect
var caustics: ColorRect
var life_layer: Control          # fish, whales, crabs
var boat: TextureRect
var fisher: TextureRect
var sky_layer: Control           # gulls
var over: Control                # line, bobber, ripples
var fx: Node2D
var _mask: Image
var _scene: Dictionary = {}
var _boat_info: Dictionary = {}
var _fisher_info: Dictionary = {}
var _fisher_tex := {}
var _anim := "idle"
var _anim_t := 0.0
var _biome := ""
var _rod_name := ""
var _rod_tex: Texture2D
var _rod_info := {}
var _boat := ""
var _species: Array = []          # [{tex, frames, cell}]
var _fish: Array = []
var _big: Array = []
var _gulls: Array = []
var _crabs: Array = []
var _ripples: Array = []
var _bobber := Vector2.ZERO
var _bobber_home := Vector2.ZERO
var _cast_t := -1.0
var _cast_from := Vector2.ZERO
var _cast_to := Vector2.ZERO
var aim := Vector2.INF            # where the player last tapped the water (scene px); INF = not aimed
const MAX_CAST := 820.0           # longest cast from the boat, in scene px
var _cast_done: Callable
var _dart: Dictionary = {}
var _t := 0.0
var water_tint := Color(0.4, 0.8, 0.8)
var _ambient: CPUParticles2D
var _merchant_info := {}
var _merchant_tex := {}
var _merchant_anim := "idle"
var _merchant_t := 0.0
var merchant: TextureRect
var merchant_hit: Control
var merchant_tag: PanelContainer
var _glints: CPUParticles2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var f := FileAccess.open(ART + "manifest.json", FileAccess.READ)
	if f: manifest = JSON.parse_string(f.get_as_text())
	root = Control.new()
	root.size = SCENE
	add_child(root)
	backdrop = TextureRect.new()
	backdrop.size = SCENE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(backdrop)
	life_layer = _layer(_draw_life)
	caustics = ColorRect.new()
	caustics.size = SCENE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vf_caustics.gdshader")
	caustics.material = mat
	root.add_child(caustics)
	fx = Node2D.new()
	boat = TextureRect.new()
	boat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boat.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(boat)
	fisher = TextureRect.new()
	fisher.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fisher.stretch_mode = TextureRect.STRETCH_SCALE
	boat.add_child(fisher)
	over = _layer(_draw_over)
	root.add_child(fx)
	sky_layer = _layer(_draw_sky)
	for c in [root, backdrop, caustics, boat, fisher]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["idle", "cast", "reel"]:
		_fisher_tex[k] = _tex("fisher/%s.png" % k)
	_build_merchant()
	_fisher_info = manifest.get("fisher", {})
	_glints = _particles("star_06", 8, 1.8, Color(1, 1, 1, 0.55), 0.03, 0.07)
	_glints.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_glints.emission_rect_extents = SCENE * 0.5
	_glints.position = SCENE * 0.5
	_glints.gravity = Vector2.ZERO
	_glints.initial_velocity_max = 0.0
	_glints.emitting = true
	resized.connect(_fit)
	_fit()

func _layer(cb: Callable) -> Control:
	var c := Control.new()
	c.size = SCENE
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(cb)
	root.add_child(c)
	return c

func _tex(path: String) -> Texture2D:
	var full := (path if path.begins_with("res://") else ART + path)
	if ResourceLoader.exists(full): return load(full)
	return null

func _fit() -> void:
	var s := maxf(size.x / SCENE.x, size.y / SCENE.y)
	root.scale = Vector2(s, s)
	root.position = (size - SCENE * s) * 0.5

func to_screen(p: Vector2) -> Vector2:
	return global_position + root.position + p * root.scale.x

func to_scene(screen: Vector2) -> Vector2:
	return (screen - global_position - root.position) / root.scale.x

## Aim the next casts at a tapped screen point. The bobber only ever lands on open water:
## a tap on land, a dock or a boat moves to the nearest open water around the tap.
## Very long casts are shortened. Returns false if there's no open water nearby.
func set_aim(screen: Vector2) -> bool:
	var from := boat.position + boat.pivot_offset
	var p := to_scene(screen)
	if from.distance_to(p) > MAX_CAST:
		p = from + (p - from).normalized() * MAX_CAST
	var best := Vector2.INF
	if open_water(p):
		best = p
	else:
		# rings around the tap, nearest first
		for r in range(16, 200, 16):
			var n := maxi(8, int(TAU * r / 18.0))
			var found := Vector2.INF
			for i in n:
				var q := p + Vector2.from_angle(TAU * i / n) * r
				if open_water(q) and from.distance_to(q) <= MAX_CAST and (found == Vector2.INF or q.distance_to(p) < found.distance_to(p)):
					found = q
			if found != Vector2.INF:
				best = found
				break
	if best == Vector2.INF:
		return false
	aim = best
	_ripples.append({"pos": best, "t": 0.0, "max": 26.0, "w": 2.0})
	return true

## water at p with a ring of water around it (not touching docks, boats, rocks or the shore),
## and not right under our own boat
func open_water(p: Vector2, margin := 30.0) -> bool:
	if p.x < 20 or p.y < 20 or p.x > SCENE.x - 20 or p.y > SCENE.y - 20: return false
	if p.distance_to(boat.position + boat.pivot_offset) < 110.0: return false
	if not _in_water(p, 0.06): return false
	for i in 8:
		if not _in_water(p + Vector2.from_angle(TAU * i / 8.0) * margin, 0.03): return false
	return true

func bobber_screen() -> Vector2:
	return to_screen(_bobber)

func boat_screen() -> Vector2:
	return to_screen(boat.position + boat.pivot_offset)

# ------------------------------------------------------------- particles
func _particles(texname: String, amount: int, life: float, col: Color, s0: float, s1: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _tex(FX + texname + ".png")
	p.amount = amount
	p.lifetime = life
	p.color = col
	p.scale_amount_min = s0
	p.scale_amount_max = s1
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.add_point(0.2, Color(1, 1, 1, 1))
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = grad
	p.emitting = false
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = m
	fx.add_child(p)
	return p

func burst(kind: String, at: Vector2) -> void:
	var p: CPUParticles2D
	match kind:
		"splash":
			p = _particles("circle_05", 9, 0.45, Color(0.92, 0.98, 1.0, 0.75), 0.012, 0.026)
			p.direction = Vector2.UP
			p.spread = 55.0
			p.initial_velocity_min = 90.0
			p.initial_velocity_max = 170.0
			p.gravity = Vector2(0, 520)
			(p.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
		"sparkle":
			p = _particles("star_06", 26, 1.1, Color(1.0, 0.85, 0.3), 0.08, 0.2)
			p.spread = 180.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 200.0
			p.gravity = Vector2(0, 80)
			p.angular_velocity_min = -180.0
			p.angular_velocity_max = 180.0
		"magic":
			p = _particles("twirl_02", 14, 1.4, Color(1.0, 0.5, 0.9), 0.15, 0.3)
			p.spread = 180.0
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 120.0
			p.gravity = Vector2(0, -40)
			p.angular_velocity_min = 90.0
			p.angular_velocity_max = 270.0
		"confetti":
			p = _particles("star_04", 60, 1.8, Color.WHITE, 0.06, 0.14)
			p.spread = 180.0
			p.initial_velocity_min = 150.0
			p.initial_velocity_max = 420.0
			p.gravity = Vector2(0, 260)
			p.color_initial_ramp = _rainbow()
			(p.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = true
	p.finished.connect(p.queue_free)

func _rainbow() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color("#ff5a5a"))
	g.add_point(0.33, Color("#ffd23f"))
	g.add_point(0.66, Color("#4fd1ff"))
	g.set_color(g.get_point_count() - 1, Color("#7dff9a"))
	return g

func _set_ambient(biome: String) -> void:
	if _ambient: _ambient.queue_free()
	_ambient = null
	var cfg := {"Volcanic": ["spark_05", Color(1.0, 0.55, 0.2), Vector2(0, -40)],
		"Abyss": ["star_06", Color(0.45, 0.95, 1.0, 0.5), Vector2(0, -8)],
		"Alien": ["star_06", Color(0.6, 1.0, 0.75, 0.45), Vector2(0, -8)],
		"Space": ["star_06", Color(0.85, 0.8, 1.0, 0.8), Vector2(0, 0)]}
	if not cfg.has(biome): return
	var c: Array = cfg[biome]
	_ambient = _particles(c[0], 24, 5.0, c[1], 0.03, 0.09)
	_ambient.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_ambient.emission_rect_extents = SCENE * 0.5
	_ambient.position = SCENE * 0.5
	_ambient.gravity = c[2]
	_ambient.initial_velocity_max = 20.0
	_ambient.spread = 180.0
	_ambient.preprocess = 5.0
	_ambient.emitting = true

# ---------------------------------------------------------------- setup
func set_biome(name: String) -> void:
	if name == _biome: return
	_biome = name
	var slug := VFData.slug(name)
	backdrop.texture = _tex("scenes/%s.png" % slug)
	var mt := _tex("scenes/%s_mask.png" % slug)
	_mask = mt.get_image() if mt else null
	if _mask and _mask.is_compressed(): _mask.decompress()
	(caustics.material as ShaderMaterial).set_shader_parameter("mask", mt)
	_scene = manifest.get("scenes", {}).get(name, {"boat": [0.35, 0.62], "bobber": [0.6, 0.55], "unit_px": 56.0, "water": ["#9ff3e6", "#2a9ec4"]})
	water_tint = Color(_scene.water[1])
	(caustics.material as ShaderMaterial).set_shader_parameter("tint", Color(_scene.water[0]).lerp(Color.WHITE, 0.6))
	_bobber_home = Vector2(_scene.bobber[0], _scene.bobber[1]) * SCENE
	_bobber = _bobber_home
	aim = Vector2.INF
	_species.clear()
	var swim: Dictionary = manifest.get("swim", {})
	for f in VFData.BIOMES[name].fish:
		_species.append(_species_entry(f, swim))
	_spawn_life()
	_set_ambient(name)
	_place_boat()
	_place_merchant()

func _species_entry(f: String, swim: Dictionary) -> Dictionary:
	if f in swim.get("species", []):
		var t := _tex("swim/%s.png" % VFData.slug(f))
		if t: return {"tex": t, "frames": int(swim.frames), "cell": float(swim.cell), "len": 1.6}
	return {"tex": _tex("fish_top/%s.png" % VFData.slug(f)), "frames": 1, "cell": 160.0, "len": 1.25}

func set_boat(name: String) -> void:
	if name == _boat: return
	_boat = name
	boat.texture = _tex("boats_top/%s.png" % VFData.slug(name))
	_boat_info = manifest.get("boats_top", {}).get(name, {"deck": [0.6, 0.5], "origin": [0.5, 0.6], "unit_px": 100.0, "fisher_scale": 1.0})
	_place_boat()

func _place_boat() -> void:
	if _scene.is_empty() or _boat_info.is_empty() or boat.texture == null: return
	var k: float = float(_scene.unit_px) / float(_boat_info.unit_px)
	var tex_sz := boat.texture.get_size()
	boat.size = tex_sz * k
	var origin := Vector2(_boat_info.origin[0], _boat_info.origin[1]) * boat.size
	boat.pivot_offset = origin
	boat.position = Vector2(_scene.boat[0], _scene.boat[1]) * SCENE - origin
	# fisher: feet on the deck anchor, scaled to scene units
	if _fisher_info.is_empty(): return
	var cell: float = _fisher_info.cell
	var fk: float = float(_scene.unit_px) / float(_fisher_info.unit_px) * float(_boat_info.get("fisher_scale", 1.0))
	fisher.size = Vector2(cell, cell) * fk
	var deck := Vector2(_boat_info.deck[0], _boat_info.deck[1]) * boat.size
	fisher.position = deck - Vector2(_fisher_info.feet[0], _fisher_info.feet[1]) * fisher.size
	_set_frame()

func _frames(anim: String) -> int:
	return int(_fisher_info.get(anim, {}).get("frames", 1))

func _frame_index() -> int:
	var n := _frames(_anim)
	var fps := 7.0 if _anim == "idle" else 18.0
	var i := int(_anim_t * fps)
	if _anim == "idle": return i % n
	return mini(i, n - 1)

func _set_frame() -> void:
	var t: Texture2D = _fisher_tex.get(_anim)
	if t == null: return
	var cell: float = _fisher_info.get("cell", 256)
	var at := AtlasTexture.new()
	at.atlas = t
	at.region = Rect2(_frame_index() * cell, 0, cell, cell)
	fisher.texture = at

func set_rod(name: String) -> void:
	if name == _rod_name: return
	_rod_name = name
	_rod_tex = _tex("rods_hand/%s.png" % VFData.slug(name))
	_rod_info = manifest.get("rods_hand", {}).get(name, {"grip": [0.08, 0.5], "tip": [0.98, 0.5]})

func _fisher_point(key: String, fallback: Array) -> Vector2:
	var pts: Array = _fisher_info.get(_anim, {}).get(key, [fallback])
	var tp: Array = pts[mini(_frame_index(), pts.size() - 1)]
	var local := fisher.position + Vector2(tp[0], tp[1]) * fisher.size
	return boat.position + boat.pivot_offset + (local - boat.pivot_offset).rotated(boat.rotation) * boat.scale

func rod_grip() -> Vector2:
	return _fisher_point("rod_grip", [0.45, 0.6])

func play_anim(a: String) -> void:
	_anim = a
	_anim_t = 0.0

func rod_tip() -> Vector2:
	if _fisher_info.is_empty() or _boat_info.is_empty(): return _bobber_home
	return _fisher_point("rod_tip", [0.6, 0.45])

# ------------------------------------------------------------------ life
func _mask_px(p: Vector2) -> Color:
	if _mask == null: return Color(1, 0.5, 0, 1)
	return _mask.get_pixel(clampi(int(p.x / SCENE.x * _mask.get_width()), 0, _mask.get_width() - 1),
		clampi(int(p.y / SCENE.y * _mask.get_height()), 0, _mask.get_height() - 1))

func _in_water(p: Vector2, min_depth := 0.12) -> bool:
	var c := _mask_px(p)
	return c.a > 0.5 and c.g >= min_depth

func _on_beach(p: Vector2) -> bool:
	if _mask_px(p).a > 0.3: return false
	for d in [Vector2(0, 60), Vector2(40, 50), Vector2(-40, 50)]:
		if _mask_px(p + d).a > 0.5: return true
	return false

func _rand_point(pred: Callable, tries := 3000) -> Variant:
	for i in tries:
		var p := Vector2(randf() * SCENE.x, randf() * SCENE.y)
		if pred.call(p): return p
	return null

func _spawn_life() -> void:
	_fish.clear()
	_big.clear()
	_gulls.clear()
	_crabs.clear()
	if not _species.is_empty():
		for i in 16:
			var p = _rand_point(func(q): return _in_water(q, 0.2))
			if p == null: break
			var sp: Dictionary = _species[randi() % _species.size()]
			var a := randf() * TAU
			_fish.append({"pos": p, "vel": Vector2.from_angle(a) * 40.0, "ang": a, "speed": randf_range(25, 55),
				"target": p, "sp": sp, "size": randf_range(0.6, 1.0), "wig": randf() * TAU})
	var bigs := {"Ocean": ["whale", "manta"], "Abyss": ["manta"], "Space": ["whale"], "Sky": ["manta"]}
	for kind in bigs.get(_biome, []):
		var t := _tex("swim/%s.png" % kind)
		if t: _big.append({"tex": t, "kind": kind, "pos": Vector2(-400, SCENE.y * randf_range(0.6, 0.9)), "wait": randf_range(4, 14), "vel": Vector2(40, -6)})
	if _biome in ["River", "Ocean", "Volcanic", "Sky"]:
		var g := _tex("critters/gull.png")
		for i in 3:
			var ang := randf_range(-0.4, 0.4) + (PI if randf() < 0.5 else 0.0)
			_gulls.append({"tex": g, "pos": Vector2(randf() * SCENE.x, randf_range(0.05, 0.6) * SCENE.y), "ang": ang,
				"turn": 0.0, "speed": randf_range(95, 135), "ph": randf() * TAU, "glide": 0.0, "fr": 0.0})
	if _biome in ["River", "Ocean"]:
		var c := _tex("critters/crab.png")
		for i in 3:
			var p = _rand_point(_on_beach)
			if p != null: _crabs.append({"tex": c, "pos": p, "home": p, "ph": randf() * TAU, "dir": 1.0, "wait": randf() * 2.0, "x": 0.0, "tilt": 0.0})

func _process(delta: float) -> void:
	_t += delta
	_anim_t += delta
	if _anim != "idle" and _frame_index() >= _frames(_anim) - 1 and _anim_t > _frames(_anim) / 18.0 + 0.25:
		play_anim("idle")
	_set_frame()
	_tick_merchant(delta)
	for f in _fish:
		# wander toward a target in deep enough water; turn at a limited rate
		if f.pos.distance_to(f.target) < 40.0 or not _in_water(f.target, 0.18):
			for _i in 12:
				var cand: Vector2 = f.pos + Vector2.from_angle(randf() * TAU) * randf_range(150, 420)
				if _in_water(cand, 0.2):
					f.target = cand
					break
			f.speed = randf_range(22, 60)
		var want_ang: float = (f.target - f.pos).angle()
		if not _in_water(f.pos + Vector2.from_angle(f.ang) * 60.0, 0.12):
			want_ang = (Vector2(SCENE.x * 0.5, SCENE.y * 0.85) - f.pos).angle()
		f.ang = rotate_toward(f.ang, want_ang, 1.6 * delta)
		f.vel = Vector2.from_angle(f.ang) * f.speed
		f.pos += f.vel * delta
	for b in _big:
		if b.wait > 0.0:
			b.wait -= delta
			continue
		b.pos += b.vel * delta
		if b.pos.x > SCENE.x + 500:
			b.pos = Vector2(-500, SCENE.y * randf_range(0.6, 0.95))
			b.wait = randf_range(15, 35)
	for g in _gulls:
		# wander: ease the turn rate toward a slowly changing target
		var want := sin(_t * 0.23 + g.ph) * 0.35 + sin(_t * 0.07 + g.ph * 2.0) * 0.25
		g.turn = lerpf(g.turn, want, delta * 0.8)
		g.ang += g.turn * delta
		g.pos += Vector2.from_angle(g.ang) * g.speed * delta
		# alternate flapping and gliding
		g.glide -= delta
		if g.glide < -2.4: g.glide = randf_range(1.0, 2.2)
		if g.glide <= 0.0: g.fr += delta * 11.0
		if g.pos.x < -220 or g.pos.x > SCENE.x + 220 or g.pos.y < -220 or g.pos.y > SCENE.y + 220:
			var from_left := randf() < 0.5
			g.pos = Vector2(-180 if from_left else SCENE.x + 180, randf_range(0.05, 0.6) * SCENE.y)
			g.ang = randf_range(-0.3, 0.3) + (0.0 if from_left else PI)
			g.turn = 0.0
	for c in _crabs:
		c.ph += delta
		if c.wait > 0.0:
			c.wait -= delta
		else:
			c.x += c.dir * 55.0 * delta
			if absf(c.x) > 80.0:
				c.dir = -signf(c.x)
				c.wait = randf_range(0.6, 2.5)
			elif randf() < delta * 0.4:
				c.dir = -c.dir
				c.wait = randf_range(0.6, 2.5)
		var walking: bool = c.wait <= 0.0
		c.pos = c.home + Vector2(c.x, sin(c.ph * 14.0) * 1.2 if walking else 0.0)
		c.tilt = sin(c.ph * 14.0) * 0.08 if walking else 0.0
	boat.rotation = sin(_t * 1.1) * 0.025
	boat.scale = Vector2.ONE * (1.0 + sin(_t * 1.6) * 0.008)
	if randf() < delta * 0.9:
		_ripples.append({"pos": Vector2(_scene.get("boat", [0.35, 0.6])[0], _scene.get("boat", [0.35, 0.6])[1]) * SCENE, "t": 0.0, "max": 90.0, "w": 2.0})
	if randf() < delta * 0.6 and _cast_t < 0.0:
		_ripples.append({"pos": _bobber, "t": 0.0, "max": 34.0, "w": 1.5})
	if _cast_t >= 0.0:
		_cast_t += delta / 0.42
		var k := clampf(_cast_t, 0.0, 1.0)
		var tip := rod_tip()
		_bobber = (tip if _cast_t < 0.0 else _cast_from).lerp(_cast_to, k) + Vector2(0, -sin(k * PI) * 130.0)
		if _cast_t >= 1.0:
			_cast_t = -1.0
			_bobber = _cast_to
			splash(_bobber)
			burst("splash", _bobber)
			if _cast_done.is_valid(): _cast_done.call()
	if not _dart.is_empty():
		_dart.t += delta / 0.35
		_dart.pos = (_dart.from as Vector2).lerp(_bobber, minf(_dart.t, 1.0))
		if _dart.t >= 1.0:
			splash(_bobber, 1.6)
			burst("splash", _bobber)
			_dart = {}
	for r in _ripples: r.t += delta
	_ripples = _ripples.filter(func(r): return r.t < 1.4)
	life_layer.queue_redraw()
	sky_layer.queue_redraw()
	over.queue_redraw()

func _sheet_draw(layer: Control, sp: Dictionary, p: Vector2, ang: float, length_px: float, col: Color, phase: float) -> void:
	var t: Texture2D = sp.tex
	if t == null: return
	var cell: float = sp.cell
	var n: int = sp.frames
	var fi := int((_t * 10.0 + phase * 3.0)) % n if n > 1 else 0
	var sc := length_px / cell
	layer.draw_set_transform(p, ang + (0.0 if n > 1 else sin(_t * 9.0 + phase) * 0.08), Vector2(sc, sc))
	layer.draw_texture_rect_region(t, Rect2(-cell * 0.5, -cell * 0.5, cell, cell), Rect2(fi * cell, 0, cell, t.get_height()), col)

func _draw_life() -> void:
	var u: float = float(_scene.get("unit_px", 56.0))
	for b in _big:
		if b.wait > 0.0: continue
		var len_px := u * (11.0 if b.kind == "whale" else 7.0)
		var sp := {"tex": b.tex, "frames": 8, "cell": 128.0}
		_sheet_draw(life_layer, sp, b.pos + Vector2(30, 40), b.vel.angle(), len_px, Color(0, 0.05, 0.1, 0.12), 0.0)
		_sheet_draw(life_layer, sp, b.pos, b.vel.angle(), len_px, Color(water_tint.r, water_tint.g, water_tint.b, 0.35).lerp(Color(1, 1, 1, 0.35), 0.3), 0.0)
	for f in _fish:
		var depth := _mask_px(f.pos).g
		var len_px: float = u * f.sp.len * f.size
		_sheet_draw(life_layer, f.sp, f.pos + Vector2(14, 18) * (0.5 + depth), f.vel.angle(), len_px, Color(0, 0.05, 0.1, 0.18), f.wig)
		var a := clampf(0.9 - depth * 0.55, 0.3, 0.9)
		_sheet_draw(life_layer, f.sp, f.pos, f.vel.angle(), len_px, Color(1, 1, 1, a).lerp(Color(water_tint.r, water_tint.g, water_tint.b, a), 0.3 + depth * 0.3), f.wig)
	if not _dart.is_empty():
		_sheet_draw(life_layer, _dart.sp, _dart.pos, ((_bobber - (_dart.from as Vector2))).angle(), u * 1.8, Color(1, 1, 1, 0.95), 0.0)
	for c in _crabs:
		var ct: Texture2D = c.tex
		if ct == null: continue
		var cs := u * 0.9 / ct.get_width()
		life_layer.draw_set_transform(c.pos + Vector2(6, 8), c.tilt, Vector2(cs, cs))
		life_layer.draw_texture(ct, -ct.get_size() * 0.5, Color(0, 0, 0, 0.18))
		life_layer.draw_set_transform(c.pos, c.tilt, Vector2(cs, cs))
		life_layer.draw_texture(ct, -ct.get_size() * 0.5)
	life_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_sky() -> void:
	var u: float = float(_scene.get("unit_px", 56.0))
	var info: Dictionary = manifest.get("gull", {"frames": 8, "cell": 160})
	var n: int = info.frames
	var cell: float = info.cell
	for g in _gulls:
		var t: Texture2D = g.tex
		if t == null: continue
		var fi := int(g.fr) % n
		var sc := u * 1.9 / cell
		var squash := 1.0 - clampf(absf(g.turn) * 0.5, 0.0, 0.2)
		var src := Rect2(fi * cell, 0, cell, cell)
		var dst := Rect2(-cell * 0.5, -cell * 0.5, cell, cell)
		sky_layer.draw_set_transform(g.pos + Vector2(110, 160), g.ang, Vector2(sc, sc * squash))
		sky_layer.draw_texture_rect_region(t, dst, src, Color(0, 0.05, 0.1, 0.15))
		sky_layer.draw_set_transform(g.pos, g.ang, Vector2(sc, sc * squash))
		sky_layer.draw_texture_rect_region(t, dst, src)
	sky_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_rod() -> void:
	if _rod_tex == null or _fisher_info.is_empty(): return
	var g := rod_grip()
	var t := rod_tip()
	var sz := _rod_tex.get_size()
	var gs := Vector2(_rod_info.grip[0], _rod_info.grip[1]) * sz
	var ts := Vector2(_rod_info.tip[0], _rod_info.tip[1]) * sz
	var k := (t - g).length() / maxf(1.0, (ts - gs).length())
	over.draw_set_transform(g, (t - g).angle(), Vector2(k, k))
	over.draw_texture(_rod_tex, -gs)
	over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_over() -> void:
	_draw_rod()
	for r in _ripples:
		if r.t < 0.0: continue
		var k: float = r.t / 1.4
		over.draw_arc(r.pos, 6.0 + k * r.max, 0, TAU, 40, Color(1, 1, 1, (1.0 - k) * 0.55), r.w, true)
	var tip := rod_tip()
	var mid := (tip + _bobber) * 0.5 + Vector2(0, 30 if _cast_t < 0.0 else 0)
	var pts := PackedVector2Array()
	for i in 17:
		var k := i / 16.0
		pts.append(tip.lerp(mid, k).lerp(mid.lerp(_bobber, k), k))
	over.draw_polyline(pts, Color(0.95, 0.95, 0.9, 0.8), 1.6, true)
	var bob := _bobber + Vector2(0, sin(_t * 2.4) * 2.0)
	over.draw_circle(bob + Vector2(4, 5), 9.0, Color(0, 0, 0, 0.18))
	over.draw_circle(bob, 9.0, Color("#ff4b3e"))
	over.draw_circle(bob + Vector2(0, -3), 5.0, Color.WHITE)

# ----------------------------------------------------------------- actions
func cast(done: Callable) -> void:
	play_anim("cast")
	if aim != Vector2.INF:
		_cast_to = aim + Vector2(randf_range(-6, 6), randf_range(-4, 4))    # right where you tapped
	else:
		_cast_to = _bobber_home + Vector2(randf_range(-90, 90), randf_range(-50, 50))
	if not open_water(_cast_to): _cast_to = aim if aim != Vector2.INF else _bobber_home
	_cast_done = done
	# release the bobber mid-swing
	get_tree().create_timer(0.22).timeout.connect(func():
		_cast_from = rod_tip()
		_cast_t = 0.0)

func splash(at: Vector2, big := 1.0) -> void:
	for i in 3:
		_ripples.append({"pos": at, "t": -i * 0.15, "max": 50.0 * big, "w": 2.5})

func show_bite(fish_name: String) -> void:
	play_anim("reel")
	var sp := _species_entry(fish_name, manifest.get("swim", {}))
	if sp.tex == null: return
	_dart = {"sp": sp, "from": _bobber + Vector2.from_angle(randf() * TAU) * 170.0, "pos": _bobber, "t": 0.0}

# ---------------------------------------------------------------- merchant
func _build_merchant() -> void:
	_merchant_info = manifest.get("merchant", {})
	for k in ["idle", "wave"]:
		_merchant_tex[k] = _tex("merchant/%s.png" % k)
	merchant = TextureRect.new()
	merchant.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	merchant.stretch_mode = TextureRect.STRETCH_SCALE
	merchant.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(merchant)
	root.move_child(merchant, caustics.get_index() + 1)
	merchant_hit = Control.new()
	merchant_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	merchant_hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	merchant_hit.gui_input.connect(_merchant_input)
	merchant_hit.mouse_entered.connect(func(): _hover_merchant(true))
	merchant_hit.mouse_exited.connect(func(): _hover_merchant(false))
	root.add_child(merchant_hit)
	merchant_tag = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fbf5e8")
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color("#c9a86a")
	sb.set_content_margin_all(10)
	sb.shadow_size = 6
	sb.shadow_color = Color(0.2, 0.12, 0.05, 0.25)
	merchant_tag.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	var t := Label.new()
	t.text = "Merchant"
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color("#3b2c20"))
	var sub := Label.new()
	sub.text = "Click to shop: rods · bait · boats"
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color("#8c7660"))
	v.add_child(t)
	v.add_child(sub)
	merchant_tag.add_child(v)
	merchant_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	merchant_tag.visible = false
	root.add_child(merchant_tag)

func _place_merchant() -> void:
	if merchant == null or _merchant_info.is_empty() or not _scene.has("merchant"): return
	var cell: float = _merchant_info.cell
	var k: float = float(_scene.get("merchant_unit_px", _scene.unit_px)) / float(_merchant_info.unit_px) * 0.95
	merchant.size = Vector2(cell, cell) * k
	var spot := Vector2(_scene.merchant[0], _scene.merchant[1]) * SCENE
	merchant.position = spot - Vector2(_merchant_info.anchor[0], _merchant_info.anchor[1]) * merchant.size
	merchant.position.y = maxf(merchant.position.y, 125.0)      # keep the roof clear of the HUD
	merchant_hit.position = merchant.position + merchant.size * Vector2(0.08, 0.1)
	merchant_hit.size = merchant.size * Vector2(0.84, 0.75)
	merchant_tag.position = merchant.position + Vector2(merchant.size.x * 0.5 - 150, merchant.size.y * 0.82)

func _tick_merchant(delta: float) -> void:
	if merchant == null or _merchant_info.is_empty(): return
	_merchant_t += delta
	var n := int(_merchant_info.get(_merchant_anim, {}).get("frames", 1))
	var fi := int(_merchant_t * 8.0)
	if _merchant_anim == "wave" and fi >= n * 2:
		_merchant_anim = "idle"
		_merchant_t = 0.0
	elif _merchant_anim == "idle" and _merchant_t > 9.0:
		_merchant_anim = "wave"           # greet the player now and then
		_merchant_t = 0.0
	var tex: Texture2D = _merchant_tex.get(_merchant_anim)
	if tex == null: return
	var cell: float = _merchant_info.cell
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2((fi % n) * cell, 0, cell, cell)
	merchant.texture = at

func _hover_merchant(on: bool) -> void:
	merchant_tag.visible = on
	merchant.modulate = Color(1.08, 1.06, 1.0) if on else Color.WHITE
	if on and _merchant_anim == "idle":
		_merchant_anim = "wave"
		_merchant_t = 0.0

func _merchant_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		merchant_clicked.emit()
		merchant_hit.accept_event()

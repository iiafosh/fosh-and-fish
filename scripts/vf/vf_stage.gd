extends Control
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
var _cast_done: Callable
var _dart: Dictionary = {}
var _t := 0.0
var water_tint := Color(0.4, 0.8, 0.8)
var _ambient: CPUParticles2D
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
	_fisher_info = manifest.get("fisher", {})
	_glints = _particles("star_06", 18, 1.6, Color(1, 1, 1, 0.9), 0.04, 0.12)
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
			p = _particles("circle_05", 22, 0.6, Color(0.95, 1, 1, 0.9), 0.03, 0.07)
			p.direction = Vector2.UP
			p.spread = 70.0
			p.initial_velocity_min = 120.0
			p.initial_velocity_max = 260.0
			p.gravity = Vector2(0, 600)
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
		"Abyss": ["light_02", Color(0.4, 0.95, 1.0, 0.6), Vector2(0, -12)],
		"Alien": ["light_02", Color(0.6, 1.0, 0.7, 0.5), Vector2(0, -15)],
		"Space": ["star_06", Color(0.85, 0.8, 1.0, 0.8), Vector2(0, 0)]}
	if not cfg.has(biome): return
	var c: Array = cfg[biome]
	_ambient = _particles(c[0], 40, 5.0, c[1], 0.05, 0.16)
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
	_species.clear()
	var swim: Dictionary = manifest.get("swim", {})
	for f in VFData.BIOMES[name].fish:
		_species.append(_species_entry(f, swim))
	_spawn_life()
	_set_ambient(name)
	_place_boat()

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

func play_anim(a: String) -> void:
	_anim = a
	_anim_t = 0.0

func rod_tip() -> Vector2:
	if _fisher_info.is_empty() or _boat_info.is_empty(): return _bobber_home
	var tips: Array = _fisher_info.get(_anim, {}).get("rod_tip", [[0.6, 0.45]])
	var tp: Array = tips[mini(_frame_index(), tips.size() - 1)]
	var local := fisher.position + Vector2(tp[0], tp[1]) * fisher.size
	return boat.position + boat.pivot_offset + (local - boat.pivot_offset).rotated(boat.rotation) * boat.scale

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
			_fish.append({"pos": p, "vel": Vector2.from_angle(randf() * TAU) * randf_range(25, 55), "sp": sp,
				"size": randf_range(0.6, 1.0), "wig": randf() * TAU})
	var bigs := {"Ocean": ["whale", "manta"], "Abyss": ["manta"], "Space": ["whale"], "Sky": ["manta"]}
	for kind in bigs.get(_biome, []):
		var t := _tex("swim/%s.png" % kind)
		if t: _big.append({"tex": t, "kind": kind, "pos": Vector2(-400, SCENE.y * randf_range(0.6, 0.9)), "wait": randf_range(4, 14), "vel": Vector2(40, -6)})
	if _biome in ["River", "Ocean", "Volcanic", "Sky"]:
		var g := _tex("critters/gull.png")
		for i in 3:
			_gulls.append({"tex": g, "pos": Vector2(randf() * SCENE.x, randf() * SCENE.y * 0.6), "vel": Vector2.from_angle(randf_range(-0.4, 0.4) + (PI if randf() < 0.5 else 0.0)) * randf_range(90, 140), "ph": randf() * TAU})
	if _biome in ["River", "Ocean"]:
		var c := _tex("critters/crab.png")
		for i in 3:
			var p = _rand_point(_on_beach)
			if p != null: _crabs.append({"tex": c, "pos": p, "home": p, "ph": randf() * TAU, "dir": 1.0})

func _process(delta: float) -> void:
	_t += delta
	_anim_t += delta
	if _anim != "idle" and _frame_index() >= _frames(_anim) - 1 and _anim_t > _frames(_anim) / 18.0 + 0.25:
		play_anim("idle")
	_set_frame()
	for f in _fish:
		var v: Vector2 = f.vel
		v = v.rotated(sin(_t * 0.7 + f.wig) * 0.6 * delta)
		if not _in_water(f.pos + v.normalized() * 70.0, 0.15):
			v = v.rotated(PI * 2.7 * delta)
			if not _in_water(f.pos, 0.1): v = (Vector2(SCENE.x * 0.5, SCENE.y * 0.85) - f.pos).normalized() * v.length()
		f.vel = v
		f.pos += v * delta
	for b in _big:
		if b.wait > 0.0:
			b.wait -= delta
			continue
		b.pos += b.vel * delta
		if b.pos.x > SCENE.x + 500:
			b.pos = Vector2(-500, SCENE.y * randf_range(0.6, 0.95))
			b.wait = randf_range(15, 35)
	for g in _gulls:
		g.pos += g.vel * delta
		g.vel = g.vel.rotated(sin(_t * 0.3 + g.ph) * 0.15 * delta)
		if g.pos.x < -200: g.pos.x = SCENE.x + 150
		if g.pos.x > SCENE.x + 200: g.pos.x = -150
		g.pos.y = wrapf(g.pos.y, -150, SCENE.y + 150)
	for c in _crabs:
		c.ph += delta
		var sidestep := sin(c.ph * 0.6) * 70.0
		c.pos = c.home + Vector2(sidestep, sin(c.ph * 7.0) * 1.5)
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
		life_layer.draw_set_transform(c.pos, 0.0, Vector2(cs, cs))
		life_layer.draw_texture(ct, -ct.get_size() * 0.5)
	life_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_sky() -> void:
	var u: float = float(_scene.get("unit_px", 56.0))
	for g in _gulls:
		var t: Texture2D = g.tex
		if t == null: continue
		var flap := 0.75 + 0.25 * sin(_t * 9.0 + g.ph)
		var s := u * 1.7 / t.get_width()
		var ang: float = g.vel.angle()
		sky_layer.draw_set_transform(g.pos + Vector2(120, 170), ang, Vector2(s, s * flap))
		sky_layer.draw_texture(t, -t.get_size() * 0.5, Color(0, 0.05, 0.1, 0.16))
		sky_layer.draw_set_transform(g.pos, ang, Vector2(s, s * flap))
		sky_layer.draw_texture(t, -t.get_size() * 0.5)
	sky_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_over() -> void:
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
	_cast_to = _bobber_home + Vector2(randf_range(-90, 90), randf_range(-50, 50))
	if not _in_water(_cast_to, 0.1): _cast_to = _bobber_home
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

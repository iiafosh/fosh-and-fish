extends Control
## Top-down fishing stage. Everything lives in "scene space": the 1920x1080
## Blender render, scaled to cover the window. Fish swim under the water
## (kept inside the water mask), the boat bobs at the spot baked into the
## manifest, and the line runs from the rod tip to the bobber.

const SCENE := Vector2(1920, 1080)
const ART := "res://assets/vf/"

var manifest := {}
var root: Control                 # scene-space container (scaled)
var backdrop: TextureRect
var caustics: ColorRect
var fish_layer: Control
var boat: TextureRect
var over: Control                 # line, bobber, ripples
var _mask: Image
var _scene: Dictionary = {}
var _boat_info: Dictionary = {}
var _biome := ""
var _boat := ""
var _fish_tex: Array = []
var _fish: Array = []             # {pos, vel, tex, size, depth}
var _ripples: Array = []          # {pos, t, max}
var _bobber := Vector2.ZERO
var _bobber_home := Vector2.ZERO
var _cast_t := -1.0
var _cast_from := Vector2.ZERO
var _cast_to := Vector2.ZERO
var _cast_done: Callable
var _dart: Dictionary = {}
var _t := 0.0
var water_tint := Color(0.4, 0.8, 0.8)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var f := FileAccess.open(ART + "manifest.json", FileAccess.READ)
	if f: manifest = JSON.parse_string(f.get_as_text())
	root = Control.new()
	root.size = SCENE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	backdrop = TextureRect.new()
	backdrop.size = SCENE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(backdrop)
	fish_layer = Control.new()
	fish_layer.size = SCENE
	fish_layer.draw.connect(_draw_fish)
	root.add_child(fish_layer)
	caustics = ColorRect.new()
	caustics.size = SCENE
	caustics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vf_caustics.gdshader")
	caustics.material = mat
	root.add_child(caustics)
	boat = TextureRect.new()
	boat.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boat.stretch_mode = TextureRect.STRETCH_SCALE
	boat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over = Control.new()
	over.size = SCENE
	over.draw.connect(_draw_over)
	root.add_child(over)
	root.add_child(boat)
	root.move_child(boat, root.get_child_count() - 2)   # boat under the line/bobber layer
	for c in [fish_layer, over]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_fit)
	_fit()

func _tex(path: String) -> Texture2D:
	if ResourceLoader.exists(ART + path): return load(ART + path)
	if FileAccess.file_exists(ART + path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(ART + path))
		if img: return ImageTexture.create_from_image(img)
	return null

func _fit() -> void:
	var s := maxf(size.x / SCENE.x, size.y / SCENE.y)
	root.scale = Vector2(s, s)
	root.position = (size - SCENE * s) * 0.5

## Scene-space point -> this control's local space (for UI effects).
func to_screen(p: Vector2) -> Vector2:
	return global_position + root.position + p * root.scale.x

func bobber_screen() -> Vector2:
	return to_screen(_bobber)

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
	_fish_tex.clear()
	for f in VFData.BIOMES[name].fish:
		var t := _tex("fish_top/%s.png" % VFData.slug(f))
		if t: _fish_tex.append(t)
	_spawn_fish()
	_place_boat()

func set_boat(name: String) -> void:
	if name == _boat: return
	_boat = name
	boat.texture = _tex("boats_top/%s.png" % VFData.slug(name))
	_boat_info = manifest.get("boats_top", {}).get(name, {"rod_tip": [0.8, 0.2], "origin": [0.5, 0.6], "unit_px": 100.0})
	_place_boat()

func _place_boat() -> void:
	if _scene.is_empty() or _boat_info.is_empty() or boat.texture == null: return
	var k: float = float(_scene.unit_px) / float(_boat_info.unit_px)
	var tsz := boat.texture.get_size() * k
	boat.size = tsz
	var origin := Vector2(_boat_info.origin[0], _boat_info.origin[1]) * tsz
	boat.pivot_offset = origin
	boat.position = Vector2(_scene.boat[0], _scene.boat[1]) * SCENE - origin

func rod_tip() -> Vector2:
	if _boat_info.is_empty(): return _bobber_home
	var local := Vector2(_boat_info.rod_tip[0], _boat_info.rod_tip[1]) * boat.size
	return boat.position + boat.pivot_offset + (local - boat.pivot_offset).rotated(boat.rotation) * boat.scale

# ------------------------------------------------------------------- fish
func _in_water(p: Vector2, min_depth := 0.12) -> bool:
	if _mask == null: return true
	var ip := Vector2i(clampi(int(p.x / SCENE.x * _mask.get_width()), 0, _mask.get_width() - 1),
		clampi(int(p.y / SCENE.y * _mask.get_height()), 0, _mask.get_height() - 1))
	var c := _mask.get_pixelv(ip)
	return c.a > 0.5 and c.g >= min_depth

func _depth(p: Vector2) -> float:
	if _mask == null: return 0.5
	var c := _mask.get_pixel(clampi(int(p.x / SCENE.x * _mask.get_width()), 0, _mask.get_width() - 1),
		clampi(int(p.y / SCENE.y * _mask.get_height()), 0, _mask.get_height() - 1))
	return c.g

func _spawn_fish() -> void:
	_fish.clear()
	if _fish_tex.is_empty(): return
	var tries := 0
	while _fish.size() < 14 and tries < 2000:
		tries += 1
		var p := Vector2(randf() * SCENE.x, randf() * SCENE.y)
		if not _in_water(p, 0.2): continue
		_fish.append({"pos": p, "vel": Vector2.from_angle(randf() * TAU) * randf_range(25, 55),
			"tex": _fish_tex[randi() % _fish_tex.size()], "size": randf_range(0.55, 1.0), "wig": randf() * TAU})

func _process(delta: float) -> void:
	_t += delta
	# fish wander and avoid the shore
	for f in _fish:
		var v: Vector2 = f.vel
		v = v.rotated(sin(_t * 0.7 + f.wig) * 0.6 * delta)
		var ahead: Vector2 = f.pos + v.normalized() * 60.0
		if not _in_water(ahead, 0.15):
			v = v.rotated(PI * 0.9 * delta * 3.0)
			if not _in_water(f.pos, 0.1): v = (Vector2(SCENE.x * 0.5, SCENE.y * 0.85) - f.pos).normalized() * v.length()
		f.vel = v
		f.pos += v * delta
		f.pos.x = clampf(f.pos.x, -40, SCENE.x + 40)
		f.pos.y = clampf(f.pos.y, -40, SCENE.y + 40)
	# boat bob
	boat.rotation = sin(_t * 1.1) * 0.025
	boat.scale = Vector2.ONE * (1.0 + sin(_t * 1.6) * 0.008)
	if randf() < delta * 0.9:
		_ripples.append({"pos": Vector2(_scene.get("boat", [0.35, 0.6])[0], _scene.get("boat", [0.35, 0.6])[1]) * SCENE, "t": 0.0, "max": 90.0, "w": 2.0})
	if randf() < delta * 0.6 and _cast_t < 0.0:
		_ripples.append({"pos": _bobber, "t": 0.0, "max": 34.0, "w": 1.5})
	# cast flight
	if _cast_t >= 0.0:
		_cast_t += delta / 0.38
		var k := minf(_cast_t, 1.0)
		_bobber = _cast_from.lerp(_cast_to, k) + Vector2(0, -sin(k * PI) * 120.0)
		if _cast_t >= 1.0:
			_cast_t = -1.0
			_bobber = _cast_to
			splash(_bobber)
			if _cast_done.is_valid(): _cast_done.call()
	# darting catch fish
	if not _dart.is_empty():
		_dart.t += delta / 0.35
		_dart.pos = (_dart.from as Vector2).lerp(_bobber, minf(_dart.t, 1.0))
		if _dart.t >= 1.0:
			splash(_bobber, 1.6)
			_dart = {}
	for r in _ripples: r.t += delta
	_ripples = _ripples.filter(func(r): return r.t < 1.4)
	fish_layer.queue_redraw()
	over.queue_redraw()

func _draw_fish() -> void:
	var u: float = float(_scene.get("unit_px", 56.0))
	for f in _fish:
		_draw_one(f.tex, f.pos, f.vel.angle(), f.size * u * 1.25 / 160.0, f.wig, _depth(f.pos))
	if not _dart.is_empty():
		_draw_one(_dart.tex, _dart.pos, ((_bobber - (_dart.from as Vector2))).angle(), u * 1.4 / 160.0, 0.0, 0.2)

func _draw_one(t: Texture2D, p: Vector2, ang: float, sc: float, wig: float, depth: float) -> void:
	if t == null: return
	var sz := t.get_size()
	var sway := sin(_t * 9.0 + wig) * 0.08
	# shadow on the seabed
	fish_layer.draw_set_transform(p + Vector2(14, 18) * (0.5 + depth), ang + sway, Vector2(sc, sc))
	fish_layer.draw_texture(t, -sz * 0.5, Color(0, 0.05, 0.1, 0.18))
	fish_layer.draw_set_transform(p, ang + sway, Vector2(sc, sc))
	var a := clampf(0.85 - depth * 0.55, 0.3, 0.85)
	fish_layer.draw_texture(t, -sz * 0.5, Color(1, 1, 1, a).lerp(Color(water_tint.r, water_tint.g, water_tint.b, a), 0.35 + depth * 0.3))
	fish_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_over() -> void:
	for r in _ripples:
		var k: float = r.t / 1.4
		over.draw_arc(r.pos, 6.0 + k * r.max, 0, TAU, 40, Color(1, 1, 1, (1.0 - k) * 0.55), r.w, true)
	var tip := rod_tip()
	var mid := (tip + _bobber) * 0.5 + Vector2(0, 40)
	var pts := PackedVector2Array()
	for i in 17:
		var k := i / 16.0
		pts.append(tip.lerp(mid, k).lerp(mid.lerp(_bobber, k), k))
	over.draw_polyline(pts, Color(0.12, 0.1, 0.08, 0.85), 2.2, true)
	var bob := _bobber + Vector2(0, sin(_t * 2.4) * 2.0)
	over.draw_circle(bob + Vector2(4, 5), 9.0, Color(0, 0, 0, 0.18))
	over.draw_circle(bob, 9.0, Color("#ff4b3e"))
	over.draw_circle(bob + Vector2(0, -3), 5.0, Color.WHITE)

# ----------------------------------------------------------------- actions
func cast(done: Callable) -> void:
	_cast_from = _bobber
	_cast_to = _bobber_home + Vector2(randf_range(-90, 90), randf_range(-50, 50))
	if not _in_water(_cast_to, 0.1): _cast_to = _bobber_home
	_cast_done = done
	_cast_t = 0.0

func splash(at: Vector2, big := 1.0) -> void:
	for i in 3:
		_ripples.append({"pos": at, "t": -i * 0.15, "max": 50.0 * big, "w": 2.5})

func show_bite(fish_name: String) -> void:
	var t := _tex("fish_top/%s.png" % VFData.slug(fish_name))
	if t == null: return
	_dart = {"tex": t, "from": _bobber + Vector2.from_angle(randf() * TAU) * 160.0, "pos": _bobber, "t": 0.0}

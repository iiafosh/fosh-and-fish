extends Control

signal merchant_clicked
## Top-down fishing stage. Everything lives in "scene space": the 1920x1080
## Blender render, scaled to cover the window. Fish (animated Quaternius
## sheets) swim under the water, seagulls fly over it, crabs walk the beach,
## and the captain sits on the boat's deck holding the line (gets up to cheer, idles with
## little gags in between). The shop is part of each backdrop; the shopkeeper stands on its deck.

const SCENE := Vector2(1920, 1080)
const ATMOS := {"River": [1.0, 0.16], "Ocean": [1.0, 0.16], "Sky": [1.0, 0.09], "Volcanic": [1.5, 0.24],   # biome: water light, cloud shadows
	"Space": [0.8, 0.0], "Alien": [1.0, 0.0], "Abyss": [0.7, 0.0]}
const ART := "res://assets/vf/"
const FX := "res://assets/third_party/kenney_particles/"

var manifest := {}
var root: Control
var backdrop: TextureRect
var caustics: ColorRect
var life_layer: Control          # fish, whales, crabs
var boat: TextureRect
var boat_foam: TextureRect        # foam and shadow on the water around the hull (behind the boat, moves with it)
var boat_reflect: TextureRect     # the boat in the water (the same)
var fisher: TextureRect
var sky_layer: Control           # gulls
var over: Control                # line, bobber, ripples
var fx: Node2D
var atmos: ColorRect             # cloud shadows and the vignette
var _mask: Image
var _scene: Dictionary = {}
var _boat_info: Dictionary = {}
var _side_tex: Texture2D
var _side_pivot := Vector2.ZERO   # where the side view's pivot is (the captain and his rod are placed from it)
var _turn: Dictionary = {}        # the boat from other angles (tools/blender/vf_turn.py), {} if it has none
var _turn_atlas := AtlasTexture.new()
var _turn_keep: Array = []
var _turn_frame := 0
var _hulls := {}
var _fisher_info: Dictionary = {}
var _fisher_tex := {}
var _anim := "idle"
var _anim_t := 0.0
var _react := ""                  # reaction queued after the cast / reel (happy, dance, sad, shrug)
var _idle_wait := 5.0             # seconds until the next idle gag (yawn, doze...)
var _last_cheer := -100.0
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
# ---- the catch (show_catch): the float goes under, the rod bends, the fish flies to the boat
const ROD_BEND := 0.3             # how far the tip goes at full bend, of the rod's length
var _bobber_tex: Texture2D
var _star_tex: Texture2D
var _rod_bend := 0.0              # a spring: 0 straight, 1 bent under a fish, below 0 whipping back
var _rod_bend_v := 0.0
var _rod_pull := 0.0
var _line_tight := 0.0            # 0 slack .. 1 tight as a wire
var _tight_to := 0.0
var _dip := 0.0                   # the float: 0 afloat .. 1 gone under
var _dip_to := 0.0
var _catch: Dictionary = {}       # the catch under way, until the fish leaves the water
var _leapers: Array = []          # fish in the air
var _drops: Array = []            # water in the air
var _flashes: Array = []          # foam on the water where a fish came out
var _drop_col := Color.WHITE
var _shake := 0.0                 # the whole stage, after a big one
var _root_scale := 1.0
var _last_big_show := -100.0
var _leap_wait := 6.0             # until a fish jumps by itself, out on the water
# ---- the world: the time of day, wind and reflections (Settings: scenery effects)
## a whole day, in seconds of play. 0 is dawn: morning .. day .. dusk at 0.56 .. night from 0.62 to 0.9 .. dawn again
const DAY_LEN := 780.0
## biome: the light at dusk and at night [land, water]; light multiplies everything, so 1 is what the render shows.
## Space and the Abyss have no sun: they stay as they are, with their lights always on.
const DAYLIGHT := {
	"River": {"dusk": [Color(1.0, 0.78, 0.58), Color(1.0, 0.74, 0.6)], "night": [Color(0.38, 0.43, 0.7), Color(0.36, 0.45, 0.74)], "low": Color(1.0, 0.72, 0.42), "moon": Color(0.8, 0.88, 1.0)},
	"Ocean": {"dusk": [Color(1.0, 0.76, 0.58), Color(1.0, 0.72, 0.62)], "night": [Color(0.38, 0.43, 0.7), Color(0.34, 0.45, 0.76)], "low": Color(1.0, 0.7, 0.44), "moon": Color(0.8, 0.88, 1.0)},
	"Sky": {"dusk": [Color(1.0, 0.76, 0.78), Color(1.0, 0.7, 0.78)], "night": [Color(0.46, 0.44, 0.82), Color(0.48, 0.44, 0.88)], "low": Color(1.0, 0.68, 0.72), "moon": Color(0.86, 0.86, 1.0)},
	"Volcanic": {"dusk": [Color(0.9, 0.68, 0.6), Color(1.0, 0.96, 0.9)], "night": [Color(0.5, 0.38, 0.46), Color(1.0, 0.92, 0.84)], "low": Color(1.0, 0.76, 0.4), "moon": Color(1.0, 0.8, 0.5)},
	"Alien": {"dusk": [Color(0.9, 0.7, 0.96), Color(0.86, 0.8, 1.0)], "night": [Color(0.42, 0.34, 0.7), Color(0.4, 0.6, 0.76)], "low": Color(0.8, 1.0, 0.8), "moon": Color(0.7, 1.0, 0.9)},
}
const NIGHT_MUSIC := ["River", "Ocean", "Sky"]     # (elsewhere the biome keeps its own music at night)
signal night_changed(night: bool)
var day_t := 0.08                 # the time of day, 0..1 (starts in the morning)
var night_amount := 0.0           # 0 by day .. 1 at night (the lights come on)
var _is_night := false
var _fx_on := true
var _reflect_mat: ShaderMaterial
var lights_layer: Control
var _glow_tex: Texture2D
var _lights: Array = []
var _light_color := Color("#ffcf7a")
var _flies: Array = []
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
var _smoke: CPUParticles2D
var _glints: CPUParticles2D

# ---- sailing state (driven by vf_sail.gd; see the "sailing" section below)
signal scene_changed              # a new biome scene was set up (sea lanes need re-scanning)
signal boat_changed               # a different boat sprite (new hull)
signal cast_started
var boat_pos := Vector2(-1, -1)   # the boat's pivot point in scene px (moves when you sail)
var boat_yaw := 0.0               # where the bow points, in degrees: 0 right, 90 away from the camera, ±180 left, -90 toward it
var facing := 1.0                 # +1 the picture as it is, -1 mirrored (follows boat_yaw)
var boat_lean := 0.0              # how it leans into a turn
var boat_speed := 0.0             # scene px / s (the wake replaces the idle ripples while moving)
var reeled := false               # line reeled in while sailing: the bobber hangs at the rod tip
var _reel_t := -1.0
var _reel_from := Vector2.ZERO
var _home_ofs := Vector2(415, -161)   # authored bobber spot relative to the boat (from the manifest)

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
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/vf_backdrop.gdshader")
	backdrop.material = bm
	root.add_child(backdrop)
	life_layer = _layer(_draw_life)
	caustics = ColorRect.new()
	caustics.size = SCENE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vf_caustics.gdshader")
	mat.set_shader_parameter("noise", _tex("fx/noise.png"))
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
	boat_reflect = _reflect_rect()
	boat.add_child(boat_reflect)
	boat_foam = _foam_rect()
	boat.add_child(boat_foam)
	over = _layer(_draw_over)
	root.add_child(fx)
	sky_layer = _layer(_draw_sky)
	atmos = ColorRect.new()
	atmos.size = SCENE
	atmos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var am := ShaderMaterial.new()
	am.shader = load("res://shaders/vf_atmos.gdshader")
	am.set_shader_parameter("noise", _tex("fx/noise.png"))
	atmos.material = am
	root.add_child(atmos)
	_glow_tex = _tex("fx/glow.png")
	lights_layer = _layer(_draw_lights)
	var lm := CanvasItemMaterial.new()
	lm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lights_layer.material = lm
	for c in [root, backdrop, caustics, boat, fisher]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_merchant()
	_fisher_info = manifest.get("fisher", {})
	for k in _fisher_info:
		if _fisher_info[k] is Dictionary and _fisher_info[k].has("frames"):
			_fisher_tex[k] = _tex("fisher/%s.png" % k)
	_bobber_tex = _tex("fx/bobber.png")
	_star_tex = _tex(FX + "star_06.png")
	_glints = _particles("star_06", 8, 1.8, Color(1, 1, 1, 0.55), 0.03, 0.07)
	_glints.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_glints.emission_rect_extents = Vector2(SCENE.x * 0.5, SCENE.y * 0.27)     # (out on the water)
	_glints.position = Vector2(SCENE.x * 0.5, SCENE.y * 0.72)
	_glints.gravity = Vector2.ZERO
	_glints.initial_velocity_max = 0.0
	_glints.emitting = true
	resized.connect(_fit)
	_fit()

## The one way to make a water ring. Rings never start under a boat's hull (they used to sit
## on the boat like a bubble), and they are drawn on the water layer, below every boat.
func _add_ripple(pos: Vector2, max_r: float, width: float, t0 := 0.0) -> void:
	if _over_hull(pos, max_r): return
	_ripples.append({"pos": pos, "t": t0, "max": max_r, "w": width})

func _over_hull(pos: Vector2, max_r := 0.0) -> bool:
	if boat == null or boat.texture == null: return false
	var c := boat.position + boat.pivot_offset
	var half := boat.size * absf(boat.scale.y) * 0.5
	var d := (pos - c).abs()
	return d.x < half.x * 0.55 + max_r * 0.25 and d.y < half.y * 0.3 + max_r * 0.25

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
	_root_scale = maxf(size.x / SCENE.x, size.y / SCENE.y)
	_frame_root()

## where the scene sits in the window (it pushes in and shakes for a moment after a big catch)
func _frame_root() -> void:
	var s := _root_scale * (1.0 + 0.018 * _shake)
	root.scale = Vector2(s, s)
	root.position = (size - SCENE * s) * 0.5 + Vector2(sin(_t * 47.0), cos(_t * 39.0)) * 7.0 * _shake * _shake * _root_scale

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
	_add_ripple(best, 26.0, 2.0, 0.0)
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
	return to_screen(_bobber_home if reeled else _bobber)     # reeled in: where the next cast goes

func boat_screen() -> Vector2:
	return to_screen(boat.position + boat.pivot_offset)

# ------------------------------------------------------------------ the fleet
## The crews you hired (VF.crews) fish around your boat: the newest boats, up to FLEET_SHOWN, bobbing on
## open water (spots picked per biome, so they don't move around), each trip a little splash by one of them.
const FLEET_SHOWN := 6
var fleet_layer: Control
var _fleet: Array = []            # [{node, home, ph}]
var _fleet_n := 0

func set_fleet(n: int) -> void:
	_fleet_n = n
	_place_fleet()

func _place_fleet() -> void:
	if fleet_layer == null:
		fleet_layer = Control.new()
		fleet_layer.size = SCENE
		fleet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(fleet_layer)
		root.move_child(fleet_layer, boat.get_index())        # over the water, under your boat
	for f in _fleet: f.node.queue_free()
	_fleet.clear()
	if _fleet_n <= 0 or _scene.is_empty() or _mask == null: return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_biome + ":fleet")
	var spots := []
	for _i in 4000:
		if spots.size() >= mini(_fleet_n, FLEET_SHOWN): break
		var p := Vector2(rng.randf_range(240, SCENE.x - 300), rng.randf_range(150, SCENE.y - 180))   # (not in the sea lanes)
		if p.distance_to(boat_pos) < 340.0 or p.distance_to(_bobber_home) < 230.0 or not _in_water(p, 0.1): continue
		var ok := true
		for i in 8:
			if not _in_water(p + Vector2.from_angle(TAU * i / 8.0) * 95.0, 0.05): ok = false
		for q in spots:
			if p.distance_to(q) < 270.0: ok = false
		if ok: spots.append(p)
	for i in spots.size():
		var name: String = VFData.BOAT_ORDER[_fleet_n - 1 - i]       # the newest crews' boats
		var t := _tex("boats_top/%s.png" % VFData.slug(name))
		if t == null: continue
		var info: Dictionary = manifest.get("boats_top", {}).get(name, {"origin": [0.5, 0.6], "unit_px": 100.0})
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = t.get_size() * float(_scene.unit_px) / float(info.unit_px) * 0.8
		r.pivot_offset = Vector2(info.origin[0], info.origin[1]) * r.size
		r.flip_h = rng.randf() < 0.5
		fleet_layer.add_child(r)
		var mirror := _reflect_rect()
		r.add_child(mirror)
		_fit_reflect(mirror, name, info, r.size)
		mirror.flip_h = r.flip_h
		(mirror.material as ShaderMaterial).set_shader_parameter("seed", rng.randf() * 50.0)
		var foam := _foam_rect()
		r.add_child(foam)
		_fit_foam(foam, name, info, r.size)
		foam.flip_h = r.flip_h
		(foam.material as ShaderMaterial).set_shader_parameter("seed", rng.randf() * 50.0)
		_fleet.append({"node": r, "home": spots[i], "ph": rng.randf() * TAU})
	_fleet_tick()

func _fleet_tick() -> void:
	for f in _fleet:
		var n: TextureRect = f.node
		n.position = f.home - n.pivot_offset + Vector2(sin(_t * 0.45 + f.ph) * 7.0, sin(_t * 1.2 + f.ph) * 3.0)
		n.rotation = sin(_t * 0.8 + f.ph) * 0.03

## a crew trip came in: a little splash by one of the crew boats -> its screen position (INF if none shows)
func crew_splash() -> Vector2:
	if _fleet.is_empty(): return Vector2.INF
	var f: Dictionary = _fleet.pick_random()
	var at: Vector2 = f.home + Vector2(randf_range(-70.0, 70.0), randf_range(40.0, 80.0))
	_add_ripple(at, 34.0, 2.0)
	burst("splash", at)
	return to_screen(f.home)

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

var event_fx_id := ""
var _event_fx: Array = []

## the water during a 1.0 event (VFData.EVENTS): golden motes, fish dashing past, treasure glints, meteors,
## the boss's red bubbles. "" lets the current one fade out.
func set_event_fx(id: String) -> void:
	event_fx_id = id
	for p in _event_fx:
		if is_instance_valid(p):
			p.emitting = false
			get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)
	_event_fx.clear()
	match id:
		"golden_hour":
			var p := _event_area("star_06", 46, 4.0, Color(1.0, 0.8, 0.3, 0.85), 0.04, 0.1)
			p.gravity = Vector2(0, -30)
		"frenzy":
			var p := _event_area("trace_02", 16, 0.9, Color(0.5, 1.0, 0.95, 0.55), 0.22, 0.4)
			p.direction = Vector2(1, 0.15)
			p.spread = 12.0
			p.initial_velocity_min = 380.0
			p.initial_velocity_max = 640.0
			p.particle_flag_align_y = true
		"treasure_tide":
			var p := _event_area("twirl_02", 18, 3.0, Color(0.8, 0.5, 1.0, 0.7), 0.08, 0.16)
			p.angular_velocity_min = 60.0
			p.angular_velocity_max = 160.0
			_event_area("star_04", 24, 2.0, Color(1.0, 0.85, 0.4, 0.9), 0.05, 0.1)
		"meteor_shower":
			var p := _event_area("trace_02", 7, 1.3, Color(0.78, 0.78, 1.0, 0.95), 0.35, 0.6)
			p.direction = Vector2(-0.55, 1.0)
			p.spread = 4.0
			p.initial_velocity_min = 900.0
			p.initial_velocity_max = 1300.0
			p.particle_flag_align_y = true
			_event_area("star_06", 30, 2.5, Color(0.7, 0.75, 1.0, 0.8), 0.03, 0.07)
		"boss":
			var p := _event_area("circle_05", 30, 4.5, Color(0.55, 0.05, 0.12, 0.45), 0.03, 0.08)
			p.gravity = Vector2(0, -25)
			(p.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_MIX

func _event_area(texname: String, amount: int, life: float, col: Color, s0: float, s1: float) -> CPUParticles2D:
	var p := _particles(texname, amount, life, col, s0, s1)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = SCENE * 0.5
	p.position = SCENE * 0.5
	p.spread = 180.0
	p.initial_velocity_max = 20.0
	p.preprocess = life
	p.emitting = true
	_event_fx.append(p)
	return p

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
	(caustics.material as ShaderMaterial).set_shader_parameter("gain", ATMOS.get(name, [1.0, 0.0])[0])
	(caustics.material as ShaderMaterial).set_shader_parameter("reflection", _tex("scenes/%s_reflect.png" % slug))
	(backdrop.material as ShaderMaterial).set_shader_parameter("sway", _tex("scenes/%s_sway.png" % slug))
	(atmos.material as ShaderMaterial).set_shader_parameter("mask", mt)
	_set_lights()
	_apply_daylight()
	_bobber_home = Vector2(_scene.bobber[0], _scene.bobber[1]) * SCENE
	_bobber = _bobber_home
	aim = Vector2.INF
	boat_pos = Vector2(_scene.boat[0], _scene.boat[1]) * SCENE
	_home_ofs = _bobber_home - boat_pos
	boat_yaw = 0.0
	facing = 1.0
	boat_lean = 0.0
	_hulls.clear()
	reeled = false
	_reel_t = -1.0
	_catch = {}
	_dart = {}
	_leapers.clear()
	_drops.clear()
	_flashes.clear()
	_rod_pull = 0.0
	_tight_to = 0.0
	_dip_to = 0.0
	_drop_col = Color(_scene.water[0]).lerp(Color.WHITE, 0.6)
	_species.clear()
	for f in VFData.BIOMES[name].fish:
		_species.append(_species_entry(f))
	_spawn_life()
	_set_ambient(name)
	_place_boat()
	_place_merchant()
	_place_fleet()
	scene_changed.emit()

## a swimming fish's sheet (tools/blender/vf_life.py), or no texture for what has none (it just doesn't swim about)
func _species_entry(f: String) -> Dictionary:
	var life: Dictionary = manifest.get("life", {})
	if not life.get("fish", {}).has(f): return {"tex": null}
	return {"tex": _tex("life/%s.png" % VFData.slug(f)), "frames": int(life.frames), "cell": float(life.cell), "rows": int(life.rows), "unit_px": float(life.fish[f])}

func set_boat(name: String) -> void:
	if name == _boat: return
	_boat = name
	var sl := VFData.slug(name)
	_boat_info = manifest.get("boats_top", {}).get(name, {"deck": [0.6, 0.5], "origin": [0.5, 0.6], "unit_px": 100.0, "fisher_scale": 1.0})
	_side_tex = _tex("boats_top/%s.png" % sl)
	_turn = _boat_info.get("turn", {})
	_turn_atlas.atlas = _tex("boats_turn/%s.png" % sl) if not _turn.is_empty() else null
	if _turn_atlas.atlas == null: _turn = {}
	# (all of it stays loaded: a boat turning must not wait for the disk)
	_turn_keep = [_side_tex, _tex("boats_foam/%s.png" % sl), _tex("boats_reflect/%s.png" % sl), _tex("boats_turn/%s_foam.png" % sl), _tex("boats_turn/%s_reflect.png" % sl)]
	_hulls.clear()
	_turn_frame = 0
	_place_boat()
	boat_changed.emit()

## which of the turning sheet's pictures the heading calls for: -6 .. 6, each 15 degrees, 0 the plain side view.
## The other half of the circle is the same pictures mirrored (they meet bow-on and stern-on, where a boat looks the same).
func _show_heading() -> void:
	var y := wrapf(boat_yaw, -180.0, 180.0)
	var mirror := absf(y) > 90.0
	facing = -1.0 if mirror else 1.0
	var fr := 0
	if not _turn.is_empty():
		fr = int(round((signf(y) * 180.0 - y if mirror else y) / float(_turn.step)))
	if fr != _turn_frame:
		_turn_frame = fr
		_place_boat()

## a picture's place on a turning sheet (they all share one layout), as 0..1 of the sheet
func _turn_region(fr: int) -> Rect2:
	var i := fr + 6 if fr < 0 else fr + 5
	var cols := int(_turn.cols)
	var rows := ceili(12.0 / cols)
	return Rect2(float(i % cols) / cols, float(i / cols) / rows, 1.0 / cols, 1.0 / rows)

## the hull as an ellipse around the pivot, in the given picture, seen as if not mirrored: {"c": centre, "r": radii}
func boat_hull(fr := 99) -> Dictionary:
	if fr == 99: fr = _turn_frame
	if _hulls.has(fr): return _hulls[fr]
	var h := {"c": Vector2.ZERO, "r": Vector2(80, 45)}
	if _scene.is_empty(): return h
	if fr != 0 and not _turn.is_empty():
		var k: float = float(_scene.unit_px) / float(_turn.unit_px) * float(_turn.cell)
		var q: Array = _turn.rects[fr + 6 if fr < 0 else fr + 5]
		var rect := Rect2(Vector2(q[0], q[1]) * k, Vector2(q[2] - q[0], q[3] - q[1]) * k)
		h = {"c": rect.get_center() - Vector2(_turn.origin[0], _turn.origin[1]) * k, "r": rect.size * 0.5 * Vector2(0.9, 0.78)}
	elif _side_tex != null:
		var used := Rect2(Vector2.ZERO, _side_tex.get_size())
		var img := _side_tex.get_image()
		if img:
			if img.is_compressed(): img.decompress()
			var u := img.get_used_rect()
			if u.size.x > 4: used = Rect2(u)
		var k: float = float(_scene.unit_px) / float(_boat_info.unit_px)
		var rect := Rect2(used.position * k, used.size * k)
		h = {"c": rect.get_center() - Vector2(_boat_info.origin[0], _boat_info.origin[1]) * _side_tex.get_size() * k, "r": rect.size * 0.5 * Vector2(0.9, 0.78)}
	_hulls[fr] = h
	return h

## the hull's foam: an image of its blurred footprint (see render_foam in vf_topdown.py), drawn by vf_foam.gdshader
func _foam_rect() -> TextureRect:
	var f := TextureRect.new()
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_SCALE
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.show_behind_parent = true
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/vf_foam.gdshader")
	f.material = m
	return f

func _reflect_rect() -> TextureRect:
	var f := TextureRect.new()
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_SCALE
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.show_behind_parent = true
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/vf_reflect.gdshader")
	f.material = m
	return f

func _fit_reflect(f: TextureRect, boat_name: String, info: Dictionary, sprite_size: Vector2, fr := 0) -> void:
	var r := _turn_region(fr) if fr != 0 else Rect2(0, 0, 1, 1)
	f.texture = _tex(("boats_turn/%s_reflect.png" if fr != 0 else "boats_reflect/%s.png") % VFData.slug(boat_name))
	f.size = sprite_size * float(info.get("reflect_pad", 2.2))
	f.position = (sprite_size - f.size) * 0.5
	var m := f.material as ShaderMaterial
	m.set_shader_parameter("region", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	if not _scene.is_empty(): m.set_shader_parameter("water", Color(_scene.water[1]))
	f.visible = _fx_on and not info.get("floats", false)

func _fit_foam(f: TextureRect, boat_name: String, info: Dictionary, sprite_size: Vector2, fr := 0) -> void:
	var r := _turn_region(fr) if fr != 0 else Rect2(0, 0, 1, 1)
	f.texture = _tex(("boats_turn/%s_foam.png" if fr != 0 else "boats_foam/%s.png") % VFData.slug(boat_name))
	f.size = sprite_size * float(info.get("foam_pad", 1.5))
	f.position = (sprite_size - f.size) * 0.5
	var m := f.material as ShaderMaterial
	m.set_shader_parameter("region", Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	m.set_shader_parameter("foam_amount", 0.0 if info.get("floats", false) else 1.0)
	if not _scene.is_empty():
		m.set_shader_parameter("foam_color", Color(_scene.water[0]).lerp(Color.WHITE, 0.75))
		m.set_shader_parameter("shade_color", Color(_scene.water[1]).darkened(0.65))

func _place_boat() -> void:
	if _scene.is_empty() or _boat_info.is_empty() or _side_tex == null: return
	var fr := _turn_frame if not _turn.is_empty() else 0
	var k: float = float(_scene.unit_px) / float(_boat_info.unit_px)
	var side_size := _side_tex.get_size() * k
	_side_pivot = Vector2(_boat_info.origin[0], _boat_info.origin[1]) * side_size
	if fr == 0:
		boat.texture = _side_tex
		boat.size = side_size
		boat.pivot_offset = _side_pivot
		_fit_foam(boat_foam, _boat, _boat_info, boat.size)
		_fit_reflect(boat_reflect, _boat, _boat_info, boat.size)
	else:
		# another angle: the captain is part of the picture, the sprite takes over again in the side view
		var cell := float(_turn.cell)
		var at := _turn_region(fr)
		var tk: float = float(_scene.unit_px) / float(_turn.unit_px)
		_turn_atlas.region = Rect2(at.position * _turn_atlas.atlas.get_size(), Vector2(cell, cell))
		boat.texture = _turn_atlas
		boat.size = Vector2(cell, cell) * tk
		boat.pivot_offset = Vector2(_turn.origin[0], _turn.origin[1]) * boat.size
		_fit_foam(boat_foam, _boat, _turn, boat.size, fr)
		_fit_reflect(boat_reflect, _boat, _turn, boat.size, fr)
	if boat_pos.x < 0.0: boat_pos = Vector2(_scene.boat[0], _scene.boat[1]) * SCENE
	boat.position = boat_pos - boat.pivot_offset
	fisher.visible = fr == 0
	# fisher: his anchor (where he sits) on the boat's seat point, scaled to scene units.
	# He is a child of the boat, so he mirrors with it when the boat turns around.
	if _fisher_info.is_empty(): return
	var cell: float = _fisher_info.cell
	var fk: float = float(_scene.unit_px) / float(_fisher_info.unit_px)
	fisher.size = Vector2(cell, cell) * fk
	var seat: Array = _boat_info.get("seat", _boat_info.deck)
	fisher.position = Vector2(seat[0], seat[1]) * side_size - Vector2(_fisher_info.feet[0], _fisher_info.feet[1]) * fisher.size
	_set_frame()

func _frames(anim: String) -> int:
	return int(_fisher_info.get(anim, {}).get("frames", 1))

func _fps(anim: String) -> float:
	return float(_fisher_info.get(anim, {}).get("fps", 7.0 if anim == "idle" else 18.0))

## one-shot length in seconds (a "loop_range" is held for "hold" seconds, e.g. the doze)
func _anim_len(anim: String) -> float:
	var e: Dictionary = _fisher_info.get(anim, {})
	var n := _frames(anim)
	if e.has("loop_range"): return n / _fps(anim) + float(e.hold)
	return n / _fps(anim)

func _frame_index() -> int:
	var n := _frames(_anim)
	var fps := _fps(_anim)
	var e: Dictionary = _fisher_info.get(_anim, {})
	var i := int(_anim_t * fps)
	if _anim == "idle" or e.get("loop", false): return i % n
	if e.has("loop_range"):
		var a: int = e.loop_range[0]
		var b: int = e.loop_range[1]
		if i < a: return i
		var t2 := _anim_t - a / fps
		if t2 < float(e.hold): return a + int(t2 * fps) % (b - a + 1)
		return mini(b + 1 + int((t2 - float(e.hold)) * fps), n - 1)
	return mini(i, n - 1)

func _standing(anim: String) -> bool:
	return anim in _fisher_info.get("standing", ["cast", "reel"])

## what follows a finished one-shot: a queued reaction, then sitting back down, then idle
func _next_anim() -> void:
	if _standing(_anim):
		if _react != "" and _fisher_tex.has(_react):
			var r := _react
			_react = ""
			play_anim(r)
		else:
			play_anim("sit" if _anim in _fisher_info.get("up", []) and _fisher_tex.has("sit") else "idle")   # (he got up to cheer)
	else:
		play_anim("idle")

## idle gags every few seconds; waves when a gull flies by
func _pick_idle() -> void:
	var gags: Array = []
	for g in _fisher_info.get("idles", []):
		if _fisher_tex.has(g) and g != "wave": gags.append(g)
	if gags.is_empty(): return
	var here := boat.position + boat.pivot_offset
	var pick: String = gags.pick_random()
	if _fisher_tex.has("wave"):
		for g in _gulls:
			if (g.pos as Vector2).distance_to(here) < 420.0:
				pick = "wave"
				break
	play_anim(pick)

## the catch decides his mood: dance for a new species, fist pump for a big catch (chest, pet,
## lucky splash, the biome's top fish or a special one), facepalm / shrug when the line comes up empty
func react_trip(res: Dictionary) -> void:
	var fish: Dictionary = res.get("fish", {})
	var kind := ""
	if fish.is_empty() and res.get("chest", {}).is_empty() and String(res.get("pet", "")) == "":
		kind = ["sad", "shrug"].pick_random()
	elif not res.get("new_species", []).is_empty():
		kind = "dance"
	elif not res.get("chest", {}).is_empty() or String(res.get("pet", "")) != "" or int(res.get("lucky", 0)) > 0:
		kind = "happy"
	elif _t - _last_cheer > 25.0:
		var tiers: Array = VFData.BIOMES.get(_biome, {}).get("fish", [])
		for f in fish:
			var i := tiers.find(f)
			if i < 0 or i == tiers.size() - 1: kind = "happy"
	if kind == "happy" or kind == "dance": _last_cheer = _t
	react(kind)

func react(kind: String) -> void:
	if kind == "" or not _fisher_tex.has(kind): return
	if _standing(_anim): _react = kind      # after the cast / reel finishes
	else: play_anim(kind)

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
	# same order as the Control transform: scale (incl. the mirror when facing left), then rotate
	return boat.position + boat.pivot_offset + ((local - _side_pivot) * boat.scale).rotated(boat.rotation)

func rod_grip() -> Vector2:
	return _fisher_point("rod_grip", [0.45, 0.6])

func play_anim(a: String) -> void:
	if not _fisher_tex.has(a): a = "idle"
	var from_standing := _standing(_anim) and _anim != "cast"
	_anim = a
	_anim_t = 0.0
	if a == "cast":
		_react = ""
		if from_standing: _anim_t = 2.0 / _fps("cast")     # already up: skip getting off the cooler
	if a == "idle": _idle_wait = randf_range(4.0, 9.0)

func rod_tip() -> Vector2:
	if _fisher_info.is_empty() or _boat_info.is_empty(): return _bobber_home
	var g := rod_grip()
	var t: Vector2 = _fisher_point("rod_tip", [0.6, 0.45])
	return t + _rod_side(g, t) * _rod_bend * ROD_BEND * (t - g).length()

# ------------------------------------------------------------------ life
func _mask_px(p: Vector2) -> Color:
	if _mask == null: return Color(1, 0.5, 0, 1)
	return _mask.get_pixel(clampi(int(p.x / SCENE.x * _mask.get_width()), 0, _mask.get_width() - 1),
		clampi(int(p.y / SCENE.y * _mask.get_height()), 0, _mask.get_height() - 1))

func _in_water(p: Vector2, min_depth := 0.12) -> bool:
	var c := _mask_px(p)
	return c.a > 0.5 and c.g >= min_depth

func _open_water(p: Vector2) -> bool:
	if not _in_water(p, 0.2): return false
	for d in [Vector2(90, 0), Vector2(-90, 0), Vector2(0, 70), Vector2(0, -70)]:      # room for a whole fish
		if _mask_px(p + d).a < 0.5: return false
	return true

func _on_beach(p: Vector2) -> bool:
	if _shop_rect().grow(100.0).has_point(p) or _mask_px(p + Vector2(0, 60)).a < 0.5: return false
	# all along the crab's walk: sand under it, sand behind it and water in front (the dock and the rowboat have boards in front)
	for x in [-110.0, -55.0, 0.0, 55.0, 110.0]:
		if _mask_px(p + Vector2(x, 0)).a > 0.3 or _mask_px(p + Vector2(x, -90)).a > 0.3 or _mask_px(p + Vector2(x, 130)).a < 0.5: return false
	return true

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
			var p = _rand_point(_open_water)
			if p == null: break
			var sp: Dictionary = _species[randi() % _species.size()]
			var a := randf() * TAU
			_fish.append({"pos": p, "vel": Vector2.from_angle(a) * 40.0, "ang": a, "speed": randf_range(25, 55),
				"target": p, "sp": sp, "size": randf_range(0.6, 1.0), "wig": randf() * TAU})
	var bigs := {"Ocean": ["whale", "manta"], "Abyss": ["manta"], "Space": ["whale"], "Sky": ["manta"]}
	for kind in bigs.get(_biome, []):
		var t := _tex("life/%s.png" % kind)
		if t: _big.append({"tex": t, "kind": kind, "pos": Vector2(-400, SCENE.y * randf_range(0.6, 0.9)), "wait": randf_range(4, 14), "vel": Vector2(40, -6)})
	if _biome in ["River", "Ocean", "Volcanic", "Sky"]:
		var g := _tex("life/gull.png")
		for i in 3:
			var ang := randf_range(-0.4, 0.4) + (PI if randf() < 0.5 else 0.0)
			_gulls.append({"tex": g, "pos": Vector2(randf() * SCENE.x, randf_range(0.05, 0.6) * SCENE.y), "ang": ang,
				"turn": 0.0, "speed": randf_range(95, 135), "ph": randf() * TAU, "glide": 0.0, "fr": 0.0})
	if _biome in ["River", "Ocean"]:
		var c := _tex("life/crab.png")
		for i in 3:
			var p = _rand_point(func(q): return _on_beach(q) and _crabs.all(func(o): return o.home.distance_to(q) > 360.0))
			if p != null: _crabs.append({"tex": c, "pos": p, "home": p, "ph": randf() * TAU, "dir": 1.0, "wait": randf() * 2.0, "x": 0.0, "tilt": 0.0})

func _process(delta: float) -> void:
	_t += delta
	_anim_t += delta
	if _anim == "idle":
		_idle_wait -= delta
		if _idle_wait <= 0.0:
			_idle_wait = randf_range(4.0, 9.0)
			_pick_idle()
	elif _anim_t > _anim_len(_anim) + (0.25 if _anim in ["cast", "reel"] else 0.08):
		_next_anim()
	_set_frame()
	_tick_merchant(delta)
	_fleet_tick()
	for f in _fish:
		# wander toward a target in deep enough water; turn at a limited rate
		if f.pos.distance_to(f.target) < 40.0 or not _in_water(f.target, 0.18):
			for _i in 12:
				var cand: Vector2 = f.pos + Vector2.from_angle(randf() * TAU) * randf_range(150, 420)
				if _open_water(cand) and _in_water((f.pos + cand) * 0.5, 0.12):
					f.target = cand
					break
			f.speed = randf_range(22, 60)
		if not _in_water(f.pos + Vector2.from_angle(f.ang) * 120.0, 0.12):      # the shore, the dock or a rowboat ahead
			f.target = f.pos.lerp(Vector2(SCENE.x * 0.5, SCENE.y * 0.85), 0.5)
		var want_ang: float = (f.target - f.pos).angle()
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
	_show_heading()
	boat.position = boat_pos - boat.pivot_offset
	boat.rotation = sin(_t * 1.1) * 0.025 + boat_lean
	var bob := 1.0 + sin(_t * 1.6) * 0.008
	boat.scale = Vector2(bob * facing, bob)
	if randf() < delta * 0.6 and _cast_t < 0.0 and not reeled and _reel_t < 0.0:
		_add_ripple(_bobber, 34.0, 1.5, 0.0)
	_tick_reel(delta)
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
		_dart.t += delta / CATCH_BITE
		_dart.pos = (_dart.from as Vector2).lerp(_bobber, minf(_dart.t, 1.0))
		if _dart.t >= 1.0:
			_dart = {}
	_tick_catch(delta)
	_tick_daylight(delta)
	_leap_wait -= delta
	if _leap_wait <= 0.0:
		_leap_wait = randf_range(8.0, 20.0)
		_wild_leap()
	for r in _ripples: r.t += delta
	_ripples = _ripples.filter(func(r): return r.t < 1.4)
	life_layer.queue_redraw()
	sky_layer.queue_redraw()
	over.queue_redraw()

## One creature from a sheet of tools/blender/vf_life.py. Its rows are headings on the water, seen from the game's camera:
## toward the camera .. right .. away from it. The other side is the same sheet mirrored, and a small turn of the sprite
## makes up the rest of the way. ang: where it's going on screen. scale_px: scene px per model unit. frame: -1 runs the cycle.
func _life_draw(layer: Control, sp: Dictionary, p: Vector2, ang: float, scale_px: float, col: Color, phase := 0.0, frame := -1) -> void:
	var t: Texture2D = sp.tex
	if t == null: return
	var cell: float = sp.cell
	var flip := cos(ang) < 0.0
	var side := atan2(sin(ang), absf(cos(ang)))              # the way it goes, folded onto the right-hand side
	var row := 0
	var rest := side
	if int(sp.rows) > 1:
		var on_water := rad_to_deg(atan2(-sin(side) / 0.82, cos(side)))    # (the view squeezes depth)
		row = clampi(int(round((on_water + 90.0) / 45.0)), 0, int(sp.rows) - 1)
		var th := deg_to_rad(-90.0 + row * 45.0)
		rest = side - atan2(-sin(th) * 0.82, cos(th))
	var fi := frame if frame >= 0 else int(_t * 11.0 + phase * 3.0) % int(sp.frames)
	var sc: float = scale_px / float(sp.unit_px)
	layer.draw_set_transform(p, -rest if flip else rest, Vector2(-sc if flip else sc, sc))
	layer.draw_texture_rect_region(t, Rect2(-cell * 0.5, -cell * 0.5, cell, cell), Rect2(fi * cell, row * cell, cell, cell), col)

func _draw_life() -> void:
	var u: float = float(_scene.get("unit_px", 56.0))
	for b in _big:
		if b.wait > 0.0: continue
		var len_px := u * (11.0 if b.kind == "whale" else 7.0)
		var big_info: Dictionary = manifest.get("life", {}).get("big", {"cell": 192, "frames": 8})
		var sp := {"tex": b.tex, "frames": big_info.frames, "cell": float(big_info.cell), "rows": 1, "unit_px": float(big_info.cell)}
		_life_draw(life_layer, sp, b.pos + Vector2(30, 40), b.vel.angle(), len_px, Color(0, 0.05, 0.1, 0.12))
		_life_draw(life_layer, sp, b.pos, b.vel.angle(), len_px, Color(water_tint.r, water_tint.g, water_tint.b, 0.35).lerp(Color(1, 1, 1, 0.35), 0.3))
	for f in _fish:
		var depth := _mask_px(f.pos).g
		var fish_px: float = u * 0.8 * f.size
		_life_draw(life_layer, f.sp, f.pos + Vector2(10, 14) * (0.5 + depth), f.vel.angle(), fish_px, Color(0, 0.05, 0.1, 0.11), f.wig)
		var a := clampf(1.0 - depth * 0.35, 0.55, 1.0)
		_life_draw(life_layer, f.sp, f.pos, f.vel.angle(), fish_px, Color(1, 1, 1, a).lerp(Color(water_tint.r, water_tint.g, water_tint.b, a), 0.08 + depth * 0.2), f.wig)
	if not _dart.is_empty():
		_life_draw(life_layer, _dart.sp, _dart.pos, ((_bobber - (_dart.from as Vector2))).angle(), u * 1.0, Color(1, 1, 1, 0.95))
	var crab_info: Dictionary = manifest.get("life", {}).get("crab", {})
	for c in _crabs:
		var ct: Texture2D = c.tex
		if ct == null or crab_info.is_empty(): continue
		var cell: float = crab_info.cell
		var cs: float = u * 0.42 / float(crab_info.unit_px)
		var walking: bool = c.wait <= 0.0
		var src := Rect2(int(c.ph * (13.0 if walking else 4.0)) % int(crab_info.frames) * cell, 0.0 if walking else cell, cell, cell)
		var dst := Rect2(-cell * 0.5, -cell * 0.5, cell, cell)
		life_layer.draw_set_transform(c.pos + Vector2(4, 7), 0.0, Vector2(cs, cs * 0.8))
		life_layer.draw_texture_rect_region(ct, dst, src, Color(0, 0, 0, 0.2))
		life_layer.draw_set_transform(c.pos, 0.0, Vector2(cs, cs))
		life_layer.draw_texture_rect_region(ct, dst, src)
	life_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for f in _flashes:                       # foam where a fish came out
		life_layer.draw_set_transform(f.p, 0.0, Vector2(1.0, 0.5))
		life_layer.draw_circle(Vector2.ZERO, f.r * (0.45 + 0.55 * f.t), Color(1, 1, 1, (1.0 - f.t) * (1.0 - f.t) * 0.85))
	life_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for r in _ripples:                       # water rings live under the boats
		if r.t < 0.0: continue
		var k: float = r.t / 1.4
		life_layer.draw_arc(r.pos, 6.0 + k * r.max, 0, TAU, 40, Color(1, 1, 1, (1.0 - k) * 0.55), r.w, true)

func _draw_sky() -> void:
	var u: float = float(_scene.get("unit_px", 56.0))
	var info: Dictionary = manifest.get("life", {}).get("gull", {})
	if info.is_empty(): return
	for g in _gulls:
		var t: Texture2D = g.tex
		if t == null or night_amount > 0.6: continue
		var sp := {"tex": t, "frames": info.frames, "cell": float(info.cell), "rows": 5, "unit_px": float(info.unit_px)}
		var fi: int = int(info.glide) if g.glide > 0.0 else int(g.fr) % int(info.frames)     # wings out to glide
		_life_draw(sky_layer, sp, g.pos + Vector2(90, 150), g.ang, u * 0.62, Color(0, 0.05, 0.1, 0.14), 0.0, fi)
		_life_draw(sky_layer, sp, g.pos, g.ang, u * 0.62, Color.WHITE, 0.0, fi)
	sky_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_rod() -> void:
	if _rod_tex == null or _fisher_info.is_empty(): return
	var g := rod_grip()
	var t: Vector2 = _fisher_point("rod_tip", [0.6, 0.45])       # where it points, not bent
	var sz := _rod_tex.get_size()
	var gs := Vector2(_rod_info.grip[0], _rod_info.grip[1]) * sz
	var ts := Vector2(_rod_info.tip[0], _rod_info.tip[1]) * sz
	var k := (t - g).length() / maxf(1.0, (ts - gs).length())
	var bend := _rod_side(g, t) * _rod_bend * ROD_BEND * (t - g).length()
	var top := -gs.y * k
	var bottom := (sz.y - gs.y) * k
	var n_seg := 12
	var white := PackedColorArray([Color.WHITE])
	for i in n_seg:
		var u0 := float(i) / n_seg
		var u1 := float(i + 1) / n_seg
		var s0 := (u0 * sz.x - gs.x) / (ts.x - gs.x)
		var s1 := (u1 * sz.x - gs.x) / (ts.x - gs.x)
		var p0 := g + (t - g) * s0 + bend * maxf(s0, 0.0) * maxf(s0, 0.0)
		var p1 := g + (t - g) * s1 + bend * maxf(s1, 0.0) * maxf(s1, 0.0)
		var n0 := ((t - g) + bend * 2.0 * maxf(s0, 0.0)).normalized().rotated(PI * 0.5)
		var n1 := ((t - g) + bend * 2.0 * maxf(s1, 0.0)).normalized().rotated(PI * 0.5)
		over.draw_polygon(PackedVector2Array([p0 + n0 * top, p1 + n1 * top, p1 + n1 * bottom, p0 + n0 * bottom]), white,
			PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]), _rod_tex)

## the way the rod bends under a fish: down, whichever way he's facing
func _rod_side(g: Vector2, t: Vector2) -> Vector2:
	var n := (t - g).orthogonal().normalized()
	return n if n.y > 0.0 else -n

func _draw_over() -> void:
	if _turn_frame != 0:            # under way at an angle: the rod is stowed
		_draw_catch()
		return
	_draw_rod()
	_draw_zzz()
	var tip := rod_tip()
	var mid := (tip + _bobber) * 0.5 + Vector2(0, lerpf(30.0, 0.0, _line_tight) if _cast_t < 0.0 else 0.0)
	var buzz := (_bobber - tip).orthogonal().normalized() * sin(_t * 70.0) * 2.4 * _line_tight * _line_tight   # a tight line hums
	var pts := PackedVector2Array()
	for i in 17:
		var k := i / 16.0
		pts.append(tip.lerp(mid, k).lerp(mid.lerp(_bobber, k), k) + buzz * sin(k * PI))
	over.draw_polyline(pts, Color(0.95, 0.95, 0.9, 0.8 + 0.2 * _line_tight), 1.6, true)
	_draw_float()
	_draw_catch()

## "Zzz" floating up from his hat while he naps (drawn here so it never mirrors)
func _draw_zzz() -> void:
	var e: Dictionary = _fisher_info.get("doze", {})
	if _anim != "doze" or not e.has("loop_range") or _frame_index() < int(e.loop_range[0]): return
	var t2 := _anim_t - float(e.loop_range[0]) / _fps("doze")
	if t2 > float(e.hold): return
	var head := _fisher_point("head", [0.5, 0.2])
	var px := fisher.size.y * absf(boat.scale.y)
	var font := over.get_theme_default_font()
	for k in 3:
		var ph := fmod(t2 * 0.9 + k / 3.0, 1.0)
		var sz := int(px * (0.13 + 0.09 * ph))
		var p := head + Vector2(px * (0.04 + 0.16 * ph) + sin(ph * 6.0 + k) * px * 0.03, -px * (0.05 + 0.3 * ph))
		var a := minf(1.0, ph * 5.0) * minf(1.0, (1.0 - ph) * 2.5)
		over.draw_string_outline(font, p, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, sz, maxi(2, sz / 6), Color(0.15, 0.2, 0.3, a))
		over.draw_string(font, p, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(1, 1, 1, a))

# ----------------------------------------------------------------- actions
func cast(done: Callable) -> void:
	if not _catch.is_empty(): _burst()           # (casting again already: the fish comes up right now)
	play_anim("cast")
	if aim != Vector2.INF:
		_cast_to = aim + Vector2(randf_range(-6, 6), randf_range(-4, 4))    # right where you tapped
	else:
		_cast_to = _bobber_home + Vector2(randf_range(-90, 90), randf_range(-50, 50))
	if not open_water(_cast_to): _cast_to = aim if aim != Vector2.INF else _bobber_home
	_cast_done = done
	cast_started.emit()
	# release the bobber mid-swing
	get_tree().create_timer(float(_fisher_info.get("cast", {}).get("release", 0.22))).timeout.connect(func():
		_cast_from = rod_tip()
		_rod_bend_v += 6.0                        # the rod whips forward
		reeled = false
		_reel_t = -1.0
		_cast_t = 0.0)

func splash(at: Vector2, big := 1.0) -> void:
	for i in 3:
		_add_ripple(at, 50.0 * big, 2.5, -i * 0.15)

# ------------------------------------------------------------ the time of day
## how far into the night (0..1) and how close to sunset or sunrise (0..1) a time of day is
func _day_phase(d: float) -> Vector2:
	var night := smoothstep(0.56, 0.64, d) * (1.0 - smoothstep(0.9, 0.98, d))
	var low := 1.0 - minf(minf(absf(d - 0.56), absf(d - 0.94)), absf(d + 0.06)) / 0.07
	return Vector2(night, clampf(low, 0.0, 1.0))

func _tick_daylight(delta: float) -> void:
	if AudioManager.scenery_fx != _fx_on:
		_fx_on = AudioManager.scenery_fx
		_apply_daylight()
		_place_boat()
		_place_fleet()
	if not _fx_on or not DAYLIGHT.has(_biome):
		lights_layer.queue_redraw()
		return
	day_t = fmod(day_t + delta / DAY_LEN, 1.0)
	_apply_daylight()
	lights_layer.queue_redraw()

## the shaders' light for this time of day
func _apply_daylight() -> void:
	var water_mat := caustics.material as ShaderMaterial
	var air := atmos.material as ShaderMaterial
	var sky: Dictionary = DAYLIGHT.get(_biome, {})
	var clouds: float = ATMOS.get(_biome, [1.0, 0.0])[1]
	water_mat.set_shader_parameter("mirror", 0.42 if _fx_on else 0.0)
	(backdrop.material as ShaderMaterial).set_shader_parameter("wind", 1.0 if _fx_on else 0.0)
	atmos.visible = _fx_on
	if not _fx_on or sky.is_empty():
		night_amount = 1.0 if sky.is_empty() and _biome != "" else 0.0
		air.set_shader_parameter("land", Color.WHITE)
		air.set_shader_parameter("water", Color.WHITE)
		air.set_shader_parameter("clouds", clouds if _fx_on else 0.0)
		water_mat.set_shader_parameter("glint", Color.WHITE)
		water_mat.set_shader_parameter("sun_at", Vector2(0.7, 0.6))
		water_mat.set_shader_parameter("sun_glow", 0.0)
		water_mat.set_shader_parameter("stars", 1.0 if sky.is_empty() and _fx_on else 0.0)
		_note_night(false)
		return
	var ph := _day_phase(day_t)
	night_amount = ph.x
	var land := Color.WHITE.lerp(sky.dusk[0], ph.y).lerp(sky.night[0], ph.x)
	var water := Color.WHITE.lerp(sky.dusk[1], ph.y).lerp(sky.night[1], ph.x)
	air.set_shader_parameter("land", land)
	air.set_shader_parameter("water", water)
	air.set_shader_parameter("clouds", clouds * (1.0 - ph.x) * (1.0 - 0.5 * ph.y))
	# the sun climbs and sets over the water to the right, the moon hangs further along
	var sun_x := 0.7 + 0.08 * ph.y
	var sun_y := 0.6 - 0.16 * ph.y
	water_mat.set_shader_parameter("sun_at", Vector2(sun_x, sun_y).lerp(Vector2(0.62, 0.42), ph.x))
	water_mat.set_shader_parameter("glint", Color.WHITE.lerp(sky.low, ph.y).lerp(sky.moon, ph.x))
	water_mat.set_shader_parameter("sun_glow", 0.38 * ph.y + 0.1 * ph.x)
	water_mat.set_shader_parameter("stars", ph.x)
	_note_night(ph.x > 0.5)

func _note_night(on: bool) -> void:
	if on == _is_night: return
	_is_night = on
	night_changed.emit(on)

## music for the place and the hour
func night_music() -> bool:
	return _is_night and _biome in NIGHT_MUSIC

## the time of day, for captures: 0.3 midday, 0.57 sunset, 0.75 night
func set_time_of_day(d: float) -> void:
	day_t = d
	_apply_daylight()

func _set_lights() -> void:
	_lights = _scene.get("lights", [])
	_light_color = Color(_scene.get("light_color", "#ffcf7a"))
	_flies.clear()
	if _biome in ["River", "Ocean", "Alien", "Sky"]:
		var col := Color(0.75, 1.0, 0.45) if _biome != "Alien" else Color(0.5, 1.0, 0.9)
		for _i in 16:
			var p = _rand_point(func(q): return _mask_px(q).a < 0.2 and q.y > 130.0, 200)
			if p != null: _flies.append({"home": p, "ph": randf() * TAU, "sp": randf_range(0.3, 0.8), "col": col})

## after dark: lit windows and lamps, their shine on the water, the lantern on your boat, fireflies. Added onto what's there
func _draw_lights() -> void:
	var a := night_amount if _fx_on else 0.0
	if a <= 0.01 or _glow_tex == null: return
	var c := _light_color
	for l in _lights:
		var p := Vector2(l[0], l[1]) * SCENE
		var flick := 0.92 + 0.08 * sin(_t * 9.0 + l[0] * 40.0)
		match l[2]:
			"lamp":
				_glow(p, 78.0, c, 0.36 * a * flick)
				_glow(p, 17.0, c.lightened(0.35), 0.95 * a * flick)
				_shine_on_water(Vector2(l[3], l[4]) * SCENE, 15.0, 62.0, c, 0.5 * a * flick)
			"door":
				_glow(p, 40.0, c, 0.3 * a)
			_:
				_glow(p, 32.0, c, 0.42 * a * flick)
				_glow(p, 11.0, c.lightened(0.4), 0.8 * a * flick)
	# the lantern on your boat
	if _boat != "":
		var at := deck_point() + Vector2(-24.0 * facing, -34.0)
		_glow(at, 135.0, Color("#ffc878"), 0.26 * a)
		_glow(at, 50.0, Color("#ffd28a"), 0.2 * a)
	if _cast_t < 0.0 and not reeled and _dip < 0.5:     # the float stays easy to see
		_glow(_bobber + Vector2(0, -8), 15.0, Color("#ff6a50"), 0.55 * a)
	for f in _flies:
		var q: Vector2 = f.home + Vector2(sin(_t * f.sp + f.ph) * 44.0, cos(_t * f.sp * 1.3 + f.ph) * 22.0)
		var blink := pow(maxf(sin(_t * 1.7 * f.sp + f.ph * 3.0), 0.0), 3.0)
		_glow(q, 11.0, f.col, blink * a * 0.95)

func _glow(p: Vector2, r: float, c: Color, a: float) -> void:
	lights_layer.draw_texture_rect(_glow_tex, Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0), false, Color(c.r, c.g, c.b, a))

## a lamp's long wobbling streak on the water, where the mirror image of it falls
func _shine_on_water(p: Vector2, w: float, h: float, c: Color, a: float) -> void:
	if not _in_water(p, 0.0): return
	for i in 3:
		var sway := sin(_t * (1.9 + i * 0.7) + p.x + i * 2.0) * (2.0 + i * 1.5)
		var hh := h * (1.0 - i * 0.2)
		var ww := w * (1.0 - i * 0.28)
		lights_layer.draw_texture_rect(_glow_tex, Rect2(p.x - ww + sway, p.y - hh, ww * 2.0, hh * 2.0), false, Color(c.r, c.g, c.b, a * 0.5))

## The catch, in three beats: the float goes under and the rod bends; the fish bursts out of the water and flies to
## the boat; it lands at the captain's feet. The bigger the catch, the bigger the show. Returns the seconds until it lands.
const CATCH_BITE := 0.26                      # a fish darts in, a nibble, and the float goes under
const CATCH_FIGHT := [0.1, 0.55, 1.05]        # on the line: everyday, a biome's best fish, something special
const CATCH_FLIGHT := [0.58, 0.8, 1.45]       # in the air

func show_catch(res: Dictionary) -> float:
	var fish: Dictionary = res.get("fish", {})
	if not _catch.is_empty(): _burst()
	if fish.is_empty():
		get_tree().create_timer(0.55).timeout.connect(reel_in)
		return 0.0
	var names: Array = fish.keys()
	names.sort_custom(func(a, b): return VFData.FISH[a].price > VFData.FISH[b].price)
	var best: String = names[0]
	var lv := _show_level(res, best)
	var sp := _species_entry(best)
	if sp.tex != null:
		_dart = {"sp": sp, "from": _bobber + Vector2.from_angle(randf() * TAU) * 170.0, "pos": _bobber, "t": 0.0}
	_catch = {"t": 0.0, "fight": CATCH_BITE, "burst": CATCH_BITE + CATCH_FIGHT[lv], "lv": lv, "best": best, "extras": _school(fish, int(res.get("count", 1))),
		"nibbled": false, "on": false, "boil": 0.0}
	return CATCH_BITE + CATCH_FIGHT[lv] + CATCH_FLIGHT[lv]

## 2: a new species, an event fish, a boss, a pet. 1: the biome's best fish or a chest, now and then (not every cast)
func _show_level(res: Dictionary, best: String) -> int:
	if not res.get("new_species", []).is_empty() or String(res.get("event_fish", "")) != "" or res.get("boss_caught", false) or String(res.get("pet", "")) != "":
		return 2
	var tiers: Array = VFData.BIOMES.get(_biome, {}).get("fish", [])
	if (best == tiers.back() if not tiers.is_empty() else false) or not res.get("chest", {}).is_empty():
		if _t - _last_big_show > 22.0: return 1
	return 0

## the rest of a big catch flies in with it: a few of them, picked by how many there are of each
func _school(fish: Dictionary, count: int) -> Array:
	var n := 0 if count < 3 else 1 if count < 6 else 2 if count < 13 else 3 if count < 31 else 4 if count < 81 else 5
	var out := []
	for _i in n:
		var pick := randi_range(1, maxi(count, 1))
		for f in fish:
			pick -= int(fish[f])
			if pick <= 0:
				out.append(f)
				break
	return out

func _tick_catch(delta: float) -> void:
	delta = minf(delta, 0.05)
	_rod_bend_v += ((_rod_pull + sin(_t * 1.9) * 0.012 - _rod_bend) * 170.0 - _rod_bend_v * 9.0) * delta
	_rod_bend += _rod_bend_v * delta
	_line_tight = move_toward(_line_tight, _tight_to, delta * 7.0)
	_dip = move_toward(_dip, _dip_to, delta * (16.0 if _dip_to > _dip else 4.0))
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 2.2, 0.0)
		_frame_root()
	if not _catch.is_empty():
		var c := _catch
		c.t += delta
		if not c.nibbled and c.t > c.fight * 0.55:
			c.nibbled = true
			_dip = 0.45
			_add_ripple(_bobber, 22.0, 1.5)
			_rod_bend_v += 3.0
		if not c.on and c.t >= c.fight:
			c.on = true
			_dip_to = 1.0
			_rod_pull = 1.0
			_tight_to = 1.0
			_add_ripple(_bobber, 40.0, 2.0)
			_spray(_bobber, 7, 0.55)
			play_anim("struggle" if c.lv > 0 else "bite")
			AudioManager.play_bite()
		if c.on and c.lv > 0:                     # it fights: the water boils, the rod nods
			_rod_pull = 1.0 + sin(_t * 19.0) * 0.16
			c.boil -= delta
			if c.boil <= 0.0:
				c.boil = 0.075
				_spray(_bobber + Vector2(randf_range(-20, 20), randf_range(-8, 8)), 3, 0.55)
				if randf() < 0.3: _add_ripple(_bobber + Vector2(randf_range(-26, 26), randf_range(-12, 12)), 26.0, 1.5)
		if c.t >= c.burst: _burst()
	for f in _leapers:
		f.t += delta
		if f.t < 0.0: continue
		if f.land < 0.0 and f.t >= f.dur:
			if f.has("to"):                       # back in the water
				_water_kick(f.to, 0.55)
				f.land = 1.0
				continue
			f.land = 0.0
			AudioManager.play_flop()
			if f.lv > 0: burst("sparkle", deck_point())
		elif f.land >= 0.0:
			f.land += delta
	_leapers = _leapers.filter(func(f): return f.land < 0.6)
	for d in _drops:
		d.v.y += 900.0 * delta
		d.p += d.v * delta
		d.t -= delta
	_drops = _drops.filter(func(d): return d.t > 0.0)
	for f in _flashes: f.t += delta / f.life
	_flashes = _flashes.filter(func(f): return f.t < 1.0)

## out it comes
func _burst() -> void:
	var c := _catch
	_catch = {}
	_dart = {}
	var lv: int = c.lv
	_rod_pull = 0.0
	_rod_bend_v -= 7.5 + 2.5 * lv             # the rod whips back up
	_tight_to = 0.0
	_dip_to = 0.0
	_dip = 0.0
	play_anim("yank")
	var at := _bobber
	_spray(at, [20, 38, 70][lv], [1.0, 1.25, 1.7][lv])
	_flashes.append({"p": at, "t": 0.0, "life": [0.5, 0.65, 0.9][lv], "r": [44.0, 66.0, 104.0][lv]})
	for i in 2 + lv:
		_add_ripple(at, 56.0 + 26.0 * lv, 2.5, -i * 0.13)
	AudioManager.play_burst(lv)
	if lv > 0: _last_big_show = _t
	if lv == 2: _shake = 1.0
	_leap(c.best, at, lv, 0.0, true)
	var i := 0
	for f in c.extras:
		i += 1
		_leap(f, at, 0, 0.05 * i, false)
	get_tree().create_timer(0.14).timeout.connect(reel_in)

func _leap(fish_name: String, from: Vector2, lv: int, delay: float, main: bool) -> void:
	var t: Texture2D = _tex("fish/%s.png" % VFData.slug(fish_name))
	if t == null: return
	var u: float = float(_scene.get("unit_px", 56.0))
	var dist := from.distance_to(deck_point())
	_leapers.append({"tex": t, "name": fish_name, "from": from + Vector2(randf_range(-10, 10), randf_range(-4, 4)), "t": -delay, "land": -1.0, "lv": lv, "main": main,
		"ofs": Vector2(randf_range(-30, 30), randf_range(-8, 12)) if not main else Vector2.ZERO,
		"dur": CATCH_FLIGHT[lv] if main else randf_range(0.5, 0.64),
		"h": clampf(dist * [0.5, 0.62, 0.8][lv], [110.0, 150.0, 240.0][lv], [230.0, 300.0, 400.0][lv]) * (1.0 if main else randf_range(0.7, 1.0)),
		"size": u * ([2.0, 2.7, 3.8][lv] if main else randf_range(1.3, 1.7))})

## now and then something jumps out on the water, for no reason at all
func _wild_leap() -> void:
	var names: Array = VFData.BIOMES.get(_biome, {}).get("fish", []).filter(func(f): return not f in ["Turtle", "Guardian", "Galactic Crab"])
	if names.is_empty() or _mask == null: return
	var from_boat := boat.position + boat.pivot_offset
	var p = _rand_point(func(q): return _in_water(q, 0.3) and q.distance_to(from_boat) > 260.0 and q.distance_to(_bobber) > 180.0, 60)
	if p == null: return
	var fish_name: String = "Dolphin" if "Dolphin" in names and randf() < 0.6 else names.pick_random()
	var t: Texture2D = _tex("fish/%s.png" % VFData.slug(fish_name))
	if t == null: return
	var u: float = float(_scene.get("unit_px", 56.0))
	var big: float = 1.5 if fish_name in ["Dolphin", "Shark"] else 1.0
	var to: Vector2 = p + Vector2(randf_range(70.0, 130.0) * big * (1.0 if randf() < 0.5 else -1.0), randf_range(-12.0, 12.0))
	_leapers.append({"tex": t, "name": fish_name, "from": p, "to": to, "ofs": Vector2.ZERO, "t": 0.0, "land": -1.0, "lv": 0, "main": false,
		"dur": 0.62 + 0.14 * big, "h": randf_range(60.0, 90.0) * big, "size": u * 1.5 * big})
	_water_kick(p, 0.5)

## the splash where something leaves the water or falls back in (no sound: this is scenery)
func _water_kick(at: Vector2, power: float) -> void:
	_spray(at, int(12.0 * power) + 3, power)
	_add_ripple(at, 44.0 * power + 12.0, 1.8)
	_flashes.append({"p": at, "t": 0.0, "life": 0.4, "r": 40.0 * power + 8.0})

## water flung into the air
func _spray(at: Vector2, n: int, power: float) -> void:
	for _i in mini(n, 260 - _drops.size()):
		var a := randf_range(-PI * 0.93, -PI * 0.07)
		var sp := randf_range(70.0, 340.0) * power
		_drops.append({"p": at + Vector2(randf_range(-16, 16), randf_range(-5, 5)), "v": Vector2(cos(a) * sp * 0.8, sin(a) * sp),
			"t": randf_range(0.3, 0.7) * (0.75 + 0.25 * power), "r": randf_range(1.5, 4.2) * sqrt(power)})

## where a caught fish lands: at the captain's feet, on the deck
func deck_point() -> Vector2:
	if _fisher_info.is_empty(): return boat.position + boat.pivot_offset
	var local: Vector2 = fisher.position + Vector2(_fisher_info.feet[0], _fisher_info.feet[1]) * fisher.size + Vector2(46, 8)
	return boat.position + boat.pivot_offset + ((local - boat.pivot_offset) * boat.scale).rotated(boat.rotation)

func deck_screen() -> Vector2:
	return to_screen(deck_point())

func _draw_float() -> void:
	var b := _bobber_tex
	if b == null: return
	var sz := b.get_size()
	var h := float(_scene.get("unit_px", 56.0)) * 1.05
	var w := h * sz.x / sz.y
	var afloat := _cast_t < 0.0 and _reel_t < 0.0 and not reeled
	var p := _bobber
	if not afloat:
		over.draw_texture_rect(b, Rect2(p.x - w * 0.5, p.y - h * 0.5, w, h), false)
		return
	# in the water: only what's above the waterline shows, and less of that as it goes under
	p.y += sin(_t * 2.4) * 1.6
	var shown := 0.68 * (1.0 - _dip)
	if shown > 0.02:
		over.draw_set_transform(p, 0.0, Vector2(1.0, 0.42))
		over.draw_circle(Vector2.ZERO, w * 0.42, Color(1, 1, 1, 0.3))
		over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		over.draw_texture_rect_region(b, Rect2(p.x - w * 0.5, p.y - h * shown, w, h * shown), Rect2(0, 0, sz.x, sz.y * shown))

## the fish in the air, and the water
func _draw_catch() -> void:
	for d in _drops:
		over.draw_circle(d.p, d.r, Color(_drop_col.r, _drop_col.g, _drop_col.b, minf(1.0, d.t * 5.0) * 0.9))
	var font: Font = null
	for f in _leapers:
		if f.t < 0.0 or f.land >= 0.6: continue
		var to: Vector2 = f.to if f.has("to") else deck_point() + f.ofs
		var pos: Vector2
		var ground: Vector2
		var ang := 0.0
		var height := 0.0
		var sc: float = f.size / f.tex.get_width()
		var a := 1.0
		if f.land >= 0.0:                         # on deck: it flops, then it's in the cooler
			ground = to
			var hop: float = absf(sin(f.land * 17.0)) * 15.0 * (1.0 - f.land / 0.6)
			pos = to + Vector2(0, -hop)
			ang = sin(f.land * 17.0) * 0.45
			a = clampf((0.6 - f.land) / 0.18, 0.0, 1.0)
			sc *= 0.82
		else:
			var k: float = f.t / f.dur
			if f.lv == 2: k = 0.5 + 0.5 * signf(2.0 * k - 1.0) * pow(absf(2.0 * k - 1.0), 2.4)    # it hangs in the air at the top
			ground = (f.from as Vector2).lerp(to, k)
			height = 4.0 * f.h * k * (1.0 - k)
			pos = ground + Vector2(0, -height)
			ang = ((to - f.from) + Vector2(0, -4.0 * f.h * (1.0 - 2.0 * k))).angle()
			if f.lv == 2:                         # the star of the show
				var glow := sin(k * PI)
				if _star_tex:
					var r: float = f.size * 1.3
					over.draw_set_transform(pos, _t * 0.9, Vector2.ONE)
					over.draw_texture_rect(_star_tex, Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(1, 0.95, 0.6, 0.75 * glow))
					over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				if font == null: font = over.get_theme_default_font()
				var fs := 44
				var tw := font.get_string_size(f.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var lp: Vector2 = pos + Vector2(-tw * 0.5, -f.size * 0.75)
				over.draw_string_outline(font, lp, f.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0.1, 0.16, 0.2, glow))
				over.draw_string(font, lp, f.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.95, 0.72, glow))
		over.draw_set_transform(ground, 0.0, Vector2(1.0, 0.42))
		over.draw_circle(Vector2.ZERO, f.size * 0.26 * (1.0 - 0.5 * minf(height / f.h, 1.0)), Color(0, 0.05, 0.1, 0.2 * a))
		over.draw_set_transform(pos, ang, Vector2(sc, sc if cos(ang) >= 0.0 else -sc))
		over.draw_texture(f.tex, -f.tex.get_size() * 0.5, Color(1, 1, 1, a))
	over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ----------------------------------------------------------------- sailing
# vf_sail.gd moves boat_pos and sets boat_yaw / boat_lean; the stage draws the
# boat there and keeps the line, bobber and resting spot with it.

## reel the line in before the boat sails off (the bobber zips back to the rod tip)
func reel_in() -> void:
	if not _catch.is_empty(): _burst()
	if reeled or _reel_t >= 0.0 or _cast_t >= 0.0: return
	_reel_from = _bobber
	_reel_t = 0.0
	_add_ripple(_bobber, 24.0, 1.5, 0.0)

func _tick_reel(delta: float) -> void:
	if _cast_t >= 0.0: return
	if _reel_t >= 0.0:
		_reel_t += delta / 0.3
		var k := clampf(_reel_t, 0.0, 1.0)
		_bobber = _reel_from.lerp(_hang_point(), k * k) + Vector2(0, -sin(k * PI) * 40.0)
		if _reel_t >= 1.0:
			_reel_t = -1.0
			reeled = true
	elif reeled:
		_bobber = _hang_point()

func _hang_point() -> Vector2:
	return rod_tip() + Vector2(0, 14)

## the resting spot for casts when the player hasn't aimed: open water ahead of the boat
## (the authored bobber offset, mirrored when the boat faces left), else the nearest open water
func update_home() -> void:
	var from := boat_pos
	for base in [from + Vector2(_home_ofs.x * facing, _home_ofs.y), from + Vector2(_home_ofs.x * facing, -_home_ofs.y),
			from + Vector2(-_home_ofs.x * facing, _home_ofs.y), from + Vector2(-_home_ofs.x * facing, -_home_ofs.y)]:
		var p := _open_near(base, from)
		if p != Vector2.INF:
			_bobber_home = p
			return

func _open_near(base: Vector2, from: Vector2) -> Vector2:
	if open_water(base) and from.distance_to(base) <= MAX_CAST: return base
	for r in range(40, 280, 40):
		var n := maxi(8, int(TAU * r / 40.0))
		var best := Vector2.INF
		for i in n:
			var q := base + Vector2.from_angle(TAU * i / n) * r
			if from.distance_to(q) <= MAX_CAST and from.distance_to(q) > 200.0 and open_water(q) \
					and (best == Vector2.INF or q.distance_to(from) < best.distance_to(from)):
				best = q
		if best != Vector2.INF: return best
	return Vector2.INF

# ---------------------------------------------------------------- merchant
## The shop's tap area follows the building: a tap on the water beside it still casts.
class ShopHit extends Control:
	var outline := PackedVector2Array()

	func _has_point(p: Vector2) -> bool:
		return Geometry2D.is_point_in_polygon(p, outline) if outline.size() > 2 else Rect2(Vector2.ZERO, size).has_point(p)

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
	merchant_hit = ShopHit.new()
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
	t.text = "Fish shop"
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

## The shop itself is part of the backdrop (see vf_shop.py); the manifest says where it stands.
func _shop_rect() -> Rect2:
	var r: Array = _scene.get("shop", [])
	if r.size() < 4: return Rect2()
	return Rect2(r[0] * SCENE.x, r[1] * SCENE.y, (r[2] - r[0]) * SCENE.x, (r[3] - r[1]) * SCENE.y)

func _place_merchant() -> void:
	if merchant == null or _merchant_info.is_empty() or not _scene.has("merchant"): return
	var cell: float = _merchant_info.cell
	var k: float = float(_scene.get("merchant_unit_px", _scene.unit_px)) / float(_merchant_info.unit_px)
	merchant.size = Vector2(cell, cell) * k
	var spot := Vector2(_scene.merchant[0], _scene.merchant[1]) * SCENE
	merchant.position = spot - Vector2(_merchant_info.anchor[0], _merchant_info.anchor[1]) * merchant.size
	var shop := _shop_rect()
	merchant_hit.position = shop.position
	merchant_hit.size = shop.size
	(merchant_hit as ShopHit).outline.clear()
	for c in _scene.get("shop_outline", []):
		(merchant_hit as ShopHit).outline.append(Vector2(c[0], c[1]) * SCENE - shop.position)
	merchant_tag.position = Vector2(shop.get_center().x - 150.0, shop.end.y + 8.0)
	_place_smoke()

## smoke from the shop's chimney (no "smoke" point in the manifest where there's no air)
func _place_smoke() -> void:
	if _smoke == null:
		_smoke = _particles("smoke_02", 7, 3.6, Color(1, 1, 1, 0.34), 0.03, 0.06)
		_smoke.material = null
		_smoke.direction = Vector2(0.25, -1.0)
		_smoke.spread = 10.0
		_smoke.gravity = Vector2(5, -10)
		_smoke.initial_velocity_min = 14.0
		_smoke.initial_velocity_max = 20.0
		var c := Curve.new()
		c.add_point(Vector2(0.0, 0.6))
		c.add_point(Vector2(1.0, 1.0))
		_smoke.scale_amount_curve = c
	_smoke.emitting = _scene.has("smoke")
	if _scene.has("smoke"):
		_smoke.position = Vector2(_scene.smoke[0], _scene.smoke[1]) * SCENE

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

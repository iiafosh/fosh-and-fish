extends Control
## Sailing: steer the boat around the biome scene and sail through the sea lanes
## at the screen edges to the previous / next biome (VFData.BIOME_ORDER).
##   desktop: WASD / arrow keys        mouse & touch: press on the boat and drag
##
## A press anywhere else still casts (vf_main._unhandled_input). Presses that start
## on the hull are taken here first (children get _unhandled_input before their
## parent) and marked handled, so they never reach the cast code.
## The hull only goes where the stage's water mask says it fits and slides along
## shores. This node sits in vf_main right above the stage and under the HUD; it
## draws the wipe between biomes, the lane signs and the one-time "how to sail" hint.

const SCENE := Vector2(1920, 1080)
const MAX_SPEED := 340.0        # scene px / s
const ACCEL := 640.0            # scene px / s²
const COAST := 1.4              # water drag per second once you let go
const GRAB_MARGIN := 28.0       # scene px around the hull that still grabs the boat
const DEPTH := 0.3              # water depth (mask green) the hull outline needs
const HULL_MARGIN := 24.0       # clearance around the hull (scene px): keeps it off the foam line and docks
const WAKE_LIFE := 1.3
const LANE_PREF_Y := 0.645      # lanes prefer the authored boat height (clear of the HUD corners)

var main                        # vf_main: UI kit (pill_box, ph, lbl, keycap), overlay, toasts
var stage                       # vf_stage: boat_pos / facing / boat_flip / boat_lean, water mask
var vel := Vector2.ZERO         # scene px / s
var dragging := false
var _grab := Vector2.ZERO       # where the finger holds the boat, relative to the boat (scene px)
var _drag_to := Vector2.ZERO    # finger position (scene px)
var state := "idle"             # idle | leaving | arriving
var _dir := 1                   # voyage direction: +1 right / next biome, -1 left / previous
var _arrive_to := Vector2.ZERO
var lanes := {}                 # side (-1 left, 1 right) -> {"biome", "y"}
var vis := Rect2()              # the part of the scene that's on screen (scene px)
var _lanes_vis := Rect2()
var layer: Control              # scene-space layer just under the boat: wake + lane chevrons
var _wake: Array = []
var _wake_acc := 0.0
var _home_acc := 0.0
var _was_moving := false
var _brake := 0.0
var _bump_t := -10.0
var _no_turn := 0.0            # right after a bump the boat backs off without turning around
var _aim_seen := Vector2.INF
var _aim_anchor := Vector2.ZERO
var _hull_cache := {}
var _signs := {}                # side -> PanelContainer
var _sign_keys := {}            # side -> "biome|locked" the sign was built for
var wipe_k := 0.0               # 0 open -> 1 covered -> 2 open again (tweened)
var _wipe_col := Color(0.04, 0.14, 0.18)
var _wipe_box: PanelContainer
var _wipe_label: Label
var _hint: PanelContainer
var _hint_t := 0.0
var _hint_from := Vector2.ZERO
var _hint_state := 0            # 0 waiting, 1 showing, 2 done
var _t := 0.0
var _hover := false
var test_touch := false         # capture test: show the touch wording of the hint

func setup(m, s) -> void:
	main = m
	stage = s

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer = Control.new()
	layer.size = SCENE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(_draw_layer)
	stage.root.add_child(layer)
	stage.root.move_child(layer, stage.boat.get_index())
	stage.scene_changed.connect(_on_scene)
	stage.boat_changed.connect(_on_boat)
	stage.cast_started.connect(func(): _brake = 0.35)       # casting drops anchor
	VF.changed.connect(_sync_signs)
	_build_wipe_box()
	_build_hint()

# ================================================================ geometry
func _update_vis() -> void:
	var s: float = stage.root.scale.x
	if s <= 0.0 or stage.size.x <= 0.0:
		vis = Rect2()
		return
	vis = Rect2(-stage.root.position / s, stage.size / s).intersection(Rect2(Vector2.ZERO, SCENE))

## the hull as an ellipse: centre relative to the boat's pivot (facing right) and radii,
## from the sprite's opaque area
func _hull() -> Dictionary:
	var tex: Texture2D = stage.boat.texture
	if tex == null: return {"c": Vector2.ZERO, "r": Vector2(80, 45)}
	var key := "%s|%s" % [tex.resource_path, stage.boat.size]
	if _hull_cache.has(key): return _hull_cache[key]
	var used := Rect2(Vector2.ZERO, tex.get_size())
	var img := tex.get_image()
	if img:
		if img.is_compressed(): img.decompress()
		var u := img.get_used_rect()
		if u.size.x > 4: used = Rect2(u)
	var k: Vector2 = stage.boat.size / tex.get_size()
	var rect := Rect2(used.position * k, used.size * k)
	var h := {"c": rect.get_center() - stage.boat.pivot_offset, "r": rect.size * 0.5 * Vector2(0.9, 0.78)}
	_hull_cache[key] = h
	return h

func _hull_center(p: Vector2, f: float) -> Vector2:
	var c: Vector2 = _hull().c
	return p + Vector2(c.x * f, c.y)

## where the boat's centre may go: on screen, with most of the hull visible
func _limits() -> Rect2:
	var r: Vector2 = _hull().r
	var x0 := vis.position.x + r.x * 0.5
	var x1 := vis.end.x - r.x * 0.5
	var y0 := vis.position.y + r.y + 40.0
	var y1 := vis.end.y - r.y * 0.6
	return Rect2(x0, y0, maxf(1.0, x1 - x0), maxf(1.0, y1 - y0))

## 0 = the boat fits here; otherwise how badly it doesn't (moves may never make it worse)
func _bad(p: Vector2, f := 0.0) -> int:
	if f == 0.0: f = stage.facing
	return _off_limits(p) + _dry(p, f)

## 0 inside the on-screen limits, else grows with the distance outside, so a boat left
## outside (window resized) can always steer back in
func _off_limits(p: Vector2) -> int:
	var lim := _limits()
	var d := maxf(maxf(lim.position.x - p.x, p.x - lim.end.x), maxf(lim.position.y - p.y, p.y - lim.end.y))
	return 0 if d <= 0.0 else 50 + int(d / 4.0)

## how many hull samples are out of the water
func _dry(p: Vector2, f: float) -> int:
	var c := _hull_center(p, f)
	var r: Vector2 = _hull().r + Vector2(HULL_MARGIN, HULL_MARGIN)
	var n := 0 if stage._in_water(c, DEPTH) else 1
	var k := clampi(int((r.x + r.y) * PI / 40.0), 16, 40)     # outline samples ~40 px apart
	for i in k:
		var a := TAU * i / k
		if not stage._in_water(c + Vector2(cos(a) * r.x, sin(a) * r.y), DEPTH): n += 1
	for i in 8:                                                 # inner ring: rocks under big hulls
		var a := TAU * (i + 0.5) / 8.0
		if not stage._in_water(c + Vector2(cos(a) * r.x, sin(a) * r.y) * 0.55, DEPTH): n += 1
	return n

func _fits(p: Vector2, f := 0.0) -> bool:
	return _bad(p, f) == 0

## is this screen point on (or right next to) the boat?
func hit_boat(screen: Vector2) -> bool:
	var c := _hull_center(stage.boat_pos, stage.facing)
	var d: Vector2 = stage.to_scene(screen) - c
	var r: Vector2 = _hull().r + Vector2(GRAB_MARGIN, GRAB_MARGIN)
	return (d.x * d.x) / (r.x * r.x) + (d.y * d.y) / (r.y * r.y) <= 1.0

func _bow() -> Vector2:
	var r: Vector2 = _hull().r
	return _hull_center(stage.boat_pos, stage.facing) + Vector2(r.x * 0.9 * stage.facing, 0)

func _edge_x(side: int) -> float:
	return vis.end.x if side > 0 else vis.position.x

## the boat is too big for its spot (bigger boat bought, window resized...): nudge it to open water nearby
func _settle(force := false) -> void:
	if state != "idle" or stage._scene.is_empty() or vis.size.x < 400.0 or vis.size.y < 300.0: return
	var p: Vector2 = stage.boat_pos
	if (_bad(p) if force else _dry(p, stage.facing)) == 0: return   # fine (or just off-limits: steer back in)
	var lim := _limits()
	var q := Vector2(clampf(p.x, lim.position.x, lim.end.x), clampf(p.y, lim.position.y, lim.end.y))
	for r in range(0, 480, 24):
		for i in 16:
			var c := q + Vector2.from_angle(TAU * i / 16.0) * r
			if _fits(c):
				stage.boat_pos = c
				stage.update_home()
				return

# =================================================================== lanes
func _on_scene() -> void:
	_wake.clear()
	if state == "idle":
		vel = Vector2.ZERO
		dragging = false
	_update_vis()
	_scan_lanes()
	if state == "idle": _settle()

func _on_boat() -> void:
	_update_vis()
	_scan_lanes()
	_settle()

func _scan_lanes() -> void:
	_lanes_vis = vis
	lanes.clear()
	var i := VFData.BIOME_ORDER.find(stage._biome)
	if i >= 0 and vis.size.x > 100.0:
		for side in [-1, 1]:
			var j: int = i + side
			if j < 0 or j >= VFData.BIOME_ORDER.size(): continue
			var y := _lane_y(side)
			if y >= 0.0: lanes[side] = {"biome": VFData.BIOME_ORDER[j], "y": y}
	_sync_signs()

## where a lane leaves the screen on this side: water from the edge inwards, wide and
## deep enough for the hull, as close as possible to the authored boat height. -1 = none.
func _lane_y(side: int) -> float:
	var r: Vector2 = _hull().r
	var lim := _limits()
	var pref := clampf(LANE_PREF_Y * SCENE.y, lim.position.y, lim.end.y)
	var best := -1.0
	var y := lim.position.y
	while y <= lim.end.y:
		if (best < 0.0 or absf(y - pref) < absf(best - pref)) and _corridor(side, y, r):
			best = y
		y += 12.0
	return best

func _corridor(side: int, y: float, r: Vector2) -> bool:
	var edge := _edge_x(side)
	var length := r.x * 2.0 + 260.0
	var dx := 0.0
	while dx <= length:
		for dy in [-r.y - 10.0, -r.y * 0.5, 0.0, r.y * 0.5, r.y + 10.0]:
			if not stage._in_water(Vector2(edge - side * (4.0 + dx), y + dy), DEPTH): return false
		dx += 24.0
	return true

## water reaches the screen edge here, so the boat can sail out
func _edge_open(side: int, y: float) -> bool:
	var x := _edge_x(side) - side * 4.0
	var r: Vector2 = _hull().r
	for dy in [-r.y * 0.6, 0.0, r.y * 0.6]:
		if not stage._in_water(Vector2(x, y + dy), DEPTH): return false
	return true

func _locked(b: String) -> bool:
	return VF.level < int(VFData.BIOMES[b].level)

# ============================================================ lane signs
func _sync_signs() -> void:
	if main == null: return
	for side in [-1, 1]:
		var key := ""
		if lanes.has(side):
			var b: String = lanes[side].biome
			key = "%s|%s" % [b, _locked(b)]
		if String(_sign_keys.get(side, "")) == key: continue
		_sign_keys[side] = key
		if _signs.has(side):
			_signs[side].queue_free()
			_signs.erase(side)
		if key != "": _signs[side] = _make_sign(side, lanes[side].biome)

## "← River", "Volcanic →", or "🔒 Ocean · Lv 100" in a light frosted pill
func _make_sign(side: int, b: String) -> PanelContainer:
	var locked := _locked(b)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", main.pill_box(true, 12, 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ic: TextureRect = main.icon(main.ph("lock" if locked else "arrow-right"), 16)
	ic.flip_h = side < 0 and not locked
	ic.modulate = main.C_MUTED if locked else Color(VFData.BIOMES[b].accent).darkened(0.12)
	var name: Label = main.lbl(b, 14, main.C_MUTED if locked else main.C_TEXT)
	if side < 0 or locked: h.add_child(ic)
	h.add_child(name)
	if locked: h.add_child(main.lbl("·  Lv %s" % VF.commas(int(VFData.BIOMES[b].level)), 12, main.C_MUTED))
	if side > 0 and not locked: h.add_child(ic)
	p.modulate.a = 0.0
	add_child(p)
	return p

func _place_signs(delta: float) -> void:
	var r: Vector2 = _hull().r
	for side in _signs:
		var p: PanelContainer = _signs[side]
		if not lanes.has(side):
			p.visible = false
			continue
		p.visible = true
		var lane: Dictionary = lanes[side]
		var sz := p.get_combined_minimum_size()
		p.size = sz
		var at: Vector2 = stage.to_screen(Vector2(_edge_x(side), float(lane.y) - r.y - 64.0))
		var x := at.x - sz.x - 16.0 if side > 0 else at.x + 16.0
		p.position = Vector2(x, at.y - sz.y * 0.5 + sin(_t * 1.7 + side) * 2.0).round()
		# brighter when you sail close, hidden mid-voyage
		var near := 1.0 - clampf(absf(stage.boat_pos.x - _edge_x(side)) / 900.0, 0.0, 1.0)
		var want := (0.82 + 0.18 * near) if state == "idle" else 0.0
		p.modulate.a = move_toward(p.modulate.a, want, delta * 4.0)

# =============================================================== steering
func _keys() -> Vector2:
	var k := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): k.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): k.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): k.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): k.y += 1.0
	return k

func max_speed() -> float:
	return MAX_SPEED + 6.0 * float(VF.boats_owned)      # better boats are a little quicker

## true while you steer, drag or are mid-voyage: no casting then (vf_main._do_cast)
func busy() -> bool:
	if state != "idle" or dragging: return true
	return main != null and not main.overlay.visible and _keys() != Vector2.ZERO

func _unhandled_input(e: InputEvent) -> void:
	if main == null or stage._scene.is_empty(): return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			if main.overlay.visible: return
			if state != "idle":
				get_viewport().set_input_as_handled()          # no casting mid-voyage
				return
			if hit_boat(e.position):
				dragging = true
				_drag_to = stage.to_scene(e.position)
				_grab = _drag_to - stage.boat_pos
				_hide_hint()
				get_viewport().set_input_as_handled()
		elif dragging:
			dragging = false
			get_viewport().set_input_as_handled()
	elif e is InputEventMouseMotion:
		if dragging:
			_drag_to = stage.to_scene(e.position)
			get_viewport().set_input_as_handled()
		elif not main.is_touch():
			var on: bool = state == "idle" and not main.overlay.visible and hit_boat(e.position)
			if on != _hover:
				_hover = on
				Input.set_default_cursor_shape(Input.CURSOR_MOVE if on else Input.CURSOR_ARROW)

func _steer(delta: float) -> void:
	var blocked: bool = main.overlay.visible
	if dragging and (blocked or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		dragging = false
	var want := Vector2.ZERO
	var steering := false
	var top := max_speed()
	if dragging:
		var to: Vector2 = _drag_to - _grab - stage.boat_pos
		var d := to.length()
		if d > 14.0: want = to / d * minf(top, (d - 14.0) * 2.6)
		steering = true                                     # finger still on the boat = brake
	elif not blocked:
		var k := _keys()
		if k != Vector2.ZERO:
			want = k.normalized() * top
			steering = true
	if steering:
		vel = vel.move_toward(want, ACCEL * delta)
	else:
		vel *= exp(-COAST * delta)
		if vel.length() < 4.0: vel = Vector2.ZERO
	if _brake > 0.0:
		_brake -= delta
		vel *= exp(-12.0 * delta)
	if vel == Vector2.ZERO: return
	var p: Vector2 = stage.boat_pos
	var step := vel * delta
	# pushing against the left / right edge where the water runs off screen: a sea lane
	var lim := _limits()
	var side := 0
	if step.x > 0.0 and p.x + step.x >= lim.end.x: side = 1
	elif step.x < 0.0 and p.x + step.x <= lim.position.x: side = -1
	if side != 0 and lanes.has(side) and absf(vel.x) > 25.0 and _edge_open(side, p.y):
		_reach_lane(side)
		return
	_move(step, delta)

## move with the hull kept in the water; deflect along the shore instead of sticking
func _move(step: Vector2, delta: float) -> void:
	var p: Vector2 = stage.boat_pos
	var now := _bad(p)
	var nb := _bad(p + step)
	if nb == 0 or (now > 0 and nb <= now):
		stage.boat_pos = p + step
		return
	for a in [0.3, 0.6, 0.9, 1.2, 1.45]:
		for s in [1.0, -1.0]:
			var d: Vector2 = step.rotated(a * s) * cos(a)
			if _bad(p + d) == 0:
				stage.boat_pos = p + d
				vel = vel.rotated(a * s) * cos(a)
				return
	if now > 0:
		_settle(true)                       # wedged somewhere it doesn't fit: pop out to open water
		return
	# head-on into the shore: a soft stop with a little splash
	if vel.length() > 160.0 and Time.get_ticks_msec() / 1000.0 - _bump_t > 0.8:
		_bump_t = Time.get_ticks_msec() / 1000.0
		stage.splash(_bow(), 0.6)
	vel = -vel * 0.12

func _reach_lane(side: int) -> void:
	var b: String = lanes[side].biome
	if _locked(b):
		# bump back softly
		vel = Vector2(-side * maxf(150.0, absf(vel.x) * 0.6), vel.y * 0.5)
		_no_turn = 0.7
		dragging = false
		stage.splash(_bow(), 0.7)
		var now := Time.get_ticks_msec() / 1000.0
		if now - _bump_t > 2.2:
			_bump_t = now
			main._toast("Reach level %s to sail to %s" % [VF.commas(int(VFData.BIOMES[b].level)), b], "warn")
			AudioManager.play_sfx("splash", -9.0, 0.7)
		return
	_start_travel(b, side, false)

# ================================================================ voyages
## Map "Travel" and the sea lanes both end up here. Returns "" or why not.
func travel_to(b: String) -> String:
	if b == VF.biome: return ""
	if _locked(b): return "%s unlocks at level %d." % [b, VFData.BIOMES[b].level]
	if state != "idle": return ""
	var side := 1 if VFData.BIOME_ORDER.find(b) > VFData.BIOME_ORDER.find(VF.biome) else -1
	_start_travel(b, side, true)
	return ""

func _start_travel(b: String, side: int, from_map: bool) -> void:
	state = "leaving"
	_dir = side
	dragging = false
	stage.reel_in()
	stage.aim = Vector2.INF
	_hide_hint()
	if absf(vel.x) < 120.0 or signf(vel.x) != side: vel.x = side * 120.0
	_voyage(b, side, from_map)

func _voyage(b: String, side: int, from_map: bool) -> void:
	_wipe_col = Color(0.03, 0.11, 0.14).lerp(Color(VFData.BIOMES[b].accent), 0.12)
	_wipe_label.text = b
	AudioManager.play_sfx("splash", -8.0, 0.8)
	if not from_map:
		# let the boat slip off screen first
		var t := 0.0
		while t < 0.9 and not _offscreen(side):
			await get_tree().process_frame
			t += get_process_delta_time()
	await _tween_wipe(1.0, 0.36)
	var err: String = VF.select_biome(b)       # VF.changed -> vf_main._refresh -> stage.set_biome
	if err != "":
		main._toast(err, "warn")
		side = -side                            # come back in where we left
	_enter(-side)
	await get_tree().create_timer(0.16).timeout
	await _tween_wipe(2.0, 0.42)
	wipe_k = 0.0
	if err == "" and not VF.rod_usable():
		main._toast("Your %s can't fish in %s. Equip another rod in the Shop." % [VF.rod, b], "warn")

func _offscreen(side: int) -> bool:
	return (stage.boat_pos.x - side * _hull().r.x * 0.9 - _edge_x(side)) * side > 0.0

## put the boat just past the given screen edge, heading in along that side's lane
func _enter(edge: int) -> void:
	_update_vis()
	_scan_lanes()
	_wake.clear()
	var r: Vector2 = _hull().r
	var y: float = float(lanes[edge].y) if lanes.has(edge) else _lane_y(edge)
	stage.facing = float(-edge)
	stage.boat_flip = stage.facing
	if y < 0.0:
		# no water reaches that edge: appear at the authored spot instead
		state = "idle"
		vel = Vector2.ZERO
		stage.update_home()
		return
	stage.boat_pos = Vector2(_edge_x(edge) + edge * r.x * 1.1, y)
	_arrive_to = Vector2(_edge_x(edge) - edge * (r.x + 200.0), y)
	vel = Vector2(-edge * max_speed(), 0.0)
	state = "arriving"

func _autopilot(delta: float) -> void:
	if state == "leaving":
		vel = vel.move_toward(Vector2(_dir * max_speed() * 1.1, 0.0), ACCEL * 1.5 * delta)
	else:
		var to: Vector2 = _arrive_to - stage.boat_pos
		var d: float = to.length()
		var want: Vector2 = to / d * minf(max_speed(), d * 2.2) if d > 1.0 else Vector2.ZERO
		vel = vel.move_toward(want, ACCEL * 1.5 * delta)
		if d < 28.0 and wipe_k == 0.0:
			state = "idle"                         # you have the helm again (the boat coasts to a stop)
			stage.update_home()
	stage.boat_pos += vel * delta

func _tween_wipe(to: float, secs: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "wipe_k", to, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

func _build_wipe_box() -> void:
	_wipe_box = PanelContainer.new()
	_wipe_box.add_theme_stylebox_override("panel", main.pill_box(true, 18, 9))
	_wipe_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 9)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic: TextureRect = main.icon(main.ph("sailboat"), 22)
	ic.modulate = main.C_TEAL
	h.add_child(ic)
	_wipe_label = main.lbl("", 20, main.C_TEXT)
	h.add_child(_wipe_label)
	_wipe_box.add_child(h)
	_wipe_box.visible = false
	add_child(_wipe_box)

# ================================================================== frame
func _process(delta: float) -> void:
	if main == null or stage._scene.is_empty(): return
	delta = minf(delta, 0.05)
	_t += delta
	_update_vis()
	if vis != _lanes_vis:
		_scan_lanes()
		_settle()
	if state == "idle": _steer(delta)
	else: _autopilot(delta)
	_tick_boat(delta)
	_tick_wake(delta)
	_place_signs(delta)
	_tick_hint(delta)
	var k := clampf(1.0 - absf(wipe_k - 1.0) * 2.4, 0.0, 1.0) if wipe_k > 0.0 else 0.0
	_wipe_box.visible = k > 0.0
	if _wipe_box.visible:
		_wipe_box.size = _wipe_box.get_combined_minimum_size()
		_wipe_box.position = ((size - _wipe_box.size) * 0.5).round()
		_wipe_box.modulate.a = k
	layer.queue_redraw()
	queue_redraw()

## facing, lean, reeling the line in, resting spot and aim follow the boat
func _tick_boat(delta: float) -> void:
	var speed := vel.length()
	stage.boat_speed = speed
	_no_turn -= delta
	if absf(vel.x) > 30.0 and signf(vel.x) != stage.facing and _no_turn <= 0.0:
		if state != "idle" or _fits(stage.boat_pos, signf(vel.x)):
			stage.facing = signf(vel.x)
	stage.boat_flip = move_toward(stage.boat_flip, stage.facing, delta / 0.12)
	var lean: float = clampf(vel.y / MAX_SPEED, -1.0, 1.0) * 0.06 * stage.facing
	stage.boat_lean = lerpf(stage.boat_lean, lean, 1.0 - exp(-6.0 * delta))
	if speed > 45.0 and not stage.reeled:
		if stage._reel_t < 0.0 and stage._cast_t < 0.0: AudioManager.play_reel()
		stage.reel_in()
	# a tap aims the casts; sail far from where you aimed and it's forgotten
	if stage.aim != _aim_seen:
		_aim_seen = stage.aim
		_aim_anchor = stage.boat_pos
	elif stage.aim != Vector2.INF and stage.boat_pos.distance_to(_aim_anchor) > 160.0:
		stage.aim = Vector2.INF
		_aim_seen = Vector2.INF
	var moving := speed > 20.0
	_home_acc += delta
	if state == "idle" and ((moving and _home_acc > 0.25) or (_was_moving and not moving)):
		_home_acc = 0.0
		stage.update_home()
	_was_moving = moving

# =================================================================== wake
func _tick_wake(delta: float) -> void:
	for w in _wake: w.t += delta
	_wake = _wake.filter(func(w): return w.t < WAKE_LIFE)
	var speed := vel.length()
	_wake_acc += delta
	if speed > 30.0 and _wake_acc > 0.05:
		_wake_acc = 0.0
		var r: Vector2 = _hull().r
		var dir := vel / speed
		var c := _hull_center(stage.boat_pos, stage.facing)
		_wake.append({"p": c - Vector2(dir.x * r.x, dir.y * r.y) * 0.85, "n": dir.orthogonal(), "t": 0.0,
			"k": clampf(speed / MAX_SPEED, 0.0, 1.0)})

func _draw_layer() -> void:
	_draw_lanes()
	if _wake.size() >= 2:
		# two foam lines spreading out behind the stern (a Kelvin wake) ...
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var cols := PackedColorArray()
		for w in _wake:
			var age: float = w.t / WAKE_LIFE
			var spread: float = 12.0 + w.t * 78.0
			left.append(w.p + w.n * spread)
			right.append(w.p - w.n * spread)
			cols.append(Color(1, 1, 1, pow(1.0 - age, 2.2) * 0.55 * w.k))
		layer.draw_polyline_colors(left, cols, 2.0, true)
		layer.draw_polyline_colors(right, cols, 2.0, true)
		# ... and churned foam right behind the stern
		for w in _wake:
			var age: float = w.t / 0.55
			if age >= 1.0: continue
			var rad: float = 7.0 + age * 12.0
			layer.draw_circle(w.p + w.n * sin(w.t * 9.0 + w.p.x) * 4.0, rad, Color(1, 1, 1, (1.0 - age) * 0.16 * w.k))
	var speed := vel.length()
	if speed > 60.0 and wipe_k == 0.0:
		# bow wave
		var dir := vel / speed
		var r: Vector2 = _hull().r
		var bow := _hull_center(stage.boat_pos, stage.facing) + Vector2(dir.x * r.x, dir.y * r.y) * 0.92
		var a := clampf(speed / MAX_SPEED, 0.0, 1.0) * 0.5
		layer.draw_arc(bow - dir * 14.0, 22.0, dir.angle() - 1.2, dir.angle() + 1.2, 16, Color(1, 1, 1, a), 2.5, true)

## faint chevrons drifting out along open lanes, so you know you can sail that way
func _draw_lanes() -> void:
	if state != "idle": return
	var boat := _hull_center(stage.boat_pos, stage.facing)
	for side in lanes:
		if _locked(lanes[side].biome): continue
		var y: float = lanes[side].y
		var base := Vector2(_edge_x(side) - side * 230.0, y)
		for i in 3:
			var ph := fmod(_t * 0.55 + i / 3.0, 1.0)
			var c := base + Vector2(side * ph * 150.0, 0.0)
			var a := sin(ph * PI) * 0.55 * clampf((c.distance_to(boat) - 90.0) / 140.0, 0.0, 1.0)
			if a <= 0.01: continue
			var s := Vector2(side * 9.0, 0.0)
			var pts := PackedVector2Array([c - s + Vector2(0, -13), c + s, c - s + Vector2(0, 13)])
			var sh := PackedVector2Array()
			for q in pts: sh.append(q + Vector2(2, 3))
			layer.draw_polyline(sh, Color(0, 0.06, 0.1, a * 0.35), 4.0, true)
			layer.draw_polyline(pts, Color(1, 1, 1, a), 4.0, true)

# =================================================================== wipe
func _draw() -> void:
	if wipe_k <= 0.0 or wipe_k >= 2.0: return
	var w := size.x
	var h := size.y
	var soft := 240.0
	# u runs along the voyage (0 behind, w ahead); the curtain sweeps in from ahead and out behind
	var solid := Vector2.ZERO        # solid curtain span in u
	var grad := Vector2.ZERO         # gradient span in u: x = transparent end, y = solid end
	if wipe_k <= 1.0:
		var e := lerpf(w + soft, 0.0, wipe_k)
		solid = Vector2(e, w + soft)
		grad = Vector2(e - soft, e)
	else:
		var e := lerpf(w, -soft, wipe_k - 1.0)
		solid = Vector2(-soft, e)
		grad = Vector2(e + soft, e)
	var c := _wipe_col
	var c0 := Color(c, 0.0)
	_curtain_rect(solid.x, solid.y, h, c, c)
	_curtain_rect(grad.x, grad.y, h, c0, c)

func _curtain_rect(u0: float, u1: float, h: float, col0: Color, col1: Color) -> void:
	var x0 := u0 if _dir > 0 else size.x - u0
	var x1 := u1 if _dir > 0 else size.x - u1
	draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, h), Vector2(x0, h)]),
		PackedColorArray([col0, col1, col1, col0]))

# =================================================================== hint
func _hints_allowed() -> bool:
	var args := OS.get_cmdline_user_args()
	if "--sail-test" in args: return true
	for a in args:
		if a.begins_with("--capture=") or a in ["--trailer", "--reel"]: return false
	return true

func _build_hint() -> void:
	_hint = PanelContainer.new()
	_hint.add_theme_stylebox_override("panel", main.pill_box(true, 12, 6))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	add_child(_hint)

func _show_hint() -> void:
	for c in _hint.get_children(): c.queue_free()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic: TextureRect = main.icon(main.ph("sailboat"), 18)
	ic.modulate = main.C_TEAL
	h.add_child(ic)
	if main.is_touch() or test_touch:
		h.add_child(main.lbl("Drag the boat to sail", 14))
	else:
		var kc: Control = main.keycap("WASD")
		kc.visible = true
		h.add_child(kc)
		h.add_child(main.lbl("to sail", 14))
	_hint.add_child(h)
	_hint_state = 1
	_hint_t = 0.0
	_hint_from = stage.boat_pos
	_hint.modulate.a = 0.0
	_hint.visible = true
	_hint.create_tween().tween_property(_hint, "modulate:a", 1.0, 0.35)
	VF.sail_hint = true
	VF.save_game()

func _hide_hint() -> void:
	if _hint_state != 1: return
	_hint_state = 2
	var tw := _hint.create_tween()
	tw.tween_property(_hint, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): _hint.visible = false)

func _tick_hint(delta: float) -> void:
	if _hint_state == 0:
		if VF.sail_hint or VF.tutorial < 99 or not _hints_allowed(): return
		if main.overlay.visible or state != "idle" or vel.length() > 5.0:
			_hint_t = 0.0
			return
		_hint_t += delta
		if _hint_t > 2.5: _show_hint()
	elif _hint_state == 1:
		_hint_t += delta
		if _hint_t > 10.0 or stage.boat_pos.distance_to(_hint_from) > 80.0 or main.overlay.visible or state != "idle":
			_hide_hint()
	if _hint.visible:
		var hh: Dictionary = _hull()
		var top: Vector2 = stage.to_screen(_hull_center(stage.boat_pos, stage.facing) - Vector2(0, hh.r.y + 22.0))
		var sz := _hint.get_combined_minimum_size()
		_hint.size = sz
		var p := top - Vector2(sz.x * 0.5, sz.y) + Vector2(0, sin(_t * 2.2) * 3.0)
		p.x = clampf(p.x, 12.0, size.x - sz.x - 12.0)
		p.y = clampf(p.y, 12.0, size.y - sz.y - 12.0)
		_hint.position = p.round()

# ============================================================ capture test
## godot --path . -- --capture=DIR --sail-test (from vf_main._check_capture): sails around
## with real key / mouse events, casts, sails through lanes, bumps a locked one, uses the
## Map, and screenshots every biome's exits. Prints SAIL / AIM lines. Never saves.
func capture_test(dir: String) -> void:
	await _wait(3.4)
	print("SAIL start biome=%s boat=%s fits=%s lanes=%s vis=%s" % [VF.biome, stage.boat_pos.round(), _fits(stage.boat_pos), lanes, vis])
	await main._shot(dir + "/sail0_hint.png")
	# keyboard: right, then left (turns around), then up into the shore
	_key(KEY_D, true)
	await _wait(1.3)
	await main._shot(dir + "/sail1_right.png")
	_key(KEY_D, false)
	_key(KEY_A, true)
	await _wait(1.1)
	await main._shot(dir + "/sail2_left.png")
	_key(KEY_A, false)
	_key(KEY_W, true)
	await _wait(2.4)
	print("SAIL shore boat=%s fits=%s vel=%s" % [stage.boat_pos.round(), _fits(stage.boat_pos), vel.round()])
	await main._shot(dir + "/sail3_shore.png")
	_key(KEY_W, false)
	_key(KEY_D, true)
	_key(KEY_W, true)
	await _wait(1.6)
	print("SAIL slide boat=%s fits=%s vel=%s" % [stage.boat_pos.round(), _fits(stage.boat_pos), vel.round()])
	_key(KEY_D, false)
	_key(KEY_W, false)
	_key(KEY_S, true)                                   # back out to open water
	await _wait(1.6)
	_key(KEY_S, false)
	print("SAIL back boat=%s fits=%s overlay=%s state=%s" % [stage.boat_pos.round(), _fits(stage.boat_pos), main.overlay.visible, state])
	await _wait(1.2)
	# a press on the boat sails; the cast count must not change
	var trips: int = VF.stats.trips
	var b0: Vector2 = stage.boat_screen()
	print("SAIL grab at=%s on_boat=%s" % [b0.round(), hit_boat(b0)])
	_mouse(b0, true)
	for i in 40:
		_motion(b0 + Vector2(i * 6, -i * 3))
		await get_tree().process_frame
	await _wait(1.4)
	await main._shot(dir + "/sail4_drag.png")
	_mouse(b0 + Vector2(234, -117), false)
	print("SAIL drag from=%s to=%s casts=%d" % [b0.round(), stage.boat_screen().round(), VF.stats.trips - trips])
	await _wait(1.6)
	# tapping the water still casts, from the new spot (pick open water clear of the HUD)
	VF._last_cast_ms = -100000
	var tap: Vector2 = size * Vector2(0.45, 0.6)
	for o in [Vector2(260, 40), Vector2(-260, 40), Vector2(220, 150), Vector2(-220, 150), Vector2(240, -120)]:
		var q: Vector2 = stage.boat_screen() + o
		if stage.open_water(stage.to_scene(q)) and q.x > 300.0 and q.x < size.x - 330.0 and q.y > 190.0 and q.y < size.y - 120.0:
			tap = q
			break
	main._tap(tap)
	await _wait(1.3)
	print("AIM tap=%s bobber=%s casts=%d" % [tap.round(), stage.bobber_screen().round(), VF.stats.trips - trips])
	await main._shot(dir + "/sail5_cast.png")
	# sail right through the lane: River -> Volcanic (steering at the sign like a player)
	var shot_wipe := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 14000:
		if state == "idle" and VF.biome == "River": _helm(1)
		else: _helm(0)
		if not shot_wipe and wipe_k > 0.55:
			shot_wipe = true
			await main._shot(dir + "/sail6_wipe.png")
		if VF.biome == "Volcanic" and state == "idle": break
		await get_tree().process_frame
	_helm(0)
	await _wait(0.6)
	print("SAIL arrived biome=%s boat=%s fits=%s" % [VF.biome, stage.boat_pos.round(), _fits(stage.boat_pos)])
	await main._shot(dir + "/sail7_volcanic.png")
	# a locked lane bumps you back (Ocean needs level 100)
	VF.level = 60
	VF.changed.emit()
	t0 = Time.get_ticks_msec()
	var bumped := false
	while Time.get_ticks_msec() - t0 < 9000 and not bumped:
		_helm(1)
		await get_tree().process_frame
		bumped = vel.x < -100.0
	_helm(0)
	await _wait(0.3)
	print("SAIL locked biome=%s boat=%s state=%s bumped=%s" % [VF.biome, stage.boat_pos.round(), state, bumped])
	await main._shot(dir + "/sail8_locked.png")
	await _wait(1.0)
	# the Map's Travel button sails too
	VF.level = 3000
	VF.changed.emit()
	main._open_panel("biomes")
	await _wait(0.5)
	await main._shot(dir + "/sail9_map.png")
	var travel := []
	_find_buttons(main.panel_body, "Travel", travel)
	if travel.size() >= 3: (travel[2] as Button).pressed.emit()      # River, Ocean, Sky...
	await _wait(0.45)
	await main._shot(dir + "/sail10_map_wipe.png")
	await _wait(1.8)
	print("SAIL map biome=%s boat=%s state=%s overlay=%s" % [VF.biome, stage.boat_pos.round(), state, main.overlay.visible])
	await main._shot(dir + "/sail11_map_arrived.png")
	# every biome with its exits (level 300: Space and beyond are locked)
	VF.level = 300
	for b in VFData.BIOME_ORDER:
		VF.biome = b
		VF.changed.emit()
		await _wait(1.0)
		print("SAIL biome=%s lanes=%s boat=%s fits=%s vel=%s state=%s drag=%s keys=%s mouse=%s" % [b, lanes, stage.boat_pos.round(),
			_fits(stage.boat_pos), vel.round(), state, dragging, _keys(), Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)])
		await main._shot(dir + "/sail_biome_%s.png" % VFData.slug(b))
	# the touch wording of the hint
	VF.biome = "Ocean"
	VF.changed.emit()
	VF.sail_hint = false
	_hint_state = 0
	test_touch = true
	await _wait(3.2)
	print("SAIL hint state=%d shown=%s vel=%s boat=%s" % [_hint_state, _hint.visible, vel.round(), stage.boat_pos.round()])
	await main._shot(dir + "/sail12_hint_touch.png")

## test helm: hold D (side 1) / A (-1) and W / S to line up with that side's lane; 0 lets go
var _held := {}
func _helm(side: int) -> void:
	var want := {}
	if side != 0:
		want[KEY_D if side > 0 else KEY_A] = true
		if lanes.has(side):
			var dy: float = float(lanes[side].y) - stage.boat_pos.y
			if dy < -20.0: want[KEY_W] = true
			elif dy > 20.0: want[KEY_S] = true
	for k in [KEY_A, KEY_D, KEY_W, KEY_S]:
		var on: bool = want.has(k)
		if on != bool(_held.get(k, false)):
			_held[k] = on
			_key(k, on)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _key(k: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)

func _mouse(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)

func _motion(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)

func _find_buttons(n: Node, text: String, out: Array) -> void:
	if n is Button and (n as Button).text == text: out.append(n)
	for c in n.get_children(): _find_buttons(c, text, out)

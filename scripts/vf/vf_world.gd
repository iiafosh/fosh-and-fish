extends RefCounted
## The world around the boat (vf_main): weather that comes and goes, hot spots on the water worth aiming at, and secrets
## that only turn up in the right weather: gold where a rainbow ends, a falling star to wish on. The rules are in VFData
## (WEATHER, FISH_LIKES, SPOTS) and VF (world, cast_bonus, conditions). Nothing here is saved.

## how each kind of weather looks: the veil's shader (shaders/vf_weather.gdshader) and the wind in the trees
const LOOKS := {
	"rain": {"rain": 1.0, "gloom": 0.45, "wind": 0.6}, "storm": {"rain": 1.0, "gloom": 1.0, "wind": 1.4}, "fog": {"fog": 1.0},
	"ash": {"ash": 1.0, "gloom": 0.35}, "aurora": {"aurora": 1.0}, "bloom": {"bloom": 1.0}, "meteors": {},
}
const FOG_COL := {"Abyss": Color(0.36, 0.52, 0.62), "Alien": Color(0.74, 0.95, 0.86)}
const LINES := {
	"rain": ["Rain. The fish don't mind. I do.", "Free water. As if we were short.", "Good fishing weather. Bad hat weather."],
	"storm": ["A storm! The big ones come up for this.", "If I get struck, tell the fish I won.", "Lovely day. For a fish."],
	"fog": ["Fog. Things wash up in fog.", "Can't see a thing. Neither can the fish."],
	"ash": ["Ash again. The volcano's cooking.", "It's snowing. Warm snow. Don't eat it."],
	"meteors": ["Meteor shower! Tap one and make a wish.", "The sky is falling. Politely."],
	"aurora": ["Look at that sky. The fish are staring too.", "Free light show. I'd have paid."],
	"bloom": ["The water's glowing. That's either good or very bad.", "Glow bloom. The fish love it. I'm undecided."],
}
const STRIKE_LINES := ["That one had my name on it. Misspelled, luckily.", "MISSED ME!", "The sea just got seasoned."]
const RAINBOW := ["#ff5a5a", "#ffa24a", "#ffe45a", "#6bdc6b", "#5ab4ff", "#6a6aff", "#b46aff"]
const RAINBOW_BIOMES := ["River", "Ocean", "Sky", "Alien"]
const RAINBOW_LIFE := 45.0
const SPOT_COL := {"school": Color("#dff8ff"), "shadow": Color("#c9a6ff"), "gold": Color("#ffd24a")}
const SQUASH := 0.58              # a circle lying on the water, seen from the game's camera

var m                             # vf_main
var stage
var weather := "clear"
var amount := 0.0                 # how far the spell has come in (0..1): it fades in and out
var spots: Array = []             # [{kind, pos, t, life, hits, gone}]
var rainbow := {}                 # {t, life, end, taken}
var stars: Array = []             # falling stars [{from, to, t, secs}]
var wish := false                 # a wish is waiting for your next cast
var veil: ColorRect
var water_layer: Control          # hot spots: on the water, under the boats
var air_layer: Control            # the rainbow, lightning
var glow_layer: Control           # falling stars, glints (added light)
var pill: PanelContainer
var pill_icon: TextureRect
var pill_title: Label
var pill_sub: Label
var _left := 60.0                 # seconds of this spell, or of clear sky, still to go
var _ending := false
var _last := ""
var _spot_wait := 12.0
var _star_wait := 14.0
var _wish_cd := 0.0
var _bolt := {}                   # {pts, t}
var _bolt_wait := 5.0
var _flash := 0.0
var _drops := 0.0
var _t := 0.0
var _shown := "-"
var _tap_at := Vector2.INF        # where the scene was last tapped (a tap on a hot spot the line can't reach gets a word)

func _init(main) -> void:
	m = main
	stage = m.stage
	water_layer = _layer(_draw_water)
	stage.root.move_child(water_layer, stage.caustics.get_index() + 1)
	air_layer = _layer(_draw_air)
	glow_layer = _layer(_draw_glow)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = add
	veil = ColorRect.new()
	veil.size = stage.SCENE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/vf_weather.gdshader")
	vm.set_shader_parameter("noise", stage._tex("fx/noise.png"))
	veil.material = vm
	veil.visible = false
	stage.root.add_child(veil)
	stage.scene_changed.connect(_on_scene)
	_left = randf_range(45.0, 90.0)
	_build_pill()

func _layer(cb: Callable) -> Control:
	var c := Control.new()
	c.size = stage.SCENE
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(cb)
	stage.root.add_child(c)
	return c

## the HUD's weather pill: what the sky is doing, what it does to a cast, and which fish like it. A tap opens the Fish Book.
func _build_pill() -> void:
	pill = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", m.pill_box(false, 10, 5))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.mouse_filter = Control.MOUSE_FILTER_STOP
	pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pill.tooltip_text = "The weather and the hour change what bites. The Fish Book says when each fish bites best."
	pill.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: m._open_panel("inventory"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pill_icon = m.icon(m.ph("drop"), 18)
	h.add_child(pill_icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	pill_title = m.lbl("", 13, Color.WHITE)
	pill_sub = m.lbl("", 10, Color(1, 1, 1, 0.75))
	v.add_child(pill_title)
	v.add_child(pill_sub)
	h.add_child(v)
	pill.add_child(h)
	pill.visible = false
	m.hud_col.add_child(pill)

func _show_pill() -> void:
	var w := String(VF.world.weather)
	var title := ""
	var icon := "star"
	var hour := ""
	if VF.world.night: hour = "Night"
	elif VF.world.dusk: hour = "Dawn" if stage.day_t > 0.9 or stage.day_t < 0.1 else "Dusk"
	var subs := PackedStringArray()
	if w != "clear":
		var d: Dictionary = VFData.WEATHER[w]
		title = String(d.name) + ("" if hour == "" else " · " + hour)
		icon = String(d.icon)
		subs.append(String(d.tip))
	elif hour != "":
		title = hour
		icon = "star" if hour == "Night" else "sun-horizon"
	var biting: Array = VF.biting_now()
	if biting.size() > 3: biting = biting.slice(biting.size() - 3)        # (the rarest ones: they're the news)
	if not biting.is_empty(): subs.append("Biting: " + ", ".join(PackedStringArray(biting)))
	if wish:
		subs.insert(0, "Wish: +%d%% fish, next cast" % int(VFData.WISH_FISH * 100.0))
		if title == "": title = "A wish"
		icon = "shooting-star"
	var on: bool = title != "" and VF.tutorial >= 99 and VF.level >= VFData.SPOT_LEVEL and not (m.compact() and subs.is_empty())
	var key := "%s|%s|%s" % [title, " · ".join(subs), on]
	if key == _shown: return
	_shown = key
	pill.visible = on
	pill_title.text = title
	pill_sub.text = " · ".join(subs)
	pill_sub.visible = not subs.is_empty()
	pill_icon.texture = m.ph(icon)

## a new biome: its own sky, clear to begin with
func _on_scene() -> void:
	weather = "clear"
	amount = 0.0
	_ending = false
	_left = randf_range(45.0, 90.0)
	spots.clear()
	stars.clear()
	rainbow = {}
	_bolt = {}
	_flash = 0.0

func tick(delta: float) -> void:
	_t += delta
	var live: bool = VF.tutorial >= 99 and VF.level >= VFData.SPOT_LEVEL and not m.launcher_open()
	_tick_weather(delta, live)
	_note_world()
	var busy: bool = not live or m.overlay.visible or m.minigame != null or m._phone_open() or (m.derby != null and m.derby.running)
	_tick_spots(delta, busy)
	_tick_secrets(delta, busy)
	_show_veil()
	if int(_t * 4.0) != int((_t - delta) * 4.0): _show_pill()
	water_layer.queue_redraw()
	air_layer.queue_redraw()
	glow_layer.queue_redraw()

## what VF's rules read: the weather while it's really on, and the hour
func _note_world() -> void:
	var day: bool = stage._fx_on and stage.DAYLIGHT.has(VF.biome)
	var d: float = stage.day_t
	var night: bool = day and stage._day_phase(d).x > 0.5
	var low: bool = day and not night and ((d > 0.47 and d < 0.62) or d > 0.9 or d < 0.03)
	VF.world = {"weather": "clear" if _ending else weather, "night": night, "dusk": low}

# ------------------------------------------------------------ the weather
func _tick_weather(delta: float, live: bool) -> void:
	_flash = maxf(0.0, _flash - delta * 2.4)
	if not _bolt.is_empty():
		_bolt.t += delta
		if _bolt.t > 0.32: _bolt = {}
	if weather == "clear":
		amount = 0.0
		if not live: return
		_left -= delta
		if _left <= 0.0: start(_pick())
		return
	if _ending:
		amount = maxf(0.0, amount - delta / 6.0)
		if amount <= 0.0:
			weather = "clear"
			_ending = false
			_left = randf_range(VFData.WEATHER_CLEAR[0], VFData.WEATHER_CLEAR[1])
		return
	amount = minf(1.0, amount + delta / 5.0)
	_left -= delta
	if _left <= 0.0:
		stop()
		return
	_tick_sky(delta)

func _pick() -> String:
	var all: Array = VFData.BIOME_WEATHER.get(VF.biome, [])
	var pool := all.filter(func(w): return w != _last)
	if pool.is_empty(): pool = all
	return "clear" if pool.is_empty() else String(pool.pick_random())

## a spell begins (secs: how long, 0 = the usual)
func start(id: String, secs := 0.0) -> void:
	if id == "clear" or not VFData.WEATHER.has(id): return
	weather = id
	_last = id
	_ending = false
	_left = secs if secs > 0.0 else randf_range(VFData.WEATHER_SPELL[0], VFData.WEATHER_SPELL[1])
	_bolt_wait = randf_range(4.0, 8.0)
	_star_wait = 1.5
	if not stage.talking(): stage.say(String((LINES[id] as Array).pick_random()), 3.6)

## ... and blows over. After rain, by day, a rainbow
func stop() -> void:
	if weather == "clear" or _ending: return
	_ending = true
	if weather in ["rain", "storm"] and VF.biome in RAINBOW_BIOMES and stage._fx_on and stage.night_amount < 0.3: _start_rainbow()

func _show_veil() -> void:
	var look: Dictionary = LOOKS.get(weather, {})
	var on: bool = stage._fx_on and (amount > 0.0 or _flash > 0.0)
	veil.visible = on
	stage.gust = amount * float(look.get("wind", 0.0)) if stage._fx_on else 0.0
	if not on: return
	var mat := veil.material as ShaderMaterial
	var dark: float = stage.night_amount
	for k in ["rain", "fog", "ash", "aurora", "bloom"]:
		mat.set_shader_parameter(k, float(look.get(k, 0.0)) * amount)
	mat.set_shader_parameter("gloom", float(look.get("gloom", 0.0)) * amount * (1.0 - 0.55 * dark))
	mat.set_shader_parameter("flash", _flash)
	var fog: Color = FOG_COL.get(VF.biome, Color(0.9, 0.94, 0.96))
	mat.set_shader_parameter("fog_col", fog.darkened(0.5 * dark))

## rain on the water, lightning
func _tick_sky(delta: float) -> void:
	if not stage._fx_on: return
	if float(LOOKS.get(weather, {}).get("rain", 0.0)) > 0.0:
		_drops += delta * 16.0 * amount
		while _drops >= 1.0:
			_drops -= 1.0
			var q := Vector2(randf() * stage.SCENE.x, randf() * stage.SCENE.y)
			if stage._in_water(q, 0.03): stage._add_ripple(q, randf_range(9.0, 18.0), 1.0)
	if weather == "storm" and amount > 0.6:
		_bolt_wait -= delta
		if _bolt_wait <= 0.0:
			_bolt_wait = randf_range(7.0, 15.0)
			strike()

## lightning hits the water. Sometimes it stuns a school: a hot spot right there
func strike() -> void:
	var v := _view()
	var to = stage._rand_point(func(q): return stage.open_water(q, 70.0) and _in_view(q, v), 80)
	if to == null: to = stage.SCENE * Vector2(randf_range(0.25, 0.75), 0.62)
	var pts := PackedVector2Array()
	var from := Vector2(to.x + randf_range(-260.0, 260.0), -30.0)
	for i in 10:
		var p: Vector2 = from.lerp(to, i / 9.0)
		if i > 0 and i < 9: p.x += randf_range(-48.0, 48.0)
		pts.append(p)
	_bolt = {"pts": pts, "t": 0.0}
	_flash = 1.0
	stage.splash(to, 1.6)
	stage.burst("splash", to)
	m.get_tree().create_timer(0.3).timeout.connect(func(): AudioManager.play_fun("thunder", -13.0, randf_range(0.85, 1.1)))
	if spots.is_empty() and randf() < 0.5 and stage.open_water(to, 70.0):
		spawn_spot("school", to)
		if not stage.talking(): stage.say("Lightning stunned a few. Cast there!", 3.2)
	elif randf() < 0.3 and not stage.talking():
		stage.say(String(STRIKE_LINES.pick_random()), 3.0)

## on screen, clear of the edges and of what's drawn over the stage. v: _view(), looked up once for a whole search
func _in_view(q: Vector2, v: Dictionary) -> bool:
	var at: Vector2 = stage.to_screen(q)
	if not (v.rect as Rect2).has_point(at): return false
	return not (v.hud as Array).any(func(r): return r.has_point(at))

func _view(edge := 70.0, hud_gap := 20.0) -> Dictionary:
	var k: float = stage.root.scale.x
	return {"rect": Rect2(stage.global_position, stage.size).grow(-edge * k), "hud": stage._hud_rects(hud_gap * k)}

# ------------------------------------------------------------ hot spots
func _tick_spots(delta: float, busy: bool) -> void:
	for s in spots:
		s.t += delta
		if s.gone >= 0.0: s.gone += delta
	spots = spots.filter(func(s): return s.t < s.life and s.gone < 0.5)
	if busy or not spots.is_empty(): return
	_spot_wait -= delta * (1.4 if String(VF.world.weather) in ["rain", "storm", "bloom"] else 1.0)
	if _spot_wait <= 0.0:
		_spot_wait = randf_range(VFData.SPOT_EVERY[0], VFData.SPOT_EVERY[1])
		spawn_spot(_pick_spot())

func _pick_spot() -> String:
	var total := 0.0
	for k in VFData.SPOT_ORDER: total += float(VFData.SPOTS[k].weight)
	var roll := randf() * total
	for k in VFData.SPOT_ORDER:
		roll -= float(VFData.SPOTS[k].weight)
		if roll <= 0.0: return k
	return "school"

## a hot spot turns up: where you can reach it most of the time, now and then further out (sail there)
func spawn_spot(kind: String, at = null) -> void:
	if at == null:
		var v := _view(100.0, VFData.SPOT_R)          # (the whole ring in the clear, not just its middle)
		var shop: Rect2 = stage._shop_rect().grow(120.0)
		var near := randf() < 0.75
		at = stage._rand_point(func(q):
			if not stage.open_water(q, 70.0) or shop.has_point(q): return false
			var d: float = q.distance_to(stage.boat_pos)
			if d < 240.0 or (near and d > stage.MAX_CAST * 0.9): return false
			return _in_view(q, v), 400)
		if at == null: return
	spots.append({"kind": kind, "pos": at, "t": 0.0, "life": VFData.SPOT_LIFE, "hits": int(VFData.SPOTS[kind].hits), "gone": -1.0})
	if int(VF.stats.get("spots", 0)) == 0 and not stage.talking(): stage.say("Something's stirring out there. Cast right into the ring!", 4.0)

## how much of its radius counts as the middle (a fingertip is blunter than a pointer)
func _bull() -> float:
	return VFData.SPOT_BULL * (1.35 if m.is_touch() else 1.0)

func _spot_alpha(s: Dictionary) -> float:
	var a := clampf(s.t / 0.5, 0.0, 1.0) * clampf((s.life - s.t) / 1.2, 0.0, 1.0)
	if s.life - s.t < 6.0: a *= 0.6 + 0.4 * sin(s.t * 9.0)           # about to go
	if s.gone >= 0.0: a *= 1.0 - s.gone / 0.5
	return a

## the float just landed (vf_main, every cast): in a hot spot? Then this cast gets its bonus (VF.cast_bonus), and a wish too
func cast_landed(outlaw := false) -> void:
	var tapped := _tap_at
	_tap_at = Vector2.INF
	if outlaw: return
	var p: Vector2 = stage._bobber
	var bonus := {}
	for s in spots:
		if s.gone >= 0.0: continue
		var d := Vector2(p.x - s.pos.x, (p.y - s.pos.y) / SQUASH).length()
		if d > VFData.SPOT_R: continue
		var bull: bool = d <= VFData.SPOT_R * _bull()
		bonus = (VFData.SPOTS[s.kind].bull if bull else VFData.SPOTS[s.kind].edge).duplicate()
		bonus["kind"] = s.kind
		bonus["bull"] = bull
		s.hits -= 1
		if s.hits <= 0: s.gone = 0.0
		_spot_hit(bonus, p)
		break
	if bonus.is_empty() and tapped != Vector2.INF and not stage.talking():      # you tapped one, but the line doesn't reach
		for s in spots:
			if s.gone < 0.0 and Vector2(tapped.x - s.pos.x, (tapped.y - s.pos.y) / SQUASH).length() <= VFData.SPOT_R:
				stage.say("Too far. Sail closer!", 2.6)
				break
	if wish:
		wish = false
		bonus["fish"] = float(bonus.get("fish", 0.0)) + VFData.WISH_FISH
		if not bonus.has("kind"): m._float_text("Wish granted!", stage.to_screen(p) + Vector2(0, -70), m.C_GOLD)
	if not bonus.is_empty(): VF.cast_bonus = bonus

func _spot_hit(bonus: Dictionary, p: Vector2) -> void:
	var what := ""
	if bonus.has("fish"): what = "+%d%% fish" % int(float(bonus.fish) * 100.0)
	elif bonus.has("quality"): what = "rarer fish ×%d" % int(bonus.quality)
	elif VF.level >= 10: what = "chest chance ×%d" % int(bonus.get("chest", 1.0))
	var head := "BULLSEYE!" if bonus.bull else "Hot spot!"
	m._float_text(("%s %s" % [head, what]).strip_edges(), stage.to_screen(p) + Vector2(-60, -104), m.C_GOLD if bonus.bull else Color.WHITE)
	if bonus.has("coins"): m.fun._pay(float(bonus.coins), p)
	stage.burst("sparkle", p)
	AudioManager.play_fun("ding", -9.0, 1.3 if bonus.bull else 1.0)
	VFHaptics.buzz("rare" if bonus.bull else "poke")

# ------------------------------------------------------------ secrets: a rainbow's end, a falling star
func _tick_secrets(delta: float, busy: bool) -> void:
	_wish_cd -= delta
	if not rainbow.is_empty():
		rainbow.t += delta
		if rainbow.t > rainbow.life: rainbow = {}
	for s in stars:
		s.t += delta / s.secs
		if s.t >= 1.0 and weather == "meteors" and stage._in_water(s.to, 0.03):       # a meteor comes down in the water
			stage.splash(s.to, 0.8)
			if spots.is_empty() and randf() < 0.12 and stage.open_water(s.to, 70.0): spawn_spot("gold", s.to)
	stars = stars.filter(func(s): return s.t < 1.0)
	if busy or not stage._fx_on: return
	var shower: bool = weather == "meteors" and not _ending and amount > 0.5
	if not shower and not (VF.world.night and weather == "clear"): return
	_star_wait -= delta
	if _star_wait <= 0.0:
		_star_wait = randf_range(1.6, 3.2) if shower else randf_range(22.0, 45.0)
		spawn_star(1.0 if shower else 1.3)

## one falls across what you can see of the scene (slow: how much longer it takes than a meteor)
func spawn_star(slow := 1.0) -> void:
	var a: Vector2 = stage.to_scene(stage.global_position)
	var b: Vector2 = stage.to_scene(stage.global_position + stage.size)
	var dir := Vector2(1.0 if randf() < 0.5 else -1.0, randf_range(0.35, 0.7)).normalized()
	var from := Vector2(lerpf(a.x, b.x, randf_range(0.3, 0.7) - dir.x * 0.22), lerpf(a.y, b.y, randf_range(0.06, 0.34)))
	stars.append({"from": from, "to": from + dir * randf_range(560.0, 760.0), "t": 0.0, "secs": randf_range(1.5, 1.9) * slow})

func _start_rainbow() -> void:
	var v := _view(110.0)
	var end = stage._rand_point(func(q): return stage.open_water(q, 60.0) and q.x > stage.SCENE.x * 0.4 and _in_view(q, v), 300)
	if end == null: return
	rainbow = {"t": 0.0, "life": RAINBOW_LIFE, "end": end, "taken": false}
	stage.say("A rainbow! They say there's gold where it ends.", 4.0)

## a tap on the scene (vf_main, before a cast): a falling star, or the rainbow's end
func tap(screen: Vector2) -> bool:
	var p: Vector2 = stage.to_scene(screen)
	_tap_at = p
	var slack: float = stage.TAP_MIN / stage.root.scale.x if m.is_touch() else 0.0
	for s in stars:
		var head: Vector2 = (s.from as Vector2).lerp(s.to, s.t)
		var tail: Vector2 = head - (s.to - s.from).normalized() * 150.0
		if Geometry2D.get_closest_point_to_segment(p, tail, head).distance_to(p) <= 46.0 + slack:
			stars.erase(s)
			_wished(head)
			return true
	if not rainbow.is_empty() and not rainbow.taken and rainbow.t > 1.5 and p.distance_to(rainbow.end) <= 64.0 + slack:
		rainbow.taken = true
		rainbow.life = rainbow.t + 2.5
		VF.stat_add("rainbows")
		stage.burst("sparkle", rainbow.end)
		m.fun._pay(4.0, rainbow.end)
		stage.say("Gold! Wet gold, but gold.", 3.0)
		VFHaptics.buzz("rare")
		return true
	return false

func _wished(at: Vector2) -> void:
	stage.burst("sparkle", at)
	VFHaptics.buzz("poke")
	if wish or _wish_cd > 0.0:                    # one wish at a time: the rest are just pretty, and worth a coin
		m.fun._pay(0.3, at)
		return
	wish = true
	_wish_cd = 20.0
	_shown = "-"
	VF.stat_add("wishes")
	AudioManager.play_fun("ding", -8.0, 1.5)
	m._float_text("Wish made! Next cast: +%d%% fish" % int(VFData.WISH_FISH * 100.0), stage.to_screen(at) + Vector2(-90, -40), m.C_GOLD)
	if not stage.talking(): stage.say(["Wished for fish. Classic.", "I wished for a bigger boat. We'll see.", "Don't tell anyone what you wished. It was fish."].pick_random(), 3.2)

# ------------------------------------------------------------ drawing
func _draw_water() -> void:
	var c := water_layer
	var u: float = float(stage._scene.get("unit_px", 56.0))
	var sp: Array = stage._species.filter(func(e): return e.get("tex") != null)
	var dark_water: bool = stage.water_tint.get_luminance() < 0.12
	for s in spots:
		var a := _spot_alpha(s)
		var col: Color = SPOT_COL[s.kind]
		var r: float = VFData.SPOT_R
		c.draw_set_transform(s.pos, 0.0, Vector2(1.0, SQUASH))
		c.draw_circle(Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.09 * a))
		c.draw_arc(Vector2.ZERO, r * (0.95 + 0.05 * sin(s.t * 3.0)), 0.0, TAU, 56, Color(col.r, col.g, col.b, 0.75 * a), 4.0, true)
		var out := fmod(s.t * 0.6, 1.0)             # a ring going out, so it catches the eye
		c.draw_arc(Vector2.ZERO, r * (1.0 + 0.35 * out), 0.0, TAU, 56, Color(col.r, col.g, col.b, 0.45 * a * (1.0 - out)), 2.0, true)
		c.draw_arc(Vector2.ZERO, r * _bull(), 0.0, TAU, 32, Color(col.r, col.g, col.b, 0.9 * a), 2.5, true)
		if s.kind == "school":                # bubbles coming up
			for i in 7:
				var k := fmod(s.t * 0.55 + i * 0.37, 1.0)
				var o := Vector2.from_angle(i * 2.4) * r * (0.15 + 0.5 * fmod(i * 0.618, 1.0))
				c.draw_arc(o, 3.0 + 9.0 * k, 0.0, TAU, 14, Color(1, 1, 1, (1.0 - k) * 0.8 * a), 1.6, true)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if s.kind == "school" and not sp.is_empty():           # the biome's own fish, going round
			for i in 5:
				var ang: float = s.t * 0.9 + i * TAU / 5.0
				var q: Vector2 = s.pos + Vector2(cos(ang), sin(ang) * SQUASH) * r * 0.6
				stage._life_draw(c, sp[i % sp.size()], q, Vector2(-sin(ang), cos(ang) * SQUASH).angle(), u * 0.62, Color(1, 1, 1, 0.9 * a), i * 1.3)
		elif s.kind == "shadow" and not sp.is_empty():         # one big shape, circling (pale on the darkest water)
			var ang: float = s.t * 0.45
			var q: Vector2 = s.pos + Vector2(cos(ang), sin(ang) * SQUASH) * r * 0.3
			var shade := Color(3.0, 3.4, 4.0, 0.4 * a) if dark_water else Color(0.0, 0.02, 0.08, 0.55 * a)
			stage._life_draw(c, sp[sp.size() - 1], q, Vector2(-sin(ang), cos(ang) * SQUASH).angle(), u * 2.6, shade)
		elif s.kind == "gold":
			for i in 6:
				var tw := 0.5 + 0.5 * sin(s.t * 4.0 + i * 1.9)
				var o := Vector2.from_angle(i * 2.2 + 0.6) * r * (0.12 + 0.42 * fmod(i * 0.618, 1.0))
				var sz := 14.0 + 22.0 * tw
				c.draw_texture_rect(stage._star_tex, Rect2(s.pos + Vector2(o.x, o.y * SQUASH) - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(1.0, 0.86, 0.35, (0.35 + 0.65 * tw) * a))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_air() -> void:
	if not rainbow.is_empty():
		var a := clampf(rainbow.t / 3.0, 0.0, 1.0) * clampf((rainbow.life - rainbow.t) / 2.5, 0.0, 1.0)
		var rr := 1150.0
		var centre: Vector2 = rainbow.end + Vector2(-rr * 0.866, rr * 0.5)       # (its end is on the circle, up and to the right)
		for i in RAINBOW.size():
			var col := Color(String(RAINBOW[i]))
			air_layer.draw_arc(centre, rr + (3 - i) * 10.0, deg_to_rad(-168.0), deg_to_rad(-30.0), 72, Color(col.r, col.g, col.b, 0.3 * a), 10.5, true)
	if not _bolt.is_empty():
		var k: float = 1.0 - _bolt.t / 0.32
		air_layer.draw_polyline(_bolt.pts, Color(0.75, 0.85, 1.0, 0.45 * k), 14.0, true)
		air_layer.draw_polyline(_bolt.pts, Color(1, 1, 1, k), 4.0, true)

func _draw_glow() -> void:
	if stage._glow_tex == null: return
	for s in stars:
		var dir: Vector2 = (s.to - s.from).normalized()
		var head: Vector2 = (s.from as Vector2).lerp(s.to, s.t)
		var a := clampf(s.t / 0.12, 0.0, 1.0) * clampf((1.0 - s.t) / 0.2, 0.0, 1.0)
		var col := Color(1.0, 0.78, 0.5) if weather == "meteors" else Color(0.9, 0.95, 1.0)
		for i in 9:
			var k := i / 9.0
			glow_layer.draw_line(head - dir * 170.0 * k, head - dir * 170.0 * (k + 0.111), Color(col.r, col.g, col.b, a * 0.7 * (1.0 - k)), 5.0 * (1.0 - k) + 1.0, true)
		_glow(head, 46.0, col, 0.7 * a)
		_glow(head, 16.0, Color.WHITE, a)
	if not rainbow.is_empty() and not rainbow.taken:
		var a := clampf(rainbow.t / 3.0, 0.0, 1.0) * clampf((rainbow.life - rainbow.t) / 2.5, 0.0, 1.0)
		_glow(rainbow.end, 64.0, Color(1.0, 0.85, 0.35), 0.4 * a * (0.7 + 0.3 * sin(_t * 5.0)))
		for i in 4:
			var tw := 0.5 + 0.5 * sin(_t * 5.0 + i * 1.7)
			var sz := 12.0 + 20.0 * tw
			glow_layer.draw_texture_rect(stage._star_tex, Rect2(rainbow.end + Vector2.from_angle(i * 1.9) * 26.0 - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(1.0, 0.9, 0.5, tw * a))
	for s in spots:                           # after dark a spot keeps its own light
		var col: Color = SPOT_COL[s.kind]
		_glow(s.pos, VFData.SPOT_R * 1.15, col, 0.2 * stage.night_amount * _spot_alpha(s), SQUASH)
	if not _bolt.is_empty():
		_glow(_bolt.pts[9], 170.0, Color(0.8, 0.9, 1.0), 0.7 * (1.0 - _bolt.t / 0.32))

func _glow(p: Vector2, r: float, c: Color, a: float, squash := 1.0) -> void:
	glow_layer.draw_texture_rect(stage._glow_tex, Rect2(p.x - r, p.y - r * squash, r * 2.0, r * 2.0 * squash), false, Color(c.r, c.g, c.b, a))

# ------------------------------------------------------------ tests
## godot --path . --resolution 1280x720 -- --capture=DIR --world-test : every kind of weather, the three hot spots with a
## cast into each, lightning, the rainbow and its gold, a falling star and a wish. Prints WORLD lines. Never saves.
func capture_test(dir: String) -> void:
	VF.trip_done.connect(func(res): print("WORLD cast: spot='%s' bull=%s fish=%d chest=%s" % [res.spot, res.bull, res.count, not res.chest.is_empty()]))
	await m._wait(1.5)
	stage.set_time_of_day(0.3)
	start("rain", 999.0)
	amount = 1.0
	spawn_spot("school")
	await m._wait(1.6)
	print("WORLD rain: world=%s biting=%s spots=%d pill='%s | %s'" % [VF.world, VF.biting_now(), spots.size(), pill_title.text, pill_sub.text])
	await m._shot(dir + "/w01_rain_school.png")
	await _test_cast(dir + "/w02_bullseye.png", Vector2.ZERO)
	await m._wait(1.0)
	VF.discovered["Cod"] = 3
	m._open_panel("inventory")
	await m._wait(0.5)
	m.panel_scroll.scroll_vertical = 100000
	await m._wait(0.3)
	await m._shot(dir + "/w02b_fish_book.png")
	m._close_panel()
	await m._wait(0.4)
	spots.clear()
	start("storm", 999.0)
	amount = 1.0
	spawn_spot("shadow")
	await m._wait(1.0)
	strike()
	await m._wait(0.07)
	await m._shot(dir + "/w03_storm_strike.png")
	await _test_cast(dir + "/w04_shadow_edge.png", Vector2(VFData.SPOT_R * 0.75, 0.0))
	spots.clear()
	stop()
	amount = 0.0
	await m._wait(4.0)
	print("WORLD rainbow: %s" % [not rainbow.is_empty()])
	await m._shot(dir + "/w05_rainbow.png")
	if not rainbow.is_empty():
		var m0: int = VF.money
		print("WORLD rainbow tap beside -> %s, on it -> %s, paid %d" % [tap(stage.to_screen(rainbow.end + Vector2(160, 0))), tap(stage.to_screen(rainbow.end)), VF.money - m0])
		await m._wait(0.5)
		await m._shot(dir + "/w06_gold.png")
	rainbow = {}
	start("fog", 999.0)
	amount = 1.0
	spawn_spot("gold")
	await m._wait(1.2)
	await m._shot(dir + "/w07_fog_gold.png")
	await _test_cast(dir + "/w08_gold_hit.png", Vector2.ZERO)
	weather = "clear"
	amount = 0.0
	spots.clear()
	stage.set_time_of_day(0.75)
	spawn_spot("school")
	spawn_star(4.0)
	await m._wait(2.6)
	print("WORLD night: world=%s biting=%s" % [VF.world, VF.biting_now()])
	await m._shot(dir + "/w09_night_star.png")
	var s0: Dictionary = stars[0]
	print("WORLD star tap far -> %s, on it -> %s, wish=%s" % [tap(stage.to_screen(s0.from + Vector2(0, 400))), tap(stage.to_screen((s0.from as Vector2).lerp(s0.to, s0.t))), wish])
	await m._wait(0.6)
	await m._shot(dir + "/w10_wish.png")
	await _test_cast(dir + "/w11_wish_cast.png", Vector2(400, 0))
	spots.clear()
	# one the line can't reach: the captain says so
	var far = stage._rand_point(func(q): return stage.open_water(q, 70.0) and q.distance_to(stage.boat_pos) > stage.MAX_CAST + 140.0, 2000)
	if far != null:
		spawn_spot("school", far)
		stage._say_t = 0.0
		await _test_cast(dir + "/w12_too_far.png", Vector2.ZERO)
		print("WORLD too far: the captain says '%s', the spot is still there: %s" % [stage._say_text, spots.size() == 1])
		spots.clear()
	else:
		print("WORLD too far: no water out of reach in this scene")
	for row in [["Volcanic", "ash", 0.3], ["Ocean", "storm", 0.3], ["Sky", "aurora", 0.75], ["Space", "meteors", 0.3], ["Alien", "aurora", 0.75], ["Alien", "fog", 0.3], ["Abyss", "bloom", 0.3], ["Abyss", "fog", 0.3]]:
		VF.biome = row[0]
		VF.changed.emit()
		await m._wait(0.4)
		stage.set_time_of_day(row[2])
		start(row[1], 999.0)
		amount = 1.0
		spots.clear()
		spawn_spot(VFData.SPOT_ORDER[randi() % 3])
		if row[1] == "meteors":
			for i in 3: spawn_star(1.6 + i * 0.5)
		await m._wait(1.4)
		print("WORLD %s %s: world=%s biting=%s pill='%s | %s'" % [row[0], row[1], VF.world, VF.biting_now(), pill_title.text, pill_sub.text])
		await m._shot(dir + "/w20_%s_%s.png" % [String(row[0]).to_lower(), row[1]])

## cast at the first hot spot (off: how far from its middle), wait for the catch, take the picture while the words are up
func _test_cast(path: String, off: Vector2) -> void:
	if spots.is_empty():
		print("WORLD no spot to cast at")
		return
	VF._last_cast_ms = -100000
	var at: Vector2 = spots[0].pos + off
	m._tap(m.get_viewport().get_screen_transform() * stage.to_screen(at))        # (a phone-sized run scales the layout)
	await m._wait(1.0)
	print("WORLD cast at %s (%.0f from the boat, reach %.0f): the float landed %.0f away" % [at.round(), at.distance_to(stage.boat_pos), stage.MAX_CAST, stage._bobber.distance_to(at)])
	await m._shot(path)
	await m._wait(1.6)

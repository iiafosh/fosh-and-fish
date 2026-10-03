extends Node2D

@onready var overworld = get_parent()

# --- Assets ---
var tex_fisherman_idle: Array[Texture2D] = []
var tex_fisherman_walk: Array[Texture2D] = []
var tex_fisherman_fish: Texture2D
var tex_boat_sprite: Texture2D

func _ready() -> void:
	for i in range(1, 5):
		var idle_path = "res://web/assets/finding_sobron/sprites/fisherman/idle/idle-%d.png" % i
		var walk_path = "res://web/assets/finding_sobron/sprites/fisherman/walking/walking-%d.png" % i
		if ResourceLoader.exists(idle_path):
			tex_fisherman_idle.append(load(idle_path))
		if ResourceLoader.exists(walk_path):
			tex_fisherman_walk.append(load(walk_path))

	var fish_path = "res://web/assets/finding_sobron/sprites/fisherman/fishing mode/fishing-mode.png"
	if ResourceLoader.exists(fish_path):
		tex_fisherman_fish = load(fish_path)

	var boat_path = "res://web/assets/finding_sobron/sprites/boat/boat.png"
	if ResourceLoader.exists(boat_path):
		tex_boat_sprite = load(boat_path)

func _draw() -> void:
	var t = Time.get_ticks_msec() * 0.001
	var deck_y = 0.0
	var cur_boat = GameManager.current_boat
	var b_info = GameManager.boats_database.get(cur_boat, {})
	var visual_style = b_info.get("visual_style", cur_boat)

	# --- 1. LAYER 1: TRAILING AUTO-TRAWLER NET (WORKER SYSTEM) ---
	if GameManager.worker_unlocked:
		_draw_trawler_net(t, deck_y)

	# --- 2. LAYER 2: BOAT HULL & SUPERSTRUCTURE (VISUAL MODELS) ---
	match visual_style:
		"Rowboat":
			_draw_rowboat(t, deck_y)
		"Fishing Boat":
			_draw_fishing_boat(t, deck_y)
		"Speedboat":
			_draw_speedboat(t, deck_y)
		"Hovercraft Vanguard":
			_draw_hovercraft(t, deck_y)
		"Luxury Yacht":
			_draw_luxury_yacht(t, deck_y)
		"Abyssal Submersible":
			_draw_abyssal_sub(t, deck_y)
		_:
			_draw_skiff(t, deck_y)

	# --- 3. LAYER 3: DECK STATIONS & INTERACTION PLAQUES ---
	_draw_stations(deck_y)

	# --- 4. LAYER 4: DEDICATED PIXEL FISHERMAN ---
	_draw_fisherman(t, deck_y)

	# --- 5. LAYER 5: COMPANION PET IN THE WAKE ---
	_draw_companion_pet(t)

	# --- 6. LAYER 6: FRONT BRASS GUARD RAILING ---
	_draw_guard_railing(deck_y)

# ==============================================================================
# HULL RENDERING: 7 DISTINCT TIERS
# ==============================================================================

# --- TIER 1: STANDARD SKIFF ---
func _draw_skiff(_t: float, deck_y: float) -> void:
	var w = 380.0
	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.5, deck_y),
		Vector2(-w * 0.44, deck_y + 44),
		Vector2(w * 0.36, deck_y + 44),
		Vector2(w * 0.50, deck_y - 8),
		Vector2(w * 0.42, deck_y)
	])
	draw_colored_polygon(hull_pts, Color("#78350f"))
	draw_polyline(hull_pts, Color("#451a03"), 2.5, true)

	# Planking
	for py in range(int(deck_y + 12), int(deck_y + 42), 9):
		draw_line(Vector2(-w * 0.46, py), Vector2(w * 0.38, py), Color(0.2, 0.09, 0.03, 0.4), 1.5)

	# Timber ribs
	for rx in range(int(-w * 0.40), int(w * 0.35), 45):
		draw_line(Vector2(rx, deck_y), Vector2(rx + 5, deck_y + 38), Color(0.25, 0.12, 0.04, 0.5), 2.0)

	# Rustic Stern Lantern Post
	draw_rect(Rect2(-w * 0.46, deck_y - 42, 4, 42), Color("#27272a"))
	draw_circle(Vector2(-w * 0.46 + 2, deck_y - 44), 8.0, Color(1.0, 0.85, 0.25, 0.35))
	draw_circle(Vector2(-w * 0.46 + 2, deck_y - 44), 4.0, Color(1.0, 0.95, 0.6, 0.95))

	# Wooden Rowing Thwart (Seat)
	draw_rect(Rect2(-30, deck_y - 12, 60, 10), Color("#b45309"))

	# Deck floor
	draw_rect(Rect2(-w * 0.48, deck_y, w * 0.90, 8), Color("#92400e"))

# --- TIER 2: ROWBOAT (VARNISHED DORY) ---
func _draw_rowboat(_t: float, deck_y: float) -> void:
	var w = 440.0
	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.49, deck_y),
		Vector2(-w * 0.42, deck_y + 48),
		Vector2(w * 0.38, deck_y + 48),
		Vector2(w * 0.50, deck_y - 12),
		Vector2(w * 0.44, deck_y)
	])
	# Deep forest green flared hull
	draw_colored_polygon(hull_pts, Color("#14532d"))
	draw_polyline(hull_pts, Color("#052e16"), 3.0, true)

	# Golden brass gunwale trim
	draw_line(Vector2(-w * 0.49, deck_y), Vector2(w * 0.44, deck_y), Color("#ca8a04"), 3.5)

	# Center wooden mast & cross-spar
	draw_rect(Rect2(-8, deck_y - 82, 6, 82), Color("#78350f"))
	draw_line(Vector2(-35, deck_y - 65), Vector2(35, deck_y - 65), Color("#854d0e"), 3.0)
	draw_line(Vector2(-8, deck_y - 82), Vector2(-w * 0.44, deck_y), Color(0.9, 0.9, 0.9, 0.4), 1.0)
	draw_line(Vector2(-8, deck_y - 82), Vector2(w * 0.40, deck_y), Color(0.9, 0.9, 0.9, 0.4), 1.0)

	# Twin resting wooden oars along the gunwales
	draw_line(Vector2(-100, deck_y - 6), Vector2(-180, deck_y + 35), Color("#d97706"), 3.0)
	draw_circle(Vector2(-180, deck_y + 35), 5.0, Color("#b45309"))

	# Fish storage crate on aft deck
	draw_rect(Rect2(-w * 0.38, deck_y - 24, 34, 24), Color("#854d0e"))
	draw_rect(Rect2(-w * 0.38 + 2, deck_y - 22, 30, 20), Color("#713f12"))
	draw_rect(Rect2(-w * 0.38 + 6, deck_y - 18, 22, 6), Color(0.7, 0.9, 1.0, 0.8)) # Ice

	# Deck floor
	draw_rect(Rect2(-w * 0.48, deck_y, w * 0.92, 8), Color("#a16207"))

# --- TIER 3: MOTOR TRAWLER (FISHING BOAT) ---
func _draw_fishing_boat(t: float, deck_y: float) -> void:
	var w = 540.0

	# Heavy navy blue commercial hull with crimson waterline
	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.48, deck_y),
		Vector2(-w * 0.42, deck_y + 54),
		Vector2(w * 0.38, deck_y + 54),
		Vector2(w * 0.49, deck_y - 14),
		Vector2(w * 0.42, deck_y)
	])
	draw_colored_polygon(hull_pts, Color("#1e3a8a"))
	draw_polyline(hull_pts, Color("#0f172a"), 3.0, true)

	# Crimson antifouling bottom band
	var keel_pts = PackedVector2Array([
		Vector2(-w * 0.44, deck_y + 34),
		Vector2(-w * 0.42, deck_y + 54),
		Vector2(w * 0.38, deck_y + 54),
		Vector2(w * 0.42, deck_y + 34)
	])
	draw_colored_polygon(keel_pts, Color("#991b1b"))

	# White Deck Bulwark
	draw_rect(Rect2(-w * 0.46, deck_y - 8, w * 0.88, 8), Color("#f1f5f9"))

	# Enclosed White Wheelhouse Cabin (Aft-Center)
	draw_rect(Rect2(-60, deck_y - 74, 95, 74), Color("#0f172a")) # Shadow frame
	draw_rect(Rect2(-56, deck_y - 70, 87, 70), Color("#e2e8f0")) # White cabin body
	# Glowing Wheelhouse Windows
	draw_rect(Rect2(-46, deck_y - 62, 28, 22), Color("#38bdf8"))
	draw_rect(Rect2(-10, deck_y - 62, 34, 22), Color("#38bdf8"))
	# Cabin Roof & Radar Dome
	draw_rect(Rect2(-62, deck_y - 78, 100, 8), Color("#0284c7"))
	draw_circle(Vector2(-12, deck_y - 84), 7.0, Color("#ffffff"))

	# Diesel Exhaust Stack & Animated Smoke Puffs
	draw_rect(Rect2(-74, deck_y - 72, 10, 72), Color("#334155"))
	draw_rect(Rect2(-76, deck_y - 76, 14, 6), Color("#1e293b"))
	for s in range(3):
		var s_t = fmod(t * 3.5 + s * 1.1, 3.0)
		var s_pos = Vector2(-71 - s_t * 6.0, deck_y - 80 - s_t * 14.0)
		var s_rad = 4.0 + s_t * 3.5
		var s_alpha = max(0.0, 0.65 - s_t * 0.20)
		draw_circle(s_pos, s_rad, Color(0.8, 0.85, 0.9, s_alpha))

	# Stern Gantry Trawler A-Frame
	draw_line(Vector2(-w * 0.45, deck_y), Vector2(-w * 0.40, deck_y - 60), Color("#475569"), 3.5)
	draw_line(Vector2(-w * 0.35, deck_y), Vector2(-w * 0.40, deck_y - 60), Color("#475569"), 3.5)
	draw_circle(Vector2(-w * 0.40, deck_y - 60), 5.0, Color("#f59e0b"))

	# Red & White Lifebuoy on Cabin Wall
	draw_circle(Vector2(16, deck_y - 25), 9.0, Color("#ef4444"))
	draw_circle(Vector2(16, deck_y - 25), 5.0, Color("#ffffff"))
	draw_circle(Vector2(16, deck_y - 25), 3.0, Color("#0f172a"))

	# Deck floor
	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.88, 9), Color("#475569"))

# --- TIER 4: SPEEDBOAT ---
func _draw_speedboat(t: float, deck_y: float) -> void:
	var w = 580.0
	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.49, deck_y),
		Vector2(-w * 0.44, deck_y + 42),
		Vector2(w * 0.38, deck_y + 42),
		Vector2(w * 0.50, deck_y - 18), # Razor sharp prow
		Vector2(w * 0.42, deck_y)
	])
	# Midnight blue aerodynamic racing hull
	draw_colored_polygon(hull_pts, Color("#0f172a"))
	draw_polyline(hull_pts, Color("#1e293b"), 3.0, true)

	# Electric cyan dynamic racing stripe
	var stripe_pts = PackedVector2Array([
		Vector2(-w * 0.48, deck_y + 14),
		Vector2(-w * 0.44, deck_y + 26),
		Vector2(w * 0.40, deck_y + 26),
		Vector2(w * 0.48, deck_y - 4),
		Vector2(w * 0.44, deck_y + 8),
		Vector2(w * 0.36, deck_y + 14)
	])
	draw_colored_polygon(stripe_pts, Color("#0284c7"))

	# Silver Deck Plating
	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.88, 7), Color("#e2e8f0"))

	# Wraparound Tinted Aero-Windshield
	var glass_pts = PackedVector2Array([
		Vector2(-10, deck_y),
		Vector2(20, deck_y - 38),
		Vector2(110, deck_y - 38),
		Vector2(145, deck_y)
	])
	draw_colored_polygon(glass_pts, Color(0.2, 0.8, 1.0, 0.55))
	draw_polyline(glass_pts, Color("#38bdf8"), 2.0, true)

	# Dual Roaring Chrome Outboard V8 Engines at Stern
	var eng_vib = sin(t * 32.0) * 1.2
	draw_rect(Rect2(-w * 0.48, deck_y - 28 + eng_vib, 18, 38), Color("#334155"))
	draw_rect(Rect2(-w * 0.48 + 2, deck_y - 26 + eng_vib, 14, 18), Color("#cbd5e1")) # Chrome top
	draw_circle(Vector2(-w * 0.48 + 9, deck_y + 16), 4.0, Color("#94a3b8")) # Propeller hub

	# Dynamic Hydroplane Spray Wake
	for p in range(4):
		var p_t = fmod(t * 5.0 + p * 0.6, 2.5)
		draw_circle(Vector2(-w * 0.50 - p_t * 14.0, deck_y + 24 + p_t * 6.0), 3.0 + p_t * 3.0, Color(0.85, 0.95, 1.0, max(0.0, 0.7 - p_t * 0.25)))

	# Dual Aerial Antenna
	draw_line(Vector2(-w * 0.35, deck_y), Vector2(-w * 0.38, deck_y - 65), Color("#cbd5e1"), 1.8)
	draw_circle(Vector2(-w * 0.38, deck_y - 65), 2.5, Color("#ef4444")) # Beacon

# --- TIER 5: HOVERCRAFT VANGUARD ---
func _draw_hovercraft(t: float, deck_y: float) -> void:
	var w = 620.0

	# Giant Segmented Black Rubber Hover-Skirt
	var skirt_pts = PackedVector2Array([
		Vector2(-w * 0.49, deck_y + 10),
		Vector2(-w * 0.46, deck_y + 55),
		Vector2(w * 0.46, deck_y + 55),
		Vector2(w * 0.49, deck_y + 10)
	])
	draw_colored_polygon(skirt_pts, Color("#090d16"))
	# Skirt segments
	for sx in range(int(-w * 0.45), int(w * 0.45), 28):
		draw_line(Vector2(sx, deck_y + 10), Vector2(sx, deck_y + 55), Color(0.2, 0.25, 0.3, 0.6), 2.0)

	# Continuous Perimeter Air-Cushion Foam / Dust Spray
	for fx in range(int(-w * 0.46), int(w * 0.46), 40):
		var puff = sin(t * 12.0 + fx * 0.1) * 3.5
		draw_circle(Vector2(fx, deck_y + 55 + puff), 5.0, Color(0.8, 0.95, 1.0, 0.35))

	# Heavy Titanium Armor Platform
	var armor_pts = PackedVector2Array([
		Vector2(-w * 0.48, deck_y),
		Vector2(-w * 0.45, deck_y + 16),
		Vector2(w * 0.45, deck_y + 16),
		Vector2(w * 0.48, deck_y - 6),
		Vector2(w * 0.44, deck_y)
	])
	draw_colored_polygon(armor_pts, Color("#1e293b"))
	draw_polyline(armor_pts, Color("#334155"), 3.0, true)

	# Hazard Yellow Chevron Accent
	draw_rect(Rect2(-w * 0.38, deck_y + 6, w * 0.76, 5), Color("#eab308"))

	# Twin Giant Rear Ducted Turbofan Pylons (Stern)
	for i in range(2):
		var fan_x = -w * 0.42 + i * 40.0
		# Ducted Ring
		draw_rect(Rect2(fan_x - 14, deck_y - 62, 28, 62), Color("#0f172a"))
		draw_circle(Vector2(fan_x, deck_y - 34), 18.0, Color("#334155"))
		draw_circle(Vector2(fan_x, deck_y - 34), 14.0, Color("#0f172a"))
		# Spinning Turbine Fan Blades
		var fan_rot = t * 24.0 + i * 1.5
		for b in range(4):
			var b_ang = fan_rot + b * (PI * 0.5)
			var b_end = Vector2(fan_x, deck_y - 34) + Vector2(cos(b_ang), sin(b_ang)) * 13.0
			draw_line(Vector2(fan_x, deck_y - 34), b_end, Color("#38bdf8"), 2.2)

	# Roll-cage Armored Bridge
	draw_rect(Rect2(20, deck_y - 52, 90, 52), Color("#0f172a"))
	draw_rect(Rect2(24, deck_y - 48, 82, 22), Color("#f59e0b", 0.75)) # Amber HUD Glass

	# Deck Floor
	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.88, 7), Color("#0f172a"))

# --- TIER 6: LUXURY YACHT ---
func _draw_luxury_yacht(t: float, deck_y: float) -> void:
	var w = 700.0

	# Underwater Cyan LED Glow
	draw_rect(Rect2(-w * 0.44, deck_y + 20, w * 0.86, 35), Color(0.0, 0.9, 0.8, 0.22))

	# Pristine Pearl-White Multi-Level Hull
	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.48, deck_y),
		Vector2(-w * 0.43, deck_y + 54),
		Vector2(w * 0.40, deck_y + 54),
		Vector2(w * 0.50, deck_y - 24),
		Vector2(w * 0.44, deck_y)
	])
	draw_colored_polygon(hull_pts, Color("#f8fafc"))
	draw_polyline(hull_pts, Color("#cbd5e1"), 2.5, true)

	# Golden Waterline Pinstripe
	draw_line(Vector2(-w * 0.45, deck_y + 24), Vector2(w * 0.45, deck_y + 12), Color("#f59e0b"), 3.0)

	# Honey Teak Decking
	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.88, 8), Color("#b45309"))

	# Tri-Deck Raised Salon Bridge
	draw_rect(Rect2(-50, deck_y - 88, 140, 88), Color("#0f172a")) # Dark frame
	draw_rect(Rect2(-46, deck_y - 84, 132, 84), Color("#f8fafc")) # White superstructure
	# Salon Panoramic Windows with Warm Golden Chandeliers
	draw_rect(Rect2(-36, deck_y - 76, 52, 28), Color("#38bdf8", 0.85))
	draw_rect(Rect2(24, deck_y - 76, 52, 28), Color("#38bdf8", 0.85))
	draw_circle(Vector2(-10, deck_y - 62), 4.0, Color(1.0, 0.9, 0.4, 0.9))
	draw_circle(Vector2(50, deck_y - 62), 4.0, Color(1.0, 0.9, 0.4, 0.9))

	# Upper Sun Deck & Rotating Satellite Radar
	draw_rect(Rect2(-20, deck_y - 110, 4, 22), Color("#94a3b8"))
	var rad_w = sin(t * 3.5) * 16.0
	draw_line(Vector2(-18 - rad_w, deck_y - 110), Vector2(-18 + rad_w, deck_y - 110), Color("#ffffff"), 4.0)

	# Polished Gold Guard Rails
	draw_line(Vector2(-w * 0.45, deck_y - 20), Vector2(w * 0.42, deck_y - 20), Color("#facc15"), 2.5)

# --- TIER 7: ABYSSAL SUBMERSIBLE ---
func _draw_abyssal_sub(t: float, deck_y: float) -> void:
	var w = 660.0

	# High-Intensity Halogen Spotlight Beam Cutting Water Depths
	var beam_pts = PackedVector2Array([
		Vector2(w * 0.38, deck_y - 10),
		Vector2(w * 0.85, deck_y + 120),
		Vector2(w * 0.70, deck_y + 180),
		Vector2(w * 0.34, deck_y + 20)
	])
	draw_colored_polygon(beam_pts, Color(0.3, 0.9, 1.0, 0.18))

	# Obsidian Titanium Cylindrical Pressure Hull
	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.48, deck_y - 10),
		Vector2(-w * 0.44, deck_y + 58),
		Vector2(w * 0.40, deck_y + 58),
		Vector2(w * 0.48, deck_y + 10),
		Vector2(w * 0.44, deck_y - 10)
	])
	draw_colored_polygon(hull_pts, Color("#090d16"))
	draw_polyline(hull_pts, Color("#1e293b"), 3.5, true)

	# Glowing Bioluminescent Circuit Conduits
	for cy in range(int(deck_y + 10), int(deck_y + 50), 16):
		draw_line(Vector2(-w * 0.43, cy), Vector2(w * 0.38, cy), Color("#06b6d4"), 2.0)

	# Heavy Copper Rivets along the bulkheads
	for rx in range(int(-w * 0.42), int(w * 0.38), 32):
		draw_circle(Vector2(rx, deck_y + 8), 3.0, Color("#d97706"))

	# Quartz Panoramic Bubble Viewport (Bow)
	draw_circle(Vector2(w * 0.38, deck_y - 2), 22.0, Color("#06b6d4", 0.4))
	draw_circle(Vector2(w * 0.38, deck_y - 2), 17.0, Color("#38bdf8", 0.85))
	draw_circle(Vector2(w * 0.34, deck_y - 7), 5.0, Color("#ffffff", 0.95))

	# Articulated Hydraulic Manipulator Arm
	draw_line(Vector2(w * 0.44, deck_y + 18), Vector2(w * 0.49, deck_y + 36), Color("#475569"), 4.0)
	draw_line(Vector2(w * 0.49, deck_y + 36), Vector2(w * 0.52, deck_y + 28), Color("#f59e0b"), 3.0)

	# Ballast Exhaust Rising Bubbles
	for b in range(4):
		var b_t = fmod(t * 4.0 + b * 0.8, 3.0)
		draw_circle(Vector2(-w * 0.36 + b * 12.0, deck_y + 50 - b_t * 22.0), 3.0 + b_t * 1.5, Color(0.7, 0.9, 1.0, max(0.0, 0.7 - b_t * 0.2)))

	# Deck Floor
	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.86, 7), Color("#1e293b"))

# ==============================================================================
# TRAILER NET (WORKER SYSTEM)
# ==============================================================================
func _draw_trawler_net(t: float, deck_y: float) -> void:
	var b_bounds = GameManager.get_deck_bounds()
	var net_stern_x = b_bounds.x - 30.0
	var float_y = deck_y + 14.0 + sin(t * 2.8) * 4.0

	# Drag line from stern
	draw_line(Vector2(b_bounds.x, deck_y), Vector2(net_stern_x, float_y), Color("#78350f"), 2.0)

	# Orange Buoy Float
	draw_circle(Vector2(net_stern_x, float_y), 7.0, Color("#ea580c"))
	draw_circle(Vector2(net_stern_x, float_y), 3.0, Color("#ffffff"))

	# Submerged Net Mesh
	var net_pts = PackedVector2Array([
		Vector2(net_stern_x, float_y),
		Vector2(net_stern_x - 32, float_y + 18),
		Vector2(net_stern_x - 18, float_y + 36),
		Vector2(net_stern_x + 8, float_y + 14)
	])
	draw_colored_polygon(net_pts, Color(0.2, 0.6, 0.5, 0.45))
	draw_polyline(net_pts, Color("#0d9488"), 1.8, true)

	# Mesh grid lines
	draw_line(Vector2(net_stern_x - 16, float_y + 9), Vector2(net_stern_x - 5, float_y + 25), Color(0.9, 0.95, 1.0, 0.4), 1.0)

# ==============================================================================
# DEDICATED PIXEL FISHERMAN
# ==============================================================================
func _draw_fisherman(t: float, deck_y: float) -> void:
	if not overworld:
		return

	var p_x = overworld.player_deck_x
	var facing = overworld.player_facing
	var is_walk = overworld.is_walking
	var is_cast = overworld.is_cooling_down

	# Dimensions: 160x271 -> scaled height ~92px
	var h = 92.0
	var scale_factor = h / 271.0
	var w = 160.0 * scale_factor

	# Frame selection
	var tex_to_draw: Texture2D = null
	var walk_bob = 0.0

	if is_cast and tex_fisherman_fish:
		tex_to_draw = tex_fisherman_fish
		# Casting stance: face stern/water
		facing = -1.0
	elif is_walk and not tex_fisherman_walk.is_empty():
		var walk_frame = int(fmod(overworld.walk_anim_timer * 1.3, float(tex_fisherman_walk.size())))
		tex_to_draw = tex_fisherman_walk[walk_frame]
		walk_bob = abs(sin(overworld.walk_anim_timer * 1.3)) * 3.0
	elif not tex_fisherman_idle.is_empty():
		# Natural Idle Blinking
		var idle_cycle = fmod(t, 3.8)
		var idle_frame = 0
		if idle_cycle > 3.5:
			idle_frame = 1 if tex_fisherman_idle.size() > 1 else 0
		elif idle_cycle > 1.8 and idle_cycle < 2.0:
			idle_frame = 2 if tex_fisherman_idle.size() > 2 else 0
		tex_to_draw = tex_fisherman_idle[idle_frame]
		walk_bob = sin(t * 3.2) * 1.5 # Gentle breathing

	if tex_to_draw:
		draw_set_transform(Vector2(p_x, deck_y), 0.0, Vector2(facing, 1.0))
		var char_rect = Rect2(-w * 0.5, -h + walk_bob, w, h)
		draw_texture_rect(tex_to_draw, char_rect, false)

		# If casting: draw bezier fishing line stretching to water
		if is_cast:
			var rod_tip = Vector2(-w * 0.45, -h * 0.55 + walk_bob)
			var wave_bobber = Vector2(-w * 1.6, 26.0 + sin(t * 3.5) * 4.0)
			# Curved tension line
			var mid_pt = Vector2((rod_tip.x + wave_bobber.x) * 0.5, max(rod_tip.y, wave_bobber.y) + 12.0)
			var line_pts = PackedVector2Array([rod_tip, mid_pt, wave_bobber])
			draw_polyline(line_pts, Color(0.9, 0.95, 1.0, 0.8), 1.2)
			# Red & White Bobber
			draw_circle(wave_bobber, 3.5, Color("#ef4444"))
			draw_circle(wave_bobber + Vector2(0, 1.5), 2.0, Color("#ffffff"))

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ==============================================================================
# COMPANION PETS
# ==============================================================================
func _draw_companion_pet(t: float) -> void:
	if GameManager.equipped_pet == "None":
		return

	var pet_wobble = sin(t * 2.5) * 5.0
	var pet_pos = Vector2(330, 20 + pet_wobble)
	match GameManager.equipped_pet:
		"Axo-9":
			draw_circle(pet_pos, 10.0, Color(1.0, 0.4, 0.75, 0.95))
			draw_circle(pet_pos + Vector2(4, -3), 4.0, Color(0.2, 1.0, 0.8, 0.9))
			draw_circle(pet_pos + Vector2(4, 3), 4.0, Color(0.2, 1.0, 0.8, 0.9))
		"Otto-Flux":
			draw_circle(pet_pos, 12.0, Color(0.3, 0.8, 1.0, 0.95))
			draw_circle(pet_pos + Vector2(-6, 0), 6.0, Color(0.9, 0.95, 1.0, 0.9))
		"Chrono-Jelly":
			draw_circle(pet_pos, 14.0, Color(0.8, 0.2, 1.0, 0.85))
			draw_circle(pet_pos, 6.0, Color(1.0, 1.0, 1.0, 0.95))
			draw_line(pet_pos, pet_pos + Vector2(0, 16), Color(0.7, 0.2, 0.9, 0.7), 2.5)
		"Aethelgard":
			draw_circle(pet_pos, 16.0, Color(1.0, 0.82, 0.15, 0.98))
			draw_circle(pet_pos, 8.0, Color(1.0, 0.35, 0.1, 0.95))
			draw_circle(pet_pos + Vector2(-12, -4), 5.0, Color(1.0, 0.9, 0.4, 0.9))

# ==============================================================================
# GUARD RAILING & STATIONS
# ==============================================================================
func _draw_guard_railing(deck_y: float) -> void:
	var b = GameManager.get_deck_bounds()
	draw_line(Vector2(b.x, deck_y - 20), Vector2(b.y, deck_y - 20), Color("#d97706"), 3.5)
	var step = 42
	for rx in range(int(b.x + 10), int(b.y - 10), step):
		draw_line(Vector2(rx, deck_y - 20), Vector2(rx, deck_y), Color("#92400e"), 2.5)

func _draw_stations(deck_y: float) -> void:
	var bounds = GameManager.get_deck_bounds()
	var s_pier = bounds.x * 0.80
	var s_market = bounds.x * 0.40
	var s_helm = 0.0
	var s_tackle = bounds.y * 0.40
	var s_pets = bounds.y * 0.80

	_draw_station_sign(Vector2(s_pier, deck_y), "Pier", Color("#38bdf8"))
	_draw_station_sign(Vector2(s_market, deck_y), "Market", Color("#facc15"))
	_draw_station_sign(Vector2(s_helm, deck_y), "Helm", Color("#4ade80"))
	_draw_station_sign(Vector2(s_tackle, deck_y), "Tackle", Color("#c084fc"))
	_draw_station_sign(Vector2(s_pets, deck_y), "Sanctuary", Color("#38bdf8"))

func _draw_station_sign(pos: Vector2, text: String, accent: Color) -> void:
	var plaque_rect = Rect2(pos.x - 26, pos.y - 62, 52, 20)
	draw_rect(plaque_rect, Color(0.10, 0.06, 0.03, 0.92))
	draw_rect(plaque_rect, accent, false, 1.5)
	draw_line(Vector2(pos.x, pos.y - 42), Vector2(pos.x, pos.y), Color("#451a03"), 2.0)
	var font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(pos.x - 24, pos.y - 48), text, HORIZONTAL_ALIGNMENT_CENTER, 48, 10, accent)

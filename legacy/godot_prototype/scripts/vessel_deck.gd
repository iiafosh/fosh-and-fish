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

	# --- 2. LAYER 2: BOAT HULL & SUPERSTRUCTURE (17 DISTINCT TIERS) ---
	match visual_style:
		"Rowboat": _draw_rowboat(t, deck_y)
		"Fishing Boat": _draw_fishing_boat(t, deck_y)
		"Speedboat": _draw_speedboat(t, deck_y)
		"Pontoon": _draw_pontoon(t, deck_y)
		"Sailboat": _draw_sailboat(t, deck_y)
		"Yacht": _draw_yacht(t, deck_y)
		"Luxury Yacht": _draw_luxury_yacht(t, deck_y)
		"Cruise Ship": _draw_cruise_ship(t, deck_y)
		"Gold Boat": _draw_gold_boat(t, deck_y)
		"Sky Cruiser": _draw_sky_cruiser(t, deck_y)
		"Satellite": _draw_satellite(t, deck_y)
		"Space Shuttle": _draw_space_shuttle(t, deck_y)
		"Cruiser": _draw_cruiser(t, deck_y)
		"Alien Raft": _draw_alien_raft(t, deck_y)
		"Alien Submarine": _draw_alien_submarine(t, deck_y)
		"Dark Explorer": _draw_dark_explorer(t, deck_y)
		"Abyssal Surveyor": _draw_abyssal_surveyor(t, deck_y)
		"Hovercraft Vanguard": _draw_hovercraft(t, deck_y)
		"Abyssal Submersible": _draw_abyssal_sub(t, deck_y)
		_: _draw_skiff(t, deck_y)

	# --- 2B. DYNAMIC MODULAR UPGRADE ATTACHMENTS ---
	_draw_ship_upgrades(t, deck_y)

	# --- 3. LAYER 3: DEDICATED PIXEL FISHERMAN ---
	_draw_fisherman(t, deck_y)

	# --- 4. LAYER 4: COMPANION PET IN THE WAKE ---
	_draw_companion_pet(t)

	# --- 5. LAYER 5: SUBTLE FRONT BRASS GUARD RAILING ---
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
	if tex_boat_sprite:
		var draw_w = 480.0
		var draw_h = 196.0
		var boat_rect = Rect2(-draw_w * 0.5, deck_y - 77.0, draw_w, draw_h)
		draw_texture_rect(tex_boat_sprite, boat_rect, false)

		# Diesel Exhaust Stack & Animated Smoke Puffs at aft cabin
		for s in range(3):
			var s_t = fmod(t * 3.5 + s * 1.1, 3.0)
			var s_pos = Vector2(-75 - s_t * 5.0, deck_y - 65 - s_t * 14.0)
			var s_rad = 3.5 + s_t * 3.0
			var s_alpha = max(0.0, 0.60 - s_t * 0.20)
			draw_circle(s_pos, s_rad, Color(0.85, 0.88, 0.95, s_alpha))
		return

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

# --- TIER 4: PONTOON ---
func _draw_pontoon(_t: float, deck_y: float) -> void:
	var w = 600.0
	# Twin cylindrical aluminum flotation tubes
	var tube_pts = PackedVector2Array([
		Vector2(-w * 0.48, deck_y + 36),
		Vector2(-w * 0.44, deck_y + 52),
		Vector2(w * 0.40, deck_y + 52),
		Vector2(w * 0.50, deck_y + 38), # Tapered aerodynamic nosecone
		Vector2(w * 0.42, deck_y + 36)
	])
	draw_colored_polygon(tube_pts, Color("#94a3b8")) # Aluminum
	draw_polyline(tube_pts, Color("#475569"), 2.5, true)
	for sx in range(int(-w * 0.42), int(w * 0.40), 40):
		draw_line(Vector2(sx, deck_y + 36), Vector2(sx, deck_y + 52), Color(0.2, 0.25, 0.3, 0.45), 2.0)

	# Heavy structural deck riser stanchions
	for rx in range(int(-w * 0.40), int(w * 0.40), 65):
		draw_rect(Rect2(rx, deck_y + 10, 8, 26), Color("#64748b"))

	# Flat Cedar/Teak Party Platform Deck
	draw_rect(Rect2(-w * 0.47, deck_y, w * 0.92, 10), Color("#b45309")) # Teak
	for px in range(int(-w * 0.45), int(w * 0.43), 20):
		draw_line(Vector2(px, deck_y), Vector2(px, deck_y + 10), Color(0.25, 0.12, 0.04, 0.4), 1.0)

	# Bimini Sunshade Canopy (Navy Canvas with aluminum frame)
	var canopy_pts = PackedVector2Array([
		Vector2(-120, deck_y - 75),
		Vector2(70, deck_y - 75),
		Vector2(85, deck_y - 70),
		Vector2(-135, deck_y - 70)
	])
	draw_colored_polygon(canopy_pts, Color("#1e3a8a"))
	draw_polyline(canopy_pts, Color("#172554"), 2.0, true)
	draw_line(Vector2(-115, deck_y), Vector2(-125, deck_y - 70), Color("#cbd5e1"), 2.5)
	draw_line(Vector2(65, deck_y), Vector2(75, deck_y - 70), Color("#cbd5e1"), 2.5)

	# Plush Stern Corner Lounge Cushion Seating
	draw_rect(Rect2(-w * 0.42, deck_y - 28, 70, 28), Color("#1e3a8a"))
	draw_rect(Rect2(-w * 0.42 + 4, deck_y - 24, 62, 16), Color("#f8fafc"))

	# Marine Party Cooler with Ice
	draw_rect(Rect2(w * 0.22, deck_y - 20, 32, 20), Color("#dc2626"))
	draw_rect(Rect2(w * 0.22, deck_y - 23, 32, 4), Color("#f8fafc"))

# --- TIER 5: SAILBOAT (CUTTER) ---
func _draw_sailboat(t: float, deck_y: float) -> void:
	var w = 620.0
	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.48, deck_y),
		Vector2(-w * 0.42, deck_y + 50),
		Vector2(w * 0.38, deck_y + 50),
		Vector2(w * 0.50, deck_y - 10), # Clipper bow
		Vector2(w * 0.42, deck_y)
	])
	draw_colored_polygon(hull_pts, Color("#f8fafc")) # Crisp white hull
	draw_polyline(hull_pts, Color("#334155"), 2.5, true)
	draw_line(Vector2(-w * 0.47, deck_y + 36), Vector2(w * 0.42, deck_y + 36), Color("#1e40af"), 3.5)

	# Teak Deck
	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.88, 8), Color("#d97706"))

	# Towering Spruce Mast (Center)
	var mast_x = -20.0
	draw_rect(Rect2(mast_x - 3, deck_y - 120, 7, 120), Color("#78350f"))
	draw_line(Vector2(mast_x - 32, deck_y - 75), Vector2(mast_x + 32, deck_y - 75), Color("#a16207"), 2.5)

	# Stainless wire stays & rigging
	draw_line(Vector2(mast_x, deck_y - 120), Vector2(-w * 0.44, deck_y), Color(0.9, 0.95, 1.0, 0.45), 1.2)
	draw_line(Vector2(mast_x, deck_y - 120), Vector2(w * 0.46, deck_y - 5), Color(0.9, 0.95, 1.0, 0.45), 1.2)

	# Billowing Cream Canvas Mainsail (Dynamic wind sway)
	var sway = sin(t * 2.2) * 5.0
	var sail_pts = PackedVector2Array([
		Vector2(mast_x - 2, deck_y - 115),
		Vector2(mast_x - 2, deck_y - 25),
		Vector2(mast_x - 115 + sway, deck_y - 20),
		Vector2(mast_x - 65 + sway * 0.6, deck_y - 65)
	])
	draw_colored_polygon(sail_pts, Color("#fef3c7"))
	draw_polyline(sail_pts, Color("#ca8a04"), 1.8, true)
	var jib_pts = PackedVector2Array([
		Vector2(mast_x + 2, deck_y - 105),
		Vector2(w * 0.40, deck_y - 5),
		Vector2(mast_x + 55, deck_y - 18)
	])
	draw_colored_polygon(jib_pts, Color(0.98, 0.96, 0.90, 0.85))
	draw_polyline(jib_pts, Color("#ca8a04"), 1.5, true)

	# Spoked Teak Steering Wheel Pedestal (Aft)
	draw_rect(Rect2(-w * 0.38, deck_y - 22, 5, 22), Color("#cbd5e1"))
	draw_circle(Vector2(-w * 0.38 + 2, deck_y - 22), 8.0, Color("#ca8a04"))
	draw_circle(Vector2(-w * 0.38 + 2, deck_y - 22), 5.0, Color("#0f172a"))

# --- TIER 6: MODERN YACHT ---
func _draw_yacht(t: float, deck_y: float) -> void:
	var w = 680.0
	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.48, deck_y),
		Vector2(-w * 0.43, deck_y + 52),
		Vector2(w * 0.40, deck_y + 52),
		Vector2(w * 0.50, deck_y - 20),
		Vector2(w * 0.43, deck_y)
	])
	draw_colored_polygon(hull_pts, Color("#1e293b"))
	draw_polyline(hull_pts, Color("#0f172a"), 2.5, true)
	draw_line(Vector2(-w * 0.46, deck_y + 20), Vector2(w * 0.44, deck_y + 8), Color("#06b6d4"), 3.0)

	draw_rect(Rect2(-w * 0.45, deck_y, w * 0.88, 8), Color("#f8fafc"))
	var salon_pts = PackedVector2Array([
		Vector2(-70, deck_y),
		Vector2(-50, deck_y - 65),
		Vector2(70, deck_y - 65),
		Vector2(110, deck_y)
	])
	draw_colored_polygon(salon_pts, Color("#f1f5f9"))
	draw_polyline(salon_pts, Color("#cbd5e1"), 2.0, true)
	var win_pts = PackedVector2Array([
		Vector2(-35, deck_y - 12),
		Vector2(-25, deck_y - 52),
		Vector2(60, deck_y - 52),
		Vector2(85, deck_y - 12)
	])
	draw_colored_polygon(win_pts, Color(0.08, 0.4, 0.55, 0.85))

	draw_line(Vector2(20, deck_y - 65), Vector2(-15, deck_y - 100), Color("#e2e8f0"), 6.0)
	draw_circle(Vector2(-15, deck_y - 100), 6.0, Color("#0284c7"))
	var arch_w = sin(t * 3.5) * 12.0
	draw_line(Vector2(-15 - arch_w, deck_y - 104), Vector2(-15 + arch_w, deck_y - 104), Color("#ffffff"), 3.0)
	draw_rect(Rect2(120, deck_y - 10, 55, 10), Color("#fef08a"))

# --- TIER 8: CRUISE SHIP ---
func _draw_cruise_ship(t: float, deck_y: float) -> void:
	var w = 740.0
	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.49, deck_y),
		Vector2(-w * 0.44, deck_y + 60),
		Vector2(w * 0.41, deck_y + 60),
		Vector2(w * 0.50, deck_y - 25),
		Vector2(w * 0.44, deck_y)
	])
	draw_colored_polygon(hull_pts, Color("#0f172a"))
	draw_polyline(hull_pts, Color("#020617"), 3.0, true)
	draw_line(Vector2(-w * 0.46, deck_y + 35), Vector2(w * 0.45, deck_y + 20), Color("#ca8a04"), 3.0)

	draw_rect(Rect2(-w * 0.44, deck_y - 50, w * 0.82, 50), Color("#f8fafc"))
	draw_rect(Rect2(-w * 0.38, deck_y - 90, w * 0.70, 42), Color("#f1f5f9"))

	for row in range(2):
		var py = deck_y - 38 + row * 20
		for px in range(int(-w * 0.40), int(w * 0.32), 24):
			draw_rect(Rect2(px, py, 12, 10), Color("#fef08a", 0.9))
			draw_rect(Rect2(px, py, 12, 10), Color("#94a3b8"), false, 1.0)

	for px in range(int(-w * 0.34), int(w * 0.28), 28):
		draw_circle(Vector2(px, deck_y - 70), 4.0, Color("#38bdf8", 0.9))

	for f in range(2):
		var fx = -110.0 + f * 75.0
		var funnel_pts = PackedVector2Array([
			Vector2(fx, deck_y - 90),
			Vector2(fx + 10, deck_y - 130),
			Vector2(fx + 36, deck_y - 130),
			Vector2(fx + 26, deck_y - 90)
		])
		draw_colored_polygon(funnel_pts, Color("#dc2626"))
		var top_pts = PackedVector2Array([
			Vector2(fx + 7, deck_y - 120),
			Vector2(fx + 10, deck_y - 130),
			Vector2(fx + 36, deck_y - 130),
			Vector2(fx + 33, deck_y - 120)
		])
		draw_colored_polygon(top_pts, Color("#18181b"))
		for s in range(2):
			var s_t = fmod(t * 3.0 + s * 1.5 + f * 0.8, 2.5)
			var s_pos = Vector2(fx + 24 - s_t * 8.0, deck_y - 135 - s_t * 16.0)
			draw_circle(s_pos, 3.5 + s_t * 3.0, Color(0.9, 0.92, 0.96, max(0.0, 0.6 - s_t * 0.22)))

	draw_rect(Rect2(w * 0.22, deck_y - 85, 55, 35), Color("#0284c7"))
	draw_rect(Rect2(w * 0.24, deck_y - 82, 48, 16), Color("#67e8f9", 0.9))
	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.88, 8), Color("#d97706"))

# --- TIER 9: SOLID GOLD BOAT ---
func _draw_gold_boat(t: float, deck_y: float) -> void:
	var w = 700.0
	draw_rect(Rect2(-w * 0.46, deck_y - 15, w * 0.90, 70), Color(1.0, 0.85, 0.2, 0.15))

	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.49, deck_y),
		Vector2(-w * 0.43, deck_y + 54),
		Vector2(w * 0.39, deck_y + 54),
		Vector2(w * 0.50, deck_y - 22),
		Vector2(w * 0.43, deck_y)
	])
	draw_colored_polygon(hull_pts, Color("#eab308"))
	draw_polyline(hull_pts, Color("#a16207"), 3.0, true)

	for y in range(int(deck_y + 12), int(deck_y + 48), 12):
		draw_line(Vector2(-w * 0.43, y), Vector2(w * 0.38, y), Color("#fef08a", 0.6), 2.0)

	for gx in range(int(-w * 0.44), int(w * 0.42), 34):
		var ruby_pulse = sin(t * 4.0 + gx * 0.05) * 0.3 + 0.7
		draw_circle(Vector2(gx, deck_y - 4), 3.5, Color(0.9, 0.1, 0.2, ruby_pulse))
		draw_circle(Vector2(gx, deck_y - 4), 1.5, Color("#ffffff"))

	var prow_pos = Vector2(w * 0.49, deck_y - 25)
	draw_circle(prow_pos, 10.0, Color("#facc15"))
	draw_line(prow_pos, prow_pos + Vector2(16, -10), Color("#fde047"), 4.0)
	draw_circle(prow_pos + Vector2(6, -4), 3.0, Color("#dc2626"))

	draw_rect(Rect2(-w * 0.38, deck_y - 45, 60, 45), Color("#a16207"))
	draw_rect(Rect2(-w * 0.38 + 4, deck_y - 42, 52, 42), Color("#7f1d1d"))
	draw_circle(Vector2(-w * 0.38 + 30, deck_y - 48), 10.0, Color("#facc15"))

	for s in range(5):
		var s_t = fmod(t * 2.5 + s * 1.2, 3.0)
		var sp = Vector2(-w * 0.35 + s * 120.0 + sin(t + s) * 20.0, deck_y - 10 - s_t * 28.0)
		draw_circle(sp, 2.5, Color(1.0, 0.95, 0.5, max(0.0, 0.8 - s_t * 0.25)))

	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.88, 8), Color("#fef08a"))

# --- TIER 10: SKY CRUISER (REPULSOR SKIFF) ---
func _draw_sky_cruiser(t: float, deck_y: float) -> void:
	var w = 700.0
	for r in range(2):
		var rx = -160.0 + r * 320.0
		var r_rad = 22.0 + sin(t * 6.0 + r * PI) * 5.0
		draw_circle(Vector2(rx, deck_y + 45), r_rad, Color(0.0, 0.8, 1.0, 0.25))
		draw_circle(Vector2(rx, deck_y + 45), 14.0, Color(0.2, 0.9, 1.0, 0.6))
		draw_circle(Vector2(rx, deck_y + 45), 6.0, Color("#ffffff"))

	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.48, deck_y),
		Vector2(-w * 0.44, deck_y + 35),
		Vector2(w * 0.40, deck_y + 35),
		Vector2(w * 0.50, deck_y - 12),
		Vector2(w * 0.42, deck_y)
	])
	draw_colored_polygon(hull_pts, Color("#1e3a8a"))
	draw_polyline(hull_pts, Color("#38bdf8"), 2.5, true)

	var wing_pts = PackedVector2Array([
		Vector2(-60, deck_y + 10),
		Vector2(-120, deck_y + 38),
		Vector2(-20, deck_y + 24)
	])
	draw_colored_polygon(wing_pts, Color("#0284c7"))
	draw_polyline(wing_pts, Color("#67e8f9"), 2.0, true)

	var canopy_pts = PackedVector2Array([
		Vector2(40, deck_y),
		Vector2(65, deck_y - 42),
		Vector2(145, deck_y - 42),
		Vector2(175, deck_y)
	])
	draw_colored_polygon(canopy_pts, Color(0.2, 0.85, 1.0, 0.6))
	draw_polyline(canopy_pts, Color("#e0f2fe"), 2.0, true)

	draw_line(Vector2(-w * 0.42, deck_y), Vector2(-w * 0.45, deck_y - 60), Color("#0284c7"), 4.0)
	draw_line(Vector2(-w * 0.45, deck_y - 60), Vector2(-w * 0.38, deck_y - 60), Color("#38bdf8"), 3.0)
	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.88, 7), Color("#0f172a"))

# --- TIER 11: SATELLITE (ORBITAL PLATFORM) ---
func _draw_satellite(t: float, deck_y: float) -> void:
	var w = 680.0
	for side in [-1, 1]:
		var panel_x = side * 220.0
		var p_rect = Rect2(panel_x - 70, deck_y - 55, 140, 35)
		draw_rect(p_rect, Color("#1e3a8a"))
		draw_rect(p_rect, Color("#ca8a04"), false, 2.0)
		for gx in range(int(panel_x - 60), int(panel_x + 60), 20):
			draw_line(Vector2(gx, deck_y - 55), Vector2(gx, deck_y - 20), Color("#facc15", 0.7), 1.0)
		draw_line(Vector2(0, deck_y - 37), Vector2(panel_x, deck_y - 37), Color("#94a3b8"), 3.0)

	var bus_rect = Rect2(-80, deck_y - 70, 160, 70)
	draw_rect(bus_rect, Color("#ca8a04"))
	draw_rect(bus_rect, Color("#fef08a"), false, 2.0)
	for cy in range(int(deck_y - 65), int(deck_y - 5), 14):
		draw_line(Vector2(-75, cy), Vector2(75, cy + 4), Color("#854d0e", 0.5), 1.5)

	var dish_rot = sin(t * 1.5) * 0.35
	var dish_center = Vector2(0, deck_y - 85)
	draw_arc(dish_center, 24.0, -PI * 0.85 + dish_rot, -PI * 0.15 + dish_rot, 16, Color("#f8fafc"), 3.5)
	draw_line(dish_center, dish_center + Vector2(cos(-PI * 0.5 + dish_rot), sin(-PI * 0.5 + dish_rot)) * 28.0, Color("#dc2626"), 2.0)

	var blink = int(t * 4.0) % 2 == 0
	draw_circle(Vector2(-70, deck_y - 65), 3.0, Color("#ef4444") if blink else Color("#7f1d1d"))
	draw_circle(Vector2(70, deck_y - 65), 3.0, Color("#22c55e") if not blink else Color("#14532d"))
	draw_rect(Rect2(-w * 0.44, deck_y, w * 0.84, 8), Color("#334155"))

# --- TIER 12: SPACE SHUTTLE ---
func _draw_space_shuttle(t: float, deck_y: float) -> void:
	var w = 720.0
	var heat_pts = PackedVector2Array([
		Vector2(-w * 0.48, deck_y + 20),
		Vector2(-w * 0.42, deck_y + 50),
		Vector2(w * 0.40, deck_y + 50),
		Vector2(w * 0.50, deck_y + 10),
		Vector2(w * 0.44, deck_y + 20)
	])
	draw_colored_polygon(heat_pts, Color("#090d16"))
	draw_polyline(heat_pts, Color("#18181b"), 2.0, true)

	var fuse_pts = PackedVector2Array([
		Vector2(-w * 0.48, deck_y),
		Vector2(-w * 0.48, deck_y + 20),
		Vector2(w * 0.44, deck_y + 20),
		Vector2(w * 0.48, deck_y - 12),
		Vector2(w * 0.42, deck_y)
	])
	draw_colored_polygon(fuse_pts, Color("#f8fafc"))
	draw_polyline(fuse_pts, Color("#cbd5e1"), 2.0, true)

	var win_pts = PackedVector2Array([
		Vector2(w * 0.32, deck_y - 8),
		Vector2(w * 0.36, deck_y - 24),
		Vector2(w * 0.42, deck_y - 24),
		Vector2(w * 0.44, deck_y - 8)
	])
	draw_colored_polygon(win_pts, Color("#0284c7"))

	var wing_pts = PackedVector2Array([
		Vector2(-100, deck_y + 10),
		Vector2(-180, deck_y + 40),
		Vector2(-40, deck_y + 35)
	])
	draw_colored_polygon(wing_pts, Color("#e2e8f0"))
	draw_line(Vector2(-100, deck_y + 10), Vector2(-180, deck_y + 40), Color("#18181b"), 4.0)

	for eng in range(3):
		var ey = deck_y - 25 + eng * 15.0
		draw_rect(Rect2(-w * 0.49, ey, 14, 10), Color("#475569"))
		var f_len = 25.0 + sin(t * 28.0 + eng * 2.0) * 8.0
		var flame_pts = PackedVector2Array([
			Vector2(-w * 0.49, ey),
			Vector2(-w * 0.49 - f_len, ey + 5),
			Vector2(-w * 0.49, ey + 10)
		])
		draw_colored_polygon(flame_pts, Color(0.2, 0.8, 1.0, 0.85))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-w * 0.49, ey + 2),
			Vector2(-w * 0.49 - f_len * 0.6, ey + 5),
			Vector2(-w * 0.49, ey + 8)
		]), Color("#ffffff"))

	draw_rect(Rect2(-w * 0.44, deck_y - 75, 20, 75), Color("#f1f5f9"))
	draw_line(Vector2(-w * 0.44, deck_y - 75), Vector2(-w * 0.36, deck_y - 75), Color("#dc2626"), 4.0)
	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.88, 7), Color("#334155"))

# --- TIER 13: DEEP VOID BATTLE CRUISER ---
func _draw_cruiser(t: float, deck_y: float) -> void:
	var w = 740.0
	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.49, deck_y),
		Vector2(-w * 0.43, deck_y + 55),
		Vector2(w * 0.40, deck_y + 55),
		Vector2(w * 0.50, deck_y - 18),
		Vector2(w * 0.43, deck_y)
	])
	draw_colored_polygon(hull_pts, Color("#090d16"))
	draw_polyline(hull_pts, Color("#334155"), 3.0, true)

	for cy in range(int(deck_y + 12), int(deck_y + 48), 15):
		draw_line(Vector2(-w * 0.44, cy), Vector2(w * 0.38, cy), Color("#06b6d4"), 2.2)

	draw_rect(Rect2(-40, deck_y - 65, 110, 65), Color("#1e293b"))
	draw_rect(Rect2(-36, deck_y - 50, 102, 12), Color("#ef4444"))
	draw_rect(Rect2(-36, deck_y - 50, 102, 12), Color("#ffffff", 0.5), false, 1.0)

	for i in range(2):
		var iy = deck_y - 35 + i * 28.0
		draw_rect(Rect2(-w * 0.49, iy, 20, 22), Color("#1e293b"))
		draw_rect(Rect2(-w * 0.49 + 2, iy + 2, 16, 18), Color("#0284c7"))
		var i_len = 35.0 + sin(t * 22.0 + i) * 10.0
		draw_line(Vector2(-w * 0.49, iy + 11), Vector2(-w * 0.49 - i_len, iy + 11), Color(0.2, 0.9, 1.0, 0.8), 6.0)
		draw_line(Vector2(-w * 0.49, iy + 11), Vector2(-w * 0.49 - i_len * 0.7, iy + 11), Color("#ffffff"), 2.5)

	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.88, 8), Color("#0f172a"))

# --- TIER 14: ALIEN RAFT (BIO-METALLIC) ---
func _draw_alien_raft(t: float, deck_y: float) -> void:
	var w = 680.0
	for r in range(3):
		var wave_r = fmod(t * 30.0 + r * 25.0, 75.0)
		var alpha = max(0.0, 0.5 - (wave_r / 75.0) * 0.5)
		draw_arc(Vector2(0, deck_y + 40), wave_r, 0, PI, 24, Color(0.1, 1.0, 0.6, alpha), 2.5)

	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.47, deck_y),
		Vector2(-w * 0.41, deck_y + 46),
		Vector2(w * 0.38, deck_y + 46),
		Vector2(w * 0.48, deck_y - 8),
		Vector2(w * 0.41, deck_y)
	])
	draw_colored_polygon(hull_pts, Color("#064e3b"))
	draw_polyline(hull_pts, Color("#10b981"), 3.0, true)

	var core_y = deck_y - 45.0 + sin(t * 3.5) * 6.0
	var core_pts = PackedVector2Array([
		Vector2(0, core_y - 25),
		Vector2(20, core_y),
		Vector2(0, core_y + 25),
		Vector2(-20, core_y)
	])
	draw_colored_polygon(core_pts, Color(0.1, 1.0, 0.7, 0.85))
	draw_polyline(core_pts, Color("#a7f3d0"), 2.0, true)
	draw_circle(Vector2(0, core_y), 8.0, Color("#ffffff", 0.9))

	for i in range(5):
		var tx = -w * 0.35 + i * 110.0
		var tw = sin(t * 3.0 + i) * 12.0
		draw_line(Vector2(tx, deck_y + 46), Vector2(tx + tw, deck_y + 70), Color("#10b981", 0.7), 3.0)

	draw_rect(Rect2(-w * 0.45, deck_y, w * 0.86, 8), Color("#065f46"))

# --- TIER 15: ALIEN SUBMARINE (CEPHALOPOD CRAFT) ---
func _draw_alien_submarine(t: float, deck_y: float) -> void:
	var w = 700.0
	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.48, deck_y - 8),
		Vector2(-w * 0.43, deck_y + 55),
		Vector2(w * 0.39, deck_y + 55),
		Vector2(w * 0.48, deck_y + 12),
		Vector2(w * 0.43, deck_y - 8)
	])
	draw_colored_polygon(hull_pts, Color("#3b0764"))
	draw_polyline(hull_pts, Color("#8b5cf6"), 3.0, true)

	for sx in range(int(-w * 0.40), int(w * 0.38), 38):
		var sy = deck_y + 24 + sin(sx * 0.1) * 12.0
		draw_circle(Vector2(sx, sy), 4.5, Color("#f59e0b", 0.9))
		draw_circle(Vector2(sx, sy), 2.0, Color("#fef08a"))

	var dome_center = Vector2(w * 0.28, deck_y - 12)
	draw_circle(dome_center, 26.0, Color(0.6, 0.2, 0.9, 0.45))
	draw_circle(dome_center, 18.0, Color(0.8, 0.4, 1.0, 0.85))
	var spark_pulse = sin(t * 8.0) * 4.0
	draw_circle(dome_center + Vector2(spark_pulse, 0), 6.0, Color("#ffffff", 0.95))

	for tent in range(3):
		var t_y = deck_y + 15 + tent * 14.0
		var t_pts = PackedVector2Array()
		for seg in range(6):
			var seg_x = -w * 0.48 - seg * 18.0
			var seg_wobble = sin(t * 4.0 + seg * 0.6 + tent) * (6.0 + seg * 2.0)
			t_pts.append(Vector2(seg_x, t_y + seg_wobble))
		draw_polyline(t_pts, Color("#a855f7", 0.85), 3.5)

	draw_rect(Rect2(-w * 0.45, deck_y, w * 0.86, 7), Color("#2e1065"))

# --- TIER 16: DARK EXPLORER (OBSIDIAN STEALTH HULL) ---
func _draw_dark_explorer(t: float, deck_y: float) -> void:
	var w = 720.0
	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.49, deck_y - 6),
		Vector2(-w * 0.43, deck_y + 56),
		Vector2(w * 0.39, deck_y + 56),
		Vector2(w * 0.50, deck_y - 12),
		Vector2(w * 0.42, deck_y - 6)
	])
	draw_colored_polygon(hull_pts, Color("#030712"))
	draw_polyline(hull_pts, Color("#1f2937"), 3.5, true)

	for slat in range(4):
		var sx = -60.0 + slat * 35.0
		var pulse = sin(t * 4.5 + slat) * 0.3 + 0.7
		draw_rect(Rect2(sx, deck_y + 12, 22, 28), Color(0.9, 0.05, 0.15, pulse))
		draw_rect(Rect2(sx + 3, deck_y + 15, 16, 22), Color("#ffffff", pulse * 0.8))

	for sp in range(3):
		var sp_x = -w * 0.38 + sp * 85.0
		draw_line(Vector2(sp_x, deck_y - 6), Vector2(sp_x - 10, deck_y - 45), Color("#111827"), 3.5)
		draw_circle(Vector2(sp_x - 10, deck_y - 45), 2.5, Color("#ef4444"))

	for p in range(4):
		var p_t = fmod(t * 3.5 + p * 0.8, 2.5)
		var pp = Vector2(-w * 0.50 - p_t * 16.0, deck_y + 20 + sin(t + p) * 10.0)
		draw_circle(pp, 3.5, Color(0.8, 0.1, 0.2, max(0.0, 0.6 - p_t * 0.2)))

	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.88, 7), Color("#111827"))

# --- TIER 17: ABYSSAL SURVEYOR (ULTIMATE BATHYSCAPHE) ---
func _draw_abyssal_surveyor(t: float, deck_y: float) -> void:
	var w = 740.0
	for beam in range(2):
		var b_start = Vector2(w * 0.36, deck_y + beam * 22.0)
		var b_pts = PackedVector2Array([
			b_start,
			Vector2(w * 0.90, deck_y + 100 + beam * 60.0),
			Vector2(w * 0.72, deck_y + 180 + beam * 60.0),
			b_start + Vector2(0, 16)
		])
		draw_colored_polygon(b_pts, Color(0.2, 0.85, 1.0, 0.22))

	var hull_pts = PackedVector2Array([
		Vector2(-w * 0.49, deck_y - 12),
		Vector2(-w * 0.44, deck_y + 60),
		Vector2(w * 0.40, deck_y + 60),
		Vector2(w * 0.49, deck_y + 8),
		Vector2(w * 0.43, deck_y - 12)
	])
	draw_colored_polygon(hull_pts, Color("#0b1329"))
	draw_polyline(hull_pts, Color("#38bdf8"), 3.5, true)

	for rx in range(int(-w * 0.42), int(w * 0.38), 28):
		draw_circle(Vector2(rx, deck_y + 10), 3.0, Color("#d97706"))

	draw_circle(Vector2(w * 0.38, deck_y - 4), 25.0, Color("#0284c7", 0.5))
	draw_circle(Vector2(w * 0.38, deck_y - 4), 19.0, Color("#38bdf8", 0.9))
	draw_circle(Vector2(w * 0.34, deck_y - 10), 6.0, Color("#ffffff", 0.95))

	draw_line(Vector2(w * 0.44, deck_y + 16), Vector2(w * 0.50, deck_y + 32), Color("#64748b"), 4.0)
	draw_line(Vector2(w * 0.50, deck_y + 32), Vector2(w * 0.54, deck_y + 22), Color("#f59e0b"), 3.0)
	draw_line(Vector2(w * 0.42, deck_y + 38), Vector2(w * 0.48, deck_y + 54), Color("#64748b"), 4.0)
	draw_line(Vector2(w * 0.48, deck_y + 54), Vector2(w * 0.53, deck_y + 50), Color("#f59e0b"), 3.0)

	for b in range(5):
		var b_t = fmod(t * 3.5 + b * 0.7, 3.0)
		draw_circle(Vector2(-w * 0.38 + b * 10.0, deck_y + 55 - b_t * 26.0), 3.0 + b_t * 1.5, Color(0.6, 0.9, 1.0, max(0.0, 0.7 - b_t * 0.2)))

	draw_rect(Rect2(-w * 0.46, deck_y, w * 0.88, 8), Color("#1e293b"))

# ==============================================================================
# DYNAMIC MODULAR UPGRADE ATTACHMENTS (VISUAL PROGRESSION)
# ==============================================================================
func _draw_ship_upgrades(t: float, deck_y: float) -> void:
	var b = GameManager.get_deck_bounds()

	# 1. Salvage Crane / Winch Davit (More Chests >= 3 or Better Chests >= 1)
	if GameManager.upgrades.get("more_chests", 0) >= 3 or GameManager.upgrades.get("better_chests", 0) >= 1:
		_draw_salvage_crane(t, deck_y, b)

	# 2. Aerated Live Aquarium Holding Tank (Salesman >= 3 or Better Fish >= 5)
	if GameManager.upgrades.get("salesman", 0) >= 3 or GameManager.upgrades.get("better_fish", 0) >= 5:
		_draw_aerated_live_tank(t, deck_y, b)

	# 3. Rotating Marine Radar Mast (Experienced >= 2 or Tier >= 5)
	var boat_data = GameManager.boats_database.get(GameManager.current_boat, {})
	var tier = boat_data.get("tier", 1)
	if GameManager.upgrades.get("experienced", 0) >= 2 or tier >= 5:
		_draw_radar_mast(t, deck_y, b)

	# 4. Outboard Jet Booster Turbines (Worker Motivation >= 3 or Speed >= 350)
	var speed = boat_data.get("speed", 200.0)
	if GameManager.upgrades.get("worker_motivation", 0) >= 3 or speed >= 350.0:
		_draw_jet_turbines(t, deck_y, b)

	# 5. Volcanic Fish Oven / Magma Forge (Special Upgrade: Fish Ovens >= 1)
	if GameManager.special_upgrades.get("fish_ovens", 0) >= 1:
		_draw_fish_oven(t, deck_y, b)

# 1. SALVAGE CRANE
func _draw_salvage_crane(t: float, deck_y: float, b: Vector2) -> void:
	var crane_x = b.x + 48.0
	draw_rect(Rect2(crane_x - 6, deck_y - 12, 12, 12), Color("#334155"))
	var elbow = Vector2(crane_x - 14, deck_y - 50)
	var tip = Vector2(crane_x - 38, deck_y - 42)
	draw_line(Vector2(crane_x, deck_y - 10), elbow, Color("#eab308"), 4.0)
	draw_line(elbow, tip, Color("#eab308"), 3.5)
	draw_circle(elbow, 4.0, Color("#1e293b"))
	draw_circle(tip, 3.5, Color("#ca8a04"))
	var hook_y = deck_y + 12.0 + sin(t * 3.0) * 4.0
	draw_line(tip, Vector2(tip.x, hook_y), Color("#cbd5e1"), 1.5)
	draw_line(Vector2(tip.x, hook_y), Vector2(tip.x - 5, hook_y + 7), Color("#94a3b8"), 2.5)
	draw_line(Vector2(tip.x, hook_y), Vector2(tip.x + 5, hook_y + 7), Color("#94a3b8"), 2.5)

# 2. AERATED LIVE AQUARIUM TANK
func _draw_aerated_live_tank(t: float, deck_y: float, b: Vector2) -> void:
	var tank_x = b.x + 95.0
	var tank_w = 46.0
	var tank_h = 32.0
	var tank_rect = Rect2(tank_x, deck_y - tank_h, tank_w, tank_h)
	draw_rect(tank_rect, Color(0.06, 0.7, 0.8, 0.45))
	draw_rect(tank_rect, Color("#38bdf8"), false, 2.0)
	for bub in range(3):
		var bub_t = fmod(t * 3.5 + bub * 0.9, 1.0)
		var bx = tank_x + 10.0 + bub * 12.0
		var by = deck_y - 4.0 - bub_t * (tank_h - 8.0)
		draw_circle(Vector2(bx, by), 2.0, Color(1.0, 1.0, 1.0, 0.85))
	var fish_x = tank_x + 12.0 + (sin(t * 3.0) * 0.5 + 0.5) * (tank_w - 24.0)
	var fish_dir = cos(t * 3.0)
	draw_circle(Vector2(fish_x, deck_y - 16), 3.0, Color("#f97316"))
	draw_line(Vector2(fish_x, deck_y - 16), Vector2(fish_x - sign(fish_dir) * 4.0, deck_y - 16), Color("#ea580c"), 1.8)

# 3. ROTATING MARINE RADAR MAST
func _draw_radar_mast(t: float, deck_y: float, b: Vector2) -> void:
	var mast_x = b.x * 0.12
	draw_line(Vector2(mast_x, deck_y), Vector2(mast_x, deck_y - 52), Color("#64748b"), 3.0)
	draw_line(Vector2(mast_x - 8, deck_y), Vector2(mast_x, deck_y - 30), Color("#94a3b8"), 1.5)
	draw_line(Vector2(mast_x + 8, deck_y), Vector2(mast_x, deck_y - 30), Color("#94a3b8"), 1.5)
	var bar_w = sin(t * 4.5) * 16.0
	draw_line(Vector2(mast_x - bar_w, deck_y - 54), Vector2(mast_x + bar_w, deck_y - 54), Color("#f8fafc"), 4.0)
	draw_circle(Vector2(mast_x - 12, deck_y - 40), 2.5, Color("#ef4444"))
	draw_circle(Vector2(mast_x + 12, deck_y - 40), 2.5, Color("#22c55e"))

# 4. OUTBOARD JET BOOSTER TURBINES
func _draw_jet_turbines(t: float, deck_y: float, b: Vector2) -> void:
	var turb_x = b.x - 8.0
	for ty_offset in [-14.0, 10.0]:
		var ty = deck_y + ty_offset
		draw_rect(Rect2(turb_x - 16, ty - 6, 16, 12), Color("#334155"))
		draw_rect(Rect2(turb_x - 16, ty - 4, 4, 8), Color("#cbd5e1"))
		var flame_len = 16.0 + sin(t * 30.0 + ty_offset) * 6.0
		var flame_pts = PackedVector2Array([
			Vector2(turb_x - 16, ty - 5),
			Vector2(turb_x - 16 - flame_len, ty),
			Vector2(turb_x - 16, ty + 5)
		])
		draw_colored_polygon(flame_pts, Color(0.2, 0.85, 1.0, 0.75))
		draw_colored_polygon(PackedVector2Array([
			Vector2(turb_x - 16, ty - 2),
			Vector2(turb_x - 16 - flame_len * 0.5, ty),
			Vector2(turb_x - 16, ty + 2)
		]), Color("#ffffff"))

# 5. VOLCANIC FISH OVEN
func _draw_fish_oven(t: float, deck_y: float, b: Vector2) -> void:
	var oven_x = b.y * 0.52
	draw_rect(Rect2(oven_x - 16, deck_y - 28, 32, 28), Color("#1c1917"))
	draw_rect(Rect2(oven_x - 16, deck_y - 28, 32, 28), Color("#44403c"), false, 2.0)
	var ember = sin(t * 6.0) * 0.25 + 0.75
	draw_rect(Rect2(oven_x - 10, deck_y - 18, 20, 14), Color(1.0, 0.35, 0.05, ember))
	draw_rect(Rect2(oven_x - 4, deck_y - 42, 8, 14), Color("#292524"))
	for s in range(2):
		var s_t = fmod(t * 4.0 + s * 1.5, 2.0)
		var sp_pos = Vector2(oven_x + sin(t * 5.0 + s) * 4.0, deck_y - 44 - s_t * 12.0)
		draw_circle(sp_pos, 1.8, Color(1.0, 0.7, 0.1, max(0.0, 0.8 - s_t * 0.4)))

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
	var rail_y = deck_y - 12.0
	# Subtle top brass/timber rail
	draw_line(Vector2(b.x + 8.0, rail_y), Vector2(b.y - 8.0, rail_y), Color("#ca8a04", 0.85), 2.0)
	draw_line(Vector2(b.x + 8.0, rail_y + 1.0), Vector2(b.y - 8.0, rail_y + 1.0), Color("#78350f", 0.7), 1.5)
	# Upright timber posts with brass caps
	var step = 48
	for rx in range(int(b.x + 16), int(b.y - 16), step):
		draw_line(Vector2(rx, rail_y), Vector2(rx, deck_y), Color("#451a03", 0.85), 1.8)
		draw_circle(Vector2(rx, rail_y), 1.8, Color("#facc15", 0.95))

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

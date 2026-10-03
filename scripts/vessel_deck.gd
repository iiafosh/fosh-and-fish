extends Node2D

@onready var overworld = get_parent()

var tex_rimuru_human: Texture2D
var tex_rimuru_slime: Texture2D

func _ready() -> void:
	tex_rimuru_human = load("res://web/assets/rimuru_human.png")
	tex_rimuru_slime = load("res://web/assets/rimuru_slime.png")

func _draw() -> void:
	var t = Time.get_ticks_msec() * 0.001
	var ship_w = 640.0
	var deck_y = 0.0 # Floor line where boots stand

	# --- 1. LAYER 1: BACK HULL & CABIN ---
	# Cedar wooden hull
	var hull_pts = PackedVector2Array([
		Vector2(-ship_w * 0.48, deck_y),
		Vector2(-ship_w * 0.44, deck_y + 55),
		Vector2(ship_w * 0.38, deck_y + 55),
		Vector2(ship_w * 0.48, deck_y - 12),
		Vector2(ship_w * 0.42, deck_y)
	])
	draw_colored_polygon(hull_pts, Color("#78350f"))
	draw_polyline(hull_pts, Color("#451a03"), 3.0, true)

	# Planking lines
	for py in range(int(deck_y + 12), int(deck_y + 50), 10):
		draw_line(Vector2(-ship_w * 0.45, py), Vector2(ship_w * 0.39, py), Color(0.18, 0.08, 0.03, 0.45), 1.5)

	# Stern Lantern Post
	draw_rect(Rect2(-ship_w * 0.44, deck_y - 48, 4, 48), Color("#1e293b"))
	draw_circle(Vector2(-ship_w * 0.44 + 2, deck_y - 50), 8.0, Color(1.0, 0.85, 0.2, 0.35)) # glow
	draw_circle(Vector2(-ship_w * 0.44 + 2, deck_y - 50), 4.5, Color(1.0, 0.95, 0.5, 0.95)) # core

	# Wheelhouse / Pilot Cabin (Behind Mast at center-left)
	draw_rect(Rect2(-55, deck_y - 68, 80, 68), Color("#042f2e"))
	draw_rect(Rect2(-50, deck_y - 64, 70, 64), Color("#0f766e"))
	# Glowing Cabin Windows
	draw_rect(Rect2(-42, deck_y - 56, 22, 18), Color("#38bdf8"))
	draw_rect(Rect2(-12, deck_y - 56, 22, 18), Color("#38bdf8"))

	# Mounted Stern Fishing Rod
	draw_line(Vector2(-ship_w * 0.42, deck_y - 10), Vector2(-ship_w * 0.49, deck_y - 65), Color("#854d0e"), 3.0)
	# Tension fishing line curving down into the waves
	var wave_tip = Vector2(-ship_w * 0.55, deck_y + 24 + sin(t * 3.0) * 4.0)
	draw_line(Vector2(-ship_w * 0.49, deck_y - 65), wave_tip, Color(0.9, 0.95, 1.0, 0.75), 1.2)

	# --- 2. LAYER 2: DECK FLOOR PLANKS ---
	draw_rect(Rect2(-ship_w * 0.46, deck_y, ship_w * 0.89, 9), Color("#b45309"))
	draw_rect(Rect2(-ship_w * 0.46, deck_y + 8, ship_w * 0.89, 2), Color("#78350f"))

	# --- 3. LAYER 2.5: PHYSICAL DECK STATIONS & PLAQUES ---
	# Station 1: Stern Pier (x = -230)
	_draw_station_sign(Vector2(-230, deck_y), "🎣", "Pier", Color("#38bdf8"))

	# Station 2: Fish Market (x = -115)
	# Striped awning
	draw_rect(Rect2(-135, deck_y - 48, 40, 8), Color("#ea580c"))
	draw_rect(Rect2(-135, deck_y - 40, 40, 40), Color("#7c2d12"))
	_draw_station_sign(Vector2(-115, deck_y), "💰", "Market", Color("#facc15"))

	# Station 3: Captain's Helm (x = 0)
	# Mahogany Ship Wheel
	draw_circle(Vector2(0, deck_y - 28), 14.0, Color("#451a03"))
	draw_circle(Vector2(0, deck_y - 28), 10.0, Color("#78350f"))
	draw_circle(Vector2(0, deck_y - 28), 3.0, Color("#fde047"))
	_draw_station_sign(Vector2(0, deck_y), "🧭", "Helm", Color("#4ade80"))

	# Station 4: Tackle Shop (x = 115)
	draw_rect(Rect2(95, deck_y - 42, 40, 42), Color("#1e293b"))
	_draw_station_sign(Vector2(115, deck_y), "🧰", "Tackle", Color("#c084fc"))

	# Station 5: Sanctuary Shrine (x = 230)
	_draw_station_sign(Vector2(230, deck_y), "🐾", "Sanctuary", Color("#38bdf8"))

	# --- 4. LAYER 3: GROUNDED MASCOT CHARACTER (Feet on deck_y) ---
	if overworld:
		var p_x = overworld.player_deck_x
		var facing = overworld.player_facing
		var is_walk = overworld.is_walking
		var walk_bob = sin(overworld.walk_anim_timer) * 3.0 if is_walk else 0.0
		var breath = sin(t * 3.5) * 1.5

		draw_set_transform(Vector2(p_x, deck_y), 0.0, Vector2(facing, 1.0))

		if GameManager.current_mascot == "rimuru_human" and tex_rimuru_human:
			var h = 82.0
			var w = (float(tex_rimuru_human.get_width()) / float(tex_rimuru_human.get_height())) * h
			var char_y = -h + breath + walk_bob
			draw_texture_rect(tex_rimuru_human, Rect2(-w * 0.5, char_y, w, h), false)
		elif tex_rimuru_slime:
			var bounce = abs(sin(t * 5.0)) * 6.0 if is_walk else abs(sin(t * 2.5)) * 2.0
			var squash = 1.0 + sin(t * 5.0) * 0.12
			var stretch = 1.0 - sin(t * 5.0) * 0.12
			var sw = 50.0 * squash
			var sh = 40.0 * stretch
			draw_texture_rect(tex_rimuru_slime, Rect2(-sw * 0.5, -sh - bounce, sw, sh), false)

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- 5. LAYER 3.5: COMPANION PET IN THE WATER ---
	if GameManager.equipped_pet != "None":
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
				draw_line(pet_pos + Vector2(-5, 0), pet_pos + Vector2(-6, 14), Color(0.7, 0.2, 0.9, 0.6), 2.0)
				draw_line(pet_pos + Vector2(5, 0), pet_pos + Vector2(6, 14), Color(0.7, 0.2, 0.9, 0.6), 2.0)
			"Aethelgard":
				draw_circle(pet_pos, 16.0, Color(1.0, 0.82, 0.15, 0.98))
				draw_circle(pet_pos, 8.0, Color(1.0, 0.35, 0.1, 0.95))
				draw_circle(pet_pos + Vector2(-12, -4), 5.0, Color(1.0, 0.9, 0.4, 0.9))

	# --- 6. LAYER 4: FRONT POLISHED BRASS RAILING ---
	draw_line(Vector2(-ship_w * 0.45, deck_y - 20), Vector2(ship_w * 0.41, deck_y - 20), Color("#d97706"), 3.5)
	for rx in range(int(-ship_w * 0.43), int(ship_w * 0.40), 38):
		draw_line(Vector2(rx, deck_y - 20), Vector2(rx, deck_y), Color("#92400e"), 2.5)

func _draw_station_sign(pos: Vector2, _icon: String, text: String, accent: Color) -> void:
	var plaque_rect = Rect2(pos.x - 28, pos.y - 64, 56, 22)
	draw_rect(plaque_rect, Color(0.12, 0.08, 0.04, 0.92))
	draw_rect(plaque_rect, accent, false, 1.5)
	# Post holding the sign
	draw_line(Vector2(pos.x, pos.y - 42), Vector2(pos.x, pos.y), Color("#451a03"), 2.5)
	var font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(pos.x - 24, pos.y - 48), text, HORIZONTAL_ALIGNMENT_CENTER, 48, 10, accent)

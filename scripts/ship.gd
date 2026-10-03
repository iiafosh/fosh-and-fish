extends CharacterBody2D

# --- Ship Physics Parameters ---
var rotation_speed: float = 2.8
var acceleration: float = 240.0
var friction: float = 0.94
var is_anchored: float = false
var can_control: bool = true

# Current dock target if inside one
var active_dock: Area2D = null

@onready var prompt_label: Label = $PromptLabel
@onready var wake_particles: CPUParticles2D = $WakeParticles

func _ready() -> void:
	if prompt_label:
		prompt_label.visible = false

func _physics_process(delta: float) -> void:
	if not can_control:
		velocity = velocity.lerp(Vector2.ZERO, friction)
		move_and_slide()
		queue_redraw()
		return

	# Handle Interaction Input
	if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_E):
		if active_dock != null and active_dock.has_method("get_dock_data"):
			GameManager.open_station_requested.emit(active_dock.get_dock_data())
			can_control = false
			return

	# Steering Input
	var turn_dir = Input.get_axis("ui_left", "ui_right")
	if turn_dir == 0:
		turn_dir = Input.get_axis("ui_left", "ui_right") # or A/D
		if Input.is_key_pressed(KEY_A):
			turn_dir = -1.0
		elif Input.is_key_pressed(KEY_D):
			turn_dir = 1.0

	var move_forward = 0.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		move_forward = 1.0
	elif Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		move_forward = -0.5

	# Anchor toggle
	if Input.is_key_pressed(KEY_SPACE):
		is_anchored = true
	else:
		if move_forward != 0.0:
			is_anchored = false

	if is_anchored:
		velocity = velocity.lerp(Vector2.ZERO, 0.15)
	else:
		# Rotate ship
		rotation += turn_dir * rotation_speed * delta

		# Forward thrust
		var max_speed = GameManager.get_boat_speed()
		var forward_vec = Vector2.UP.rotated(rotation)
		if move_forward > 0.0:
			velocity += forward_vec * acceleration * delta
			if velocity.length() > max_speed:
				velocity = velocity.normalized() * max_speed
		elif move_forward < 0.0:
			velocity += forward_vec * (acceleration * 0.5) * delta * -1.0
		else:
			# Water drag
			velocity = velocity.lerp(Vector2.ZERO, 1.0 - pow(friction, delta * 60.0))

	# Update Wake Particles
	if wake_particles:
		wake_particles.emitting = velocity.length() > 20.0 and not is_anchored

	move_and_slide()
	queue_redraw()

func _draw() -> void:
	# Draw Boat Hull (facing Vector2.UP)
	var hull_color = Color("#d97706") # warm oak
	var rim_color = Color("#78350f")  # dark timber
	var deck_color = Color("#fef3c7") # clean birch deck
	
	if GameManager.current_boat == "Speedboat":
		hull_color = Color("#0284c7")
		rim_color = Color("#0369a1")
		deck_color = Color("#e0f2fe")
	elif GameManager.current_boat == "Fishing Boat":
		hull_color = Color("#059669")
		rim_color = Color("#047857")
		deck_color = Color("#d1fae5")

	# Hull polygon
	var points = PackedVector2Array([
		Vector2(0, -28),    # Bow (pointy front)
		Vector2(14, -10),
		Vector2(14, 18),
		Vector2(-14, 18),
		Vector2(-14, -10)
	])
	draw_colored_polygon(points, hull_color)
	draw_polyline(points, rim_color, 2.5, true)

	# Inner Deck
	var inner_points = PackedVector2Array([
		Vector2(0, -22),
		Vector2(10, -8),
		Vector2(10, 14),
		Vector2(-10, 14),
		Vector2(-10, -8)
	])
	draw_colored_polygon(inner_points, deck_color)

	# Cabin / Helm
	draw_rect(Rect2(-6, -4, 12, 10), Color("#475569"))
	draw_rect(Rect2(-4, -2, 8, 3), Color("#38bdf8")) # windshield

	# Fisherman Figure
	draw_circle(Vector2(0, 8), 4.5, Color("#fcd34d")) # cap
	draw_circle(Vector2(0, 9), 3.0, Color("#1e293b")) # raincoat

	# Rimuru Mascot companion on the deck!
	if GameManager.current_mascot == "rimuru_slime":
		var bounce_offset = sin(Time.get_ticks_msec() * 0.006) * 1.5
		var slime_pos = Vector2(-5, 6 + bounce_offset)
		draw_circle(slime_pos, 3.8, Color(0.2, 0.7, 1.0, 0.95))
		draw_circle(slime_pos + Vector2(1, -1), 1.2, Color(1, 1, 1, 0.8))
		draw_circle(slime_pos + Vector2(-1.2, 0), 0.6, Color(0, 0, 0))
		draw_circle(slime_pos + Vector2(1.2, 0), 0.6, Color(0, 0, 0))
	elif GameManager.current_mascot == "rimuru_human":
		var rimuru_pos = Vector2(-5, 7)
		draw_circle(rimuru_pos + Vector2(0, -3), 3.5, Color(0.35, 0.65, 0.95))
		draw_circle(rimuru_pos, 3.0, Color(0.12, 0.12, 0.18))
		draw_circle(rimuru_pos + Vector2(0, 2), 1.5, Color(0.9, 0.75, 0.2))

	# Equipped Companion Pet swimming alongside
	if GameManager.equipped_pet != "None":
		var pet_wobble = sin(Time.get_ticks_msec() * 0.005) * 3.0
		var pet_pos = Vector2(19, 2 + pet_wobble)
		match GameManager.equipped_pet:
			"Axo-9":
				draw_circle(pet_pos, 4.5, Color(1.0, 0.4, 0.7, 0.9))
				draw_circle(pet_pos + Vector2(-2, -2), 1.5, Color(0.2, 1.0, 0.8))
				draw_circle(pet_pos + Vector2(-2, 2), 1.5, Color(0.2, 1.0, 0.8))
			"Otto-Flux":
				draw_circle(pet_pos, 5.0, Color(0.4, 0.8, 1.0, 0.9))
				draw_circle(pet_pos + Vector2(2, 0), 2.5, Color(0.9, 0.9, 1.0))
			"Chrono-Jelly":
				draw_circle(pet_pos, 5.5, Color(0.8, 0.3, 1.0, 0.8))
				draw_line(pet_pos, pet_pos + Vector2(0, 7), Color(0.6, 0.2, 0.9, 0.6), 1.5)
				draw_line(pet_pos + Vector2(-2, 0), pet_pos + Vector2(-3, 6), Color(0.6, 0.2, 0.9, 0.6), 1.0)
				draw_line(pet_pos + Vector2(2, 0), pet_pos + Vector2(3, 6), Color(0.6, 0.2, 0.9, 0.6), 1.0)
			"Aethelgard":
				draw_circle(pet_pos, 6.5, Color(1.0, 0.8, 0.1, 0.95))
				draw_circle(pet_pos, 3.0, Color(1.0, 0.3, 0.1))

	# Fishing Rod extending from the stern
	draw_line(Vector2(5, 12), Vector2(16, 26), Color("#713f12"), 2.0)
	draw_line(Vector2(16, 26), Vector2(18, 34), Color("#e2e8f0"), 1.0) # line

func set_active_dock(dock: Area2D) -> void:
	active_dock = dock
	if prompt_label:
		if active_dock != null and active_dock.has_method("get_dock_data"):
			var d_data = active_dock.get_dock_data()
			prompt_label.text = "⚓ Press [E] to Dock at " + d_data.get("name", "Port")
			prompt_label.visible = true
		else:
			prompt_label.visible = false

extends Node2D

@export var fish_name: String = "Cod"
@export var biome: String = "River"
@export var swim_speed: float = 65.0
@export var wander_radius: float = 600.0

var velocity: Vector2 = Vector2.ZERO
var target_heading: Vector2 = Vector2.RIGHT
var target_change_timer: float = 0.0
var wag_time: float = 0.0
var flee_speed_mult: float = 1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var ripple_particles: CPUParticles2D = $RippleParticles

var player_ship: Node2D = null

func _ready() -> void:
	wag_time = randf() * 10.0
	target_change_timer = randf_range(1.5, 4.0)
	target_heading = Vector2.RIGHT.rotated(randf() * TAU)
	
	# Match sprite based on species
	_setup_species_visuals()

func _setup_species_visuals() -> void:
	if not sprite:
		return
		
	var tex_path = "res://web/assets/Fish_Cod.png"
	var scale_factor = 0.45
	var tint = Color(1, 1, 1, 0.75)
	
	match fish_name:
		"Cod":
			tex_path = "res://web/assets/Fish_Cod.png"
			scale_factor = 0.40
			swim_speed = 55.0
		"Raw Salmon":
			tex_path = "res://web/assets/Fish_Cod.png"
			tint = Color(1.0, 0.6, 0.5, 0.8)
			scale_factor = 0.42
			swim_speed = 65.0
		"Bluefin Tuna":
			tex_path = "res://web/assets/Fish_Bluefin Tuna.png"
			scale_factor = 0.65
			swim_speed = 95.0
		"Anchovy", "Sardine":
			tex_path = "res://web/assets/Fish_Anchovy.png"
			scale_factor = 0.28
			swim_speed = 70.0
		"Dolphin":
			tex_path = "res://web/assets/dolphin.png"
			scale_factor = 0.70
			swim_speed = 120.0
		"Abyssal Kraken":
			tex_path = "res://web/assets/kraken.png"
			scale_factor = 0.90
			tint = Color(0.9, 0.1, 0.2, 0.85)
			swim_speed = 40.0
		"ERR_404_NULL_EEL":
			tex_path = "res://web/assets/Fish_Cod.png"
			tint = Color(0.0, 1.0, 0.8, 0.9)
			scale_factor = 0.50
			swim_speed = 110.0

	var loaded_tex = load(tex_path)
	if loaded_tex:
		sprite.texture = loaded_tex
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.modulate = tint

func _process(delta: float) -> void:
	wag_time += delta * (8.0 * flee_speed_mult)
	target_change_timer -= delta
	
	# Pick a new gentle wandering heading
	if target_change_timer <= 0.0:
		target_change_timer = randf_range(2.0, 5.0)
		var angle_offset = randf_range(-0.8, 0.8)
		target_heading = target_heading.rotated(angle_offset).normalized()

	# Check distance to player ship (flee behavior)
	flee_speed_mult = 1.0
	if player_ship and is_instance_valid(player_ship):
		var dist = global_position.distance_to(player_ship.global_position)
		if dist < 140.0:
			# Flee away from ship!
			var flee_vec = (global_position - player_ship.global_position).normalized()
			target_heading = target_heading.lerp(flee_vec, 0.15).normalized()
			flee_speed_mult = 2.2
			if ripple_particles:
				ripple_particles.emitting = true

	# Smooth movement
	var current_speed = swim_speed * flee_speed_mult
	velocity = velocity.lerp(target_heading * current_speed, 0.08)
	position += velocity * delta

	# Face movement direction
	if velocity.length() > 5.0:
		rotation = lerp_angle(rotation, velocity.angle(), 0.12)

	# Organic procedural fish wiggle (sinusoidal spine wiggle)
	if sprite:
		var wiggle = sin(wag_time) * 0.12
		sprite.skew = wiggle
		sprite.scale.y = abs(sprite.scale.x) * (1.0 + sin(wag_time * 2.0) * 0.05)

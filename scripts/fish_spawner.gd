extends Node2D

@export var max_fish_count: int = 18
@export var spawn_radius_min: float = 220.0
@export var spawn_radius_max: float = 650.0
@export var despawn_radius: float = 1100.0

var fish_scene = preload("res://scenes/swimming_fish.tscn")
var active_fishes: Array[Node2D] = []

@onready var player_ship: Node2D = get_parent().get_node_or_null("Ship")

var check_timer: float = 0.0

func _ready() -> void:
	# Initial spawn
	for i in range(10):
		_spawn_fish()

func _process(delta: float) -> void:
	check_timer += delta
	if check_timer < 0.6:
		return
	check_timer = 0.0

	if not player_ship or not is_instance_valid(player_ship):
		player_ship = get_parent().get_node_or_null("Ship")
		return

	var ship_pos = player_ship.global_position

	# Despawn distant fish
	for i in range(active_fishes.size() - 1, -1, -1):
		var f = active_fishes[i]
		if not is_instance_valid(f):
			active_fishes.remove_at(i)
			continue
		if f.global_position.distance_to(ship_pos) > despawn_radius:
			f.queue_free()
			active_fishes.remove_at(i)

	# Replenish fish count
	while active_fishes.size() < max_fish_count:
		_spawn_fish()

func _spawn_fish() -> void:
	if not player_ship or not is_instance_valid(player_ship):
		return

	var angle = randf() * TAU
	var dist = randf_range(spawn_radius_min, spawn_radius_max)
	var spawn_pos = player_ship.global_position + Vector2.RIGHT.rotated(angle) * dist

	var fish_inst = fish_scene.instantiate()
	fish_inst.global_position = spawn_pos
	fish_inst.player_ship = player_ship
	
	# Determine species based on biome
	var biome = GameManager.current_biome
	fish_inst.biome = biome
	
	match biome:
		"River":
			var opts = ["Cod", "Raw Salmon", "Anchovy"]
			fish_inst.fish_name = opts.pick_random()
		"Volcanic":
			var opts = ["Raw Salmon", "Cod"]
			fish_inst.fish_name = opts.pick_random()
		"Ocean":
			var opts = ["Bluefin Tuna", "Dolphin", "Sardine", "Anchovy"]
			if randf() < 0.08:
				opts.append("Abyssal Kraken")
			fish_inst.fish_name = opts.pick_random()
		"Subspace 0x00":
			fish_inst.fish_name = "ERR_404_NULL_EEL"
		_:
			fish_inst.fish_name = "Cod"

	add_child(fish_inst)
	active_fishes.append(fish_inst)

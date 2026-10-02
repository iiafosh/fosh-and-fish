extends Area2D

@export var dock_id: String = "river_harbor"
@export var dock_name: String = "Riverwood Harbor"
@export var dock_type: String = "harbor" # "harbor", "fishing_spot", "shipyard"
@export var biome: String = "River"
@export var level_required: int = 1
@export var description: String = "The bustling inland river port. Trade fish and gear."

@onready var label: Label = $DockMarker/Label

var is_player_inside: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if label:
		label.text = dock_name

func get_dock_data() -> Dictionary:
	return {
		"id": dock_id,
		"name": dock_name,
		"type": dock_type,
		"biome": biome,
		"level_required": level_required,
		"description": description
	}

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_active_dock"):
		is_player_inside = true
		body.set_active_dock(self)
		GameManager.dock_available.emit(get_dock_data())

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_active_dock"):
		is_player_inside = false
		body.set_active_dock(null)
		GameManager.dock_cleared.emit()

func _draw() -> void:
	if dock_type == "harbor":
		# Draw Wooden Dock Boardwalk
		draw_rect(Rect2(-45, -30, 90, 60), Color("#78350f"))
		draw_rect(Rect2(-40, -25, 80, 50), Color("#92400e"))
		# Wooden planks lines
		for y in range(-20, 25, 8):
			draw_line(Vector2(-38, y), Vector2(38, y), Color("#451a03"), 1.5)
		# Mooring posts
		draw_circle(Vector2(-35, -20), 4.5, Color("#451a03"))
		draw_circle(Vector2(35, -20), 4.5, Color("#451a03"))
		draw_circle(Vector2(-35, 20), 4.5, Color("#451a03"))
		draw_circle(Vector2(35, 20), 4.5, Color("#451a03"))
		# Lantern glow
		draw_circle(Vector2(0, 0), 10.0, Color(1.0, 0.8, 0.2, 0.35))
		draw_circle(Vector2(0, 0), 4.0, Color(1.0, 0.95, 0.6, 0.9))
	elif dock_type == "fishing_spot":
		# Draw Water Ripples / Buoy
		draw_arc(Vector2.ZERO, 35.0, 0, TAU, 32, Color(0.3, 0.7, 0.9, 0.4), 2.0)
		draw_arc(Vector2.ZERO, 20.0, 0, TAU, 24, Color(0.3, 0.8, 1.0, 0.6), 2.0)
		# Red/White floating Buoy
		draw_circle(Vector2.ZERO, 6.0, Color("#ef4444"))
		draw_circle(Vector2(0, -2), 3.0, Color("#ffffff"))

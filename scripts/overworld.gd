extends Node2D

@onready var ship: CharacterBody2D = $Ship
@onready var station_hub: Control = $CanvasLayer/StationHub
@onready var hud_biome_label: Label = $CanvasLayer/SailingHUD/TopLeft/VBox/BiomeLabel
@onready var hud_speed_label: Label = $CanvasLayer/SailingHUD/TopLeft/VBox/SpeedLabel
@onready var hud_cash_label: Label = $CanvasLayer/SailingHUD/TopRight/CashLabel
@onready var hud_level_label: Label = $CanvasLayer/SailingHUD/TopRight/LevelLabel
@onready var quick_fish_btn: Button = $CanvasLayer/SailingHUD/BottomBar/QuickFishBtn
@onready var loot_popup_label: Label = $CanvasLayer/SailingHUD/Center/LootPopup

var water_time: float = 0.0

func _ready() -> void:
	station_hub.station_closed.connect(_on_station_closed)
	GameManager.stats_changed.connect(_update_hud)
	GameManager.fish_caught.connect(_on_fish_caught)
	_update_hud()

func _process(delta: float) -> void:
	water_time += delta
	queue_redraw()
	
	# Update sailing HUD
	if ship:
		var speed_knots = int(ship.velocity.length() / 15.0)
		hud_speed_label.text = "Speed: %d knots" % speed_knots
		
		# Detect Biome by World Position
		var ship_pos = ship.global_position
		if ship_pos.x > 800 and ship_pos.y > 400:
			GameManager.current_biome = "Volcanic"
		elif ship_pos.x < -800 and ship_pos.y > 400:
			GameManager.current_biome = "Ocean"
		else:
			GameManager.current_biome = "River"
		
		hud_biome_label.text = "Waters: %s Biome" % GameManager.current_biome

func _update_hud() -> void:
	hud_cash_label.text = "$ %d" % GameManager.cash
	hud_level_label.text = "Lv. %d (%d/%d XP)" % [GameManager.level, GameManager.xp, GameManager.xp_needed]

func _on_station_closed() -> void:
	if ship:
		ship.can_control = true

func _on_quick_fish_pressed() -> void:
	# Open a floating open-water fishing spot UI
	var dock_data = {
		"id": "open_water",
		"name": "Open Water Drift",
		"type": "fishing_spot",
		"biome": GameManager.current_biome,
		"level_required": 1,
		"description": "Casting your line directly from the ship into open waters."
	}
	ship.can_control = false
	station_hub.open_dock(dock_data)

func _on_fish_caught(f_name: String, count: int, xp_gained: int, rarity: String) -> void:
	loot_popup_label.text = "+%dx %s! (+%d XP)" % [count, f_name, xp_gained]
	loot_popup_label.visible = true
	var tween = create_tween()
	loot_popup_label.modulate.a = 1.0
	tween.tween_property(loot_popup_label, "modulate:a", 0.0, 2.5)

func _draw() -> void:
	# Draw World Water Gradients & Islands
	# 1. Base River Water
	draw_rect(Rect2(-2400, -1800, 4800, 3600), Color("#0a252c"))
	
	# 2. Volcanic Sector (South-East)
	draw_rect(Rect2(600, 300, 1800, 1500), Color(0.22, 0.08, 0.08, 0.65))
	
	# 3. Ocean Sector (South-West)
	draw_rect(Rect2(-2400, 300, 1800, 1500), Color(0.04, 0.10, 0.22, 0.65))

	# Gentle wave lines
	for i in range(-12, 12):
		var y = i * 140 + sin(water_time + i) * 12
		draw_line(Vector2(-2000, y), Vector2(2000, y), Color(1, 1, 1, 0.04), 2.0)

	# --- Draw Islands ---
	# Riverwood Home Island (near 0, -150)
	_draw_island(Vector2(0, -220), 160, Color("#15803d"), Color("#ca8a04"))
	
	# Volcanic Caldera Island (at 1200, 900)
	_draw_island(Vector2(1200, 850), 200, Color("#3f3f46"), Color("#ea580c"))
	
	# Ocean Coral Atoll (at -1200, 900)
	_draw_island(Vector2(-1200, 850), 180, Color("#0d9488"), Color("#fde047"))

func _draw_island(center: Vector2, radius: float, terrain_col: Color, beach_col: Color) -> void:
	# Beach rim
	draw_circle(center, radius + 14, beach_col)
	# Main landmass
	draw_circle(center, radius, terrain_col)
	# Center hills/peaks
	draw_circle(center + Vector2(-15, -10), radius * 0.5, terrain_col.darkened(0.2))

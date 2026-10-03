extends Node2D

@onready var ship: CharacterBody2D = $Ship
@onready var station_hub: Control = $CanvasLayer/StationHub
@onready var hud_biome_label: Label = $CanvasLayer/SailingHUD/TopLeft/VBox/BiomeLabel
@onready var hud_speed_label: Label = $CanvasLayer/SailingHUD/TopLeft/VBox/SpeedLabel
@onready var hud_cash_label: Label = $CanvasLayer/SailingHUD/TopRight/HBox/CashLabel
@onready var hud_level_label: Label = $CanvasLayer/SailingHUD/TopRight/HBox/LevelLabel
@onready var quick_fish_btn: Button = $CanvasLayer/SailingHUD/BottomBar/QuickFishBtn
@onready var catch_toast: Control = $CanvasLayer/CatchToast
@onready var boss_minigame: Control = $CanvasLayer/BossMinigame

var water_time: float = 0.0

func _ready() -> void:
	station_hub.station_closed.connect(_on_station_closed)
	GameManager.stats_changed.connect(_update_hud)
	GameManager.fish_caught.connect(_on_fish_caught)
	GameManager.boss_hooked.connect(_on_boss_hooked)
	if boss_minigame:
		boss_minigame.boss_resolved.connect(_on_boss_resolved)
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
		if ship_pos.distance_to(Vector2(2000, -1400)) < 650.0:
			GameManager.current_biome = "Subspace 0x00"
		elif ship_pos.x > 800 and ship_pos.y > 400:
			GameManager.current_biome = "Volcanic"
		elif ship_pos.x < -800 and ship_pos.y > 400:
			GameManager.current_biome = "Ocean"
		else:
			GameManager.current_biome = "River"
		
		hud_biome_label.text = "Waters: %s Biome" % GameManager.current_biome

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F and not station_hub.visible and not boss_minigame.visible:
			_on_quick_fish_pressed()

func _update_hud() -> void:
	hud_cash_label.text = "$ %d" % GameManager.cash
	hud_level_label.text = "Lv. %d (%d/%d XP)" % [GameManager.level, GameManager.xp, GameManager.xp_needed]

func _on_station_closed() -> void:
	if ship:
		ship.can_control = true

func _on_boss_hooked(boss_data: Dictionary) -> void:
	if station_hub.visible:
		station_hub.close_dock()
	if ship:
		ship.can_control = false
	boss_minigame.start_encounter(boss_data)

func _on_boss_resolved(caught: bool, boss_data: Dictionary) -> void:
	if ship:
		ship.can_control = true
	if caught and catch_toast:
		catch_toast.show_catch(boss_data["name"], boss_data.get("count", 1), boss_data.get("xp", 5000), "TITAN BOSS", " 💎 +1 Diamond Fish!")

func _on_quick_fish_pressed() -> void:
	AudioManager.play_click()
	# Open a floating open-water fishing spot UI
	var dock_data = {
		"id": "open_water",
		"name": "Open Water Drift (%s)" % GameManager.current_biome,
		"type": "fishing_spot",
		"biome": GameManager.current_biome,
		"level_required": 1,
		"description": "Casting your line directly from the ship into open waters."
	}
	ship.can_control = false
	station_hub.open_dock(dock_data)

func _on_fish_caught(f_name: String, count: int, xp_gained: int, _rarity: String) -> void:
	if catch_toast and not boss_minigame.visible:
		catch_toast.show_catch(f_name, count, xp_gained, _rarity)

func _draw() -> void:
	# Draw Sector Tints & Islands over the Water Shader
	# 1. Volcanic Sector (South-East)
	draw_rect(Rect2(600, 300, 1800, 1500), Color(0.35, 0.08, 0.05, 0.40))
	
	# 2. Ocean Sector (South-West)
	draw_rect(Rect2(-2400, 300, 1800, 1500), Color(0.02, 0.08, 0.25, 0.40))

	# 3. Subspace 0x00 Anomaly Sector (North-East Rift)
	draw_rect(Rect2(1400, -2000, 1200, 1200), Color(0.04, 0.0, 0.12, 0.45))
	var pulse = sin(water_time * 2.5) * 12.0
	draw_arc(Vector2(2000, -1400), 160 + pulse, 0, TAU, 32, Color(0.0, 1.0, 0.8, 0.45), 3.5)
	draw_arc(Vector2(2000, -1400), 90 - pulse * 0.5, 0, TAU, 24, Color(0.8, 0.1, 1.0, 0.45), 2.5)

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

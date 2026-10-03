extends Node2D

# --- Node References ---
@onready var station_hub: Control = $CanvasLayer/StationHub
@onready var boss_minigame: Control = $CanvasLayer/BossMinigame
@onready var catch_toast: Control = $CanvasLayer/CatchToast
@onready var travel_map: Control = $CanvasLayer/TravelMapModal
@onready var inventory_modal: Control = $CanvasLayer/InventoryModal
@onready var shop_modal: Control = $CanvasLayer/ShopModal

# Top HUD
@onready var hud_biome_label: Label = $CanvasLayer/TopHUD/LeftPill/HBox/BiomeLabel
@onready var hud_cash_label: Label = $CanvasLayer/TopHUD/RightPills/CashPill/HBox/CashLabel
@onready var hud_level_label: Label = $CanvasLayer/TopHUD/RightPills/LevelPill/HBox/LevelLabel
@onready var hud_xp_bar: ProgressBar = $CanvasLayer/TopHUD/RightPills/LevelPill/HBox/XPBar
@onready var hud_tokens_label: Label = $CanvasLayer/TopHUD/RightPills/TokensPill/HBox/TokensLabel

# Bottom Dock
@onready var hero_cast_btn: Button = $CanvasLayer/BottomDock/Center/CenterBox/HeroCastBtn
@onready var btn_inventory: Button = $CanvasLayer/BottomDock/Center/LeftBox/InventoryBtn
@onready var btn_shop: Button = $CanvasLayer/BottomDock/Center/LeftBox/ShopBtn
@onready var btn_pets: Button = $CanvasLayer/BottomDock/Center/RightBox/PetsBtn
@onready var btn_map: Button = $CanvasLayer/BottomDock/Center/RightBox/MapBtn

# Prompt Label
@onready var prompt_bubble: PanelContainer = $Vessel/Player/PromptBubble
@onready var prompt_text: Label = $Vessel/Player/PromptBubble/PromptLabel

# Sprites & Containers
@onready var sky_rect: ColorRect = $SkyRect
@onready var sky_tile: TextureRect = $SkyTile
@onready var back_wave: TextureRect = $BackWave
@onready var fore_wave: TextureRect = $ForeWave
@onready var underwater_depth: ColorRect = $UnderwaterDepth
@onready var splash_particles: CPUParticles2D = $SplashParticles
@onready var ambient_particles: CPUParticles2D = $AmbientParticles
@onready var vessel_node: Node2D = $Vessel
@onready var player_node: Node2D = $Vessel/Player
@onready var fish_container: Node2D = $UnderwaterFish

# --- State Variables ---
var sim_time: float = 0.0
var is_cooling_down: bool = false
var cooldown_timer: float = 0.0

# Player Deck Walking
var player_deck_x: float = 0.0
var player_facing: float = 1.0
var walk_anim_timer: float = 0.0
var is_walking: bool = false
const WALK_SPEED: float = 230.0

# Active Station
var active_station: Dictionary = {}

# Textures
var fish_textures: Dictionary = {}

# Swimming fish underwater
var underwater_fishes: Array[Dictionary] = []

# Weather & Storm state
var storm_lightning_timer: float = 0.0
var lightning_flash_alpha: float = 0.0

func _ready() -> void:
	# Load Fish Textures
	_load_fish_textures()

	# Connect Game Manager Signals
	GameManager.stats_changed.connect(_update_hud)
	GameManager.fish_caught.connect(_on_fish_caught)
	GameManager.boss_hooked.connect(_on_boss_hooked)
	GameManager.weather_changed.connect(_on_weather_changed)
	GameManager.worker_netted.connect(_on_worker_netted)
	GameManager.treasure_found.connect(_on_treasure_found)

	if boss_minigame:
		boss_minigame.boss_resolved.connect(_on_boss_resolved)

	# Modals setup
	if inventory_modal:
		inventory_modal.visible = false
		inventory_modal.open_shop_requested.connect(func():
			if shop_modal:
				shop_modal.open_modal("hub")
		)
		inventory_modal.open_pets_requested.connect(func():
			_open_station_from_deck({"id": "pets", "name": "Companion Sanctuary", "tab": "pets"})
		)
	if shop_modal:
		shop_modal.visible = false

	# Connect Bottom Dock Buttons directly
	if btn_inventory and not btn_inventory.pressed.is_connected(_toggle_inventory):
		btn_inventory.pressed.connect(_toggle_inventory)
	if btn_shop and not btn_shop.pressed.is_connected(_toggle_shop):
		btn_shop.pressed.connect(func(): _toggle_shop("hub"))
	if btn_pets:
		btn_pets.pressed.connect(func(): _open_station_from_deck({"id": "pets", "name": "Companion Sanctuary", "tab": "pets"}))
	if btn_map and not btn_map.pressed.is_connected(_open_travel_map):
		btn_map.pressed.connect(_open_travel_map)

	# Setup initial underwater fish
	_spawn_underwater_fish()

	# Initial UI state
	_update_hud()
	_update_biome_atmosphere()
	if prompt_bubble:
		prompt_bubble.visible = false
	if travel_map:
		travel_map.visible = false

func _load_fish_textures() -> void:
	var paths = {
		"Cod": "res://web/assets/Fish_Cod.png",
		"Tuna": "res://web/assets/Fish_Bluefin Tuna.png",
		"Anchovy": "res://web/assets/Fish_Anchovy.png",
		"Turtle": "res://web/assets/turtle.png",
		"Dolphin": "res://web/assets/dolphin.png",
		"Kraken": "res://web/assets/kraken.png"
	}
	for k in paths.keys():
		if ResourceLoader.exists(paths[k]):
			fish_textures[k] = load(paths[k])

func _spawn_underwater_fish() -> void:
	underwater_fishes.clear()
	for i in range(12):
		var f_type = "Cod"
		var r = randf()
		if r < 0.25:
			f_type = "Anchovy"
		elif r < 0.50:
			f_type = "Cod"
		elif r < 0.75:
			f_type = "Tuna"
		elif r < 0.90:
			f_type = "Turtle"
		else:
			f_type = "Dolphin"

		var fish_data = {
			"type": f_type,
			"pos": Vector2(randf_range(50, 1230), randf_range(470, 680)),
			"speed": randf_range(45.0, 95.0),
			"dir": 1.0 if randf() > 0.5 else -1.0,
			"wag_offset": randf() * 10.0,
			"depth_scale": randf_range(0.35, 0.65),
			"alpha": randf_range(0.40, 0.80)
		}
		underwater_fishes.append(fish_data)

func _process(delta: float) -> void:
	sim_time += delta

	# 1. Ship Buoyancy Heave & Roll
	var heave = sin(sim_time * 1.8) * 4.5
	var pitch = sin(sim_time * 1.8 + 0.4) * 0.016
	vessel_node.position = Vector2(640.0, 424.0 + heave)
	vessel_node.rotation = pitch

	# 2. Parallax Wave Scroll & Bobbing
	if back_wave:
		back_wave.position.y = 398.0 + sin(sim_time * 1.5) * 3.0
	if fore_wave:
		fore_wave.position.y = 432.0 + sin(sim_time * 2.2) * 3.5

	# 3. Dynamic Player Deck Walking Clamped per Boat Model
	var bounds = GameManager.get_deck_bounds()
	is_walking = false
	var move_dir = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		move_dir -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		move_dir += 1.0

	if move_dir != 0.0:
		is_walking = true
		player_facing = move_dir
		player_deck_x += move_dir * WALK_SPEED * delta
		player_deck_x = clampf(player_deck_x, bounds.x + 12.0, bounds.y - 12.0)
		walk_anim_timer += delta * 12.0
	else:
		walk_anim_timer = 0.0

	# Update Player Node Position on Deck
	var step_bob = sin(walk_anim_timer) * 3.0 if is_walking else sin(sim_time * 3.2) * 1.5
	player_node.position = Vector2(player_deck_x, -6.0 + step_bob)

	# 4. Dynamic Station Proximity Check
	var stations = _get_current_stations(bounds)
	active_station = {}
	for st in stations:
		if abs(player_deck_x - st["x"]) < 42.0:
			active_station = st
			break

	if active_station.is_empty():
		prompt_bubble.visible = false
	else:
		prompt_bubble.visible = true
		prompt_text.text = "[E] %s" % active_station["name"]

	# 5. Cooldown Timer & Dynamic Hero Button State
	if is_cooling_down:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			is_cooling_down = false
			hero_cast_btn.disabled = false
			hero_cast_btn.text = "🎣 CAST LINE [SPACE]"
			hero_cast_btn.modulate = Color(1.0, 1.0, 1.0)
		else:
			hero_cast_btn.disabled = true
			hero_cast_btn.text = "⏳ LINE IN WATER (%.1fs)" % cooldown_timer
			hero_cast_btn.modulate = Color(0.7, 0.95, 1.0)

	# 6. Storm Weather Lightning Engine
	if GameManager.current_weather == "Storm":
		storm_lightning_timer -= delta
		if storm_lightning_timer <= 0.0:
			storm_lightning_timer = randf_range(6.0, 14.0)
			lightning_flash_alpha = 0.85
			AudioManager.play_strike()
	if lightning_flash_alpha > 0.0:
		lightning_flash_alpha = max(0.0, lightning_flash_alpha - delta * 4.0)

	# 7. Update Underwater Fish Positions
	for f in underwater_fishes:
		f["pos"].x += f["speed"] * f["dir"] * delta
		if f["pos"].x > 1320:
			f["pos"].x = -40
			f["dir"] = 1.0
		elif f["pos"].x < -50:
			f["pos"].x = 1310
			f["dir"] = -1.0

	vessel_node.queue_redraw()
	queue_redraw()

func _get_current_stations(bounds: Vector2) -> Array:
	return [
		{"id": "fishing", "x": bounds.x * 0.80, "name": "Stern Fishing Pier",  "tab": "fishing"},
		{"id": "market",  "x": bounds.x * 0.40, "name": "Fish Cargo Market",   "tab": "market"},
		{"id": "helm",    "x": 0.0,              "name": "Navigation Helm",     "tab": "map"},
		{"id": "tackle",  "x": bounds.y * 0.40, "name": "Tackle & Baits",      "tab": "tackle"},
		{"id": "pets",    "x": bounds.y * 0.80, "name": "Companion Sanctuary", "tab": "pets"}
	]

func _toggle_inventory() -> void:
	AudioManager.play_click()
	if inventory_modal:
		if inventory_modal.visible:
			inventory_modal.close_modal()
		else:
			if shop_modal and shop_modal.visible:
				shop_modal.close_modal()
			if travel_map and travel_map.visible:
				travel_map.visible = false
			if station_hub and station_hub.visible:
				station_hub.close_dock()
			inventory_modal.open_modal()

func _toggle_shop(target_view: String = "hub") -> void:
	AudioManager.play_click()
	if shop_modal:
		if shop_modal.visible and shop_modal.current_view == target_view:
			shop_modal.close_modal()
		else:
			if inventory_modal and inventory_modal.visible:
				inventory_modal.close_modal()
			if travel_map and travel_map.visible:
				travel_map.visible = false
			if station_hub and station_hub.visible:
				station_hub.close_dock()
			shop_modal.open_modal(target_view)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if inventory_modal and inventory_modal.visible:
				inventory_modal.close_modal()
			elif shop_modal and shop_modal.visible:
				shop_modal.close_modal()
			elif travel_map and travel_map.visible:
				travel_map.visible = false
			elif station_hub and station_hub.visible:
				station_hub.close_dock()
		elif event.keycode == KEY_I:
			_toggle_inventory()
		elif event.keycode == KEY_S:
			_toggle_shop("hub")
		elif event.keycode == KEY_M:
			_open_travel_map()
		elif event.keycode == KEY_SPACE:
			var modal_active = (inventory_modal and inventory_modal.visible) or (shop_modal and shop_modal.visible) or (station_hub and station_hub.visible) or (boss_minigame and boss_minigame.visible) or (travel_map and travel_map.visible)
			if not modal_active:
				_on_cast_pressed()
		elif event.keycode == KEY_E:
			if not active_station.is_empty():
				_open_station_from_deck(active_station)

func _open_station_from_deck(station_info: Dictionary) -> void:
	AudioManager.play_click()
	var tab_name = station_info.get("tab", "fishing")
	if tab_name == "map":
		_open_travel_map()
	elif tab_name == "market":
		_toggle_shop("hub")
	elif tab_name == "tackle":
		_toggle_shop("bait")
	elif tab_name == "shipyard":
		_toggle_shop("boats")
	else:
		var dock_data = {
			"id": station_info["id"],
			"name": station_info["name"],
			"type": "harbor" if tab_name != "fishing" else "fishing_spot",
			"biome": GameManager.current_biome,
			"level_required": 1,
			"description": "On-Deck Station: %s" % station_info["name"]
		}
		station_hub.open_dock(dock_data)
		match tab_name:
			"pets":
				station_hub._on_pets_btn_pressed()
			"fishing":
				station_hub._on_fishing_btn_pressed()

func _on_dock_btn_pressed(tab_name: String) -> void:
	AudioManager.play_click()
	var dock_data = {
		"id": tab_name,
		"name": "Vessel Management",
		"type": "harbor",
		"biome": GameManager.current_biome,
		"level_required": 1,
		"description": "On-Deck Station Access"
	}
	station_hub.open_dock(dock_data)
	match tab_name:
		"market":
			station_hub._on_market_btn_pressed()
		"tackle":
			station_hub._on_tackle_btn_pressed()
		"shipyard":
			station_hub._on_shipyard_btn_pressed()
		"pets":
			station_hub._on_pets_btn_pressed()
		"fishing":
			station_hub._on_fishing_btn_pressed()

func _on_cast_pressed() -> void:
	if is_cooling_down:
		return

	AudioManager.play_cast()

	# Trigger splash particles
	if splash_particles:
		splash_particles.restart()
		splash_particles.emitting = true

	# Roll fish from GameManager
	var result = GameManager.roll_catch(GameManager.current_biome)

	# Check for Titan Boss
	if result.get("is_boss", false):
		return

	# Start Cooldown
	is_cooling_down = true
	cooldown_timer = GameManager.get_fishing_cooldown()

func _on_fish_caught(f_name: String, count: int, xp_gained: int, rarity: String, quality_data: Dictionary = {}) -> void:
	if catch_toast and not boss_minigame.visible:
		catch_toast.show_catch(f_name, count, xp_gained, rarity, quality_data)

func _on_worker_netted(f_name: String, count: int, earned: int) -> void:
	if catch_toast and not boss_minigame.visible:
		var q_data = {"tag": "⚓ AUTO-NET", "mult": 1.0, "color": Color(0.2, 0.9, 0.8)}
		catch_toast.show_catch(f_name, count, count * 5, "AUTO-TRAWLER", q_data, " +$%d Banked" % earned)

func _on_treasure_found(chest_data: Dictionary) -> void:
	if catch_toast and not boss_minigame.visible:
		catch_toast.show_chest(chest_data)

func _on_boss_hooked(boss_data: Dictionary) -> void:
	if station_hub.visible:
		station_hub.close_dock()
	if travel_map and travel_map.visible:
		travel_map.visible = false
	boss_minigame.start_encounter(boss_data)

func _on_boss_resolved(caught: bool, boss_data: Dictionary) -> void:
	if caught and catch_toast:
		var q_data = {"tag": "👑 TITAN", "mult": 5.0, "color": Color(1.0, 0.15, 0.2)}
		catch_toast.show_catch(boss_data["name"], boss_data.get("count", 1), boss_data.get("xp", 5000), "TITAN BOSS", q_data, " 💎 +1 Diamond Fish!")

func _on_weather_changed(_new_weather: String) -> void:
	_update_biome_atmosphere()
	_update_hud()

func _get_weather_display() -> String:
	match GameManager.current_weather:
		"Rain":
			return "🌧️ Rain (-20% CD)"
		"Storm":
			return "⛈️ Storm (+40% Bite)"
		"Fog":
			return "🌫️ Fog (+50% Qual)"
		_:
			return "☀️ Clear Sea"

func _update_hud() -> void:
	hud_biome_label.text = "%s  •  %s" % [GameManager.current_biome, _get_weather_display()]
	hud_cash_label.text = "$ %d" % GameManager.cash
	hud_level_label.text = "Lv. %d" % GameManager.level
	hud_xp_bar.max_value = GameManager.xp_needed
	hud_xp_bar.value = GameManager.xp

	var bait_name = GameManager.current_bait
	var bait_ct = GameManager.bait_stock.get(bait_name, 0)
	var bait_badge = "🪱 %s (%d)" % [bait_name, bait_ct] if bait_name != "None" else "🪝 No Bait"
	hud_tokens_label.text = "🪙 %d  💎 %d  |  %s" % [GameManager.gold_fish, GameManager.diamond_fish, bait_badge]

func _update_biome_atmosphere() -> void:
	var biome = GameManager.current_biome
	var weather = GameManager.current_weather

	# Base Biome Colors
	var sky_col = Color("#38bdf8")
	var under_col = Color("#073b5c")
	var ambient_col = Color(1.0, 1.0, 0.8, 0.4)

	match biome:
		"River":
			sky_col = Color("#38bdf8")
			under_col = Color("#073b5c")
			ambient_col = Color(1.0, 1.0, 0.8, 0.4)
		"Volcanic":
			sky_col = Color("#450a0a")
			under_col = Color("#2d0505")
			ambient_col = Color(1.0, 0.4, 0.1, 0.6)
		"Ocean":
			sky_col = Color("#0f172a")
			under_col = Color("#02182b")
			ambient_col = Color(0.3, 0.8, 1.0, 0.4)
		"Subspace 0x00":
			sky_col = Color("#050014")
			under_col = Color("#140026")
			ambient_col = Color(0.0, 1.0, 0.9, 0.7)

	# Weather Overrides
	if weather == "Rain":
		sky_col = sky_col.darkened(0.25)
	elif weather == "Storm":
		sky_col = sky_col.darkened(0.50)
	elif weather == "Fog":
		sky_col = sky_col.lerp(Color(0.8, 0.85, 0.9), 0.35)

	sky_rect.color = sky_col
	underwater_depth.color = under_col
	if ambient_particles:
		ambient_particles.color = ambient_col

func _open_travel_map() -> void:
	AudioManager.play_click()
	if travel_map:
		travel_map.visible = true

func travel_to_biome(target_biome: String) -> void:
	AudioManager.play_strike()
	GameManager.current_biome = target_biome
	_update_biome_atmosphere()
	_spawn_underwater_fish()
	if travel_map:
		travel_map.visible = false
	if catch_toast:
		catch_toast.show_catch("Voyage Arrived", 1, 50, "VOYAGE", {"tag": "VOYAGE", "mult": 1.0, "color": Color(0.4, 0.9, 1.0)}, " Welcome to " + target_biome)

# --- Drawing the Underwater Scenery & Weather Overlays ---
func _draw() -> void:
	# Draw Underwater Swimming Fish (Screen Space)
	for f in underwater_fishes:
		var tex = fish_textures.get(f["type"], fish_textures.get("Cod"))
		if tex:
			var sz = Vector2(tex.get_width(), tex.get_height()) * f["depth_scale"]
			var wag_rot = sin(sim_time * 7.0 + f["wag_offset"]) * 0.10 * f["dir"]
			draw_set_transform(f["pos"], wag_rot, Vector2(f["dir"], 1.0))
			draw_texture_rect(tex, Rect2(-sz.x * 0.5, -sz.y * 0.5, sz.x, sz.y), false, Color(0.6, 0.85, 1.0, f["alpha"]))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Weather Visual Overlays
	if GameManager.current_weather == "Rain" or GameManager.current_weather == "Storm":
		# Diagonal rain streaks
		var streak_count = 55 if GameManager.current_weather == "Rain" else 95
		for r in range(streak_count):
			var rx = fmod(r * 47.0 - sim_time * 280.0, 1340.0)
			var ry = fmod(r * 31.0 + sim_time * 650.0, 480.0)
			draw_line(Vector2(rx, ry), Vector2(rx - 8.0, ry + 22.0), Color(0.75, 0.88, 1.0, 0.45), 1.2)

	elif GameManager.current_weather == "Fog":
		# Soft rolling misty fog layers
		for fy in range(350, 450, 25):
			var f_drift = sin(sim_time * 0.8 + fy * 0.1) * 40.0
			draw_rect(Rect2(f_drift - 50, fy, 1380, 22), Color(0.85, 0.92, 1.0, 0.12))

	# Storm Lightning Screen Flash
	if lightning_flash_alpha > 0.01:
		draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 1.0, 1.0, lightning_flash_alpha))

	# If Subspace 0x00: draw cyber matrix grid scanlines in sky
	if GameManager.current_biome == "Subspace 0x00":
		for y in range(0, 420, 24):
			var scan_alpha = (sin(sim_time * 3.0 + y * 0.05) + 1.0) * 0.12
			draw_line(Vector2(0, y), Vector2(1280, y), Color(0.0, 1.0, 0.9, scan_alpha), 1.0)

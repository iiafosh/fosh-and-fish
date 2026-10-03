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

# Sprite metadata: target on-screen width (px) and whether the source art faces right.
# Source sprites have wildly different resolutions, so we size by width, not by scale.
const FISH_SPRITES = {
	"Sardine":  {"path": "res://web/assets/sardine.png",            "width": 30.0,  "faces_right": false},
	"Anchovy":  {"path": "res://web/assets/Fish_Anchovy.png",       "width": 34.0,  "faces_right": false},
	"Mackerel": {"path": "res://web/assets/mackerel.png",           "width": 44.0,  "faces_right": false},
	"Cod":      {"path": "res://web/assets/Fish_Cod.png",           "width": 62.0,  "faces_right": true},
	"Tuna":     {"path": "res://web/assets/Fish_Bluefin Tuna.png",  "width": 92.0,  "faces_right": true},
	"Turtle":   {"path": "res://web/assets/turtle.png",             "width": 48.0,  "faces_right": false},
	"Sunfish":  {"path": "res://web/assets/sun fish.png",           "width": 64.0,  "faces_right": true},
	"Shark":    {"path": "res://web/assets/shark.png",              "width": 130.0, "faces_right": false}
}
const BIOME_FISH_POOLS = {
	"River":         ["Sardine", "Anchovy", "Mackerel", "Cod"],
	"Volcanic":      ["Mackerel", "Cod", "Tuna", "Sardine"],
	"Ocean":         ["Tuna", "Turtle", "Sunfish", "Mackerel", "Cod", "Shark"],
	"Subspace 0x00": ["Shark", "Sunfish", "Tuna", "Anchovy"]
}

# Swimming fish underwater
var underwater_fishes: Array[Dictionary] = []
var bubbles: Array[Dictionary] = []
var under_color: Color = Color("#073b5c")
var fx_layer: Node2D = null

# Bobber / bite feedback
var bobber_pos: Vector2 = Vector2.ZERO
var cast_total_time: float = 1.0

# Weather & Storm state
var storm_lightning_timer: float = 0.0
var lightning_flash_alpha: float = 0.0

func _ready() -> void:
	# Load Fish Textures
	_load_fish_textures()

	# Render layers: Overworld._draw() would paint *under* its own child ColorRects,
	# so underwater life draws on the UnderwaterFish node (above the depth rect, below the hull)
	# and weather/fishing-line FX draw on a top-most FXLayer (above the front wave).
	fish_container.draw.connect(_draw_underwater)
	fx_layer = Node2D.new()
	fx_layer.name = "FXLayer"
	add_child(fx_layer)
	move_child(fx_layer, $CanvasLayer.get_index())
	fx_layer.draw.connect(_draw_fx)
	for i in range(26):
		bubbles.append(_new_bubble(true))

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

	# Hero Cast Button Gold Glow Styling
	if hero_cast_btn:
		var cast_sb = StyleBoxFlat.new()
		cast_sb.bg_color = Color("#3b1803")
		cast_sb.border_width_left = 2
		cast_sb.border_width_top = 2
		cast_sb.border_width_right = 2
		cast_sb.border_width_bottom = 2
		cast_sb.border_color = Color("#f59e0b")
		cast_sb.corner_radius_top_left = 10
		cast_sb.corner_radius_top_right = 10
		cast_sb.corner_radius_bottom_right = 10
		cast_sb.corner_radius_bottom_left = 10
		cast_sb.shadow_color = Color(0.96, 0.62, 0.07, 0.40)
		cast_sb.shadow_size = 8
		hero_cast_btn.add_theme_stylebox_override("normal", cast_sb)

		var cast_sb_hover = cast_sb.duplicate() as StyleBoxFlat
		cast_sb_hover.bg_color = Color("#78350f")
		cast_sb_hover.border_color = Color("#fde047")
		cast_sb_hover.shadow_color = Color(1.0, 0.88, 0.28, 0.55)
		cast_sb_hover.shadow_size = 12
		hero_cast_btn.add_theme_stylebox_override("hover", cast_sb_hover)

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
	for k in FISH_SPRITES.keys():
		var p = FISH_SPRITES[k]["path"]
		if ResourceLoader.exists(p):
			fish_textures[k] = load(p)

func _spawn_underwater_fish() -> void:
	underwater_fishes.clear()
	var pool: Array = BIOME_FISH_POOLS.get(GameManager.current_biome, BIOME_FISH_POOLS["River"])
	for i in range(14):
		var f_type: String = pool[randi() % pool.size()]
		# Sharks are rare visitors
		if f_type == "Shark" and randf() < 0.6:
			f_type = pool[0]
		# Depth 0 = near surface (bright, small), 1 = deep (dim, larger parallax)
		var depth = randf()
		underwater_fishes.append({
			"type": f_type,
			"pos": Vector2(randf_range(-40, 1320), lerpf(478.0, 640.0, depth)),
			"speed": randf_range(28.0, 70.0) * (1.25 if f_type in ["Tuna", "Shark"] else 1.0),
			"dir": 1.0 if randf() > 0.5 else -1.0,
			"wag_offset": randf() * TAU,
			"size": randf_range(0.85, 1.15) * lerpf(0.85, 1.1, depth),
			"alpha": lerpf(0.95, 0.55, depth),
			"bob": randf() * TAU
		})

func _new_bubble(random_y: bool) -> Dictionary:
	return {
		"pos": Vector2(randf_range(0, 1280), randf_range(470, 720) if random_y else randf_range(700, 740)),
		"speed": randf_range(18.0, 42.0),
		"r": randf_range(1.2, 3.2),
		"phase": randf() * TAU
	}

func _process(delta: float) -> void:
	sim_time += delta

	# 1. Ship Buoyancy Heave & Roll
	# Deck sits at y≈398 so the hull (deck..deck+54) rides above the front wave crest (~440)
	# instead of being hidden underneath it.
	var heave = sin(sim_time * 1.8) * 4.0
	var pitch = sin(sim_time * 1.8 + 0.4) * 0.016
	vessel_node.position = Vector2(640.0, 398.0 + heave)
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
		if f["dir"] > 0.0 and f["pos"].x > 1360:
			f["pos"].x = -80
		elif f["dir"] < 0.0 and f["pos"].x < -80:
			f["pos"].x = 1360

	# 8. Rising bubbles
	for b in bubbles:
		b["pos"].y -= b["speed"] * delta
		b["pos"].x += sin(sim_time * 2.0 + b["phase"]) * 8.0 * delta
		if b["pos"].y < 462.0:
			var nb = _new_bubble(false)
			b["pos"] = nb["pos"]
			b["speed"] = nb["speed"]
			b["r"] = nb["r"]

	vessel_node.queue_redraw()
	fish_container.queue_redraw()
	if fx_layer:
		fx_layer.queue_redraw()

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
	cast_total_time = cooldown_timer

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
	hud_cash_label.text = "$ " + _fmt(GameManager.cash)
	hud_level_label.text = "Lv. %s" % _fmt(GameManager.level)
	hud_xp_bar.max_value = GameManager.xp_needed
	hud_xp_bar.value = GameManager.xp

	var bait_name = GameManager.current_bait
	var bait_ct = GameManager.bait_stock.get(bait_name, 0)
	var bait_badge = "🪱 %s (%s)" % [bait_name, _fmt(bait_ct)] if bait_name != "None" else "🪝 No Bait"
	hud_tokens_label.text = "🪙 %s  💎 %s  |  %s" % [_fmt(GameManager.gold_fish), _fmt(GameManager.diamond_fish), bait_badge]

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
	under_color = under_col
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

# --- Underwater layer (drawn on UnderwaterFish node: above depth rect, below hull & front wave) ---
func _draw_underwater() -> void:
	var c: CanvasItem = fish_container
	var top_col = under_color
	var bot_col = under_color.darkened(0.78)

	# 1. Depth gradient (replaces the flat navy rectangle)
	var band_h = 14.0
	var y = 440.0
	while y < 720.0:
		var k = clampf((y - 440.0) / 280.0, 0.0, 1.0)
		c.draw_rect(Rect2(0, y, 1280, band_h + 1.0), top_col.lerp(bot_col, k * k * 0.6 + k * 0.4))
		y += band_h

	# 2. Swaying god rays from the surface
	for i in range(6):
		var base_x = fmod(i * 233.0 + 90.0, 1380.0) - 50.0
		var sway = sin(sim_time * 0.35 + i * 1.7) * 26.0
		var w_top = 34.0 + float(i % 3) * 14.0
		var ray = PackedVector2Array([
			Vector2(base_x + sway, 470),
			Vector2(base_x + sway + w_top, 470),
			Vector2(base_x + sway * 2.2 + w_top + 120.0, 700),
			Vector2(base_x + sway * 2.2 + 60.0, 700)
		])
		var a = 0.045 + 0.025 * sin(sim_time * 0.9 + i)
		c.draw_colored_polygon(ray, Color(0.75, 0.95, 1.0, a))

	# 3. Fish (back to front by depth)
	for f in underwater_fishes:
		var tex: Texture2D = fish_textures.get(f["type"])
		if tex == null:
			continue
		var meta: Dictionary = FISH_SPRITES[f["type"]]
		var draw_w: float = meta["width"] * f["size"]
		var draw_h: float = draw_w * float(tex.get_height()) / float(tex.get_width())
		# Flip so the fish always faces its swim direction
		var flip = f["dir"] if meta["faces_right"] else -f["dir"]
		var wag = sin(sim_time * 6.0 + f["wag_offset"]) * 0.06
		var bob = sin(sim_time * 1.4 + f["bob"]) * 3.0
		var tint = Color(0.78, 0.92, 1.0, f["alpha"]).lerp(top_col.lightened(0.4), 0.12)
		tint.a = f["alpha"]
		c.draw_set_transform(f["pos"] + Vector2(0, bob), wag, Vector2(flip, 1.0))
		c.draw_texture_rect(tex, Rect2(-draw_w * 0.5, -draw_h * 0.5, draw_w, draw_h), false, tint)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 4. Seabed silhouette + kelp on both sides
	var bed = PackedVector2Array([Vector2(0, 720)])
	for i in range(0, 1281, 64):
		bed.append(Vector2(i, 692.0 + sin(i * 0.013) * 9.0 + sin(i * 0.051) * 4.0))
	bed.append(Vector2(1280, 720))
	c.draw_colored_polygon(bed, bot_col.lerp(Color(0.35, 0.3, 0.2), 0.25))
	for k_i in range(9):
		var kx = [40.0, 78.0, 130.0, 200.0, 1070.0, 1118.0, 1160.0, 1210.0, 1250.0][k_i]
		var kh = 70.0 + float((k_i * 37) % 60)
		var pts = PackedVector2Array()
		for s in range(9):
			var sy = 700.0 - kh * (float(s) / 8.0)
			var sx = kx + sin(sim_time * 1.3 + k_i + s * 0.55) * (float(s) * 1.6)
			pts.append(Vector2(sx, sy))
		c.draw_polyline(pts, Color(0.12, 0.45, 0.3, 0.85), 4.0, true)

	# 5. Bubbles
	for b in bubbles:
		c.draw_arc(b["pos"], b["r"], 0.0, TAU, 10, Color(0.85, 0.97, 1.0, 0.55), 1.0, true)

# --- Top FX layer (above front wave): fishing line, bobber, weather ---
func _draw_fx() -> void:
	var c: CanvasItem = fx_layer

	# 1. Fishing line & bobber while the line is in the water
	if is_cooling_down:
		var facing = player_facing
		var tip_local = Vector2(player_deck_x + facing * 62.0, -96.0)
		var tip = vessel_node.transform * tip_local
		var surface_y = (fore_wave.position.y if fore_wave else 432.0) + 14.0
		var cast_x = tip.x + facing * 96.0
		# Reel in over the final 20% of the cooldown
		var progress = clampf(cooldown_timer / max(0.01, cast_total_time), 0.0, 1.0)
		var reel = clampf((0.2 - progress) / 0.2, 0.0, 1.0)
		var bob_y = surface_y + sin(sim_time * 3.2) * 2.5 - reel * 30.0
		bobber_pos = Vector2(lerpf(cast_x, tip.x + facing * 20.0, reel), bob_y)

		# Sagging line (quadratic bezier)
		var ctrl = Vector2((tip.x + bobber_pos.x) * 0.5, max(tip.y, bobber_pos.y) + 10.0 - reel * 18.0)
		var line_pts = PackedVector2Array()
		for i in range(13):
			var t = float(i) / 12.0
			line_pts.append(tip.lerp(ctrl, t).lerp(ctrl.lerp(bobber_pos, t), t))
		c.draw_polyline(line_pts, Color(0.95, 0.97, 1.0, 0.85), 1.2, true)

		# Expanding ripple rings (flattened circles)
		if reel < 0.5:
			for r_i in range(2):
				var rt = fmod(sim_time * 0.9 + r_i * 0.5, 1.0)
				c.draw_set_transform(bobber_pos + Vector2(0, 3), 0.0, Vector2(1.0, 0.32))
				c.draw_arc(Vector2.ZERO, 6.0 + rt * 22.0, 0.0, TAU, 24, Color(1, 1, 1, 0.55 * (1.0 - rt)), 1.4, true)
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Bobber
		c.draw_circle(bobber_pos, 5.0, Color("#ef4444"))
		c.draw_circle(bobber_pos + Vector2(0, 2.5), 3.2, Color("#f8fafc"))
		c.draw_line(bobber_pos - Vector2(0, 5), bobber_pos - Vector2(0, 9), Color("#1e293b"), 1.5)

	# 2. Weather overlays
	if GameManager.current_weather == "Rain" or GameManager.current_weather == "Storm":
		var streak_count = 70 if GameManager.current_weather == "Rain" else 120
		for r in range(streak_count):
			var rx = fmod(r * 47.0 - sim_time * 280.0, 1340.0)
			if rx < 0.0:
				rx += 1340.0
			var ry = fmod(r * 31.0 + sim_time * 650.0, 470.0)
			c.draw_line(Vector2(rx, ry), Vector2(rx - 8.0, ry + 20.0), Color(0.78, 0.9, 1.0, 0.35), 1.2)
	elif GameManager.current_weather == "Fog":
		for fy in range(300, 470, 24):
			var f_drift = sin(sim_time * 0.6 + fy * 0.1) * 50.0
			c.draw_rect(Rect2(f_drift - 60, fy, 1400, 26), Color(0.88, 0.93, 1.0, 0.09))

	# 3. Subspace scanlines in the sky
	if GameManager.current_biome == "Subspace 0x00":
		for sy in range(0, 420, 24):
			var scan_alpha = (sin(sim_time * 3.0 + sy * 0.05) + 1.0) * 0.10
			c.draw_line(Vector2(0, sy), Vector2(1280, sy), Color(0.0, 1.0, 0.9, scan_alpha), 1.0)

	# 4. Storm lightning flash
	if lightning_flash_alpha > 0.01:
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 1.0, 1.0, lightning_flash_alpha * 0.8))

# --- Number formatting helpers ---
func _fmt(val: int) -> String:
	var s = str(abs(val))
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i != 0:
			res = "," + res
	return ("-" if val < 0 else "") + res

func _fmt_short(val: int) -> String:
	var v = float(val)
	if v >= 1e12:
		return "%.2fT" % (v / 1e12)
	if v >= 1e9:
		return "%.2fB" % (v / 1e9)
	if v >= 1e6:
		return "%.2fM" % (v / 1e6)
	return _fmt(val)

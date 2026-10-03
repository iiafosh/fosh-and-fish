extends Node2D

# --- Node References ---
@onready var station_hub: Control = $CanvasLayer/StationHub
@onready var boss_minigame: Control = $CanvasLayer/BossMinigame
@onready var catch_toast: Control = $CanvasLayer/CatchToast
@onready var travel_map: Control = $CanvasLayer/TravelMapModal

# Top HUD
@onready var hud_biome_label: Label = $CanvasLayer/TopHUD/LeftPill/HBox/BiomeLabel
@onready var hud_cash_label: Label = $CanvasLayer/TopHUD/RightPills/CashPill/HBox/CashLabel
@onready var hud_level_label: Label = $CanvasLayer/TopHUD/RightPills/LevelPill/HBox/LevelLabel
@onready var hud_xp_bar: ProgressBar = $CanvasLayer/TopHUD/RightPills/LevelPill/HBox/XPBar
@onready var hud_tokens_label: Label = $CanvasLayer/TopHUD/RightPills/TokensPill/HBox/TokensLabel

# Bottom Dock
@onready var hero_cast_btn: Button = $CanvasLayer/BottomDock/Center/CenterBox/HeroCastBtn
@onready var btn_market: Button = $CanvasLayer/BottomDock/Center/LeftBox/MarketBtn
@onready var btn_tackle: Button = $CanvasLayer/BottomDock/Center/LeftBox/TackleBtn
@onready var btn_shipyard: Button = $CanvasLayer/BottomDock/Center/RightBox/ShipyardBtn
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
var player_deck_x: float = 0.0 # Clamped between -250 and +250
var player_facing: float = 1.0
var walk_anim_timer: float = 0.0
var is_walking: bool = false
const WALK_SPEED: float = 230.0

# Station Positions (x offsets from vessel center)
const STATIONS = [
	{"id": "fishing", "x": -230.0, "name": "Stern Fishing Pier", "tab": "fishing"},
	{"id": "market",  "x": -115.0, "name": "Fish Cargo Market",  "tab": "market"},
	{"id": "helm",    "x": 0.0,    "name": "Navigation Helm",    "tab": "map"},
	{"id": "tackle",  "x": 115.0,  "name": "Tackle & Baits",     "tab": "tackle"},
	{"id": "pets",    "x": 230.0,  "name": "Companion Sanctuary","tab": "pets"}
]
var active_station: Dictionary = {}

# Textures
var tex_rimuru_human: Texture2D
var tex_rimuru_slime: Texture2D
var fish_textures: Dictionary = {}

# Swimming fish underwater
var underwater_fishes: Array[Dictionary] = []

func _ready() -> void:
	# Load Core Visual Assets
	tex_rimuru_human = load("res://web/assets/rimuru_human.png")
	tex_rimuru_slime = load("res://web/assets/rimuru_slime.png")
	
	fish_textures["Cod"] = load("res://web/assets/Fish_Cod.png")
	fish_textures["Tuna"] = load("res://web/assets/Fish_Bluefin Tuna.png")
	fish_textures["Anchovy"] = load("res://web/assets/Fish_Anchovy.png")
	fish_textures["Turtle"] = load("res://web/assets/turtle.png")
	fish_textures["Dolphin"] = load("res://web/assets/dolphin.png")
	fish_textures["Kraken"] = load("res://web/assets/kraken.png")

	# Connect Signals
	GameManager.stats_changed.connect(_update_hud)
	GameManager.fish_caught.connect(_on_fish_caught)
	GameManager.boss_hooked.connect(_on_boss_hooked)
	if boss_minigame:
		boss_minigame.boss_resolved.connect(_on_boss_resolved)

	# Setup initial underwater fish
	_spawn_underwater_fish()

	# Initial UI state
	_update_hud()
	_update_biome_atmosphere()
	if prompt_bubble:
		prompt_bubble.visible = false
	if travel_map:
		travel_map.visible = false

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

	# 3. Player Deck Walking Input
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
		player_deck_x = clampf(player_deck_x, -260.0, 260.0)
		walk_anim_timer += delta * 12.0
	else:
		walk_anim_timer = 0.0

	# Update Player Position on Deck
	var step_bob = sin(walk_anim_timer) * 3.0 if is_walking else sin(sim_time * 3.5) * 1.5
	player_node.position = Vector2(player_deck_x, -6.0 + step_bob)

	# 4. Station Proximity Check
	active_station = {}
	for st in STATIONS:
		if abs(player_deck_x - st["x"]) < 48.0:
			active_station = st
			break

	if active_station.is_empty():
		prompt_bubble.visible = false
	else:
		prompt_bubble.visible = true
		prompt_text.text = "[E] %s" % active_station["name"]

	# 5. Cooldown Timer
	if is_cooling_down:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			is_cooling_down = false
			hero_cast_btn.disabled = false
			hero_cast_btn.text = "🎣 CAST LINE [SPACE]"
		else:
			hero_cast_btn.disabled = true
			hero_cast_btn.text = "WAIT (%.1fs)" % cooldown_timer

	# 6. Update Underwater Fish Positions
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if not station_hub.visible and not boss_minigame.visible and not (travel_map and travel_map.visible):
				_on_cast_pressed()
		elif event.keycode == KEY_E:
			if not active_station.is_empty():
				_open_station_from_deck(active_station)

func _open_station_from_deck(station_info: Dictionary) -> void:
	AudioManager.play_click()
	var tab_name = station_info.get("tab", "fishing")
	if tab_name == "map":
		_open_travel_map()
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

func _on_fish_caught(f_name: String, count: int, xp_gained: int, rarity: String) -> void:
	if catch_toast and not boss_minigame.visible:
		catch_toast.show_catch(f_name, count, xp_gained, rarity)

func _on_boss_hooked(boss_data: Dictionary) -> void:
	if station_hub.visible:
		station_hub.close_dock()
	if travel_map and travel_map.visible:
		travel_map.visible = false
	boss_minigame.start_encounter(boss_data)

func _on_boss_resolved(caught: bool, boss_data: Dictionary) -> void:
	if caught and catch_toast:
		catch_toast.show_catch(boss_data["name"], boss_data.get("count", 1), boss_data.get("xp", 5000), "TITAN BOSS", " 💎 +1 Diamond Fish!")

func _update_hud() -> void:
	hud_biome_label.text = "%s Waters" % GameManager.current_biome
	hud_cash_label.text = "$ %d" % GameManager.cash
	hud_level_label.text = "Lv. %d" % GameManager.level
	hud_xp_bar.max_value = GameManager.xp_needed
	hud_xp_bar.value = GameManager.xp
	hud_tokens_label.text = "🪙 %d  💎 %d" % [GameManager.gold_fish, GameManager.diamond_fish]

func _update_biome_atmosphere() -> void:
	var biome = GameManager.current_biome
	match biome:
		"River":
			sky_rect.color = Color("#38bdf8")
			underwater_depth.color = Color("#073b5c")
			if ambient_particles:
				ambient_particles.color = Color(1.0, 1.0, 0.8, 0.4)
		"Volcanic":
			sky_rect.color = Color("#450a0a")
			underwater_depth.color = Color("#2d0505")
			if ambient_particles:
				ambient_particles.color = Color(1.0, 0.4, 0.1, 0.6)
		"Ocean":
			sky_rect.color = Color("#0f172a")
			underwater_depth.color = Color("#02182b")
			if ambient_particles:
				ambient_particles.color = Color(0.3, 0.8, 1.0, 0.4)
		"Subspace 0x00":
			sky_rect.color = Color("#050014")
			underwater_depth.color = Color("#140026")
			if ambient_particles:
				ambient_particles.color = Color(0.0, 1.0, 0.9, 0.7)

	hud_biome_label.text = "%s Waters" % biome

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
		catch_toast.show_catch("Voyage Arrived", 1, 50, "VOYAGE", " Welcome to " + target_biome)

# --- Drawing the Lush On-Deck Vessel & Scenery ---
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

	# If Subspace 0x00: draw cyber matrix grid scanlines in sky
	if GameManager.current_biome == "Subspace 0x00":
		for y in range(0, 420, 24):
			var scan_alpha = (sin(sim_time * 3.0 + y * 0.05) + 1.0) * 0.12
			draw_line(Vector2(0, y), Vector2(1280, y), Color(0.0, 1.0, 0.9, scan_alpha), 1.0)

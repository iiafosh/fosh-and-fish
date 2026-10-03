extends Control

signal boss_resolved(caught: bool, boss_data: Dictionary)

@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var boss_title: Label = $CenterContainer/Panel/VBox/BossTitle
@onready var boss_rarity: Label = $CenterContainer/Panel/VBox/BossRarity
@onready var boss_icon: TextureRect = $CenterContainer/Panel/VBox/BossIcon
@onready var pet_perk_label: Label = $CenterContainer/Panel/VBox/PetPerkLabel

# Track elements
@onready var track_area: Control = $CenterContainer/Panel/VBox/HBox/TrackArea
@onready var reel_bar: Panel = $CenterContainer/Panel/VBox/HBox/TrackArea/ReelBar
@onready var fish_marker: TextureRect = $CenterContainer/Panel/VBox/HBox/TrackArea/FishMarker
@onready var tension_bar: ProgressBar = $CenterContainer/Panel/VBox/HBox/TensionBar
@onready var status_label: Label = $CenterContainer/Panel/VBox/StatusLabel

var is_active: bool = false
var current_boss_data: Dictionary = {}

var tension: float = 0.35
var fish_pos: float = 0.5
var fish_target: float = 0.5
var fish_timer: float = 0.0
var fish_speed: float = 0.9

var bar_pos: float = 0.6
var bar_velocity: float = 0.0
const BAR_SIZE: float = 0.26
const GRAVITY: float = 1.8
const LIFT_ACCEL: float = 3.6

const TRACK_HEIGHT: float = 240.0

var reel_sfx_timer: float = 0.0

func _ready() -> void:
	visible = false

func start_encounter(boss_data: Dictionary) -> void:
	current_boss_data = boss_data
	visible = true
	is_active = true
	tension = 0.38
	fish_pos = 0.5
	fish_target = 0.5
	bar_pos = 0.65
	bar_velocity = 0.0
	
	boss_title.text = "⚡ %s ⚡" % boss_data.get("name", "TITAN BOSS")
	boss_rarity.text = "TITAN BOSS ENCOUNTER"
	status_label.text = "HOLD [SPACE] OR [LEFT CLICK] TO REEL!"
	status_label.modulate = Color(1.0, 0.9, 0.4)
	
	# Load appropriate icon
	var b_name = boss_data.get("name", "")
	var tex_path = "res://web/assets/kraken.png"
	if "Glitch" in b_name or "0x" in b_name:
		tex_path = "res://web/assets/asset_1806.png"
	var t = load(tex_path)
	if t:
		boss_icon.texture = t
		fish_marker.texture = t

	# Pet Perk check
	if GameManager.equipped_pet == "Chrono-Jelly":
		fish_speed = 0.55
		pet_perk_label.visible = true
		pet_perk_label.text = "🪼 Chrono-Jelly active: Titan movement slowed by 40%!"
	else:
		fish_speed = 0.95
		pet_perk_label.visible = false

	tension_bar.value = tension * 100.0
	AudioManager.play_strike()
	_update_positions()

func _process(delta: float) -> void:
	if not is_active:
		return

	# 1. Player Input & Reel Bar Physics
	var is_reeling = Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if is_reeling:
		bar_velocity -= LIFT_ACCEL * delta
		reel_sfx_timer += delta
		if reel_sfx_timer > 0.35:
			reel_sfx_timer = 0.0
			AudioManager.play_reel()
	else:
		bar_velocity += GRAVITY * delta
		reel_sfx_timer = 0.0

	bar_velocity = clampf(bar_velocity, -2.5, 2.5)
	bar_pos += bar_velocity * delta

	# Damp and clamp bar position
	if bar_pos <= 0.0:
		bar_pos = 0.0
		bar_velocity = 0.0
	elif bar_pos >= (1.0 - BAR_SIZE):
		bar_pos = 1.0 - BAR_SIZE
		bar_velocity = 0.0

	# 2. Fish AI Movement
	fish_timer -= delta
	if fish_timer <= 0.0:
		fish_timer = randf_range(0.4, 1.2)
		fish_target = randf_range(0.08, 0.92)

	fish_pos = move_toward(fish_pos, fish_target, fish_speed * delta)

	# 3. Tension Check
	var bar_top = bar_pos
	var bar_bottom = bar_pos + BAR_SIZE
	var is_inside = (fish_pos >= bar_top and fish_pos <= bar_bottom)

	if is_inside:
		tension += 0.28 * delta
		reel_bar.modulate = Color(0.3, 1.0, 0.4, 0.9)
	else:
		tension -= 0.22 * delta
		reel_bar.modulate = Color(1.0, 0.3, 0.3, 0.9)

	tension = clampf(tension, 0.0, 1.0)
	tension_bar.value = tension * 100.0

	_update_positions()

	# 4. Victory / Defeat Conditions
	if tension >= 1.0:
		_on_victory()
	elif tension <= 0.0:
		_on_escape()

func _update_positions() -> void:
	if not track_area:
		return
	var usable_h = TRACK_HEIGHT
	# Update Reel Bar
	reel_bar.position.y = bar_pos * usable_h
	reel_bar.size.y = BAR_SIZE * usable_h

	# Update Fish Marker
	fish_marker.position.y = clampf(fish_pos * usable_h - 16, 0.0, usable_h - 32)

func _on_victory() -> void:
	is_active = false
	status_label.text = "🏆 TITAN DEFEATED! REELED IN!"
	status_label.modulate = Color(0.2, 1.0, 0.5)
	AudioManager.play_success()
	
	GameManager.award_boss_catch(current_boss_data)
	boss_resolved.emit(true, current_boss_data)

	var tween = create_tween()
	tween.tween_interval(1.6)
	tween.tween_callback(func(): visible = false)

func _on_escape() -> void:
	is_active = false
	status_label.text = "💥 SNAP! The Titan broke your line and escaped!"
	status_label.modulate = Color(1.0, 0.2, 0.2)
	AudioManager.play_splash()

	boss_resolved.emit(false, current_boss_data)

	var tween = create_tween()
	tween.tween_interval(1.8)
	tween.tween_callback(func(): visible = false)

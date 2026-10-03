extends Control

@onready var panel: PanelContainer = $Panel
@onready var fish_icon: TextureRect = $Panel/Margin/HBox/FishIcon
@onready var rarity_badge: Label = $Panel/Margin/HBox/VBox/RarityBadge
@onready var title_label: Label = $Panel/Margin/HBox/VBox/TitleLabel
@onready var rewards_label: Label = $Panel/Margin/HBox/VBox/RewardsLabel

var active_tween: Tween = null

func _ready() -> void:
	visible = false
	modulate.a = 0.0

func show_catch(fish_name: String, count: int, xp_gained: int, rarity: String, quality_data: Variant = null, exotic_text: String = "") -> void:
	var quality_tag = ""
	var price_mult = 1.0
	var quality_color = Color(1, 1, 1)

	if typeof(quality_data) == TYPE_DICTIONARY:
		quality_tag = quality_data.get("tag", "")
		price_mult = quality_data.get("mult", 1.0)
		quality_color = quality_data.get("color", Color(1, 1, 1))
	elif typeof(quality_data) == TYPE_STRING:
		exotic_text = quality_data

	# Populate visual data
	var title_prefix = ("%s " % quality_tag) if quality_tag != "" else ""
	title_label.text = "%s+%dx %s!" % [title_prefix, count, fish_name]
	title_label.modulate = quality_color
	rarity_badge.text = " %s " % rarity.to_upper()

	var price_estimate = 0
	if GameManager.fish_database.has(fish_name):
		var base_p = GameManager.fish_database[fish_name]["price"]
		price_estimate = int(base_p * count * price_mult * GameManager.get_sell_multiplier())

	rewards_label.text = "+$%d | +%d XP%s" % [price_estimate, xp_gained, exotic_text]

	if rarity == "TITAN BOSS":
		AudioManager.play_strike()
	else:
		AudioManager.play_success()

	# Color code rarity badge
	match rarity:
		"Common":
			rarity_badge.modulate = Color(0.7, 0.8, 0.9)
		"Uncommon":
			rarity_badge.modulate = Color(0.3, 0.9, 0.4)
		"Rare":
			rarity_badge.modulate = Color(0.2, 0.7, 1.0)
		"Epic":
			rarity_badge.modulate = Color(0.8, 0.3, 1.0)
		"Legendary":
			rarity_badge.modulate = Color(1.0, 0.8, 0.1)
		"TITAN BOSS":
			rarity_badge.modulate = Color(1.0, 0.15, 0.2)
		"AUTO-TRAWLER":
			rarity_badge.modulate = Color(0.2, 0.8, 0.7)
		"CHEST":
			rarity_badge.modulate = Color(1.0, 0.85, 0.2)
		_:
			rarity_badge.modulate = Color(1, 1, 1)

	# Load appropriate fish texture
	var tex_path = "res://web/assets/Fish_Cod.png"
	match fish_name:
		"Bluefin Tuna", "Tuna":
			tex_path = "res://web/assets/Fish_Bluefin Tuna.png"
		"Anchovy", "Sardine":
			tex_path = "res://web/assets/Fish_Anchovy.png"
		"Mackerel":
			tex_path = "res://web/assets/Fish_Mackerel.png"
		"Dolphin":
			tex_path = "res://web/assets/dolphin.png"
		"Abyssal Kraken":
			tex_path = "res://web/assets/kraken.png"
		"Turtle":
			tex_path = "res://web/assets/turtle.png"
		"Squid":
			tex_path = "res://web/assets/kraken.png"

	if ResourceLoader.exists(tex_path):
		var loaded_tex = load(tex_path)
		if loaded_tex:
			fish_icon.texture = loaded_tex

	_animate_toast()

func show_chest(chest_data: Dictionary) -> void:
	title_label.text = "📦 %s Hooked!" % chest_data["name"]
	title_label.modulate = Color(1.0, 0.9, 0.4)
	rarity_badge.text = " SUNKEN TREASURE "
	rarity_badge.modulate = Color(1.0, 0.85, 0.2)

	var bonus = chest_data.get("tokens", "")
	rewards_label.text = "+$%d | +%dx %s Bait %s" % [
		chest_data["cash"], chest_data["bait_amt"], chest_data["bait_name"], bonus
	]

	var bag_path = "res://web/assets/bag_of_money.png"
	if ResourceLoader.exists(bag_path):
		fish_icon.texture = load(bag_path)

	AudioManager.play_strike()
	_animate_toast()

func _animate_toast() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	visible = true
	position.y = -80.0
	modulate.a = 0.0

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(self, "position:y", 20.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "modulate:a", 1.0, 0.25)

	# Hold for 2.4 seconds then dismiss
	active_tween.chain().tween_interval(2.4)
	active_tween.chain().tween_property(self, "position:y", -40.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	active_tween.chain().tween_callback(func(): visible = false)

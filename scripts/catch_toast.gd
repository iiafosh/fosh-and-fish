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

func show_catch(fish_name: String, count: int, xp_gained: int, rarity: String, exotic_text: String = "") -> void:
	# Populate visual data
	title_label.text = "+%dx %s!" % [count, fish_name]
	rarity_badge.text = " %s " % rarity.to_upper()
	
	var price_estimate = 0
	if GameManager.fish_database.has(fish_name):
		price_estimate = GameManager.fish_database[fish_name]["price"] * count
	
	rewards_label.text = "+$%d | +%d XP%s" % [price_estimate, xp_gained, exotic_text]
	
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
		_:
			rarity_badge.modulate = Color(1, 1, 1)

	# Load appropriate fish texture
	var tex_path = "res://web/assets/Fish_Cod.png"
	match fish_name:
		"Bluefin Tuna":
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

	var loaded_tex = load(tex_path)
	if loaded_tex:
		fish_icon.texture = loaded_tex

	# Animation Tween: Drop down from top with smooth bounce
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	visible = true
	position.y = -80.0
	modulate.a = 0.0

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(self, "position:y", 20.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "modulate:a", 1.0, 0.25)

	# Hold for 2.2 seconds then dismiss
	active_tween.chain().tween_interval(2.2)
	active_tween.chain().tween_property(self, "position:y", -40.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	active_tween.chain().tween_callback(func(): visible = false)

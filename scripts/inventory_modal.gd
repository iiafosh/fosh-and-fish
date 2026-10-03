extends Control

signal open_shop_requested
signal open_pets_requested
signal close_requested

@onready var panel: PanelContainer = $Panel
@onready var dim_overlay: ColorRect = $DimOverlay

# Profile Labels
@onready var player_title_label: Label = $Panel/Margin/VBox/Header/PlayerTitleLabel
@onready var balance_label: Label = $Panel/Margin/VBox/BalanceLabel
@onready var level_label: Label = $Panel/Margin/VBox/LevelLabel
@onready var xp_bar: ProgressBar = $Panel/Margin/VBox/XPBar

# Gear Labels
@onready var rod_label: Label = $Panel/Margin/VBox/GearBox/RodLabel
@onready var biome_label: Label = $Panel/Margin/VBox/GearBox/BiomeLabel
@onready var pet_label: Label = $Panel/Margin/VBox/GearBox/PetLabel
@onready var bait_label: Label = $Panel/Margin/VBox/GearBox/BaitLabel

# Fish Inventory Container
@onready var fish_list_container: VBoxContainer = $Panel/Margin/VBox/FishSection/FishList
@onready var fish_value_label: Label = $Panel/Margin/VBox/FishSection/ValueRow/FishValueLabel
@onready var sell_all_btn: Button = $Panel/Margin/VBox/FishSection/ValueRow/SellAllBtn

# Exotic & Special Labels
@onready var gold_label: Label = $Panel/Margin/VBox/ExoticsBox/GoldLabel
@onready var emerald_label: Label = $Panel/Margin/VBox/ExoticsBox/EmeraldLabel
@onready var lava_label: Label = $Panel/Margin/VBox/ExoticsBox/LavaLabel
@onready var diamond_label: Label = $Panel/Margin/VBox/ExoticsBox/DiamondLabel
@onready var hooks_label: Label = $Panel/Margin/VBox/SpecialBox/HooksLabel

# Bottom Navigation Buttons
@onready var btn_fish: Button = $Panel/Margin/VBox/NavRow/FishBtn
@onready var btn_shop: Button = $Panel/Margin/VBox/NavRow/ShopBtn
@onready var btn_pets: Button = $Panel/Margin/VBox/NavRow/PetsBtn
@onready var btn_menu: Button = $Panel/Margin/VBox/NavRow/MenuBtn

var active_tween: Tween = null

func _ready() -> void:
	visible = false
	GameManager.stats_changed.connect(refresh_view)
	GameManager.inventory_changed.connect(refresh_view)

	btn_fish.pressed.connect(func():
		AudioManager.play_click()
		close_modal()
	)
	btn_shop.pressed.connect(func():
		AudioManager.play_click()
		close_modal()
		open_shop_requested.emit()
	)
	btn_pets.pressed.connect(func():
		AudioManager.play_click()
		close_modal()
		open_pets_requested.emit()
	)
	btn_menu.pressed.connect(func():
		AudioManager.play_click()
		close_modal()
	)
	sell_all_btn.pressed.connect(_on_sell_all_pressed)

func open_modal() -> void:
	refresh_view()
	visible = true

	if active_tween and active_tween.is_valid():
		active_tween.kill()

	panel.position.y = 740.0
	dim_overlay.modulate.a = 0.0

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(panel, "position:y", 30.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(dim_overlay, "modulate:a", 1.0, 0.22)

func close_modal() -> void:
	AudioManager.play_click()
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(panel, "position:y", 740.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_tween.tween_property(dim_overlay, "modulate:a", 0.0, 0.18)
	active_tween.chain().tween_callback(func():
		visible = false
		close_requested.emit()
	)

func refresh_view() -> void:
	# 1. Profile & Balance (Screenshot 1 Match)
	player_title_label.text = "Inventory of %s" % GameManager.player_name
	balance_label.text = "Balance: $%s" % _format_number(GameManager.cash)
	level_label.text = "%s, %s/%s XP to next level." % [
		GameManager.get_display_level(),
		_format_number(GameManager.xp),
		_format_number(GameManager.xp_needed)
	]
	xp_bar.max_value = GameManager.xp_needed
	xp_bar.value = GameManager.xp

	# 2. Equipped Gear & Companions
	rod_label.text = "Currently using 🎣 %s." % GameManager.current_rod
	biome_label.text = "Current biome: 🌊 %s" % GameManager.current_biome
	pet_label.text = "Pet: 🦎 %s (Level %d)" % [GameManager.equipped_pet, GameManager.pet_level]

	var b_name = GameManager.current_bait
	var b_count = GameManager.bait_stock.get(b_name, 0)
	bait_label.text = "Bait: 🧲 %s (%s)" % [b_name, _format_number(b_count)]

	# 3. Fish Inventory
	for child in fish_list_container.get_children():
		child.queue_free()

	var has_fish = false
	for f_name in GameManager.inventory.keys():
		var count = GameManager.inventory[f_name]
		if count > 0:
			has_fish = true
			var item_lbl = Label.new()
			var icon = "🐟"
			match f_name:
				"Pufferfish", "Fiery Pufferfish": icon = "🐡"
				"Squid", "Abyssal Kraken": icon = "🦑"
				"Turtle": icon = "🐢"
				"Dolphin": icon = "🐬"
			item_lbl.text = "%s %s %s" % [_format_number(count), icon, f_name]
			item_lbl.add_theme_font_size_override("font_size", 12)
			item_lbl.modulate = Color("#f8fafc")
			fish_list_container.add_child(item_lbl)

	if not has_fish:
		var empty_lbl = Label.new()
		empty_lbl.text = "(No fish in cargo hold - cast line to catch!)"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.modulate = Color("#64748b")
		fish_list_container.add_child(empty_lbl)

	var hold_value = GameManager.get_inventory_total_value()
	fish_value_label.text = "Fish Value: $%s" % _format_number(hold_value)
	sell_all_btn.disabled = not has_fish

	# 4. Exotic Fish Counters (Screenshot 1 Match)
	gold_label.text = "%s 🪙 Gold Fish" % _format_number(GameManager.gold_fish)
	emerald_label.text = "%s 🟢 Emerald Fish" % _format_number(GameManager.emerald_fish)
	lava_label.text = "%s 🌶️ Lava Fish" % _format_number(GameManager.lava_fish)
	diamond_label.text = "%s 💎 Diamond Fish" % _format_number(GameManager.diamond_fish)

	# 5. Special Currencies
	hooks_label.text = "%s 🪝 Hooks" % _format_number(GameManager.hooks)

func _on_sell_all_pressed() -> void:
	AudioManager.play_strike()
	var earned = GameManager.sell_all_fish()
	if earned > 0:
		refresh_view()

func _format_number(val: int) -> String:
	var s = str(val)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i != 0:
			res = "," + res
	return res

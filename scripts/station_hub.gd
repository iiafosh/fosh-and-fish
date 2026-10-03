extends Control

signal station_closed

var current_dock_data: Dictionary = {}
var is_cooling_down: bool = false
var cooldown_timer: float = 0.0

@onready var panel: PanelContainer = $Panel
@onready var dim_overlay: ColorRect = $DimOverlay
@onready var title_label: Label = $Panel/Margin/VBox/Header/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/Margin/VBox/Header/VBox/SubtitleLabel
@onready var cash_label: Label = $Panel/Margin/VBox/Header/Currencies/CashContainer/CashLabel
@onready var level_label: Label = $Panel/Margin/VBox/Header/Currencies/LevelContainer/LevelLabel
@onready var xp_bar: ProgressBar = $Panel/Margin/VBox/Header/Currencies/LevelContainer/XPBar
@onready var gold_label: Label = $Panel/Margin/VBox/Header/Currencies/ExoticContainer/GoldLabel
@onready var emerald_label: Label = $Panel/Margin/VBox/Header/Currencies/ExoticContainer/EmeraldLabel

# Tab Buttons
@onready var tab_market_btn: Button = $Panel/Margin/VBox/TabButtons/MarketBtn
@onready var tab_tackle_btn: Button = $Panel/Margin/VBox/TabButtons/TackleBtn
@onready var tab_shipyard_btn: Button = $Panel/Margin/VBox/TabButtons/ShipyardBtn
@onready var tab_pets_btn: Button = $Panel/Margin/VBox/TabButtons/PetsBtn
@onready var tab_upgrades_btn: Button = $Panel/Margin/VBox/TabButtons/UpgradesBtn
@onready var tab_fishing_btn: Button = $Panel/Margin/VBox/TabButtons/FishingBtn

# Content Panels
@onready var market_panel: VBoxContainer = $Panel/Margin/VBox/Content/MarketPanel
@onready var tackle_panel: VBoxContainer = $Panel/Margin/VBox/Content/TacklePanel
@onready var shipyard_panel: VBoxContainer = $Panel/Margin/VBox/Content/ShipyardPanel
@onready var pets_panel: VBoxContainer = $Panel/Margin/VBox/Content/PetsPanel
@onready var upgrades_panel: VBoxContainer = $Panel/Margin/VBox/Content/UpgradesPanel
@onready var fishing_panel: VBoxContainer = $Panel/Margin/VBox/Content/FishingPanel

# Containers
@onready var fish_grid: GridContainer = $Panel/Margin/VBox/Content/MarketPanel/Scroll/FishGrid
@onready var sell_all_btn: Button = $Panel/Margin/VBox/Content/MarketPanel/SellHeader/SellAllBtn
@onready var rods_container: VBoxContainer = $Panel/Margin/VBox/Content/TacklePanel/Scroll/VBox/RodsContainer
@onready var baits_container: VBoxContainer = $Panel/Margin/VBox/Content/TacklePanel/Scroll/VBox/BaitsContainer
@onready var boats_container: VBoxContainer = $Panel/Margin/VBox/Content/ShipyardPanel/Scroll/BoatsContainer
@onready var mascots_container: VBoxContainer = $Panel/Margin/VBox/Content/PetsPanel/Scroll/VBox/MascotsContainer
@onready var pets_container: VBoxContainer = $Panel/Margin/VBox/Content/PetsPanel/Scroll/VBox/PetsContainer
@onready var upgrades_container: VBoxContainer = $Panel/Margin/VBox/Content/UpgradesPanel/Scroll/UpgradesContainer

# Fishing Pier Nodes
@onready var cast_btn: Button = $Panel/Margin/VBox/Content/FishingPanel/Center/CastBtn
@onready var catch_banner: Label = $Panel/Margin/VBox/Content/FishingPanel/Center/CatchBanner
@onready var rod_info_label: Label = $Panel/Margin/VBox/Content/FishingPanel/InfoBar/RodInfoLabel
@onready var bait_info_label: Label = $Panel/Margin/VBox/Content/FishingPanel/InfoBar/BaitInfoLabel
@onready var cd_info_label: Label = $Panel/Margin/VBox/Content/FishingPanel/InfoBar/CDInfoLabel

var active_tween: Tween = null
var fish_tex_cache: Dictionary = {}

func _ready() -> void:
	visible = false
	GameManager.stats_changed.connect(refresh_header)
	GameManager.inventory_changed.connect(refresh_market)
	GameManager.open_station_requested.connect(open_dock)
	
	# Preload fish textures
	fish_tex_cache["Cod"] = load("res://web/assets/Fish_Cod.png")
	fish_tex_cache["Bluefin Tuna"] = load("res://web/assets/Fish_Bluefin Tuna.png")
	fish_tex_cache["Anchovy"] = load("res://web/assets/Fish_Anchovy.png")
	fish_tex_cache["Sardine"] = load("res://web/assets/Fish_Anchovy.png")
	fish_tex_cache["Mackerel"] = load("res://web/assets/Fish_Mackerel.png")
	fish_tex_cache["Turtle"] = load("res://web/assets/turtle.png")
	fish_tex_cache["Dolphin"] = load("res://web/assets/dolphin.png")
	fish_tex_cache["Abyssal Kraken"] = load("res://web/assets/kraken.png")

	refresh_header()

func _process(delta: float) -> void:
	if is_cooling_down:
		cooldown_timer -= delta
		if cooldown_timer <= 0.0:
			is_cooling_down = false
			cast_btn.disabled = false
			cast_btn.text = "🎣 CAST LINE"
		else:
			cast_btn.disabled = true
			cast_btn.text = "WAIT (%.1fs)" % cooldown_timer

func open_dock(dock_data: Dictionary) -> void:
	current_dock_data = dock_data
	visible = true
	
	title_label.text = "⚓ " + dock_data.get("name", "Harbor Station")
	subtitle_label.text = dock_data.get("description", "")
	
	# Show appropriate tabs based on dock type
	var dtype = dock_data.get("type", "harbor")
	if dtype in ["fishing_spot", "portal"]:
		tab_market_btn.visible = false
		tab_tackle_btn.visible = false
		tab_shipyard_btn.visible = false
		tab_pets_btn.visible = false
		tab_upgrades_btn.visible = false
		tab_fishing_btn.visible = true
		_on_fishing_btn_pressed()

		# Easter egg check for subspace portal
		if dock_data.get("id") == "subspace_portal":
			if GameManager.unlock_secret_rod():
				subtitle_label.text = "👾 ANOMALY CRACKED: Unlocked '0xDEADBEEF Dev Glitch Rod'!\n" + subtitle_label.text
				subtitle_label.modulate = Color(0.0, 1.0, 0.9)
				AudioManager.play_strike()
	else:
		subtitle_label.modulate = Color(0.85, 0.8, 0.7)
		tab_market_btn.visible = true
		tab_tackle_btn.visible = true
		tab_shipyard_btn.visible = true
		tab_pets_btn.visible = true
		tab_upgrades_btn.visible = true
		tab_fishing_btn.visible = false
		_on_market_btn_pressed()

	refresh_all()

	# Jev Decision #3: Slide-up bottom drawer tween
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	panel.position.y = 720.0
	dim_overlay.modulate.a = 0.0
	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(panel, "position:y", 200.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(dim_overlay, "modulate:a", 1.0, 0.25)

func close_dock() -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(panel, "position:y", 720.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_tween.tween_property(dim_overlay, "modulate:a", 0.0, 0.2)
	active_tween.chain().tween_callback(func():
		visible = false
		station_closed.emit()
		GameManager.close_station_requested.emit()
	)

func refresh_all() -> void:
	refresh_header()
	refresh_market()
	refresh_tackle()
	refresh_shipyard()
	refresh_fishing_view()
	refresh_pets_and_mascots()
	refresh_upgrades()

func refresh_header() -> void:
	cash_label.text = "$ " + str(GameManager.cash)
	level_label.text = "Lv. " + str(GameManager.level)
	xp_bar.max_value = GameManager.xp_needed
	xp_bar.value = GameManager.xp
	gold_label.text = "🪙 " + str(GameManager.gold_fish)
	emerald_label.text = "💎 " + str(GameManager.diamond_fish)

func refresh_market() -> void:
	for child in fish_grid.get_children():
		child.queue_free()

	var mult = GameManager.get_sell_multiplier()
	var total_count = 0
	var total_value = 0

	for f_name in GameManager.fish_database.keys():
		var count = GameManager.inventory.get(f_name, 0)
		var f_data = GameManager.fish_database[f_name]
		var unit_price = int(f_data["price"] * mult)
		if count > 0:
			total_count += count
			total_value += count * unit_price

		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(240, 100)

		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		# Fish Icon
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(48, 48)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var icon_tex = fish_tex_cache.get(f_name, fish_tex_cache["Cod"])
		if icon_tex:
			icon_rect.texture = icon_tex
		hbox.add_child(icon_rect)

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl = Label.new()
		name_lbl.text = f_name
		name_lbl.modulate = f_data["color"]
		name_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(name_lbl)

		var info_lbl = Label.new()
		info_lbl.text = "Owned: %d | $%d each" % [count, unit_price]
		info_lbl.add_theme_font_size_override("font_size", 10)
		info_lbl.modulate = Color(0.9, 0.9, 0.9) if count > 0 else Color(0.5, 0.5, 0.5)
		vbox.add_child(info_lbl)

		if count > 0:
			var btn_row = HBoxContainer.new()
			btn_row.add_theme_constant_override("separation", 6)

			var sell_single_btn = Button.new()
			sell_single_btn.text = "Sell 1 ($%d)" % unit_price
			sell_single_btn.add_theme_font_size_override("font_size", 10)
			sell_single_btn.pressed.connect(func():
				AudioManager.play_click()
				GameManager.inventory[f_name] -= 1
				GameManager.add_cash(unit_price)
				GameManager.inventory_changed.emit()
			)
			btn_row.add_child(sell_single_btn)

			var sell_all_fish_btn = Button.new()
			sell_all_fish_btn.text = "All ($%d)" % (count * unit_price)
			sell_all_fish_btn.add_theme_font_size_override("font_size", 10)
			sell_all_fish_btn.pressed.connect(func():
				AudioManager.play_click()
				GameManager.sell_fish(f_name)
			)
			btn_row.add_child(sell_all_fish_btn)
			vbox.add_child(btn_row)

		hbox.add_child(vbox)
		margin.add_child(hbox)
		card.add_child(margin)
		fish_grid.add_child(card)

	sell_all_btn.disabled = (total_count <= 0)
	sell_all_btn.text = "💰 Sell All Catch (%d for $%d)" % [total_count, total_value]

func refresh_tackle() -> void:
	for child in rods_container.get_children():
		child.queue_free()

	for r_name in GameManager.rods_database.keys():
		var r_data = GameManager.rods_database[r_name]
		var card = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)

		var lbl = Label.new()
		lbl.text = "🎣 %s | Catches %d-%d fish | %s" % [r_name, r_data["min_fish"], r_data["max_fish"], r_data["desc"]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)

		if r_name == GameManager.current_rod:
			var eq = Label.new()
			eq.text = " [EQUIPPED] "
			eq.modulate = Color(0.2, 0.95, 0.45)
			eq.add_theme_font_size_override("font_size", 12)
			hbox.add_child(eq)
		elif r_name in GameManager.owned_rods:
			var equip_btn = Button.new()
			equip_btn.text = "Equip Rod"
			equip_btn.pressed.connect(func():
				AudioManager.play_click()
				GameManager.current_rod = r_name
				GameManager.save_game()
				refresh_tackle()
				refresh_fishing_view()
			)
			hbox.add_child(equip_btn)
		else:
			var buy_btn = Button.new()
			buy_btn.text = "Buy ($%d)" % r_data["cost"]
			buy_btn.disabled = GameManager.cash < r_data["cost"]
			buy_btn.pressed.connect(func():
				if GameManager.cash >= r_data["cost"]:
					AudioManager.play_click()
					GameManager.cash -= r_data["cost"]
					GameManager.owned_rods.append(r_name)
					GameManager.current_rod = r_name
					GameManager.stats_changed.emit()
					GameManager.save_game()
					refresh_tackle()
					refresh_fishing_view()
			)
			hbox.add_child(buy_btn)

		margin.add_child(hbox)
		card.add_child(margin)
		rods_container.add_child(card)

	# Baits
	for child in baits_container.get_children():
		child.queue_free()

	for b_name in GameManager.baits_database.keys():
		var b_data = GameManager.baits_database[b_name]
		var count = GameManager.bait_stock.get(b_name, 0)
		var card = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)

		var lbl = Label.new()
		lbl.text = "🪱 %s (Stock: %d) - %s" % [b_name, count, b_data["desc"]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)

		if b_name != "None":
			var buy_5_btn = Button.new()
			buy_5_btn.text = "+5 ($%d)" % (b_data["cost"] * 5)
			buy_5_btn.disabled = GameManager.cash < (b_data["cost"] * 5)
			buy_5_btn.pressed.connect(func():
				var c = b_data["cost"] * 5
				if GameManager.cash >= c:
					AudioManager.play_click()
					GameManager.cash -= c
					GameManager.bait_stock[b_name] = GameManager.bait_stock.get(b_name, 0) + 5
					GameManager.stats_changed.emit()
					GameManager.save_game()
					refresh_tackle()
					refresh_fishing_view()
			)
			hbox.add_child(buy_5_btn)

		if b_name == GameManager.current_bait:
			var eq = Label.new()
			eq.text = " [EQUIPPED] "
			eq.modulate = Color(0.2, 0.95, 0.45)
			eq.add_theme_font_size_override("font_size", 12)
			hbox.add_child(eq)
		else:
			var eq_btn = Button.new()
			eq_btn.text = "Select Bait"
			eq_btn.disabled = (b_name != "None" and count <= 0)
			eq_btn.pressed.connect(func():
				AudioManager.play_click()
				GameManager.current_bait = b_name
				GameManager.save_game()
				refresh_tackle()
				refresh_fishing_view()
			)
			hbox.add_child(eq_btn)

		margin.add_child(hbox)
		card.add_child(margin)
		baits_container.add_child(card)

func refresh_shipyard() -> void:
	for child in boats_container.get_children():
		child.queue_free()

	for b_name in GameManager.boats_database.keys():
		var b_data = GameManager.boats_database[b_name]
		var card = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)

		var lbl = Label.new()
		lbl.text = "🚢 %s | Speed: %d knots | CD Bonus: -%.2fs | Bonus Fish: +%d\n%s" % [
			b_name, b_data["speed"], b_data["cd_bonus"], b_data["fish_bonus"], b_data["desc"]
		]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)

		if b_name == GameManager.current_boat:
			var eq = Label.new()
			eq.text = " [ACTIVE HULL] "
			eq.modulate = Color(0.2, 0.95, 0.45)
			eq.add_theme_font_size_override("font_size", 12)
			hbox.add_child(eq)
		elif b_name in GameManager.owned_boats:
			var eq_btn = Button.new()
			eq_btn.text = "Deploy Hull"
			eq_btn.pressed.connect(func():
				AudioManager.play_click()
				GameManager.current_boat = b_name
				GameManager.save_game()
				refresh_shipyard()
				refresh_fishing_view()
			)
			hbox.add_child(eq_btn)
		else:
			var buy_btn = Button.new()
			buy_btn.text = "Upgrade ($%d)" % b_data["cost"]
			buy_btn.disabled = GameManager.cash < b_data["cost"]
			buy_btn.pressed.connect(func():
				if GameManager.cash >= b_data["cost"]:
					AudioManager.play_click()
					GameManager.cash -= b_data["cost"]
					GameManager.owned_boats.append(b_name)
					GameManager.current_boat = b_name
					GameManager.stats_changed.emit()
					GameManager.save_game()
					refresh_shipyard()
					refresh_fishing_view()
			)
			hbox.add_child(buy_btn)

		margin.add_child(hbox)
		card.add_child(margin)
		boats_container.add_child(card)

func refresh_pets_and_mascots() -> void:
	for child in mascots_container.get_children():
		child.queue_free()
	for child in pets_container.get_children():
		child.queue_free()

	for m_key in GameManager.mascots.keys():
		var m_data = GameManager.mascots[m_key]
		var card = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)

		var icon_lbl = Label.new()
		icon_lbl.text = m_data["icon"]
		icon_lbl.add_theme_font_size_override("font_size", 20)
		hbox.add_child(icon_lbl)

		var name_lbl = Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text = "%s\n%s" % [m_data["name"], m_data["desc"]]
		name_lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(name_lbl)

		var btn = Button.new()
		if GameManager.current_mascot == m_key:
			btn.text = "Active Form"
			btn.disabled = true
		else:
			btn.text = "Switch Form"
			btn.pressed.connect(func():
				AudioManager.play_click()
				GameManager.current_mascot = m_key
				GameManager.save_game()
				refresh_pets_and_mascots()
			)
		hbox.add_child(btn)
		margin.add_child(hbox)
		card.add_child(margin)
		mascots_container.add_child(card)

	for p_name in GameManager.pets_database.keys():
		var p_data = GameManager.pets_database[p_name]
		var card = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)

		var icon_lbl = Label.new()
		icon_lbl.text = p_data["icon"]
		icon_lbl.add_theme_font_size_override("font_size", 20)
		hbox.add_child(icon_lbl)

		var info_lbl = Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_lbl.text = "%s (Lv. %d Milestone)\n%s" % [p_name, p_data["req_level"], p_data["desc"]]
		info_lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(info_lbl)

		var btn = Button.new()
		if GameManager.level < p_data["req_level"]:
			btn.text = "Locked (Lv. %d)" % p_data["req_level"]
			btn.disabled = true
		elif GameManager.equipped_pet == p_name:
			btn.text = "Equipped"
			btn.disabled = true
		else:
			btn.text = "Equip Companion"
			btn.pressed.connect(func():
				AudioManager.play_click()
				GameManager.equipped_pet = p_name
				GameManager.save_game()
				refresh_pets_and_mascots()
			)
		hbox.add_child(btn)
		margin.add_child(hbox)
		card.add_child(margin)
		pets_container.add_child(card)

func refresh_upgrades() -> void:
	for child in upgrades_container.get_children():
		child.queue_free()

	var upgrade_defs = [
		{"id": "better_fish", "name": "Master Angler", "icon": "🎣", "desc": "Increases probability of reeling in higher rarity species (+5% per rank)."},
		{"id": "salesman", "name": "Master Merchant", "icon": "💰", "desc": "Negotiates higher payout prices when selling catches (+5% per rank)."},
		{"id": "more_chests", "name": "Treasure Hunter", "icon": "💎", "desc": "Boosts chances of extracting rare gold and diamond fish (+5% per rank)."},
		{"id": "experienced", "name": "Seasoned Sailor", "icon": "📜", "desc": "Maximizes experience gained on all fishing voyages (+10% per rank)."}
	]

	for u in upgrade_defs:
		var u_id = u["id"]
		var rank = GameManager.upgrades.get(u_id, 0)
		var cost = GameManager.get_upgrade_cost(u_id)

		var card = PanelContainer.new()
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)

		var icon_lbl = Label.new()
		icon_lbl.text = u["icon"]
		icon_lbl.add_theme_font_size_override("font_size", 20)
		hbox.add_child(icon_lbl)

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_lbl = Label.new()
		name_lbl.text = "%s [Rank %d / 10]" % [u["name"], rank]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.modulate = Color(1.0, 0.88, 0.4)
		vbox.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = u["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		vbox.add_child(desc_lbl)
		hbox.add_child(vbox)

		var btn = Button.new()
		if rank >= 10:
			btn.text = "MAX RANK"
			btn.disabled = true
		else:
			btn.text = "Upgrade ($%d)" % cost
			btn.disabled = GameManager.cash < cost
			btn.pressed.connect(func():
				if GameManager.buy_perk_upgrade(u_id):
					AudioManager.play_strike()
					refresh_upgrades()
					refresh_header()
			)
		hbox.add_child(btn)

		margin.add_child(hbox)
		card.add_child(margin)
		upgrades_container.add_child(card)

func refresh_fishing_view() -> void:
	rod_info_label.text = "Rod: " + GameManager.current_rod
	var bait_count = GameManager.bait_stock.get(GameManager.current_bait, 0)
	bait_info_label.text = "Bait: %s (%d left)" % [GameManager.current_bait, bait_count]
	cd_info_label.text = "Base CD: %.1fs" % GameManager.get_fishing_cooldown()

# --- Tab Switching ---
func _on_market_btn_pressed() -> void:
	AudioManager.play_click()
	market_panel.visible = true
	tackle_panel.visible = false
	shipyard_panel.visible = false
	pets_panel.visible = false
	upgrades_panel.visible = false
	fishing_panel.visible = false

func _on_tackle_btn_pressed() -> void:
	AudioManager.play_click()
	market_panel.visible = false
	tackle_panel.visible = true
	shipyard_panel.visible = false
	pets_panel.visible = false
	upgrades_panel.visible = false
	fishing_panel.visible = false

func _on_shipyard_btn_pressed() -> void:
	AudioManager.play_click()
	market_panel.visible = false
	tackle_panel.visible = false
	shipyard_panel.visible = true
	pets_panel.visible = false
	upgrades_panel.visible = false
	fishing_panel.visible = false

func _on_pets_btn_pressed() -> void:
	AudioManager.play_click()
	market_panel.visible = false
	tackle_panel.visible = false
	shipyard_panel.visible = false
	pets_panel.visible = true
	upgrades_panel.visible = false
	fishing_panel.visible = false

func _on_upgrades_btn_pressed() -> void:
	AudioManager.play_click()
	market_panel.visible = false
	tackle_panel.visible = false
	shipyard_panel.visible = false
	pets_panel.visible = false
	upgrades_panel.visible = true
	fishing_panel.visible = false
	refresh_upgrades()

func _on_fishing_btn_pressed() -> void:
	AudioManager.play_click()
	market_panel.visible = false
	tackle_panel.visible = false
	shipyard_panel.visible = false
	pets_panel.visible = false
	upgrades_panel.visible = false
	fishing_panel.visible = true
	refresh_fishing_view()

func _on_cast_btn_pressed() -> void:
	if is_cooling_down:
		return
	
	AudioManager.play_cast()
	var dock_biome = current_dock_data.get("biome", "River")
	var result = GameManager.roll_catch(dock_biome)
	
	if result.get("is_boss", false):
		close_dock()
		return
	
	catch_banner.text = "🎉 Reeled in %dx %s (+%d XP)!%s" % [
		result["count"], result["name"], result["xp"], result["exotic"]
	]
	catch_banner.modulate = result["color"]

	is_cooling_down = true
	cooldown_timer = GameManager.get_fishing_cooldown()
	refresh_header()
	refresh_fishing_view()

func _on_sell_all_btn_pressed() -> void:
	AudioManager.play_click()
	var total = GameManager.sell_all_fish()
	if total > 0:
		catch_banner.text = "💰 Sold your entire catch for $%d!" % total
		catch_banner.modulate = Color(0.2, 0.9, 0.4)
	refresh_market()
	refresh_header()

func _on_close_btn_pressed() -> void:
	AudioManager.play_click()
	close_dock()

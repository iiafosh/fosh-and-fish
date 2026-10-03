extends Control

signal station_closed

var current_dock_data: Dictionary = {}
var is_cooling_down: bool = false
var cooldown_timer: float = 0.0

@onready var title_label: Label = $Panel/Header/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/Header/VBox/SubtitleLabel
@onready var cash_label: Label = $Panel/Header/Currencies/CashContainer/CashLabel
@onready var level_label: Label = $Panel/Header/Currencies/LevelContainer/LevelLabel
@onready var xp_bar: ProgressBar = $Panel/Header/Currencies/LevelContainer/XPBar
@onready var gold_label: Label = $Panel/Header/Currencies/ExoticContainer/GoldLabel
@onready var emerald_label: Label = $Panel/Header/Currencies/ExoticContainer/EmeraldLabel

# Tab Buttons
@onready var tab_market_btn: Button = $Panel/TabButtons/MarketBtn
@onready var tab_tackle_btn: Button = $Panel/TabButtons/TackleBtn
@onready var tab_shipyard_btn: Button = $Panel/TabButtons/ShipyardBtn
@onready var tab_fishing_btn: Button = $Panel/TabButtons/FishingBtn
@onready var tab_pets_btn: Button = $Panel/TabButtons/PetsBtn

# Content Panels
@onready var market_panel: VBoxContainer = $Panel/Content/MarketPanel
@onready var tackle_panel: VBoxContainer = $Panel/Content/TacklePanel
@onready var shipyard_panel: VBoxContainer = $Panel/Content/ShipyardPanel
@onready var fishing_panel: VBoxContainer = $Panel/Content/FishingPanel
@onready var pets_panel: VBoxContainer = $Panel/Content/PetsPanel
@onready var mascots_container: VBoxContainer = $Panel/Content/PetsPanel/Scroll/VBox/MascotsContainer
@onready var pets_container: VBoxContainer = $Panel/Content/PetsPanel/Scroll/VBox/PetsContainer

# Market Nodes
@onready var fish_grid: GridContainer = $Panel/Content/MarketPanel/Scroll/FishGrid
@onready var sell_all_btn: Button = $Panel/Content/MarketPanel/SellHeader/SellAllBtn

# Tackle Nodes
@onready var rods_container: VBoxContainer = $Panel/Content/TacklePanel/Scroll/VBox/RodsContainer
@onready var baits_container: VBoxContainer = $Panel/Content/TacklePanel/Scroll/VBox/BaitsContainer

# Shipyard Nodes
@onready var boats_container: VBoxContainer = $Panel/Content/ShipyardPanel/Scroll/BoatsContainer

# Fishing Pier Nodes
@onready var cast_btn: Button = $Panel/Content/FishingPanel/Center/CastBtn
@onready var catch_banner: Label = $Panel/Content/FishingPanel/Center/CatchBanner
@onready var rod_info_label: Label = $Panel/Content/FishingPanel/InfoBar/RodInfoLabel
@onready var bait_info_label: Label = $Panel/Content/FishingPanel/InfoBar/BaitInfoLabel
@onready var cd_info_label: Label = $Panel/Content/FishingPanel/InfoBar/CDInfoLabel

func _ready() -> void:
	visible = false
	GameManager.stats_changed.connect(refresh_header)
	GameManager.inventory_changed.connect(refresh_market)
	GameManager.open_station_requested.connect(open_dock)
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
	
	# Check Level Requirement
	var req = dock_data.get("level_required", 1)
	title_label.text = dock_data.get("name", "Harbor Station")
	subtitle_label.text = dock_data.get("description", "")
	
	if GameManager.level < req:
		subtitle_label.text = "⚠️ LEVEL %d REQUIRED TO ACCESS THIS PORT!" % req
		market_panel.visible = false
		tackle_panel.visible = false
		shipyard_panel.visible = false
		fishing_panel.visible = false
		return

	# Show appropriate tabs based on dock type
	var dtype = dock_data.get("type", "harbor")
	if dtype in ["fishing_spot", "portal"]:
		tab_market_btn.visible = false
		tab_tackle_btn.visible = false
		tab_shipyard_btn.visible = false
		tab_pets_btn.visible = false
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
		tab_fishing_btn.visible = true
		_on_market_btn_pressed()

	refresh_all()

func close_dock() -> void:
	visible = false
	station_closed.emit()
	GameManager.close_station_requested.emit()

func refresh_all() -> void:
	refresh_header()
	refresh_market()
	refresh_tackle()
	refresh_shipyard()
	refresh_fishing_view()
	refresh_pets_and_mascots()

func refresh_header() -> void:
	cash_label.text = "$ " + str(GameManager.cash)
	level_label.text = "Lv. " + str(GameManager.level)
	xp_bar.max_value = GameManager.xp_needed
	xp_bar.value = GameManager.xp
	gold_label.text = "🪙 " + str(GameManager.gold_fish)
	emerald_label.text = "💎 " + str(GameManager.emerald_fish)

func refresh_market() -> void:
	# Clear previous items
	for child in fish_grid.get_children():
		child.queue_free()

	var mult = GameManager.get_sell_multiplier()
	var any_fish = false

	for f_name in GameManager.fish_database.keys():
		var count = GameManager.inventory.get(f_name, 0)
		var f_data = GameManager.fish_database[f_name]
		var unit_price = int(f_data["price"] * mult)

		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(160, 95)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var name_lbl = Label.new()
		name_lbl.text = f_name
		name_lbl.modulate = f_data["color"]
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		var info_lbl = Label.new()
		info_lbl.text = "$%d each | Owned: %d" % [unit_price, count]
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(info_lbl)

		if count > 0:
			any_fish = true
			var sell_single_btn = Button.new()
			sell_single_btn.text = "Sell (%d)" % (count * unit_price)
			sell_single_btn.pressed.connect(func(): GameManager.sell_fish(f_name))
			vbox.add_child(sell_single_btn)

		card.add_child(vbox)
		fish_grid.add_child(card)

	sell_all_btn.disabled = not any_fish

func refresh_tackle() -> void:
	# Rods
	for child in rods_container.get_children():
		child.queue_free()

	for r_name in GameManager.rods_database.keys():
		var r_data = GameManager.rods_database[r_name]
		var hbox = HBoxContainer.new()
		
		var lbl = Label.new()
		lbl.text = "🎣 %s (Catches %d-%d fish) - %s" % [r_name, r_data["min_fish"], r_data["max_fish"], r_data["desc"]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		if r_name == GameManager.current_rod:
			var equipped_lbl = Label.new()
			equipped_lbl.text = "[EQUIPPED]"
			equipped_lbl.modulate = Color(0.2, 0.9, 0.4)
			hbox.add_child(equipped_lbl)
		elif r_name in GameManager.owned_rods:
			var equip_btn = Button.new()
			equip_btn.text = "Equip"
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

		rods_container.add_child(hbox)

	# Baits
	for child in baits_container.get_children():
		child.queue_free()

	for b_name in GameManager.baits_database.keys():
		var b_data = GameManager.baits_database[b_name]
		var hbox = HBoxContainer.new()
		
		var count = GameManager.bait_stock.get(b_name, 0)
		var lbl = Label.new()
		lbl.text = "🪱 %s (Owned: %d) - %s" % [b_name, count, b_data["desc"]]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		if b_name != "None":
			var buy_btn = Button.new()
			buy_btn.text = "Buy 5x ($%d)" % (b_data["cost"] * 5)
			buy_btn.disabled = GameManager.cash < (b_data["cost"] * 5)
			buy_btn.pressed.connect(func():
				var total_cost = b_data["cost"] * 5
				if GameManager.cash >= total_cost:
					AudioManager.play_click()
					GameManager.cash -= total_cost
					GameManager.bait_stock[b_name] = GameManager.bait_stock.get(b_name, 0) + 5
					GameManager.stats_changed.emit()
					GameManager.save_game()
					refresh_tackle()
					refresh_fishing_view()
			)
			hbox.add_child(buy_btn)

		if b_name == GameManager.current_bait:
			var eq = Label.new()
			eq.text = "[EQUIPPED]"
			eq.modulate = Color(0.2, 0.9, 0.4)
			hbox.add_child(eq)
		else:
			var eq_btn = Button.new()
			eq_btn.text = "Select"
			eq_btn.disabled = (b_name != "None" and count <= 0)
			eq_btn.pressed.connect(func():
				AudioManager.play_click()
				GameManager.current_bait = b_name
				GameManager.save_game()
				refresh_tackle()
				refresh_fishing_view()
			)
			hbox.add_child(eq_btn)

		baits_container.add_child(hbox)

func refresh_shipyard() -> void:
	for child in boats_container.get_children():
		child.queue_free()

	for b_name in GameManager.boats_database.keys():
		var b_data = GameManager.boats_database[b_name]
		var hbox = HBoxContainer.new()
		
		var lbl = Label.new()
		lbl.text = "🚢 %s | Speed: %d | CD Bonus: -%.2fs | Fish Bonus: +%d" % [
			b_name, b_data["speed"], b_data["cd_bonus"], b_data["fish_bonus"]
		]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		if b_name == GameManager.current_boat:
			var eq = Label.new()
			eq.text = "[ACTIVE HULL]"
			eq.modulate = Color(0.2, 0.9, 0.4)
			hbox.add_child(eq)
		elif b_name in GameManager.owned_boats:
			var eq_btn = Button.new()
			eq_btn.text = "Deploy"
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

		boats_container.add_child(hbox)

func refresh_fishing_view() -> void:
	rod_info_label.text = "Equipped Rod: " + GameManager.current_rod
	var bait_count = GameManager.bait_stock.get(GameManager.current_bait, 0)
	bait_info_label.text = "Equipped Bait: %s (%d left)" % [GameManager.current_bait, bait_count]
	cd_info_label.text = "Base Cooldown: %.1fs" % GameManager.get_fishing_cooldown()

# --- Tab Switching ---
func _on_market_btn_pressed() -> void:
	AudioManager.play_click()
	market_panel.visible = true
	tackle_panel.visible = false
	shipyard_panel.visible = false
	fishing_panel.visible = false

func _on_tackle_btn_pressed() -> void:
	AudioManager.play_click()
	market_panel.visible = false
	tackle_panel.visible = true
	shipyard_panel.visible = false
	fishing_panel.visible = false

func _on_shipyard_btn_pressed() -> void:
	AudioManager.play_click()
	market_panel.visible = false
	tackle_panel.visible = false
	shipyard_panel.visible = true
	fishing_panel.visible = false

func _on_fishing_btn_pressed() -> void:
	AudioManager.play_click()
	market_panel.visible = false
	tackle_panel.visible = false
	shipyard_panel.visible = false
	pets_panel.visible = false
	fishing_panel.visible = true
	refresh_fishing_view()

func _on_pets_btn_pressed() -> void:
	AudioManager.play_click()
	market_panel.visible = false
	tackle_panel.visible = false
	shipyard_panel.visible = false
	fishing_panel.visible = false
	pets_panel.visible = true
	refresh_pets_and_mascots()

func refresh_pets_and_mascots() -> void:
	if not mascots_container or not pets_container:
		return

	# 1. Clear containers
	for child in mascots_container.get_children():
		child.queue_free()
	for child in pets_container.get_children():
		child.queue_free()

	# 2. Render Mascots
	for m_key in GameManager.mascots.keys():
		var m_data = GameManager.mascots[m_key]
		var hbox = HBoxContainer.new()
		
		var icon_lbl = Label.new()
		icon_lbl.text = m_data["icon"]
		hbox.add_child(icon_lbl)
		
		var name_lbl = Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.text = "%s - %s" % [m_data["name"], m_data["desc"]]
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
		mascots_container.add_child(hbox)

	# 3. Render Pets
	for p_name in GameManager.pets_database.keys():
		var p_data = GameManager.pets_database[p_name]
		var hbox = HBoxContainer.new()
		
		var icon_lbl = Label.new()
		icon_lbl.text = p_data["icon"]
		hbox.add_child(icon_lbl)
		
		var info_lbl = Label.new()
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_lbl.text = "%s (Lv. %d Milestone) - %s" % [p_name, p_data["req_level"], p_data["desc"]]
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
		pets_container.add_child(hbox)

# --- Fishing Reel Action ---
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

	# Start cooldown
	is_cooling_down = true
	cooldown_timer = GameManager.get_fishing_cooldown()
	refresh_header()
	refresh_fishing_view()

func _on_sell_all_btn_pressed() -> void:
	AudioManager.play_click()
	var total = GameManager.sell_all_fish()
	if total > 0:
		catch_banner.text = "💰 Sold your catch for $%d!" % total
		catch_banner.modulate = Color(0.2, 0.9, 0.4)
	refresh_market()
	refresh_header()

func _on_close_btn_pressed() -> void:
	AudioManager.play_click()
	close_dock()

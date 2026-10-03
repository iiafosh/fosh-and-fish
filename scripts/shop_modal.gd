extends Control

signal close_requested

@onready var panel: PanelContainer = $Panel
@onready var dim_overlay: ColorRect = $DimOverlay

# Sub-views
@onready var view_hub: Control = $Panel/Margin/VBox/ViewHub
@onready var view_rods: Control = $Panel/Margin/VBox/ViewRods
@onready var view_boats: Control = $Panel/Margin/VBox/ViewBoats
@onready var view_bait: Control = $Panel/Margin/VBox/ViewBait
@onready var view_upgrades: Control = $Panel/Margin/VBox/ViewUpgrades
@onready var view_boosts: Control = $Panel/Margin/VBox/ViewBoosts
@onready var view_special: Control = $Panel/Margin/VBox/ViewSpecial
@onready var view_league: Control = $Panel/Margin/VBox/ViewLeague

# Headers
@onready var title_label: Label = $Panel/Margin/VBox/Header/TitleLabel
@onready var balance_label: Label = $Panel/Margin/VBox/Header/BalanceLabel
@onready var close_btn: Button = $Panel/Margin/VBox/Header/CloseXBtn

# Hub 2x4 Matrix Buttons
@onready var btn_hub_rods: Button = $Panel/Margin/VBox/ViewHub/MatrixGrid/RodsBtn
@onready var btn_hub_bait: Button = $Panel/Margin/VBox/ViewHub/MatrixGrid/BaitBtn
@onready var btn_hub_upgrades: Button = $Panel/Margin/VBox/ViewHub/MatrixGrid/UpgradesBtn
@onready var btn_hub_boats: Button = $Panel/Margin/VBox/ViewHub/MatrixGrid/BoatsBtn
@onready var btn_hub_boosts: Button = $Panel/Margin/VBox/ViewHub/MatrixGrid/BoostsBtn
@onready var btn_hub_special: Button = $Panel/Margin/VBox/ViewHub/MatrixGrid/SpecialBtn
@onready var btn_hub_league: Button = $Panel/Margin/VBox/ViewHub/MatrixGrid/LeagueBtn
@onready var btn_hub_return: Button = $Panel/Margin/VBox/ViewHub/MatrixGrid/ReturnBtn

# Lists & Dynamic Containers
@onready var rods_list_container: VBoxContainer = $Panel/Margin/VBox/ViewRods/Scroll/RodsList
@onready var rods_page_label: Label = $Panel/Margin/VBox/ViewRods/NavRow/PageLabel
@onready var rods_prev_btn: Button = $Panel/Margin/VBox/ViewRods/NavRow/PrevBtn
@onready var rods_next_btn: Button = $Panel/Margin/VBox/ViewRods/NavRow/NextBtn
@onready var rods_back_btn: Button = $Panel/Margin/VBox/ViewRods/NavRow/BackBtn

@onready var boats_list_container: VBoxContainer = $Panel/Margin/VBox/ViewBoats/Scroll/BoatsList
@onready var boats_back_btn: Button = $Panel/Margin/VBox/ViewBoats/BackBtn

@onready var bait_list_container: VBoxContainer = $Panel/Margin/VBox/ViewBait/Scroll/BaitList
@onready var bait_back_btn: Button = $Panel/Margin/VBox/ViewBait/BackBtn

@onready var upgrades_list_container: VBoxContainer = $Panel/Margin/VBox/ViewUpgrades/Scroll/UpgradesList
@onready var upgrades_back_btn: Button = $Panel/Margin/VBox/ViewUpgrades/BackBtn

@onready var boosts_list_container: VBoxContainer = $Panel/Margin/VBox/ViewBoosts/VBox
@onready var boosts_back_btn: Button = $Panel/Margin/VBox/ViewBoosts/BackBtn

@onready var special_list_container: VBoxContainer = $Panel/Margin/VBox/ViewSpecial/Scroll/SpecialList
@onready var special_back_btn: Button = $Panel/Margin/VBox/ViewSpecial/BackBtn

@onready var league_list_container: VBoxContainer = $Panel/Margin/VBox/ViewLeague/Scroll/LeagueList
@onready var league_back_btn: Button = $Panel/Margin/VBox/ViewLeague/BackBtn

var current_view: String = "hub"
var rod_page: int = 1
const RODS_PER_PAGE: int = 7
var active_tween: Tween = null

func _ready() -> void:
	visible = false
	GameManager.stats_changed.connect(refresh_current_view)

	close_btn.pressed.connect(close_modal)

	# Hub button connections
	btn_hub_rods.pressed.connect(func(): switch_view("rods"))
	btn_hub_bait.pressed.connect(func(): switch_view("bait"))
	btn_hub_upgrades.pressed.connect(func(): switch_view("upgrades"))
	btn_hub_boats.pressed.connect(func(): switch_view("boats"))
	btn_hub_boosts.pressed.connect(func(): switch_view("boosts"))
	btn_hub_special.pressed.connect(func(): switch_view("special"))
	btn_hub_league.pressed.connect(func(): switch_view("league"))
	btn_hub_return.pressed.connect(close_modal)

	# Sub-shop back buttons
	rods_back_btn.pressed.connect(func(): switch_view("hub"))
	boats_back_btn.pressed.connect(func(): switch_view("hub"))
	bait_back_btn.pressed.connect(func(): switch_view("hub"))
	upgrades_back_btn.pressed.connect(func(): switch_view("hub"))
	boosts_back_btn.pressed.connect(func(): switch_view("hub"))
	special_back_btn.pressed.connect(func(): switch_view("hub"))
	league_back_btn.pressed.connect(func(): switch_view("hub"))

	# Rods pagination
	rods_prev_btn.pressed.connect(func():
		if rod_page > 1:
			rod_page -= 1
			AudioManager.play_click()
			_populate_rods()
	)
	rods_next_btn.pressed.connect(func():
		var total_pages = int(ceil(float(GameManager.rods_database.size()) / RODS_PER_PAGE))
		if rod_page < total_pages:
			rod_page += 1
			AudioManager.play_click()
			_populate_rods()
	)

func open_modal(target_view: String = "hub") -> void:
	switch_view(target_view)
	visible = true

	if active_tween and active_tween.is_valid():
		active_tween.kill()

	panel.position.y = 740.0
	dim_overlay.modulate.a = 0.0

	active_tween = create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(panel, "position:y", 25.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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

func switch_view(new_view: String) -> void:
	AudioManager.play_click()
	current_view = new_view

	view_hub.visible = (new_view == "hub")
	view_rods.visible = (new_view == "rods")
	view_boats.visible = (new_view == "boats")
	view_bait.visible = (new_view == "bait")
	view_upgrades.visible = (new_view == "upgrades")
	view_boosts.visible = (new_view == "boosts")
	view_special.visible = (new_view == "special")
	view_league.visible = (new_view == "league")

	refresh_current_view()

func refresh_current_view() -> void:
	# Update Header
	balance_label.text = "Balance: $%s" % _format_number(GameManager.cash)
	match current_view:
		"hub":
			title_label.text = "Shop Hub"
		"rods":
			title_label.text = "/shop rods"
			_populate_rods()
		"boats":
			title_label.text = "/shop boats"
			_populate_boats()
		"bait":
			title_label.text = "/shop bait"
			_populate_bait()
		"upgrades":
			title_label.text = "/shop upgrades"
			_populate_upgrades()
		"boosts":
			title_label.text = "/shop boosts"
			_populate_boosts()
		"special":
			title_label.text = "/shop special"
			_populate_special()
		"league":
			title_label.text = "/shop league"
			_populate_league()

# --- 1. Rods View (Screenshot 3 Match) ---
func _populate_rods() -> void:
	for c in rods_list_container.get_children():
		c.queue_free()

	var rod_names = GameManager.rods_database.keys()
	var total_pages = int(ceil(float(rod_names.size()) / RODS_PER_PAGE))
	rod_page = clamp(rod_page, 1, total_pages)
	rods_page_label.text = "Page %d/%d" % [rod_page, total_pages]
	rods_prev_btn.disabled = (rod_page <= 1)
	rods_next_btn.disabled = (rod_page >= total_pages)

	var start_idx = (rod_page - 1) * RODS_PER_PAGE
	var end_idx = min(start_idx + RODS_PER_PAGE, rod_names.size())

	for i in range(start_idx, end_idx):
		var r_name = rod_names[i]
		var r_data = GameManager.rods_database[r_name]
		var is_owned = (r_name in GameManager.owned_rods)
		var is_equipped = (r_name == GameManager.current_rod)

		var card = _create_shop_card(r_name, r_data["desc"])
		var stats_lbl = Label.new()
		stats_lbl.text = "🎣 %d-%d fish | 💎 %d%% treasure | 🌊 %s" % [
			r_data["min_fish"], r_data["max_fish"],
			int(r_data.get("treasure_chance", 0.05) * 100),
			", ".join(r_data.get("biomes", ["River"]))
		]
		stats_lbl.add_theme_font_size_override("font_size", 11)
		stats_lbl.modulate = Color(0.65, 0.75, 0.9)
		card.get_node("Info").add_child(stats_lbl)

		var action_btn = Button.new()
		action_btn.custom_minimum_size = Vector2(120, 36)
		action_btn.add_theme_font_size_override("font_size", 12)

		if is_equipped:
			action_btn.text = "EQUIPPED"
			action_btn.disabled = true
			_style_button_green(action_btn)
		elif is_owned:
			action_btn.text = "🎣 Select"
			_style_button_green(action_btn)
			action_btn.pressed.connect(func():
				AudioManager.play_strike()
				GameManager.select_rod(r_name)
			)
		else:
			action_btn.text = "$%s" % _format_number(r_data["cost"])
			action_btn.disabled = (GameManager.cash < r_data["cost"])
			_style_button_blue(action_btn)
			action_btn.pressed.connect(func():
				AudioManager.play_strike()
				GameManager.buy_rod(r_name)
			)

		card.add_child(action_btn)
		rods_list_container.add_child(card)

# --- 2. Boats View (Screenshot 4 Match) ---
func _populate_boats() -> void:
	for c in boats_list_container.get_children():
		c.queue_free()

	for b_name in GameManager.boats_database.keys():
		var b_data = GameManager.boats_database[b_name]
		var is_owned = (b_name in GameManager.owned_boats)
		var is_active = (b_name == GameManager.current_boat)
		var req_lvl = b_data.get("req_level", 0)
		var lvl_met = (GameManager.level >= req_lvl)

		var sub_desc = "%s (-0.25s CD, +1 fish per cast permanent)" % b_data.get("desc", "")
		var card = _create_shop_card("Tier %d: %s" % [b_data["tier"], b_name], sub_desc)

		var action_btn = Button.new()
		action_btn.custom_minimum_size = Vector2(130, 36)
		action_btn.add_theme_font_size_override("font_size", 11)

		if is_active:
			action_btn.text = "FLAGSHIP"
			action_btn.disabled = true
			_style_button_green(action_btn)
		elif is_owned:
			action_btn.text = "⚓ Deploy Hull"
			_style_button_green(action_btn)
			action_btn.pressed.connect(func():
				AudioManager.play_strike()
				GameManager.select_boat(b_name)
			)
		elif not lvl_met:
			action_btn.text = "🔒 Unlock Lv. %d" % req_lvl
			action_btn.disabled = true
		else:
			action_btn.text = "$%s" % _format_number(b_data["cost"])
			action_btn.disabled = (GameManager.cash < b_data["cost"])
			_style_button_purple(action_btn)
			action_btn.pressed.connect(func():
				AudioManager.play_strike()
				GameManager.buy_boat(b_name)
			)

		card.add_child(action_btn)
		boats_list_container.add_child(card)

# --- 3. Bait View ---
func _populate_bait() -> void:
	for c in bait_list_container.get_children():
		c.queue_free()

	for b_name in GameManager.baits_database.keys():
		if b_name == "None":
			continue
		var b_data = GameManager.baits_database[b_name]
		var stock = GameManager.bait_stock.get(b_name, 0)
		var is_equipped = (b_name == GameManager.current_bait)

		var title = "%s (In Stock: %s)" % [b_name, _format_number(stock)]
		var card = _create_shop_card(title, b_data.get("desc", ""))

		var btn_box = HBoxContainer.new()
		btn_box.theme_override_constants.separation = 6

		# Equip button
		var equip_btn = Button.new()
		equip_btn.custom_minimum_size = Vector2(75, 34)
		equip_btn.add_theme_font_size_override("font_size", 11)
		if is_equipped:
			equip_btn.text = "EQUIPPED"
			equip_btn.disabled = true
			_style_button_green(equip_btn)
		else:
			equip_btn.text = "Equip"
			equip_btn.disabled = (stock <= 0)
			_style_button_blue(equip_btn)
			equip_btn.pressed.connect(func():
				AudioManager.play_click()
				GameManager.select_bait(b_name)
			)
		btn_box.add_child(equip_btn)

		# Buy 10 button
		var cost10 = b_data["cost"] * 10
		var buy10_btn = Button.new()
		buy10_btn.custom_minimum_size = Vector2(85, 34)
		buy10_btn.add_theme_font_size_override("font_size", 11)
		buy10_btn.text = "+10 ($%s)" % _format_number(cost10)
		buy10_btn.disabled = (GameManager.cash < cost10)
		buy10_btn.pressed.connect(func():
			AudioManager.play_strike()
			GameManager.buy_bait(b_name, 10)
		)
		btn_box.add_child(buy10_btn)

		# Buy 100 button
		var cost100 = b_data["cost"] * 100
		var buy100_btn = Button.new()
		buy100_btn.custom_minimum_size = Vector2(95, 34)
		buy100_btn.add_theme_font_size_override("font_size", 11)
		buy100_btn.text = "+100 ($%s)" % _format_number(cost100)
		buy100_btn.disabled = (GameManager.cash < cost100)
		buy100_btn.pressed.connect(func():
			AudioManager.play_strike()
			GameManager.buy_bait(b_name, 100)
		)
		btn_box.add_child(buy100_btn)

		card.add_child(btn_box)
		bait_list_container.add_child(card)

# --- 4. Upgrades View ---
func _populate_upgrades() -> void:
	for c in upgrades_list_container.get_children():
		c.queue_free()

	var upgrade_defs = [
		{"id": "better_fish", "name": "Better Fish (Master Angler)", "desc": "+5% Fish Quality per level"},
		{"id": "salesman", "name": "Salesman (Master Merchant)", "desc": "+5% Fish Sell Price per level"},
		{"id": "more_chests", "name": "More Chests (Treasure Hunter)", "desc": "+5% Treasure Chest Chance per level"},
		{"id": "experienced", "name": "Experienced (Seasoned Sailor)", "desc": "+10% Fishing XP Gain per level"},
		{"id": "worker_motivation", "name": "Worker Motivation", "desc": "+10% Fish Catch from Workers per level"},
		{"id": "better_chests", "name": "Better Chests", "desc": "+10% Treasure Quality per level"}
	]

	for u in upgrade_defs:
		var u_id = u["id"]
		var current_lvl = GameManager.upgrades.get(u_id, 0)
		var max_lvl = GameManager.get_upgrade_max(u_id)
		var is_max = (current_lvl >= max_lvl)
		var cost = GameManager.get_upgrade_cost(u_id)

		var title = "%s (Lv %d/%d)" % [u["name"], current_lvl, max_lvl]
		var card = _create_shop_card(title, u["desc"])

		var action_btn = Button.new()
		action_btn.custom_minimum_size = Vector2(140, 36)
		action_btn.add_theme_font_size_override("font_size", 11)

		if is_max:
			action_btn.text = "MAX LEVEL"
			action_btn.disabled = true
			_style_button_green(action_btn)
		else:
			action_btn.text = "Upgrade ($%s)" % _format_number(cost)
			action_btn.disabled = (GameManager.cash < cost)
			_style_button_blue(action_btn)
			action_btn.pressed.connect(func():
				AudioManager.play_strike()
				GameManager.buy_perk_upgrade(u_id)
			)

		card.add_child(action_btn)
		upgrades_list_container.add_child(card)

# --- 5. Boosts View (Workers) ---
func _populate_boosts() -> void:
	for c in boosts_list_container.get_children():
		c.queue_free()

	# Status Card
	var status_card = PanelContainer.new()
	var s_box = VBoxContainer.new()
	var s_title = Label.new()
	s_title.text = "⚓ Automated Net Worker System"
	s_title.add_theme_font_size_override("font_size", 14)
	s_title.modulate = Color(1.0, 0.9, 0.4)
	s_box.add_child(s_title)

	var boost_time = GameManager.worker_boost_remaining
	var time_str = "%dm %02ds remaining" % [int(boost_time / 60.0), int(boost_time) % 60] if boost_time > 0.0 else "Inactive"
	var s_detail = Label.new()
	s_detail.text = "Net Level: %d | Worker Speed: ~12s per trip\nActive Boost Timer: %s" % [GameManager.worker_level, time_str]
	s_detail.add_theme_font_size_override("font_size", 12)
	s_detail.modulate = Color(0.85, 0.92, 1.0)
	s_box.add_child(s_detail)
	status_card.add_child(s_box)
	boosts_list_container.add_child(status_card)

	# Auto10m Card
	var auto10 = _create_shop_card("Auto10m Net Boost", "Workers automatically gather fish into your cargo for 10 minutes.\nCost: 8 🪙 Gold Fish (You have: %s)" % _format_number(GameManager.gold_fish))
	var btn10 = Button.new()
	btn10.custom_minimum_size = Vector2(140, 38)
	btn10.text = "Deploy 10m (8 🪙)"
	btn10.disabled = (GameManager.gold_fish < 8)
	_style_button_blue(btn10)
	btn10.pressed.connect(func():
		AudioManager.play_strike()
		GameManager.buy_worker_boost("Auto10m")
	)
	auto10.add_child(btn10)
	boosts_list_container.add_child(auto10)

	# Auto30m Card
	var auto30 = _create_shop_card("Auto30m Deep Net Boost", "Deep oceanic trawling automatically pulls rare fish for 30 minutes.\nCost: 8 🟢 Emerald Fish (You have: %s)" % _format_number(GameManager.emerald_fish))
	var btn30 = Button.new()
	btn30.custom_minimum_size = Vector2(140, 38)
	btn30.text = "Deploy 30m (8 🟢)"
	btn30.disabled = (GameManager.emerald_fish < 8)
	_style_button_blue(btn30)
	btn30.pressed.connect(func():
		AudioManager.play_strike()
		GameManager.buy_worker_boost("Auto30m")
	)
	auto30.add_child(btn30)
	boosts_list_container.add_child(auto30)

# --- 6. Special View (Exotic Fish) ---
func _populate_special() -> void:
	for c in special_list_container.get_children():
		c.queue_free()

	var specials = [
		{"id": "fish_ovens", "name": "Fish Ovens", "desc": "+5% Fish Sell Price permanently.", "max": 20},
		{"id": "statistician", "name": "Statistician", "desc": "+2% across All Multipliers.", "max": 10},
		{"id": "duplicator", "name": "Duplicator", "desc": "+2% chance to duplicate fish catches.", "max": 10},
		{"id": "boost_booster", "name": "Boost Booster", "desc": "+50% Treasure Quality, +40% Fish Quality, +10% Worker Speed.", "max": 4}
	]

	for s in specials:
		var s_id = s["id"]
		var rank = GameManager.special_upgrades.get(s_id, 0)
		var max_rank = s["max"]
		var cost = GameManager.get_special_upgrade_cost(s_id)
		var curr_name = GameManager.get_special_upgrade_currency(s_id)
		var curr_icon = "🪙"
		var have_amt = GameManager.gold_fish
		match curr_name:
			"lava":
				curr_icon = "🌶️"
				have_amt = GameManager.lava_fish
			"emerald":
				curr_icon = "🟢"
				have_amt = GameManager.emerald_fish
			"diamond":
				curr_icon = "💎"
				have_amt = GameManager.diamond_fish

		var title = "%s (Rank %d/%d)" % [s["name"], rank, max_rank]
		var card = _create_shop_card(title, "%s\nCost: %d %s %s (You have: %s)" % [s["desc"], cost, curr_icon, curr_name.capitalize(), _format_number(have_amt)])

		var action_btn = Button.new()
		action_btn.custom_minimum_size = Vector2(130, 36)
		action_btn.add_theme_font_size_override("font_size", 11)

		if rank >= max_rank:
			action_btn.text = "MAX RANK"
			action_btn.disabled = true
			_style_button_green(action_btn)
		else:
			action_btn.text = "Upgrade (%d %s)" % [cost, curr_icon]
			action_btn.disabled = (have_amt < cost)
			_style_button_purple(action_btn)
			action_btn.pressed.connect(func():
				AudioManager.play_strike()
				GameManager.buy_special_upgrade(s_id)
			)

		card.add_child(action_btn)
		special_list_container.add_child(card)

# --- 7. League View (Hooks) ---
func _populate_league() -> void:
	for c in league_list_container.get_children():
		c.queue_free()

	var leagues = [
		{"id": "pet_helper", "name": "Pet Helper", "desc": "Increases max Pet Level by 5 & boosts pet XP."},
		{"id": "bait_helper", "name": "Bait Helper", "desc": "Increases effectiveness of all Baits by 5%."},
		{"id": "super_crates", "name": "Super Crates", "desc": "Unlocks high-tier Super Crates from fishing."},
		{"id": "worker_crates", "name": "Worker Crates", "desc": "Allows Workers to pull sunken treasure crates."},
		{"id": "fishing_frenzy", "name": "Fishing Frenzy", "desc": "Increases Worker fishing trip speed by 10%."}
	]

	for l in leagues:
		var l_id = l["id"]
		var rank = GameManager.league_upgrades.get(l_id, 0)
		var cost = GameManager.get_league_upgrade_cost(l_id)
		var title = "%s (Level %d/5)" % [l["name"], rank]

		var card = _create_shop_card(title, "%s\nCost: %d 🪝 Hooks (You have: %d)" % [l["desc"], cost, GameManager.hooks])

		var action_btn = Button.new()
		action_btn.custom_minimum_size = Vector2(130, 36)
		action_btn.add_theme_font_size_override("font_size", 11)

		if rank >= 5:
			action_btn.text = "MAX LEVEL"
			action_btn.disabled = true
			_style_button_green(action_btn)
		else:
			action_btn.text = "Buy (%d 🪝)" % cost
			action_btn.disabled = (GameManager.hooks < cost)
			_style_button_blue(action_btn)
			action_btn.pressed.connect(func():
				AudioManager.play_strike()
				GameManager.buy_league_upgrade(l_id)
			)

		card.add_child(action_btn)
		league_list_container.add_child(card)

# --- Helper Methods ---
func _create_shop_card(title: String, desc: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.theme_override_constants.separation = 12

	var vbox = VBoxContainer.new()
	vbox.name = "Info"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.theme_override_constants.separation = 2

	var t_lbl = Label.new()
	t_lbl.text = title
	t_lbl.add_theme_font_size_override("font_size", 13)
	t_lbl.modulate = Color(1.0, 0.95, 0.7)
	vbox.add_child(t_lbl)

	var d_lbl = Label.new()
	d_lbl.text = desc
	d_lbl.add_theme_font_size_override("font_size", 11)
	d_lbl.modulate = Color(0.75, 0.82, 0.92)
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(d_lbl)

	hbox.add_child(vbox)
	return hbox

func _style_button_green(btn: Button) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.65, 0.28, 0.95)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.2, 0.9, 0.4, 1.0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("normal", sb)

func _style_button_blue(btn: Button) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.35, 0.85, 0.95)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.4, 0.55, 1.0, 1.0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("normal", sb)

func _style_button_purple(btn: Button) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.48, 0.22, 0.78, 0.95)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.7, 0.45, 1.0, 1.0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("normal", sb)

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

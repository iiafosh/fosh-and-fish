extends Node

# --- Signals ---
signal stats_changed
signal inventory_changed
signal fish_caught(fish_name: String, count: int, xp_gained: int, rarity: String, quality_data: Dictionary)
@warning_ignore("unused_signal")
signal dock_available(dock_data: Dictionary)
@warning_ignore("unused_signal")
signal dock_cleared
@warning_ignore("unused_signal")
signal open_station_requested(dock_data: Dictionary)
@warning_ignore("unused_signal")
signal close_station_requested
signal boss_hooked(boss_data: Dictionary)
signal weather_changed(new_weather: String)
signal worker_netted(fish_name: String, count: int, earned: int)
signal treasure_found(chest_data: Dictionary)

const SAVE_PATH = "user://savegame.json"

# --- Player State ---
var cash: int = 250
var level: int = 1
var xp: int = 0
var xp_needed: int = 30
var current_biome: String = "River"

# Exotic Currencies
var gold_fish: int = 0
var emerald_fish: int = 0
var lava_fish: int = 0
var diamond_fish: int = 0

# Equipment
var current_rod: String = "Plastic Rod"
var owned_rods: Array[String] = ["Plastic Rod"]
var current_boat: String = "Standard Skiff"
var owned_boats: Array[String] = ["Standard Skiff"]
var current_bait: String = "None"
var bait_stock: Dictionary = {
	"Worms": 15,
	"Leeches": 0,
	"Wise": 0,
	"Fish": 0,
	"Magic": 0
}

# Inventory
var inventory: Dictionary = {}

# Shop Upgrades (level: int)
var upgrades: Dictionary = {
	"better_fish": 0,    # +5% quality per lvl
	"salesman": 0,       # +5% sell price per lvl
	"more_chests": 0,    # +5% treasure chance per lvl
	"experienced": 0     # +10% XP gain per lvl
}

# Auto-Trawler Net (Worker System from Virtual Fisher)
var worker_unlocked: bool = false
var worker_level: int = 1
var worker_timer: float = 18.0

# Dynamic Weather System (Virtual Fisher Core)
var current_weather: String = "Clear"
var weather_timer: float = 200.0
const WEATHERS = ["Clear", "Rain", "Storm", "Fog"]

# Pets & Companions
var equipped_pet: String = "None"
var owned_pets: Array[String] = []
var pets_database: Dictionary = {
	"Axo-9": {"req_level": 5, "icon": "🦎", "desc": "Cyber Axolotl. +15% XP Gain on all catches.", "xp_boost": 0.15, "double_catch": 0.0},
	"Otto-Flux": {"req_level": 15, "icon": "🦦", "desc": "Quantum Otter. 25% Chance to double fish catch.", "xp_boost": 0.0, "double_catch": 0.25},
	"Chrono-Jelly": {"req_level": 25, "icon": "🪼", "desc": "Tachyon Jelly. Slows down boss tension by 40%.", "xp_boost": 0.10, "double_catch": 0.10},
	"Aethelgard": {"req_level": 40, "icon": "🐉", "desc": "Sovereign Dragon. Instant boss taming & 50% double catch.", "xp_boost": 0.30, "double_catch": 0.50}
}

# Fish Quality Tiers (Virtual Fisher Exact Scaling)
const QUALITY_TIERS = {
	"Standard": {"tier": "Standard", "mult": 1.0, "xp_mult": 1.0, "tag": "", "color": Color("#ffffff")},
	"Bronze":   {"tier": "Bronze", "mult": 1.25, "xp_mult": 1.2, "tag": "🥉 BRONZE", "color": Color("#cd7f32")},
	"Silver":   {"tier": "Silver", "mult": 1.5, "xp_mult": 1.4, "tag": "🥈 SILVER", "color": Color("#cbd5e1")},
	"Gold":     {"tier": "Gold", "mult": 2.0, "xp_mult": 1.8, "tag": "🥇 GOLD", "color": Color("#facc15")},
	"Platinum": {"tier": "Platinum", "mult": 3.0, "xp_mult": 2.5, "tag": "💎 PLATINUM", "color": Color("#67e8f9")},
	"Diamond":  {"tier": "Diamond", "mult": 5.0, "xp_mult": 4.0, "tag": "👑 DIAMOND", "color": Color("#ec4899")}
}

# --- Databases ---
var fish_database: Dictionary = {
	# River Biome
	"Raw Fish": {"price": 2, "xp": 2, "rarity": "Common", "biomes": ["River"], "color": Color(0.7, 0.8, 0.9), "is_boss": false},
	"Raw Salmon": {"price": 6, "xp": 4, "rarity": "Common", "biomes": ["River", "Volcanic"], "color": Color(1.0, 0.6, 0.5), "is_boss": false},
	"Cod": {"price": 18, "xp": 8, "rarity": "Uncommon", "biomes": ["River", "Volcanic"], "color": Color(0.9, 0.85, 0.4), "is_boss": false},
	"Tropical Fish": {"price": 65, "xp": 18, "rarity": "Rare", "biomes": ["River", "Volcanic", "Ocean"], "color": Color(0.2, 0.9, 0.8), "is_boss": false},
	"Pufferfish": {"price": 180, "xp": 40, "rarity": "Epic", "biomes": ["River", "Volcanic", "Ocean"], "color": Color(0.9, 0.7, 0.2), "is_boss": false},
	
	# Volcanic Biome
	"Fiery Pufferfish": {"price": 320, "xp": 75, "rarity": "Rare", "biomes": ["Volcanic"], "color": Color(1.0, 0.4, 0.2), "is_boss": false},
	"Hot Cod": {"price": 650, "xp": 140, "rarity": "Epic", "biomes": ["Volcanic"], "color": Color(1.0, 0.2, 0.2), "is_boss": false},
	"Magma Ray": {"price": 1800, "xp": 320, "rarity": "Legendary", "biomes": ["Volcanic"], "color": Color(1.0, 0.3, 0.0), "is_boss": false},
	
	# Ocean Biome
	"Squid": {"price": 1400, "xp": 220, "rarity": "Rare", "biomes": ["Ocean"], "color": Color(0.7, 0.4, 0.9), "is_boss": false},
	"Turtle": {"price": 4500, "xp": 500, "rarity": "Epic", "biomes": ["Ocean"], "color": Color(0.3, 0.8, 0.4), "is_boss": false},
	"Dolphin": {"price": 22000, "xp": 950, "rarity": "Legendary", "biomes": ["Ocean"], "color": Color(0.2, 0.6, 1.0), "is_boss": false},
	"Abyssal Kraken": {"price": 120000, "xp": 6000, "rarity": "TITAN BOSS", "biomes": ["Ocean"], "color": Color(0.9, 0.1, 0.2), "is_boss": true},

	# Secret Biome: Subspace 0x00 (Glitch Waters)
	"ERR_404_NULL_EEL": {"price": 35000, "xp": 1400, "rarity": "Rare", "biomes": ["Subspace 0x00"], "color": Color(0.0, 1.0, 0.8), "is_boss": false},
	"Quantum Matrix Ray": {"price": 95000, "xp": 3500, "rarity": "Epic", "biomes": ["Subspace 0x00"], "color": Color(0.8, 0.2, 1.0), "is_boss": false},
	"Tachyon Singularity Chimera": {"price": 280000, "xp": 9000, "rarity": "Legendary", "biomes": ["Subspace 0x00"], "color": Color(1.0, 0.9, 0.0), "is_boss": false},
	"Echo of the Glitch Sovereign": {"price": 1200000, "xp": 30000, "rarity": "TITAN BOSS", "biomes": ["Subspace 0x00"], "color": Color(0.0, 1.0, 1.0), "is_boss": true}
}

var rods_database: Dictionary = {
	"Plastic Rod": {"cost": 0, "min_fish": 4, "max_fish": 10, "cd_penalty": 0.0, "treasure_chance": 0.05, "biomes": ["River"], "desc": "Basic starter rod."},
	"Improved Rod": {"cost": 500, "min_fish": 5, "max_fish": 10, "cd_penalty": 0.0, "treasure_chance": 0.05, "biomes": ["River"], "desc": "Attracts slightly better fish."},
	"Steel Rod": {"cost": 8000, "min_fish": 5, "max_fish": 8, "cd_penalty": 0.0, "treasure_chance": 0.06, "biomes": ["River"], "desc": "Catches higher quality fish."},
	"Fiberglass Rod": {"cost": 50000, "min_fish": 7, "max_fish": 10, "cd_penalty": 0.0, "treasure_chance": 0.07, "biomes": ["River", "Ocean"], "desc": "Catches large amounts of quality fish."},
	"Lava Rod": {"cost": 1000000, "min_fish": 7, "max_fish": 11, "cd_penalty": 0.0, "treasure_chance": 0.08, "biomes": ["River", "Volcanic", "Ocean"], "desc": "Forged to resist boiling magma."},
	"Celestial Prism Rod": {"cost": 5000000, "min_fish": 10, "max_fish": 18, "cd_penalty": -0.5, "treasure_chance": 0.12, "biomes": ["River", "Volcanic", "Ocean", "Subspace 0x00"], "desc": "Refracts stellar light into pure fishing fortune."},
	"0xDEADBEEF Dev Glitch Rod": {"cost": 0, "min_fish": 20, "max_fish": 40, "cd_penalty": -1.2, "treasure_chance": 0.25, "biomes": ["River", "Volcanic", "Ocean", "Subspace 0x00"], "desc": "Secret Easter Egg relic pulsing with binary code."}
}

var boats_database: Dictionary = {
	"Standard Skiff": {
		"tier": 1, "cost": 0, "speed": 180.0, "cd_bonus": 0.0, "fish_bonus": 0,
		"deck_min_x": -140.0, "deck_max_x": 140.0,
		"desc": "Rustic handcrafted oak timber skiff with lantern."
	},
	"Rowboat": {
		"tier": 2, "cost": 5000, "speed": 220.0, "cd_bonus": 0.25, "fish_bonus": 1,
		"deck_min_x": -170.0, "deck_max_x": 170.0,
		"desc": "Varnished dory with brass rowlocks and resting oars."
	},
	"Fishing Boat": {
		"tier": 3, "cost": 25000, "speed": 260.0, "cd_bonus": 0.50, "fish_bonus": 2,
		"deck_min_x": -210.0, "deck_max_x": 220.0,
		"desc": "Coastal motor trawler with wheelhouse & diesel exhaust."
	},
	"Speedboat": {
		"tier": 4, "cost": 100000, "speed": 340.0, "cd_bonus": 0.75, "fish_bonus": 3,
		"deck_min_x": -230.0, "deck_max_x": 230.0,
		"desc": "Midnight-blue aerodynamic racer with wraparound glass."
	},
	"Hovercraft Vanguard": {
		"tier": 5, "cost": 750000, "speed": 420.0, "cd_bonus": 1.0, "fish_bonus": 5,
		"deck_min_x": -250.0, "deck_max_x": 250.0,
		"desc": "Amphibious air-cushion platform with twin turbofans."
	},
	"Luxury Yacht": {
		"tier": 6, "cost": 20000000, "speed": 480.0, "cd_bonus": 1.25, "fish_bonus": 7,
		"deck_min_x": -280.0, "deck_max_x": 280.0,
		"desc": "Tri-deck sovereign cruiser with teak deck & salon."
	},
	"Abyssal Submersible": {
		"tier": 7, "cost": 100000000, "speed": 520.0, "cd_bonus": 1.5, "fish_bonus": 10,
		"deck_min_x": -260.0, "deck_max_x": 260.0,
		"desc": "Titanium bathyscaphe with quartz viewport and searchlights."
	}
}

var baits_database: Dictionary = {
	"None": {"cost": 0, "bonus_fish": 0, "quality_mult": 1.0, "xp_mult": 1.0, "desc": "Standard unbaited hook."},
	"Worms": {"cost": 4, "bonus_fish": 3, "quality_mult": 1.0, "xp_mult": 0.9, "desc": "+3 Fish per cast, -10% XP."},
	"Leeches": {"cost": 25, "bonus_fish": 3, "quality_mult": 1.2, "xp_mult": 0.8, "desc": "+20% Quality, +3 Fish, -20% XP."},
	"Wise": {"cost": 35, "bonus_fish": 0, "quality_mult": 1.0, "xp_mult": 2.5, "desc": "+150% XP Gain for rapid leveling."},
	"Fish": {"cost": 70, "bonus_fish": 1, "quality_mult": 2.0, "xp_mult": 0.7, "desc": "+100% Quality, +1 Fish."},
	"Magic": {"cost": 200, "bonus_fish": 4, "quality_mult": 3.0, "xp_mult": 1.5, "desc": "Mystic bait attracting rare exotic species."}
}

func _ready() -> void:
	for f in fish_database.keys():
		inventory[f] = 0
	load_game()

func _process(delta: float) -> void:
	# 1. Weather Cycle Engine
	weather_timer -= delta
	if weather_timer <= 0.0:
		weather_timer = randf_range(180.0, 260.0)
		var next_idx = randi() % WEATHERS.size()
		current_weather = WEATHERS[next_idx]
		weather_changed.emit(current_weather)

	# 2. Passive Auto-Trawler Net (Worker System)
	if worker_unlocked:
		worker_timer -= delta
		if worker_timer <= 0.0:
			worker_timer = max(9.0, 18.0 - (worker_level - 1) * 2.0)
			_process_worker_trip()

func _process_worker_trip() -> void:
	# Determine eligible fish in current biome
	var pool: Array[String] = []
	for f_name in fish_database.keys():
		if current_biome in fish_database[f_name]["biomes"] and not fish_database[f_name].get("is_boss", false):
			pool.append(f_name)
	if pool.is_empty():
		pool = ["Raw Fish"]
	var caught_fish = pool[randi() % pool.size()]
	var count = randi_range(1 + worker_level, 2 + worker_level * 2)
	var price_each = int(fish_database[caught_fish]["price"] * get_sell_multiplier())
	var total_earned = count * price_each

	inventory[caught_fish] = inventory.get(caught_fish, 0) + count
	add_xp(count * fish_database[caught_fish]["xp"])
	inventory_changed.emit()
	worker_netted.emit(caught_fish, count, total_earned)
	save_game()

func save_game() -> void:
	var save_data = {
		"cash": cash,
		"level": level,
		"xp": xp,
		"xp_needed": xp_needed,
		"gold_fish": gold_fish,
		"emerald_fish": emerald_fish,
		"lava_fish": lava_fish,
		"diamond_fish": diamond_fish,
		"current_rod": current_rod,
		"owned_rods": owned_rods,
		"current_boat": current_boat,
		"owned_boats": owned_boats,
		"current_bait": current_bait,
		"bait_stock": bait_stock,
		"inventory": inventory,
		"upgrades": upgrades,
		"equipped_pet": equipped_pet,
		"owned_pets": owned_pets,
		"worker_unlocked": worker_unlocked,
		"worker_level": worker_level,
		"current_weather": current_weather
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json_str = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(json_str) != OK:
		return
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return
	cash = data.get("cash", cash)
	level = data.get("level", level)
	xp = data.get("xp", xp)
	xp_needed = data.get("xp_needed", xp_needed)
	gold_fish = data.get("gold_fish", gold_fish)
	emerald_fish = data.get("emerald_fish", emerald_fish)
	lava_fish = data.get("lava_fish", lava_fish)
	diamond_fish = data.get("diamond_fish", diamond_fish)
	current_rod = data.get("current_rod", current_rod)
	if data.has("owned_rods"):
		owned_rods.clear()
		for r in data["owned_rods"]:
			owned_rods.append(str(r))
	current_boat = data.get("current_boat", current_boat)
	if data.has("owned_boats"):
		owned_boats.clear()
		for b in data["owned_boats"]:
			owned_boats.append(str(b))
	current_bait = data.get("current_bait", current_bait)
	if data.has("bait_stock"):
		for k in data["bait_stock"].keys():
			bait_stock[k] = int(data["bait_stock"][k])
	if data.has("inventory"):
		for k in data["inventory"].keys():
			inventory[k] = int(data["inventory"][k])
	if data.has("upgrades"):
		for k in data["upgrades"].keys():
			upgrades[k] = int(data["upgrades"][k])
	equipped_pet = data.get("equipped_pet", equipped_pet)
	if data.has("owned_pets"):
		owned_pets.clear()
		for p in data["owned_pets"]:
			owned_pets.append(str(p))
	worker_unlocked = data.get("worker_unlocked", worker_unlocked)
	worker_level = data.get("worker_level", worker_level)
	current_weather = data.get("current_weather", current_weather)

# --- Getters & Formulas ---
func get_sell_multiplier() -> float:
	return 1.0 + (upgrades["salesman"] * 0.05)

func get_fish_quality_multiplier() -> float:
	var bait_mult = 1.0
	if baits_database.has(current_bait):
		bait_mult = baits_database[current_bait]["quality_mult"]
	var weather_mult = 1.5 if current_weather == "Fog" else 1.0
	return (1.0 + (upgrades["better_fish"] * 0.05)) * bait_mult * weather_mult

func get_xp_multiplier() -> float:
	var bait_mult = 1.0
	if baits_database.has(current_bait):
		bait_mult = baits_database[current_bait]["xp_mult"]
	var weather_xp = 1.25 if current_weather == "Storm" else 1.0
	return (1.0 + (upgrades["experienced"] * 0.10)) * bait_mult * weather_xp

func get_fishing_cooldown() -> float:
	var base_cd = 3.2
	if current_biome == "Volcanic":
		base_cd += 0.5
	elif current_biome == "Ocean":
		base_cd += 0.8
	
	if boats_database.has(current_boat):
		base_cd -= boats_database[current_boat]["cd_bonus"]

	if current_weather == "Rain":
		base_cd *= 0.80
	elif current_weather == "Storm":
		base_cd *= 0.65
	
	return max(1.2, base_cd)

func get_boat_speed() -> float:
	if boats_database.has(current_boat):
		return boats_database[current_boat]["speed"]
	return 180.0

func get_deck_bounds() -> Vector2:
	if boats_database.has(current_boat):
		var b = boats_database[current_boat]
		return Vector2(b["deck_min_x"], b["deck_max_x"])
	return Vector2(-150.0, 150.0)

func get_upgrade_cost(perk_name: String) -> int:
	var rank = upgrades.get(perk_name, 0)
	return int(150 * pow(1.75, rank))

func buy_perk_upgrade(perk_name: String) -> bool:
	var cost = get_upgrade_cost(perk_name)
	if cash >= cost and upgrades.get(perk_name, 0) < 10:
		cash -= cost
		upgrades[perk_name] = upgrades.get(perk_name, 0) + 1
		stats_changed.emit()
		save_game()
		return true
	return false

# --- Economy Methods ---
func add_cash(amount: int) -> void:
	cash += amount
	stats_changed.emit()
	save_game()

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = int(xp_needed * 1.45 + 15)
	stats_changed.emit()
	save_game()

func sell_fish(fish_name: String) -> int:
	if not inventory.has(fish_name) or inventory[fish_name] <= 0:
		return 0
	var count = inventory[fish_name]
	var unit_price = fish_database[fish_name]["price"]
	var total = int(count * unit_price * get_sell_multiplier())
	inventory[fish_name] = 0
	add_cash(total)
	inventory_changed.emit()
	save_game()
	return total

func sell_all_fish() -> int:
	var total_earned = 0
	var mult = get_sell_multiplier()
	for f in inventory.keys():
		var count = inventory[f]
		if count > 0:
			var price = fish_database[f]["price"]
			total_earned += int(count * price * mult)
			inventory[f] = 0
	add_cash(total_earned)
	inventory_changed.emit()
	save_game()
	return total_earned

# --- Virtual Fisher Quality Roll ---
func roll_fish_quality() -> Dictionary:
	var q_mult = get_fish_quality_multiplier()
	var roll = randf() * 100.0 / max(0.5, q_mult)

	if roll < 1.2:
		return QUALITY_TIERS["Diamond"]
	elif roll < 4.5:
		return QUALITY_TIERS["Platinum"]
	elif roll < 13.0:
		return QUALITY_TIERS["Gold"]
	elif roll < 30.0:
		return QUALITY_TIERS["Silver"]
	elif roll < 58.0:
		return QUALITY_TIERS["Bronze"]
	else:
		return QUALITY_TIERS["Standard"]

# --- Sunken Treasure Chest Roll ---
func roll_treasure_chest() -> Dictionary:
	var roll = randf()
	var chest_name = "Wooden Crate"
	var cash_reward = randi_range(150, 450)
	var bait_name = "Worms"
	var bait_amt = randi_range(3, 8)
	var bonus_tokens = ""
	
	if roll < 0.06:
		chest_name = "Cosmic Artifact Crate"
		cash_reward = randi_range(25000, 75000)
		bait_name = "Magic"
		bait_amt = 5
		diamond_fish += 2
		bonus_tokens = "+2 💎 Diamond Fish!"
	elif roll < 0.18:
		chest_name = "Pirate Relic Chest"
		cash_reward = randi_range(5000, 15000)
		bait_name = "Wise"
		bait_amt = 5
		gold_fish += 3
		bonus_tokens = "+3 🪙 Gold Fish!"
	elif roll < 0.40:
		chest_name = "Gilded Strongbox"
		cash_reward = randi_range(1200, 3500)
		bait_name = "Leeches"
		bait_amt = 4
		gold_fish += 1
		bonus_tokens = "+1 🪙 Gold Fish!"
	elif roll < 0.70:
		chest_name = "Iron Locker"
		cash_reward = randi_range(450, 1100)
		bait_name = "Leeches"
		bait_amt = 3
	else:
		chest_name = "Wooden Crate"
		cash_reward = randi_range(150, 450)
		bait_name = "Worms"
		bait_amt = 5

	add_cash(cash_reward)
	bait_stock[bait_name] = bait_stock.get(bait_name, 0) + bait_amt
	stats_changed.emit()
	save_game()
	
	var data = {
		"name": chest_name,
		"cash": cash_reward,
		"bait_name": bait_name,
		"bait_amt": bait_amt,
		"tokens": bonus_tokens
	}
	treasure_found.emit(data)
	return data

# --- Fishing Simulation ---
func roll_catch(location_biome: String = "") -> Dictionary:
	var biome_to_use = location_biome if location_biome != "" else current_biome
	var rod = rods_database.get(current_rod, rods_database["Plastic Rod"])
	var bait = baits_database.get(current_bait, baits_database["None"])
	var boat = boats_database.get(current_boat, boats_database["Standard Skiff"])

	# Deduct 1 bait if equipped
	if current_bait != "None":
		if bait_stock.get(current_bait, 0) > 0:
			bait_stock[current_bait] -= 1
		else:
			current_bait = "None"
			stats_changed.emit()

	# Determine available fish in this biome
	var eligible_fish: Array[String] = []
	for f_name in fish_database.keys():
		var f_data = fish_database[f_name]
		if biome_to_use in f_data["biomes"]:
			eligible_fish.append(f_name)

	if eligible_fish.is_empty():
		eligible_fish = ["Raw Fish"]

	# Quality roll
	var quality_mult = get_fish_quality_multiplier()
	var selected_fish = eligible_fish[0]
	var roll = randf() / max(1.0, quality_mult)

	if biome_to_use == "River":
		if roll < 0.08 and "Pufferfish" in eligible_fish:
			selected_fish = "Pufferfish"
		elif roll < 0.20 and "Tropical Fish" in eligible_fish:
			selected_fish = "Tropical Fish"
		elif roll < 0.45 and "Cod" in eligible_fish:
			selected_fish = "Cod"
		elif roll < 0.70 and "Raw Salmon" in eligible_fish:
			selected_fish = "Raw Salmon"
		else:
			selected_fish = "Raw Fish"
	elif biome_to_use == "Volcanic":
		if roll < 0.15 and "Hot Cod" in eligible_fish:
			selected_fish = "Hot Cod"
		elif roll < 0.35 and "Fiery Pufferfish" in eligible_fish:
			selected_fish = "Fiery Pufferfish"
		elif roll < 0.60 and "Tropical Fish" in eligible_fish:
			selected_fish = "Tropical Fish"
		else:
			selected_fish = "Raw Salmon"
	elif biome_to_use == "Ocean":
		if roll < 0.03 and "Abyssal Kraken" in eligible_fish:
			selected_fish = "Abyssal Kraken"
		elif roll < 0.08 and "Dolphin" in eligible_fish:
			selected_fish = "Dolphin"
		elif roll < 0.25 and "Turtle" in eligible_fish:
			selected_fish = "Turtle"
		elif roll < 0.50 and "Squid" in eligible_fish:
			selected_fish = "Squid"
		else:
			selected_fish = "Pufferfish"
	elif biome_to_use == "Subspace 0x00":
		if roll < 0.04 and "Echo of the Glitch Sovereign" in eligible_fish:
			selected_fish = "Echo of the Glitch Sovereign"
		elif roll < 0.18 and "Tachyon Singularity Chimera" in eligible_fish:
			selected_fish = "Tachyon Singularity Chimera"
		elif roll < 0.45 and "Quantum Matrix Ray" in eligible_fish:
			selected_fish = "Quantum Matrix Ray"
		else:
			selected_fish = "ERR_404_NULL_EEL"

	# Calculate quantity caught (Virtual Fisher formula: CNT += boats)
	var base_count = randi_range(rod["min_fish"], rod["max_fish"])
	base_count += bait["bonus_fish"]
	base_count += boat["fish_bonus"]
	if current_weather == "Rain":
		base_count += 1
		
	# Pet Perks (Double Catch)
	var pet_bonus_msg = ""
	if equipped_pet != "None" and pets_database.has(equipped_pet):
		var p_data = pets_database[equipped_pet]
		if p_data.get("double_catch", 0.0) > 0 and randf() < p_data["double_catch"]:
			base_count *= 2
			pet_bonus_msg = " ⚡ [PET DOUBLE-CATCH!]"

	base_count = max(1, base_count)

	# Roll fish quality tier
	var quality = roll_fish_quality()

	# Rare roll for exotic currencies
	var exotic_msg = ""
	if randf() < 0.08:
		gold_fish += 1
		exotic_msg = " +1 🪙 Gold Fish!"
	if randf() < 0.03:
		emerald_fish += 1
		exotic_msg = " +1 💎 Emerald Fish!"

	# Award XP
	var xp_unit = fish_database[selected_fish]["xp"]
	var xp_mult = get_xp_multiplier() * quality["xp_mult"]
	if equipped_pet != "None" and pets_database.has(equipped_pet):
		xp_mult *= (1.0 + pets_database[equipped_pet].get("xp_boost", 0.0))

	var total_xp = int(base_count * xp_unit * xp_mult)
	var rarity = fish_database[selected_fish]["rarity"]
	var is_boss_fish = fish_database[selected_fish].get("is_boss", false)

	# Sunken Treasure Chest check
	var chest_data = {}
	var base_t_chance = rod.get("treasure_chance", 0.05) * (1.0 + upgrades["more_chests"] * 0.05)
	if current_weather == "Storm":
		base_t_chance += 0.15
	elif current_weather == "Fog":
		base_t_chance += 0.20
	if randf() < base_t_chance:
		chest_data = roll_treasure_chest()

	# Titan Boss Check
	if is_boss_fish:
		if equipped_pet == "Aethelgard":
			inventory[selected_fish] = inventory.get(selected_fish, 0) + base_count
			diamond_fish += 1
			add_xp(total_xp)
			inventory_changed.emit()
			fish_caught.emit(selected_fish, base_count, total_xp, rarity, quality)
			save_game()
			return {
				"name": selected_fish,
				"count": base_count,
				"xp": total_xp,
				"rarity": rarity,
				"quality": quality,
				"color": fish_database[selected_fish]["color"],
				"exotic": exotic_msg + pet_bonus_msg + " [🐉 Aethelgard Tamed Titan!]",
				"chest": chest_data,
				"is_boss": false
			}
		else:
			var boss_data = {
				"name": selected_fish,
				"count": base_count,
				"xp": total_xp,
				"rarity": rarity,
				"quality": quality,
				"color": fish_database[selected_fish]["color"],
				"exotic": exotic_msg + pet_bonus_msg,
				"chest": chest_data,
				"is_boss": true
			}
			boss_hooked.emit(boss_data)
			return boss_data

	# Standard chill instant catch
	inventory[selected_fish] = inventory.get(selected_fish, 0) + base_count
	add_xp(total_xp)
	inventory_changed.emit()
	fish_caught.emit(selected_fish, base_count, total_xp, rarity, quality)
	save_game()

	return {
		"name": selected_fish,
		"count": base_count,
		"xp": total_xp,
		"rarity": rarity,
		"quality": quality,
		"color": fish_database[selected_fish]["color"],
		"exotic": exotic_msg + pet_bonus_msg,
		"chest": chest_data,
		"is_boss": false
	}

func award_boss_catch(result: Dictionary) -> void:
	var f_name = result["name"]
	var count = result.get("count", 1)
	var xp_amount = result.get("xp", 5000)
	inventory[f_name] = inventory.get(f_name, 0) + count
	diamond_fish += 1
	emerald_fish += 1
	add_xp(xp_amount)
	inventory_changed.emit()
	var rarity = fish_database[f_name]["rarity"]
	fish_caught.emit(f_name, count, xp_amount, rarity, QUALITY_TIERS["Diamond"])
	save_game()

func unlock_secret_rod() -> bool:
	var r_name = "0xDEADBEEF Dev Glitch Rod"
	if r_name not in owned_rods:
		owned_rods.append(r_name)
		current_rod = r_name
		stats_changed.emit()
		save_game()
		return true
	return false

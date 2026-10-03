extends Node

# --- Signals ---
signal stats_changed
signal inventory_changed
signal fish_caught(fish_name: String, count: int, xp_gained: int, rarity: String)
signal dock_available(dock_data: Dictionary)
signal dock_cleared
signal open_station_requested(dock_data: Dictionary)
signal close_station_requested
signal boss_hooked(boss_data: Dictionary)

const SAVE_PATH = "user://savegame.json"

# --- Player State ---
var cash: int = 150
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
	"Worms": 10,
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

# Mascots & Companions
var current_mascot: String = "rimuru_slime"
var mascots: Dictionary = {
	"rimuru_slime": {"name": "Rimuru Tempest (Slime)", "icon": "🌀", "fish_bonus": 1, "xp_mult": 1.0, "desc": "+1 Extra fish per reel."},
	"rimuru_human": {"name": "Rimuru Tempest (Human)", "icon": "👑", "fish_bonus": 0, "xp_mult": 1.15, "desc": "+15% Extra EXP gain."}
}

var equipped_pet: String = "None"
var owned_pets: Array[String] = []
var pets_database: Dictionary = {
	"Axo-9": {"req_level": 5, "icon": "🦎", "desc": "Cyber Axolotl. +15% XP Gain on all catches.", "xp_boost": 0.15, "double_catch": 0.0},
	"Otto-Flux": {"req_level": 15, "icon": "🦦", "desc": "Quantum Otter. 25% Chance to double fish catch.", "xp_boost": 0.0, "double_catch": 0.25},
	"Chrono-Jelly": {"req_level": 25, "icon": "🪼", "desc": "Tachyon Jelly. Slows down boss tension by 40%.", "xp_boost": 0.10, "double_catch": 0.10},
	"Aethelgard": {"req_level": 40, "icon": "🐉", "desc": "Sovereign Dragon. Instant boss taming & 50% double catch.", "xp_boost": 0.30, "double_catch": 0.50}
}

# --- Databases ---
var fish_database: Dictionary = {
	# River Biome
	"Raw Fish": {"price": 1, "xp": 1, "rarity": "Common", "biomes": ["River"], "color": Color(0.7, 0.8, 0.9), "is_boss": false},
	"Raw Salmon": {"price": 3, "xp": 2, "rarity": "Common", "biomes": ["River", "Volcanic"], "color": Color(1.0, 0.6, 0.5), "is_boss": false},
	"Cod": {"price": 10, "xp": 5, "rarity": "Uncommon", "biomes": ["River", "Volcanic"], "color": Color(0.9, 0.85, 0.4), "is_boss": false},
	"Tropical Fish": {"price": 50, "xp": 10, "rarity": "Rare", "biomes": ["River", "Volcanic", "Ocean"], "color": Color(0.2, 0.9, 0.8), "is_boss": false},
	"Pufferfish": {"price": 150, "xp": 25, "rarity": "Epic", "biomes": ["River", "Volcanic", "Ocean"], "color": Color(0.9, 0.7, 0.2), "is_boss": false},
	
	# Volcanic Biome
	"Fiery Pufferfish": {"price": 250, "xp": 50, "rarity": "Rare", "biomes": ["Volcanic"], "color": Color(1.0, 0.4, 0.2), "is_boss": false},
	"Hot Cod": {"price": 500, "xp": 100, "rarity": "Epic", "biomes": ["Volcanic"], "color": Color(1.0, 0.2, 0.2), "is_boss": false},
	"Magma Ray": {"price": 1500, "xp": 250, "rarity": "Legendary", "biomes": ["Volcanic"], "color": Color(1.0, 0.3, 0.0), "is_boss": false},
	
	# Ocean Biome
	"Squid": {"price": 1200, "xp": 175, "rarity": "Rare", "biomes": ["Ocean"], "color": Color(0.7, 0.4, 0.9), "is_boss": false},
	"Turtle": {"price": 4000, "xp": 400, "rarity": "Epic", "biomes": ["Ocean"], "color": Color(0.3, 0.8, 0.4), "is_boss": false},
	"Dolphin": {"price": 20000, "xp": 800, "rarity": "Legendary", "biomes": ["Ocean"], "color": Color(0.2, 0.6, 1.0), "is_boss": false},
	"Abyssal Kraken": {"price": 100000, "xp": 5000, "rarity": "TITAN BOSS", "biomes": ["Ocean"], "color": Color(0.9, 0.1, 0.2), "is_boss": true},

	# Secret Biome: Subspace 0x00 (Glitch Waters)
	"ERR_404_NULL_EEL": {"price": 30000, "xp": 1200, "rarity": "Rare", "biomes": ["Subspace 0x00"], "color": Color(0.0, 1.0, 0.8), "is_boss": false},
	"Quantum Matrix Ray": {"price": 85000, "xp": 3000, "rarity": "Epic", "biomes": ["Subspace 0x00"], "color": Color(0.8, 0.2, 1.0), "is_boss": false},
	"Tachyon Singularity Chimera": {"price": 250000, "xp": 8000, "rarity": "Legendary", "biomes": ["Subspace 0x00"], "color": Color(1.0, 0.9, 0.0), "is_boss": false},
	"Echo of the Glitch Sovereign": {"price": 1000000, "xp": 25000, "rarity": "TITAN BOSS", "biomes": ["Subspace 0x00"], "color": Color(0.0, 1.0, 1.0), "is_boss": true}
}

var rods_database: Dictionary = {
	"Plastic Rod": {"cost": 0, "min_fish": 4, "max_fish": 10, "cd_penalty": 0.0, "biomes": ["River"], "desc": "Basic starter rod."},
	"Improved Rod": {"cost": 500, "min_fish": 5, "max_fish": 10, "cd_penalty": 0.0, "biomes": ["River"], "desc": "Attracts slightly better fish."},
	"Steel Rod": {"cost": 8000, "min_fish": 5, "max_fish": 8, "cd_penalty": 0.0, "biomes": ["River"], "desc": "Catches higher quality fish."},
	"Fiberglass Rod": {"cost": 50000, "min_fish": 7, "max_fish": 10, "cd_penalty": 0.0, "biomes": ["River", "Ocean"], "desc": "Catches large amounts of quality fish."},
	"Lava Rod": {"cost": 1000000, "min_fish": 7, "max_fish": 11, "cd_penalty": 0.0, "biomes": ["River", "Volcanic", "Ocean"], "desc": "Forged to resist boiling magma."},
	"Celestial Prism Rod": {"cost": 5000000, "min_fish": 10, "max_fish": 18, "cd_penalty": -0.5, "biomes": ["River", "Volcanic", "Ocean", "Subspace 0x00"], "desc": "Refracts stellar light into pure fishing fortune."},
	"0xDEADBEEF Dev Glitch Rod": {"cost": 0, "min_fish": 20, "max_fish": 40, "cd_penalty": -1.2, "biomes": ["River", "Volcanic", "Ocean", "Subspace 0x00"], "desc": "Secret Easter Egg relic pulsing with binary code."}
}

var boats_database: Dictionary = {
	"Standard Skiff": {"cost": 0, "speed": 180.0, "cd_bonus": 0.0, "fish_bonus": 0, "desc": "Simple wooden skiff."},
	"Rowboat": {"cost": 5000, "speed": 220.0, "cd_bonus": 0.25, "fish_bonus": 1, "desc": "-0.25s CD, +1 fish per cast, faster rowing."},
	"Fishing Boat": {"cost": 25000, "speed": 260.0, "cd_bonus": 0.50, "fish_bonus": 2, "desc": "Motorized fishing vessel with improved hold."},
	"Speedboat": {"cost": 100000, "speed": 340.0, "cd_bonus": 0.75, "fish_bonus": 3, "desc": "High speed marine vessel for long-range cruising."},
	"Hovercraft Vanguard": {"cost": 750000, "speed": 420.0, "cd_bonus": 1.0, "fish_bonus": 5, "desc": "All-terrain air-cushion cruiser navigating reefs and magma alike."}
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
	# Initialize empty inventory
	for f in fish_database.keys():
		inventory[f] = 0
	load_game()

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
		"current_mascot": current_mascot,
		"equipped_pet": equipped_pet,
		"owned_pets": owned_pets
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(save_data)
		file.store_string(json_str)
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
	var parse_err = json.parse(json_str)
	if parse_err != OK:
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
	current_mascot = data.get("current_mascot", current_mascot)
	equipped_pet = data.get("equipped_pet", equipped_pet)
	if data.has("owned_pets"):
		owned_pets.clear()
		for p in data["owned_pets"]:
			owned_pets.append(str(p))

# --- Getters & Formulas ---
func get_sell_multiplier() -> float:
	return 1.0 + (upgrades["salesman"] * 0.05)

func get_fish_quality_multiplier() -> float:
	var bait_mult = 1.0
	if baits_database.has(current_bait):
		bait_mult = baits_database[current_bait]["quality_mult"]
	return (1.0 + (upgrades["better_fish"] * 0.05)) * bait_mult

func get_xp_multiplier() -> float:
	var bait_mult = 1.0
	if baits_database.has(current_bait):
		bait_mult = baits_database[current_bait]["xp_mult"]
	return (1.0 + (upgrades["experienced"] * 0.10)) * bait_mult

func get_fishing_cooldown() -> float:
	var base_cd = 3.5
	if current_biome == "Volcanic":
		base_cd += 0.5
	elif current_biome == "Ocean":
		base_cd += 1.0
	
	if boats_database.has(current_boat):
		base_cd -= boats_database[current_boat]["cd_bonus"]
	
	return max(1.5, base_cd)

func get_boat_speed() -> float:
	if boats_database.has(current_boat):
		return boats_database[current_boat]["speed"]
	return 180.0

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

	# Calculate quantity caught
	var base_count = randi_range(rod["min_fish"], rod["max_fish"])
	base_count += bait["bonus_fish"]
	base_count += boat["fish_bonus"]
	
	# Mascot Rimuru Slime Perk
	if current_mascot == "rimuru_slime":
		base_count += 1
		
	# Pet Perks (Double Catch)
	var pet_bonus_msg = ""
	if equipped_pet != "None" and pets_database.has(equipped_pet):
		var p_data = pets_database[equipped_pet]
		if p_data.get("double_catch", 0.0) > 0 and randf() < p_data["double_catch"]:
			base_count *= 2
			pet_bonus_msg = " ⚡ [PET DOUBLE-CATCH!]"

	base_count = max(1, base_count)

	# Store in inventory
	inventory[selected_fish] = inventory.get(selected_fish, 0) + base_count
	
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
	var xp_mult = get_xp_multiplier()
	if current_mascot == "rimuru_human":
		xp_mult *= 1.15
	if equipped_pet != "None" and pets_database.has(equipped_pet):
		xp_mult *= (1.0 + pets_database[equipped_pet].get("xp_boost", 0.0))

	var total_xp = int(base_count * xp_unit * xp_mult)
	var rarity = fish_database[selected_fish]["rarity"]
	var is_boss_fish = fish_database[selected_fish].get("is_boss", false)

	# Titan Boss Check
	if is_boss_fish:
		if equipped_pet == "Aethelgard":
			# Aethelgard instant taming perk!
			inventory[selected_fish] = inventory.get(selected_fish, 0) + base_count
			diamond_fish += 1
			add_xp(total_xp)
			inventory_changed.emit()
			fish_caught.emit(selected_fish, base_count, total_xp, rarity)
			save_game()
			return {
				"name": selected_fish,
				"count": base_count,
				"xp": total_xp,
				"rarity": rarity,
				"color": fish_database[selected_fish]["color"],
				"exotic": exotic_msg + pet_bonus_msg + " [🐉 Aethelgard Tamed Titan!]",
				"is_boss": false
			}
		else:
			# Boss hooked! Will trigger BossMinigame
			var boss_data = {
				"name": selected_fish,
				"count": base_count,
				"xp": total_xp,
				"rarity": rarity,
				"color": fish_database[selected_fish]["color"],
				"exotic": exotic_msg + pet_bonus_msg,
				"is_boss": true
			}
			boss_hooked.emit(boss_data)
			return boss_data

	# Standard chill instant catch
	inventory[selected_fish] = inventory.get(selected_fish, 0) + base_count
	add_xp(total_xp)
	inventory_changed.emit()
	fish_caught.emit(selected_fish, base_count, total_xp, rarity)
	save_game()

	return {
		"name": selected_fish,
		"count": base_count,
		"xp": total_xp,
		"rarity": rarity,
		"color": fish_database[selected_fish]["color"],
		"exotic": exotic_msg + pet_bonus_msg,
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
	fish_caught.emit(f_name, count, xp_amount, rarity)
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

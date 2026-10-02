extends Node

# --- Signals ---
signal stats_changed
signal inventory_changed
signal fish_caught(fish_name: String, count: int, xp_gained: int, rarity: String)
signal dock_available(dock_data: Dictionary)
signal dock_cleared
signal open_station_requested(dock_data: Dictionary)
signal close_station_requested

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

# --- Databases ---
var fish_database: Dictionary = {
	"Raw Fish": {"price": 1, "xp": 1, "rarity": "Common", "biomes": ["River", "Space"], "color": Color(0.7, 0.8, 0.9)},
	"Raw Salmon": {"price": 3, "xp": 2, "rarity": "Common", "biomes": ["River", "Volcanic", "Space"], "color": Color(1.0, 0.6, 0.5)},
	"Cod": {"price": 10, "xp": 5, "rarity": "Uncommon", "biomes": ["River", "Volcanic"], "color": Color(0.9, 0.85, 0.4)},
	"Tropical Fish": {"price": 50, "xp": 10, "rarity": "Rare", "biomes": ["River", "Volcanic", "Ocean"], "color": Color(0.2, 0.9, 0.8)},
	"Pufferfish": {"price": 150, "xp": 25, "rarity": "Epic", "biomes": ["River", "Volcanic", "Ocean"], "color": Color(0.9, 0.7, 0.2)},
	"Fiery Pufferfish": {"price": 250, "xp": 50, "rarity": "Rare", "biomes": ["Volcanic", "Sky"], "color": Color(1.0, 0.4, 0.2)},
	"Hot Cod": {"price": 500, "xp": 100, "rarity": "Epic", "biomes": ["Volcanic"], "color": Color(1.0, 0.2, 0.2)},
	"Squid": {"price": 1200, "xp": 175, "rarity": "Rare", "biomes": ["Ocean", "Sky"], "color": Color(0.7, 0.4, 0.9)},
	"Turtle": {"price": 4000, "xp": 400, "rarity": "Epic", "biomes": ["Ocean"], "color": Color(0.3, 0.8, 0.4)},
	"Dolphin": {"price": 20000, "xp": 800, "rarity": "Legendary", "biomes": ["Ocean"], "color": Color(0.2, 0.6, 1.0)}
}

var rods_database: Dictionary = {
	"Plastic Rod": {"cost": 0, "min_fish": 4, "max_fish": 10, "cd_penalty": 0.0, "biomes": ["River"], "desc": "Basic starter rod."},
	"Improved Rod": {"cost": 500, "min_fish": 5, "max_fish": 10, "cd_penalty": 0.0, "biomes": ["River"], "desc": "Attracts slightly better fish."},
	"Steel Rod": {"cost": 8000, "min_fish": 5, "max_fish": 8, "cd_penalty": 0.0, "biomes": ["River"], "desc": "Catches higher quality fish."},
	"Fiberglass Rod": {"cost": 50000, "min_fish": 7, "max_fish": 10, "cd_penalty": 0.0, "biomes": ["River"], "desc": "Catches large amounts of quality fish."},
	"Lava Rod": {"cost": 1000000, "min_fish": 7, "max_fish": 11, "cd_penalty": 0.0, "biomes": ["River", "Volcanic", "Ocean"], "desc": "Forged to resist boiling magma."}
}

var boats_database: Dictionary = {
	"Standard Skiff": {"cost": 0, "speed": 180.0, "cd_bonus": 0.0, "fish_bonus": 0, "desc": "Simple wooden skiff."},
	"Rowboat": {"cost": 5000, "speed": 220.0, "cd_bonus": 0.25, "fish_bonus": 1, "desc": "-0.25s CD, +1 fish per cast, faster rowing."},
	"Fishing Boat": {"cost": 25000, "speed": 260.0, "cd_bonus": 0.50, "fish_bonus": 2, "desc": "Motorized fishing vessel with improved hold."},
	"Speedboat": {"cost": 100000, "speed": 340.0, "cd_bonus": 0.75, "fish_bonus": 3, "desc": "High speed marine vessel for long-range cruising."}
}

var baits_database: Dictionary = {
	"None": {"cost": 0, "bonus_fish": 0, "quality_mult": 1.0, "xp_mult": 1.0, "desc": "Standard unbaited hook."},
	"Worms": {"cost": 4, "bonus_fish": 3, "quality_mult": 1.0, "xp_mult": 0.9, "desc": "+3 Fish per cast, -10% XP."},
	"Leeches": {"cost": 25, "bonus_fish": 3, "quality_mult": 1.2, "xp_mult": 0.8, "desc": "+20% Quality, +3 Fish, -20% XP."},
	"Wise": {"cost": 35, "bonus_fish": 0, "quality_mult": 1.0, "xp_mult": 2.5, "desc": "+150% XP Gain for rapid leveling."},
	"Fish": {"cost": 70, "bonus_fish": 1, "quality_mult": 2.0, "xp_mult": 0.7, "desc": "+100% Quality, +1 Fish."}
}

func _ready() -> void:
	# Initialize empty inventory
	for f in fish_database.keys():
		inventory[f] = 0

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

# --- Economy Methods ---
func add_cash(amount: int) -> void:
	cash += amount
	stats_changed.emit()

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = int(xp_needed * 1.45 + 15)
	stats_changed.emit()

func sell_fish(fish_name: String) -> int:
	if not inventory.has(fish_name) or inventory[fish_name] <= 0:
		return 0
	var count = inventory[fish_name]
	var unit_price = fish_database[fish_name]["price"]
	var total = int(count * unit_price * get_sell_multiplier())
	inventory[fish_name] = 0
	add_cash(total)
	inventory_changed.emit()
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
		if roll < 0.05 and "Dolphin" in eligible_fish:
			selected_fish = "Dolphin"
		elif roll < 0.20 and "Turtle" in eligible_fish:
			selected_fish = "Turtle"
		elif roll < 0.45 and "Squid" in eligible_fish:
			selected_fish = "Squid"
		else:
			selected_fish = "Pufferfish"

	# Calculate quantity caught
	var base_count = randi_range(rod["min_fish"], rod["max_fish"])
	base_count += bait["bonus_fish"]
	base_count += boat["fish_bonus"]
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
	var total_xp = int(base_count * xp_unit * get_xp_multiplier())
	add_xp(total_xp)

	inventory_changed.emit()
	var rarity = fish_database[selected_fish]["rarity"]
	fish_caught.emit(selected_fish, base_count, total_xp, rarity)

	return {
		"name": selected_fish,
		"count": base_count,
		"xp": total_xp,
		"rarity": rarity,
		"color": fish_database[selected_fish]["color"],
		"exotic": exotic_msg
	}

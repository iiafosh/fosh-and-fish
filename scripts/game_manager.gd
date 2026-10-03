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

# --- Player Profile State (Screenshot 1 Match) ---
var player_name: String = "iisafosh_"
var prestige: int = 4
var level: int = 203
var xp: int = 63266
var xp_needed: int = 3195000
var cash: int = 384021555
var current_biome: String = "Ocean"

# Exotic Currencies (Screenshot 1 Match)
var gold_fish: int = 2605
var emerald_fish: int = 1427
var lava_fish: int = 33
var diamond_fish: int = 51

# Special Currencies (Screenshot 1 Match)
var hooks: int = 101          # League currency
var azure_fish: int = 4       # Prestige currency

# Equipment & Companions
var current_rod: String = "Golden Rod"
var owned_rods: Array[String] = [
	"Plastic Rod", "Improved Rod", "Steel Rod", "Fiberglass Rod",
	"Heavy Rod", "Lava Rod", "Oceanium Rod", "Golden Rod"
]

var current_boat: String = "Luxury Yacht"
var owned_boats: Array[String] = [
	"Rowboat", "Fishing Boat", "Speedboat", "Pontoon",
	"Sailboat", "Yacht", "Luxury Yacht", "Cruise Ship"
]

var current_bait: String = "Artifact Magnet"
var bait_stock: Dictionary = {
	"Worms": 250,
	"Leeches": 40,
	"Magnet": 100,
	"Wise": 50,
	"Fish": 25,
	"Artifact Magnet": 2882,
	"Magic": 15,
	"Support": 10
}

# Pets (Screenshot 1 Match: Axolotl Level 51)
var equipped_pet: String = "Axolotl"
var pet_level: int = 51
var pet_xp: int = 2400
var pet_xp_needed: int = 5000
var owned_pets: Array[String] = ["Axolotl", "Puffer", "Dolphin"]

var pets_database: Dictionary = {
	"Axolotl": {
		"icon": "🦎", "desc": "+%s%% Treasure Quality & +%s%% Treasure Chance.",
		"type": "treasure"
	},
	"Puffer": {
		"icon": "🐡", "desc": "+%s%% Fish Catch.",
		"type": "fish_catch"
	},
	"Dolphin": {
		"icon": "🐬", "desc": "+%s%% XP Gain & +%s%% Treasure Chance.",
		"type": "xp_treasure"
	},
	"Zebrafish": {
		"icon": "🦓", "desc": "+%s%% Fish Catch & +%s%% Fish Quality.",
		"type": "catch_quality"
	},
	"Tuna": {
		"icon": "🐟", "desc": "+%s%% across All Stats.",
		"type": "all_stats"
	}
}

# Fish Inventory (Hold)
var inventory: Dictionary = {
	"Pufferfish": 6,
	"Squid": 1
}

# Shop Upgrades (level: int)
var upgrades: Dictionary = {
	"better_fish": 5,        # Master Angler (+5% quality per lvl)
	"salesman": 5,           # Master Merchant (+5% sell price per lvl)
	"more_chests": 5,        # Treasure Hunter (+5% treasure chance per lvl)
	"experienced": 5,        # Seasoned Sailor (+10% XP gain per lvl)
	"worker_motivation": 2,  # Increases Fish Catch from workers (+10%/lvl)
	"better_chests": 1       # Increases Treasure Quality (+10%/lvl)
}

# Special Upgrades (Exotic Fish)
var special_upgrades: Dictionary = {
	"fish_ovens": 2,         # +5% Sell Price (Cost: Lava Fish)
	"statistician": 2,       # +2% All Multipliers (Cost: Gold Fish)
	"duplicator": 1,         # +2% Fish Duplication (Cost: Emerald Fish)
	"boost_booster": 0       # +50% TQ, +40% FQ, +10% Worker Speed (Cost: Diamond Fish)
}

# League Upgrades (Hooks)
var league_upgrades: Dictionary = {
	"pet_helper": 1,         # +5 Max Pet Level (Cost: Hooks)
	"bait_helper": 1,        # +5% Bait Effectiveness (Cost: Hooks)
	"super_crates": 0,       # Unlocks Super Crates (Cost: Hooks)
	"worker_crates": 1,      # Worker Fishes Crates (Cost: Hooks)
	"fishing_frenzy": 0      # +10% Worker Trip Speed (Cost: Hooks)
}

# Auto-Trawler Net (Worker System from Virtual Fisher)
var worker_unlocked: bool = true
var worker_level: int = 2
var worker_timer: float = 14.0
var worker_boost_remaining: float = 0.0

# Dynamic Weather System (Virtual Fisher Core)
var current_weather: String = "Clear"
var weather_timer: float = 200.0
const WEATHERS = ["Clear", "Rain", "Storm", "Fog"]

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
	"Raw Fish": {"price": 1, "xp": 1, "rarity": "Common", "biomes": ["River"], "color": Color(0.7, 0.8, 0.9), "is_boss": false},
	"Raw Salmon": {"price": 3, "xp": 2, "rarity": "Common", "biomes": ["River", "Volcanic"], "color": Color(1.0, 0.6, 0.5), "is_boss": false},
	"Cod": {"price": 10, "xp": 5, "rarity": "Uncommon", "biomes": ["River", "Volcanic"], "color": Color(0.9, 0.85, 0.4), "is_boss": false},
	"Tropical Fish": {"price": 50, "xp": 10, "rarity": "Rare", "biomes": ["River", "Volcanic", "Ocean"], "color": Color(0.2, 0.9, 0.8), "is_boss": false},
	"Pufferfish": {"price": 150, "xp": 25, "rarity": "Epic", "biomes": ["River", "Volcanic", "Ocean"], "color": Color(0.9, 0.7, 0.2), "is_boss": false},
	
	# Volcanic Biome
	"Fiery Pufferfish": {"price": 250, "xp": 50, "rarity": "Rare", "biomes": ["Volcanic"], "color": Color(1.0, 0.4, 0.2), "is_boss": false},
	"Hot Cod": {"price": 500, "xp": 100, "rarity": "Epic", "biomes": ["Volcanic"], "color": Color(1.0, 0.2, 0.2), "is_boss": false},
	"Magma Ray": {"price": 1800, "xp": 320, "rarity": "Legendary", "biomes": ["Volcanic"], "color": Color(1.0, 0.3, 0.0), "is_boss": false},
	
	# Ocean Biome
	"Squid": {"price": 1200, "xp": 175, "rarity": "Rare", "biomes": ["Ocean"], "color": Color(0.7, 0.4, 0.9), "is_boss": false},
	"Turtle": {"price": 4000, "xp": 400, "rarity": "Epic", "biomes": ["Ocean"], "color": Color(0.3, 0.8, 0.4), "is_boss": false},
	"Dolphin": {"price": 20000, "xp": 800, "rarity": "Legendary", "biomes": ["Ocean"], "color": Color(0.2, 0.6, 1.0), "is_boss": false},
	"Abyssal Kraken": {"price": 120000, "xp": 6000, "rarity": "TITAN BOSS", "biomes": ["Ocean"], "color": Color(0.9, 0.1, 0.2), "is_boss": true},

	# Secret Biome: Subspace 0x00 (Glitch Waters)
	"ERR_404_NULL_EEL": {"price": 35000, "xp": 1400, "rarity": "Rare", "biomes": ["Subspace 0x00"], "color": Color(0.0, 1.0, 0.8), "is_boss": false},
	"Quantum Matrix Ray": {"price": 95000, "xp": 3500, "rarity": "Epic", "biomes": ["Subspace 0x00"], "color": Color(0.8, 0.2, 1.0), "is_boss": false},
	"Tachyon Singularity Chimera": {"price": 280000, "xp": 9000, "rarity": "Legendary", "biomes": ["Subspace 0x00"], "color": Color(1.0, 0.9, 0.0), "is_boss": false},
	"Echo of the Glitch Sovereign": {"price": 1200000, "xp": 30000, "rarity": "TITAN BOSS", "biomes": ["Subspace 0x00"], "color": Color(0.0, 1.0, 1.0), "is_boss": true}
}

# Complete 21 Rods from the Virtual Fisher Encyclopedia
var rods_database: Dictionary = {
	"Plastic Rod": {"cost": 0, "min_fish": 4, "max_fish": 10, "cd_penalty": 0.0, "treasure_chance": 0.05, "treasure_quality": 0.0, "biomes": ["River"], "desc": "Basic starter rod."},
	"Improved Rod": {"cost": 500, "min_fish": 5, "max_fish": 10, "cd_penalty": 0.0, "treasure_chance": 0.05, "treasure_quality": 0.0, "biomes": ["River"], "desc": "Attracts slightly better fish."},
	"Steel Rod": {"cost": 8000, "min_fish": 5, "max_fish": 8, "cd_penalty": 0.0, "treasure_chance": 0.05, "treasure_quality": 0.0, "biomes": ["River"], "desc": "Allows you to catch better fish, but slightly less of them."},
	"Fiberglass Rod": {"cost": 50000, "min_fish": 7, "max_fish": 10, "cd_penalty": 0.0, "treasure_chance": 0.05, "treasure_quality": 0.0, "biomes": ["River", "Ocean"], "desc": "Catches large amounts of quality fish."},
	"Heavy Rod": {"cost": 100000, "min_fish": 6, "max_fish": 9, "cd_penalty": 0.0, "treasure_chance": 0.085, "treasure_quality": 0.05, "biomes": ["River"], "desc": "Doesn't catch as many fish, but gets you far more treasure."},
	"Alloy Rod": {"cost": 250000, "min_fish": 4, "max_fish": 13, "cd_penalty": 0.0, "treasure_chance": 0.05, "treasure_quality": 0.0, "biomes": ["River"], "desc": "Catch rare fish at an inconsistent rate."},
	"Lava Rod": {"cost": 1000000, "min_fish": 7, "max_fish": 11, "cd_penalty": 0.0, "treasure_chance": 0.05, "treasure_quality": 0.0, "biomes": ["River", "Volcanic", "Ocean"], "desc": "Forged to resist boiling magma."},
	"Magma Rod": {"cost": 10000000, "min_fish": 10, "max_fish": 13, "cd_penalty": 0.0, "treasure_chance": 0.05, "treasure_quality": 0.0, "biomes": ["River", "Volcanic", "Ocean"], "desc": "Empowered lava rod to catch even more fish."},
	"Oceanium Rod": {"cost": 75000000, "min_fish": 11, "max_fish": 14, "cd_penalty": 0.0, "treasure_chance": 0.05, "treasure_quality": 0.0, "biomes": ["River", "Ocean"], "desc": "Made of rare ocean materials."},
	"Golden Rod": {"cost": 120000000, "min_fish": 4, "max_fish": 6, "cd_penalty": 0.0, "treasure_chance": 0.13, "treasure_quality": 0.0, "biomes": ["River", "Volcanic", "Ocean", "Sky"], "desc": "Made of pure gold. Catch treasure like you never thought possible."},
	"Superium Rod": {"cost": 250000000, "min_fish": 8, "max_fish": 18, "cd_penalty": 0.0, "treasure_chance": 0.055, "treasure_quality": 0.0, "biomes": ["River", "Volcanic", "Ocean", "Sky"], "desc": "Ultra light strong design for incredible fish catching abilities."},
	"Infinity Rod": {"cost": 1000000000, "min_fish": 15, "max_fish": 18, "cd_penalty": 0.0, "treasure_chance": 0.06, "treasure_quality": 0.0, "biomes": ["River", "Volcanic", "Ocean", "Sky"], "desc": "From 6 stones..."},
	"Floating Rod": {"cost": 50000000000, "min_fish": 15, "max_fish": 30, "cd_penalty": 0.0, "treasure_chance": 0.065, "treasure_quality": 0.0, "biomes": ["River", "Volcanic", "Ocean", "Sky", "Space"], "desc": "Emits so much energy it appears to float."},
	"Sky Rod": {"cost": 250000000000, "min_fish": 30, "max_fish": 34, "cd_penalty": 0.0, "treasure_chance": 0.067, "treasure_quality": 0.0, "biomes": ["River", "Volcanic", "Ocean", "Sky", "Space"], "desc": "The ultimate rod - made from elements found in the sky biome."},
	"Meteor Rod": {"cost": 500000000000, "min_fish": 20, "max_fish": 24, "cd_penalty": 0.0, "treasure_chance": 0.15, "treasure_quality": 0.30, "biomes": ["Space", "Alien"], "desc": "Extremely dense rod capable of attracting high quality treasure."},
	"Space Rod": {"cost": 1000000000000, "min_fish": 33, "max_fish": 37, "cd_penalty": 0.0, "treasure_chance": 0.068, "treasure_quality": 0.0, "biomes": ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien"], "desc": "SPAAAAAAAAAAACE."},
	"Alien Rod": {"cost": 5000000000000, "min_fish": 37, "max_fish": 42, "cd_penalty": 0.0, "treasure_chance": 0.07, "treasure_quality": 0.10, "biomes": ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien"], "desc": "An extremely complex rod built with alien technology."},
	"Ultimate Depths Rod": {"cost": 50000000000000, "min_fish": 40, "max_fish": 47, "cd_penalty": 0.0, "treasure_chance": 0.07, "treasure_quality": 0.05, "biomes": ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien", "Abyss"], "desc": "A rod capable of fishing in extreme depths."},
	"Abyssal Supermagnet": {"cost": 250000000000000, "min_fish": 22, "max_fish": 28, "cd_penalty": 0.0, "treasure_chance": 0.05, "treasure_quality": 0.50, "biomes": ["Abyss"], "desc": "A magnetic rod capable of attracting the highest quality treasure."},
	"Dark Rod": {"cost": 1000000000000000, "min_fish": 42, "max_fish": 50, "cd_penalty": 0.0, "treasure_chance": 0.07, "treasure_quality": 0.10, "biomes": ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien", "Abyss"], "desc": "The ultimate fishing rod."},
	"0xDEADBEEF Dev Glitch Rod": {"cost": 0, "min_fish": 20, "max_fish": 40, "cd_penalty": -1.2, "treasure_chance": 0.25, "treasure_quality": 0.25, "biomes": ["River", "Volcanic", "Ocean", "Subspace 0x00"], "desc": "Secret Easter Egg relic pulsing with binary code."}
}

# Complete 18-Tier Permanent Boat Progression from Virtual Fisher
var boats_database: Dictionary = {
	"Rowboat": {"tier": 1, "cost": 5000, "req_level": 0, "speed": 220.0, "cd_bonus": 0.25, "fish_bonus": 1, "visual_style": "Rowboat", "deck_bounds": Vector2(-170, 170), "desc": "-0.25s CD, +1 fish per cast."},
	"Fishing Boat": {"tier": 2, "cost": 25000, "req_level": 0, "speed": 260.0, "cd_bonus": 0.50, "fish_bonus": 2, "visual_style": "Fishing Boat", "deck_bounds": Vector2(-210, 220), "desc": "Motorized coastal workhorse."},
	"Speedboat": {"tier": 3, "cost": 100000, "req_level": 0, "speed": 340.0, "cd_bonus": 0.75, "fish_bonus": 3, "visual_style": "Speedboat", "deck_bounds": Vector2(-230, 230), "desc": "High-speed aerodynamic racer."},
	"Pontoon": {"tier": 4, "cost": 250000, "req_level": 0, "speed": 240.0, "cd_bonus": 1.00, "fish_bonus": 4, "visual_style": "Rowboat", "deck_bounds": Vector2(-220, 220), "desc": "Twin-hull river platform."},
	"Sailboat": {"tier": 5, "cost": 1000000, "req_level": 0, "speed": 280.0, "cd_bonus": 1.25, "fish_bonus": 5, "visual_style": "Rowboat", "deck_bounds": Vector2(-240, 240), "desc": "Traditional cutter under sail."},
	"Yacht": {"tier": 6, "cost": 20000000, "req_level": 50, "speed": 400.0, "cd_bonus": 1.50, "fish_bonus": 6, "visual_style": "Luxury Yacht", "deck_bounds": Vector2(-260, 260), "desc": "Spacious sea-going cruiser."},
	"Luxury Yacht": {"tier": 7, "cost": 100000000, "req_level": 50, "speed": 480.0, "cd_bonus": 1.75, "fish_bonus": 7, "visual_style": "Luxury Yacht", "deck_bounds": Vector2(-280, 280), "desc": "Tri-deck luxury sovereign flagship."},
	"Cruise Ship": {"tier": 8, "cost": 500000000, "req_level": 100, "speed": 360.0, "cd_bonus": 2.00, "fish_bonus": 8, "visual_style": "Luxury Yacht", "deck_bounds": Vector2(-300, 300), "desc": "Massive ocean-going liner."},
	"Gold Boat": {"tier": 9, "cost": 2500000000, "req_level": 250, "speed": 500.0, "cd_bonus": 2.25, "fish_bonus": 9, "visual_style": "Luxury Yacht", "deck_bounds": Vector2(-280, 280), "desc": "Solid gold plated pleasure craft."},
	"Sky Cruiser": {"tier": 10, "cost": 10000000000, "req_level": 250, "speed": 550.0, "cd_bonus": 2.50, "fish_bonus": 10, "visual_style": "Hovercraft Vanguard", "deck_bounds": Vector2(-280, 280), "desc": "Aero-skiff navigating high clouds."},
	"Satellite": {"tier": 11, "cost": 50000000000, "req_level": 500, "speed": 600.0, "cd_bonus": 2.75, "fish_bonus": 11, "visual_style": "Hovercraft Vanguard", "deck_bounds": Vector2(-270, 270), "desc": "Orbital sensory station."},
	"Space Shuttle": {"tier": 12, "cost": 250000000000, "req_level": 500, "speed": 680.0, "cd_bonus": 3.00, "fish_bonus": 12, "visual_style": "Hovercraft Vanguard", "deck_bounds": Vector2(-280, 280), "desc": "Rocket-propelled spaceplane."},
	"Cruiser": {"tier": 13, "cost": 1000000000000, "req_level": 500, "speed": 720.0, "cd_bonus": 3.25, "fish_bonus": 13, "visual_style": "Hovercraft Vanguard", "deck_bounds": Vector2(-290, 290), "desc": "Deep void battle cruiser."},
	"Alien Raft": {"tier": 14, "cost": 2500000000000, "req_level": 1000, "speed": 750.0, "cd_bonus": 3.50, "fish_bonus": 14, "visual_style": "Hovercraft Vanguard", "deck_bounds": Vector2(-280, 280), "desc": "Hover platform woven from alien tech."},
	"Alien Submarine": {"tier": 15, "cost": 5000000000000, "req_level": 1000, "speed": 780.0, "cd_bonus": 3.75, "fish_bonus": 15, "visual_style": "Abyssal Submersible", "deck_bounds": Vector2(-270, 270), "desc": "Extraterrestrial submersible vessel."},
	"Dark Explorer": {"tier": 16, "cost": 50000000000000, "req_level": 2500, "speed": 820.0, "cd_bonus": 4.00, "fish_bonus": 16, "visual_style": "Abyssal Submersible", "deck_bounds": Vector2(-280, 280), "desc": "Obsidian hull braving dark pressure."},
	"Abyssal Surveyor": {"tier": 17, "cost": 500000000000000, "req_level": 2500, "speed": 900.0, "cd_bonus": 4.25, "fish_bonus": 17, "visual_style": "Abyssal Submersible", "deck_bounds": Vector2(-290, 290), "desc": "The ultimate oceanic research bathyscaphe."}
}

# Complete 8 Baits from the Virtual Fisher Encyclopedia
var baits_database: Dictionary = {
	"None": {"cost": 0, "req_level": 0, "bonus_fish": 0, "quality_mult": 1.0, "xp_mult": 1.0, "treasure_chance_mult": 1.0, "treasure_qual_add": 0.0, "desc": "Standard unbaited hook."},
	"Worms": {"cost": 4, "req_level": 0, "bonus_fish": 2, "quality_mult": 1.0, "xp_mult": 0.9, "treasure_chance_mult": 1.0, "treasure_qual_add": 0.0, "desc": "+2 Fish per cast, -10% XP."},
	"Leeches": {"cost": 25, "req_level": 10, "bonus_fish": 3, "quality_mult": 1.2, "xp_mult": 0.8, "treasure_chance_mult": 1.0, "treasure_qual_add": 0.0, "desc": "+3 Fish, +20% Quality, -20% XP."},
	"Magnet": {"cost": 25, "req_level": 20, "bonus_fish": 0, "quality_mult": 0.9, "xp_mult": 1.2, "treasure_chance_mult": 1.5, "treasure_qual_add": 0.0, "desc": "+50% Treasure Chance, -10% Quality, +20% XP."},
	"Wise": {"cost": 35, "req_level": 30, "bonus_fish": 0, "quality_mult": 1.0, "xp_mult": 2.5, "treasure_chance_mult": 1.0, "treasure_qual_add": 0.0, "desc": "+150% XP Gain for rapid leveling."},
	"Fish": {"cost": 70, "req_level": 40, "bonus_fish": 1, "quality_mult": 2.0, "xp_mult": 0.7, "treasure_chance_mult": 1.0, "treasure_qual_add": 0.0, "desc": "+100% Quality, +1 Fish, -30% XP."},
	"Artifact Magnet": {"cost": 75, "req_level": 60, "bonus_fish": 0, "quality_mult": 0.7, "xp_mult": 1.3, "treasure_chance_mult": 1.4, "treasure_qual_add": 0.50, "desc": "+40% Treasure Chance, +50% Treasure Quality."},
	"Magic": {"cost": 250, "req_level": 80, "bonus_fish": 2, "quality_mult": 1.5, "xp_mult": 0.8, "treasure_chance_mult": 1.15, "treasure_qual_add": 0.15, "desc": "+2 Fish, +50% Quality, +15% Treasure Chance."},
	"Support": {"cost": 500, "req_level": 150, "bonus_fish": 0, "quality_mult": 1.0, "xp_mult": 1.0, "treasure_chance_mult": 1.0, "treasure_qual_add": 0.0, "desc": "+40% Pet Catch Chance, +35% Pet Effectiveness."}
}

func _ready() -> void:
	for f in fish_database.keys():
		if not inventory.has(f):
			inventory[f] = 0
	load_game()

func _process(delta: float) -> void:
	weather_timer -= delta
	if weather_timer <= 0.0:
		weather_timer = randf_range(180.0, 260.0)
		var next_idx = randi() % WEATHERS.size()
		current_weather = WEATHERS[next_idx]
		weather_changed.emit(current_weather)

	if worker_boost_remaining > 0.0:
		worker_boost_remaining = max(0.0, worker_boost_remaining - delta)

	if worker_unlocked or worker_boost_remaining > 0.0:
		worker_timer -= delta
		if worker_timer <= 0.0:
			var base_sec = 20.0 / (1.0 + 0.1 * special_upgrades.get("boost_booster", 0) + 0.1 * league_upgrades.get("fishing_frenzy", 0))
			if worker_boost_remaining > 0.0:
				base_sec *= 0.70
			worker_timer = max(5.0, base_sec - (worker_level - 1) * 1.5)
			_process_worker_trip()

func _process_worker_trip() -> void:
	var pool: Array[String] = []
	for f_name in fish_database.keys():
		if current_biome in fish_database[f_name]["biomes"] and not fish_database[f_name].get("is_boss", false):
			pool.append(f_name)
	if pool.is_empty():
		pool = ["Raw Fish"]
	var caught_fish = pool[randi() % pool.size()]
	var count = randi_range(1 + worker_level, 3 + worker_level * 2)
	var motivation_mult = 1.0 + (upgrades.get("worker_motivation", 0) * 0.10)
	count = int(count * motivation_mult)
	var price_each = int(fish_database[caught_fish]["price"] * get_sell_multiplier())
	var total_earned = count * price_each

	inventory[caught_fish] = inventory.get(caught_fish, 0) + count
	add_xp(count * fish_database[caught_fish]["xp"])
	inventory_changed.emit()
	worker_netted.emit(caught_fish, count, total_earned)

	# Worker crates roll from League Shop
	var wc_lvl = league_upgrades.get("worker_crates", 0)
	if wc_lvl > 0:
		var chances = [0.0, 0.02, 0.025, 0.031, 0.038, 0.05]
		var c_rate = chances[clamp(wc_lvl, 0, 5)]
		if randf() < c_rate:
			roll_treasure_chest()

	save_game()

func save_game() -> void:
	var save_data = {
		"player_name": player_name,
		"prestige": prestige,
		"level": level,
		"xp": xp,
		"xp_needed": xp_needed,
		"cash": cash,
		"gold_fish": gold_fish,
		"emerald_fish": emerald_fish,
		"lava_fish": lava_fish,
		"diamond_fish": diamond_fish,
		"hooks": hooks,
		"azure_fish": azure_fish,
		"current_rod": current_rod,
		"owned_rods": owned_rods,
		"current_boat": current_boat,
		"owned_boats": owned_boats,
		"current_bait": current_bait,
		"bait_stock": bait_stock,
		"equipped_pet": equipped_pet,
		"pet_level": pet_level,
		"pet_xp": pet_xp,
		"owned_pets": owned_pets,
		"inventory": inventory,
		"upgrades": upgrades,
		"special_upgrades": special_upgrades,
		"league_upgrades": league_upgrades,
		"worker_unlocked": worker_unlocked,
		"worker_level": worker_level,
		"worker_boost_remaining": worker_boost_remaining,
		"current_weather": current_weather,
		"current_biome": current_biome
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
	player_name = data.get("player_name", player_name)
	prestige = data.get("prestige", prestige)
	level = data.get("level", level)
	xp = data.get("xp", xp)
	xp_needed = data.get("xp_needed", xp_needed)
	cash = data.get("cash", cash)
	gold_fish = data.get("gold_fish", gold_fish)
	emerald_fish = data.get("emerald_fish", emerald_fish)
	lava_fish = data.get("lava_fish", lava_fish)
	diamond_fish = data.get("diamond_fish", diamond_fish)
	hooks = data.get("hooks", hooks)
	azure_fish = data.get("azure_fish", azure_fish)
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
	equipped_pet = data.get("equipped_pet", equipped_pet)
	pet_level = data.get("pet_level", pet_level)
	pet_xp = data.get("pet_xp", pet_xp)
	if data.has("owned_pets"):
		owned_pets.clear()
		for p in data["owned_pets"]:
			owned_pets.append(str(p))
	if data.has("inventory"):
		for k in data["inventory"].keys():
			inventory[k] = int(data["inventory"][k])
	if data.has("upgrades"):
		for k in data["upgrades"].keys():
			upgrades[k] = int(data["upgrades"][k])
	if data.has("special_upgrades"):
		for k in data["special_upgrades"].keys():
			special_upgrades[k] = int(data["special_upgrades"][k])
	if data.has("league_upgrades"):
		for k in data["league_upgrades"].keys():
			league_upgrades[k] = int(data["league_upgrades"][k])
	worker_unlocked = data.get("worker_unlocked", worker_unlocked)
	worker_level = data.get("worker_level", worker_level)
	worker_boost_remaining = data.get("worker_boost_remaining", worker_boost_remaining)
	current_weather = data.get("current_weather", current_weather)
	current_biome = data.get("current_biome", current_biome)

# --- Formatters & Getters ---
func get_display_level() -> String:
	if prestige > 0:
		return "P%d Level %d" % [prestige, level]
	return "Level %d" % level

func get_inventory_total_value() -> int:
	var total = 0
	var mult = get_sell_multiplier()
	for f in inventory.keys():
		var count = inventory[f]
		if count > 0 and fish_database.has(f):
			total += int(count * fish_database[f]["price"] * mult)
	return total

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
	var base_cd = 3.5
	if current_biome == "Volcanic":
		base_cd += 0.5
	elif current_biome == "Ocean":
		base_cd += 0.8
	
	# All owned boats stack CD bonus in Virtual Fisher
	var total_cd_bonus = 0.0
	for b in owned_boats:
		if boats_database.has(b):
			total_cd_bonus += 0.25

	base_cd -= total_cd_bonus

	if current_weather == "Rain":
		base_cd *= 0.80
	elif current_weather == "Storm":
		base_cd *= 0.65
	
	return max(1.5, base_cd)

func get_boat_speed() -> float:
	if boats_database.has(current_boat):
		return boats_database[current_boat]["speed"]
	return 180.0

func get_deck_bounds() -> Vector2:
	if boats_database.has(current_boat):
		var b = boats_database[current_boat]
		return b.get("deck_bounds", Vector2(-180, 180))
	return Vector2(-180.0, 180.0)

func get_upgrade_max(perk_name: String) -> int:
	match perk_name:
		"better_fish": return 21
		"salesman": return 18
		"more_chests": return 11
		"experienced": return 5
		"worker_motivation": return 12
		"better_chests": return 5
		_: return 10

func get_upgrade_cost(perk_name: String) -> int:
	var rank = upgrades.get(perk_name, 0)
	match perk_name:
		"better_fish": return int(250 * pow(1.65, rank))
		"salesman": return int(150 * pow(1.65, rank))
		"more_chests": return int(350 * pow(1.75, rank))
		"experienced": return int(1000 * pow(2.0, rank))
		"worker_motivation": return int(500 * pow(1.8, rank))
		"better_chests": return int(2000 * pow(2.2, rank))
		_: return int(200 * pow(1.75, rank))

func buy_perk_upgrade(perk_name: String) -> bool:
	var max_lvl = get_upgrade_max(perk_name)
	var current_lvl = upgrades.get(perk_name, 0)
	if current_lvl >= max_lvl:
		return false
	var cost = get_upgrade_cost(perk_name)
	if cash >= cost:
		cash -= cost
		upgrades[perk_name] = current_lvl + 1
		stats_changed.emit()
		save_game()
		return true
	return false

# --- Special Upgrades (Exotics) ---
func get_special_upgrade_cost(id: String) -> int:
	var rank = special_upgrades.get(id, 0)
	match id:
		"fish_ovens": return 10 + rank * 10
		"statistician": return 40 + rank * 40
		"duplicator": return 45 + rank * 45
		"boost_booster": return 5 + rank * 5
		_: return 20

func get_special_upgrade_currency(id: String) -> String:
	match id:
		"fish_ovens": return "lava"
		"statistician": return "gold"
		"duplicator": return "emerald"
		"boost_booster": return "diamond"
		_: return "gold"

func buy_special_upgrade(id: String) -> bool:
	var rank = special_upgrades.get(id, 0)
	var max_rank = 4 if id == "boost_booster" else (20 if id == "fish_ovens" else 10)
	if rank >= max_rank:
		return false
	var cost = get_special_upgrade_cost(id)
	var curr = get_special_upgrade_currency(id)
	var can_afford = false
	match curr:
		"lava": can_afford = (lava_fish >= cost)
		"gold": can_afford = (gold_fish >= cost)
		"emerald": can_afford = (emerald_fish >= cost)
		"diamond": can_afford = (diamond_fish >= cost)

	if can_afford:
		match curr:
			"lava": lava_fish -= cost
			"gold": gold_fish -= cost
			"emerald": emerald_fish -= cost
			"diamond": diamond_fish -= cost
		special_upgrades[id] = rank + 1
		stats_changed.emit()
		save_game()
		return true
	return false

# --- League Upgrades (Hooks) ---
func get_league_upgrade_cost(id: String) -> int:
	var rank = league_upgrades.get(id, 0)
	match id:
		"pet_helper", "bait_helper": return 15 + rank * 15
		_: return 20 + rank * 20

func buy_league_upgrade(id: String) -> bool:
	var rank = league_upgrades.get(id, 0)
	if rank >= 5:
		return false
	var cost = get_league_upgrade_cost(id)
	if hooks >= cost:
		hooks -= cost
		league_upgrades[id] = rank + 1
		stats_changed.emit()
		save_game()
		return true
	return false

# --- Worker Boosts ---
func buy_worker_boost(boost_type: String) -> bool:
	if boost_type == "Auto10m":
		if gold_fish >= 8:
			gold_fish -= 8
			worker_boost_remaining += 600.0
			stats_changed.emit()
			save_game()
			return true
	elif boost_type == "Auto30m":
		if emerald_fish >= 8:
			emerald_fish -= 8
			worker_boost_remaining += 1800.0
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
		if count > 0 and fish_database.has(f):
			var price = fish_database[f]["price"]
			total_earned += int(count * price * mult)
			inventory[f] = 0
	add_cash(total_earned)
	inventory_changed.emit()
	save_game()
	return total_earned

# --- Shop Actions ---
func buy_rod(r_name: String) -> bool:
	if not rods_database.has(r_name) or r_name in owned_rods:
		return false
	var cost = rods_database[r_name]["cost"]
	if cash >= cost:
		cash -= cost
		owned_rods.append(r_name)
		current_rod = r_name
		stats_changed.emit()
		save_game()
		return true
	return false

func select_rod(r_name: String) -> void:
	if r_name in owned_rods:
		current_rod = r_name
		stats_changed.emit()
		save_game()

func buy_boat(b_name: String) -> bool:
	if not boats_database.has(b_name) or b_name in owned_boats:
		return false
	var b_data = boats_database[b_name]
	if cash >= b_data["cost"] and level >= b_data.get("req_level", 0):
		cash -= b_data["cost"]
		owned_boats.append(b_name)
		current_boat = b_name
		stats_changed.emit()
		save_game()
		return true
	return false

func select_boat(b_name: String) -> void:
	if b_name in owned_boats:
		current_boat = b_name
		stats_changed.emit()
		save_game()

func buy_bait(b_name: String, amount: int) -> bool:
	if not baits_database.has(b_name) or b_name == "None":
		return false
	var total_cost = baits_database[b_name]["cost"] * amount
	if cash >= total_cost:
		cash -= total_cost
		bait_stock[b_name] = bait_stock.get(b_name, 0) + amount
		stats_changed.emit()
		save_game()
		return true
	return false

func select_bait(b_name: String) -> void:
	if baits_database.has(b_name):
		current_bait = b_name
		stats_changed.emit()
		save_game()

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
		bait_name = "Magnet"
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

	if current_bait != "None":
		if bait_stock.get(current_bait, 0) > 0:
			bait_stock[current_bait] -= 1
		else:
			current_bait = "None"
			stats_changed.emit()

	var eligible_fish: Array[String] = []
	for f_name in fish_database.keys():
		var f_data = fish_database[f_name]
		if biome_to_use in f_data["biomes"]:
			eligible_fish.append(f_name)

	if eligible_fish.is_empty():
		eligible_fish = ["Raw Fish"]

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
	base_count += owned_boats.size() # Cumulative permanent boats!
	if current_weather == "Rain":
		base_count += 1

	base_count = max(1, base_count)
	var quality = roll_fish_quality()

	var exotic_msg = ""
	if randf() < 0.08:
		gold_fish += 1
		exotic_msg = " +1 🪙 Gold Fish!"
	if randf() < 0.03:
		emerald_fish += 1
		exotic_msg = " +1 🟢 Emerald Fish!"

	var xp_unit = fish_database[selected_fish]["xp"]
	var xp_mult = get_xp_multiplier() * quality["xp_mult"]
	var total_xp = int(base_count * xp_unit * xp_mult)
	var rarity = fish_database[selected_fish]["rarity"]
	var is_boss_fish = fish_database[selected_fish].get("is_boss", false)

	# Sunken Treasure Chest check
	var chest_data = {}
	var base_t_chance = rod.get("treasure_chance", 0.05) * (1.0 + upgrades["more_chests"] * 0.05) * bait.get("treasure_chance_mult", 1.0)
	if current_weather == "Storm":
		base_t_chance += 0.15
	elif current_weather == "Fog":
		base_t_chance += 0.20
	if randf() < base_t_chance:
		chest_data = roll_treasure_chest()

	if is_boss_fish:
		var boss_data = {
			"name": selected_fish,
			"count": base_count,
			"xp": total_xp,
			"rarity": rarity,
			"quality": quality,
			"color": fish_database[selected_fish]["color"],
			"exotic": exotic_msg,
			"chest": chest_data,
			"is_boss": true
		}
		boss_hooked.emit(boss_data)
		return boss_data

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
		"exotic": exotic_msg,
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

class_name VFData
extends RefCounted
## Static game data for Virtual Fisher.
##
## Sources (in priority order):
##   1. Virtual Fisher Encyclopaedia (Google Doc by @defilantema)
##   2. virtualfisher.miraheze.org wiki (Rod, Biome, Upgrade, Charm, Pet, Worker,
##      Temporary Buff, Quest pages — snapshot in wiki_dump/)
##   3. Virtual Fisher Prestige 0 Guide (Google Doc by infernal._.)
##   4. Community Prestige Shop buy-order chart (P1-P160)
## Values the sources do not state (per-level upgrade prices, chest base
## weights, prestige requirements after P0) are marked "DERIVED" and are
## chosen to match the stated totals / guide pacing.

const BIOME_ORDER := ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien", "Abyss"]

## Fish lists are ordered lowest tier -> highest tier (matches the wiki's
## rod quality tables column order).
const BIOMES := {
	"River":    {"level": 1,    "cd_add": 0.0, "catch_rate": 1.0,   "pet_x": 0,
				 "fish": ["Raw Fish", "Raw Salmon", "Cod", "Tropical Fish", "Pufferfish"],
				 "accent": Color("#3ec7e0"), "desc": "Calm freshwater where every fisher starts."},
	"Volcanic": {"level": 50,   "cd_add": 0.5, "catch_rate": 0.6,   "pet_x": 2,
				 "fish": ["Raw Salmon", "Cod", "Tropical Fish", "Fiery Pufferfish", "Hot Cod"],
				 "accent": Color("#ff7a2f"), "desc": "Boiling waters under an active volcano. Unlocks Lava Fish and the Special Shop."},
	"Ocean":    {"level": 100,  "cd_add": 1.0, "catch_rate": 0.3,   "pet_x": 4,
				 "fish": ["Tropical Fish", "Pufferfish", "Squid", "Turtle", "Dolphin"],
				 "accent": Color("#2f7bff"), "desc": "Open sea. Unlocks Diamond Fish."},
	"Sky":      {"level": 250,  "cd_add": 2.0, "catch_rate": 0.12,  "pet_x": 5,
				 "fish": ["Fiery Pufferfish", "Squid", "Guardian", "Emerald Squid", "Rainbow Fish"],
				 "accent": Color("#c0392b"), "desc": "A sea of clouds between floating islands."},
	"Space":    {"level": 500,  "cd_add": 3.0, "catch_rate": 0.065, "pet_x": 7,
				 "fish": ["Raw Fish", "Raw Salmon", "Rainbow Fish", "Space Fish", "Galactic Crab"],
				 "accent": Color("#8e6cff"), "desc": "Zero-gravity currents among the stars."},
	"Alien":    {"level": 1000, "cd_add": 4.0, "catch_rate": 0.03,  "pet_x": 10,
				 "fish": ["Emerald Squid", "Rainbow Fish", "Space Fish", "Shark", "Alien Fish"],
				 "accent": Color("#4cd964"), "desc": "Strange seas under twin moons."},
	"Abyss":    {"level": 2500, "cd_add": 5.0, "catch_rate": 0.01,  "pet_x": 12,
				 "fish": ["Galactic Crab", "Shark", "Artifact Fish", "Dark Puffer", "Dark Tuna"],
				 "accent": Color("#6a2dbd"), "desc": "The lightless bottom of everything."},
}

const BEGINNER_XP := 3.0          # DERIVED: Beginner's Luck XP multiplier below level 10 (not in the bot)
const BEGINNER_XP_AT10 := 2.0     # DERIVED: fades linearly from x2 at level 10 ...
const BEGINNER_END := 25          # DERIVED: ... to x1 at level 25
const BASE_COOLDOWN := 3.5        # River base cooldown (wiki Biome page)
const MIN_COOLDOWN := 2.0         # Haste charm floor (wiki Charm page)

## Catch modes (not in the bot): "relax" = tap, wait out the cooldown (classic);
## "reel" = a short "Reel it in!" mini-game after each bite.
const CATCH_MODES := ["relax", "reel"]
const MINIGAME_FISH_BONUS := 0.75 # win the mini-game: +75% fish on that cast (owner: skill should pay off)
const MINIGAME_COOLDOWN := 0.5    # ... and the next cast is ready after 0.5s (instead of the normal cooldown)
## Interface scale for a touch screen whose short side is short_dp (CSS px on the web, dp on Android):
## about 1.28 layout px per dp, at least 500 px of height, never smaller than the 1280x720 desktop layout.
## (vf_main applies it, times the player's Settings -> Interface size, as the window's content scale;
## phones ~1.4, tablets 1. 0.5.4 used 1.15 / 460 px: testers found it too big.)
static func ui_scale_for(short_dp: float) -> float:
	if short_dp <= 0.0: return 1.0
	return clampf(720.0 / clampf(short_dp * 1.28, 500.0, 720.0), 1.0, 1.6)

## Rod "reel power" for the Reel it in! mini-game (not in the bot): 0 for the starter rod,
## 1.0 for the best rods. More power = a bigger catch zone, a faster reel and slower slipping.
static func rod_reel_power(r: String) -> float:
	if RODS.has(r) and RODS[r].has("reel"): return float(RODS[r].reel)       # exclusive rods
	var i := ROD_ORDER.find(r)
	if i < 0: return 0.0
	var regular := 0
	for x in ROD_ORDER:
		if not RODS[x].has("reel"): regular += 1
	return clampf(float(i) / float(regular - 1), 0.0, 1.0)

## Mini-game difficulty for a fish tier (0 common .. 4 rarest), the rod's reel power (0..1)
## and the device. Rarer fish: smaller zone, faster fish, slower reel. Better rod: bigger zone,
## faster reel, less slipping. Desktop (keyboard + mouse) gets a slightly calmer setup than phones.
## Tuning history (reaction-time bot, starter rod vs common fish on PC): 0.5.1 ~1% (owner: "really
## hard"), 0.5.2 ~100% (owner: "really easy"), 0.5.3 ~52% - a sharp player wins most common fish,
## rare fish need a better rod, and even the best rod can lose to the rarest fish (~60%).
static func minigame_params(tier: int, power: float, desktop := false) -> Dictionary:
	var t := clampi(tier, 0, 4)
	var pw := clampf(power, 0.0, 1.0)
	var p := {
		"zone_h": 0.34 - 0.03 * t + 0.09 * pw,
		"fish_speed": 0.32 + 0.09 * t,
		"fill_rate": (0.42 - 0.03 * t) * (1.0 + 0.4 * pw),
		"drain_rate": 0.24 * (1.0 - 0.3 * pw),
		"time_limit": MINIGAME_TIME + 0.25 * t,
		"lift": 3.4, "sink": 2.8, "max_v": 1.7,
	}
	if desktop:
		p.zone_h += 0.04
		p.fish_speed *= 0.9
		p.fill_rate *= 1.08
		p.drain_rate *= 0.9
		p.time_limit += 1.0
		p.lift = 3.0
		p.sink = 2.4
		p.max_v = 1.45
	else:
		p.zone_h += 0.035
		p.fish_speed *= 0.92
		p.fill_rate *= 1.06
		p.drain_rate *= 0.92
		p.time_limit += 0.8
		p.lift = 3.15
		p.sink = 2.55
		p.max_v = 1.52
	return p

const MINIGAME_TIME := 7.0        # seconds before the fish wriggles free (rarer fish: up to +1s)

const FISH := {
	"Raw Fish":         {"price": 1,        "xp": 1},
	"Raw Salmon":       {"price": 3,        "xp": 2},
	"Cod":              {"price": 10,       "xp": 5},
	"Tropical Fish":    {"price": 50,       "xp": 10},
	"Pufferfish":       {"price": 150,      "xp": 25},
	"Fiery Pufferfish": {"price": 250,      "xp": 50},
	"Hot Cod":          {"price": 500,      "xp": 100},
	"Squid":            {"price": 1200,     "xp": 175},
	"Turtle":           {"price": 4000,     "xp": 400},
	"Dolphin":          {"price": 20000,    "xp": 800},
	"Guardian":         {"price": 29000,    "xp": 1100},
	"Emerald Squid":    {"price": 42000,    "xp": 1900},
	"Rainbow Fish":     {"price": 125000,   "xp": 4800},
	"Space Fish":       {"price": 200000,   "xp": 8000},
	"Galactic Crab":    {"price": 600000,   "xp": 15000},
	"Shark":            {"price": 2000000,  "xp": 35000},
	"Alien Fish":       {"price": 5000000,  "xp": 65000},
	"Artifact Fish":    {"price": 8000000,  "xp": 120000},
	"Dark Puffer":      {"price": 23000000, "xp": 270000},
	"Dark Tuna":        {"price": 40000000, "xp": 420000},
}

const FISH_ORDER := ["Raw Fish", "Raw Salmon", "Cod", "Tropical Fish", "Pufferfish",
	"Fiery Pufferfish", "Hot Cod", "Squid", "Turtle", "Dolphin", "Guardian",
	"Emerald Squid", "Rainbow Fish", "Space Fish", "Galactic Crab", "Shark",
	"Alien Fish", "Artifact Fish", "Dark Puffer", "Dark Tuna"]

## Exotic fish are currencies, not sellable fish.
const EXOTICS := {
	"gold":    {"name": "Gold Fish",    "level": 10,  "color": Color("#f5c542")},
	"emerald": {"name": "Emerald Fish", "level": 10,  "color": Color("#2ecc71")},
	"lava":    {"name": "Lava Fish",    "level": 50,  "color": Color("#ff5a1f")},
	"diamond": {"name": "Diamond Fish", "level": 100, "color": Color("#7fe7ff")},
	"azure":   {"name": "Azure Fish",   "level": 0,   "color": Color("#3a7bff")},
}

## Rod quality tables: probability per biome fish (low -> high tier), from
## the wiki Rod page. Rods without a measured table in a biome fall back to
## the closest cheaper measured rod in that biome (see VFGame._rod_table).
const RODS := {
	"Plastic Rod":         {"cost": 0,                 "level": 0,    "min": 4,  "max": 10, "tc": 0.05,  "tq": 0.0,  "biomes": ["River"],
							"tables": {"River": [84, 13.5, 2.5, 0, 0]}, "desc": "Basic starter rod."},
	"Improved Rod":        {"cost": 500,               "level": 0,    "min": 5,  "max": 10, "tc": 0.05,  "tq": 0.0,  "biomes": ["River"],
							"tables": {"River": [56, 30, 14, 0, 0]}, "desc": "Attracts slightly better fish."},
	"Steel Rod":           {"cost": 8000,              "level": 0,    "min": 5,  "max": 8,  "tc": 0.05,  "tq": 0.0,  "biomes": ["River"],
							"tables": {"River": [20, 35, 45, 0, 0]}, "desc": "Allows you to catch better fish, but slightly less of them."},
	"Fiberglass Rod":      {"cost": 50000,             "level": 0,    "min": 7,  "max": 10, "tc": 0.05,  "tq": 0.0,  "biomes": ["River"],
							"tables": {"River": [15, 30, 50, 5, 0]}, "desc": "Catches large amounts of quality fish."},
	"Heavy Rod":           {"cost": 100000,            "level": 0,    "min": 6,  "max": 9,  "tc": 0.085, "tq": 0.05, "biomes": ["River"],
							"tables": {"River": [15, 30, 45, 10, 0]}, "desc": "Doesn't catch as many fish, but gets you far more treasure."},
	"Alloy Rod":           {"cost": 250000,            "level": 0,    "min": 4,  "max": 13, "tc": 0.05,  "tq": 0.0,  "biomes": ["River"],
							"tables": {"River": [15, 30, 42, 10, 3]}, "desc": "Catch rare fish at an inconsistent rate."},
	"Lava Rod":            {"cost": 1000000,           "level": 0,    "min": 7,  "max": 11, "tc": 0.05,  "tq": 0.0,  "biomes": ["River", "Volcanic", "Ocean"],
							"tables": {"Volcanic": [15, 25, 37, 19, 4]}, "desc": "Catches many rare fish consistently."},
	"Magma Rod":           {"cost": 10000000,          "level": 0,    "min": 10, "max": 13, "tc": 0.05,  "tq": 0.0,  "biomes": ["River", "Volcanic", "Ocean"],
							"tables": {"Volcanic": [10, 20, 35, 27, 8], "Ocean": [35, 54, 9, 2, 0]}, "desc": "Empowered lava rod to catch even more fish."},
	"Oceanium Rod":        {"cost": 75000000,          "level": 100,  "min": 11, "max": 14, "tc": 0.05,  "tq": 0.0,  "biomes": ["River", "Ocean"],
							"tables": {"Ocean": [35, 40, 18, 7, 0.1]}, "desc": "Made of rare ocean materials."},
	"Golden Rod":          {"cost": 120000000,         "level": 100,  "min": 4,  "max": 6,  "tc": 0.13,  "tq": 0.0,  "biomes": ["River", "Volcanic", "Ocean", "Sky"],
							"tables": {"Ocean": [45, 40, 10, 5, 0]}, "desc": "Made of pure gold. Catch treasure like you never thought possible."},
	"Superium Rod":        {"cost": 250000000,         "level": 100,  "min": 8,  "max": 18, "tc": 0.055, "tq": 0.0,  "biomes": ["River", "Volcanic", "Ocean", "Sky"],
							"tables": {"Ocean": [3, 30, 40, 25, 2]}, "desc": "Ultra light strong design for incredible fish catching abilities."},
	"Infinity Rod":        {"cost": 1000000000,        "level": 100,  "min": 15, "max": 18, "tc": 0.06,  "tq": 0.0,  "biomes": ["River", "Volcanic", "Ocean", "Sky"],
							"tables": {"Ocean": [0, 15, 35, 45, 5], "Sky": [60, 24, 9.7, 5.5, 0.8]}, "desc": "From 6 stones..."},
	"Floating Rod":        {"cost": 50000000000,       "level": 250,  "min": 15, "max": 30, "tc": 0.065, "tq": 0.0,  "biomes": ["River", "Volcanic", "Ocean", "Sky", "Space"],
							"tables": {"Sky": [40, 40, 10, 8, 2]}, "desc": "Emits so much energy it appears to float."},
	"Sky Rod":             {"cost": 250000000000,      "level": 250,  "min": 30, "max": 34, "tc": 0.067, "tq": 0.0,  "biomes": ["River", "Volcanic", "Ocean", "Sky", "Space"],
							"tables": {"Sky": [20, 40, 26, 10, 4], "Space": [50, 33, 12.4, 4.4, 0.2]}, "desc": "The ultimate rod - made from elements found in the sky biome."},
	"Meteor Rod":          {"cost": 500000000000,      "level": 500,  "min": 20, "max": 24, "tc": 0.15,  "tq": 0.30, "biomes": ["Space", "Alien"],
							"tables": {"Space": [40, 32.3, 20, 7.5, 0.2], "Alien": [30, 40, 27.5, 2, 0.5]}, "desc": "Extremely dense rod capable of attracting much high quality treasure."},
	"Space Rod":           {"cost": 1000000000000,     "level": 500,  "min": 33, "max": 37, "tc": 0.068, "tq": 0.0,  "biomes": ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien"],
							"tables": {"Space": [40, 25, 20, 14.5, 0.5], "Alien": [30, 40, 25, 4, 1]}, "desc": "SPAAAAAAAAAAAACE."},
	"Alien Rod":           {"cost": 5000000000000,     "level": 1000, "min": 37, "max": 42, "tc": 0.07,  "tq": 0.05, "biomes": ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien", "Abyss"],
							"tables": {"Alien": [20, 30, 45, 7, 1.5], "Abyss": [64, 25, 10, 1, 0]}, "desc": "An extremely complex rod built with alien technology."},
	"Ultimate Depths Rod": {"cost": 50000000000000,    "level": 2500, "min": 40, "max": 47, "tc": 0.07,  "tq": 0.05, "biomes": ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien", "Abyss"],
							"tables": {"Alien": [10, 35, 45, 8.1, 1.9], "Abyss": [42, 42, 15.7, 2, 0.01]}, "desc": "A rod capable of fishing in extreme depths."},
	"Abyssal Supermagnet": {"cost": 250000000000000,   "level": 2500, "min": 22, "max": 28, "tc": 0.05,  "tq": 0.50, "biomes": ["Abyss"],
							"tables": {"Abyss": [42, 42, 14, 2, 0.01]}, "desc": "A magnetic rod capable of attracting the highest quality treasure."},
	"Dark Rod":            {"cost": 1000000000000000,  "level": 2500, "min": 42, "max": 50, "tc": 0.07,  "tq": 0.10, "biomes": ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien", "Abyss"],
							"tables": {"Alien": [15, 25, 46, 11, 3], "Abyss": [40, 40, 17, 2.7, 0.3]}, "desc": "The ultimate fishing rod."},
	# exclusive rods (1.0): never sold for money, kept through prestige. "exclusive" says where they come from,
	# "reel" is their Reel it in! power (regular rods get it from their place in ROD_ORDER)
	"Supporter Rod":       {"cost": 0,                 "level": 0,    "min": 7,  "max": 10, "tc": 0.065, "tq": 0.10,
							"exclusive": "pack", "reel": 1.0,
							"biomes": ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien", "Abyss"],
							"biome_mult": {"River": 1.0, "Volcanic": 1.2, "Ocean": 1.4, "Sky": 2.0, "Space": 3.2, "Alien": 4.0, "Abyss": 4.6},
							"tables": {"River": [14, 32, 47, 6.3, 0.7], "Volcanic": [10, 24, 42, 20, 4], "Ocean": [30, 40, 23, 6.8, 0.2],
									   "Sky": [39.8, 39.8, 12.7, 6.7, 1], "Space": [40, 32.7, 20, 7.05, 0.25], "Alien": [30, 30, 36, 5, 1],
									   "Abyss": [60, 26.4, 12.303, 1.29, 0.007]},
							"desc": "Comes with every Supporter Pack. Scales with every biome."},
	"Starfall Rod":        {"cost": 0,                 "level": 0,    "min": 8,  "max": 11, "tc": 0.075, "tq": 0.20,
							"exclusive": "event", "reel": 0.9,
							"biomes": ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien", "Abyss"],
							"biome_mult": {"River": 1.1, "Volcanic": 1.3, "Ocean": 1.55, "Sky": 2.2, "Space": 3.5, "Alien": 4.4, "Abyss": 5.0},
							"tables": {"River": [12, 30, 48, 8.6, 1.4], "Volcanic": [9, 22, 42, 22, 5], "Ocean": [27, 40, 24, 8.5, 0.5],
									   "Sky": [36, 39, 14, 9, 2], "Space": [37, 32, 21, 9.4, 0.6], "Alien": [27, 30, 37, 4.5, 1.5],
									   "Abyss": [56, 28, 14, 1.98, 0.02]},
							"desc": "Event Shop exclusive: forged from fallen stars. Scales with every biome."},
	"Pearl Rod":           {"cost": 0,                 "level": 0,    "min": 9,  "max": 12, "tc": 0.08,  "tq": 0.25,
							"exclusive": "pearl", "reel": 0.95,
							"biomes": ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien", "Abyss"],
							"biome_mult": {"River": 1.15, "Volcanic": 1.4, "Ocean": 1.65, "Sky": 2.35, "Space": 3.7, "Alien": 4.6, "Abyss": 5.3},
							"tables": {"River": [11, 29, 49, 9.2, 1.8], "Volcanic": [8, 21, 42, 23, 6], "Ocean": [25, 40, 25, 9.3, 0.7],
									   "Sky": [34, 39, 15, 9.5, 2.5], "Space": [35, 32, 22, 10.2, 0.8], "Alien": [25, 30, 38, 5, 2],
									   "Abyss": [53, 29, 15.5, 2.47, 0.03]},
							"desc": "Pearl exclusive: lustrous and strong. Scales with every biome."},
	"Legend Rod":          {"cost": 0,                 "level": 0,    "min": 11, "max": 15, "tc": 0.09,  "tq": 0.35,
							"exclusive": "pack", "reel": 1.0,
							"biomes": ["River", "Volcanic", "Ocean", "Sky", "Space", "Alien", "Abyss"],
							"biome_mult": {"River": 1.3, "Volcanic": 1.6, "Ocean": 1.9, "Sky": 2.7, "Space": 4.2, "Alien": 5.2, "Abyss": 6.0},
							"tables": {"River": [9, 27, 50, 11, 3], "Volcanic": [6, 19, 42, 25, 8], "Ocean": [22, 40, 26, 11, 1],
									   "Sky": [30, 39, 17, 10.5, 3.5], "Space": [32, 32, 23, 11.8, 1.2], "Alien": [22, 30, 39, 6, 3],
									   "Abyss": [48, 31, 17.5, 3.45, 0.05]},
							"desc": "Legend Pack exclusive: the best rod in the game. Scales with every biome."},
}

const ROD_ORDER := ["Plastic Rod", "Improved Rod", "Steel Rod", "Fiberglass Rod", "Heavy Rod",
	"Alloy Rod", "Lava Rod", "Magma Rod", "Oceanium Rod", "Golden Rod", "Superium Rod",
	"Infinity Rod", "Floating Rod", "Sky Rod", "Meteor Rod", "Space Rod", "Alien Rod",
	"Ultimate Depths Rod", "Abyssal Supermagnet", "Dark Rod", "Supporter Rod", "Starfall Rod", "Pearl Rod", "Legend Rod"]

## Rods that are never sold for money (packs, pearls, events) and survive prestige.
static func is_exclusive_rod(r: String) -> bool:
	return RODS.has(r) and RODS[r].has("exclusive")

## Every boat: -0.25s cooldown and +1 fish per cast (wiki Boat page).
const BOATS := {
	"Rowboat":          {"level": 1,    "cost": 5000},
	"Fishing Boat":     {"level": 1,    "cost": 25000},
	"Speedboat":        {"level": 1,    "cost": 100000},
	"Pontoon":          {"level": 1,    "cost": 250000},
	"Sailboat":         {"level": 1,    "cost": 1000000},
	"Yacht":            {"level": 1,    "cost": 20000000},
	"Luxury Yacht":     {"level": 50,   "cost": 100000000},
	"Cruise Ship":      {"level": 100,  "cost": 500000000},
	"Gold Boat":        {"level": 250,  "cost": 2500000000},
	"Sky Cruiser":      {"level": 250,  "cost": 10000000000},
	"Satellite":        {"level": 500,  "cost": 50000000000},
	"Space Shuttle":    {"level": 500,  "cost": 250000000000},
	"Cruiser":          {"level": 500,  "cost": 1000000000000},
	"Alien Raft":       {"level": 1000, "cost": 2500000000000},
	"Alien Submarine":  {"level": 1000, "cost": 5000000000000},
	"Dark Explorer":    {"level": 2500, "cost": 50000000000000},
	"Abyssal Surveyor": {"level": 2500, "cost": 500000000000000},
}

const BOAT_ORDER := ["Rowboat", "Fishing Boat", "Speedboat", "Pontoon", "Sailboat", "Yacht",
	"Luxury Yacht", "Cruise Ship", "Gold Boat", "Sky Cruiser", "Satellite", "Space Shuttle",
	"Cruiser", "Alien Raft", "Alien Submarine", "Dark Explorer", "Abyssal Surveyor"]

## Bait effects are fractions (0.2 = +20%). "fish" is flat extra fish per cast.
const BAITS := {
	"Worms":           {"cost": 4,   "level": 1,   "fish": 2, "xp": -0.10,
						"desc": "Increases amount of fish caught."},
	"Leeches":         {"cost": 25,  "level": 10,  "fish": 3, "catch": 0.20, "quality": 0.20, "xp": -0.20,
						"desc": "Increases amount of fish caught and slightly improves the quality of fish caught."},
	"Magnet":          {"cost": 25,  "level": 20,  "catch": -0.10, "quality": -0.10, "tc": 0.50, "xp": 0.20,
						"desc": "Causes fewer fish to bite but significantly increases your chances of finding treasure."},
	"Wise Bait":       {"cost": 35,  "level": 30,  "xp": 1.50,
						"desc": "Increases XP per fish catch."},
	"Fish":            {"cost": 70,  "level": 40,  "fish": 1, "catch": 0.50, "quality": 1.00, "xp": -0.30,
						"desc": "Increases your fish catch and the quality of fish."},
	"Artifact Magnet": {"cost": 75,  "level": 60,  "catch": -0.30, "quality": -0.30, "tc": 0.40, "tq": 0.50, "xp": 0.30,
						"desc": "Fewer fish bite, but more and better treasure."},
	"Magic Bait":      {"cost": 250, "level": 80,  "fish": 2, "catch": 1.00, "quality": 0.50, "tc": 0.15, "tq": 0.15, "xp": -0.20,
						"desc": "Causes you to catch more, better quality fish and treasure."},
	"Support Bait":    {"cost": 500, "level": 150, "pet_chance": 0.40, "pet_eff": 0.35, "pet_xp": 0.35,
						"desc": "Helps you find pets. Increases effectiveness of pets."},
}

const BAIT_ORDER := ["Worms", "Leeches", "Magnet", "Wise Bait", "Fish", "Artifact Magnet", "Magic Bait", "Support Bait"]

## Chest tiers. "w" is the DERIVED base weight before treasure quality is
## applied; drop tables are the encyclopedia percentages.
const CHESTS := [
	{"id": "common",    "name": "Common",    "mult": 1.0, "w": 55.0,
	 "drops": {"gold": 15, "emerald": 2, "lava": 1, "xpmoney": 82}},
	{"id": "uncommon",  "name": "Uncommon",  "mult": 1.0, "w": 27.0,
	 "drops": {"gold": 25, "emerald": 5, "lava": 1.9, "diamond": 1, "xpmoney": 67.1}},
	{"id": "rare",      "name": "Rare",      "mult": 1.4, "w": 12.0,
	 "drops": {"gold": 38, "emerald": 15, "lava": 6.5, "diamond": 6, "charm": 2, "xpmoney": 32.5}},
	{"id": "epic",      "name": "Epic",      "mult": 1.7, "w": 4.5,
	 "drops": {"gold": 25, "emerald": 25, "lava": 10, "diamond": 15, "charm": 25}},
	{"id": "legendary", "name": "Legendary", "mult": 2.2, "w": 1.3,
	 "drops": {"gold": 15, "emerald": 10, "lava": 15, "diamond": 20, "charm": 40}},
	{"id": "artifact",  "name": "Artifact",  "mult": 3.0, "w": 0.2,
	 "drops": {"gold": 5, "emerald": 5, "lava": 5, "diamond": 10, "charm": 75}},
]

const CHARMS := {
	"marketing":  {"name": "Marketing Charm",  "desc": "+5% Sell Price (compounding to T50)"},
	"endurance":  {"name": "Endurance Charm",  "desc": "+2.5% Fish Catch"},
	"haste":      {"name": "Haste Charm",      "desc": "-0.05s Fishing Cooldown"},
	"quantity":   {"name": "Quantity Charm",   "desc": "+5% Extra Chest Items"},
	"worker":     {"name": "Worker Charm",     "desc": "+3% Worker Fish"},
	"treasure":   {"name": "Treasure Charm",   "desc": "+2.5% Treasure Chance"},
	"quality":    {"name": "Quality Charm",    "desc": "+2.5% Treasure Quality"},
	"experience": {"name": "Experience Charm", "desc": "+5% XP"},
}

const CHARM_ORDER := ["marketing", "endurance", "haste", "quantity", "worker", "treasure", "quality", "experience"]

## Pet buffs in percent: value = a + b * level (wiki Pet "General Formula").
const PETS := {
	"Puffer":    {"desc": "Boosts Fish Catch.", "buffs": {"catch": [10.0, 0.75]}},
	"Zebrafish": {"desc": "Boosts Fish Quality and slightly boosts Fish Catch.",
				  "buffs": {"catch": [2.5, 0.1875], "quality": [10.0, 0.75]}},
	"Dolphin":   {"desc": "Boosts XP and Treasure Chance.", "buffs": {"xp": [7.5, 0.5625], "tc": [7.5, 0.5625]}},
	"Axolotl":   {"desc": "Boosts Treasure Quality and slightly boosts Treasure Chance.",
				  "buffs": {"tc": [2.5, 0.1875], "tq": [10.0, 0.75]}},
	"Tuna":      {"desc": "Slightly boosts every stat.",
				  "buffs": {"catch": [3.0, 0.225], "quality": [3.0, 0.225], "xp": [3.0, 0.225], "tc": [3.0, 0.225], "tq": [3.0, 0.225]}},
}

const PET_ORDER := ["Puffer", "Zebrafish", "Dolphin", "Axolotl", "Tuna"]

## Pet XP needed to go from level i+1 to i+2 (wiki Pet appendix; sums to
## 9,774,225 at Lv100 and 44,574,225 at Lv125).
const PET_XP := [50, 75, 100, 150, 200, 250, 300, 350, 400, 450, 500, 575, 650, 725, 800, 900, 1000,
	1100, 1200, 1300, 1400, 1500, 1600, 1750, 1900, 2050, 2200, 2350, 2500, 2600, 2800, 3000, 3250,
	3500, 3750, 4000, 4250, 4500, 4750, 5000, 5500, 6000, 6500, 7000, 8000, 9000, 10000, 12000, 14000,
	16000, 18000, 20000, 22000, 24000, 26000, 28000, 30000, 32500, 35000, 40000, 45000, 50000, 55000,
	60000, 65000, 70000, 75000, 80000, 85000, 90000, 95000, 100000, 105000, 110000, 120000, 130000,
	140000, 150000, 160000, 170000, 185000, 200000, 220000, 240000, 260000, 280000, 300000, 320000,
	340000, 360000, 380000, 400000, 430000, 465000, 500000, 550000, 600000, 650000, 700000, 750000,
	800000, 850000, 900000, 950000, 1000000, 1050000, 1100000, 1150000, 1200000, 1250000, 1300000,
	1350000, 1400000, 1450000, 1500000, 1550000, 1600000, 1650000, 1700000, 1800000, 1900000,
	2000000, 2100000, 2500000]

## Shop upgrades (/shop upgrades). "total" = cost to max (wiki Upgrade page).
## Per-level prices are DERIVED: a x1.45 geometric curve summing to "total".
const UPGRADES := {
	"better_fish":         {"name": "Better Fish",         "max": 21, "total": 14902000,  "desc": "+5% Fish Quality"},
	"salesman":            {"name": "Salesman",            "max": 20, "total": 34058000,  "desc": "+5% Sell Price"},
	"bait_efficiency":     {"name": "Bait Efficiency",     "max": 9,  "total": 220500,    "desc": "-5% chance to consume bait"},
	"more_chests":         {"name": "More Chests",         "max": 11, "total": 6087000,   "desc": "+5% Treasure Chance"},
	"worker_motivation":   {"name": "Worker Motivation",   "max": 12, "total": 777310000, "desc": "+10% Worker Fish Catch"},
	"artifact_specialist": {"name": "Artifact Specialist", "max": 7,  "total": 521500,    "desc": "+0.1 Treasure rewards (not charms)"},
	"experienced":         {"name": "Experienced",         "max": 5,  "total": 555550000, "desc": "+10% XP Gain"},
	"better_chests":       {"name": "Better Chests",       "max": 5,  "total": 131100000, "desc": "+10% Treasure Quality"},
	"better_dailies":      {"name": "Better Dailies",      "max": 10, "total": 2990000,   "desc": "+10% Daily reward items"},
}
const UPGRADE_ORDER := ["better_fish", "salesman", "bait_efficiency", "more_chests", "worker_motivation",
	"artifact_specialist", "experienced", "better_chests", "better_dailies"]

## Special upgrades (/shop special), paid in exotic fish.
const SPECIALS := {
	"fish_ovens":         {"name": "Fish Ovens",         "cur": "lava",    "max": 20, "total": 3360, "level": 50,  "desc": "+5% Sell Price"},
	"bait_lover":         {"name": "Bait Lover",         "cur": "diamond", "max": 4,  "total": 385,  "level": 100, "desc": "+15% Bait effectiveness"},
	"aquatic_expert":     {"name": "Aquatic Expert",     "cur": "diamond", "max": 4,  "total": 385,  "level": 100, "desc": "+5% Fish Catch"},
	"worker_extender":    {"name": "Worker Extender",    "cur": "diamond", "max": 4,  "total": 385,  "level": 100, "desc": "+10% Worker duration"},
	"ultimate_salesman":  {"name": "Ultimate Salesman",  "cur": "diamond", "max": 4,  "total": 385,  "level": 100, "desc": "+15% Sell Price"},
	"highly_experienced": {"name": "Highly Experienced", "cur": "diamond", "max": 4,  "total": 385,  "level": 100, "desc": "+15% XP Gain"},
	"boost_booster":      {"name": "Boost Booster",      "cur": "diamond", "max": 4,  "total": 385,  "level": 100, "desc": "Stronger Fish/Treasure boosts, faster workers"},
	"statistician":       {"name": "Statistician",       "cur": "gold",    "max": 10, "total": 4000, "level": 250, "desc": "+2% to all multipliers"},
	"duplicator":         {"name": "Duplicator",         "cur": "emerald", "max": 10, "total": 4400, "level": 500, "desc": "+2% chance to duplicate a trip's fish"},
	"charmer":            {"name": "Charmer",            "cur": "lava",    "max": 10, "total": 3200, "level": 500, "desc": "+2.5% Charms found"},
}
const SPECIAL_ORDER := ["fish_ovens", "bait_lover", "aquatic_expert", "worker_extender", "ultimate_salesman",
	"highly_experienced", "boost_booster", "statistician", "duplicator", "charmer"]

## League upgrades (/shop league), paid in Hooks. Never reset.
## Price lists are DERIVED to match the stated totals (1050 / 1185).
const LEAGUE := {
	"super_crates":   {"name": "Super Crates",   "costs": [50, 100, 200, 300, 400], "desc": "Unlocks Super Crates (1/4000 x TQ x level)"},
	"bait_helper":    {"name": "Bait Helper",    "costs": [50, 100, 200, 300, 400], "desc": "+10% Bait effectiveness"},
	"fishing_frenzy": {"name": "Fishing Frenzy", "costs": [50, 100, 200, 300, 400], "desc": "+10% Worker speed, stronger boosts"},
	"duplicator2":    {"name": "Duplicator 2.0", "costs": [75, 80, 90, 100, 110, 120, 130, 140, 160, 180], "desc": "+3% Duplication chance"},
	"pet_helper":     {"name": "Pet Helper",     "costs": [50, 100, 200, 300, 400], "desc": "+5 max Pet level"},
	"worker_crates":  {"name": "Worker Crates",  "costs": [50, 100, 200, 300, 400], "desc": "Workers can find chests"},
}
const LEAGUE_ORDER := ["super_crates", "bait_helper", "fishing_frenzy", "duplicator2", "pet_helper", "worker_crates"]

## Prestige perks: 1 Azure Fish each; cap per perk = 1 + floor(P/5).
const PRESTIGE_PERKS := {
	"international_ties": {"name": "International Ties", "short": "IT", "unlock": 1, "desc": "+10% to all multipliers"},
	"business_education": {"name": "Business Education", "short": "BE", "unlock": 1, "desc": "+40% Sell Price"},
	"fish_whisperer":     {"name": "Fish Whisperer",     "short": "FW", "unlock": 1, "desc": "+25% Fish Catch"},
	"ancient_one":        {"name": "Ancient One",        "short": "AO", "unlock": 1, "desc": "+35% XP Gain"},
	"virtual_fisher":     {"name": "Virtual Fisher",     "short": "VF", "unlock": 5, "desc": "+40% Fish Quality, +20% Sell Price, +20% XP"},
}
const PERK_ORDER := ["international_ties", "business_education", "fish_whisperer", "ancient_one", "virtual_fisher"]

## Shop boosts (/shop boosts), unlocked at level 10.
const BOOSTS := {
	"fish5m":      {"name": "Fish Boost",     "kind": "fish",     "cur": "gold",    "cost": 6, "secs": 300},
	"fish20m":     {"name": "Fish Boost",     "kind": "fish",     "cur": "emerald", "cost": 6, "secs": 1200},
	"treasure5m":  {"name": "Treasure Boost", "kind": "treasure", "cur": "gold",    "cost": 6, "secs": 300},
	"treasure20m": {"name": "Treasure Boost", "kind": "treasure", "cur": "emerald", "cost": 6, "secs": 1200},
	"auto10m":     {"name": "Worker",         "kind": "worker",   "cur": "gold",    "cost": 8, "secs": 600},
	"auto30m":     {"name": "Worker",         "kind": "worker",   "cur": "emerald", "cost": 8, "secs": 1800},
}
const BOOST_ORDER := ["fish20m", "treasure20m", "auto30m", "fish5m", "treasure5m", "auto10m"]

const WORKER_BASE_COOLDOWN := 20.0

## Daily quests (wiki Quest page). Normal quests pay money/XP; the special
## quest pays 10 Hooks.
const QUESTS := [
	{"id": "levelups", "name": "Daily Level-ups",       "stat": "levelups", "goals": [1, 2, 3]},
	{"id": "fishing",  "name": "Daily Fishing",         "stat": "fish",     "goals": [100, 500, 1000, 2500, 5000]},
	{"id": "chests",   "name": "Daily Artifact Hunter", "stat": "chests",   "goals": [5, 10, 25, 100]},
]
const SPECIAL_QUESTS := [
	{"id": "fisherman",  "name": "Fisherman",        "stat": "trips",    "goal": 1000},
	{"id": "charmer",    "name": "Charmer",          "stat": "charms",   "goal": 100},
	{"id": "exotic",     "name": "Exotic Fisherman", "stat": "chests",   "goal": 250},
	{"id": "booster",    "name": "Booster",          "stat": "boostmin", "goal": 360},
	{"id": "leveler",    "name": "Extreme Leveler",  "stat": "levelups", "goal": 20},
	{"id": "pet",        "name": "Pet Locator",      "stat": "pets",     "goal": 1},
]

## Prestige requirements. P0 -> P1 is from the Prestige 0 Guide
## (440/440 charms, Level 250, $5B). Later prestiges are DERIVED so the
## level requirement reaches the 25k cap around P160 (as the community
## buy-order chart notes).
static func prestige_level_req(p: int) -> int:
	return mini(25000, 250 + 150 * p)

static func prestige_money_req(p: int) -> int:
	return int(5_000_000_000.0 * pow(1.6, p))

static func charm_tier_cap(p: int) -> int:
	return 10 + p if p <= 99 else 2 * p - 88

static func charm_total_cap(p: int) -> int:
	var t := charm_tier_cap(p)
	return 8 * t * (t + 1) / 2

## Community Prestige Shop buy-order chart (the image the player shared).
## Returns {"main": String, "max": String} for the prestige you just reached.
static func prestige_guide(p: int) -> Dictionary:
	var d := p % 10
	match p:
		1: return {"main": "IT", "max": ""}
		2: return {"main": "FW | AO", "max": ""}
		3: return {"main": "AO | FW", "max": ""}
		4: return {"main": "SKIP", "max": ""}
		5: return {"main": "IT + VF", "max": ""}
		6: return {"main": "AO", "max": ""}
		7: return {"main": "FW", "max": ""}
		8: return {"main": "BE", "max": ""}
		9: return {"main": "SKIP", "max": ""}
		10: return {"main": "IT + VF", "max": ""}
		11: return {"main": "AO", "max": ""}
		12: return {"main": "FW", "max": ""}
		13, 14: return {"main": "SKIP", "max": ""}
		15: return {"main": "IT + VF + AO", "max": ""}
		16: return {"main": "FW", "max": ""}
		101: return {"main": "BE", "max": ""}
		141: return {"main": "AO", "max": ""}
		142: return {"main": "SKIP", "max": "AO27"}
		143, 144: return {"main": "SKIP", "max": ""}
		145: return {"main": "IT + VF + FW + BE", "max": "IT + VF + FW"}
		156: return {"main": "AO31", "max": "AO32"}
		157: return {"main": "AO32", "max": "SKIP"}
		158, 159: return {"main": "SKIP", "max": ""}
		160: return {"main": "IT + VF + FW", "max": "IT + VF + FW + AO"}
	if p >= 17 and p <= 85:
		if d == 1 or d == 6: return {"main": "BE", "max": ""}
		if d == 0 or d == 5: return {"main": "IT + VF + AO + FW", "max": ""}
		return {"main": "SKIP", "max": ""}
	if p >= 86 and p <= 100:
		if d in [1, 2, 6, 7]: return {"main": "BE", "max": ""}
		if d == 0 or d == 5: return {"main": "IT + VF + FW", "max": ""}
		return {"main": "SKIP", "max": ""}
	if p >= 102 and p <= 140:
		if d == 1 or d == 6: return {"main": "AO", "max": ""}
		if d == 0 or d == 5: return {"main": "IT + VF + FW + BE", "max": ""}
		return {"main": "SKIP", "max": ""}
	if p >= 146 and p <= 155:
		if d in [1, 2, 6, 7]: return {"main": "AO", "max": ""}
		if d == 0 or d == 5: return {"main": "IT + VF + FW", "max": ""}
		return {"main": "SKIP", "max": ""}
	return {"main": "—", "max": ""}

## Geometric price for upgrade level `lvl` (1-based) so all levels sum to total.
static func curve_cost(total: float, max_lvl: int, lvl: int, ratio: float = 1.45) -> int:
	var first := total * (ratio - 1.0) / (pow(ratio, max_lvl) - 1.0)
	return maxi(1, int(round(first * pow(ratio, lvl - 1))))

static func slug(name: String) -> String:
	return name.to_lower().replace(" ", "_").replace(".", "")


## Beginner goals shown one at a time under the HUD. Not part of the bot —
## they give new players a short-term target and speed up the first levels.
## stat: fish | sells | rods | bait_casts | species | level | boats | crews
## (new goals go at the end: saves only count how many are done)
const STARTER_GOALS := [
	{"id": "first_fish", "text": "Catch your first fish", "stat": "fish", "goal": 1, "reward": {"money": 20}},
	{"id": "sell", "text": "Sell your catch", "stat": "sells", "goal": 1, "reward": {"bait": ["Worms", 25]}},
	{"id": "fish50", "text": "Catch 50 fish", "stat": "fish", "goal": 50, "reward": {"money": 100}},
	{"id": "improved", "text": "Buy the Improved Rod at the shop", "stat": "rods", "goal": 2, "reward": {"money": 150}},
	{"id": "bait", "text": "Fish with bait 10 times", "stat": "bait_casts", "goal": 10, "reward": {"money": 150}},
	{"id": "species", "text": "Discover all 5 River fish", "stat": "species", "goal": 5, "reward": {"money": 400}},
	{"id": "lv5", "text": "Reach level 5", "stat": "level", "goal": 5, "reward": {"chest": "rare"}},
	{"id": "steel", "text": "Buy the Steel Rod", "stat": "rods", "goal": 3, "reward": {"money": 1200}},
	{"id": "boat", "text": "Buy your first boat (Rowboat)", "stat": "boats", "goal": 1, "reward": {"money": 1500}},
	{"id": "lv10", "text": "Reach level 10 — chests & boosts unlock", "stat": "level", "goal": 10, "reward": {"chest": "epic", "gold": 12, "emerald": 6}},
	{"id": "crew", "text": "Hire a crew: they fish for you (Menu - Fleet)", "stat": "crews", "goal": 1, "reward": {"chest": "rare"}},
]


# ====================================================================== 1.0
## Everything a little easier: money and XP earned x EASE (progress about 10% faster).
const EASE := 1.10

# ------------------------------------------------------------------ events
## One event starts after every EVENT_EVERY seconds of active play (casting in the last
## EVENT_IDLE seconds) and lasts its "secs". Effects multiply the normal rules.
const EVENT_EVERY := 600.0
const EVENT_IDLE := 90.0
const EVENTS := {
	"golden_hour":   {"name": "Golden Hour",   "secs": 120, "color": Color("#ffb627"), "icon": "sun-horizon",
		"desc": "Every fish sells for double", "money": 2.0, "fish_id": "Golden Koi"},
	"frenzy":        {"name": "Fish Frenzy",   "secs": 90,  "color": Color("#14b8a6"), "icon": "lightning",
		"desc": "Casts recharge twice as fast and bring +50% fish", "cooldown": 0.5, "fish": 1.5, "fish_id": "Frenzy Piranha"},
	"treasure_tide": {"name": "Treasure Tide", "secs": 120, "color": Color("#a855f7"), "icon": "treasure-chest",
		"desc": "Triple treasure chance and better chests", "treasure": 3.0, "tq": 1.5, "fish_id": "Treasure Crab"},
	"meteor_shower": {"name": "Meteor Shower", "secs": 120, "color": Color("#6366f1"), "icon": "shooting-star",
		"desc": "Shiny fish turn up five times as often", "shiny": 5.0, "fish_id": "Meteor Fish"},
	"boss":          {"name": "Boss Fish!",    "secs": 150, "color": Color("#ef4444"), "icon": "skull",
		"desc": "The Leviathan is near: every catch wears it down", "boss_hp": 25, "fish_id": "Leviathan"},
}
const EVENT_ORDER := ["golden_hour", "frenzy", "treasure_tide", "meteor_shower", "boss"]
## Event fish only bite during their event; each one pays money (scaled to your level) and Event Stars.
## You also get 1 Star for every catch during an event.
const EVENT_FISH := {
	"Golden Koi":     {"event": "golden_hour",   "chance": 0.10, "money": 6.0,  "stars": 3},
	"Frenzy Piranha": {"event": "frenzy",        "chance": 0.12, "money": 4.0,  "stars": 2},
	"Treasure Crab":  {"event": "treasure_tide", "chance": 0.10, "money": 5.0,  "stars": 3},
	"Meteor Fish":    {"event": "meteor_shower", "chance": 0.08, "money": 8.0,  "stars": 4},
	"Leviathan":      {"event": "boss",          "chance": 0.0,  "money": 40.0, "stars": 25},
}
const EVENT_FISH_ORDER := ["Golden Koi", "Frenzy Piranha", "Treasure Crab", "Meteor Fish", "Leviathan"]
## The Event Shop: exclusive things for Event Stars.
const EVENT_SHOP := {
	"starfall_rod": {"name": "Starfall Rod",  "cost": 400, "rod": "Starfall Rod", "desc": "Exclusive rod: +treasure, scales with every biome"},
	"event_chest":  {"name": "Event Chest",   "cost": 40,  "chest": "legendary",  "desc": "A legendary chest"},
	"shiny_lure":   {"name": "Shiny Lure",    "cost": 80,  "lure": 25,            "desc": "Your next 25 catches: shiny fish 3x as often"},
	"star_boost":   {"name": "Frenzy Boost",  "cost": 30,  "boost": [["fish", 1800]], "desc": "30 minutes of Fish Boost"},
}
const EVENT_SHOP_ORDER := ["starfall_rod", "shiny_lure", "event_chest", "star_boost"]

# ------------------------------------------------------------------ shinies
## Shiny fish: a rare sparkling version of every species, only SHINY_SUPPLY numbered copies of each
## worldwide. The game asks the server for a roll on SHINY_TICKET of your catches (signed in only);
## the server decides (supabase/schema.sql try_shiny: stock left, a cooldown, per-player caps, odds that
## fall for every copy you own), so nobody can collect a whole stock.
const SHINY_SUPPLY := 3000
const SHINY_TICKET := 1.0 / 50.0
const SHINY_LURE_MULT := 3.0
const SHINY_MAX_EACH := 3            # copies of one species a player can own (enforced by the server)
const SHINY_SELL_BONUS := 0.02       # +2% sell price for every shiny species you own
const SHINY_SERVER_ODDS := 1.0 / 70.0  # = base_odds in supabase/schema.sql try_shiny (shown to players as odds)

# --------------------------------------------------------- pearls & packs
## Pearls: the premium currency (Supporter Packs, Pearl Packs, ads), spent in the Pearl Shop.
## Prices here are only fallbacks: the store shows Google Play's real, local price.
const PACKS := {
	"pack_starter": {"name": "Starter Pack", "price": "$1.49", "pearls": 150, "color": Color("#22c55e"),
		"perks": {"money": 0.05}, "boost": [["fish", 2400]]},
	"pack_fisher":  {"name": "Fisher Pack",  "price": "$4.99", "pearls": 600, "color": Color("#0ea5e9"),
		"perks": {"money": 0.10, "xp": 0.05}, "rods": ["Pearl Rod"]},
	"pack_captain": {"name": "Captain Pack", "price": "$9.99", "pearls": 1500, "color": Color("#a855f7"),
		"perks": {"money": 0.20, "xp": 0.10, "worker": 0.25}, "boost": [["fish", 7200], ["treasure", 7200], ["worker", 7200]]},
	"pack_legend":  {"name": "Legend Pack",  "price": "$19.99", "pearls": 3500, "color": Color("#f59e0b"),
		"perks": {"money": 0.35, "xp": 0.15, "shiny": 0.25}, "rods": ["Legend Rod"],
		"boost": [["fish", 18000], ["treasure", 18000], ["worker", 18000]]},
}
const PACK_ORDER := ["pack_starter", "pack_fisher", "pack_captain", "pack_legend"]
const PEARL_PACKS := {
	"pearls_100":  {"pearls": 100,  "price": "$0.99"},
	"pearls_550":  {"pearls": 550,  "price": "$4.99"},
	"pearls_1200": {"pearls": 1200, "price": "$9.99"},
	"pearls_2600": {"pearls": 2600, "price": "$19.99"},
}
const PEARL_PACK_ORDER := ["pearls_100", "pearls_550", "pearls_1200", "pearls_2600"]
const PEARL_SHOP := {
	"fish1h":      {"name": "Fish Boost 1h",     "cost": 30,   "boost": [["fish", 3600]], "icon": "fish"},
	"treasure1h":  {"name": "Treasure Boost 1h", "cost": 30,   "boost": [["treasure", 3600]], "icon": "treasure-chest"},
	"worker1h":    {"name": "Worker 1h",         "cost": 40,   "boost": [["worker", 3600]], "icon": "robot"},
	"mega1h":      {"name": "Mega Boost 1h",     "cost": 80,   "boost": [["fish", 3600], ["treasure", 3600], ["worker", 3600]], "icon": "rocket-launch"},
	"money_bag":   {"name": "Bag of Money",      "cost": 40,   "money_levels": 20, "icon": "money"},
	"xp_potion":   {"name": "XP Potion",         "cost": 50,   "xp_frac": 0.5, "icon": "flask"},
	"chest":       {"name": "Legendary Chest",   "cost": 60,   "chest": "legendary", "icon": "treasure-chest"},
	"event_now":   {"name": "Start an Event",    "cost": 100,  "event": true, "icon": "confetti"},
	"shiny_lure":  {"name": "Shiny Lure",        "cost": 150,  "lure": 50, "icon": "sparkle"},
	"pearl_rod":   {"name": "Pearl Rod",         "cost": 1200, "rod": "Pearl Rod", "icon": "crown"},
}
const PEARL_SHOP_ORDER := ["mega1h", "fish1h", "treasure1h", "worker1h", "money_bag", "xp_potion", "chest", "event_now", "shiny_lure", "pearl_rod"]
## Rewarded ads (Android): watch one, get the reward. AD_DAILY_MAX ads a day in all.
const AD_REWARDS := {
	"ad_money2x": {"name": "Double Money",  "desc": "x2 money from selling for 10 minutes (stacks up to an hour)", "money2x": 600, "icon": "coins"},
	"ad_fish":    {"name": "Free Fish Boost", "desc": "15 minutes of Fish Boost", "boost": [["fish", 900]], "icon": "fish"},
	"ad_pearls":  {"name": "+10 Pearls",    "desc": "Up to 3 times a day", "pearls": 10, "max": 3, "icon": "circle"},
	# (not in the Store's Free tab: offered on the welcome-back card and by the daily spin)
	"ad_offline2x": {"name": "Double the catch", "desc": "x2 what your crews caught while you were away", "offline2x": true, "max": 3, "icon": "anchor"},
	"ad_spin":      {"name": "Extra spin", "desc": "One more spin of the wheel", "spin": 1, "max": 3, "icon": "star"},
}
const AD_ORDER := ["ad_money2x", "ad_fish", "ad_pearls"]
const AD_DAILY_MAX := 8

## Odds shown next to random things you can get with bought currency (Google Play's loot box rule).
## A chest's prizes: "Charms 40%, Diamond Fish 20%, ..." (what your level can't use yet comes as XP + money)
static func chest_odds(tier: String) -> String:
	var names := {"charm": "Charms", "gold": "Gold Fish", "emerald": "Emerald Fish", "lava": "Lava Fish",
		"diamond": "Diamond Fish", "xpmoney": "XP + money"}
	for c in CHESTS:
		if c.id != tier: continue
		var total := 0.0
		for k in c.drops: total += float(c.drops[k])
		var keys: Array = c.drops.keys()
		keys.sort_custom(func(a, b): return c.drops[a] > c.drops[b])
		var bits := []
		for k in keys:
			var pct := 100.0 * float(c.drops[k]) / total
			bits.append("%s %s%%" % [names.get(k, k), ("%d" % int(round(pct))) if absf(pct - round(pct)) < 0.05 else ("%.1f" % pct)])
		return ", ".join(bits) + " (what you can't use yet comes as XP + money)"
	return ""


## the chance of a shiny on one catch, before and with the lure (a species you don't have yet)
static func shiny_odds() -> String:
	var base := SHINY_TICKET * SHINY_SERVER_ODDS
	return "Odds of a shiny: about 1 in %s catches, 1 in %s with the lure (lower for species you already have, and as the %s run out)" % [
		_commas(int(round(1.0 / base))), _commas(int(round(1.0 / (base * SHINY_LURE_MULT)))), _commas(SHINY_SUPPLY)]


static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ==================================================================== idle
## Idle play (not in the bot, numbers DERIVED): your boat can fish by itself, crews you hire fish for you
## all the time, and they keep fishing while the game is closed.
## Auto-fish: Relax casts on their own, AUTO_SLOW times the cooldown apart (holding the button is faster,
## the Reel it in! mini-game faster still). Auto casts roll no shiny tickets and aren't active play (events).
const AUTO_LEVEL := 5
const AUTO_SLOW := 1.5
## The Fleet: the k-th crew sails the k-th boat of BOAT_ORDER and makes a trip every CREW_TRIP seconds
## with your rod, biome and catch buffs (like the bot's workers: Worker Motivation and Worker charms count,
## bait doesn't). Their fish give CREW_XP of the XP (levels come from your own fishing). The first crew
## costs CREW_COST, every next one CREW_GROWTH times the last. Prestige resets the fleet, like your boats.
## (Tuned with tests/idle_balance_probe.gd: 4 hours away pay about 35 minutes of your own fishing at level
## 10, an hour and a half at level 100, two and a half at level 250; the crews' XP adds a few levels early
## on, less than one late; hiring crews as you go gets a run to level 100 about 15% sooner.)
const FLEET_LEVEL := 5
const CREW_TRIP := 15.0
const CREW_XP := 0.25
const CREW_COST := 250.0
const CREW_GROWTH := 6.0
## Fleet upgrades, bought with money: the price of the next level = cost * growth^level; each level adds "step"
## (nets: fish per trip, speed: trips, cooler: seconds away, sealegs: the offline rate)
const FLEET_UPGRADES := {
	"nets":    {"name": "Bigger Nets",   "max": 8, "step": 0.05, "cost": 5000.0,  "growth": 5.0,  "icon": "fish", "desc": "+5% fish on every crew trip"},
	"speed":   {"name": "Faster Crews",  "max": 6, "step": 0.05, "cost": 8000.0,  "growth": 6.0,  "icon": "lightning", "desc": "Crews make their trips 5% faster"},
	"cooler":  {"name": "Bigger Cooler", "max": 4, "step": 3600.0, "cost": 50000.0, "growth": 12.0, "icon": "hourglass-medium", "desc": "Crews keep fishing an hour longer while you're away"},
	"sealegs": {"name": "Sea Legs",      "max": 5, "step": 0.05, "cost": 30000.0, "growth": 10.0, "icon": "anchor", "desc": "+5% of the catch while you're away"},
}
const FLEET_UPGRADE_ORDER := ["nets", "speed", "cooler", "sealegs"]
## While you're away the crews fish at OFFLINE_RATE (Sea Legs: more) for up to OFFLINE_HOURS (Bigger
## Cooler: longer). Away for less than OFFLINE_MIN seconds: nothing to report.
const OFFLINE_RATE := 0.35
const OFFLINE_HOURS := 4.0
const OFFLINE_MIN := 120.0

## The daily reward (the bot's /daily, here from level DAILY_LEVEL) also pays a 7-day calendar: claim every
## day (within 48 hours, or the streak starts over) to move along it; day 7 is the big one, then it repeats.
const DAILY_LEVEL := 3
const CALENDAR := [
	{"name": "Bag of Money", "money_levels": 2, "icon": "money"},
	{"name": "50 Best Bait", "bait_best": 50, "icon": "fish"},
	{"name": "Fish Boost 30m", "boost": [["fish", 1800]], "icon": "lightning"},
	{"name": "2 Spins", "spin": 2, "icon": "star"},
	{"name": "Epic Chest", "chest": "epic", "icon": "treasure-chest"},
	{"name": "25 Pearls", "pearls": 25, "icon": "drop"},
	{"name": "Jackpot", "pearls": 100, "chest": "legendary", "boost": [["fish", 3600], ["treasure", 3600]], "icon": "crown"},
]
## The daily spin: one free spin a day, more from the calendar and ads. "w" = the chance in percent (shown).
const SPIN := [
	{"name": "Money",      "money_levels": 1,                "w": 26, "color": Color("#22c55e")},
	{"name": "XP",         "xp_frac": 0.25,                  "w": 20, "color": Color("#3b82f6")},
	{"name": "Bait",       "bait_best": 25,                  "w": 16, "color": Color("#f59e0b")},
	{"name": "Fish Boost", "boost": [["fish", 900]],         "w": 12, "color": Color("#14b8a6")},
	{"name": "Big Money",  "money_levels": 5,                "w": 10, "color": Color("#0e9f6e")},
	{"name": "Rare Chest", "chest": "rare",                  "w": 8,  "color": Color("#a855f7")},
	{"name": "10 Pearls",  "pearls": 10,                     "w": 6,  "color": Color("#6366f1")},
	{"name": "JACKPOT",    "pearls": 50, "chest": "legendary", "w": 2, "color": Color("#ef4444")},
]

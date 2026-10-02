"""
Data models and catalog definitions for Virtual Fisher 2099 (vfish.fosh).
"""

from dataclasses import dataclass, field
from enum import Enum
from typing import List, Dict, Optional, Any


class Rarity(str, Enum):
    COMMON = "Common"
    UNCOMMON = "Uncommon"
    RARE = "Rare"
    EPIC = "Epic"
    LEGENDARY = "Legendary"
    MYTHIC = "Mythic"
    COSMIC = "Cosmic"
    GLITCH = "Glitch"


@dataclass
class FishSpecies:
    id: str
    name: str
    rarity: Rarity
    base_value: int
    min_weight: float
    max_weight: float
    biome: str  # 'all' or specific biome id
    description: str
    color: str
    emoji: str
    is_anomaly: bool = False


@dataclass
class CaughtFish:
    id: str
    species_id: str
    name: str
    rarity: str
    weight: float
    value: int
    caught_at: float
    biome: str
    color: str
    emoji: str
    is_anomaly: bool = False


@dataclass
class Rod:
    id: str
    name: str
    tier: int
    cost: int
    gem_cost: int
    luck_multiplier: float
    reel_speed_boost: float
    max_tension: float
    description: str
    is_secret: bool = False
    glow_color: str = "#00f0ff"


@dataclass
class Bait:
    id: str
    name: str
    cost: int
    gem_cost: int
    luck_bonus: float
    rare_weight_multiplier: float
    description: str
    is_secret: bool = False
    icon: str = "🪱"


@dataclass
class Biome:
    id: str
    name: str
    tier: int
    required_level: int
    travel_cost: int
    description: str
    theme_color: str
    bg_sky_color: str
    water_color: str
    is_secret: bool = False
    anomaly_factor: float = 1.0


@dataclass
class Pet:
    id: str
    name: str
    title: str
    tier: str  # Standard, Rare, Godlike
    description: str
    passive_description: str
    catch_speed_boost: float = 0.0
    sell_multiplier: float = 1.0
    double_catch_chance: float = 0.0
    rare_luck_bonus: float = 0.0
    passive_income_credits: int = 0
    passive_income_gems: int = 0
    instant_catch_chance: float = 0.0
    glow_color: str = "#00f0ff"
    icon: str = "🦎"
    is_overpowered: bool = False


# ==========================================
# MASTER CATALOGS
# ==========================================

BIOMES: Dict[str, Biome] = {
    "neon_waterfront": Biome(
        id="neon_waterfront",
        name="Neon Waterfront (District 7)",
        tier=1,
        required_level=1,
        travel_cost=0,
        description="A bustling cyber-canal bathed in holographic neon advertisements and synthwave tranquility.",
        theme_color="#00f0ff",
        bg_sky_color="#0a0520",
        water_color="#004466",
        is_secret=False,
        anomaly_factor=1.0,
    ),
    "biolum_shelf": Biome(
        id="biolum_shelf",
        name="Bioluminescent Coral Shelf",
        tier=2,
        required_level=5,
        travel_cost=500,
        description="Deep cyber-reefs alive with glowing nano-algae and electric marine life.",
        theme_color="#00ff9d",
        bg_sky_color="#021c1e",
        water_color="#006655",
        is_secret=False,
        anomaly_factor=1.3,
    ),
    "abyssal_trench": Biome(
        id="abyssal_trench",
        name="Mariana Cyber Trench",
        tier=3,
        required_level=12,
        travel_cost=2500,
        description="Pitch black depths pressurized at 11,000 meters. Home to ancient cybernetic behemoths.",
        theme_color="#7928ca",
        bg_sky_color="#050014",
        water_color="#180033",
        is_secret=False,
        anomaly_factor=1.8,
    ),
    "acid_basin": Biome(
        id="acid_basin",
        name="Corrosive Industrial Basin",
        tier=4,
        required_level=20,
        travel_cost=8000,
        description="Hazardous reactor coolant reservoir teeming with irradiated, mutated metal fish.",
        theme_color="#ff0055",
        bg_sky_color="#1a000d",
        water_color="#4d001a",
        is_secret=False,
        anomaly_factor=2.4,
    ),
    "orbital_ocean": Biome(
        id="orbital_ocean",
        name="Orbital Zero-G Hydrosphere",
        tier=5,
        required_level=30,
        travel_cost=25000,
        description="A floating sphere of zero-gravity water suspended in high orbit above Earth's satellites.",
        theme_color="#ffd700",
        bg_sky_color="#000000",
        water_color="#0a2a4a",
        is_secret=False,
        anomaly_factor=3.2,
    ),
    # SECRET BIOME:
    "subspace_zero": Biome(
        id="subspace_zero",
        name="Subspace 0x00: The Chrono-Singularity",
        tier=99,
        required_level=1,  # Accessible once player has key / coordinates!
        travel_cost=0,
        description="A collapsed reality fold where timelines converge. Liquid quantum data flows past fractured geometries.",
        theme_color="#ff00ea",
        bg_sky_color="#120024",
        water_color="#2b0054",
        is_secret=True,
        anomaly_factor=7.77,
    ),
}


RODS: Dict[str, Rod] = {
    "rod_starter": Rod(
        id="rod_starter",
        name="Nano Rod Mk-I",
        tier=1,
        cost=0,
        gem_cost=0,
        luck_multiplier=1.0,
        reel_speed_boost=0.0,
        max_tension=100.0,
        description="Standard issue lightweight cyber-rod with polymer line.",
        glow_color="#00f0ff",
    ),
    "rod_carbon": Rod(
        id="rod_carbon",
        name="Carbon Fiber Exoskeleton",
        tier=2,
        cost=800,
        gem_cost=0,
        luck_multiplier=1.35,
        reel_speed_boost=0.15,
        max_tension=140.0,
        description="Reinforced carbon-nanotube weave with magnetic line stabilizer.",
        glow_color="#39ff14",
    ),
    "rod_plasma": Rod(
        id="rod_plasma",
        name="Plasma Flux Caster",
        tier=3,
        cost=3500,
        gem_cost=15,
        luck_multiplier=1.85,
        reel_speed_boost=0.35,
        max_tension=200.0,
        description="Superheated magnetic coils accelerate cast distance and weaken fish thrash resistance.",
        glow_color="#ff007f",
    ),
    "rod_superconduct": Rod(
        id="rod_superconduct",
        name="Superconductive Harvester",
        tier=4,
        cost=15000,
        gem_cost=50,
        luck_multiplier=2.6,
        reel_speed_boost=0.6,
        max_tension=320.0,
        description="Zero-resistance superconductor wire capable of pulling deep sea behemoths.",
        glow_color="#9d00ff",
    ),
    "rod_void": Rod(
        id="rod_void",
        name="Dark Matter Void Spool",
        tier=5,
        cost=60000,
        gem_cost=150,
        luck_multiplier=4.0,
        reel_speed_boost=1.0,
        max_tension=500.0,
        description="Forged from stabilized micro-black holes. Gravitational pull draws massive mythic catches.",
        glow_color="#ff4500",
    ),
    # SECRET ROD 1:
    "rod_chronos": Rod(
        id="rod_chronos",
        name="The Chronos Singularity Rod",
        tier=6,
        cost=0,  # Unlocked only via Secret Ritual or Oracle Riddle!
        gem_cost=0,
        luck_multiplier=8.5,
        reel_speed_boost=2.0,
        max_tension=1000.0,
        description="Forged in Subspace 0x00. Warps local space-time, giving near-infinite line strength and cosmic anomaly detection.",
        is_secret=True,
        glow_color="#ff00ea",
    ),
    # EASTER EGG DEV ROD:
    "rod_dev_glitch": Rod(
        id="rod_dev_glitch",
        name="0xDEADBEEF Dev Glitch Rod",
        tier=7,
        cost=0,
        gem_cost=0,
        luck_multiplier=12.0,
        reel_speed_boost=4.0,
        max_tension=9999.0,
        description="A forbidden developer debug rod with infinite line strength and chromatic glitch rainbow effects.",
        is_secret=True,
        glow_color="#ffffff",
    ),
}


BAITS: Dict[str, Bait] = {
    "bait_basic": Bait(
        id="bait_basic",
        name="Synthetic Bio-Worm",
        cost=15,
        gem_cost=0,
        luck_bonus=0.0,
        rare_weight_multiplier=1.0,
        description="Standard lab-grown nutrient grub for basic fishing.",
        icon="🐛",
    ),
    "bait_neon": Bait(
        id="bait_neon",
        name="Neon Glowbait",
        cost=60,
        gem_cost=0,
        luck_bonus=0.35,
        rare_weight_multiplier=1.3,
        description="Emits 440nm cyan light pulses that attract exotic species.",
        icon="✨",
    ),
    "bait_magnetic": Bait(
        id="bait_magnetic",
        name="Magnetic Micro-Krill",
        cost=250,
        gem_cost=2,
        luck_bonus=0.8,
        rare_weight_multiplier=1.7,
        description="Nano-magnets pull heavier deep-water fish towards the hook.",
        icon="🧲",
    ),
    "bait_plasma": Bait(
        id="bait_plasma",
        name="Dark Plasma Cluster",
        cost=1000,
        gem_cost=8,
        luck_bonus=1.75,
        rare_weight_multiplier=2.5,
        description="Compressed plasma sphere tuned to abyssal predator frequencies.",
        icon="🔮",
    ),
    # SECRET BAIT:
    "bait_chrono": Bait(
        id="bait_chrono",
        name="Chrono-Singularity Bait",
        cost=5000,
        gem_cost=30,
        luck_bonus=4.5,
        rare_weight_multiplier=5.0,
        description="Quantum matter distilled from Subspace 0x00. Can tear open dimensional fissures.",
        is_secret=True,
        icon="🌌",
    ),
}


PETS: Dict[str, Pet] = {
    "pet_axolotl": Pet(
        id="pet_axolotl",
        name="Axo-9",
        title="Cybernetic Axolotl",
        tier="Standard",
        description="An amphibious companion equipped with cyber-goggles and gill-cooling fans.",
        passive_description="+25% Faster fish bite timing, +15% XP gained from all catches.",
        catch_speed_boost=0.25,
        sell_multiplier=1.0,
        double_catch_chance=0.0,
        rare_luck_bonus=0.1,
        passive_income_credits=0,
        passive_income_gems=0,
        instant_catch_chance=0.0,
        glow_color="#00f0ff",
        icon="🦎",
    ),
    "pet_penguin": Pet(
        id="pet_penguin",
        name="Ping-0",
        title="Mecha-Tux Penguin",
        tier="Standard",
        description="Tactical recon penguin with miniature rocket thrusters and deep-diving sonar.",
        passive_description="+35% Fish sell value, occasionally dives to salvage 50-200 bonus Credits.",
        catch_speed_boost=0.0,
        sell_multiplier=1.35,
        double_catch_chance=0.0,
        rare_luck_bonus=0.1,
        passive_income_credits=15,
        passive_income_gems=0,
        instant_catch_chance=0.0,
        glow_color="#39ff14",
        icon="🐧",
    ),
    "pet_otter": Pet(
        id="pet_otter",
        name="Otto-Flux",
        title="Holographic River Otter",
        tier="Rare",
        description="A playful hologram of pure light and quantum particles that plays with your line.",
        passive_description="30% chance for DOUBLE CATCH (two fish on one cast!) and +25% rare luck.",
        catch_speed_boost=0.1,
        sell_multiplier=1.1,
        double_catch_chance=0.30,
        rare_luck_bonus=0.25,
        passive_income_credits=0,
        passive_income_gems=0,
        instant_catch_chance=0.0,
        glow_color="#ff007f",
        icon="🦦",
    ),
    "pet_jelly": Pet(
        id="pet_jelly",
        name="Jelly-Pulse",
        title="Tachyon Chrono-Jelly",
        tier="Epic",
        description="An ethereal cosmic jellyfish that emits localized temporal deceleration waves.",
        passive_description="Slows reel mini-game bar by 40% and grants +50% rare fish probability.",
        catch_speed_boost=0.15,
        sell_multiplier=1.2,
        double_catch_chance=0.1,
        rare_luck_bonus=0.5,
        passive_income_credits=25,
        passive_income_gems=1,
        instant_catch_chance=0.1,
        glow_color="#9d00ff",
        icon="🪼",
    ),
    # THE OVERPOWERED SECRET PET:
    "pet_sovereign": Pet(
        id="pet_sovereign",
        name="Aethelgard, The Glitch Sovereign",
        title="Cosmic Singularity Leviathan",
        tier="GODLIKE / TRANSCENDENT",
        description="A legendary celestial serpent born from the code of Subspace 0x00. Its scales bend the fabric of reality itself.",
        passive_description="🔥 OVERPOWERED: 5.0x Sell Multiplier, 100% Perfect Auto-Reel, 500% Cosmic Fish Luck, and harvests 250 Credits + 2 Gems every 8 seconds!",
        catch_speed_boost=0.8,
        sell_multiplier=5.0,
        double_catch_chance=0.5,
        rare_luck_bonus=5.0,
        passive_income_credits=250,
        passive_income_gems=2,
        instant_catch_chance=1.0,
        glow_color="#ff00ea",
        icon="🐉",
        is_overpowered=True,
    ),
}


# ==========================================
# FISH SPECIES (Extensive Virtual Fisher Roster)
# ==========================================

FISH_SPECIES: List[FishSpecies] = [
    # Tier 1 - Neon Waterfront
    FishSpecies("neon_tetra", "Neon Tetra", Rarity.COMMON, 12, 0.2, 0.8, "neon_waterfront", "A tiny bioluminescent freshwater fish that flickers like a neon diode.", "#00f0ff", "🐟"),
    FishSpecies("cyber_minnow", "Cyber Minnow", Rarity.COMMON, 18, 0.3, 1.2, "neon_waterfront", "Fitted with tiny chrome scales and low-voltage electrical sensory nodes.", "#00ff9d", "🐟"),
    FishSpecies("synth_carp", "Synthwave Carp", Rarity.UNCOMMON, 45, 2.0, 7.5, "neon_waterfront", "Vibrant magenta stripes that pulse to 120 BPM synthesizer frequencies.", "#ff007f", "🐠"),
    FishSpecies("holo_guppy", "Holographic Guppy", Rarity.UNCOMMON, 55, 0.5, 2.0, "neon_waterfront", "Projects tiny light projections around itself to confuse predators.", "#ffea00", "🐠"),
    FishSpecies("plasma_bass", "Plasma Bass", Rarity.RARE, 160, 4.0, 14.0, "neon_waterfront", "Conducts mild plasma charges along its dorsal spines. Very feisty.", "#7928ca", "🐡"),
    FishSpecies("district_dragonet", "District 7 Dragonet", Rarity.EPIC, 550, 1.5, 5.0, "neon_waterfront", "Rare nocturnal specimen with fiber-optic whiskers and emerald eyes.", "#ff0055", "🐉"),
    FishSpecies("mecha_catfish", "Cybernetic Catfish", Rarity.LEGENDARY, 1800, 15.0, 45.0, "neon_waterfront", "An old canal titan reinforced with discarded cyber-implants.", "#ffd700", "🦈"),

    # Tier 2 - Bioluminescent Shelf
    FishSpecies("glow_herring", "Prismatic Glow-Herring", Rarity.COMMON, 35, 0.8, 2.5, "biolum_shelf", "Swims in synchronized shimmering schools through glowing coral canopies.", "#00f0ff", "🐟"),
    FishSpecies("laser_trout", "Laser Trout", Rarity.UNCOMMON, 95, 3.0, 9.0, "biolum_shelf", "Shoots brief flashes of focused laser light to stun plankton.", "#00ff9d", "🐠"),
    FishSpecies("aurora_angelfish", "Aurora Angelfish", Rarity.RARE, 280, 2.0, 6.0, "biolum_shelf", "Its translucent fins display shifting northern-light spectrums.", "#00b4d8", "🐠"),
    FishSpecies("electric_ray", "Ampere Manta Ray", Rarity.EPIC, 850, 25.0, 80.0, "biolum_shelf", "Glides majestically while discharging beautiful lightning arcs into the sand.", "#7928ca", "🪼"),
    FishSpecies("titan_lanternfish", "Titan Lanternfish", Rarity.LEGENDARY, 2900, 12.0, 35.0, "biolum_shelf", "A deep-shelf predator whose lure burns bright enough to illuminate shipwrecks.", "#ff7700", "🐡"),

    # Tier 3 - Mariana Cyber Trench
    FishSpecies("abyssal_viper", "Abyssal Viperfish", Rarity.UNCOMMON, 180, 1.0, 4.0, "abyssal_trench", "Equipped with elongated chrome fangs that lock onto unsuspecting prey.", "#999999", "🐟"),
    FishSpecies("obsidian_coelacanth", "Obsidian Coelacanth", Rarity.RARE, 420, 20.0, 65.0, "abyssal_trench", "Prehistoric armor-plated survivor preserved by extreme abyssal pressure.", "#444466", "🐠"),
    FishSpecies("hadal_squid", "Bioluminescent Colossal Squid", Rarity.EPIC, 1400, 60.0, 220.0, "abyssal_trench", "Enormous tentacled cephalopod with rings of glowing cybernetic suckers.", "#ff007f", "🦑"),
    FishSpecies("leviathan_spawn", "Young Trench Leviathan", Rarity.LEGENDARY, 4800, 150.0, 500.0, "abyssal_trench", "An infant deep-sea deity that shakes sonar radars across three sectors.", "#9d00ff", "🐋"),
    FishSpecies("quantum_kraken", "Quantum Spool Kraken", Rarity.MYTHIC, 15000, 400.0, 1200.0, "abyssal_trench", "Phases through solid sea-trenches by manipulating quantum probability fields.", "#ff0055", "🐙"),

    # Tier 4 - Corrosive Industrial Basin
    FishSpecies("acid_gar", "Acid-Proof Needle-Gar", Rarity.UNCOMMON, 240, 4.0, 15.0, "acid_basin", "Coated in heavy Teflon-alloy scales immune to chemical erosion.", "#70e000", "🐟"),
    FishSpecies("reactor_eel", "Chernobyl Reactor Eel", Rarity.RARE, 620, 8.0, 28.0, "acid_basin", "Feeds on raw nuclear runoff. Glows with intense radioactive emerald light.", "#39ff14", "🐍"),
    FishSpecies("scrap_snapper", "Mechanical Scrap Snapper", Rarity.EPIC, 2100, 30.0, 95.0, "acid_basin", "Its jaw is a hydraulic crusher crafted from discarded starship salvage.", "#ff5400", "🦀"),
    FishSpecies("mutant_hydra", "Polymorphic Hydra-Shark", Rarity.LEGENDARY, 7200, 120.0, 380.0, "acid_basin", "Three snapping heads with laser-sharpened titanium teeth.", "#ff0055", "🦈"),
    FishSpecies("meltdown_whale", "The Core Meltdown Behemoth", Rarity.MYTHIC, 22000, 800.0, 2500.0, "acid_basin", "A mountain of molten machinery and mutated whale blubber.", "#ff0000", "🐳"),

    # Tier 5 - Orbital Zero-G Hydrosphere
    FishSpecies("star_guppy", "Starlight Micro-Guppy", Rarity.RARE, 800, 0.5, 2.0, "orbital_ocean", "Glitters like distant quasars in zero-gravity floating droplets.", "#ffff3f", "✨"),
    FishSpecies("solar_manta", "Solar Flare Sail-Manta", Rarity.EPIC, 3200, 40.0, 130.0, "orbital_ocean", "Harvests solar wind radiation with enormous gold-foil photonic wings.", "#ffd700", "🛸"),
    FishSpecies("tachyon_sailfish", "Tachyon Hyper-Sailfish", Rarity.LEGENDARY, 11000, 70.0, 210.0, "orbital_ocean", "Swims at near relativistic velocities through orbital water tubes.", "#00f0ff", "🐟"),
    FishSpecies("nebula_dragon", "Celestial Nebula Dragon", Rarity.MYTHIC, 35000, 500.0, 1800.0, "orbital_ocean", "Formed from condensed stellar dust and magnetic plasma fields.", "#ff00ea", "🐉"),
    FishSpecies("astral_colossus", "The Astral Whale of Orion", Rarity.COSMIC, 100000, 2500.0, 8000.0, "orbital_ocean", "A legendary cosmic titan that hums deep orbital frequencies.", "#7000ff", "🌌"),

    # Tier 99 - SECRET BIOME (Subspace 0x00) EXCLUSIVES & ANOMALIES
    FishSpecies("err_null_eel", "ERR_404_NULL_EEL", Rarity.GLITCH, 15000, 1.0, 10.0, "subspace_zero", "A literal glitch in the aquatic rendering matrix. Body coordinates shift constantly.", "#00ffea", "👾", is_anomaly=True),
    FishSpecies("matrix_anomaly_ray", "Quantum Matrix Ray", Rarity.COSMIC, 45000, 80.0, 300.0, "subspace_zero", "Swims in 4 spatial dimensions. Furls through the timeline.", "#ff007f", "🪼", is_anomaly=True),
    FishSpecies("tachyon_chimera", "Tachyon Singularity Chimera", Rarity.COSMIC, 75000, 200.0, 700.0, "subspace_zero", "Existing in the past and future simultaneously. Reeling it requires temporal anchor.", "#ffd700", "🪐", is_anomaly=True),
    FishSpecies("aethelgard_echo", "Echo of the Glitch Sovereign", Rarity.GLITCH, 150000, 1000.0, 4500.0, "subspace_zero", "A majestic avatar of Aethelgard that radiates infinite energy.", "#ff00ea", "🐉", is_anomaly=True),
]

# Quick lookups
FISH_BY_ID: Dict[str, FishSpecies] = {f.id: f for f in FISH_SPECIES}
RODS_BY_ID: Dict[str, Rod] = RODS
BAITS_BY_ID: Dict[str, Bait] = BAITS
PETS_BY_ID: Dict[str, Pet] = PETS
BIOMES_BY_ID: Dict[str, Biome] = BIOMES

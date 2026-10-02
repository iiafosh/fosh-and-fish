"""
Game Engine and Mechanics for Virtual Fisher 2099.
Handles fishing physics, RNG loot tables, secrets, and pet synergies.
"""

import time
import random
import uuid
from typing import Dict, Any, List, Optional, Tuple

from core.models import (
    FISH_SPECIES, FISH_BY_ID, RODS, BAITS, PETS, BIOMES, Rarity,
    FishSpecies, CaughtFish, Rod, Bait, Pet, Biome
)
from core.game_state import PlayerState
from ai.jev_engine import JevDecisionEngine


class GameEngine:
    def __init__(self, jev_engine: Optional[JevDecisionEngine] = None):
        self.jev = jev_engine or JevDecisionEngine()

    def get_available_biomes(self, player: PlayerState) -> List[Dict[str, Any]]:
        result = []
        for b_id, b in BIOMES.items():
            unlocked = b_id in player.unlocked_biomes
            result.append({
                "id": b.id,
                "name": b.name,
                "tier": b.tier,
                "required_level": b.required_level,
                "travel_cost": b.travel_cost,
                "description": b.description,
                "theme_color": b.theme_color,
                "is_secret": b.is_secret,
                "unlocked": unlocked,
                "current": player.current_biome == b_id,
            })
        return result

    def travel_to_biome(self, player: PlayerState, biome_id: str) -> Dict[str, Any]:
        if biome_id not in BIOMES:
            return {"success": False, "message": "Unknown destination sector."}

        biome = BIOMES[biome_id]
        
        # Check if secret biome
        if biome.is_secret and biome_id not in player.unlocked_biomes:
            return {
                "success": False,
                "message": "🔒 Dimensional lock engaged. Coordinate cipher or Quantum Keycard required.",
            }

        # Check level
        if player.level < biome.required_level:
            return {
                "success": False,
                "message": f"Requires Level {biome.required_level} clearance.",
            }

        # Check credits
        if player.credits < biome.travel_cost:
            return {
                "success": False,
                "message": f"Insufficient credits. Warp transit costs {biome.travel_cost} 💵.",
            }

        if biome.travel_cost > 0:
            player.credits -= biome.travel_cost

        player.current_biome = biome_id
        player.save()
        return {
            "success": True,
            "message": f"🚀 Arrived at {biome.name}!",
            "biome": biome_id,
            "theme_color": biome.theme_color,
        }

    def cast_line(self, player: PlayerState) -> Dict[str, Any]:
        """Initiates cast, validates bait, and prepares the bite."""
        rod = RODS.get(player.equipped_rod, RODS["rod_starter"])
        bait_id = player.equipped_bait
        
        # Check and consume bait if available
        has_bait = False
        if bait_id in player.inventory_baits and player.inventory_baits[bait_id] > 0:
            player.inventory_baits[bait_id] -= 1
            has_bait = True
        else:
            player.equipped_bait = "bait_basic"
            has_bait = False

        # Calculate bite delay
        pet = PETS.get(player.equipped_pet) if player.equipped_pet else None
        pet_speed = pet.catch_speed_boost if pet else 0.0
        
        # Base wait 2.0 to 4.5 seconds, reduced by rod and pet
        speed_factor = 1.0 + (rod.reel_speed_boost * 0.4) + pet_speed
        bite_time = max(0.8, round(random.uniform(2.2, 4.0) / speed_factor, 2))

        player.stats["total_casts"] += 1
        player.save()

        return {
            "success": True,
            "bite_time": bite_time,
            "rod_name": rod.name,
            "rod_glow": rod.glow_color,
            "bait_used": bait_id if has_bait else "bare_hook",
            "message": f"Cast line with {rod.name}! Bobber floating on the neon waves...",
        }

    def resolve_catch(self, player: PlayerState) -> Dict[str, Any]:
        """Resolves the catch when fish bites, applying luck, species pools, and pet bonuses."""
        biome_id = player.current_biome
        biome = BIOMES.get(biome_id, BIOMES["neon_waterfront"])
        rod = RODS.get(player.equipped_rod, RODS["rod_starter"])
        bait = BAITS.get(player.equipped_bait, BAITS["bait_basic"])
        pet = PETS.get(player.equipped_pet) if player.equipped_pet else None

        # Filter species pool
        pool: List[FishSpecies] = [
            f for f in FISH_SPECIES
            if f.biome == biome_id or (f.biome == "all" and not f.is_anomaly)
        ]
        
        # If empty (safety fallback), use district 7 pool
        if not pool:
            pool = [f for f in FISH_SPECIES if f.biome == "neon_waterfront"]

        # Calculate luck score
        pet_luck = pet.rare_luck_bonus if pet else 0.0
        total_luck = (rod.luck_multiplier * (1.0 + bait.luck_bonus) * (1.0 + pet_luck))

        # Weight distribution based on rarity
        rarity_weights = {
            Rarity.COMMON: max(5, int(100 / total_luck)),
            Rarity.UNCOMMON: max(10, int(60 / (total_luck ** 0.8))),
            Rarity.RARE: int(30 * (total_luck ** 0.9)),
            Rarity.EPIC: int(15 * (total_luck ** 1.1)),
            Rarity.LEGENDARY: int(6 * (total_luck ** 1.3)),
            Rarity.MYTHIC: int(2 * (total_luck ** 1.6)),
            Rarity.COSMIC: int(1 * (total_luck ** 1.9)),
            Rarity.GLITCH: int(1 * (total_luck ** 2.1)) if biome.is_secret else 0,
        }

        # Calculate selection weights
        species_weights = []
        for sp in pool:
            base_w = rarity_weights.get(sp.rarity, 10)
            if sp.is_anomaly and not biome.is_secret:
                base_w = int(base_w * 0.1)
            species_weights.append(max(1, base_w))

        chosen_species: FishSpecies = random.choices(pool, weights=species_weights, k=1)[0]

        # Generate fish weight
        weight_boost = bait.rare_weight_multiplier
        min_w = chosen_species.min_weight
        max_w = chosen_species.max_weight * weight_boost
        weight = round(random.uniform(min_w, max_w), 2)

        # Calculate value & XP
        avg_w = (chosen_species.min_weight + chosen_species.max_weight) / 2.0
        weight_ratio = max(0.5, weight / max(0.1, avg_w))
        base_val = int(chosen_species.base_value * weight_ratio)
        
        # Anomaly multiplier
        if chosen_species.is_anomaly or chosen_species.rarity in [Rarity.COSMIC, Rarity.GLITCH]:
            base_val = int(base_val * 1.5)

        xp_gain = max(10, int(base_val * 0.35 + weight * 2))

        # Check for special secret item drops!
        dropped_items = []
        
        # 1. Glitch Core drop (Abyssal Trench 10%, Subspace 40%)
        if biome_id == "subspace_zero" and random.random() < 0.40:
            player.special_items["glitch_core"] = player.special_items.get("glitch_core", 0) + 1
            dropped_items.append({"id": "glitch_core", "name": "Glitch Core", "icon": "👾"})
        elif biome_id == "abyssal_trench" and random.random() < 0.10:
            player.special_items["glitch_core"] = player.special_items.get("glitch_core", 0) + 1
            dropped_items.append({"id": "glitch_core", "name": "Glitch Core", "icon": "👾"})

        # 2. Singularity Pearl drop (on Mythic / Cosmic catches)
        if chosen_species.rarity in [Rarity.MYTHIC, Rarity.COSMIC, Rarity.GLITCH] and random.random() < 0.50:
            player.special_items["singularity_pearl"] = player.special_items.get("singularity_pearl", 0) + 1
            dropped_items.append({"id": "singularity_pearl", "name": "Singularity Pearl", "icon": "🔮"})

        # 3. Chrono Fragment drop
        if total_luck > 3.0 and random.random() < 0.15:
            player.special_items["chrono_fragment"] = player.special_items.get("chrono_fragment", 0) + 1
            dropped_items.append({"id": "chrono_fragment", "name": "Chrono Fragment", "icon": "⏳"})

        # Record fish
        fish_data = {
            "id": str(uuid.uuid4())[:8],
            "species_id": chosen_species.id,
            "name": chosen_species.name,
            "rarity": chosen_species.rarity.value,
            "weight": weight,
            "value": base_val,
            "caught_at": time.time(),
            "biome": biome_id,
            "color": chosen_species.color,
            "emoji": chosen_species.emoji,
            "is_anomaly": chosen_species.is_anomaly,
        }
        player.record_catch(fish_data)
        leveled_up = player.add_xp(xp_gain)

        # Check Pet Double Catch (Holo Otter / Sovereign)
        double_caught = False
        second_fish_data = None
        if pet and pet.double_catch_chance > 0 and random.random() < pet.double_catch_chance:
            double_caught = True
            bonus_species = random.choice(pool)
            bw = round(random.uniform(bonus_species.min_weight, bonus_species.max_weight), 2)
            bval = int(bonus_species.base_value * (bw / max(0.1, (bonus_species.min_weight + bonus_species.max_weight) / 2.0)))
            second_fish_data = {
                "id": str(uuid.uuid4())[:8],
                "species_id": bonus_species.id,
                "name": bonus_species.name,
                "rarity": bonus_species.rarity.value,
                "weight": bw,
                "value": bval,
                "caught_at": time.time(),
                "biome": biome_id,
                "color": bonus_species.color,
                "emoji": bonus_species.emoji,
                "is_anomaly": bonus_species.is_anomaly,
            }
            player.record_catch(second_fish_data)

        # Consult Jev Decision Engine for fight telemetry
        jev_combat = self.jev.evaluate_fish_combat({
            "tension": random.uniform(35.0, 75.0),
            "fish_rarity": chosen_species.rarity.value,
            "fish_weight": weight,
            "rod_tier": rod.tier,
            "biome": biome_id,
        })

        player.save()

        return {
            "success": True,
            "fish": fish_data,
            "second_fish": second_fish_data,
            "double_caught": double_caught,
            "xp_gain": xp_gain,
            "leveled_up": leveled_up,
            "new_level": player.level,
            "dropped_items": dropped_items,
            "jev_telemetry": jev_combat,
        }

    def perform_genesis_ritual(self, player: PlayerState) -> Dict[str, Any]:
        """
        The 4-stage Genesis Ritual to awaken Aethelgard, The Glitch Sovereign (Overpowered Pet).
        Requirements:
        - 1x Glitch Core
        - 1x Void Cipher Key (decoded from Jev Oracle)
        - 3x Singularity Pearl
        """
        cores = player.special_items.get("glitch_core", 0)
        ciphers = player.special_items.get("void_cipher_key", 0)
        pearls = player.special_items.get("singularity_pearl", 0)

        if "pet_sovereign" in player.unlocked_pets:
            return {
                "success": False,
                "message": "🐉 Aethelgard, The Glitch Sovereign has already awakened and serves you.",
            }

        if cores < 1 or ciphers < 1 or pearls < 3:
            return {
                "success": False,
                "message": (
                    f"Ritual incomplete! You require:\n"
                    f"- 1x Glitch Core ({cores}/1)\n"
                    f"- 1x Void Cipher Key ({ciphers}/1) [Ask Jev Oracle for 'GENESIS']\n"
                    f"- 3x Singularity Pearls ({pearls}/3) [Catch Mythic/Cosmic fish]"
                ),
                "requirements": {
                    "glitch_core": {"current": cores, "needed": 1},
                    "void_cipher_key": {"current": ciphers, "needed": 1},
                    "singularity_pearl": {"current": pearls, "needed": 3},
                },
            }

        # Consume materials
        player.special_items["glitch_core"] -= 1
        player.special_items["void_cipher_key"] -= 1
        player.special_items["singularity_pearl"] -= 3

        # Unlock Aethelgard
        player.unlocked_pets.append("pet_sovereign")
        player.equipped_pet = "pet_sovereign"
        player.unlock_secret("aethelgard_awakened")
        player.add_gems(25)
        player.save()

        return {
            "success": True,
            "message": (
                "🌌 [REALITY MATRIX COLLAPSED] The Glitch Sovereign Awakens!\n"
                "Aethelgard descends with celestial neon wings.\n"
                "🔥 Passive Activated: 5.0x Sell Value, 100% Perfect Auto-Reel, 500% Cosmic Luck, +250 Credits & 2 Gems every 8s!"
            ),
            "pet_unlocked": "pet_sovereign",
        }

    def craft_chronos_rod(self, player: PlayerState) -> Dict[str, Any]:
        """Crafts the Chronos Singularity Rod using 3 Chrono Fragments."""
        frags = player.special_items.get("chrono_fragment", 0)
        if "rod_chronos" in player.inventory_rods:
            return {"success": False, "message": "Chronos Rod is already in your arsenal."}

        if frags < 3:
            return {
                "success": False,
                "message": f"Requires 3x Chrono Fragments ({frags}/3). Fish in high luck conditions or ask the Oracle.",
            }

        player.special_items["chrono_fragment"] -= 3
        player.inventory_rods.append("rod_chronos")
        player.equipped_rod = "rod_chronos"
        player.unlock_secret("chronos_rod_crafted")
        player.save()

        return {
            "success": True,
            "message": "⏳ The Chronos Singularity Rod has been synthesized! Spacetime bending rod equipped.",
            "rod_id": "rod_chronos",
        }

    def collect_pet_tick(self, player: PlayerState) -> Dict[str, Any]:
        """Collects periodic passive income from active pet."""
        if not player.equipped_pet or player.equipped_pet not in PETS:
            return {"awarded": False}

        pet = PETS[player.equipped_pet]
        credits = pet.passive_income_credits
        gems = pet.passive_income_gems

        if credits > 0 or gems > 0:
            player.credits += credits
            player.gems += gems
            player.save()
            return {
                "awarded": True,
                "pet_name": pet.name,
                "credits": credits,
                "gems": gems,
            }
        return {"awarded": False}

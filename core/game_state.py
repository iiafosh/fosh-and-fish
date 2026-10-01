"""
Player State and Persistence for Virtual Fisher 2099.
"""

import json
import os
import time
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, field, asdict

from core.models import (
    CaughtFish, RODS, BAITS, PETS, BIOMES, FISH_SPECIES, FISH_BY_ID,
    Rarity
)

SAVE_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "savegame.json")


class PlayerState:
    def __init__(self):
        self.name: str = "CyberAngler_01"
        self.credits: int = 250
        self.gems: int = 10
        self.level: int = 1
        self.xp: int = 0
        self.current_biome: str = "neon_waterfront"
        self.equipped_rod: str = "rod_starter"
        self.equipped_bait: str = "bait_basic"
        self.equipped_pet: Optional[str] = "pet_axolotl"
        
        # Inventories
        self.inventory_rods: List[str] = ["rod_starter"]
        self.inventory_baits: Dict[str, int] = {
            "bait_basic": 30,
            "bait_neon": 5,
        }
        self.unlocked_pets: List[str] = ["pet_axolotl"]
        self.unlocked_biomes: List[str] = ["neon_waterfront"]
        self.unlocked_secrets: List[str] = []
        
        # Secret Quest & Ritual Materials
        self.special_items: Dict[str, int] = {
            "glitch_core": 0,
            "singularity_pearl": 0,
            "void_cipher_key": 0,
            "chrono_fragment": 0,
        }
        
        # Recent catches & records
        self.inventory_fish: List[Dict[str, Any]] = []
        self.fish_catalog_counts: Dict[str, int] = {}
        
        # Lifetime statistics
        self.stats: Dict[str, Any] = {
            "total_casts": 0,
            "total_catches": 0,
            "total_credits_earned": 0,
            "biggest_catch_weight": 0.0,
            "biggest_catch_name": "None",
            "anomalies_encountered": 0,
            "secrets_unlocked": 0,
        }

    @property
    def xp_for_next_level(self) -> int:
        return int(100 * (1.35 ** (self.level - 1)))

    def add_xp(self, amount: int) -> bool:
        """Adds XP and returns True if leveled up."""
        self.xp += amount
        leveled_up = False
        while self.xp >= self.xp_for_next_level:
            self.xp -= self.xp_for_next_level
            self.level += 1
            self.gems += 3  # Level-up gem reward
            leveled_up = True
            self._check_biome_unlocks()
        return leveled_up

    def _check_biome_unlocks(self):
        for b_id, b in BIOMES.items():
            if not b.is_secret and self.level >= b.required_level and b_id not in self.unlocked_biomes:
                self.unlocked_biomes.append(b_id)

    def add_credits(self, amount: int):
        self.credits += amount
        self.stats["total_credits_earned"] += amount

    def add_gems(self, amount: int):
        self.gems += amount

    def record_catch(self, fish: Dict[str, Any]):
        self.inventory_fish.append(fish)
        sp_id = fish["species_id"]
        self.fish_catalog_counts[sp_id] = self.fish_catalog_counts.get(sp_id, 0) + 1
        self.stats["total_catches"] += 1
        
        if fish["weight"] > self.stats["biggest_catch_weight"]:
            self.stats["biggest_catch_weight"] = fish["weight"]
            self.stats["biggest_catch_name"] = fish["name"]
        
        if fish.get("is_anomaly", False):
            self.stats["anomalies_encountered"] += 1

    def sell_all_fish(self) -> Dict[str, Any]:
        """Sells all caught fish with pet multipliers."""
        if not self.inventory_fish:
            return {"count": 0, "total_value": 0}
        
        # Calculate pet sell multiplier
        multiplier = 1.0
        if self.equipped_pet and self.equipped_pet in PETS:
            multiplier = PETS[self.equipped_pet].sell_multiplier

        base_sum = sum(f["value"] for f in self.inventory_fish)
        final_sum = int(base_sum * multiplier)
        count = len(self.inventory_fish)
        
        self.add_credits(final_sum)
        self.inventory_fish.clear()
        self.save()

        return {
            "count": count,
            "base_value": base_sum,
            "final_value": final_sum,
            "multiplier": multiplier,
        }

    def unlock_secret(self, secret_key: str) -> bool:
        if secret_key not in self.unlocked_secrets:
            self.unlocked_secrets.append(secret_key)
            self.stats["secrets_unlocked"] += 1
            self.save()
            return True
        return False

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "credits": self.credits,
            "gems": self.gems,
            "level": self.level,
            "xp": self.xp,
            "xp_next": self.xp_for_next_level,
            "current_biome": self.current_biome,
            "equipped_rod": self.equipped_rod,
            "equipped_bait": self.equipped_bait,
            "equipped_pet": self.equipped_pet,
            "inventory_rods": self.inventory_rods,
            "inventory_baits": self.inventory_baits,
            "unlocked_pets": self.unlocked_pets,
            "unlocked_biomes": self.unlocked_biomes,
            "unlocked_secrets": self.unlocked_secrets,
            "special_items": self.special_items,
            "inventory_fish": self.inventory_fish,
            "fish_catalog_counts": self.fish_catalog_counts,
            "stats": self.stats,
        }

    def save(self):
        os.makedirs(os.path.dirname(SAVE_FILE), exist_ok=True)
        try:
            with open(SAVE_FILE, "w", encoding="utf-8") as f:
                json.dump(self.to_dict(), f, indent=2)
        except Exception as e:
            print(f"[PlayerState] Error saving game: {e}")

    @classmethod
    def load(cls) -> "PlayerState":
        state = cls()
        if os.path.exists(SAVE_FILE):
            try:
                with open(SAVE_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                state.name = data.get("name", state.name)
                state.credits = data.get("credits", state.credits)
                state.gems = data.get("gems", state.gems)
                state.level = data.get("level", state.level)
                state.xp = data.get("xp", state.xp)
                state.current_biome = data.get("current_biome", state.current_biome)
                state.equipped_rod = data.get("equipped_rod", state.equipped_rod)
                state.equipped_bait = data.get("equipped_bait", state.equipped_bait)
                state.equipped_pet = data.get("equipped_pet", state.equipped_pet)
                state.inventory_rods = data.get("inventory_rods", state.inventory_rods)
                state.inventory_baits = data.get("inventory_baits", state.inventory_baits)
                state.unlocked_pets = data.get("unlocked_pets", state.unlocked_pets)
                state.unlocked_biomes = data.get("unlocked_biomes", state.unlocked_biomes)
                state.unlocked_secrets = data.get("unlocked_secrets", state.unlocked_secrets)
                state.special_items = data.get("special_items", state.special_items)
                state.inventory_fish = data.get("inventory_fish", [])
                state.fish_catalog_counts = data.get("fish_catalog_counts", {})
                state.stats = data.get("stats", state.stats)
            except Exception as e:
                print(f"[PlayerState] Error loading save: {e}. Starting fresh.")
        return state

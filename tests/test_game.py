"""
Unit and integration tests for Virtual Fisher 2099.
"""

import unittest
import os
import shutil

from core.models import RODS, BAITS, PETS, BIOMES, FISH_SPECIES
from core.game_state import PlayerState, SAVE_FILE
from core.game_engine import GameEngine
from ai.jev_engine import JevDecisionEngine


class TestVirtualFisher(unittest.TestCase):
    def setUp(self):
        self.player = PlayerState()
        self.jev = JevDecisionEngine()
        self.engine = GameEngine(jev_engine=self.jev)

    def test_player_leveling(self):
        initial_lvl = self.player.level
        initial_gems = self.player.gems
        xp_needed = self.player.xp_for_next_level
        leveled = self.player.add_xp(xp_needed + 10)
        self.assertTrue(leveled)
        self.assertEqual(self.player.level, initial_lvl + 1)
        self.assertEqual(self.player.gems, initial_gems + 3)

    def test_cast_and_catch(self):
        cast_res = self.engine.cast_line(self.player)
        self.assertTrue(cast_res["success"])
        self.assertGreater(cast_res["bite_time"], 0.0)

        catch_res = self.engine.resolve_catch(self.player)
        self.assertTrue(catch_res["success"])
        fish = catch_res["fish"]
        self.assertIn("name", fish)
        self.assertIn("weight", fish)
        self.assertGreater(fish["value"], 0)
        self.assertEqual(len(self.player.inventory_fish), 1)

    def test_sell_all_with_pet_multiplier(self):
        self.engine.cast_line(self.player)
        self.engine.resolve_catch(self.player)
        self.assertGreater(len(self.player.inventory_fish), 0)

        # Equip Mecha Penguin (1.35x multiplier)
        self.player.equipped_pet = "pet_penguin"
        res = self.player.sell_all_fish()
        self.assertGreater(res["count"], 0)
        self.assertEqual(res["multiplier"], 1.35)
        self.assertEqual(len(self.player.inventory_fish), 0)

    def test_jev_system_one_decisions(self):
        combat = self.jev.evaluate_fish_combat({
            "tension": 65.0,
            "fish_rarity": "Legendary",
            "rod_tier": 3,
            "biome": "abyssal_trench",
        })
        self.assertIn("fish_action", combat)
        self.assertIn("threat_level", combat)
        self.assertIn(combat["threat_level"], ["calm", "moderate", "severe", "critical"])

        # Test Jev Angler decision
        angler = self.jev.evaluate_ai_angler_step({"tension": 90.0, "max_tension": 100.0})
        self.assertEqual(angler["decision"], "RELEASE_LINE")

    def test_oracle_secrets_unlock(self):
        # 1. Secret Rod via Oracle
        res_rod = self.jev.consult_oracle("TEMPORAL_HOOK", self.player.to_dict())
        self.assertEqual(res_rod["unlock"], "rod_chronos")

        # 2. Secret Biome via Oracle
        res_biome = self.jev.consult_oracle("404-0X00-VOID", self.player.to_dict())
        self.assertEqual(res_biome["unlock"], "subspace_zero")

        # 3. Genesis Cipher via Oracle
        res_genesis = self.jev.consult_oracle("GENESIS", self.player.to_dict())
        self.assertEqual(res_genesis["unlock"], "void_cipher_key")

    def test_overpowered_pet_genesis_ritual(self):
        # Test ritual fails if lacking ingredients
        self.player.special_items["glitch_core"] = 0
        fail_res = self.engine.perform_genesis_ritual(self.player)
        self.assertFalse(fail_res["success"])

        # Supply ingredients
        self.player.special_items["glitch_core"] = 1
        self.player.special_items["void_cipher_key"] = 1
        self.player.special_items["singularity_pearl"] = 3

        success_res = self.engine.perform_genesis_ritual(self.player)
        self.assertTrue(success_res["success"])
        self.assertIn("pet_sovereign", self.player.unlocked_pets)
        self.assertEqual(self.player.equipped_pet, "pet_sovereign")

        # Check OP Pet stats
        op_pet = PETS["pet_sovereign"]
        self.assertEqual(op_pet.sell_multiplier, 5.0)
        self.assertEqual(op_pet.instant_catch_chance, 1.0)
        self.assertTrue(op_pet.is_overpowered)


if __name__ == "__main__":
    unittest.main()

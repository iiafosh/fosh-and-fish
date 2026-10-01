"""
Discord-style CLI Interface for Virtual Fisher 2099.
Emulates the classic bot feel while leveraging the Jev AI Decision Engine!
"""

import time
import sys

# Ensure UTF-8 output on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from core.models import RODS, BAITS, PETS, BIOMES, FISH_BY_ID
from core.game_state import PlayerState
from core.game_engine import GameEngine
from ai.jev_engine import JevDecisionEngine


def print_banner():
    print(r"""
  ██╗   ██╗██╗██████╗ ████████╗██╗   ██╗ █████╗ ██╗     ███████╗██╗███████╗██╗  ██╗
  ██║   ██║██║██╔══██╗╚══██╔══╝██║   ██║██╔══██╗██║     ██╔════╝██║██╔════╝██║  ██║
  ██║   ██║██║██████╔╝   ██║   ██║   ██║███████║██║     █████╗  ██║███████╗███████║
  ╚██╗ ██╔╝██║██╔══██╗   ██║   ██║   ██║██╔══██║██║     ██╔══╝  ██║╚════██║██╔══██║
   ╚████╔╝ ██║██║  ██║   ██║   ╚██████╔╝██║  ██║███████╗██║     ██║███████║██║  ██║
    ╚═══╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝
                2 0 9 9   •   P O W E R E D   B Y   J E V   A P I
    """)


def run_cli():
    print_banner()
    jev = JevDecisionEngine()
    engine = GameEngine(jev_engine=jev)
    player = PlayerState.load()

    print(f"Logged in as: {player.name} | Level {player.level} | 💵 {player.credits:,} | 💎 {player.gems}")
    print(f"Current Biome: {BIOMES[player.current_biome].name}")
    print(f"Equipped Rod: {RODS[player.equipped_rod].name} | Bait: {BAITS[player.equipped_bait].name}")
    if player.equipped_pet:
        print(f"Active Pet: {PETS[player.equipped_pet].name} ({PETS[player.equipped_pet].title})")
    print(f"Type 'help' for commands or 'fish' to cast your line.\n")

    while True:
        try:
            line = input(f"[{player.name} @ {BIOMES[player.current_biome].name}] > ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nExiting Virtual Fisher CLI. State saved.")
            player.save()
            break

        if not line:
            continue

        parts = line.split()
        cmd = parts[0].lower()
        args = parts[1:]

        if cmd in ["exit", "quit", "q"]:
            player.save()
            print("👋 Until next time, Angler!")
            break

        elif cmd in ["help", "h"]:
            print("""
Available Commands:
  fish / f            Cast your line into the water!
  sell / s [all]      Sell caught fish for credits (boosted by pet multipliers)
  profile / p         View your level, stats, and records
  inventory / inv     Inspect your caught fish and quest relics
  shop / store        Browse rods and baits for purchase
  buy rod <id>        Purchase and equip a rod
  buy bait <id> [qty] Purchase bait in bulk
  equip <rod|pet> <id>Equip an owned rod or companion pet
  biomes / b          List accessible fishing zones
  travel <biome_id>   Warp to another fishing zone
  oracle <query>      Ask Jev Cyber Oracle / test secret codes & riddles!
  genesis             Perform the Genesis Ritual to awaken Aethelgard (OP Pet)
  craft chronos       Forge the Chronos Singularity Rod from fragments
  auto                Run 5 automated casts using Jev AI Angler
            """)

        elif cmd in ["fish", "f"]:
            cast_res = engine.cast_line(player)
            bite_time = cast_res["bite_time"]
            print(f"🎣 {cast_res['message']}")
            print(f"⏳ Waiting for bite...", end="", flush=True)
            for _ in range(int(bite_time * 2)):
                time.sleep(0.3)
                print(".", end="", flush=True)
            print(" 💥 BITE DETECTED!")
            
            catch_res = engine.resolve_catch(player)
            f = catch_res["fish"]
            print(f"\n🎉 You caught a {f['rarity']} {f['name']} {f['emoji']}!")
            print(f"   Weight: {f['weight']} kg | Market Value: 💵 {f['value']:,} | +{catch_res['xp_gain']} XP")
            
            if catch_res.get("double_caught"):
                sf = catch_res["second_fish"]
                print(f"✨ [DOUBLE HOOK!] Your pet also pulled up a {sf['rarity']} {sf['name']} {sf['emoji']} ({sf['weight']} kg)!")

            if catch_res["leveled_up"]:
                print(f"\n🆙 LEVEL UP! You reached Level {player.level}! Earned +3 💎 Gems.")

            for drop in catch_res.get("dropped_items", []):
                print(f"🌟 [RARE DROP] Found {drop['name']} {drop['icon']}!")

            jev_telemetry = catch_res.get("jev_telemetry", {})
            print(f"🧠 [Jev System One]: Maneuver '{jev_telemetry.get('fish_action')}' | Threat: {jev_telemetry.get('threat_level')}")

        elif cmd in ["sell", "s"]:
            res = player.sell_all_fish()
            if res["count"] == 0:
                print("Your fish cooler is empty. Cast a line first!")
            else:
                print(f"💰 Sold {res['count']} fish for 💵 {res['final_value']:,} credits! (Multiplier: {res['multiplier']}x)")

        elif cmd in ["inv", "inventory"]:
            print(f"\n--- FISH COOLER ({len(player.inventory_fish)} catches) ---")
            if not player.inventory_fish:
                print("  No fish in cooler.")
            else:
                for f in player.inventory_fish[-10:]:
                    print(f"  - {f['emoji']} {f['rarity']} {f['name']} ({f['weight']} kg) - 💵 {f['value']:,}")
                if len(player.inventory_fish) > 10:
                    print(f"  ... and {len(player.inventory_fish) - 10} more fish.")

            print(f"\n--- SPECIAL RELICS & QUEST ITEMS ---")
            for item, qty in player.special_items.items():
                print(f"  - {item}: {qty}")

        elif cmd in ["profile", "p"]:
            print(f"\n=== ANGLER DOSSIER: {player.name} ===")
            print(f"Level: {player.level} (XP: {player.xp}/{player.xp_for_next_level})")
            print(f"Credits: 💵 {player.credits:,} | Gems: 💎 {player.gems}")
            print(f"Total Casts: {player.stats['total_casts']} | Catches: {player.stats['total_catches']}")
            print(f"Biggest Trophy: {player.stats['biggest_catch_name']} ({player.stats['biggest_catch_weight']} kg)")
            print(f"Secrets Unlocked: {player.stats['secrets_unlocked']}")

        elif cmd in ["biomes", "b"]:
            print("\n=== AVAILABLE SECTOR BIOMES ===")
            biomes = engine.get_available_biomes(player)
            for b in biomes:
                status = "✅ CURRENT" if b["current"] else ("🔓 UNLOCKED" if b["unlocked"] else f"🔒 LVL {b['required_level']}")
                print(f"[{b['id']}] {b['name']} (Tier {b['tier']}) - {status} (Cost: {b['travel_cost']} 💵)")

        elif cmd == "travel":
            if not args:
                print("Usage: travel <biome_id>")
            else:
                res = engine.travel_to_biome(player, args[0])
                print(res["message"])

        elif cmd in ["oracle", "jev"]:
            q = " ".join(args) if args else "help"
            res = jev.consult_oracle(q, player.to_dict())
            print(f"\n🔮 [JEV CYBER ORACLE - {res['mode']}] (Score: {res['resonance_score']}/100):")
            print(f"   {res['message']}")
            if res.get("unlock"):
                print(f"   ✨ UNLOCKED: {res['unlock']}!")
                if res["unlock"] == "rod_chronos" and "rod_chronos" not in player.inventory_rods:
                    player.inventory_rods.append("rod_chronos")
                    player.equipped_rod = "rod_chronos"
                elif res["unlock"] == "rod_dev_glitch" and "rod_dev_glitch" not in player.inventory_rods:
                    player.inventory_rods.append("rod_dev_glitch")
                    player.equipped_rod = "rod_dev_glitch"
                elif res["unlock"] == "subspace_zero" and "subspace_zero" not in player.unlocked_biomes:
                    player.unlocked_biomes.append("subspace_zero")
                elif res["unlock"] == "void_cipher_key":
                    player.special_items["void_cipher_key"] = max(1, player.special_items.get("void_cipher_key", 0) + 1)
                player.save()

        elif cmd == "genesis":
            res = engine.perform_genesis_ritual(player)
            print(res["message"])

        elif cmd == "craft" and args and args[0] == "chronos":
            res = engine.craft_chronos_rod(player)
            print(res["message"])

        elif cmd == "auto":
            print("🤖 Engaging Jev AI Auto-Angler for 5 casts...")
            for i in range(5):
                engine.cast_line(player)
                catch_res = engine.resolve_catch(player)
                f = catch_res["fish"]
                print(f"[{i+1}/5] Caught {f['rarity']} {f['name']} {f['emoji']} ({f['weight']} kg) - 💵 {f['value']:,}")
                time.sleep(0.5)
            print("Auto-session completed.")

        else:
            print(f"Unknown command '{cmd}'. Type 'help' for available commands.")


if __name__ == "__main__":
    run_cli()

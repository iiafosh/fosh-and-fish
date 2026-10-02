"""
Virtual Fisher 2099 Backend Server.
Provides multi-threaded HTTP static file serving and JSON REST API.
"""

import os
import sys
import json
import urllib.parse
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from typing import Dict, Any

# Ensure UTF-8 output on Windows consoles
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from core.models import RODS, BAITS, PETS, BIOMES, FISH_SPECIES
from core.game_state import PlayerState
from core.game_engine import GameEngine
from ai.jev_engine import JevDecisionEngine

STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")


class VirtualFisherHandler(SimpleHTTPRequestHandler):
    player: PlayerState = None
    engine: GameEngine = None
    jev: JevDecisionEngine = None

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=STATIC_DIR, **kwargs)

    @classmethod
    def initialize_game(cls):
        cls.player = PlayerState.load()
        cls.jev = JevDecisionEngine()
        cls.engine = GameEngine(jev_engine=cls.jev)
        print(f"[Server] Game initialized. Player: {cls.player.name}, Level: {cls.player.level}, Credits: {cls.player.credits}")

    def send_json(self, data: Dict[str, Any], status: int = 200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/api/state":
            rod = RODS.get(self.player.equipped_rod)
            bait = BAITS.get(self.player.equipped_bait)
            pet = PETS.get(self.player.equipped_pet) if self.player.equipped_pet else None
            biome = BIOMES.get(self.player.current_biome)

            resp = {
                "player": self.player.to_dict(),
                "equipped": {
                    "rod": rod.__dict__ if rod else None,
                    "bait": bait.__dict__ if bait else None,
                    "pet": pet.__dict__ if pet else None,
                    "biome": biome.__dict__ if biome else None,
                },
                "jev": {
                    "mode": self.jev.mode_name,
                    "history_count": len(self.jev.history),
                },
            }
            self.send_json(resp)
            return

        elif path == "/api/catalog":
            resp = {
                "species": [s.__dict__ for s in FISH_SPECIES],
                "rods": [r.__dict__ for r in RODS.values()],
                "baits": [b.__dict__ for b in BAITS.values()],
                "biomes": [b.__dict__ for b in BIOMES.values()],
                "pets": [p.__dict__ for p in PETS.values()],
            }
            self.send_json(resp)
            return

        elif path == "/api/biomes":
            biomes = self.engine.get_available_biomes(self.player)
            self.send_json({"biomes": biomes})
            return

        # Static files
        super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        
        # Read body
        content_length = int(self.headers.get("Content-Length", 0))
        body_bytes = self.rfile.read(content_length) if content_length > 0 else b"{}"
        try:
            body = json.loads(body_bytes.decode("utf-8")) if body_bytes else {}
        except Exception:
            body = {}

        if path == "/api/cast":
            res = self.engine.cast_line(self.player)
            self.send_json(res)
            return

        elif path == "/api/catch":
            res = self.engine.resolve_catch(self.player)
            self.send_json(res)
            return

        elif path == "/api/sell_all":
            res = self.player.sell_all_fish()
            self.send_json(res)
            return

        elif path == "/api/biomes/travel":
            target_biome = body.get("biome_id", "neon_waterfront")
            res = self.engine.travel_to_biome(self.player, target_biome)
            self.send_json(res)
            return

        elif path == "/api/shop/buy_rod":
            rod_id = body.get("rod_id")
            if rod_id not in RODS:
                self.send_json({"success": False, "message": "Invalid rod ID."}, status=400)
                return
            rod = RODS[rod_id]
            if rod_id in self.player.inventory_rods:
                self.send_json({"success": False, "message": "You already own this rod."})
                return
            if self.player.credits < rod.cost or self.player.gems < rod.gem_cost:
                self.send_json({"success": False, "message": "Insufficient funds."})
                return
            
            self.player.credits -= rod.cost
            self.player.gems -= rod.gem_cost
            self.player.inventory_rods.append(rod_id)
            self.player.equipped_rod = rod_id
            self.player.save()
            self.send_json({"success": True, "message": f"Purchased and equipped {rod.name}!"})
            return

        elif path == "/api/shop/buy_bait":
            bait_id = body.get("bait_id")
            count = int(body.get("count", 10))
            if bait_id not in BAITS:
                self.send_json({"success": False, "message": "Invalid bait ID."}, status=400)
                return
            bait = BAITS[bait_id]
            total_credits = bait.cost * count
            total_gems = bait.gem_cost * count

            if self.player.credits < total_credits or self.player.gems < total_gems:
                self.send_json({"success": False, "message": "Insufficient funds."})
                return

            self.player.credits -= total_credits
            self.player.gems -= total_gems
            self.player.inventory_baits[bait_id] = self.player.inventory_baits.get(bait_id, 0) + count
            self.player.equipped_bait = bait_id
            self.player.save()
            self.send_json({"success": True, "message": f"Purchased {count}x {bait.name}!"})
            return

        elif path == "/api/equip":
            item_type = body.get("type")
            item_id = body.get("id")

            if item_type == "rod" and item_id in self.player.inventory_rods:
                self.player.equipped_rod = item_id
            elif item_type == "bait" and item_id in BAITS:
                self.player.equipped_bait = item_id
            elif item_type == "pet" and (item_id in self.player.unlocked_pets or item_id is None):
                self.player.equipped_pet = item_id
            else:
                self.send_json({"success": False, "message": "Unable to equip item."}, status=400)
                return

            self.player.save()
            self.send_json({"success": True, "message": f"Equipped {item_type} successfully."})
            return

        elif path == "/api/oracle":
            query = body.get("query", "")
            res = self.jev.consult_oracle(query, self.player.to_dict())
            
            # Apply unlocks if granted by Oracle
            unlock = res.get("unlock")
            if unlock == "rod_chronos":
                if "rod_chronos" not in self.player.inventory_rods:
                    self.player.inventory_rods.append("rod_chronos")
                    self.player.equipped_rod = "rod_chronos"
                    self.player.unlock_secret("chronos_rod_oracle")
            elif unlock == "rod_dev_glitch":
                if "rod_dev_glitch" not in self.player.inventory_rods:
                    self.player.inventory_rods.append("rod_dev_glitch")
                    self.player.equipped_rod = "rod_dev_glitch"
                    self.player.unlock_secret("dev_glitch_rod")
            elif unlock == "subspace_zero":
                if "subspace_zero" not in self.player.unlocked_biomes:
                    self.player.unlocked_biomes.append("subspace_zero")
                    self.player.unlock_secret("subspace_zero_unlocked")
            elif unlock == "void_cipher_key":
                self.player.special_items["void_cipher_key"] = max(1, self.player.special_items.get("void_cipher_key", 0) + 1)
                self.player.unlock_secret("void_cipher_obtained")

            self.player.save()
            self.send_json(res)
            return

        elif path == "/api/secrets/genesis":
            res = self.engine.perform_genesis_ritual(self.player)
            self.send_json(res)
            return

        elif path == "/api/secrets/craft_chronos":
            res = self.engine.craft_chronos_rod(self.player)
            self.send_json(res)
            return

        elif path == "/api/pets/tick":
            res = self.engine.collect_pet_tick(self.player)
            self.send_json(res)
            return

        elif path == "/api/ai/angler_step":
            res = self.jev.evaluate_ai_angler_step(body)
            self.send_json(res)
            return

        else:
            self.send_json({"error": "Endpoint not found"}, status=404)


def run_server(host: str = "0.0.0.0", port: int = 8080):
    VirtualFisherHandler.initialize_game()
    server = ThreadingHTTPServer((host, port), VirtualFisherHandler)
    print(f"==================================================")
    print(f"🎣 Virtual Fisher 2099 Server Running!")
    print(f"🌐 Web UI: http://localhost:{port}")
    print(f"⚡ Jev System One Engine: ACTIVE")
    print(f"==================================================")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server gracefully...")
        server.server_close()


if __name__ == "__main__":
    run_server()

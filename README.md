# 🐟 Virtual Fisher (Godot 4 + Blender)

**Made by afosh** — [LinkedIn](https://www.linkedin.com/in/mostafa-kamal-3731453a9/) · [GitHub](https://github.com/iiafosh)


A desktop fishing game built on the real **Virtual Fisher** Discord bot mechanics, with all art
rendered procedurally in **Blender**: high-angle biome scenes with see-through water (one shared
height function drives the terrain mesh and the water's depth colour/foam), a straw-hat fisherman
on each of the 17 boats, and fish that swim under the surface in-game with caustics on top.
Free third-party assets (Quaternius, Kenney, OpenGameArt, Poly by Google, Fredoka) are listed with
their licenses in [CREDITS.md](CREDITS.md); fetch the raw packs with `python tools/fetch_assets.py`.

## Play the 0.1 beta

- Download from [Releases](https://github.com/iiafosh/vfish.fosh/releases): **Windows** `…-windows.zip` (run `VirtualFisher.exe`), **Linux** `…-linux.tar.gz` (run `./VirtualFisher.x86_64`), **Android** `…-android.apk` (install on the phone).
- **Browser / phone:** upload `VirtualFisher-0.1-beta-web.zip` to itch.io (HTML game) or serve `build/web/`.
- **How to play:** [GUIDE.md](GUIDE.md) or press **G** in-game.  **Feedback:** Guide → Feedback in-game, or [open an issue](https://github.com/iiafosh/vfish.fosh/issues/new/choose).
- What's in it: [CHANGELOG.md](CHANGELOG.md)

## Play from source

```bash
launch_game.bat
```
or `Godot.exe --path .` (Godot 4.7). Controls: **Space/F** or tap/click the water to fish, **S** sell, **1-9** menus, **Esc** close panel. Click the merchant on the island to shop.

## Platforms

| Platform | How |
|---|---|
| **Desktop (Windows)** | `Godot_console.exe --headless --path . --export-release "Windows Desktop" build/windows/VirtualFisher.exe` |
| **Web** | `Godot_console.exe --headless --path . --export-release "Web" build/web/index.html`, then `python tools/serve_web.py` (or upload `build/web/` to itch.io / GitHub Pages) |
| **Mobile** | Open the web build on your phone (same Wi-Fi: the URL printed by `serve_web.py`) and use *Add to Home Screen* — it installs as a full-screen landscape app (PWA). Tap the water to cast. |

Saves are kept per device (desktop: `%APPDATA%/Godot/app_userdata/Virtual Fisher`, web/mobile: browser storage).

## What's in the game

Everything follows the Virtual Fisher Encyclopaedia, the miraheze wiki (snapshot in `wiki_dump/`)
and the Prestige 0 Guide:

- **Fishing formula** from the wiki: rod range × fish catch, +1 fish per boat, bait fish,
  × biome catch rate (River 100% → Abyss 1%), fish/treasure boosts, duplicator.
- **Fish quality**: per-rod, per-biome species odds from the wiki tables, shifted by Fish Quality
  (`E_n = min(Q_n·fq, 1 − higher tiers)`).
- **20 fish, 21 rods, 17 boats, 8 baits, 7 biomes** with exact prices, levels and cooldowns.
- **Chests** (Common → Artifact, Super) with the encyclopedia drop tables; **Gold / Emerald /
  Lava / Diamond** fish unlock at levels 10 / 10 / 50 / 100.
- **8 charms** (tier n costs n charms; 440 at P0, `10 + P` tiers later).
- **5 pets** (1/10,000 per cast, never buyable) with the wiki buff formulas and pet XP table.
- **Shop upgrades (9), Special (10), League (6), Boosts & Workers**, daily reward, daily quests,
  league quest and weekly hooks.
- **Prestige**: P0 needs Level 250, $5B and 440/440 charms; grants an Azure Fish for the
  Prestige Shop (cap `1 + P/5`). The community P1–P160 buy-order chart is built in (Prestige → Guide).
- Real **XP-per-level table** (25,000 levels) in `data/vf/levels.txt`.

Values the sources don't state (per-level upgrade prices, chest base weights, prestige
requirements after P0) are marked `DERIVED` in `scripts/vf/vf_data.gd`.

## Code map

| Path | What |
|---|---|
| `scripts/vf/vf_data.gd` | All game data + sources |
| `scripts/vf/vf_game.gd` | Simulation (autoload `VF`): casting, chests, pets, prestige, save |
| `scripts/vf/vf_main.gd` | UI: stage, catch card, dock, panels |
| `scripts/vf/vf_stage.gd` | Top-down stage: scene, swimming fish, boat, line, bobber, ripples |
| `shaders/vf_caustics.gdshader` | Caustics masked to the water (uses `scenes/*_mask.png`) |
| `tools/blender/` | Art pipeline: procedural models, top-down scenes (`vf_topdown.py`), vendor models (`vf_vendor.py`), animated sheets (`vf_critters.py`) |
| `assets/third_party/` | Kenney UI/particles, CC0 sounds, Fredoka font (see CREDITS.md) |
| `assets/vf/` | Rendered sprites, `scenes/` + masks, `boats_top/`, `fish_top/`, and `manifest.json` anchors |
| `tests/vf_sim_test.gd` | Headless mechanics & balance checks |
| `legacy/` | Previous Godot prototype (ignored by Godot via `.gdignore`) |

## Re-render the art

```bash
D:/Blender/blender-4.2.3-windows-x64/blender.exe -b --factory-startup --python tools/blender/render_assets.py
```
Pass categories (`fish exotics pets rods boats baits chests charms ui scenes boats_top fish_top critters fisher`) and/or
`--only "Name,Other"` to render a subset.

## Tests & screenshots

```bash
Godot_console.exe --headless --path . -s res://tests/vf_sim_test.gd
Godot_console.exe --path . -- --capture=OUT_DIR --demo=Ocean
```
`--capture` plays a few casts, screenshots the main screen and panels, then quits without saving.

---

# Legacy web prototype

# 🐟 Virtual Fisher 2099 (`vfish.fosh`)

[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/)
[![Three.js 3D](https://img.shields.io/badge/3D%20Engine-Three.js-00f0ff.svg)](https://threejs.org/)
[![Jev AI](https://img.shields.io/badge/AI%20Engine-TypeSafe%20Jev%20API-9d00ff.svg)](https://typesafe.ai)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A futuristic 2D/3D Cyberpunk Fishing RPG inspired by the legendary Discord bot **Virtual Fisher**, supercharged with real-time 3D graphics, procedural audio synthesis, secret dimensions, easter eggs, overpowered pets, and **TypeSafe AI's Jev API System One decision engine**.

---

## 🌟 Key Highlights & Features

### 1. 🎮 2D / 3D Futuristic Visuals & Sound
- **Three.js WebGL 3D World**: Procedural dynamic ocean surface with animated sine waves, specular reflections, neon skyline city backdrop, and day/night fog.
- **Dynamic Physics Rod & Bobber**: The fishing rod flexes realistically according to line tension. The floating neon bobber dips and splashes particle rings upon fish bites.
- **Cyber Companions**: Equipped pets hover and swim beside your cyber catamaran, featuring glowing animated models.
- **Web Audio API Cyber Synthesizer**: 100% self-contained sci-fi procedural audio engine (laser line cast whooshes, resonant water splashes, sonar alarms, reel ratchets, synthwave victory chords, and cosmic drone swells).

### 2. 🧠 Jev API Integration (System One Decision Core)
Powered by TypeSafe AI's **Jev API** (`typesafe-sdk`), this game demonstrates high-speed, typed, calibrated decisions:
- **`Choice`**: Real-time fish combat maneuvers (`thrash_furious`, `deep_dive`, `erratic_zigzag`, `exhausted_glide`).
- **`Score`**: Continuous reel tension risk rubric (`calm`, `moderate`, `severe`, `critical`) and riddle relevance scores.
- **`Noul`**: Space-time anomaly trigger probabilities and secret phrase evaluation.
- **Autonomous Jev AI Angler**: Chill one-click auto-fishing mode where Jev manages reel tension and pulls automatically with microsecond timing.
- **Jev Cyber Oracle Terminal**: In-game interactive console allowing players to query Jev telemetry, ask riddles, and discover hidden override ciphers.
- *Zero-Dependency Fallback*: Includes an embedded local high-precision Jev emulator that conforms to the exact same typed schema—so the game runs out of the box with or without an active `TYPESAFE_API_KEY`!

### 3. 🐾 Pets & The Overpowered Secret Companion
- **Standard Pets**:
  - `Axo-9` (Cyber Axolotl): +25% bite speed, +15% XP.
  - `Ping-0` (Mecha Penguin): +35% fish sell value, deep-sea salvage income.
  - `Otto-Flux` (Holo Otter): 30% chance for **Double Hook** (catch 2 fish simultaneously!).
  - `Jelly-Pulse` (Tachyon Jelly): 40% time dilation on tension bar, +50% rare luck.
- **🔥 The Overpowered Pet — `Aethelgard, The Glitch Sovereign`**:
  - Visual: A colossal celestial neon dragon/leviathan that orbits the player's boat in the 3D scene, leaving cosmic particle trails.
  - **Godlike Perks**:
    - **5.0x Sell Multiplier** on all catches.
    - **100% Instant Auto-Reel** (bypasses reel resistance).
    - **500% (5x) Cosmic Luck** boost.
    - **Passively harvests 250 Credits + 2 Gems every 8 seconds!**

### 4. 🔮 Easter Eggs & Secret Unlocks
| Secret | Name | How to Unlock |
|---|---|---|
| **Secret Rod 1** | *The Chronos Singularity Rod* | Enter `TEMPORAL_HOOK` in the Jev Oracle, or forge using 3x Chrono Fragments |
| **Secret Rod 2** | *0xDEADBEEF Dev Glitch Rod* | Enter `0xDEADBEEF` in the Jev Oracle (or enter Konami Code) |
| **Secret Biome** | *Subspace 0x00: The Chrono-Singularity* | Enter `404-0x00-VOID` in the Jev Oracle to unlock in Warp Nav |
| **OP Pet** | *Aethelgard, The Glitch Sovereign* | Complete the 4-stage **Genesis Ritual** at the Pet Altar |

#### 📜 The 4-Stage Genesis Ritual:
1. **Glitch Core**: Found in Mariana Cyber Trench (10% drop) or Subspace 0x00 (40% drop).
2. **Void Cipher Key**: Decode by querying the Jev Oracle with `"GENESIS"`.
3. **3x Singularity Pearls**: Harvested from Mythic, Cosmic, or Glitch fish.
4. **The Sovereign Altar**: Synthesize in the Pet Sanctuary -> Altar to awaken Aethelgard!

---

## 🚀 Quick Start

### Installation

Clone the repository and install requirements:
```bash
git clone https://github.com/iiafosh/vfish.fosh.git
cd vfish.fosh
pip install -r requirements.txt
```

*(Optional)* Configure your TypeSafe Jev API Key:
```bash
# Windows PowerShell
$env:TYPESAFE_API_KEY="your-api-key-here"

# Linux / macOS
export TYPESAFE_API_KEY="your-api-key-here"
```

### Launch the 2D/3D Web Game
```bash
python main.py
```
This automatically starts the server and opens `http://localhost:8080` in your default browser!

### Launch the Discord-Style Terminal CLI
For the nostalgic text bot experience:
```bash
python main.py --cli
```
Commands: `fish`, `sell all`, `shop`, `buy rod <id>`, `oracle <query>`, `genesis`, `auto`, etc.

---

## 🧪 Running Unit Tests

Run the complete test suite verifying mechanics, Jev System One logic, and secrets:
```bash
python -m unittest discover tests
```

---

## 🏗️ Architecture

```
vfish.fosh/
├── ai/
│   ├── __init__.py
│   └── jev_engine.py         # TypeSafe Jev API System One engine & local fallback
├── core/
│   ├── __init__.py
│   ├── models.py             # Fish, Rods, Baits, Pets, Biomes data models
│   ├── game_state.py         # Player economy, leveling, inventory & persistence
│   └── game_engine.py        # Fishing physics, loot generation, Genesis ritual
├── static/
│   ├── index.html            # Futuristic glassmorphic HUD & viewport
│   ├── css/
│   │   └── game.css          # Cyberpunk synthwave styling & animations
│   └── js/
│       ├── audio.js          # Web Audio API procedural cyber synthesizer
│       ├── three_view.js     # Three.js 3D water, flex rod, bobber, Aethelgard model
│       └── game.js           # Game controller, auto-angler, API bridge
├── tests/
│   └── test_game.py          # Unit & integration tests
├── cli.py                    # Terminal Discord-style Virtual Fisher CLI
├── server.py                 # Multi-threaded HTTP & REST API server
├── main.py                   # Game launcher
└── requirements.txt
```

---

## 📄 License
MIT License. Created for the cyber angling community.

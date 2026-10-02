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

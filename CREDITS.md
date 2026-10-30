# Credits & third-party assets

**Made by afosh** — [LinkedIn](https://www.linkedin.com/in/mostafa-kmal-3731453a9/) · [GitHub](https://github.com/iiafosh)


Everything not listed here (game code, procedural Blender art, shaders) is original to this project.
Raw source packs are fetched with `python tools/fetch_assets.py` into `scratch/downloads/` (git-ignored);
only the files the game uses are copied into `assets/third_party/` or baked into renders under `assets/vf/`.
The puppet fisher of the marketing videos (`tools/blender/vf_fisher.py`) is original, built and animated from primitives.

| Asset | Author | License | Used for |
|---|---|---|---|
| [Animated Fish](https://poly.pizza/bundle/Animated-Fish-Bundle-ZkGbjS8m8g) (fish ×3, dolphin, shark, whale, manta ray) | [Quaternius](https://quaternius.com/packs/animatedfish.html) | CC0 | Swimming fish sprite sheets (`assets/vf/swim/`); the Leviathan boss (`assets/vf/event/leviathan.png`) |
| [Adventurers](https://kaylousberg.itch.io/kaykit-adventurers) | [Kay Lousberg (KayKit)](https://www.kaylousberg.com) | CC0 | The captain (the Ranger, as a fisherman: `assets/vf/fisher/`) and the shopkeeper (the Rogue: `assets/vf/merchant/`) |
| [Character Animations](https://kaylousberg.itch.io/kaykit-character-animations) | Kay Lousberg (KayKit) | CC0 | How they move: fishing, sitting, cheering, waving... |
| [Forest Nature Pack](https://kaylousberg.itch.io/kaykit-forest) | Kay Lousberg (KayKit) | CC0 | Trees, bushes, grass and rocks in the scenes (recoloured per biome) |
| [Fantasy Town Kit](https://kenney.nl/assets/fantasy-town-kit) | Kenney | CC0 | The fish shop: walls, roof, stall, lanterns, deck (recoloured per biome; `tools/blender/vf_shop.py`) |
| [Chest](https://poly.pizza/m/O72u4Drp8k) | Quaternius | CC0 | Sunken chests in the Ocean / Abyss scenes |
| [Flying gull](https://poly.pizza/m/eMNhHDZakYp) | Poly by Google | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | Seagulls (`assets/vf/critters/gull.png`) |
| [Crab](https://poly.pizza/m/2DgM36qZW2u) | Poly by Google | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | Beach crabs (`assets/vf/critters/crab.png`) |
| [Nature Kit](https://kenney.nl/assets/nature-kit) | Kenney | CC0 | Palms, flowers, stumps, lily pads in scenes |
| [Watercraft Kit](https://kenney.nl/assets/watercraft-kit) | Kenney | CC0 | Buoys, the moored rowboat, and the Rowboat, Fishing Boat, Speedboat, Pontoon, Sailboat, Yacht, Cruiser and Cruise Ship hulls |
| [Pirate Kit](https://kenney.nl/assets/pirate-kit) | Kenney | CC0 | Gold Boat (galleon), Sky Cruiser hull, Dark Explorer (ghost ship), barrels and crates at the shop |
| [Cruise Ship](https://poly.pizza/m/yq9EKmEmfC), [Spaceship](https://poly.pizza/m/uCeLfsdmNP) | Quaternius | CC0 | Luxury Yacht, space cruiser parts |
| [Cruise ship](https://poly.pizza/m/dgLCxDWhnZQ), [Blimp](https://poly.pizza/m/cGHU2Pu0Ytf), [Satellite](https://poly.pizza/m/1C3zb8Q9USk), [Flying saucer](https://poly.pizza/m/6hu2h8v78mO), [Submarine](https://poly.pizza/m/8PgPdFGg3MO) | Poly by Google | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | Boat parts: Sky Cruiser balloon, Satellite, Alien Raft, Alien Submarine, Abyssal Surveyor (recolored, cel-shaded) |
| [Space Shuttle Orbiter](https://poly.pizza/m/bIAMfx1bHVY) | Zoe XR | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | Space Shuttle boat |
| [Particle Pack](https://kenney.nl/assets/particle-pack) | Kenney | CC0 | Splash, sparkle, ember and confetti particles |
| [UI Pack – Adventure](https://kenney.nl/assets/ui-pack-adventure) | Kenney | CC0 | Parchment panels, buttons, banner |
| [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | CC0 | UI clicks and confirmations |
| [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 | Thuds and hits in the KABOOM trailer (`tools/video/music_boom.py`); in game, the coin clinks when you sell, the shiny-fish bell and a fish landing on deck (`assets/third_party/sfx/impact*`) |
| [Fish Pack](https://kenney.nl/assets/fish-pack) | Kenney | CC0 (`assets/third_party/kenney_fish/License.txt`) | "Reel it in!" mini-game: cartoon fish, bubbles, seaweed, rock (`assets/third_party/kenney_fish/`) |
| [Emotes Pack](https://kenney.nl/assets/emotes-pack) | Kenney | CC0 (`assets/third_party/kenney_emotes/License.txt`) | "Reel it in!" mini-game: the fish's reaction bubbles (HAHA, anger, dizzy...) |
| [40 CC0 water / splash / slime SFX](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) | rubberduck (OpenGameArt) | CC0 | Splashes and bubbles |
| [Fredoka](https://fonts.google.com/specimen/Fredoka) | Milena Brandão, Hafontia | SIL OFL 1.1 (`assets/third_party/fonts/OFL.txt`) | UI font |
| [Cairo](https://fonts.google.com/specimen/Cairo) | The Cairo Project Authors (Mohamed Gaber) | SIL OFL 1.1 (`assets/third_party/fonts/Cairo-OFL.txt`) | Arabic letters (fallback font) |
| [Phosphor Icons](https://phosphoricons.com) | Phosphor Icons (Helena Zhang, Tobias Fried) | MIT (`assets/third_party/phosphor/LICENSE`) | interface icons |

## Music

The soundtrack is by **[Scott Buckley](https://www.scottbuckley.com.au)**, from his free library, under
[CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/). The game also credits him on the Radio, on every "now playing"
note and in the Guide. The tracks are only converted (`tools/video/make_music.py`: a smaller file, one loudness).

- [Echoes Of Home](https://www.scottbuckley.com.au/library/echoes-of-home/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Home Was You](https://www.scottbuckley.com.au/library/home-was-you/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Glow](https://www.scottbuckley.com.au/library/glow/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Amberlight](https://www.scottbuckley.com.au/library/amberlight/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Simplicity](https://www.scottbuckley.com.au/library/simplicity/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Felicity](https://www.scottbuckley.com.au/library/felicity/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Castles in the Sky](https://www.scottbuckley.com.au/library/castles-in-the-sky/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Cirrus](https://www.scottbuckley.com.au/library/cirrus/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Beyond These Walls](https://www.scottbuckley.com.au/library/beyond-these-walls/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Path Through The Mountains](https://www.scottbuckley.com.au/library/path-through-the-mountains/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Aurora](https://www.scottbuckley.com.au/library/aurora/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Borealis](https://www.scottbuckley.com.au/library/borealis/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Solace](https://www.scottbuckley.com.au/library/solace/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Hymn to the Dawn](https://www.scottbuckley.com.au/library/hymn-to-the-dawn/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Meanwhile](https://www.scottbuckley.com.au/library/meanwhile/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Reverie](https://www.scottbuckley.com.au/library/reverie/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [Moonlight](https://www.scottbuckley.com.au/library/moonlight/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au
- [The Long Way Home](https://www.scottbuckley.com.au/library/the-long-way-home/) by Scott Buckley, released under CC-BY 4.0. www.scottbuckley.com.au

Using one of these in a YouTube video: put the credit in the video's description, or it gets an automatic copyright claim
(his [guide](https://www.scottbuckley.com.au/library/copyright-claims-release/) has how to clear one). They can't be released
on their own or on streaming services, only with other media, like this game.

## Game data

Game mechanics data: Virtual Fisher Encyclopaedia (@defilantema), virtualfisher.miraheze.org wiki,
Virtual Fisher Prestige 0 Guide (infernal._. and contributors).

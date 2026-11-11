# The missing list: who builds what

**Status (11 November 2026):** everything below shipped in 1.0, except the seven outlaws ("The Most Wanted" in part 3), which are built on `next` and not released. None of it has been tested on a real phone, so nobody has felt the vibration yet. One decision is still the owner's: whether to ease the mini-game for clumsy players.

The owner, 2026-11-01: "work on the list you listed we are missing in game and i loved the prev enter screen can we do smth similar to it".

This is the contract between the sessions (Design, Game mechanics, UI, Audio, Code). The names here are binding, so art, rules and screens fit together when they're merged. If a name has to change, tell the header session before using another one.

## What players get

- The painted bay is the enter screen again.
- New players meet the funny mini-game straight away, with a clean first minute.
- Phones vibrate when something happens.
- Seven outlaw fish to chase, one per world, from Gerald to the Duchess.
- Things to find when sailing, in every biome.
- Collecting pays off: achievements, a paid-off Fish Book, an aquarium.
- Silly hats for the captain.
- The first rebirth is within reach.

## Rules for all of it

- **Funny and relaxing.** Nothing punishes the player or costs progress. No timers that stress. Losing to Gerald costs nothing.
- **Hats are cosmetic only.** Nothing here adds pay-to-win. Hats and achievements may pay or cost a few Pearls, but no hat is Pearl-only.
- **Saves:** every new field defaults when missing, so current saves and 0.5 saves load. Gerald, finds, achievements, stats and hats survive prestige.
- **Art is real 3D from the game's camera** (Blender 4.2, `tools/blender`). No flat cut-outs. All new art together stays under 3 MB after import; use lossy sheets where they hold up.
- **Calm interface.** Use the `C_*` palette and pills. At most one new thing always on the HUD: the WANTED pill, which fades with the rest (`_calm_a`). Everything else lives in the Menu, the Shop or the Fish Book.
- **Phones first.** Every new screen must work at `--resolution 1560x720 ... --touch --ui-dp=390`.
- **Toys wait** until `VF.tutorial >= 99`.
- **No ambience loops.** The owner hated the water loop.
- **Mechanics stay faithful** to the Virtual Fisher sources, except where this file changes them. Mark anything not from the sources `DERIVED`.
- **Captures must not save:** set `VF.autosave = false`, as the other capture modes do. Several sessions run at once and share the owner's real `user://` folder.

## Who owns which files

A session can make small edits outside its files when a feature needs a hook. Keep those few and small, so merges stay clean.

| Session | Owns |
|---|---|
| Game mechanics | `vf_game.gd`, `vf_data.gd`, `vf_minigame.gd`, `vf_fun.gd`, `vf_sail.gd`, `tests/` |
| UI | `vf_main.gd`, `vf_launcher.gd`, `vf_v1_ui.gd`, `vf_idle_ui.gd`, `vf_guide.gd`, new `vf_collect_ui.gd`, `export_presets.cfg` exclude filters, `tools/art/make_brand.py` for the splash |
| Code | `vf_stage.gd`, new `vf_haptics.gd`, `export_presets.cfg` vibrate permission |
| Design | `tools/blender/`, `assets/vf/` art, `assets/vf/manifest.json` (only Design writes it) |
| Audio | `tools/video/make_sfx.py`, `assets/audio/fun/`, `audio_manager.gd` |

## Order

1. **Now, side by side:** UI does the enter screen and the first minute. Game mechanics does parts 1 and 7, then all the rules for parts 3 to 6. Code does part 2. Design makes all the art. Audio makes all the sounds.
2. **After the header merges the rules and the art:** Code draws parts 3, 4 and 6 on the stage. UI builds the screens for parts 3 to 6.
3. **Last:** the Release session writes the changelog.

## Enter screen (UI)

Restore the previous screen: `git show 9615f67^:scripts/vf/vf_launcher.gd` (the owner's painting `assets/launcher/launcher_bg.jpg`, its masks, water shimmer and glints, swaying leaves, bobber ripples, lantern glow, passing gull, slow camera drift, and the deep-sea side panel with greeting, Play, sign-in and update status).

- Keep the API `vf_main.gd` and `vf_fun.gd` use: `setup`, `play`, `_open_form`, `_typed`, `_submit`, `form`. Compare with the current file so nothing added since gets lost (update states, `--tour`).
- It shows the current logo, `assets/brand/logo.png`. Check that it reads well on the dark panel.
- One small addition from the current screen: now and then a real fish (the `life` sheets) leaps in the turquoise water, with a splash.
- The boot splash comes from the painting too: `ART` in `tools/art/make_brand.py`, then run `splash()`. Set `boot_splash/bg_color` in `project.godot` so it flows into the screen.
- `export_presets.cfg`: stop excluding `assets/launcher/launcher_*`.
- Delete `assets/launcher/title_*`, `title()` in `make_brand.py`, `render_title` and what only it uses in `tools/blender/vf_brand.py`.
- Check it with `--launcher`, on desktop and at phone size.

## 1. The mini-game for new players (Game mechanics, UI)

Today it's off by default and the tutorial never mentions it, so most players never see the gags.

- **Game mechanics:** new games start with `catch_mode = "reel"`. A save with no `catch_mode` field still loads as `"relax"`. Add `VF.reel_rounds` (saved): rounds played. The first three rounds are easier, and the first is close to impossible to lose. `VFData.minigame_params` takes that into account.
- **UI:** a coach line for the first round that says how to play it. After the third round, one friendly card with two choices: "Keep reeling (+200% fish)" and "Just relax". Auto-fish and Relax stay as they are.
- **UI, the first minute:** today it shows two text boxes at once, the "Welcome, Fisher!" card and the coach bubble. Show the coach bubble alone during the tutorial. Fix the bubble's blank line in `COACH_TEXT[0]`. "Made by afosh" moves to the Menu.

## 2. Vibration (Code)

- New `scripts/vf/vf_haptics.gd`: `class_name VFHaptics`, `static func buzz(kind: String)`, built on `Input.vibrate_handheld`.
- Kinds: `tap`, `bite`, `reel`, `win`, `lose`, `rare`, `shiny`, `honk`, `poke`, `gerald`. Short and gentle. `rare`, `shiny` and `gerald` may be a short pattern.
- `permissions/vibrate=true` in the Android and Android Play presets (Godot does nothing without it).
- Saved in `user://settings.cfg`, default on, with a "Vibration" row in Settings shown only on touch devices.
- Call it where those things happen: the bite, the mini-game's ticks and ending, a catch, a shiny, the honk, a poke.
- Under `--capture`, print one `HAPTIC <kind>` line per call instead of vibrating, so captures can prove the calls happen. **Nobody can feel this without a real phone; say so in the report.**

## 3. Gerald (all of them)

> Replaced on 2026-11-03: the outfits and Geraldine below became seven different outlaws. The current plan is "The Most Wanted: seven different fish", at the end of this part.

Gerald is a fish who has decided you're his rival. He turns up, fights you with the mini-game's comedy, gets away, and taunts you from a WANTED poster. Catch him at the end of his run. Then a bottle arrives: "You caught my son. - Geraldine", and his mum starts a harder run for the late game.

**Rules (Game mechanics):**

```gdscript
# vf_data.gd
const GERALD := [
	{"who": "Gerald", "biome": "River", "level": 10, "bounty": 20.0},
	{"who": "Gerald", "biome": "Volcanic", "level": 50, "bounty": 30.0},
	{"who": "Gerald", "biome": "Ocean", "level": 100, "bounty": 45.0},
	{"who": "Gerald", "biome": "Sky", "level": 250, "bounty": 80.0, "final": true},
	{"who": "Geraldine", "biome": "Space", "level": 500, "bounty": 80.0},
	{"who": "Geraldine", "biome": "Alien", "level": 1000, "bounty": 120.0},
	{"who": "Geraldine", "biome": "Abyss", "level": 2500, "bounty": 200.0, "final": true},
]
# vf_game.gd (saved; survives prestige)
var gerald := {"stage": 0, "casts": 0, "tries": 0, "wins": 0, "losses": 0}
func gerald_due() -> bool          # in that stage's biome, level met, enough casts since the last meeting
func gerald_soon() -> bool         # due within about 10 casts: the stage teases him
func gerald_result(won: bool) -> Dictionary   # {"caught": bool, "escaped": bool, "pay": int, "line": String, "stage": int}
func gerald_info() -> Dictionary   # {"who": String, "biome": String, "level": int, "bounty": int, "met": bool, "done": bool}
```

- First meeting comes early, within about 15 minutes of normal play: level 10 and about 80 casts. Later ones come every 60 to 120 casts.
- Win a stage that isn't final: he pays the bounty (`pay_find(bounty)`), gets away with a gag at the last second (the `snip` gag), and moves to the next biome.
- Lose: he laughs, pays a little, comes back sooner and a bit easier each time, so nobody gets stuck.
- Win a final stage: caught. Gerald gives the `crown` hat, Geraldine the `tiara` hat, and a big payout. After Gerald, the bottle note sets up Geraldine.
- He bites in both catch modes, never during auto-fish. `vf_main._do_cast` decides; `resolved` calls `VF.gerald_result(won)` instead of `cast_reel`.
- `vf_minigame.gd`: the rival plays with `tier` 4, adjusted by `tries`, with his own lines and gags. Remove "Gerald" from `NAMES`, so only the rival has that name. Keep the bottle note "IOU: 3 shrimp. Signed, Gerald."

**Art (Design):**
- Mini-game: `assets/vf/mini/gerald.png` and `assets/vf/mini/geraldine.png`, built like the other species (`render_mini`, eyes removed, same `MINI_CELL` and `MINI_FRAMES`), plus `mini.fish.Gerald` and `mini.fish.Geraldine` in the manifest. Gerald: fat, grumpy, big moustache, thick eyebrows. Geraldine: the same family, a pearl necklace, a big bow, an unimpressed look.
- Stage: `assets/vf/life/gerald.png`, same format as `life/whale.png`, a big dark shape that swims past.

**Stage (Code):** when `VF.gerald_soon()`, the big shape passes near the boat, with a line like "Something big just laughed at you."

**Screens (UI):** in `vf_collect_ui.gd`, a WANTED board with one poster per stage (who, biome, bounty, stamped when done). A small HUD pill, "WANTED: Gerald · Volcanic", shown only after the first meeting; tapping it opens the board. Reuse the poster style of `_draw_poster`.

**Sounds (Audio):** `laugh`, `sting`, `fanfare`.

**The Most Wanted: seven different fish** (2026-11-03). This replaces the outfits. The owner asked "why all the bounty are the same fish ?", got Gerald in seven costumes, and said: "SO YOU JUST MADE THE FISH WEAR A HAT AND YOU CALL IT A CHANGE AND ITS EVEN THE SAME NAME". So every stage is a different outlaw fish, with its own name, body, personality, lines and gags. Gerald is only the first and smallest crook.

| Stage | Name | Who they are | `look` |
|---|---|---|---|
| River | Gerald | the grumpy pufferfish with a moustache and a MUM tattoo (the art there now) | `Gerald` |
| Volcanic | Sizzle | a hot-headed catfish, charcoal skin with glowing cracks, whiskers on fire | `sizzle` |
| Ocean | Captain Swordbeard | a swordfish pirate: long sword nose, curly beard, eyepatch, a gold tooth | `swordbeard` |
| Sky (end of run 1) | Baron von Flap | a flying fish with big wing fins, an old aviator cap, goggles and a monocle | `baron` |
| Space | Commander Chomp | a small, very confident shark in a space helmet, with a jetpack | `chomp` |
| Alien | Zlorp | a purple three-eyed alien blobfish with little tentacles | `zlorp` |
| Abyss (end of run 2) | The Duchess | a huge anglerfish lady whose lure is a chandelier, with pearls and lipstick | `duchess` |

- **Rules (Game mechanics):**
  - Each row has `who` (the name players see), `look`, and its own lines (lose, caught, tease) and gags. The internal names `GERALD` and `gerald_*` stay, so the other sessions' hooks keep working.
  - Win a stage and that outlaw is caught: the poster is stamped CAUGHT!, the bounty is paid, and the next one is wanted in the next biome. There's no more snip-and-escape, because each stage is a different fish.
  - Lose: as now. They laugh, leave a tip, and come back a bit easier.
  - Catch the Baron for the crown, renamed "The Baron's Crown", and a bottle note from the Duchess starts run 2. Catch the Duchess for the tiara, "The Duchess's Tiara".
  - Achievements that name Geraldine get fitting new names. Gerald's own stay.
  - Saves keep their place: `gerald.stage` maps straight onto the new rows.
- **Art (Design):**
  - Six new rivals, each a different body, in real 3D from the game's camera: `assets/vf/mini/<look>.png` with `mini.fish.<look>`, built like the other species, and a stage shape `assets/vf/life/<look>.png` in the whale format.
  - Restyle the crown for the Baron (no moustache) and the tiara for the Duchess.
  - Delete the six outfit sheets and plain Geraldine (art and manifest) unless something still uses them.
- **Stage (Code):** the shape that passes is that rival's `life/<look>.png`, falling back to `life/gerald.png`, and the tease lines come from the row.
- **Screens (UI):** each poster shows its own name and caption, the pill reads "WANTED: Sizzle · Volcanic", and the aquarium shows every outlaw you've caught. Fall back to plain Gerald while a picture is missing.

## 4. Finds when sailing (Game mechanics, Design, Code, UI)

Every biome gets three residents to find, and they sit away from the shop, so sailing has a reason. Tapping one from far off says "Too far. Sail closer!". The third of each biome is rarer.

| Biome | Find | Rare |
|---|---|---|
| River | `otter` floating on its back, `frog` on a lily pad | `old_boot` with a tiny fish living in it |
| Volcanic | `capybara` in a hot spring, `lava_crab` | `marshmallow` toasting on a stick |
| Ocean | `turtle` with a barnacle hat, `fake_fin` (a little fish holding a shark fin on a stick) | `treasure` chest on a sandbar |
| Sky | `cloud_sheep`, `kite` with a lost string | `paper_plane` |
| Space | `astro_cat`, `satellite` | `space_duck` in a helmet |
| Alien | `ufo` beaming up a fish, `blob` with three eyes | `glow_shroom` |
| Abyss | `anglerfish`, `tiny_sub` | `sunken_tv`, still on |

- **Rules (Game mechanics):** `VFData.FINDS := {biome: {id: {"name", "line", "rare"}}}`, `var finds := {}` (id to count, saved), `func find_tapped(id: String) -> Dictionary` returning `{"first": bool, "pay": int, "line": String}`. A first find pays about `pay_find(10.0)`; later ones about `pay_find(0.5)` with a cooldown. `vf_fun.gd` decides when one appears: one at a time, undiscovered ones first, gone after about 90 s.
- **Art (Design):** `assets/vf/life/find_<id>.png`, same format as `life.finds` (`FIND_CELL` 112), and `life.finds.<id>` in the manifest.
- **Stage (Code):** `stage.spawn_resident(id)`, placed in open water far from the shop (or on the beach for `frog` and `lava_crab`, if that reads better). A tap emits `poked("find:<id>", at)` when the boat is within about 320 px, and says "Too far. Sail closer!" otherwise.
- **Screens (UI):** a Finds tab in the Fish Book with silhouettes for the ones not found yet, and "3 of 21".
- **Sounds (Audio):** `find_new`, for a first find.

## 5. Collecting pays off (Game mechanics, UI)

- **Achievements:** `VFData.ACHIEVEMENTS := [{"id", "name", "desc", "stat", "goal", "pearls"}]`, about 30, half of them jokes (honk 100 times, get robbed by a gull, lose to Gerald 5 times, 50 ducks). `var stats := {}`, `func stat_add(id: String, n := 1)`, `var ach_claimed := {}`, `func ach_ready() -> Array`, `func ach_claim(id: String) -> int`.
- **Fish Book:** finishing all the fish of a biome gives a permanent +5% money in that biome and a stamp: `func book_bonus(biome: String) -> float`.
- **Aquarium:** a calm screen where the species you've caught swim around (`swim/` and `life.fish` sheets). Tap one for its name, how many you've caught and a line from `FACTS`. Visitors pay: `func aquarium_income() -> float` adds up to +30% to the catch while away, shown on the Welcome back card. Check it with `tests/idle_balance_probe.gd`.
- **Screens (UI):** Achievements and Aquarium in the Menu, with a badge when something can be claimed.
- **Sounds (Audio):** `ach`, for claiming an achievement.

## 6. Hats (Game mechanics, Design, Code, UI)

- **Rules (Game mechanics):** `VFData.HATS := {slug: {"name", "price", ...}}`: `straw` (free, the one he has now), `pirate`, `chef`, `propeller`, `viking`, `traffic_cone`, `top_hat`, `sombrero`, `duck` (25 rubber ducks), `crown` (caught Gerald), `tiara` (caught Geraldine). `var hats_owned := ["straw"]`, `var hat := "straw"`, `func buy_hat(id: String) -> String`, `func wear_hat(id: String) -> void`. Prices scale with progress and hats buy nothing but laughs.
- **Art (Design):** the hat must sit on the captain's head in both views, while fishing (the live `fisher` sheets) and while sailing (`boats_turn`, where he's baked in). He wears the straw hat in those pictures today, so they need re-rendering without a hat, with `straw` as an overlay like the rest. The deliverable for Code:
  - `assets/vf/hats/<slug>.png`, one frame per view angle.
  - `hats` in the manifest: `{"cell": N, "angles": [...], "pivot": [x, y]}`.
  - `fisher.head`: `{anim: [[x, y, rot], ...]}`, one per frame.
  - `boats_top[boat].turn.head`: `[[x, y], ...]`, one per frame.
  - If re-rendering every boat would break the size budget or takes too long, tell the header before starting.
- **Stage (Code):** `_draw_hat()`, using `VF.hat`, the head positions and the boat's current frame, in both views.
- **Screens (UI):** a Hats tab in the Shop with a preview.
- **Sounds (Audio):** `hat_on`, for putting a hat on.

## 7. The first rebirth (Game mechanics)

P0 needs level 250, $5B and every charm maxed, which is far too far for a first goal.

- Change the first rebirth's requirement in `prestige_check` and `vf_data.gd` (mark it `DERIVED`), so normal play gets there in about 4 to 6 hours. Measure with `tools/pace_sim.gd` and `tests/idle_balance_probe.gd`, and report the numbers.
- Later prestiges shouldn't get easier than they are unless the numbers call for it.
- Re-run `tests/idle_balance_probe.gd` while you're there: it wasn't run after the mini-game's +200%.

## Testing

- `tests/vf_sim_test.gd` gets a test for every new rule and still ends with `PASS (0 failures)`.
- New capture flags, each with screenshots and no script errors: `--gerald-test`, `--finds-test`, `--collect-test`, `--hats-test`. Existing ones keep working: `--launcher`, `--onboarding`, `--minigame-test`, `--sail-test`, `--turn-test`, `--fun-test`, `--phone-test`.
- The owner judges by screenshots and video, so every report shows them.

## Not in this list

Marketing (store screenshots, ads and trailers still show the old look), real-phone testing, the Play setup and publishing 1.0.

## Open questions

None block the work. The owner may change any of this once they see it: which hats, how often Gerald shows up, and how early the first rebirth comes.

# Changelog

![fosh&fish](https://raw.githubusercontent.com/iiafosh/fosh-and-fish/master/assets/brand/cover_1280x720.png)

## 0.5.4 — in-game update

Get it in the game: **Menu → Updates → Update now** (the web version updates on reload).

- **A phone-sized interface:** on phones everything was the PC layout shrunk to half size. Text and buttons are now about 1.6× bigger, menus fill the screen as scrollable sheets, small print has a minimum size and the Reel it in! card fits short screens. PCs and tablets look the same as before.
- **Web: cloud save fixed.** Signing in worked, but saving and loading your cloud save failed with "Can't reach the server" (the browser had already unpacked the server's compressed reply and the game tried to unpack it again). The in-game update check on the web had the same bug.
- **Web on phones:** holding the phone upright shows "Turn your phone sideways" instead of a tiny squashed game.
- Phones: the welcome card waits until you've made your first cast, and no longer mentions keyboard keys.

## 0.5.3 — in-game update

- **Reel it in! balanced:** 0.5.2 made it too easy. Now common fish are a fair challenge with the starter rod, rare fish really need a better rod, and even the best rod can lose to the rarest fish. Keyboard & mouse stays a little easier than phones.

## 0.5.2 — in-game update

Get it in the game: **Menu → Updates → Update now**.

- **Reel it in! is much easier**, and better rods help: every rod now has a **reel power** (0–10, shown in the Shop and in the mini-game). More power = a bigger catch zone, a faster reel and less slipping. With the best rods every fish is catchable.
- **Easier on PC and Linux:** with keyboard and mouse the zone is bigger, the fish calmer, the reel faster, you get 2 extra seconds and the zone is easier to control.
- Phones got fairer too (the starter rod now beats common fish most of the time).

## 0.5.1 — in-game update

Get it in the game: **Menu → Updates → Update now** (no new download).

- **Reel it in!** A new way to catch: switch the pill next to the cast button from *Relax* to *Reel it in!*, then keep the cheeky fish in the zone. Win for **+75% fish** and a **0.5 s cooldown**; lose and you still get your normal catch (the fish just blows a raspberry at you).
- **A new fisherman:** a chunky sea dog who sits on his cooler, yawns, sips his mug, dozes off, waves at seagulls, dances for new fish and facepalms when nothing bites.
- The line now reels back to the rod after every catch.

## 0.5 beta — the big update

Play in the browser: https://iiafosh.github.io/fosh-and-fish/ · Downloads: https://github.com/iiafosh/fosh-and-fish/releases/latest

**New**
- **Sailing:** steer your boat (WASD, or drag it) and sail off the map edge into the next biome. Locked biomes tell you the level you need.
- **FishTok:** a phone inside the game (P). A daily *trending fish* sells for +50%, a daily challenge, and your best catches get likes and followers with rewards.
- **Online accounts:** cloud save, play on any device, and a leaderboard (Menu → Account).
- **In-game updates:** from now on, new versions install from Menu → Updates; no new download needed.
- **17 new boats**, from a rowboat to a ghost ship and an alien saucer.

**Better**
- A new minimal look: small pills at the top, a round cast button, a Menu (Esc) and the Fish Book (Tab).
- The line lands **where you tap** (only on water), and you can **hold** to keep fishing.
- **Beginner's Luck:** extra XP early on, so chests and boosts (level 10) arrive in about 6 minutes instead of 15.

**Fixed**
- The game was broken on phones set to Arabic (the map slid off-screen); Arabic text now shows properly.
- A white ring sat on top of the boat.
- The boat no longer squashes paper-thin when it turns around.

## 0.1 beta — first public test

**Made by afosh** — [LinkedIn](https://www.linkedin.com/in/mostafa-kmal-3731453a9/) · [GitHub](https://github.com/iiafosh)

Play in the browser: https://iiafosh.github.io/fosh-and-fish/

**Game**
- Full Virtual Fisher (Discord bot) progression: 20 fish, 21 rods, 17 boats, 8 baits, 7 biomes (River → Abyss),
  the real 25,000-level XP table, per-rod catch odds and fish-quality rules from the wiki.
- Chests (Common → Artifact, Super), Gold / Emerald / Lava / Diamond fish, 8 charms, 5 pets.
- Shop, special and league upgrades; Fish / Treasure boosts and Workers; daily reward, daily quests,
  league quest and weekly Hooks.
- Prestige with Azure Fish and the prestige shop, including the community P1–P160 buy-order chart.

**Look & feel**
- Top-down Blender-rendered biomes with see-through water, shoreline foam and caustics.
- Animated fisher holding your equipped rod; boats change as you upgrade.
- Swimming fish, whales and manta rays, flapping seagulls, beach crabs.
- A Bait & Tackle fish shop on the island — tap it to shop.
- Tap / click anywhere on the water to cast (fixed: the scene used to swallow the click).
- Cozy parchment UI, "Next goal" hint, catch card, keyboard shortcuts, sounds and water ambience.

**Platforms**
- Windows, Linux and Android (APK) builds, plus a web build that works on any phone browser.

**New in this beta**
- In-game **Guide** (press **G**) covering every system.
- In-game **Feedback** form that opens a pre-filled GitHub issue.
- **Settings** (gear button or **O**): music and sound on/off + volume, fullscreen, reset save.
- Game icon, loading screen and cover art.
- Fishing cooldown now starts when you cast, not when the fish lands.
- **Better start:** step-by-step tutorial pointer, 10 starter goals with rewards, "New fish discovered!" banners and a fish collection (x/20), lucky bonus splashes and early treasure before level 10.

**Known limitations**
- Prestige requirements after P0, per-level upgrade prices and chest weights are estimates
  (the sources don't publish them) — balance feedback welcome.
- No cloud saves yet; desktop and web saves are separate.
- Android APK is a test (debug-signed) build; no iOS app yet — iPhone players use the web version.

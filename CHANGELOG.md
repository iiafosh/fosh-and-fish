# Changelog

![fosh&fish](https://raw.githubusercontent.com/iiafosh/fosh-and-fish/master/assets/brand/cover_1280x720.png)

## 0.5.12 — in-game update

- The web version downloads about 5 MB less (store and social cover images aren't packed into the game any more).

## 0.5.11 — in-game update: a new look

- **Rebrand.** fosh&fish has a new logo: chunky white letters, a little leaping fish and a splash, in deep-sea teal and mint. There's a new app icon (a fish leaping out of the waves), a deep-sea loading screen, and new store / social covers. The title screen uses the new logo.
- The web version shows the new icon and loading screen right away. On Windows and Android the in-game logo changes now; the app icon and the first loading screen change with the next full download.

## 0.5.10 — in-game update

- **A new title screen design.** The picture is sharper (upscaled art) and the right side is now a deep-sea panel with a gently moving wave edge, drifting bubbles and fish shadows. It greets you ("Welcome back, afosh!"), puts a big **Play** first, and you can **sign in or create an account right there** (email and password fields open in the panel, no extra window). Updates show as one line, or a highlighted strip with a button when there's something new.

## 0.5.9 — in-game update

- Web: the title screen's update check no longer says "Can't reach the update server" when the game has just started (it now waits a moment, and retries once on its own).

## 0.5.8 — in-game update

- **A title screen.** The game now opens on a hand-painted dock at sunrise, with shimmering water, swaying leaves, bobber ripples, flickering lanterns and the odd passing gull. Everything you need before you play is in one card: **sign in or create an account** (or see that your cloud save is synced), **check and install updates**, then press **Play** (or Enter / Space) to dive in. Settings are one tap away too.

## 0.5.7 — in-game update

- **Phones: menus scroll with your finger.** Drag anywhere on a menu, even on a card or a button, and flick to keep it moving. Before, cards swallowed the drag and only the thin scrollbar worked. A drag never presses the button it started on; a tap still does.
- **Phones: a less giant interface** (about 10% smaller by default), and a new **Settings → Interface size** (Smaller / Normal / Bigger) on every device.
- **Phones: the Account form fills the screen** (the "Your fish, everywhere" column is hidden there), so signing in needs no scrolling.
- If a reset-password email can't be sent, the game now says so instead of "The server is having trouble".

## 0.5.6 — in-game update

- **Web: no more empty boxes.** Symbols like ✓, ✗, ★, arrows and a few emoji aren't in the game's font. Windows and Android quietly filled them in from system fonts, but browsers showed empty squares (in the catch card, goals, quests, prestige, updates and FishTok). They're now icons or plain text everywhere.

## 0.5.5 — in-game update

- **Two devices, one account:** if your phone saved while your PC was also playing, the PC's next cloud save used to replace it silently (coins and fish from the phone were lost). Now the game only replaces the cloud save it last saw; if another device saved in between it checks again and loads it, or asks you which one to keep.
- **No more random sign-outs with two tabs or windows open:** logins are single-use behind the scenes, so the second tab used to get signed out. Tabs and windows now share the newest login.
- A cloud save made by a newer version of the game is never replaced by an older copy; the older copy asks you to update instead.

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

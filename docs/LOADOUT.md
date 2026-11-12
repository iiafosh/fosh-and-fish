# Launching fosh&fish on Loadout (loadout.xyz)

What Loadout is, from its own docs (docs.loadout.xyz, "Launch Guide" and "Getting Started", read 13 November 2026):
a launchpad where a studio publishes a project page and **a Solana token for its game**. "Launching" means
connecting a Solana wallet, configuring the token (name, symbol, supply, allocations, vesting, buyback share),
reviewing the terms, and publishing it on-chain; then trading opens. The game itself isn't uploaded: the page links
to it. Routes: **Instant** (self-service, 85 SOL reserve target) or **Curated** (reviewed, 150 SOL).

**Only the owner can do the launch itself.** Claude doesn't connect wallets, approve transactions, set token terms or
give financial advice (how many tokens, what allocation, what price is the owner's call). Everything else is ready
below, and on the owner's word the game side is released.

## The playable build

- **Play link: https://foshfish.xyz/play** (free, no account needed, desktop and phone browsers).
- Since 1.0.0 + the next release: a loading screen shows at once and the first visit downloads about 33 MB
  (it was about 50). Repeat visits load from the browser's cache.
- Downloads (Windows, Android APK): https://github.com/iiafosh/fosh-and-fish/releases/latest

## Texts to paste (edit freely)

**Game name:** fosh&fish

**One line:** A cozy fishing game: cast, catch and collect across seven worlds, with friends.

**Game description:**
> fosh&fish is a cozy, funny fishing game you can play in any browser. Cast your line, play the Reel it in!
> mini-game against fish with opinions (and fake moustaches), sell your catch and upgrade from a calm river to the
> deepest Abyss through seven worlds. Hunt numbered shiny fish (only 3,000 of each exist), race everyone in the
> weekly 3-minute Fishing Derby, fish with your friends live, chase seven outlaw fish across the biomes, hire a fleet
> that fishes while you're away, and dress your captain in silly hats. Free to play.

**What exists today (live at foshfish.xyz/play, 1.0.0):**
- 7 biomes, 20+ species, rods, baits, 17 boats, charms, pets, prestige with a perk shop
- Reel it in! mini-game with jokes and gags; seven named outlaw fish to catch
- Shiny fish (3,000 numbered per species, handed out by the server), live events every 10 minutes, a boss fish
- The weekly Fishing Derby with a public board and prizes; the leaderboard; accounts with cloud saves
- Idle play: auto-fish, a fleet of crews, offline earnings, daily calendar and spin
- 18-track soundtrack, day and night, a FishTok phone you can scroll while fishing
- In the next release (built, not released yet): fishing with friends live (party codes), other players sailing
  through your bay, share cards, the faster web start

**Planned (not built yet, say so on the page):** Google Play release; beta features in testing (expeditions,
redeem codes, pet eggs; clans and shiny trading after that); more events and biomes. Owner: add dates if you want.

**Studio / team:** _owner to write_ (who you are, solo or team, how the game is made).

**Use of funds:** _owner to write_ (Loadout asks for it; it should match what you will really do).

## Media (all in the repo)

| What | File |
|---|---|
| Token artwork / square icon | `assets/brand/icon_1024.png` |
| Logo (transparent) | `assets/brand/logo.png` |
| Banner | `store/play/feature_1024x500.png`, `site/img/og.jpg` (1280x640) |
| Screenshots (1920x1080) | `store/play/screenshots/*.png` (friends, Derby, shiny, events, boss, Store...) |
| Square / portrait ads | `store/ads/*_1080x1080.jpg`, `*_1080x1350.jpg`, `*_1080x1920.jpg` |
| Trailers | the old ones (`build/boom10`, `build/starfall`) still show the old look: a new one is on the to-do list |

## On launch day (the owner says "let's launch it")

1. Claude: release the waiting update (friends, visitors, share cards, faster web) with `tools/release.py`, and
   deploy the website (new logo and link preview).
2. Owner: run `supabase/schema.sql` once more if it changed since the last run (it has: the fairer Derby check).
3. Owner, on loadout.xyz: connect the wallet, fill the page with the texts and media above, set the token, review,
   publish. Loadout's own rules: describe the game's real state, don't promise prices or returns.
4. Watch Supabase: Realtime (friends) and the API share the free plan's limits (200 live connections at once).

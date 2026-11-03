# fosh&fish 1.0: Google Play store listing

Copy these into Play Console. The art is next to this file (`make_play_kit.py` makes it):
`icon_512.png` (App icon), `feature_1024x500.png` (Feature graphic), `screenshots/*.png` (Phone screenshots,
1920x1080; add the same ones as tablet screenshots too).

## Main store listing

**App name** (30 max): `fosh&fish`

**Short description** (80 max):

> Cast, catch and collect: shiny fish, live events and 7 worlds to fish in.

**Full description** (4000 max):

```
fosh&fish is a cozy fishing game for a quick cast or a long evening. Throw your line, reel in fish, sell your catch and upgrade your way from a calm river to the deepest Abyss.

NEW IN 1.0
★ Shiny fish: rare, sparkling versions of every species. Only 3,000 of each exist in the whole world, and every one is numbered, so your Shiny Cod No. 0042 is yours alone.
★ An event every 10 minutes of play: Golden Hour, Fish Frenzy, Treasure Tide, Meteor Shower, and the Boss Fish: wear down the Leviathan before it swims away!
★ Event fish and Event Stars: catch the Golden Koi, the Frenzy Piranha and more, and trade your stars for the exclusive Starfall Rod.
★ Supporter Packs: optional one-time packs with exclusive rods, Pearls and bonuses that last forever.
★ Free rewards: watch a short ad only when you want to, for double money, a Fish Boost or Pearls.

WHAT YOU'LL DO
• Fish in 7 worlds: the River, Volcanic, Ocean, Sky, Space, Alien and the Abyss
• Fill your Fish Book with 20 species, then hunt their shinies
• Upgrade your rods, boats, baits and charms
• Raise pets that fish with you
• Daily quests, treasure chests, boosts and prestige for the long run
• Tap the water to cast, or relax and let the fish come to you
• One account, every device: your progress comes with you between phone and PC

fosh&fish is free to play. It has optional in-app purchases (Supporter Packs and Pearls) and optional ads that you choose to watch for a reward.

Made with love by afosh.
```

**What's new in this version** (500 max):

```
fosh&fish 1.0 is here! Shiny fish (only 3,000 of each in the world), a live event every 10 minutes of play with event fish and the Leviathan boss, the Event Shop and the Starfall Rod, Supporter Packs and Pearls, free ad rewards, new art and effects, and the whole game is 10% easier.
```

**App category**: Game → Casual (or Simulation). **Tags**: Fishing, Casual, Idle, Collecting, Relaxing.
**Contact email**: `support@foshfish.xyz` (set it up first: docs/PLAY_STORE.md). **Website**: https://foshfish.xyz
**Privacy policy**: https://foshfish.xyz/privacy.html

## In-app products (Monetize → Products → One-time products)

The IDs must be exactly these (they are `VFData.PACK_ORDER` and `VFData.PEARL_PACK_ORDER`). The game gives
packs once and keeps them (acknowledged); Pearl packs are used up so they can be bought again (consumed).

| Product ID | Name | Description | Price (USD) |
|---|---|---|---|
| `pack_starter` | Starter Pack | Supporter Rod, 150 Pearls, +5% money forever, 40 min Fish Boost | 1.49 |
| `pack_fisher` | Fisher Pack | Supporter Rod, Pearl Rod, 600 Pearls, +10% money and +5% XP forever | 4.99 |
| `pack_captain` | Captain Pack | Supporter Rod, 1,500 Pearls, +20% money, +10% XP and +25% workers forever, 2 hours of every boost | 9.99 |
| `pack_legend` | Legend Pack | Supporter Rod, Legend Rod, 3,500 Pearls, +35% money, +15% XP and +25% shiny chance forever, 5 hours of every boost | 19.99 |
| `pearls_100` | 100 Pearls | 100 Pearls for the Pearl Shop | 0.99 |
| `pearls_550` | 550 Pearls | 550 Pearls for the Pearl Shop | 4.99 |
| `pearls_1200` | 1,200 Pearls | 1,200 Pearls for the Pearl Shop | 9.99 |
| `pearls_2600` | 2,600 Pearls | 2,600 Pearls for the Pearl Shop | 19.99 |

Play converts the USD price to local prices; the game shows Play's local price.

## App content answers

**Ads**: Yes, the app contains ads (rewarded ads, only when the player presses *Watch ad*).

**App access**: Some features need an account (cloud save, leaderboard, shiny fish). Make a test account in the
game (Menu → Account → Create account) and give its email and password to Google in *App access*.

**Target audience**: 13-15, 16-17 and 18+. Not under 13 (the ads and purchases aren't set up for children).
Answer "No" to "could the store listing unintentionally appeal to children" only if you agree; a cozy fishing game
may, in which case Google asks for more (see docs/PLAY_STORE.md).

**Content rating** (IARC questionnaire): category *Game*. No violence, blood, sexual content, bad language,
drugs or real gambling. Users can see each other's fisher names (leaderboard, latest shinies) but can't chat.
Digital purchases: **Yes**. Random items that can be bought: **Yes** (the Pearl Shop's Legendary Chest; the game
shows its odds). Expect "In-Game Purchases (Includes Random Items)".

**Data safety** (check against Google's AdMob guide: https://developers.google.com/admob/android/privacy/play-data-disclosure):

- Data is encrypted in transit: **Yes**. Users can ask for their data to be deleted: **Yes** (in game, or email).
- Collected by the game (accounts are optional):

| Data type | Why | Optional? | Shared? |
|---|---|---|---|
| Personal info → Email address | Account management | Yes (only with an account) | No |
| Personal info → User IDs (account ID, fisher name) | Account management, App functionality | Yes | No |
| Financial info → Purchase history | App functionality (give each purchase once) | No (if you buy) | No |
| App activity → Other actions (game save, shiny fish) | App functionality | Yes | No |

- Collected by the Google Mobile Ads SDK (AdMob) in the Google Play version:

| Data type | Why |
|---|---|
| Device or other IDs (advertising ID, app set ID) | Advertising or marketing, Analytics, Fraud prevention |
| Location → Approximate location (from the IP address) | Advertising or marketing, Analytics, Fraud prevention |
| App activity → App interactions (ad views and taps) | Advertising or marketing, Analytics |
| App info and performance → Crash logs, Diagnostics | Analytics, Fraud prevention |

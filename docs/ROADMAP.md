# fosh&fish: where the game stands, and what comes next

Written 13 November 2026, after a full check of the game (every test mode, every panel on PC and phone size, the live
site and the server). The old roadmap (the "why would a gamer quit?" list from 0.5) is done: the mini-game, the
soundtrack, events and shinies, the outlaws and things to find while sailing all shipped in 1.0.

## The short verdict

| Question | Honest answer |
|---|---|
| Is the game good? | Yes. It's finished, deep and good-looking, and it has its own charm (the captain, the outlaws, the music). |
| Is it alive? | Not yet. The server has **6 accounts**, 5 signed in this week, 1 today. Almost nobody knows the game exists. |
| Can it beat other games? | Not the big ones. It can be the best game in one small corner: a free, cozy fishing game in the browser, "Virtual Fisher you can see". |
| What's the real problem? | Not missing features. It's missing **players**, a way to **see what players do**, and a way to **pay**. |

## What's strong

- A full game: 7 worlds, rods, bait, boats, charms, rebirths, pets, quests, an event every 10 minutes, numbered shinies,
  7 outlaws, the weekly Derby, hats, the aquarium, FishTok.
- A look of its own (real 3D art from the game's camera), a funny captain, and a soundtrack the owner loves.
- Plays in the browser, on PC and on Android, with one account and in-game updates.
- Now social: friends' boats live in your bay, other players visiting, share cards.
- Well tested: unit tests, 65 account checks, 42 panels, server-side checks against cheating.

## What's weak

1. **No players.** 6 accounts. With so few, the leaderboard, the Derby board, visitors and "only 3,000 of each shiny"
   all feel empty. Everything social needs a crowd first.
2. **We're blind.** The game counts nothing, so we don't know if new players leave after one minute or one hour.
3. **No income.** Nothing can be bought and no ads run on the web or PC (see the money plan).
4. **It's a lot.** 42 panels. A new player may feel lost after the tutorial. Nobody outside has been watched playing.
5. **Friends is thin.** You see boats, waves and catches, but there's nothing to do *together* yet.
6. **Nothing calls players back** when the game is closed: no notifications, no "your boat is back".
7. **The live web game is still the slow one** (about 50 MB). The faster start is built but not released.

## Will it stay alive?

It costs almost nothing to keep running, so it won't die from bills. It dies if nobody plays. Two things decide that:
getting it in front of people (it has never been launched anywhere), and whether new players come back the next day
(unknown, because nothing is measured). One practical risk: a free Supabase project pauses after about a week with no
activity, so the server needs at least some players, or an upgrade later.

## Can it beat other games?

Big fishing games have teams, budgets and huge audiences; a head-on fight is lost. The way to win is to be different
and easy to start:
- **Free and instant**: one link, no install. Most rivals need a download, a console or a Discord server.
- **Virtual Fisher's players** already love these rules, and have never seen them as a real 3D bay.
- **Cozy and funny**, with collecting (numbered shinies) and friends. That's a niche the big games don't fill.

## The plan, in order

### Step 1: release what's built (owner's word)
The update on `next` is tested and ready: fish with friends, visitors, share cards, the faster web start, the fairer
Derby, the charm rule. Today's bug fixes ride along.

### Step 2: see what players do
A small anonymous counter: started, finished the tutorial, level 10, first rebirth, came back the next day, opened the
Shop. One server table (the owner runs the SQL), no personal data. Every later choice depends on these numbers.

### Step 3: get players (free ways first)
- Web game portals (CrazyGames, itch.io, Newgrounds): they bring the audience.
- A Discord server for the game, then a Discord Activity so Virtual Fisher fans can play without leaving Discord.
- Short clips on TikTok / Shorts / Reels from the trailer and the two ads that are already cut.
- Codes for followers (built on the beta).

### Step 4: reasons to come back
- **Expeditions and pet eggs** (built on the beta): "my boat is back" brings players back the same day.
- A **monthly fish** or small event, so there's always something new. This is cheap to make.
- Notifications on Android (when the Play version goes out).
- A **Derby season**: four weeks, a free reward row and a paid one.

### Step 5: play together
- A **party goal**: "catch 500 fish together" for a chest everyone gets. No server work.
- **Clans** with a weekly clan board, and **shiny trading** (both designed in the beta notes; they need server SQL).

### Step 6: money
The Supporter Packs on the web, portal ads, Google Play, cosmetics other players can see. See the money plan given on
13 November. It only matters once steps 2 to 4 hold players.

### Later
More fish, new sound effects (the owner's ears decide), a smaller web engine, a name filter before the crowd comes,
Steam.

## Bug sweep, 13 November 2026

**Checked:** the unit tests, all 24 test modes, all 42 panels at PC size and two phone sizes, the 65 account checks, the web
build in a browser, the live site and update feed, the server's security report, and a line-by-line read of the newest
code (friends, visitors, share cards).

**Fixed:**
- Friends: someone in your party could flood your screen with wave and catch messages. Now one line every 3 seconds
  per friend.
- Friends: in a copy of the game with no server, Join blamed your code. Now it says the real reason.
- Friends: "Reset save" while in a party left a ghost of your boat in friends' bays for 45 seconds. It says bye first.
- Small phones (16:9): FishTok docked beside the game left too little room, so the Calendar, Pets, Biomes and Spin
  panels slid under it. Now the phone only docks when the game keeps enough room; otherwise it opens full screen.
- The daily Calendar wraps to two rows in a narrow game area, and the Pets note wraps instead of running off.
- `supabase/schema.sql` on the owner's PC had been emptied by accident. Restored from git. The server was never
  affected: the live Derby check is in place.

**Known and open:**
| What | When to fix |
|---|---|
| The live web game is the slow build | Fixed on `next`; needs the release |
| Share on the Android app only saves a file (and may fail on new Android) | Before Google Play |
| Player names aren't filtered for rude words (they show on boats and boards) | Before the crowd comes; needs a server rule |
| Nobody has watched a new player's first five minutes | Step 2 and 3 |
| Never run on an iPhone | When someone has one |
| Old polish notes, not re-checked: the Sailboat looks bulky from above; the captain's seat on the Yacht and Pontoon | With the next art pass |
| Leaked-password check on sign-up | Needs the paid Supabase plan |

# The beta branch (`beta`, not merged into the game)

The owner, 2026-11-12: "start working on it but dont merge it with the game yet make what you think its good for the
game and tell me what you did and show me it on a beta dev version". From the old idea list (expeditions, codes, pet
eggs, clans, shiny trading), the three that need no new server tables are built and playable; the two that do are
designed below.

## Playable in the beta build (Menu -> Beta, scripts/vf/vf_beta.gd)

| Idea | How it works | Why it's good for the game |
|---|---|---|
| **Expeditions** | Send a boat away for 30 min, 2 h or 8 h of real time (it keeps going with the game closed). It comes back with a Rare, Epic or Legendary chest, money, and maybe a pet egg (10 / 30 / 75%). Opens at level 5. | A reason to come back later ("my boat's back!"), a decision before closing the game, and it fits the fleet. |
| **Pet eggs** | From expeditions, or 120 Event Stars. A nest holds 3; each hatches in 20 minutes into one of the five pets (Puffer 30%, Zebrafish 25%, Dolphin 20%, Axolotl 15%, Tuna 10%, shown in the game). A pet you already have becomes pet XP. | Pets are the best buffs, but a cast finds one only 1 in 10,000: eggs are a sure road to them, and something to spend Event Stars on. |
| **Codes** | Type a code; it pays once per save. The examples: LOADOUT (50 Pearls and an egg), FOSHFISH (60 Event Stars), GERALD (money). Only SHA-256 hashes are in the game files. | Gifts for launch posts (Loadout!) and socials: players follow to get them. |

The beta build has its own save folder (`fosh-and-fish-beta`), plays offline (no account, so it can never overwrite a
real cloud save), and calls itself 1.1-beta build 9999 (the in-game updater never replaces it). Its state is in
`user://beta.json`, outside the main save, so merging later needs no save-format change. Test: `--beta-test` (8 checks).

Before merging: move the beta state into the main save (VF to_dict/_apply), give expeditions a slot per fleet crew,
show eggs in the Pets panel and expeditions in Shop -> Fleet instead of a Beta tile, pick the real codes (and later a
server table so codes can expire), and undo the beta-only lines (project.godot custom_user_dir, data/build.json,
the offline line in backend.gd).

## Designed, not built (they need the server: the owner runs the SQL)

**Clans (crews).** A clan has a name, a tag and up to 20 members; the weekly clan score is the sum of its members'
Derby bests, with a clan board next to the Derby board and a small prize for the top clans. Tables: `clans`
(id, name, tag, owner), `clan_members` (clan, user, joined_at); RPCs create / join (by invite code) / leave / kick,
all checking `auth.uid()`; a security-invoker view over a definer function for the public board (the same pattern as
the five public boards). The party code system (vf_party.gd) is the live chat-free part of it already.

**Shiny trading.** Two players swap shinies, both accepting the exact same offer, and the server does the swap in one
transaction: `trade_offers` (from, to, give_species/serial, want_species/serial, expires_at), RPC `accept_trade`
locking both rows, checking both owners still own them, the 3-copies cap and a daily trade limit, then swapping owners
and logging it. Never on the client: a trade the client could fake would let one player empty another's collection.

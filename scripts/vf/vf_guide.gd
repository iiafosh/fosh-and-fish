class_name VFGuide
extends RefCounted
## In-game guide text. Each tab is a list of [title, icon, body]; icon is
## [kind, name] for VFMain.icon_for(). Kept short — GUIDE.md has the long version.

const TABS := {
	"Basics": [
		["Welcome to fosh&fish", ["ui", "inventory"],
		"Cast, catch, sell, upgrade, repeat. Everything you catch goes into your hold (bucket). Sell it for money, spend the money on better rods, bait, boats and upgrades, and travel to new biomes as you level up."],
		["Fishing", ["rod", "Plastic Rod"],
		"Tap the water, press FISH or hit Space. After every cast there is a short cooldown (the green bar on the FISH button). Each cast catches several fish at once — how many depends on your rod, boats, bait and buffs.\n\nReel it in! (the pill beside the FISH button) turns every bite into a little mini-game: hold to lift the net and keep the fish inside it. Win and that cast brings +200% fish. Lose twice in a row and the next round is a little easier; win and it's back to normal. Relax mode just catches, no mini-game."],
		["Selling", ["ui", "money"],
		"Press SELL (or E) to sell your whole hold. Fish are worth more with a higher Sell Price (Salesman, Fish Ovens, Marketing charms…). Tip: sell right before a big purchase."],
		["Sailing", ["boat", "Rowboat"],
		"Press on your boat and drag it (or use WASD / the arrow keys) to sail somewhere else and fish from there. Sail out through the lanes at the screen edges to reach the previous or next biome — later biomes need a higher level. The Map takes you anywhere you've unlocked."],
		["Poke things", ["ui", "inventory"],
		"Everything's alive and it doesn't mind (much). Tap crabs and gulls. Tap your boat to honk (or H). Bottles and rubber ducks float by: tap them for a little money and a note. And if a gull flies off with your fish, tap it before it's gone."],
		["The merchant", ["ui", "shop"],
		"The fish shop on the island is the merchant. Tap it (or the Shop button) to buy rods, bait, boats, boosts, crews for your fleet, upgrades, hats and Pearls: everything you can buy is in the Shop, one tab each."],
		["Next goal", ["ui", "xp"],
		"The bar under your level shows the next rod or boat you're saving for. Tap it to jump straight to that item in the shop."],
	],
	"Gear": [
		["Rods", ["rod", "Lava Rod"],
		"Rods decide how many fish you catch, which fish bite and your treasure chance. Some rods only work in certain biomes — the Buffs panel shows your exact catch odds. The rod you equip is the one your fisher holds."],
		["Bait", ["bait", "Leeches"],
		"Bait is used up one per cast (Bait Efficiency can save it). Worms » Leeches (Lv10) » Magnet (Lv20, treasure) » Wise Bait (Lv30, XP) » Fish (Lv40) » Artifact Magnet (Lv60) » Magic Bait (Lv80) » Support Bait (Lv150, pets)."],
		["Boats", ["boat", "Rowboat"],
		"Every boat gives −0.25s cooldown and +1 fish per cast. They're bought in order, and later boats need higher levels."],
		["Upgrades", ["ui", "stats"],
		"Shop upgrades cost money (Better Fish, Salesman, More Chests…). Special upgrades (Lv50+) cost exotic fish. League upgrades cost Hooks and are never reset."],
	],
	"Progress": [
		["Levels & biomes", ["ui", "biomes"],
		"XP levels you up and every level-up pays money. New biomes unlock at Lv50 Volcanic, Lv100 Ocean, Lv250 Sky, Lv500 Space, Lv1000 Alien and Lv2500 Abyss. Better fish, but fewer per cast and a longer cooldown."],
		["Chests & exotic fish", ["chest", "epic"],
		"From Lv10 casts can find chests (Common » Artifact). They give money, XP, charms and exotic fish: Gold & Emerald (Lv10), Lava (Lv50), Diamond (Lv100). Exotic fish pay for boosts and special upgrades — check your Wallet."],
		["Charms", ["charm", "quality"],
		"Rare, Epic, Legendary and Artifact chests drop charms from Lv20, a few of one kind at a time (the better the chest, the more). Each kind goes up in tiers: tier n takes n charms, up to tier 6 (one more every two prestiges). They make you a lot stronger and start over when you prestige, so fill them first. Menu - Charms shows how close you are."],
		["Pets", ["pet", "Puffer"],
		"Pets can't be bought: every cast has a 1 in 10,000 chance to find one. Equipped pets level up as you fish and give big buffs."],
		["Boosts, workers & quests", ["ui", "boosts"],
		"Boosts (Lv10) cost Gold/Emerald fish: Fish boost, Treasure boost and Workers that fish for you. Daily quests pay money/XP, the league quest pays Hooks, and the Daily reward (Lv10) grows with your streak."],
		["Fishing Derby", ["ui", "star"],
		"Menu - Derby: three minutes of Reel it in! rounds back to back, the same for everyone (your rod and level don't count). Each win scores points, more for rarer fish, a perfect round and a streak of wins. Play as often as you like: your best run of the week goes on the weekly board. When the week ends, the top three get the Derby Cup hat and Event Stars, and everyone who played gets some Stars."],
		["Leaderboard", ["ui", "prestige"],
		"Menu - Leaderboard (or L): the top fishers by prestige and level, and this week's Derby board. You need a free account to be on them."],
		["Fish with friends", ["ui", "quests"],
		"Menu - Friends: make a party and send the code to your friends. In the same biome you see each other's boats sail, live, and you hear about each other's new catches. Wave from the Friends panel. Other players who played lately also sail through your bay now and then: tap one to see who it is."],
		["Share", ["ui", "star"],
		"Caught a shiny, or set a Derby score you're proud of? Press Share for a picture with your name and the game's link. On a phone it opens the share menu; on a computer it's saved in Pictures/fosh&fish and the text is copied."],
	],
	"Prestige": [
		["Prestiging", ["ui", "prestige"],
		"Your first rebirth comes at Level 60 with $5M. You restart from Level 1 but keep pets, Hooks, league upgrades and prestige perks, and earn an Azure Fish. Each rebirth after that asks for a little more and takes a little longer: about 6 hours for the second."],
		["Prestige shop", ["exotic", "azure"],
		"Spend Azure Fish on permanent perks: International Ties, Business Education, Fish Whisperer, Ancient One and Virtual Fisher (P5+). Each perk's cap is 1 + prestige/5. The Guide tab in the Prestige panel shows the community buy order."],
	],
	"Controls": [
		["Desktop", ["ui", "settings"],
		"Click the water — cast right there (hold to keep fishing)\nSpace / F — cast where you aimed last (hold to keep fishing)\nE — sell everything · Tab — Fish Book · P — phone (FishTok sits beside the game, so you keep fishing while you scroll; D, with the pointer on the phone, makes it full screen)\nEsc — menu (or close a panel) · 1–9 — Shop, Map, Fish Book, Charms, Pets, Boosts, Quests, Prestige, Buffs\nL — leaderboard · G — guide · O — settings (music, sound, fullscreen)"],
		["Phone & tablet", ["ui", "settings"],
		"Tap the water to cast exactly there; keep your finger down to keep fishing. The round button bottom-right casts too. The Phone button opens FishTok beside the game: scroll it with one hand and keep fishing with the other (the little icon at the top of the phone makes it full screen). Tap the fish shop to buy. On the web version use your browser's \"Add to Home Screen\" to play full-screen in landscape."],
		["Saving", ["ui", "daily"],
		"The game saves automatically every 20 seconds and when you close it. Desktop and web keep separate saves. Settings (O) has the music/sound switches and Reset save."],
	],
}
const TAB_ORDER := ["Basics", "Gear", "Progress", "Prestige", "Controls", "Credits", "Feedback"]

const AUTHOR := "afosh"
const SOCIALS := [["LinkedIn", "https://www.linkedin.com/in/mostafa-kmal-3731453a9/"],
	["GitHub", "https://github.com/iiafosh"]]
const ASSET_CREDITS := "Captain, shopkeeper, trees & rocks: KayKit by Kay Lousberg (CC0) · Fish: Quaternius (CC0) · Shop, boats, particles, UI & sounds: Kenney (CC0) · Resting gulls & some boat parts: Poly by Google (CC-BY 3.0) · Space Shuttle: Zoe XR (CC-BY 3.0) · Music: Scott Buckley, www.scottbuckley.com.au (CC-BY 4.0) · Sound effects: OpenGameArt (CC0) · Fonts: Fredoka & Cairo (OFL) · Interface icons: Phosphor Icons (MIT) · Game data: Virtual Fisher Encyclopaedia, virtualfisher.miraheze.org wiki and the Prestige 0 Guide. Full list in CREDITS.md."

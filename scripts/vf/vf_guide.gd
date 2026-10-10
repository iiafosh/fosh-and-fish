class_name VFGuide
extends RefCounted
## In-game guide text. Each tab is a list of [title, icon, body]; icon is
## [kind, name] for VFMain.icon_for(). Kept short — GUIDE.md has the long version.

const TABS := {
	"Basics": [
		["Welcome to fosh&fish", ["ui", "inventory"],
		"Cast, catch, sell, upgrade, repeat. Everything you catch goes into your hold (bucket). Sell it for money, spend the money on better rods, bait, boats and upgrades, and travel to new biomes as you level up."],
		["Fishing", ["rod", "Plastic Rod"],
		"Tap the water, press FISH or hit Space. After every cast there is a short cooldown (the green bar on the FISH button). Each cast catches several fish at once — how many depends on your rod, boats, bait and buffs."],
		["Selling", ["ui", "money"],
		"Press SELL (or E) to sell your whole hold. Fish are worth more with a higher Sell Price (Salesman, Fish Ovens, Marketing charms…). Tip: sell right before a big purchase."],
		["Sailing", ["boat", "Rowboat"],
		"Press on your boat and drag it (or use WASD / the arrow keys) to sail somewhere else and fish from there. Sail out through the lanes at the screen edges to reach the previous or next biome — later biomes need a higher level. The Map takes you anywhere you've unlocked."],
		["The merchant", ["ui", "shop"],
		"The fish shop on the island is the merchant. Tap it (or the Shop button) to buy rods, bait, boats and upgrades."],
		["Next goal", ["ui", "xp"],
		"The bar under your level shows the next rod or boat you're saving for. Tap it to jump straight to that item in the shop."],
	],
	"Gear": [
		["Rods", ["rod", "Lava Rod"],
		"Rods decide how many fish you catch, which fish bite and your treasure chance. Some rods only work in certain biomes — the Buffs panel shows your exact catch odds. The rod you equip is the one your fisher holds."],
		["Bait", ["bait", "Leeches"],
		"Bait is used up one per cast (Bait Efficiency can save it). Worms → Leeches (Lv10) → Magnet (Lv20, treasure) → Wise Bait (Lv30, XP) → Fish (Lv40) → Artifact Magnet (Lv60) → Magic Bait (Lv80) → Support Bait (Lv150, pets)."],
		["Boats", ["boat", "Rowboat"],
		"Every boat gives −0.25s cooldown and +1 fish per cast. They're bought in order, and later boats need higher levels."],
		["Upgrades", ["ui", "stats"],
		"Shop upgrades cost money (Better Fish, Salesman, More Chests…). Special upgrades (Lv50+) cost exotic fish. League upgrades cost Hooks and are never reset."],
	],
	"Progress": [
		["Levels & biomes", ["ui", "biomes"],
		"XP levels you up and every level-up pays money. New biomes unlock at Lv50 Volcanic, Lv100 Ocean, Lv250 Sky, Lv500 Space, Lv1000 Alien and Lv2500 Abyss. Better fish, but fewer per cast and a longer cooldown."],
		["Chests & exotic fish", ["chest", "epic"],
		"From Lv10 casts can find chests (Common → Artifact). They give money, XP, charms and exotic fish: Gold & Emerald (Lv10), Lava (Lv50), Diamond (Lv100). Exotic fish pay for boosts and special upgrades — check your Wallet."],
		["Charms", ["charm", "quality"],
		"Rare+ chests drop charms (Lv20+). Each type levels in tiers; tier n costs n charms. You need every charm maxed (440 at P0) to prestige."],
		["Pets", ["pet", "Puffer"],
		"Pets can't be bought: every cast has a 1 in 10,000 chance to find one. Equipped pets level up as you fish and give big buffs."],
		["Boosts, workers & quests", ["ui", "boosts"],
		"Boosts (Lv10) cost Gold/Emerald fish: Fish boost, Treasure boost and Workers that fish for you. Daily quests pay money/XP, the league quest pays Hooks, and the Daily reward (Lv10) grows with your streak."],
	],
	"Prestige": [
		["Prestiging", ["ui", "prestige"],
		"At Level 250 with 440/440 charms and $5B you can prestige. You restart from Level 1 but keep pets, Hooks, league upgrades and prestige perks, and earn an Azure Fish."],
		["Prestige shop", ["exotic", "azure"],
		"Spend Azure Fish on permanent perks: International Ties, Business Education, Fish Whisperer, Ancient One and Virtual Fisher (P5+). Each perk's cap is 1 + prestige/5. The Guide tab in the Prestige panel shows the community buy order."],
	],
	"Controls": [
		["Desktop", ["ui", "settings"],
		"Click the water — cast right there (hold to keep fishing)\nSpace / F — cast where you aimed last (hold to keep fishing)\nS — sell everything · Tab — Fish Book · P — phone\nEsc — menu (or close a panel) · 1–9 — Shop, Map, Fish Book, Charms, Pets, Boosts, Quests, Prestige, Buffs\nG — guide · O — settings (music, sound, fullscreen)"],
		["Phone & tablet", ["ui", "settings"],
		"Tap the water to cast exactly there; keep your finger down to keep fishing. The round button bottom-right casts too. Tap the fish shop to buy. On the web version use your browser's \"Add to Home Screen\" to play full-screen in landscape."],
		["Saving", ["ui", "daily"],
		"The game saves automatically every 20 seconds and when you close it. Desktop and web keep separate saves. Settings (O) has the music/sound switches and Reset save."],
	],
}
const TAB_ORDER := ["Basics", "Gear", "Progress", "Prestige", "Controls", "Credits", "Feedback"]

const AUTHOR := "afosh"
const SOCIALS := [["LinkedIn", "https://www.linkedin.com/in/mostafa-kmal-3731453a9/"],
	["GitHub", "https://github.com/iiafosh"]]
const ASSET_CREDITS := "Fish, characters & market art: Quaternius (CC0) · Nature, boats, particles, UI & sounds: Kenney (CC0) · Seagull, crab & some boat parts: Poly by Google (CC-BY 3.0) · Space Shuttle: Zoe XR (CC-BY 3.0) · Water sounds: OpenGameArt (CC0) · Fonts: Fredoka & Cairo (OFL) · Interface icons: Phosphor Icons (MIT) · Game data: Virtual Fisher Encyclopaedia, virtualfisher.miraheze.org wiki and the Prestige 0 Guide. Full list in CREDITS.md."

extends RefCounted
## FishTok content: NPC fishers, captions, tips (facts from VFData / VFGuide),
## parody "sponsored" posts and today's feed. Pure data built from VF state;
## vf_phone.gd + vf_tok_post.gd draw it. A parody: no real apps, brands or people.
##
## A feed item: {id, kind, who, caption, sound, likes, comments, shares, v, seed}
##   kind: trend | challenge | tip | npc | ad | mine | end
##   who:  {handle, color, icon: [kind, name], verified?, sponsored?, me?}
##   v:    visual spec, v.type: scene | haul | boat | fish | chest | trend |
##         challenge | tip | ad | level | end

const OFFICIAL := {"handle": "fishtok", "color": Color("#12343b"), "icon": ["ph", "fish"], "verified": true}
const TIPS := {"handle": "fosh.tips", "color": Color("#1d9bb0"), "icon": ["ph", "sparkle"], "verified": true}
const MARKET := {"handle": "fishmarket.island", "color": Color("#d4920f"), "icon": ["ph", "storefront"], "verified": true, "sponsored": true}

const CREATORS := [
	{"handle": "reel_deal", "color": Color("#2f8f9e"), "icon": ["fish", "Cod"]},
	{"handle": "the_codfather", "color": Color("#7a4e2d"), "icon": ["fish", "Hot Cod"]},
	{"handle": "krillionaire", "color": Color("#d4920f"), "icon": ["fish", "Rainbow Fish"]},
	{"handle": "lure_queen", "color": Color("#c0367a"), "icon": ["fish", "Tropical Fish"]},
	{"handle": "bobber_bob", "color": Color("#e04f45"), "icon": ["fish", "Raw Salmon"]},
	{"handle": "salty_sue", "color": Color("#1d4ed8"), "icon": ["fish", "Pufferfish"]},
	{"handle": "abyss_gazer", "color": Color("#5b21b6"), "icon": ["fish", "Dark Puffer"]},
	{"handle": "fishfluencer", "color": Color("#ea580c"), "icon": ["fish", "Fiery Pufferfish"]},
	{"handle": "tidal_tina", "color": Color("#16a34a"), "icon": ["fish", "Turtle"]},
	{"handle": "sushi_sensei", "color": Color("#334155"), "icon": ["fish", "Squid"]},
	{"handle": "captain_sardine", "color": Color("#0f766e"), "icon": ["fish", "Dolphin"]},
	{"handle": "gone_fishin_gran", "color": Color("#9a6b4f"), "icon": ["pet", "Puffer"]},
]

const SOUNDS := ["lofi waves to fish to", "Sea Shanty No. 5 (sped up)", "splash splash (remix)",
	"ocean ambience, 10 hours", "reel it in (slowed + reverb)", "bobber bounce", "the deep end (instrumental)",
	"seagull choir", "tide pod-cast intro"]

## NPC post templates. {fish} {biome} {btag} {ftag} {n} {tier} {price} {day} {boat}
const NPC_POSTS := [
	{"v": "scene", "cap": "POV: you finally made it to the {biome} #{btag}tok #fyp", "sticker": "POV: new biome unlocked"},
	{"v": "haul", "cap": "{n} {fish} in ONE cast?? I'm shaking #luck #fishtok", "sticker": "{n} {fish}. one cast."},
	{"v": "fish", "cap": "rate my {fish} 1-10, be honest #fishcheck #fyp", "sticker": "rate my {fish}"},
	{"v": "fish", "cap": "the {fish} stare. that's the post. #{ftag}tok", "sticker": ""},
	{"v": "chest", "cap": "opening a {tier} chest live... wait for it #treasure #chest", "sticker": "WAIT FOR IT"},
	{"v": "scene", "cap": "day {day} of fishing until I find a pet #1in10000 #petcheck", "sticker": "day {day} of looking for a pet"},
	{"v": "scene", "cap": "ASMR: {biome} waves, no talking #asmr #relax", "sticker": ""},
	{"v": "boat", "cap": "my {boat} vs your rowboat #boattok #flex", "sticker": "rate the boat"},
	{"v": "fish", "cap": "this {fish} sells for {price} and I will not elaborate #money #{ftag}tok", "sticker": "{price}. each."},
	{"v": "scene", "cap": "nobody: ... me at 3am: one more cast #fishinglife", "sticker": "one more cast"},
	{"v": "fish", "cap": "{fish} appreciation post. just look at it #wholesome", "sticker": ""},
	{"v": "scene", "cap": "the {biome} at golden hour hits different #scenery #fyp", "sticker": ""},
	{"v": "haul", "cap": "told my boss I was sick. caught {n} {fish}. worth it #fishinglife", "sticker": ""},
	{"v": "chest", "cap": "{tier} chest number 3 today. the grind is real #treasure", "sticker": ""},
]

const COMMENTS := ["first", "the {fish} is so real", "what rod is that??", "teach me your ways", "W post",
	"been grinding the {biome} for weeks and never seen this", "this is why I fish", "ok but the sound",
	"petition for more {fish} content", "my bait could never", "the way I screamed", "saving this for later",
	"drop the setup pls", "not me watching this instead of fishing", "{fish} supremacy", "goals fr"]

const BAIT_SLOGANS := {
	"Worms": "The original. Accept no substitutes.",
	"Leeches": "Gross? Yes. Effective? Also yes.",
	"Magnet": "Fish say no. Treasure says yes.",
	"Wise Bait": "Big brain fishing.",
	"Fish": "Fish that catches fish. Don't think about it.",
	"Artifact Magnet": "Treasure hunters' little secret.",
	"Magic Bait": "Fish can't resist. Neither can you.",
	"Support Bait": "Your future pet is out there.",
}

const TIP_COLORS := [["#0f766e", "#22d3ee"], ["#1e3a8a", "#38bdf8"], ["#7c2d12", "#fb923c"],
	["#4c1d95", "#c084fc"], ["#14532d", "#4ade80"], ["#831843", "#f472b6"]]

# ------------------------------------------------------------------ helpers
static func tag(name: String) -> String:
	return VFData.slug(name).replace("_", "")

static func handle_for(player_name: String) -> String:
	var out := ""
	for ch in player_name.to_lower().replace(" ", "_"):
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == ".": out += ch
	return out if out != "" else "fisher"

## 1234 -> "1,234", 12400 -> "12.4K", 1200000 -> "1.2M" (feed style)
static func count(n: int) -> String:
	if n < 10000: return VF.commas(n)
	if n < 1000000: return ("%.1f" % (n / 1000.0)).trim_suffix(".0") + "K"
	return ("%.1f" % (n / 1000000.0)).trim_suffix(".0") + "M"

static func ago(seconds: float) -> String:
	var s := int(maxf(0.0, seconds))
	if s < 60: return "now"
	if s < 3600: return "%dm" % (s / 60)
	if s < 86400: return "%dh" % (s / 3600)
	return "%dd" % (s / 86400)

static func fill(text: String, ctx: Dictionary) -> String:
	var out := text
	for k in ctx:
		out = out.replace("{" + k + "}", str(ctx[k]))
	return out

static func bait_fx(name: String) -> String:
	var d: Dictionary = VFData.BAITS[name]
	var bits := []
	if d.has("fish"): bits.append("+%d fish" % int(d.fish))
	var names := {"catch": "catch", "quality": "quality", "tc": "treasure", "tq": "treasure quality", "xp": "XP",
		"pet_chance": "pet chance", "pet_eff": "pet power"}
	for k in names:
		if d.has(k) and float(d[k]) > 0.0: bits.append("+%d%% %s" % [int(round(float(d[k]) * 100.0)), names[k]])
	return ", ".join(bits)

static func unlocked_biomes(level: int) -> Array:
	var out := []
	for b in VFData.BIOME_ORDER:
		if VFData.BIOMES[b].level <= level: out.append(b)
	return out

static func _pick(rng: RandomNumberGenerator, a: Array):
	return a[rng.randi() % a.size()]

static func _npc_counts(rng: RandomNumberGenerator, lo: float, hi: float) -> Array:
	var likes := int(pow(10.0, rng.randf_range(lo, hi)))
	return [likes, int(likes * rng.randf_range(0.004, 0.03)), int(likes * rng.randf_range(0.002, 0.015))]

# --------------------------------------------------------------------- tips
## Short, accurate tips. Numbers come straight from VFData so they stay true.
## [min level, max level] keeps them relevant to where you are.
static func tips(vf) -> Array:
	var b: Dictionary = VFData.BAITS
	var out := [
		{"text": "Hold to keep fishing", "body": "Hold the FISH button, Space or your finger on the water and you keep casting.",
			"tags": "#controls #protip", "icon": ["ph", "fish"], "min": 1, "max": 40},
		{"text": "Every boat: -0.25s and +1 fish", "body": "Boats are bought in order. Each one cuts 0.25s off your cooldown and adds a fish to every cast.",
			"tags": "#boats #protip", "icon": ["boat", "Rowboat"], "min": 1, "max": 999},
		{"text": "Sell the trending fish", "body": "One fish trends on FishTok every day and sells for +50% until midnight (UTC). It's always the first post.",
			"tags": "#trending #money", "icon": ["ph", "fire"], "min": 1, "max": 99999},
		{"text": "Sell right before you buy", "body": "Fish in your hold don't earn anything. Sell, then spend.",
			"tags": "#money #protip", "icon": ["ui", "money"], "min": 1, "max": 80},
		{"text": "Chests start at level 10", "body": "From Lv10 casts can find chests with money, XP and exotic fish. Gold & Emerald Fish pay for boosts.",
			"tags": "#chests #treasure", "icon": ["chest", "rare"], "min": 1, "max": 30},
		{"text": "Charms from level 20", "body": "Rare+ chests drop charms from Lv20. Tier n costs n charms, and prestige needs every charm maxed (%d at P0)." % VFData.charm_total_cap(0),
			"tags": "#charms", "icon": ["charm", "quality"], "min": 12, "max": 400},
		{"text": "Pets: 1 in 10,000 casts", "body": "Pets can't be bought. Support Bait (Lv%d) gives +%d%% pet chance and stronger pets." % [b["Support Bait"].level, int(b["Support Bait"].pet_chance * 100)],
			"tags": "#pets #1in10000", "icon": ["pet", "Puffer"], "min": 1, "max": 99999},
		{"text": "Daily reward at level 10", "body": "Claim it once a day. Come back within 48h to keep your streak: every streak day adds +2%.",
			"tags": "#daily #streak", "icon": ["ui", "daily"], "min": 5, "max": 99999},
		{"text": "Haste charms = faster casts", "body": "Each Haste tier cuts 0.05s off your cooldown, down to a %.1fs floor." % VFData.MIN_COOLDOWN,
			"tags": "#charms #speed", "icon": ["charm", "haste"], "min": 20, "max": 99999},
		{"text": "Check your exact odds", "body": "The Buffs panel (9) shows your catch odds for every fish in this biome, with your rod and bait.",
			"tags": "#stats #protip", "icon": ["ui", "stats"], "min": 3, "max": 99999},
		{"text": "Hooks never reset", "body": "+10 Hooks from the daily league quest and +10 per 500 trips each week (max 100). League upgrades survive prestige.",
			"tags": "#league #hooks", "icon": ["ui", "hooks"], "min": 10, "max": 99999},
		{"text": "Prestige at level %d" % VFData.prestige_level_req(0), "body": "You also need %d charms and $%s. You keep pets, Hooks and perks, and earn an Azure Fish." % [VFData.charm_total_cap(0), VF.fmt(VFData.prestige_money_req(0))],
			"tags": "#prestige", "icon": ["exotic", "azure"], "min": 120, "max": 99999},
		{"text": "Wise Bait: +%d%% XP" % int(b["Wise Bait"].xp * 100), "body": "Unlocks at Lv%d. Perfect when you're chasing the next biome." % b["Wise Bait"].level,
			"tags": "#bait #xp", "icon": ["bait", "Wise Bait"], "min": 20, "max": 400},
		{"text": "Magnet: treasure > fish", "body": "Magnet (Lv%d): fewer bites but +%d%% treasure chance. Pair it with a treasure boost." % [b["Magnet"].level, int(b["Magnet"].tc * 100)],
			"tags": "#bait #treasure", "icon": ["bait", "Magnet"], "min": 15, "max": 300},
	]
	# where to next: the next biome
	for bm in VFData.BIOME_ORDER:
		var d: Dictionary = VFData.BIOMES[bm]
		if d.level > vf.level:
			out.append({"text": "Next stop: %s (Lv%s)" % [bm, VF.commas(d.level)], "body": "%s Better fish, but fewer per cast and +%.1fs cooldown." % [d.desc, d.cd_add],
				"tags": "#%s #explore" % tag(bm), "icon": ["ph", "map-trifold"], "min": 1, "max": 99999})
			break
	# next bait worth knowing about
	for x in VFData.BAIT_ORDER:
		if b[x].level > vf.level and b[x].level <= vf.level + 40:
			out.append({"text": "%s unlocks at Lv%d" % [x, b[x].level], "body": "%s: %s." % [x, bait_fx(x)],
				"tags": "#bait #%s" % tag(x), "icon": ["bait", x], "min": 1, "max": 99999})
			break
	# the next rod to save for
	for r in VFData.ROD_ORDER:
		var d: Dictionary = VFData.RODS[r]
		if r in vf.owned_rods or r == "Supporter Rod" or d.level > vf.level: continue
		out.append({"text": "Saving up? %s" % r, "body": "%d-%d fish per cast, %s%% treasure. %s Costs $%s." % [d.min, d.max, str(snappedf(d.tc * 100.0, 0.1)), d.desc, VF.fmt(d.cost)],
			"tags": "#rods #upgrade", "icon": ["rod", r], "min": 1, "max": 99999})
		break
	return out.filter(func(t): return vf.level >= int(t.min) and vf.level <= int(t.max))

# ---------------------------------------------------------------- the feed
static func feed(vf, salt: int) -> Array:
	var day: String = vf._today()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("fishtok-feed:%s:%d" % [day, salt])
	var tips_all := tips(vf)
	var tip_order := range(tips_all.size())
	_shuffle(rng, tip_order)
	var npc_order := range(NPC_POSTS.size())
	_shuffle(rng, npc_order)
	var ad_list := ads(vf)
	var mine: Array = vf.tok_posts
	var slots := ["trend", "npc", "challenge", "tip", "npc", "ad", "mine", "npc", "tip", "npc", "ad", "tip", "npc", "tip", "npc", "end"]
	var out := []
	var ti := 0
	var ni := 0
	var ai := 0
	for i in slots.size():
		var s: String = slots[i]
		var id := "%s:%d:%d" % [day, salt, i]
		var item := {}
		match s:
			"trend": item = trend_post(vf, rng)
			"challenge": item = challenge_post(vf, rng)
			"tip":
				if ti < tip_order.size():
					item = tip_post(tips_all[tip_order[ti]], rng)
					ti += 1
			"npc":
				item = npc_post(vf, rng, NPC_POSTS[npc_order[ni % npc_order.size()]])
				ni += 1
			"ad":
				if ai < ad_list.size():
					item = ad_post(ad_list[ai], rng)
					ai += 1
			"mine":
				if not mine.is_empty(): item = mine_post(vf, mine[-1])
			"end": item = {"kind": "end", "who": OFFICIAL, "caption": "", "sound": "", "likes": 0, "comments": 0, "shares": 0, "v": {"type": "end"}}
		if item.is_empty(): continue
		if not item.has("id"): item["id"] = id
		item["seed"] = absi(hash(id)) % 10000
		out.append(item)
	return out

static func _shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

static func trend_post(vf, rng: RandomNumberGenerator) -> Dictionary:
	var f: String = vf.trending_fish()
	var c := _npc_counts(rng, 5.6, 6.4)
	var where := []
	for b in VFData.BIOME_ORDER:
		if f in VFData.BIOMES[b].fish: where.append(b)
	return {"kind": "trend", "who": OFFICIAL, "likes": c[0], "comments": c[1], "shares": c[2],
		"caption": "#%sTok is trending! %s sells for +50%% today, until midnight UTC. Found in: %s #trending #fishtok" % [
			f.replace(" ", ""), f, ", ".join(where)],
		"sound": "trending now", "v": {"type": "trend", "fish": f}, "where": where}

static func challenge_post(vf, rng: RandomNumberGenerator) -> Dictionary:
	var ch: Dictionary = vf.tok_challenge()
	var c := _npc_counts(rng, 4.6, 5.4)
	return {"kind": "challenge", "who": OFFICIAL, "likes": c[0], "comments": c[1], "shares": c[2],
		"caption": "Today's #challenge: %s. Reward: %s. Resets at midnight UTC #dailychallenge" % [vf.tok_challenge_text(ch), vf.goal_reward_text(ch.reward)],
		"sound": "challenge accepted", "v": {"type": "challenge"}}

static func tip_post(t: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var c := _npc_counts(rng, 3.6, 4.9)
	var cols: Array = TIP_COLORS[rng.randi() % TIP_COLORS.size()]
	return {"kind": "tip", "who": TIPS, "likes": c[0], "comments": c[1], "shares": c[2],
		"caption": "%s %s #protip" % [t.body, t.tags], "sound": "original sound - fosh.tips",
		"v": {"type": "tip", "text": t.text, "icon": t.icon, "c1": Color(cols[0]), "c2": Color(cols[1])}}

static func npc_post(vf, rng: RandomNumberGenerator, tpl: Dictionary) -> Dictionary:
	var who: Dictionary = CREATORS[rng.randi() % CREATORS.size()]
	var open_biomes := unlocked_biomes(vf.level)
	# scenery: mostly places you know, sometimes a teaser of what's ahead
	var biome: String = _pick(rng, VFData.BIOME_ORDER) if rng.randf() < 0.35 else _pick(rng, open_biomes)
	var fish_pool: Array = VFData.BIOMES[_pick(rng, open_biomes)].fish
	var fish: String = fish_pool[mini(fish_pool.size() - 1, int(pow(rng.randf(), 0.7) * fish_pool.size()))]
	if tpl.v in ["scene", "haul", "boat"]:
		fish = _pick(rng, VFData.BIOMES[biome].fish)
	var tiers := ["rare", "epic", "legendary", "artifact"]
	var boats := VFData.BOAT_ORDER.slice(2, 12)
	var ctx := {"fish": fish, "biome": biome, "btag": tag(biome), "ftag": tag(fish), "n": rng.randi_range(14, 60),
		"tier": _pick(rng, tiers), "price": "$" + VF.fmt(VFData.FISH[fish].price), "day": rng.randi_range(12, 340),
		"boat": _pick(rng, boats)}
	var c := _npc_counts(rng, 2.9, 6.2)
	var sound: String = ("original sound - " + String(who.handle)) if rng.randf() < 0.45 else _pick(rng, SOUNDS)
	var v := {"type": tpl.v, "biome": biome, "fish": fish, "tier": ctx.tier, "sticker": fill(tpl.sticker, ctx)}
	if tpl.v == "haul": v["fish_n"] = 7
	if tpl.v == "boat": v["boat"] = ctx.boat
	if tpl.v == "fish": v["accent"] = VFData.BIOMES[_biome_of(fish)].accent
	return {"kind": "npc", "who": who, "caption": fill(tpl.cap, ctx), "sound": sound,
		"likes": c[0], "comments": c[1], "shares": c[2], "v": v, "ctx": ctx}

static func _biome_of(fish: String) -> String:
	for b in VFData.BIOME_ORDER:
		if fish in VFData.BIOMES[b].fish: return b
	return "River"

## Sponsored parody posts for things you can actually buy next. Tapping the
## button opens the matching shop tab.
static func ads(vf) -> Array:
	var out := []
	var best := "Worms"
	for x in VFData.BAIT_ORDER:
		if VFData.BAITS[x].level <= vf.level: best = x
	out.append({"head": best, "slogan": BAIT_SLOGANS.get(best, ""), "fx": bait_fx(best),
		"price": "$%s each" % VF.commas(VFData.BAITS[best].cost), "icon": ["bait", best], "panel": ["shop", "Bait"],
		"cta": "Shop bait", "tags": "#bait #%s" % tag(best)})
	for r in VFData.ROD_ORDER:
		var d: Dictionary = VFData.RODS[r]
		if r in vf.owned_rods or r == "Supporter Rod" or d.level > vf.level: continue
		out.append({"head": r, "slogan": "%d-%d fish per cast. Your old rod will understand." % [d.min, d.max], "fx": d.desc,
			"price": "$" + VF.fmt(d.cost), "icon": ["rod", r], "panel": ["shop", "Rods"], "cta": "See the rod", "tags": "#rods #upgrade"})
		break
	var nb: String = vf.next_boat()
	if nb != "":
		out.append({"head": nb, "slogan": "-0.25s cooldown and +1 fish. Sail in style.", "fx": "Boats stack: every boat you own counts.",
			"price": "$" + VF.fmt(VFData.BOATS[nb].cost), "icon": ["boat", nb], "panel": ["shop", "Boats"], "cta": "See the boat", "tags": "#boattok"})
	return out

static func ad_post(a: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var c := _npc_counts(rng, 2.6, 3.8)
	return {"kind": "ad", "who": MARKET, "likes": c[0], "comments": c[1], "shares": c[2],
		"caption": "%s %s %s" % [a.slogan, a.fx + ("." if not String(a.fx).ends_with(".") else ""), a.tags],
		"sound": "Promoted music", "v": {"type": "ad", "icon": a.icon, "head": a.head, "slogan": a.slogan, "price": a.price},
		"panel": a.panel, "cta": a.cta}

## One of your own posts (VF.tok_posts entry) as a feed item.
static func mine_post(vf, p: Dictionary) -> Dictionary:
	var who := me(vf)
	var fish := String(p.get("fish", ""))
	var biome := String(p.get("biome", "River"))
	var cap := ""
	var v := {}
	match String(p.kind):
		"species":
			cap = "New catch unlocked: %s! Fish Book %d / %d #newfish #%stok #fishtok" % [fish, vf.discovered.size(), VFData.FISH_ORDER.size(), tag(fish)]
			v = {"type": "fish", "fish": fish, "accent": VFData.BIOMES[_biome_of(fish)].accent, "sticker": "NEW FISH"}
		"chest":
			cap = "Pulled a %s chest in the %s #treasure #%schest" % [p.tier, biome, p.tier]
			v = {"type": "chest", "tier": p.tier, "sticker": "%s chest!" % String(p.tier).capitalize()}
		"haul":
			cap = "%d fish in one cast. New personal record #recordbreaker #%stok" % [int(p.count), tag(biome)]
			v = {"type": "haul", "biome": biome, "fish": fish if fish != "" else VFData.BIOMES[biome].fish[0], "fish_n": 8,
				"sticker": "%d fish. one cast." % int(p.count)}
		"level":
			cap = "Level %s reached! The grind pays off #levelup #fishtok" % VF.commas(int(p.level))
			v = {"type": "level", "level": int(p.level)}
		_:
			cap = "My %s collection is looking healthy #flex #%stok" % [fish, tag(fish)]
			v = {"type": "fish", "fish": fish, "accent": VFData.BIOMES[_biome_of(fish)].accent, "sticker": "my %s haul" % fish}
	var likes: int = vf.tok_post_likes(p)
	return {"kind": "mine", "id": "mine:%d" % int(p.id), "who": who, "caption": cap, "sound": "original sound - " + String(who.handle),
		"likes": likes, "comments": int(likes * 0.04), "shares": int(likes * 0.015), "v": v, "post": p}

static func me(vf) -> Dictionary:
	var icon := ["ph", "user-circle"]
	if vf.pet != "": icon = ["pet", vf.pet]
	else:
		var best := ""
		for f in vf.discovered:
			if best == "" or VFData.FISH[f].price > VFData.FISH[best].price: best = f
		if best != "": icon = ["fish", best]
	return {"handle": handle_for(vf.player_name), "color": VFData.BIOMES[vf.biome].accent, "icon": icon, "me": true}

## A few fake comments for the comment sheet (deterministic per post).
static func comments_for(item: Dictionary, n: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(item.get("seed", 1)) * 7919 + 13
	var v: Dictionary = item.get("v", {})
	var ctx := {"fish": String(v.get("fish", "Cod")) if String(v.get("fish", "")) != "" else "Cod",
		"biome": String(v.get("biome", "River")) if String(v.get("biome", "")) != "" else "River"}
	var out := []
	var order := range(COMMENTS.size())
	_shuffle(rng, order)
	for i in mini(n, order.size()):
		var who: Dictionary = CREATORS[rng.randi() % CREATORS.size()]
		out.append({"who": who, "text": fill(COMMENTS[order[i]], ctx), "ago": "%dh" % rng.randi_range(1, 23),
			"likes": int(pow(10.0, rng.randf_range(0.3, 3.4)))})
	return out

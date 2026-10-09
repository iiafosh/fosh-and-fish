extends SceneTree
## Headless balance + correctness check for the VF simulation.
## Run: Godot_console.exe --headless --path . -s res://tests/vf_sim_test.gd

var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)

func _init() -> void:
	var g = load("res://scripts/vf/vf_game.gd").new()
	g.autosave = false
	g.name = "VF"
	root.add_child(g)
	g.rng.seed = 12345
	# fresh state regardless of any save file
	g.prestige = 0; g.level = 1; g.xp = 0; g.money = 0; g.inventory = {}; g.charms = {}

	print("== tables")
	check(g.xp_to_next(1) == 100 and g.xp_to_next(250) == 6367500, "XP table loaded (L1=100, L250=6,367,500)")
	check(VFData.charm_total_cap(0) == 440, "P0 charm cap is 440")
	check(VFData.charm_total_cap(1) == 528, "P1 charm cap is 8*11*12/2 = 528")
	var s := 0
	for i in VFData.UPGRADES.better_fish.max:
		s += VFData.curve_cost(VFData.UPGRADES.better_fish.total, VFData.UPGRADES.better_fish.max, i + 1)
	check(absi(s - 14902000) < 50, "Better Fish level prices sum to the wiki total (%d)" % s)
	check(VFData.prestige_guide(23).main == "SKIP" and VFData.prestige_guide(26).main == "BE"
		and VFData.prestige_guide(30).main == "IT + VF + AO + FW", "Prestige chart: P17-85 rules")
	check(VFData.prestige_guide(142).max == "AO27", "Prestige chart: P142 Max AO27")

	print("== species odds")
	var odds: Array = g.species_odds("Plastic Rod", "River", 1.0)
	check(absf(odds[0] - 0.84) < 0.001 and absf(odds[2] - 0.025) < 0.001, "Plastic/River base odds match wiki (84/13.5/2.5)")
	odds = g.species_odds("Plastic Rod", "River", 2.0)
	check(absf(odds[2] - 0.05) < 0.001 and absf(odds[1] - 0.27) < 0.001, "Fish quality x2 doubles the higher tiers")
	odds = g.species_odds("Lava Rod", "River", 1.0)
	check(odds[4] > 0.0, "Lava Rod in River falls back to Alloy table")

	print("== cooldown / catch")
	check(is_equal_approx(g.cooldown(), 3.5), "River base cooldown 3.5s")
	g.boats_owned = 6
	check(is_equal_approx(g.cooldown(), 2.0), "6 boats -> 2.0s floor")
	g.boats_owned = 0
	var tot := 0
	for i in 2000:
		tot += g._fish_count()
	var avg := tot / 2000.0
	check(avg > 6.5 and avg < 7.5, "Plastic Rod averages ~7 fish/cast (got %.2f)" % avg)

	print("== P0 run: play the guide's opening")
	var casts := 0
	g._last_cast_ms = -100000
	while g.level < 10 and casts < 20000:
		g._last_cast_ms = -100000
		g.cast()
		casts += 1
		if g.inventory_value() >= 500 and not ("Improved Rod" in g.owned_rods):
			g.sell_all(); g.buy_rod("Improved Rod")
	print("  reached level %d after %d casts, money $%s, rods %s" % [g.level, casts, g.commas(g.money + g.inventory_value()), g.owned_rods])
	check(g.level >= 10, "Level 10 reachable")
	check(casts > 100 and casts < 3000, "Level 10 pacing is in a sane range (%d casts)" % casts)

	print("== chests / charms / prestige")
	g.level = 250; g.rod = "Golden Rod"; g.owned_rods.append("Golden Rod"); g.biome = "Ocean"
	g.bait = "Artifact Magnet"; g.bait_stock["Artifact Magnet"] = 100000
	var chests := 0
	for i in 3000:
		g._last_cast_ms = -100000
		var r: Dictionary = g.cast()
		if not r.chest.is_empty(): chests += 1
	print("  treasure chance %.1f%%, chests %d / 3000, charms %d" % [g.treasure_chance() * 100, chests, g.charms_total()])
	check(chests > 150, "Golden Rod + Artifact Magnet finds plenty of chests")
	check(g.charms_total() > 0, "Charms drop at level 20+")
	g.charms = {}
	for id in VFData.CHARM_ORDER: g.charms[id] = 55
	g.money = 5_000_000_000; g.level = 250
	check(g.prestige_check().ok, "P0 prestige requirements met with 440 charms, L250, $5B")
	check(g.do_prestige() == "" and g.prestige == 1 and g.exotics.azure == 1 and g.level == 1, "Prestige resets and grants 1 Azure Fish")
	check(g.buy_perk("international_ties") == "" and g.pk("international_ties") == 1, "Buy International Ties with Azure Fish")
	check(g.buy_perk("virtual_fisher") != "", "Virtual Fisher perk locked before P5")

	print("== shop flows")
	g.prestige = 0; g.level = 120; g.money = 2_000_000_000; g.owned_rods = ["Plastic Rod"]; g.boats_owned = 0
	check(g.buy_rod("Magma Rod") == "" and g.rod == "Magma Rod", "Buy + auto-equip a rod")
	check(g.buy_rod("Dark Rod") != "", "Level-locked rod is refused")
	check(g.buy_boat() == "" and g.boats_owned == 1 and g.current_boat() == "Rowboat", "Boats are bought in order")
	check(g.buy_bait("Magic Bait", 10) == "" and g.bait_stock["Magic Bait"] == 10, "Buy bait")
	var c0: int = g.upgrade_cost("salesman")
	check(g.buy_upgrade("salesman") == "" and g.up("salesman") == 1 and g.upgrade_cost("salesman") > c0, "Upgrade price rises per level")
	check(g.select_biome("Abyss") != "" and g.select_biome("Ocean") == "", "Biome travel respects level locks")
	g.select_rod("Plastic Rod")
	g._last_cast_ms = -100000
	check(g.can_cast() != "" and g.can_cast() != "cooldown", "Plastic Rod can't cast in the Ocean")
	g.select_rod("Magma Rod")
	g.inventory = {"Dolphin": 3}
	var before: int = g.money
	var earned: int = g.sell_all()
	check(earned > 60000 and g.money == before + earned and g.inventory.is_empty(), "Selling empties the hold and pays out")

	print("== quests / daily")
	g.level = 50; g.daily_last = 0.0
	var d: Dictionary = g.claim_daily()
	check(not d.has("error") and d.streak >= 1, "Daily reward claimable")
	check(g.claim_daily().has("error"), "Daily can't be claimed twice")

	print("== FishTok: trending fish")
	g._tok_apply({})
	g.prestige = 0; g.level = 120; g.biome = "Ocean"
	var t1: String = g.trending_for("2026-10-09", 120)
	check(t1 == g.trending_for("2026-10-09", 120) and t1 in g.tok_trend_candidates(120), "Trending fish is deterministic for a date (%s)" % t1)
	var seen := {}
	for dd in 30: seen[g.trending_for("2026-11-%02d" % (dd + 1), 120)] = true
	check(seen.size() >= 4, "Trending fish changes day to day (%d species in 30 days)" % seen.size())
	check(g.tok_trend_candidates(1).size() == 5 and g.tok_trend_candidates(120).size() == 10, "Only fish from unlocked biomes can trend")
	var tf: String = g.trending_fish()
	check(tf == g.trending_for(g._today(), 120) and g.is_trending(tf), "Today's trending fish comes from today's date")
	var other := "Raw Fish" if tf != "Raw Fish" else "Cod"
	check(is_equal_approx(g.fish_price(tf), VFData.FISH[tf].price * 1.5) and is_equal_approx(g.fish_price(other), float(VFData.FISH[other].price)),
		"Trending fish sells for +50%, other fish unchanged")
	g.inventory = {tf: 10, other: 10}
	var want := int(round((10 * VFData.FISH[tf].price * 1.5 + 10 * VFData.FISH[other].price) * g.sell_mult()))
	var mb: int = g.money
	check(g.inventory_value() == want and g.sell_all() == want and g.money == mb + want, "inventory_value and sell_all pay the trending bonus ($%d)" % want)
	g.level = 200
	check(g.trending_fish() == tf, "Trending fish stays fixed for the day after leveling up")

	print("== FishTok: posts, likes, followers")
	g._tok_apply({})
	var now := Time.get_unix_time_from_system()
	var post: Dictionary = g._tok_post("species", {"fish": "Cod"}, 3.0, true, now)
	var l0: int = g.tok_post_likes(post, now)
	var l1: int = g.tok_post_likes(post, now + 600)
	var l2: int = g.tok_post_likes(post, now + 7200)
	check(l0 > 0 and l1 > l0 and l2 > l1 and l2 <= int(post.peak), "Post likes grow over real time toward a peak (%d -> %d -> %d / %d)" % [l0, l1, l2, post.peak])
	check(g.tok_followers(now + 7200) > g.tok_followers(now) and g.tok_likes(now + 7200) == l2, "Likes turn into followers")
	check(g._tok_post("chest", {"tier": "rare"}, 3.0, false, now + 10).is_empty(), "Auto posts are rate limited")
	var big: Dictionary = g._tok_post("chest", {"tier": "legendary"}, 6.0, true, now + 20)
	check(int(big.peak) > int(post.peak), "Better posts and more followers reach more likes")
	var fans_before: int = g.tok_followers(now + 9000)
	for i in 40: g._tok_post("level", {"level": 50 + i}, 2.0, true, now + 30 + i)
	check(g.tok_posts.size() == 30 and g.tok_followers(now + 9000) > fans_before, "Posts cap at 30; old posts keep their followers")
	g._tok_apply({})
	g._tok_on_trip({"count": 3, "fish": {"Raw Fish": 3}, "chest": {}, "new_species": ["Raw Fish"]})
	check(g.tok_posts.size() == 1 and g.tok_posts[0].kind == "species", "Discovering a new species posts automatically")

	print("== FishTok: milestones + challenge")
	g._tok_apply({})
	g.level = 30
	check(g.tok_claim_milestone(100).has("error"), "Milestone locked below 100 followers")
	g.tok_banked_followers = 150
	var m0: int = g.money
	var r1: Dictionary = g.tok_claim_milestone(100)
	var m1: int = g.money
	check(not r1.has("error") and m1 > m0, "Milestone 100 pays ($%d)" % (m1 - m0))
	check(g.tok_claim_milestone(100).has("error") and g.money == m1, "A milestone pays only once")
	check(g.tok_claim_milestone(1000).has("error") and g.tok_milestone_state(1000) == "locked", "1K needs 1K followers")
	check(g.tok_milestone_reward(1000000).money <= g.levelup_money(30) * 15, "Milestone rewards stay modest")
	g.biome = "River"; g.rod = "Steel Rod"
	var ch: Dictionary = g.tok_challenge()
	check(int(ch.goal) > 0 and g.tok_challenge_text() != "", "Daily challenge rolls: %s -> %s" % [g.tok_challenge_text(), g.goal_reward_text(ch.reward)])
	check(g.tok_claim_challenge().has("error"), "Challenge can't be claimed before it's done")
	g.tok_ch = {"day": g._today(), "kind": "species", "fish": "Cod", "goal": 20, "biome": "River", "reward": {"money": 400}}
	g.tok_ch_prog = 0
	g._tok_on_trip({"count": 9, "fish": {"Cod": 12, "Raw Fish": 3}, "chest": {}, "new_species": []})
	check(g.tok_ch_prog == 12, "Challenge progress comes from trip results")
	g._tok_on_trip({"count": 9, "fish": {"Cod": 9}, "chest": {}, "new_species": []})
	var mc: int = g.money
	check(not g.tok_claim_challenge().has("error") and g.money == mc + 400, "Finished challenge pays its reward")
	check(g.tok_claim_challenge().has("error") and g.money == mc + 400, "Challenge pays only once per day")
	g.tok_posts = []
	g._tok_post("haul", {"count": 21, "fish": "Cod"}, 3.5, true, now - 3600)

	print("== save / load round trip")
	g.charms = {"marketing": 7}
	g.pets = {"Puffer": {"level": 12, "xp": 30}}
	g.pet = "Puffer"
	var snap: Dictionary = g.to_dict()
	var g2 = load("res://scripts/vf/vf_game.gd").new()
	g2.autosave = false
	g2._apply(JSON.parse_string(JSON.stringify(snap)))
	check(g2.money == g.money and g2.level == g.level and g2.rod == g.rod and g2.boats_owned == g.boats_owned, "Core state survives JSON round trip")
	check(int(g2.charms.marketing) == 7 and int(g2.pets.Puffer.level) == 12 and g2.pet == "Puffer", "Charms and pets survive JSON round trip")
	check(g2.tok_followers() == g.tok_followers() and g2.tok_likes() == g.tok_likes() and g2.tok_posts.size() == g.tok_posts.size()
		and 100 in g2.tok_claimed and g2.tok_ch_claimed and g2.trending_fish() == g.trending_fish(), "FishTok state survives JSON round trip")
	check(g2.tok_claim_milestone(100).has("error"), "Claimed milestones stay claimed after loading")
	var old: Dictionary = JSON.parse_string(JSON.stringify(snap))
	old.erase("tok")
	g2._apply(old)
	check(g2.tok_posts.is_empty() and g2.tok_followers() == 0 and g2.tok_claimed.is_empty(), "Old saves without FishTok data load with defaults")
	g2.free()

	print("\n%s (%d failures)" % ["PASS" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)

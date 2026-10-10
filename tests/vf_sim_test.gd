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

	print("== catch modes (Relax / Reel it in!)")
	var tb := 0
	for i in 4000:
		tb += g._fish_count(false, VFData.MINIGAME_FISH_BONUS)
	var tn := 0
	for i in 4000:
		tn += g._fish_count()
	var ratio := float(tb) / float(tn)
	check(VFData.rod_reel_power("Plastic Rod") == 0.0 and VFData.rod_reel_power("Dark Rod") == 1.0
		and VFData.rod_reel_power("Steel Rod") < VFData.rod_reel_power("Lava Rod"), "rod reel power: starter 0, best 1, rises with the rod")
	var weak: Dictionary = VFData.minigame_params(4, 0.0)
	var strong: Dictionary = VFData.minigame_params(4, 1.0)
	check(strong.zone_h > weak.zone_h and strong.fill_rate > weak.fill_rate and strong.drain_rate < weak.drain_rate
		and strong.fish_speed == weak.fish_speed, "better rod: bigger zone, faster reel, slower slip (fish speed unchanged)")
	check(strong.zone_h < VFData.minigame_params(0, 0.0).zone_h, "the rarest fish stays a bit harder than a common one, even with the best rod")
	var pc: Dictionary = VFData.minigame_params(2, 0.3, true)
	var phone: Dictionary = VFData.minigame_params(2, 0.3, false)
	check(pc.zone_h > phone.zone_h and pc.fish_speed < phone.fish_speed and pc.fill_rate > phone.fill_rate
		and pc.time_limit > phone.time_limit and pc.max_v < phone.max_v, "keyboard + mouse: easier mini-game than on a phone")
	check(absf(ratio - (1.0 + VFData.MINIGAME_FISH_BONUS)) < 0.05, "won mini-game: +%d%% fish on average (x%.3f)" % [int(round(VFData.MINIGAME_FISH_BONUS * 100.0)), ratio])
	g._last_cast_ms = -100000
	var rw: Dictionary = g.cast_reel(true)
	check(rw.ok and rw.reel == "win" and absf(g.cur_cooldown() - VFData.MINIGAME_COOLDOWN) < 0.001
		and g.cooldown_left() <= VFData.MINIGAME_COOLDOWN and g.cooldown_left() > 0.3, "won mini-game: next cast ready after 0.5s (left %.2f)" % g.cooldown_left())
	var t0 := Time.get_ticks_msec()
	var rl: Dictionary = g.cast_reel(false, t0)
	check(rl.ok and rl.reel == "lose" and is_equal_approx(g.cur_cooldown(), g.cooldown()) and g.cooldown_left() > 3.0,
		"lost mini-game: normal catch + normal cooldown")
	g._last_cast_ms = -100000
	var rr: Dictionary = g.cast()
	check(rr.reel == "" and is_equal_approx(g.cur_cooldown(), g.cooldown()), "Relax cast: normal cooldown, no bonus tag")
	g.set_catch_mode("reel")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	g.catch_mode = "relax"
	g._apply(saved)
	check(g.catch_mode == "reel", "catch mode survives save/load")
	saved.erase("catch_mode")
	g._apply(saved)
	check(g.catch_mode == "relax", "old saves default to Relax mode")
	g._last_cast_ms = -100000

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
	g.sail_hint = true
	g2._apply(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(g2.sail_hint == true, "Sail hint flag survives JSON round trip")
	var old_sail: Dictionary = g.to_dict()
	old_sail.erase("sail_hint")                      # a save from before sailing existed
	g2._apply(JSON.parse_string(JSON.stringify(old_sail)))
	check(g2.sail_hint == false and g2.level == g.level, "Old saves without the sail hint flag still load")
	g2.free()

	print("== online backend (no network)")
	var B = load("res://scripts/net/backend.gd")
	var shipped = JSON.parse_string(FileAccess.get_file_as_string("res://data/backend.json"))
	check(shipped is Dictionary and shipped.has("url") and shipped.has("anon_key"), "data/backend.json has url + anon_key")
	check(B.parse_config({}).url == "" and B.parse_config({"url": "", "anon_key": ""}).anon_key == "", "empty config = offline mode")
	check(B.parse_config({"url": " https://abc.supabase.co/rest/v1/ ", "anon_key": " k "}).url == "https://abc.supabase.co"
		and B.parse_config({"anon_key": " k "}).anon_key == "k", "config URL/key are cleaned up")
	check(B.friendly_error({"net": true, "code": 0}).begins_with("Can't reach the server"), "offline -> friendly message")
	check(B.friendly_error({"code": 400, "data": {"code": 400, "error_code": "invalid_credentials", "msg": "Invalid login credentials"}}) == "Wrong email or password."
		and B.friendly_error({"code": 400, "data": {"error": "invalid_grant", "error_description": "Invalid login credentials"}}) == "Wrong email or password.",
		"wrong password (new + old GoTrue errors)")
	check(B.friendly_error({"code": 400, "data": {"error_code": "email_not_confirmed", "msg": "Email not confirmed"}}).begins_with("Please confirm your email"), "email not confirmed")
	check(B.friendly_error({"code": 422, "data": {"error_code": "user_already_exists", "msg": "User already registered"}}).begins_with("That email already has an account"), "email taken")
	check(B.friendly_error({"code": 429, "data": {"error_code": "over_request_rate_limit", "msg": "Request rate limit reached"}}).begins_with("Too many tries"), "rate limited")
	check(B.friendly_error({"code": 409, "data": {"code": "23505", "message": "duplicate key value"}}) == "That name is taken. Try another one.", "name taken")
	check(B.is_downgrade({"code": 400, "data": {"code": "P0001", "message": "save_downgrade: the cloud save has more progress"}}), "server downgrade refusal recognised")
	check(B.validate_email("fisher@example.com") == "" and B.validate_email("fisher@") != "" and B.validate_email("a b@c.d") != "", "email check")
	check(B.validate_password("12345") != "" and B.validate_password("hunter22") == "", "password needs 6+ characters")
	check(B.validate_name("Marlin Mae") == "" and B.validate_name("Al") != "" and B.validate_name("<script>") != ""
		and B.validate_name("x".repeat(21)) != "", "fisher name: 3-20 letters, numbers, spaces, _ - .")
	check(B.validate_name("صياد_سمك") == "" and B.validate_name("Pêcheur") == "", "fisher names may use any alphabet")
	var frag: Dictionary = B.parse_fragment("access_token=a.b&refresh_token=r1&type=recovery&error_description=Email+link+is+invalid")
	check(frag.refresh_token == "r1" and frag.type == "recovery" and frag.error_description == "Email link is invalid", "email-link URL fragment parsed")
	# which save wins
	g.prestige = 3; g.level = 140; g.money = 9_007_199_254_740_993; g.stats.money_earned = 12_345_678_901_234_567; g.stats.trips = 4000
	var here: Dictionary = B.summarize(g.to_dict())
	var round_trip: Dictionary = B.summarize(JSON.parse_string(JSON.stringify(g.to_dict())))
	check(here.fp == round_trip.fp and not here.fresh, "a save and its JSON cloud copy fingerprint the same (huge money too)")
	check(B.save_valid(JSON.parse_string(JSON.stringify(g.to_dict()))) and not B.save_valid({}) and not B.save_valid({"v": 1, "level": 3}), "cloud save validation")
	var fresh: Dictionary = B.summarize(g._defaults)
	check(fresh.fresh, "a new install counts as fresh")
	var cloud_sum := here.duplicate()
	cloud_sum["updated_at"] = "2026-10-09T10:00:00+00:00"
	var played: Dictionary = B.summarize(g.to_dict())
	played.level = 141; played.fp = "played"
	var behind := here.duplicate()
	behind.level = 120; behind.fp = "behind"
	var cloud_newer := cloud_sum.duplicate()
	cloud_newer.level = 150; cloud_newer.fp = "elsewhere"; cloud_newer.updated_at = "2026-10-09T11:00:00+00:00"
	check(B.decide(here, cloud_sum, "", "") == "same", "same progress -> nothing to do")
	check(B.decide(fresh, cloud_sum, "", "") == "download", "fresh install -> cloud save loads")
	check(B.decide(played, cloud_sum, here.fp, cloud_sum.updated_at) == "upload", "only this device moved -> upload")
	check(B.decide(here, cloud_newer, here.fp, cloud_sum.updated_at) == "download", "only the cloud moved -> download")
	check(B.decide(played, cloud_newer, here.fp, cloud_sum.updated_at) == "ask", "both moved -> ask the player")
	check(B.decide(behind, cloud_sum, here.fp, cloud_sum.updated_at) == "ask", "this device lost progress (reset) -> ask, never upload")
	check(B.decide(played, cloud_sum, "", "") == "ask", "first sign-in on a device with progress -> ask")
	check(B.worse({"prestige": 2, "level": 900}, {"prestige": 3, "level": 1}) and not B.worse({"prestige": 3, "level": 5}, {"prestige": 3, "level": 5}), "prestige outranks level")

	# phone interface scale: phones get a bigger UI (>= 460 px of layout height), tablets/desktops stay 1:1
	var k_phone := VFData.ui_scale_for(390.0)
	check(k_phone > 1.5 and absf(720.0 / k_phone - 460.0) < 1.0, "iPhone (390 dp) -> UI x%.2f, 460 px tall" % k_phone)
	check(VFData.ui_scale_for(412.0) > 1.4, "Pixel (412 dp) -> bigger UI")
	check(VFData.ui_scale_for(800.0) == 1.0 and VFData.ui_scale_for(0.0) == 1.0, "tablet / unknown -> desktop layout")
	check(VFData.ui_scale_for(200.0) <= 1.6, "tiny screens are capped")

	print("\n%s (%d failures)" % ["PASS" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)

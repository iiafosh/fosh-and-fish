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
	check(g.tok_dock and not g.tok_dock_tip, "An old save (no dock setting) docks the phone beside the game")
	g.tok_dock = false
	g.tok_dock_tip = true
	var tok_saved: Dictionary = g._tok_dict()
	g._tok_apply({})
	g._tok_apply(tok_saved)
	check(not g.tok_dock and g.tok_dock_tip, "The dock choice and the tip survive a save")
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
	check(B.friendly_error({"code": 500, "data": {"code": 500, "error_code": "unexpected_failure", "msg": "Error sending recovery email"}}).begins_with("We couldn't send the email"),
		"mail server refused -> says the email couldn't be sent")
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

	# a cloud save from a newer game version is never mistaken for a damaged one (that path replaces it)
	check(B.is_newer_save({"v": B.SAVE_VERSION + 1}) and not B.is_newer_save({"v": B.SAVE_VERSION}) and not B.is_newer_save(null),
		"newer-version cloud save is recognised (and left alone)")

	# phone interface scale: phones get a bigger UI (>= 500 px of layout height), tablets/desktops stay 1:1
	var k_phone := VFData.ui_scale_for(390.0)
	check(k_phone > 1.35 and absf(720.0 / k_phone - 500.0) < 1.0, "iPhone (390 dp) -> UI x%.2f, 500 px tall" % k_phone)
	check(VFData.ui_scale_for(412.0) > 1.3 and VFData.ui_scale_for(412.0) < k_phone, "Pixel (412 dp) -> bigger UI, a bit less")
	check(VFData.ui_scale_for(800.0) == 1.0 and VFData.ui_scale_for(0.0) == 1.0, "tablet / unknown -> desktop layout")
	check(VFData.ui_scale_for(200.0) <= 1.6, "tiny screens are capped")

	_test_v1()
	_test_idle()
	_test_rookie_rounds()
	_test_first_rebirth()
	_test_gerald()
	_test_finds()
	_test_collecting()
	_test_hats()
	process_frame.connect(_with_autoloads, CONNECT_ONE_SHOT)


## the tests that play the real mini-game need the autoloads, which exist from the first frame on
func _with_autoloads() -> void:
	_test_haptics()
	var v = load("res://tests/reel_bot.gd").vf()
	v.autosave = false                   # (the autoload holds the real save: it must never be written from here)
	v._apply(v._defaults.duplicate(true))
	_test_rookie_bots(v)
	_test_rival_bots(v)
	_test_lose_streak(v)
	_test_resident_timing(v)
	_test_counters(v)
	print("\n%s (%d failures)" % ["PASS" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)


## the phone's vibration stays short and gentle, whoever tunes it (docs/MISSING_LIST.md part 2)
func _test_haptics() -> void:
	print("== haptics")
	var H = load("res://scripts/vf/vf_haptics.gd")      # (not by its class name: it uses AudioManager, and this file compiles before the autoloads exist)
	var want := ["tap", "bite", "reel", "win", "lose", "rare", "shiny", "honk", "poke", "gerald"]
	check(want.all(func(k): return H.KINDS.has(k)) and H.KINDS.size() == want.size(), "all %d kinds are there" % want.size())
	var longest := 0
	var hardest := 0.0
	var pattern := 0
	for k in H.KINDS:
		var total := 0
		for p in H.KINDS[k]:
			longest = maxi(longest, p[0])
			hardest = maxf(hardest, p[1])
			total += p[0]
		pattern = maxi(pattern, total + (H.KINDS[k].size() - 1) * H.PAUSE_MS)
	check(longest <= 80 and hardest <= 0.6 and pattern <= 400, "gentle: longest pulse %d ms, strength %.2f, longest pattern %d ms" % [longest, hardest, pattern])
	check(H.KINDS.keys().filter(func(k): return H.KINDS[k].size() > 1).all(func(k): return k in ["rare", "shiny", "gerald"]), "only rare, shiny and gerald are patterns")
	check(not H._too_soon("reel") and H._too_soon("reel") and not H._too_soon("tap"), "the mini-game's ticks are thinned out, nothing else waits")


## the first rounds of Reel it in!: new games start in that mode, old saves don't, the first rounds are easier
func _test_rookie_rounds() -> void:
	print("== the first rounds of Reel it in!")
	var g = load("res://scripts/vf/vf_game.gd").new()
	g.autosave = false
	root.add_child(g)
	g._apply(g._defaults.duplicate(true))
	check(g.catch_mode == "reel" and g.reel_rounds == 0, "a new game starts in Reel it in! mode, with no rounds played")
	g.reel_rounds = 2
	var sd: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	g.reel_rounds = 0
	g._apply(sd)
	check(g.reel_rounds == 2 and g.catch_mode == "reel", "rounds played survive save -> load")
	var old: Dictionary = sd.duplicate(true)
	old.erase("catch_mode")
	old.erase("reel_rounds")
	g._apply(old)
	check(g.catch_mode == "relax" and g.reel_rounds == 0, "a save from before these fields stays on Relax")
	old = sd.duplicate(true)
	old.erase("reel_rounds")
	g._apply(old)
	check(g.catch_mode == "reel" and g.reel_rounds > VFData.ROOKIE_ROUNDS, "a save already on Reel it in! isn't a beginner: no easy rounds, no coach, no card")
	old = sd.duplicate(true)
	old["catch_mode"] = "relax"
	g._apply(old)
	check(g.catch_mode == "relax", "a player who chose Relax stays on Relax")
	g._apply(g._defaults.duplicate(true))
	g.reel_rounds = 5
	g.prestige = 0; g.level = 250; g.money = 5000000000
	g.charms = {}
	for id in VFData.CHARM_ORDER: g.charms[id] = 55
	g.do_prestige()
	check(g.reel_rounds == 5 and g.catch_mode == "reel", "prestige keeps your rounds and your catch mode")

	var seasoned: Dictionary = VFData.minigame_params(0, 0.0, false, VFData.ROOKIE_ROUNDS)
	check(seasoned == VFData.minigame_params(0, 0.0) and is_equal_approx(seasoned.zone_h, 0.34 + 0.035), "after the first rounds it's the normal game, unchanged")
	for desktop in [false, true]:
		var kinds := "phone" if not desktop else "desktop"
		var r0: Dictionary = VFData.minigame_params(0, 0.0, desktop, 0)
		var r1: Dictionary = VFData.minigame_params(0, 0.0, desktop, 1)
		var r2: Dictionary = VFData.minigame_params(0, 0.0, desktop, 2)
		var r3: Dictionary = VFData.minigame_params(0, 0.0, desktop, 3)
		check(r0.zone_h > r1.zone_h and r1.zone_h > r2.zone_h and r2.zone_h > r3.zone_h, "%s: the net shrinks to normal over three rounds (%.2f %.2f %.2f %.2f)" % [kinds, r0.zone_h, r1.zone_h, r2.zone_h, r3.zone_h])
		check(r0.drain_rate < r1.drain_rate and r1.drain_rate < r2.drain_rate and r2.drain_rate < r3.drain_rate, "%s: the ring slips less in the first rounds" % kinds)
		check(r0.fish_speed < r1.fish_speed and r1.fish_speed < r2.fish_speed and r2.fish_speed < r3.fish_speed, "%s: the fish is slower in the first rounds" % kinds)
		check(r0.time_limit > r1.time_limit and r1.time_limit > r2.time_limit and r2.time_limit > r3.time_limit, "%s: there's more time in the first rounds" % kinds)
	var rare: Dictionary = VFData.minigame_params(4, 0.0, false, 0)
	check(rare.zone_h == VFData.minigame_params(0, 0.0, false, 0).zone_h, "a rare fish on the very first round gets the same big net")

	# after lost rounds in a row the next round is eased a little; nothing changes for a player who isn't losing
	for desktop in [false, true]:
		var kind2 := "phone" if not desktop else "desktop"
		var s0: Dictionary = VFData.minigame_params(3, 0.2, desktop, VFData.ROOKIE_ROUNDS, 0)
		var s1: Dictionary = VFData.minigame_params(3, 0.2, desktop, VFData.ROOKIE_ROUNDS, 1)
		var s2: Dictionary = VFData.minigame_params(3, 0.2, desktop, VFData.ROOKIE_ROUNDS, 2)
		var s3: Dictionary = VFData.minigame_params(3, 0.2, desktop, VFData.ROOKIE_ROUNDS, 3)
		var s9: Dictionary = VFData.minigame_params(3, 0.2, desktop, VFData.ROOKIE_ROUNDS, 99)
		check(s0 == VFData.minigame_params(3, 0.2, desktop, VFData.ROOKIE_ROUNDS) and s1 == s0, "%s: no easing after 0 or 1 lost rounds" % kind2)
		check(s2.zone_h > s0.zone_h and s2.fish_speed < s0.fish_speed and s2.drain_rate < s0.drain_rate and s2.time_limit > s0.time_limit,
			"%s: after two lost rounds the net is bigger, the fish slower, the ring slips less and there's more time" % kind2)
		check(is_equal_approx(s2.fill_rate, s0.fill_rate), "%s: ...but the ring fills at the normal pace" % kind2)
		check(s3.zone_h > s2.zone_h and s3.fish_speed < s2.fish_speed, "%s: a little more after three" % kind2)
		check(s9 == VFData.minigame_params(3, 0.2, desktop, VFData.ROOKIE_ROUNDS, VFData.STREAK_EASE.size() - 1), "%s: ...and it stops at a limit" % kind2)
	check(VFData.minigame_params(3, 0.2, false, 0, 4) == VFData.minigame_params(3, 0.2, false, 0, 0), "a beginner's first rounds don't stack with it")
	check(VFData.minigame_params(3, 0.2, false, VFData.ROOKIE_ROUNDS, 4).zone_h < VFData.minigame_params(3, 0.2, false, 0, 0).zone_h, "...and it's never as easy as a beginner's very first round")
	g.reel_lose_streak = 3
	check(not g.to_dict().has("reel_lose_streak"), "the lost-round streak isn't saved (it starts again with the game)")
	g.reel_lose_streak = 0


## the first rebirth is within reach; the ones after it are as far as they were
func _test_first_rebirth() -> void:
	print("== the first rebirth")
	var g = load("res://scripts/vf/vf_game.gd").new()
	g.autosave = false
	root.add_child(g)
	g._apply(g._defaults.duplicate(true))
	var lv: int = VFData.prestige_level_req(0)
	var cash: int = VFData.prestige_money_req(0)
	check(lv < 250 and cash < 5000000000 and VFData.prestige_charm_req(0) == 0, "the first rebirth asks for less than the bot's P0 (Lv%d, $%s, no charms)" % [lv, g.fmt(cash)])
	g.level = lv
	g.money = cash - 1
	check(not g.prestige_check().ok and g.do_prestige() != "" and g.prestige == 0, "a dollar short: not yet")
	g.level = lv - 1
	g.money = cash
	check(not g.prestige_check().ok, "a level short: not yet")
	g.level = lv
	check(g.prestige_check().ok and g.prestige_check().charms == [0, 0], "the level and the money are enough, no charms needed")
	check(g.do_prestige() == "" and g.prestige == 1 and g.level == 1 and g.money == 0 and g.exotics.azure == 1, "reborn: back to level 1, with an Azure Fish")
	# the ones after it: each asks a little more than the last, none needs charms, and the level cap is still at the far end
	var more := true
	var gentle := true
	var no_charms := true
	var cap_at := -1
	for p in range(1, 300):
		var lv_p: int = VFData.prestige_level_req(p)
		var lv0: int = VFData.prestige_level_req(p - 1)
		var cash_p: int = VFData.prestige_money_req(p)
		var cash0: int = VFData.prestige_money_req(p - 1)
		if lv0 < 25000: more = more and lv_p > lv0
		else: more = more and lv_p == 25000
		if p <= 160: more = more and cash_p > cash0
		else: more = more and cash_p >= cash0
		gentle = gentle and float(lv_p) / lv0 <= 1.4 and cash_p <= 1000000000000000000
		no_charms = no_charms and VFData.prestige_charm_req(p) == 0
		if lv_p == 25000 and cap_at < 0: cap_at = p
	check(more, "every prestige asks for more level and more money than the one before")
	check(gentle, "never a big jump in level (at most 40% more; the perks make you faster too), and the money never overflows")
	check(no_charms, "no rebirth needs charms any more")
	check(cap_at >= 150 and cap_at <= 170, "the 25,000 level cap is still there at the far end (P%d)" % cap_at)
	check(VFData.prestige_level_req(1) > lv and VFData.prestige_level_req(1) < 100 and VFData.prestige_money_req(1) < 100000000, "the second rebirth: Lv%d and $%s (it was level 400, $8B and 528 charms)" % [VFData.prestige_level_req(1), g.fmt(VFData.prestige_money_req(1))])
	g.prestige = 1
	g.level = VFData.prestige_level_req(1)
	g.money = VFData.prestige_money_req(1)
	g.charms = {}
	check(g.prestige_check().ok and g.prestige_check().charms == [0, 0], "at P1 the level and the money are enough")
	g.money -= 1
	check(not g.prestige_check().ok, "... all of the money")
	g._apply(g._defaults.duplicate(true))
	check(VFData.charm_total_cap(0) == 440 and VFData.charm_total_cap(1) == 528 and g.charms_total() == 0, "the charm caps themselves don't change")
	# it's on the screen: the last starter goal is the rebirth, and you're told when it's ready
	var said := []
	g.toast.connect(func(text, _kind): said.append(text))
	g.level = lv
	g.money = cash
	g.goals_done = VFData.STARTER_GOALS.size() - 1
	var last: Dictionary = g.current_goal()
	var before: Dictionary = VFData.STARTER_GOALS[-2]
	check(before.goal == lv and str(lv) in before.text and last.id == "rebirth" and ("$" + g.fmt(cash)) in last.text and g.goal_progress(last) == 0,
		"the last starter goals are the first rebirth, with the real numbers: %s / %s" % [before.text, last.text])
	var guide := ""
	for entry in VFGuide.TABS["Prestige"]: guide += entry[2]
	for entry in VFGuide.TABS["Basics"]: guide += entry[2]
	check(("Level %d" % lv) in guide and ("$" + g.fmt(cash)) in guide and not "every charm" in guide, "the guide says the real numbers, and doesn't ask for every charm")
	g.check_goals()
	check(said.size() == 1 and "rebirth" in said[0].to_lower(), "you're told once when the rebirth is ready: %s" % ("" if said.is_empty() else said[0]))
	g.check_goals()
	check(said.size() == 1, "... only once")
	g.do_prestige()
	check(g.goals_done == VFData.STARTER_GOALS.size(), "being reborn finishes that goal")


## The Most Wanted, Gerald first: when each outlaw turns up, what winning and losing do, and that it all survives
func _test_gerald() -> void:
	print("== Gerald")
	var g = load("res://scripts/vf/vf_game.gd").new()
	g.autosave = false
	root.add_child(g)
	g._apply(g._defaults.duplicate(true))
	g.tutorial = 99
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vf/manifest.json"))
	check(manifest.mini.fish.has("Gerald") and FileAccess.file_exists("res://assets/vf/mini/gerald.png"), "Gerald has a picture for the mini-game")
	var looks := ["Gerald", "sizzle", "swordbeard", "baron", "chomp", "zlorp", "duchess"]
	var names := ["Gerald", "Sizzle", "Captain Swordbeard", "Baron von Flap", "Commander Chomp", "Zlorp", "The Duchess"]
	var looks_ok := true
	for i in VFData.GERALD.size():
		looks_ok = looks_ok and VFData.GERALD[i].get("look", "") == looks[i] and VFData.GERALD[i].who == names[i] and g.gerald_info(i).look == looks[i] and g.gerald_info(i).who == names[i]
	check(looks_ok, "every stage is a different outlaw with their own name and look, and gerald_info says which")
	check(VFData.GERALD.size() == 7 and VFData.GERALD[3].get("final", false) and VFData.GERALD[6].get("final", false) and not VFData.GERALD[0].get("final", false)
		and VFData.GERALD[3].hat == "crown" and VFData.GERALD[6].hat == "tiara" and VFData.GERALD[3].has("note"), "seven stages: the Baron ends the first run (crown, and the Duchess's note), the Duchess the second (tiara)")
	var rows_ok := true
	for row in VFData.GERALD:
		rows_ok = rows_ok and row.has("intro") and row.has("lose") and row.has("caught") and row.has("tease") and row.get("gags", []).size() >= 2 and float(row.get("size", 0.0)) > 0.0
		for k in ["first", "start", "escape", "caught", "almost"]:
			rows_ok = rows_ok and row.say.get(k, []).size() >= 2
	check(rows_ok, "every outlaw has an intro, lines for every moment, a tease, a size and their gags")
	var info: Dictionary = g.gerald_info()
	check(info.who == "Gerald" and info.biome == "River" and info.level == 10 and not info.met and not info.done and info.bounty > 0, "before anything happens: he's in the River, unmet")
	check(not g.gerald_due() and not g.gerald_soon(), "level 1: not yet")
	var first: int = VFData.gerald_need(0, 0)
	check(first == 80, "the first meeting is about 80 casts in")
	g.level = 10
	g.gerald.casts = first - 11
	check(not g.gerald_soon() and not g.gerald_due(), "level 10, %d casts: nothing yet" % g.gerald.casts)
	g.gerald.casts = first - 10
	check(g.gerald_soon() and not g.gerald_due(), "10 casts to go: the stage can tease him")
	g.gerald.casts = first
	check(g.gerald_due() and g.gerald_soon(), "level 10 and enough casts: he's due")
	g.tutorial = 2
	check(not g.gerald_due(), "he waits for the tutorial, like every toy")
	g.tutorial = 99
	g.level = 9
	check(not g.gerald_due(), "not below his level")
	g.level = 60
	g.biome = "Volcanic"
	check(not g.gerald_due() and not g.gerald_soon(), "not in another biome")
	g.biome = "River"
	g.gerald.casts = 0
	g._last_cast_ms = -100000
	g.cast()
	check(g.gerald.casts == 1, "a cast in his biome counts")
	for s in VFData.GERALD.size():
		check(VFData.gerald_need(s, 0) >= 60 and VFData.gerald_need(s, 0) <= 120, "stage %d: every %d casts" % [s, VFData.gerald_need(s, 0)])
	# losing costs nothing, and he comes back sooner
	g.rod = "Plastic Rod"
	g.level = 10
	g.gerald.casts = first
	var m0: int = g.money
	var lost: Dictionary = g.gerald_result(false)
	check(not lost.caught and not lost.escaped and lost.pay > 0 and g.money == m0 + lost.pay and lost.line != "" and lost.stage == 0, "he wins: he laughs and pays a little ($%d): %s" % [lost.pay, lost.line])
	check(g.gerald.stage == 0 and g.gerald.tries == 1 and g.gerald.losses == 1 and g.gerald.casts == 0, "he stays where he is, and the casts start over")
	check(is_equal_approx(g.cur_cooldown(), g.cooldown()), "a lost round: the normal cooldown")
	var need1: int = VFData.gerald_need(0, 1)
	var need2: int = VFData.gerald_need(0, 2)
	check(need1 < first and need2 < need1 and VFData.gerald_need(0, 50) >= 20, "he comes back sooner each time (%d, %d casts), never at once" % [need1, need2])
	# winning a stage: the outlaw is caught for good, the bounty, and the next one is wanted
	g.gerald.casts = need1
	check(g.gerald_due(), "he's back")
	m0 = g.money
	var won: Dictionary = g.gerald_result(true)
	check(won.caught and not won.escaped and won.hat == "" and won.pay > lost.pay and g.money == m0 + won.pay and won.line != "" and won.stage == 0, "you win: Gerald is caught for good, the bounty ($%d): %s" % [won.pay, won.line])
	check(g.gerald.stage == 1 and g.gerald.tries == 0 and g.gerald.wins == 1 and g.gerald.casts == 0 and g.gerald_info().biome == "Volcanic" and g.gerald_info().who == "Sizzle", "the next outlaw, Sizzle, is wanted in the Volcano")
	check(g.gerald_info().met and not g.gerald_due(), "you've met now, and nobody is due in the River any more")
	check(absf(g.cur_cooldown() - VFData.MINIGAME_COOLDOWN) < 0.001, "a won round: the next cast is ready like after any win")
	# Baron von Flap's stage: caught, and the crown
	g.gerald.stage = 3
	g.level = 250
	g.biome = "Sky"
	g.rod = "Infinity Rod"
	g.gerald.casts = VFData.gerald_need(3, 0)
	check(g.gerald_due(), "stage 4: the Sky at level 250")
	check(not "crown" in g.hats_owned, "no crown yet")
	var caught: Dictionary = g.gerald_result(true)
	check(caught.caught and not caught.escaped and caught.pay > 0 and caught.hat == "crown" and "crown" in g.hats_owned and not "tiara" in g.hats_owned, "the Baron is caught: a big payout ($%d) and the crown: %s" % [caught.pay, caught.line])
	check(g.gerald_info().who == "Commander Chomp" and g.gerald_info().biome == "Space" and not g.gerald_info().done, "then run two starts with Commander Chomp")
	g.gerald.stage = 6
	g.level = 2500
	g.biome = "Abyss"
	g.rod = "Dark Rod"
	g.gerald.casts = VFData.gerald_need(6, 0)
	var duchess: Dictionary = g.gerald_result(true)
	check(duchess.caught and duchess.hat == "tiara" and "tiara" in g.hats_owned and g.gerald_info().done, "The Duchess gives the tiara, and that's the end of it")
	check(not g.gerald_due() and not g.gerald_soon(), "all done: nobody's due")
	var after: Dictionary = g.gerald_result(true)
	check(after.pay == 0 and not after.caught and int(g.gerald.stage) == 7, "a stray result after the end changes nothing")
	var poster: Dictionary = g.gerald_info(1)
	check(poster.who == "Sizzle" and poster.biome == "Volcanic" and poster.bounty > 0 and poster.done, "a poster for any stage: stage 2 is Sizzle, and stamped")
	# it survives
	g._apply(g._defaults.duplicate(true))
	g.gerald = {"stage": 2, "casts": 17, "tries": 3, "wins": 2, "losses": 5}
	g.hats_owned = ["straw", "crown"]
	var sd: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	g._apply(g._defaults.duplicate(true))
	g._apply(sd)
	check(g.gerald.stage == 2 and g.gerald.casts == 17 and g.gerald.tries == 3 and g.gerald.wins == 2 and g.gerald.losses == 5 and "crown" in g.hats_owned, "Gerald survives save -> load")
	var old: Dictionary = sd.duplicate(true)
	old.erase("gerald")
	old.erase("hats_owned")
	g._apply(old)
	check(g.gerald.stage == 0 and g.gerald.casts == 0 and g.hats_owned == ["straw"], "a save from before Gerald loads with him unmet")
	old = sd.duplicate(true)
	old["gerald"] = {"stage": 99, "casts": -5}
	g._apply(old)
	check(g.gerald.stage == 7 and g.gerald.casts == 0 and g.gerald.losses == 0, "a damaged save can't break him")
	g._apply(sd)
	g.prestige = 0; g.level = VFData.prestige_level_req(0); g.money = VFData.prestige_money_req(0)
	g.do_prestige()
	check(g.gerald.stage == 2 and g.gerald.losses == 5 and "crown" in g.hats_owned, "Gerald and the hats survive prestige")
	var easy: Dictionary = VFData.rival_params(0, 0.1, false, 3, 99)
	var hard: Dictionary = VFData.rival_params(0, 0.1, false, 0, 99)
	var tough: Dictionary = VFData.rival_params(4, 0.1, false, 0, 99)
	check(easy.zone_h > hard.zone_h and easy.fish_speed < hard.fish_speed and easy.drain_rate < hard.drain_rate and easy.time_limit > hard.time_limit, "they get easier every time you lose to them")
	check(tough.zone_h < hard.zone_h and tough.fish_speed > hard.fish_speed, "run two's outlaws are harder")


## finds when sailing: the 21 residents, what tapping one pays, which one turns up next, and that they're kept
func _test_finds() -> void:
	print("== finds")
	var g = load("res://scripts/vf/vf_game.gd").new()
	g.autosave = false
	root.add_child(g)
	g._apply(g._defaults.duplicate(true))
	var want := {"River": ["otter", "frog", "old_boot"], "Volcanic": ["capybara", "lava_crab", "marshmallow"], "Ocean": ["turtle", "fake_fin", "treasure"],
		"Sky": ["cloud_sheep", "kite", "paper_plane"], "Space": ["astro_cat", "satellite", "space_duck"], "Alien": ["ufo", "blob", "glow_shroom"],
		"Abyss": ["anglerfish", "tiny_sub", "sunken_tv"]}
	var ok := VFData.FINDS.size() == VFData.BIOME_ORDER.size()
	for b in want:
		var ids: Array = VFData.FINDS[b].keys()
		ok = ok and ids == want[b] and VFData.FINDS[b][want[b][2]].rare and not VFData.FINDS[b][want[b][0]].rare and not VFData.FINDS[b][want[b][1]].rare
		for id in ids:
			var d: Dictionary = VFData.FINDS[b][id]
			ok = ok and String(d.name) != "" and String(d.line) != "" and VFData.find_def(id) == d
	check(ok and VFData.finds_total() == 21, "every biome has its three finds, and the third is the rare one (%d in all)" % VFData.finds_total())
	check(VFData.find_def("nope").is_empty(), "an unknown id isn't a find")
	var longest := 0
	for b in VFData.FINDS:
		for id in VFData.FINDS[b]: longest = maxi(longest, String(VFData.FINDS[b][id].line).length())
	check(longest <= 70, "every line fits the captain's one-line bubble (longest: %d characters)" % longest)
	# tapping one
	var worth: int = g.find_value(VFData.FIND_FIRST)
	var m0: int = g.money
	var r1: Dictionary = g.find_tapped("otter")
	check(r1.first and r1.pay == worth and g.money == m0 + worth and r1.line == VFData.FINDS.River.otter.line and g.finds.otter == 1, "the first otter pays about 10 casts' worth ($%d) and says its line" % r1.pay)
	check(absf(float(worth) / g.find_value(1.0) - 10.0) < 0.5 and VFData.FIND_FIRST == 10.0 and VFData.FIND_AGAIN == 0.5, "the numbers from the missing list")
	var r2: Dictionary = g.find_tapped("otter")
	check(not r2.first and r2.pay == 0 and g.finds.otter == 2 and r2.line != "", "tapping it again right away pays nothing, but it still counts and still talks")
	g._find_paid_at -= VFData.FIND_PAY_CD + 1.0
	var r3: Dictionary = g.find_tapped("otter")
	check(not r3.first and r3.pay == g.find_value(VFData.FIND_AGAIN) and r3.pay < r1.pay, "after the cooldown a repeat pays a little ($%d)" % r3.pay)
	check(g.find_tapped("otter").pay == 0, "... and the cooldown starts over")
	var r4: Dictionary = g.find_tapped("frog")
	check(r4.first and r4.pay > 0, "a new find always pays, cooldown or not")
	m0 = g.money
	var bad: Dictionary = g.find_tapped("nope")
	check(not bad.first and bad.pay == 0 and bad.line == "" and g.money == m0 and not g.finds.has("nope"), "an unknown id does nothing")
	check(g.finds.size() == 2, "2 of 21 found")
	# what turns up next
	g.finds = {}
	g.biome = "Ocean"
	var seen := {}
	for i in 400: seen[g.find_pick()] = true
	check(seen.keys().size() == 2 and seen.has("turtle") and seen.has("fake_fin"), "nothing found yet: the two common ones of this biome come first (%s)" % [seen.keys()])
	g.finds = {"turtle": 1}
	seen = {}
	for i in 100: seen[g.find_pick()] = true
	check(seen.keys() == ["fake_fin"], "the one you haven't found comes before the one you have")
	g.finds = {"turtle": 1, "fake_fin": 3}
	var rare := 0
	for i in 2000:
		if g.find_pick() == "treasure": rare += 1
	check(absf(rare / 2000.0 - VFData.FIND_RARE) < 0.05, "both found: the rare one turns up %d%% of the time" % int(rare / 20.0))
	g.finds = {"turtle": 1, "fake_fin": 3, "treasure": 1}
	rare = 0
	for i in 2000:
		if g.find_pick() == "treasure": rare += 1
	check(absf(rare / 2000.0 - VFData.FIND_RARE) < 0.05, "all found: they keep turning up, the rare one less often (%d%%)" % int(rare / 20.0))
	for b in VFData.BIOME_ORDER:
		g.biome = b
		check(VFData.FINDS[b].has(g.find_pick()), "%s: only its own finds turn up" % b)
	# they're kept
	g.finds = {"otter": 4, "treasure": 1}
	var sd: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	g.finds = {}
	g._apply(sd)
	check(g.finds == {"otter": 4, "treasure": 1}, "finds survive save -> load")
	var old: Dictionary = sd.duplicate(true)
	old.erase("finds")
	g._apply(old)
	check(g.finds.is_empty(), "a save from before finds has none")
	old = sd.duplicate(true)
	old["finds"] = {"otter": 2, "not_a_find": 9}
	g._apply(old)
	check(g.finds == {"otter": 2}, "ids that don't exist are dropped")
	g._apply(sd)
	g.prestige = 0; g.level = VFData.prestige_level_req(0); g.money = VFData.prestige_money_req(0)
	g.do_prestige()
	check(g.finds.otter == 4, "finds survive prestige")


## collecting pays off: achievements, the Fish Book's stamps, the aquarium's visitors
func _test_collecting() -> void:
	print("== achievements")
	var g = load("res://scripts/vf/vf_game.gd").new()
	g.autosave = false
	root.add_child(g)
	g._apply(g._defaults.duplicate(true))
	var ids := {}
	var jokes := 0
	var well_formed := true
	for a in VFData.ACHIEVEMENTS:
		ids[a.id] = true
		well_formed = well_formed and String(a.name) != "" and String(a.desc) != "" and String(a.stat) != "" and int(a.goal) > 0 and int(a.pearls) > 0 and int(a.pearls) <= 25
		if a.get("joke", false): jokes += 1
	check(ids.size() == VFData.ACHIEVEMENTS.size() and ids.size() >= 28 and ids.size() <= 36 and well_formed, "about 30 achievements (%d), each with a goal and a few Pearls" % ids.size())
	check(jokes * 2 >= ids.size() - 4, "about half of them are jokes (%d)" % jokes)
	check(g.ach_ready().is_empty(), "a new game has nothing to claim")
	check(g.ach_claim("first_fish") == 0 and g.pearls == 0, "you can't claim what you haven't done")
	check(g.ach_claim("nope") == 0, "an unknown id does nothing")
	g.stat_add("honks")
	g.stat_add("honks", 98)
	check(g.stats.honks == 99 and not "honks_100" in g.ach_ready(), "99 honks: not yet")
	g.stat_add("honks")
	check("honks_100" in g.ach_ready(), "100 honks: ready to claim")
	var def: Dictionary = VFData.ach_def("honks_100")
	check(g.ach_claim("honks_100") == int(def.pearls) and g.pearls == int(def.pearls) and g.ach_claimed.has("honks_100"), "claiming pays its Pearls (%d)" % def.pearls)
	check(g.ach_claim("honks_100") == 0 and g.pearls == int(def.pearls) and not "honks_100" in g.ach_ready(), "only once")
	# what it reads from the game itself
	g.level = 100
	g.prestige = 1
	g.discovered = {"Cod": 3, "Squid": 1}
	g.finds = {"otter": 2, "frog": 1}
	g.crews = 5
	g.ducks = 12
	g.gerald = {"stage": 4, "casts": 0, "tries": 0, "wins": 4, "losses": 6}
	g.hats_owned = ["straw", "crown"]
	check(g.stat_value("level") == 100 and g.stat_value("prestige") == 1 and g.stat_value("species") == 2 and g.stat_value("finds") == 2 and g.stat_value("crews") == 5
		and g.stat_value("ducks") == 12 and g.stat_value("gerald_losses") == 6 and g.stat_value("gerald_caught") == 1 and g.stat_value("mum_caught") == 0 and g.stat_value("hats") == 2,
		"it knows your level, species, finds, crews, ducks, hats and how it's going with Gerald")
	check("gerald_5" in g.ach_ready() and "gerald_caught" in g.ach_ready() and "ducks_10" in g.ach_ready() and not "ducks_50" in g.ach_ready() and "rebirth" in g.ach_ready(), "the jokes count too")
	# nothing is lost to a rebirth
	g.level = maxi(100, VFData.prestige_level_req(1))
	g.money = VFData.prestige_money_req(1)
	for id in VFData.CHARM_ORDER: g.charms[id] = VFData.charm_total_cap(1) / 8
	g.stat_add("voyages", 3)
	g.do_prestige()
	check(g.level == 1 and g.crews == 0 and g.stat_value("level") >= 100 and g.stat_value("crews") == 5 and g.stats.voyages == 3 and "level_100" in g.ach_ready() and "crews_5" in g.ach_ready(), "a rebirth doesn't take back what you've done")
	check(g.ach_claimed.has("honks_100"), "... or what you've claimed")
	var sd: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	g.stats.erase("honks")
	g.ach_claimed = {}
	g._apply(sd)
	check(g.stats.honks == 100 and g.ach_claimed.has("honks_100") and g.ach_claim("honks_100") == 0, "stats and claims survive save -> load")
	var old: Dictionary = sd.duplicate(true)
	old.erase("ach_claimed")
	g._apply(old)
	check(g.ach_claimed.is_empty(), "a save from before achievements has none claimed")
	old = sd.duplicate(true)
	old["ach_claimed"] = {"honks_100": true, "not_a_thing": true}
	g._apply(old)
	check(g.ach_claimed.has("honks_100") and not g.ach_claimed.has("not_a_thing"), "ids that don't exist are dropped")

	print("== the Fish Book")
	g._apply(g._defaults.duplicate(true))
	g.level = 30
	var base: float = g.sell_mult()
	check(g.book_bonus("River") == 0.0 and not g.book_done("River"), "nothing caught: no stamp")
	for f in VFData.BIOMES.River.fish.slice(0, 4): g.discovered[f] = 1
	check(g.book_bonus("River") == 0.0, "four of the five: no stamp yet")
	g.discovered[VFData.BIOMES.River.fish[4]] = 1
	check(g.book_done("River") and is_equal_approx(g.book_bonus("River"), 0.05) and g.book_bonus("Abyss") == 0.0, "all five: a stamp and +5% in the River, not elsewhere")
	check(is_equal_approx(g.sell_mult(), base * 1.05), "you sell for +5% in the River")
	g.biome = "Abyss"
	check(is_equal_approx(g.sell_mult(), base), "... and not anywhere else")
	g.biome = "River"
	g.prestige = 0; g.level = VFData.prestige_level_req(0); g.money = VFData.prestige_money_req(0)
	g.do_prestige()
	check(g.book_done("River"), "stamps are permanent: they survive prestige")
	check(g.stat_value("books") == 1 and "book_1" in g.ach_ready(), "and the first stamp is an achievement")

	print("== the aquarium")
	g._apply(g._defaults.duplicate(true))
	check(g.aquarium_income() == 0.0, "an empty aquarium has no visitors")
	g.discovered = {"Cod": 1}
	check(is_equal_approx(g.aquarium_income(), VFData.AQUARIUM_MAX / VFData.FISH_ORDER.size()), "every species brings some")
	for f in VFData.FISH_ORDER: g.discovered[f] = 1
	check(is_equal_approx(g.aquarium_income(), 0.30), "every species: +30%")
	g.discovered["Not a fish"] = 1
	check(g.aquarium_income() <= 0.30 + 1e-6, "and never more than that")
	g.discovered.erase("Not a fish")
	g.level = 10
	g.crews = 2
	g.biome = "River"
	var now := Time.get_unix_time_from_system()
	g.discovered = {}
	g.idle_seen = now - 3600.0
	g.offline = {}
	g.offline_check()
	var plain: int = g.offline.n
	check(g.offline.aquarium == 0.0, "an empty aquarium adds nothing while you're away")
	for f in VFData.FISH_ORDER: g.discovered[f] = 1
	g.idle_seen = now - 3600.0
	g.offline = {}
	g.offline_check()
	check(absf(float(g.offline.n) / plain - 1.3) < 0.02 and is_equal_approx(g.offline.aquarium, 0.30), "a full one: +30%% on the catch while you're away (%d -> %d fish), and the card can say so" % [plain, g.offline.n])
	var osd: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	g._apply(osd)
	check(g.offline.has("aquarium") and is_equal_approx(g.offline.aquarium, 0.30), "it survives save -> load with the waiting catch")


## hats: bought with money, the special ones earned, and they buy nothing but laughs
func _test_hats() -> void:
	print("== hats")
	var g = load("res://scripts/vf/vf_game.gd").new()
	g.autosave = false
	root.add_child(g)
	g._apply(g._defaults.duplicate(true))
	var slugs := ["straw", "pirate", "chef", "propeller", "viking", "traffic_cone", "top_hat", "sombrero", "duck", "crown", "tiara", "derby_cup"]
	var well_formed := true
	for id in slugs:
		var d: Dictionary = VFData.HATS.get(id, {})
		well_formed = well_formed and String(d.get("name", "")) != "" and d.has("price") and not d.has("pearls")
	check(VFData.HATS.size() == slugs.size() and VFData.HAT_ORDER == slugs and well_formed, "the eleven hats of the missing list and the Derby Cup, none of them for Pearls")
	check(g.hats_owned == ["straw"] and g.hat == "straw", "a new game: the straw hat, and he's wearing it")
	check(g.hat_price("straw") == 0 and g.hat_lock("straw") == "", "the straw hat is free")
	# buying
	g.money = 0
	check(g.buy_hat("pirate") != "" and not "pirate" in g.hats_owned and g.hat == "straw", "no money, no hat")
	var price: int = g.hat_price("pirate")
	check(price > 0, "the pirate hat costs $%d for a new player" % price)
	g.money = price + 5
	check(g.buy_hat("pirate") == "" and "pirate" in g.hats_owned and g.money == 5 and g.hat == "pirate", "buying costs its price, and he puts it on")
	g.money = price
	check(g.buy_hat("pirate") != "" and g.money == price, "you can't buy it twice")
	check(g.buy_hat("nope") != "" and g.money == price and not "nope" in g.hats_owned, "there's no such hat")
	# wearing
	g.wear_hat("straw")
	check(g.hat == "straw", "any hat you own goes on")
	g.wear_hat("chef")
	check(g.hat == "straw", "not one you don't own")
	g.wear_hat("nope")
	check(g.hat == "straw", "not one that doesn't exist")
	# prices follow your progress, and rise along the list
	var rising := true
	var last := 0
	for id in ["pirate", "chef", "propeller", "viking", "traffic_cone", "top_hat", "sombrero"]:
		rising = rising and g.hat_price(id) > last
		last = g.hat_price(id)
	check(rising, "they cost more along the list")
	var early: int = g.hat_price("viking")
	g.level = 500
	g.rod = "Space Rod"
	g.biome = "Space"
	g.boats_owned = 6
	check(g.hat_price("viking") > early * 100, "prices scale with progress ($%d, later $%d)" % [early, g.hat_price("viking")])
	g.rod = "Plastic Rod"
	g.biome = "River"
	g.boats_owned = 0
	g.level = 1
	# earned ones
	g.money = 1000000000
	g.ducks = 24
	check(g.buy_hat("duck") != "" and "25" in g.hat_lock("duck") and not "duck" in g.hats_owned, "the duck hat needs 25 rubber ducks: %s" % g.hat_lock("duck"))
	g.ducks = 25
	var m0: int = g.money
	check(g.hat_lock("duck") == "" and g.buy_hat("duck") == "" and "duck" in g.hats_owned and g.money == m0, "at 25 it's yours, free")
	check(g.buy_hat("crown") != "" and g.buy_hat("tiara") != "" and not "crown" in g.hats_owned and not "tiara" in g.hats_owned and g.money == m0, "no amount of money buys the crown or the tiara")
	check(g.hat_lock("crown") != "" and g.hat_lock("tiara") != "", "they say how to get them: %s / %s" % [g.hat_lock("crown"), g.hat_lock("tiara")])
	g.gerald = {"stage": 3, "casts": 0, "tries": 0, "wins": 3, "losses": 0}
	g.gerald_result(true)
	g.wear_hat("crown")
	check(g.hat == "crown" and g.hat_lock("crown") == "", "catch Gerald and the crown goes on")
	# nothing but laughs
	var before := [g.fish_catch_mult(), g.fish_quality_mult(), g.sell_mult(), g.xp_mult(), g.treasure_chance(), g.treasure_quality(), g.cooldown(), g.crew_trip_secs(), g.offline_rate(), VFData.rod_reel_power(g.rod)]
	var same := true
	for id in g.hats_owned:
		g.wear_hat(id)
		same = same and before == [g.fish_catch_mult(), g.fish_quality_mult(), g.sell_mult(), g.xp_mult(), g.treasure_chance(), g.treasure_quality(), g.cooldown(), g.crew_trip_secs(), g.offline_rate(), VFData.rod_reel_power(g.rod)]
	check(same, "hats change nothing: catch, quality, price, XP, treasure, cooldown, crews, reel power")
	# they're kept
	g.wear_hat("duck")
	var sd: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	g.hat = "straw"
	g.hats_owned = ["straw"]
	g._apply(sd)
	check(g.hat == "duck" and "pirate" in g.hats_owned and "crown" in g.hats_owned, "hats survive save -> load")
	var old: Dictionary = sd.duplicate(true)
	old.erase("hat")
	old.erase("hats_owned")
	g._apply(old)
	check(g.hat == "straw" and g.hats_owned == ["straw"], "a save from before hats: the straw hat")
	old = sd.duplicate(true)
	old["hats_owned"] = ["pirate", "not_a_hat", "pirate"]
	old["hat"] = "tiara"
	g._apply(old)
	check(g.hats_owned == ["straw", "pirate"] and g.hat == "straw", "a damaged save: hats that don't exist are dropped, and he never wears one he doesn't own")
	g._apply(sd)
	g.prestige = 0; g.level = VFData.prestige_level_req(0); g.money = VFData.prestige_money_req(0)
	g.do_prestige()
	check(g.hat == "duck" and "pirate" in g.hats_owned and "crown" in g.hats_owned, "hats survive prestige")
	check(g.stat_value("hats") == g.hats_owned.size(), "they count for Hat Person")


## the places that count: every stat an achievement needs goes up when the thing happens
func _test_counters(v) -> void:
	print("== what counts")
	v._apply(v._defaults.duplicate(true))
	v.tutorial = 99
	v.biome = "River"
	var known := ["level", "prestige", "species", "finds", "books", "crews", "ducks", "hats", "gerald_losses", "gerald_caught", "mum_caught",
		"fish", "trips", "chests", "money_earned", "honks", "robbed", "thieves", "crab_pokes", "gull_pokes", "bottles", "reel_wins", "reel_losses", "perfect_rounds", "blanks", "glass_taps", "voyages"]
	var all_known := true
	for a in VFData.ACHIEVEMENTS:
		if not a.stat in known:
			all_known = false
			print("  unknown stat: ", a.stat)
	check(all_known, "every achievement's stat is one that's counted")
	var Fun = load("res://scripts/vf/vf_fun.gd")
	var m := FunMain.new()
	m.stage = FunStageWithResidents.new()
	m.tree_root = root
	var f = Fun.new(m)
	for kind in ["crab", "gull", "bottle", "thief", "thief_away"]:
		m.stage.poked.emit(kind, Vector2.ZERO)
	check(v.stats.get("crab_pokes", 0) == 1 and v.stats.get("gull_pokes", 0) == 1 and v.stats.get("bottles", 0) == 1 and v.stats.get("thieves", 0) == 1 and v.stats.get("robbed", 0) == 1,
		"poking counts: crabs, gulls, bottles, thieves stopped, and being robbed")
	f.honk()
	check(v.stats.get("honks", 0) == 1, "honking counts")
	var d0: int = v.ducks
	m.stage.poked.emit("duck", Vector2.ZERO)
	check(v.ducks == d0 + 1, "ducks count themselves")
	var Bot = load("res://tests/reel_bot.gd")
	seed(99)
	v.reel_rounds = VFData.ROOKIE_ROUNDS
	v.rod = "Dark Rod"
	v.stats.erase("reel_wins")
	v.stats.erase("reel_losses")
	Bot.play(self, "sharp", "Raw Fish", 0)
	check(v.stats.get("reel_wins", 0) == 1, "winning a round counts")
	v.rod = "Plastic Rod"
	for i in 10: Bot.play(self, "hold", "Dark Tuna", 4)
	check(v.stats.get("reel_losses", 0) >= 1, "losing a round counts (%d of 10)" % v.stats.get("reel_losses", 0))
	var wins0: int = v.stats.get("reel_wins", 0)
	var losses0: int = v.stats.get("reel_losses", 0)
	Bot.play_rival(self, "sharp", 0)
	check(v.stats.get("reel_wins", 0) == wins0 and v.stats.get("reel_losses", 0) == losses0, "a round against Gerald counts for Gerald, not for these")
	v.level = 100
	v.stats.erase("voyages")
	check(v.select_biome("Volcanic") == "" and v.stats.get("voyages", 0) == 1, "sailing to another biome counts")
	check(v.select_biome("Volcanic") == "" and v.stats.get("voyages", 0) == 1, "staying where you are doesn't")
	check(v.select_biome("Abyss") != "" and v.stats.get("voyages", 0) == 1, "and neither does a trip you can't make")
	v.biome = "River"
	v._apply(v._defaults.duplicate(true))


## stand-ins for what vf_fun.gd asks of vf_main and the stage
class FunStage:
	signal poked(kind: String, at: Vector2)
	var night_amount := 0.0
	var said := ""
	func spawn_find(_kind: String) -> void: pass
	func spawn_thief() -> void: pass
	func say(text: String, _secs := 3.4) -> void: said = text
	func to_screen(p: Vector2) -> Vector2: return p
	func on_honk() -> void: pass

class FunStageWithResidents extends FunStage:
	var sent := []
	func spawn_resident(id: String) -> void: sent.append(id)

class FunUI:
	func coins_to_wallet(_from: Vector2, _n: int) -> void: pass

class FunMain:
	var stage
	var size := Vector2(1280, 720)               # (the game's own area, as in vf_main.gd: beside a docked phone it's narrower than the window)
	var v1 := FunUI.new()
	var overlay := {"visible": false}
	var minigame = null
	var sail := {"state": "idle"}
	var C_GOLD := Color.GOLD
	var banners := []
	var tree_root: Node
	func launcher_open() -> bool: return false
	func _phone_open() -> bool: return false
	func money_str(n: float) -> String: return "$%d" % int(n)
	func _float_text(_t: String, _at: Vector2, _c: Color) -> void: pass
	func _toast(_t: String, _k: String) -> void: pass
	func ph(_n: String) -> Texture2D: return null
	func _banner(title: String, _sub: String, _tex: Texture2D, _col: Color) -> void: banners.append(title)
	func sbox(_c = null, _r = 0, _b = 0, _bc = null, _s = 0, _p = 0) -> StyleBoxFlat: return StyleBoxFlat.new()
	func lbl(text = "", _size = 16, _col = null, _outline = 0) -> Label:
		var l := Label.new()
		l.text = str(text)
		return l
	func add_child(n: Node) -> void: tree_root.add_child(n)
	func get_viewport_rect() -> Rect2: return Rect2(0, 0, 1280, 720)


## when a find turns up: one at a time, gone after FIND_SECS, never during a panel or the tutorial, safe until the stage can show one
func _test_resident_timing(v) -> void:
	print("== when a find turns up")
	v._apply(v._defaults.duplicate(true))
	v.tutorial = 99
	v.biome = "River"
	var Fun = load("res://scripts/vf/vf_fun.gd")
	var plain := FunMain.new()
	plain.stage = FunStage.new()
	var f1 = Fun.new(plain)
	for i in 400: f1.tick(1.0)
	check(true, "no spawn_resident on the stage yet: nothing happens, nothing breaks")
	var m := FunMain.new()
	var st := FunStageWithResidents.new()
	m.stage = st
	var f = Fun.new(m)
	var t := 0.0
	var at := []
	var gaps_ok := true
	while t < 1800.0:
		f.tick(1.0)
		t += 1.0
		while at.size() < st.sent.size(): at.append(t)
	for i in range(1, at.size()):
		if at[i] - at[i - 1] < VFData.FIND_SECS + VFData.FIND_WAIT[0] - 1.0 or at[i] - at[i - 1] > VFData.FIND_SECS + VFData.FIND_WAIT[1] + 1.0: gaps_ok = false
	check(at.size() >= 7 and gaps_ok, "one at a time: %d in half an hour, none while the last is still out" % at.size())
	check(st.sent[0] in ["otter", "frog"], "the first one is a common one you haven't found (%s)" % st.sent[0])
	var n: int = st.sent.size()
	m.overlay.visible = true
	for i in 400: f.tick(1.0)
	check(st.sent.size() == n, "nothing new turns up behind an open panel")
	m.overlay.visible = false
	v.tutorial = 2
	for i in 400: f.tick(1.0)
	check(st.sent.size() == n, "toys wait for the tutorial")
	v.tutorial = 99
	f._resident_left = 50.0
	var money0: int = v.money
	st.poked.emit("find:old_boot", Vector2(100, 100))
	check(st.said == VFData.FINDS.River.old_boot.line and v.money > money0 and m.banners.size() == 1 and v.finds.has("old_boot") and f._resident_left <= 0.0,
		"tapping one: it says its line, pays, gets its banner, and the next can come")
	st.poked.emit("find:old_boot", Vector2(100, 100))
	check(m.banners.size() == 1 and v.finds.old_boot == 2, "the banner is only for the first time")
	st.poked.emit("crab", Vector2(100, 100))
	check(v.finds.size() == 1, "a crab isn't a find")
	check(f.catch_line({"count": 0, "chest": {"tier": "rare"}}) == "" and f.catch_line({"count": 0, "chest": {}}) != "", "a goal's chest card doesn't say the fish are on a break")
	v._apply(v._defaults.duplicate(true))


## Gerald in the real mini-game: a rival round works without his art, he's a real fight, and nobody gets stuck
## Reel it in!, in the real mini-game: lost rounds in a row are counted (not the outlaws'), the round after them is eased,
## and a win puts it back
func _test_lose_streak(v) -> void:
	print("== Reel it in!: lost rounds in a row, played by bots")
	var Bot = load("res://tests/reel_bot.gd")
	var MG = load("res://scripts/vf/vf_minigame.gd")
	seed(20261111)
	v._apply(v._defaults.duplicate(true))
	v.reel_rounds = VFData.ROOKIE_ROUNDS
	v.rod = "Plastic Rod"
	v.reel_lose_streak = 0
	var lost := 0
	for i in 3:
		if not Bot.play(self, "idle", "Raw Fish", 3, true).won: lost += 1
	check(lost == 3 and v.reel_lose_streak == 3, "three lost rounds in a row are counted (%d lost, streak %d)" % [lost, v.reel_lose_streak])
	var stub = Bot.StubMain.new()
	var eased_round: Control = MG.new()
	eased_round.setup(stub, "Raw Fish", 3)
	var eased_net: float = eased_round.zone_h
	eased_round.free()
	v.reel_lose_streak = 0
	var plain_round: Control = MG.new()
	plain_round.setup(stub, "Raw Fish", 3)
	var plain_net: float = plain_round.zone_h
	plain_round.free()
	check(eased_net > plain_net, "...and the round after them has a bigger net (%.2f against %.2f)" % [eased_net, plain_net])
	v.reel_lose_streak = 3
	var won := false
	for i in 4:                                         # (a sharp player wins a common fish: one of a few tries is enough)
		if Bot.play(self, "sharp", "Raw Fish", 0, true).won:
			won = true
			break
	check(won and v.reel_lose_streak == 0, "a win puts it back to normal (streak %d)" % v.reel_lose_streak)
	v.reel_lose_streak = 2
	v.reel_rounds = VFData.ROOKIE_ROUNDS
	v.gerald.stage = 0
	Bot.play_rival(self, "idle", 0)
	check(v.reel_lose_streak == 2, "a lost round against an outlaw isn't counted (they have their own easing)")
	v.reel_lose_streak = 0
	v.gerald.tries = 0

func _test_rival_bots(v) -> void:
	print("== Gerald, played by bots")
	var Bot = load("res://tests/reel_bot.gd")
	seed(20261102)
	var MG = load("res://scripts/vf/vf_minigame.gd")
	check(not "Gerald" in MG.NAMES, "only the rival is called Gerald")
	var gags_ok := true
	for row in VFData.GERALD:
		for gag in row.gags:
			gags_ok = gags_ok and MG.GAGS.has(gag)
	check(gags_ok, "every gag the outlaws pull exists")
	var real: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vf/manifest.json"))
	check(MG.rival_picture(real, "Gerald", "Gerald") == "Gerald", "the River stage plays plain Gerald")
	check(MG.rival_picture({}, "sizzle", "Gerald") == "Gerald" and MG.rival_picture({"mini": {"fish": {"sizzle": {}}}}, "no_such_look", "Gerald") == "Gerald",
		"a look whose picture or manifest entry is missing falls back to plain Gerald")
	var ready := 0
	for i in VFData.GERALD.size():
		var row: Dictionary = VFData.GERALD[i]
		var want: String = row.look if (real.mini.fish.has(row.look) and ResourceLoader.exists("res://assets/vf/mini/%s.png" % VFData.slug(row.look))) else "Gerald"
		var stub = Bot.StubMain.new()
		stub.stage.manifest = real
		v.gerald.stage = i
		var mg: Control = MG.new()
		mg.setup_rival(stub)
		if mg.fish_name == want and mg.rival == row.who: ready += 1
		mg.free()
	v.gerald.stage = 0
	check(ready == VFData.GERALD.size(), "each stage's round plays its outlaw's look where its picture exists, else plain Gerald (%d of %d)" % [ready, VFData.GERALD.size()])
	check("IOU: 3 shrimp. Signed, Gerald." in load("res://scripts/vf/vf_fun.gd").NOTES, "the bottle note with his name stays")
	v._apply(v._defaults.duplicate(true))
	v.reel_rounds = VFData.ROOKIE_ROUNDS
	v.rod = "Improved Rod"
	var r0: int = v.reel_rounds
	var one: Dictionary = Bot.play_rival(self, "sharp", 0)
	check(v.reel_rounds == r0 + 1, "a round against him counts as a round, %s in %.1fs" % ["won" if one.won else "lost", one.secs])
	var rates := []
	for tries in 5:
		rates.append(Bot.rival_rate(self, "novice", tries, 40))
	check(rates[0] <= 0.5 and rates[3] >= 0.5 and rates[4] >= 0.8, "starter rods, a clumsy player: wins %s, as he gets easier" % [rates.map(func(x): return "%d%%" % int(x * 100.0))])
	var sharp: float = Bot.rival_rate(self, "sharp", 0, 40)
	check(sharp >= 0.4, "a good player can beat him the first time (%d%%)" % int(sharp * 100.0))
	v.reel_rounds = 0
	var rookie: float = Bot.rival_rate(self, "idle", 0, 40)
	check(rookie >= 0.95, "someone who has never played a round isn't thrown in at the deep end (%d%%)" % int(rookie * 100.0))
	v.reel_rounds = VFData.ROOKIE_ROUNDS


## the same rounds, played for real: a player who does nothing, or nothing useful, still wins the first one
func _test_rookie_bots(v) -> void:
	print("== the first rounds, played by bots")
	var Bot = load("res://tests/reel_bot.gd")
	seed(20261101)
	v.reel_rounds = 0
	var r: Dictionary = Bot.play(self, "idle", "Raw Fish", 0)
	check(v.reel_rounds == 1, "a finished round counts (%s after %.1fs)" % ["won" if r.won else "lost", r.secs])
	for bot in Bot.BOTS:
		for touch in [true, false]:
			var rate: float = Bot.win_rate(self, bot, "Raw Fish", 0, 0, 60, touch)
			check(rate >= 59.0 / 60.0, "first round, %s, %s: won %d%%" % ["phone" if touch else "desktop", bot, int(rate * 100.0)])
	var rare: float = Bot.win_rate(self, "idle", "Pufferfish", 4, 0, 60)
	check(rare >= 59.0 / 60.0, "first round against the rarest fish, doing nothing: won %d%%" % int(rare * 100.0))
	var rates := []
	for k in 4:
		rates.append(Bot.win_rate(self, "novice", "Raw Fish", 0, k, 80))
	check(rates[1] >= 0.9 and rates[2] >= 0.75 and rates[1] >= rates[3] and rates[2] >= rates[3],
		"a novice wins round 2 %d%%, round 3 %d%%, round 4 (normal) %d%%" % [int(rates[1] * 100.0), int(rates[2] * 100.0), int(rates[3] * 100.0)])
	v.reel_rounds = 0


## 1.0: easier economy, events, packs & Pearls, ads, shinies, exclusive rods, saves
func _test_v1() -> void:
	print("== 1.0")
	var g = load("res://scripts/vf/vf_game.gd").new()
	g.autosave = false
	root.add_child(g)
	g.rng.seed = 777
	g._apply(g._defaults.duplicate(true))
	g.level = 30
	check(absf(g.sell_mult() - 1.1) < 1e-6 and absf(g.extra_money_mult() - 1.1) < 1e-6, "10% easier: a new fisher sells for x1.10")
	var xp_before: float = g.xp_mult()
	check(absf(xp_before - 1.1) < 1e-6, "10% easier: XP x1.10 (no beginner bonus at level 30)")

	# events
	check(g.start_event("golden_hour") == "" and g.event_active() and absf(g.sell_mult() - 2.2) < 1e-6,
		"Golden Hour doubles the sell price")
	check(g.start_event("frenzy") != "", "only one event at a time")
	g._ev_end(false)
	check(not g.event_active() and g.event_mult("money") == 1.0, "event over -> normal prices")
	var cd0: float = g.cooldown()
	g.start_event("frenzy")
	check(absf(g.cooldown() - cd0 * 0.5) < 1e-6, "Fish Frenzy halves the cooldown")
	var stars0: int = g.stars
	g._last_cast_ms = -100000
	var r: Dictionary = g.cast()
	check(r.stars >= 1 and g.stars >= stars0 + 1, "every catch in an event gives an Event Star")
	g._ev_end(false)
	g.start_event("boss")
	var caught := false
	for i in 40:
		g._last_cast_ms = -100000
		r = g.cast()
		if r.boss_caught:
			caught = true
			break
	check(caught and not g.event_active() and int(g.event_fish.get("Leviathan", 0)) == 1 and not r.chest.is_empty(),
		"the boss: 25 catches wear the Leviathan down, it's caught with a legendary chest, the event ends")
	g.ev_last = "boss"
	g.ev_play = 0.0
	g._last_active = Time.get_unix_time_from_system()
	g._ev_tick(599.0)
	check(not g.event_active() and g.event_next_in() < 2.0, "the event clock counts active play")
	g._ev_tick(2.0)
	check(g.event_active() and g.ev_id != "boss", "after 10 minutes of play an event starts (never the same twice)")
	g._ev_end(false)
	g._last_active = -1000.0
	g._ev_tick(700.0)
	check(not g.event_active() and g.ev_play == 0.0, "idle time doesn't count toward events")

	# packs, pearls, exclusive rods
	var gr: Dictionary = g.grant_purchase("pack_fisher", "tok-1")
	check(gr.get("ok", false) and g.pearls == 600 and "Supporter Rod" in g.owned_rods and "Pearl Rod" in g.owned_rods,
		"Fisher Pack: 600 Pearls, the Supporter Rod and the Pearl Rod")
	check(g.grant_purchase("pack_fisher", "tok-1").has("error") and g.pearls == 600, "the same purchase is never granted twice")
	check(g.grant_purchase("pack_fisher", "tok-2").has("error"), "a Supporter Pack is bought once")
	g.grant_purchase("pack_starter", "tok-3")
	check(absf(g.perk("money") - 0.15) < 1e-6 and absf(g.sell_mult() - 1.1 * 1.15) < 1e-6, "pack perks stack (+5% and +10% money)")
	check(g.buy_rod("Legend Rod") != "", "exclusive rods aren't sold for money")
	check(VFData.rod_reel_power("Dark Rod") == 1.0 and VFData.rod_reel_power("Plastic Rod") == 0.0
		and VFData.rod_reel_power("Pearl Rod") <= 1.0, "reel power unchanged for regular rods")
	g.grant_purchase("pearls_550", "tok-4")
	check(g.pearls == 1300, "Pearl pack adds Pearls")
	var got: Dictionary = g.buy_pearl_item("mega1h")
	check(not got.has("error") and g.pearls == 1220 and g.is_boost_active("fish") and g.is_boost_active("worker"),
		"Mega Boost: 80 Pearls, every boost on")
	check(g.buy_pearl_item("pearl_rod").has("error"), "can't buy a rod you already own")
	g.pearls = 10
	check(g.buy_pearl_item("chest").has("error") and g.pearls == 10, "not enough Pearls -> nothing happens")
	g.prestige = 0; g.level = 250; g.money = 5000000000
	g.charms = {}
	for id in VFData.CHARM_ORDER: g.charms[id] = 55
	g.do_prestige()
	check("Pearl Rod" in g.owned_rods and "Supporter Rod" in g.owned_rods and g.owned_rods.size() == 3,
		"exclusive rods survive prestige")

	# ads
	var n := 0
	while not g.grant_ad("ad_pearls").has("error"): n += 1
	check(n == 3, "+10 Pearls: 3 ads a day")
	var m := 0
	while not g.grant_ad("ad_money2x").has("error"): m += 1
	check(m == VFData.AD_DAILY_MAX - 3 and g.money2x_left() <= 3600.5, "8 ads a day in all, Double Money capped at an hour")
	check(absf(g.extra_money_mult() / (1.1 * 1.15) - 2.0) < 1e-6, "Double Money doubles sales")

	# shinies
	var base: float = g.shiny_ticket_chance()
	g.shiny_lure = 2
	g.start_event("meteor_shower")
	check(absf(g.shiny_ticket_chance() / base - 15.0) < 1e-6, "Meteor Shower x5 and a Shiny Lure x3")
	g._ev_end(false)
	g.add_shiny("Cod", 41)
	g.add_shiny("Cod", 41)
	g.add_shiny("Squid", 7)
	check(g.shiny_species_owned() == 2 and g.shinies["Cod"] == [41] and absf(g.shiny_bonus() - 0.04) < 1e-6,
		"shinies: one copy per serial, +2% per species")
	g.set_shinies([{"species": "Turtle", "serial": 3000}, {"species": "Nope", "serial": 1}])
	check(g.shinies.keys() == ["Turtle"], "the server's list replaces the mirror (unknown species dropped)")

	# save / load
	g.stars = 77
	g.event_fish = {"Golden Koi": 2}
	var d: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var h = load("res://scripts/vf/vf_game.gd").new()
	h.autosave = false
	root.add_child(h)
	h._apply(d)
	check(h.pearls == g.pearls and h.packs == g.packs and h.stars == 77 and h.event_fish == {"Golden Koi": 2}
		and h.shinies == {"Turtle": [3000]} and h.purchases == ["tok-1", "tok-3", "tok-4"], "1.0 state survives save -> load")
	var old: Dictionary = d.duplicate(true)
	old.erase("v1")
	h._apply(old)
	check(h.pearls == 0 and h.packs.is_empty() and h.ev_id == "", "a save from before 1.0 loads with fresh 1.0 state")

	# odds shown on random items bought with Pearls (Google Play's loot box rule)
	var odds: String = VFData.chest_odds("legendary")
	var total := 0
	for hit in RegEx.create_from_string("([0-9]+)%").search_all(odds): total += int(hit.get_string(1))
	check(odds.begins_with("Charms 40%") and "Emerald Fish 10%" in odds and total == 100,
		"the Legendary Chest's odds are shown and add up to 100%: " + odds)
	check("1 in 3,500 catches" in VFData.shiny_odds() and "1 in 1,167 with the lure" in VFData.shiny_odds(), "shiny odds: " + VFData.shiny_odds())


## idle: the fleet and its catch while you're away, auto casts, the 7-day calendar, the daily spin, saves
func _test_idle() -> void:
	print("== idle")
	var g = load("res://scripts/vf/vf_game.gd").new()
	g.autosave = false
	root.add_child(g)
	g.rng.seed = 4242
	g._apply(g._defaults.duplicate(true))
	check(g.crew_cost(1) == 250 and g.crew_cost(2) == 1500 and g.crew_cost(17) == int(round(250.0 * pow(6.0, 16))),
		"crew prices: $250, then x6 for every next one")
	g.money = 1000
	check(g.hire_crew() != "" and g.crews == 0, "the fleet unlocks at level %d" % VFData.FLEET_LEVEL)
	g.level = VFData.FLEET_LEVEL
	check(g.hire_crew() == "" and g.crews == 1 and g.money == 750, "hiring a crew costs its price")
	check(g.hire_crew() != "" and g.crews == 1, "not enough money: no second crew")

	# crew trips: worker trips with your gear (crew_trip_fish is their average)
	var avg: float = g.crew_trip_fish()
	g.fleet_fish_total = 0
	g._crew_trips(600)
	var per: float = g.fleet_fish_total / 600.0
	check(absf(per / avg - 1.0) < 0.15, "a crew trip lands about crew_trip_fish() fish (%.2f vs %.2f)" % [per, avg])

	# the catch while you're away
	g.inventory = {}
	g.offline = {}
	g.crews = 2
	var now := Time.get_unix_time_from_system()
	g.idle_seen = now - 60.0
	g.offline_check()
	check(g.offline.is_empty(), "away a minute: nothing to report")
	g.idle_seen = now - 3600.0
	g.offline_check()
	var want: float = 2 * 3600.0 / g.crew_trip_secs() * g.offline_rate() * g.crew_trip_fish()
	check(not g.offline.is_empty() and absf(g.offline.n / want - 1.0) < 0.02,
		"an hour away: crews x trips x %d%% (%d fish, expected %.0f)" % [int(g.offline_rate() * 100), int(g.offline.get("n", 0)), want])
	g.idle_seen = now - 48.0 * 3600.0
	g.offline_check()
	check(absf(float(g.offline.secs) - 3600.0 - g.offline_cap_secs()) < 1.0 and float(g.offline.away) > 49.0 * 3600.0 - 5.0,
		"two days away fish only the cooler's %d hours (added to the hour before)" % int(g.offline_cap_secs() / 3600.0))
	var waiting: int = g.offline.n
	var col: Dictionary = g.collect_offline(1.0)
	var held := 0
	for f in g.inventory: held += int(g.inventory[f])
	check(col.n == waiting and held == waiting and g.offline.is_empty(), "collect: the catch goes into the hold")
	check(g.collect_offline().has("error"), "nothing waiting: nothing to collect")
	g.idle_seen = now - 3600.0
	g.offline_check()
	var n2: int = g.offline.n
	var got: Dictionary = g.grant_ad("ad_offline2x")
	check(absi(int(got.get("offline", {}).get("n", 0)) - 2 * n2) <= 5 and g.offline.is_empty(), "the x2 ad doubles the catch")
	g.idle_seen = now - 1800.0
	g._idle_tick(0.016)
	check(not g.offline.is_empty() and g.idle_seen >= now, "the game slept 30 minutes while open: the crews' catch waits too")
	g.collect_offline()
	g.crews = 0
	g.idle_seen = now - 3600.0
	g.offline_check()
	check(g.offline.is_empty(), "no crews: nothing caught while away")
	g.crews = 2

	# fleet upgrades
	g.money = 1000000000000
	var t0: float = g.crew_trip_secs()
	check(g.buy_fleet_up("speed") == "" and g.crew_trip_secs() < t0, "Faster Crews: shorter trips")
	for i in 10: g.buy_fleet_up("cooler")
	check(g.fleet_lv("cooler") == 4 and absf(g.offline_cap_secs() - (VFData.OFFLINE_HOURS + 4.0) * 3600.0) < 1.0,
		"Bigger Cooler: 4 levels, an hour each")
	check(absf(g.offline_rate() - VFData.OFFLINE_RATE) < 1e-6 and g.buy_fleet_up("sealegs") == "" and g.offline_rate() > VFData.OFFLINE_RATE,
		"Sea Legs: a bigger share while you're away")

	# auto casts: no shiny tickets, not active play
	g.auto_cast = true
	g._last_active = -1000.0
	g.shiny_lure = 3
	g._last_cast_ms = -100000
	var ar: Dictionary = g.cast()
	g.auto_cast = false
	check(ar.ok and g._last_active == -1000.0 and ar.shiny_ticket == "" and g.shiny_lure == 3,
		"an auto cast rolls no shiny ticket, uses no lure and isn't active play (events)")

	# the 7-day calendar on the daily reward
	g.level = VFData.DAILY_LEVEL
	g.daily_last = 0.0
	g.daily_streak = 0
	var d: Dictionary = g.claim_daily()
	check(not d.has("error") and d.day == 1 and g.calendar_done() == 1 and g.calendar_next() == 2, "calendar: the first claim is day 1")
	var p0: int = g.pearls
	for i in 6:
		g.daily_last -= 86400.0
		d = g.claim_daily()
	check(d.day == 7 and g.pearls >= p0 + 125 and String(d.bonus.get("chest", {}).get("tier", "")) == "legendary",
		"day 7: the jackpot (Pearls and a legendary chest)")
	g.daily_last -= 86400.0
	check(g.calendar_done() == 0 and g.calendar_next() == 1, "after day 7 it starts again")
	d = g.claim_daily()
	g.daily_last -= 49.0 * 3600.0
	check(g.calendar_done() == 0 and g.claim_daily().day == 1, "a missed day (48 hours) starts the calendar over")

	# the daily spin
	var w := 0
	for x in VFData.SPIN: w += int(x.w)
	check(w == 100, "the wheel's odds add up to 100%")
	g.spin_day = ""
	g.spins = 0
	var s1: Dictionary = g.spin()
	check(not s1.has("error") and int(s1.index) >= 0 and int(s1.index) < VFData.SPIN.size(), "the free spin of the day")
	check(g.spin().has("error"), "one free spin a day")
	g.grant_ad("ad_spin")
	check(g.spins == 1 and not g.spin().has("error") and g.spins == 0, "an ad buys an extra spin")
	g.spins = 4000
	var money_hits := 0
	for i in 4000:
		if int(g.spin().index) == 0: money_hits += 1
	check(absf(money_hits / 4000.0 - 0.26) < 0.03, "the wheel lands as its odds say (Money %.1f%%, listed 26%%)" % (money_hits / 40.0))

	# prestige starts the fleet over
	g.prestige = 0; g.level = 250; g.money = 5000000000
	g.charms = {}
	for id in VFData.CHARM_ORDER: g.charms[id] = 55
	g.crews = 5
	g.fleet_up = {"nets": 3}
	g.do_prestige()
	check(g.crews == 0 and g.fleet_up.is_empty(), "prestige starts the fleet over, like the boats")

	# save / load
	g.crews = 3
	g.fleet_up = {"speed": 2}
	g.auto_on = true
	g.spins = 2
	g.idle_seen = Time.get_unix_time_from_system()
	var sd: Dictionary = JSON.parse_string(JSON.stringify(g.to_dict()))
	var h = load("res://scripts/vf/vf_game.gd").new()
	h.autosave = false
	root.add_child(h)
	h._apply(sd)
	check(h.crews == 3 and h.fleet_up == {"speed": 2} and h.auto_on and h.spins == 2 and h.spin_day == g.spin_day,
		"the fleet, auto-fish and spins survive save -> load")
	var old: Dictionary = sd.duplicate(true)
	old.erase("idle")
	h._apply(old)
	check(h.crews == 0 and not h.auto_on and h.offline.is_empty() and h.idle_seen > 0.0, "a save from before idle play loads with no fleet")

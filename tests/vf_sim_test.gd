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

	print("\n%s (%d failures)" % ["PASS" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)

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
	g2.free()

	print("\n%s (%d failures)" % ["PASS" if failures == 0 else "FAILED", failures])
	quit(1 if failures else 0)

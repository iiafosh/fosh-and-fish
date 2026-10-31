extends SceneTree
## Balance probe for the idle systems (not a pass/fail test): a P0 player fishes actively (one cast per
## cooldown), sells, buys the next rod / boat when they can, and (run 2) hires crews when they have twice the
## price. Prints when each run reaches a level, and what 4 hours away would bring at that point.
## Run: Godot_console.exe --headless --path . -s res://tests/idle_balance_probe.gd

func _init() -> void:
	for with_crews in [false, true]:
		var g = load("res://scripts/vf/vf_game.gd").new()
		g.autosave = false
		root.add_child(g)
		g._apply(g._defaults.duplicate(true))
		g.rng.seed = 99
		var t := 0.0
		var marks := [10, 25, 50, 75, 100, 150, 250]
		print("== run %s" % ("WITH crews" if with_crews else "without crews"))
		var casts := 0
		while casts < 200000 and not marks.is_empty():
			g._last_cast_ms = -100000
			g.cast()
			casts += 1
			var dt: float = g.cooldown()
			t += dt
			if with_crews and g.crews > 0:
				g._crew_accum += dt * g.crews / g.crew_trip_secs()
				var k := int(g._crew_accum)
				if k > 0:
					g._crew_accum -= k
					g._crew_trips(k)
			if casts % 20 == 0:
				g.sell_all()
				_shop(g, with_crews)
			if g.level >= marks[0]:
				var lv: int = marks.pop_front()
				var line := "  Lv %d after %s min  ($%s, %s, %d boats, %d crews)" % [lv, int(t / 60.0), g.fmt(g.money), g.rod, g.boats_owned, g.crews]
				if g.crews > 0:
					var secs: float = g.offline_cap_secs()
					var n: float = g.crews * secs / g.crew_trip_secs() * g.offline_rate() * g.crew_trip_fish()
					var odds: Array = g.species_odds()
					var names: Array = VFData.BIOMES[g.biome].fish
					var val := 0.0
					var xp := 0.0
					for i in 5:
						val += n * odds[i] * VFData.FISH[names[i]].price
						xp += n * odds[i] * VFData.FISH[names[i]].xp
					val *= g.sell_mult()
					xp *= g.xp_mult() * VFData.CREW_XP
					# the money an active minute makes now, for scale
					var r: Dictionary = VFData.RODS[g.rod]
					var per_cast: float = g._tok_avg_fish()
					var cast_val := 0.0
					for i in 5: cast_val += per_cast * odds[i] * VFData.FISH[names[i]].price
					cast_val *= g.sell_mult() * 60.0 / g.cooldown()
					line += "\n      4h away: %s fish, $%s (= %.0f min of active play), %s XP (= %.1f levels now)" % [
						g.fmt(n), g.fmt(val), val / maxf(1.0, cast_val), g.fmt(xp), xp / maxf(1.0, g.xp_to_next())]
				print(line)
		g.queue_free()
	quit()


func _shop(g, with_crews: bool) -> void:
	for r in VFData.ROD_ORDER:
		var d: Dictionary = VFData.RODS[r]
		if r in g.owned_rods or VFData.is_exclusive_rod(r) or g.level < d.level or g.prestige < int(d.get("prestige", 0)): continue
		if g.money >= d.cost and g.biome in d.biomes:
			g.buy_rod(r)
		break
	var nb: String = g.next_boat()
	if nb != "" and g.level >= VFData.BOATS[nb].level and g.money >= VFData.BOATS[nb].cost:
		g.buy_boat()
	for b in VFData.BIOME_ORDER:
		if g.level >= VFData.BIOMES[b].level and g.rod_usable(g.rod, b): g.biome = b
	if with_crews and g.fleet_unlocked() and g.next_crew_cost() > 0 and g.money >= 2 * g.next_crew_cost():
		g.hire_crew()

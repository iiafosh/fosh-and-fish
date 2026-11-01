extends SceneTree
## Balance probe for the idle systems (not a pass/fail test): a P0 player fishes actively, sells, buys the next rod /
## boat when they can, and (with crews) hires crews when they have twice the price. Prints when each run reaches a level,
## and what 4 hours away would bring at that point.
## Relax: one cast per cooldown. Reel it in!: rounds as a clumsy player plays them (tools/reel_model.gd), for the bonus of
## that run: today's +200% (VFData.MINIGAME_FISH_BONUS) and the old +75%, to see what the change did.
## Run: Godot_console.exe --headless --path . -s res://tests/idle_balance_probe.gd

const Reel = preload("res://tools/reel_model.gd")
const RUNS := [
	{"name": "Relax, without crews", "crews": false},
	{"name": "Relax, WITH crews", "crews": true},
	{"name": "Reel it in! at the old +75%, WITH crews", "crews": true, "bonus": 0.75},
	{"name": "Reel it in! at +200%, WITH crews", "crews": true, "bonus": VFData.MINIGAME_FISH_BONUS},
]

func _init() -> void:
	for run in RUNS:
		var g = load("res://scripts/vf/vf_game.gd").new()
		g.autosave = false
		root.add_child(g)
		g._apply(g._defaults.duplicate(true))
		g.rng.seed = 99
		var t := 0.0
		var marks := [10, 25, 50, 60, 75, 100, 150, 250]
		var reel: bool = run.has("bonus")
		var rate := {"wins": 0, "secs": 0.0, "n": 0}         # the rounds so far (a minute of Reel it in! is worth this much)
		print("== %s" % run.name)
		var casts := 0
		while casts < 200000 and not marks.is_empty():
			g._last_cast_ms = -100000
			var dt: float = g.cooldown()
			if reel:
				var r: Dictionary = Reel.round_for(g)
				dt = r.secs
				g.cast(run.bonus if r.won else 0.0)
				rate.wins += 1 if r.won else 0
				rate.secs += r.secs
				rate.n += 1
			else:
				g.cast()
			casts += 1
			t += dt
			if run.crews and g.crews > 0:
				g._crew_accum += dt * g.crews / g.crew_trip_secs()
				var k := int(g._crew_accum)
				if k > 0:
					g._crew_accum -= k
					g._crew_trips(k)
			if casts % 20 == 0:
				g.sell_all()
				_shop(g, run.crews)
			if g.level >= marks[0]:
				var lv: int = marks.pop_front()
				var line := "  Lv %d after %s min  ($%s, %s, %d boats, %d crews)" % [lv, int(t / 60.0), g.fmt(g.money), g.rod, g.boats_owned, g.crews]
				if g.crews > 0:
					var secs: float = g.offline_cap_secs()
					var n: float = g.crews * secs / g.crew_trip_secs() * g.offline_rate() * g.crew_trip_fish() * (1.0 + g.aquarium_income())
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
					var per_cast: float = g._tok_avg_fish()
					var cast_val := 0.0
					for i in 5: cast_val += per_cast * odds[i] * VFData.FISH[names[i]].price
					if reel:
						cast_val *= g.sell_mult() * (1.0 + float(rate.wins) / rate.n * float(run.bonus)) * 60.0 / (rate.secs / rate.n)
					else:
						cast_val *= g.sell_mult() * 60.0 / g.cooldown()
					line += "\n      4h away: %s fish, $%s (= %.0f min of active play), %s XP (= %.1f levels now)" % [
						g.fmt(n), g.fmt(val), val / maxf(1.0, cast_val), g.fmt(xp), xp / maxf(1.0, g.xp_to_next())]
					line += "  (aquarium +%d%%)" % int(round(g.aquarium_income() * 100.0))
				print(line)
		if reel: print("  rounds won %d%%, %.1fs from tap to tap" % [int(100.0 * rate.wins / rate.n), rate.secs / rate.n])
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

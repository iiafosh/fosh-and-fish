extends SceneTree
## Pacing check: a sensible new player casts as soon as they can, sells often, buys the next rod / boat / worms when
## affordable, moves on to the next biome. Prints minutes to reach levels, on Relax and on Reel it in!, with and without
## crews, and when the first rebirth comes (they stop shopping once they have the level, and save the money).
## Run: Godot_console.exe --headless --path . -s res://tools/pace_sim.gd

const Reel = preload("res://tools/reel_model.gd")
const TAP_OVERHEAD := Reel.TAP_OVERHEAD
const RUNS := 10
const MILESTONES := [5, 10, 15, 20, 25, 50, 60, 75, 100]
const MAX_MINUTES := 1200.0
const MODES := [
	{"name": "Relax", "reel": false, "crews": false},
	{"name": "Relax + crews", "reel": false, "crews": true},
	{"name": "Reel it in!, clumsy", "reel": true, "crews": false},
	{"name": "Reel it in!, clumsy + crews", "reel": true, "crews": true},
	{"name": "Reel it in!, good", "reel": true, "crews": false, "sharp": true},
	{"name": "Reel it in!, good + crews", "reel": true, "crews": true, "sharp": true},
]

func _init() -> void:
	for mode in MODES:
		_run_mode(mode)
	_second_rebirth()
	quit()

## for scale: the run after the first rebirth, on Relax with crews, up to the level and money of the second one
## (those didn't change). The perk is the Guide's pick. Prints how many charms of the ones it needs have dropped by then.
func _second_rebirth() -> void:
	var G = load("res://scripts/vf/vf_game.gd")
	var g = G.new()
	g.autosave = false
	root.add_child(g)
	g._apply(g._defaults.duplicate(true))
	g.rng.seed = 2000
	g.prestige = 1
	g.perks = {"international_ties": 1}
	var lv: int = VFData.prestige_level_req(1)
	var cash: int = VFData.prestige_money_req(1)
	var t := 0.0
	var casts := 0
	while casts < 400000 and (g.level < lv or g.money < cash):
		g._last_cast_ms = -100000
		g.cast()
		casts += 1
		var dt: float = g.cooldown() + TAP_OVERHEAD
		t += dt
		if g.crews > 0:
			g._crew_accum += dt * g.crews / g.crew_trip_secs()
			var k := int(g._crew_accum)
			if k > 0:
				g._crew_accum -= k
				g._crew_trips(k)
		if casts % 5 == 0:
			g.sell_all()
			if g.level < lv: _shop(g, true)
	print("== the second rebirth, on Relax + crews: Lv%d and $%s after %.0f hours (%d casts), with %d of the %d charms it needs" % [lv, G.fmt(cash), t / 3600.0, casts, g.charms_total(), VFData.prestige_charm_req(1)])
	print("   reached: Lv%d, $%s" % [g.level, G.fmt(g.money)])
	g.queue_free()

func _run_mode(mode: Dictionary) -> void:
	var totals := {}
	var counted := {}
	var rebirth := 0.0
	var rebirth_runs := 0
	var earned := 0.0
	var wins := 0
	var rounds := 0
	var secs := 0.0
	var G = load("res://scripts/vf/vf_game.gd")
	for run in RUNS:
		var g = G.new()
		g.autosave = false
		root.add_child(g)
		g._apply(g._defaults.duplicate(true))
		g.rng.seed = 1000 + run
		var t := 0.0
		var casts := 0
		var hit := {}
		while t < MAX_MINUTES * 60.0:
			g._last_cast_ms = -100000
			var dt: float = g.cooldown() + TAP_OVERHEAD
			if mode.reel:
				var r: Dictionary = Reel.round_for(g, mode.get("sharp", false))
				dt = r.secs
				g.cast(VFData.MINIGAME_FISH_BONUS if r.won else 0.0)
				wins += 1 if r.won else 0
				secs += r.secs
				rounds += 1
			else:
				g.cast()
			casts += 1
			t += dt
			if mode.crews and g.crews > 0:
				g._crew_accum += dt * g.crews / g.crew_trip_secs()
				var k := int(g._crew_accum)
				if k > 0:
					g._crew_accum -= k
					g._crew_trips(k)
			if casts % 5 == 0:
				g.sell_all()
				if g.level < VFData.prestige_level_req(0): _shop(g, mode.crews)
			for m in MILESTONES:
				if g.level >= m and not hit.has(m):
					hit[m] = true
					totals[m] = totals.get(m, 0.0) + t / 60.0
					counted[m] = counted.get(m, 0) + 1
			if g.prestige_check().ok:
				rebirth += t / 60.0
				rebirth_runs += 1
				earned += float(g.stats.money_earned)
				break
		g.queue_free()
	print("== %s (%d runs)" % [mode.name, RUNS])
	var line := "   "
	for m in MILESTONES:
		if counted.get(m, 0) > 0: line += "Lv%d %.0f min  " % [m, totals[m] / counted[m]]
	print(line)
	if rounds > 0: print("   rounds won %d%%, %.1fs from tap to tap" % [int(100.0 * wins / rounds), secs / rounds])
	var want := "Lv%d, $%s, %d charms" % [VFData.prestige_level_req(0), G.fmt(VFData.prestige_money_req(0)), VFData.prestige_charm_req(0)]
	if rebirth_runs > 0:
		print("   first rebirth (%s): %.1f hours, $%s earned on the way (%d of %d runs)" % [want, rebirth / rebirth_runs / 60.0, G.fmt(earned / rebirth_runs), rebirth_runs, RUNS])
	else:
		print("   first rebirth (%s): not reached in %.0f hours" % [want, MAX_MINUTES / 60.0])

func _shop(g, with_crews: bool) -> void:
	for r in VFData.ROD_ORDER:
		var d: Dictionary = VFData.RODS[r]
		if r in g.owned_rods or VFData.is_exclusive_rod(r) or g.level < d.level: continue
		if g.money >= d.cost and g.biome in d.biomes: g.buy_rod(r)
		break
	var nb: String = g.next_boat()
	if nb != "" and g.level >= VFData.BOATS[nb].level and g.money >= VFData.BOATS[nb].cost * 2:
		g.buy_boat()
	if g.money > 400 and int(g.bait_stock.get("Worms", 0)) < 20:
		g.buy_bait("Worms", 50)
		g.select_bait("Worms")
	for b in VFData.BIOME_ORDER:
		if g.level >= VFData.BIOMES[b].level and g.rod_usable(g.rod, b): g.biome = b
	if with_crews and g.fleet_unlocked() and g.next_crew_cost() > 0 and g.money >= 2 * g.next_crew_cost():
		g.hire_crew()

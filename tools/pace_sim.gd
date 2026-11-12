extends SceneTree
## Pacing check: a sensible new player casts as soon as they can, sells often, buys the next rod / boat / worms when
## affordable, moves on to the next biome, and saves the money once they have the level for the next rebirth.
## Run: Godot_console.exe --headless --path . -s res://tools/pace_sim.gd [-- --chain | --table]
##   (nothing): minutes to reach levels, on Relax and on Reel it in!, with and without crews, and when the first rebirth comes
##   --chain:   a new game through CHAIN_TO rebirths with today's requirements: the hours from each rebirth to the next.
##              At every rebirth the Azure Fish go where the Prestige Guide says.
##   --table:   for tuning the curve: after each rebirth (P1 to TABLE_TO), when normal play reaches each level, and what it
##              has earned by then (no saving up: it keeps shopping)

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
const NORMAL := ["Relax", "Relax + crews", "Reel it in!, good", "Reel it in!, good + crews"]
const CHAIN_TO := 7
const CHAIN_RUNS := 4
const CHAIN_CAP_HOURS := 60.0     # a stage that takes longer than this is reported as not reached
const TABLE_TO := 10
const TABLE_RUNS := 2
const TABLE_HOURS := 16.0
const TABLE_LEVELS := [40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 180, 200]
const PERK_IDS := {"IT": "international_ties", "BE": "business_education", "FW": "fish_whisperer", "AO": "ancient_one", "VF": "virtual_fisher"}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if "--chain" in args:
		for mode in MODES: _chain(mode)
	elif "--table" in args:
		for mode in MODES:
			if mode.name in NORMAL: _table(mode)
	elif "--charms" in args:
		for mode in MODES:
			if mode.name in ["Relax", "Relax + crews", "Reel it in!, good"]: _charms(mode)
	else:
		for mode in MODES: _run_mode(mode)
	quit()

## one cast (or round) and what goes with it: the crews' trips, selling, and shopping until the next rebirth's level
## (keep_shopping: never stop to save). Returns the seconds it took.
func _step(g, mode: Dictionary, n: int, keep_shopping := false) -> float:
	g._last_cast_ms = -100000
	var dt: float = g.cooldown() + TAP_OVERHEAD
	if mode.reel:
		var r: Dictionary = Reel.round_for(g, mode.get("sharp", false))
		dt = r.secs
		g.cast(VFData.MINIGAME_FISH_BONUS if r.won else 0.0)
	else:
		g.cast()
	if mode.crews and g.crews > 0:
		g._crew_accum += dt * g.crews / g.crew_trip_secs()
		var k := int(g._crew_accum)
		if k > 0:
			g._crew_accum -= k
			g._crew_trips(k)
	if n % 5 == 0:
		g.sell_all()
		if keep_shopping or g.level < VFData.prestige_level_req(g.prestige): _shop(g, mode.crews)
	return dt

## the Azure Fish of the prestige just reached go where the Prestige Guide says ("FW | AO": the first one)
static func _guide_perks(g) -> void:
	for part in String(VFData.prestige_guide(g.prestige).main).split(" + "):
		var short := part.split(" | ")[0].strip_edges()
		if PERK_IDS.has(short): g.buy_perk(PERK_IDS[short])

func _new_game(seed_no: int):
	var g = load("res://scripts/vf/vf_game.gd").new()
	g.autosave = false
	root.add_child(g)
	g._apply(g._defaults.duplicate(true))
	g.rng.seed = seed_no
	return g

## from a new game through CHAIN_TO rebirths: how long each stage takes
func _chain(mode: Dictionary) -> void:
	var G = load("res://scripts/vf/vf_game.gd")
	var sums := []
	var counts := []
	var lows := []
	var highs := []
	for i in CHAIN_TO:
		sums.append(0.0)
		counts.append(0)
		lows.append(INF)
		highs.append(0.0)
	var stuck := 0
	for run in CHAIN_RUNS:
		var g = _new_game(3000 + run)
		var t := 0.0
		var since := 0.0
		var n := 0
		while g.prestige < CHAIN_TO:
			t += _step(g, mode, n)
			n += 1
			if g.prestige_check().ok:
				var h := (t - since) / 3600.0
				var p: int = g.prestige
				sums[p] += h
				counts[p] += 1
				lows[p] = minf(lows[p], h)
				highs[p] = maxf(highs[p], h)
				since = t
				g.do_prestige()
				_guide_perks(g)
			elif t - since > CHAIN_CAP_HOURS * 3600.0:
				stuck += 1
				break
		g.queue_free()
	var line := "== %-28s" % mode.name
	for p in CHAIN_TO:
		if counts[p] > 0: line += "  P%d>P%d %.1fh (%.1f-%.1f)" % [p, p + 1, sums[p] / counts[p], lows[p], highs[p]]
		else: line += "  P%d>P%d -" % [p, p + 1]
	if stuck > 0: line += "  (%d runs stuck over %d hours)" % [stuck, int(CHAIN_CAP_HOURS)]
	print(line)
	print("   requirements: " + ", ".join(range(CHAIN_TO).map(func(p): return "P%d Lv%d $%s" % [p, VFData.prestige_level_req(p), G.fmt(VFData.prestige_money_req(p))])))

## --charms: in each prestige's run, how many charms you have when its rebirth is ready, and how many hours from the
## start of the run until every charm is maxed (then it prestiges). Charms start over at every rebirth.
func _charms(mode: Dictionary) -> void:
	const TO := 4
	const RUNS_C := 3
	const CAP_H := 40.0
	var ready_sum := []
	var ready_h := []
	var max_h := []
	var maxed := []
	for p in TO:
		ready_sum.append(0.0); ready_h.append(0.0); max_h.append(0.0); maxed.append(0)
	for run in RUNS_C:
		var g = _new_game(7000 + run)
		var t := 0.0
		var since := 0.0
		var n := 0
		var ready := false
		while g.prestige < TO:
			t += _step(g, mode, n)
			n += 1
			var p: int = g.prestige
			if not ready and g.prestige_check().ok:
				ready = true
				ready_sum[p] += g.charms_total()
				ready_h[p] += (t - since) / 3600.0
			var full: bool = g.charms_total() >= VFData.charm_total_cap(p)
			if ready and g.prestige_check().ok and (full or t - since > CAP_H * 3600.0):
				if full:
					max_h[p] += (t - since) / 3600.0
					maxed[p] += 1
				g.do_prestige()
				_guide_perks(g)
				since = t
				ready = false
		g.queue_free()
	var line := "== %-22s" % mode.name
	for p in TO:
		line += "  P%d: ready %.1fh with %d/%d charms, all maxed %s" % [p, ready_h[p] / RUNS_C, int(ready_sum[p] / RUNS_C),
			VFData.charm_total_cap(p), ("%.1fh" % (max_h[p] / maxed[p])) if maxed[p] > 0 else "not in %dh" % int(CAP_H)]
	print(line)

## after each rebirth (a new game played to its first rebirth, then the Guide's perks for each prestige up to p): when
## this mode reaches each level, and what it has earned by then
func _table(mode: Dictionary) -> void:
	var G = load("res://scripts/vf/vf_game.gd")
	print("== %s: hours after the rebirth to reach a level, and $ earned by then" % mode.name)
	var snaps := []
	for run in TABLE_RUNS:
		var g = _new_game(5000 + run)
		var n := 0
		while g.prestige == 0:
			_step(g, mode, n)
			n += 1
			if g.prestige_check().ok:
				g.do_prestige()
				_guide_perks(g)
		snaps.append(JSON.parse_string(JSON.stringify(g.to_dict())))
		g.queue_free()
	for p in range(1, TABLE_TO + 1):
		var at := {}
		var earned := {}
		for run in TABLE_RUNS:
			var g = _new_game(6000 + run * 100 + p)
			g._apply(snaps[run].duplicate(true))
			for q in range(2, p + 1):
				g.prestige = q
				g.exotics.azure = int(g.exotics.azure) + 1
				_guide_perks(g)
			var t := 0.0
			var n := 0
			var e0 := float(g.stats.money_earned)
			var marks := TABLE_LEVELS.duplicate()
			while t < TABLE_HOURS * 3600.0 and not marks.is_empty():
				t += _step(g, mode, n, true)
				n += 1
				while not marks.is_empty() and g.level >= marks[0]:
					var lv: int = marks.pop_front()
					at[lv] = at.get(lv, 0.0) + t / 3600.0 / TABLE_RUNS
					earned[lv] = earned.get(lv, 0.0) + (float(g.stats.money_earned) - e0) / TABLE_RUNS
			for lv in marks: at[lv] = -1000.0
			g.queue_free()
		var line := "   P%-2d" % p
		for lv in TABLE_LEVELS:
			if at.get(lv, -1.0) > 0.0: line += "  L%d %.1fh $%s" % [lv, at[lv], G.fmt(earned[lv])]
		print(line)

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
		var g = _new_game(1000 + run)
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

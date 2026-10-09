extends SceneTree
## Early-game pacing check: a sensible new player taps every cooldown, sells often,
## buys the next rod / boat / worms when affordable. Prints minutes to reach levels.
## Run: Godot_console.exe --headless --path . -s res://tools/pace_sim.gd

const TAP_OVERHEAD := 0.4        # seconds a real player loses per cast (reaction, banners)
const RUNS := 20
const MILESTONES := [5, 10, 15, 20, 25]

func _init() -> void:
	var totals := {}
	var casts_at := {}
	for run in RUNS:
		var g = load("res://scripts/vf/vf_game.gd").new()
		g.autosave = false
		root.add_child(g)
		g._apply(g._defaults.duplicate(true))
		g.rng.seed = 1000 + run
		var t := 0.0
		var casts := 0
		var hit := {}
		while g.level < MILESTONES[-1] and casts < 20000:
			g._last_cast_ms = -100000
			g.cast()
			casts += 1
			t += g.cooldown() + TAP_OVERHEAD
			if casts % 5 == 0:
				g.sell_all()
				_shop(g)
			for m in MILESTONES:
				if g.level >= m and not hit.has(m):
					hit[m] = true
					totals[m] = totals.get(m, 0.0) + t / 60.0
					casts_at[m] = casts_at.get(m, 0) + casts
		g.queue_free()
	for m in MILESTONES:
		print("level %2d: %5.1f min  (%d casts)" % [m, totals.get(m, 0.0) / RUNS, casts_at.get(m, 0) / RUNS])
	quit()

func _shop(g) -> void:
	for r in VFData.ROD_ORDER:
		if not r in g.owned_rods and g.rod_usable(r, g.biome) and g.level >= VFData.RODS[r].level and g.money >= VFData.RODS[r].cost:
			g.buy_rod(r)
			g.select_rod(r)
	var nb: String = g.next_boat()
	if nb != "" and g.level >= VFData.BOATS[nb].level and g.money >= VFData.BOATS[nb].cost * 2:
		g.buy_boat()
	if g.money > 400 and int(g.bait_stock.get("Worms", 0)) < 20:
		g.buy_bait("Worms", 50)
		g.select_bait("Worms")

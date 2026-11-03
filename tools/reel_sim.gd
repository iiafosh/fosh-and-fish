extends SceneTree
## How hard is Reel it in!? Simulated players (tests/reel_bot.gd) play the real mini-game; prints how often each one wins.
## Never saves. Run: Godot_console.exe --headless --path . -s res://tools/reel_sim.gd

const N := 100

func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var Bot = load("res://tests/reel_bot.gd")
	var V = Bot.vf()
	V.autosave = false
	V._apply(V._defaults.duplicate(true))
	seed(7)
	var table_only := ""                 # -- --table=novice : only the table tools/reel_model.gd uses
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--table="): table_only = a.substr(8)
	if table_only == "rival":
		_rival_table(Bot, V)
		quit()
		return
	if table_only != "":
		_table(Bot, V, table_only)
		quit()
		return
	print("== a new player with the starter rod and a common fish, %d rounds each (phone / desktop)" % N)
	print("   %-8s %-14s %-14s %-14s %-14s" % ["", "round 1", "round 2", "round 3", "round 4 (normal)"])
	for bot in Bot.BOTS:
		var line := "   %-8s " % bot
		for k in 4:
			var phone: float = Bot.win_rate(self, bot, "Raw Fish", 0, k, N, true, 1.0 / 60.0)
			var pc: float = Bot.win_rate(self, bot, "Raw Fish", 0, k, N, false, 1.0 / 60.0)
			line += "%-14s " % ("%d%% / %d%%" % [int(round(phone * 100.0)), int(round(pc * 100.0))])
		print(line)
	var secs := 0.0
	for i in N:
		V.reel_rounds = 0
		secs += float(Bot.play(self, "novice", "Raw Fish", 0, true, 1.0 / 60.0).secs)
	print("   a novice's first round lasts %.1fs on average" % (secs / N))
	_table(Bot, V, "novice")
	quit()

func _table(Bot, V, bot: String) -> void:
	print("== the normal game, by rod and fish tier: %s on a phone, won and the average round in seconds" % bot)
	for r in ["Plastic Rod", "Steel Rod", "Alloy Rod", "Magma Rod", "Infinity Rod", "Dark Rod"]:
		V.rod = r
		var row := "   %-14s" % r
		for tier in 5:
			var wins := 0
			var long := 0.0
			for i in N / 2:
				V.reel_rounds = VFData.ROOKIE_ROUNDS
				var one: Dictionary = Bot.play(self, bot, "Raw Fish", tier, true, 1.0 / 60.0)
				wins += 1 if one.won else 0
				long += float(one.secs)
			row += "  t%d %3d%% %.1fs" % [tier, int(round(100.0 * wins / (N / 2))), long / (N / 2)]
		print(row)

## the rival, stage by stage with a rod you could have by then: how often each bot wins, by how many times he has beaten them
func _rival_table(Bot, V) -> void:
	V.reel_rounds = VFData.ROOKIE_ROUNDS
	var rods := ["Improved Rod", "Lava Rod", "Oceanium Rod", "Infinity Rod", "Space Rod", "Alien Rod", "Dark Rod"]
	for bot in ["novice", "sharp"]:
		print("== the rival, %s on a phone: wins after he has beaten you 0, 1, 2, 3, 4 times" % bot)
		for i in VFData.GERALD.size():
			V.gerald.stage = i
			V.rod = rods[i]
			var row := "   %-9s %-8s %-13s" % [VFData.GERALD[i].who, VFData.GERALD[i].biome, rods[i]]
			for tries in 5:
				row += " %3d%%" % int(round(100.0 * Bot.rival_rate(self, bot, tries, 30)))
			print(row)
	V.gerald.stage = 0

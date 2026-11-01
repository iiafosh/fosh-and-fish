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
	quit()

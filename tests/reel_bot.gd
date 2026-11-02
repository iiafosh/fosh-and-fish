extends RefCounted
## Plays the real "Reel it in!" (scripts/vf/vf_minigame.gd) with a simulated player and no game around it: a stand-in
## for vf_main, fixed time steps, nothing drawn. tests/vf_sim_test.gd and tools/reel_sim.gd use it.
## It needs the VF and AudioManager autoloads, which a SceneTree script only has from its first frame on, and VF holds
## the real save by then: callers set VF.autosave = false before anything else.

## idle: never touches it. hold: holds it down all the time. mash: taps without looking.
## novice: chases where the fish was a moment ago, changes its mind a few times a second, doesn't allow for the net's
## momentum and looks away now and then. sharp: quicker, and it does allow for the momentum.
const BOTS := ["idle", "hold", "mash", "novice", "sharp"]
const REACTION := {"novice": 0.35, "sharp": 0.2}     # seconds behind what the fish is doing
const DECIDE := {"novice": 0.3, "sharp": 0.1}        # seconds between changes of mind

## the real VF autoload (a SceneTree script compiles before autoloads exist, so it can't name it itself)
static func vf() -> Node:
	return VF

## the parts of vf_main the mini-game asks for
class StubStage:
	var manifest := {}
	var _scene := {}
	var position := Vector2.ZERO
	var _bobber := Vector2.ZERO
	func _tex(_path: String) -> Texture2D: return null
	func burst(_kind: String, _at: Vector2) -> void: pass

class StubMain:
	var stage := StubStage.new()
	var touch := true
	func is_touch() -> bool: return touch
	func sbox(_c = null, _r = 0, _b = 0, _bc = null, _s = 0, _p = 0) -> StyleBoxFlat: return StyleBoxFlat.new()
	func lbl(text = "", _size = 16, _col = null, _outline = 0) -> Label:
		var l := Label.new()
		l.text = str(text)
		return l
	func icon(_tex = null, _size = 16) -> TextureRect: return TextureRect.new()
	func ph(_name = "") -> Texture2D: return null
	func icon_for(_kind = "", _name = "") -> Texture2D: return null
	func keycap(_text = "") -> Control: return Control.new()
	func money_str(n: float) -> String: return "$%d" % int(n)

## one round from the first bite to the result. Returns {"won": bool, "secs": float} (the round's length).
static func play(tree: SceneTree, bot: String, fish: String, tier: int, touch := true, dt := 1.0 / 30.0) -> Dictionary:
	var main := StubMain.new()
	main.touch = touch
	var mg: Control = load("res://scripts/vf/vf_minigame.gd").new()
	mg.setup(main, fish, tier)
	return _run(tree, mg, bot, dt)

## one round against the rival of VF.gerald's stage, as if they had lost to him `tries` times (nothing is paid or saved)
static func play_rival(tree: SceneTree, bot: String, tries: int, touch := true, dt := 1.0 / 30.0) -> Dictionary:
	var main := StubMain.new()
	main.touch = touch
	VF.gerald.tries = tries
	var mg: Control = load("res://scripts/vf/vf_minigame.gd").new()
	mg.setup_rival(main)
	return _run(tree, mg, bot, dt)

static func rival_rate(tree: SceneTree, bot: String, tries: int, n: int) -> float:
	var rounds: int = VF.reel_rounds
	var wins := 0
	for i in n:
		if play_rival(tree, bot, tries).won: wins += 1
		VF.reel_rounds = rounds
	VF.gerald.tries = 0
	return float(wins) / float(n)

static func _run(tree: SceneTree, mg: Control, bot: String, dt: float) -> Dictionary:
	tree.root.add_child(mg)
	mg.set_process(false)
	mg.phase = "play"
	var seen: Array = []                  # where the fish was, oldest first (a player reacts to what they saw)
	var lag := int(float(REACTION.get(bot, 0.0)) / dt)
	var state := {"on": false, "left": 0.0, "away": 0.0}
	mg.sim_hold = func() -> bool:
		match bot:
			"idle": return false
			"hold": return true
			"mash":
				state.left -= dt
				if state.left <= 0.0:
					state.on = not state.on
					state.left = randf_range(0.1, 0.3) if state.on else randf_range(0.1, 0.5)
				return state.on
		seen.append(mg.fish_y)
		var saw: float = seen[maxi(0, seen.size() - 1 - lag)]
		if bot == "novice":                   # looks somewhere else for a moment, now and then
			state.away -= dt
			if state.away < -1.0 and randf() < dt * 0.5: state.away = randf_range(0.3, 0.8)
			if state.away > 0.0: return false
		state.left -= dt
		if state.left <= 0.0:
			state.left = float(DECIDE[bot]) * randf_range(0.8, 1.2)
			var net: float = mg.zone_y + mg._net_h() * 0.5
			if bot == "sharp": net += mg.zone_v * 0.22
			state.on = net < saw
		return state.on
	while mg.phase == "play":
		mg._play(dt)
	var out := {"won": mg.won, "secs": mg.play_t}
	mg.sim_hold = Callable()
	mg.free()
	return out

## how often this bot wins, out of n rounds, starting from the rounds played so far
static func win_rate(tree: SceneTree, bot: String, fish: String, tier: int, rounds: int, n: int, touch := true, dt := 1.0 / 30.0) -> float:
	var wins := 0
	for i in n:
		VF.reel_rounds = rounds
		if play(tree, bot, fish, tier, touch, dt).won: wins += 1
	return float(wins) / float(n)

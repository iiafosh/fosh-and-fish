extends RefCounted
## What a round of Reel it in! costs a clumsy player, for tools/pace_sim.gd and tests/idle_balance_probe.gd, which play
## thousands of hours and can't afford the real mini-game. The numbers are tests/reel_bot.gd's novice and sharp players on
## a phone, against the fish tier that bit and the rod's reel power, measured with tools/reel_sim.gd (50 rounds each).

const TAP_OVERHEAD := 0.4        # seconds a real player loses per cast (reaction, banners)
const LINE_OUT := 0.64           # the cast (vf_stage.cast)
const BITE := 0.55               # the fish pops up (vf_minigame "intro")
const ENDING_WON := 2.1          # the mugshot. A tap skips it; this doesn't.
const ENDING_LOST := 2.5         # the WANTED poster

const POWERS := [0.0, 0.105, 0.263, 0.368, 0.579, 1.0]    # Plastic, Steel, Alloy, Magma, Infinity, Dark
const WINS := [
	[0.76, 0.48, 0.20, 0.06, 0.00],
	[0.90, 0.40, 0.32, 0.18, 0.04],
	[0.96, 0.66, 0.36, 0.14, 0.12],
	[1.00, 0.80, 0.64, 0.24, 0.20],
	[1.00, 0.98, 0.74, 0.56, 0.34],
	[1.00, 1.00, 1.00, 0.84, 0.70],
]
const SECS := [
	[5.9, 6.9, 7.9, 8.4, 8.8],
	[5.3, 7.2, 7.8, 8.0, 8.7],
	[4.0, 6.1, 7.3, 8.1, 8.3],
	[3.9, 5.8, 6.5, 7.9, 8.1],
	[3.0, 4.6, 6.1, 7.2, 7.8],
	[2.2, 3.1, 4.2, 5.5, 6.8],
]

const WINS_SHARP := [
	[1.00, 1.00, 0.96, 0.88, 0.50],
	[1.00, 1.00, 0.98, 0.94, 0.70],
	[1.00, 1.00, 1.00, 1.00, 0.90],
	[1.00, 1.00, 0.98, 1.00, 0.84],
	[1.00, 1.00, 1.00, 1.00, 0.92],
	[1.00, 1.00, 1.00, 1.00, 0.98],
]
const SECS_SHARP := [
	[2.8, 3.4, 4.6, 5.7, 7.3],
	[2.6, 3.1, 4.2, 5.0, 6.7],
	[2.4, 3.1, 3.6, 4.7, 6.1],
	[2.3, 2.8, 3.6, 4.3, 6.5],
	[2.0, 2.6, 3.2, 4.0, 5.4],
	[1.8, 2.3, 2.7, 2.9, 3.5],
]

static func _lookup(table: Array, power: float, tier: int) -> float:
	for i in range(POWERS.size() - 1):
		if power <= POWERS[i + 1]:
			return lerpf(float(table[i][tier]), float(table[i + 1][tier]), (power - POWERS[i]) / (POWERS[i + 1] - POWERS[i]))
	return float(table[-1][tier])

## one round for this game's rod and biome: {"won": bool, "secs": from this tap to the next}
static func round_for(g, sharp := false) -> Dictionary:
	var odds: Array = g.species_odds()
	var roll: float = g.rng.randf()
	var tier := 0
	var acc := 0.0
	for k in range(4, -1, -1):
		acc += float(odds[k])
		if roll < acc:
			tier = k
			break
	var power := VFData.rod_reel_power(g.rod)
	var won: bool = g.rng.randf() < _lookup(WINS_SHARP if sharp else WINS, power, tier)
	var secs: float = LINE_OUT + BITE + _lookup(SECS_SHARP if sharp else SECS, power, tier) + (ENDING_WON if won else ENDING_LOST) + TAP_OVERHEAD
	return {"won": won, "secs": maxf(secs, g.cooldown() + TAP_OVERHEAD)}

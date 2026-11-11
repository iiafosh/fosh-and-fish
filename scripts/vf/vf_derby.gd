extends RefCounted
## The Fishing Derby (1.1): three minutes of Reel it in! rounds back to back, at one fair difficulty for everyone (your
## rod, your level and the easing don't count), for points, and a weekly board of everyone's best run (Backend.derby_*,
## supabase/schema.sql "the fishing derby"). A win scores 10 + 5 x tier, +10 when perfect, times the combo (x1, x1.25 ..
## x2 for 1..5 wins in a row: VFData.derby_points). The fish get rarer as the run goes on (VFData.derby_tier). Signed out
## it still plays, and the week's best stays on this device. When a week is over, its prize comes once
## (VFData.DERBY_PRIZES). Menu -> Derby. The run pays like a few casts' worth too (VF.pay_find).

const MG := "res://scripts/vf/vf_minigame.gd"
const C_TEXT := Color("#2b3a40")        # (copies of vf_main's palette, like the other panels)
const C_MUTED := Color("#6d7c7d")

var m                                   # vf_main
var running := false
var t_left := 0.0                       # seconds left in the run
var score := 0
var wins := 0
var rounds := 0
var perfect := 0
var combo := 0
var last := {}                          # the run that just ended, for the panel
var _run := -1                          # the server's id for this run (signed in), else -1
var _count := 0.0                       # the 3-2-1 before the first round
var _gap := 0.0                         # a beat between rounds
var _mg: Control
var _layer: CanvasLayer                 # (above the mini-game)
var _hud: PanelContainer
var _hud_time: Label
var _hud_score: Label
var _big: Label
var _claimed_this_session := false

func _init(main) -> void:
	m = main
	Backend.derby_changed.connect(func():
		if m._panel_kind == "derby" and m.overlay.visible and not running: m._render_panel())

## how long a run is (-- --derby-secs=N for tests)
static func run_secs() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--derby-secs="): return maxf(5.0, float(a.substr(13)))
	return VFData.DERBY_SECS

# ===================================================================== the run
func start() -> void:
	if running: return
	m._close_panel()
	running = true
	t_left = run_secs()
	score = 0
	wins = 0
	rounds = 0
	perfect = 0
	combo = 0
	last = {}
	_run = -1
	_count = 3.0
	_gap = 0.0
	_build_hud()
	_show_big("3")
	AudioManager.play_click()
	if Backend.state == "signed_in":
		var r: Dictionary = await Backend.derby_start()
		if bool(r.get("ok", false)): _run = int(r.get("run", -1))

func tick(delta: float) -> void:
	if not running: return
	if _count > 0.0:
		var before := ceili(_count)
		_count -= delta
		if _count <= 0.0:
			_show_big("FISH!")
			_next_round()
		elif ceili(_count) != before:
			_show_big(str(ceili(_count)))
			AudioManager.play_click()
		return
	t_left = maxf(0.0, t_left - delta)
	_update_hud()
	if _mg != null and is_instance_valid(_mg): return
	if t_left <= 0.0:
		_end()
		return
	_gap -= delta
	if _gap <= 0.0: _next_round()

func _next_round() -> void:
	var tier: int = VFData.derby_tier(rounds)
	var fish: String = VFData.BIOMES[VF.biome].fish[tier]
	var mg: Control = load(MG).new()
	mg.setup_derby(m, fish, tier)
	mg.resolved.connect(_on_round.bind(mg))
	mg.tree_exited.connect(func():
		if _mg == mg: _mg = null
		if m.minigame == mg: m.minigame = null
		_gap = 0.3)
	_mg = mg
	m.minigame = mg
	m.add_child(mg)
	_gap = 0.3

func _on_round(won: bool, mg) -> void:
	rounds += 1
	if won:
		wins += 1
		combo += 1
		if mg.perfect: perfect += 1
		var pts: int = VFData.derby_points(mg.tier, mg.perfect, combo)
		score += pts
		mg.derby_points = pts
		mg.derby_combo = combo
	else:
		combo = 0
	_update_hud()

func _end() -> void:
	running = false
	_free_hud()
	var pay: int = VF.pay_find(float(score) / 15.0) if score > 0 else 0
	var online := _run >= 0
	var new_best: bool = VF.derby_record(score, online)
	last = {"score": score, "wins": wins, "rounds": rounds, "perfect": perfect, "pay": pay, "new_best": new_best,
		"best": int(VF.derby.best), "rank": 0, "players": 0, "online": online, "why": ""}
	AudioManager.play_success()
	m._open_panel("derby")
	if not online: return
	var r: Dictionary = await Backend.derby_finish(_run, score, wins, rounds, perfect)
	if bool(r.get("ok", false)):
		last.rank = int(r.get("rank", 0))
		last.players = int(r.get("players", 0))
		last.best = maxi(int(r.get("best", 0)), int(last.best))
	else:
		last.why = String(r.get("reason", "error"))
	Backend.load_derby()

# ===================================================================== HUD
func _build_hud() -> void:
	_free_hud()
	_layer = CanvasLayer.new()
	_layer.layer = 6
	m.add_child(_layer)
	_hud = PanelContainer.new()
	_hud.add_theme_stylebox_override("panel", m.sbox(Color("#10303a", 0.92), 999, 2, Color("#ffd75e"), 18, 8))
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(m.icon(m.ph("trophy"), 22))
	_hud_time = m.lbl("", 22, Color.WHITE)
	_hud_score = m.lbl("", 22, Color("#ffd75e"))
	h.add_child(_hud_time)
	h.add_child(_hud_score)
	_hud.add_child(h)
	_layer.add_child(_hud)
	_big = m.lbl("", 110, Color.WHITE, 10)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_big)
	_update_hud()

func _update_hud() -> void:
	if _hud == null or not is_instance_valid(_hud): return
	_hud_time.text = "DERBY  %s" % m._clock(ceilf(t_left))
	_hud_score.text = "%s pts%s" % [VF.commas(score), ("   x%d" % combo) if combo >= 2 else ""]
	_hud.reset_size()
	_hud.position = Vector2((m.size.x - _hud.size.x) * 0.5, 10.0)

func _show_big(text: String) -> void:
	if _big == null or not is_instance_valid(_big): return
	_big.text = text
	_big.reset_size()
	_big.pivot_offset = _big.size * 0.5
	_big.position = (m.size - _big.size) * 0.5
	_big.scale = Vector2(1.6, 1.6)
	_big.modulate.a = 1.0
	var tw := _big.create_tween()
	tw.tween_property(_big, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45 if text != "FISH!" else 0.2)
	tw.tween_property(_big, "modulate:a", 0.0, 0.25)

func _free_hud() -> void:
	if _layer != null and is_instance_valid(_layer): _layer.queue_free()
	_layer = null
	_hud = null
	_big = null

# ===================================================================== the panel
## Menu -> Derby
func panel() -> void:
	var signed_in: bool = Backend.state == "signed_in"
	if Backend.configured() and Backend.derby_state == "": Backend.load_derby()
	if signed_in and not _claimed_this_session:
		_claimed_this_session = true
		_claim_prizes()
	if not last.is_empty():
		m.panel_body.add_child(_result_card())
	var how: Label = m.lbl("Three minutes of Reel it in!, round after round. Everyone gets the same fish at the same difficulty, so it's all you: a win scores more for a rarer fish, a perfect round scores extra, and wins in a row multiply. This week's race ends in %s." % _ends_text(), 14, C_TEXT)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.panel_body.add_child(how)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var go: Button = m._act("Play again" if not last.is_empty() else "Start the Derby", Color("#d4920f"), func(): start(); return "")
	go.custom_minimum_size = Vector2(240, 52)
	row.add_child(go)
	var mine: Label = m.lbl("Your best this week: %s points%s" % [VF.commas(int(VF.derby_best_now())), "" if signed_in else "  (on this device)"], 15, C_TEXT)
	mine.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mine)
	m.panel_body.add_child(row)
	if not signed_in:
		var n: Label = m.lbl("Sign in (Menu -> Account) to race everyone on the weekly board. You can play and keep your best here without it.", 13, Color("#7c3aed"))
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.panel_body.add_child(n)
	m.panel_body.add_child(m.lbl("This week's board", 18))
	if Backend.derby_board.is_empty():
		m.panel_body.add_child(m.lbl("No one on it yet. Be the first!" if Backend.derby_state != "loading" else "Loading the board...", 14, C_MUTED))
	else:
		var i := 0
		for r in Backend.derby_board.slice(0, 20):
			i += 1
			var me: bool = signed_in and String(r.get("display_name", "")).to_lower() == Backend.display_name.to_lower()
			var runs := int(r.get("runs", 1))
			m.panel_body.add_child(m.lbl("%d.  %s  ·  %s points  (%d run%s)" % [i, r.get("display_name", "?"), VF.commas(int(r.get("best", 0))), runs, "" if runs == 1 else "s"],
				15, Color("#b45309") if me else C_TEXT))
	var prizes: Label = m.lbl("When the week ends: the top 3 get the Derby Cup hat (and %d or %d Event Stars), the top 10 get %d Event Stars, and everyone who raced gets %d." % [
		VFData.DERBY_PRIZES[0][1], VFData.DERBY_PRIZES[1][1], VFData.DERBY_PRIZES[2][1], VFData.DERBY_PRIZES[3][1]], 13, C_MUTED)
	prizes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.panel_body.add_child(prizes)

func _result_card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", m.sbox(Color("#fff4d6"), 16, 2, Color("#f0b429"), 16))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(m.lbl("%s points%s" % [VF.commas(int(last.score)), "  ·  a new best!" if last.new_best and int(last.score) > 0 else ""], 28, Color("#8a5a00")))
	v.add_child(m.lbl("%d wins out of %d rounds  ·  %d perfect  ·  +%s" % [int(last.wins), int(last.rounds), int(last.perfect), m.money_str(int(last.pay))], 15, C_TEXT))
	var where := ""
	if last.online:
		if int(last.rank) > 0: where = "You're #%d of %d on this week's board." % [int(last.rank), int(last.players)]
		elif String(last.why) != "": where = "The board didn't take this run (%s)." % String(last.why)
		else: where = "Putting it on the board..."
	else:
		where = "Sign in to put your runs on the weekly board."
	v.add_child(m.lbl(where, 14, Color("#7c3aed")))
	p.add_child(v)
	return p

func _ends_text() -> String:
	var s := int(VF.derby_ends_in())
	if s >= 86400: return "%dd %dh" % [s / 86400, (s % 86400) / 3600]
	return "%dh %02dm" % [s / 3600, (s % 3600) / 60]

## A finished week's prize, once per week (the server checks the rank and that it wasn't claimed yet)
func _claim_prizes() -> void:
	for wk in VF.derby_unclaimed():
		var r: Dictionary = await Backend.derby_claim(wk)
		if bool(r.get("ok", false)):
			var got: Dictionary = VF.derby_grant(wk, int(r.get("rank", 0)))
			var what := "+%d Event Stars" % int(got.stars)
			if String(got.hat) != "": what += " and the %s" % VFData.HATS[got.hat].name
			m._toast("Derby, week of %s: you came #%d of %d! %s" % [wk, int(r.get("rank", 0)), int(r.get("players", 0)), what], "prestige")
			AudioManager.play_levelup()
		elif String(r.get("reason", "")) in ["claimed", "no_run"]:
			VF.derby_grant(wk, 0)                    # (nothing to give here: just don't ask again)
	if m._panel_kind == "derby" and m.overlay.visible and not running: m._render_panel()

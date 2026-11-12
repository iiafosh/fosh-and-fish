extends RefCounted
## BETA (branch `beta`, not in the game yet): three ideas from the old list, to try before they go in. Menu -> Beta.
##   Expeditions  send a boat away for 30 min, 2 h or 8 h of real time (it keeps going with the game closed); it comes
##                back with a chest (better for longer trips), money, and maybe a pet egg
##   Pet eggs     from expeditions, or EGG_STARS Event Stars; they hatch in EGG_MINUTES into one of the five pets (odds
##                shown); a pet you already have becomes pet XP. A sure road to pets (a cast finds one 1 in 10,000)
##   Codes        a word from the owner's posts (the Loadout launch, socials) pays once per save. Only SHA-256 hashes of
##                the codes are in the game, so nobody can read them out of its files
## The beta keeps its state in user://beta.json, has its own save folder (project.godot custom_user_dir) and plays
## offline (Backend), so it can never touch a real save. Test: godot --path . -- --capture=DIR --beta-test

const SAVE := "user://beta.json"
const TRIPS := [       # [id, name, minutes, chest tier, money (casts' worth), egg chance]
	["short", "A quick look around", 30, "rare", 40.0, 0.10],
	["long", "Over the horizon", 120, "epic", 160.0, 0.30],
	["night", "The long night voyage", 480, "legendary", 600.0, 0.75],
]
const EGG_MINUTES := 20
const EGG_STARS := 120
const EGG_SLOTS := 3
const EGG_ODDS := {"Puffer": 30, "Zebrafish": 25, "Dolphin": 20, "Axolotl": 15, "Tuna": 10}
const CODES := {       # sha256(code in lower case) -> what it gives
	"6acd1cb1cd3d3593327ae35ef1bb78a36e29f443b447b484f15601583b5d6ed5": {"label": "LOADOUT", "pearls": 50, "egg": 1},
	"870ee170638d6450228df951e449343caf14d02aa99b4d79f3215b4bc2d7fc5f": {"label": "FOSHFISH", "stars": 60},
	"21aafe2f10e974a8dd7c1533b954116ff776f572fda8abf523641f33bd8e42bc": {"label": "GERALD", "casts": 200.0},
}
const C_BETA := Color("#7c5cd6")

var m
var trips := {}                 # trip id -> unix time it's back
var eggs: Array = []            # unix times they're ready
var codes: Array = []           # labels of the codes used
var offset := 0.0               # (tests: fast-forward)
var _redraw := 0.0

func _init(main) -> void:
	m = main
	_load()
	m.get_tree().process_frame.connect(_tick)

func now() -> float:
	return Time.get_unix_time_from_system() + offset

func _load() -> void:
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null: return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary): return
	for k in (d.get("trips", {}) as Dictionary): trips[str(k)] = float(d.trips[k])
	for t in d.get("eggs", []): eggs.append(float(t))
	for c in d.get("codes", []): codes.append(str(c))

func _save() -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({"trips": trips, "eggs": eggs, "codes": codes}))

func _tick() -> void:                            # (the open panel's clocks count down)
	if m._panel_kind != "beta" or not m.overlay.visible: return
	_redraw -= m.get_process_delta_time()
	if _redraw <= 0.0:
		_redraw = 1.0
		m._render_panel()

static func clock(secs: float) -> String:
	var s := maxi(0, int(ceil(secs)))
	if s >= 3600: return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]

# ---------------------------------------------------------------- expeditions
func send(id: String) -> String:
	if trips.has(id): return "That boat is already out."
	if VF.level < 5: return "Expeditions open at level 5."
	for t in TRIPS:
		if t[0] == id:
			trips[id] = now() + float(t[2]) * 60.0
			_save()
			m._toast("Your boat set off: %s. Back in %s." % [t[1], clock(float(t[2]) * 60.0)], "quest")
			return ""
	return "?"

func collect(id: String) -> String:
	if not trips.has(id) or now() < float(trips[id]): return "Not back yet."
	for t in TRIPS:
		if t[0] != id: continue
		trips.erase(id)
		var out: Dictionary = VF._open_chest(String(t[3]))
		VF.chest_found.emit(out, "expedition")
		var pay: int = VF.pay_find(float(t[4]))
		var egg := randf() < float(t[5]) and eggs.size() < EGG_SLOTS
		if egg: eggs.append(now() + EGG_MINUTES * 60.0)
		_save()
		VF.changed.emit()
		m._toast("Your boat is back: %s%s!" % [m.money_str(pay), " and a pet egg" if egg else ""], "quest")
		return ""
	return "?"

# ---------------------------------------------------------------- eggs
func buy_egg() -> String:
	if eggs.size() >= EGG_SLOTS: return "Your nest is full: hatch an egg first."
	if VF.stars < EGG_STARS: return "An egg is %d Event Stars (you have %d)." % [EGG_STARS, VF.stars]
	VF.stars -= EGG_STARS
	eggs.append(now() + EGG_MINUTES * 60.0)
	_save()
	VF.changed.emit()
	return ""

func hatch(i: int) -> String:
	if i < 0 or i >= eggs.size() or now() < float(eggs[i]): return "Not ready yet."
	eggs.remove_at(i)
	var roll := randi() % 100
	var got := "Puffer"
	for p in EGG_ODDS:
		roll -= int(EGG_ODDS[p])
		if roll < 0:
			got = p
			break
	if VF.pets.has(got):
		VF._add_pet_xp(got, VF._pet_xp_needed(int(VF.pets[got].level)))
		m._toast("It's a %s! You have one, so it became pet XP." % got, "pet")
	else:
		VF.pets[got] = {"level": 1, "xp": 0}
		if VF.pet == "": VF.pet = got
		m._toast("It's a %s! Your new pet." % got, "pet")
	_save()
	VF.changed.emit()
	return ""

# ---------------------------------------------------------------- codes
func redeem(text: String) -> String:
	var c := text.strip_edges().to_lower()
	if c == "": return "Type a code first."
	var r: Dictionary = CODES.get(c.sha256_text(), {})
	if r.is_empty(): return "That code doesn't exist (or it ran out)."
	if String(r.label) in codes: return "You already used %s." % r.label
	codes.append(String(r.label))
	var got := []
	if r.has("pearls"):
		VF.pearls += int(r.pearls)
		got.append("%d Pearls" % int(r.pearls))
	if r.has("stars"):
		VF.stars += int(r.stars)
		got.append("%d Event Stars" % int(r.stars))
	if r.has("casts"):
		got.append(m.money_str(VF.pay_find(float(r.casts))))
	if r.has("egg") and eggs.size() < EGG_SLOTS:
		eggs.append(now() + EGG_MINUTES * 60.0)
		got.append("a pet egg")
	_save()
	VF.changed.emit()
	m._toast("Code %s: %s!" % [r.label, ", ".join(got)], "quest")
	return ""

# ---------------------------------------------------------------- the panel
func panel() -> void:
	var body: VBoxContainer = m.panel_body
	var note: Label = m.lbl("BETA: ideas being tried, not in the game yet. This copy has its own save and plays offline.", 13, C_BETA)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	body.add_child(m.lbl("Expeditions", 22, m.C_TEXT))
	var t_now := now()
	for t in TRIPS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(m.lbl(String(t[1]), 17, m.C_TEXT))
		var tier := String(t[3]).capitalize()
		col.add_child(m.lbl("%s  ·  %s %s chest, money%s" % [clock(float(t[2]) * 60.0), "an" if tier[0] in "AEIOU" else "a", tier,
			", often an egg" if float(t[5]) >= 0.5 else ", maybe an egg"], 13, m.C_MUTED))
		row.add_child(col)
		var id: String = t[0]
		if not trips.has(id):
			row.add_child(m._act("Send", C_BETA, func(): return send(id), VF.level >= 5))
		elif t_now < float(trips[id]):
			row.add_child(m.lbl("back in " + clock(float(trips[id]) - t_now), 15, m.C_MUTED))
		else:
			row.add_child(m._act("Collect", m.C_GOOD, func(): return collect(id)))
		body.add_child(row)
	body.add_child(m.lbl("Pet eggs", 22, m.C_TEXT))
	var odds := []
	for p in EGG_ODDS: odds.append("%s %d%%" % [p, EGG_ODDS[p]])
	body.add_child(m.lbl("Hatch in %d min into  %s" % [EGG_MINUTES, "  ·  ".join(odds)], 13, m.C_MUTED))
	var nest := HBoxContainer.new()
	nest.add_theme_constant_override("separation", 10)
	for i in eggs.size():
		var at := float(eggs[i])
		if t_now >= at:
			nest.add_child(m._act("Hatch egg %d" % (i + 1), m.C_GOOD, func(): return hatch(i)))
		else:
			nest.add_child(m.lbl("Egg %d: %s  " % [i + 1, clock(at - t_now)], 15, m.C_TEXT))
	if eggs.size() < EGG_SLOTS:
		nest.add_child(m._act("Buy an egg · %d Event Stars" % EGG_STARS, C_BETA, func(): return buy_egg()))
	body.add_child(nest)
	body.add_child(m.lbl("Codes", 22, m.C_TEXT))
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	var edit := LineEdit.new()
	edit.placeholder_text = "Type a code"
	edit.custom_minimum_size = Vector2(220, 46)
	crow.add_child(edit)
	crow.add_child(m._act("Redeem", C_BETA, func(): return redeem(edit.text)))
	body.add_child(crow)
	if not codes.is_empty(): body.add_child(m.lbl("Used: " + ", ".join(codes), 13, m.C_MUTED))
	var later: Label = m.lbl("Next, once the server has them: clans (a crew name and a weekly crew total) and shiny trading (a swap both sides accept, checked by the server). See docs/BETA.md.", 13, m.C_MUTED)
	later.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(later)

# ---------------------------------------------------------------- test
func test(dir: String) -> void:
	VF.autosave = false
	m._veteran("River")
	VF.tutorial = 99
	m._close_panel()
	trips.clear()
	eggs.clear()
	codes.clear()
	offset = 0.0
	await m.get_tree().create_timer(1.0).timeout
	var ok := func(cond: bool, what: String): print("BETA %s %s" % ["PASS" if cond else "FAIL", what])
	for t in TRIPS: send(t[0])
	m._open_panel("beta")
	await m.get_tree().create_timer(0.5).timeout
	await m._shot(dir + "/beta_0_sent.png")
	ok.call(trips.size() == 3 and collect("short") != "", "three boats out; nothing to collect before they're back")
	offset = 30 * 60 + 5
	var money0: int = VF.money
	var chests0: int = VF.stats.chests
	ok.call(collect("short") == "" and VF.money > money0 and VF.stats.chests == chests0 + 1, "back after 30 min: a chest and money")
	offset = 8 * 3600 + 5
	collect("long")
	collect("night")
	ok.call(trips.is_empty(), "the long trips come back too")
	VF.stars = 500
	eggs.clear()
	var stars0: int = VF.stars
	ok.call(buy_egg() == "" and VF.stars == stars0 - EGG_STARS and eggs.size() == 1, "an egg for %d Event Stars" % EGG_STARS)
	ok.call(hatch(0) != "", "an egg doesn't hatch early")
	offset += EGG_MINUTES * 60 + 5
	var pets0: int = VF.pets.size()
	var xp0 := 0
	for p in VF.pets: xp0 += int(VF.pets[p].xp) + 1000 * int(VF.pets[p].level)
	ok.call(hatch(0) == "" and eggs.is_empty(), "it hatches after %d min" % EGG_MINUTES)
	var xp1 := 0
	for p in VF.pets: xp1 += int(VF.pets[p].xp) + 1000 * int(VF.pets[p].level)
	ok.call(VF.pets.size() > pets0 or xp1 > xp0, "into a pet (or pet XP)")
	var pearls0: int = VF.pearls
	ok.call(redeem("nope") != "" and redeem("LoadOut") == "" and VF.pearls == pearls0 + 50 and redeem("loadout") != "", "codes: unknown no, LOADOUT once (any case), not twice")
	m._render_panel()
	await m.get_tree().create_timer(0.5).timeout
	await m._shot(dir + "/beta_1_after.png")
	trips.clear()
	eggs.clear()
	codes.clear()
	offset = 0.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

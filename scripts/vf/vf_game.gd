extends Node
## Virtual Fisher game simulation (autoload "VF").
## All formulas follow the wiki/encyclopedia; see vf_data.gd for sources.

signal changed
signal trip_done(result: Dictionary)
signal leveled_up(new_level: int, money_reward: int)
signal toast(text: String, kind: String)
signal goal_done(text: String, reward: String, chest: Dictionary)

const SAVE_PATH := "user://vf_save.json"
const SAVE_VERSION := 1
const MAX_LEVEL := 25000

var rng := RandomNumberGenerator.new()
var _xp_table := PackedInt64Array()
var _money_table := PackedInt64Array()

# --- persistent state ---
var player_name := "Fisher"
var prestige := 0
var level := 1
var xp := 0
var money := 0
var biome := "River"
var rod := "Plastic Rod"
var bait := ""
var pet := ""
var owned_rods: Array = ["Plastic Rod"]
var boats_owned := 0                       # boats are bought in order
var bait_stock := {}
var inventory := {}
var exotics := {"gold": 0, "emerald": 0, "lava": 0, "diamond": 0, "azure": 0}
var hooks := 0
var upgrades := {}
var specials := {}
var league := {}
var perks := {}
var charms := {}                           # id -> charms collected
var pets := {}                             # name -> {"level", "xp"}
var trips_without_pet := 0
var boosts := {"fish": 0.0, "treasure": 0.0, "worker": 0.0}   # unix expiry
var personal_boosters := 0
var personal_until := 0.0
var stats := {"trips": 0, "fish": 0, "chests": 0, "charms": 0, "money_earned": 0, "sells": 0, "bait_casts": 0}
var discovered := {}                      # species -> total ever caught (fishdex)
var goals_done := 0                       # STARTER_GOALS completed (in order)
var tutorial := 0                         # onboarding step (UI)
var quest_day := ""
var quest_progress := {}
var quest_claimed := {}
var week_key := ""
var week_trips := 0
var week_hooks := 0
var daily_last := 0.0
var daily_streak := 0
var worker_fish_total := 0

# --- runtime ---
var _last_cast_ms := -100000
var _worker_accum := 0.0

var _defaults := {}

func _init() -> void:
	rng.randomize()
	_load_levels()
	_defaults = to_dict().duplicate(true)
	_tok_connect()                         # FishTok: auto-posts + daily challenge progress

func _ready() -> void:
	_migrate_old_user_dir()
	load_game()
	_roll_quest_day()

func _process(delta: float) -> void:
	if is_boost_active("worker"):
		_worker_accum += delta
		var cd := worker_cooldown()
		while _worker_accum >= cd:
			_worker_accum -= cd
			_worker_trip()
	else:
		_worker_accum = 0.0

# ------------------------------------------------------------------ levels
func _load_levels() -> void:
	var f := FileAccess.open("res://data/vf/levels.txt", FileAccess.READ)
	if f == null:
		push_error("levels.txt missing")
		return
	_xp_table.resize(MAX_LEVEL + 1)
	_money_table.resize(MAX_LEVEL + 1)
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(",")
		var lvl := int(parts[0])
		if lvl <= MAX_LEVEL:
			_xp_table[lvl] = int(parts[1])
			_money_table[lvl] = int(parts[2])

func xp_to_next(lvl: int = -1) -> int:
	if lvl < 0: lvl = level
	if lvl >= MAX_LEVEL or lvl >= _xp_table.size(): return 0
	return _xp_table[lvl]

func levelup_money(lvl: int) -> int:
	if lvl < 0 or lvl >= _money_table.size(): return 0
	return _money_table[lvl]

func add_xp(amount: int) -> void:
	xp += amount
	while level < MAX_LEVEL and xp_to_next() > 0 and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		var reward := levelup_money(level)
		money += reward
		_quest_add("levelups", 1)
		leveled_up.emit(level, reward)
		for b in VFData.BIOME_ORDER:
			if VFData.BIOMES[b].level == level and level > 1:
				toast.emit("New biome unlocked: %s!" % b, "unlock")

# ------------------------------------------------------------ multipliers
func up(id: String) -> int: return int(upgrades.get(id, 0))
func sp(id: String) -> int: return int(specials.get(id, 0))
func lg(id: String) -> int: return int(league.get(id, 0))
func pk(id: String) -> int: return int(perks.get(id, 0))

func charm_tier(id: String) -> int:
	var n := int(charms.get(id, 0))
	# tier t needs t charms -> t(t+1)/2 total
	return mini(int((sqrt(8.0 * n + 1.0) - 1.0) / 2.0), VFData.charm_tier_cap(prestige))

func charms_total() -> int:
	var s := 0
	for id in VFData.CHARM_ORDER:
		s += mini(int(charms.get(id, 0)), VFData.charm_total_cap(prestige) / 8)
	return s

func stat_mult() -> float:
	return (1.0 + 0.02 * sp("statistician")) * (1.0 + 0.10 * pk("international_ties"))

func bait_eff() -> float:
	return 1.0 + 0.15 * sp("bait_lover") + 0.10 * lg("bait_helper")

func has_bait() -> bool:
	return bait != "" and int(bait_stock.get(bait, 0)) > 0

func bait_stat(key: String) -> float:
	if not has_bait(): return 0.0
	return float(VFData.BAITS[bait].get(key, 0.0)) * bait_eff()

func pet_level_cap() -> int:
	return 100 + 5 * lg("pet_helper")

func pet_stat(key: String, pet_name: String = "") -> float:
	if pet_name == "": pet_name = pet
	if pet_name == "" or not pets.has(pet_name): return 0.0
	var b: Dictionary = VFData.PETS[pet_name].buffs
	if not b.has(key): return 0.0
	var lv := int(pets[pet_name].level)
	var pct: float = b[key][0] + b[key][1] * lv
	return pct / 100.0 * (1.0 + bait_stat("pet_eff"))

func fish_catch_mult() -> float:
	return (1.0 + 0.025 * charm_tier("endurance") + 0.05 * sp("aquatic_expert") + 0.25 * pk("fish_whisperer")
		+ pet_stat("catch") + bait_stat("catch")) * stat_mult()

func fish_quality_mult() -> float:
	return maxf(0.1, 1.0 + 0.05 * up("better_fish") + 0.40 * pk("virtual_fisher") + pet_stat("quality")
		+ bait_stat("quality")) * stat_mult()

func marketing_mult() -> float:
	var t := charm_tier("marketing")
	if t <= 50: return pow(1.05, t)
	return (1.0 + 0.05 * (t - 50)) * pow(1.05, 50)

func sell_mult() -> float:
	return (1.0 + 0.05 * up("salesman") + 0.05 * sp("fish_ovens") + 0.15 * sp("ultimate_salesman")
		+ 0.40 * pk("business_education") + 0.20 * pk("virtual_fisher")) * marketing_mult() * stat_mult()

## Beginner's Luck (not in the bot): new players level faster so chests and boosts
## (level 10) arrive in the first session. x3 below level 10, fading to x1 at level 25.
## First run only (prestige 0).
func beginner_mult(lvl: int = -1) -> float:
	if lvl < 0: lvl = level
	if prestige > 0 or lvl >= VFData.BEGINNER_END: return 1.0
	if lvl < 10: return VFData.BEGINNER_XP
	return lerpf(VFData.BEGINNER_XP_AT10, 1.0, float(lvl - 10) / float(VFData.BEGINNER_END - 10))

func xp_mult() -> float:
	return beginner_mult() * maxf(0.1, 1.0 + 0.10 * up("experienced") + 0.15 * sp("highly_experienced") + 0.35 * pk("ancient_one")
		+ 0.20 * pk("virtual_fisher") + 0.05 * charm_tier("experience") + pet_stat("xp") + bait_stat("xp")) * stat_mult()

func treasure_boost_mult() -> float:
	if not is_boost_active("treasure"): return 1.0
	return 1.5 + 0.05 * sp("boost_booster") + 0.05 * lg("fishing_frenzy")

func treasure_chance() -> float:
	var r: Dictionary = VFData.RODS[rod]
	var m := (1.0 + 0.05 * up("more_chests") + 0.025 * charm_tier("treasure") + bait_stat("tc") + pet_stat("tc")) * stat_mult()
	return clampf(r.tc * m * treasure_boost_mult(), 0.0, 1.0)

func treasure_quality() -> float:
	var r: Dictionary = VFData.RODS[rod]
	return (1.0 + r.tq) * (1.0 + 0.10 * up("better_chests") + 0.025 * charm_tier("quality") + bait_stat("tq")
		+ pet_stat("tq")) * stat_mult()

func cooldown() -> float:
	var cd := VFData.BASE_COOLDOWN + float(VFData.BIOMES[biome].cd_add) - 0.25 * boats_owned - 0.05 * charm_tier("haste")
	return maxf(VFData.MIN_COOLDOWN, cd)

func booster_buff() -> float:
	return 1.75 if Time.get_unix_time_from_system() < personal_until else 1.0

func duplicate_chance() -> float:
	return 0.02 * sp("duplicator") + 0.03 * lg("duplicator2")

func worker_cooldown() -> float:
	return VFData.WORKER_BASE_COOLDOWN / (1.0 + 0.1 * sp("boost_booster") + 0.1 * lg("fishing_frenzy"))

# ------------------------------------------------------------------ fishing
func cooldown_left() -> float:
	return maxf(0.0, cooldown() - (Time.get_ticks_msec() - _last_cast_ms) / 1000.0)

func rod_usable(r: String = "", b: String = "") -> bool:
	if r == "": r = rod
	if b == "": b = biome
	return b in VFData.RODS[r].biomes

## Quality table for (rod, biome); falls back to the closest cheaper rod
## measured in that biome, else the cheapest measured one.
func _rod_table(r: String, b: String) -> Array:
	var tables: Dictionary = VFData.RODS[r].tables
	if tables.has(b): return tables[b]
	var cost: int = VFData.RODS[r].cost
	var best: Array = []
	var best_cost := -1
	var cheapest: Array = []
	var cheapest_cost := -1
	for other in VFData.ROD_ORDER:
		var t: Dictionary = VFData.RODS[other].tables
		if other == "Supporter Rod" or not t.has(b): continue
		var c: int = VFData.RODS[other].cost
		if c <= cost and c > best_cost:
			best = t[b]; best_cost = c
		if cheapest_cost < 0 or c < cheapest_cost:
			cheapest = t[b]; cheapest_cost = c
	return best if not best.is_empty() else cheapest

## Wiki fish-quality rule: from the top tier down, E_n = min(Q_n * fq, 1 - sum(higher)).
func species_odds(r: String = "", b: String = "", fq: float = -1.0) -> Array:
	if r == "": r = rod
	if b == "": b = biome
	if fq < 0.0: fq = fish_quality_mult()
	var q: Array = _rod_table(r, b)
	var total := 0.0
	for v in q: total += v
	var e := [0.0, 0.0, 0.0, 0.0, 0.0]
	var used := 0.0
	for i in range(4, 0, -1):
		e[i] = minf(q[i] / total * fq, 1.0 - used)
		used += e[i]
	e[0] = maxf(0.0, 1.0 - used)
	return e

func _fish_count(for_worker: bool = false) -> int:
	var r: Dictionary = VFData.RODS[rod]
	var bm: Dictionary = VFData.BIOMES[biome]
	var cnt := float(rng.randi_range(r.min, r.max))
	var fc := fish_catch_mult()
	if for_worker:
		fc *= 1.0 + 0.10 * up("worker_motivation") + 0.03 * charm_tier("worker")
	cnt *= fc
	cnt += boats_owned
	if not for_worker:
		cnt += round(float(VFData.BAITS[bait].get("fish", 0)) * bait_eff()) if has_bait() else 0.0
	var sr: float = r.get("biome_mult", {}).get(biome, 1.0)
	cnt *= bm.catch_rate * sr * booster_buff()
	if is_boost_active("fish"):
		var bb := sp("boost_booster")
		var ff := lg("fishing_frenzy")
		cnt += bm.catch_rate * rng.randf_range(0.0, 4.0) + 1.0 + bb + rng.randf_range(0.0, 2.0) * ff
		cnt *= 1.05 + 0.01 * ff + 0.01 * bb
	var n := int(floor(cnt))
	if rng.randf() < cnt - n: n += 1
	if n > 0 and rng.randf() < duplicate_chance():
		n *= 2
	return n

func _distribute(n: int) -> Dictionary:
	var odds := species_odds()
	var names: Array = VFData.BIOMES[biome].fish
	var out := {}
	if n <= 0: return out
	if n <= 400:
		for _i in n:
			var roll := rng.randf()
			var acc := 0.0
			var pick: String = names[0]
			for k in range(4, -1, -1):
				acc += odds[k]
				if roll < acc:
					pick = names[k]
					break
			out[pick] = int(out.get(pick, 0)) + 1
	else:
		var left := n
		for k in range(4, 0, -1):
			var exp_n: float = n * odds[k]
			var c := int(floor(exp_n))
			if rng.randf() < exp_n - c: c += 1
			c = mini(c, left)
			if c > 0: out[names[k]] = c
			left -= c
		if left > 0: out[names[0]] = int(out.get(names[0], 0)) + left
	return out

func can_cast() -> String:
	if cooldown_left() > 0.0: return "cooldown"
	if not rod_usable(): return "Your %s can't be used in the %s biome." % [rod, biome]
	return ""

func cast() -> Dictionary:
	var why := can_cast()
	if why != "":
		return {"ok": false, "reason": why}
	_last_cast_ms = Time.get_ticks_msec()
	_roll_quest_day()
	var res := {"ok": true, "fish": {}, "count": 0, "xp": 0, "chest": {}, "pet": "", "bait_used": "",
		"levels": 0, "duplicated": false, "new_species": [], "lucky": 0}
	var used_bait := has_bait()
	var n := _fish_count()
	var caught := _distribute(n)
	var xp_gain := 0.0
	for f in caught:
		inventory[f] = int(inventory.get(f, 0)) + caught[f]
		xp_gain += caught[f] * VFData.FISH[f].xp
		if not discovered.has(f):
			res.new_species.append(f)
		discovered[f] = int(discovered.get(f, 0)) + caught[f]
	xp_gain *= xp_mult()
	res.fish = caught
	res.count = n
	res.xp = int(round(xp_gain))
	# chest
	if level >= 10 and rng.randf() < treasure_chance():
		res.chest = _open_chest(_roll_chest_tier())
		_quest_add("chests", 1)
	elif lg("super_crates") > 0 and rng.randf() < treasure_quality() * lg("super_crates") / 4000.0:
		res.chest = _open_chest("super")
		_quest_add("chests", 1)
	elif level < 10 and stats.trips >= 3 and rng.randf() < 1.0 / 30.0:
		res.chest = _open_chest("common")      # early taste of treasure before chests unlock
	# lucky moments in the early game: a bonus purse every so often
	if level < 25 and stats.trips >= 2 and rng.randf() < 1.0 / 18.0:
		res.lucky = int(maxf(25.0, levelup_money(level) * 1.5))
		money += res.lucky
	# pet
	res.pet = _roll_pet()
	_pet_xp_tick()
	# bait consumption
	if used_bait:
		res.bait_used = bait
		stats.bait_casts = int(stats.get("bait_casts", 0)) + 1
		if rng.randf() >= 0.05 * up("bait_efficiency"):
			bait_stock[bait] = int(bait_stock[bait]) - 1
			if int(bait_stock[bait]) <= 0:
				toast.emit("You ran out of %s." % bait, "warn")
	var lvl_before := level
	add_xp(res.xp)
	res.levels = level - lvl_before
	stats.trips += 1
	stats.fish += n
	trips_without_pet += 1
	_quest_add("fish", n)
	_quest_add("trips", 1)
	_week_trip()
	trip_done.emit(res)
	check_goals()
	changed.emit()
	return res

# ------------------------------------------------------------------ chests
func _roll_chest_tier() -> String:
	var tq := treasure_quality()
	var w := []
	var total := 0.0
	for c in VFData.CHESTS:
		w.append(c.w); total += c.w
	var e := []
	e.resize(w.size())
	var used := 0.0
	for i in range(w.size() - 1, 0, -1):
		e[i] = minf(w[i] / total * tq, 1.0 - used)
		used += e[i]
	e[0] = maxf(0.0, 1.0 - used)
	var roll := rng.randf()
	var acc := 0.0
	for i in range(w.size() - 1, -1, -1):
		acc += e[i]
		if roll < acc: return VFData.CHESTS[i].id
	return "common"

func _chest_def(id: String) -> Dictionary:
	for c in VFData.CHESTS:
		if c.id == id: return c
	return VFData.CHESTS[0]

func _charm_qty_mult() -> float:
	return (1.0 + 0.025 * sp("charmer")) * (1.0 + floor(prestige / 5.0) * 0.1)

func _open_chest(tier: String) -> Dictionary:
	stats.chests += 1
	var out := {"tier": tier, "items": {}}
	var biome_idx := VFData.BIOME_ORDER.find(biome)
	var reward_mult := (1.0 + 0.1 * up("artifact_specialist")) * (1.0 + 0.05 * charm_tier("quantity"))
	if tier == "super":
		var lvl := lg("super_crates")
		var roll := rng.randf()
		if roll < 0.45 + 0.05 * (lvl - 1) and level >= 20:
			_give_charms(rng.randf_range(2.5, 7.5) * _charm_qty_mult(), out)
		elif roll < 0.95:
			for k in ["gold", "emerald", "lava", "diamond"]:
				if level >= VFData.EXOTICS[k].level:
					var a := int(round((3 + biome_idx * 2) * 7.5 * reward_mult))
					exotics[k] += a
					out.items[k] = a
		else:
			_give_xpmoney(7.5 * reward_mult, out)
		return out
	var def := _chest_def(tier)
	var mult: float = def.mult * reward_mult
	var drops: Dictionary = def.drops
	var total := 0.0
	for k in drops: total += drops[k]
	var roll := rng.randf() * total
	var cat := "xpmoney"
	for k in drops:
		roll -= drops[k]
		if roll <= 0.0:
			cat = k
			break
	if cat == "charm":
		if level < 20:
			cat = "xpmoney"
		else:
			var x := _charm_qty_mult()
			if tier == "artifact":
				x = rng.randf_range(x, 3.0 * x)
			_give_charms(x, out)
			return out
	if cat != "xpmoney" and level < VFData.EXOTICS[cat].level:
		cat = "xpmoney"
	if cat == "xpmoney":
		_give_xpmoney(mult, out)
	else:
		var base := rng.randi_range(1, 3) + biome_idx
		var amount := maxi(1, int(round(base * mult)))
		exotics[cat] += amount
		out.items[cat] = amount
	return out

func _give_xpmoney(mult: float, out: Dictionary) -> void:
	var gx := int(round(xp_to_next() * rng.randf_range(0.02, 0.05) * mult))
	var gm := int(round(maxf(100.0, levelup_money(level)) * rng.randf_range(0.2, 0.45) * mult))
	money += gm
	stats.money_earned += gm
	out.items["money"] = gm
	out.items["xp"] = gx
	add_xp(gx)

func _give_charms(x: float, out: Dictionary) -> void:
	var count := int(floor(x))
	if rng.randf() < x - count: count += 1
	var per_cap := VFData.charm_total_cap(prestige) / 8
	var got := {}
	for _i in count:
		var open := []
		for id in VFData.CHARM_ORDER:
			if int(charms.get(id, 0)) < per_cap: open.append(id)
		if open.is_empty(): break
		var id: String = open[rng.randi() % open.size()]
		charms[id] = int(charms.get(id, 0)) + 1
		got[id] = int(got.get(id, 0)) + 1
		stats.charms += 1
		_quest_add("charms", 1)
	out.items["charms"] = got

# --------------------------------------------------------------------- pets
func _roll_pet() -> String:
	var chance := (1.0 + 0.03 * prestige) / 10000.0
	if bait == "Support Bait" and has_bait():
		chance *= 1.4 * bait_eff()
	if pets.is_empty():
		if trips_without_pet > 12000: chance *= 3.0
		elif trips_without_pet > 6000: chance *= 1.5
	if rng.randf() >= chance: return ""
	trips_without_pet = 0
	_quest_add("pets", 1)
	var missing := []
	for p in VFData.PET_ORDER:
		if not pets.has(p): missing.append(p)
	if missing.is_empty():
		var p: String = VFData.PET_ORDER[rng.randi() % 5]
		_add_pet_xp(p, _pet_xp_needed(int(pets[p].level)))
		toast.emit("Duplicate %s converted into pet XP!" % p, "pet")
		return p
	var got: String = missing[0]
	pets[got] = {"level": 1, "xp": 0}
	if pet == "": pet = got
	toast.emit("You found a pet: %s!" % got, "pet")
	return got

func _pet_xp_needed(lv: int) -> int:
	if lv - 1 < VFData.PET_XP.size(): return VFData.PET_XP[lv - 1]
	return VFData.PET_XP[-1]

func pet_xp_per_trip() -> float:
	var x: int = VFData.BIOMES[biome].pet_x
	var p := prestige
	var base: float
	if p < 50:
		base = 10 + x + p + (floor(p / (50.0 / x)) if x > 0 else 0.0)
	else:
		base = 60 + x + (floor(p / (50.0 / x)) if x > 0 else 0.0) + floor((p - 50) / 2.0)
	return base * (1.0 + bait_stat("pet_xp"))

func _pet_xp_tick() -> void:
	if pet == "" or not pets.has(pet): return
	_add_pet_xp(pet, int(round(pet_xp_per_trip() * rng.randf_range(0.75, 1.25))))

func _add_pet_xp(p: String, amount: int) -> void:
	var d: Dictionary = pets[p]
	d.xp = int(d.xp) + amount
	while int(d.level) < pet_level_cap() and int(d.xp) >= _pet_xp_needed(int(d.level)):
		d.xp = int(d.xp) - _pet_xp_needed(int(d.level))
		d.level = int(d.level) + 1
	if int(d.level) >= pet_level_cap():
		d.xp = 0

# ------------------------------------------------------------------ worker
func _worker_trip() -> void:
	var n := _fish_count(true)
	var caught := _distribute(n)
	var gx := 0.0
	for f in caught:
		inventory[f] = int(inventory.get(f, 0)) + caught[f]
		gx += caught[f] * VFData.FISH[f].xp
	worker_fish_total += n
	add_xp(int(round(gx * xp_mult())))
	var wc := lg("worker_crates")
	if wc > 0 and rng.randf() < [0.0, 1.0 / 50, 1.0 / 40, 1.0 / 32, 1.0 / 26, 1.0 / 20][wc]:
		_open_chest(_roll_chest_tier())
	changed.emit()

# ------------------------------------------------------------------ economy
func inventory_value() -> int:
	var v := 0.0
	var trend := trending_fish()           # FishTok: today's trending fish sells for +50%
	for f in inventory:
		v += int(inventory[f]) * VFData.FISH[f].price * (TOK_TREND_MULT if f == trend else 1.0)
	return int(round(v * sell_mult()))

func sell_all() -> int:
	var earned := inventory_value()
	inventory.clear()
	money += earned
	stats.money_earned += earned
	if earned > 0:
		stats.sells = int(stats.get("sells", 0)) + 1
		check_goals()
	changed.emit()
	return earned

func _spend(amount: int) -> bool:
	if money < amount: return false
	money -= amount
	return true

func next_boat() -> String:
	if boats_owned >= VFData.BOAT_ORDER.size(): return ""
	return VFData.BOAT_ORDER[boats_owned]

func current_boat() -> String:
	return "" if boats_owned == 0 else VFData.BOAT_ORDER[boats_owned - 1]

func buy_boat() -> String:
	var b := next_boat()
	if b == "": return "You own every boat."
	var d: Dictionary = VFData.BOATS[b]
	if level < d.level: return "%s needs level %d." % [b, d.level]
	if not _spend(d.cost): return "Not enough money."
	boats_owned += 1
	toast.emit("Bought the %s! (-0.25s cooldown, +1 fish)" % b, "buy")
	changed.emit()
	check_goals()
	return ""

func buy_rod(r: String) -> String:
	var d: Dictionary = VFData.RODS[r]
	if r in owned_rods: return "Already owned."
	if prestige < int(d.get("prestige", 0)): return "Needs Prestige %d." % d.prestige
	if level < d.level: return "%s needs level %d." % [r, d.level]
	if not _spend(d.cost): return "Not enough money."
	owned_rods.append(r)
	rod = r
	toast.emit("Bought the %s!" % r, "buy")
	changed.emit()
	check_goals()
	return ""

func select_rod(r: String) -> void:
	if r in owned_rods:
		rod = r
		changed.emit()

func buy_bait(b: String, amount: int) -> String:
	var d: Dictionary = VFData.BAITS[b]
	if level < d.level: return "%s needs level %d." % [b, d.level]
	if not _spend(d.cost * amount): return "Not enough money."
	bait_stock[b] = int(bait_stock.get(b, 0)) + amount
	if bait == "": bait = b
	changed.emit()
	return ""

func select_bait(b: String) -> void:
	bait = b
	changed.emit()

func select_biome(b: String) -> String:
	if level < VFData.BIOMES[b].level: return "%s unlocks at level %d." % [b, VFData.BIOMES[b].level]
	biome = b
	changed.emit()
	return ""

func select_pet(p: String) -> void:
	if p == "" or pets.has(p):
		pet = p
		changed.emit()

func upgrade_cost(id: String) -> int:
	var d: Dictionary = VFData.UPGRADES[id]
	if up(id) >= d.max: return -1
	return VFData.curve_cost(d.total, d.max, up(id) + 1)

func buy_upgrade(id: String) -> String:
	var c := upgrade_cost(id)
	if c < 0: return "Maxed."
	if not _spend(c): return "Not enough money."
	upgrades[id] = up(id) + 1
	changed.emit()
	return ""

func special_cost(id: String) -> int:
	var d: Dictionary = VFData.SPECIALS[id]
	if sp(id) >= d.max: return -1
	return VFData.curve_cost(d.total, d.max, sp(id) + 1, 1.25)

func buy_special(id: String) -> String:
	var d: Dictionary = VFData.SPECIALS[id]
	if level < d.level: return "Unlocks at level %d." % d.level
	var c := special_cost(id)
	if c < 0: return "Maxed."
	if exotics[d.cur] < c: return "Not enough %s." % VFData.EXOTICS[d.cur].name
	exotics[d.cur] -= c
	specials[id] = sp(id) + 1
	changed.emit()
	return ""

func league_cost(id: String) -> int:
	var costs: Array = VFData.LEAGUE[id].costs
	return -1 if lg(id) >= costs.size() else costs[lg(id)]

func buy_league(id: String) -> String:
	var c := league_cost(id)
	if c < 0: return "Maxed."
	if hooks < c: return "Not enough Hooks."
	hooks -= c
	league[id] = lg(id) + 1
	changed.emit()
	return ""

func perk_cap() -> int:
	return 1 + prestige / 5

func buy_perk(id: String) -> String:
	var d: Dictionary = VFData.PRESTIGE_PERKS[id]
	if prestige < d.unlock: return "Unlocks at Prestige %d." % d.unlock
	if pk(id) >= perk_cap(): return "Capped at %d until Prestige %d." % [perk_cap(), (prestige / 5 + 1) * 5]
	if exotics.azure < 1: return "You need an Azure Fish."
	exotics.azure -= 1
	perks[id] = pk(id) + 1
	changed.emit()
	return ""

# ------------------------------------------------------------------ boosts
func is_boost_active(kind: String) -> bool:
	return Time.get_unix_time_from_system() < float(boosts.get(kind, 0.0))

func boost_left(kind: String) -> float:
	return maxf(0.0, float(boosts.get(kind, 0.0)) - Time.get_unix_time_from_system())

func buy_boost(id: String) -> String:
	var d: Dictionary = VFData.BOOSTS[id]
	if level < 10: return "Boosts unlock at level 10."
	if exotics[d.cur] < d.cost: return "Not enough %s." % VFData.EXOTICS[d.cur].name
	exotics[d.cur] -= d.cost
	var secs: float = d.secs
	if d.kind == "worker":
		secs *= 1.0 + 0.1 * sp("worker_extender")
	var now := Time.get_unix_time_from_system()
	boosts[d.kind] = maxf(now, float(boosts.get(d.kind, 0.0))) + secs
	_quest_add("boostmin", int(secs / 60.0))
	changed.emit()
	return ""

func use_personal_booster() -> String:
	if personal_boosters <= 0: return "No personal boosters."
	personal_boosters -= 1
	personal_until = maxf(Time.get_unix_time_from_system(), personal_until) + 600.0
	changed.emit()
	return ""

# ------------------------------------------------------------------ daily
func daily_ready_in() -> float:
	return maxf(0.0, daily_last + 86400.0 - Time.get_unix_time_from_system())

func claim_daily() -> Dictionary:
	if level < 10: return {"error": "Daily unlocks at level 10."}
	if daily_ready_in() > 0.0: return {"error": "Come back later."}
	var now := Time.get_unix_time_from_system()
	daily_streak = daily_streak + 1 if now - daily_last < 172800.0 else 1
	daily_last = now
	var m := (1.0 + 0.1 * up("better_dailies")) * (1.0 + 0.02 * mini(daily_streak, 50))
	var out := {}
	out.money = int(levelup_money(level) * 3 * m)
	out.xp = int(xp_to_next() * 0.1 * m)
	money += out.money
	add_xp(out.xp)
	for k in ["gold", "emerald", "lava", "diamond"]:
		if level >= VFData.EXOTICS[k].level:
			var a := int(round(rng.randi_range(2, 6) * m))
			exotics[k] += a
			out[k] = a
	if rng.randf() < 0.0997:
		personal_boosters += 1
		out.booster = 1
	out.streak = daily_streak
	changed.emit()
	return out

# ------------------------------------------------------------------ quests
func _today() -> String:
	return Time.get_date_string_from_system(true)

func _roll_quest_day() -> void:
	var t := _today()
	if quest_day != t:
		quest_day = t
		quest_progress = {}
		quest_claimed = {}
	var d := Time.get_date_dict_from_system(true)
	var wk := "%d-%d" % [d.year, int((Time.get_unix_time_from_system() / 86400.0 + 3) / 7)]
	if wk != week_key:
		week_key = wk
		week_trips = 0
		week_hooks = 0

func special_quest() -> Dictionary:
	var idx := absi(hash(quest_day)) % VFData.SPECIAL_QUESTS.size()
	return VFData.SPECIAL_QUESTS[idx]

func _quest_add(stat: String, n: int) -> void:
	quest_progress[stat] = int(quest_progress.get(stat, 0)) + n
	for q in VFData.QUESTS:
		if q.stat != stat: continue
		var claimed := int(quest_claimed.get(q.id, 0))
		while claimed < q.goals.size() and int(quest_progress[stat]) >= q.goals[claimed]:
			claimed += 1
			var gm := int(maxf(500.0, levelup_money(level)) * 0.5 * claimed)
			var gx := int(xp_to_next() * 0.03 * claimed)
			money += gm
			xp += gx
			toast.emit("Quest complete: %s %d (+$%s, +%s XP)" % [q.name, q.goals[claimed - 1], fmt(gm), fmt(gx)], "quest")
		quest_claimed[q.id] = claimed
	var sq := special_quest()
	if sq.stat == stat and not quest_claimed.get("special", false) and int(quest_progress[stat]) >= sq.goal:
		quest_claimed["special"] = true
		hooks += 10
		toast.emit("League quest complete: %s (+10 Hooks)" % sq.name, "quest")

func _week_trip() -> void:
	week_trips += 1
	if week_trips % 500 == 0 and week_hooks < 100:
		week_hooks += 10
		hooks += 10
		toast.emit("Weekly milestone: %d trips (+10 Hooks)" % week_trips, "quest")

# ---------------------------------------------------------------- prestige
func prestige_check() -> Dictionary:
	var lv_req := VFData.prestige_level_req(prestige)
	var m_req := VFData.prestige_money_req(prestige)
	var c_req := VFData.charm_total_cap(prestige)
	return {
		"level": [level, lv_req], "money": [money, m_req], "charms": [charms_total(), c_req],
		"ok": level >= lv_req and money >= m_req and charms_total() >= c_req,
	}

func do_prestige() -> String:
	if not prestige_check().ok: return "Requirements not met."
	prestige += 1
	exotics = {"gold": 0, "emerald": 0, "lava": 0, "diamond": 0, "azure": int(exotics.azure) + 1}
	level = 1
	xp = 0
	money = 0
	biome = "River"
	owned_rods = ["Plastic Rod"]
	if prestige >= 5: owned_rods.append("Supporter Rod")
	rod = "Plastic Rod"
	bait = ""
	bait_stock = {}
	boats_owned = 0
	inventory = {}
	upgrades = {}
	specials = {}
	charms = {}
	boosts = {"fish": 0.0, "treasure": 0.0, "worker": 0.0}
	toast.emit("Welcome to Prestige %d! +1 Azure Fish. Guide pick: %s" % [prestige, VFData.prestige_guide(prestige).main], "prestige")
	save_game()
	changed.emit()
	return ""

# -------------------------------------------------------------- save/load
func to_dict() -> Dictionary:
	return {
		"v": SAVE_VERSION, "name": player_name, "prestige": prestige, "level": level, "xp": xp,
		"money": money, "biome": biome, "rod": rod, "bait": bait, "pet": pet, "owned_rods": owned_rods,
		"boats_owned": boats_owned, "bait_stock": bait_stock, "inventory": inventory, "exotics": exotics,
		"hooks": hooks, "upgrades": upgrades, "specials": specials, "league": league, "perks": perks,
		"charms": charms, "pets": pets, "trips_without_pet": trips_without_pet, "boosts": boosts,
		"personal_boosters": personal_boosters, "personal_until": personal_until, "stats": stats,
		"quest_day": quest_day, "quest_progress": quest_progress, "quest_claimed": quest_claimed,
		"week_key": week_key, "week_trips": week_trips, "week_hooks": week_hooks,
		"daily_last": daily_last, "daily_streak": daily_streak,
		"discovered": discovered, "goals_done": goals_done, "tutorial": tutorial,
		"tok": _tok_dict(),
	}

var autosave := true

func save_game() -> void:
	if not autosave: return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(to_dict()))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("v", 0)) != SAVE_VERSION: return
	_apply(d)

func _apply(d: Dictionary) -> void:
	player_name = d.name
	prestige = int(d.prestige); level = int(d.level); xp = int(d.xp); money = int(d.money)
	biome = d.biome; rod = d.rod; bait = d.bait; pet = d.pet
	owned_rods = d.owned_rods; boats_owned = int(d.boats_owned)
	bait_stock = _ints(d.bait_stock); inventory = _ints(d.inventory); exotics = _ints(d.exotics)
	hooks = int(d.hooks); upgrades = _ints(d.upgrades); specials = _ints(d.specials)
	league = _ints(d.league); perks = _ints(d.perks); charms = _ints(d.charms)
	pets = {}
	for p in d.pets: pets[p] = {"level": int(d.pets[p].level), "xp": int(d.pets[p].xp)}
	trips_without_pet = int(d.trips_without_pet); boosts = d.boosts
	personal_boosters = int(d.personal_boosters); personal_until = float(d.personal_until)
	stats = _ints(d.stats); quest_day = d.quest_day; quest_progress = _ints(d.quest_progress)
	quest_claimed = d.quest_claimed; week_key = d.week_key; week_trips = int(d.week_trips)
	week_hooks = int(d.week_hooks); daily_last = float(d.daily_last); daily_streak = int(d.daily_streak)
	discovered = _ints(d.get("discovered", {}))
	tutorial = int(d.get("tutorial", 0))
	if d.has("goals_done"):
		goals_done = int(d.goals_done)
	else:
		# saves from before starter goals: veterans skip them
		goals_done = VFData.STARTER_GOALS.size() if (level >= 10 or prestige > 0) else 0
		if goals_done > 0: tutorial = 99
	for k in ["sells", "bait_casts"]:
		if not stats.has(k): stats[k] = 0
	_tok_apply(d.get("tok", {}))           # FishTok (absent in old saves -> defaults)

func _ints(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src: out[k] = int(src[k])
	return out

func reset_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_apply(_defaults.duplicate(true))
	_roll_quest_day()
	changed.emit()

# ---------------------------------------------------------------- helpers
static func fmt(n: float) -> String:
	var a := absf(n)
	var units := [[1e15, "Q"], [1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "K"]]
	for u in units:
		if a >= u[0] * 10.0 or (a >= u[0] and u[1] != "K"):
			var v: float = n / u[0]
			return ("%.2f" % v).rstrip("0").rstrip(".") + u[1]
	return str(int(n))

static func commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out




# ----------------------------------------------------------- starter goals
func current_goal() -> Dictionary:
	if goals_done >= VFData.STARTER_GOALS.size(): return {}
	return VFData.STARTER_GOALS[goals_done]

func goal_progress(gdef: Dictionary) -> int:
	match gdef.stat:
		"fish": return int(stats.fish)
		"sells": return int(stats.get("sells", 0))
		"rods": return owned_rods.size()
		"bait_casts": return int(stats.get("bait_casts", 0))
		"species": return discovered.size()
		"level": return level
		"boats": return boats_owned
	return 0

func goal_reward_text(r: Dictionary) -> String:
	var bits := []
	if r.has("money"): bits.append("$" + fmt(r.money))
	if r.has("bait"): bits.append("%d %s" % [r.bait[1], r.bait[0]])
	if r.has("chest"): bits.append("%s chest" % String(r.chest).capitalize())
	if r.has("gold"): bits.append("%d Gold Fish" % r.gold)
	if r.has("emerald"): bits.append("%d Emerald Fish" % r.emerald)
	return ", ".join(bits)

func check_goals() -> void:
	while goals_done < VFData.STARTER_GOALS.size():
		var gdef: Dictionary = VFData.STARTER_GOALS[goals_done]
		if goal_progress(gdef) < int(gdef.goal): return
		goals_done += 1
		var r: Dictionary = gdef.reward
		var chest := {}
		if r.has("money"): money += int(r.money)
		if r.has("bait"): bait_stock[r.bait[0]] = int(bait_stock.get(r.bait[0], 0)) + int(r.bait[1])
		if r.has("gold"): exotics.gold += int(r.gold)
		if r.has("emerald"): exotics.emerald += int(r.emerald)
		if r.has("chest"): chest = _open_chest(r.chest)
		if bait == "" and r.has("bait"): bait = r.bait[0]
		goal_done.emit(gdef.text, goal_reward_text(r), chest)
		changed.emit()


## The game was called "Virtual Fisher", then "fosh_fish"; desktop saves live in a
## folder named after the game. Copy the newest old save once so progress carries over.
func _migrate_old_user_dir() -> void:
	if FileAccess.file_exists(SAVE_PATH): return
	var base := ProjectSettings.globalize_path("user://").trim_suffix("/").get_base_dir()
	for name in ["fosh_fish", "Virtual Fisher"]:
		var old: String = base + "/" + name + "/"
		if not FileAccess.file_exists(old + "vf_save.json"): continue
		for f in ["vf_save.json", "settings.cfg"]:
			if FileAccess.file_exists(old + f) and not FileAccess.file_exists("user://" + f):
				DirAccess.copy_absolute(old + f, ProjectSettings.globalize_path("user://" + f))
		return


# ======================================================================
# ---- FishTok
# The in-game phone's social app (UI: vf_phone.gd, content: vf_fishtok.gd).
#  * Trending fish of the day: one species from your unlocked biomes, picked
#    from the UTC date, sells for +50% (inventory_value / fish_price).
#  * Your posts: new species, record hauls, rare+ chests and level milestones
#    post themselves. Likes grow over real time on a fixed curve
#    (peak * (0.05 + 0.95 * (1 - e^(-age / 15 min)))); 12% of likes become followers.
#  * Follower milestones (100 ... 1M) pay a reward once.
#  * Daily challenge (#challenge) tracked from trip results, claimed once a day.
# Not part of the Virtual Fisher bot — all numbers here are DERIVED.

const TOK_TREND_MULT := 1.5
const TOK_MILESTONES := [100, 1000, 10000, 100000, 1000000]
## milestone -> [money x max(250, level-up money), chest tier or ""]
const TOK_MILESTONE_REWARD := {100: [1, ""], 1000: [2, "uncommon"], 10000: [4, "rare"], 100000: [8, "epic"], 1000000: [15, "legendary"]}
const TOK_MAX_POSTS := 30
const TOK_TAU := 900.0                    # a post gets ~63% of its likes in 15 minutes
const TOK_CONV := 0.12                    # followers per like
const TOK_POST_GAP := 120.0               # seconds between auto posts (new species always post)
const TOK_FLEX_GAP := 600.0               # "post your catch" cooldown
const TOK_CHEST_Q := {"rare": 3.0, "epic": 4.5, "legendary": 6.0, "artifact": 8.0, "super": 7.0}

var tok_posts: Array = []                 # your posts, oldest first (max TOK_MAX_POSTS)
var tok_next_id := 1
var tok_banked_likes := 0                 # likes/followers of posts that scrolled out of the cap
var tok_banked_followers := 0
var tok_claimed: Array = []               # follower milestones already paid
var tok_announced := 0                    # highest milestone announced with a toast
var tok_best_haul := 0
var tok_last_post := 0.0
var tok_last_flex := 0.0
var tok_ch := {}                          # today's challenge {day, kind, fish, goal, reward}
var tok_ch_prog := 0
var tok_ch_claimed := false
var tok_seen_day := ""                    # last day FishTok was opened (badge)
var tok_liked: Array = []                 # feed post ids you liked (today's ids only)
var tok_trend_day := ""
var tok_trend := ""

func _tok_connect() -> void:
	trip_done.connect(_tok_on_trip)
	leveled_up.connect(_tok_on_level)

func _tok_now() -> float:
	return Time.get_unix_time_from_system()

# ---------------------------------------------------------------- trending
## Fish from every biome you have unlocked at `lvl`, cheapest first.
static func tok_trend_candidates(lvl: int) -> Array:
	var out := []
	for f in VFData.FISH_ORDER:
		for b in VFData.BIOME_ORDER:
			if VFData.BIOMES[b].level <= lvl and f in VFData.BIOMES[b].fish:
				out.append(f)
				break
	return out

## Deterministic: the same day and level always give the same fish.
static func trending_for(day: String, lvl: int) -> String:
	var c := tok_trend_candidates(maxi(1, lvl))
	return c[absi(hash("fishtok-trend:" + day)) % c.size()]

## Today's trending fish (picked once per UTC day, then kept even if you level up).
func trending_fish() -> String:
	var t := _today()
	if tok_trend_day != t or not VFData.FISH.has(tok_trend):
		tok_trend_day = t
		tok_trend = trending_for(t, level)
	return tok_trend

func is_trending(f: String) -> bool:
	return f == trending_fish()

## Base price of one fish today (before sell multipliers).
func fish_price(f: String) -> float:
	return float(VFData.FISH[f].price) * (TOK_TREND_MULT if f == trending_fish() else 1.0)

# ------------------------------------------------------------ posts & fans
func tok_post_likes(p: Dictionary, now := -1.0) -> int:
	if now < 0.0: now = _tok_now()
	var age := maxf(0.0, now - float(p.get("t", now)))
	return int(float(p.get("peak", 0)) * (0.05 + 0.95 * (1.0 - exp(-age / TOK_TAU))))

func tok_likes(now := -1.0) -> int:
	if now < 0.0: now = _tok_now()
	var s := tok_banked_likes
	for p in tok_posts: s += tok_post_likes(p, now)
	return s

func tok_followers(now := -1.0) -> int:
	if now < 0.0: now = _tok_now()
	var s := tok_banked_followers
	for p in tok_posts: s += int(tok_post_likes(p, now) * TOK_CONV)
	return s

## Create one of your posts. `q` (quality ~1-10) and your current followers set
## how many likes it will reach. Auto posts are rate limited unless `force`.
func _tok_post(kind: String, data: Dictionary, q: float, force := false, now := -1.0) -> Dictionary:
	if now < 0.0: now = _tok_now()
	if not force and now - tok_last_post < TOK_POST_GAP: return {}
	var fans := float(tok_followers(now))
	var id := tok_next_id
	tok_next_id += 1
	var jitter := 0.85 + float(absi(hash("fishtok-post:%d" % id)) % 1000) / 1000.0 * 0.4
	var p := {"id": id, "kind": kind, "t": now, "q": snappedf(q, 0.01), "fish": "", "tier": "", "count": 0,
		"level": level, "biome": biome}
	p.merge(data, true)
	p["peak"] = int(round((40.0 + 30.0 * q + fans * (0.25 + 0.05 * q)) * jitter))
	tok_posts.append(p)
	tok_last_post = now
	while tok_posts.size() > TOK_MAX_POSTS:
		var old: Dictionary = tok_posts.pop_front()       # keeps what it would have earned
		var l := maxi(int(old.peak), tok_post_likes(old, now))
		tok_banked_likes += l
		tok_banked_followers += int(l * TOK_CONV)
	if kind != "species":                  # new species already get a banner
		toast.emit("Posted to FishTok: %s" % tok_post_title(p), "tok")
	return p

func tok_post_title(p: Dictionary) -> String:
	match String(p.get("kind", "")):
		"species": return "New fish: %s!" % p.fish
		"chest": return "%s chest!" % String(p.tier).capitalize()
		"haul": return "%d fish in one cast!" % int(p.count)
		"level": return "Level %s!" % commas(int(p.level))
		"flex": return "Check out my %s" % p.fish
	return "New post"

func _tok_best_fish(fish: Dictionary) -> String:
	var best := ""
	for f in fish:
		if int(fish[f]) > 0 and (best == "" or VFData.FISH[f].price > VFData.FISH[best].price): best = f
	return best

func _tok_on_trip(res: Dictionary) -> void:
	_tok_roll_day()
	var goal := int(tok_ch.get("goal", 0))
	var before := tok_ch_prog
	tok_ch_prog += _tok_ch_gain(res)
	if before < goal and tok_ch_prog >= goal and not tok_ch_claimed:
		toast.emit("FishTok challenge complete! Claim it on your phone (P)", "quest")
	var newbies: Array = res.get("new_species", [])
	if not newbies.is_empty():
		var best: String = newbies[0]
		for f in newbies:
			if VFData.FISH_ORDER.find(f) > VFData.FISH_ORDER.find(best): best = f
		_tok_post("species", {"fish": best}, 2.0 + 0.4 * VFData.FISH_ORDER.find(best), true)
	var chest: Dictionary = res.get("chest", {})
	var tier := String(chest.get("tier", ""))
	if TOK_CHEST_Q.has(tier):
		_tok_post("chest", {"tier": tier}, TOK_CHEST_Q[tier])
	var n := int(res.get("count", 0))
	if n > tok_best_haul:
		var prev := tok_best_haul
		tok_best_haul = n
		if n >= 12 and n >= prev * 1.15:
			_tok_post("haul", {"count": n, "fish": _tok_best_fish(res.get("fish", {}))}, 2.5 + log(float(n)) / log(10.0))

func _tok_on_level(lvl: int, _money: int) -> void:
	var unlock := false
	for b in VFData.BIOME_ORDER:
		if VFData.BIOMES[b].level == lvl and lvl > 1: unlock = true
	if unlock or lvl in [5, 10, 25] or lvl % 50 == 0:
		_tok_post("level", {"level": lvl}, 2.0 + 1.5 * log(float(lvl)) / log(10.0) + (3.0 if unlock else 0.0), unlock)

## "Post your catch": shows off the most valuable fish in your hold (or your
## best discovery). Ten-minute cooldown. Returns "" or a reason.
func tok_post_flex() -> String:
	var now := _tok_now()
	var left := TOK_FLEX_GAP - (now - tok_last_flex)
	if left > 0.0:
		return "You can post again in %d:%02d" % [int(left) / 60, int(left) % 60]
	var best := _tok_best_fish(inventory)
	if best == "": best = _tok_best_fish(discovered)
	if best == "": return "Catch a fish first!"
	tok_last_flex = now
	_tok_post("flex", {"fish": best, "count": int(inventory.get(best, 0))}, 1.5 + 0.35 * VFData.FISH_ORDER.find(best), true, now)
	changed.emit()
	return ""

func tok_flex_ready_in() -> float:
	return maxf(0.0, TOK_FLEX_GAP - (_tok_now() - tok_last_flex))

# --------------------------------------------------------------- milestones
func tok_milestone_reward(m: int) -> Dictionary:
	var r: Array = TOK_MILESTONE_REWARD.get(m, [1, ""])
	var out := {"money": int(maxf(250.0, levelup_money(level)) * r[0])}
	if r[1] != "": out["chest"] = r[1]
	return out

func tok_milestone_state(m: int) -> String:
	if m in tok_claimed: return "claimed"
	return "ready" if tok_followers() >= m else "locked"

func tok_claim_milestone(m: int) -> Dictionary:
	if not m in TOK_MILESTONES: return {"error": "Unknown milestone."}
	if m in tok_claimed: return {"error": "Already claimed."}
	if tok_followers() < m: return {"error": "Reach %s followers first." % fmt(m)}
	var r := tok_milestone_reward(m)
	tok_claimed.append(m)
	var chest := _tok_give(r)
	changed.emit()
	return {"text": goal_reward_text(r), "chest": chest, "reward": r}

func _tok_give(r: Dictionary) -> Dictionary:
	if r.has("money"): money += int(r.money)
	if r.has("bait"):
		bait_stock[r.bait[0]] = int(bait_stock.get(r.bait[0], 0)) + int(r.bait[1])
		if bait == "" or not has_bait(): bait = r.bait[0]
	if r.has("chest"): return _open_chest(String(r.chest))
	return {}

# ----------------------------------------------------------- daily challenge
func tok_challenge() -> Dictionary:
	_tok_roll_day()
	return tok_ch

func _tok_roll_day() -> void:
	var t := _today()
	if String(tok_ch.get("day", "")) == t: return
	tok_ch = _tok_make_challenge(t)
	tok_ch_prog = 0
	tok_ch_claimed = false
	tok_liked = tok_liked.filter(func(id): return String(id).begins_with(t))

## Expected fish per cast with your current setup (mirrors the Buffs panel).
func _tok_avg_fish() -> float:
	var r: Dictionary = VFData.RODS[rod]
	var v: float = (r.min + r.max) / 2.0 * fish_catch_mult() + boats_owned
	if has_bait(): v += round(float(VFData.BAITS[bait].get("fish", 0)) * bait_eff())
	return maxf(1.0, v * VFData.BIOMES[biome].catch_rate * float(r.get("biome_mult", {}).get(biome, 1.0)))

static func _tok_nice(v: float, lo: int) -> int:
	var step := 1.0
	if v >= 5000.0: step = 500.0
	elif v >= 1000.0: step = 100.0
	elif v >= 200.0: step = 50.0
	elif v >= 50.0: step = 10.0
	elif v >= 10.0: step = 5.0
	return maxi(lo, int(round(v / step) * step))

## Built once per day from your biome and gear (~100 casts of work).
func _tok_make_challenge(day: String) -> Dictionary:
	var h := absi(hash("fishtok-challenge:" + day))
	var kinds := ["species", "species", "fish"]
	if level >= 10: kinds.append("chests")
	var kind: String = kinds[h % kinds.size()]
	var avg := _tok_avg_fish()
	var c := {"day": day, "kind": kind, "fish": "", "goal": 0, "biome": biome}
	if kind == "species":
		var odds := species_odds()
		var names: Array = VFData.BIOMES[biome].fish
		var pick := 0
		for i in range(4, 0, -1):          # the rarest fish you land about once every 12 casts
			if avg * odds[i] >= 0.08:
				pick = i
				break
		c.fish = names[pick]
		c.goal = _tok_nice(avg * odds[pick] * 100.0, 5)
	elif kind == "fish":
		c.goal = _tok_nice(avg * 120.0, 50)
	else:
		c.goal = _tok_nice(treasure_chance() * 150.0, 2)
	c.reward = _tok_challenge_reward((h / 7) % 3)
	return c

func _tok_challenge_reward(kind: int) -> Dictionary:
	var base := maxi(200, levelup_money(level) * 2)
	if kind == 1:
		var b := "Worms"
		for x in VFData.BAIT_ORDER:
			if VFData.BAITS[x].level <= level and x != "Support Bait": b = x
		return {"bait": [b, clampi(base / int(VFData.BAITS[b].cost), 10, 250)]}
	if kind == 2:
		return {"chest": "uncommon" if level < 20 else ("rare" if level < 100 else "epic")}
	return {"money": base}

func _tok_ch_gain(res: Dictionary) -> int:
	match String(tok_ch.get("kind", "")):
		"species": return int(res.get("fish", {}).get(tok_ch.fish, 0))
		"fish": return int(res.get("count", 0))
		"chests": return 0 if res.get("chest", {}).is_empty() else 1
	return 0

func tok_challenge_text(c: Dictionary = {}) -> String:
	if c.is_empty(): c = tok_challenge()
	match String(c.get("kind", "")):
		"species": return "Catch %s %s" % [commas(int(c.goal)), c.fish]
		"fish": return "Catch %s fish" % commas(int(c.goal))
		"chests": return "Open %d chests" % int(c.goal)
	return ""

func tok_challenge_done() -> bool:
	return tok_ch_prog >= int(tok_challenge().get("goal", 1))

func tok_claim_challenge() -> Dictionary:
	_tok_roll_day()
	if tok_ch_claimed: return {"error": "Already claimed today. New challenge tomorrow!"}
	if tok_ch_prog < int(tok_ch.goal): return {"error": "Not done yet: %s / %s" % [commas(tok_ch_prog), commas(int(tok_ch.goal))]}
	tok_ch_claimed = true
	var chest := _tok_give(tok_ch.reward)
	changed.emit()
	return {"text": goal_reward_text(tok_ch.reward), "chest": chest}

# ------------------------------------------------------------- badge & seen
## Red badge on the Phone pill: unclaimed milestones + a finished challenge +
## "something new today". Also announces newly reached milestones once.
func tok_badge() -> int:
	var fans := tok_followers()
	var n := 0
	for m in TOK_MILESTONES:
		if fans >= m and not m in tok_claimed:
			n += 1
			if m > tok_announced:
				tok_announced = m
				toast.emit("FishTok: %s followers! Claim your reward on the phone (P)" % fmt(m), "quest")
	if tok_challenge_done() and not tok_ch_claimed: n += 1
	if tok_seen_day != _today(): n += 1
	return n

func tok_mark_seen() -> void:
	tok_seen_day = _today()

func tok_toggle_like(id: String) -> bool:
	if id in tok_liked:
		tok_liked.erase(id)
		return false
	tok_liked.append(id)
	if tok_liked.size() > 200: tok_liked.pop_front()
	return true

# --------------------------------------------------------------- save/load
func _tok_dict() -> Dictionary:
	return {"posts": tok_posts, "next_id": tok_next_id, "banked_likes": tok_banked_likes,
		"banked_followers": tok_banked_followers, "claimed": tok_claimed, "announced": tok_announced,
		"best_haul": tok_best_haul, "last_post": tok_last_post, "last_flex": tok_last_flex,
		"ch": tok_ch, "ch_prog": tok_ch_prog, "ch_claimed": tok_ch_claimed, "seen_day": tok_seen_day,
		"liked": tok_liked, "trend_day": tok_trend_day, "trend": tok_trend}

func _tok_apply(t: Dictionary) -> void:
	tok_posts = []
	for p in t.get("posts", []):
		if typeof(p) != TYPE_DICTIONARY: continue
		var fish := String(p.get("fish", ""))
		tok_posts.append({"id": int(p.get("id", 0)), "kind": String(p.get("kind", "flex")), "t": float(p.get("t", 0.0)),
			"peak": int(p.get("peak", 0)), "q": float(p.get("q", 1.0)), "fish": fish if VFData.FISH.has(fish) else "",
			"tier": String(p.get("tier", "")), "count": int(p.get("count", 0)), "level": int(p.get("level", 1)),
			"biome": String(p.get("biome", "River")) if VFData.BIOMES.has(String(p.get("biome", ""))) else "River"})
	tok_next_id = int(t.get("next_id", tok_posts.size() + 1))
	tok_banked_likes = int(t.get("banked_likes", 0))
	tok_banked_followers = int(t.get("banked_followers", 0))
	tok_claimed = []
	for m in t.get("claimed", []): tok_claimed.append(int(m))
	tok_announced = int(t.get("announced", 0))
	tok_best_haul = int(t.get("best_haul", 0))
	tok_last_post = float(t.get("last_post", 0.0))
	tok_last_flex = float(t.get("last_flex", 0.0))
	tok_ch = {}
	var c = t.get("ch", {})
	if typeof(c) == TYPE_DICTIONARY and c.has("day") and c.has("reward"):
		var fish := String(c.get("fish", ""))
		var r: Dictionary = c.reward if typeof(c.reward) == TYPE_DICTIONARY else {"money": 200}
		var clean_r := {}
		if r.has("money"): clean_r["money"] = int(r.money)
		if r.has("chest"): clean_r["chest"] = String(r.chest)
		if r.has("bait") and typeof(r.bait) == TYPE_ARRAY and r.bait.size() == 2 and VFData.BAITS.has(String(r.bait[0])):
			clean_r["bait"] = [String(r.bait[0]), int(r.bait[1])]
		if clean_r.is_empty(): clean_r = {"money": 200}
		tok_ch = {"day": String(c.day), "kind": String(c.get("kind", "fish")), "fish": fish if VFData.FISH.has(fish) else "",
			"goal": maxi(1, int(c.get("goal", 50))), "biome": String(c.get("biome", "River")), "reward": clean_r}
		if tok_ch.kind == "species" and tok_ch.fish == "": tok_ch.kind = "fish"
	tok_ch_prog = int(t.get("ch_prog", 0))
	tok_ch_claimed = bool(t.get("ch_claimed", false))
	tok_seen_day = String(t.get("seen_day", ""))
	tok_liked = []
	for id in t.get("liked", []): tok_liked.append(String(id))
	tok_trend_day = String(t.get("trend_day", ""))
	tok_trend = String(t.get("trend", ""))

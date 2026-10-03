extends Node
## Virtual Fisher game simulation (autoload "VF").
## All formulas follow the wiki/encyclopedia; see vf_data.gd for sources.

signal changed
signal trip_done(result: Dictionary)
signal leveled_up(new_level: int, money_reward: int)
signal toast(text: String, kind: String)

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
var stats := {"trips": 0, "fish": 0, "chests": 0, "charms": 0, "money_earned": 0}
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

func _ready() -> void:
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

func xp_mult() -> float:
	return maxf(0.1, 1.0 + 0.10 * up("experienced") + 0.15 * sp("highly_experienced") + 0.35 * pk("ancient_one")
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
		"levels": 0, "duplicated": false}
	var used_bait := has_bait()
	var n := _fish_count()
	var caught := _distribute(n)
	var xp_gain := 0.0
	for f in caught:
		inventory[f] = int(inventory.get(f, 0)) + caught[f]
		xp_gain += caught[f] * VFData.FISH[f].xp
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
	# pet
	res.pet = _roll_pet()
	_pet_xp_tick()
	# bait consumption
	if used_bait:
		res.bait_used = bait
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
	for f in inventory:
		v += int(inventory[f]) * VFData.FISH[f].price
	return int(round(v * sell_mult()))

func sell_all() -> int:
	var earned := inventory_value()
	inventory.clear()
	money += earned
	stats.money_earned += earned
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

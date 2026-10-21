extends Node
## Local save: Flux, Forge levels, records and settings, as JSON in user://.

const PATH := "user://afterglow_save.json"
const DEFAULTS := {
	"flux": 0,
	"forge": {},
	"best_time": 0.0,
	"best_kills": 0,
	"best_level": 0,
	"runs": 0,
	"wins": 0,
	"total_kills": 0,
	"total_rifts": 0,
	"total_flux": 0,
	"tutorial_done": false,
	"evolved": [],
	"resonances": [],
	"trait_kills": {},
	"ship": "lumen",
	"missions": [],
	"ships_won": [],
	"seen_ships": ["lumen"],
	"best_score": 0,
	"best_afterdark": 0,
	"best_chain": 0,
	"ship_best": {},
	"daily_runs": 0,
	"daily_streak": 0,
	"daily_streak_best": 0,
	"daily_last": -1,
	"daily_log": [],
	"daily_replay": {},
	"radiance": 0,
	"radiance_cleared": -1,
	"gauntlet": {},
	"sector": 0,
	"sector_best": {},
	"tips": [],
	"settings": {"sound": true, "music": true, "haptics": true, "shake": true, "numbers": true},
}

var data: Dictionary = {}


func _ready() -> void:
	load_data()
	sync_missions()


## Completes missions earlier runs already earned (records kept before
## missions existed count too). Returns the ids it completed.
func sync_missions() -> Array:
	var done: Array = data.missions
	var fresh: Array = []
	for m in Defs.MISSIONS:
		if not done.has(m.id) and Missions.done(m, null, data):
			done.append(m.id)
			fresh.append(m.id)
			data.flux = int(data.flux) + int(m.flux)
			data.total_flux = int(data.total_flux) + int(m.flux)
	if not fresh.is_empty():
		save_data()
	return fresh


## Unlocked ships the player has not looked at in the hangar yet.
func unseen_ships() -> Array:
	var out: Array = []
	for s in Defs.SHIPS:
		if ship_unlocked(s.id) and not (data.seen_ships as Array).has(s.id):
			out.append(s.id)
	return out


func mark_ships_seen() -> void:
	var seen: Array = data.seen_ships
	for id in unseen_ships():
		seen.append(id)
	save_data()


func load_data() -> void:
	data = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		for k in parsed:
			if k == "settings" and parsed[k] is Dictionary:
				for s in parsed[k]:
					data.settings[s] = parsed[k][s]
			else:
				data[k] = parsed[k]
	# Saves from before Radiance: an earlier dawn already clears level 0.
	if int(data.wins) > 0 and int(data.radiance_cleared) < 0:
		data.radiance_cleared = 0


func save_data() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func setting(key: String) -> bool:
	return bool(data.settings.get(key, true))


func set_setting(key: String, value: bool) -> void:
	data.settings[key] = value
	save_data()


func forge_level(id: String) -> int:
	return int(data.forge.get(id, 0))


## The loadout a new run starts with: Forge levels as plain ints, the ship
## and the Radiance level.
func loadout() -> Dictionary:
	var out := {"ship": current_ship()}
	for f in Defs.FORGE:
		var l := forge_level(f.id)
		if l > 0:
			out[f.id] = l
	var r := current_radiance()
	if r > 0:
		out.radiance = r
	var sec := current_sector()
	if sec > 0:
		out.sector = sec
	return out


## The Gauntlet's loadout: your ship and Forge, no Radiance.
func gauntlet_loadout() -> Dictionary:
	var out := loadout()
	out.erase("radiance")
	out.erase("sector")
	out.gauntlet = true
	return out


## The Gauntlet opens once the Warden has fallen.
func gauntlet_unlocked() -> bool:
	return (data.missions as Array).has("warden")


## The Gauntlet record: runs, clears, best_clear (ticks), best_felled,
## best_stage, best_score, splits (best ticks per boss, 0 for none).
func gauntlet_rec() -> Dictionary:
	if not (data.get("gauntlet") is Dictionary):
		data.gauntlet = {}
	var g: Dictionary = data.gauntlet
	for k in ["runs", "clears", "best_clear", "best_felled", "best_stage", "best_score"]:
		if not g.has(k):
			g[k] = 0
	if not (g.get("splits") is Array) or (g.splits as Array).size() != Defs.GAUNTLET.size():
		g.splits = [0, 0, 0, 0]
	return g


## Sectors open as their mission is completed (the Neon Grid always is).
func sector_unlocked(k: int) -> bool:
	var unlock := String(Defs.sector(k).unlock)
	return unlock == "" or (data.missions as Array).has(unlock)


func current_sector() -> int:
	var k := clampi(int(data.get("sector", 0)), 0, Defs.SECTORS.size() - 1)
	return k if sector_unlocked(k) else 0


func set_sector(k: int) -> void:
	if sector_unlocked(k):
		data.sector = k
		save_data()


## A sector's record: time, score and whether the dawn was reached there.
func sector_rec(k: int) -> Dictionary:
	var sb = data.get("sector_best", {})
	if not (sb is Dictionary):
		return {}
	return sb.get(String(Defs.sector(k).id), {})


## The highest Radiance level the player may choose (0 until the first dawn).
func radiance_max() -> int:
	return clampi(int(data.radiance_cleared) + 1, 0, Defs.MAX_RADIANCE)


func current_radiance() -> int:
	return clampi(int(data.radiance), 0, radiance_max())


func set_radiance(r: int) -> void:
	data.radiance = clampi(r, 0, radiance_max())
	save_data()


## The highest Radiance a ship has reached the dawn at, or -1.
func ship_radiance(id: String) -> int:
	var rec: Dictionary = (data.ship_best as Dictionary).get(id, {})
	if rec.is_empty():
		return -1
	return int(rec.get("radiance", 0 if bool(rec.get("dawn", false)) else -1))


## One-time coach tips: true the first time a key is asked for.
func tip_once(key: String) -> bool:
	var seen: Array = data.tips
	if seen.has(key):
		return false
	seen.append(key)
	save_data()
	return true


## Today's UTC day number: the Daily Run key. The wall clock is fine here; the
## rules only ever see the day number.
static func today() -> int:
	return int(floor(Time.get_unix_time_from_system() / 86400.0))


## Seconds until the next Daily Run.
static func daily_left() -> int:
	var now := Time.get_unix_time_from_system()
	return int(86400.0 - fmod(now, 86400.0))


## This player's record for a day: {day, score, time, kills, dawn, ship, tries}, or {}.
func daily_entry(day: int) -> Dictionary:
	for e in data.daily_log:
		if int(e.day) == day:
			return e
	return {}


## The streak still counts if the last Daily was today or yesterday.
func live_streak() -> int:
	var last := int(data.daily_last)
	return int(data.daily_streak) if last >= today() - 1 else 0


## Flux paid for the first Daily Run of a day: grows with the score and the streak.
static func daily_bounty(score: int, streak: int) -> int:
	var base := mini(400, 50 + score / 400)
	return int(float(base) * (1.0 + 0.1 * float(clampi(streak - 1, 0, 5))))


## The selected ship, falling back to Lumen if it is somehow locked.
func current_ship() -> String:
	var id := String(data.get("ship", "lumen"))
	return id if ship_unlocked(id) else "lumen"


func ship_unlocked(id: String) -> bool:
	return Missions.ship_unlocked(id, data.missions)


func select_ship(id: String) -> void:
	if ship_unlocked(id):
		data.ship = id
		save_data()


func forge_cost(id: String) -> int:
	var f := Defs.forge_def(id)
	var l := forge_level(id)
	if f.is_empty() or l >= int(f.max):
		return -1
	return int(f.cost[l])


func buy(id: String) -> bool:
	var c := forge_cost(id)
	if c < 0 or int(data.flux) < c:
		return false
	data.flux = int(data.flux) - c
	data.forge[id] = forge_level(id) + 1
	save_data()
	return true


## Records a finished run. Returns which records were beaten.
func record_run(sim: Sim) -> Dictionary:
	var beat := {}
	var earned := sim.flux_earned()
	var score := sim.score()
	if sim.gauntlet:
		_record_gauntlet(sim, score, beat)
		return _record_common(sim, earned, beat)
	if score > int(data.best_score):
		beat.score = true
		data.best_score = score
	data.best_afterdark = maxi(int(data.best_afterdark), sim.afterdark_seconds())
	if sim.chain_best > int(data.best_chain):
		beat.chain = true
		data.best_chain = sim.chain_best
	var sb: Dictionary = data.ship_best
	var rec: Dictionary = sb.get(sim.ship_id, {"time": 0.0, "score": 0, "dawn": false})
	if score > int(rec.get("score", 0)):
		beat.ship_score = true
	rec.time = maxf(float(rec.get("time", 0.0)), sim.seconds())
	rec.score = maxi(int(rec.get("score", 0)), score)
	var ship_rad := ship_radiance(sim.ship_id)
	rec.dawn = bool(rec.get("dawn", false)) or sim.dawn
	rec.radiance = maxi(ship_rad, sim.radiance) if sim.dawn else ship_rad
	sb[sim.ship_id] = rec
	if Defs.trail_tier(int(rec.radiance)) > Defs.trail_tier(ship_rad):
		beat.trail = Defs.trail_tier(int(rec.radiance))
	# Radiance: every dawn at your highest level unlocks the next one.
	if sim.dawn and sim.radiance > int(data.radiance_cleared):
		var old_max := radiance_max()
		data.radiance_cleared = sim.radiance
		if radiance_max() > old_max:
			beat.radiance_unlocked = radiance_max()
			if sim.radiance > 0 and sim.radiance == old_max:
				data.radiance = radiance_max()
	if sim.loadout.has("daily"):
		_record_daily(sim, score, beat)
	else:
		_record_sector(sim, score, beat)
	if sim.dawn:
		data.wins = int(data.wins) + 1
		var won: Array = data.ships_won
		if not won.has(sim.ship_id):
			won.append(sim.ship_id)
	if sim.seconds() > float(data.best_time):
		beat.time = true
		data.best_time = sim.seconds()
	if sim.kills > int(data.best_kills):
		beat.kills = true
		data.best_kills = sim.kills
	if sim.level > int(data.best_level):
		beat.level = true
		data.best_level = sim.level
	return _record_common(sim, earned, beat)


## What every run records, the Gauntlet included: Flux, totals, the best
## Chain, evolutions discovered and missions.
func _record_common(sim: Sim, earned: int, beat: Dictionary) -> Dictionary:
	data.flux = int(data.flux) + earned
	data.total_flux = int(data.total_flux) + earned
	data.runs = int(data.runs) + 1
	data.total_kills = int(data.total_kills) + sim.kills
	data.total_rifts = int(data.get("total_rifts", 0)) + sim.rifts_done
	if sim.gauntlet and sim.chain_best > int(data.best_chain):
		beat.chain = true
		data.best_chain = sim.chain_best
	var known: Array = data.evolved
	for w in sim.weapons:
		if sim.is_evolved(w.id) and not known.has(w.id):
			known.append(w.id)
			beat[w.id] = true
	var heard: Array = data.resonances
	var fresh_res: Array = []
	for id in sim.resonances:
		if not heard.has(id):
			heard.append(id)
			fresh_res.append(id)
	beat.resonances = fresh_res
	# Elite traits: trophies per trait, and the ones slain for the first time.
	if not (data.get("trait_kills") is Dictionary):
		data.trait_kills = {}
	var trophies: Dictionary = data.trait_kills
	var fresh_traits: Array = []
	for id in sim.traits_slain:
		if int(trophies.get(id, 0)) <= 0:
			fresh_traits.append(id)
		trophies[id] = int(trophies.get(id, 0)) + int(sim.traits_slain[id])
	beat.traits = fresh_traits
	# Missions: pay out once, unlock ships.
	var done: Array = data.missions
	var fresh: Array = []
	var ships: Array = []
	for m in Defs.MISSIONS:
		if done.has(m.id) or not Missions.done(m, sim, data):
			continue
		done.append(m.id)
		fresh.append(m.id)
		data.flux = int(data.flux) + int(m.flux)
		data.total_flux = int(data.total_flux) + int(m.flux)
		if m.has("ship"):
			ships.append(m.ship)
	beat.missions = fresh
	beat.ships = ships
	save_data()
	return beat


## Sector bookkeeping (not for dailies): best time and score per sector, and
## whether its dawn has been reached. `beat` gets sector_score and sector_dawn.
func _record_sector(sim: Sim, score: int, beat: Dictionary) -> void:
	if not (data.get("sector_best") is Dictionary):
		data.sector_best = {}
	var id := String(Defs.sector(sim.sector).id)
	var rec: Dictionary = (data.sector_best as Dictionary).get(id, {"time": 0.0, "score": 0, "dawn": false})
	if sim.sector > 0 and score > int(rec.get("score", 0)):
		beat.sector_score = true
	if sim.dawn and not bool(rec.get("dawn", false)):
		beat.sector_dawn = true
	rec.time = maxf(float(rec.get("time", 0.0)), sim.seconds())
	rec.score = maxi(int(rec.get("score", 0)), score)
	rec.dawn = bool(rec.get("dawn", false)) or sim.dawn
	data.sector_best[id] = rec


## Gauntlet bookkeeping: clears, the fastest clear, best splits per boss.
## `beat` gets gauntlet_clear, gauntlet_score, gauntlet_felled and
## gauntlet_splits (the indices of bosses felled faster than ever), plus
## gauntlet_prev (the splits as they stood before this run).
func _record_gauntlet(sim: Sim, score: int, beat: Dictionary) -> void:
	var g := gauntlet_rec()
	beat.gauntlet_prev = (g.splits as Array).duplicate()
	beat.gauntlet_prev_clear = int(g.best_clear)
	g.runs = int(g.runs) + 1
	if score > int(g.best_score):
		g.best_score = score
		beat.gauntlet_score = true
	if sim.bosses_killed > int(g.best_felled):
		g.best_felled = sim.bosses_killed
		beat.gauntlet_felled = true
	g.best_stage = maxi(int(g.best_stage), sim.g_stage)
	if sim.g_clear_tick >= 0:
		g.clears = int(g.clears) + 1
		if int(g.best_clear) <= 0 or sim.g_clear_tick < int(g.best_clear):
			g.best_clear = sim.g_clear_tick
			beat.gauntlet_clear = true
	var fast: Array = []
	var splits: Array = g.splits
	for k in mini(sim.g_splits.size(), splits.size()):
		var t := int(sim.g_splits[k])
		if t > 0 and (int(splits[k]) <= 0 or t < int(splits[k])):
			splits[k] = t
			fast.append(k)
	beat.gauntlet_splits = fast


## Daily Run bookkeeping: per-day best, tries, streak, bounty, best replay.
func _record_daily(sim: Sim, score: int, beat: Dictionary) -> void:
	var day := int(sim.loadout.daily)
	data.daily_runs = int(data.daily_runs) + 1
	var log: Array = data.daily_log
	var e := daily_entry(day)
	var first := e.is_empty()
	if first:
		var last := int(data.daily_last)
		data.daily_streak = int(data.daily_streak) + 1 if last == day - 1 else 1
		data.daily_streak_best = maxi(int(data.daily_streak_best), int(data.daily_streak))
		data.daily_last = maxi(last, day)
		e = {"day": day, "score": 0, "time": 0.0, "kills": 0, "dawn": false, "ship": sim.ship_id, "tries": 0}
		log.append(e)
		var bounty := daily_bounty(score, int(data.daily_streak))
		beat.bounty = bounty
		data.flux = int(data.flux) + bounty
		data.total_flux = int(data.total_flux) + bounty
	e.tries = int(e.tries) + 1
	beat.daily_prev = int(e.score)
	if score > int(e.score):
		if not first:
			beat.daily_best = true
		e.score = score
		e.time = sim.seconds()
		e.kills = sim.kills
		e.dawn = sim.dawn
		data.daily_replay = sim.to_replay()
	# Keep the last 60 days.
	log.sort_custom(func(a, b): return int(a.day) > int(b.day))
	while log.size() > 60:
		log.pop_back()

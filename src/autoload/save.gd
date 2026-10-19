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
	"total_flux": 0,
	"tutorial_done": false,
	"evolved": [],
	"ship": "lumen",
	"missions": [],
	"ships_won": [],
	"seen_ships": ["lumen"],
	"best_score": 0,
	"best_afterdark": 0,
	"ship_best": {},
	"daily_runs": 0,
	"daily_streak": 0,
	"daily_streak_best": 0,
	"daily_last": -1,
	"daily_log": [],
	"daily_replay": {},
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


## The loadout a new run starts with: Forge levels as plain ints plus the ship.
func loadout() -> Dictionary:
	var out := {"ship": current_ship()}
	for f in Defs.FORGE:
		var l := forge_level(f.id)
		if l > 0:
			out[f.id] = l
	return out


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
	if score > int(data.best_score):
		beat.score = true
		data.best_score = score
	data.best_afterdark = maxi(int(data.best_afterdark), sim.afterdark_seconds())
	var sb: Dictionary = data.ship_best
	var rec: Dictionary = sb.get(sim.ship_id, {"time": 0.0, "score": 0, "dawn": false})
	if score > int(rec.get("score", 0)):
		beat.ship_score = true
	rec.time = maxf(float(rec.get("time", 0.0)), sim.seconds())
	rec.score = maxi(int(rec.get("score", 0)), score)
	rec.dawn = bool(rec.get("dawn", false)) or sim.dawn
	sb[sim.ship_id] = rec
	if sim.loadout.has("daily"):
		_record_daily(sim, score, beat)
	data.flux = int(data.flux) + earned
	data.total_flux = int(data.total_flux) + earned
	data.runs = int(data.runs) + 1
	data.total_kills = int(data.total_kills) + sim.kills
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
	var known: Array = data.evolved
	for w in sim.weapons:
		if sim.is_evolved(w.id) and not known.has(w.id):
			known.append(w.id)
			beat[w.id] = true
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

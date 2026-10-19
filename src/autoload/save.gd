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
	data.flux = int(data.flux) + earned
	data.total_flux = int(data.total_flux) + earned
	data.runs = int(data.runs) + 1
	data.total_kills = int(data.total_kills) + sim.kills
	if sim.state == Sim.WON:
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

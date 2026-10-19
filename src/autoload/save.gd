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
	"settings": {"sound": true, "music": true, "haptics": true, "shake": true, "numbers": true},
}

var data: Dictionary = {}


func _ready() -> void:
	load_data()


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


## The loadout a new run starts with: Forge levels as plain ints.
func loadout() -> Dictionary:
	var out := {}
	for f in Defs.FORGE:
		var l := forge_level(f.id)
		if l > 0:
			out[f.id] = l
	return out


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
	if sim.seconds() > float(data.best_time):
		beat.time = true
		data.best_time = sim.seconds()
	if sim.kills > int(data.best_kills):
		beat.kills = true
		data.best_kills = sim.kills
	if sim.level > int(data.best_level):
		beat.level = true
		data.best_level = sim.level
	save_data()
	return beat

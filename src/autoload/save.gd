extends Node
## Local persistence: best scores, stats, settings and the run in progress.
## Runs are stored as replays ({seed, moves}) and rebuilt by re-simulating,
## so a resumed game is bit-for-bit the game that was left.

signal changed

const PATH := "user://prisma_save.json"
const VERSION := 1

var data: Dictionary = {}


func _ready() -> void:
	load_data()


func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"best": 0,
		"daily_best": {},
		"daily_streak": 0,
		"daily_last": "",
		"stats": {
			"games": 0, "lines": 0, "prisms": 0, "perfects": 0,
			"best_combo": 0, "pieces": 0, "total_score": 0, "dailies": 0,
		},
		"settings": {"sound": true, "music": true, "haptics": true},
		"run": null,
		"daily_run": null,
		"tutorial_done": false,
		"seen_notes": "",
	}


func load_data() -> void:
	data = defaults()
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_merge(data, parsed)


func save_data() -> void:
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))
	changed.emit()


func setting(key: String) -> bool:
	return bool(data.settings.get(key, true))


func set_setting(key: String, value: bool) -> void:
	data.settings[key] = value
	save_data()


func stat(key: String) -> int:
	return int(data.stats.get(key, 0))


func daily_best(date: String) -> int:
	return int(data.daily_best.get(date, 0))


## Records a finished game. Returns true if it set a new best.
func record_game(game: PrismGame, daily_date: String) -> bool:
	var s: Dictionary = data.stats
	s.games = int(s.games) + 1
	s.lines = int(s.lines) + int(game.stats.lines)
	s.prisms = int(s.prisms) + int(game.stats.prisms)
	s.perfects = int(s.perfects) + int(game.stats.perfects)
	s.pieces = int(s.pieces) + int(game.stats.pieces)
	s.total_score = int(s.total_score) + game.score
	s.best_combo = maxi(int(s.best_combo), int(game.stats.best_combo))
	var new_best := false
	if daily_date != "":
		s.dailies = int(s.dailies) + 1
		if game.score > daily_best(daily_date):
			data.daily_best[daily_date] = game.score
			new_best = true
		data.daily_run = null
	else:
		data.run = null
	if game.score > int(data.best):
		data.best = game.score
		new_best = true
	save_data()
	return new_best


## Call when a daily is started for `date`; keeps the streak honest.
func touch_daily(date: String, yesterday: String) -> void:
	if data.daily_last == date:
		return
	if data.daily_last == yesterday:
		data.daily_streak = int(data.daily_streak) + 1
	else:
		data.daily_streak = 1
	data.daily_last = date
	save_data()


func _merge(into: Dictionary, from: Dictionary) -> void:
	for k in from:
		if into.has(k) and into[k] is Dictionary and from[k] is Dictionary:
			_merge(into[k], from[k])
		else:
			into[k] = from[k]

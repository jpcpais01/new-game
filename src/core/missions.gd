class_name Missions
extends RefCounted
## Mission progress as pure functions of a finished run and the save data, so
## the tests can check them without the Save autoload.


## Progress towards a mission (0..goal). `run` may be null (menus), then only
## what the save remembers counts. `data` is the save dictionary, already
## updated with the run's totals.
static func progress(m: Dictionary, run: Sim, data: Dictionary) -> int:
	var goal: int = m.goal
	var v := 0
	match String(m.kind):
		"time":
			v = int(float(data.get("best_time", 0.0)))
			if run != null:
				v = maxi(v, int(run.seconds()))
		"level":
			v = int(data.get("best_level", 0))
			if run != null:
				v = maxi(v, run.level)
		"kills":
			v = int(data.get("best_kills", 0))
			if run != null:
				v = maxi(v, run.kills)
		"total_kills":
			v = int(data.get("total_kills", 0))
		"warden":
			v = 1 if run != null and run.warden_down else 0
		"win":
			v = int(data.get("wins", 0))
			if run != null and run.state == Sim.WON:
				v = maxi(v, 1)
		"win_nyx":
			v = 1 if run != null and run.state == Sim.WON and run.ship_id == "nyx" else 0
		"evolutions":
			if run != null:
				v = run.evolutions
			if goal <= 1:
				v = maxi(v, mini(1, (data.get("evolved", []) as Array).size()))
		"codex":
			v = (data.get("evolved", []) as Array).size()
		"fleet":
			v = (data.get("ships_won", []) as Array).size()
		"overdrives":
			v = run.od_uses if run != null else 0
		"caches":
			v = run.caches_opened if run != null else 0
		"untouched":
			if run != null:
				var clean := run.tick if run.first_hurt < 0 else run.first_hurt
				v = clean / Sim.TPS
	return clampi(v, 0, goal)


static func done(m: Dictionary, run: Sim, data: Dictionary) -> bool:
	return progress(m, run, data) >= int(m.goal)


## Ships available to fly: the starters plus those whose mission is complete.
static func ship_unlocked(ship_id: String, completed: Array) -> bool:
	var m := Defs.ship_mission(ship_id)
	return m.is_empty() or completed.has(m.id)

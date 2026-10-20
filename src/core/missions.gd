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
		"seraph":
			v = 1 if run != null and run.seraph_down else 0
		"leviathan":
			v = 1 if run != null and run.levi_down else 0
		"charmer":
			v = 1 if run != null and run.levi_clean else 0
		"chain":
			v = int(data.get("best_chain", 0))
			if run != null:
				v = maxi(v, run.chain_best)
		"win":
			v = int(data.get("wins", 0))
			if run != null and run.dawn:
				v = maxi(v, 1)
		"radiance":
			# Highest Radiance level the dawn was reached at (-1 for none yet).
			v = int(data.get("radiance_cleared", -1))
			if run != null and run.dawn:
				v = maxi(v, run.radiance)
		"win_nyx":
			v = 1 if run != null and run.dawn and run.ship_id == "nyx" else 0
		"evolutions":
			if run != null:
				v = run.evolutions
			if goal <= 1:
				v = maxi(v, mini(1, (data.get("evolved", []) as Array).size()))
		"codex":
			v = (data.get("evolved", []) as Array).size()
		"res_codex":
			var known: Array = data.get("resonances", [])
			v = known.size()
			if run != null:
				for id in run.resonances:
					if not known.has(id):
						v += 1
		"resonances":
			v = run.resonances.size() if run != null else 0
		"fleet":
			v = (data.get("ships_won", []) as Array).size()
		"overdrives":
			v = run.od_uses if run != null else 0
		"relics":
			v = run.relics.size() if run != null else 0
		"rifts":
			v = run.rifts_done if run != null else 0
		"total_rifts":
			v = int(data.get("total_rifts", 0))
		"starfalls":
			v = run.starfalls if run != null else 0
		"ricochet":
			v = run.ricochet_best if run != null else 0
		"umbrals":
			if run != null:
				for id in run.relics:
					if Defs.is_umbral(id):
						v += 1
		"caches":
			v = run.caches_opened if run != null else 0
		"dailies":
			v = int(data.get("daily_runs", 0))
		"streak":
			v = int(data.get("daily_streak_best", 0))
		"score":
			v = int(data.get("best_score", 0))
			if run != null:
				v = maxi(v, run.score())
		"afterdark":
			v = int(data.get("best_afterdark", 0))
			if run != null:
				v = maxi(v, run.afterdark_seconds())
		"bosses":
			v = run.bosses_killed if run != null else 0
		"gauntlet":
			v = 1 if int(Missions.gauntlet_rec(data).get("clears", 0)) > 0 else 0
			if run != null and run.gauntlet and run.g_clear_tick >= 0:
				v = 1
		"gauntlet_fast":
			var best := int(Missions.gauntlet_rec(data).get("best_clear", 0))
			if run != null and run.gauntlet and run.g_clear_tick >= 0:
				best = run.g_clear_tick if best <= 0 else mini(best, run.g_clear_tick)
			v = 1 if best > 0 and best < Defs.GAUNTLET_FAST * Sim.TPS else 0
		"gauntlet_bosses":
			v = int(Missions.gauntlet_rec(data).get("best_felled", 0))
			if run != null and run.gauntlet:
				v = maxi(v, run.bosses_killed)
		"maw":
			if run != null:
				v = run.maw_best
				for mw in run.maws:
					v = maxi(v, int(mw.eaten))
		"flares":
			v = run.flares_passed if run != null else 0
		"shards":
			v = run.shards_broken if run != null else 0
		"cover":
			v = run.beams_covered if run != null else 0
		"sectors":
			var sb = data.get("sector_best", {})
			for k in Defs.SECTORS.size():
				var rec = sb.get(String(Defs.SECTORS[k].id), {}) if sb is Dictionary else {}
				var won: bool = rec is Dictionary and bool(rec.get("dawn", false))
				if not won and run != null and run.dawn and run.sector == k and not run.loadout.has("daily"):
					won = true
				if won:
					v += 1
		"untouched":
			if run != null:
				var clean := run.tick if run.first_hurt < 0 else run.first_hurt
				v = clean / Sim.TPS
	return clampi(v, 0, goal)


## The save's Gauntlet record ({} before the first Gauntlet).
static func gauntlet_rec(data: Dictionary) -> Dictionary:
	var g = data.get("gauntlet", {})
	return g if g is Dictionary else {}


static func done(m: Dictionary, run: Sim, data: Dictionary) -> bool:
	return progress(m, run, data) >= int(m.goal)


## Ships available to fly: the starters plus those whose mission is complete.
static func ship_unlocked(ship_id: String, completed: Array) -> bool:
	var m := Defs.ship_mission(ship_id)
	return m.is_empty() or completed.has(m.id)

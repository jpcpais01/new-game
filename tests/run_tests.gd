extends SceneTree
## Deterministic logic checks. Run: godot --headless --path . -s tests/run_tests.gd
## Must not reference autoloads (Save, Sfx).

var _checks := 0
var _fails := 0


func _init() -> void:
	_test_rng()
	_test_trig()
	_test_cards()
	_test_evolutions()
	_test_chests()
	_test_overload()
	_test_ships()
	_test_overdrive_replay()
	_test_missions()
	if not OS.get_cmdline_user_args().has("quick"):
		_test_runs()
	if _fails == 0:
		print("ALL %d CHECKS PASSED" % _checks)
	else:
		print("%d of %d CHECKS FAILED" % [_fails, _checks])
	quit(1 if _fails > 0 else 0)


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", what)


func _test_rng() -> void:
	var a := GlowRng.new(1234)
	var b := GlowRng.new(1234)
	var same := true
	for i in 1000:
		if a.next_u32() != b.next_u32():
			same = false
	check(same, "rng is reproducible")
	var r := GlowRng.new(7)
	var lo := 0
	for i in 10000:
		var v := r.range_i(10)
		if v < 0 or v >= 10:
			check(false, "range_i bounds")
		if v < 5:
			lo += 1
	check(lo > 4700 and lo < 5300, "range_i roughly uniform (%d)" % lo)
	check(GlowRng.mul32(0xFFFFFFFF, 0xFFFFFFFF) == 1, "mul32 wraps")


func _test_trig() -> void:
	var worst := 0.0
	for a in Trig.STEPS:
		var c := Trig.cos_i(a)
		var s := Trig.sin_i(a)
		worst = maxf(worst, absf(c - cos(Trig.to_rad(a))))
		worst = maxf(worst, absf(s - sin(Trig.to_rad(a))))
	check(worst < 1e-9, "trig table accurate (%s)" % str(worst))
	var aw := 0
	for a in range(0, Trig.STEPS, 3):
		var back := Trig.angle_of(Trig.cos_i(a) * 5.0, Trig.sin_i(a) * 5.0)
		var diff := absi(((back - a + Trig.HALF) & Trig.MASK) - Trig.HALF)
		aw = maxi(aw, diff)
	check(aw <= 2, "angle_of inverts table (worst %d steps)" % aw)
	check(Trig.angle_of(0.0, -1.0) == 768, "up is 768")


func _test_cards() -> void:
	var s := Sim.new(99)
	s.xp = s.xp_need
	s.step(0, 0)
	check(s.state == Sim.CHOOSING, "level up opens cards")
	check(s.choices.size() == 3, "three cards")
	var seen := {}
	for c in s.choices:
		seen[c] = true
	check(seen.size() == 3, "cards are distinct")
	s.choose(0)
	check(s.state == Sim.RUNNING, "choosing resumes")
	check(s.level == 2, "level 2")


func _has_event(s: Sim, code: int) -> bool:
	for e in s.events:
		if int(e[0]) == code:
			return true
	return false


func _give_chest(s: Sim, kind: String) -> void:
	s.pickups.append({"k": kind, "x": s.px, "y": s.py, "mag": true, "spd": 0.0})


func _test_evolutions() -> void:
	for id in Defs.EVOLUTIONS:
		var s := Sim.new(5)
		s.weapons = [{"id": id, "lvl": Defs.MAX_LEVEL, "t": 10, "k": 0, "a": 0}]
		var need: String = Defs.EVOLUTIONS[id].needs
		check(Defs.evolves(need) == id, "%s is the catalyst for %s" % [need, id])
		check(not s.evolution_ready(id), "%s not ready without %s" % [id, need])
		s.passives[need] = 1
		s.passive_order.append(need)
		s._recompute()
		check(s.evolution_ready(id), "%s ready with %s" % [id, need])
		_give_chest(s, "chest")
		s.step(0, 0)
		check(s.is_evolved(id), "%s evolves from a cache" % id)
		check(_has_event(s, Sim.EV_EVOLVE), "%s evolution event" % id)
		check(s.display_id(id) == id + "_evo", "%s evolved display id" % id)
		check(String(Defs.card_info(s.display_id(id)).get("name", "")) == Defs.EVOLUTIONS[id].name,
				"%s evolved name" % id)
		# The evolved weapon must fight: surround the ship and let it work.
		for k in 40:
			var a := k * Trig.STEPS / 40
			s._spawn(Defs.BRUTE, s.px + Trig.cos_i(a) * (180.0 + 8.0 * k), s.py + Trig.sin_i(a) * (180.0 + 8.0 * k),
					false, 0)
		s.hp = 1e9
		s.max_hp = 1e9
		var kills0 := s.kills
		for t in 900:
			if s.state == Sim.CHOOSING:
				s.choose(0)
			s.step(0, 0)
		check(s.kills > kills0, "%s evolved kills things (%d)" % [id, s.kills - kills0])


func _test_chests() -> void:
	var s := Sim.new(6)
	_give_chest(s, "chest")
	s.step(0, 0)
	check(s.weapon_level("pulse") == 2, "a cache upgrades what you own")
	check(_has_event(s, Sim.EV_CHEST), "cache event")
	check(s.flux_bonus == 10, "a cache gives Flux")
	var b := Sim.new(7)
	b.weapons[0].lvl = Defs.MAX_LEVEL
	b.passives["amplifier"] = 1
	b.passive_order.append("amplifier")
	b.weapons.append({"id": "orbit", "lvl": 1, "t": 10, "k": 0, "a": 0})
	b._recompute()
	_give_chest(b, "bigchest")
	b.step(0, 0)
	var rewards: Array = []
	for e in b.events:
		if int(e[0]) == Sim.EV_CHEST:
			rewards = e[1]
	check(b.is_evolved("pulse"), "boss cache evolves")
	check(rewards.size() == 4, "boss cache: evolution, two upgrades and Flux (%d)" % rewards.size())
	check(b.weapon_level("orbit") + int(b.passives.amplifier) == 4, "boss cache upgrades twice")


func _test_overload() -> void:
	var s := Sim.new(8)
	var i := s._spawn(Defs.WARDEN, s.px + 600.0, s.py, false, 0)
	s.e_t[i] = Sim.OVERLOAD_TICKS
	s.step(0, 0)
	check(s.e_state[s.boss_index()] == 5, "a Warden left alive overloads")


func _surround(s: Sim, type: int, n: int) -> void:
	for k in n:
		var a := k * Trig.STEPS / n
		s._spawn(type, s.px + Trig.cos_i(a) * (150.0 + 9.0 * k), s.py + Trig.sin_i(a) * (150.0 + 9.0 * k), false, 0)


func _test_ships() -> void:
	for sd in Defs.SHIPS:
		var id: String = sd.id
		var s := Sim.new(11, {"ship": id})
		check(s.ship_id == id, "%s: ship chosen from the loadout" % id)
		check(s.weapons.size() == 1 and s.weapons[0].id == sd.weapon, "%s starts with %s" % [id, sd.weapon])
		check(is_equal_approx(s.max_hp, 100.0 + float(sd.stats.get("hp", 0.0))), "%s max HP" % id)
		check(s.hp == s.max_hp, "%s starts at full HP" % id)
		# Overdrive does nothing until charged.
		s.step(0, 0, true)
		check(s.od_uses == 0 and not _has_event(s, Sim.EV_OVERDRIVE), "%s: burst ignored while charging" % id)
		_surround(s, Defs.DRIFTER, 30)
		s.od = s.od_need
		check(s.od_ready(), "%s: full meter is ready" % id)
		var kills0 := s.kills
		s.step(0, 0, true)
		check(_has_event(s, Sim.EV_OVERDRIVE), "%s: Overdrive fires" % id)
		check(s.od_uses == 1 and s.od < 1.0, "%s: Overdrive spends the meter" % id)
		check(s.od_need > Defs.OD_BASE, "%s: next Overdrive costs more" % id)
		check(not s.od_ready(), "%s: not ready right after firing" % id)
		for t in 300:
			if s.state == Sim.CHOOSING:
				s.choose(0)
			s.step(0, 0)
		if id != "nyx":
			check(s.kills > kills0 + 10, "%s: Overdrive clears the crowd (%d)" % [id, s.kills - kills0])
	# Specific powers.
	var v := Sim.new(12, {"ship": "vesper"})
	v.od = v.od_need
	v.step(0, 0, true)
	check(v.shield > 0, "Aegis raises a shield")
	v.iframes = 0
	v._hurt(50.0)
	check(v.hp == v.max_hp, "Aegis blocks damage")
	var n := Sim.new(13, {"ship": "nyx"})
	var e := n._spawn(Defs.DRIFTER, n.px + 400.0, n.py, false, 0)
	n.od = n.od_need
	n.step(0, 0, true)
	var ex := n.e_x[e]
	for t in 30:
		n.step(0, 0)
	check(n.freeze > 0 and absf(n.e_x[e] - ex) < 0.5, "Eclipse stops enemies in time")
	check(n.e_maxhp[e] > Defs.ENEMY[Defs.DRIFTER].hp * 1.3, "Nyx's swarm is tougher")
	var l := Sim.new(14)
	l._fire_orb(l.px + 300.0, l.py, 0, 100.0, 10.0)
	l.od = l.od_need
	l.step(0, 0, true)
	check(l.qn == 0, "Flare erases enemy fire")
	var k := Sim.new(15, {"ship": "kestrel"})
	check(k.st_speed > 300.0 * 1.1, "Kestrel is fast")
	var a := Sim.new(16, {"ship": "aurora"})
	check(is_equal_approx(a.st_crit, 0.15), "Aurora crit chance")
	var h := Sim.new(17, {"ship": "halcyon"})
	h.hp = 50.0
	h._drop_gem(h.px, h.py, 50.0)
	h.step(0, 0)
	check(h.hp > 50.0, "Halcyon heals from light")


## Overdrive presses are part of the input log, so replays reproduce them.
func _test_overdrive_replay() -> void:
	for id in ["strix", "lumen", "nyx"]:
		var s := Sim.new(21, {"ship": id})
		var fired_at := -1
		while s.tick < 12000 and (s.state == Sim.RUNNING or s.state == Sim.CHOOSING):
			if s.state == Sim.CHOOSING:
				s.choose(Autopilot.pick(s))
				continue
			if fired_at < 0 and s.od_uses > 0:
				fired_at = s.tick
			if fired_at >= 0 and s.tick > fired_at + 400:
				break
			var m := Autopilot.move(s)
			# Mash the button: presses while charging must be harmless too.
			s.step(m.x, m.y, s.od_ready() or s.tick % 7 == 0)
		check(s.od_uses >= 1, "%s: Overdrive fired in a natural run (%d)" % [id, s.od_uses])
		var r := Sim.from_replay(s.to_replay())
		check(r.od_uses == s.od_uses, "%s: replay reproduces Overdrives" % id)
		check(r.checksum() == s.checksum(), "%s: Overdrive replay checksum" % id)


func _find_mission(id: String) -> Dictionary:
	for m in Defs.MISSIONS:
		if m.id == id:
			return m
	return {}


func _test_missions() -> void:
	var data := {"best_time": 0.0, "best_level": 0, "best_kills": 0, "total_kills": 0, "wins": 0,
			"evolved": [], "ships_won": [], "missions": []}
	var s := Sim.new(31)
	s.tick = 130 * Sim.TPS
	check(Missions.done(_find_mission("first_flight"), s, data), "surviving 2:00 completes First Flight")
	check(not Missions.done(_find_mission("long_haul"), s, data), "2:10 is not Long Haul")
	check(not Missions.done(_find_mission("untouchable"), s, data), "2:10 untouched is short of Untouchable")
	s.tick = 200 * Sim.TPS
	check(Missions.done(_find_mission("untouchable"), s, data), "3:20 untouched completes Untouchable")
	s.first_hurt = 60 * Sim.TPS
	s.tick = 130 * Sim.TPS
	check(not Missions.done(_find_mission("untouchable"), s, data), "hurt at 1:00 fails Untouchable")
	s.warden_down = true
	check(Missions.done(_find_mission("warden"), s, data), "Wardenfall")
	data.total_kills = 2500
	check(Missions.done(_find_mission("exterminator"), null, data), "total kills count from the save")
	data.evolved = ["pulse"]
	check(Missions.done(_find_mission("alchemist"), null, data), "a past evolution completes Alchemist")
	check(not Missions.done(_find_mission("twin_evo"), null, data), "Twin Stars needs one run")
	check(Missions.ship_unlocked("lumen", []), "Lumen is always flyable")
	check(not Missions.ship_unlocked("vesper", []), "Vesper starts locked")
	check(Missions.ship_unlocked("vesper", ["warden"]), "Wardenfall unlocks Vesper")
	for sd in Defs.SHIPS:
		if sd.id != "lumen":
			check(not Defs.ship_mission(sd.id).is_empty(), "%s has an unlock mission" % sd.id)


func _test_runs() -> void:
	var t0 := Time.get_ticks_msec()
	var total_ticks := 0
	for seed_v in [1, 2, 3]:
		var s := Sim.new(seed_v, {"hull": 2, "power": 1})
		Autopilot.play(s, 9 * 60 * Sim.TPS)
		total_ticks += s.tick
		print("seed %d: state=%d t=%.0fs lvl=%d kills=%d en=%d flux=%d hp=%.0f weapons=%s" % [
			seed_v, s.state, s.seconds(), s.level, s.kills, s.en, s.flux_earned(), s.hp,
			str(s.weapons.map(func(w): return "%s%d" % [w.id, w.lvl]))])
		check(s.tick > 60 * 60, "bot survives the first minute (seed %d)" % seed_v)
		var r := Sim.from_replay(s.to_replay())
		check(r.tick == s.tick, "replay reaches the same tick (seed %d)" % seed_v)
		check(r.checksum() == s.checksum(), "replay matches checksum (seed %d)" % seed_v)
		check(r.kills == s.kills and r.level == s.level, "replay matches stats (seed %d)" % seed_v)
	var ms := Time.get_ticks_msec() - t0
	print("sim speed: %.3f ms/tick" % (float(ms) / float(maxi(total_ticks, 1)) / 2.0))

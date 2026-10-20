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
	_test_daily()
	_test_mutators()
	_test_afterdark()
	_test_threats()
	_test_seraph()
	_test_chain()
	_test_scythe()
	_test_mines()
	_test_relics()
	_test_radiance()
	_test_banish()
	_test_rifts()
	_test_umbrals()
	_test_glaive()
	_test_echo()
	_test_starfall()
	_test_leviathan()
	_test_gauntlet()
	_test_sectors()
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


func _test_daily() -> void:
	var a := Daily.for_day(20745)
	var b := Daily.for_day(20745)
	check(a.seed == b.seed and a.ship == b.ship and a.mods == b.mods, "a day's run is the same for everyone")
	check(Daily.for_day(20746).seed != a.seed, "the next day is a different run")
	check(Daily.label(20745) == "OCT 19", "day 20745 is Oct 19 (%s)" % Daily.label(20745))
	check(Daily.label(11016) == "FEB 29", "leap day label (%s)" % Daily.label(11016))
	var ships := {}
	for d in 60:
		var dd := Daily.for_day(20000 + d)
		var mods: Array = dd.mods
		ships[dd.ship] = true
		var boons := 0
		for id in mods:
			if Defs.MUTATORS[id].boon:
				boons += 1
		if mods.size() != 3 or boons != 1 or mods[1] == mods[2]:
			check(false, "day %d: one boon and two distinct banes (%s)" % [20000 + d, str(mods)])
		check(not dd.loadout.has("power") and dd.loadout.daily == 20000 + d, "daily loadout has no Forge")
	check(ships.size() >= 5, "dailies rotate through the fleet (%d ships)" % ships.size())
	var s := Sim.new(int(a.seed), a.loadout)
	check(s.mods.size() == 3, "daily mutators reach the sim")
	check(s.score_mult() > 1.3, "banes raise the score multiplier (%.2f)" % s.score_mult())
	# A short daily run replays exactly.
	Autopilot.play(s, 40 * Sim.TPS)
	var r := Sim.from_replay(s.to_replay())
	check(r.checksum() == s.checksum(), "daily replay checksum")


func _test_mutators() -> void:
	var base := Sim.new(51)
	var g := Sim.new(51, {"mods": ["glass"]})
	check(is_equal_approx(g.max_hp, base.max_hp * 0.5) and g.hp == g.max_hp, "Glass Heart halves HP")
	check(g.st_might > base.st_might + 0.39, "Glass Heart hits harder")
	var gr := Sim.new(51, {"mods": ["gravity"]})
	check(is_equal_approx(gr.st_magnet, base.st_magnet * 3.0), "Gravity triples pickup range")
	var gi := Sim.new(51, {"mods": ["giants"]})
	var e := gi._spawn(Defs.DRIFTER, 300.0, 0.0, false, 0)
	check(gi.e_r[e] > Defs.ENEMY[Defs.DRIFTER].r * 1.25 and gi.e_maxhp[e] >= Defs.ENEMY[Defs.DRIFTER].hp * 1.99,
			"Giants are big and tough")
	var fr := Sim.new(51, {"mods": ["frenzy"]})
	var f := fr._spawn(Defs.DRIFTER, 300.0, 0.0, false, 0)
	check(fr.e_speed[f] > Defs.ENEMY[Defs.DRIFTER].speed * 1.1, "Frenzy speeds the swarm")
	var oc := Sim.new(51, {"mods": ["overcharged"]})
	var k := oc._spawn(Defs.DRIFTER, 300.0, 0.0, false, 0)
	oc.e_hp[k] = 0.0
	oc.step(0, 0)
	check(is_equal_approx(oc.od, 2.0), "Overcharged doubles Overdrive charge (%.1f)" % oc.od)
	var bl := Sim.new(51, {"mods": ["bloodlight"]})
	bl.hp = 50.0
	var j := bl._spawn(Defs.DRIFTER, 300.0, 0.0, false, 0)
	bl.e_hp[j] = 0.0
	bl.step(0, 0)
	check(bl.hp > 50.0, "Bloodlight heals on kills")
	for t in 40:
		var cs := bl._roll_choices()
		if cs.has("renewal"):
			check(false, "Bloodlight removes Renewal")
			break
	var du := Sim.new(51, {"mods": ["dusk"]})
	du.sched_i = 3
	du.tick = 180 * Sim.TPS - 1
	du.step(0, 0)
	check(du.boss_index() >= 0 and du.e_type[du.boss_index()] == Defs.WARDEN, "Short Night: Warden at 3:00")
	var gl := Sim.new(51, {"mods": ["gilded"]})
	check(gl.elite_next == 60 * Sim.TPS, "Gilded elites from the first minute")
	var lu := Sim.new(52, {"mods": ["lucky"]})
	_give_chest(lu, "chest")
	lu.step(0, 0)
	check(lu.flux_bonus == 20, "Lucky Star doubles cache Flux")
	var v := Sim.new(53, {"mods": ["volatile"]})
	_surround(v, Defs.DRIFTER, 40)
	v.hp = 1e9
	v.max_hp = 1e9
	var blasts := 0
	for t in 600:
		if v.state == Sim.CHOOSING:
			v.choose(0)
		v.step(0, 0)
		for ev in v.events:
			if int(ev[0]) == Sim.EV_BLAST:
				blasts += 1
	check(blasts > 0, "Volatile enemies detonate (%d)" % blasts)
	for id in Defs.MUTATORS:
		check(Defs.BOONS.has(id) != Defs.BANES.has(id), "%s is a boon or a bane" % id)
		check(bool(Defs.MUTATORS[id].boon) == Defs.BOONS.has(id), "%s listed correctly" % id)


func _kill_boss(s: Sim, type: int) -> void:
	var i := s._spawn(type, s.px + 600.0, s.py, false, 0)
	s.e_hp[i] = 0.0
	s.step(0, 0)


func _test_afterdark() -> void:
	var s := Sim.new(61)
	s.tick = 480 * Sim.TPS
	s.sched_i = Sim.SCHEDULE.size()
	var sc0 := s.score()
	_kill_boss(s, Defs.ECLIPSE)
	check(s.state == Sim.WON and s.dawn, "the Eclipse brings the dawn")
	check(s.score() > sc0 + 10000, "the dawn is worth a big score")
	s.step(0, 0)
	check(s.state == Sim.WON, "a won run waits for a choice")
	s.continue_night()
	check(s.state == Sim.RUNNING and s.endless, "continue into the Afterdark")
	check(_has_event(s, Sim.EV_WAVE), "Afterdark banner")
	s.continue_night()
	check(s.log_actions.size() == 2, "continuing twice does nothing")
	s.tick = s.night_next - 1
	s.step(0, 0)
	var b := s.boss_index()
	check(b >= 0 and s.e_type[b] == Defs.WARDEN and s.night == 1, "night 1 brings back the Warden")
	check(s.e_maxhp[b] > Defs.ENEMY[Defs.WARDEN].hp * 1.5, "night bosses are tougher (%.0f)" % s.e_maxhp[b])
	s.e_hp[b] = 0.0
	s.step(0, 0)
	s.tick = s.night_next - 1
	s.step(0, 0)
	b = s.boss_index()
	check(b >= 0 and s.e_type[b] == Defs.LEVIATHAN and s.night == 2, "night 2 brings back the Leviathan")
	s.e_hp[b] = 0.0
	s.step(0, 0)
	var night_big := false
	for p in s.pickups:
		if p.k == "bigchest":
			night_big = true
	check(night_big, "an Afterdark Leviathan drops a boss cache")
	s.tick = s.night_next - 1
	s.step(0, 0)
	b = s.boss_index()
	check(b >= 0 and s.e_type[b] == Defs.SERAPH and s.night == 3, "night 3 brings back the Seraph")
	s.e_hp[b] = 0.0
	s.step(0, 0)
	s.tick = s.night_next - 1
	s.step(0, 0)
	b = s.boss_index()
	check(b >= 0 and s.e_type[b] == Defs.ECLIPSE and s.night == 4, "night 4 brings back the Eclipse")
	var bosses := s.bosses_killed
	s.e_hp[b] = 0.0
	s.step(0, 0)
	check(s.state == Sim.RUNNING and s.bosses_killed == bosses + 1, "an Afterdark Eclipse does not end the run")
	var big := false
	for p in s.pickups:
		if p.k == "bigchest":
			big = true
	check(big, "an Afterdark Eclipse drops a boss cache")
	check(s.afterdark_seconds() > 100, "Afterdark time is counted (%d)" % s.afterdark_seconds())
	s.tick += 80 * Sim.TPS
	_kill_boss(s, Defs.WARDEN)
	var data := {"best_score": 0, "best_afterdark": 0, "daily_runs": 2, "daily_streak_best": 3}
	check(Missions.done(_find_mission("afterdark"), s, data), "Into the Afterdark mission")
	check(Missions.done(_find_mission("nightmare"), s, data), "Nightmare: six bosses in one run")
	var plain := Sim.new(61)
	plain.tick = s.tick
	var pe := plain._spawn(Defs.DRIFTER, 0.0, 0.0, false, 0)
	var ne := s._spawn(Defs.DRIFTER, 0.0, 0.0, false, 0)
	check(s.e_maxhp[ne] > plain.e_maxhp[pe] * 1.4, "the swarm toughens every night")
	check(Missions.done(_find_mission("daybreaker"), null, data), "Daybreaker counts dailies")
	check(Missions.done(_find_mission("ritual"), null, data), "Ritual counts the best streak")
	check(not Missions.done(_find_mission("luminary"), null, data), "Luminary needs a big score")


## A sim with an empty field and the director held back.
func _quiet(seed_v: int) -> Sim:
	var s := Sim.new(seed_v)
	s.spawn_acc = -1e9
	s.elite_next = 1 << 30
	s.sched_i = Sim.SCHEDULE.size()
	s.rift_next = 1 << 30
	return s


func _test_threats() -> void:
	# Sentinel: tracks, warns, then fires a beam that hurts.
	var s := _quiet(71)
	var e := s._spawn(Defs.SENTINEL, s.px + 320.0, s.py, false, 0)
	s.e_t[e] = 0
	var charged := false
	var fired := false
	var warned := false
	for k in 140:
		s.step(0, 0)
		for ev in s.events:
			if ev[0] == Sim.EV_LASER:
				if ev[6] == 0:
					charged = true
				else:
					fired = true
		if s.e_state[e] == 1 and not s.lasers().is_empty():
			warned = true
	check(charged and fired and warned, "Sentinels warn, then fire")
	check(s.hp < s.max_hp, "a Sentinel beam hurts a pilot who stands still")
	var s2 := _quiet(72)
	var e2 := s2._spawn(Defs.SENTINEL, s2.px + 320.0, s2.py, false, 0)
	s2.e_t[e2] = 0
	for k in 140:
		var dodge := 100 if s2.e_state[e2] == 1 and s2.e_t[e2] < 30 else 0
		s2.step(0, dodge)
	check(s2.hp == s2.max_hp, "stepping out of the line dodges the beam")
	# Phantom: marks a spot beside you, then blinks there.
	var p := _quiet(73)
	var f := p._spawn(Defs.PHANTOM, p.px + 600.0, p.py, false, 0)
	p.e_t[f] = 0
	var marked := false
	var arrived := false
	for k in 60:
		p.step(0, 0)
		for ev in p.events:
			if ev[0] == Sim.EV_BLINK:
				if ev[6] == 0:
					marked = true
				else:
					arrived = true
	var dx := p.e_x[f] - p.px
	var dy := p.e_y[f] - p.py
	check(marked and arrived, "Phantoms mark, then blink")
	check(absf(sqrt(dx * dx + dy * dy) - 200.0) < 40.0, "a Phantom lands beside you (%.0f)" % sqrt(dx * dx + dy * dy))
	# Bastion: its aegis halves the damage its neighbours take.
	var b := _quiet(74)
	var bi := b._spawn(Defs.BASTION, b.px + 700.0, b.py, false, 0)
	var di := b._spawn(Defs.DRIFTER, b.px + 760.0, b.py, false, 0)
	var far := b._spawn(Defs.DRIFTER, b.px - 700.0, b.py, false, 0)
	for k in 6:
		b.step(0, 0)
	check(b.e_shd[di] == 1 and b.e_shd[far] == 0 and b.e_shd[bi] == 0, "a Bastion shields its neighbours")
	b.st_crit = 0.0
	b.e_hp[di] = 500.0
	b.e_hp[far] = 500.0
	b._damage(di, 10.0, 0.0, 0.0)
	b._damage(far, 10.0, 0.0, 0.0)
	check(absf((500.0 - b.e_hp[di]) * 2.0 - (500.0 - b.e_hp[far])) < 0.01, "shielded enemies take half damage")
	b.e_hp[bi] = 0.0
	for k in 7:
		b.step(0, 0)
	check(b.e_shd[di] == 0, "the aegis falls with its Bastion")
	var sp := false
	for ev in Sim.SCHEDULE:
		if ev[1] == "grid" and ev[2] == Defs.SENTINEL:
			sp = true
	check(sp, "a Laser Grid is scheduled")


func _test_seraph() -> void:
	var at := -1
	for ev in Sim.SCHEDULE:
		if ev[1] == "boss" and ev[2] == Defs.SERAPH:
			at = ev[0]
	check(at == 360, "the Seraph arrives at 6:00")
	var s := _quiet(81)
	var i := s._spawn(Defs.SERAPH, s.px + 900.0, s.py, false, 0)
	var arms := 0
	var lances := 0
	var blinked := false
	for k in 600:
		s.iframes = 999
		s.step(0, 0)
		var live := 0
		for l in s.lasers():
			if l[5]:
				live += 1
		if s.e_state[i] == 2:
			arms = maxi(arms, live)
		elif s.e_state[i] == 4:
			lances = maxi(lances, live)
		for ev in s.events:
			if ev[0] == Sim.EV_BLINK and ev[6] == 1 and ev[5] == Defs.SERAPH:
				blinked = true
	check(arms == 3, "the Seraph's wheel has three arms (%d)" % arms)
	check(lances == 1, "the Seraph fires aimed lances (%d)" % lances)
	check(blinked, "the Seraph blinks beside you")
	s.e_hp[i] = s.e_maxhp[i] * 0.4
	check(s.seraph_arms(i) == 4 and s.seraph_lances(i).size() == 3, "a wounded Seraph burns brighter")
	s.e_hp[i] = 0.0
	s.step(0, 0)
	var big := false
	for p in s.pickups:
		if p.k == "bigchest":
			big = true
	check(s.seraph_down and s.bosses_killed == 1 and big, "the Seraph falls and drops a boss cache")
	check(s.state == Sim.RUNNING, "the Seraph is not the last boss")
	check(Missions.done(_find_mission("seraphfall"), s, {}), "Seraphfall mission")


func _test_chain() -> void:
	var s := _quiet(91)
	for k in 60:
		var e := s._spawn(Defs.DRIFTER, s.px + 800.0, s.py + float(k), false, 0)
		s.e_hp[e] = 0.0
	s.step(0, 0)
	check(s.chain == 60 and s.chain_best == 60, "kills build the Chain (%d)" % s.chain)
	check(_has_event(s, Sim.EV_CHAIN), "a Chain milestone is announced")
	check(s.chain_score > 0, "a long Chain multiplies the score (%d)" % s.chain_score)
	check(absf(Defs.chain_mult(25) - 1.1) < 1e-9 and Defs.chain_mult(100000) == Defs.CHAIN_MAX_MULT, "Chain multiplier steps")
	s._hurt(5.0)
	check(s.chain == 0 and _has_event(s, Sim.EV_CHAIN_LOST), "a hit breaks the Chain")
	check(s.chain_best == 60, "the best Chain is kept")
	var e2 := s._spawn(Defs.DRIFTER, s.px + 800.0, s.py, false, 0)
	s.e_hp[e2] = 0.0
	s.step(0, 0)
	check(s.chain == 1, "a new Chain starts")
	for k in Defs.CHAIN_TICKS + 1:
		s.step(0, 0)
	check(s.chain == 0, "the Chain fades without kills")
	check(Missions.done(_find_mission("unbroken"), null, {"best_chain": 300}), "Unbroken mission")


func _test_scythe() -> void:
	var s := _quiet(101)
	s.weapons = [{"id": "scythe", "lvl": 1, "t": 1, "k": 0, "a": 0}]
	var front := s._spawn(Defs.BRUTE, s.px + 120.0, s.py, false, 0)
	var back := s._spawn(Defs.BRUTE, s.px - 150.0, s.py, false, 0)
	s.step(0, 0)
	check(_has_event(s, Sim.EV_SLASH), "the Ion Scythe sweeps")
	check(s.e_hp[front] < s.e_maxhp[front], "the sweep cuts what is in front")
	check(s.e_hp[back] == s.e_maxhp[back], "a Lv1 sweep leaves what is behind you")
	s.weapons[0].lvl = 4
	s.weapons[0].t = 1
	s.step(0, 0)
	check(s.e_hp[back] < s.e_maxhp[back], "a Lv4 sweep cuts behind you too")
	# Lunar Reaper: full circles that heal on kills.
	var r := _quiet(102)
	r.weapons = [{"id": "scythe", "lvl": Defs.EVO_LEVEL, "t": 1, "k": 0, "a": 0}]
	r.hp = 50.0
	for k in 8:
		var a := k * Trig.STEPS / 8
		r._spawn(Defs.DRIFTER, r.px + Trig.cos_i(a) * 150.0, r.py + Trig.sin_i(a) * 150.0, false, 0)
	r.step(0, 0)
	var slashes := 0
	for e in r.events:
		if int(e[0]) == Sim.EV_SLASH:
			slashes += 1
	check(r.kills == 0 and r.en == 0 or r.hp > 50.0, "the Lunar Reaper cuts down a ring (%d left)" % r.en)
	check(r.hp > 50.0 and r.hp <= 54.0, "the Lunar Reaper heals on kills, capped per sweep (%.1f)" % r.hp)
	for t in 10:
		r.step(0, 0)
	check(r.weapons[0].k == 0 and r.weapons[0].t > 10, "the Lunar Reaper sweeps twice, then recharges")


func _test_mines() -> void:
	var s := _quiet(111)
	s.weapons = [{"id": "mine", "lvl": 1, "t": 1, "k": 0, "a": 0}]
	var far := s._spawn(Defs.BRUTE, s.px + 700.0, s.py, false, 0)
	s.e_speed[far] = 0.0
	s.step(0, 0)
	check(s.mines.size() == 1 and _has_event(s, Sim.EV_MINE), "Photon Mines drop a mine")
	var m: Dictionary = s.mines[0]
	var e := s._spawn(Defs.DRIFTER, m.x, m.y, false, 0)
	s.e_speed[e] = 0.0
	s.step(0, 0)
	check(s.mines.size() == 1, "a fresh mine waits to arm")
	for t in Sim.MINE_ARM + 2:
		s.step(0, 0)
	check(s.mines.is_empty() and s.e_hp[e] < s.e_maxhp[e] or s.kills > 0, "an armed mine detonates under the swarm")
	# A full field: the oldest mine goes off to make room.
	var f := _quiet(112)
	f.weapons = [{"id": "mine", "lvl": 1, "t": 1, "k": 0, "a": 0}]
	var far2 := f._spawn(Defs.BRUTE, f.px + 700.0, f.py, false, 0)
	f.e_speed[far2] = 0.0
	for k in 4:
		f.weapons[0].t = 1
		f.step(0, 0)
	check(f.mines.size() == int(Defs.WEAPONS.mine.levels[0].max), "the field holds at most %d mines" % f.mines.size())
	# Constellation: armed mines link into tripwires.
	var c := _quiet(113)
	c.weapons = [{"id": "mine", "lvl": Defs.EVO_LEVEL, "t": 999, "k": 0, "a": 0}]
	c.mines = [{"x": c.px + 300.0, "y": c.py - 200.0, "t": 0, "life": 600, "dmg": 10.0, "blast": 100.0},
			{"x": c.px + 300.0, "y": c.py + 200.0, "t": 0, "life": 600, "dmg": 10.0, "blast": 100.0}]
	var w := c._spawn(Defs.BRUTE, c.px + 300.0, c.py, false, 0)
	c.e_speed[w] = 0.0
	check(c.mine_links().size() == 1, "two close armed mines link")
	for t in 9:
		c.step(0, 0)
	check(c.e_hp[w] < c.e_maxhp[w], "a tripwire burns what crosses it")
	check(c.mines.size() == 2, "a tripwire does not set the mines off")


func _test_relics() -> void:
	var s := _quiet(121)
	_give_chest(s, "bigchest")
	s.step(0, 0)
	check(s.state == Sim.CHOOSING and s.relic_choice, "a boss cache offers a relic")
	check(s.choices.size() == 3, "three relics to choose from")
	var ok := true
	for c in s.choices:
		ok = ok and Defs.is_relic(c)
	check(ok, "relic offers are relics")
	s.rerolls = 1
	s.reroll()
	ok = s.relic_choice
	for c in s.choices:
		ok = ok and Defs.is_relic(c)
	check(ok, "a reroll keeps it a relic offer")
	var id: String = s.choices[0]
	s.choose(0)
	check(s.relics == [id] and s.state == Sim.RUNNING and not s.relic_choice, "a relic is taken")
	check(_has_event(s, Sim.EV_RELIC), "relic event")
	# The first elite's cache holds one too; later elites' do not.
	var el := _quiet(122)
	var a := el._spawn(Defs.BRUTE, el.px + 800.0, el.py, true, 0)
	el.e_hp[a] = 0.0
	el.step(0, 0)
	check(el.pickups.size() == 1 and el.pickups[0].get("relic", false), "the first elite guards a relic")
	var b := el._spawn(Defs.BRUTE, el.px - 800.0, el.py, true, 0)
	el.e_hp[b] = 0.0
	el.step(0, 0)
	check(not el.pickups[1].get("relic", false), "later elites do not")
	el.pickups[0].mag = true
	el.pickups[0].x = el.px
	el.pickups[0].y = el.py
	el.step(0, 0)
	check(el.state == Sim.CHOOSING and el.relic_choice, "the relic cache offers a relic")
	# Guardian Halo: blocks a hit, keeps the Chain, then recharges.
	var h := _quiet(123)
	h._take_relic("halo")
	h.chain = 40
	h.chain_t = 100
	var hp0 := h.hp
	h._hurt(30.0)
	check(h.hp == hp0 and h.chain == 40 and _has_event(h, Sim.EV_HALO), "the Halo blocks a hit and the Chain holds")
	h.iframes = 0
	h._hurt(30.0)
	check(h.hp < hp0 and h.chain == 0, "a spent Halo lets the next hit through")
	for t in Defs.HALO_TICKS:
		h.step(0, 0)
	check(h.halo_frac() >= 1.0, "the Halo recharges")
	# Ion Wake burns what crosses the trail.
	var wk := _quiet(124)
	wk.weapons = []
	wk._take_relic("wake")
	var en := wk._spawn(Defs.BRUTE, wk.px + 200.0, wk.py, false, 0)
	wk.e_speed[en] = 0.0
	for t in 60:
		wk.step(100, 0)
	check(wk.trail.size() > 5 and wk.e_hp[en] < wk.e_maxhp[en], "Ion Wake scorches the swarm")
	# Starbreaker and Wrath of Dawn.
	var sb := _quiet(125)
	sb.st_crit = 0.0
	var e1 := sb._spawn(Defs.BRUTE, sb.px + 800.0, sb.py, true, 0)
	sb._damage(e1, 10.0, 0.0, 0.0)
	var plain := sb.e_maxhp[e1] - sb.e_hp[e1]
	sb._take_relic("starbreaker")
	sb.st_crit = 0.0
	sb._damage(e1, 10.0, 0.0, 0.0)
	check(absf((sb.e_maxhp[e1] - sb.e_hp[e1]) - plain * 2.6) < 1e-6, "Starbreaker hits elites +60%")
	sb._take_relic("wrath")
	sb.st_crit = 0.0
	sb.hp = sb.max_hp * 0.4
	var before := sb.e_hp[e1]
	sb._damage(e1, 10.0, 0.0, 0.0)
	check(absf((before - sb.e_hp[e1]) - plain * 1.6 * 1.5) < 1e-6, "Wrath of Dawn hits harder at low health")
	# Phoenix, Midas, Supercritical, Overcharge.
	var ph := _quiet(126)
	var rv := ph.revives
	var rr := ph.rerolls
	ph._take_relic("phoenix")
	ph._take_relic("midas")
	ph._take_relic("supercrit")
	check(ph.revives == rv + 1 and ph.rerolls == rr + 1, "Phoenix adds a revive, Midas a reroll")
	check(absf(ph.st_crit - 0.15) < 1e-9 and absf(ph.st_xp - 1.25) < 1e-9, "Supercritical and Midas stats")
	_give_chest(ph, "chest")
	ph.step(0, 0)
	check(ph.flux_bonus == 30, "Midas triples cache Flux (%d)" % ph.flux_bonus)
	ph._take_relic("phoenix")
	check(ph.relics.size() == 3, "a relic is only taken once")
	var all := _quiet(127)
	for r in Defs.RELIC_ORDER:
		all._take_relic(r)
	_give_chest(all, "bigchest")
	all.step(0, 0)
	check(all.state == Sim.RUNNING and all.pending_relics == 0, "no relic offer once you hold them all")
	check(Missions.done(_find_mission("relic_keeper"), all, {}), "Reliquary mission")


func _test_radiance() -> void:
	# Radiance 0 is the plain game, bit for bit.
	var a := Sim.new(41, {})
	var b := Sim.new(41, {"radiance": 0})
	for i in 1800:
		a.step(30, -20)
		b.step(30, -20)
		if a.state == Sim.CHOOSING:
			a.choose(0)
			b.choose(0)
	check(a.checksum() == b.checksum(), "Radiance 0 changes nothing")
	var r0 := _quiet(42)
	var r8 := Sim.new(42, {"radiance": 8})
	var d0 := r0._spawn(Defs.DRIFTER, 300.0, 0.0, false, 0)
	var d8 := r8._spawn(Defs.DRIFTER, 300.0, 0.0, false, 0)
	check(absf(r8.e_maxhp[d8] / r0.e_maxhp[d0] - 1.15 * 1.15) < 1e-6, "Kindled and Legion toughen the swarm")
	check(absf(r8.e_dmg[d8] / r0.e_dmg[d0] - 1.2) < 1e-6, "Sharp: enemies hit harder")
	var w0 := r0._spawn(Defs.WARDEN, 600.0, 0.0, false, 0)
	var w8 := r8._spawn(Defs.WARDEN, 600.0, 0.0, false, 0)
	check(absf(r8.e_maxhp[w8] / r0.e_maxhp[w0] - 1.3) < 1e-6, "Titans: bosses have more HP")
	check(r8.heal_mult < 1.0 and r0.heal_mult == 1.0, "Scarcity weakens healing")
	r8.hp = 10.0
	r8._heal(30.0)
	check(absf(r8.hp - 10.0 - 30.0 * 0.65) < 1e-9, "healing is scaled")
	var r10 := Sim.new(43, {"radiance": 10})
	check(r10.overload_ticks == 75 * Sim.TPS and r0.overload_ticks == Sim.OVERLOAD_TICKS, "Impatient bosses")
	check(absf(r10.sched_scale - 0.9) < 1e-9, "Eventide runs the night faster")
	check(r10.elite_next == 150 * Sim.TPS, "Hunted: elites from 2:30")
	check(absf(r10.score_mult() - 2.5) < 1e-9, "Radiance 10 scores x2.5")
	check(Sim.new(1, {"radiance": 99}).radiance == Defs.MAX_RADIANCE, "Radiance is clamped")
	check(Defs.RADIANCE.size() == Defs.MAX_RADIANCE, "one rule per Radiance level")
	var fl0 := Sim.new(44, {})
	var fl5 := Sim.new(44, {"radiance": 5})
	fl0.kills = 600
	fl5.kills = 600
	check(fl5.flux_earned() == int(float(fl0.flux_earned()) * 1.5), "Radiance pays more Flux")
	# Missions read the highest level cleared.
	var m := _find_mission("zenith")
	check(not Missions.done(m, null, {"radiance_cleared": 4}), "Zenith needs Radiance 5")
	check(Missions.done(m, null, {"radiance_cleared": 5}), "Zenith from the save")
	var won := Sim.new(45, {"radiance": 5})
	won.dawn = true
	check(Missions.done(m, won, {"radiance_cleared": 2}), "Zenith from a run")
	check(Missions.progress(_find_mission("kindled"), null, {}) == 0, "no Radiance cleared yet")


func _test_banish() -> void:
	var s := Sim.new(51, {"banish": 1})
	check(s.banishes == Defs.BASE_BANISHES + 1, "banishes from the Forge")
	s.xp = s.xp_need
	s.step(0, 0)
	check(s.state == Sim.CHOOSING, "cards open for banishing")
	var gone: String = s.choices[1]
	var keep0: String = s.choices[0]
	var keep2: String = s.choices[2]
	s.banish(1)
	check(s.banished.has(gone) and s.banishes == Defs.BASE_BANISHES, "a card is banished")
	check(s.choices.size() == 3 and s.choices[0] == keep0 and s.choices[2] == keep2, "other cards stay put")
	check(s.choices[1] != gone and s.choices[1] != keep0 and s.choices[1] != keep2, "a fresh card fills the slot")
	check(_has_event(s, Sim.EV_BANISH), "banish event")
	var ok := true
	for i in 300:
		for c in s._roll_choices():
			if c == gone:
				ok = false
	check(ok, "a banished card never returns")
	s.choices[0] = "heal"
	var left := s.banishes
	s.banish(0)
	check(s.banishes == left and s.choices[0] == "heal", "Repair cannot be banished")
	s.choose(2)
	s.banish(0)
	check(s.banishes == left, "no banishing outside a choice")
	# Run on with the bot banishing as it goes; the replay must follow.
	var r := Sim.new(52, {"banish": 2})
	while r.tick < 150 * Sim.TPS and (r.state == Sim.RUNNING or r.state == Sim.CHOOSING):
		if r.state == Sim.CHOOSING:
			var bk := r.choices.find_custom(func(c): return Sim.can_banish(c))
			if r.banishes > 0 and not r.relic_choice and bk >= 0:
				r.banish(bk)
			else:
				r.choose(Autopilot.pick(r))
			continue
		var mv := Autopilot.move(r)
		r.step(mv.x, mv.y, Autopilot.burst(r))
	check(r.banished.size() == 3, "the run banished three cards (%d)" % r.banished.size())
	var rp := Sim.from_replay(r.to_replay())
	check(rp.checksum() == r.checksum() and rp.banished == r.banished, "banishes replay")


func _rift_at(s: Sim, kind: int, x: float, y: float) -> void:
	s.rift = {"kind": kind, "x": x, "y": y, "ox": x, "oy": y, "life": int(Defs.RIFT_LIFE[kind]) * Sim.TPS,
			"on": false, "prog": 0.0, "k0": 0, "goal": 0}


func _test_rifts() -> void:
	# The first rift is a beacon at 0:50.
	var s := _quiet(201)
	s.rift_next = Defs.RIFT_FIRST * Sim.TPS
	while s.tick < Defs.RIFT_FIRST * Sim.TPS:
		s.step(0, 0)
	check(not s.rift.is_empty() and int(s.rift.kind) == Defs.RIFT_BEACON and _has_event(s, Sim.EV_RIFT),
			"the first rift is a beacon at 0:50")
	var d := sqrt(pow(float(s.rift.x) - s.px, 2) + pow(float(s.rift.y) - s.py, 2))
	check(d > 500.0 and sqrt(pow(float(s.rift.x), 2) + pow(float(s.rift.y), 2)) < Sim.ARENA_R - 200.0,
			"rifts open out in the open, away from the ship")
	# Standing inside lights it; the swarm answers while it charges.
	s.px = float(s.rift.x) + 20.0
	s.py = float(s.rift.y)
	var en0 := s.en
	for t in Defs.BEACON_TICKS + 2:
		s.iframes = 2
		s.step(0, 0)
	check(s.rift.is_empty() and s.rifts_done == 1, "a beacon is lit by holding the ring")
	check(s.en > en0, "the swarm closes in on a charging beacon")
	for t in 30:
		s.step(0, 0)
	check(s.caches_opened == 1, "a lit beacon pays a Prism Cache")
	check(s.rift_next > s.tick, "the next rift is scheduled")
	# Stepping out drains the charge; an untouched rift fades.
	var b := _quiet(202)
	_rift_at(b, Defs.RIFT_BEACON, b.px, b.py)
	for t in 100:
		b.step(0, 0)
	b.px += 400.0
	for t in 60:
		b.step(0, 0)
	check(absf(float(b.rift.prog) - 70.0) < 1.5, "the charge drains outside the ring (%.1f)" % float(b.rift.prog))
	var f := _quiet(203)
	_rift_at(f, Defs.RIFT_TRIAL, f.px + 900.0, f.py)
	var faded := false
	for t in int(Defs.RIFT_LIFE[Defs.RIFT_TRIAL]) * Sim.TPS + 2:
		f.step(0, 0)
		for e in f.events:
			if int(e[0]) == Sim.EV_RIFT and int(e[4]) == 3:
				faded = true
	check(faded and f.rift.is_empty() and f.rifts_done == 0, "an untouched rift fades")
	# No rift opens while a boss is up.
	var bo := _quiet(204)
	bo.rift_next = 10
	bo._spawn(Defs.WARDEN, bo.px + 900.0, bo.py, false, 0)
	for t in 20:
		bo.iframes = 2
		bo.step(0, 0)
	check(bo.rift.is_empty(), "rifts wait for the boss to fall")
	# The Prism Wisp flees when you come close, but you can run it down.
	var w := _quiet(205)
	_rift_at(w, Defs.RIFT_WISP, w.px + 320.0, w.py)
	for t in 20:
		w.step(0, 0)
	check(w.rift.on and float(w.rift.x) > w.px + 330.0, "the wisp bolts")
	var caught := false
	for t in 30 * Sim.TPS:
		if w.rift.is_empty():
			caught = true
			break
		var dx: float = float(w.rift.x) - w.px
		var dy: float = float(w.rift.y) - w.py
		var l := sqrt(dx * dx + dy * dy) + 0.001
		w.iframes = 2
		w.step(int(dx / l * 100.0), int(dy / l * 100.0))
	check(caught and w.rifts_done == 1, "a chased wisp is caught")
	check(w.od_ready() and w.gn > 0, "the wisp fills the Overdrive and showers light")
	# Umbral Trial: touch it, destroy enough of the swarm in time.
	var tr := _quiet(206)
	tr.tick = 180 * Sim.TPS
	_rift_at(tr, Defs.RIFT_TRIAL, tr.px + 30.0, tr.py)
	tr.step(0, 0)
	check(tr.rift.on and int(tr.rift.goal) == tr.trial_goal() and tr.en >= 18, "touching the rift starts a trial")
	check(_has_event(tr, Sim.EV_RIFT), "trial event")
	tr.kills += int(tr.rift.goal)
	tr.iframes = 2
	tr.step(0, 0)
	check(tr.state == Sim.CHOOSING and tr.relic_choice and tr.umbral_choice and tr.rifts_done == 1,
			"a won trial offers Umbral relics")
	var ok := tr.choices.size() == 3
	for c in tr.choices:
		ok = ok and Defs.is_umbral(c)
	check(ok, "the offer holds three Umbral relics")
	tr.rerolls = 1
	tr.reroll()
	ok = tr.umbral_choice
	for c in tr.choices:
		ok = ok and Defs.is_umbral(c)
	check(ok, "a reroll keeps it an Umbral offer")
	tr.banishes = 1
	tr.banish(0)
	check(tr.banishes == 1, "Umbral relics cannot be banished")
	var pick: String = tr.choices[1]
	tr.choose(1)
	check(tr.relics.has(pick) and tr.state == Sim.RUNNING and not tr.umbral_choice, "an Umbral relic is taken")
	# Refusing drops a Prism Cache instead.
	var de := _quiet(207)
	de.pending_umbral = 1
	de.step(0, 0)
	check(de.state == Sim.CHOOSING and de.umbral_choice, "an Umbral offer opens")
	de.decline()
	check(de.state == Sim.RUNNING and de.relics.is_empty() and de.pickups.size() == 1, "refusing drops a cache")
	de.step(0, 0)
	check(de.caches_opened == 1, "the refused offer's cache opens")
	de.choose(0)
	de.decline()
	check(de.state == Sim.RUNNING, "decline only works on an Umbral offer")
	# A trial that runs out of time fails without a prize.
	var fa := _quiet(208)
	_rift_at(fa, Defs.RIFT_TRIAL, fa.px, fa.py)
	fa.step(0, 0)
	fa.rift.life = 2
	var failed := false
	for t in 4:
		fa.iframes = 2
		fa.step(0, 0)
		for e in fa.events:
			if int(e[0]) == Sim.EV_RIFT and int(e[4]) == 4:
				failed = true
	check(failed and fa.rift.is_empty() and fa.rifts_done == 0 and fa.pending_umbral == 0, "a timed-out trial fails")
	# Once every Umbral relic is held, a trial pays a boss cache instead.
	var all := _quiet(209)
	for id in Defs.UMBRAL_ORDER:
		all._take_relic(id)
	_rift_at(all, Defs.RIFT_TRIAL, all.px, all.py)
	all.step(0, 0)
	all.kills += 999
	all.iframes = 2
	all.step(0, 0)
	check(all.pending_umbral == 0 and all.state == Sim.CHOOSING and all.relic_choice and not all.umbral_choice,
			"with every Umbral relic held a trial pays a boss cache (and its relic)")
	check(all.score() >= Defs.RIFT_SCORE, "rifts add to the score")
	# Missions.
	check(Missions.progress(_find_mission("riftwalker"), all, {}) == 1, "Riftwalker counts rifts")
	check(Missions.done(_find_mission("umbral_pact"), all, {}), "Umbral Pact counts Umbral relics")
	check(Missions.done(_find_mission("pathfinder"), null, {"total_rifts": 40}), "Pathfinder reads the save")
	# A bot run that refuses every Umbral offer replays exactly.
	var r := Sim.new(1, {"hull": 5, "power": 3})
	var declines := 0
	while r.tick < 330 * Sim.TPS and (r.state == Sim.RUNNING or r.state == Sim.CHOOSING):
		if r.state == Sim.CHOOSING:
			if r.umbral_choice:
				r.decline()
				declines += 1
			else:
				r.choose(Autopilot.pick(r))
			continue
		var mv := Autopilot.move(r)
		r.step(mv.x, mv.y, Autopilot.burst(r))
	check(r.rifts_done >= 2, "the bot completes rifts (%d)" % r.rifts_done)
	var rp := Sim.from_replay(r.to_replay())
	check(rp.checksum() == r.checksum() and rp.rifts_done == r.rifts_done, "rifts and refusals replay (%d refused)"
			% declines)


func _test_umbrals() -> void:
	var base := _quiet(221)
	var s := _quiet(221)
	s._take_relic("u_sun")
	check(absf(s.max_hp - base.max_hp * 0.7) < 1e-9 and absf(s.st_might - base.st_might - 0.5) < 1e-9,
			"Shattered Sun: +50% damage, less hull")
	s._take_relic("u_hunger")
	check(absf(s.st_xp - base.st_xp - 0.4) < 1e-9, "Hunger: more experience")
	var e0 := base._spawn(Defs.DRIFTER, 300.0, 0.0, false, 0)
	var e1 := s._spawn(Defs.DRIFTER, 300.0, 0.0, false, 0)
	check(absf(s.e_maxhp[e1] / base.e_maxhp[e0] - 1.25) < 1e-6, "Hunger: a tougher swarm")
	var fr := _quiet(222)
	fr._take_relic("u_frenzy")
	check(absf(fr.st_haste - 0.75) < 1e-9, "Frenzy Engine: faster weapons")
	var hp0 := fr.hp
	fr._hurt(20.0)
	check(absf(hp0 - fr.hp - 27.0) < 1e-9, "Frenzy Engine: hits hurt more")
	var g := _quiet(223)
	g._take_relic("u_gambit")
	check(absf(g.st_crit - 0.25) < 1e-9, "Gambler's Prism: more crits")
	var ge := g._spawn(Defs.BRUTE, g.px + 800.0, g.py, false, 0)
	g.st_crit = 0.0
	g._damage(ge, 10.0, 0.0, 0.0)
	check(absf(g.e_maxhp[ge] - g.e_hp[ge] - 7.0) < 1e-9, "Gambler's Prism: plain hits are weaker")
	g.st_crit = 1.0
	var h0 := g.e_hp[ge]
	g._damage(ge, 10.0, 0.0, 0.0)
	check(absf(h0 - g.e_hp[ge] - 30.0) < 1e-9, "Gambler's Prism: crits hit x3")
	var c := _quiet(224)
	c._take_relic("u_crown")
	check(absf(Defs.chain_mult(50, true) - 1.4) < 1e-9 and Defs.chain_mult(100000, true) == Defs.CROWN_MAX_MULT,
			"Chain Crown climbs twice as fast to x6")
	check(c.chain_mult() == 1.0 and c.chain_cap() == Defs.CROWN_MAX_MULT, "Chain Crown on the sim")
	c.chain = 30
	var c0 := c.hp
	c._hurt(10.0)
	check(absf(c0 - c.hp - 25.0) < 1e-9 and c.chain == 0, "Chain Crown: breaking a long Chain costs more")
	check(c.umbrals_left() == Defs.UMBRAL_ORDER.size() - 1, "Umbral relics left")
	# Umbral relics never crowd out the light ones.
	var l := _quiet(225)
	for id in Defs.UMBRAL_ORDER:
		l._take_relic(id)
	_give_chest(l, "bigchest")
	l.step(0, 0)
	check(l.relic_choice and not l.umbral_choice and l.light_relics() == 0, "boss caches still offer relics")


func _glaives(s: Sim) -> int:
	var n := 0
	for i in s.bn:
		if s.b_kind[i] >= 4:
			n += 1
	return n


func _test_glaive() -> void:
	# A glaive ricochets down a line of enemies, then flies home.
	var s := _quiet(301)
	s.weapons = [{"id": "glaive", "lvl": 2, "t": 1, "k": 0, "a": 0}]
	var line: Array = []
	for k in 4:
		var e := s._spawn(Defs.BRUTE, s.px + 220.0 + 150.0 * k, s.py, false, 0)
		s.e_speed[e] = 0.0
		line.append(e)
	s.step(0, 0)
	check(_glaives(s) == 1 and _has_event(s, Sim.EV_SHOT), "a glaive is thrown")
	var bounced := 0
	var home := false
	for t in 120:
		s.step(0, 0)
		for e in s.events:
			if int(e[0]) == Sim.EV_RICOCHET:
				bounced += 1
		for i in s.bn:
			if s.b_kind[i] == 5:
				home = true
	var hurt := 0
	for e in line:
		if s.e_hp[e] < s.e_maxhp[e]:
			hurt += 1
	check(hurt == 4 and bounced >= 4, "it ricochets through the line (%d hit, %d ricochets)" % [hurt, bounced])
	check(home, "out of ricochets, it flies home")
	check(s.ricochet_best >= 4, "ricochets are counted (%d)" % s.ricochet_best)
	for t in 120:
		s.step(0, 0)
	check(_glaives(s) <= 1, "a glaive is thrown again only once it is back in hand")
	# Only as many glaives in flight as the level allows.
	var m := _quiet(302)
	m.weapons = [{"id": "glaive", "lvl": 4, "t": 1, "k": 0, "a": 0}]
	for k in 12:
		var a := k * Trig.STEPS / 12
		var e2 := m._spawn(Defs.BRUTE, m.px + Trig.cos_i(a) * 400.0, m.py + Trig.sin_i(a) * 400.0, false, 0)
		m.e_speed[e2] = 0.0
	var most := 0
	for t in 240:
		m.weapons[0].t = mini(m.weapons[0].t, 2)
		m.step(0, 0)
		most = maxi(most, _glaives(m))
	check(most == 2, "a Lv4 glaive keeps two in flight (%d)" % most)
	# Ouroboros: damage grows with each ricochet, and a caught glaive leaps back out.
	var o := _quiet(303)
	o.weapons = [{"id": "glaive", "lvl": Defs.EVO_LEVEL, "t": 1, "k": 0, "a": 0}]
	var spec := o.glaive_spec()
	for k in 16:
		var a2 := k * Trig.STEPS / 16
		var e3 := o._spawn(Defs.BRUTE, o.px + Trig.cos_i(a2) * 300.0, o.py + Trig.sin_i(a2) * 300.0, false, 0)
		o.e_speed[e3] = 0.0
		o.e_hp[e3] = 1e6
		o.e_maxhp[e3] = 1e6
	var grew := 0.0
	var rethrown := false
	for t in 600:
		o.step(0, 0)
		for i in o.bn:
			if o.b_kind[i] == 4:
				grew = maxf(grew, o.b_dmg[i] / float(spec.dmg))
		for e in o.events:
			if int(e[0]) == Sim.EV_SHOT and e[1] == "glaive_evo":
				rethrown = true
	check(grew > 1.5 and grew <= 3.0001, "Ouroboros grows with every ricochet, up to x3 (x%.2f)" % grew)
	check(rethrown, "a caught Ouroboros glaive leaps straight back out")
	check(o.ricochet_best > int(spec.bounce), "Ouroboros keeps counting ricochets across throws (%d)" % o.ricochet_best)
	check(Missions.progress(_find_mission("ricochet"), o, {}) == mini(40, o.ricochet_best), "the Ricochet mission")


func _test_echo() -> void:
	var s := _quiet(311)
	s.ship_id = "echo"
	s.loadout.ship = "echo"
	var e := s._spawn(Defs.DRIFTER, s.px + 600.0, s.py, false, 0)
	s.e_hp[e] = 0.0
	s.step(0, 0)
	check(s.chain == 1 and s.chain_t > Defs.CHAIN_TICKS, "Echo's Chain fades twice as slowly")
	var b := s._spawn(Defs.BRUTE, s.px + 600.0, s.py, false, 0)
	s.st_crit = 0.0
	var h0 := s.e_hp[b]
	s._damage(b, 10.0, 0.0, 0.0)
	var plain := h0 - s.e_hp[b]
	s.chain = 250
	h0 = s.e_hp[b]
	s._damage(b, 10.0, 0.0, 0.0)
	check(is_equal_approx(h0 - s.e_hp[b], plain * 1.4), "Resonance: a 250 Chain adds +40% damage")
	s.chain = 999
	h0 = s.e_hp[b]
	s._damage(b, 10.0, 0.0, 0.0)
	check(is_equal_approx(h0 - s.e_hp[b], plain * 1.4), "Resonance stops at +40%")
	# Encore: the Chain holds through hits, and kills throw glaives.
	var o := Sim.new(312, {"ship": "echo"})
	o.spawn_acc = -1e9
	o.sched_i = Sim.SCHEDULE.size()
	o.rift_next = 1 << 30
	_surround(o, Defs.DRIFTER, 24)
	o.chain = 60
	o.chain_t = 1000
	o.od = o.od_need
	o.step(0, 0, true)
	check(o.od_t > 0 and _glaives(o) >= 10, "Encore opens with a ring of glaives")
	o.iframes = 0
	o._hurt(5.0)
	check(o.chain >= 60, "Encore: a hit does not break the Chain")
	var thrown := false
	for t in 120:
		o.step(0, 0)
		if o.state == Sim.CHOOSING:
			o.choose(0)
		for i in o.bn:
			if o.b_kind[i] == 6 and o.b_pierce[i] == 2:
				thrown = true
	check(thrown, "Encore: kills throw glaives")
	check(Defs.ship_mission("echo").get("id", "") == "unbroken", "Unbroken unlocks Echo")


func _test_starfall() -> void:
	# Never before 1:30.
	var early := _quiet(321)
	var seen := false
	for k in 40:
		early.rift_last = Defs.RIFT_BEACON
		early._open_rift()
		if int(early.rift.kind) == Defs.RIFT_STARFALL:
			seen = true
		early.rift = {}
	check(not seen, "no Starfall before 1:30")
	# Step in and the storm begins; meteors crush the swarm.
	var s := _quiet(322)
	s.tick = 200 * Sim.TPS
	_rift_at(s, Defs.RIFT_STARFALL, s.px + 50.0, s.py)
	var brute := s._spawn(Defs.BRUTE, s.px + 200.0, s.py, false, 0)
	s.e_speed[brute] = 0.0
	s.step(0, 0)
	check(s.rift.on and _has_event(s, Sim.EV_RIFT), "stepping into the ring calls the Starfall")
	var marks := 0
	var impacts := 0
	var won := false
	for t in Defs.STARFALL_TICKS + Defs.METEOR_FALL + 10:
		s.iframes = 2
		s.step(0, 0)
		for e in s.events:
			if int(e[0]) == Sim.EV_METEOR:
				if int(e[4]) == 0:
					marks += 1
				else:
					impacts += 1
			if int(e[0]) == Sim.EV_RIFT and int(e[4]) == 2:
				won = true
	check(marks > 30 and impacts == marks, "meteors are marked, then land (%d/%d)" % [impacts, marks])
	check(won and s.starfalls == 1 and s.rifts_done == 1, "an unstruck Starfall is weathered")
	var core := false
	for p in s.pickups:
		if p.k == "core":
			core = true
	check(core or s.level > 1, "the last star falls as a Star Core")
	check(Missions.done(_find_mission("stargazer"), s, {}), "the Stargazer mission")
	# Stand still under it and a meteor finds you: the rift fails.
	var f := _quiet(323)
	f.tick = 200 * Sim.TPS
	_rift_at(f, Defs.RIFT_STARFALL, f.px, f.py)
	f.max_hp = 1e6
	f.hp = 1e6
	var failed := false
	for t in Defs.STARFALL_TICKS + Defs.METEOR_FALL:
		f.step(0, 0)
		for e in f.events:
			if int(e[0]) == Sim.EV_RIFT and int(e[4]) == 4:
				failed = true
		if failed:
			break
	check(failed and f.hp < 1e6 and f.starfalls == 0, "a meteor strike ends the Starfall")
	# Outside the ring the storm pauses.
	var p := _quiet(324)
	_rift_at(p, Defs.RIFT_STARFALL, p.px, p.py)
	p.step(0, 0)
	p.px += Defs.STARFALL_R + 200.0
	for t in 120:
		p.iframes = 2
		p.step(0, 0)
	check(float(p.rift.prog) < 2.0 and (p.rift.mets as Array).is_empty(), "outside the ring the storm pauses")


func _test_leviathan() -> void:
	var at := -1
	for ev in Sim.SCHEDULE:
		if ev[1] == "boss" and ev[2] == Defs.LEVIATHAN:
			at = ev[0]
	check(at == 120, "the Leviathan arrives at 2:00")
	var s := _quiet(401)
	var i := s._spawn(Defs.LEVIATHAN, s.px + 700.0, s.py, false, 0)
	check(s.lv_n == Defs.LEVI_SEGS and s.lv_uid == s.e_uid[i], "the Leviathan uncoils a body")
	var coiled := false
	var marked := false
	var lunged := false
	var orbs := 0
	var spaced := true
	for k in 720:
		s.iframes = 999
		s.step(0, 0)
		for e in s.events:
			if int(e[0]) == Sim.EV_LEVI and int(e[3]) == 0:
				coiled = true
			if int(e[0]) == Sim.EV_TELEGRAPH:
				marked = true
			if int(e[0]) == Sim.EV_ORB:
				orbs += 1
		if s.e_state[i] == 4:
			lunged = true
		for j in range(1, s.lv_n):
			var dx := s.lv_x[j] - s.lv_x[j - 1]
			var dy := s.lv_y[j] - s.lv_y[j - 1]
			if absf(sqrt(dx * dx + dy * dy) - Defs.LEVI_GAP) > 0.5:
				spaced = false
	check(coiled and orbs > 10, "the Leviathan coils and its body fires inwards (%d orbs)" % orbs)
	check(marked and lunged, "the Leviathan marks its lunge, then lunges")
	check(spaced, "the body follows the head like a chain")
	# The body burns.
	s.qn = 0
	s.iframes = 0
	s.px = s.lv_x[10]
	s.py = s.lv_y[10]
	var hp0 := s.hp
	s.step(0, 0)
	check(s.hp < hp0, "touching the body hurts")
	# Wounded, it sheds its tail.
	s.e_hp[i] = s.e_maxhp[i] * 0.7
	s.iframes = 999
	s.step(0, 0)
	check(s.lv_n == Defs.LEVI_SEGS - Defs.LEVI_SHED and _has_event(s, Sim.EV_LEVI), "it sheds its tail at 75 percent")
	s.e_hp[i] = s.e_maxhp[i] * 0.2
	s.step(0, 0)
	check(s.lv_n == Defs.LEVI_SEGS - 3 * Defs.LEVI_SHED, "and again at half and a quarter (%d)" % s.lv_n)
	s.e_hp[i] = 0.0
	s.step(0, 0)
	var relic := false
	var core := false
	for p in s.pickups:
		if p.k == "chest" and p.get("relic", false):
			relic = true
		if p.k == "core":
			core = true
	check(s.levi_down and s.bosses_killed == 1 and relic and core, "the Leviathan falls and guards the first relic")
	for k in 3 * Defs.LEVI_SEGS + 6:
		s.iframes = 999
		s.step(0, 0)
	check(s.lv_n == 0 and s.lv_pop == 0, "its body bursts after it falls")
	check(Missions.done(_find_mission("serpentfall"), s, {}), "Serpentfall mission")
	check(not Missions.done(_find_mission("charmer"), s, {}), "Snake Charmer needs a clean fight")
	# Untouched, it charms.
	var c := _quiet(402)
	var ci := c._spawn(Defs.LEVIATHAN, c.px + 900.0, c.py, false, 0)
	c.step(0, 0)
	c.e_hp[ci] = 0.0
	c.step(0, 0)
	check(Missions.done(_find_mission("charmer"), c, {}), "Snake Charmer mission")
	# Left alive too long, it escapes with its prize; the first elite then guards the relic.
	var e := _quiet(403)
	var ei := e._spawn(Defs.LEVIATHAN, e.px + 900.0, e.py, false, 0)
	e.step(0, 0)
	e.e_t[ei] = e.levi_escape_ticks()
	e.step(0, 0)
	var escaped := false
	for ev in e.events:
		if int(ev[0]) == Sim.EV_LEVI and int(ev[3]) == 4:
			escaped = true
	check(escaped and e.boss_index() < 0 and e.bosses_killed == 0 and e.pickups.is_empty() and e.lv_n == 0,
			"a Leviathan left too long escapes")
	var el := e._spawn(Defs.BRUTE, e.px + 800.0, e.py, true, 0)
	e.e_hp[el] = 0.0
	e.step(0, 0)
	check(e.pickups.size() == 1 and e.pickups[0].get("relic", false), "then the first elite guards the relic")
	# Light trails grow with mastery.
	check(Defs.trail_tier(-1) == 0 and Defs.trail_tier(0) == 1 and Defs.trail_tier(2) == 1, "first trails")
	check(Defs.trail_tier(3) == 2 and Defs.trail_tier(9) == 3 and Defs.trail_tier(10) == 4, "mastery trails")


## Steps a Gauntlet run with no swarm until its next boss is up, then fells it.
func _fell_next(s: Sim) -> int:
	while s.boss_index() < 0 and s.tick < 1 << 20:
		if s.state == Sim.CHOOSING:
			s.choose(0)
			continue
		s.iframes = 999
		s.spawn_acc = -1e9
		s.step(0, 0)
	var b := s.boss_index()
	var type := s.e_type[b]
	for k in 90:
		s.iframes = 999
		s.step(0, 0)
	s.e_hp[s.boss_index()] = 0.0
	s.step(0, 0)
	return type


func _test_gauntlet() -> void:
	var s := Sim.new(501, {"gauntlet": true, "radiance": 5, "mods": ["horde"]})
	check(s.gauntlet and s.radiance == 0 and s.mods.is_empty(), "the Gauntlet ignores Radiance and mutators")
	check(s.level == 1 + Defs.GAUNTLET_DRAFT and s.pending_levels == Defs.GAUNTLET_DRAFT, "it opens with a draft")
	s.step(0, 0)
	check(s.state == Sim.CHOOSING, "the draft cards come up at once")
	for k in Defs.GAUNTLET_DRAFT:
		s.choose(0)
	check(s.state == Sim.RUNNING and s.pending_levels == 0, "after the draft the run starts")
	var normal := Sim.new(501)
	check(is_equal_approx(normal.minutes(), 0.0) and is_equal_approx(s.minutes(), Defs.GAUNTLET_PACE + 1.0 / 3600.0 * Defs.GAUNTLET_CREEP),
			"the Gauntlet runs on its own pace clock")
	var order: Array = []
	for k in Defs.GAUNTLET.size():
		order.append(_fell_next(s))
	check(order == Defs.GAUNTLET, "the bosses come in order: %s" % str(order))
	check(s.g_clear_tick > 0 and s.g_splits.size() == 4 and s.bosses_killed == 4, "four bosses felled clear it")
	check(int(s.g_splits[0]) == 91, "a split counts the ticks from arrival to the fall (%d)" % int(s.g_splits[0]))
	check(not s.dawn and s.state == Sim.RUNNING, "the Eclipse does not end a Gauntlet")
	check(s.g_bonus >= Defs.GAUNTLET_CLEAR_SCORE + 4 * (Defs.GAUNTLET_PAR - 2) * Defs.GAUNTLET_SPEED_PTS,
			"fast splits and the clear pay score (%d)" % s.g_bonus)
	check(s.minutes() >= Defs.GAUNTLET_PACE + 4.0 * Defs.GAUNTLET_STEP, "the pace jumps with every boss")
	var bigs := 0
	for p in s.pickups:
		if p.k == "bigchest":
			bigs += 1
	check(bigs >= 3, "the Warden, Seraph and Eclipse leave boss caches (%d)" % bigs)
	check(s.rift.is_empty() and s.elite_kills == 0, "no rifts or elites in the Gauntlet")
	# Cycle II: stronger.
	_fell_next(s)
	check(s.boss_mult > Defs.GAUNTLET_HP[0] * 1.5, "the second cycle is stronger (%.2f)" % s.boss_mult)
	check(s.g_splits.size() == 5, "the second cycle keeps splitting")
	# Missions.
	var data := {"gauntlet": {"clears": 0, "best_clear": 0, "best_felled": 0}}
	check(Missions.done(_find_mission("gauntlet"), s, data), "Gauntlet Runner mission")
	check(Missions.done(_find_mission("lightspeed"), s, data) == (s.g_clear_tick < Defs.GAUNTLET_FAST * Sim.TPS),
			"Lightspeed mission follows the clear time")
	check(not Missions.done(_find_mission("eternal"), s, data), "Eternal Return needs 8 bosses")
	check(Missions.done(_find_mission("eternal"), null, {"gauntlet": {"best_felled": 8}}), "Eternal Return from the save")
	check(not Missions.done(_find_mission("gauntlet"), Sim.new(1), {}), "a normal run never clears the Gauntlet")
	# Escapes count as passed, without a split.
	var e := Sim.new(502, {"gauntlet": true})
	e.step(0, 0)
	for k in Defs.GAUNTLET_DRAFT:
		e.choose(0)
	while e.boss_index() < 0:
		e.iframes = 999
		e.spawn_acc = -1e9
		e.step(0, 0)
	e.e_spawn[e.boss_index()] = 0
	e.e_t[e.boss_index()] = e.levi_escape_ticks()
	e.step(0, 0)
	check(e.g_stage == 1 and e.g_splits == [-1] and e.bosses_killed == 0 and e.g_next > e.tick,
			"an escaped Leviathan passes the stage with no split")
	# Replays.
	var r := Sim.new(503, {"gauntlet": true, "hull": 2})
	Autopilot.play(r, 150 * Sim.TPS)
	var rr := Sim.from_replay(r.to_replay())
	check(rr.tick == r.tick and rr.checksum() == r.checksum() and rr.g_splits == r.g_splits,
			"a Gauntlet replays bit for bit (%d bosses passed)" % r.g_stage)


## Steps a run with the swarm held off, so a test can watch one mechanic.
func _quiet_step(s: Sim, n: int) -> void:
	for k in n:
		s.spawn_acc = -1e9
		s.en = 0
		s.step(0, 0)


func _test_sectors() -> void:
	check(Sim.new(1, {"sector": 99}).sector == Defs.SECTORS.size() - 1, "the sector is clamped")
	check(Sim.new(1, {"sector": 2, "gauntlet": true}).sector == 0, "the Gauntlet is always on the Neon Grid")
	var a := Sim.new(71, {})
	var b := Sim.new(71, {"sector": 0})
	Autopilot.play(a, 100 * Sim.TPS)
	Autopilot.play(b, 100 * Sim.TPS)
	check(a.checksum() == b.checksum() and a.maws.is_empty() and a.flare.is_empty(),
			"the Neon Grid plays exactly as before")
	check(is_equal_approx(Sim.new(1, {"sector": 1}).score_mult(), 1.2) and
			is_equal_approx(Sim.new(1, {"sector": 2}).score_mult(), 1.35), "sectors raise the score multiplier")
	# The Abyss: a black hole opens on time.
	var s := Sim.new(73, {"sector": Defs.SECTOR_ABYSS})
	while s.maws.is_empty() and s.tick < 60 * Sim.TPS:
		s.iframes = 999
		_quiet_step(s, 1)
	check(s.tick == Defs.MAW_FIRST * Sim.TPS, "the first black hole opens at %ds (%d)" % [Defs.MAW_FIRST, s.tick])
	_quiet_step(s, Defs.MAW_FORM + 1)
	var m: Dictionary = s.maws[0]
	# It crushes the swarm at its core and keeps the light.
	s._spawn(Defs.DRIFTER, float(m.x) + 20.0, float(m.y), false, 0)
	var gems := s.gn
	s.iframes = 999
	s.spawn_acc = -1e9
	s.step(0, 0)
	check(s.maws_eaten == 1 and int(m.eaten) == 1 and float(m.fed) >= 1.0 and s.gn == gems,
			"a drifter at the core is crushed and fed to the hole (eaten %d, gems %d -> %d)" % [s.maws_eaten, gems, s.gn])
	check(s.kills == 1, "a crushed enemy counts as your kill")
	# Elites are too big to swallow.
	var e := s._spawn(Defs.BRUTE, float(m.x), float(m.y), true, 0)
	var ehp := s.e_hp[e]
	s.spawn_acc = -1e9
	s.step(0, 0)
	check(s.en == 1 and s.e_hp[0] > 0.0 and s.e_hp[0] <= ehp, "an elite is ground, not swallowed")
	# It drags you in, and its core burns.
	s.en = 0
	s.px = float(m.x) + 300.0
	s.py = float(m.y)
	m.vx = 0.0
	m.vy = 0.0
	var d0 := absf(s.px - float(m.x))
	s.spawn_acc = -1e9
	s.step(0, 0)
	check(absf(s.px - float(m.x)) < d0 - 0.5, "a black hole drags you in")
	s.iframes = 0
	s.px = float(m.x)
	s.py = float(m.y)
	var hp0 := s.hp
	s.spawn_acc = -1e9
	s.step(0, 0)
	check(s.hp < hp0, "its core burns you")
	# Gems drift in and are eaten too.
	s._drop_gem(float(m.x) + 10.0, float(m.y), 5.0)
	var fed0 := float(m.fed)
	s.iframes = 999
	_quiet_step(s, 2)
	check(float(m.fed) >= fed0 + 5.0, "loose gems are eaten")
	# It collapses and gives the light back.
	m.t = int(m.life) - 1
	gems = s.gn
	var burst := false
	s.spawn_acc = -1e9
	s.en = 0
	s.step(0, 0)
	for ev in s.events:
		if ev[0] == Sim.EV_MAW and ev[3] == 2:
			burst = true
	check(burst and s.maws.is_empty() and s.gn >= gems + 3, "a collapse bursts its light back out (%d gems)" % (s.gn - gems))
	check(s.maw_best == 1, "the best black hole is remembered")
	# Corona: you start below the sun, which is solid and burns.
	var c := Sim.new(74, {"sector": Defs.SECTOR_CORONA})
	check(is_equal_approx(c.py, Defs.SUN_START), "Corona starts you below the sun")
	c.px = 0.0
	c.py = Defs.SUN_R * 0.5
	var chp := c.hp
	_quiet_step(c, 1)
	check(sqrt(c.px * c.px + c.py * c.py) >= Defs.SUN_R + Sim.PLAYER_R - 0.01 and c.hp < chp,
			"the sun pushes you out and burns you")
	c.iframes = 999
	while c.flare.is_empty() and c.tick < 60 * Sim.TPS:
		_quiet_step(c, 1)
	check(c.tick == Defs.FLARE_FIRST * Sim.TPS and (c.flare.gaps as Array).size() == 3,
			"the first flare comes at %ds with three gaps" % Defs.FLARE_FIRST)
	# In a gap: the front passes you by.
	var g: int = c.flare.gaps[0]
	c.px = Trig.cos_i(g) * 500.0
	c.py = Trig.sin_i(g) * 500.0
	c.iframes = 0
	chp = c.hp
	while not c.flare.is_empty():
		_quiet_step(c, 1)
	check(c.flares_passed == 1 and c.hp == chp, "a flare passes you by in a gap")
	# Out of a gap: it burns, and it burns the swarm too.
	c.flare_next = c.tick + 1
	_quiet_step(c, 2)
	var outside := -1
	for k in Trig.STEPS:
		if not c.flare_gap(k):
			outside = k
			break
	c.px = Trig.cos_i(outside) * 500.0
	c.py = Trig.sin_i(outside) * 500.0
	c.iframes = 0
	chp = c.hp
	var hit_flare := false
	var dr := c._spawn(Defs.BRUTE, Trig.cos_i(outside) * 700.0, Trig.sin_i(outside) * 700.0, false, 0)
	var dhp := c.e_hp[dr]
	while not c.flare.is_empty():
		c.spawn_acc = -1e9
		c.step(0, 0)
		for ev in c.events:
			if ev[0] == Sim.EV_FLARE and ev[1] == 2:
				hit_flare = true
	check(hit_flare and c.hp < chp and c.flares_passed == 1, "a flare burns you outside the gaps")
	check(c.en == 0 or c.e_hp[0] < dhp, "the front burns the swarm it sweeps over")
	# Missions.
	var ms := Sim.new(1, {"sector": 1})
	ms.maw_best = Defs.MAW_SATED
	check(Missions.done(_find_mission("sated"), ms, {}), "Sated mission")
	ms.flares_passed = 15
	check(Missions.done(_find_mission("sunrunner"), ms, {}), "Sunrunner mission")
	var carto := {"sector_best": {"grid": {"dawn": true}, "abyss": {"dawn": true}}}
	check(not Missions.done(_find_mission("cartographer"), null, carto), "Cartographer needs all three dawns")
	var cw := Sim.new(1, {"sector": 2})
	cw.dawn = true
	check(Missions.done(_find_mission("cartographer"), cw, carto), "Cartographer counts this run's dawn")
	# Replays.
	for k in [1, 2]:
		var r := Sim.new(80 + k, {"sector": k, "hull": 2})
		Autopilot.play(r, 160 * Sim.TPS)
		var rr := Sim.from_replay(r.to_replay())
		check(rr.tick == r.tick and rr.checksum() == r.checksum() and rr.maws_eaten == r.maws_eaten and
				rr.flares_passed == r.flares_passed, "%s replays bit for bit (eaten %d, flares %d)" % [
				Defs.sector(k).name, r.maws_eaten, r.flares_passed])


func _test_runs() -> void:
	var t0 := Time.get_ticks_msec()
	var total_ticks := 0
	for seed_v in [1, 2, 3]:
		var s := Sim.new(seed_v, {"hull": 2, "power": 1})
		Autopilot.play(s, 9 * 60 * Sim.TPS)
		if s.state == Sim.WON:
			# Fly on into the Afterdark so the replay covers it too.
			s.continue_night()
			Autopilot.play(s, s.tick + 100 * Sim.TPS)
			check(s.endless and s.dawn, "Afterdark continues a won run (seed %d)" % seed_v)
		total_ticks += s.tick
		print("seed %d: state=%d t=%.0fs lvl=%d kills=%d en=%d flux=%d hp=%.0f weapons=%s" % [
			seed_v, s.state, s.seconds(), s.level, s.kills, s.en, s.flux_earned(), s.hp,
			str(s.weapons.map(func(w): return "%s%d" % [w.id, w.lvl]))])
		check(s.tick > 60 * 60, "bot survives the first minute (seed %d)" % seed_v)
		var r := Sim.from_replay(s.to_replay())
		check(r.tick == s.tick, "replay reaches the same tick (seed %d)" % seed_v)
		check(r.checksum() == s.checksum(), "replay matches checksum (seed %d)" % seed_v)
		check(r.kills == s.kills and r.level == s.level, "replay matches stats (seed %d)" % seed_v)
		check(not s.relics.is_empty() and r.relics == s.relics, "relic picks replay (seed %d: %s)" % [seed_v, s.relics])
	var ms := Time.get_ticks_msec() - t0
	print("sim speed: %.3f ms/tick" % (float(ms) / float(maxi(total_ticks, 1)) / 2.0))

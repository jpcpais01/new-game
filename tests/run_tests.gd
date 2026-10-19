extends SceneTree
## Deterministic logic checks. Run: godot --headless --path . -s tests/run_tests.gd
## Must not reference autoloads (Save, Sfx).

var _checks := 0
var _fails := 0


func _init() -> void:
	_test_rng()
	_test_trig()
	_test_cards()
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

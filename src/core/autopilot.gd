class_name Autopilot
extends RefCounted
## A simple kiting pilot used by the title demo and the tests: flees nearby threats, drifts towards
## gems when safe, stays off the arena wall, and picks cards by preference.

const PREF := ["pulse", "orbit", "nova", "arc", "seeker", "lance", "amplifier", "vitality", "overclock",
		"magnet", "thrusters", "plating", "lens", "renewal", "fortune", "scholar", "heal", "flux"]


static func move(s: Sim) -> Vector2i:
	var fx := 0.0
	var fy := 0.0
	for i in s.en:
		if s.e_spawn[i] > 0:
			continue
		var dx := s.px - s.e_x[i]
		var dy := s.py - s.e_y[i]
		var d2 := dx * dx + dy * dy
		var reach := 260.0 + s.e_r[i] * 2.0
		if d2 < reach * reach:
			var d := sqrt(d2) + 1.0
			var w := (reach - d) / reach
			fx += dx / d * w * w * 3.0
			fy += dy / d * w * w * 3.0
	for i in s.qn:
		var dx := s.px - s.q_x[i]
		var dy := s.py - s.q_y[i]
		var d2 := dx * dx + dy * dy
		if d2 < 160.0 * 160.0:
			var d := sqrt(d2) + 1.0
			fx += dx / d * 1.5
			fy += dy / d * 1.5
	var threat := sqrt(fx * fx + fy * fy)
	var chased := false
	if threat < 0.9:
		for p in s.pickups:
			if p.k != "chest" and p.k != "bigchest":
				continue
			var dx: float = p.x - s.px
			var dy: float = p.y - s.py
			var d := sqrt(dx * dx + dy * dy) + 1.0
			if d < 1100.0:
				fx += dx / d * 0.8
				fy += dy / d * 0.8
				chased = true
				break
	if threat < 0.4 and not chased:
		var best := -1
		var bd := 500.0 * 500.0
		for i in s.gn:
			var dx := s.g_x[i] - s.px
			var dy := s.g_y[i] - s.py
			var d2 := dx * dx + dy * dy
			if d2 < bd:
				bd = d2
				best = i
		if best >= 0:
			var dx := s.g_x[best] - s.px
			var dy := s.g_y[best] - s.py
			var d := sqrt(dx * dx + dy * dy) + 1.0
			fx += dx / d * 0.6
			fy += dy / d * 0.6
	var r := sqrt(s.px * s.px + s.py * s.py)
	if r > 900.0:
		var k := (r - 900.0) / 600.0 * 2.5
		fx -= s.px / r * k
		fy -= s.py / r * k
	var l := sqrt(fx * fx + fy * fy)
	if l < 0.05:
		return Vector2i(0, 0)
	return Vector2i(int(fx / l * 100.0), int(fy / l * 100.0))


static func pick(s: Sim) -> int:
	var best := 0
	var bi := 999
	for k in s.choices.size():
		var p := PREF.find(s.choices[k])
		if p >= 0 and p < bi:
			bi = p
			best = k
	return best


static func play(s: Sim, max_ticks: int) -> void:
	while s.tick < max_ticks:
		if s.state == Sim.CHOOSING:
			s.choose(pick(s))
		elif s.state == Sim.RUNNING:
			var m := move(s)
			s.step(m.x, m.y)
		else:
			break

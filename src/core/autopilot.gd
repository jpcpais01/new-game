class_name Autopilot
extends RefCounted
## A simple kiting pilot used by the title demo and the tests: flees nearby threats, drifts towards
## gems when safe, stays off the arena wall, and picks cards by preference.

const PREF := ["pulse", "orbit", "nova", "arc", "seeker", "lance", "scythe", "mine", "amplifier", "vitality",
		"overclock", "magnet", "thrusters", "plating", "lens", "renewal", "fortune", "scholar", "halo", "phoenix",
		"wake", "starbreaker", "wrath", "supercrit", "overcharge", "midas", "heal", "flux"]

## Cards the pilot takes before anything in PREF (balance probes set this).
static var favor: Array = []


static func move(s: Sim) -> Vector2i:
	var fx := 0.0
	var fy := 0.0
	# Blade pilots let enemies come close enough to be cut.
	var hunt := s.weapon_level("orbit") > 0 and s.weapons.size() <= 2
	for i in s.en:
		if s.e_spawn[i] > 0:
			continue
		var dx := s.px - s.e_x[i]
		var dy := s.py - s.e_y[i]
		var d2 := dx * dx + dy * dy
		var reach := (110.0 + s.e_r[i] * 1.5) if hunt else (260.0 + s.e_r[i] * 2.0)
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
	# Step out of laser lines, warning lines included.
	for l in s.lasers():
		var ux := Trig.cos_i(l[2])
		var uy := Trig.sin_i(l[2])
		var rx: float = s.px - l[0]
		var ry: float = s.py - l[1]
		var along := rx * ux + ry * uy
		if along < -40.0 or along > float(l[3]) + 40.0:
			continue
		var side := rx * uy - ry * ux
		var gap: float = float(l[4]) + 90.0
		if absf(side) < gap:
			var sgn := 1.0 if side >= 0.0 else -1.0
			var w := (gap - absf(side)) / gap * (6.0 if l[5] or float(l[7]) > 0.6 else 2.5)
			fx += uy * sgn * w
			fy += -ux * sgn * w
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
		elif hunt:
			var t := s._nearest(s.px, s.py, 700.0)
			if t >= 0:
				var dx := s.e_x[t] - s.px
				var dy := s.e_y[t] - s.py
				var d := sqrt(dx * dx + dy * dy) + 1.0
				fx += dx / d * 0.5
				fy += dy / d * 0.5
	var r := sqrt(s.px * s.px + s.py * s.py)
	if r > 900.0:
		var k := (r - 900.0) / 600.0 * 2.5
		fx -= s.px / r * k
		fy -= s.py / r * k
	var l := sqrt(fx * fx + fy * fy)
	if l < 0.05:
		return Vector2i(0, 0)
	return Vector2i(int(fx / l * 100.0), int(fy / l * 100.0))


## Fires the Overdrive when it is charged and the moment is right: a crowd
## close by, a boss in range, or low health.
static func burst(s: Sim) -> bool:
	if not s.od_ready():
		return false
	if s.hp < s.max_hp * 0.4:
		return true
	var b := s.boss_index()
	if b >= 0 and s.e_spawn[b] <= 0:
		var bx := s.e_x[b] - s.px
		var by := s.e_y[b] - s.py
		if bx * bx + by * by < 600.0 * 600.0:
			return true
	var near := 0
	for i in s.en:
		var dx := s.e_x[i] - s.px
		var dy := s.e_y[i] - s.py
		if dx * dx + dy * dy < 420.0 * 420.0:
			near += 1
	return near >= 24


static func pick(s: Sim) -> int:
	var best := 0
	var bi := 999
	for k in s.choices.size():
		var p := favor.find(s.choices[k])
		p = p if p >= 0 else (PREF.find(s.choices[k]) + favor.size() if PREF.has(s.choices[k]) else -1)
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
			s.step(m.x, m.y, burst(s))
		else:
			break

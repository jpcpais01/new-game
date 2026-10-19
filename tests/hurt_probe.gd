extends SceneTree
## Balance probe (not run in CI): what hurts the bot, by source.
## godot --headless --path . -s tests/hurt_probe.gd -- [seeds] [minutes]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 4
	var mins := float(args[1]) if args.size() > 1 else 9.0
	var total := {}
	for sd in seeds:
		var s := Sim.new(100 + sd, {})
		var src := {}
		while s.tick < int(mins * 60.0) * Sim.TPS and (s.state == Sim.RUNNING or s.state == Sim.CHOOSING):
			if s.state == Sim.CHOOSING:
				s.choose(Autopilot.pick(s))
				continue
			var m := Autopilot.move(s)
			s.step(m.x, m.y, Autopilot.burst(s))
			for e in s.events:
				if e[0] != Sim.EV_HURT:
					continue
				var why := _source(s)
				src[why] = float(src.get(why, 0.0)) + float(e[1])
				total[why] = float(total.get(why, 0.0)) + float(e[1])
		print("seed %d: state %d at %ds  %s" % [100 + sd, s.state, int(s.seconds()), str(src)])
	print("total: ", total)
	quit()


func _source(s: Sim) -> String:
	for l in s.lasers():
		if l[5] and s._beam_hit(l[0], l[1], l[2], l[3], l[4]):
			return "laser_" + String(Defs.ENEMY[l[6]].name)
	var best := "orb/blast"
	var bd := 1e9
	for i in s.en:
		var dx := s.e_x[i] - s.px
		var dy := s.e_y[i] - s.py
		var d := sqrt(dx * dx + dy * dy) - s.e_r[i]
		if d < bd:
			bd = d
			best = String(Defs.ENEMY[s.e_type[i]].name)
	if bd > 60.0:
		return "orb/blast"
	return best

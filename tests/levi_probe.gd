extends SceneTree
## Balance probe (not run in CI): how the bot fares against the Leviathan.
## godot --headless --path . -s tests/levi_probe.gd -- [seeds] [loadout-json]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 10
	var loadout: Dictionary = JSON.parse_string(args[1]) if args.size() > 1 else {}
	var down := 0
	for sd in seeds:
		var s := Sim.new(100 + sd, loadout)
		var t0 := -1
		var hp0 := 0.0
		var body := 0.0
		var other := 0.0
		var outcome := "alive"
		var by_state := {}
		while s.tick < 260 * Sim.TPS and (s.state == Sim.RUNNING or s.state == Sim.CHOOSING):
			if s.state == Sim.CHOOSING:
				var bk := Autopilot.banish_pick(s)
				if bk >= 0:
					s.banish(bk)
				else:
					s.choose(Autopilot.pick(s))
				continue
			var m := Autopilot.move(s)
			s._levi_hit = false
			s.step(m.x, m.y, Autopilot.burst(s))
			for e in s.events:
				if e[0] == Sim.EV_BOSS and e[1] == Defs.LEVIATHAN:
					t0 = s.tick
					hp0 = s.hp
				elif e[0] == Sim.EV_HURT and t0 >= 0 and outcome == "alive":
					if s._levi_hit:
						body += e[1]
						var hb := s._levi_head()
						var key := "st%d" % (s.e_state[hb] if hb >= 0 else -1)
						by_state[key] = float(by_state.get(key, 0.0)) + float(e[1])
					else:
						other += e[1]
				elif e[0] == Sim.EV_BOSS_DOWN and e[1] == Defs.LEVIATHAN:
					outcome = "down in %ds" % ((s.tick - t0) / Sim.TPS)
					down += 1
				elif e[0] == Sim.EV_LEVI and e[3] == 4:
					outcome = "escaped"
			if s.state == Sim.DEAD and outcome == "alive":
				outcome = "DIED at %ds" % int(s.seconds())
		print("seed %d: lvl %d hp %.0f/%.0f at arrival, %s, levi dmg %.0f %s, other %.0f, %s" % [100 + sd, s.level, hp0,
				s.max_hp, outcome, body, str(by_state), other, str(s.weapons.map(func(w): return "%s%d" % [w.id, w.lvl]))])
	print("down %d/%d" % [down, seeds])
	quit()

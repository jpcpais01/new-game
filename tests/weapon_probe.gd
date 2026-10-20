extends SceneTree
## Weapon balance probe (not run in CI): damage each weapon deals per second
## at every level against a steady crowd, with the ship standing still.
## godot --headless --path . -s tests/weapon_probe.gd -- [seconds] [weapon,ids]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var secs := 20 if args.is_empty() else int(args[0])
	var only: Array = Array(args[1].split(",")) if args.size() > 1 else Defs.WEAPON_ORDER
	for id in only:
		var line := "%-7s" % id
		for lvl in range(1, Defs.EVO_LEVEL + 1):
			var s := Sim.new(77)
			s.spawn_acc = -1e9
			s.elite_next = 1 << 30
			s.sched_i = Sim.SCHEDULE.size()
			s.weapons = [{"id": id, "lvl": lvl, "t": 10, "k": 0, "a": 0}]
			s.hp = 1e9
			s.max_hp = 1e9
			for t in secs * Sim.TPS:
				# Keep a ring of tough drifters walking in.
				if s.en < 60 and t % 6 == 0:
					var a := (t * 37) % Trig.STEPS
					var e := s._spawn(Defs.DRIFTER, s.px + Trig.cos_i(a) * 420.0, s.py + Trig.sin_i(a) * 420.0, false, 0)
					if e >= 0:
						s.e_hp[e] = 400.0
						s.e_maxhp[e] = 400.0
				s.pending_levels = 0
				s.step(0, 0)
			line += "  L%d %6.0f" % [lvl, s.damage_dealt / float(secs)]
		print(line)
	quit()

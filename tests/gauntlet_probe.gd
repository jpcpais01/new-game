extends SceneTree
## Gauntlet probe (not run in CI): how the bot fares in the boss rush.
## godot --headless --path . -s tests/gauntlet_probe.gd -- [seeds] [ship] [minutes] [first seed]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := 6 if args.size() < 1 else int(args[0])
	var ship := "lumen" if args.size() < 2 else String(args[1])
	var mins := 8 if args.size() < 3 else int(args[2])
	var base := 300 if args.size() < 4 else int(args[3])
	var clears := 0
	for sd in seeds:
		var s := Sim.new(base + sd, {"ship": ship, "gauntlet": true})
		var hurt := 0.0
		var line := ""
		while s.tick < mins * 60 * Sim.TPS and (s.state == Sim.RUNNING or s.state == Sim.CHOOSING):
			if s.state == Sim.CHOOSING:
				var bk := Autopilot.banish_pick(s)
				if bk >= 0:
					s.banish(bk)
				else:
					s.choose(Autopilot.pick(s))
				continue
			var m := Autopilot.move(s)
			s.step(m.x, m.y, Autopilot.burst(s))
			for e in s.events:
				if e[0] == Sim.EV_HURT:
					hurt += e[1]
				elif e[0] == Sim.EV_GAUNTLET and int(e[1]) == 1:
					line += "\n  %-10s %s at %3ds  lvl%2d hp%4.0f/%4.0f hurt%5.0f" % [Defs.gauntlet_name(int(e[2])),
						("%5.1fs" % (float(e[3]) / 60.0)) if bool(e[4]) else "ESCAPED", int(s.seconds()), s.level, s.hp, s.max_hp, hurt]
		if s.g_clear_tick >= 0:
			clears += 1
		print("seed %d %s -> state %d at %ds, passed %d, lvl %d, kills %d, score %d, flux %d, clear %s %s" % [base + sd,
			ship, s.state, int(s.seconds()), s.g_stage, s.level, s.kills, s.score(), s.flux_earned(),
			"%.0fs" % (float(s.g_clear_tick) / 60.0) if s.g_clear_tick >= 0 else "-",
			str(s.weapons.map(func(w): return "%s%d" % [w.id, w.lvl])) + str(s.relics)])
		print(line)
	print("clears %d / %d" % [clears, seeds])
	quit()

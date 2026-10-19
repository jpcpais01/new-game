extends SceneTree
## Balance probe (not run in CI): prints a per-30s timeline of bot runs.
## godot --headless --path . -s tests/tune.gd -- [seeds] [loadout-json]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := 3
	var loadout := {}
	if args.size() > 0:
		seeds = int(args[0])
	if args.size() > 1:
		loadout = JSON.parse_string(args[1])
	for sd in seeds:
		var s := Sim.new(100 + sd, loadout)
		var hurt := 0.0
		var max_en := 0
		var line := ""
		while s.tick < 10 * 60 * Sim.TPS and (s.state == Sim.RUNNING or s.state == Sim.CHOOSING):
			if s.state == Sim.CHOOSING:
				s.choose(Autopilot.pick(s))
				continue
			var m := Autopilot.move(s)
			s.step(m.x, m.y)
			for e in s.events:
				if e[0] == Sim.EV_HURT:
					hurt += e[1]
				elif e[0] == Sim.EV_BOSS_DOWN:
					line += " [boss%d down @%ds]" % [e[1], int(s.seconds())]
			max_en = maxi(max_en, s.en)
			if s.tick % (30 * Sim.TPS) == 0:
				var b := s.boss_index()
				line += "\n  %3ds lvl%2d en%3d hp%4.0f/%4.0f hurt%5.0f kills%5d%s" % [int(s.seconds()), s.level, s.en, s.hp, s.max_hp, hurt, s.kills,
					(" boss %.0f%%" % (100.0 * s.e_hp[b] / s.e_maxhp[b])) if b >= 0 else ""]
		print("seed %d -> state %d at %ds, lvl %d, kills %d, max_en %d, flux %d %s" % [100 + sd, s.state, int(s.seconds()), s.level, s.kills, max_en, s.flux_earned(),
			str(s.weapons.map(func(w): return "%s%d" % [w.id, w.lvl])) + str(s.passives)])
		print(line)
	quit()

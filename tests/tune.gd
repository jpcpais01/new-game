extends SceneTree
## Balance probe (not run in CI): prints a per-30s timeline of bot runs.
## godot --headless --path . -s tests/tune.gd -- [seeds] [loadout-json] [favoured,card,ids]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := 3
	var loadout := {}
	if args.size() > 0:
		seeds = int(args[0])
	if args.size() > 1:
		loadout = JSON.parse_string(args[1])
	if args.size() > 2:
		Autopilot.favor = Array(args[2].split(","))
	for sd in seeds:
		var s := Sim.new(100 + sd, loadout)
		var hurt := 0.0
		var sector_hurt := 0.0
		var max_en := 0
		var line := ""
		while s.tick < 10 * 60 * Sim.TPS and (s.state == Sim.RUNNING or s.state == Sim.CHOOSING):
			if s.state == Sim.CHOOSING:
				var bk := Autopilot.banish_pick(s)
				if bk >= 0:
					s.banish(bk)
				else:
					s.choose(Autopilot.pick(s))
				continue
			var m := Autopilot.move(s)
			s.step(m.x, m.y, Autopilot.burst(s))
			var by_sector := false
			for e in s.events:
				if (e[0] == Sim.EV_MAW and e[3] == 3) or (e[0] == Sim.EV_FLARE and e[1] == 2):
					by_sector = true
			for e in s.events:
				if e[0] == Sim.EV_HURT:
					hurt += e[1]
					if by_sector:
						sector_hurt += e[1]
				elif e[0] == Sim.EV_BOSS_DOWN:
					line += " [boss%d down @%ds]" % [e[1], int(s.seconds())]
				elif e[0] == Sim.EV_EVOLVE:
					line += " [EVOLVED %s @%ds]" % [e[1], int(s.seconds())]
				elif e[0] == Sim.EV_CHEST:
					line += " [cache @%ds]" % int(s.seconds())
				elif e[0] == Sim.EV_OVERDRIVE:
					line += " [OD @%ds]" % int(s.seconds())
				elif e[0] == Sim.EV_RELIC:
					line += " [RELIC %s @%ds]" % [e[1], int(s.seconds())]
			max_en = maxi(max_en, s.en)
			if s.tick % (30 * Sim.TPS) == 0:
				var b := s.boss_index()
				line += "\n  %3ds lvl%2d en%3d hp%4.0f/%4.0f hurt%5.0f kills%5d%s" % [int(s.seconds()), s.level, s.en, s.hp, s.max_hp, hurt, s.kills,
					(" boss %.0f%%" % (100.0 * s.e_hp[b] / s.e_maxhp[b])) if b >= 0 else ""]
		var sec := "" if s.sector == 0 else " sector %d (eaten %d, best maw %d, flares passed %d, hurt by sector %.0f)" % [
				s.sector, s.maws_eaten, s.maw_best, s.flares_passed, sector_hurt]
		print("seed %d -> state %d at %ds, lvl %d, kills %d, max_en %d, flux %d%s %s" % [100 + sd, s.state, int(s.seconds()), s.level, s.kills, max_en, s.flux_earned(), sec,
			str(s.weapons.map(func(w): return "%s%d" % [w.id, w.lvl])) + str(s.passives) + str(s.relics)])
		print(line)
	quit()

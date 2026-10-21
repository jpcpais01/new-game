extends SceneTree
## Balance probe (not run in CI): how the bot fares against trait elites.
## godot --headless --path . -s tests/trait_probe.gd -- [seeds] [loadout-json] [minutes]
## Prints every elite: its traits, how long it lived and the damage the bot
## took while it was alive, then totals per trait.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 6
	var loadout: Dictionary = JSON.parse_string(args[1]) if args.size() > 1 else {"mods": ["gilded"]}
	var minutes := float(args[2]) if args.size() > 2 else 9.0
	var per := {}   # trait -> [elites, seconds alive, damage taken while alive]
	var deaths := 0
	for sd in seeds:
		var s := Sim.new(100 + sd, loadout)
		var alive := {}   # uid -> [mask, tick, hurt]
		var lines: Array = []
		while s.tick < int(minutes * 60.0) * Sim.TPS and (s.state == Sim.RUNNING or s.state == Sim.CHOOSING):
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
					for u in alive:
						alive[u][2] += float(e[1])
			# Track trait carriers by uid.
			for i in s.en:
				if s.e_tr[i] != 0 and not alive.has(s.e_uid[i]):
					alive[s.e_uid[i]] = [s.e_tr[i], s.tick, 0.0, s.e_type[i]]
			for u in alive.keys():
				var found := false
				for i in s.en:
					if s.e_uid[i] == u:
						found = true
						break
				if not found:
					var rec: Array = alive[u]
					var secs := float(s.tick - int(rec[1])) / Sim.TPS
					lines.append("  %s @%d: %.0fs, took %.0f" % [Defs.elite_name(rec[3], rec[0]), int(rec[1]) / Sim.TPS,
							secs, rec[2]])
					for id in Defs.trait_ids(rec[0]):
						var p: Array = per.get(id, [0, 0.0, 0.0])
						p[0] += 1
						p[1] += secs
						p[2] += float(rec[2])
						per[id] = p
					alive.erase(u)
		if s.state == Sim.DEAD:
			deaths += 1
		print("seed %d: %s at %s, lvl %d, elites %d, trait kills %d (%d exalted)" % [100 + sd,
				"DIED" if s.state == Sim.DEAD else ("DAWN" if s.dawn else "alive"), "%d:%02d" % [int(s.seconds()) / 60, int(s.seconds()) % 60], s.level,
				s.elite_kills, s.trait_kills, s.exalted_kills])
		for l in lines:
			print(l)
	print("deaths %d/%d" % [deaths, seeds])
	for id in Defs.TRAIT_ORDER:
		if per.has(id):
			var p: Array = per[id]
			print("%-10s n=%d avg life %.0fs, avg hurt %.0f" % [id, p[0], p[1] / p[0], p[2] / p[0]])
	quit()

extends SceneTree
## Balance probe for Daily Runs (not run in CI): bot plays N days.
## godot --headless --path . -s tests/daily_probe.gd -- [first_day] [days]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first := int(args[0]) if args.size() > 0 else 20745
	var days := int(args[1]) if args.size() > 1 else 6
	for d in range(first, first + days):
		var dd := Daily.for_day(d)
		var s := Sim.new(int(dd.seed), dd.loadout)
		Autopilot.play(s, 10 * 60 * Sim.TPS)
		if s.state == Sim.WON:
			s.continue_night()
			Autopilot.play(s, s.tick + 5 * 60 * Sim.TPS)
		print("%s %-8s %-40s -> %s %s lvl %d kills %d score %s night %d" % [Daily.label(d), dd.ship, str(dd.mods),
			["RUN", "CHOOSE", "DEAD", "WON"][s.state], "%ds" % int(s.seconds()), s.level, s.kills,
			str(s.score()), s.night])
	quit()

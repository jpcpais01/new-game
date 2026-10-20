extends SceneTree
## After-action report probe (not run in CI): bot-plays runs and prints the
## damage by source, the boss log and the highlights.
## godot --headless --path . -s tests/report_probe.gd -- [seeds] [loadout-json]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := 2
	var loadout := {}
	if args.size() > 0:
		seeds = int(args[0])
	if args.size() > 1:
		loadout = JSON.parse_string(args[1])
	for sd in seeds:
		var s := Sim.new(100 + sd, loadout)
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
		var total := 0.0
		for r in s.damage_report():
			total += float(r[1])
		print("seed %d  %ds  dawn %s  kills %d  dealt %.0f (raw %.0f)" % [100 + sd, int(s.seconds()), s.dawn,
				s.kills, total, s.damage_dealt])
		for r in s.damage_report():
			print("  %-12s %9.0f  %5.1f%%  %5d kills" % [r[0] if r[0] != "" else "(other)", r[1],
					100.0 * float(r[1]) / maxf(1.0, total), r[2]])
		print("  bosses ", s.boss_log)
		print("  best hit %.0f (%s)  low hp %.1f  peak en %d  peak dps %.0f  samples %d  marks %d" % [s.best_hit,
				s.best_hit_src, s.low_hp, s.peak_en, s.peak_dps(), s.tl_hp.size(), s.tl_marks.size()])
	quit()

extends Node
## Screenshot helper (run as a scene, not with -s):
## xvfb-run -s "-screen 0 1280x2400x24" godot --path . --resolution 720x1280 res://tests/shots.tscn -- /tmp/shots
## Captures the title, a mid-run moment, the level-up cards, the pause menu,
## the results panel and the Forge.

var out := "/tmp/shots"
var main: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	Save.data.missions = ["alchemist", "exterminator", "first_flight"]
	Save.data.ship = "strix"
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(2.5)
	await _shot("1_title")
	if args.has("daily"):
		await _daily_shots()
		get_tree().quit()
		return
	main.start_run()
	await _wait(1.0)
	var gs = main.screen
	# Fast-forward the run with the autopilot so the screen is busy.
	var s: Sim = gs.sim
	s.loadout = {"hull": 5}
	while s.seconds() < 150.0 and s.state != Sim.DEAD:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			var m := Autopilot.move(s)
			s.step(m.x, m.y)
		s.events.clear()
	main.arena.demo = true
	await _wait(1.6)
	main.arena.demo = false
	await _shot("2_run")
	# Overdrive: charged, then unleashed.
	s.od = s.od_need
	await _wait(0.6)
	await _shot("2a_od_ready")
	gs._od.trigger()
	await _wait(0.45)
	await _shot("2d_overdrive")
	# Evolved arsenal in action.
	s.weapons = [
		{"id": "pulse", "lvl": Defs.EVO_LEVEL, "t": 5, "k": 0, "a": 0},
		{"id": "orbit", "lvl": Defs.EVO_LEVEL, "t": 5, "k": 0, "a": 0},
		{"id": "nova", "lvl": Defs.EVO_LEVEL, "t": 5, "k": 0, "a": 0},
		{"id": "lance", "lvl": Defs.EVO_LEVEL, "t": 5, "k": 0, "a": 0},
	]
	s.hp = s.max_hp
	main.arena.demo = true
	await _wait(1.3)
	main.arena.demo = false
	await _shot("2b_evolved")
	# A Prism Cache that evolves the Seeker Swarm.
	s.weapons[3] = {"id": "seeker", "lvl": Defs.MAX_LEVEL, "t": 5, "k": 0, "a": 0}
	s.passives["fortune"] = 1
	s.passive_order.append("fortune")
	s.pickups.append({"k": "bigchest", "x": s.px, "y": s.py, "mag": true, "spd": 0.0})
	await _wait(3.4)
	await _shot("2c_cache")
	gs._chest.visible = false
	gs._on_chest_closed()
	await _wait(0.5)
	s.xp = s.xp_need
	main.arena.demo = false
	await _wait(1.2)
	await _shot("3_levelup")
	gs._cards._pick(0)
	await _wait(0.8)
	gs.open_pause()
	await _wait(0.7)
	await _shot("4_pause")
	gs._pause.close()
	gs._resume()
	await _wait(0.3)
	s.state = Sim.DEAD
	s.warden_down = true
	gs._on_end(false)
	await _wait(1.6)
	await _shot("5_results")
	Save.data.flux = 900
	main.go_forge()
	await _wait(1.2)
	await _shot("6_forge")
	main.go_hangar()
	await _wait(1.2)
	await _shot("7_hangar")
	main.screen._show(1, 1)
	await _wait(0.8)
	await _shot("7b_hangar_vesper")
	main.screen._show(6, 1)
	await _wait(0.8)
	await _shot("7c_hangar_locked")
	main.go_missions()
	await _wait(1.4)
	await _shot("8_missions")
	get_tree().quit()


## The Daily Run, the dawn choice, the Afterdark, the results and the Codex.
func _daily_shots() -> void:
	Save.data.evolved = ["pulse", "nova"]
	Save.data.daily_log = [
		{"day": Save.today() - 1, "score": 84210, "time": 512.0, "kills": 6400, "dawn": false, "ship": "kestrel", "tries": 3},
		{"day": Save.today() - 2, "score": 131560, "time": 690.0, "kills": 9100, "dawn": true, "ship": "vesper", "tries": 1},
	]
	Save.data.daily_last = Save.today() - 1
	Save.data.daily_streak = 2
	Save.data.daily_streak_best = 2
	main.go_daily()
	await _wait(1.4)
	await _shot("d1_daily")
	main.start_daily()
	await _wait(1.6)
	await _shot("d2_daily_intro")
	var gs = main.screen
	var s: Sim = gs.sim
	while s.state != Sim.WON and s.state != Sim.DEAD and s.tick < 10 * 60 * Sim.TPS:
		if s.state == Sim.CHOOSING:
			s.choose(Autopilot.pick(s))
		else:
			var m := Autopilot.move(s)
			s.step(m.x, m.y, Autopilot.burst(s))
		s.events.clear()
	if s.state != Sim.WON:
		# Force the dawn so the screens below have something to show.
		s.state = Sim.RUNNING
		var i := s._spawn(Defs.ECLIPSE, s.px + 500.0, s.py, false, 0)
		s.e_hp[i] = 0.0
		s.step(0, 0)
		s.events.clear()
	gs._on_end(true)
	await _wait(1.4)
	await _shot("d3_dawn")
	var dp = gs._dawn
	dp.chose.emit(true)
	dp.close()
	await _wait(0.3)
	s.tick = s.night_next - 1
	main.arena.demo = true
	await _wait(3.5)
	main.arena.demo = false
	await _shot("d4_afterdark")
	s.state = Sim.DEAD
	gs._on_end(false)
	await _wait(2.5)
	await _shot("d5_results")
	main.go_codex()
	await _wait(1.4)
	await _shot("d6_codex")
	main.go_title()
	await _wait(2.0)
	await _shot("d7_title_after")


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)

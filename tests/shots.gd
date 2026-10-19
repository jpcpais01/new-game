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
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(2.5)
	await _shot("1_title")
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
	gs._on_end(false)
	await _wait(1.6)
	await _shot("5_results")
	Save.data.flux = 900
	main.go_forge()
	await _wait(1.2)
	await _shot("6_forge")
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)

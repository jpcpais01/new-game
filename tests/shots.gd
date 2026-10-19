extends Node
## Dev helper: renders screenshots of key screens for a visual sanity check.
## xvfb-run godot --path . --rendering-driver opengl3 res://tests/shots.tscn -- <outdir>

var out_dir := "user://shots"
var main: Control


var root: Window


func _ready() -> void:
	root = get_tree().root
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Save.data = Save.defaults()
	Save.data.best = 23456
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)
	_run()


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _bot(g: GameScreen) -> Array:
	var best := []
	var best_s := -1
	for slot in g.game.hand.size():
		var shape := g.game.shape_in_slot(slot)
		if shape.is_empty():
			continue
		var spot := PrismDealer.best_spot(g.game.board, shape)
		if spot.ok and spot.score > best_s:
			best_s = spot.score
			best = [slot, spot.pos]
	return best


func _run() -> void:
	await _wait(2.6)
	await _shot("01_title")
	main.get_child(main.get_child_count() - 2).call("_open", Dialogs.whats_new())
	await _wait(0.6)
	await _shot("02_whats_new")
	main.start_game("classic", false)
	await _wait(1.0)
	var g: GameScreen = null
	for c in main.get_children():
		if c is GameScreen:
			g = c
	await _shot("03_game_start")
	# Play until something clears, capture mid-effect.
	var captured := false
	for i in 60:
		var m := _bot(g)
		if m.is_empty():
			break
		var lines_before: int = g.game.stats.lines
		g._commit(m[0], m[1])
		if g.game.stats.lines > lines_before and not captured and i > 4:
			await _wait(0.12)
			await _shot("04_clear_fx")
			captured = true
		await _wait(0.05)
	await _wait(1.0)
	await _shot("05_midgame")
	# Simulated drag with a ghost preview.
	for slot in 3:
		if g.game.hand[slot] != null and g.game.slot_playable(slot):
			var spot := PrismDealer.best_spot(g.game.board, g.game.shape_in_slot(slot))
			g._press(g.tray_view.position + g.tray_view.slot_center(slot))
			var shape := g.game.shape_in_slot(slot)
			var center: Vector2 = g.board_view.position + (Vector2(spot.pos) + Vector2(shape.w, shape.h) / 2.0) * g.cell
			g.drag_finger = center + Vector2(0, shape.h * g.cell / 2.0 + g.cell * GameScreen.LIFT_CELLS)
			g._update_snap()
			await _wait(0.4)
			await _shot("06_drag")
			g._release()
			break
	await _wait(0.5)
	g.open_pause()
	await _wait(0.6)
	await _shot("07_pause")
	g._modal.close()
	await _wait(0.4)
	for i in 400:
		if g.game.game_over:
			break
		var m := _bot(g)
		if m.is_empty():
			break
		g._commit(m[0], m[1])
		await get_tree().process_frame
	await _wait(1.2)
	await _shot("08_out_of_space")
	await _wait(2.6)
	await _shot("09_game_over")
	get_tree().quit()

class_name GameScreen
extends Control
## The play screen. Owns one PrismGame (the rules) and turns its events into
## everything the player sees, hears and feels. Input becomes moves, moves go
## through PrismGame.place(), and the returned event drives the show.

const HUD_H := 330.0
const LIFT_CELLS := 1.15

var main: Node
var game: PrismGame
var mode := "classic"
var daily_date := ""

var world: Node2D
var board_view: BoardView
var tray_view: TrayView
var drag_view: DragView
var hint_view: HintView
var fx: Fx

var score_label: Label
var best_label: Label
var best_icon: TextureRect
var mode_label: Label
var pause_btn: PrismButton
var combo_meter: ComboMeter

var cell := 110.0
var tray_cell := 56.0
var shown_score := 0.0
var best_at_start := 0
var new_best_shown := false
var input_locked := false
var drag_slot := -1
var drag_finger := Vector2.ZERO
var snap_valid := false
var snap_origin := Vector2i(-99, -99)
var shake := 0.0
var energy := 0.0
var energy_target := 0.0
var flash := 0.0
var _dim_t := -1.0
var _score_pop := 0.0
var _modal: Modal


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	board_view = BoardView.new()
	world.add_child(board_view)
	tray_view = TrayView.new()
	world.add_child(tray_view)
	fx = Fx.new()
	world.add_child(fx)
	hint_view = HintView.new()
	hint_view.visible = false
	world.add_child(hint_view)
	drag_view = DragView.new()
	drag_view.returned.connect(func(slot): tray_view.hidden_slots.erase(slot))
	world.add_child(drag_view)
	_build_hud()
	resized.connect(_layout)
	_layout()


## Start (or resume) a run. `resume` rebuilds the saved run from its replay.
func start(p_mode: String, resume: bool) -> void:
	mode = p_mode
	daily_date = main.today() if mode == "daily" else ""
	var saved = null
	if resume:
		if mode == "daily":
			var dr = Save.data.daily_run
			if dr is Dictionary and dr.get("date", "") == daily_date:
				saved = dr.replay
		else:
			saved = Save.data.run
	if saved is Dictionary:
		game = PrismGame.from_replay(saved)
		if game.game_over:
			Save.record_game(game, daily_date)
			game = null
	if game == null:
		var seed_value: int
		if mode == "daily":
			seed_value = PrismRng.hash_string("prisma-daily-" + daily_date)
			Save.touch_daily(daily_date, main.yesterday())
		else:
			seed_value = main.fresh_seed()
		game = PrismGame.new(seed_value, mode)
		_save_run()
	best_at_start = Save.daily_best(daily_date) if mode == "daily" else int(Save.data.best)
	new_best_shown = best_at_start == 0
	shown_score = game.score
	board_view.sync(game.board)
	tray_view.set_hand(game.hand, _playable(), true)
	Sfx.play("deal", 1.0, -4.0)
	mode_label.text = ("DAILY  ·  " + main.pretty_date(daily_date)) if mode == "daily" else ""
	_update_hud(false)
	if not Save.data.tutorial_done and game.moves.is_empty():
		_show_hint.call_deferred()


# ---------------------------------------------------------------- layout --

func _build_hud() -> void:
	pause_btn = UiKit.icon_button("pause", 124)
	pause_btn.pressed.connect(open_pause)
	add_child(pause_btn)

	best_icon = TextureRect.new()
	best_icon.texture = Art.icon("crown")
	best_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	best_icon.custom_minimum_size = Vector2(56, 56)
	best_icon.size = Vector2(56, 56)
	best_icon.modulate = PrismPalette.GOLD
	best_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(best_icon)
	best_label = UiKit.label("0", 50, PrismPalette.GOLD)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(best_label)

	score_label = UiKit.label("0", 132)
	score_label.label_settings.outline_size = 0
	add_child(score_label)

	mode_label = UiKit.label("", 32, PrismPalette.TEXT_DIM, false)
	add_child(mode_label)

	combo_meter = ComboMeter.new()
	combo_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(combo_meter)


func _layout() -> void:
	if board_view == null or main == null:
		return
	var vs := size
	var ins: Dictionary = main.safe_insets()
	var top: float = ins.top
	var bottom: float = ins.bottom
	var W := vs.x
	var H := vs.y - top - bottom
	var margin := 40.0
	var max_board := minf(W - margin * 2 - BoardView.PAD * 2, H * 0.5)
	cell = floorf(max_board / PrismBoard.SIZE)
	var board_px := cell * PrismBoard.SIZE
	tray_cell = floorf(cell * 0.54)
	var tray_h := tray_cell * 4.6
	var content_h := HUD_H + board_px + BoardView.PAD * 2 + 30 + tray_h
	var y0 := top + maxf(0.0, (H - content_h) * 0.38)

	board_view.cell = cell
	board_view.position = Vector2(roundf((W - board_px) / 2.0), roundf(y0 + HUD_H + BoardView.PAD))
	tray_view.width = minf(W - margin, board_px + 160)
	tray_view.height = tray_h
	tray_view.cell = tray_cell
	tray_view.position = Vector2(roundf((W - tray_view.width) / 2.0), board_view.position.y + board_px + BoardView.PAD + 30)
	drag_view.cell = cell
	hint_view.cell = cell

	var hud_y := y0 + 24
	pause_btn.position = Vector2(margin, hud_y)
	best_label.size = Vector2(420, 70)
	best_label.position = Vector2(W - margin - 420, hud_y + 26)
	best_icon.position = Vector2(W - margin - 64, hud_y - 30)
	score_label.size = Vector2(W, 150)
	score_label.position = Vector2(0, hud_y + 70)
	mode_label.size = Vector2(W, 40)
	mode_label.position = Vector2(0, hud_y + 2)
	combo_meter.size = Vector2(560, 90)
	combo_meter.position = Vector2((W - 560) / 2.0, hud_y + 214)
	score_label.pivot_offset = score_label.size / 2.0
	main.set_bg_aspect(vs)


# ----------------------------------------------------------------- input --

func _unhandled_input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press(event.position)
		else:
			_release()
	elif event is InputEventMouseMotion and drag_slot >= 0:
		drag_finger = event.position
		_update_snap()


func _press(pos: Vector2) -> void:
	if input_locked or game.game_over or drag_slot >= 0:
		return
	var slot := tray_view.slot_at(tray_view.to_local(pos))
	if slot < 0 or game.hand[slot] == null or tray_view.hidden_slots.has(slot):
		return
	drag_slot = slot
	drag_finger = pos
	var shape := game.shape_in_slot(slot)
	drag_view.shape = shape
	drag_view.color = game.hand[slot].color
	drag_view.center = tray_view.position + tray_view.slot_center(slot)
	drag_view.scale_now = tray_cell / cell
	drag_view.active = true
	drag_view.valid = false
	tray_view.hidden_slots[slot] = true
	snap_origin = Vector2i(-99, -99)
	Sfx.play("pick", randf_range(0.96, 1.06), -3.0)
	Sfx.haptic(6, 0.25)
	hint_view.dismiss()
	_update_snap()


func _drag_target() -> Vector2:
	var shape := drag_view.shape
	var lift: float = shape.h * cell / 2.0 + cell * LIFT_CELLS
	return world.to_local(drag_finger) - Vector2(0, lift)


func _update_snap() -> void:
	var shape := drag_view.shape
	var tl := _drag_target() - Vector2(shape.w, shape.h) * cell / 2.0
	var f := (tl - board_view.position) / cell
	var best := Vector2i(-99, -99)
	var best_d := 0.85
	for cx in [floori(f.x), ceili(f.x)]:
		for cy in [floori(f.y), ceili(f.y)]:
			var d := Vector2(cx, cy).distance_to(f)
			if d < best_d and game.can_place(drag_slot, cx, cy):
				best_d = d
				best = Vector2i(cx, cy)
	if best.x == -99:
		if snap_valid:
			board_view.clear_ghost()
		snap_valid = false
		snap_origin = best
		drag_view.valid = false
		return
	if best != snap_origin:
		snap_origin = best
		snap_valid = true
		drag_view.valid = true
		board_view.set_ghost(shape, best, drag_view.color, game.preview(drag_slot, best.x, best.y))


func _release() -> void:
	if drag_slot < 0:
		return
	var slot := drag_slot
	drag_slot = -1
	board_view.clear_ghost()
	drag_view.active = false
	if snap_valid:
		snap_valid = false
		_commit(slot, snap_origin)
	else:
		var to := tray_view.position + tray_view.slot_center(slot)
		drag_view.fly_back(drag_view.shape, drag_view.color, drag_view.center, to, drag_view.scale_now, tray_cell / cell, slot)
		var board_rect := Rect2(board_view.global_position, Vector2.ONE * cell * PrismBoard.SIZE)
		if board_rect.has_point(drag_finger):
			Sfx.play("drop_bad", 1.0, -4.0)
			Sfx.haptic(14, 0.3)


# ----------------------------------------------------------------- moves --

func _commit(slot: int, origin: Vector2i) -> void:
	var ev := game.place(slot, origin.x, origin.y)
	if not ev.ok:
		tray_view.hidden_slots.erase(slot)
		return
	tray_view.hidden_slots.erase(slot)
	tray_view.clear_slot(slot)
	hint_view.dismiss()
	board_view.sync(game.board)

	var cleared_keys := {}
	for c in ev.cleared:
		cleared_keys[c.pos] = true
	var survivors: Array = []
	for p in ev.placed:
		if not cleared_keys.has(p):
			survivors.append(p)
	board_view.animate_place(survivors)

	var shape := PrismPieces.get_shape(ev.shape)
	var piece_center := board_view.position + (Vector2(origin) + Vector2(shape.w, shape.h) / 2.0) * cell
	var col := PrismPalette.gem(ev.color)
	fx.glow(piece_center, Color(col.r, col.g, col.b, 0.5), cell * (shape.w + shape.h) * 0.9, 0.35)
	fx.sparks(piece_center, col.lightened(0.3), 4 + shape.size, 0.6)
	Sfx.play("place", 1.12 - shape.size * 0.035 + randf_range(-0.03, 0.03))
	Sfx.haptic(10 + shape.size * 2, 0.4)

	if ev.lines > 0:
		_celebrate(ev, piece_center)
	else:
		shake = maxf(shake, 3.0)

	if ev.combo > 0 and ev.lines == 0 and ev.combo_left == 1:
		combo_meter.warn()

	_update_hud(true)
	if ev.dealt:
		tray_view.hidden_slots.clear()
		tray_view.set_hand(game.hand, _playable(), true)
		_later(0.12, func(): Sfx.play("deal", 1.0, -6.0))
	else:
		tray_view.set_playable(_playable())

	if not Save.data.tutorial_done:
		Save.data.tutorial_done = true
	_save_run()

	if not new_best_shown and game.score > best_at_start:
		new_best_shown = true
		_later(0.5, _celebrate_new_best)

	if ev.game_over:
		_begin_game_over(0.75 if ev.lines == 0 else 1.25)


func _celebrate(ev: Dictionary, piece_center: Vector2) -> void:
	var bp := board_view.position
	var origin_local := piece_center - bp
	board_view.animate_clear(ev.cleared, origin_local)
	var col := PrismPalette.gem(ev.color)
	var board_px := cell * PrismBoard.SIZE

	# Light beams sweep each cleared line.
	for r in ev.rows:
		var prism: bool = ev.prism_rows.has(r)
		fx.beam(bp + Vector2(board_px / 2.0, (r + 0.5) * cell), true, board_px, cell * 1.3, col.lightened(0.2), 0.02, prism)
	for c in ev.cols:
		var prism: bool = ev.prism_cols.has(c)
		fx.beam(bp + Vector2((c + 0.5) * cell, board_px / 2.0), false, board_px, cell * 1.3, col.lightened(0.2), 0.02, prism)

	# Every gem shatters as the wave reaches it.
	var centroid := Vector2.ZERO
	for c in ev.cleared:
		var p: Vector2 = bp + board_view.cell_center(c.pos)
		centroid += p
		var delay := 0.04 + (p - piece_center).length() / cell * 0.035
		var color: int = c.color
		var gem_col := PrismPalette.gem(color)
		_later(delay, func():
			fx.shards(p, color, 3, 1.0, cell)
			fx.sparks(p, gem_col.lightened(0.35), 2, 0.8))
	centroid /= float(ev.cleared.size())

	var lines: int = ev.lines
	var combo: int = ev.combo
	fx.ring(piece_center, Color(col.r, col.g, col.b, 0.9), cell * 0.4, cell * (2.5 + lines * 1.2), 0.6)
	fx.glow(centroid, Color(1, 1, 1, 0.35), board_px * 0.8, 0.45)
	fx.text(centroid + Vector2(0, -cell * 0.3), "+" + UiKit.format_score(ev.gained), 78 if lines < 3 else 96, PrismPalette.GOLD, "pop", 1.2)

	# Banners, stacked in the middle of the board.
	var mid := bp + Vector2(board_px / 2.0, board_px * 0.42)
	var stack := 0.0
	if ev.perfect:
		fx.text(mid + Vector2(0, -cell * 0.6), "PERFECT!", 150, Color.WHITE, "rainbow", 2.0, 0.1)
		fx.confetti(bp + Vector2(board_px / 2.0, board_px * 0.9), 90)
		flash = 0.35
		stack += cell * 1.2
	elif ev.prisms > 0:
		var ptxt := "PRISM!" if ev.prisms == 1 else "PRISM x%d!" % ev.prisms
		fx.text(mid + Vector2(0, -cell * 0.2), ptxt, 132, Color.WHITE, "rainbow", 1.6, 0.05)
		stack += cell * 1.0
	elif lines >= 2:
		var names := ["", "", "DOUBLE!", "TRIPLE!", "MEGA!", "ULTRA!", "PRISMATIC!"]
		var txt: String = names[mini(lines, names.size() - 1)]
		fx.text(mid, txt, 118, col.lightened(0.45), "banner", 1.3, 0.05)
		stack += cell * 0.95
	if combo >= 2:
		fx.text(mid + Vector2(0, stack * 0.6 + cell * 0.2), "COMBO  x%d" % combo, 78, PrismPalette.GOLD.lightened(0.2), "banner", 1.2, 0.18)
		combo_meter.bump()

	# Sound: the clear climbs the scale with the combo.
	Sfx.play_step("clear", (combo - 1) + (lines - 1), -2.0)
	if lines >= 2:
		Sfx.play("whoosh", 1.0 + lines * 0.05, -6.0)
	if ev.prisms > 0:
		Sfx.play("prism", 1.0, -1.0)
	if ev.perfect:
		Sfx.play("perfect", 1.0, 0.0)
	if combo >= 3:
		Sfx.play("combo", 0.9 + mini(combo, 10) * 0.04, -8.0)
	Sfx.haptic(18 + lines * 12 + (60 if ev.perfect else 0), minf(1.0, 0.45 + lines * 0.12))

	shake = maxf(shake, minf(34.0, 8.0 + lines * 6.0 + combo * 1.5 + (14.0 if ev.perfect else 0.0)))
	energy_target = clampf(combo / 7.0, 0.0, 1.0)
	if lines >= 2:
		flash = maxf(flash, 0.06 * lines)


func _celebrate_new_best() -> void:
	var mid := Vector2(size.x / 2.0, board_view.position.y - 20)
	fx.text(mid, "NEW BEST!", 96, PrismPalette.GOLD, "banner", 1.6)
	fx.confetti(Vector2(size.x / 2.0, board_view.position.y + cell * 2), 50)
	Sfx.play("newbest", 1.0, -4.0)
	Sfx.haptic(40, 0.6)


func _begin_game_over(delay: float) -> void:
	input_locked = true
	_later(delay, func():
		Sfx.play("gameover")
		Sfx.duck_music(true)
		Sfx.haptic(120, 0.5)
		_dim_t = 0.0
		var board_px := cell * PrismBoard.SIZE
		fx.text(board_view.position + Vector2(board_px / 2.0, board_px / 2.0), "OUT OF SPACE", 104, Color.WHITE, "banner", 1.7))
	_later(delay + 1.9, _show_game_over)


func _show_game_over() -> void:
	var record := Save.record_game(game, daily_date)
	var m := Modal.new(920)
	m.dismissable = false
	var title := "NEW BEST!" if record else "GAME OVER"
	if mode == "daily":
		title = "DAILY BEST!" if record else "DAILY DONE"
	if record:
		var crown := TextureRect.new()
		crown.texture = Art.icon("crown")
		crown.custom_minimum_size = Vector2(120, 120)
		crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		crown.modulate = PrismPalette.GOLD
		m.content.add_child(crown)
	m.add_title(title, PrismPalette.GOLD if record else PrismPalette.TEXT, 80)
	var score_l := UiKit.label("0", 150)
	m.content.add_child(score_l)
	var best_v := Save.daily_best(daily_date) if mode == "daily" else int(Save.data.best)
	m.add_text(("Daily best  " if mode == "daily" else "Best  ") + UiKit.format_score(best_v), 42, PrismPalette.GOLD)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.add_child(UiKit.chip("Lines", str(game.stats.lines), PrismPalette.gem(4)))
	row.add_child(UiKit.chip("Best combo", str(game.stats.best_combo), PrismPalette.gem(2)))
	row.add_child(UiKit.chip("Prisms", str(game.stats.prisms), PrismPalette.gem(6)))
	m.content.add_child(row)
	if mode == "daily":
		m.add_text("Same puzzle for everyone today.\nStreak: %d day%s" % [int(Save.data.daily_streak), "" if int(Save.data.daily_streak) == 1 else "s"], 34)
	m.add_button("PLAY AGAIN", "primary", func():
		m.close()
		main.restart_game(mode))
	m.add_button("HOME", "ghost", func():
		m.close()
		main.go_title(), Vector2(620, 120))
	_open_modal(m)
	var final_score := game.score
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_method(func(v: float): score_l.text = UiKit.format_score(int(v)), 0.0, float(final_score), 1.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if record:
		tw.tween_callback(func():
			fx.confetti(Vector2(size.x / 2.0, size.y * 0.75), 140, 1200.0)
			Sfx.play("newbest")
			Sfx.haptic(60, 0.8))


# ----------------------------------------------------------------- dialogs --

func open_pause() -> void:
	if _modal != null or game == null or game.game_over:
		return
	var m := Modal.new(820)
	m.add_title("PAUSED")
	m.add_text("Score  " + UiKit.format_score(game.score), 44, PrismPalette.GOLD)
	m.add_button("RESUME", "primary", m.close)
	m.add_button("RESTART", "ghost", func():
		m.close()
		main.restart_game(mode, true), Vector2(620, 124))
	m.add_button("SETTINGS", "ghost", func():
		m.close()
		_open_modal.call_deferred(Dialogs.settings(_replay_tutorial)), Vector2(620, 124))
	m.add_button("HOME", "ghost", func():
		m.close()
		main.go_title(), Vector2(620, 124))
	_open_modal(m)


func _replay_tutorial() -> void:
	Save.data.tutorial_done = false
	Save.save_data()
	_show_hint()


func _open_modal(m: Modal) -> void:
	_modal = m
	m.closed.connect(func():
		if _modal == m:
			_modal = null)
	add_child(m)


func on_back() -> void:
	if _modal != null:
		if _modal.dismissable:
			_modal.close()
	else:
		open_pause()


# ----------------------------------------------------------------- frame --

func _process(delta: float) -> void:
	if game == null:
		return
	# Smooth drag follow.
	if drag_view.active:
		var target := _drag_target()
		var k := 1.0 - exp(-delta * 28.0)
		drag_view.center = drag_view.center.lerp(target, k)
		drag_view.scale_now = lerpf(drag_view.scale_now, 1.0, 1.0 - exp(-delta * 16.0))
	# Score count-up.
	if shown_score < game.score:
		shown_score = minf(float(game.score), shown_score + maxf(1.0, (game.score - shown_score) * delta * 8.0))
		score_label.text = UiKit.format_score(int(shown_score))
	_score_pop = maxf(0.0, _score_pop - delta * 3.5)
	score_label.scale = Vector2.ONE * (1.0 + 0.16 * _score_pop * _score_pop)
	# Screen shake.
	if shake > 0.1:
		world.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
		shake = lerpf(shake, 0.0, 1.0 - exp(-delta * 10.0))
	else:
		world.position = Vector2.ZERO
	# Background mood follows the combo.
	if game.combo == 0:
		energy_target = 0.0
	energy = lerpf(energy, energy_target, 1.0 - exp(-delta * 2.0))
	flash = lerpf(flash, 0.0, 1.0 - exp(-delta * 7.0))
	main.set_bg_mood(energy, flash)
	# Game-over greying wave.
	if _dim_t >= 0.0:
		_dim_t += delta
		var c := Vector2(3.5, 3.5)
		for y in PrismBoard.SIZE:
			for x in PrismBoard.SIZE:
				var d := Vector2(x, y).distance_to(c)
				board_view.set_dim(y * PrismBoard.SIZE + x, clampf((_dim_t * 7.0 - d) / 2.0, 0.0, 1.0))


func _update_hud(animate: bool) -> void:
	var best_v := maxi(best_at_start, game.score)
	best_label.text = UiKit.format_score(best_v)
	if not animate:
		shown_score = game.score
		score_label.text = UiKit.format_score(game.score)
	else:
		_score_pop = 1.0
	combo_meter.set_combo(game.combo, game.combo_left(), (1 + mini(game.combo, PrismGame.COMBO_MULT_CAP)) / 2.0)


func _playable() -> Array:
	var out := []
	for i in game.hand.size():
		out.append(game.hand[i] == null or game.slot_playable(i))
	return out


func _save_run() -> void:
	if game == null:
		return
	if game.game_over:
		Save.save_data()
		return
	if mode == "daily":
		Save.data.daily_run = {"date": daily_date, "replay": game.to_replay()}
	else:
		Save.data.run = game.to_replay()
	Save.save_data()


func _show_hint() -> void:
	if game == null:
		return
	for slot in game.hand.size():
		var shape := game.shape_in_slot(slot)
		if shape.is_empty():
			continue
		var spot := PrismDealer.best_spot(game.board, shape)
		if not spot.ok:
			continue
		var from := tray_view.position + tray_view.slot_center(slot)
		var to: Vector2 = board_view.position + (Vector2(spot.pos) + Vector2(shape.w, shape.h) / 2.0) * cell
		hint_view.setup(shape, game.hand[slot].color, from, to, cell, tray_cell)
		var tip := UiKit.label("Drag a piece onto the board.\nFill a row or column to clear it!", 40, PrismPalette.TEXT)
		tip.size = Vector2(size.x, 120)
		tip.position = Vector2(0, minf(size.y - 150.0, tray_view.position.y + tray_view.height + 10.0))
		tip.modulate.a = 0.0
		add_child(tip)
		var tw := tip.create_tween()
		tw.tween_property(tip, "modulate:a", 1.0, 0.4)
		_watch_hint(tip)
		return


func _watch_hint(tip: Label) -> void:
	while is_instance_valid(tip) and hint_view.visible and not hint_view._dismissed:
		await get_tree().create_timer(0.2).timeout
	if is_instance_valid(tip):
		var tw := tip.create_tween()
		tw.tween_property(tip, "modulate:a", 0.0, 0.3)
		tw.tween_callback(tip.queue_free)


func _later(delay: float, cb: Callable) -> void:
	get_tree().create_timer(delay).timeout.connect(cb)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if drag_slot >= 0:
			_release()
		_save_run()
		if what == NOTIFICATION_APPLICATION_PAUSED:
			open_pause()

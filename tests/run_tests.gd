extends SceneTree
## Headless logic checks for the deterministic core.
## Run: godot --headless --path . -s tests/run_tests.gd
## Exits non-zero on failure so CI blocks a broken build.

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_rng_reference()
	_test_rng_helpers()
	_test_pieces()
	_test_board()
	_test_scoring()
	_test_bot_games_and_replays()
	print("")
	if _failures == 0:
		print("ALL %d CHECKS PASSED" % _checks)
		quit(0)
	else:
		print("%d OF %d CHECKS FAILED" % [_failures, _checks])
		quit(1)


func _check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("FAIL: " + what)


## Values computed independently in Python with arbitrary-precision ints.
func _test_rng_reference() -> void:
	var expected := {
		1: [2593460259, 2543776658, 3456840467, 3209785660, 4260460091],
		42: [182134639, 981137801, 990397809, 2648683283, 40606474],
		123456789012345: [4213421217, 51557046, 1985360401, 1291488775, 408296092],
	}
	for seed in expected:
		var r := PrismRng.new(seed)
		var got := []
		for i in 5:
			got.append(r.next_u32())
		_check(got == expected[seed], "rng seed %d -> %s" % [seed, got])
	_check(PrismRng.hash_string("prisma-daily-2026-10-19") == 2767410181, "fnv hash")


func _test_rng_helpers() -> void:
	var r := PrismRng.new(7)
	var counts := [0, 0, 0, 0, 0, 0]
	for i in 6000:
		var v := r.next_int(6)
		counts[v] += 1
		if v < 0 or v >= 6:
			_check(false, "next_int range")
	for c in counts:
		_check(c > 850 and c < 1150, "next_int roughly uniform %s" % [counts])
	var a := PrismRng.new(99)
	var b := PrismRng.new(99)
	b.set_state(a.get_state())
	_check(a.next_u32() == b.next_u32(), "state round trip")


func _test_pieces() -> void:
	var ids := {}
	for s in PrismPieces.all():
		_check(not ids.has(s.id), "unique piece id " + s.id)
		ids[s.id] = true
		_check(s.size == s.cells.size() and s.size > 0, "piece size " + s.id)
		var mx := 0
		var my := 0
		for c in s.cells:
			mx = maxi(mx, c.x)
			my = maxi(my, c.y)
		_check(mx + 1 == s.w and my + 1 == s.h, "piece bounds " + s.id)


func _test_board() -> void:
	var b := PrismBoard.new()
	var row := PrismPieces.get_shape(PrismPieces.index_of("i4h"))
	b.place(row, 2, 0, 3)
	_check(not b.can_place(row, 2, 3), "overlap rejected")
	_check(b.can_place(row, 4, 3), "adjacent allowed")
	_check(not b.can_place(row, 5, 3), "out of bounds rejected")
	_check(b.lines_completed_by(row, 4, 3) == 1, "line completion preview")
	b.place(row, 2, 4, 3)
	_check(b.full_rows() == [3], "full row detected")
	_check(b.line_color(true, 3) == 2, "prism row colour")
	_check(b.clear_full_lines() == 1 and b.is_clear(), "line cleared")


func _test_scoring() -> void:
	# Build a controlled game: craft the board then play a move by hand.
	var g := PrismGame.new(5)
	g.board = PrismBoard.new()
	var i4 := PrismPieces.index_of("i4h")
	g.board.place(PrismPieces.get_shape(i4), 3, 0, 0)
	g.hand = [{"shape": i4, "color": 3}, {"shape": i4, "color": 1}, {"shape": PrismPieces.index_of("dot"), "color": 1}]
	var ev := g.place(0, 4, 0)
	_check(ev.ok and ev.lines == 1 and ev.prisms == 1, "prism single clear")
	# 4 placed + (80 line + 160 prism) * x1 (combo 1) ... + perfect clear
	_check(ev.perfect, "perfect clear detected")
	_check(ev.gained == 4 + (80 + 160 + 2400), "score maths %d" % ev.gained)
	_check(g.combo == 1, "combo started")
	g.place(2, 0, 7)
	g.place(1, 0, 6)
	_check(g.combo == 1 and g.combo_left() == 1, "combo grace counting")


func _bot_move(g: PrismGame, rng: PrismRng) -> Array:
	# Greedy bot with a dash of randomness: tries each slot, keeps the best.
	var best := []
	var best_score := -1
	for slot in g.hand.size():
		var shape := g.shape_in_slot(slot)
		if shape.is_empty():
			continue
		var spot := PrismDealer.best_spot(g.board, shape)
		if spot.ok:
			var s: int = spot.score + rng.next_int(40)
			if s > best_score:
				best_score = s
				best = [slot, spot.pos.x, spot.pos.y]
	return best


func _test_bot_games_and_replays() -> void:
	var total_score := 0
	var total_moves := 0
	var max_score := 0
	var games := 40
	for n in games:
		var seed := 1000 + n * 7919
		var g := PrismGame.new(seed)
		var bot_rng := PrismRng.new(seed ^ 0xABCDEF)
		var guard := 0
		while not g.game_over and guard < 3000:
			guard += 1
			var m := _bot_move(g, bot_rng)
			_check(not m.is_empty(), "bot found a move when not game over")
			if m.is_empty():
				break
			var ev := g.place(m[0], m[1], m[2])
			_check(ev.ok, "bot move legal")
			if ev.dealt:
				var any := false
				for s in g.hand.size():
					any = any or g.slot_playable(s)
				_check(any, "fresh hand always has a playable piece")
		total_score += g.score
		total_moves += g.moves.size()
		max_score = maxi(max_score, g.score)
		# Replay must reproduce the exact same game.
		var replay := g.to_replay()
		var json := JSON.stringify(replay)
		var parsed: Dictionary = JSON.parse_string(json)
		var g2 := PrismGame.from_replay(parsed)
		_check(g2.score == g.score, "replay score seed %d" % seed)
		_check(g2.checksum() == g.checksum(), "replay checksum seed %d" % seed)
		_check(g2.game_over == g.game_over, "replay game over seed %d" % seed)
	print("bot: %d games, avg score %d, avg moves %d, best %d" % [games, total_score / games, total_moves / games, max_score])

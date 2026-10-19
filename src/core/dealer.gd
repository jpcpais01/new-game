class_name PrismDealer
extends RefCounted
## Decides which three pieces the player gets next.
##
## A good dealer is the difference between a block puzzle that feels fair and
## one that feels rigged. This one:
##  * always deals at least one piece that fits,
##  * early on, makes sure the whole hand can be played,
##  * sometimes slips in a piece that completes a line ("assist"), more often
##    when the board is crowded, so comebacks happen,
##  * slowly raises the share of awkward shapes as the run goes on,
##  * groups colours so single-colour Prism lines are achievable on purpose.
## Everything is driven by the seeded PrismRng, so a seed fully determines it.

const HAND := 3
const MAX_ATTEMPTS := 8


static func deal(board: PrismBoard, rng: PrismRng, deal_no: int) -> Array:
	var shapes := PrismPieces.all()
	var fullness := board.filled_count()
	var weights := _weights(shapes, fullness, deal_no)

	# Chance the whole hand is guaranteed playable. Generous at first, then
	# eases off so long runs eventually end through tough hands.
	var fair_pct := clampi(100 - deal_no * 2, 45, 100)
	# Chance each slot is an "assist" piece that completes a line.
	var assist_pct := 12 + (fullness * 30) / 64
	if deal_no < 3:
		assist_pct += 10

	var want_full_fit := rng.chance(fair_pct)
	var hand: Array = []
	for attempt in MAX_ATTEMPTS:
		hand = _draw_hand(board, rng, shapes, weights, assist_pct)
		if want_full_fit:
			if _hand_playable(board, hand):
				break
		elif _any_fits(board, hand):
			break

	if not _any_fits(board, hand):
		# Last resort: swap the first slot for the biggest shape that fits.
		var order: Array = range(shapes.size())
		rng.shuffle(order)
		order.sort_custom(func(a, b): return shapes[a].size > shapes[b].size)
		for idx in order:
			if board.fits_anywhere(shapes[idx]):
				hand[0].shape = idx
				break

	_color_hand(rng, hand)
	return hand


static func _weights(shapes: Array, fullness: int, deal_no: int) -> Array:
	var out := []
	var ramp := mini(deal_no, 30)
	for s in shapes:
		var w: int = s.weight * 12
		match s.tier:
			1:
				w = w * (12 + ramp / 3) / 12
			2:
				w = w * (8 + ramp / 2) / 12
		# Mercy: crowded boards see fewer huge pieces.
		if fullness > 34 and s.size >= 5:
			w = w * 2 / 3
		if fullness > 44 and s.size >= 5:
			w = w / 2
		out.append(maxi(1, w))
	return out


static func _draw_hand(board: PrismBoard, rng: PrismRng, shapes: Array, weights: Array, assist_pct: int) -> Array:
	var hand: Array = []
	var sim := board.duplicate_board()
	for slot in HAND:
		var idx := rng.pick_weighted(weights)
		if rng.chance(assist_pct):
			var best_lines := 0
			for k in 5:
				var cand := rng.pick_weighted(weights)
				var spot := best_spot(sim, shapes[cand])
				if spot.lines > best_lines:
					best_lines = spot.lines
					idx = cand
		hand.append({"shape": idx, "color": 0})
		# Play it greedily on the simulation so later slots react to it.
		var s := best_spot(sim, shapes[idx])
		if s.ok:
			sim.place(shapes[idx], 1, s.pos.x, s.pos.y)
			sim.clear_full_lines()
	return hand


static func _color_hand(rng: PrismRng, hand: Array) -> void:
	for i in hand.size():
		if i > 0 and rng.chance(45):
			hand[i].color = hand[rng.next_int(i)].color
		else:
			hand[i].color = 1 + rng.next_int(PrismPieces.COLORS)


static func _any_fits(board: PrismBoard, hand: Array) -> bool:
	for p in hand:
		if board.fits_anywhere(PrismPieces.get_shape(p.shape)):
			return true
	return false


## True if some order of the hand can be fully played (greedy placement).
static func _hand_playable(board: PrismBoard, hand: Array) -> bool:
	var orders := [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
	for order in orders:
		var sim := board.duplicate_board()
		var ok := true
		for i in order:
			var shape := PrismPieces.get_shape(hand[i].shape)
			var s := best_spot(sim, shape)
			if not s.ok:
				ok = false
				break
			sim.place(shape, 1, s.pos.x, s.pos.y)
			sim.clear_full_lines()
		if ok:
			return true
	return false


## Best origin for a shape: most lines completed, then closest to a corner /
## edge (keeps the board tidy). {ok, pos, lines}.
static func best_spot(board: PrismBoard, shape: Dictionary) -> Dictionary:
	var best := {"ok": false, "pos": Vector2i.ZERO, "lines": -1, "score": -1}
	for y in PrismBoard.SIZE - shape.h + 1:
		for x in PrismBoard.SIZE - shape.w + 1:
			if not board.can_place(shape, x, y):
				continue
			var lines := board.lines_completed_by(shape, x, y)
			var edge := 0
			for c in shape.cells:
				var cx: int = x + c.x
				var cy: int = y + c.y
				if cx == 0 or cx == PrismBoard.SIZE - 1 or not board.is_empty_at(cx - 1, cy) or not board.is_empty_at(cx + 1, cy):
					edge += 1
				if cy == 0 or cy == PrismBoard.SIZE - 1 or not board.is_empty_at(cx, cy - 1) or not board.is_empty_at(cx, cy + 1):
					edge += 1
			var score := lines * 1000 + edge
			if score > best.score:
				best = {"ok": true, "pos": Vector2i(x, y), "lines": lines, "score": score}
	return best

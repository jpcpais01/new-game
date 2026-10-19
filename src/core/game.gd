class_name PrismGame
extends RefCounted
## One run of Prisma: the complete, deterministic rules of the game.
##
## No nodes, no rendering, no clock. Given a seed and a list of moves this
## class always produces exactly the same game, so a run can be saved as
## {seed, moves}, resumed, replayed, verified or shared. The view layer asks
## for moves through `place()` and animates the event dictionary it returns.

const RULES_VERSION := 1

const PLACE_POINTS := 1          # per cell placed
const LINE_POINTS := 80          # per line, scaled by a triangular multi-line bonus
const PRISM_POINTS := 160        # extra per single-colour line
const PERFECT_POINTS := 2400     # board fully cleared
const COMBO_GRACE := 3           # placements a combo survives without a clear
const COMBO_MULT_CAP := 19       # multiplier tops out at x10

var seed_value: int
var mode: String
var rng: PrismRng
var board: PrismBoard
var hand: Array = []             # HAND slots: {shape, color} or null once used
var score := 0
var combo := 0                   # current streak of clearing placements
var moves_since_clear := 0       # placements since the last clear
var deal_no := 0
var game_over := false
var moves: Array = []            # [[slot, x, y], ...] - the replay
var stats := {
	"lines": 0,
	"best_combo": 0,
	"prisms": 0,
	"perfects": 0,
	"pieces": 0,
	"best_move": 0,
}


func _init(p_seed: int, p_mode: String = "classic") -> void:
	seed_value = p_seed
	mode = p_mode
	rng = PrismRng.new(p_seed)
	board = PrismBoard.new()
	_deal()


static func from_replay(data: Dictionary) -> PrismGame:
	var g := PrismGame.new(int(data.seed), str(data.get("mode", "classic")))
	for m in data.get("moves", []):
		var ev := g.place(int(m[0]), int(m[1]), int(m[2]))
		if not ev.ok:
			push_warning("Replay diverged at move %d" % g.moves.size())
			break
	return g


func to_replay() -> Dictionary:
	return {
		"v": RULES_VERSION,
		"seed": seed_value,
		"mode": mode,
		"moves": moves.duplicate(true),
		"score": score,
		"checksum": checksum(),
	}


func shape_in_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= hand.size() or hand[slot] == null:
		return {}
	return PrismPieces.get_shape(hand[slot].shape)


func can_place(slot: int, x: int, y: int) -> bool:
	if game_over:
		return false
	var shape := shape_in_slot(slot)
	return not shape.is_empty() and board.can_place(shape, x, y)


func slot_playable(slot: int) -> bool:
	var shape := shape_in_slot(slot)
	return not shape.is_empty() and board.fits_anywhere(shape)


## Lines that WOULD clear, for the drag preview. {rows, cols, prism_rows, prism_cols}
func preview(slot: int, x: int, y: int) -> Dictionary:
	var out := {"rows": [], "cols": [], "prism_rows": [], "prism_cols": []}
	if not can_place(slot, x, y):
		return out
	var sim := board.duplicate_board()
	sim.place(shape_in_slot(slot), hand[slot].color, x, y)
	out.rows = sim.full_rows()
	out.cols = sim.full_cols()
	for r in out.rows:
		if sim.line_color(true, r) != 0:
			out.prism_rows.append(r)
	for c in out.cols:
		if sim.line_color(false, c) != 0:
			out.prism_cols.append(c)
	return out


## Play the piece in `slot` with its top-left at (x, y). Returns an event
## dictionary describing everything that happened (ok=false if illegal).
func place(slot: int, x: int, y: int) -> Dictionary:
	if not can_place(slot, x, y):
		return {"ok": false}
	var piece: Dictionary = hand[slot]
	var shape := PrismPieces.get_shape(piece.shape)
	var color: int = piece.color

	var placed := board.place(shape, color, x, y)
	hand[slot] = null
	moves.append([slot, x, y])
	stats.pieces += 1

	var rows := board.full_rows()
	var cols := board.full_cols()
	var prism_rows: Array[int] = []
	var prism_cols: Array[int] = []
	for r in rows:
		if board.line_color(true, r) != 0:
			prism_rows.append(r)
	for c in cols:
		if board.line_color(false, c) != 0:
			prism_cols.append(c)

	# Snapshot the cells that are about to vanish (for the view's effects).
	var cleared := []
	var seen := {}
	for r in rows:
		for cx in PrismBoard.SIZE:
			var k: int = r * PrismBoard.SIZE + cx
			if not seen.has(k):
				seen[k] = true
				cleared.append({"pos": Vector2i(cx, r), "color": board.cells[k]})
	for c in cols:
		for cy in PrismBoard.SIZE:
			var k: int = cy * PrismBoard.SIZE + c
			if not seen.has(k):
				seen[k] = true
				cleared.append({"pos": Vector2i(c, cy), "color": board.cells[k]})

	var lines := rows.size() + cols.size()
	var prisms := prism_rows.size() + prism_cols.size()
	var place_pts: int = shape.size * PLACE_POINTS
	var clear_pts := 0
	var mult_x2 := 2
	var perfect := false

	if lines > 0:
		board.clear_full_lines()
		combo += 1
		moves_since_clear = 0
		var base := LINE_POINTS * lines * (lines + 1) / 2 + PRISM_POINTS * prisms
		perfect = board.is_clear()
		if perfect:
			base += PERFECT_POINTS
		mult_x2 = 1 + mini(combo, COMBO_MULT_CAP)
		clear_pts = base * mult_x2 / 2
		stats.lines += lines
		stats.prisms += prisms
		stats.best_combo = maxi(stats.best_combo, combo)
		if perfect:
			stats.perfects += 1
	else:
		moves_since_clear += 1
		if moves_since_clear >= COMBO_GRACE:
			combo = 0

	var gained: int = place_pts + clear_pts
	score += gained
	stats.best_move = maxi(stats.best_move, gained)

	var dealt := false
	if hand.all(func(p): return p == null):
		_deal()
		dealt = true

	game_over = not _any_playable()

	return {
		"ok": true,
		"slot": slot,
		"shape": piece.shape,
		"color": color,
		"origin": Vector2i(x, y),
		"placed": placed,
		"rows": rows,
		"cols": cols,
		"prism_rows": prism_rows,
		"prism_cols": prism_cols,
		"cleared": cleared,
		"lines": lines,
		"prisms": prisms,
		"perfect": perfect,
		"place_points": place_pts,
		"clear_points": clear_pts,
		"gained": gained,
		"combo": combo,
		"mult_x2": mult_x2,
		"combo_left": 0 if combo == 0 else COMBO_GRACE - moves_since_clear,
		"score": score,
		"dealt": dealt,
		"game_over": game_over,
	}


func combo_left() -> int:
	return 0 if combo == 0 else COMBO_GRACE - moves_since_clear


func checksum() -> int:
	var h := board.checksum()
	h = PrismRng.mix32(h ^ (score & PrismRng.MASK32))
	h = PrismRng.mix32(h ^ combo ^ (moves.size() << 8))
	for p in hand:
		h = PrismRng.mix32(h ^ (0xFFFF if p == null else (p.shape << 4 | p.color)))
	return h


func _deal() -> void:
	hand = PrismDealer.deal(board, rng, deal_no)
	deal_no += 1


func _any_playable() -> bool:
	for i in hand.size():
		if slot_playable(i):
			return true
	return false

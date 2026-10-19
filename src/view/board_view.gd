class_name BoardView
extends Node2D
## Draws the 8x8 board: recessed slots, gems, the drag ghost, the glowing
## "these lines will clear" preview, and every per-cell animation.
## Purely visual: it mirrors the logic board and never changes game state.

const N := PrismBoard.SIZE
const PAD := 22.0

var cell := 120.0
var cells := PackedInt32Array()
var pop := PackedFloat32Array()      # seconds left on each cell's pop
var pop_delay := PackedFloat32Array()
var dying: Array = []                # {pos, color, delay, t, spin}
var dim := PackedFloat32Array()      # game-over greying, 0..1 per cell

var ghost_shape := {}
var ghost_origin := Vector2i.ZERO
var ghost_color := 1
var preview_rows: Array = []
var preview_cols: Array = []
var preview_prism_rows: Array = []
var preview_prism_cols: Array = []

var _t := 0.0
var _panel := StyleBoxFlat.new()


func _ready() -> void:
	cells.resize(N * N)
	pop.resize(N * N)
	pop_delay.resize(N * N)
	dim.resize(N * N)
	_panel.bg_color = PrismPalette.PANEL
	_panel.border_color = PrismPalette.PANEL_EDGE
	_panel.set_border_width_all(3)
	_panel.set_corner_radius_all(34)
	_panel.shadow_color = Color(0, 0, 0, 0.45)
	_panel.shadow_size = 40
	_panel.shadow_offset = Vector2(0, 14)
	_panel.anti_aliasing = true


func size_px() -> float:
	return cell * N


func sync(board: PrismBoard) -> void:
	cells = board.cells.duplicate()
	queue_redraw()


func cell_rect(x: int, y: int) -> Rect2:
	return Rect2(x * cell, y * cell, cell, cell)


func cell_center(p: Vector2i) -> Vector2:
	return Vector2((p.x + 0.5) * cell, (p.y + 0.5) * cell)


func set_ghost(shape: Dictionary, origin: Vector2i, color: int, pv: Dictionary) -> void:
	ghost_shape = shape
	ghost_origin = origin
	ghost_color = color
	preview_rows = pv.get("rows", [])
	preview_cols = pv.get("cols", [])
	preview_prism_rows = pv.get("prism_rows", [])
	preview_prism_cols = pv.get("prism_cols", [])


func clear_ghost() -> void:
	ghost_shape = {}
	preview_rows = []
	preview_cols = []
	preview_prism_rows = []
	preview_prism_cols = []


## Newly placed cells bounce in.
func animate_place(placed: Array) -> void:
	for i in placed.size():
		var p: Vector2i = placed[i]
		var k := p.y * N + p.x
		pop[k] = 0.32
		pop_delay[k] = i * 0.012


## Cleared cells flash, then shatter outward from `origin` in a wave.
func animate_clear(cleared: Array, origin: Vector2) -> float:
	var longest := 0.0
	for c in cleared:
		var d := (cell_center(c.pos) - origin).length() / cell
		var delay := 0.04 + d * 0.035
		longest = maxf(longest, delay)
		dying.append({"pos": c.pos, "color": c.color, "delay": delay, "t": 0.0,
				"spin": (1.0 if (c.pos.x + c.pos.y) % 2 == 0 else -1.0)})
	return longest


func reset_dim() -> void:
	dim.fill(0.0)


func set_dim(k: int, v: float) -> void:
	dim[k] = v


func _process(delta: float) -> void:
	_t += delta
	for k in N * N:
		if pop_delay[k] > 0.0:
			pop_delay[k] -= delta
		elif pop[k] > 0.0:
			pop[k] = maxf(0.0, pop[k] - delta)
	var i := dying.size() - 1
	while i >= 0:
		var d: Dictionary = dying[i]
		if d.delay > 0.0:
			d.delay -= delta
		else:
			d.t += delta
			if d.t > 0.42:
				dying.remove_at(i)
		i -= 1
	queue_redraw()


func _draw() -> void:
	var s := size_px()
	draw_style_box(_panel, Rect2(-PAD, -PAD, s + PAD * 2, s + PAD * 2))

	var slot_tex := Art.slot()
	for y in N:
		for x in N:
			draw_texture_rect(slot_tex, cell_rect(x, y).grow(-cell * 0.02), false)

	var in_preview := {}
	for r in preview_rows:
		for x in N:
			in_preview[r * N + x] = preview_prism_rows.has(r)
	for c in preview_cols:
		for y in N:
			var k: int = y * N + c
			in_preview[k] = in_preview.get(k, false) or preview_prism_cols.has(c)

	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	# Settled gems.
	for y in N:
		for x in N:
			var k := y * N + x
			var v := cells[k]
			if v == 0:
				continue
			var r := cell_rect(x, y)
			var sc := 1.0
			if pop[k] > 0.0 and pop_delay[k] <= 0.0:
				var t := 1.0 - pop[k] / 0.32
				sc = 1.0 + 0.22 * sin(t * PI) * (1.0 - t)
			r = _scaled(r, sc * 0.97)
			if in_preview.has(k):
				_draw_preview_cell(r, k, in_preview[k], pulse)
			else:
				var m := Color.WHITE
				if dim[k] > 0.0:
					var g := 0.35
					m = Color(1, 1, 1).lerp(Color(g, g, g * 1.25, 1), dim[k])
				draw_texture_rect(Art.gem(v), r, false, m)
				if pop[k] > 0.0 and pop_delay[k] <= 0.0:
					var f := pop[k] / 0.32
					draw_texture_rect(Art.white(), r, false, Color(1, 1, 1, f * f * 0.7))

	# Ghost of the piece being dragged.
	if not ghost_shape.is_empty():
		var col := PrismPalette.gem(ghost_color)
		for c in ghost_shape.cells:
			var p: Vector2i = ghost_origin + c
			var r := _scaled(cell_rect(p.x, p.y), 0.97)
			var k := p.y * N + p.x
			if in_preview.has(k):
				_draw_preview_cell(r, k, in_preview[k], pulse)
			else:
				draw_texture_rect(Art.gem(ghost_color), r, false, Color(1, 1, 1, 0.42))
				draw_texture_rect(Art.ghost(), r, false, Color(col.r, col.g, col.b, 0.85))

	# Shattering gems.
	for d in dying:
		if d.delay > 0.0:
			# Waiting for the wave: glow white so the line reads as "going".
			var r := _scaled(cell_rect(d.pos.x, d.pos.y), 0.97)
			draw_texture_rect(Art.gem(d.color), r, false)
			draw_texture_rect(Art.white(), r, false, Color(1, 1, 1, 0.55))
			continue
		var t: float = d.t / 0.42
		var e := t * t
		var center := cell_center(d.pos)
		var size := cell * 0.97 * (1.0 + 0.25 * sin(minf(t * 2.0, 1.0) * PI) - e)
		if size <= 1.0:
			continue
		draw_set_transform(center, d.spin * e * 1.6, Vector2.ONE)
		var rr := Rect2(-size / 2, -size / 2, size, size)
		draw_texture_rect(Art.gem(d.color), rr, false, Color(1, 1, 1, 1.0 - e * 0.5))
		draw_texture_rect(Art.white(), rr, false, Color(1, 1, 1, maxf(0.0, 0.9 - t * 1.6)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_preview_cell(r: Rect2, k: int, prism: bool, pulse: float) -> void:
	var color := ghost_color
	if prism:
		var x := k % N
		var y := k / N
		color = 1 + int(floor(_t * 10.0 + x + y)) % PrismPieces.COLORS
	draw_texture_rect(Art.gem(color), r, false)
	draw_texture_rect(Art.white(), r, false, Color(1, 1, 1, 0.12 + 0.22 * pulse))


func _scaled(r: Rect2, sc: float) -> Rect2:
	var c := r.get_center()
	var sz := r.size * sc
	return Rect2(c - sz / 2, sz)

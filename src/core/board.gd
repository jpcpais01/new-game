class_name PrismBoard
extends RefCounted
## The 8x8 grid. 0 = empty, 1..COLORS = a gem of that colour.

const SIZE := 8

var cells := PackedInt32Array()


func _init() -> void:
	cells.resize(SIZE * SIZE)
	cells.fill(0)


func duplicate_board() -> PrismBoard:
	var b := PrismBoard.new()
	b.cells = cells.duplicate()
	return b


func get_cell(x: int, y: int) -> int:
	return cells[y * SIZE + x]


func set_cell(x: int, y: int, v: int) -> void:
	cells[y * SIZE + x] = v


func is_empty_at(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < SIZE and y < SIZE and cells[y * SIZE + x] == 0


func filled_count() -> int:
	var n := 0
	for v in cells:
		if v != 0:
			n += 1
	return n


func is_clear() -> bool:
	for v in cells:
		if v != 0:
			return false
	return true


func can_place(shape: Dictionary, ox: int, oy: int) -> bool:
	if ox < 0 or oy < 0 or ox + shape.w > SIZE or oy + shape.h > SIZE:
		return false
	for c in shape.cells:
		if cells[(oy + c.y) * SIZE + ox + c.x] != 0:
			return false
	return true


## Every origin where the shape fits.
func placements(shape: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in SIZE - shape.h + 1:
		for x in SIZE - shape.w + 1:
			if can_place(shape, x, y):
				out.append(Vector2i(x, y))
	return out


func fits_anywhere(shape: Dictionary) -> bool:
	for y in SIZE - shape.h + 1:
		for x in SIZE - shape.w + 1:
			if can_place(shape, x, y):
				return true
	return false


func place(shape: Dictionary, color: int, ox: int, oy: int) -> Array[Vector2i]:
	var placed: Array[Vector2i] = []
	for c in shape.cells:
		var p := Vector2i(ox + c.x, oy + c.y)
		cells[p.y * SIZE + p.x] = color
		placed.append(p)
	return placed


func full_rows() -> Array[int]:
	var out: Array[int] = []
	for y in SIZE:
		var full := true
		for x in SIZE:
			if cells[y * SIZE + x] == 0:
				full = false
				break
		if full:
			out.append(y)
	return out


func full_cols() -> Array[int]:
	var out: Array[int] = []
	for x in SIZE:
		var full := true
		for y in SIZE:
			if cells[y * SIZE + x] == 0:
				full = false
				break
		if full:
			out.append(x)
	return out


## Colour shared by every cell of a row/column, or 0 if mixed.
func line_color(is_row: bool, i: int) -> int:
	var first := cells[i * SIZE] if is_row else cells[i]
	for k in SIZE:
		var v := cells[i * SIZE + k] if is_row else cells[k * SIZE + i]
		if v != first:
			return 0
	return first


## How many rows + columns would be completed by placing shape at origin.
## Assumes the placement is legal. Does not modify the board.
func lines_completed_by(shape: Dictionary, ox: int, oy: int) -> int:
	var rows := {}
	var cols := {}
	for c in shape.cells:
		rows[oy + c.y] = true
		cols[ox + c.x] = true
	var occupied := {}
	for c in shape.cells:
		occupied[(oy + c.y) * SIZE + ox + c.x] = true
	var n := 0
	for y in rows:
		var full := true
		for x in SIZE:
			var idx: int = y * SIZE + x
			if cells[idx] == 0 and not occupied.has(idx):
				full = false
				break
		if full:
			n += 1
	for x in cols:
		var full := true
		for y in SIZE:
			var idx: int = y * SIZE + x
			if cells[idx] == 0 and not occupied.has(idx):
				full = false
				break
		if full:
			n += 1
	return n


## Removes every full row and column at once. Returns how many lines went.
func clear_full_lines() -> int:
	var rows := full_rows()
	var cols := full_cols()
	for y in rows:
		for x in SIZE:
			cells[y * SIZE + x] = 0
	for x in cols:
		for y in SIZE:
			cells[y * SIZE + x] = 0
	return rows.size() + cols.size()


## Stable 32-bit fingerprint of the grid (used by replay verification).
func checksum() -> int:
	var h := 0x811C9DC5
	for v in cells:
		h ^= v & 0xFF
		h = PrismRng.mul32(h, 0x01000193)
	return h


func to_array() -> Array:
	return Array(cells)


func from_array(arr: Array) -> void:
	for i in mini(arr.size(), cells.size()):
		cells[i] = int(arr[i])

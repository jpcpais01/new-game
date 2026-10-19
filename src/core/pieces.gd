class_name PrismPieces
extends RefCounted
## The catalogue of piece shapes. Pure data, no rendering.
##
## Each shape is drawn as a little ASCII grid so the set is easy to read and
## tune. `weight` is the relative chance the dealer picks it (per
## orientation), `tier` groups shapes by how awkward they are to fit.

const COLORS := 6  # Number of gem colours a piece can have (1..COLORS).

# [id, weight, tier, rows]
const _DEFS := [
	["dot", 3, 0, ["#"]],
	["i2h", 5, 0, ["##"]],
	["i2v", 5, 0, ["#", "#"]],
	["d2a", 2, 1, ["#.", ".#"]],
	["d2b", 2, 1, [".#", "#."]],
	["i3h", 6, 0, ["###"]],
	["i3v", 6, 0, ["#", "#", "#"]],
	["v3a", 4, 0, ["##", "#."]],
	["v3b", 4, 0, ["##", ".#"]],
	["v3c", 4, 0, ["#.", "##"]],
	["v3d", 4, 0, [".#", "##"]],
	["o2", 8, 0, ["##", "##"]],
	["i4h", 4, 1, ["####"]],
	["i4v", 4, 1, ["#", "#", "#", "#"]],
	["t4a", 2, 1, ["###", ".#."]],
	["t4b", 2, 1, [".#.", "###"]],
	["t4c", 2, 1, ["#.", "##", "#."]],
	["t4d", 2, 1, [".#", "##", ".#"]],
	["l4a", 2, 1, ["#.", "#.", "##"]],
	["l4b", 2, 1, ["###", "#.."]],
	["l4c", 2, 1, ["##", ".#", ".#"]],
	["l4d", 2, 1, ["..#", "###"]],
	["j4a", 2, 1, [".#", ".#", "##"]],
	["j4b", 2, 1, ["#..", "###"]],
	["j4c", 2, 1, ["##", "#.", "#."]],
	["j4d", 2, 1, ["###", "..#"]],
	["s4h", 1, 2, [".##", "##."]],
	["s4v", 1, 2, ["#.", "##", ".#"]],
	["z4h", 1, 2, ["##.", ".##"]],
	["z4v", 1, 2, [".#", "##", "#."]],
	["i5h", 2, 2, ["#####"]],
	["i5v", 2, 2, ["#", "#", "#", "#", "#"]],
	["r6h", 3, 1, ["###", "###"]],
	["r6v", 3, 1, ["##", "##", "##"]],
	["c5a", 1, 2, ["###", "#..", "#.."]],
	["c5b", 1, 2, ["###", "..#", "..#"]],
	["c5c", 1, 2, ["#..", "#..", "###"]],
	["c5d", 1, 2, ["..#", "..#", "###"]],
	["o3", 2, 2, ["###", "###", "###"]],
]

static var _shapes: Array = []


## All shapes. Each entry: {id, index, cells: Array[Vector2i], w, h, size,
## weight, tier}. Index order is stable and is what replays store.
static func all() -> Array:
	if _shapes.is_empty():
		for i in _DEFS.size():
			var d: Array = _DEFS[i]
			var rows: Array = d[3]
			var cells: Array[Vector2i] = []
			var w := 0
			for y in rows.size():
				var row: String = rows[y]
				w = maxi(w, row.length())
				for x in row.length():
					if row[x] == "#":
						cells.append(Vector2i(x, y))
			_shapes.append({
				"id": d[0],
				"index": i,
				"weight": d[1],
				"tier": d[2],
				"cells": cells,
				"w": w,
				"h": rows.size(),
				"size": cells.size(),
			})
	return _shapes


static func count() -> int:
	return all().size()


static func get_shape(index: int) -> Dictionary:
	return all()[index]


static func index_of(id: String) -> int:
	for s in all():
		if s.id == id:
			return s.index
	return -1

class_name DragView
extends Node2D
## Draws the piece under the player's finger (lifted, with a soft shadow and
## a halo when it would snap) and pieces flying back to the tray.

var active := false
var shape := {}
var color := 1
var center := Vector2.ZERO       # smoothed draw position
var cell := 100.0
var scale_now := 0.5
var valid := false
var flying: Array = []           # {shape, color, from, to, s0, s1, t, slot}
var _t := 0.0

signal returned(slot: int)


func fly_back(p_shape: Dictionary, p_color: int, from: Vector2, to: Vector2, s0: float, s1: float, slot: int) -> void:
	flying.append({"shape": p_shape, "color": p_color, "from": from, "to": to, "s0": s0, "s1": s1, "t": 0.0, "slot": slot})


func _process(delta: float) -> void:
	_t += delta
	var i := flying.size() - 1
	while i >= 0:
		var f: Dictionary = flying[i]
		f.t += delta / 0.22
		if f.t >= 1.0:
			flying.remove_at(i)
			returned.emit(f.slot)
		i -= 1
	queue_redraw()


func _draw() -> void:
	for f in flying:
		var e := 1.0 - pow(1.0 - f.t, 3.0)
		var c: Vector2 = f.from.lerp(f.to, e)
		_draw_piece(f.shape, f.color, c, cell * lerpf(f.s0, f.s1, e), false, 1.0)
	if active and not shape.is_empty():
		var c := cell * scale_now
		# Shadow
		var size := Vector2(shape.w, shape.h) * c
		for cc in shape.cells:
			var r := Rect2(center - size / 2.0 + Vector2(cc.x, cc.y) * c + Vector2(0, c * 0.28), Vector2(c, c)).grow(-c * 0.06)
			draw_texture_rect(Art.white(), r, false, Color(0, 0, 0, 0.28))
		if valid:
			var g := PrismPalette.gem(color)
			g.a = 0.18 + 0.08 * sin(_t * 8.0)
			for cc in shape.cells:
				var r := Rect2(center - size / 2.0 + Vector2(cc.x, cc.y) * c, Vector2(c, c)).grow(c * 0.12)
				draw_texture_rect(Art.white(), r, false, g)
		_draw_piece(shape, color, center, c, true, 1.0)


func _draw_piece(p_shape: Dictionary, p_color: int, c_pos: Vector2, c: float, lifted: bool, alpha: float) -> void:
	var size := Vector2(p_shape.w, p_shape.h) * c
	var tl := c_pos - size / 2.0
	for cc in p_shape.cells:
		var r := Rect2(tl + Vector2(cc.x, cc.y) * c, Vector2(c, c)).grow(-c * 0.015)
		draw_texture_rect(Art.gem(p_color), r, false, Color(1, 1, 1, alpha))

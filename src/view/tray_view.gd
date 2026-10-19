class_name TrayView
extends Node2D
## The three pieces waiting below the board. Handles the deal animation,
## the idle float, and greys out pieces that no longer fit anywhere.

var width := 1000.0
var height := 260.0
var cell := 60.0
var hand: Array = []
var playable: Array = [true, true, true]
var hidden_slots := {}               # slots not drawn (being dragged / flying)
var _appear := [9.0, 9.0, 9.0]
var _grey := [0.0, 0.0, 0.0]
var _t := 0.0


func slot_center(i: int) -> Vector2:
	return Vector2(width * (i + 0.5) / 3.0, height * 0.5)


func slot_at(local: Vector2) -> int:
	if local.y < -height * 0.35 or local.y > height * 1.35:
		return -1
	var i := int(floor(local.x / (width / 3.0)))
	if i < 0 or i > 2:
		return -1
	return i


func set_hand(new_hand: Array, new_playable: Array, animate: bool) -> void:
	hand = new_hand.duplicate(true)
	playable = new_playable.duplicate()
	if animate:
		for i in 3:
			_appear[i] = -0.08 * i
	queue_redraw()


func set_playable(new_playable: Array) -> void:
	playable = new_playable.duplicate()


func clear_slot(i: int) -> void:
	if i >= 0 and i < hand.size():
		hand[i] = null


func _process(delta: float) -> void:
	_t += delta
	for i in 3:
		_appear[i] += delta
		var target := 0.0 if (i < playable.size() and playable[i]) else 1.0
		_grey[i] = move_toward(_grey[i], target, delta * 4.0)
	queue_redraw()


func _draw() -> void:
	for i in hand.size():
		if hand[i] == null or hidden_slots.has(i):
			continue
		var shape := PrismPieces.get_shape(hand[i].shape)
		var color: int = hand[i].color
		var center := slot_center(i)
		var sc := 1.0
		var a := clampf(_appear[i] / 0.45, 0.0, 1.0)
		if a < 1.0:
			if _appear[i] < 0.0:
				continue
			# Fly in from the right with an overshoot.
			var e := _back_out(a)
			center.x += (1.0 - e) * width * 0.9
			sc = 0.6 + 0.4 * e
		else:
			center.y += sin(_t * 2.2 + i * 2.1) * 4.0
		var c := cell * sc
		var origin := center - Vector2(shape.w, shape.h) * c / 2.0
		var g: float = _grey[i]
		var mod := Color(1, 1, 1).lerp(Color(0.38, 0.36, 0.48, 0.65), g)
		for cc in shape.cells:
			var r := Rect2(origin + Vector2(cc.x, cc.y) * c, Vector2(c, c)).grow(-c * 0.02)
			draw_texture_rect(Art.gem(color), r, false, mod)


static func _back_out(t: float) -> float:
	var c1 := 1.4
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)

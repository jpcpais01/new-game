class_name HintView
extends Node2D
## First-game tutorial: a ghostly finger drags the first piece from the tray
## to a good spot on the board, over and over, until the player tries it.

var from := Vector2.ZERO
var to := Vector2.ZERO
var shape := {}
var color := 1
var cell := 100.0
var tray_cell := 50.0
var _t := 0.0
var _alpha := 0.0
var _dismissed := false


func setup(p_shape: Dictionary, p_color: int, p_from: Vector2, p_to: Vector2, p_cell: float, p_tray_cell: float) -> void:
	shape = p_shape
	color = p_color
	from = p_from
	to = p_to
	cell = p_cell
	tray_cell = p_tray_cell
	_t = 0.0
	_dismissed = false
	visible = true


func dismiss() -> void:
	_dismissed = true


func _process(delta: float) -> void:
	_t += delta
	_alpha = move_toward(_alpha, 0.0 if _dismissed else 1.0, delta * 3.0)
	if _dismissed and _alpha <= 0.0:
		visible = false
	queue_redraw()


func _draw() -> void:
	if shape.is_empty() or _alpha <= 0.0:
		return
	var cycle := fmod(_t, 2.6)
	var a := _alpha
	var p := 0.0
	if cycle < 0.35:
		a *= cycle / 0.35
	elif cycle < 1.55:
		var k := (cycle - 0.35) / 1.2
		p = k * k * (3.0 - 2.0 * k)
	elif cycle < 2.1:
		p = 1.0
	else:
		p = 1.0
		a *= 1.0 - (cycle - 2.1) / 0.5
	var finger := from.lerp(to + Vector2(0, shape.h * cell / 2.0 + cell * 1.15), p)
	var c := lerpf(tray_cell, cell, minf(1.0, p * 3.0))
	var lift := lerpf(0.0, shape.h * cell / 2.0 + cell * 1.15, minf(1.0, p * 3.0))
	var center := finger - Vector2(0, lift)
	var size := Vector2(shape.w, shape.h) * c
	for cc in shape.cells:
		var r := Rect2(center - size / 2.0 + Vector2(cc.x, cc.y) * c, Vector2(c, c)).grow(-c * 0.02)
		draw_texture_rect(Art.gem(color), r, false, Color(1, 1, 1, 0.5 * a))
	# Finger: a soft glowing dot with a ring.
	var press := 1.0 if (cycle > 0.25 and cycle < 1.7) else 0.0
	draw_circle(finger, 46.0, Color(1, 1, 1, 0.16 * a))
	draw_circle(finger, 30.0 - press * 4.0, Color(1, 1, 1, 0.75 * a))
	draw_arc(finger, 58.0 + press * 6.0, 0.0, TAU, 48, Color(1, 1, 1, 0.45 * a), 5.0, true)

class_name TrailArt
extends RefCounted
## Draws a ship's light trail as a tapering ribbon. Shared by the arena and
## the Hangar preview. `pts` run from the tail (oldest) to the ship.


static func draw(ci: CanvasItem, pts: PackedVector2Array, col: Color, tier: int, t: float, scale := 1.0,
		boost := 1.0) -> void:
	var n := pts.size()
	if n < 2:
		return
	_boost = boost
	match tier:
		0:
			_ribbon(ci, pts, col, 7.0 * scale, 0.45, t, false)
		1, 2:
			_ribbon(ci, pts, col, 20.0 * scale, 0.32, t, false)
			_ribbon(ci, pts, Color(1.6, 1.6, 1.6), 5.0 * scale, 0.7, t, false)
		3:
			# Helix: two braided ribbons, the second a shifted hue.
			var alt := Color.from_hsv(fmod(col.h + 0.12, 1.0), col.s, col.v)
			_ribbon(ci, _braid(pts, 13.0 * scale, t, 0.0), col, 10.0 * scale, 0.5, t, false)
			_ribbon(ci, _braid(pts, 13.0 * scale, t, PI), alt, 10.0 * scale, 0.5, t, false)
			_ribbon(ci, pts, Color(1.6, 1.6, 1.6), 4.0 * scale, 0.6, t, false)
		_:
			# Prism: every colour, flowing down the ribbon.
			_ribbon(ci, pts, col, 24.0 * scale, 0.36, t, true)
			_ribbon(ci, pts, Color(1.7, 1.7, 1.7), 5.0 * scale, 0.75, t, false)


static var _boost := 1.0


## A strip of quads whose width and alpha taper towards the tail.
static func _ribbon(ci: CanvasItem, pts: PackedVector2Array, col: Color, width: float, alpha: float, t: float,
		prism: bool) -> void:
	var n := pts.size()
	var prev_l := Vector2.ZERO
	var prev_r := Vector2.ZERO
	var prev_c := Color.TRANSPARENT
	for k in n:
		var f := float(k) / float(n - 1)
		var dir := pts[mini(k + 1, n - 1)] - pts[maxi(k - 1, 0)]
		if dir.length_squared() < 0.0001:
			dir = Vector2.RIGHT
		var nrm := dir.normalized().orthogonal()
		var w := width * (0.15 + 0.85 * f)
		var l := pts[k] + nrm * w
		var r := pts[k] - nrm * w
		var c := col
		if prism:
			c = Color.from_hsv(fmod(t * 0.6 - f * 0.8 + 1.0, 1.0), 0.6, 1.0) * 1.5
		c.a = minf(1.0, alpha * _boost) * f * sqrt(f)
		if k > 0:
			ci.draw_polygon(PackedVector2Array([prev_l, l, r, prev_r]),
					PackedColorArray([prev_c, c, c, prev_c]))
		prev_l = l
		prev_r = r
		prev_c = c


static func _braid(pts: PackedVector2Array, amp: float, t: float, phase: float) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	out.resize(n)
	for k in n:
		var dir := pts[mini(k + 1, n - 1)] - pts[maxi(k - 1, 0)]
		var nrm := dir.normalized().orthogonal() if dir.length_squared() > 0.0001 else Vector2.ZERO
		var f := float(k) / float(maxi(n - 1, 1))
		out[k] = pts[k] + nrm * sin(f * 9.0 - t * 10.0 + phase) * amp * (0.3 + 0.7 * f)
	return out

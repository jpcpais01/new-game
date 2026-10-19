class_name Fx
extends Node2D
## Cosmetic effects in world space, drawn additively: particles, shockwave
## rings, flashes, beams, lightning, dash warnings. Damage numbers live on a
## child with normal blending. View-only: free to use randf().

const MAXP := 2200
const MAX_NUMBERS := 70

var pn := 0
var p_x := PackedFloat32Array()
var p_y := PackedFloat32Array()
var p_vx := PackedFloat32Array()
var p_vy := PackedFloat32Array()
var p_life := PackedFloat32Array()
var p_max := PackedFloat32Array()
var p_size := PackedFloat32Array()
var p_drag := PackedFloat32Array()
var p_col := PackedColorArray()
var p_kind := PackedByteArray()  # 0 dot, 1 streak

var rings: Array = []
var flashes: Array = []
var beams: Array = []
var arcs: Array = []
var warns: Array = []
var numbers: Array = []

var _spark: Texture2D
var _streak: Texture2D
var _ring: Texture2D
var _glow: Texture2D
var _beam: Texture2D
var _disc: Texture2D
var _text_layer: Node2D


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	p_x.resize(MAXP); p_y.resize(MAXP); p_vx.resize(MAXP); p_vy.resize(MAXP); p_life.resize(MAXP)
	p_max.resize(MAXP); p_size.resize(MAXP); p_drag.resize(MAXP); p_col.resize(MAXP); p_kind.resize(MAXP)
	_spark = Art.tex("spark")
	_streak = Art.tex("streak")
	_ring = Art.tex("ring")
	_glow = Art.tex("glow")
	_beam = Art.tex("beam")
	_disc = Art.tex("disc")
	_text_layer = Node2D.new()
	_text_layer.z_index = 5
	_text_layer.draw.connect(_draw_numbers)
	add_child(_text_layer)


func clear() -> void:
	pn = 0
	rings.clear()
	flashes.clear()
	beams.clear()
	arcs.clear()
	warns.clear()
	numbers.clear()


# --- emitters ---------------------------------------------------------------------

func particle(x: float, y: float, vx: float, vy: float, life: float, size: float, col: Color, kind := 0,
		drag := 3.0) -> void:
	var i := pn
	if pn >= MAXP:
		i = randi() % MAXP
	else:
		pn += 1
	p_x[i] = x
	p_y[i] = y
	p_vx[i] = vx
	p_vy[i] = vy
	p_life[i] = life
	p_max[i] = life
	p_size[i] = size
	p_drag[i] = drag
	p_col[i] = col
	p_kind[i] = kind


## Radial burst of streak sparks and soft dots.
func burst(x: float, y: float, col: Color, n: int, speed: float, size := 1.0, life := 0.5) -> void:
	for k in n:
		var a := randf() * TAU
		var s := speed * (0.35 + randf() * 0.9)
		particle(x, y, cos(a) * s, sin(a) * s, life * (0.6 + randf() * 0.6), size * (0.7 + randf() * 0.6),
				col, 1, 4.0)
	for k in n / 2:
		var a := randf() * TAU
		var s := speed * 0.35 * randf()
		particle(x, y, cos(a) * s, sin(a) * s, life * 1.4 * (0.6 + randf() * 0.5), size * (1.4 + randf()),
				col, 0, 2.5)


## Sparks sprayed in a cone around `ang` (radians).
func spray(x: float, y: float, col: Color, n: int, ang: float, spread: float, speed: float, size := 0.8,
		life := 0.3) -> void:
	for k in n:
		var a := ang + (randf() - 0.5) * spread
		var s := speed * (0.4 + randf() * 0.8)
		particle(x, y, cos(a) * s, sin(a) * s, life * (0.6 + randf() * 0.6), size, col, 1, 5.0)


func ring(x: float, y: float, r0: float, r1: float, dur: float, col: Color, width := 1.0) -> void:
	rings.append({"x": x, "y": y, "r0": r0, "r1": r1, "t": 0.0, "d": dur, "c": col, "w": width})


func flash(x: float, y: float, r: float, dur: float, col: Color) -> void:
	flashes.append({"x": x, "y": y, "r": r, "t": 0.0, "d": dur, "c": col})


func beam(a: Vector2, b: Vector2, w: float, col: Color, dur := 0.28) -> void:
	beams.append({"a": a, "b": b, "w": w, "t": 0.0, "d": dur, "c": col})


func arc(pts: PackedVector2Array, col: Color, dur := 0.22) -> void:
	arcs.append({"p": pts, "t": 0.0, "d": dur, "c": col})


func warn(x: float, y: float, ang: float, length: float, dur: float) -> void:
	warns.append({"x": x, "y": y, "a": ang, "l": length, "t": 0.0, "d": dur})


func number(x: float, y: float, value: float, crit: bool) -> void:
	if numbers.size() >= MAX_NUMBERS:
		numbers.pop_front()
	numbers.append({"x": x + randf_range(-10, 10), "y": y - 10.0, "v": str(int(ceil(value))), "t": 0.0,
		"d": 0.75 if crit else 0.55, "crit": crit, "vx": randf_range(-40, 40)})


# --- update -----------------------------------------------------------------------

func update_fx(delta: float) -> void:
	var i := 0
	while i < pn:
		p_life[i] -= delta
		if p_life[i] <= 0.0:
			pn -= 1
			p_x[i] = p_x[pn]; p_y[i] = p_y[pn]; p_vx[i] = p_vx[pn]; p_vy[i] = p_vy[pn]
			p_life[i] = p_life[pn]; p_max[i] = p_max[pn]; p_size[i] = p_size[pn]; p_drag[i] = p_drag[pn]
			p_col[i] = p_col[pn]; p_kind[i] = p_kind[pn]
			continue
		var k := maxf(0.0, 1.0 - p_drag[i] * delta)
		p_vx[i] *= k
		p_vy[i] *= k
		p_x[i] += p_vx[i] * delta
		p_y[i] += p_vy[i] * delta
		i += 1
	for list in [rings, flashes, beams, arcs, warns, numbers]:
		var j: int = list.size() - 1
		while j >= 0:
			list[j].t += delta
			if list[j].t >= list[j].d:
				list.remove_at(j)
			j -= 1
	for n in numbers:
		n.y -= 70.0 * delta
		n.x += n.vx * delta
	queue_redraw()
	_text_layer.queue_redraw()


# --- drawing ----------------------------------------------------------------------

func _draw() -> void:
	for f in flashes:
		var k: float = f.t / f.d
		var a := (1.0 - k) * (1.0 - k)
		var r: float = f.r * (0.6 + 0.6 * k)
		draw_texture_rect(_glow, Rect2(f.x - r, f.y - r, r * 2.0, r * 2.0), false, Color(f.c, a))
	for g in rings:
		var k: float = g.t / g.d
		var e := 1.0 - pow(1.0 - k, 3.0)
		var r: float = lerpf(g.r0, g.r1, e)
		var s := r / 110.0 * 256.0
		var a := (1.0 - k)
		draw_texture_rect(_disc, Rect2(g.x - s * 0.5, g.y - s * 0.5, s, s), false, Color(g.c, a * 0.22 * g.w))
		draw_texture_rect(_ring, Rect2(g.x - s * 0.5, g.y - s * 0.5, s, s), false, Color(g.c, a * g.w))
	for b in beams:
		var k: float = b.t / b.d
		var a: Vector2 = b.a
		var bb: Vector2 = b.b
		var dir := (bb - a)
		var length := dir.length()
		var w: float = b.w * (1.0 + 2.2 * (1.0 - k)) * (1.0 - k * 0.5)
		draw_set_transform(a, dir.angle(), Vector2.ONE)
		var col: Color = b.c
		draw_texture_rect(_beam, Rect2(0, -w * 1.6, length, w * 3.2), false, Color(col, (1.0 - k) * 0.7))
		draw_texture_rect(_beam, Rect2(0, -w * 0.45, length, w * 0.9), false,
				Color(1.6, 1.6, 1.6, (1.0 - k)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for a in arcs:
		var k: float = a.t / a.d
		var pts: PackedVector2Array = a.p
		var jag := PackedVector2Array()
		for s in pts.size() - 1:
			var p0 := pts[s]
			var p1 := pts[s + 1]
			var n := (p1 - p0).orthogonal().normalized()
			jag.append(p0)
			for m in range(1, 6):
				var tt := m / 6.0
				jag.append(p0.lerp(p1, tt) + n * randf_range(-16.0, 16.0))
		jag.append(pts[pts.size() - 1])
		var col: Color = a.c
		draw_polyline(jag, Color(col, (1.0 - k) * 0.45), 14.0)
		draw_polyline(jag, Color(col * 1.6, 1.0 - k), 5.0)
		draw_polyline(jag, Color(1.8, 1.8, 2.0, 1.0 - k), 2.0)
	for w in warns:
		var k: float = w.t / w.d
		var blink := 0.45 + 0.55 * absf(sin(k * 18.0))
		var dir := Vector2(cos(w.a), sin(w.a))
		var p0 := Vector2(w.x, w.y)
		var p1: Vector2 = p0 + dir * w.l
		draw_line(p0, p1, Color(1.0, 0.25, 0.3, 0.16 * blink), 26.0)
		draw_line(p0, p1, Color(1.0, 0.3, 0.35, 0.7 * blink), 3.0)
		draw_circle(p1, 10.0, Color(1.0, 0.3, 0.35, 0.6 * blink))
	for i in pn:
		var life := p_life[i] / p_max[i]
		var c := p_col[i]
		c.a = life
		var sz := p_size[i]
		if p_kind[i] == 1:
			var vx := p_vx[i]
			var vy := p_vy[i]
			var sp := sqrt(vx * vx + vy * vy)
			var length := clampf(sp * 0.05, 6.0, 44.0) * sz
			draw_set_transform(Vector2(p_x[i], p_y[i]), atan2(vy, vx), Vector2.ONE)
			draw_texture_rect(_streak, Rect2(-length, -5.0 * sz, length, 10.0 * sz), false, c)
		else:
			var r := 14.0 * sz * (0.4 + 0.6 * life)
			draw_set_transform(Vector2(p_x[i], p_y[i]), 0.0, Vector2.ONE)
			draw_texture_rect(_spark, Rect2(-r, -r, r * 2.0, r * 2.0), false, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_numbers() -> void:
	var font := UiKit.display()
	for n in numbers:
		var k: float = n.t / n.d
		var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - k * 6.0)
		var size := int((40.0 if n.crit else 26.0) * pop)
		var col := Color(1.0, 0.85, 0.3) if n.crit else Color(1, 1, 1)
		col.a = 1.0 - k * k
		var pos := Vector2(n.x - 60.0, n.y)
		_text_layer.draw_string_outline(font, pos, n.v, HORIZONTAL_ALIGNMENT_CENTER, 120.0, size, 6,
				Color(0.05, 0.0, 0.1, col.a * 0.85))
		_text_layer.draw_string(font, pos, n.v, HORIZONTAL_ALIGNMENT_CENTER, 120.0, size, col)

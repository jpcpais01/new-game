class_name LogoView
extends Node2D
## "PRISMA" spelled in gems. The blocks rain down and bounce into place when
## the title appears, a light sweep glints across them, and tapping the logo
## blows it apart and rebuilds it.

signal block_landed

const LETTERS := {
	"P": ["###.", "#..#", "###.", "#...", "#..."],
	"R": ["###.", "#..#", "###.", "#.#.", "#..#"],
	"I": ["###", ".#.", ".#.", ".#.", "###"],
	"S": [".###", "#...", ".##.", "...#", "###."],
	"M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
	"A": [".##.", "#..#", "####", "#..#", "#..#"],
}
const WORD := "PRISMA"
const FALL := 0.55

var block := 34.0
var blocks: Array = []   # {home, pos, vel, color, delay, state, rot}
var cols := 0
var _t := 0.0
var _sweep := -1.0


func _ready() -> void:
	_build()


func width_px() -> float:
	return cols * block


func height_px() -> float:
	return 5 * block


func _build() -> void:
	blocks.clear()
	var x := 0
	for li in WORD.length():
		var rows: Array = LETTERS[WORD[li]]
		var w: int = rows[0].length()
		for y in rows.size():
			for cx in w:
				if rows[y][cx] == "#":
					blocks.append({
						"cell": Vector2(x + cx, y),
						"color": li + 1,
						"delay": 0.15 + (x + cx) * 0.028 + (4 - y) * 0.05 + randf() * 0.05,
						"t": 0.0,
						"landed": false,
						"rot": 0.0,
						"off": Vector2.ZERO,
						"vel": Vector2.ZERO,
						"rv": 0.0,
						"mode": "drop",
					})
		x += w + 1
	cols = x - 1


func replay_drop() -> void:
	for b in blocks:
		b.mode = "drop"
		b.t = 0.0
		b.landed = false
		b.delay = 0.1 + b.cell.x * 0.02 + randf() * 0.08
		b.off = Vector2.ZERO
		b.rot = 0.0


## Blow the logo apart; the pieces fall back into place on their own.
func burst(at: Vector2) -> void:
	for b in blocks:
		var home: Vector2 = (b.cell + Vector2(0.5, 0.5)) * block
		var dir: Vector2 = (home - at).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		b.mode = "burst"
		b.vel = dir * randf_range(500.0, 1300.0) + Vector2(0, -500.0)
		b.rv = randf_range(-10.0, 10.0)
		b.t = 0.0
		b.landed = false


func contains(local: Vector2) -> bool:
	return Rect2(0, 0, width_px(), height_px()).grow(30).has_point(local)


func _process(delta: float) -> void:
	_t += delta
	for b in blocks:
		match b.mode:
			"drop":
				if b.delay > 0.0:
					b.delay -= delta
					continue
				b.t += delta
				var p := clampf(b.t / FALL, 0.0, 1.0)
				b.off = Vector2(0, -(1.0 - _bounce(p)) * 900.0)
				if p >= 1.0 and not b.landed:
					b.landed = true
					block_landed.emit()
			"burst":
				b.t += delta
				b.vel.y += 2600.0 * delta
				b.off += b.vel * delta
				b.rot += b.rv * delta
				if b.t > 0.7:
					# Fly home.
					b.mode = "home"
					b.t = 0.0
					b.vel = b.off
			"home":
				b.t += delta
				var p := clampf(b.t / 0.6, 0.0, 1.0)
				var e := 1.0 - pow(1.0 - p, 3.0)
				b.off = b.vel * (1.0 - e)
				b.rot = lerpf(b.rot, 0.0, e)
				if p >= 1.0:
					b.mode = "rest"
					b.off = Vector2.ZERO
					b.rot = 0.0
					block_landed.emit()
	# A glint sweeps across every few seconds.
	var cycle := fmod(_t, 3.6)
	_sweep = cycle / 1.1 if cycle < 1.1 else -1.0
	queue_redraw()


func _draw() -> void:
	var span := cols + 5.0
	for b in blocks:
		if b.mode == "drop" and b.delay > 0.0:
			continue
		var c: Vector2 = (b.cell + Vector2(0.5, 0.5)) * block + b.off
		var s := block * 0.98
		draw_set_transform(c, b.rot, Vector2.ONE)
		var r := Rect2(-s / 2, -s / 2, s, s)
		draw_texture_rect(Art.gem(b.color), r, false)
		if _sweep >= 0.0:
			var pos: float = (b.cell.x + b.cell.y * 0.6) / span
			var d := absf(pos - (_sweep * 1.4 - 0.2))
			var a := clampf(1.0 - d * 9.0, 0.0, 1.0)
			if a > 0.0:
				draw_texture_rect(Art.white(), r, false, Color(1, 1, 1, a * 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _bounce(t: float) -> float:
	var n1 := 7.5625
	var d1 := 2.75
	if t < 1.0 / d1:
		return n1 * t * t
	elif t < 2.0 / d1:
		t -= 1.5 / d1
		return n1 * t * t + 0.75
	elif t < 2.5 / d1:
		t -= 2.25 / d1
		return n1 * t * t + 0.9375
	t -= 2.625 / d1
	return n1 * t * t + 0.984375

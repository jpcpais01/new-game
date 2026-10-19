class_name Fx
extends Node2D
## Particle and text effects: shards, sparks, glows, shock rings, light beams,
## floating score text, banners and confetti. Visual only.
##
## Two canvases: one additive (light) and one normal-blended (solid things
## and text), so glows add up like real light while text stays crisp.

var _add_items: Array = []
var _norm_items: Array = []
var _add: Node2D
var _norm: Node2D
var _font: Font


func _ready() -> void:
	_font = Art.font_bold()
	_norm = _FxCanvas.new()
	_norm.owner_fx = self
	_norm.additive = false
	add_child(_norm)
	_add = _FxCanvas.new()
	_add.owner_fx = self
	_add.additive = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = mat
	add_child(_add)


func clear_all() -> void:
	_add_items.clear()
	_norm_items.clear()


# ------------------------------------------------------------------ emit --

func shards(pos: Vector2, color: int, count: int, power := 1.0, cell := 100.0) -> void:
	for i in count:
		var ang := randf() * TAU
		var spd := randf_range(250.0, 820.0) * power
		_norm_items.append({
			"type": "shard", "pos": pos + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3)) * cell,
			"vel": Vector2(cos(ang), sin(ang)) * spd + Vector2(0, -380.0 * power),
			"rot": randf() * TAU, "rv": randf_range(-9.0, 9.0),
			"size": cell * randf_range(0.16, 0.32), "color": color,
			"life": 0.0, "max": randf_range(0.55, 0.95),
		})


func sparks(pos: Vector2, col: Color, count: int, power := 1.0) -> void:
	for i in count:
		var ang := randf() * TAU
		var spd := randf_range(120.0, 640.0) * power
		_add_items.append({
			"type": "spark", "pos": pos, "vel": Vector2(cos(ang), sin(ang)) * spd,
			"size": randf_range(26.0, 70.0) * power, "color": col,
			"life": 0.0, "max": randf_range(0.35, 0.8), "rot": randf() * TAU,
		})


func glow(pos: Vector2, col: Color, size: float, life := 0.5) -> void:
	_add_items.append({"type": "glow", "pos": pos, "size": size, "color": col, "life": 0.0, "max": life})


func ring(pos: Vector2, col: Color, r0: float, r1: float, life := 0.55) -> void:
	_add_items.append({"type": "ring", "pos": pos, "r0": r0, "r1": r1, "color": col, "life": 0.0, "max": life})


func beam(center: Vector2, horizontal: bool, length: float, thickness: float, col: Color, delay := 0.0, rainbow := false) -> void:
	_add_items.append({"type": "beam", "pos": center, "h": horizontal, "len": length, "th": thickness,
			"color": col, "life": -delay, "max": 0.55, "rainbow": rainbow})


func text(pos: Vector2, msg: String, size: int, col: Color, kind := "pop", life := 1.0, delay := 0.0) -> void:
	_norm_items.append({"type": "text", "pos": pos, "text": msg, "size": size, "color": col,
			"kind": kind, "life": -delay, "max": life})


func confetti(origin: Vector2, count: int, spread := 900.0) -> void:
	for i in count:
		var ang := randf_range(-PI * 0.92, -PI * 0.08)
		var spd := randf_range(700.0, 1700.0)
		_norm_items.append({
			"type": "confetti", "pos": origin + Vector2(randf_range(-spread, spread) * 0.15, 0),
			"vel": Vector2(cos(ang), sin(ang)) * spd, "rot": randf() * TAU, "rv": randf_range(-12.0, 12.0),
			"size": Vector2(randf_range(14.0, 24.0), randf_range(26.0, 42.0)),
			"color": PrismPalette.gem(1 + randi() % PrismPieces.COLORS).lightened(0.15),
			"life": 0.0, "max": randf_range(1.6, 2.6), "phase": randf() * TAU,
		})


# ---------------------------------------------------------------- update --

func _process(delta: float) -> void:
	_step(_add_items, delta)
	_step(_norm_items, delta)
	_add.queue_redraw()
	_norm.queue_redraw()


func _step(items: Array, delta: float) -> void:
	var i := items.size() - 1
	while i >= 0:
		var p: Dictionary = items[i]
		p.life += delta
		if p.life >= p.max:
			items.remove_at(i)
			i -= 1
			continue
		if p.life >= 0.0:
			match p.type:
				"shard":
					p.vel.y += 2600.0 * delta
					p.vel *= 1.0 - 0.6 * delta
					p.pos += p.vel * delta
					p.rot += p.rv * delta
				"spark":
					p.vel *= 1.0 - 3.2 * delta
					p.pos += p.vel * delta
				"confetti":
					p.vel.y += 1500.0 * delta
					p.vel *= 1.0 - 1.9 * delta
					p.pos += p.vel * delta + Vector2(sin(p.life * 6.0 + p.phase) * 90.0 * delta, 0)
					p.rot += p.rv * delta
		i -= 1


# ------------------------------------------------------------------ draw --

func _draw_items(canvas: Node2D, additive: bool) -> void:
	var items := _add_items if additive else _norm_items
	for p in items:
		if p.life < 0.0:
			continue
		var t: float = p.life / p.max
		match p.type:
			"shard":
				var a := 1.0 - t * t
				canvas.draw_set_transform(p.pos, p.rot, Vector2.ONE)
				var s: float = p.size * (1.0 - t * 0.5)
				canvas.draw_texture_rect(Art.gem(p.color), Rect2(-s / 2, -s / 2, s, s), false, Color(1, 1, 1, a))
			"spark":
				var c: Color = p.color
				c.a = (1.0 - t) * 0.9
				var s: float = p.size * (1.0 - t * 0.6)
				canvas.draw_set_transform(p.pos, p.rot, Vector2.ONE)
				canvas.draw_texture_rect(Art.spark(), Rect2(-s / 2, -s / 2, s, s), false, c)
			"glow":
				var c: Color = p.color
				c.a = (1.0 - t) * (1.0 - t) * c.a
				var s: float = p.size * (0.7 + t * 0.6)
				canvas.draw_set_transform(p.pos, 0.0, Vector2.ONE)
				canvas.draw_texture_rect(Art.glow(), Rect2(-s / 2, -s / 2, s, s), false, c)
			"ring":
				var c: Color = p.color
				var e := 1.0 - pow(1.0 - t, 3.0)
				c.a = (1.0 - t) * c.a
				var r: float = lerpf(p.r0, p.r1, e)
				canvas.draw_set_transform(p.pos, 0.0, Vector2.ONE)
				canvas.draw_texture_rect(Art.ring(), Rect2(-r, -r, r * 2, r * 2), false, c)
			"beam":
				var c: Color = p.color
				if p.rainbow:
					c = PrismPalette.rainbow(t * 0.8 + p.pos.x * 0.001 + p.pos.y * 0.001, 0.55)
				var fade := 1.0 - t
				c.a = fade * fade
				var th: float = p.th * (1.6 - t * 1.1)
				var ln: float = p.len * (0.5 + 0.5 * minf(1.0, t * 5.0)) + 60.0
				canvas.draw_set_transform(p.pos, 0.0 if p.h else PI / 2, Vector2.ONE)
				canvas.draw_texture_rect(Art.beam(), Rect2(-ln / 2, -th / 2, ln, th), false, c)
				canvas.draw_texture_rect(Art.beam(), Rect2(-ln / 2, -th / 6, ln, th / 3), false, Color(1, 1, 1, c.a))
			"text":
				_draw_text(canvas, p, t)
			"confetti":
				var c: Color = p.color
				c.a = minf(1.0, (1.0 - t) * 3.0)
				var flip := absf(sin(p.life * 9.0 + p.phase))
				canvas.draw_set_transform(p.pos, p.rot, Vector2(1.0, 0.25 + flip * 0.75))
				var sz: Vector2 = p.size
				canvas.draw_rect(Rect2(-sz / 2, sz), c)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_text(canvas: Node2D, p: Dictionary, t: float) -> void:
	var sc := 1.0
	var alpha := 1.0
	var offset := 0.0
	match p.kind:
		"pop":
			sc = 0.6 + 0.5 * _back_out(minf(1.0, t * 5.0))
			offset = -150.0 * _ease_out(t)
			alpha = 1.0 - smoothstep(0.65, 1.0, t)
		_:
			sc = _elastic_out(minf(1.0, t * 2.4)) * (1.0 + 0.06 * t)
			offset = -40.0 * t
			alpha = 1.0 - smoothstep(0.78, 1.0, t)
	if sc <= 0.01:
		return
	var size: int = p.size
	var msg: String = p.text
	var w := _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_set_transform(p.pos + Vector2(0, offset), 0.0, Vector2(sc, sc))
	var base := Vector2(-w / 2.0, size * 0.36)
	var outline := maxi(6, size / 7)
	var oc := Color(0.05, 0.03, 0.14, 0.85 * alpha)
	if p.kind == "rainbow":
		var x := base.x
		for i in msg.length():
			var ch := msg.unicode_at(i)
			var cw := _font.get_char_size(ch, size).x
			var col := PrismPalette.rainbow(p.life * 1.4 + i * 0.09, 0.62)
			col.a = alpha
			canvas.draw_char_outline(_font, Vector2(x, base.y), msg[i], size, outline, oc)
			canvas.draw_char(_font, Vector2(x, base.y), msg[i], size, col)
			x += cw
	else:
		var col: Color = p.color
		col.a *= alpha
		canvas.draw_string_outline(_font, base, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, oc)
		canvas.draw_string(_font, base, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


static func _back_out(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)


static func _elastic_out(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * (2.0 * PI / 3.0)) + 1.0


class _FxCanvas:
	extends Node2D
	var owner_fx: Fx
	var additive := false

	func _draw() -> void:
		owner_fx._draw_items(self, additive)

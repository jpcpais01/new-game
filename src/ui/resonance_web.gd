class_name ResonanceWeb
extends Control
## The Codex's map of resonances: the nine weapons on a ring, each bridged to
## its two partners. Discovered bridges burn in the resonance's colour with
## its sigil at the middle; the rest wait as faint dashed lines.

const ICON := 96.0

var known: Array = []
var _ring: Array = []
var _t := 0.0


func _init(discovered: Array = []) -> void:
	known = discovered
	custom_minimum_size = Vector2(0, 820)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring = ring()


## The weapons in ring order: start at the Pulse Cannon, walk partner to partner.
static func ring() -> Array:
	var out: Array = ["pulse"]
	var prev := ""
	while out.size() < Defs.WEAPON_ORDER.size():
		var cur: String = out[out.size() - 1]
		var nxt := ""
		for p in Defs.resonance_partners(cur):
			if p[1] != prev and not out.has(p[1]):
				nxt = p[1]
				break
		if nxt == "":
			break
		prev = cur
		out.append(nxt)
	return out


func _ready() -> void:
	resized.connect(_place)
	for id in _ring:
		var ic := UiKit.icon_rect(id, ICON)
		ic.size = Vector2(ICON, ICON)
		ic.name = "w_" + id
		add_child(ic)
	for id in Defs.RESONANCE_ORDER:
		var ic := UiKit.icon_rect("res_" + id, 84)
		ic.size = Vector2(84, 84)
		ic.name = "r_" + id
		if not known.has(id):
			ic.modulate = Color(0.3, 0.27, 0.45, 0.8)
		add_child(ic)
	_place()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _center() -> Vector2:
	return Vector2(size.x * 0.5, 410.0)


func _radius() -> float:
	return minf(size.x * 0.5 - ICON * 0.6, 330.0)


func _pos(k: int) -> Vector2:
	var a := -PI * 0.5 + TAU * float(k) / float(_ring.size())
	return _center() + Vector2(cos(a), sin(a)) * _radius()


func _place() -> void:
	if _ring.is_empty():
		return
	for k in _ring.size():
		var n := get_node_or_null("w_" + String(_ring[k]))
		if n:
			n.position = _pos(k) - Vector2(ICON, ICON) * 0.5
	for id in Defs.RESONANCE_ORDER:
		var n := get_node_or_null("r_" + id)
		if n:
			n.position = _mid(id) - Vector2(42, 42)


## Where a resonance's sigil sits: the middle of its bridge, pulled a little
## towards the centre so it clears the weapon icons.
func _mid(id: String) -> Vector2:
	var r: Dictionary = Defs.RESONANCES[id]
	var a := _pos(_ring.find(r.a))
	var b := _pos(_ring.find(r.b))
	return _center().lerp((a + b) * 0.5, 0.78)


func _draw() -> void:
	var c := _center()
	draw_arc(c, _radius() * 0.5, 0.0, TAU, 64, Color(Defs.RESONANCE_COLOR, 0.06), 2.0)
	for idx in Defs.RESONANCE_ORDER.size():
		var id: String = Defs.RESONANCE_ORDER[idx]
		var r: Dictionary = Defs.RESONANCES[id]
		var a := _pos(_ring.find(r.a))
		var b := _pos(_ring.find(r.b))
		var m := _mid(id)
		var lit := known.has(id)
		if lit:
			var col: Color = r.color
			var pulse := 0.7 + 0.3 * sin(_t * 2.0 + float(idx))
			for seg in [[a, m], [m, b]]:
				draw_line(seg[0], seg[1], Color(col, 0.18), 12.0, true)
				draw_line(seg[0], seg[1], Color(col * 1.3, 0.9 * pulse), 3.0, true)
			# Sparks run between the two weapons.
			var tt := fmod(_t * 0.5 + float(idx) * 0.29, 1.0)
			var sp := a.lerp(m, tt * 2.0) if tt < 0.5 else m.lerp(b, tt * 2.0 - 1.0)
			draw_circle(sp, 7.0, Color(col, 0.4))
			draw_circle(sp, 3.5, Color(1, 1, 1, 0.95))
		else:
			for seg in [[a, m], [m, b]]:
				draw_dashed_line(seg[0], seg[1], Color(0.55, 0.5, 0.8, 0.22), 2.0, 10.0, true)
	var title := "%d / %d" % [known.size(), Defs.RESONANCES.size()]
	var font := UiKit.display()
	var fs := 56
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-tw * 0.5, 18.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(Defs.RESONANCE_COLOR, 0.85))
	var sub := "RESONANCES"
	var sw := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	draw_string(font, c + Vector2(-sw * 0.5, 52.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.45))

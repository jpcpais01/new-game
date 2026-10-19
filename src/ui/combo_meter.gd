class_name ComboMeter
extends Control
## Shows the live combo under the score: a flame, the streak, the current
## multiplier, and three pips for how many placements the combo survives
## without another clear.

var combo := 0
var left := 0
var mult := 1.0
var _alpha := 0.0
var _bump := 0.0
var _warn := 0.0
var _t := 0.0
var _pill := StyleBoxFlat.new()


func set_combo(p_combo: int, p_left: int, p_mult: float) -> void:
	combo = p_combo
	left = p_left
	mult = p_mult


func bump() -> void:
	_bump = 1.0


func warn() -> void:
	_warn = 1.0


func _process(delta: float) -> void:
	_t += delta
	_alpha = move_toward(_alpha, 1.0 if combo > 0 else 0.0, delta * 5.0)
	_bump = maxf(0.0, _bump - delta * 3.0)
	_warn = maxf(0.0, _warn - delta * 1.2)
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var font := Art.font_bold()
	var sc := 1.0 + 0.25 * _bump * _bump
	var c := size / 2.0
	draw_set_transform(c, 0.0, Vector2(sc, sc))
	var hot := clampf(combo / 8.0, 0.0, 1.0)
	var flame_col := PrismPalette.GOLD.lerp(Color("ff5c5c"), hot)
	flame_col.a = _alpha
	var txt := "COMBO %d" % combo
	var fs := 46
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var mtxt := "x%s" % (str(mult) if mult != floorf(mult) else str(int(mult)))
	var mw := font.get_string_size(mtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x + 28
	var total := 54 + 14 + tw + 16 + mw
	var x := -total / 2.0
	var flick := 1.0 + 0.06 * sin(_t * 17.0) * hot
	draw_texture_rect(Art.icon("flame"), Rect2(x, -40 * flick, 54, 54 * flick), false, flame_col)
	x += 54 + 14
	var tc := Color(1, 1, 1, _alpha)
	draw_string_outline(font, Vector2(x, 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0.05, 0.03, 0.14, 0.8 * _alpha))
	draw_string(font, Vector2(x, 2), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
	x += tw + 16
	var pill := Rect2(x, -36, mw, 48)
	_pill.bg_color = Color(flame_col.r, flame_col.g, flame_col.b, 0.22 * _alpha)
	_pill.set_corner_radius_all(24)
	draw_style_box(_pill, pill)
	draw_string(font, Vector2(x + 14, 1), mtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, flame_col)
	# Pips: placements left before the combo breaks.
	for i in 3:
		var on := i < left
		var pc := flame_col if on else Color(1, 1, 1, 0.16 * _alpha)
		if on and left == 1 and _warn > 0.0:
			pc = pc.lerp(Color("ff4d6d"), 0.5 + 0.5 * sin(_t * 20.0))
		draw_circle(Vector2((i - 1) * 34.0, 34), 9.0, pc)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

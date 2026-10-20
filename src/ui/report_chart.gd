class_name ReportChart
extends Control
## The run as a picture: damage per second (magenta area), hull (a line that
## burns from cyan to red), every boss fight as a band in its colour, and
## markers for evolutions, resonances, relics, revives and the dawn. Draws
## itself in from left to right.

var sim: Sim
var reveal := 0.0:
	set(v):
		reveal = v
		queue_redraw()

const PAD_L := 8.0
const PAD_R := 8.0
const TOP := 46.0      # marker lane
const BOTTOM := 34.0   # time labels


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	create_tween().tween_property(self, "reveal", 1.0, 1.4).set_delay(0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _x(tick: float, w: float) -> float:
	return PAD_L + (w - PAD_L - PAD_R) * clampf(tick / maxf(1.0, float(sim.tick)), 0.0, 1.0)


func _draw() -> void:
	if sim == null:
		return
	var w := size.x
	var h := size.y
	var y0 := TOP
	var y1 := h - BOTTOM
	var ch := y1 - y0
	var font := UiKit.display_light()
	draw_rect(Rect2(0, y0, w, ch), Color(0.02, 0.015, 0.06, 0.75))
	for k in 5:
		var gy := y0 + ch * k / 4.0
		draw_line(Vector2(PAD_L, gy), Vector2(w - PAD_R, gy), Color(1, 1, 1, 0.05 if k % 4 else 0.12), 1.0)
	# Minute ticks: at most ~8 labels.
	var secs := float(sim.tick) / Sim.TPS
	var step := 60.0
	while secs / step > 8.0:
		step *= 2.0
	var t := step
	while t < secs:
		var gx := _x(t * Sim.TPS, w)
		draw_line(Vector2(gx, y0), Vector2(gx, y1), Color(1, 1, 1, 0.06), 1.0)
		if gx < w - 40.0:
			draw_string(font, Vector2(gx - 50, h - 6), UiKit.fmt_time(t).trim_prefix("0"),
					HORIZONTAL_ALIGNMENT_CENTER, 100, 18, UiKit.DIM)
		t += step
	var clip := _x(reveal * float(sim.tick), w)
	# Boss fights.
	for b in sim.boss_log:
		var type: int = b[0]
		var bx0 := _x(float(b[1]), w)
		var end: int = b[2] if int(b[2]) >= 0 else sim.tick
		var bx1 := minf(_x(float(end), w), clip)
		if bx1 <= bx0:
			continue
		var bc: Color = Defs.ENEMY_COLOR[type]
		draw_rect(Rect2(bx0, y0, bx1 - bx0, ch), Color(bc, 0.13))
		draw_line(Vector2(bx0, y0), Vector2(bx0, y1), Color(bc, 0.6), 2.0)
		if int(b[2]) >= 0 and _x(float(end), w) <= clip:
			draw_line(Vector2(bx1, y0), Vector2(bx1, y1), Color(bc, 0.35 if b[3] else 0.8), 2.0)
		var tex: Texture2D = Art.enemy[type] if Art.enemy.size() > type else null
		if tex:
			draw_texture_rect(tex, Rect2(bx0 + 2, y0 + 4, 34, 34), false, Color(1, 1, 1, 0.9))
	# Damage per second, as a filled area.
	var n := sim.tl_dps.size()
	if n > 0:
		var top := maxf(1.0, sim.peak_dps())
		var line := PackedVector2Array([Vector2(_x(0, w), y1)])
		for k in n:
			var px := _x(float((k + 1) * Sim.TL_TICKS), w)
			if px > clip:
				break
			line.append(Vector2(px, y1 - ch * 0.92 * float(sim.tl_dps[k]) / top))
		# The area as one quad per sample (a single concave polygon can fail to triangulate).
		var fill := Color(UiKit.MAGENTA, 0.22)
		for k in line.size() - 1:
			var a := line[k]
			var b := line[k + 1]
			var pts := PackedVector2Array([a, b])
			if y1 - b.y >= 0.5:
				pts.append(Vector2(b.x, y1))
			if y1 - a.y >= 0.5:
				pts.append(Vector2(a.x, y1))
			if pts.size() >= 3 and b.x - a.x >= 0.5:
				draw_colored_polygon(pts, fill)
		if line.size() > 1:
			draw_polyline(line, Color(UiKit.MAGENTA * 1.3, 0.95), 3.0, true)
	# Hull.
	if sim.tl_hp.size() > 0:
		var prev := Vector2(_x(0, w), y0 + ch * 0.04)
		var prev_v := 1.0
		for k in sim.tl_hp.size():
			var px := _x(float((k + 1) * Sim.TL_TICKS), w)
			if px > clip:
				break
			var v := float(sim.tl_hp[k])
			var pt := Vector2(px, y1 - ch * (0.04 + 0.92 * v))
			var c := UiKit.RED.lerp(UiKit.CYAN, clampf((v + prev_v) * 0.5 * 1.4 - 0.2, 0.0, 1.0))
			draw_line(prev, pt, Color(c, 0.25), 9.0, true)
			draw_line(prev, pt, c * 1.2, 3.0, true)
			prev = pt
			prev_v = v
	# Markers: icons that would overlap step down into the chart.
	var last_x := -100.0
	var lane := 0
	for m in sim.tl_marks:
		var mx := _x(float(m[0]), w)
		if mx > clip:
			continue
		var kind: String = m[1]
		if kind in ["evo", "res", "relic", "revive"]:
			lane = (lane + 1) % 3 if mx - last_x < 40.0 else 0
			last_x = mx
		match kind:
			"evo":
				_mark_icon(Art.icon(String(m[2]) + "_evo"), mx, UiKit.GOLD, lane)
			"res":
				_mark_icon(Art.icon("res_" + String(m[2])), mx, Defs.RESONANCES[m[2]].color, lane)
			"relic":
				_mark_icon(Art.icon(String(m[2])), mx, Color(0.8, 0.55, 1.0), lane)
			"revive":
				_mark_icon(Art.icon("revive"), mx, UiKit.GREEN, lane)
			"dawn":
				draw_line(Vector2(mx, y0), Vector2(mx, y1), Color(UiKit.GOLD, 0.9), 3.0)
				draw_string(font, Vector2(mx - 60, y0 - 8), "DAWN", HORIZONTAL_ALIGNMENT_CENTER, 120, 20, UiKit.GOLD)
			"night":
				draw_line(Vector2(mx, y0), Vector2(mx, y1), Color(1.0, 0.25, 0.4, 0.5), 2.0)
	# The scan line drawing the chart in.
	if reveal < 1.0:
		draw_line(Vector2(clip, y0), Vector2(clip, y1), Color(1, 1, 1, 0.7), 2.0)
		draw_rect(Rect2(clip - 18, y0, 18, ch), Color(1, 1, 1, 0.05))


func _mark_icon(tex: Texture2D, x: float, col: Color, lane: int) -> void:
	var cy := TOP - 20.0 + 40.0 * lane
	draw_line(Vector2(x, cy + 19.0), Vector2(x, size.y - BOTTOM), Color(col, 0.35), 1.5)
	draw_circle(Vector2(x, cy), 19.0, Color(0.03, 0.02, 0.08, 0.9))
	draw_arc(Vector2(x, cy), 19.0, 0.0, TAU, 24, Color(col, 0.9), 2.0, true)
	if tex:
		draw_texture_rect(tex, Rect2(x - 15, cy - 15, 30, 30), false)

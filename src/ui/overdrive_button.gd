class_name OverdriveButton
extends Control
## The Overdrive button: a ring that fills with kills, then blazes until you
## tap it. Only catches touches while charged, so the rest of the time the
## joystick works right through it. Space or E fire it on desktop.

signal fired

const R := 92.0

var arena: Arena

var _ready_t := 0.0
var _press := 0.0
var _active_max := 1
var _shown := 0.0
var _label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(R * 2.0 + 40.0, R * 2.0 + 70.0)
	size = custom_minimum_size
	pivot_offset = Vector2(size.x * 0.5, R + 20.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UiKit.glow_label("", 26, UiKit.CYAN)
	_label.position = Vector2(-40, R * 2.0 + 26.0)
	_label.size = Vector2(size.x + 80, 40)
	add_child(_label)


func _gui_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = not DisplayServer.is_touchscreen_available()
	if pressed and (event.position - _center()).length() < R + 30.0:
		accept_event()
		trigger()


func trigger() -> void:
	if arena == null or arena.sim == null or not arena.sim.od_ready() or arena.paused:
		return
	arena.burst_request = true
	_press = 1.0
	fired.emit()


func _center() -> Vector2:
	return Vector2(size.x * 0.5, R + 20.0)


func _process(delta: float) -> void:
	if arena == null or arena.sim == null:
		return
	var s := arena.sim
	var ready := s.od_ready() and s.state == Sim.RUNNING
	mouse_filter = Control.MOUSE_FILTER_STOP if ready else Control.MOUSE_FILTER_IGNORE
	_ready_t = _ready_t + delta if ready else 0.0
	_press = maxf(0.0, _press - delta * 3.0)
	if s.od_t > _active_max or s.od_t <= 0:
		_active_max = maxi(1, s.od_t)
	_shown = lerpf(_shown, s.od_frac(), clampf(delta * 10.0, 0.0, 1.0))
	var col := arena.ship_color
	if s.od_t > 0:
		_label.text = String(Defs.ship(s.ship_id).od).to_upper()
	elif ready:
		_label.text = "TAP!"
	else:
		_label.text = ""
	_label.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.3))
	_label.add_theme_color_override("font_shadow_color", Color(col, 0.6))
	_label.modulate.a = 0.6 + 0.4 * sin(_ready_t * 8.0) if ready else 1.0
	scale = Vector2.ONE * (1.0 + 0.06 * sin(_ready_t * 6.0) * float(ready) + 0.15 * _press)
	queue_redraw()


func _draw() -> void:
	if arena == null or arena.sim == null:
		return
	var s := arena.sim
	var c := _center()
	var col := arena.ship_color
	var ready := s.od_ready()
	var active := s.od_t > 0
	var t := arena.vtime
	if ready:
		var k := 0.5 + 0.5 * sin(t * 6.0)
		draw_texture_rect(Art.tex("glow"), Rect2(c - Vector2(R, R) * 1.9, Vector2(R, R) * 3.8), false,
				Color(col, 0.35 + 0.25 * k))
	draw_circle(c, R, Color(0.03, 0.02, 0.08, 0.72))
	draw_arc(c, R, 0.0, TAU, 72, Color(col, 0.18), 10.0, true)
	var frac := _shown
	if active:
		frac = float(s.od_t) / float(_active_max)
	if frac > 0.002:
		var a0 := -PI * 0.5
		var fc := Color(col * 1.4, 1.0) if ready or active else Color(col, 0.75)
		draw_arc(c, R, a0, a0 + TAU * frac, maxi(8, int(72 * frac)), fc, 10.0, true)
		# A bright head on the filling ring.
		if not ready and not active:
			var hp := c + Vector2(cos(a0 + TAU * frac), sin(a0 + TAU * frac)) * R
			draw_circle(hp, 8.0, Color(1.4, 1.4, 1.4, 0.9))
	if ready:
		for k in 3:
			var a := t * 2.4 + k * TAU / 3.0
			draw_arc(c, R + 16.0, a, a + 0.8, 16, Color(col * 1.5, 0.9), 5.0, true)
	var ic := Art.icon("od_" + s.ship_id)
	var isz := R * (1.35 if ready or active else 1.15)
	var mod := Color(1.5, 1.5, 1.5, 1.0) if ready or active else Color(0.7, 0.7, 0.8, 0.55)
	draw_texture_rect(ic, Rect2(c - Vector2(isz, isz) * 0.5, Vector2(isz, isz)), false, mod)

class_name Joystick
extends Control
## Floating thumb-stick: touch anywhere to place it, drag to steer.
## Also reads WASD / arrow keys for desktop testing.

signal moved_first

const RADIUS := 120.0
const DEAD := 0.12

var value := Vector2.ZERO
var _active := false
var _index := -1
var _base := Vector2.ZERO
var _knob := Vector2.ZERO
var _fade := 0.0
var _announced := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _active:
			_begin(event.index, event.position)
		elif not event.pressed and event.index == _index:
			_end()
		accept_event()
	elif event is InputEventScreenDrag:
		if event.index == _index:
			_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if DisplayServer.is_touchscreen_available():
			return
		if event.pressed:
			_begin(0, event.position)
		else:
			_end()
	elif event is InputEventMouseMotion and _active and not DisplayServer.is_touchscreen_available():
		_drag(event.position)


func _begin(index: int, pos: Vector2) -> void:
	_active = true
	_index = index
	_base = pos
	_knob = pos
	value = Vector2.ZERO


func _drag(pos: Vector2) -> void:
	var d := pos - _base
	if d.length() > RADIUS:
		# The base trails the thumb so reversing direction is instant.
		_base = pos - d.normalized() * RADIUS
		d = pos - _base
	_knob = pos
	var v := d / RADIUS
	value = Vector2.ZERO if v.length() < DEAD else v.limit_length(1.0)
	if value != Vector2.ZERO and not _announced:
		_announced = true
		moved_first.emit()


func _end() -> void:
	_active = false
	_index = -1
	value = Vector2.ZERO


func release() -> void:
	_end()


func get_vector() -> Vector2:
	var k := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up"))
	if Input.is_physical_key_pressed(KEY_D):
		k.x += 1
	if Input.is_physical_key_pressed(KEY_A):
		k.x -= 1
	if Input.is_physical_key_pressed(KEY_S):
		k.y += 1
	if Input.is_physical_key_pressed(KEY_W):
		k.y -= 1
	if k != Vector2.ZERO:
		if not _announced:
			_announced = true
			moved_first.emit()
		return k.limit_length(1.0)
	return value


func _process(delta: float) -> void:
	_fade = move_toward(_fade, 1.0 if _active else 0.0, delta * (8.0 if _active else 3.0))
	queue_redraw()


func _draw() -> void:
	if _fade <= 0.01:
		return
	var c := UiKit.CYAN
	draw_circle(_base, RADIUS, Color(0.02, 0.05, 0.1, 0.25 * _fade))
	draw_arc(_base, RADIUS, 0.0, TAU, 64, Color(c, 0.45 * _fade), 4.0, true)
	draw_arc(_base, RADIUS + 10.0, 0.0, TAU, 64, Color(c, 0.12 * _fade), 10.0, true)
	var k := _base + (_knob - _base).limit_length(RADIUS)
	draw_circle(k, 46.0, Color(c, 0.25 * _fade))
	draw_circle(k, 34.0, Color(0.7, 1.0, 1.0, 0.6 * _fade))
	draw_arc(k, 46.0, 0.0, TAU, 40, Color(c, 0.9 * _fade), 3.0, true)

class_name PrismButton
extends Button
## A chunky, tactile button: it sits on a coloured "lip" that it sinks into
## when pressed, squashes a little, clicks and gives a haptic tap.

const KINDS := {
	"primary": [Color("8f6bff"), Color("5a3bd6")],
	"gold": [Color("ffb238"), Color("c97a12")],
	"pink": [Color("ff5c9a"), Color("c22f68")],
	"teal": [Color("2fcfb5"), Color("158a77")],
	"ghost": [Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.05)],
	"icon": [Color(1, 1, 1, 0.09), Color(0, 0, 0, 0.18)],
}

var kind := "primary"
var _tween: Tween


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(_on_pressed)
	resized.connect(func(): pivot_offset = size / 2.0)


func apply_kind() -> void:
	var cols: Array = KINDS.get(kind, KINDS.primary)
	var face: Color = cols[0]
	var lip: Color = cols[1]
	var radius := 999 if kind == "icon" else 48
	var lip_h := 0 if kind == "icon" else 12
	add_theme_stylebox_override("normal", _box(face, lip, lip_h, radius, false))
	add_theme_stylebox_override("hover", _box(face, lip, lip_h, radius, false))
	add_theme_stylebox_override("pressed", _box(face.darkened(0.08), lip, lip_h, radius, true))
	add_theme_stylebox_override("disabled", _box(Color(0.3, 0.3, 0.4, 0.4), Color(0.2, 0.2, 0.3, 0.4), lip_h, radius, false))
	if kind == "icon":
		add_theme_color_override("icon_normal_color", Color(1, 1, 1, 0.92))
		add_theme_color_override("icon_pressed_color", Color(1, 1, 1, 1))
		add_theme_color_override("icon_hover_color", Color(1, 1, 1, 0.92))
		add_theme_constant_override("icon_max_width", int(custom_minimum_size.x * 0.5))
	if kind == "ghost":
		add_theme_font_size_override("font_size", 44)


func _box(face: Color, lip: Color, lip_h: int, radius: int, pressed_state: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = face
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if lip_h > 0:
		var h := 4 if pressed_state else lip_h
		sb.border_color = lip
		sb.border_width_bottom = h
		sb.content_margin_top = 18 + (lip_h - h)
		sb.content_margin_bottom = 18
		sb.shadow_color = Color(0, 0, 0, 0.3)
		sb.shadow_size = 18
		sb.shadow_offset = Vector2(0, 8 if not pressed_state else 3)
	else:
		sb.border_color = Color(1, 1, 1, 0.14)
		sb.set_border_width_all(2)
		sb.set_content_margin_all(20)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	return sb


func _on_down() -> void:
	_animate(Vector2(0.94, 0.92), 0.06)
	Sfx.play("click", randf_range(0.95, 1.05), -2.0)
	Sfx.haptic(8, 0.35)


func _on_up() -> void:
	_animate(Vector2.ONE, 0.25, true)


func _on_pressed() -> void:
	pass


func _animate(target: Vector2, dur: float, springy := false) -> void:
	pivot_offset = size / 2.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if springy:
		_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", target, dur)

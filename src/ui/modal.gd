class_name Modal
extends Control
## A dimmed full-screen overlay with a panel that springs in. Every dialog
## (pause, settings, stats, patch notes, game over) is built on this.

signal closed

var panel: PanelContainer
var content: VBoxContainer
var dismissable := true
var _dim: ColorRect
var _closing := false


func _init(width := 900.0) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.01, 0.06, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(content)


func _ready() -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.86, 0.86)
	panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.72, 0.25)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	panel.resized.connect(func(): panel.pivot_offset = panel.size / 2.0)


func add_title(text: String, color := PrismPalette.TEXT, size := 84) -> Label:
	var l := UiKit.label(text, size, color)
	content.add_child(l)
	return l


func add_text(text: String, size := 38, color := PrismPalette.TEXT_DIM) -> Label:
	var l := UiKit.label(text, size, color, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(l)
	return l


func add_button(text: String, kind: String, cb: Callable, min_size := Vector2(620, 150)) -> PrismButton:
	var b := UiKit.button(text, kind, min_size)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	content.add_child(b)
	return b


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.0, 0.2)
	tw.tween_property(panel, "modulate:a", 0.0, 0.16)
	tw.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.18)
	tw.chain().tween_callback(func():
		closed.emit()
		queue_free())


func _gui_input(event: InputEvent) -> void:
	if not dismissable:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not panel.get_global_rect().has_point(event.global_position):
			close()

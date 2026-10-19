class_name Modal
extends Control
## Frosted full-screen overlay with a glowing panel. Subclasses fill `body`.

signal closed

var body: VBoxContainer
var panel: PanelContainer
var accent := UiKit.CYAN


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/ui/frost.gdshader")
	back.material = mat
	add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 0)
	center.add_child(panel)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	panel.add_child(body)
	build()
	var sb := UiKit.box(accent, Color(0.035, 0.025, 0.09, 0.96), 34, 3, 26)
	sb.content_margin_left = 54
	sb.content_margin_right = 54
	sb.content_margin_top = 48
	sb.content_margin_bottom = 48
	panel.add_theme_stylebox_override("panel", sb)
	modulate.a = 0.0
	panel.pivot_offset = Vector2(440, 300)
	panel.scale = Vector2(0.92, 0.92)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Override to add content to `body`.
func build() -> void:
	pass


func heading(text: String, color: Color = accent, size := 64) -> Label:
	var l := UiKit.glow_label(text, size, color)
	body.add_child(l)
	return l


func close() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		closed.emit()
		queue_free())

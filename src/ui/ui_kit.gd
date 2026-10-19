class_name UiKit
extends RefCounted
## Fonts, colours and widget factories shared by every screen.

const CYAN := Color(0.35, 0.95, 1.0)
const MAGENTA := Color(1.0, 0.32, 0.82)
const GOLD := Color(1.0, 0.82, 0.35)
const RED := Color(1.0, 0.3, 0.38)
const GREEN := Color(0.4, 1.0, 0.6)
const INK := Color(0.02, 0.015, 0.06)
const PANEL := Color(0.05, 0.035, 0.12, 0.92)
const DIM := Color(0.62, 0.6, 0.8)

static var _display: FontVariation
static var _display_light: FontVariation
static var _body: Font
static var _bold: Font
static var _theme: Theme


static func display() -> Font:
	if _display == null:
		_display = FontVariation.new()
		_display.base_font = load("res://assets/fonts/Orbitron.ttf")
		var ts := TextServerManager.get_primary_interface()
		_display.variation_opentype = {ts.name_to_tag("wght"): 820}
		_display.spacing_glyph = 2
	return _display


static func display_light() -> Font:
	if _display_light == null:
		_display_light = FontVariation.new()
		_display_light.base_font = load("res://assets/fonts/Orbitron.ttf")
		var ts := TextServerManager.get_primary_interface()
		_display_light.variation_opentype = {ts.name_to_tag("wght"): 560}
		_display_light.spacing_glyph = 4
	return _display_light


static func body() -> Font:
	if _body == null:
		_body = load("res://assets/fonts/Rajdhani-SemiBold.ttf")
	return _body


static func bold() -> Font:
	if _bold == null:
		_bold = load("res://assets/fonts/Rajdhani-Bold.ttf")
	return _bold


static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = body()
		_theme.default_font_size = 40
	return _theme


static func label(text: String, size: int, color: Color = Color.WHITE, font: Font = null,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else body())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func glow_label(text: String, size: int, color: Color, font: Font = null) -> Label:
	var l := label(text, size, color, font if font != null else display())
	l.add_theme_color_override("font_shadow_color", Color(color, 0.55))
	l.add_theme_constant_override("shadow_outline_size", maxi(4, size / 5))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	return l


static func box(color: Color, fill: Color = PANEL, radius := 22, border := 3, glow := 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = color
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(color, 0.45)
	sb.shadow_size = glow
	sb.anti_aliasing = true
	sb.corner_detail = 10
	return sb


## A glowing neon button. `primary` buttons are filled with colour.
static func button(text: String, color: Color = CYAN, size := 46, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", display())
	b.add_theme_font_size_override("font_size", size)
	var fill := Color(color, 0.22) if primary else Color(0.04, 0.03, 0.1, 0.85)
	var normal := box(color, fill)
	normal.content_margin_left = 36
	normal.content_margin_right = 36
	normal.content_margin_top = 22
	normal.content_margin_bottom = 22
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(color, 0.45)
	pressed.shadow_size = 26
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(color, 0.3) if primary else Color(color, 0.12)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.border_color = Color(color, 0.3)
	disabled.shadow_size = 0
	disabled.bg_color = Color(0.04, 0.03, 0.08, 0.7)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var txt := Color(1, 1, 1) if primary else color.lerp(Color.WHITE, 0.35)
	b.add_theme_color_override("font_color", txt)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(color, 0.35))
	b.button_down.connect(func():
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.94, 0.94), 0.06))
	b.button_up.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.pressed.connect(func(): Sfx.play("click"))
	return b


static func icon_rect(id: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.icon(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func fmt_time(seconds: float) -> String:
	var s := int(seconds)
	return "%02d:%02d" % [s / 60, s % 60]


static func fmt_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Fade + rise entrance used by most screens.
static func pop_in(node: CanvasItem, delay := 0.0, rise := 40.0) -> void:
	node.modulate.a = 0.0
	var ctl := node as Control
	if ctl and ctl.get_parent() is Container:
		ctl = null
	var base := ctl.position if ctl else Vector2.ZERO
	if ctl:
		ctl.position = base + Vector2(0, rise)
	var tw := node.create_tween().set_parallel()
	tw.tween_property(node, "modulate:a", 1.0, 0.35).set_delay(delay)
	if ctl:
		tw.tween_property(ctl, "position", base, 0.5).set_delay(delay).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

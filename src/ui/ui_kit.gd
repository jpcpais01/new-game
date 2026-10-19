class_name UiKit
extends RefCounted
## Shared UI building blocks: theme, label styles, buttons and panels.

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font = Art.font()
	_theme.default_font_size = 44
	_theme.set_color("font_color", "Label", PrismPalette.TEXT)
	_theme.set_color("font_color", "Button", PrismPalette.TEXT)
	_theme.set_color("font_pressed_color", "Button", PrismPalette.TEXT)
	_theme.set_color("font_hover_color", "Button", PrismPalette.TEXT)
	_theme.set_color("font_focus_color", "Button", PrismPalette.TEXT)
	_theme.set_font("font", "Button", Art.font_bold())
	_theme.set_font_size("font_size", "Button", 54)
	var empty := StyleBoxEmpty.new()
	_theme.set_stylebox("focus", "Button", empty)
	_theme.set_color("default_color", "RichTextLabel", PrismPalette.TEXT)
	_theme.set_font("normal_font", "RichTextLabel", Art.font())
	_theme.set_font("bold_font", "RichTextLabel", Art.font_bold())
	_theme.set_font_size("normal_font_size", "RichTextLabel", 38)
	_theme.set_font_size("bold_font_size", "RichTextLabel", 40)
	# Slim scrollbar for the patch notes.
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(1, 1, 1, 0.25)
	grabber.set_corner_radius_all(6)
	grabber.content_margin_left = 6
	grabber.content_margin_right = 6
	_theme.set_stylebox("grabber", "VScrollBar", grabber)
	_theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	_theme.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.05)
	track.set_corner_radius_all(6)
	track.content_margin_left = 6
	track.content_margin_right = 6
	_theme.set_stylebox("scroll", "VScrollBar", track)
	return _theme


static func label_settings(size: int, color := PrismPalette.TEXT, bold := true, outline := 0, shadow := true) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = Art.font_bold() if bold else Art.font()
	ls.font_size = size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = Color(0.04, 0.02, 0.12, 0.9)
	if shadow:
		ls.shadow_color = Color(0, 0, 0, 0.35)
		ls.shadow_offset = Vector2(0, 5)
		ls.shadow_size = 6
	return ls


static func label(text: String, size: int, color := PrismPalette.TEXT, bold := true) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = label_settings(size, color, bold)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel_style(radius := 44, alpha := 0.94) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.085, 0.07, 0.19, alpha)
	sb.border_color = Color(0.62, 0.55, 1.0, 0.28)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 50
	sb.shadow_offset = Vector2(0, 20)
	sb.set_content_margin_all(48)
	sb.anti_aliasing = true
	return sb


static func button(text: String, kind := "primary", min_size := Vector2(560, 150)) -> PrismButton:
	var b := PrismButton.new()
	b.text = text
	b.kind = kind
	b.custom_minimum_size = min_size
	b.apply_kind()
	return b


static func icon_button(icon_name: String, size := 128.0) -> PrismButton:
	var b := PrismButton.new()
	b.kind = "icon"
	b.icon = Art.icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(size, size)
	b.apply_kind()
	return b


static func chip(caption: String, value: String, tint := PrismPalette.ACCENT) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r, tint.g, tint.b, 0.14)
	sb.border_color = Color(tint.r, tint.g, tint.b, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(28)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var val := label(value, 50, PrismPalette.TEXT)
	var cap := label(caption.to_upper(), 24, PrismPalette.TEXT_DIM, false)
	v.add_child(val)
	v.add_child(cap)
	pc.add_child(v)
	return pc


static func format_score(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out

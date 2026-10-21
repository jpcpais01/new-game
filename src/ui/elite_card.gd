class_name EliteCard
extends Control
## An elite arrives: a glass card drops in under the HUD with its name ("SHIELDED
## PULSAR BRUTE"), the crest and one line per trait, then fades away. Elites
## carrying a trait you have never slain are marked NEW.

const SHOW_TIME := 3.2


static func make(type: int, mask: int, slain: Dictionary, width: float) -> EliteCard:
	var c := EliteCard.new()
	c._build(type, mask, slain, width)
	return c


func _build(type: int, mask: int, slain: Dictionary, width: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ids := Defs.trait_ids(mask)
	var lead: Color = Defs.TRAITS[ids[0]].color if not ids.is_empty() else Defs.TRAIT_COLOR
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiKit.box(Color(Defs.TRAIT_COLOR, 0.75), Color(0.03, 0.02, 0.07, 0.86), 24, 2, 14)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(width, 0)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	head.add_child(UiKit.icon_rect("trait", 46))
	var tag := "EXALTED ELITE" if ids.size() >= Defs.TRAIT_MAX else "ELITE"
	head.add_child(UiKit.glow_label(tag, 28, Defs.TRAIT_COLOR, UiKit.display_light()))
	var name_l := UiKit.glow_label(Defs.elite_name(type, mask), 40 if ids.size() < 3 else 34,
			lead.lerp(Color.WHITE, 0.45), UiKit.display())
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(width - 52, 0)
	col.add_child(name_l)
	for id in ids:
		var info: Dictionary = Defs.TRAITS[id]
		var tc: Color = info.color
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UiKit.icon_rect("trait_" + id, 60))
		var txt := VBoxContainer.new()
		txt.add_theme_constant_override("separation", -4)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		txt.add_child(UiKit.label(String(info.name).to_upper(), 26, tc.lerp(Color.WHITE, 0.3), UiKit.display(),
				HORIZONTAL_ALIGNMENT_LEFT))
		txt.add_child(UiKit.label(String(info.hint), 20, Color(0.9, 0.9, 1.0, 0.8), UiKit.display_light(),
				HORIZONTAL_ALIGNMENT_LEFT))
		row.add_child(txt)
		if int(slain.get(id, 0)) <= 0:
			row.add_child(UiKit.label("NEW", 22, UiKit.GOLD, UiKit.display(), HORIZONTAL_ALIGNMENT_RIGHT))
		col.add_child(row)
	modulate.a = 0.0
	scale = Vector2(1.08, 1.08)


func _ready() -> void:
	pivot_offset = Vector2(size.x * 0.5, 0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(SHOW_TIME - 0.75)
	tw.tween_property(self, "modulate:a", 0.0, 0.55)
	tw.tween_callback(queue_free)

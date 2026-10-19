class_name MissionsScreen
extends Control
## Missions: long-term goals with Flux rewards; some unlock new ships.

var main


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/ui/frost.gdshader")
	back.material = mat
	add_child(back)
	var top: float = main.safe_top()
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = top + 70
	col.offset_left = 50
	col.offset_right = -50
	col.offset_bottom = -60
	col.add_theme_constant_override("separation", 20)
	add_child(col)
	var done: Array = Save.data.missions
	col.add_child(UiKit.glow_label("MISSIONS", 84, UiKit.GOLD))
	col.add_child(UiKit.label("%d / %d COMPLETE" % [done.size(), Defs.MISSIONS.size()], 32, UiKit.DIM,
			UiKit.display_light()))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 18)
	scroll.add_child(list)
	# Open missions first, completed ones after.
	var k := 0
	for pass_done in [false, true]:
		for m in Defs.MISSIONS:
			if done.has(m.id) != pass_done:
				continue
			var row := _row(m, pass_done)
			list.add_child(row)
			if k < 8:
				UiKit.pop_in(row, 0.05 * k, 20)
			k += 1
	var b := UiKit.button("BACK", UiKit.CYAN, 46, true)
	b.custom_minimum_size = Vector2(0, 130)
	b.pressed.connect(func(): main.go_title())
	col.add_child(b)


func _row(m: Dictionary, is_done: bool) -> Control:
	var ship: String = m.get("ship", "")
	var col: Color = UiKit.GREEN if is_done else (Defs.ship(ship).color if ship != "" else UiKit.GOLD)
	var p := PanelContainer.new()
	var sb := UiKit.box(Color(col, 0.6 if not is_done else 0.3), Color(0.04, 0.03, 0.1, 0.9), 24, 2,
			8 if not is_done else 0)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	p.add_child(h)
	var icon := UiKit.icon_rect("ship_" + ship if ship != "" else "flux", 96)
	if is_done:
		icon.modulate = Color(1, 1, 1, 0.55)
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	v.add_child(UiKit.label(String(m.name).to_upper(), 32, Color.WHITE if not is_done else UiKit.DIM, UiKit.display(),
			HORIZONTAL_ALIGNMENT_LEFT))
	var t := String(m.text)
	if ship != "":
		t += "  Unlocks " + String(Defs.ship(ship).name) + "."
	var l := UiKit.label(t, 31, UiKit.DIM, UiKit.body(), HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	v.add_child(l)
	if not is_done:
		v.add_child(progress_bar(m, Missions.progress(m, null, Save.data), col))
	h.add_child(v)
	var reward := UiKit.label("✓" if is_done else "◆ %s" % UiKit.fmt_int(int(m.flux)), 34,
			UiKit.GREEN if is_done else UiKit.GOLD, UiKit.display(), HORIZONTAL_ALIGNMENT_RIGHT)
	reward.custom_minimum_size = Vector2(150, 0)
	h.add_child(reward)
	return p


## A slim neon progress bar with a "12 / 30" readout.
static func progress_bar(m: Dictionary, value: int, col: Color) -> Control:
	var bar := ProgressBarView.new()
	bar.value = value
	bar.goal = int(m.goal)
	bar.clock = String(m.kind) in ["time", "untouched", "afterdark"]
	bar.color = col
	bar.custom_minimum_size = Vector2(0, 40)
	return bar


func on_back() -> void:
	main.go_title()


class ProgressBarView extends Control:
	var value := 0
	var goal := 1
	var color := UiKit.GOLD
	var clock := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x - 280.0
		var y := size.y * 0.5 - 6.0
		draw_rect(Rect2(0, y, w, 12), Color(1, 1, 1, 0.1))
		var f := clampf(float(value) / float(maxi(goal, 1)), 0.0, 1.0)
		if f > 0.0:
			draw_rect(Rect2(0, y, w * f, 12), Color(color * 1.3, 1.0))
		var txt := "%s / %s" % [_fmt(value), _fmt(goal)]
		draw_string(UiKit.display_light(), Vector2(w + 16.0, y + 13.0), txt, HORIZONTAL_ALIGNMENT_RIGHT, 264, 24,
				Color(1, 1, 1, 0.75))

	func _fmt(n: int) -> String:
		return UiKit.fmt_time(float(n)) if clock else UiKit.fmt_int(n)

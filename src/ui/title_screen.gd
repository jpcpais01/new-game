class_name TitleScreen
extends Control
## Title: a live autopilot run plays behind the logo.

var main

var _settings: SettingsPanel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: float = main.safe_top()
	main.arena.ended.connect(func(_won): _restart_demo())
	var shade := TextureRect.new()
	shade.texture = _gradient()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var spacer_top := Control.new()
	spacer_top.custom_minimum_size = Vector2(0, top + 190)
	col.add_child(spacer_top)
	var logo := UiKit.glow_label("AFTERGLOW", 118, UiKit.CYAN)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/ui/logo.gdshader")
	logo.material = mat
	col.add_child(logo)
	var tag := UiKit.label("SURVIVE THE SWARM.  BECOME THE LIGHT.", 32, Color(0.85, 0.8, 1.0, 0.85),
			UiKit.display_light())
	col.add_child(tag)
	UiKit.pop_in(logo, 0.1, 30)
	UiKit.pop_in(tag, 0.35, 20)

	var mid := Control.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(mid)

	var d: Dictionary = Save.data
	if int(d.runs) > 0:
		var best := UiKit.label("BEST  %s   ·   LV %d   ·   %s KILLS" % [UiKit.fmt_time(float(d.best_time)),
				int(d.best_level), UiKit.fmt_int(int(d.best_kills))], 30, Color(0.85, 0.85, 1.0, 0.8),
				UiKit.display_light())
		col.add_child(best)
		UiKit.pop_in(best, 0.5)
	var known: Array = d.get("evolved", [])
	if not known.is_empty():
		var evo := UiKit.label("EVOLUTIONS DISCOVERED  %d / %d" % [known.size(), Defs.EVOLUTIONS.size()], 28,
				UiKit.GOLD, UiKit.display_light())
		col.add_child(evo)
		UiKit.pop_in(evo, 0.55)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	col.add_child(gap)

	var play := UiKit.button("PLAY", UiKit.CYAN, 64, true)
	play.custom_minimum_size = Vector2(620, 150)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func(): main.start_run())
	col.add_child(play)
	UiKit.pop_in(play, 0.45)
	var pulse := play.create_tween().set_loops()
	pulse.tween_property(play, "modulate", Color(1.25, 1.25, 1.25), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(play, "modulate", Color(1, 1, 1), 0.9).set_trans(Tween.TRANS_SINE)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 34)
	col.add_child(gap2)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	var forge := UiKit.button("FORGE  ◆ %s" % UiKit.fmt_int(int(d.flux)), UiKit.GOLD, 38)
	forge.custom_minimum_size = Vector2(430, 110)
	forge.pressed.connect(func(): main.go_forge())
	row.add_child(forge)
	var gear := UiKit.button("⚙", UiKit.MAGENTA, 46)
	gear.add_theme_font_override("font", UiKit.body())
	gear.custom_minimum_size = Vector2(160, 110)
	gear.pressed.connect(_open_settings)
	row.add_child(gear)
	UiKit.pop_in(row, 0.6)

	var bottom := Control.new()
	bottom.custom_minimum_size = Vector2(0, 120)
	col.add_child(bottom)
	var ver := UiKit.label("v" + str(ProjectSettings.get_setting("application/config/version")), 24,
			Color(1, 1, 1, 0.3), UiKit.display_light())
	ver.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ver.offset_top = -60
	ver.offset_bottom = -24
	add_child(ver)


func _gradient() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.005, 0.03, 0.85))
	g.add_point(0.3, Color(0.01, 0.005, 0.03, 0.15))
	g.add_point(0.55, Color(0.01, 0.005, 0.03, 0.2))
	g.set_color(g.get_point_count() - 1, Color(0.01, 0.005, 0.03, 0.92))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 256
	return t


func _restart_demo() -> void:
	main.arena.start(Sim.new(main.fresh_seed(), {"hull": 5, "power": 3}), true)


func _open_settings() -> void:
	if _settings and is_instance_valid(_settings):
		return
	_settings = SettingsPanel.new()
	add_child(_settings)


func on_back() -> void:
	if _settings and is_instance_valid(_settings):
		_settings.close()
		return
	get_tree().quit()

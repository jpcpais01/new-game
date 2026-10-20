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
	gap.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap)
	var sd := Defs.ship(Save.current_ship())
	var chip := HBoxContainer.new()
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_theme_constant_override("separation", 14)
	chip.add_child(UiKit.icon_rect("ship_" + String(sd.id), 64))
	chip.add_child(UiKit.label("%s  ·  %s" % [String(sd.name).to_upper(), String(sd.od).to_upper()], 30,
			Color(sd.color).lerp(Color.WHITE, 0.25), UiKit.display()))
	var rad := Save.current_radiance()
	if rad > 0:
		chip.add_child(UiKit.icon_rect("radiance", 56))
		chip.add_child(UiKit.label("R%d" % rad, 30, Defs.radiance_color(rad), UiKit.display()))
	var sec := Save.current_sector()
	if sec > 0:
		var secd := Defs.sector(sec)
		chip.add_child(UiKit.icon_rect("sector_" + String(secd.id), 56))
		chip.add_child(UiKit.label(String(secd.name).to_upper(), 30, Color(secd.color).lerp(Color.WHITE, 0.25),
				UiKit.display()))
	col.add_child(chip)
	UiKit.pop_in(chip, 0.4)
	var gap1 := Control.new()
	gap1.custom_minimum_size = Vector2(0, 14)
	col.add_child(gap1)

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
	gap2.custom_minimum_size = Vector2(0, 26)
	col.add_child(gap2)
	var daily := _daily_button()
	col.add_child(daily)
	UiKit.pop_in(daily, 0.5)
	var gap2g := Control.new()
	gap2g.custom_minimum_size = Vector2(0, 20)
	col.add_child(gap2g)
	var gauntlet := _gauntlet_button()
	col.add_child(gauntlet)
	UiKit.pop_in(gauntlet, 0.52)
	var gap2b := Control.new()
	gap2b.custom_minimum_size = Vector2(0, 24)
	col.add_child(gap2b)
	var row0 := HBoxContainer.new()
	row0.alignment = BoxContainer.ALIGNMENT_CENTER
	row0.add_theme_constant_override("separation", 28)
	col.add_child(row0)
	var fresh := not Save.unseen_ships().is_empty()
	var hangar := UiKit.button("HANGAR" + ("  •NEW" if fresh else ""), UiKit.CYAN, 38)
	hangar.custom_minimum_size = Vector2(430, 110)
	hangar.pressed.connect(func(): main.go_hangar())
	row0.add_child(hangar)
	if fresh:
		var hp := hangar.create_tween().set_loops()
		hp.tween_property(hangar, "modulate", Color(1.4, 1.4, 1.4), 0.6).set_trans(Tween.TRANS_SINE)
		hp.tween_property(hangar, "modulate", Color(1, 1, 1), 0.6).set_trans(Tween.TRANS_SINE)
	var done: int = (Save.data.missions as Array).size()
	var missions := UiKit.button("MISSIONS %d/%d" % [done, Defs.MISSIONS.size()], UiKit.GREEN, 34)
	missions.custom_minimum_size = Vector2(430, 110)
	missions.pressed.connect(func(): main.go_missions())
	row0.add_child(missions)
	UiKit.pop_in(row0, 0.55)
	var gap3 := Control.new()
	gap3.custom_minimum_size = Vector2(0, 24)
	col.add_child(gap3)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	var forge := UiKit.button("FORGE  ◆ %s" % UiKit.fmt_int(int(d.flux)), UiKit.GOLD, 34)
	forge.custom_minimum_size = Vector2(400, 110)
	forge.pressed.connect(func(): main.go_forge())
	row.add_child(forge)
	var codex := UiKit.button("CODEX", UiKit.MAGENTA, 34)
	codex.custom_minimum_size = Vector2(260, 110)
	codex.pressed.connect(func(): main.go_codex())
	row.add_child(codex)
	var gear := UiKit.button("⚙", UiKit.MAGENTA, 46)
	gear.add_theme_font_override("font", UiKit.body())
	gear.custom_minimum_size = Vector2(140, 110)
	gear.pressed.connect(_open_settings)
	row.add_child(gear)
	UiKit.pop_in(row, 0.6)

	var bottom := Control.new()
	bottom.custom_minimum_size = Vector2(0, 100)
	col.add_child(bottom)
	var ver := UiKit.label("v" + str(ProjectSettings.get_setting("application/config/version")), 24,
			Color(1, 1, 1, 0.3), UiKit.display_light())
	ver.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ver.offset_top = -60
	ver.offset_bottom = -24
	add_child(ver)


## Today's Daily Run: the ship, the streak, and a glow until you have flown it.
func _daily_button() -> Control:
	var day := Save.today()
	var dd := Daily.for_day(day)
	var played := not Save.daily_entry(day).is_empty()
	var b := UiKit.button("", UiKit.GOLD, 36)
	b.custom_minimum_size = Vector2(888, 120)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): main.go_daily())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 30
	h.offset_right = -30
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.add_child(UiKit.icon_rect("daily", 76))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(UiKit.label("DAILY RUN", 38, UiKit.GOLD.lerp(Color.WHITE, 0.3), UiKit.display(),
			HORIZONTAL_ALIGNMENT_LEFT))
	var e := Save.daily_entry(day)
	var sub := "BEST %s" % UiKit.fmt_int(int(e.score)) if played else "NEW RUN  ·  BOUNTY WAITING"
	var streak := Save.live_streak()
	if streak > 0:
		sub += "  ·  STREAK %d" % streak
	v.add_child(UiKit.label(sub, 24, UiKit.DIM, UiKit.display_light(), HORIZONTAL_ALIGNMENT_LEFT))
	if int(dd.sector) > 0:
		h.add_child(UiKit.icon_rect("sector_" + String(Defs.sector(int(dd.sector)).id), 52))
	for id in dd.mods:
		h.add_child(UiKit.icon_rect("mod_" + String(id), 52))
	h.add_child(UiKit.icon_rect("ship_" + String(dd.ship), 64))
	if not played:
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "modulate", Color(1.35, 1.3, 1.15), 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)
	return b


## The Gauntlet: the four bosses in a row, your best clear, or what unlocks it.
func _gauntlet_button() -> Control:
	var open := Save.gauntlet_unlocked()
	var g := Save.gauntlet_rec()
	var b := UiKit.button("", Defs.GAUNTLET_COLOR if open else UiKit.DIM, 36)
	b.custom_minimum_size = Vector2(888, 110)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.disabled = not open
	if open:
		b.pressed.connect(func(): main.go_gauntlet())
	else:
		b.modulate = Color(1, 1, 1, 0.6)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 30
	h.offset_right = -30
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	h.add_child(UiKit.icon_rect("gauntlet", 72))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	v.add_child(UiKit.label("THE GAUNTLET", 36, Defs.GAUNTLET_COLOR.lerp(Color.WHITE, 0.3) if open else UiKit.DIM,
			UiKit.display(), HORIZONTAL_ALIGNMENT_LEFT))
	var sub := "DEFEAT THE WARDEN TO UNLOCK"
	if open:
		sub = "BOSS RUSH  ·  NEW"
		if int(g.best_clear) > 0:
			sub = "BEST CLEAR %s" % GauntletScreen.fmt_split(int(g.best_clear))
		elif int(g.runs) > 0:
			sub = "MOST BOSSES %d  ·  NOT YET CLEARED" % int(g.best_felled)
	v.add_child(UiKit.label(sub, 24, UiKit.DIM, UiKit.display_light(), HORIZONTAL_ALIGNMENT_LEFT))
	for type in Defs.GAUNTLET:
		var tr := TextureRect.new()
		tr.texture = Art.enemy[type]
		tr.custom_minimum_size = Vector2(62, 62)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not open:
			tr.modulate = Color(0.4, 0.4, 0.5, 0.8)
		h.add_child(tr)
	return b


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
	main.arena.start(Sim.new(main.fresh_seed(), main.demo_loadout()), true)


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

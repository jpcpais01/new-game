class_name TitleScreen
extends Control
## Home screen: the gem logo, best score, Play / Continue, the Daily Prism,
## and quick access to stats, patch notes and settings.

var main: Node
var logo: LogoView
var _logo_holder: Control
var _modal: Modal
var _land_cooldown := 0.0
var _notes_badge: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var ins: Dictionary = main.safe_insets()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", int(ins.top) + 40)
	margin.add_theme_constant_override("margin_bottom", int(ins.bottom) + 40)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	col.add_child(_spacer(1.0))

	# Logo
	logo = LogoView.new()
	logo.block = floorf(minf(36.0, (size.x - 140.0) / 29.0)) if size.x > 0 else 34.0
	_logo_holder = Control.new()
	_logo_holder.custom_minimum_size = Vector2(0, logo.block * 5 + 20)
	_logo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_holder.add_child(logo)
	_logo_holder.resized.connect(_place_logo)
	logo.block_landed.connect(_on_block_landed)
	col.add_child(_logo_holder)

	var tag := UiKit.label("a block puzzle of light", 40, PrismPalette.TEXT_DIM, false)
	col.add_child(tag)

	col.add_child(_spacer(0.6))

	# Best score
	var best_row := HBoxContainer.new()
	best_row.alignment = BoxContainer.ALIGNMENT_CENTER
	best_row.add_theme_constant_override("separation", 16)
	best_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crown := TextureRect.new()
	crown.texture = Art.icon("crown")
	crown.custom_minimum_size = Vector2(60, 60)
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown.modulate = PrismPalette.GOLD
	best_row.add_child(crown)
	best_row.add_child(UiKit.label("BEST  " + UiKit.format_score(int(Save.data.best)), 54, PrismPalette.GOLD))
	col.add_child(best_row)

	col.add_child(_spacer(0.5))

	# Main actions
	var has_run: bool = Save.data.run is Dictionary
	var play := UiKit.button("CONTINUE" if has_run else "PLAY", "primary", Vector2(640, 172))
	play.add_theme_font_size_override("font_size", 64)
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.pressed.connect(func(): main.start_game("classic", has_run))
	col.add_child(play)
	_pulse(play)

	if has_run:
		var fresh := UiKit.button("NEW GAME", "ghost", Vector2(640, 116))
		fresh.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		fresh.pressed.connect(func(): main.start_game("classic", false))
		col.add_child(fresh)

	var today: String = main.today()
	var daily_best := Save.daily_best(today)
	var daily_txt := "DAILY PRISM"
	var daily := UiKit.button(daily_txt, "gold", Vector2(640, 150))
	daily.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var dr = Save.data.daily_run
	var resume_daily: bool = dr is Dictionary and dr.get("date", "") == today
	daily.pressed.connect(func(): main.start_game("daily", resume_daily))
	col.add_child(daily)

	var sub := "%s  ·  " % main.pretty_date(today)
	if daily_best > 0:
		sub += "today's best " + UiKit.format_score(daily_best)
	elif resume_daily:
		sub += "in progress"
	else:
		sub += "new puzzle!"
	var streak := int(Save.data.daily_streak)
	if streak > 1 and Save.data.daily_last == today:
		sub += "  ·  %d-day streak" % streak
	col.add_child(UiKit.label(sub, 32, PrismPalette.TEXT_DIM, false))

	col.add_child(_spacer(1.0))

	# Bottom bar
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 56)
	var stats_b := UiKit.icon_button("stats", 132)
	stats_b.pressed.connect(func(): _open(Dialogs.stats()))
	bar.add_child(_captioned(stats_b, "Stats"))
	var notes_b := UiKit.icon_button("sparkle", 132)
	notes_b.pressed.connect(func():
		_open(Dialogs.whats_new())
		if _notes_badge:
			_notes_badge.queue_free()
			_notes_badge = null)
	var notes_wrap := _captioned(notes_b, "What's new")
	bar.add_child(notes_wrap)
	if Dialogs.has_unseen_notes():
		_notes_badge = _badge()
		notes_b.add_child(_notes_badge)
	var set_b := UiKit.icon_button("gear", 132)
	set_b.pressed.connect(func(): _open(Dialogs.settings()))
	bar.add_child(_captioned(set_b, "Settings"))
	col.add_child(bar)

	var ver := UiKit.label("v" + str(ProjectSettings.get_setting("application/config/version")), 26, Color(1, 1, 1, 0.3), false)
	col.add_child(ver)


func _place_logo() -> void:
	logo.block = floorf(minf(36.0, (_logo_holder.size.x - 60.0) / 29.0))
	logo.position = Vector2((_logo_holder.size.x - logo.width_px()) / 2.0, 10)


func _on_block_landed() -> void:
	if _land_cooldown <= 0.0:
		Sfx.play("land", randf_range(0.9, 1.25), -10.0)
		_land_cooldown = 0.045


func _process(delta: float) -> void:
	_land_cooldown -= delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local := logo.to_local(event.position)
		if logo.contains(local):
			logo.burst(local)
			Sfx.play("whoosh", 1.2, -4.0)
			Sfx.haptic(25, 0.5)


func _spacer(ratio: float) -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = ratio
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _captioned(b: Control, caption: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	v.add_child(UiKit.label(caption, 28, PrismPalette.TEXT_DIM, false))
	return v


func _badge() -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ff4d6d")
	sb.set_corner_radius_all(16)
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(32, 32)
	p.position = Vector2(96, 4)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _pulse(b: Control) -> void:
	var tw := b.create_tween().set_loops()
	tw.tween_interval(1.6)
	tw.tween_property(b, "modulate", Color(1.18, 1.18, 1.25), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(b, "modulate", Color.WHITE, 0.55).set_trans(Tween.TRANS_SINE)


func _open(m: Modal) -> void:
	if _modal != null:
		return
	_modal = m
	m.closed.connect(func(): _modal = null)
	add_child(m)


func on_back() -> void:
	if _modal != null:
		_modal.close()
	else:
		get_tree().quit()

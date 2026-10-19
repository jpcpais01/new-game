class_name DailyScreen
extends Control
## The Daily Run: today's ship and mutators, your standing, the streak, the
## bounty, and a log of past days.

var main

var _clock: Label


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
	col.offset_top = top + 60
	col.offset_left = 50
	col.offset_right = -50
	col.offset_bottom = -50
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var day := Save.today()
	var d := Daily.for_day(day)
	var sd := Defs.ship(String(d.ship))
	col.add_child(UiKit.glow_label("DAILY RUN", 84, UiKit.GOLD))
	_clock = UiKit.label("", 30, UiKit.DIM, UiKit.display_light())
	col.add_child(_clock)
	_tick_clock()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)

	list.add_child(_ship_card(sd))
	var k := 0
	for id in d.mods:
		var row := _mod_row(String(id))
		list.add_child(row)
		UiKit.pop_in(row, 0.1 + 0.08 * k, 16)
		k += 1
	var same := UiKit.label("The same run for every pilot, no Forge upgrades. Score x%.2f." % Daily.multiplier(d.mods),
			28, UiKit.DIM, UiKit.body())
	same.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(same)
	list.add_child(_standing(day))
	var log := _history(day)
	if log != null:
		list.add_child(log)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var b := UiKit.button("BACK", UiKit.MAGENTA, 40)
	b.custom_minimum_size = Vector2(260, 130)
	b.pressed.connect(func(): main.go_title())
	row.add_child(b)
	var played := not Save.daily_entry(day).is_empty()
	var go := UiKit.button("FLY AGAIN" if played else "FLY TODAY'S RUN", UiKit.GOLD, 46, true)
	go.custom_minimum_size = Vector2(0, 130)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func(): main.start_daily())
	row.add_child(go)
	if not played:
		var tw := go.create_tween().set_loops()
		tw.tween_property(go, "modulate", Color(1.3, 1.25, 1.1), 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(go, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 20 == 0:
		_tick_clock()


func _tick_clock() -> void:
	var left := Save.daily_left()
	_clock.text = "%s   ·   NEXT RUN IN %02d:%02d:%02d" % [Daily.label(Save.today()), left / 3600, (left / 60) % 60,
			left % 60]


func _panel(col: Color, fill_a := 0.9) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiKit.box(Color(col, 0.6), Color(0.04, 0.03, 0.1, fill_a), 24, 2, 8)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	return p


func _ship_card(sd: Dictionary) -> Control:
	var col: Color = sd.color
	var p := _panel(col)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	p.add_child(h)
	h.add_child(UiKit.icon_rect("ship_" + String(sd.id), 150))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(UiKit.label("TODAY'S SHIP", 24, UiKit.DIM, UiKit.display_light(), HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(UiKit.glow_label(String(sd.name).to_upper(), 60, col))
	(v.get_child(1) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var t := "%s  ·  Overdrive: %s" % [sd.quirk, sd.od]
	if not Save.ship_unlocked(sd.id):
		t = "Not in your hangar yet: today you fly it anyway.  " + t
	var l := UiKit.label(t, 28, Color(0.9, 0.9, 1.0, 0.9), UiKit.body(), HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
	v.add_child(l)
	UiKit.pop_in(p, 0.0, 20)
	return p


func _mod_row(id: String) -> Control:
	var m: Dictionary = Defs.MUTATORS[id]
	var col: Color = m.color
	var p := _panel(col)
	var outer := HBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	p.add_child(outer)
	outer.add_child(UiKit.icon_rect("mod_" + id, 92))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	outer.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var name := UiKit.glow_label(String(m.name).to_upper(), 36, col, UiKit.display())
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name)
	var tag := "BOON" if m.boon else "BANE  +%d%% SCORE" % int(round(float(m.score) * 100.0))
	h.add_child(UiKit.label(tag, 24, UiKit.GREEN if m.boon else UiKit.RED, UiKit.display(), HORIZONTAL_ALIGNMENT_RIGHT))
	var l := UiKit.label(String(m.text), 30, Color(0.9, 0.9, 1.0, 0.9), UiKit.body(), HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(680, 0)
	v.add_child(l)
	return p


## Today's best, tries, the streak and what the next flight pays.
func _standing(day: int) -> Control:
	var e := Save.daily_entry(day)
	var p := _panel(UiKit.GOLD, 0.7)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	v.add_child(grid)
	_stat(grid, "TODAY'S BEST", UiKit.fmt_int(int(e.get("score", 0))) if not e.is_empty() else "-")
	_stat(grid, "TRIES", str(int(e.get("tries", 0))))
	var streak := Save.live_streak()
	_stat(grid, "STREAK", "%d DAY%s" % [streak, "" if streak == 1 else "S"])
	var note := ""
	if e.is_empty():
		var next := streak + 1 if int(Save.data.daily_last) == day - 1 else 1
		note = "Your first flight today pays a Daily Bounty of ◆ %d or more" % Save.daily_bounty(0, next)
		if next > 1:
			note += ", +%d%% for your streak" % (10 * mini(next - 1, 5))
		note += "."
	else:
		note = "Bounty claimed. Fly again to beat %s: only your best counts." % UiKit.fmt_int(int(e.score))
	var l := UiKit.label(note, 28, UiKit.GOLD.lerp(Color.WHITE, 0.3), UiKit.body())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(800, 0)
	v.add_child(l)
	return p


func _stat(grid: GridContainer, name: String, value: String) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(250, 0)
	box.add_theme_constant_override("separation", 0)
	box.add_child(UiKit.label(name, 22, UiKit.DIM, UiKit.display_light()))
	box.add_child(UiKit.glow_label(value, 40, Color.WHITE))
	grid.add_child(box)


## Past days, newest first: date, ship, best score, time, dawn.
func _history(today: int) -> Control:
	var past: Array = []
	for e in Save.data.daily_log:
		if int(e.day) != today:
			past.append(e)
	if past.is_empty():
		return null
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(UiKit.label("PAST DAYS  ·  BEST STREAK %d" % int(Save.data.daily_streak_best), 26, UiKit.CYAN,
			UiKit.display()))
	var best := 0
	for e in past:
		best = maxi(best, int(e.score))
	for e in past.slice(0, 14):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		var date := UiKit.label(Daily.label(int(e.day)), 28, UiKit.DIM, UiKit.display_light(), HORIZONTAL_ALIGNMENT_LEFT)
		date.custom_minimum_size = Vector2(170, 0)
		h.add_child(date)
		h.add_child(UiKit.icon_rect("ship_" + String(e.ship), 54))
		var top := int(e.score) == best
		var sc := UiKit.label(UiKit.fmt_int(int(e.score)), 32, UiKit.GOLD if top else Color.WHITE, UiKit.display(),
				HORIZONTAL_ALIGNMENT_LEFT)
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sc)
		h.add_child(UiKit.label(UiKit.fmt_time(float(e.time)) + ("  ✓" if bool(e.dawn) else ""), 28,
				UiKit.GOLD if bool(e.dawn) else UiKit.DIM, UiKit.display_light(), HORIZONTAL_ALIGNMENT_RIGHT))
		v.add_child(h)
	return v


func on_back() -> void:
	main.go_title()

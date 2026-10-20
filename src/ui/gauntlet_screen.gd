class_name GauntletScreen
extends Control
## The Gauntlet: the four bosses back to back. Shows the ladder with your best
## split for each boss, your records and the ship you will fly.

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
	col.offset_top = top + 60
	col.offset_left = 50
	col.offset_right = -50
	col.offset_bottom = -50
	col.add_theme_constant_override("separation", 14)
	add_child(col)

	var g := Save.gauntlet_rec()
	var title := UiKit.glow_label("THE GAUNTLET", 84, Defs.GAUNTLET_COLOR)
	col.add_child(title)
	UiKit.pop_in(title, 0.0, 20)
	col.add_child(UiKit.label("FOUR BOSSES BACK TO BACK.  THEN AGAIN.", 30, UiKit.DIM, UiKit.display_light()))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)

	list.add_child(_records(g))
	var splits: Array = g.splits
	for k in Defs.GAUNTLET.size():
		var row := _boss_row(k, int(splits[k]))
		list.add_child(row)
		UiKit.pop_in(row, 0.1 + 0.08 * k, 16)
	var rules := UiKit.label(("Draft %d cards, then the Leviathan arrives. Each boss that falls leaves its cache, " +
			"and the next one comes %d seconds later. Fell a boss in under %s for a speed bonus. Clear all four and " +
			"the cycle starts again, stronger. No rifts, no elites. Your ship and Forge fly with you; Radiance " +
			"stays behind.") % [Defs.GAUNTLET_DRAFT, Defs.GAUNTLET_BREATHER, UiKit.fmt_time(float(Defs.GAUNTLET_PAR))],
			28, UiKit.DIM, UiKit.body())
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size = Vector2(800, 0)
	list.add_child(rules)
	list.add_child(_ship_card())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var b := UiKit.button("BACK", UiKit.MAGENTA, 40)
	b.custom_minimum_size = Vector2(260, 130)
	b.pressed.connect(func(): main.go_title())
	row.add_child(b)
	var go := UiKit.button("ENTER THE GAUNTLET", Defs.GAUNTLET_COLOR, 44, true)
	go.custom_minimum_size = Vector2(0, 130)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func(): main.start_gauntlet())
	row.add_child(go)
	var tw := go.create_tween().set_loops()
	tw.tween_property(go, "modulate", Color(1.3, 1.2, 1.05), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(go, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)


func _panel(c: Color, fill_a := 0.9) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiKit.box(Color(c, 0.6), Color(0.04, 0.03, 0.1, fill_a), 24, 2, 8)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	return p


## Best clear, clears, most bosses felled and the sum of your best splits.
func _records(g: Dictionary) -> Control:
	var p := _panel(Defs.GAUNTLET_COLOR, 0.7)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	p.add_child(grid)
	var best := int(g.best_clear)
	_stat(grid, "BEST CLEAR", fmt_split(best) if best > 0 else "-")
	_stat(grid, "CLEARS", "%d / %d" % [int(g.clears), int(g.runs)])
	_stat(grid, "MOST BOSSES", str(int(g.best_felled)))
	var sum := 0
	var full := true
	for t in g.splits:
		if int(t) <= 0:
			full = false
		sum += int(t)
	_stat(grid, "SUM OF BEST", fmt_split(sum) if full else "-")
	_stat(grid, "BEST SCORE", UiKit.fmt_int(int(g.best_score)) if int(g.best_score) > 0 else "-")
	_stat(grid, "LIGHTSPEED", "UNDER " + UiKit.fmt_time(float(Defs.GAUNTLET_FAST)))
	return p


func _stat(grid: GridContainer, name: String, value: String) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(250, 0)
	box.add_theme_constant_override("separation", 0)
	box.add_child(UiKit.label(name, 22, UiKit.DIM, UiKit.display_light()))
	box.add_child(UiKit.glow_label(value, 40, Color.WHITE))
	grid.add_child(box)


## One rung of the ladder: the boss, its epithet and your best split.
func _boss_row(k: int, best: int) -> Control:
	var type: int = Defs.GAUNTLET[k]
	var c: Color = Defs.ENEMY_COLOR[type]
	var p := _panel(c)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	p.add_child(h)
	var num := UiKit.label(str(k + 1), 44, Color(c, 0.6), UiKit.display())
	num.custom_minimum_size = Vector2(40, 0)
	h.add_child(num)
	var tr := TextureRect.new()
	tr.texture = Art.enemy[type]
	tr.custom_minimum_size = Vector2(104, 104)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(tr)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	h.add_child(v)
	var name := UiKit.glow_label(String(Hud.BOSS_NAMES[type]), 38, c)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(name)
	v.add_child(UiKit.label(String(Hud.BOSS_EPITHETS[type]), 22, UiKit.DIM, UiKit.display_light(),
			HORIZONTAL_ALIGNMENT_LEFT))
	var r := VBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", -4)
	h.add_child(r)
	r.add_child(UiKit.label("BEST", 20, UiKit.DIM, UiKit.display_light(), HORIZONTAL_ALIGNMENT_RIGHT))
	r.add_child(UiKit.label(fmt_split(best) if best > 0 else "-", 40,
			Defs.GAUNTLET_COLOR.lerp(Color.WHITE, 0.4) if best > 0 else UiKit.DIM, UiKit.display(), HORIZONTAL_ALIGNMENT_RIGHT))
	return p


func _ship_card() -> Control:
	var sd := Defs.ship(Save.current_ship())
	var c: Color = sd.color
	var p := _panel(c, 0.6)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	p.add_child(h)
	h.add_child(UiKit.icon_rect("ship_" + String(sd.id), 96))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(UiKit.label("YOUR SHIP  ·  CHANGE IT IN THE HANGAR", 22, UiKit.DIM, UiKit.display_light(),
			HORIZONTAL_ALIGNMENT_LEFT))
	var n := UiKit.glow_label("%s  ·  %s" % [String(sd.name).to_upper(), String(sd.od).to_upper()], 38, c)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(n)
	return p


## A split as 0:42.3.
static func fmt_split(ticks: int) -> String:
	var tenths := int(round(float(ticks) / float(Sim.TPS) * 10.0))
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]


func on_back() -> void:
	main.go_title()

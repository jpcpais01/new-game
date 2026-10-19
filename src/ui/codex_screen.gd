class_name CodexScreen
extends Control
## The Codex: every evolution (silhouettes until discovered, recipes always
## shown) and a bestiary of the swarm.

var main

const LORE := [
	["Drifter", "The first light-eaters. Slow, endless, and never alone."],
	["Dart", "Locks on, flashes a warning line, then lunges. Step aside."],
	["Splitter", "Breaks into three mites when it dies. Kill it away from you."],
	["Mite", "Tiny, fast and fragile. Born from splitters and the Eclipse."],
	["Weaver", "Swings side to side as it closes in, hard to line up."],
	["Brute", "A slow hexagonal wall that shrugs off knockback."],
	["Spitter", "Keeps its distance and fires orbs. Hunt it down."],
	["Bomber", "Lights its fuse when close. Shoot it and it bursts on its friends."],
	["Phantom", "Fades out, marks a ring of light beside you, then blinks into it. Watch the ring."],
	["Sentinel", "Anchors, tracks you with a warning line, then fires a long beam. Step out of the line."],
	["Bastion", "Hangs back behind the swarm. Everything inside its aegis takes half damage. Break it first."],
	["The Warden", "Arrives at 4:00. Radial bursts and summoned drifters. Overloads if you stall."],
	["Eclipse", "Arrives at 8:00. Spiral streams, dashes and swarms. Defeat it to reach the dawn."],
	["The Seraph", "Arrives at 6:00. A turning wheel of lasers, aimed lances, and it blinks to your side in a ring of fire. Ride the gaps between its arms."],
]


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
	col.add_theme_constant_override("separation", 18)
	add_child(col)
	var known: Array = Save.data.get("evolved", [])
	col.add_child(UiKit.glow_label("CODEX", 84, UiKit.MAGENTA))
	col.add_child(UiKit.label("EVOLUTIONS DISCOVERED  %d / %d" % [known.size(), Defs.EVOLUTIONS.size()], 30,
			UiKit.GOLD, UiKit.display_light()))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	list.add_child(grid)
	var k := 0
	for w in Defs.WEAPON_ORDER:
		var card := _evo_card(w, known.has(w))
		grid.add_child(card)
		UiKit.pop_in(card, 0.05 * k, 20)
		k += 1
	list.add_child(UiKit.label("THE SWARM", 34, UiKit.CYAN, UiKit.display()))
	for i in LORE.size():
		list.add_child(_enemy_row(i))
	var b := UiKit.button("BACK", UiKit.CYAN, 46, true)
	b.custom_minimum_size = Vector2(0, 130)
	b.pressed.connect(func(): main.go_title())
	col.add_child(b)


func _evo_card(w: String, found: bool) -> Control:
	var evo: Dictionary = Defs.EVOLUTIONS[w]
	var col: Color = evo.color if found else Color(0.45, 0.42, 0.6)
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := UiKit.box(Color(col, 0.6), Color(0.04, 0.03, 0.1, 0.9), 24, 2, 10 if found else 0)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var ic := UiKit.icon_rect(w + "_evo", 150)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not found:
		ic.modulate = Color(0.08, 0.06, 0.16, 0.95)
	else:
		var tw := ic.create_tween().set_loops()
		tw.tween_property(ic, "modulate", Color(1.35, 1.35, 1.35), 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(ic, "modulate", Color.WHITE, 1.2).set_trans(Tween.TRANS_SINE)
	v.add_child(ic)
	v.add_child(UiKit.glow_label(String(evo.name).to_upper() if found else "? ? ?", 30,
			col.lerp(Color.WHITE, 0.2) if found else Color(0.6, 0.58, 0.75), UiKit.display()))
	var recipe := HBoxContainer.new()
	recipe.alignment = BoxContainer.ALIGNMENT_CENTER
	recipe.add_theme_constant_override("separation", 8)
	recipe.add_child(UiKit.icon_rect(w, 56))
	recipe.add_child(UiKit.label("5  +", 28, UiKit.DIM, UiKit.display()))
	recipe.add_child(UiKit.icon_rect(String(evo.needs), 56))
	v.add_child(recipe)
	var txt := String(Defs.WEAPONS[w].levels[Defs.EVO_LEVEL - 1].text) if found else \
			"Max %s, carry %s, then open a Prism Cache." % [Defs.WEAPONS[w].name, Defs.PASSIVES[evo.needs].name]
	var l := UiKit.label(txt, 26, Color(0.9, 0.9, 1.0, 0.85) if found else UiKit.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(400, 0)
	v.add_child(l)
	return p


func _enemy_row(i: int) -> Control:
	var col: Color = Defs.ENEMY_COLOR[i]
	var p := PanelContainer.new()
	var sb := UiKit.box(Color(col, 0.4), Color(0.04, 0.03, 0.1, 0.85), 20, 2, 0)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	var t := TextureRect.new()
	t.texture = Art.enemy[i]
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(96, 96)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(UiKit.label(String(LORE[i][0]).to_upper(), 28, col.lerp(Color.WHITE, 0.3), UiKit.display(),
			HORIZONTAL_ALIGNMENT_LEFT))
	var l := UiKit.label(String(LORE[i][1]), 28, Color(0.88, 0.88, 1.0, 0.85), UiKit.body(), HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)
	v.add_child(l)
	return p


func on_back() -> void:
	main.go_title()

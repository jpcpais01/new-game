class_name ForgeScreen
extends Control
## The Forge: spend Flux on permanent upgrades between runs.

var main

var _flux: Label
var _list: VBoxContainer


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
	col.add_theme_constant_override("separation", 22)
	add_child(col)
	col.add_child(UiKit.glow_label("THE FORGE", 88, UiKit.GOLD))
	col.add_child(UiKit.label("Permanent upgrades. They power every future run.", 34, UiKit.DIM))
	_flux = UiKit.glow_label("", 54, UiKit.GOLD)
	col.add_child(_flux)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 20)
	scroll.add_child(_list)
	var done := UiKit.button("BACK", UiKit.CYAN, 46, true)
	done.custom_minimum_size = Vector2(0, 130)
	done.pressed.connect(func(): main.go_title())
	col.add_child(done)
	_refresh()


func _refresh() -> void:
	_flux.text = "◆ %s" % UiKit.fmt_int(int(Save.data.flux))
	for c in _list.get_children():
		c.queue_free()
	var k := 0
	for f in Defs.FORGE:
		var row := _row(f)
		_list.add_child(row)
		k += 1


func _row(f: Dictionary) -> Control:
	var lvl := Save.forge_level(f.id)
	var mx: int = f.max
	var cost := Save.forge_cost(f.id)
	var col := Art.card_color(f.id)
	if col == Color.WHITE:
		col = UiKit.GOLD
	var p := PanelContainer.new()
	var sb := UiKit.box(Color(col, 0.7), Color(0.04, 0.03, 0.1, 0.9), 26, 2, 10)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	p.add_child(h)
	h.add_child(UiKit.icon_rect(f.id, 118))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	mid.add_child(UiKit.label(String(f.name).to_upper(), 38, Color.WHITE, UiKit.display(), HORIZONTAL_ALIGNMENT_LEFT))
	mid.add_child(UiKit.label(f.text, 32, UiKit.DIM, UiKit.body(), HORIZONTAL_ALIGNMENT_LEFT))
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 8)
	for i in mx:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(42, 12)
		var psb := StyleBoxFlat.new()
		psb.set_corner_radius_all(6)
		psb.bg_color = UiKit.GOLD if i < lvl else Color(1, 1, 1, 0.12)
		pip.add_theme_stylebox_override("panel", psb)
		pips.add_child(pip)
	mid.add_child(pips)
	h.add_child(mid)
	var buy := UiKit.button("MAX" if cost < 0 else "◆ %s" % UiKit.fmt_int(cost), UiKit.GOLD, 34, cost >= 0)
	buy.custom_minimum_size = Vector2(220, 100)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = cost < 0 or int(Save.data.flux) < cost
	buy.pressed.connect(func():
		if Save.buy(f.id):
			Sfx.play("buy")
			Sfx.buzz(30)
			_refresh())
	h.add_child(buy)
	return p


func on_back() -> void:
	main.go_title()

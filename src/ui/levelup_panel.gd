class_name LevelUpPanel
extends Control
## The level-up moment: the world freezes behind frosted glass and three
## upgrade cards fly in. Tap one to take it.

signal picked(index: int)
signal reroll_pressed

var sim: Sim
var _cards: Array = []
var _title: Label
var _reroll: Button
var _locked := false
var _backdrop: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/ui/frost.gdshader")
	_backdrop.material = mat
	add_child(_backdrop)


func open(s: Sim) -> void:
	sim = s
	_locked = false
	for c in get_children():
		if c != _backdrop:
			c.queue_free()
	_cards.clear()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	var w := size.x
	var h := size.y
	_title = UiKit.glow_label("LEVEL UP", 92, UiKit.GOLD)
	_title.position = Vector2(0, h * 0.11)
	_title.size = Vector2(w, 120)
	_title.pivot_offset = _title.size * 0.5
	add_child(_title)
	_title.scale = Vector2(1.8, 1.8)
	create_tween().tween_property(_title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var sub := UiKit.label("LEVEL %d  ·  CHOOSE AN UPGRADE" % s.level, 32, UiKit.DIM, UiKit.display_light())
	sub.position = Vector2(0, h * 0.11 + 112)
	sub.size = Vector2(w, 40)
	add_child(sub)
	var card_w := minf(w - 80.0, 940.0)
	var card_h := 300.0
	var gap := 34.0
	var y0 := h * 0.11 + 190.0
	for k in s.choices.size():
		var card := _make_card(s.choices[k], k, Vector2(card_w, card_h))
		card.position = Vector2((w - card_w) * 0.5, y0 + k * (card_h + gap))
		add_child(card)
		_cards.append(card)
		var target := card.position
		card.position.x += w
		var tw := card.create_tween()
		tw.tween_interval(0.12 + k * 0.09)
		tw.tween_callback(func(): Sfx.play("card", 1.0 + k * 0.08))
		tw.tween_property(card, "position", target, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reroll = UiKit.button("REROLL  ×%d" % s.rerolls, UiKit.MAGENTA, 36)
	_reroll.position = Vector2((w - 420) * 0.5, y0 + 3 * (card_h + gap) + 10)
	_reroll.custom_minimum_size = Vector2(420, 0)
	_reroll.visible = s.rerolls > 0
	_reroll.pressed.connect(func():
		if not _locked:
			reroll_pressed.emit())
	add_child(_reroll)


func _make_card(id: String, index: int, sz: Vector2) -> Control:
	var info := Defs.card_info(id)
	var col: Color = info.get("color", Color.WHITE)
	var lvl := sim.card_level(id)
	var is_new := lvl == 0 and (Defs.is_weapon(id) or Defs.PASSIVES.has(id))
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.size = sz
	card.custom_minimum_size = sz
	var sb := UiKit.box(col, Color(0.04, 0.03, 0.1, 0.94), 28, 4, 22)
	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(col, 0.25)
	card.add_theme_stylebox_override("normal", sb)
	card.add_theme_stylebox_override("hover", sb)
	card.add_theme_stylebox_override("pressed", sb_p)
	card.add_theme_stylebox_override("hover_pressed", sb_p)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.pivot_offset = sz * 0.5
	# Icon disc.
	var disc := Panel.new()
	var dsb := UiKit.box(col, Color(col, 0.12), 90, 2, 10)
	disc.add_theme_stylebox_override("panel", dsb)
	disc.position = Vector2(34, (sz.y - 170) * 0.5)
	disc.size = Vector2(170, 170)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(disc)
	var ic := UiKit.icon_rect(id, 150)
	ic.position = Vector2(10, 10)
	ic.size = Vector2(150, 150)
	disc.add_child(ic)
	var tx := 236.0
	var name := UiKit.label(String(info.get("name", id)).to_upper(), 44, col.lerp(Color.WHITE, 0.3), UiKit.display(),
			HORIZONTAL_ALIGNMENT_LEFT)
	name.position = Vector2(tx, 34)
	name.size = Vector2(sz.x - tx - 30, 56)
	card.add_child(name)
	var tag_text := ""
	if is_new:
		tag_text = "NEW WEAPON" if Defs.is_weapon(id) else "NEW SYSTEM"
	elif lvl > 0:
		tag_text = "LEVEL %d  →  %d" % [lvl, lvl + 1]
	var tag := UiKit.label(tag_text, 28, UiKit.GOLD if is_new else UiKit.DIM, UiKit.display_light(),
			HORIZONTAL_ALIGNMENT_LEFT)
	tag.position = Vector2(tx, 92)
	tag.size = Vector2(sz.x - tx - 30, 36)
	card.add_child(tag)
	var desc_text: String = info.get("text", "")
	if Defs.is_weapon(id):
		desc_text = Defs.WEAPONS[id].levels[mini(lvl, Defs.MAX_LEVEL - 1)].text
	var desc := UiKit.label(desc_text, 38, Color(0.92, 0.92, 1.0), UiKit.body(), HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc.position = Vector2(tx, 140)
	desc.size = Vector2(sz.x - tx - 34, 110)
	card.add_child(desc)
	_evo_badge(card, id, sz, name)
	# Level pips.
	if Defs.is_weapon(id) or Defs.PASSIVES.has(id):
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 8)
		pips.position = Vector2(tx, sz.y - 48)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for p in Defs.MAX_LEVEL:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(38, 12)
			var on := p < lvl
			var nxt := p == lvl
			var psb := StyleBoxFlat.new()
			psb.set_corner_radius_all(6)
			psb.bg_color = col if on else (Color(col, 0.55) if nxt else Color(1, 1, 1, 0.12))
			pip.add_theme_stylebox_override("panel", psb)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if nxt:
				var tw := pip.create_tween().set_loops()
				tw.tween_property(pip, "modulate:a", 0.35, 0.4)
				tw.tween_property(pip, "modulate:a", 1.0, 0.4)
			pips.add_child(pip)
		card.add_child(pips)
	card.pressed.connect(func(): _pick(index))
	return card


func _pick(index: int) -> void:
	if _locked:
		return
	_locked = true
	Sfx.play("select")
	Sfx.buzz(25)
	for k in _cards.size():
		var c: Control = _cards[k]
		var tw := c.create_tween().set_parallel()
		if k == index:
			tw.tween_property(c, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK)
			tw.tween_property(c, "modulate", Color(1.6, 1.6, 1.6, 1.0), 0.12)
			tw.chain().tween_property(c, "modulate:a", 0.0, 0.18)
		else:
			tw.tween_property(c, "modulate:a", 0.0, 0.15)
			tw.tween_property(c, "position:y", c.position.y + 40.0, 0.15)
	var t := create_tween()
	t.tween_interval(0.26)
	t.tween_callback(func(): picked.emit(index))


func close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): visible = false)


## Top-right badge showing what this card evolves with (weapons) or into
## (catalyst systems for a weapon you carry). Gold when it is relevant now.
func _evo_badge(card: Control, id: String, sz: Vector2, name: Label) -> void:
	var icon_id := ""
	var hot := false
	if Defs.EVOLUTIONS.has(id):
		var need: String = Defs.EVOLUTIONS[id].needs
		icon_id = need
		hot = sim.passives.has(need)
	elif Defs.PASSIVES.has(id):
		var base := Defs.evolves(id)
		if base != "" and sim.weapon_level(base) > 0 and not sim.is_evolved(base):
			icon_id = base + "_evo"
			hot = true
	if icon_id == "":
		return
	name.size.x -= 120.0
	var col := UiKit.GOLD if hot else Color(1, 1, 1, 0.35)
	var disc := Panel.new()
	disc.add_theme_stylebox_override("panel", UiKit.box(col, Color(col, 0.1), 50, 2, 8 if hot else 0))
	disc.position = Vector2(sz.x - 124, 16)
	disc.size = Vector2(96, 96)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(disc)
	var ic := UiKit.icon_rect(icon_id, 76)
	ic.position = Vector2(10, 10)
	ic.size = Vector2(76, 76)
	ic.modulate = Color.WHITE if hot else Color(1, 1, 1, 0.45)
	disc.add_child(ic)
	var tag := UiKit.label("EVOLVES", 18, col, UiKit.display())
	tag.position = Vector2(sz.x - 134, 112)
	tag.size = Vector2(116, 24)
	card.add_child(tag)
	if hot:
		var tw := disc.create_tween().set_loops()
		tw.tween_property(disc, "modulate", Color(1.5, 1.3, 0.8), 0.5)
		tw.tween_property(disc, "modulate", Color.WHITE, 0.5)

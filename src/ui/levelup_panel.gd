class_name LevelUpPanel
extends Control
## The level-up moment: the world freezes behind frosted glass and three
## upgrade cards fly in. Tap one to take it. Relic offers use the same panel
## in violet. BANISH arms a one-tap banish: the next card tapped is struck
## from the run and a new one takes its place.

signal picked(index: int)
signal reroll_pressed
signal banish_pressed(index: int)
signal decline_pressed

var sim: Sim
var _cards: Array = []
var _title: Label
var _reroll: Button
var _banish: Button
var _banish_mode := false
var _locked := false
var _backdrop: ColorRect
var _card_size := Vector2.ZERO
var _hint: Label
var _teach := false

const RELIC_COL := Color(0.78, 0.55, 1.0)
const BANISH_COL := Color(1.0, 0.3, 0.38)


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
	_banish_mode = false
	for c in get_children():
		if c != _backdrop:
			c.queue_free()
	_cards.clear()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	var w := size.x
	var h := size.y
	var relic := s.relic_choice
	var umbral := s.umbral_choice
	var head_col := Defs.UMBRAL_COLOR if umbral else (RELIC_COL if relic else UiKit.GOLD)
	_title = UiKit.glow_label("UMBRAL RELIC" if umbral else ("RELIC" if relic else "LEVEL UP"), 92 if not umbral else 80,
			head_col)
	_title.position = Vector2(0, h * 0.11)
	_title.size = Vector2(w, 120)
	_title.pivot_offset = _title.size * 0.5
	add_child(_title)
	_title.scale = Vector2(1.8, 1.8)
	create_tween().tween_property(_title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var sub_text := "LEVEL %d  ·  CHOOSE AN UPGRADE" % s.level
	if umbral:
		sub_text = "POWER AT A PRICE  ·  OR REFUSE ALL THREE"
	elif relic:
		sub_text = "CHOOSE ONE  ·  IT LASTS THE WHOLE RUN"
	var sub := UiKit.label(sub_text, 32, UiKit.DIM, UiKit.display_light())
	if relic:
		Sfx.play("relic", 0.8)
		Sfx.buzz(40)
	sub.position = Vector2(0, h * 0.11 + 112)
	sub.size = Vector2(w, 40)
	add_child(sub)
	var card_w := minf(w - 80.0, 940.0)
	var card_h := 300.0
	_card_size = Vector2(card_w, card_h)
	var gap := 34.0
	var y0 := h * 0.11 + 190.0
	for k in s.choices.size():
		var card := _make_card(s.choices[k], Vector2(card_w, card_h))
		card.position = Vector2((w - card_w) * 0.5, y0 + k * (card_h + gap))
		add_child(card)
		_cards.append(card)
		var target := card.position
		card.position.x += w
		var tw := card.create_tween()
		tw.tween_interval(0.12 + k * 0.09)
		tw.tween_callback(func(): Sfx.play("card", 1.0 + k * 0.08))
		tw.tween_property(card, "position", target, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var row_y := y0 + 3 * (card_h + gap) + 10
	var can_banish := s.banishes > 0 and not relic
	# An Umbral offer can be refused: the REFUSE button sits where BANISH would.
	var both := s.rerolls > 0 and (can_banish or umbral)
	var bw := 400.0
	_reroll = UiKit.button("REROLL  ×%d" % s.rerolls, UiKit.MAGENTA, 36)
	_reroll.position = Vector2(w * 0.5 - bw - 20.0 if both else (w - bw) * 0.5, row_y)
	_reroll.custom_minimum_size = Vector2(bw, 0)
	_reroll.visible = s.rerolls > 0
	_reroll.pressed.connect(func():
		if not _locked:
			reroll_pressed.emit())
	add_child(_reroll)
	_banish = UiKit.button("", BANISH_COL, 36)
	_banish.position = Vector2(w * 0.5 + 20.0 if both else (w - bw) * 0.5, row_y)
	_banish.custom_minimum_size = Vector2(bw, 0)
	_banish.visible = can_banish
	_banish.pressed.connect(_toggle_banish)
	add_child(_banish)
	if umbral:
		var refuse := UiKit.button("REFUSE  ·  TAKE A CACHE", Defs.UMBRAL_COLOR, 30)
		refuse.position = Vector2(w * 0.5 + 20.0 if both else (w - 520.0) * 0.5, row_y)
		refuse.custom_minimum_size = Vector2(bw if both else 520.0, 0)
		refuse.pressed.connect(func():
			if not _locked:
				_locked = true
				Sfx.play("click", 0.8)
				decline_pressed.emit())
		add_child(refuse)
	_hint = UiKit.label("", 28, BANISH_COL, UiKit.display_light())
	_hint.position = Vector2(0, row_y + 120)
	_hint.size = Vector2(w, 40)
	add_child(_hint)
	_teach = can_banish and s.level >= 3 and Save.tip_once("banish")
	_sync_banish()


func _make_card(id: String, sz: Vector2) -> Control:
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
	if Defs.is_umbral(id):
		tag_text = "UMBRAL RELIC"
	elif Defs.is_relic(id):
		tag_text = "RELIC"
	elif is_new:
		tag_text = "NEW WEAPON" if Defs.is_weapon(id) else "NEW SYSTEM"
	elif lvl > 0:
		tag_text = "LEVEL %d  →  %d" % [lvl, lvl + 1]
	var tag_col := UiKit.GOLD if is_new else (RELIC_COL if Defs.is_relic(id) else UiKit.DIM)
	if Defs.is_umbral(id):
		tag_col = Defs.UMBRAL_COLOR
	var tag := UiKit.label(tag_text, 28, tag_col,
			UiKit.display_light(),
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
	card.pressed.connect(func(): _on_card(card))
	return card


func _on_card(card: Control) -> void:
	var index := _cards.find(card)
	if index < 0:
		return
	if _banish_mode:
		if _locked or not Sim.can_banish(sim.choices[index]):
			Sfx.play("click", 0.7)
			return
		_locked = true
		banish_pressed.emit(index)
	else:
		_pick(index)


func _toggle_banish() -> void:
	if _locked or sim == null or sim.banishes <= 0:
		return
	_banish_mode = not _banish_mode
	_teach = false
	Sfx.play("click", 0.8 if _banish_mode else 1.1)
	_sync_banish()


## BANISH is armed: cards that can go glow red and shiver.
func _sync_banish() -> void:
	if _banish == null:
		return
	_banish.text = ("CANCEL" if _banish_mode else "BANISH  ×%d" % sim.banishes)
	_banish.visible = sim.banishes > 0 and not sim.relic_choice
	_hint.text = "TAP A CARD TO BANISH IT" if _banish_mode else \
			("BANISH A CARD FOR THE WHOLE RUN" if _teach else "")
	_hint.add_theme_color_override("font_color", BANISH_COL if _banish_mode else UiKit.DIM)
	for k in _cards.size():
		var c: Control = _cards[k]
		var ok := _banish_mode and Sim.can_banish(sim.choices[k])
		c.modulate = Color(1.25, 0.55, 0.6) if ok else (Color(0.6, 0.6, 0.65) if _banish_mode else Color.WHITE)


## The sim already banished card `index` and dealt a new one: the old card
## burns away and the new one slides into its slot.
func replace_card(index: int) -> void:
	_banish_mode = false
	var old: Control = _cards[index]
	var pos := old.position
	var tw := old.create_tween().set_parallel()
	tw.tween_property(old, "modulate", Color(2.4, 0.5, 0.5, 0.0), 0.3)
	tw.tween_property(old, "scale", Vector2(0.86, 0.86), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(old, "rotation", 0.06, 0.3)
	tw.chain().tween_callback(old.queue_free)
	var card := _make_card(sim.choices[index], _card_size)
	card.position = pos + Vector2(size.x, 0.0)
	add_child(card)
	_cards[index] = card
	var t2 := card.create_tween()
	t2.tween_interval(0.22)
	t2.tween_callback(func(): Sfx.play("card", 1.2))
	t2.tween_property(card, "position", pos, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_callback(func(): _locked = false)
	_sync_banish()


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

class_name ChestPanel
extends Control
## The Prism Cache reveal: the world freezes, the cache shakes and charges up,
## bursts open in a fan of light, then each reward lands like a slot machine.
## An evolution gets its own showcase card. Tap to skip, tap again to go on.
## View only: the sim already applied the rewards when the cache was touched.

signal closed

const OPEN_TIME := 1.15
const SPIN_TIME := 0.55
const SPIN_GAP := 0.32

var _rewards: Array = []
var _big := false
var _t := 0.0
var _opened := false
var _done := false
var _closing := false
var _backdrop: ColorRect
var _ray_layer: Control
var _chest: TextureRect
var _flash: ColorRect
var _hint: Label
var _items: Array = []   # {icon: TextureRect, final: Texture2D, at: float, landed: bool, node: Control}
var _rays := 0.0
var _accent := UiKit.GOLD
var _center := Vector2.ZERO
var _spin_icons: Array = []


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
	_ray_layer = Control.new()
	_ray_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ray_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ray_layer.draw.connect(_draw_rays)
	add_child(_ray_layer)
	for id in Defs.WEAPON_ORDER + Defs.PASSIVE_ORDER:
		_spin_icons.append(Art.icon(id))


func open(rewards: Array, big: bool) -> void:
	for c in get_children():
		if c != _backdrop and c != _ray_layer:
			c.queue_free()
	_items.clear()
	_rewards = rewards
	_big = big
	_t = 0.0
	_opened = false
	_done = false
	_closing = false
	_rays = 0.0
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	var w := size.x
	var h := size.y
	var evolved := false
	for r in rewards:
		if int(r[1]) == Defs.EVO_LEVEL:
			evolved = true
	_accent = Color(1.0, 0.45, 0.95) if big else UiKit.GOLD
	if evolved:
		_accent = Defs.EVOLUTIONS[_first_evo()].color
	_center = Vector2(w * 0.5, h * (0.25 if evolved else 0.3))
	var title := UiKit.glow_label("BOSS CACHE" if big else "PRISM CACHE", 70, _accent)
	title.position = Vector2(0, h * 0.07)
	title.size = Vector2(w, 100)
	add_child(title)
	UiKit.pop_in(title, 0.0, 30)
	_chest = TextureRect.new()
	_chest.texture = Art.tex("chest_big")
	_chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chest.size = Vector2(300, 300)
	_chest.position = _center - _chest.size * 0.5
	_chest.pivot_offset = _chest.size * 0.5
	_chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest.modulate = Color(1.0, 0.45, 0.95) * 1.2 if big else Color(1.2, 1.2, 1.2)
	add_child(_chest)
	_chest.scale = Vector2(0.3, 0.3)
	create_tween().tween_property(_chest, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_rewards(evolved)
	add_child(_flash)
	_hint = UiKit.glow_label("TAP TO CONTINUE", 34, Color(0.9, 0.9, 1.0), UiKit.display_light())
	_hint.position = Vector2(0, h - 260)
	_hint.size = Vector2(w, 60)
	_hint.modulate.a = 0.0
	add_child(_hint)
	Sfx.play("chest")


func _first_evo() -> String:
	for r in _rewards:
		if int(r[1]) == Defs.EVO_LEVEL:
			return r[0]
	return ""


func _build_rewards(evolved: bool) -> void:
	var w := size.x
	var h := size.y
	var y := _center.y + 230.0
	var at := OPEN_TIME + 0.15
	if evolved:
		var id := _first_evo()
		_items.append(_evo_card(id, Vector2(60, y), Vector2(w - 120, 370), at))
		y += 400.0
		at += 1.0
	for r in _rewards:
		var id: String = r[0]
		var lvl: int = int(r[1])
		if lvl == Defs.EVO_LEVEL:
			continue
		var row_h := 130.0 if id != "flux" else 90.0
		_items.append(_row(id, lvl, Vector2(90, y), Vector2(w - 180, row_h), at))
		y += row_h + 22.0
		at += SPIN_GAP
	if y > h - 300.0:
		# Lots of rewards: pull everything up so the hint stays clear.
		var lift := y - (h - 300.0)
		for it in _items:
			it.node.position.y -= lift


func _evo_card(id: String, pos: Vector2, sz: Vector2, at: float) -> Dictionary:
	var evo: Dictionary = Defs.EVOLUTIONS[id]
	var col: Color = evo.color
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", UiKit.box(col, Color(0.05, 0.03, 0.1, 0.95), 30, 4, 34))
	card.position = pos
	card.size = sz
	card.pivot_offset = sz * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	add_child(card)
	var tag := UiKit.glow_label("EVOLUTION", 40, UiKit.GOLD)
	tag.position = Vector2(0, 26)
	tag.size = Vector2(sz.x, 50)
	card.add_child(tag)
	var ic := UiKit.icon_rect(id + "_evo", 200)
	ic.position = Vector2(40, 100)
	ic.size = Vector2(200, 200)
	ic.pivot_offset = Vector2(100, 100)
	card.add_child(ic)
	var tx := 280.0
	var name := UiKit.glow_label(String(evo.name).to_upper(), 50, col.lerp(Color.WHITE, 0.35))
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.position = Vector2(tx, 110)
	name.size = Vector2(sz.x - tx - 30, 64)
	card.add_child(name)
	var base_name := String(Defs.WEAPONS[id].name).to_upper()
	var need_name := String(Defs.PASSIVES[evo.needs].name).to_upper()
	var recipe := UiKit.label("%s  +  %s" % [base_name, need_name], 24, UiKit.DIM, UiKit.display_light(),
			HORIZONTAL_ALIGNMENT_LEFT)
	recipe.position = Vector2(tx, 176)
	recipe.size = Vector2(sz.x - tx - 30, 34)
	card.add_child(recipe)
	var desc := UiKit.label(Defs.WEAPONS[id].levels[Defs.EVO_LEVEL - 1].text, 36, Color(0.95, 0.93, 1.0), UiKit.body(),
			HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	desc.position = Vector2(tx, 222)
	desc.size = Vector2(sz.x - tx - 34, 220)
	card.add_child(desc)
	return {"icon": ic, "final": ic.texture, "at": at, "landed": false, "node": card, "evo": true}


func _row(id: String, lvl: int, pos: Vector2, sz: Vector2, at: float) -> Dictionary:
	var info := Defs.card_info(id)
	var col: Color = info.get("color", Color.WHITE)
	var row := Panel.new()
	row.add_theme_stylebox_override("panel", UiKit.box(col, Color(0.04, 0.03, 0.1, 0.92), 24, 3, 14))
	row.position = pos
	row.size = sz
	row.pivot_offset = sz * 0.5
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.modulate.a = 0.0
	add_child(row)
	var isz := sz.y - 24.0
	var ic := UiKit.icon_rect(id, isz)
	ic.position = Vector2(24, 12)
	ic.size = Vector2(isz, isz)
	ic.pivot_offset = Vector2(isz, isz) * 0.5
	row.add_child(ic)
	var text := String(info.get("name", id)).to_upper()
	var sub := ""
	match id:
		"flux":
			text = "+%d FLUX" % lvl
		"heal":
			text = "REPAIRED"
			sub = "+50% HP"
		_:
			sub = "LEVEL %d" % lvl if lvl < Defs.MAX_LEVEL else "MAX LEVEL"
	var tx := isz + 54.0
	var name := UiKit.label(text, 40 if id != "flux" else 36, col.lerp(Color.WHITE, 0.3), UiKit.display(),
			HORIZONTAL_ALIGNMENT_LEFT)
	name.position = Vector2(tx, 10 if sub != "" else 0)
	name.size = Vector2(sz.x - tx - 20, 64 if sub != "" else sz.y)
	row.add_child(name)
	if sub != "":
		var s := UiKit.label(sub, 28, UiKit.GOLD if lvl >= Defs.MAX_LEVEL else UiKit.DIM, UiKit.display_light(),
				HORIZONTAL_ALIGNMENT_LEFT)
		s.position = Vector2(tx, 68)
		s.size = Vector2(sz.x - tx - 20, 40)
		row.add_child(s)
	return {"icon": ic, "final": ic.texture, "at": at, "landed": false, "node": row, "evo": false,
		"spin": id != "flux" and id != "heal"}


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if not _opened:
		# Charge up: the cache shakes harder and glows hotter.
		var k := clampf(_t / OPEN_TIME, 0.0, 1.0)
		var sh := 3.0 + 18.0 * k * k
		_chest.position = _center - _chest.size * 0.5 + Vector2(randf_range(-sh, sh), randf_range(-sh, sh))
		_chest.rotation = randf_range(-0.06, 0.06) * k
		_rays = 0.25 * k
		if _t >= OPEN_TIME:
			_burst()
	else:
		_rays = lerpf(_rays, 1.0, clampf(delta * 4.0, 0.0, 1.0))
	var all_landed := true
	for it in _items:
		var node: Control = it.node
		if _t < it.at:
			all_landed = false
			continue
		if node.modulate.a == 0.0:
			node.modulate.a = 1.0
			node.scale = Vector2(0.6, 0.6)
			node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)\
					.set_ease(Tween.EASE_OUT)
			if it.evo:
				Sfx.play("evolve")
				Sfx.buzz(140)
				_flash.color = Color(Defs.EVOLUTIONS[_first_evo()].color, 0.85)
				_show_relic(_first_evo() + "_evo")
		if it.landed:
			continue
		var spin_end: float = it.at + (SPIN_TIME if it.get("spin", false) else 0.0)
		var ic: TextureRect = it.icon
		if _t < spin_end:
			all_landed = false
			ic.texture = _spin_icons[int(_t * 18.0 + float(it.at) * 7.0) % _spin_icons.size()]
			ic.modulate = Color(1, 1, 1, 0.7)
		else:
			_land(it)
	if all_landed and _opened and not _done:
		_done = true
		_hint.modulate.a = 1.0
		var tw := _hint.create_tween().set_loops()
		tw.tween_property(_hint, "modulate:a", 0.35, 0.6)
		tw.tween_property(_hint, "modulate:a", 1.0, 0.6)
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 2.2)
	_ray_layer.queue_redraw()


## The evolved weapon rises where the cache was.
func _show_relic(icon_id: String) -> void:
	var r := UiKit.icon_rect(icon_id, 280)
	r.size = Vector2(280, 280)
	r.position = _center - r.size * 0.5
	r.pivot_offset = r.size * 0.5
	r.scale = Vector2(0.2, 0.2)
	r.modulate = Color(1.6, 1.6, 1.6)
	add_child(r)
	move_child(r, _ray_layer.get_index() + 1)
	var tw := r.create_tween()
	tw.tween_property(r, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "scale", Vector2.ONE, 0.3)
	var spin := r.create_tween().set_loops()
	spin.tween_property(r, "modulate", Color(2.2, 2.2, 2.2), 0.7)
	spin.tween_property(r, "modulate", Color(1.4, 1.4, 1.4), 0.7)


func _land(it: Dictionary) -> void:
	it.landed = true
	var ic: TextureRect = it.icon
	ic.texture = it.final
	ic.modulate = Color(1.3, 1.3, 1.3)
	ic.scale = Vector2(1.35, 1.35)
	ic.create_tween().tween_property(ic, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not it.evo:
		Sfx.play("select", 1.0 + 0.08 * _items.find(it))
		Sfx.buzz(20)


func _burst() -> void:
	_opened = true
	_flash.color = Color(_accent.lerp(Color.WHITE, 0.5), 0.9)
	_chest.rotation = 0.0
	_chest.position = _center - _chest.size * 0.5
	var tw := _chest.create_tween().set_parallel()
	tw.tween_property(_chest, "scale", Vector2(1.7, 1.7), 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_chest, "modulate:a", 0.0, 0.4)
	Sfx.play("kill_big", 1.2)
	Sfx.buzz(80)


func _skip() -> void:
	if not _opened:
		_t = OPEN_TIME
		_burst()
	var last := 0.0
	for it in _items:
		last = maxf(last, float(it.at))
	_t = maxf(_t, last + SPIN_TIME + 0.01)


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not pressed or _closing:
		return
	accept_event()
	if not _done:
		_skip()
		return
	_closing = true
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		visible = false
		closed.emit())


func _draw_rays() -> void:
	if _rays <= 0.0:
		return
	# A slowly turning fan of light behind the cache.
	var n := 18
	var rot := _t * 0.35
	var reach := size.length()
	for k in n:
		var a0 := rot + TAU * k / n
		var a1 := a0 + TAU / n * 0.35
		var pts := PackedVector2Array([_center, _center + Vector2(cos(a0), sin(a0)) * reach,
				_center + Vector2(cos(a1), sin(a1)) * reach])
		var cols := PackedColorArray([Color(_accent, 0.2 * _rays), Color(_accent, 0.0), Color(_accent, 0.0)])
		_ray_layer.draw_polygon(pts, cols)
	_ray_layer.draw_circle(_center, 150.0 * _rays, Color(_accent.lerp(Color.WHITE, 0.6), 0.18 * _rays))

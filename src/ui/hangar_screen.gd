class_name HangarScreen
extends Control
## The Hangar: browse the fleet, read each ship's quirk and Overdrive, see
## what unlocks the locked ones, and launch.

var main

var _index := 0
var _preview: ShipPreview
var _name: Label
var _title: Label
var _info: VBoxContainer
var _launch: Button
var _dots: HBoxContainer
var _swipe_from := -1.0
var _rad_name: Label
var _rad_text: Label
var _rad_icon: TextureRect


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
	col.add_child(UiKit.glow_label("HANGAR", 80, UiKit.CYAN))

	var stage := HBoxContainer.new()
	stage.custom_minimum_size = Vector2(0, 520)
	stage.add_theme_constant_override("separation", 0)
	col.add_child(stage)
	var prev := _arrow("‹")
	prev.pressed.connect(func(): _show(_index - 1, -1))
	stage.add_child(prev)
	_preview = ShipPreview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.gui_input.connect(_on_preview_input)
	stage.add_child(_preview)
	var nxt := _arrow("›")
	nxt.pressed.connect(func(): _show(_index + 1, 1))
	stage.add_child(nxt)

	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 14)
	col.add_child(_dots)
	_name = UiKit.glow_label("", 84, Color.WHITE)
	col.add_child(_name)
	_title = UiKit.label("", 34, UiKit.DIM, UiKit.display_light())
	col.add_child(_title)
	col.add_child(_radiance_row())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_info = VBoxContainer.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_constant_override("separation", 18)
	scroll.add_child(_info)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	var b := UiKit.button("BACK", UiKit.MAGENTA, 40)
	b.custom_minimum_size = Vector2(260, 130)
	b.pressed.connect(func(): main.go_title())
	row.add_child(b)
	_launch = UiKit.button("LAUNCH", UiKit.CYAN, 50, true)
	_launch.custom_minimum_size = Vector2(0, 130)
	_launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_launch.pressed.connect(_on_launch)
	row.add_child(_launch)

	for k in Defs.SHIPS.size():
		if Defs.SHIPS[k].id == Save.current_ship():
			_index = k
	_show(_index, 0)
	Save.mark_ships_seen()


func _arrow(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(110, 0)
	b.add_theme_font_override("font", UiKit.display())
	b.add_theme_font_size_override("font_size", 110)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0.9))
	b.add_theme_color_override("font_pressed_color", UiKit.CYAN)
	return b


func _on_preview_input(event: InputEvent) -> void:
	var down: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed
	var up: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) and not event.pressed
	if down:
		_swipe_from = event.position.x
	elif up and _swipe_from >= 0.0:
		var dx: float = event.position.x - _swipe_from
		_swipe_from = -1.0
		if absf(dx) > 90.0:
			_show(_index + (1 if dx < 0.0 else -1), 1 if dx < 0.0 else -1)


func _show(i: int, dir: int) -> void:
	var n := Defs.SHIPS.size()
	_index = posmod(i, n)
	var sd: Dictionary = Defs.SHIPS[_index]
	var unlocked := Save.ship_unlocked(sd.id)
	var col: Color = sd.color
	_preview.show_ship(sd.id, unlocked, dir)
	if dir != 0:
		Sfx.play("card", 1.0 + 0.04 * _index)
	_name.text = String(sd.name).to_upper() if unlocked else "LOCKED"
	_name.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.2) if unlocked else Color(0.7, 0.7, 0.8))
	_name.add_theme_color_override("font_shadow_color", Color(col, 0.55 if unlocked else 0.15))
	_title.text = String(sd.title).to_upper() if unlocked else "???"
	for c in _dots.get_children():
		c.queue_free()
	for k in n:
		var dot := TextureRect.new()
		dot.texture = Art.icon("ship_" + Defs.SHIPS[k].id)
		dot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dot.custom_minimum_size = Vector2(64, 64)
		var on := Save.ship_unlocked(Defs.SHIPS[k].id)
		dot.modulate = Color(1.4, 1.4, 1.4) if k == _index else (Color(1, 1, 1, 0.55) if on else Color(0.3, 0.3, 0.4, 0.5))
		dot.mouse_filter = Control.MOUSE_FILTER_STOP
		var kk := k
		dot.gui_input.connect(func(ev: InputEvent):
			if (ev is InputEventScreenTouch or ev is InputEventMouseButton) and ev.pressed:
				_show(kk, signi(kk - _index)))
		_dots.add_child(dot)
	for c in _info.get_children():
		c.queue_free()
	if unlocked:
		var rec: Dictionary = (Save.data.ship_best as Dictionary).get(sd.id, {})
		if not rec.is_empty():
			var line := "BEST  %s   ·   SCORE  %s" % [UiKit.fmt_time(float(rec.time)), UiKit.fmt_int(int(rec.score))]
			var mastery := Save.ship_radiance(sd.id)
			if mastery > 0:
				line += "   ·   MASTERY R%d" % mastery
			elif bool(rec.get("dawn", false)):
				line += "   ·   DAWN ✓"
			_info.add_child(UiKit.label(line, 28, UiKit.GOLD if bool(rec.get("dawn", false)) else UiKit.DIM,
					UiKit.display_light()))
		var w: String = sd.weapon
		_info.add_child(_section("STARTS WITH", w, String(Defs.WEAPONS[w].name),
				String(Defs.WEAPONS[w].blurb), Defs.WEAPONS[w].color))
		_info.add_child(_section("QUIRK", "ship_" + String(sd.id), String(sd.name), String(sd.quirk), col))
		_info.add_child(_section("OVERDRIVE", "od_" + String(sd.id), String(sd.od), String(sd.od_text), col))
		var selected: bool = Save.current_ship() == sd.id
		_launch.disabled = false
		_launch.text = "LAUNCH" if selected else "FLY " + String(sd.name).to_upper()
	else:
		var m := Defs.ship_mission(sd.id)
		var p := Missions.progress(m, null, Save.data)
		_info.add_child(_locked(m, p))
		_info.add_child(_section("OVERDRIVE", "od_" + String(sd.id), String(sd.od), String(sd.od_text), col))
		_launch.disabled = true
		_launch.text = "LOCKED"
	UiKit.pop_in(_info, 0.0, 16)


## Radiance: pick how bright the night burns. Locked until the first dawn.
func _radiance_row() -> Control:
	var p := PanelContainer.new()
	var sb := UiKit.box(Color(Defs.RADIANCE_COLOR, 0.5), Color(0.06, 0.03, 0.06, 0.85), 24, 2, 8)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	if Save.radiance_max() <= 0:
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := UiKit.icon_rect("radiance", 64)
		ic.modulate = Color(0.5, 0.5, 0.6)
		h.add_child(ic)
		h.add_child(UiKit.label("RADIANCE  ·  REACH THE DAWN TO UNLOCK", 28, UiKit.DIM, UiKit.display_light()))
		return p
	var minus := _arrow("‹")
	minus.custom_minimum_size = Vector2(90, 0)
	minus.add_theme_font_size_override("font_size", 80)
	minus.pressed.connect(func(): _step_radiance(-1))
	h.add_child(minus)
	_rad_icon = UiKit.icon_rect("radiance", 84)
	_rad_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_rad_icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	_rad_name = UiKit.glow_label("", 38, UiKit.GOLD, UiKit.display())
	v.add_child(_rad_name)
	_rad_text = UiKit.label("", 28, Color(0.9, 0.9, 1.0, 0.85), UiKit.body())
	_rad_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rad_text.custom_minimum_size = Vector2(560, 0)
	v.add_child(_rad_text)
	h.add_child(v)
	var plus := _arrow("›")
	plus.custom_minimum_size = Vector2(90, 0)
	plus.add_theme_font_size_override("font_size", 80)
	plus.pressed.connect(func(): _step_radiance(1))
	h.add_child(plus)
	_sync_radiance()
	return p


func _step_radiance(d: int) -> void:
	var r := Save.current_radiance()
	var nr := clampi(r + d, 0, Save.radiance_max())
	if nr == r:
		Sfx.play("click", 0.7)
		return
	Save.set_radiance(nr)
	Sfx.play("select", 1.0 + 0.05 * nr)
	Sfx.buzz(20)
	_sync_radiance()
	_rad_name.pivot_offset = _rad_name.size * 0.5
	_rad_name.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(_rad_name, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func _sync_radiance() -> void:
	if _rad_name == null:
		return
	var r := Save.current_radiance()
	var col := Defs.radiance_color(r)
	_rad_icon.modulate = Color(1, 1, 1) * (1.0 + 0.06 * r) if r > 0 else Color(0.55, 0.55, 0.65)
	if r == 0:
		_rad_name.text = "RADIANCE OFF"
		_rad_text.text = "The night as it was. Raise it for new rules and a bigger score (up to R%d)." % \
				Save.radiance_max()
	else:
		_rad_name.text = "RADIANCE %d  ·  %s" % [r, String(Defs.RADIANCE[r - 1].name).to_upper()]
		_rad_text.text = "%s  Score x%.2f, Flux x%.2f.%s" % [String(Defs.RADIANCE[r - 1].text),
				Defs.radiance_score(r), Defs.radiance_flux(r), "" if r == 1 else " Keeps every rule below."]
	_rad_name.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.2))
	_rad_name.add_theme_color_override("font_shadow_color", Color(col, 0.55))


func _section(head: String, icon: String, name: String, text: String, col: Color) -> Control:
	var p := PanelContainer.new()
	var sb := UiKit.box(Color(col, 0.55), Color(0.04, 0.03, 0.1, 0.9), 24, 2, 8)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	p.add_child(h)
	h.add_child(UiKit.icon_rect(icon, 104))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.add_child(UiKit.label(head + "  ·  " + name.to_upper(), 26, col.lerp(Color.WHITE, 0.25), UiKit.display(),
			HORIZONTAL_ALIGNMENT_LEFT))
	var l := UiKit.label(text, 32, Color(0.9, 0.9, 1.0, 0.9), UiKit.body(), HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(640, 0)
	v.add_child(l)
	h.add_child(v)
	return p


func _locked(m: Dictionary, prog: int) -> Control:
	var p := PanelContainer.new()
	var sb := UiKit.box(UiKit.GOLD, Color(0.1, 0.07, 0.02, 0.7), 24, 2, 10)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UiKit.label("MISSION  ·  " + String(m.name).to_upper(), 28, UiKit.GOLD, UiKit.display(),
			HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(UiKit.label(String(m.text), 36, Color.WHITE, UiKit.body(), HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(MissionsScreen.progress_bar(m, prog, UiKit.GOLD))
	return p


func _on_launch() -> void:
	var sd: Dictionary = Defs.SHIPS[_index]
	if not Save.ship_unlocked(sd.id):
		return
	if Save.current_ship() != sd.id:
		Save.select_ship(sd.id)
		Sfx.play("select")
		Sfx.buzz(30)
		_show(_index, 0)
		return
	main.start_run()


func on_back() -> void:
	main.go_title()


## The big rotating ship on its pedestal of light.
class ShipPreview extends Control:
	var id := "lumen"
	var unlocked := true
	var _t := 0.0
	var _slide := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func show_ship(ship_id: String, is_unlocked: bool, dir: int) -> void:
		id = ship_id
		unlocked = is_unlocked
		_slide = float(dir)

	func _process(delta: float) -> void:
		_t += delta
		_slide = move_toward(_slide, 0.0, delta * 5.0)
		queue_redraw()

	func _draw() -> void:
		var col: Color = Defs.ship(id).color
		var c := size * 0.5 + Vector2(_slide * 160.0, sin(_t * 1.6) * 10.0)
		var a := 1.0 - absf(_slide)
		var glow := Art.tex("glow")
		var ring := Art.tex("ring")
		var lc := col if unlocked else Color(0.4, 0.4, 0.55)
		draw_texture_rect(glow, Rect2(c - Vector2(330, 330), Vector2(660, 660)), false, Color(lc, 0.28 * a))
		# Pedestal rings, tilted into ellipses.
		for k in 3:
			var rr := 190.0 + 40.0 * k
			draw_set_transform(c + Vector2(0, 150), 0.0, Vector2(1.0, 0.28))
			draw_arc(Vector2.ZERO, rr + 10.0 * sin(_t * 2.0 + k), 0.0, TAU, 72, Color(lc, (0.5 - 0.13 * k) * a),
					5.0 - k, true)
		draw_set_transform(c, _t * 0.4, Vector2(2.2, 2.2))
		draw_texture(ring, Vector2(-128, -128), Color(lc, 0.25 * a))
		var tilt := 1.0 - 0.12 * absf(sin(_t * 0.9))
		draw_set_transform(c, -PI * 0.5 + sin(_t * 0.9) * 0.12, Vector2(1.25, 1.25 * tilt))
		var mod := Color(1.5, 1.5, 1.5, a) if unlocked else Color(0.32, 0.3, 0.42, a)
		draw_texture(Art.tex("ship_big_" + id), Vector2(-160, -160), mod)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not unlocked:
			draw_string(UiKit.display(), c + Vector2(-60, 30), "?", HORIZONTAL_ALIGNMENT_CENTER, 120, 110,
					Color(1, 1, 1, 0.35 * a))

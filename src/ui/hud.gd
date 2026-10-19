class_name Hud
extends Control
## In-run overlay: XP bar, level, timer, kills, loadout, boss bar, banners.

signal pause_pressed

const BOSS_NAMES := {Defs.WARDEN: "THE WARDEN", Defs.ECLIPSE: "ECLIPSE"}

var arena: Arena
var top := 0.0

var _level: Label
var _timer: Label
var _kills: Label
var _boss_name: Label
var _banner: Label
var _loadout: HBoxContainer
var _pause: Button
var _xp_shown := 0.0
var _xp_flash := 0.0
var _boss_shown := 1.0
var _boss_alpha := 0.0
var _boss_type := -1
var _icons := {}
var _target_level := 1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level = UiKit.glow_label("LV 1", 34, UiKit.CYAN)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_level)
	_timer = UiKit.glow_label("00:00", 56, Color.WHITE)
	add_child(_timer)
	_kills = UiKit.label("0", 36, Color(1, 1, 1, 0.9), UiKit.display(), HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_kills)
	_boss_name = UiKit.glow_label("", 30, UiKit.RED, UiKit.display_light())
	_boss_name.modulate.a = 0.0
	add_child(_boss_name)
	_banner = UiKit.glow_label("", 76, UiKit.MAGENTA)
	_banner.modulate.a = 0.0
	add_child(_banner)
	_loadout = HBoxContainer.new()
	_loadout.add_theme_constant_override("separation", 6)
	_loadout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loadout)
	_pause = Button.new()
	_pause.text = "II"
	_pause.focus_mode = Control.FOCUS_NONE
	_pause.add_theme_font_override("font", UiKit.display())
	_pause.add_theme_font_size_override("font_size", 34)
	var sb := UiKit.box(UiKit.CYAN, Color(0.03, 0.02, 0.08, 0.6), 40, 2, 8)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		_pause.add_theme_stylebox_override(st, sb)
	_pause.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_pause.add_theme_color_override("font_color", UiKit.CYAN)
	_pause.custom_minimum_size = Vector2(84, 84)
	_pause.pressed.connect(func(): pause_pressed.emit())
	add_child(_pause)
	resized.connect(_layout)
	_layout()


func bind(a: Arena) -> void:
	arena = a
	a.banner.connect(show_banner)
	a.boss_started.connect(func(type):
		_boss_type = type
		_boss_name.text = BOSS_NAMES.get(type, "BOSS"))
	a.card_taken.connect(func(_id, _lvl): _rebuild_loadout())
	a.leveled_up.connect(func(): _xp_flash = 1.0)
	_rebuild_loadout()


func _layout() -> void:
	var w := size.x
	_level.position = Vector2(28, top + 44)
	_level.size = Vector2(240, 50)
	_timer.position = Vector2(0, top + 40)
	_timer.size = Vector2(w, 70)
	_kills.position = Vector2(w - 420, top + 44)
	_kills.size = Vector2(250, 50)
	_pause.position = Vector2(w - 110, top + 40)
	_boss_name.position = Vector2(0, top + 122)
	_boss_name.size = Vector2(w, 40)
	_banner.position = Vector2(0, size.y * 0.3)
	_banner.size = Vector2(w, 110)
	_banner.pivot_offset = _banner.size * 0.5
	_loadout.position = Vector2(24, top + 104)


func _rebuild_loadout() -> void:
	if arena == null or arena.sim == null:
		return
	for c in _loadout.get_children():
		c.queue_free()
	_icons.clear()
	var ids: Array = []
	for w in arena.sim.weapons:
		ids.append(w.id)
	ids.append_array(arena.sim.passive_order)
	for id in ids:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(54, 64)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := UiKit.icon_rect(id, 54)
		slot.add_child(ic)
		var lv := arena.sim.card_level(id)
		var pips := UiKit.label("•".repeat(lv), 18, Art.card_color(id), UiKit.bold())
		pips.position = Vector2(0, 46)
		pips.size = Vector2(54, 18)
		slot.add_child(pips)
		_loadout.add_child(slot)
		_icons[id] = slot
	if _boss_type == -1 and _loadout.get_child_count() > 0:
		_loadout.modulate.a = 0.9


func show_banner(text: String, color: Color) -> void:
	if text == "":
		return
	_banner.text = text
	_banner.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.25))
	_banner.add_theme_color_override("font_shadow_color", Color(color, 0.6))
	var big := text.length() <= 10
	_banner.add_theme_font_size_override("font_size", 84 if big else 56)
	_banner.scale = Vector2(1.6, 1.6)
	_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_banner, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.0)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.5)


func _process(delta: float) -> void:
	if arena == null or arena.sim == null:
		return
	var s := arena.sim
	_level.text = "LV %d" % s.level
	_timer.text = UiKit.fmt_time(s.seconds())
	_kills.text = UiKit.fmt_int(s.kills)
	var frac := clampf(s.xp / s.xp_need, 0.0, 1.0)
	if frac < _xp_shown - 0.3:
		_xp_shown = 0.0
	_xp_shown = lerpf(_xp_shown, frac, clampf(delta * 10.0, 0.0, 1.0))
	_xp_flash = maxf(0.0, _xp_flash - delta * 2.0)
	var b := s.boss_index()
	if b >= 0 and s.e_spawn[b] <= 0:
		_boss_alpha = move_toward(_boss_alpha, 1.0, delta * 3.0)
		_boss_shown = lerpf(_boss_shown, s.e_hp[b] / s.e_maxhp[b], clampf(delta * 8.0, 0.0, 1.0))
	else:
		_boss_alpha = move_toward(_boss_alpha, 0.0, delta * 2.0)
		if _boss_alpha <= 0.0:
			_boss_shown = 1.0
	_boss_name.modulate.a = _boss_alpha
	_loadout.position.y = top + (104.0 + 80.0 * _boss_alpha)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	# XP bar.
	var y := top + 14.0
	var h := 20.0
	var rect := Rect2(20, y, w - 40, h)
	draw_rect(rect.grow(3), Color(0.02, 0.01, 0.06, 0.85))
	draw_rect(rect, Color(0.12, 0.1, 0.25, 0.9))
	var fw := rect.size.x * _xp_shown
	if fw > 1.0:
		var steps := 24
		for k in steps:
			var t0 := float(k) / steps
			var x0 := rect.position.x + fw * t0
			var c := UiKit.CYAN.lerp(UiKit.MAGENTA, t0 * _xp_shown)
			draw_rect(Rect2(x0, y, fw / steps + 1.0, h), c * Color(1.2, 1.2, 1.2))
		var shine := fmod(arena.vtime * 0.6, 1.4) - 0.2
		draw_rect(Rect2(rect.position.x + fw * clampf(shine, 0.0, 1.0), y, 14, h), Color(1, 1, 1, 0.35))
		draw_rect(Rect2(rect.position.x + fw - 3, y - 4, 6, h + 8), Color(1, 1, 1, 0.9))
	if _xp_flash > 0.0:
		draw_rect(rect.grow(6.0 * _xp_flash), Color(1.0, 0.85, 0.4, _xp_flash * 0.6), false, 4.0)
	# Kill icon.
	var kx := w - 150.0
	var ky := top + 69.0
	var pts := PackedVector2Array([Vector2(kx, ky - 13), Vector2(kx + 9, ky), Vector2(kx, ky + 13), Vector2(kx - 9, ky)])
	draw_colored_polygon(pts, Color(1.0, 0.35, 0.7))
	# Boss bar.
	if _boss_alpha > 0.0:
		var by := top + 160.0
		var bw := w * 0.8
		var br := Rect2((w - bw) * 0.5, by, bw, 18)
		draw_rect(br.grow(3), Color(0.03, 0.0, 0.03, 0.9 * _boss_alpha))
		draw_rect(br, Color(0.25, 0.05, 0.1, 0.9 * _boss_alpha))
		var col: Color = Defs.ENEMY_COLOR[maxi(_boss_type, Defs.WARDEN)]
		draw_rect(Rect2(br.position, Vector2(bw * _boss_shown, 18)), Color(col * 1.3, _boss_alpha))
		for k in range(1, 10):
			var x := br.position.x + bw * k / 10.0
			draw_line(Vector2(x, by), Vector2(x, by + 18), Color(0, 0, 0, 0.5 * _boss_alpha), 2.0)

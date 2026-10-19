class_name Hud
extends Control
## In-run overlay: XP bar, level, timer, kills, loadout, boss bar, banners.

signal pause_pressed

const BOSS_NAMES := {Defs.WARDEN: "THE WARDEN", Defs.ECLIPSE: "ECLIPSE", Defs.SERAPH: "THE SERAPH"}
## The Chain counter shows from this many kills in a row.
const CHAIN_SHOW := 5

var arena: Arena
var top := 0.0

var _level: Label
var _timer: Label
var _kills: Label
var _score: Label
var _score_shown := 0.0
var _boss_name: Label
var _banner: Label
var _loadout: HBoxContainer
var _relics: HBoxContainer
var _pause: Button
var _xp_shown := 0.0
var _xp_flash := 0.0
var _boss_shown := 1.0
var _boss_alpha := 0.0
var _boss_type := -1
var _icons := {}
var _target_level := 1
var _chain: Label
var _chain_mult: Label
var _chain_alpha := 0.0
var _chain_pop := 0.0
var _chain_shown := 0
var _broken: Label


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
	_score = UiKit.label("0", 28, Color(1, 1, 1, 0.7), UiKit.display_light(), HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_score)
	_boss_name = UiKit.glow_label("", 30, UiKit.RED, UiKit.display_light())
	_boss_name.modulate.a = 0.0
	add_child(_boss_name)
	_chain = UiKit.glow_label("", 44, UiKit.GOLD, UiKit.display())
	_chain.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chain.modulate.a = 0.0
	add_child(_chain)
	_chain_mult = UiKit.label("", 26, Color(1.0, 0.9, 0.6, 0.85), UiKit.display_light(), HORIZONTAL_ALIGNMENT_RIGHT)
	_chain_mult.modulate.a = 0.0
	add_child(_chain_mult)
	_broken = UiKit.glow_label("CHAIN BROKEN", 30, UiKit.RED, UiKit.display_light())
	_broken.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_broken.modulate.a = 0.0
	add_child(_broken)
	_banner = UiKit.glow_label("", 76, UiKit.MAGENTA)
	_banner.modulate.a = 0.0
	add_child(_banner)
	_loadout = HBoxContainer.new()
	_loadout.add_theme_constant_override("separation", 6)
	_loadout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loadout)
	_relics = HBoxContainer.new()
	_relics.add_theme_constant_override("separation", 4)
	_relics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_relics)
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
		_boss_name.text = BOSS_NAMES.get(type, "BOSS")
		if arena.sim.endless:
			_boss_name.text += "  ·  NIGHT %d" % arena.sim.night)
	a.card_taken.connect(func(_id, _lvl): _rebuild_loadout())
	a.leveled_up.connect(func(): _xp_flash = 1.0)
	a.chain_milestone.connect(func(count: int, title: String):
		_chain_pop = 1.0
		show_banner(title, UiKit.GOLD, "CHAIN %s" % UiKit.fmt_int(count)))
	a.chain_lost.connect(func(count: int):
		if count < 25:
			return
		_broken.text = "CHAIN BROKEN  ·  %s" % UiKit.fmt_int(count)
		_broken.modulate.a = 1.0
		_broken.scale = Vector2(1.25, 1.25)
		var tw := _broken.create_tween()
		tw.tween_property(_broken, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.9)
		tw.tween_property(_broken, "modulate:a", 0.0, 0.6))
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
	_score.position = Vector2(w - 540, top + 100)
	_score.size = Vector2(400, 36)
	_boss_name.position = Vector2(0, top + 122)
	_boss_name.size = Vector2(w, 40)
	_banner.position = Vector2(0, size.y * 0.3)
	_banner.size = Vector2(w, 110)
	_banner.pivot_offset = _banner.size * 0.5
	_loadout.position = Vector2(24, top + 104)
	_chain.size = Vector2(420, 56)
	_chain.pivot_offset = Vector2(400, 28)
	_chain_mult.size = Vector2(420, 32)
	_broken.size = Vector2(600, 40)
	_broken.pivot_offset = Vector2(580, 20)
	_place_chain()


## The Chain sits on the right edge, below the score (lower while a boss is up).
func _place_chain() -> void:
	var w := size.x
	var y := top + 236.0 + 80.0 * _boss_alpha
	_chain.position = Vector2(w - 444, y)
	_chain_mult.position = Vector2(w - 444, y + 52)
	_broken.position = Vector2(w - 624, y + 6)


func _rebuild_loadout() -> void:
	if arena == null or arena.sim == null:
		return
	for c in _loadout.get_children():
		c.queue_free()
	for c in _relics.get_children():
		c.queue_free()
	for id in arena.sim.relics:
		var ic := UiKit.icon_rect(id, 44)
		ic.custom_minimum_size = Vector2(44, 44)
		_relics.add_child(ic)
	_icons.clear()
	var ids: Array = []
	for w in arena.sim.weapons:
		ids.append(w.id)
	ids.append_array(arena.sim.passive_order)
	for id in ids:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(54, 64)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var did := arena.sim.display_id(id)
		var ic := UiKit.icon_rect(did, 54)
		slot.add_child(ic)
		var lv := arena.sim.card_level(id)
		var evo := lv >= Defs.EVO_LEVEL
		var pips := UiKit.label("EVO" if evo else "•".repeat(lv), 16 if evo else 18, Art.card_color(did),
				UiKit.display() if evo else UiKit.bold())
		pips.position = Vector2(0, 46)
		pips.size = Vector2(54, 18)
		slot.add_child(pips)
		_loadout.add_child(slot)
		_icons[id] = slot
		if arena.sim.evolution_ready(id):
			# Ready to evolve: the slot pulses gold until the next cache.
			var tw := ic.create_tween().set_loops()
			tw.tween_property(ic, "modulate", Color(2.0, 1.6, 0.6), 0.45)
			tw.tween_property(ic, "modulate", Color.WHITE, 0.45)
	if _boss_type == -1 and _loadout.get_child_count() > 0:
		_loadout.modulate.a = 0.9


func show_banner(text: String, color: Color, sub := "") -> void:
	if text == "":
		return
	_banner.text = text if sub == "" else text + "\n" + sub
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
	var sc := float(s.score())
	_score_shown = sc if sc < _score_shown else lerpf(_score_shown, sc, clampf(delta * 6.0, 0.0, 1.0))
	_score.text = "SCORE " + UiKit.fmt_int(int(ceil(_score_shown)))
	if s.endless:
		_timer.add_theme_color_override("font_color", Color(1.0, 0.55, 0.85))
		_timer.add_theme_color_override("font_shadow_color", Color(1.0, 0.2, 0.6, 0.6))
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
	_relics.position = Vector2(24, _loadout.position.y + 70.0)
	_update_chain(s, delta)
	queue_redraw()


func _update_chain(s: Sim, delta: float) -> void:
	var on := s.chain >= CHAIN_SHOW
	_chain_alpha = move_toward(_chain_alpha, 1.0 if on else 0.0, delta * (6.0 if on else 3.0))
	_chain_pop = maxf(0.0, _chain_pop - delta * 2.5)
	if on:
		if s.chain != _chain_shown:
			_chain.scale = Vector2.ONE * (1.12 + 0.25 * _chain_pop)
		_chain_shown = s.chain
		_chain.text = "%s CHAIN" % UiKit.fmt_int(s.chain)
		var m := Defs.chain_mult(s.chain)
		_chain_mult.text = "SCORE x%.1f" % m if m > 1.0 else "KEEP IT GOING"
		# The counter warms from gold to white-hot as the multiplier climbs.
		var heat := clampf((m - 1.0) / (Defs.CHAIN_MAX_MULT - 1.0), 0.0, 1.0)
		_chain.add_theme_color_override("font_color", UiKit.GOLD.lerp(Color(1.0, 0.95, 0.9), heat))
	_chain.scale = _chain.scale.lerp(Vector2.ONE, clampf(delta * 10.0, 0.0, 1.0))
	_chain.modulate.a = _chain_alpha
	_chain_mult.modulate.a = _chain_alpha * 0.9
	_place_chain()


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
	_draw_cache_arrows()
	# Chain timer: a gold fuse that burns down between kills.
	if _chain_alpha > 0.0 and arena.sim.chain > 0:
		var fuse := clampf(float(arena.sim.chain_t) / float(Defs.CHAIN_TICKS), 0.0, 1.0)
		var cy := _chain.position.y + 90.0
		var cw := 220.0
		var cx := w - 24.0 - cw
		draw_rect(Rect2(cx, cy, cw, 6), Color(0.1, 0.06, 0.02, 0.7 * _chain_alpha))
		var fc := UiKit.GOLD if fuse > 0.3 else UiKit.RED
		draw_rect(Rect2(cx + cw * (1.0 - fuse), cy, cw * fuse, 6), Color(fc * 1.3, _chain_alpha))
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


## Off-screen Prism Caches get a pulsing arrow on the screen edge.
func _draw_cache_arrows() -> void:
	if arena == null or arena.sim == null or arena.sim.pickups.is_empty():
		return
	var vs := size
	var center := arena.camera.get_screen_center_position()
	var half := vs * 0.5
	var t := arena.vtime
	for p in arena.sim.pickups:
		if p.k != "chest" and p.k != "bigchest":
			continue
		var rel := Vector2(p.x, p.y) - center
		if absf(rel.x) < half.x - 40.0 and absf(rel.y) < half.y - 40.0:
			continue
		var col := Color(1.0, 0.45, 0.95) if p.k == "bigchest" else UiKit.GOLD
		var dir := rel.normalized()
		var margin := Vector2(70.0, 70.0)
		var lim := half - margin
		var k := minf(lim.x / maxf(absf(dir.x), 0.001), lim.y / maxf(absf(dir.y), 0.001))
		var pos := half + dir * k
		pos.y = clampf(pos.y, top + 220.0, vs.y - 70.0)
		var pulse := 1.0 + 0.15 * sin(t * 8.0)
		var tip := pos + dir * 34.0 * pulse
		var side := dir.orthogonal() * 22.0 * pulse
		draw_colored_polygon(PackedVector2Array([tip, pos - dir * 6.0 + side, pos - dir * 6.0 - side]), col)
		draw_texture_rect(Art.tex("p_" + String(p.k)), Rect2(pos - dir * 52.0 - Vector2(32, 32), Vector2(64, 64)),
				false, Color(1.2, 1.2, 1.2, 0.95))

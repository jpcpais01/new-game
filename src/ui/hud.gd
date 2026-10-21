class_name Hud
extends Control
## In-run overlay: XP bar, level, timer, kills, loadout, boss bar, banners.

signal pause_pressed

const BOSS_NAMES := {Defs.WARDEN: "THE WARDEN", Defs.ECLIPSE: "ECLIPSE", Defs.SERAPH: "THE SERAPH",
		Defs.LEVIATHAN: "THE LEVIATHAN"}
const BOSS_EPITHETS := {Defs.WARDEN: "KEEPER OF THE FIRST GATE", Defs.ECLIPSE: "THE LAST DARK BEFORE DAWN",
		Defs.SERAPH: "WHEEL OF BURNING LIGHT", Defs.LEVIATHAN: "SERPENT OF THE DEEP DARK"}
## Seconds a boss's title card stays up.
const INTRO_TIME := 2.8
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
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
var _rift_title: Label
var _rift_sub: Label
var _rift_alpha := 0.0
var _rift_kind := 0
var _rift_y := 0.0
var _rift_box := UiKit.box(Color.WHITE, Color.BLACK, 22, 2, 0)
var _intro_tag: Label
var _intro_title: Label
var _intro_sub: Label
var _intro := 0.0
var _intro_col := Color.WHITE
# The Gauntlet: best splits as they stood when the run began, and the split popup.
var _g_best: Array = []
var _g_prev_clear := 0
var _split_head: Label
var _split_time: Label
var _split_sub: Label
var _res_queue: Array = []
var _res_box: Control
var _elite_card: EliteCard


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
	_rift_title = UiKit.label("", 26, Color.WHITE, UiKit.display(), HORIZONTAL_ALIGNMENT_LEFT)
	_rift_title.size = Vector2(420, 34)
	add_child(_rift_title)
	_rift_sub = UiKit.label("", 24, Color(1, 1, 1, 0.8), UiKit.display_light(), HORIZONTAL_ALIGNMENT_LEFT)
	_rift_sub.size = Vector2(420, 30)
	add_child(_rift_sub)
	_banner = UiKit.glow_label("", 76, UiKit.MAGENTA)
	_banner.modulate.a = 0.0
	add_child(_banner)
	_intro_tag = UiKit.glow_label("", 34, UiKit.RED, UiKit.display_light())
	_intro_title = UiKit.glow_label("", 92, Color.WHITE, UiKit.display())
	_intro_sub = UiKit.label("", 30, Color(1, 1, 1, 0.75), UiKit.display_light())
	for l in [_intro_tag, _intro_title, _intro_sub]:
		l.modulate.a = 0.0
		add_child(l)
	_split_head = UiKit.label("", 28, Color(1, 1, 1, 0.85), UiKit.display_light())
	_split_time = UiKit.glow_label("", 96, Defs.GAUNTLET_COLOR, UiKit.display())
	_split_sub = UiKit.glow_label("", 40, UiKit.GREEN, UiKit.display())
	for l in [_split_head, _split_time, _split_sub]:
		l.modulate.a = 0.0
		add_child(l)
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
		if not arena.demo:
			_boss_intro(type)
		_boss_name.text = BOSS_NAMES.get(type, "BOSS")
		if arena.sim.gauntlet:
			_boss_name.text = ""
		if arena.sim.endless:
			_boss_name.text += "  ·  NIGHT %d" % arena.sim.night
		var bi := arena.sim.boss_index()
		if bi >= 0 and arena.sim.e_tr[bi] != 0:
			var adj: Array = []
			for id in Defs.trait_ids(arena.sim.e_tr[bi]):
				adj.append(String(Defs.TRAITS[id].adj))
			_boss_name.text = " ".join(adj) + "  ·  " + _boss_name.text)
	a.elite_arrived.connect(_on_elite)
	a.trophy.connect(func(type: int, mask: int):
		if type >= Defs.WARDEN:
			return
		var n := Defs.trait_ids(mask).size()
		var tag := "EXALTED TROPHY" if n >= Defs.TRAIT_MAX else "TROPHY"
		show_banner(tag, Defs.TRAIT_COLOR, "%s  ·  +%s" % [String(Defs.ENEMY[type].name).to_upper(),
				UiKit.fmt_int(Defs.TRAIT_SCORE * n)]))
	a.card_taken.connect(func(_id, _lvl): _rebuild_loadout())
	a.resonance_formed.connect(func(id: String):
		_rebuild_loadout()
		show_resonance(id))
	if a.sim.gauntlet:
		var g := Save.gauntlet_rec()
		_g_best = (g.splits as Array).duplicate()
		_g_prev_clear = int(g.best_clear)
		a.gauntlet_split.connect(_on_split)
		a.gauntlet_cleared.connect(func(ticks: int):
			var rec := _g_prev_clear <= 0 or ticks < _g_prev_clear
			show_banner("GAUNTLET CLEARED", Defs.GAUNTLET_COLOR, GauntletScreen.fmt_split(ticks) +
					("  ·  NEW RECORD" if rec else "  ·  CYCLE II BEGINS")))
		a.gauntlet_cycle.connect(func(cycle: int):
			show_banner("CYCLE %s" % ROMAN[mini(cycle, ROMAN.size() - 1)], Defs.GAUNTLET_COLOR,
					"THE BOSSES RETURN STRONGER"))
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
	if arena != null and arena.sim != null and arena.sim.gauntlet:
		y = top + 300.0 + 40.0 * _boss_alpha
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
	for id in arena.sim.resonances:
		var ic := UiKit.icon_rect("res_" + id, 44)
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


## An elite arrives: its card drops in under the HUD, naming it and its traits.
func _on_elite(type: int, mask: int) -> void:
	if arena.demo or mask == 0:
		return
	if is_instance_valid(_elite_card):
		_elite_card.queue_free()
	var w := minf(size.x - 80.0, 900.0)
	var slain = Save.data.get("trait_kills", {})
	_elite_card = EliteCard.make(type, mask, slain if slain is Dictionary else {}, w)
	_elite_card.position = Vector2((size.x - w) * 0.5, top + 400.0)
	add_child(_elite_card)


## A boss arrives: letterbox bars slide in around a title card with its name.
func _boss_intro(type: int) -> void:
	_intro = INTRO_TIME
	_intro_col = Defs.ENEMY_COLOR[type]
	var s := arena.sim
	_intro_tag.text = "NIGHT %d" % s.night if s.endless else "WARNING"
	if s.gauntlet:
		_intro_tag.text = "BOSS %d" % (s.g_stage + 1)
		if s.gauntlet_cycle() > 0:
			_intro_tag.text += "  ·  CYCLE %s" % ROMAN[mini(s.gauntlet_cycle(), ROMAN.size() - 1)]
	_intro_title.text = BOSS_NAMES.get(type, "BOSS")
	_intro_title.add_theme_color_override("font_color", _intro_col.lerp(Color.WHITE, 0.6))
	_intro_title.add_theme_color_override("font_shadow_color", Color(_intro_col, 0.7))
	_intro_sub.text = BOSS_EPITHETS.get(type, "")
	var w := size.x
	var y := size.y * 0.34
	_intro_tag.position = Vector2(0, y - 70)
	_intro_title.position = Vector2(0, y)
	_intro_sub.position = Vector2(0, y + 118)
	for l in [_intro_tag, _intro_title, _intro_sub]:
		l.size = Vector2(w, l.size.y)
		l.pivot_offset = Vector2(w * 0.5, l.size.y * 0.5)
	var tw := create_tween()
	_intro_title.scale = Vector2(1.5, 1.5)
	_intro_tag.modulate.a = 0.0
	tw.tween_property(_intro_tag, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(_intro_title, "modulate:a", 1.0, 0.25).set_delay(0.12)
	tw.parallel().tween_property(_intro_title, "scale", Vector2.ONE, 0.5).set_delay(0.12) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_intro_sub, "modulate:a", 1.0, 0.4).set_delay(0.45)
	tw.tween_interval(INTRO_TIME - 1.2)
	for l in [_intro_tag, _intro_title, _intro_sub]:
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5)


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
	_score.text = ("R%d  ·  " % s.radiance if s.radiance > 0 else "") + "SCORE " + UiKit.fmt_int(int(ceil(_score_shown)))
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
	if s.gauntlet:
		_update_gauntlet(s)
	_relics.position = Vector2(24, _loadout.position.y + 70.0)
	_update_rift(s, delta)
	_update_chain(s, delta)
	_intro = maxf(0.0, _intro - delta)
	if not _res_queue.is_empty() and not arena.paused and not is_instance_valid(_res_box):
		_reveal_resonance(_res_queue.pop_front())
	queue_redraw()


## The Gauntlet: the live split under the boss bar (green while ahead of your
## best), or the countdown to the next boss. The ladder sits above the bar.
func _update_gauntlet(s: Sim) -> void:
	_loadout.position.y = top + 304.0
	var k := s.g_stage % Defs.GAUNTLET.size()
	var best := int(_g_best[k]) if s.gauntlet_cycle() == 0 and k < _g_best.size() else 0
	if s.g_next < 0:
		var ticks := s.tick - s.g_boss_tick
		_boss_name.text = "SPLIT  " + GauntletScreen.fmt_split(ticks)
		var col := Defs.GAUNTLET_COLOR
		if best > 0:
			_boss_name.text += "   ·   BEST " + GauntletScreen.fmt_split(best)
			col = UiKit.GREEN if ticks <= best else UiKit.RED
		_boss_name.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.3))
		_boss_name.position.y = top + 248.0
	else:
		var wait := s.gauntlet_wait()
		_boss_name.text = "" if s.tick <= 1 else "NEXT  ·  %s  ·  %d" % [BOSS_NAMES[Defs.GAUNTLET[k]], ceili(wait)]
		_boss_name.add_theme_color_override("font_color", Defs.GAUNTLET_COLOR.lerp(Color.WHITE, 0.3))
		_boss_name.position.y = top + 222.0
		_boss_name.modulate.a = 1.0


## A Gauntlet boss passed: its split, and how it compares with your best.
func _on_split(stage: int, ticks: int, felled: bool) -> void:
	var k := stage % Defs.GAUNTLET.size()
	var type: int = Defs.GAUNTLET[k]
	var best := int(_g_best[k]) if stage < Defs.GAUNTLET.size() and k < _g_best.size() else 0
	_split_head.text = BOSS_NAMES[type] + ("  FELLED" if felled else "  ESCAPED")
	var sub := ""
	var sub_col := Defs.GAUNTLET_COLOR
	if not felled:
		_split_time.text = "NO SPLIT"
		sub = "IT TOOK ITS PRIZE"
		sub_col = UiKit.RED
	else:
		_split_time.text = GauntletScreen.fmt_split(ticks)
		if stage >= Defs.GAUNTLET.size():
			sub = "CYCLE %s" % ROMAN[mini(stage / Defs.GAUNTLET.size(), ROMAN.size() - 1)]
		elif best <= 0:
			sub = "FIRST SPLIT"
		else:
			var d := ticks - best
			sub = ("-" if d < 0 else "+") + GauntletScreen.fmt_split(absi(d)) + ("  ·  NEW BEST" if d < 0 else "")
			sub_col = UiKit.GREEN if d < 0 else UiKit.RED
		var under := Defs.GAUNTLET_PAR - ticks / Sim.TPS
		if under > 0:
			sub += "  ·  +%s SPEED" % UiKit.fmt_int(under * Defs.GAUNTLET_SPEED_PTS)
	_split_sub.text = sub
	_split_sub.add_theme_color_override("font_color", sub_col.lerp(Color.WHITE, 0.25))
	_split_sub.add_theme_color_override("font_shadow_color", Color(sub_col, 0.6))
	var record := felled and best > 0 and ticks < best and stage < Defs.GAUNTLET.size()
	Sfx.play("split_best" if record or (felled and best <= 0 and stage < Defs.GAUNTLET.size()) else "split")
	var w := size.x
	var y := size.y * 0.27
	_split_head.position = Vector2(0, y)
	_split_time.position = Vector2(0, y + 34)
	_split_sub.position = Vector2(0, y + 150)
	for l in [_split_head, _split_time, _split_sub]:
		l.size = Vector2(w, l.size.y)
		l.pivot_offset = Vector2(w * 0.5, l.size.y * 0.5)
	_split_time.scale = Vector2(1.6, 1.6)
	var tw := create_tween()
	tw.tween_property(_split_head, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(_split_time, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(_split_time, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_EXPO) \
			.set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_split_sub, "modulate:a", 1.0, 0.3).set_delay(0.35)
	tw.tween_interval(1.9)
	for l in [_split_head, _split_time, _split_sub]:
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6)


## The open rift's objective: a glass pill under the loadout.
func _update_rift(s: Sim, delta: float) -> void:
	var on := not s.rift.is_empty()
	_rift_alpha = move_toward(_rift_alpha, 1.0 if on else 0.0, delta * (5.0 if on else 2.5))
	_rift_y = _relics.position.y + (56.0 if not s.relics.is_empty() else 0.0)
	_rift_title.position = Vector2(112, _rift_y + 8)
	_rift_sub.position = Vector2(112, _rift_y + 40)
	_rift_title.modulate.a = _rift_alpha
	_rift_sub.modulate.a = _rift_alpha * 0.9
	if not on:
		return
	_rift_kind = int(s.rift.kind)
	var info: Dictionary = Defs.RIFTS[_rift_kind]
	var left := UiKit.fmt_time(float(s.rift.life) / float(Sim.TPS))
	var title := String(info.goal)
	var sub := left
	match _rift_kind:
		Defs.RIFT_BEACON:
			if s.rift_frac() > 0.0:
				title = "CHARGING  %d%%" % int(s.rift_frac() * 100.0)
				sub = "STAY IN THE RING"
			else:
				sub = "HOLD THE RING  ·  " + left
		Defs.RIFT_WISP:
			sub = ("IT TIRES, KEEP CHASING  ·  " if s.rift.on else "FOLLOW THE ARROW  ·  ") + left
		Defs.RIFT_TRIAL:
			if s.rift.on:
				sub = "%d / %d  ·  %s" % [mini(s.kills - int(s.rift.k0), int(s.rift.goal)), int(s.rift.goal), left]
			else:
				title = "UMBRAL RIFT"
				sub = "TOUCH IT TO BEGIN  ·  " + left
		Defs.RIFT_STARFALL:
			if s.rift.on:
				var secs := ceili(float(Defs.STARFALL_TICKS) * (1.0 - s.rift_frac()) / float(Sim.TPS))
				title = "STARFALL  %ds" % secs if secs > 0 else "THE LAST STAR"
				sub = "STAY IN THE RING, DODGE THE MARKS  ·  " + left
			else:
				sub = "STEP INTO THE RING  ·  " + left
	_rift_title.text = title
	_rift_sub.text = sub
	var col: Color = info.color
	_rift_title.add_theme_color_override("font_color", col.lerp(Color.WHITE, 0.35))


func _update_chain(s: Sim, delta: float) -> void:
	var on := s.chain >= CHAIN_SHOW
	_chain_alpha = move_toward(_chain_alpha, 1.0 if on else 0.0, delta * (6.0 if on else 3.0))
	_chain_pop = maxf(0.0, _chain_pop - delta * 2.5)
	if on:
		if s.chain != _chain_shown:
			_chain.scale = Vector2.ONE * (1.12 + 0.25 * _chain_pop)
		_chain_shown = s.chain
		_chain.text = "%s CHAIN" % UiKit.fmt_int(s.chain)
		var m := s.chain_mult()
		_chain_mult.text = "SCORE x%.1f" % m if m > 1.0 else "KEEP IT GOING"
		# The counter warms from gold to white-hot as the multiplier climbs.
		var heat := clampf((m - 1.0) / (s.chain_cap() - 1.0), 0.0, 1.0)
		_chain.add_theme_color_override("font_color", UiKit.GOLD.lerp(Color(1.0, 0.95, 0.9), heat))
	_chain.scale = _chain.scale.lerp(Vector2.ONE, clampf(delta * 10.0, 0.0, 1.0))
	_chain.modulate.a = _chain_alpha
	_chain_mult.modulate.a = _chain_alpha * 0.9
	_place_chain()


func _draw() -> void:
	var w := size.x
	if _intro > 0.0:
		# Letterbox bars and a line of the boss's colour sweeping out under its name.
		var age := INTRO_TIME - _intro
		var k := clampf(minf(age / 0.35, _intro / 0.5), 0.0, 1.0)
		k = 1.0 - (1.0 - k) * (1.0 - k)
		var bh := 150.0 * k
		draw_rect(Rect2(0, 0, w, bh), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(0, size.y - bh, w, bh), Color(0, 0, 0, 0.8))
		# A dark band behind the title so it reads over the fight.
		var by := size.y * 0.34
		for j in 6:
			var e := float(j) * 14.0
			draw_rect(Rect2(0, by - 80.0 + e, w, 270.0 - 2.0 * e), Color(0.0, 0.0, 0.02, 0.1 * k))
		var ly := size.y * 0.34 + 108.0
		var lw := w * 0.42 * clampf((age - 0.2) / 0.5, 0.0, 1.0) * k
		draw_line(Vector2(w * 0.5 - lw, ly), Vector2(w * 0.5 + lw, ly), Color(_intro_col * 1.4, 0.8 * k), 3.0)
		draw_line(Vector2(w * 0.5 - lw * 0.6, ly + 8), Vector2(w * 0.5 + lw * 0.6, ly + 8), Color(_intro_col, 0.35 * k), 2.0)
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
	_draw_res_links()
	_draw_cache_arrows()
	_draw_rift()
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
	if arena.sim.gauntlet:
		_draw_ladder()
	if _boss_alpha > 0.0:
		var by := top + (222.0 if arena.sim.gauntlet else 160.0)
		var bw := w * 0.8
		var br := Rect2((w - bw) * 0.5, by, bw, 18)
		draw_rect(br.grow(3), Color(0.03, 0.0, 0.03, 0.9 * _boss_alpha))
		draw_rect(br, Color(0.25, 0.05, 0.1, 0.9 * _boss_alpha))
		var col: Color = Defs.ENEMY_COLOR[maxi(_boss_type, Defs.WARDEN)]
		draw_rect(Rect2(br.position, Vector2(bw * _boss_shown, 18)), Color(col * 1.3, _boss_alpha))
		for k in range(1, 10):
			var x := br.position.x + bw * k / 10.0
			draw_line(Vector2(x, by), Vector2(x, by + 18), Color(0, 0, 0, 0.5 * _boss_alpha), 2.0)
		# A Shielded night boss: its barrier as a strip over the bar.
		var bi := arena.sim.boss_index()
		if bi >= 0:
			var ts := arena.sim.trait_state(bi)
			if float(ts.get("bmax", 0.0)) > 0.0:
				var bf := clampf(float(ts.bar) / float(ts.bmax), 0.0, 1.0)
				draw_rect(Rect2(br.position + Vector2(0, -9), Vector2(bw * bf, 6)),
						Color(Defs.TRAITS.shielded.color * 1.6, _boss_alpha))


## Resonating weapons in the loadout are bridged by an arc of the
## resonance's colour, with a spark running along it.
func _draw_res_links() -> void:
	var s := arena.sim
	var fade := _loadout.modulate.a
	for idx in s.resonances.size():
		var r: Dictionary = Defs.RESONANCES[s.resonances[idx]]
		if not _icons.has(r.a) or not _icons.has(r.b):
			continue
		var sa: Control = _icons[r.a]
		var sb: Control = _icons[r.b]
		var x0 := _loadout.position.x + sa.position.x + 27.0
		var x1 := _loadout.position.x + sb.position.x + 27.0
		var y0 := _loadout.position.y + 4.0
		var hgt := 8.0 + 3.0 * absf(x1 - x0) / 60.0
		var pts := PackedVector2Array()
		for k in 17:
			var t := float(k) / 16.0
			pts.append(Vector2(lerpf(x0, x1, t), y0 - hgt * 4.0 * t * (1.0 - t)))
		var col: Color = r.color
		var pulse := 0.65 + 0.35 * sin(arena.vtime * 3.0 + float(idx) * 2.1)
		draw_polyline(pts, Color(col, 0.22 * fade), 8.0, true)
		draw_polyline(pts, Color(col * 1.4, 0.85 * pulse * fade), 2.5, true)
		var tt := fmod(arena.vtime * 0.6 + float(idx) * 0.37, 1.0)
		var sp := Vector2(lerpf(x0, x1, tt), y0 - hgt * 4.0 * tt * (1.0 - tt))
		draw_circle(sp, 6.0, Color(col, 0.35 * fade))
		draw_circle(sp, 3.0, Color(1, 1, 1, 0.95 * fade))


## A resonance switched on: shown once play resumes (not under the cards or
## a cache), one at a time.
func show_resonance(id: String) -> void:
	_res_queue.append(id)


## The two weapons slide in from either side, lock together in a flash and
## become the resonance's sigil, with its name and what it does underneath.
func _reveal_resonance(id: String) -> void:
	var info: Dictionary = Defs.RESONANCES[id]
	var col: Color = info.color
	var fresh := not (Save.data.get("resonances", []) as Array).has(id)
	var w := size.x
	var cy := size.y * 0.36
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	_res_box = box
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.03, 0.55)
	shade.position = Vector2(0, cy - 150.0)
	shade.size = Vector2(w, 440.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.modulate.a = 0.0
	box.add_child(shade)
	var tag := UiKit.glow_label("NEW RESONANCE" if fresh else "RESONANCE", 32, col, UiKit.display_light())
	tag.position = Vector2(0, cy - 140.0)
	tag.size = Vector2(w, 44)
	tag.modulate.a = 0.0
	box.add_child(tag)
	var icons: Array = []
	for k in 2:
		var wid: String = info.a if k == 0 else info.b
		var ic := UiKit.icon_rect(wid, 130)
		ic.size = Vector2(130, 130)
		ic.pivot_offset = Vector2(65, 65)
		ic.position = Vector2(w * 0.5 - 65.0 + (-300.0 if k == 0 else 300.0), cy - 75.0)
		ic.modulate = Color(1, 1, 1, 0)
		box.add_child(ic)
		icons.append(ic)
	var sigil := UiKit.icon_rect("res_" + id, 190)
	sigil.size = Vector2(190, 190)
	sigil.pivot_offset = Vector2(95, 95)
	sigil.position = Vector2(w * 0.5 - 95.0, cy - 105.0)
	sigil.modulate = Color(3, 3, 3, 0)
	sigil.scale = Vector2(0.4, 0.4)
	box.add_child(sigil)
	var name := UiKit.glow_label(String(info.name).to_upper(), 72, col.lerp(Color.WHITE, 0.35), UiKit.display())
	name.position = Vector2(0, cy + 92.0)
	name.size = Vector2(w, 90)
	name.pivot_offset = Vector2(w * 0.5, 45)
	name.modulate.a = 0.0
	box.add_child(name)
	var desc := UiKit.label(String(info.text), 32, Color(0.92, 0.94, 1.0), UiKit.body())
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size = Vector2(minf(w - 120.0, 820.0), 90)
	desc.position = Vector2((w - desc.size.x) * 0.5, cy + 196.0)
	desc.modulate.a = 0.0
	box.add_child(desc)
	var tw := box.create_tween()
	tw.tween_property(shade, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(tag, "modulate:a", 1.0, 0.25)
	for k in 2:
		var ic: TextureRect = icons[k]
		var to_x := w * 0.5 - 65.0 + (-62.0 if k == 0 else 62.0)
		tw.parallel().tween_property(ic, "modulate:a", 1.0, 0.18)
		tw.parallel().tween_property(ic, "position:x", to_x, 0.42).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	# They meet: a flash, and the sigil blooms out of them.
	for k in 2:
		var ic: TextureRect = icons[k]
		tw.parallel().tween_property(ic, "modulate", Color(3, 3, 3, 0), 0.25).set_delay(0.42)
		tw.parallel().tween_property(ic, "scale", Vector2(1.5, 1.5), 0.25).set_delay(0.42)
	tw.parallel().tween_property(sigil, "modulate", Color.WHITE, 0.35).set_delay(0.42)
	tw.parallel().tween_property(sigil, "scale", Vector2.ONE, 0.5).set_delay(0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	name.scale = Vector2(1.4, 1.4)
	tw.parallel().tween_property(name, "modulate:a", 1.0, 0.25).set_delay(0.55)
	tw.parallel().tween_property(name, "scale", Vector2.ONE, 0.45).set_delay(0.55) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(desc, "modulate:a", 1.0, 0.4).set_delay(0.8)
	tw.tween_interval(2.1)
	tw.tween_property(box, "modulate:a", 0.0, 0.5)
	tw.tween_callback(box.queue_free)


## The Gauntlet ladder: the four bosses of this cycle in a row, passed ones
## with their split, the one you face glowing.
func _draw_ladder() -> void:
	var s := arena.sim
	var w := size.x
	var n := Defs.GAUNTLET.size()
	var cur := s.g_stage % n
	var up := s.g_next < 0
	var y := top + 150.0
	var gap := 96.0
	var x0 := w * 0.5 - gap * float(n - 1) * 0.5
	var font := UiKit.display()
	var gold := Defs.GAUNTLET_COLOR
	for k in n - 1:
		var lit := k < cur
		draw_line(Vector2(x0 + gap * k + 26.0, y), Vector2(x0 + gap * (k + 1) - 26.0, y),
				Color(gold * (1.3 if lit else 0.5), 0.9 if lit else 0.35), 3.0 if lit else 2.0)
	var first := s.g_stage - cur
	for k in n:
		var type: int = Defs.GAUNTLET[k]
		var c := Vector2(x0 + gap * k, y)
		var col: Color = Defs.ENEMY_COLOR[type]
		var sz := 62.0
		var mod := Color(0.35, 0.35, 0.45, 0.7)
		if k < cur:
			mod = Color(1.0, 0.85, 0.6, 0.75)
		elif k == cur:
			var pulse := 0.5 + 0.5 * sin(arena.vtime * (7.0 if up else 3.0))
			sz = 74.0 + (8.0 * pulse if up else 0.0)
			mod = Color(1.3, 1.3, 1.3, 1.0) if up else Color(1.0, 1.0, 1.0, 0.85)
			draw_circle(c, 34.0 + 6.0 * pulse, Color(col, 0.16 + 0.14 * pulse))
			draw_arc(c, 36.0 + 4.0 * pulse, 0.0, TAU, 40, Color(col * 1.4, 0.7), 2.5)
		draw_texture_rect(Art.enemy[type], Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, mod)
		if k < cur and first + k < s.g_splits.size():
			var t := int(s.g_splits[first + k])
			var txt := GauntletScreen.fmt_split(t) if t > 0 else "ESC"
			draw_string(font, Vector2(c.x - 60.0, y + 50.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20,
					Color(gold.lerp(Color.WHITE, 0.4), 0.85) if t > 0 else Color(UiKit.RED, 0.8))


## The rift's objective pill and, while it is off screen, an arrow to it.
func _draw_rift() -> void:
	if _rift_alpha <= 0.0:
		return
	var s := arena.sim
	var col: Color = Defs.RIFTS[_rift_kind].color
	var rect := Rect2(20, _rift_y, 500, 82)
	_rift_box.border_color = Color(col, 0.7 * _rift_alpha)
	_rift_box.bg_color = Color(0.03, 0.02, 0.08, 0.75 * _rift_alpha)
	draw_style_box(_rift_box, rect)
	var pulse := 1.0 + 0.06 * sin(arena.vtime * 6.0)
	var isz := 64.0 * pulse
	draw_texture_rect(Art.tex("i_rift_" + String(Defs.RIFTS[_rift_kind].id)),
			Rect2(rect.position + Vector2(48.0 - isz * 0.5, 41.0 - isz * 0.5), Vector2(isz, isz)), false,
			Color(1.3, 1.3, 1.3, _rift_alpha))
	var frac := s.rift_frac() if not s.rift.is_empty() else 0.0
	var bar := Rect2(rect.position.x + 92, rect.position.y + rect.size.y - 12, rect.size.x - 112, 5)
	draw_rect(bar, Color(1, 1, 1, 0.1 * _rift_alpha))
	if frac > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(col * 1.4, _rift_alpha))
	if s.rift.is_empty() or (s.rift.on and _rift_kind == Defs.RIFT_TRIAL):
		return
	var vs := size
	var center := arena.camera.get_screen_center_position()
	var half := vs * 0.5
	var rel := Vector2(float(s.rift.x), float(s.rift.y)) - center
	if absf(rel.x) < half.x - 40.0 and absf(rel.y) < half.y - 40.0:
		return
	var dir := rel.normalized()
	var lim := half - Vector2(70.0, 70.0)
	var k := minf(lim.x / maxf(absf(dir.x), 0.001), lim.y / maxf(absf(dir.y), 0.001))
	var pos := half + dir * k
	pos.y = clampf(pos.y, top + 220.0, vs.y - 70.0)
	var ap := 1.0 + 0.15 * sin(arena.vtime * 8.0)
	var tip := pos + dir * 34.0 * ap
	var side := dir.orthogonal() * 22.0 * ap
	draw_colored_polygon(PackedVector2Array([tip, pos - dir * 6.0 + side, pos - dir * 6.0 - side]), col)
	draw_texture_rect(Art.tex("i_rift_" + String(Defs.RIFTS[_rift_kind].id)),
			Rect2(pos - dir * 52.0 - Vector2(32, 32), Vector2(64, 64)), false, Color(1.3, 1.3, 1.3, 0.95))


## Off-screen Prism Caches (and elites) get a pulsing arrow on the screen edge.
func _draw_cache_arrows() -> void:
	if arena == null or arena.sim == null:
		return
	var vs := size
	var center := arena.camera.get_screen_center_position()
	var half := vs * 0.5
	var t := arena.vtime
	var s := arena.sim
	for i in s.en:
		if s.e_elite[i] == 0 or s.e_spawn[i] > 0 or s.e_type[i] >= Defs.WARDEN:
			continue
		var rel2 := Vector2(s.e_x[i], s.e_y[i]) - center
		if absf(rel2.x) < half.x - 40.0 and absf(rel2.y) < half.y - 40.0:
			continue
		var dir2 := rel2.normalized()
		var lim2 := half - Vector2(70.0, 70.0)
		var k2 := minf(lim2.x / maxf(absf(dir2.x), 0.001), lim2.y / maxf(absf(dir2.y), 0.001))
		var pos2 := half + dir2 * k2
		pos2.y = clampf(pos2.y, top + 220.0, vs.y - 70.0)
		var pulse2 := 1.0 + 0.12 * sin(t * 6.0)
		var side2 := dir2.orthogonal() * 18.0 * pulse2
		var tip2 := pos2 + dir2 * 28.0 * pulse2
		draw_colored_polygon(PackedVector2Array([tip2, pos2 - dir2 * 4.0 + side2, pos2 - dir2 * 4.0 - side2]),
				Color(Defs.TRAIT_COLOR * 1.2, 0.9))
		draw_texture_rect(Art.icon("trait"), Rect2(pos2 - dir2 * 44.0 - Vector2(26, 26), Vector2(52, 52)), false,
				Color(1.3, 1.3, 1.3, 0.9))
	for p in s.pickups:
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

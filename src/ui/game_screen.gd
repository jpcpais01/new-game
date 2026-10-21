class_name GameScreen
extends Control
## A run: joystick input -> Arena/Sim, HUD, level-up cards, pause, results.

var main
var arena: Arena
var sim: Sim

var _stick: Joystick
var _hud: Hud
var _od: OverdriveButton
var _cards: LevelUpPanel
var _chest: ChestPanel
var _pause: Modal
var _hint: Control
var _card_delay := -1.0
var _over := false
var _dawn: Control
var _tips: Array = []      # queued coach tips [title, text, colour]
var _tip: Control
var _gauntlet_intro := false
var _resonated := false    # a resonance switched on during the last pick


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena = main.arena
	_stick = Joystick.new()
	_stick.moved_first.connect(_hide_hint)
	add_child(_stick)
	_hud = Hud.new()
	_hud.top = main.safe_top()
	_hud.pause_pressed.connect(open_pause)
	add_child(_hud)
	_od = OverdriveButton.new()
	add_child(_od)
	resized.connect(_layout_od)
	_cards = LevelUpPanel.new()
	_cards.visible = false
	_cards.picked.connect(_on_pick)
	_cards.reroll_pressed.connect(_on_reroll)
	_cards.banish_pressed.connect(_on_banish)
	_cards.decline_pressed.connect(_on_decline)
	add_child(_cards)
	_chest = ChestPanel.new()
	_chest.visible = false
	_chest.closed.connect(_on_chest_closed)
	add_child(_chest)


func begin(seed_value: int, loadout: Dictionary) -> void:
	sim = Sim.new(seed_value, loadout)
	arena.start(sim, false)
	arena.leveled_up.connect(_on_level)
	arena.ended.connect(_on_end)
	arena.chest_opened.connect(_on_chest)
	arena.hurt.connect(func(): _stick.modulate = Color(1.4, 0.6, 0.6))
	_hud.bind(arena)
	_od.arena = arena
	_layout_od()
	arena.overdrive_ready.connect(_on_od_ready)
	arena.coach.connect(_on_coach)
	arena.card_taken.connect(_on_card_taken)
	arena.resonance_formed.connect(_on_resonance)
	Sfx.music("run", "" if sim.sector == 0 else String(Defs.sector(sim.sector).id))
	if not bool(Save.data.tutorial_done):
		_show_hint()
	if not sim.mods.is_empty():
		_show_mods()
	elif sim.sector > 0:
		_show_sector()
	elif sim.radiance > 0:
		_show_radiance()


func _process(delta: float) -> void:
	if arena == null or sim == null:
		return
	_stick.modulate = _stick.modulate.lerp(Color.WHITE, clampf(delta * 4.0, 0.0, 1.0))
	arena.input_vec = _stick.get_vector()
	if sim.gauntlet and not _gauntlet_intro and sim.state == Sim.RUNNING and sim.tick > 1:
		# After the draft: the bosses in line.
		_gauntlet_intro = true
		_show_gauntlet()
	if _card_delay > 0.0:
		_card_delay -= delta
		if _card_delay <= 0.0:
			_open_cards()
	elif sim.state == Sim.CHOOSING and not _cards.visible and not _chest.visible and _pause == null and not _over:
		_card_delay = 0.01


## The first few times the meter fills, say what the glowing button is for.
func _on_od_ready() -> void:
	var tips := int(Save.data.get("od_tips", 0))
	if tips < 3:
		Save.data.od_tips = tips + 1
		_hud.show_banner("OVERDRIVE READY", arena.ship_color)
	if Save.tip_once("overdrive"):
		_queue_tip("OVERDRIVE", "Tap the blazing ring in the corner to unleash %s." % Defs.ship(sim.ship_id).od,
				arena.ship_color)


func _layout_od() -> void:
	if _od == null:
		return
	_od.position = Vector2(size.x - _od.size.x - 26.0, size.y - _od.size.y - 120.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE or event.physical_keycode == KEY_E:
			_od.trigger()


func _on_level() -> void:
	arena.slowmo(0.1, 0.3)
	_card_delay = 0.38


func _open_cards() -> void:
	if sim.state != Sim.CHOOSING or _over or _chest.visible:
		return
	arena.paused = true
	_stick.release()
	Sfx.duck(true)
	_cards.open(sim)


func _on_pick(index: int) -> void:
	_resonated = false
	sim.choose(index)
	arena.handle_events()
	if sim.state == Sim.CHOOSING and not _resonated:
		_cards.open(sim)
		Sfx.play("levelup", 1.12)
	else:
		_cards.close()
		arena.paused = false
		Sfx.duck(false)
		# A burst of light as play resumes.
		arena.fx.ring(sim.px, sim.py, 10.0, 260.0, 0.45, UiKit.CYAN, 1.2)
		arena.add_wave(sim.px, sim.py, 1.0)
		if _resonated:
			# Let the resonance play out before the next cards.
			_card_delay = 2.2


## A resonance switched on: the HUD shows it; explain the idea the first time.
func _on_resonance(_id: String) -> void:
	_resonated = true
	if Save.tip_once("resonance"):
		_queue_tip("RESONANCE", "Some weapons resonate in pairs. Hold both at level 2 and they unlock a bonus " +
				"for the run. Cards show a partner you already carry, and the Codex maps all nine.",
				Defs.RESONANCE_COLOR)


func _on_chest(rewards: Array, big: bool) -> void:
	if _over:
		return
	arena.paused = true
	_stick.release()
	Sfx.duck(true)
	_chest.open(rewards, big)


func _on_chest_closed() -> void:
	if sim.state == Sim.CHOOSING:
		return
	arena.paused = false
	Sfx.duck(false)
	arena.fx.ring(sim.px, sim.py, 10.0, 260.0, 0.45, UiKit.GOLD, 1.2)
	arena.add_wave(sim.px, sim.py, 1.0)


func _on_banish(index: int) -> void:
	sim.banish(index)
	arena.handle_events()
	Sfx.play("banish")
	Sfx.buzz(45)
	_cards.replace_card(index)


## Refused an Umbral offer: a Prism Cache drops at the ship instead.
func _on_decline() -> void:
	sim.decline()
	arena.handle_events()
	if sim.state == Sim.CHOOSING:
		_cards.open(sim)
	else:
		_cards.close()
		arena.paused = false
		Sfx.duck(false)


func _on_reroll() -> void:
	sim.reroll()
	arena.handle_events()
	Sfx.play("card", 0.8)
	_cards.open(sim)


func _on_end(won: bool) -> void:
	if _over:
		return
	if won and not sim.endless:
		_offer_night()
		return
	_over = true
	_stick.release()
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var beat: Dictionary = Save.record_run(sim)
	Save.data.tutorial_done = true
	Save.save_data()
	var r := ResultsPanel.new()
	r.sim = sim
	r.won = sim.dawn
	r.beat = beat
	r.retry.connect(func():
		if sim.gauntlet:
			main.start_gauntlet()
		elif sim.loadout.has("daily"):
			main.start_daily()
		else:
			main.start_run())
	r.forge.connect(func(): main.go_forge())
	r.home.connect(func(): main.go_title())
	r.hangar.connect(func(): main.go_hangar())
	add_child(r)
	Sfx.music("menu")


## Dawn reached: bank the win, or fly on into the Afterdark for a bigger score.
func _offer_night() -> void:
	_stick.release()
	var p := DawnPanel.new()
	p.sim = sim
	_dawn = p
	p.chose.connect(func(go_on: bool):
		_dawn = null
		if go_on:
			sim.continue_night()
			arena.handle_events()
			arena.night_fall()
			Sfx.music("run", "" if sim.sector == 0 else String(Defs.sector(sim.sector).id))
		else:
			_on_end(false))
	add_child(p)
	Sfx.music("menu")


func open_pause() -> void:
	if _pause != null or _over or _dawn != null or _cards.visible or _chest.visible:
		return
	arena.paused = true
	_stick.release()
	Sfx.duck(true)
	var p := PausePanel.new()
	p.sim = sim
	p.resume.connect(_resume)
	p.quit.connect(func():
		_pause = null
		sim.state = Sim.DEAD
		_on_end(false))
	_pause = p
	add_child(p)


func _resume() -> void:
	_pause = null
	if not _cards.visible:
		arena.paused = false
	Sfx.duck(false)


# --- coach tips ---------------------------------------------------------------------

const COACH := {
	"elite": ["ELITE HUNT", "Every elite carries traits, shown over its head. Slay it for a Prism Cache: one upgrade per trait. The first also guards a relic."],
	"boss": ["BOSS", "Bosses telegraph every attack. Defeat one for a big cache, a core and a heart."],
	"laser": ["LASERS", "A thin line warns you before a beam fires. Step out of it."],
	"chain": ["THE CHAIN", "Kills in a row build your Chain and multiply your score. A hit breaks it."],
	"low_hp": ["LOW HULL", "The swarm sometimes drops hearts. Repair cards heal you too."],
	"leviathan": ["THE LEVIATHAN", "Only its head can be hurt, and its body burns. When it coils, slip out " +
			"through the gap; when it rears back, step out of its line."],
	"rift": ["RIFTS", "A rift has opened: follow its arrow. Light a Beacon, catch a Wisp, weather a Starfall or " +
			"win an Umbral Trial for a prize, before it fades."],
	"maw": ["BLACK HOLES", "It drags in the swarm, your gems and you. Lure the swarm in and keep clear of the " +
			"core: when it collapses, everything it ate bursts back out as light."],
	"flare": ["SOLAR FLARE", "The sun is about to erupt. The cool lanes are the gaps in its wall of fire: " +
			"be inside one when the front reaches you."],
	"shard": ["CRYSTALS", "Fight beside a crystal to charge it: full, it shatters in a burst of light that " +
			"tears through the swarm. Standing, it stops the swarm, its shots and its lasers."],
	"cover": ["TAKE COVER", "A crystal just took a laser for you. Put one between you and a Sentinel or the " +
			"Seraph and their beams cannot reach you."],
}


func _on_coach(key: String) -> void:
	if COACH.has(key) and Save.tip_once(key):
		var col := UiKit.RED if key == "low_hp" or key == "laser" or key == "boss" else UiKit.GOLD
		if key == "rift":
			col = Defs.RIFTS[0].color
		_queue_tip(COACH[key][0], COACH[key][1], col)


## A maxed weapon whose catalyst you carry: say how to evolve it, once.
func _on_card_taken(_id: String, _lvl: int) -> void:
	for w in sim.weapons:
		if sim.evolution_ready(w.id):
			if Save.tip_once("evolve"):
				_queue_tip("EVOLUTION READY", "%s pulses gold. Open a Prism Cache from an elite or boss to evolve it." %
						String(Defs.WEAPONS[w.id].name), UiKit.GOLD)
			return


func _queue_tip(title: String, text: String, col: Color) -> void:
	_tips.append([title, text, col])
	if _tip == null:
		_next_tip()


## One glass card at a time, low on the screen, out of the way of the ship.
func _next_tip() -> void:
	if _tips.is_empty() or _over:
		_tip = null
		return
	var t: Array = _tips.pop_front()
	var col: Color = t[2]
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiKit.box(Color(col, 0.8), Color(0.03, 0.02, 0.08, 0.86), 26, 2, 14)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	v.add_child(UiKit.label("TIP  ·  " + String(t[0]), 28, col.lerp(Color.WHITE, 0.2), UiKit.display()))
	var l := UiKit.label(String(t[1]), 34, Color(0.92, 0.92, 1.0), UiKit.body())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(size.x - 140.0, 860.0), 0)
	v.add_child(l)
	add_child(p)
	move_child(p, _stick.get_index() + 1)
	_tip = p
	p.reset_size()
	p.position = Vector2((size.x - p.size.x) * 0.5, size.y * 0.66)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(p, "position:y", p.position.y - 30.0, 0.35).set_trans(Tween.TRANS_EXPO) \
			.set_ease(Tween.EASE_OUT)
	tw.tween_interval(4.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		p.queue_free()
		_next_tip())


## A run in another sector opens with its name and epithet (and Radiance).
func _show_sector() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = main.safe_top() + 320
	box.offset_bottom = box.offset_top + 320
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	move_child(box, _stick.get_index() + 1)
	var sd := Defs.sector(sim.sector)
	var col: Color = sd.color
	var l := HBoxContainer.new()
	l.alignment = BoxContainer.ALIGNMENT_CENTER
	l.add_theme_constant_override("separation", 16)
	l.add_child(UiKit.icon_rect("sector_" + String(sd.id), 84))
	l.add_child(UiKit.glow_label(String(sd.name).to_upper(), 60, col))
	box.add_child(l)
	box.add_child(UiKit.label(String(sd.title).to_upper(), 30, col.lerp(Color.WHITE, 0.5), UiKit.display_light()))
	var line := "SCORE  x%.2f" % sim.score_mult()
	if sim.radiance > 0:
		line = "RADIANCE %d  ·  %s  ·  %s" % [sim.radiance, String(Defs.RADIANCE[sim.radiance - 1].name).to_upper(), line]
	box.add_child(UiKit.label(line, 26, UiKit.DIM, UiKit.display_light()))
	UiKit.pop_in(box, 0.6, 0)
	var tw := box.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(box, "modulate:a", 0.0, 0.8)
	tw.tween_callback(box.queue_free)


## A Radiance run opens with its level, then fades away.
func _show_radiance() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = main.safe_top() + 320
	box.offset_bottom = box.offset_top + 300
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	move_child(box, _stick.get_index() + 1)
	var r := sim.radiance
	var col := Defs.radiance_color(r)
	var l := HBoxContainer.new()
	l.alignment = BoxContainer.ALIGNMENT_CENTER
	l.add_theme_constant_override("separation", 16)
	l.add_child(UiKit.icon_rect("radiance", 72))
	l.add_child(UiKit.glow_label("RADIANCE %d" % r, 52, col))
	box.add_child(l)
	box.add_child(UiKit.label(String(Defs.RADIANCE[r - 1].name).to_upper() + "  ·  SCORE  x%.2f" % sim.score_mult(),
			28, UiKit.DIM, UiKit.display_light()))
	UiKit.pop_in(box, 0.6, 0)
	var tw := box.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(box, "modulate:a", 0.0, 0.8)
	tw.tween_callback(box.queue_free)


## The Gauntlet opens with its four bosses in a row, then fades away.
func _show_gauntlet() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = main.safe_top() + 540
	box.offset_bottom = box.offset_top + 360
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	move_child(box, _stick.get_index() + 1)
	box.add_child(UiKit.glow_label("THE GAUNTLET", 64, Defs.GAUNTLET_COLOR))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	for k in Defs.GAUNTLET.size():
		var tr := TextureRect.new()
		tr.texture = Art.enemy[Defs.GAUNTLET[k]]
		tr.custom_minimum_size = Vector2(110, 110)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)
		UiKit.pop_in(tr, 0.5 + 0.18 * k, 0)
	box.add_child(UiKit.label("FOUR BOSSES  ·  NO WAITING  ·  BEAT YOUR SPLITS", 28, UiKit.DIM, UiKit.display_light()))
	UiKit.pop_in(box, 0.2, 0)
	var tw := box.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(box, "modulate:a", 0.0, 0.8)
	tw.tween_callback(box.queue_free)


## Daily runs open with today's rules, then fade away.
func _show_mods() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = main.safe_top() + 300
	box.offset_bottom = box.offset_top + 400
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	move_child(box, _stick.get_index() + 1)
	var head := "DAILY RUN  ·  " + Daily.label(int(sim.loadout.daily)) if sim.loadout.has("daily") else "MUTATORS"
	box.add_child(UiKit.glow_label(head, 44, UiKit.GOLD))
	box.add_child(UiKit.label("SCORE  x%.2f" % sim.score_mult(), 28, UiKit.DIM, UiKit.display_light()))
	var k := 0
	for id in sim.loadout.get("mods", []):
		var m: Dictionary = Defs.MUTATORS[id]
		var l := HBoxContainer.new()
		l.alignment = BoxContainer.ALIGNMENT_CENTER
		l.add_theme_constant_override("separation", 12)
		l.add_child(UiKit.icon_rect("mod_" + String(id), 56))
		l.add_child(UiKit.glow_label(String(m.name).to_upper(), 36, m.color, UiKit.display_light()))
		box.add_child(l)
		UiKit.pop_in(l, 0.3 + 0.25 * k, 0)
		k += 1
	UiKit.pop_in(box, 0.2, 0)
	var tw := box.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(box, "modulate:a", 0.0, 0.8)
	tw.tween_callback(box.queue_free)


func _show_hint() -> void:
	_hint = Control.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	move_child(_hint, _stick.get_index() + 1)
	var l := UiKit.glow_label("DRAG ANYWHERE TO MOVE", 44, UiKit.CYAN)
	l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -520
	l.offset_bottom = -440
	_hint.add_child(l)
	var l2 := UiKit.label("Your weapons fire on their own. Collect the light.", 34, Color(0.9, 0.9, 1.0, 0.8))
	l2.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	l2.offset_top = -430
	l2.offset_bottom = -380
	_hint.add_child(l2)
	var tw := _hint.create_tween().set_loops()
	tw.tween_property(l, "modulate:a", 0.45, 0.7)
	tw.tween_property(l, "modulate:a", 1.0, 0.7)


func _hide_hint() -> void:
	if _hint == null:
		return
	var h := _hint
	_hint = null
	var tw := h.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(h, "modulate:a", 0.0, 0.6)
	tw.tween_callback(h.queue_free)


func on_back() -> void:
	if _over:
		main.go_title()
	elif _chest.visible or _dawn != null:
		return
	elif _pause != null:
		_pause.close()
		_resume()
	else:
		open_pause()


func on_background() -> void:
	if not _over and _pause == null and not _cards.visible and not _chest.visible:
		open_pause()

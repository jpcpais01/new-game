class_name ResultsPanel
extends Modal
## End of run: verdict, stats, Flux earned, records, next steps.

signal retry
signal forge
signal home
signal hangar

var sim: Sim
var won := false
var beat := {}

var _flux_label: Label
var _flux_shown := 0.0
var _flux_target := 0
var _score_label: Label
var _score_shown := 0.0
var _score_target := 0


func build() -> void:
	accent = UiKit.GOLD if won else UiKit.MAGENTA
	var night := won and sim.endless
	var t := heading("BEYOND THE DAWN" if night else ("DAWN REACHED" if won else "SIGNAL LOST"),
			UiKit.MAGENTA if night else (UiKit.GOLD if won else UiKit.RED), 70 if night else 76)
	t.pivot_offset = Vector2(386, 50)
	t.scale = Vector2(1.5, 1.5)
	create_tween().tween_property(t, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var sub := "You outlasted the Eclipse." if won else "The swarm took you. The light remembers."
	if night:
		sub = "You held the Afterdark for %s through %d night%s." % [
				UiKit.fmt_time(float(sim.afterdark_seconds())), sim.night, "" if sim.night == 1 else "s"]
	body.add_child(UiKit.label(sub, 34, UiKit.DIM))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 18)
	_stat(grid, "SURVIVED", UiKit.fmt_time(sim.seconds()), beat.has("time"), 0)
	_stat(grid, "LEVEL", str(sim.level), beat.has("level"), 1)
	_stat(grid, "KILLS", UiKit.fmt_int(sim.kills), beat.has("kills"), 2)
	_stat(grid, "BOSSES", str(sim.bosses_killed), false, 3)
	_stat(grid, "ELITES", str(sim.elite_kills), false, 4)
	_stat(grid, "BEST CHAIN", UiKit.fmt_int(sim.chain_best), beat.has("chain"), 5)
	var cc := CenterContainer.new()
	cc.add_child(grid)
	body.add_child(cc)
	_score_box()
	_radiance()
	_evolutions()
	_missions()
	var flux_box := PanelContainer.new()
	var fsb := UiKit.box(UiKit.GOLD, Color(0.1, 0.07, 0.02, 0.6), 24, 2, 12)
	fsb.content_margin_top = 16
	fsb.content_margin_bottom = 16
	flux_box.add_theme_stylebox_override("panel", fsb)
	_flux_label = UiKit.glow_label("+0  FLUX", 58, UiKit.GOLD)
	flux_box.add_child(_flux_label)
	body.add_child(flux_box)
	_flux_target = sim.flux_earned()
	var total := UiKit.label("TOTAL  ◆ %s" % UiKit.fmt_int(int(Save.data.flux)), 30, UiKit.DIM, UiKit.display_light())
	body.add_child(total)
	var again := UiKit.button("RETRY", UiKit.CYAN, 52, true)
	again.custom_minimum_size = Vector2(0, 140)
	again.pressed.connect(func(): retry.emit())
	body.add_child(again)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var f := UiKit.button("FORGE", UiKit.GOLD, 40)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f.pressed.connect(func(): forge.emit())
	row.add_child(f)
	if not (beat.get("ships", []) as Array).is_empty():
		var hg := UiKit.button("HANGAR", UiKit.CYAN, 40)
		hg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hg.pressed.connect(func(): hangar.emit())
		row.add_child(hg)
	var h := UiKit.button("HOME", UiKit.MAGENTA, 40)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.pressed.connect(func(): home.emit())
	row.add_child(h)
	body.add_child(row)


## Radiance cleared, and the next level unlocked.
func _radiance() -> void:
	if not beat.has("radiance_unlocked") and sim.radiance <= 0:
		return
	var r := int(beat.get("radiance_unlocked", sim.radiance))
	var col := Defs.radiance_color(r)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	h.add_child(UiKit.icon_rect("radiance", 64))
	var text := "RADIANCE %d" % sim.radiance
	if beat.has("radiance_unlocked"):
		text = "RADIANCE %d UNLOCKED" % r
	elif won:
		text += "  CLEARED"
	h.add_child(UiKit.glow_label(text, 40 if beat.has("radiance_unlocked") else 32, col))
	body.add_child(h)
	UiKit.pop_in(h, 0.65, 20)
	if beat.has("radiance_unlocked"):
		Sfx.play("ascend")
		var sub := UiKit.label(("%s  ·  %s" % [String(Defs.RADIANCE[r - 1].name).to_upper(),
				String(Defs.RADIANCE[r - 1].text)]) + ("  Your next flight burns brighter." if
				Save.current_radiance() == r else "  Choose it in the Hangar."), 28, UiKit.DIM)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(760, 0)
		body.add_child(sub)
		var tw := h.create_tween().set_loops()
		tw.tween_property(h, "modulate", Color(1.4, 1.25, 1.0), 0.6)
		tw.tween_property(h, "modulate", Color.WHITE, 0.6)


## The score, counting up, with the Daily Run's standing under it.
func _score_box() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var head := "SCORE"
	if sim.score_mult() > 1.001:
		head += "  ·  x%.2f" % sim.score_mult()
	v.add_child(UiKit.label(head, 26, UiKit.DIM, UiKit.display_light()))
	_score_label = UiKit.glow_label("0", 78, Color.WHITE)
	v.add_child(_score_label)
	_score_target = sim.score()
	var daily := sim.loadout.has("daily")
	var tag := ""
	if beat.has("score"):
		tag = "NEW BEST SCORE"
	elif daily and (beat.has("daily_best") or beat.has("bounty")):
		tag = "TODAY'S BEST"
	elif beat.has("ship_score"):
		tag = "BEST WITH " + String(Defs.ship(sim.ship_id).name).to_upper()
	if tag != "":
		var r := UiKit.label(tag, 26, UiKit.GOLD, UiKit.display())
		v.add_child(r)
		var tw := r.create_tween().set_loops()
		tw.tween_property(r, "modulate:a", 0.4, 0.5)
		tw.tween_property(r, "modulate:a", 1.0, 0.5)
	body.add_child(v)
	UiKit.pop_in(v, 0.55, 20)
	if not daily:
		return
	var day := int(sim.loadout.daily)
	var e: Dictionary = Save.daily_entry(day)
	var p := PanelContainer.new()
	var sb := UiKit.box(UiKit.MAGENTA, Color(0.1, 0.02, 0.09, 0.6), 22, 2, 10)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	p.add_child(col)
	col.add_child(UiKit.label("DAILY RUN  ·  %s  ·  TRY %d" % [Daily.label(day), int(e.get("tries", 1))], 26,
			UiKit.MAGENTA.lerp(Color.WHITE, 0.3), UiKit.display()))
	col.add_child(UiKit.label("TODAY'S BEST  %s   ·   STREAK %d" % [UiKit.fmt_int(int(e.get("score", 0))),
			int(Save.data.daily_streak)], 26, UiKit.DIM, UiKit.display_light()))
	if beat.has("bounty"):
		col.add_child(UiKit.label("DAILY BOUNTY  +◆ %s" % UiKit.fmt_int(int(beat.bounty)), 30, UiKit.GOLD,
				UiKit.display()))
	body.add_child(p)
	UiKit.pop_in(p, 0.7, 20)


## Evolved weapons this run; first-time discoveries are marked NEW.
func _evolutions() -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	for w in sim.weapons:
		if not sim.is_evolved(w.id):
			continue
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(UiKit.icon_rect(w.id + "_evo", 110))
		var fresh: bool = beat.has(w.id)
		cell.add_child(UiKit.label("NEW" if fresh else "EVOLVED", 20, UiKit.GOLD if fresh else UiKit.DIM, UiKit.display()))
		row.add_child(cell)
	for id in sim.relics:
		var rc := VBoxContainer.new()
		rc.add_theme_constant_override("separation", 0)
		rc.add_child(UiKit.icon_rect(id, 84))
		rc.add_child(UiKit.label("UMBRAL" if Defs.is_umbral(id) else "RELIC", 18, Art.card_color(id), UiKit.display()))
		row.add_child(rc)
	if row.get_child_count() == 0:
		row.free()
		return
	body.add_child(row)
	UiKit.pop_in(row, 0.6, 20)


## Missions completed this run, and any ship they unlocked.
func _missions() -> void:
	var ids: Array = beat.get("missions", [])
	if ids.is_empty():
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var shown := 0
	for id in ids:
		for m in Defs.MISSIONS:
			if m.id != id:
				continue
			if shown < 3:
				var line := HBoxContainer.new()
				line.add_theme_constant_override("separation", 14)
				var name := UiKit.label("✓  " + String(m.name).to_upper(), 30, UiKit.GREEN, UiKit.display(),
						HORIZONTAL_ALIGNMENT_LEFT)
				name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				line.add_child(name)
				line.add_child(UiKit.label("+◆ %s" % UiKit.fmt_int(int(m.flux)), 30, UiKit.GOLD, UiKit.display()))
				box.add_child(line)
				UiKit.pop_in(line, 0.8 + 0.25 * shown, 0)
			shown += 1
	if shown > 3:
		box.add_child(UiKit.label("+%d MORE MISSIONS" % (shown - 3), 26, UiKit.DIM, UiKit.display_light()))
	body.add_child(box)
	for k in mini(shown, 3):
		get_tree().create_timer(0.8 + 0.25 * k).timeout.connect(func(): Sfx.play("mission", 1.0 + 0.06 * k))
	var new_ships: Array = beat.get("ships", [])
	if new_ships.size() > 1:
		_ship_row(new_ships)
		return
	for sid in new_ships:
		var sd := Defs.ship(String(sid))
		var p := PanelContainer.new()
		var sb := UiKit.box(sd.color, Color(sd.color, 0.12), 24, 3, 18)
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		p.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 18)
		h.add_child(UiKit.icon_rect("ship_" + String(sd.id), 90))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.add_child(UiKit.label("NEW SHIP UNLOCKED", 24, Color(1, 1, 1, 0.75), UiKit.display_light(),
				HORIZONTAL_ALIGNMENT_LEFT))
		v.add_child(UiKit.glow_label(String(sd.name).to_upper(), 50, sd.color))
		h.add_child(v)
		p.add_child(h)
		body.add_child(p)
		UiKit.pop_in(p, 1.4, 0)
		var tw := p.create_tween().set_loops()
		tw.tween_property(p, "modulate", Color(1.3, 1.3, 1.3), 0.7).set_delay(1.8)
		tw.tween_property(p, "modulate", Color.WHITE, 0.7)


## Several ships at once: one panel with a row of silhouettes.
func _ship_row(ids: Array) -> void:
	var p := PanelContainer.new()
	var sb := UiKit.box(UiKit.CYAN, Color(UiKit.CYAN, 0.1), 24, 3, 18)
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(UiKit.glow_label("%d NEW SHIPS UNLOCKED" % ids.size(), 34, UiKit.CYAN))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 22)
	v.add_child(h)
	for sid in ids:
		h.add_child(UiKit.icon_rect("ship_" + String(sid), 86))
	body.add_child(p)
	UiKit.pop_in(p, 1.4, 0)


func _stat(grid: GridContainer, name: String, value: String, record: bool, k: int) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(200, 0)
	box.add_theme_constant_override("separation", 0)
	box.add_child(UiKit.label(name, 22, UiKit.DIM, UiKit.display_light()))
	var v := UiKit.glow_label(value, 46, Color.WHITE)
	box.add_child(v)
	if record:
		var r := UiKit.label("NEW BEST", 20, UiKit.GOLD, UiKit.display())
		box.add_child(r)
		var tw := r.create_tween().set_loops()
		tw.tween_property(r, "modulate:a", 0.4, 0.5)
		tw.tween_property(r, "modulate:a", 1.0, 0.5)
	grid.add_child(box)
	UiKit.pop_in(box, 0.25 + 0.1 * k, 24)


func _process(delta: float) -> void:
	if _score_label != null and _score_shown < float(_score_target):
		_score_shown = minf(float(_score_target), _score_shown + maxf(50.0, float(_score_target) * 0.8) * delta)
		_score_label.text = UiKit.fmt_int(int(_score_shown))
	if _flux_label == null:
		return
	if _flux_shown < float(_flux_target):
		var before := int(_flux_shown)
		_flux_shown = minf(float(_flux_target), _flux_shown + maxf(4.0, float(_flux_target) * 0.9) * delta)
		if int(_flux_shown) != before and int(_flux_shown) % 3 == 0:
			Sfx.play("gem", 1.0 + 0.6 * _flux_shown / maxf(1.0, float(_flux_target)))
		_flux_label.text = "+%s  FLUX" % UiKit.fmt_int(int(_flux_shown))

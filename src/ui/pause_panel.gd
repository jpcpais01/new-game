class_name PausePanel
extends Modal
## Pause: current build, resume, settings, abandon run.

signal resume
signal quit

var sim: Sim


## Every Radiance rule in force, as short names.
static func _rules(r: int) -> Array:
	var out: Array = []
	for k in r:
		out.append(String(Defs.RADIANCE[k].name))
	return out


func build() -> void:
	heading("PAUSED", UiKit.CYAN, 70)
	var info := UiKit.label("%s   ·   LV %d   ·   %s KILLS" % [UiKit.fmt_time(sim.seconds()), sim.level,
			UiKit.fmt_int(sim.kills)], 32, UiKit.DIM, UiKit.display_light())
	body.add_child(info)
	body.add_child(UiKit.label("SCORE  %s" % UiKit.fmt_int(sim.score()), 30, Color.WHITE, UiKit.display()))
	if sim.gauntlet:
		var gl := UiKit.label("THE GAUNTLET  ·  CYCLE %d  ·  %d BOSSES PASSED" % [sim.gauntlet_cycle() + 1, sim.g_stage],
				26, Defs.GAUNTLET_COLOR, UiKit.display())
		body.add_child(gl)
	if sim.sector > 0:
		var sd := Defs.sector(sim.sector)
		var sl := UiKit.label("%s  ·  %s" % [String(sd.name).to_upper(), sd.text], 24, sd.color, UiKit.body())
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(760, 0)
		body.add_child(sl)
	if sim.radiance > 0:
		var rl := UiKit.label("RADIANCE %d  ·  %s" % [sim.radiance, ". ".join(_rules(sim.radiance))], 24,
				Defs.radiance_color(sim.radiance), UiKit.body())
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.custom_minimum_size = Vector2(760, 0)
		body.add_child(rl)
	for id in sim.loadout.get("mods", []):
		var m: Dictionary = Defs.MUTATORS[id]
		var ml := UiKit.label("%s %s  ·  %s" % ["+" if m.boon else "-", String(m.name).to_upper(), m.text], 24,
				m.color, UiKit.body())
		ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ml.custom_minimum_size = Vector2(760, 0)
		body.add_child(ml)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 18)
	var ids: Array = []
	for w in sim.weapons:
		ids.append(w.id)
	ids.append_array(sim.passive_order)
	for id in ids:
		var did := sim.display_id(id)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(UiKit.icon_rect(did, 120))
		var lv := sim.card_level(id)
		var nm := UiKit.label("%s  %s" % [String(Defs.card_info(did).get("name", id)).split(" ")[0].to_upper(),
				"EVO" if lv >= Defs.EVO_LEVEL else str(lv)], 18, Art.card_color(did), UiKit.display_light())
		nm.custom_minimum_size = Vector2(230, 30)
		cell.add_child(nm)
		grid.add_child(cell)
	var cc := CenterContainer.new()
	cc.add_child(grid)
	body.add_child(cc)
	# Relics carried this run.
	for id in sim.relics:
		var r: Dictionary = Defs.card_info(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(UiKit.icon_rect(id, 56))
		var rl := UiKit.label("%s  ·  %s" % [String(r.name).to_upper(), r.text], 22, r.color, UiKit.body(),
				HORIZONTAL_ALIGNMENT_LEFT)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.custom_minimum_size = Vector2(680, 0)
		row.add_child(rl)
		body.add_child(row)
	# Evolution recipes for the weapons you carry.
	var lines: Array = []
	for w in sim.weapons:
		if sim.is_evolved(w.id):
			continue
		var evo: Dictionary = Defs.EVOLUTIONS[w.id]
		var ready := sim.evolution_ready(w.id)
		var have := sim.passives.has(evo.needs)
		var l := UiKit.label("%s %s  +  %s  →  %s" % [
				String(Defs.WEAPONS[w.id].name).to_upper(), "5" if w.lvl >= Defs.MAX_LEVEL else "%d/5" % w.lvl,
				String(Defs.PASSIVES[evo.needs].name).to_upper() + ("" if have else "?"),
				String(evo.name).to_upper()], 22, UiKit.GOLD if ready else UiKit.DIM, UiKit.display_light())
		lines.append(l)
	if not lines.is_empty():
		body.add_child(UiKit.label("EVOLUTIONS  ·  OPEN A PRISM CACHE WHEN READY", 22, UiKit.CYAN, UiKit.display()))
		for l in lines:
			body.add_child(l)
	var res := UiKit.button("RESUME", UiKit.CYAN, 48, true)
	res.custom_minimum_size = Vector2(0, 130)
	res.pressed.connect(func():
		resume.emit()
		close())
	body.add_child(res)
	var set := UiKit.button("SETTINGS", UiKit.MAGENTA, 38)
	set.pressed.connect(func(): add_child(SettingsPanel.new()))
	body.add_child(set)
	var q := UiKit.button("ABANDON RUN", UiKit.RED, 34)
	var armed := [false]
	q.pressed.connect(func():
		if not armed[0]:
			armed[0] = true
			q.text = "TAP AGAIN TO ABANDON"
			return
		quit.emit()
		close())
	body.add_child(q)
